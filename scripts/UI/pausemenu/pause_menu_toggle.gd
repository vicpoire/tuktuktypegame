extends Control

@export_group("animation")
@export var pause_animation_player: AnimationPlayer

@export_group("time")
@export var slow_speed := 1.5

var target_time_scale := 1.0
var time_scale := 1.0
var could_pause := true
var currently_paused := false
var is_transitioning := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	pass



func _unhandled_input(event):
	if event.is_action_pressed("pausegame"):
		pausetime()

func pausetime():
	if not could_pause or is_transitioning:
		return

	is_transitioning = true

	if not currently_paused:
		$ColorRect.visible = true
		pause_animation_player.play("pause_ui_anim")
		currently_paused = true
		target_time_scale = 0.0
	else:
		pause_animation_player.play_backwards("pause_ui_anim")
		currently_paused = false
		target_time_scale = 1.0
		$ColorRect.visible = false

	is_transitioning = false


func _process(delta):
	time_scale = move_toward(time_scale, target_time_scale, delta * slow_speed)
	Engine.time_scale = time_scale

	if currently_paused and Engine.time_scale <= 0.01:
		Engine.time_scale = 0.0
		get_tree().paused = true
	elif not currently_paused and get_tree().paused:
		get_tree().paused = false
