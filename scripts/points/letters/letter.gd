extends Node3D

signal picked_up

@export var is_on: bool = true
@export var letter_visuals: Array[Node]
@export var letter: String
@export var letter_anim_player: AnimationPlayer

var camera: Camera3D
var animation: AnimationPlayer
var random = RandomNumberGenerator.new()

func _ready():
	add_to_group("letters")
	animation = $LetterArea/AnimationPlayer
	play_animation()
	
	if not letter_anim_player:
		letter_anim_player = get_node("LetterArea/AnimationPlayer")
		
	var car = get_tree().get_first_node_in_group("car")
	if not car:
		car = get_node_or_null("/root/Main/Car")
	if car:
		camera = find_camera_in_node(car)

func play_animation():
	var t = random.randf_range(0, 2)
	await get_tree().create_timer(t).timeout
	animation.play("up_down_letter")

func find_camera_in_node(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var result = find_camera_in_node(child)
		if result:
			return result
	return null

func _process(delta):
	if camera and is_on:
		rotate_toward_camera(delta)

func rotate_toward_camera(delta):
	var target_pos = camera.global_transform.origin
	var current_pos = global_transform.origin
	var direction = Vector3(target_pos.x - current_pos.x, 0, target_pos.z - current_pos.z)
	
	if direction.length() > 0.001:
		direction = direction.normalized()
		var target_angle = atan2(-direction.x, -direction.z) + PI
		var current_rotation = global_rotation.y
		var new_rotation = lerp_angle(current_rotation, target_angle, 5.0 * delta)
		global_rotation.y = new_rotation

func toggle_letter():
	#for visual in letter_visuals:
		#visual.visible = is_on
	letter_anim_player.play("letter_picked_up")

func _on_letter_area_body_entered(body):
	if body.name == "Car" and is_on:
		is_on = false
		toggle_letter()
		picked_up.emit() 
		print("letter " + letter + " picked up")
