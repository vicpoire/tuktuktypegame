extends Node3D
@export_range(1, 10, 0.1) var smooth_speed: float = 2.5
@export var camera: Node3D
@export var camera_views: Array[Node3D]  # [0] = default, [1] = top-down
@export var lookback_view: Node3D
@export_range(1.0, 10.0) var camera_lerp_speed := 5.0
@export_range(0.1, 5.0) var lookback_lerp_speed := 2.0
var using_topdown_view := false
var direction: Vector3
var current_camera_target: Node3D
var lookback_target_basis: Basis

func _ready():
	direction = -global_transform.basis.z.normalized()
	current_camera_target = camera_views[0]
	camera.global_transform = current_camera_target.global_transform

func _physics_process(delta):
	handle_direction_rotation(delta)
	handle_camera_lerp(delta)

func handle_direction_rotation(delta):
	var lookback := Input.is_action_pressed("lookback")
	var changeview := Input.is_action_pressed("changeview")
	var velocity = get_parent().get_linear_velocity()
	velocity.y = 0
	
	if lookback:
		var backward = direction.rotated(Vector3.UP, PI).normalized()
		direction = lerp(direction, backward, smooth_speed * delta)
	else:
		if velocity.length_squared() > 1:
			var move_dir = -velocity.normalized()
			var angle = direction.angle_to(move_dir)
			if angle < deg_to_rad(180):
				direction = lerp(direction, move_dir, smooth_speed * delta)
	
	global_transform.basis = get_rotation_from_direction(-direction)

func _input(event):
	if event.is_action_pressed("changeview"):
		using_topdown_view = !using_topdown_view
		current_camera_target = camera_views[1] if using_topdown_view else camera_views[0]

func handle_camera_lerp(delta):
	var lookback := Input.is_action_pressed("lookback")
	var target_transform: Transform3D
	
	if lookback and lookback_view:
		var current_forward = -global_transform.basis.z.normalized()
		var desired_backward_dir = -current_forward
		var desired_backward_basis = get_rotation_from_direction(desired_backward_dir)
		
		if lookback_target_basis == Basis():
			lookback_target_basis = desired_backward_basis
		else:
			lookback_target_basis = lookback_target_basis.slerp(desired_backward_basis, lookback_lerp_speed * delta)
		
		target_transform.origin = lookback_view.global_transform.origin
		target_transform.basis = lookback_target_basis
	else:
		lookback_target_basis = Basis()
		target_transform = current_camera_target.global_transform
	
	if camera:
		camera.global_transform.origin = camera.global_transform.origin.lerp(target_transform.origin, camera_lerp_speed * delta)
		camera.global_transform.basis = camera.global_transform.basis.slerp(target_transform.basis, camera_lerp_speed * delta)

func get_rotation_from_direction(look_direction: Vector3) -> Basis:
	look_direction = look_direction.normalized()
	var x_axis = look_direction.cross(Vector3.UP)
	return Basis(x_axis, Vector3.UP, -look_direction)
