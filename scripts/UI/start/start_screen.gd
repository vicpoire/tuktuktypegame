extends Control

@export var enable_anim: bool = true
@export var main_ui: Node
@export var car: Node
@export var time_mode: Node
@export var start_cinematic: Node
@export var drunken_filter: Node

@export var time_label: Label
@export var anim_player: AnimationPlayer
@export var anim_player_cam: AnimationPlayer
@export var anim_player_game_cam: AnimationPlayer

@export var sky_profile_manager: Node

@export_group("cams")
@export var game_cam: Camera3D
@export var cinematic_cam: Camera3D

var time_left: float
var original_accel: float 
var cinematicpos_update: bool

func _ready():
	time_left = time_mode.time_before_starting
	original_accel = car.acceleration
	start_animation()
	
	if !time_mode.play_intro:
		game_cam.current
		anim_player_game_cam.play("up_game_cam")
	
func _process(delta):
	if cinematicpos_update:
		start_cinematic.transform = car.transform
	
func start_animation():
	if time_mode.play_intro:
		update_cinematic_position()
		start_countdown()
		update_cinematic()
		toggle_main_ui(false)
		disable_car()

func update_cinematic_position():
	cinematicpos_update = true
func start_countdown() -> void:
	while time_left > 0:
		await get_tree().create_timer(1).timeout
		time_left -= 1
		update_cinematic()

func toggle_main_ui(visible: bool) -> void:
	main_ui.visible = visible

func disable_car():
	car.acceleration = 0

func enable_car():
	car.acceleration = original_accel
	
func change_sky():
	sky_profile_manager.start_transition_to_next_profile()

func game_cam_animation():
	await get_tree().create_timer(0).timeout
	anim_player_game_cam.play("up_game_cam")

func update_cinematic() -> void:
	match time_left:
		7.0:
			anim_player_cam.play("camanimation1")
			game_cam.current = false
			cinematic_cam.current = true
			
		6.0:
			drunken_filter.fade_in()
			await get_tree().create_timer(0.25).timeout

			anim_player.play("countdown_label_animation")
			time_label.text = "ready?"

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
			change_sky()
			
		2.0:
			time_label.text = "1"
			anim_player.play("countdown_label_animation")
			anim_player_cam.play("camanimation4")
			
		1.0:
			time_label.text = "go!"
			anim_player.play("countdown_label_animation")
			game_cam.current = true
			game_cam_animation()
			enable_car()
			
		0.0:
			anim_player.play("fade_out")
			toggle_main_ui(true)
			cinematic_cam.current = false
			drunken_filter.fade_out()
