extends RigidBody3D

@export var acceleration := 600.0
@export var max_speed := 20.0
@export var accel_curve : Curve

@export var tire_turn_speed := 2.0
@export var tire_turn_max_degree := 25

@export_group("drift")
@export var drift_turn_boost := 2.0  
@export var drift_min_speed := 3.0
@export var drift_angle_multiplier := 1.8
@export var drift_side_grip := 0.3

@export_group("grip")
@export var side_grip := 1.0 
@export var forward_grip := 1.0
@export var slip_point := 0.5
@export var min_grip_angle := 45.0
@export var ledge_check_distance := 0.5

@export_group("aircontrol")
@export var air_turn_torque := 50.0
@export var air_flip_torque := 30.0

@export_group("anticlipping")
@export var side_raycast_distance := 0.3
@export var side_pushback_force := 1000.0

@export_group("tilting")
@export var tilt_torque := 4000.0
@export var tilt_rest_offset := 0.1 
@export var tilt_speed := 3.0

var jump_force := 15000.0
var jump_hold_force := 2000.0

var current_speed: float

var motor_input := 0
var hand_brake := false
var is_sharp_turning := false
var sharp_turn_amount := 0.0

var jump_pressed := false

var wheels: Array[RaycastWheel] = []
var wheel_default_rest_dists: Dictionary = {}
var wheel_target_rest_dists: Dictionary = {}
var skid_marks: Array[GPUParticles3D] = []
var steering_wheels: Array[RaycastWheel] = []

func _ready():
	add_to_group("car")
	_setup_wheels()

func _setup_wheels() -> void:
	wheels.clear()
	skid_marks.clear()
	steering_wheels.clear()
	_collect_wheels_recursive(self)
	for wheel in wheels:
		wheel_default_rest_dists[wheel] = wheel.rest_dist
		wheel_target_rest_dists[wheel] = wheel.rest_dist
		var skid_mark := GPUParticles3D.new()
		add_child(skid_mark)
		skid_marks.append(skid_mark)
		skid_mark.emitting = false
		skid_mark.amount = 100
		var name := wheel.name.to_lower()
		if name.contains("front") or name.contains("steer") or name.ends_with("f"):
			steering_wheels.append(wheel)
	if steering_wheels.is_empty() and not wheels.is_empty():
		steering_wheels.append(wheels[0])

func _handle_suspension_tilt(delta: float) -> void:
	var tilt_left := Input.is_action_pressed("tiltleft")
	var tilt_right := Input.is_action_pressed("tiltright")
	var direction := 0
	if tilt_left:
		direction = 1
	elif tilt_right:
		direction = -1
	for wheel in wheels:
		var is_left = wheel.position.x < 0.0
		var default_rest = wheel_default_rest_dists.get(wheel, wheel.rest_dist)
		var target = default_rest
		if direction != 0:
			if (direction == -1 and is_left) or (direction == 1 and not is_left):
				target = default_rest + tilt_rest_offset
			else:
				target = default_rest - tilt_rest_offset
		var current = wheel_target_rest_dists.get(wheel, default_rest)
		current = lerp(current, target, delta * tilt_speed)
		wheel_target_rest_dists[wheel] = current
		wheel.rest_dist = current

func _collect_wheels_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is RaycastWheel:
			wheels.append(child)
			var name = child.name.to_lower()
			if name.contains("front") or name.contains("steer") or name.ends_with("f"):
				steering_wheels.append(child)
		_collect_wheels_recursive(child)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sharpturn"):
		hand_brake = true
	elif event.is_action_released("sharpturn"):
		hand_brake = false
	if event.is_action_pressed("forward"):
		motor_input = 1
	elif event.is_action_released("forward"):
		motor_input = 0
	if event.is_action_pressed("backward"):
		motor_input = -1
	elif event.is_action_released("backward"):
		motor_input = 0

func _physics_process(delta: float) -> void:
	_update_sharp_turn_state(delta)
	_handle_steering(delta)
	_handle_wheel_side_collision()
	_handle_suspension_tilt(delta)
	get_current_speed()
	var grounded := false
	for i in range(wheels.size()):
		var wheel = wheels[i]
		if wheel.is_colliding():
			grounded = true
		wheel.force_raycast_update()
		_do_suspension(wheel)
		_do_acceleration(wheel)
		_do_traction(wheel, i)
	if not grounded:
		_handle_air_control(delta)
	if grounded:
		center_of_mass = Vector3.ZERO
	else:
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3.DOWN * 0.5

func get_current_speed() -> float:
	return linear_velocity.length()

func _handle_wheel_side_collision() -> void:
	var space_state = get_world_3d().direct_space_state
	for wheel in wheels:
		if not wheel.is_colliding():
			continue
		var wheel_pos = wheel.wheel.global_position
		var wheel_right = wheel.global_basis.x
		var wheel_left = -wheel.global_basis.x
		var right_query = PhysicsRayQueryParameters3D.create(
			wheel_pos,
			wheel_pos + wheel_right * side_raycast_distance
		)
		right_query.exclude = [self]
		var right_result = space_state.intersect_ray(right_query)
		if not right_result.is_empty():
			var pushback_force = wheel_left * side_pushback_force
			var force_position = wheel_pos - global_position
			apply_force(pushback_force, force_position)
		var left_query = PhysicsRayQueryParameters3D.create(
			wheel_pos,
			wheel_pos + wheel_left * side_raycast_distance
		)
		left_query.exclude = [self]
		var left_result = space_state.intersect_ray(left_query)
		if not left_result.is_empty():
			var pushback_force = wheel_right * side_pushback_force
			var force_position = wheel_pos - global_position
			apply_force(pushback_force, force_position)

func _update_sharp_turn_state(delta: float) -> void:
	var speed: float = linear_velocity.length()
	var turn_input: float = abs(Input.get_axis("right", "left"))
	var should_sharp_turn: bool = false
	if speed > drift_min_speed and hand_brake and turn_input > 0.1:
		should_sharp_turn = true
	if should_sharp_turn:
		is_sharp_turning = true
		sharp_turn_amount = move_toward(sharp_turn_amount, 1.0, delta * 4.0)
	else:
		sharp_turn_amount = move_toward(sharp_turn_amount, 0.0, delta * 3.0)
		if sharp_turn_amount < 0.05:
			is_sharp_turning = false
			sharp_turn_amount = 0.0

func _handle_tilt_input() -> void:
	var tilt_left := Input.is_action_pressed("tiltleft")
	var tilt_right := Input.is_action_pressed("tiltright")
	if tilt_left == tilt_right:
		return
	var direction := 1.0 if tilt_right else -1.0
	var torque := global_basis.x * direction * tilt_torque
	apply_torque(torque)

func _handle_steering(delta: float) -> void:
	var turn_input := Input.get_axis("right", "left") * tire_turn_speed
	if is_sharp_turning:
		turn_input *= lerp(1.0, drift_turn_boost, sharp_turn_amount)
		var sharp_turn_max_angle = tire_turn_max_degree * drift_angle_multiplier
		for wheel in steering_wheels:
			if turn_input != 0:
				var new_rotation = clampf(
					wheel.rotation.y + turn_input * delta,
					deg_to_rad(-sharp_turn_max_angle),
					deg_to_rad(sharp_turn_max_angle)
				)
				wheel.rotation.y = new_rotation
			else:
				wheel.rotation.y = move_toward(wheel.rotation.y, 0, tire_turn_speed * 0.8 * delta)
	else:
		for wheel in steering_wheels:
			if turn_input != 0:
				var new_rotation = clampf(
					wheel.rotation.y + turn_input * delta,
					deg_to_rad(-tire_turn_max_degree),
					deg_to_rad(tire_turn_max_degree)
				)
				wheel.rotation.y = new_rotation
			else:
				wheel.rotation.y = move_toward(wheel.rotation.y, 0, tire_turn_speed * delta)

func _can_grip_surface(wheel: RaycastWheel) -> bool:
	if not wheel.is_colliding():
		return false
	var surface_normal = wheel.get_collision_normal()
	var angle_from_up = rad_to_deg(Vector3.UP.angle_to(surface_normal))
	if angle_from_up > min_grip_angle:
		return false
	var forward_dir = -global_basis.z
	var angle_with_forward = rad_to_deg(forward_dir.angle_to(surface_normal))
	if angle_with_forward < 60.0:
		return false
	if _is_approaching_ledge(wheel):
		return false
	return true

func _is_approaching_ledge(wheel: RaycastWheel) -> bool:
	var space_state = get_world_3d().direct_space_state
	var wheel_velocity = _get_point_velocity(wheel.wheel.global_position)
	if wheel_velocity.length() < 1.0:
		return false
	var movement_direction = wheel_velocity.normalized()
	var check_position = wheel.wheel.global_position + movement_direction * ledge_check_distance
	var query = PhysicsRayQueryParameters3D.create(
		check_position,
		check_position + Vector3.DOWN * (wheel.rest_dist + wheel.wheel_radius + 0.5)
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var ground_distance = check_position.distance_to(result.position)
	var current_ground_distance = wheel.global_position.distance_to(wheel.get_collision_point())
	if ground_distance > current_ground_distance + 0.5:
		return true
	return false

func _do_traction(wheel: RaycastWheel, idx: int) -> void:
	if not wheel.is_colliding() or idx >= skid_marks.size():
		if idx < skid_marks.size():
			skid_marks[idx].emitting = false
		return
	var skid_mark = skid_marks[idx]
	skid_mark.global_position = wheel.get_collision_point() + Vector3.UP * 0.01
	skid_mark.look_at(skid_mark.global_position + global_basis.z)
	var side_dir := wheel.global_basis.x
	var wheel_velocity := _get_point_velocity(wheel.wheel.global_position)
	var side_speed := side_dir.dot(wheel_velocity)
	var speed_factor: float = wheel_velocity.length()
	var should_skid := false
	var can_grip := _can_grip_surface(wheel)
	if can_grip:
		var grip_loss: float = abs(side_speed / speed_factor) if speed_factor > 0.01 else 0.0
		should_skid = (is_sharp_turning and sharp_turn_amount > 0.3) or grip_loss > 0.7
	else:
		should_skid = speed_factor > 2.0
	skid_mark.emitting = should_skid
	if not can_grip:
		return
	var grip_loss: float = abs(side_speed / speed_factor) if speed_factor > 0.01 else 0.0
	var base_traction: float = wheel.grip_curve.sample_baked(grip_loss) if wheel.grip_curve else 1.0
	var final_side_grip := base_traction * side_grip
	if is_sharp_turning:
		var drift_grip = base_traction * drift_side_grip
		final_side_grip = lerp(final_side_grip, drift_grip, sharp_turn_amount)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var weight_per_wheel: float = (mass * gravity) / wheels.size()
	var side_force: Vector3 = -side_dir * side_speed * final_side_grip * weight_per_wheel
	var forward_velocity: float = -wheel.global_basis.z.dot(wheel_velocity)
	var forward_resistance: Vector3 = global_basis.z * forward_velocity * 0.05 * forward_grip * weight_per_wheel
	var force_position := wheel.wheel.global_position - global_position
	apply_force(side_force, force_position)
	apply_force(forward_resistance, force_position)

func _do_acceleration(wheel: RaycastWheel) -> void:
	if not wheel.is_colliding():
		return
	if not _can_grip_surface(wheel):
		return
	var forward_dir := -wheel.global_basis.z
	var wheel_speed := forward_dir.dot(linear_velocity)
	wheel.wheel.rotate_x((-wheel_speed * get_process_delta_time()) / wheel.wheel_radius)
	if wheel.is_motor and motor_input != 0:
		var speed_ratio := wheel_speed / max_speed
		var power_curve := accel_curve.sample_baked(speed_ratio) if accel_curve else 1.0
		var motor_force := forward_dir * acceleration * motor_input * power_curve * forward_grip
		var force_position := wheel.wheel.global_position - global_position
		apply_force(motor_force, force_position)

func _do_suspension(wheel: RaycastWheel) -> void:
	if not wheel.is_colliding():
		return
	wheel.target_position.y = -(wheel.rest_dist + wheel.wheel_radius + wheel.over_extend)
	var hit_point := wheel.get_collision_point()
	var spring_dir := wheel.global_transform.basis.y
	var spring_length := maxf(0.0, wheel.global_position.distance_to(hit_point) - wheel.wheel_radius)
	var compression := wheel.rest_dist - spring_length
	wheel.wheel.position.y = -spring_length
	var spring_force := wheel.spring_strength * compression
	var contact_velocity := _get_point_velocity(hit_point)
	var spring_velocity := spring_dir.dot(contact_velocity)
	var damping_force := wheel.spring_damping * spring_velocity
	var total_force := (spring_force - damping_force) * wheel.get_collision_normal()
	var force_position := wheel.wheel.global_position - global_position
	apply_force(total_force, force_position)

func _handle_air_control(delta: float) -> void:
	var turn_left = Input.is_action_pressed("airtimeR")
	var turn_right = Input.is_action_pressed("airtimeL")
	if turn_left and not turn_right:
		var turn_torque = Vector3.UP * -1.0 * air_turn_torque
		apply_torque(turn_torque)
	elif turn_right and not turn_left:
		var turn_torque = Vector3.UP * 1.0 * air_turn_torque
		apply_torque(turn_torque)
	var flip_front = Input.is_action_pressed("airtimeB")
	var flip_back = Input.is_action_pressed("airtimeF")
	if flip_front and not flip_back:
		var flip_torque = global_basis.x * air_flip_torque
		apply_torque(flip_torque)
	elif flip_back and not flip_front:
		var flip_torque = global_basis.x * -air_flip_torque
		apply_torque(flip_torque)

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)



func _is_grounded() -> bool:
	for wheel in wheels:
		if wheel.is_colliding() and _can_grip_surface(wheel):
			return true
	return false

func get_wheels() -> Array[RaycastWheel]:
	return wheels
