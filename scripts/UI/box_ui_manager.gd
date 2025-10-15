extends Node

@export var box_count_label: Label
@export var ui_viewport_rects: Array[TextureRect] = []  
@export var ui_spawn_curve: Curve 
@export var ui_despawn_curve: Curve 
@export var ui_spawn_time: float = 0.5
@export var ui_despawn_time: float = 0.3 
@export var delivery_manager: Node
var ui_animating_rects: Array[bool] = []
var ui_active_tweens: Array[Tween] = [] 

var box_manager: Node3D
var box_amount: int

func _ready():
	ui_animating_rects.resize(ui_viewport_rects.size())
	ui_active_tweens.resize(ui_viewport_rects.size())

	for i in range(ui_viewport_rects.size()):
		ui_animating_rects[i] = false
		ui_active_tweens[i] = null

	update_ui_viewports(box_amount)


func _process(_delta):
	box_amount = delivery_manager.current_box_amount
	if box_count_label and box_manager:
		box_count_label.text = str(box_manager.get_current_box_count())
	update_ui_viewports(box_amount)
	



func update_ui_viewports(current_box_amount: int):
	if ui_viewport_rects.is_empty():
		return
	
	for i in range(ui_viewport_rects.size()):
		if i < ui_viewport_rects.size() and ui_viewport_rects[i]:
			var should_be_visible = (i < current_box_amount)
			var is_currently_visible = ui_viewport_rects[i].visible and ui_viewport_rects[i].scale.x > 0.1
			
			if should_be_visible != is_currently_visible and not ui_animating_rects[i]:
				animate_ui_rect(i, should_be_visible)

func disable_all_ui_viewports():
	for i in range(ui_viewport_rects.size()):
		if ui_viewport_rects[i] and ui_viewport_rects[i].visible:
			animate_ui_rect(i, false)

func animate_ui_rect(rect_index: int, show: bool):
	if rect_index >= ui_viewport_rects.size() or not ui_viewport_rects[rect_index]:
		return
	
	var texture_rect = ui_viewport_rects[rect_index]
	
	if ui_active_tweens[rect_index]:
		ui_active_tweens[rect_index].kill()
		ui_active_tweens[rect_index] = null
	
	ui_animating_rects[rect_index] = true
	
	if show:
		texture_rect.visible = true
		texture_rect.scale = Vector2.ZERO
		texture_rect.modulate = Color.WHITE
		
		var duration = ui_spawn_time
		animate_ui_with_curve(rect_index, Vector2.ZERO, Vector2.ONE, duration, ui_spawn_curve, true)
	else:
		var duration = ui_despawn_time
		animate_ui_with_curve(rect_index, texture_rect.scale, Vector2.ZERO, duration, ui_despawn_curve, false)

func animate_ui_with_curve(rect_index: int, from_scale: Vector2, to_scale: Vector2, duration: float, curve: Curve, is_spawning: bool):
	if rect_index >= ui_viewport_rects.size() or not ui_viewport_rects[rect_index]:
		return
	
	var texture_rect = ui_viewport_rects[rect_index]
	texture_rect.scale = from_scale
	
	var tween = create_tween()
	ui_active_tweens[rect_index] = tween
	
	if curve:
		# Manual curve interpolation
		tween.tween_method(
			func(progress: float):
				var curve_value = curve.sample(progress)
				texture_rect.scale = from_scale.lerp(to_scale, curve_value),
			0.0, 1.0, duration
		)
	else:
		if is_spawning:
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BACK)
		else:
			tween.set_ease(Tween.EASE_IN)
			tween.set_trans(Tween.TRANS_CUBIC)
		
		tween.tween_property(texture_rect, "scale", to_scale, duration)
	
	# Handle completion
	tween.tween_callback(func():
		ui_animating_rects[rect_index] = false
		ui_active_tweens[rect_index] = null
		
		if not is_spawning:
			texture_rect.visible = false
			texture_rect.scale = Vector2.ONE 
	)

func animate_ui_rect_with_delay(rect_index: int, show: bool, delay: float = 0.0):
	if rect_index >= ui_viewport_rects.size() or not ui_viewport_rects[rect_index]:
		return
	
	var texture_rect = ui_viewport_rects[rect_index]
	
	if ui_active_tweens[rect_index]:
		ui_active_tweens[rect_index].kill()
		ui_active_tweens[rect_index] = null
	
	ui_animating_rects[rect_index] = true
	
	var tween = create_tween()
	ui_active_tweens[rect_index] = tween
	
	if delay > 0.0:
		tween.tween_interval(delay)
	
	if show:
		texture_rect.visible = true
		texture_rect.scale = Vector2.ZERO
		texture_rect.modulate = Color.WHITE
		
		var duration = ui_spawn_time
		
		if ui_spawn_curve:
			tween.parallel().tween_method(
				func(progress: float):
					var curve_value = ui_spawn_curve.sample(progress)
					texture_rect.scale = Vector2.ZERO.lerp(Vector2.ONE, curve_value)
					texture_rect.rotation = deg_to_rad(360 * curve_value * 0.1),
				0.0, 1.0, duration
			)
		else:
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_ELASTIC)
			tween.parallel().tween_property(texture_rect, "scale", Vector2.ONE, duration)
		
		tween.tween_callback(func(): 
			texture_rect.rotation = 0.0
			ui_animating_rects[rect_index] = false
			ui_active_tweens[rect_index] = null
		)
	else:
		var duration = ui_despawn_time
		
		if ui_despawn_curve:
			var start_scale = texture_rect.scale
			tween.parallel().tween_method(
				func(progress: float):
					var curve_value = ui_despawn_curve.sample(progress)
					texture_rect.scale = start_scale.lerp(Vector2.ZERO, curve_value)
					texture_rect.modulate.a = 1.0 - curve_value,
				0.0, 1.0, duration
			)
		else:
			tween.set_ease(Tween.EASE_IN)
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.parallel().tween_property(texture_rect, "scale", Vector2.ZERO, duration)
			tween.parallel().tween_property(texture_rect, "modulate:a", 0.0, duration)
		
		tween.tween_callback(func():
			texture_rect.visible = false
			texture_rect.modulate.a = 1.0
			texture_rect.scale = Vector2.ONE
			ui_animating_rects[rect_index] = false
			ui_active_tweens[rect_index] = null
		)
