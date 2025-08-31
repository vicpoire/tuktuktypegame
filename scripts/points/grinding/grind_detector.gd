extends Area3D

@export var grinding_manager: Node
@export var min_speed_threshold: float = 1.0  # Reduced from 3.0
@export var min_grinding_duration: float = 0.2  # Reduced from 0.5
@export var max_wheels_touching: int = 1  # Max wheels allowed to touch ground while grinding
@export var detection_layers: int = 1
@export var excluded_objects: Array[String] = ["Floor", "Ground", "Terrain"]
@export var same_grind_cooldown: float = 2.0
@export var grinding_height_threshold: float = 0.3  # How high chassis needs to be above ground

var recently_ground_objects: Dictionary = {}
var current_grinds: Dictionary = {}  # Track ongoing grinds
var grind_start_times: Dictionary = {}

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	collision_layer = 0
	collision_mask = detection_layers
	
	# Setup cleanup timer
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.5
	cleanup_timer.timeout.connect(_cleanup_old_grinds)
	cleanup_timer.autostart = true
	add_child(cleanup_timer)
	
	# Setup continuous grinding check
	var grind_check_timer = Timer.new()
	grind_check_timer.wait_time = 0.1  # Check every 0.1 seconds
	grind_check_timer.timeout.connect(_check_ongoing_grinds)
	grind_check_timer.autostart = true
	add_child(grind_check_timer)

func test_grinding():
	var fake_object = Node3D.new()
	fake_object.name = "TestGrindObject"
	_start_potential_grind(fake_object)
	fake_object.queue_free()

func _on_body_entered(body: Node3D):
	# Allow the car itself to trigger grinding
	if body is RigidBody3D:
		# Check if this is the car we want to track
		var car = _find_car()
		if body == car:
			print("Car entered grinding zone!")
			_start_potential_grind(body)
			return
		else:
			return  # Ignore other rigid bodies
	
	# Skip excluded objects
	for excluded_name in excluded_objects:
		if body.name.to_lower().contains(excluded_name.to_lower()):
			return
	
	_start_potential_grind(body)

func _on_body_exited(body: Node3D):
	# Allow the car itself to trigger grinding end
	if body is RigidBody3D:
		# Check if this is the car we want to track
		var car = _find_car()
		if body == car:
			print("Car exited grinding zone!")
			_end_potential_grind(body)
			return
		else:
			return  # Ignore other rigid bodies
	
	# Skip excluded objects
	for excluded_name in excluded_objects:
		if body.name.to_lower().contains(excluded_name.to_lower()):
			return
	
	_end_potential_grind(body)

func _start_potential_grind(object: Node3D):
	var object_id = object.get_instance_id()
	var current_time = Time.get_time_dict_from_system()
	
	grind_start_times[object_id] = _dict_to_timestamp(current_time)
	current_grinds[object_id] = {
		"object": object,
		"start_time": _dict_to_timestamp(current_time),
		"start_speed": _get_current_speed(),
		"start_position": global_position
	}
	
	print("Started potential grind on: %s" % object.name)

func _end_potential_grind(object: Node3D):
	var object_id = object.get_instance_id()
	
	if not current_grinds.has(object_id):
		return
	
	var grind_data = current_grinds[object_id]
	var current_time = Time.get_time_dict_from_system()
	var grind_duration = _dict_to_timestamp(current_time) - grind_data.start_time
	
	print("Ended potential grind on: %s (duration: %.2f seconds)" % [object.name, grind_duration])
	
	# Check if this qualifies as a successful grind
	if grind_duration >= min_grinding_duration:
		_handle_successful_grind(object, grind_data, grind_duration)
	
	# Clean up
	current_grinds.erase(object_id)
	grind_start_times.erase(object_id)

func _check_ongoing_grinds():
	var objects_to_remove = []
	
	for object_id in current_grinds.keys():
		var grind_data = current_grinds[object_id]
		var object = grind_data.object
		
		# Check if object still exists
		if not is_instance_valid(object):
			objects_to_remove.append(object_id)
			continue
		
		# TEMPORARY: Be much more lenient - only check speed for now
		var current_speed = _get_current_speed()
		print("Ongoing grind check - Speed: %.1f (min: %.1f)" % [current_speed, min_speed_threshold])
		
		if current_speed < min_speed_threshold:
			print("Grind interrupted on: %s (too slow: %.1f < %.1f)" % [object.name, current_speed, min_speed_threshold])
			objects_to_remove.append(object_id)
			continue
		
		# Skip the other checks for now to see if grinding works
		print("Grind continuing on: %s" % object.name)
	
	# Remove interrupted grinds
	for object_id in objects_to_remove:
		current_grinds.erase(object_id)
		grind_start_times.erase(object_id)

func _handle_successful_grind(object: Node3D, grind_data: Dictionary, duration: float):
	var current_speed = _get_current_speed()
	
	# Check speed threshold
	if current_speed < min_speed_threshold:
		print("Grind rejected - too slow (%.1f < %.1f)" % [current_speed, min_speed_threshold])
		return
	
	# Check cooldown
	var object_id = object.get_instance_id()
	if recently_ground_objects.has(object_id):
		var last_grind_time = recently_ground_objects[object_id]
		var current_time = Time.get_time_dict_from_system()
		var time_diff = _calculate_time_difference(current_time, last_grind_time)
		
		if time_diff < same_grind_cooldown:
			print("Grind rejected - cooldown (%.1f seconds remaining)" % (same_grind_cooldown - time_diff))
			return
	
	# Record this grind
	recently_ground_objects[object_id] = Time.get_time_dict_from_system()
	
	# Send to grinding manager
	if grinding_manager and grinding_manager.has_method("register_grind"):
		var complete_grind_data = {
			"object": object,
			"duration": duration,
			"average_speed": (grind_data.start_speed + current_speed) / 2.0,
			"current_speed": current_speed,
			"start_speed": grind_data.start_speed,
			"position": global_position,
			"start_position": grind_data.start_position,
			"car_velocity": _get_car_velocity(),
			"wheels_touching": _get_wheels_touching_count()
		}
		grinding_manager.register_grind(complete_grind_data)
		print("Successful grind registered: %s (%.2fs, %.1f speed)" % [object.name, duration, current_speed])

func _is_currently_grinding() -> bool:
	var current_speed = _get_current_speed()
	
	# Must have minimum speed
	if current_speed < min_speed_threshold:
		print("Grinding failed: too slow (%.1f < %.1f)" % [current_speed, min_speed_threshold])
		return false
	
	# Check wheel contact - be more lenient
	var wheels_touching = _get_wheels_touching_count()
	print("Grinding check: Speed %.1f, Wheels touching: %d (max allowed: %d)" % [current_speed, wheels_touching, max_wheels_touching])
	
	if wheels_touching > max_wheels_touching:
		print("Grinding failed: too many wheels touching (%d > %d)" % [wheels_touching, max_wheels_touching])
		return false
	
	# Since we're in the grinding zone area, assume chassis contact
	# The area collision detection handles this for us
	print("Grinding conditions met!")
	return true

func _is_chassis_touching() -> bool:
	# For now, let's simplify this - if we're in the grinding zone and moving, assume chassis contact
	# This is a simpler approach that should work for most grinding scenarios
	var car = _find_car()
	if not car:
		return false
	
	# Basic check: if we're in the area and have low wheel contact, assume we're grinding
	var wheels_touching = _get_wheels_touching_count()
	var total_wheels = car.get_wheels().size() if car.has_method("get_wheels") else 4
	
	# If most wheels aren't touching, we're probably grinding on something
	return wheels_touching <= max_wheels_touching
	
	# Alternative: Use the Area3D collision detection since we're already inside the grinding zone
	# The fact that _is_currently_grinding() is called means we detected collision with the grinding object

func _get_wheels_touching_count() -> int:
	var car = _find_car()
	if not car or not car.has_method("get_wheels"):
		return 0
	
	var wheels = car.get_wheels()
	var touching_count = 0
	
	for wheel in wheels:
		if wheel.is_colliding():
			touching_count += 1
	
	return touching_count

func _get_current_speed() -> float:
	var car = _find_car()
	if car:
		return car.linear_velocity.length()
	return 0.0

func _get_car_velocity() -> Vector3:
	var car = _find_car()
	if car:
		return car.linear_velocity
	return Vector3.ZERO

func _find_car() -> RigidBody3D:
	if get_parent() is RigidBody3D:
		return get_parent() as RigidBody3D
	
	var car = get_tree().get_first_node_in_group("player") as RigidBody3D
	if car:
		return car
	
	var all_bodies = get_tree().get_nodes_in_group("vehicle")
	if all_bodies.size() > 0:
		return all_bodies[0] as RigidBody3D
	
	return null

func _cleanup_old_grinds():
	var current_time = Time.get_time_dict_from_system()
	var keys_to_remove = []
	
	for object_id in recently_ground_objects.keys():
		var grind_time = recently_ground_objects[object_id]
		var time_diff = _calculate_time_difference(current_time, grind_time)
		
		if time_diff > (same_grind_cooldown * 2):
			keys_to_remove.append(object_id)
	
	for key in keys_to_remove:
		recently_ground_objects.erase(key)

func _calculate_time_difference(current: Dictionary, previous: Dictionary) -> float:
	return _dict_to_timestamp(current) - _dict_to_timestamp(previous)

func _dict_to_timestamp(time_dict: Dictionary) -> float:
	return time_dict.hour * 3600.0 + time_dict.minute * 60.0 + time_dict.second

func can_object_trigger_grind(object: Node3D) -> bool:
	var object_id = object.get_instance_id()
	
	if not recently_ground_objects.has(object_id):
		return true
	
	var last_grind_time = recently_ground_objects[object_id]
	var current_time = Time.get_time_dict_from_system()
	var time_diff = _calculate_time_difference(current_time, last_grind_time)
	
	return time_diff >= same_grind_cooldown

func get_object_cooldown_remaining(object: Node3D) -> float:
	var object_id = object.get_instance_id()
	
	if not recently_ground_objects.has(object_id):
		return 0.0
	
	var last_grind_time = recently_ground_objects[object_id]
	var current_time = Time.get_time_dict_from_system()
	var time_diff = _calculate_time_difference(current_time, last_grind_time)
	
	return max(0.0, same_grind_cooldown - time_diff)
