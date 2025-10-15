extends CanvasLayer

@export var fade_duration: float = 1.0
@export var target_alpha: float = 0.75
@export var blur_rect: ColorRect
@export var vhs_rect: ColorRect

var is_faded_in: bool = false

func _ready() -> void:
	blur_rect.visible = true
	if blur_rect:
		blur_rect.alpha = 0.0
	if vhs_rect:
		vhs_rect.modulate.a = 0.0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug4"):
		if is_faded_in:
			fade_out()
		else:
			fade_in()
		is_faded_in = not is_faded_in

func fade_in() -> void:
	if blur_rect:
		blur_rect.fade_in()
	if vhs_rect:
		var tween := create_tween()
		tween.tween_property(vhs_rect, "modulate:a", target_alpha, fade_duration)

func fade_out() -> void:
	if blur_rect:
		blur_rect.fade_out()
	if vhs_rect:
		var tween := create_tween()
		tween.tween_property(vhs_rect, "modulate:a", 0.0, fade_duration)
