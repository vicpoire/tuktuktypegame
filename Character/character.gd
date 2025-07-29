extends CharacterBody3D

const speed = 5.0
const jumpvelocity = 4.5


@export var sensitivity = 1000 

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jumpvelocity
		
	var inputdir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(inputdir.x, 0, inputdir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
	move_and_slide()
		

func _input(event):
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x / sensitivity
	
		$CamPivot.rotation.x -= event.relative.y / sensitivity
		$CamPivot.rotation.x  = clamp($CamPivot.rotation.x, deg_to_rad(-15), deg_to_rad(-15))
