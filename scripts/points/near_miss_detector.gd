extends Area3D

@export var near_miss_manager: Node
@export var min_speed_threshold: float = 5.0  
@export var detection_layers: int = 1 
@export var excluded_objects: Array[String] = ["Floor", "Ground", "Terrain"]
@export var detect_area3d: bool = false
@export var detection_mode: String = "on_exit"  # "on_exit" or "on_enter"
@export var exit_delay: float = 0.3  # Delay after exiting objects

# NEW: Allow same object to trigger near miss again after this delay
@export var same_object_cooldown: float = 2.0  # Time before same object can trigger again

var recently_missed_objects: Dictionary = {}
var objects_inside: Dictionary = {}  # Track objects currently inside detector

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if detect_area3d:
		area_entered.connect(_on_area_entered)
		area_exited.connect(_on_area_exited)
	
	collision_layer = 0  
	collision_mask = detection_layers
	
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.5
	cleanup_timer.timeout.connect(_cleanup_old_misses)
	cleanup_timer.autostart = true
	add_child(cleanup_timer)

func test_near_miss():
	var fake_object = Node3D.new()
	fake_object.name = "TestObject"
	_handle_near_miss(fake_object)
	fake_object.queue_free()

func test_point_manager_direct():
	var point_mgr = get_tree().get_first_node_in_group("point_manager")
	if point_mgr:
		if point_mgr.has_method("add_points"):
			point_mgr.add_points(50, "test")

func test_near_miss_manager_direct():
	if near_miss_manager:
		if near_miss_manager.has_method("register_near_miss"):
			var fake_data = {"speed": 10.0, "position": Vector3.ZERO, "object": self}
			near_miss_manager.register_near_miss(fake_data)

func _on_body_entered(body: Node3D):
	if body is RigidBody3D:
		return
	
	for excluded_name in excluded_objects:
		if body.name.to_lower().contains(excluded_name.to_lower()):
			return
	
	var object_id = body.get_instance_id()
	objects_inside[object_id] = {
		"object": body,
		"entry_speed": _get_current_speed(),
		"entry_time": Time.get_time_dict_from_system()
	}
	
	if detection_mode == "on_enter":
		_handle_near_miss(body)

func _on_body_exited(body: Node3D):
	if body is RigidBody3D:
		return
	
	for excluded_name in excluded_objects:
		if body.name.to_lower().contains(excluded_name.to_lower()):
			return
	
	var object_id = body.get_instance_id()
	if objects_inside.has(object_id) and detection_mode == "on_exit":
		_handle_near_miss(body)
	
	objects_inside.erase(object_id)

func _on_area_entered(area: Area3D):
	if not detect_area3d:
		return
	
	var object_id = area.get_instance_id()
	objects_inside[object_id] = {
		"object": area,
		"entry_speed": _get_current_speed(),
		"entry_time": Time.get_time_dict_from_system()
	}
	
	if detection_mode == "on_enter":
		_handle_near_miss(area)

func _on_area_exited(area: Area3D):
	if not detect_area3d:
		return
	
	var object_id = area.get_instance_id()
	if objects_inside.has(object_id) and detection_mode == "on_exit":
		_handle_near_miss(area)
	
	objects_inside.erase(object_id)

func _handle_near_miss(object: Node3D):
	var current_speed = _get_current_speed()
	if current_speed == 0:
		return
		
	print("found car, current speed: ", current_speed)
	
	if current_speed < min_speed_threshold:
		return
	
	var object_id = object.get_instance_id()
	
	# MODIFIED: Check if object is in cooldown period
	if recently_missed_objects.has(object_id):
		var last_miss_time = recently_missed_objects[object_id]
		var current_time = Time.get_time_dict_from_system()
		var time_diff = _calculate_time_difference(current_time, last_miss_time)
		
		# If not enough time has passed, skip this near miss
		if time_diff < same_object_cooldown:
			print("Object %s is still in cooldown (%.1f seconds remaining)" % [object.name, same_object_cooldown - time_diff])
			return
	
	# Update the timestamp for this object (whether it's new or cooldown expired)
	recently_missed_objects[object_id] = Time.get_time_dict_from_system()
	
	if near_miss_manager and near_miss_manager.has_method("register_near_miss"):
		var miss_data = {
			"object": object,
			"speed": current_speed,
			"position": global_position,
			"car_velocity": _get_car_velocity()
		}
		near_miss_manager.register_near_miss(miss_data)
		print("Near miss registered for object: %s (speed: %.1f)" % [object.name, current_speed])

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

func _cleanup_old_misses():
	var current_time = Time.get_time_dict_from_system()
	var keys_to_remove = []
	
	for object_id in recently_missed_objects.keys():
		var miss_time = recently_missed_objects[object_id]
		var time_diff = _calculate_time_difference(current_time, miss_time)
		
		# MODIFIED: Use same_object_cooldown instead of object_cleanup_time
		# Clean up objects that are way past their cooldown to prevent memory bloat
		if time_diff > (same_object_cooldown * 2):
			keys_to_remove.append(object_id)
	
	for key in keys_to_remove:
		recently_missed_objects.erase(key)

func _calculate_time_difference(current: Dictionary, previous: Dictionary) -> float:
	var current_total = current.hour * 3600 + current.minute * 60 + current.second
	var previous_total = previous.hour * 3600 + previous.minute * 60 + previous.second
	return current_total - previous_total

# NEW: Helper function to check if an object can trigger a near miss
func can_object_trigger_near_miss(object: Node3D) -> bool:
	var object_id = object.get_instance_id()
	
	if not recently_missed_objects.has(object_id):
		return true
	
	var last_miss_time = recently_missed_objects[object_id]
	var current_time = Time.get_time_dict_from_system()
	var time_diff = _calculate_time_difference(current_time, last_miss_time)
	
	return time_diff >= same_object_cooldown

# NEW: Get remaining cooldown time for an object
func get_object_cooldown_remaining(object: Node3D) -> float:
	var object_id = object.get_instance_id()
	
	if not recently_missed_objects.has(object_id):
		return 0.0
	
	var last_miss_time = recently_missed_objects[object_id]
	var current_time = Time.get_time_dict_from_system()
	var time_diff = _calculate_time_difference(current_time, last_miss_time)
	
	return max(0.0, same_object_cooldown - time_diff)
