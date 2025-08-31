extends Camera3D

# Target to follow
@export var target: Node3D

# Camera settings
@export var follow_distance: float = 10.0
@export var follow_height: float = 5.0
@export var rotation_speed: float = 1.0
@export var follow_speed: float = 5.0
@export var auto_rotate: bool = true

# Mouse control
@export var mouse_sensitivity: float = 0.002
@export var enable_mouse_control: bool = true

# Internal variables
var rotation_angle: float = 0.0
var mouse_delta: Vector2 = Vector2.ZERO
var vertical_angle: float = 0.0

func _ready():
	if target == null:
		print("Warning: No target assigned to camera follower")

func _input(event):
	if enable_mouse_control and event is InputEventMouseMotion:
		if Input.is_action_pressed("camera_rotate"):  # Right mouse button
			mouse_delta = event.relative

func _process(delta):
	if target == null:
		return
	
	# Handle mouse rotation
	if enable_mouse_control and mouse_delta.length() > 0:
		rotation_angle -= mouse_delta.x * mouse_sensitivity
		vertical_angle = clamp(vertical_angle - mouse_delta.y * mouse_sensitivity, -PI/3, PI/3)
		mouse_delta = Vector2.ZERO
	
	# Auto rotation
	if auto_rotate:
		rotation_angle += rotation_speed * delta
	
	# Calculate target position
	var target_pos = target.global_position
	
	# Calculate camera orbit position
	var offset = Vector3.ZERO
	offset.x = cos(rotation_angle) * follow_distance
	offset.z = sin(rotation_angle) * follow_distance
	offset.y = follow_height + sin(vertical_angle) * follow_distance * 0.5
	
	var desired_position = target_pos + offset
	
	# Smooth camera movement
	global_position = global_position.lerp(desired_position, follow_speed * delta)
	
	# Look at target
	look_at(target_pos, Vector3.UP)

# Public methods to control camera
func set_target(new_target: Node3D):
	target = new_target

func set_rotation_speed(speed: float):
	rotation_speed = speed

func set_follow_distance(distance: float):
	follow_distance = distance

func set_follow_height(height: float):
	follow_height = height

func toggle_auto_rotate():
	auto_rotate = !auto_rotate

func reset_rotation():
	rotation_angle = 0.0
	vertical_angle = 0.0
