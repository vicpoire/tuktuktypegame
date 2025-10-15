extends Node

@export var car: RigidBody3D
@export var combo_manager: Node
@export var min_air_time: float = 0.3
@export var min_air_height: float = 0.5
@export var air_points_base: int = 25
@export var air_time_multiplier: float = 10.0
@export var min_wheels_for_grounded: int = 2
@export var ground_buffer_time: float = 0.1
@export var takeoff_buffer_time: float = 0.05
@export var debug_output: bool = true

var is_airborne: bool = false
var air_time: float = 0.0
var max_air_height: float = 0.0
var air_start_position: Vector3 = Vector3.ZERO
var grounded_timer: float = 0.0
var last_grounded_time: float = 0.0
var physics_time: float = 0.0

signal airtime_started(start_position: Vector3)
signal airtime_ended(duration: float, max_height: float, points: int)

func _ready():
	if not car:
		car = $".."
	if not combo_manager:
		combo_manager = get_tree().get_first_node_in_group("combo_manager")

func _physics_process(delta: float) -> void:
	if not car:
		return
	
	physics_time += delta
	_update_air_state(delta)

func _update_air_state(delta: float) -> void:
	var currently_grounded = _is_car_grounded()
	
	if currently_grounded:
		grounded_timer += delta
		
		# just landed after being airborne
		if is_airborne and grounded_timer > ground_buffer_time:
			_on_land()
		
		if grounded_timer > 0.2:
			is_airborne = false
			air_time = 0.0
			max_air_height = 0.0
		
		last_grounded_time = physics_time
		
	else:
		grounded_timer = 0.0
		
		# check if just became airborne
		if not is_airborne:
			var time_since_grounded = physics_time - last_grounded_time
			
			if time_since_grounded > takeoff_buffer_time:
				_on_takeoff()
		
		if is_airborne:
			air_time += delta
			
			var current_height = car.global_position.y - air_start_position.y
			if current_height > max_air_height:
				max_air_height = current_height
			
			if debug_output and int(air_time * 10) % 10 == 0:
				print("airborne: %.2fs, height: %.2fm" % [air_time, current_height])

func _is_car_grounded() -> bool:
	# check wheels 
	if car.has_method("get_wheels"):
		var wheels = car.get_wheels()
		var grounded_count = 0
		
		for wheel in wheels:
			if wheel.is_colliding():
				grounded_count += 1
		
		return grounded_count >= min_wheels_for_grounded
	
	# check if car has significant downward velocity while near ground
	var space_state = car.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		car.global_position,
		car.global_position + Vector3.DOWN * 2.0
	)
	query.exclude = [car]
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var distance_to_ground = car.global_position.distance_to(result.position)
		return distance_to_ground < 1.0
	
	return false

func _on_takeoff() -> void:
	is_airborne = true
	air_time = 0.0
	max_air_height = 0.0
	air_start_position = car.global_position
	airtime_started.emit(air_start_position)

func _on_land() -> void:
	if air_time >= min_air_time or max_air_height >= min_air_height:
		_award_air_points()
	
	# reset air state
	is_airborne = false
	air_time = 0.0
	max_air_height = 0.0

func _award_air_points() -> void:

	var time_bonus = int(air_time * air_time_multiplier)
	var height_bonus = int(max_air_height)
	var total_points = air_points_base + time_bonus + height_bonus
	
	if debug_output:
		print("  - Points breakdown:")
		print("    Base: ", air_points_base)
		print("    Time bonus: ", time_bonus, " (%.2fs)" % air_time)
		print("    Height bonus: ", height_bonus, " (%.2fm)" % max_air_height)
		print("    Total: ", total_points)
	
	# send to combo manager
	if combo_manager:
		if combo_manager.has_method("on_airtime"):
			if debug_output:
				print("  - Sending to combo manager...")
			var final_points = combo_manager.on_airtime(total_points)
			if debug_output:
				print("  - Combo manager returned: ", final_points)
		else:
			push_error("[AirtimeDetector] Combo manager has no on_airtime() method!")
	else:
		push_warning("[AirtimeDetector] No combo manager - points not awarded!")
	
	# signal
	airtime_ended.emit(air_time, max_air_height, total_points)

# pub getters
func get_is_airborne() -> bool:
	return is_airborne

func get_air_time() -> float:
	return air_time

func get_max_air_height() -> float:
	return max_air_height

func get_current_height() -> float:
	if not is_airborne:
		return 0.0
	return car.global_position.y - air_start_position.y
