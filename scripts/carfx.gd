extends Node3D
class_name CarFX

@export var car: NodePath
@export var fog_particle_scene: PackedScene
@export var fog_emit_speed_threshold := 2.0
@export var skid_side_threshold := 3.0
@export var brake_skid_speed_threshold := 6.0

@export var skid_marks: Array[GPUParticles3D] = []
@export var dust_emitters: Array[GPUParticles3D] = []
@export var skid_smoke_emitters: Array[GPUParticles3D] = []
@export var wheels: Array[RaycastWheel]

var car_body: RigidBody3D


func _ready() -> void:
	if car.is_empty():
		push_error("Car path not set in CarFX")
		return

	car_body = get_node(car) as RigidBody3D
	if not car_body:
		push_error("Target is not a RigidBody3D")
		return

	if car_body.has_method("get_wheels"):
		wheels = car_body.get_wheels()
	else:
		push_error("Car controller missing get_wheels() method.")
		return

	for wheel in wheels:
		# Skid mark particle
		var skid := GPUParticles3D.new()
		skid.emitting = false
		skid.amount = 100
		add_child(skid)
		skid_marks.append(skid)

		# Dust emitter
		if fog_particle_scene:
			var dust := fog_particle_scene.instantiate() as GPUParticles3D
			dust.emitting = false
			add_child(dust)
			dust_emitters.append(dust)
		else:
			push_warning("Fog particle scene is not assigned (dust emitter).")

		# Skid smoke emitter
		if fog_particle_scene:
			var smoke := fog_particle_scene.instantiate() as GPUParticles3D
			smoke.emitting = false
			add_child(smoke)
			skid_smoke_emitters.append(smoke)
		else:
			push_warning("Fog particle scene is not assigned (skid smoke).")


func _physics_process(_delta: float) -> void:
	_handle_skidmarks()
	_handle_dust()
	_handle_skid_smoke()


func _handle_skidmarks() -> void:
	if not car_body or wheels.is_empty():
		return

	for i in wheels.size():
		var wheel = wheels[i]
		var skid = skid_marks[i]

		if not wheel.is_colliding():
			skid.emitting = false
			continue

		var wheel_velocity = car_body.linear_velocity + car_body.angular_velocity.cross(wheel.global_position - car_body.global_position)
		var side_velocity = wheel.global_basis.x.dot(wheel_velocity)
		var forward_velocity = -wheel.global_basis.z.dot(wheel_velocity)

		var is_drifting = car_body.get("is_sharp_turning")
		var sharp_turn_amount = car_body.get("sharp_turn_amount")
		var motor_input = car_body.get("motor_input")

		var is_braking = motor_input < 0 and forward_velocity > brake_skid_speed_threshold
		var is_sliding = abs(side_velocity) > skid_side_threshold
		var is_drift_skid = is_drifting and sharp_turn_amount > 0.3

		var should_skid = is_drift_skid or is_sliding or is_braking

		skid.global_position = wheel.get_collision_point() + Vector3.UP * 0.02
		skid.look_at(skid.global_position + car_body.global_basis.z)
		skid.emitting = should_skid


func _handle_dust() -> void:
	if not car_body or wheels.is_empty():
		return

	for i in wheels.size():
		var wheel = wheels[i]
		var dust = dust_emitters[i]

		if not wheel.is_colliding():
			dust.emitting = false
			continue

		var wheel_velocity = car_body.linear_velocity + car_body.angular_velocity.cross(wheel.global_position - car_body.global_position)
		var speed = wheel_velocity.length()

		var should_emit = speed > fog_emit_speed_threshold

		dust.global_position = wheel.get_collision_point() + Vector3.UP * 0.05
		dust.look_at(dust.global_position + wheel_velocity.normalized())
		dust.emitting = should_emit


func _handle_skid_smoke() -> void:
	if not car_body or wheels.is_empty():
		return

	for i in wheels.size():
		var wheel = wheels[i]
		var smoke = skid_smoke_emitters[i]

		if not wheel.is_colliding():
			smoke.emitting = false
			continue

		var is_drifting = car_body.get("is_sharp_turning")
		var sharp_turn_amount = car_body.get("sharp_turn_amount")
		var is_drift_skid = is_drifting and sharp_turn_amount > 0.3

		smoke.global_position = wheel.get_collision_point() + Vector3.UP * 0.03
		smoke.look_at(smoke.global_position + car_body.global_basis.z)
		smoke.emitting = is_drift_skid
