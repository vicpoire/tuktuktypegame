extends Control

@export var panel_fade_in: Panel
@export var animated_sprite: AnimatedSprite2D
@export var default_animation: String = "timeout"
@export var fade_duration: float = 1.0
@export var wait_duration: float = 2.0
@export var car_anim_player: AnimationPlayer
@export var debrief_anim_player: AnimationPlayer


@export_group("uielems")
@export var texts_to_fade: Array[Label] = []
@export var panels_to_fade: Array[Node] = []
@export var progress_bar: ProgressBar
@export var label3d: Label3D

@export var fade_out_duration: float = 0.1

@export_category("debrief")
@export_group("enter_animation")
@export var time_before_debrief_anim := 1.25
@export var car_debrief_delay := 2.0
@export var debrief_letter_delay := 0.2
@export var debrief_letter_delay_2 := 0.1

@export var debrief_letters : Array[Label] = []

@export_group("text_animation")
@export var debrief_delivery_point : Label
@export var debrief_delivery_point_amount : Label
@export var debrief_delivery_point_amount_char : int

@export var debrief_style_point : Label
@export var debrief_style_point_amount : Label
@export var debrief_style_point_amount_char : int
@export var driver_type : Label

func _ready():
	animated_sprite.visible = false
	panel_fade_in.visible = false
	pass

func on_game_end():
	fade_out_ui()
	fade_panel()

func fade_out_ui():
	var fadetween = create_tween()
	fadetween.tween_property(progress_bar, "modulate:a", 0.0, fade_out_duration)
	fadetween.tween_property(label3d, "outline_modulate", Color(0,0,0,0), fade_out_duration)
	fadetween.tween_property(label3d, "modulate", Color(1,1,1,0), fade_out_duration)
	
	for i in texts_to_fade.size():
		fadetween.tween_property(texts_to_fade[i], "modulate:a", 0.0, fade_out_duration)
	for i in panels_to_fade.size():
		fadetween.tween_property(panels_to_fade[i], "modulate:a", 0.0, fade_out_duration)
		
	
	
func fade_panel():
	if panel_fade_in:
		panel_fade_in.visible = true
		panel_fade_in.modulate.a = 0.0
		
		var tween = create_tween()
		tween.tween_property(panel_fade_in, "modulate:a", 1.0, fade_duration)
		tween.tween_callback(wait_then_animate)

func wait_then_animate():
	var timer = get_tree().create_timer(wait_duration)
	timer.timeout.connect(play_animation)

func play_animation():
	if animated_sprite:
		animated_sprite.visible = true
		animated_sprite.play(default_animation)
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished():
	if animated_sprite:
		animated_sprite.stop()
		var frame_count = animated_sprite.sprite_frames.get_frame_count(default_animation)
		animated_sprite.frame = frame_count - 1
	await get_tree().create_timer(time_before_debrief_anim).timeout
	print("starting debrief animation")
	play_debrief_animation()
	

func play_debrief_animation():
	car_anim_player.play("car up")
	
	await car_anim_player.animation_finished
	await get_tree().create_timer(car_debrief_delay)
	
	debrief_anim_player.play("debrief")
	activate_debrief_letters()

func activate_debrief_letters():
	await get_tree().create_timer(0.6).timeout
	for letter in debrief_letters:
		letter.visible = !letter.visible
		await get_tree().create_timer(debrief_letter_delay).timeout
	activate_delivery_point_labels()

func activate_delivery_point_labels():
	debrief_delivery_point.visible = !debrief_delivery_point.visible
	await get_tree().create_timer(0.05).timeout
	
	debrief_delivery_point_amount.visible_characters = 0
	debrief_delivery_point_amount.visible = true
	
	for i in range(debrief_delivery_point_amount_char):
		debrief_delivery_point_amount.visible_characters = i + 1
		await get_tree().create_timer(debrief_letter_delay_2).timeout
	
	activate_style_point_labels()
	
func activate_style_point_labels():
	debrief_style_point.visible = !debrief_style_point.visible
	await get_tree().create_timer(0.5).timeout
	
	debrief_style_point_amount.visible_characters = 0
	debrief_style_point_amount.visible = true
	
	for i in range(debrief_style_point_amount_char):
		debrief_style_point_amount.visible_characters = i + 1
		await get_tree().create_timer(debrief_letter_delay_2).timeout
		
	await get_tree().create_timer(0.25).timeout
	activate_driver_type()

func activate_driver_type():
	driver_type.visible = !driver_type.visible
