extends RigidBody3D

@export var wheels: Array[RayCast3D]
@export var spring_strength := 100.0
@export var spring_damping := 2.0
@export var rest_dist := 0.5
@export var wheel_radius := 0.4


func _physics_process(_delta):
	for wheel in wheels:
		_do_single_wheel_suspension(wheel)
		

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)

func _do_single_wheel_suspension(suspension_ray: RayCast3D) -> void:
	if suspension_ray.is_colliding():
		suspension_ray.target_position.y = -(rest_dist + wheel_radius + 0.2)
		var contact := suspension_ray.get_collision_point()
		var spring_up_dir:= suspension_ray.global_transform.basis.y
		var spring_len := suspension_ray.global_position.distance_to(contact) - wheel_radius
		var offset := rest_dist - spring_len
		
		suspension_ray.get_node("Wheel").position.y = -spring_len
		
		var spring_force := spring_strength * offset
		
		var world_velocity := _get_point_velocity(contact)
		var relative_velocity := spring_up_dir.dot(world_velocity)
		var spring_damp_force := spring_damping * relative_velocity
		
		
		var force_vector := (spring_force - spring_damp_force) * spring_up_dir
		
		var force_pos_offset := contact - global_position
		apply_force(force_vector, force_pos_offset)
