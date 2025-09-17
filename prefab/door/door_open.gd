extends Area3D

@export var door_collider: CollisionShape3D
@export var door_animation_player: AnimationPlayer
@export var glb_door_node: Node3D
@export var door_animation_name: String = "door_open"
@export var animation_speed: float = 1.0
@export var exit_delay: float = 2.0

var car_in_area: bool = false
var exit_timer: Timer

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	exit_timer = Timer.new()
	exit_timer.wait_time = exit_delay
	exit_timer.one_shot = true
	exit_timer.timeout.connect(_on_exit_timer_timeout)
	add_child(exit_timer)
	
	if not door_animation_player:
		if glb_door_node:
			door_animation_player = glb_door_node.find_child("AnimationPlayer", true, false)
		
		if not door_animation_player:
			var scene_root = get_tree().current_scene
			door_animation_player = scene_root.find_child("AnimationPlayer", true, false)
		
		if not door_animation_player:
			door_animation_player = find_child("AnimationPlayer", true, false)

	if not door_collider:
		if glb_door_node:
			door_collider = glb_door_node.find_child("CollisionShape3D", true, false)
		
		if not door_collider:
			var scene_root = get_tree().current_scene
			door_collider = scene_root.find_child("CollisionShape3D", true, false)

func _on_body_entered(body: Node3D):
	if body.name == "Car" and body is RigidBody3D:
		car_in_area = true
		exit_timer.stop()
		open_door()

func _on_body_exited(body: Node3D):
	if body.name == "Car" and body is RigidBody3D:
		car_in_area = false
		exit_timer.start()

func _on_exit_timer_timeout():
	if not car_in_area:
		close_door()

func open_door():
	if door_collider:
		door_collider.disabled = true
		var parent = door_collider.get_parent()
		if parent is StaticBody3D or parent is RigidBody3D:
			parent.set_meta("original_collision_layer", parent.collision_layer)
			parent.set_meta("original_collision_mask", parent.collision_mask)
			parent.collision_layer = 0
			parent.collision_mask = 0
	
	if door_animation_player and door_animation_player.has_animation(door_animation_name):
		door_animation_player.speed_scale = animation_speed
		door_animation_player.play(door_animation_name)

func close_door():
	if door_collider:
		door_collider.disabled = false
		var parent = door_collider.get_parent()
		if parent is StaticBody3D or parent is RigidBody3D and parent.has_meta("original_collision_layer"):
			parent.collision_layer = parent.get_meta("original_collision_layer")
			parent.collision_mask = parent.get_meta("original_collision_mask")
	
	if door_animation_player and door_animation_player.has_animation(door_animation_name):
		door_animation_player.speed_scale = animation_speed
		door_animation_player.play_backwards(door_animation_name)

func close_door_with_separate_animation():
	var close_animation_name = "door_close"
	
	if door_collider:
		door_collider.disabled = false
	
	if door_animation_player and door_animation_player.has_animation(close_animation_name):
		door_animation_player.speed_scale = animation_speed
		door_animation_player.play(close_animation_name)
