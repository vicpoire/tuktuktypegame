extends RayCast3D
class_name RaycastWheel

@export var spring_strength := 100.0
@export var spring_damping := 2.0
@export var rest_dist := 0.5
@export var over_extend := 0.4
@export var wheel_radius := 0.4
@export var is_motor := false 
@export var grip_curve : Curve 


@onready var wheel: Node3D = get_child(0)
