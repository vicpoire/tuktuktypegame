extends Control

@export var enable_anim: bool = true
@export var main_ui: Node
@export var car: Node
@export var time_mode: Node

@export var time_label: Label
@export var anim_player: AnimationPlayer
@export var anim_player_cam: AnimationPlayer


var time_left: float
var original_accel: float 

func _ready():
	time_left = time_mode.time_before_starting
	original_accel = car.acceleration
	if enable_anim:
		start_countdown()
		update_label()
		toggle_main_ui(false)
		disable_car()

func start_countdown() -> void:
	while time_left > 0:
		await get_tree().create_timer(1).timeout
		time_left -= 1
		update_label()

func toggle_main_ui(visible: bool) -> void:
	main_ui.visible = visible

func disable_car():
	car.acceleration = 0

func enable_car():
	car.acceleration = original_accel
	
func update_label() -> void:
	match time_left:
		6.0:
			anim_player_cam.play("camanimation1")
			await get_tree().create_timer(0.15).timeout

			time_label.text = "ready?"
			anim_player.play("countdown_label_animation")
		5.0:
			anim_player.play("fade_out")
			
		4.0:
			time_label.text = "3"
			anim_player.play("countdown_label_animation")
			anim_player_cam.play("camanimation2")
			
		3.0:
			time_label.text = "2"
			anim_player.play("countdown_label_animation")
			anim_player_cam.play("camanimation3")
			
		2.0:
			time_label.text = "1"
			anim_player.play("countdown_label_animation")
			anim_player_cam.play("camanimation4")
			
		1.0:
			time_label.text = "go!"
			anim_player.play("countdown_label_animation")
			
		0.0:
			anim_player.play("fade_out")
			toggle_main_ui(true)
			enable_car()
