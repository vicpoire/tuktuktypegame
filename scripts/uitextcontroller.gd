extends Control

@export var speed_text: Label

@export_group("screenshake")
@export var shake_enabled := true
@export var collision_shake_amplitude := 8.0
@export var wheel_shake_amplitude := 1.0
@export var shake_duration := 0.2
@export var shake_decay := 12.0
@export var collision_threshold := 3.0

@export_group("directional movement")
@export var movement_enabled := true
@export var acceleration_amplitude := 3.0
@export var turning_amplitude := 1.0
@export var movement_smoothing := 8.0
@export var acceleration_sensitivity := 0.1

@export_group("wheel effects")
@export var wheel_effects_enabled := true
@export var wheel_vibration_amplitude := 0.8
@export var speed_threshold := 2.0
@export var air_time_reduction := 0.3

var car: Node = null
var original_position: Vector2
var shake_timer := 0.0
var shake_offset := Vector2.ZERO
var movement_offset := Vector2.ZERO
var wheel_vibration := Vector2.ZERO

var last_velocity := Vector3.ZERO
var velocity_history: Array[Vector3] = []
var grounded_wheels := 0

func _ready():
	car = get_node("../Car")
	original_position = position
	
	velocity_history.resize(5)
	velocity_history.fill(Vector3.ZERO)

func _process(delta):
	update_speed_text()
	
	if car:
		update_tracking_data(delta)
		handle_collision_detection(delta)
		handle_directional_movement(delta)
		handle_wheel_effects(delta)
		handle_screen_shake(delta)
	
	var time = Engine.get_process_frames() * 0.016
	var organic_shake = Vector2(
		sin(time * 15.0) * 0.1,
		cos(time * 12.0) * 0.08
	) * wheel_vibration.length() * 0.3
	
	position = original_position + shake_offset + movement_offset + wheel_vibration + organic_shake

func update_speed_text():
	if car and speed_text:
		var speed: float = car.get_current_speed()
		speed_text.text = "Speed: %d km/h" % round(speed * 3.6)

func update_tracking_data(delta: float):
	var current_velocity = car.linear_velocity
	
	velocity_history.push_back(current_velocity)
	if velocity_history.size() > 5:
		velocity_history.pop_front()
	
	grounded_wheels = 0
	var wheels = car.get_wheels()
	for wheel in wheels:
		if wheel.is_colliding():
			grounded_wheels += 1
	
	last_velocity = current_velocity

func handle_collision_detection(delta: float):
	if velocity_history.size() < 3:
		return
	
	var recent_velocity = velocity_history[-1]
	var old_velocity = velocity_history[-3]
	
	var velocity_change = (recent_velocity - old_velocity).length() / 2.0
	var angular_change = (car.angular_velocity - car.angular_velocity).length()
	
	# collision impacts
	if velocity_change > collision_threshold:
		var intensity = min(velocity_change / (collision_threshold * 2.0), 1.5)
		trigger_collision_shake(intensity)

func handle_directional_movement(delta: float):
	if not movement_enabled:
		return
	
	var current_velocity = car.linear_velocity
	var acceleration = Vector3.ZERO
	
	if velocity_history.size() >= 2:
		acceleration = (velocity_history[-1] - velocity_history[-2]) / delta
	
	var linear_effect = Vector2(
		-acceleration.x * acceleration_amplitude * acceleration_sensitivity,
		acceleration.z * acceleration_amplitude * acceleration_sensitivity
	)
	
	var angular_velocity_y = car.angular_velocity.y
	var turn_effect = Vector2(
		angular_velocity_y * turning_amplitude * 0.2,  
		-abs(angular_velocity_y) * turning_amplitude * 0.1 
	)
	
	var ground_factor = float(grounded_wheels) / max(1.0, car.get_wheels().size())
	ground_factor = lerp(air_time_reduction, 1.0, ground_factor)
	
	var target_movement = (linear_effect + turn_effect) * ground_factor
	
	var speed_factor = clamp(car.get_current_speed() / 20.0, 0.3, 1.0)
	var dynamic_smoothing = movement_smoothing * speed_factor
	
	movement_offset = movement_offset.lerp(target_movement, dynamic_smoothing * delta)

func handle_wheel_effects(delta: float):
	if not wheel_effects_enabled:
		wheel_vibration = wheel_vibration.lerp(Vector2.ZERO, 10.0 * delta)
		return
	
	var current_speed = car.get_current_speed()
	
	# exit if below speed threshold
	if current_speed < speed_threshold:
		wheel_vibration = wheel_vibration.lerp(Vector2.ZERO, 15.0 * delta)
		return
	
	# speed-based vibration
	var speed_factor = clamp(current_speed / 25.0, 0.0, 1.0)
	var base_intensity = speed_factor * 0.3
	
	# only vibrate when wheels are on ground
	var ground_factor = float(grounded_wheels) / max(1.0, car.get_wheels().size())
	var final_intensity = base_intensity * ground_factor * wheel_vibration_amplitude
	
	var time = Engine.get_process_frames() * 0.016
	var frequency = 20.0 + (current_speed * 0.3)
	var target_vibration = Vector2(
		sin(time * frequency) * final_intensity,
		cos(time * frequency * 0.8) * final_intensity * 0.6
	)
	
	wheel_vibration = wheel_vibration.lerp(target_vibration, 12.0 * delta)

func handle_screen_shake(delta: float):
	if not shake_enabled:
		return
	
	var current_speed = car.get_current_speed()
	
	# Collision shake
	if shake_timer > 0.0:
		shake_timer -= delta
		var shake_power = (shake_timer / shake_duration) * (shake_timer / shake_duration)
		
		var time = Engine.get_process_frames() * 0.016
		shake_offset = Vector2(
			sin(time * 45.0) * collision_shake_amplitude * shake_power,
			cos(time * 50.0) * collision_shake_amplitude * shake_power * 0.7
		)
	else:
		shake_offset = shake_offset.lerp(Vector2.ZERO, shake_decay * delta)
	
	if current_speed > speed_threshold:
		var wheel_shake_intensity = clamp(current_speed / 30.0, 0.0, 1.0) * 0.3
		var ground_factor = float(grounded_wheels) / max(1.0, car.get_wheels().size())
		wheel_shake_intensity *= ground_factor
		
		if wheel_shake_intensity > 0.05:
			var time = Engine.get_process_frames() * 0.016
			var frequency = 25.0
			var wheel_shake = Vector2(
				sin(time * frequency) * wheel_shake_amplitude * wheel_shake_intensity,
				cos(time * frequency * 0.9) * wheel_shake_amplitude * wheel_shake_intensity * 0.5
			)
			shake_offset += wheel_shake

func trigger_collision_shake(intensity: float = 1.0):
	if not shake_enabled:
		return
	
	var scaled_intensity = pow(intensity, 0.7) * 0.8
	shake_timer = shake_duration * scaled_intensity
	
	shake_offset += Vector2(
		randf_range(-collision_shake_amplitude, collision_shake_amplitude) * scaled_intensity,
		randf_range(-collision_shake_amplitude * 0.7, collision_shake_amplitude * 0.7) * scaled_intensity
	)

# Public control methods
func set_turning_intensity(intensity: float):
	turning_amplitude = intensity

func set_shake_intensity(collision_intensity: float, wheel_intensity: float):
	collision_shake_amplitude = collision_intensity
	wheel_shake_amplitude = wheel_intensity

func set_movement_intensity(accel_intensity: float, turn_intensity: float):
	acceleration_amplitude = accel_intensity
	turning_amplitude = turn_intensity

func set_wheel_effects_intensity(vibration: float):
	wheel_vibration_amplitude = vibration
