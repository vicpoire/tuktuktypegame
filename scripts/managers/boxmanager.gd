extends Node3D

@export var stacked_boxes: Array[Node3D] = []
@export var scale_up_time: float = 0.5
@export var scale_down_time: float = 0.5
@export var scale_up_curve: Curve
@export var scale_down_curve: Curve
@export var box_count_label: Label
@export var animation_delay: float = 0.2 

@export var ui_viewport_rects: Array[TextureRect] = []  
@export var ui_spawn_curve: Curve 
@export var ui_despawn_curve: Curve 
@export var ui_spawn_time: float = 0.5
@export var ui_despawn_time: float = 0.3 

var current_box_max := 3
var current_box_amount := 0
var animating_boxes: Array[BoxAnim] = []
var pending_animations: Array[PendingAnim] = []

class BoxAnim:
	var target: Node3D
	var from_scale: Vector3
	var to_scale: Vector3
	var time: float
	var duration: float
	var curve: Curve
	var scaling_up: bool
	var box: Node3D
	var mesh: Node3D

class PendingAnim:
	var box_index: int
	var delay_remaining: float
	var scaling_up: bool

func _ready():
	add_to_group("box_manager")
	setup_ui_viewports()  
	disable_all_boxes()

func _process(delta):
	# Debug controls
	if Input.is_action_just_pressed("debug1"):
		add_box()
	elif Input.is_action_just_pressed("debug2"):
		remove_box()

	for i in range(pending_animations.size() - 1, -1, -1):
		var pending = pending_animations[i]
		pending.delay_remaining -= delta
		
		if pending.delay_remaining <= 0.0:
			if pending.scaling_up:
				start_box_scale_up(pending.box_index)
			else:
				start_box_scale_down(pending.box_index)
			pending_animations.remove_at(i)

	for i in range(animating_boxes.size() - 1, -1, -1):
		var anim = animating_boxes[i]
		anim.time += delta
		var progress = anim.time / anim.duration
		if progress >= 1.0:
			progress = 1.0
			finish_animation(anim)
			animating_boxes.remove_at(i)
			continue
		
		var scale_value: float
		if anim.curve:
			scale_value = anim.curve.sample(progress)
		else:
			scale_value = sine_ease_out(progress) if anim.scaling_up else sine_ease_in(progress)
		
		var current_scale = anim.from_scale.lerp(anim.to_scale, scale_value)
		anim.target.scale = current_scale

	if box_count_label:
		box_count_label.text = str(current_box_amount)

func add_box():
	if stacked_boxes.is_empty():
		print("Warning: No stacked_boxes assigned")
		return
	
	if current_box_amount >= min(stacked_boxes.size(), current_box_max):
		return
	
	var box_index = current_box_amount
	current_box_amount += 1
	
	update_ui_viewports()
	
	var pending = PendingAnim.new()
	pending.box_index = box_index
	pending.delay_remaining = animation_delay * box_index
	pending.scaling_up = true
	
	pending_animations.append(pending)

func remove_box():
	if current_box_amount <= 0:
		return
	
	if stacked_boxes.is_empty():
		print("Warning: No stacked_boxes assigned")
		return
	
	current_box_amount -= 1
	var box_index = current_box_amount
	
	update_ui_viewports()
	
	var pending = PendingAnim.new()
	pending.box_index = box_index
	pending.delay_remaining = animation_delay * (min(stacked_boxes.size(), current_box_max) - box_index - 1)
	pending.scaling_up = false
	
	pending_animations.append(pending)

var ui_animating_rects: Array[bool] = []
var ui_active_tweens: Array[Tween] = [] 

func setup_ui_viewports():
	if ui_viewport_rects.is_empty():
		return
	
	ui_animating_rects.resize(ui_viewport_rects.size())
	ui_active_tweens.resize(ui_viewport_rects.size())
	
	for i in range(ui_viewport_rects.size()):
		if ui_viewport_rects[i]:
			ui_viewport_rects[i].scale = Vector2.ZERO
			ui_viewport_rects[i].visible = false
			ui_animating_rects[i] = false
			ui_active_tweens[i] = null

func update_ui_viewports():
	if ui_viewport_rects.is_empty():
		return
	
	for i in range(ui_viewport_rects.size()):
		if i < ui_viewport_rects.size() and ui_viewport_rects[i]:
			var should_be_visible = (i < current_box_amount)
			var is_currently_visible = ui_viewport_rects[i].visible and ui_viewport_rects[i].scale.x > 0.1
			
			if should_be_visible != is_currently_visible and not ui_animating_rects[i]:
				animate_ui_rect(i, should_be_visible)

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
		var time_elapsed = 0.0
		
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

func start_box_scale_up(box_index: int):
	var box = stacked_boxes[box_index]
	box.visible = true
	
	if box is RigidBody3D:
		box.sleeping = false
		box.set_linear_velocity(Vector3.ZERO)
		box.set_physics_process(true)
		box.set_process(true)
	
	set_child_colliders_enabled(box, true)
	emit_box_particles(box)
	
	# update_ui_with_animation(box_index, true)
	
	var target = get_mesh_instance(box)
	if not target:
		target = box
	
	target.scale = Vector3.ZERO
	
	var anim = BoxAnim.new()
	anim.target = target
	anim.from_scale = Vector3.ZERO
	anim.to_scale = Vector3.ONE
	anim.time = 0.0
	anim.duration = scale_up_time
	anim.curve = scale_up_curve
	anim.scaling_up = true
	anim.box = box
	anim.mesh = target if target != box else null
	
	animating_boxes.append(anim)

func start_box_scale_down(box_index: int):
	var box = stacked_boxes[box_index]
	
	# update_ui_with_animation(box_index, false)
	
	var target = get_mesh_instance(box)
	if not target:
		target = box
	
	var anim = BoxAnim.new()
	anim.target = target
	anim.from_scale = Vector3.ONE
	anim.to_scale = Vector3.ZERO
	anim.time = 0.0
	anim.duration = scale_down_time
	anim.curve = scale_down_curve
	anim.scaling_up = false
	anim.box = box
	anim.mesh = target if target != box else null
	
	animating_boxes.append(anim)

func finish_animation(anim: BoxAnim):
	if not anim.scaling_up:
		if anim.mesh:
			anim.mesh.scale = Vector3.ONE
		else:
			anim.box.scale = Vector3.ONE
		
		anim.box.visible = false
		
		if anim.box is RigidBody3D:
			anim.box.sleeping = true
			anim.box.set_linear_velocity(Vector3.ZERO)
			anim.box.set_physics_process(false)
			anim.box.set_process(false)

		set_child_colliders_enabled(anim.box, false)

func disable_all_boxes():
	current_box_amount = 0
	pending_animations.clear()
	animating_boxes.clear()
	
	for i in range(ui_viewport_rects.size()):
		if ui_viewport_rects[i] and ui_viewport_rects[i].visible:
			animate_ui_rect(i, false)
	
	for box in stacked_boxes:
		box.visible = false
		
		if box is RigidBody3D:
			box.sleeping = true
			box.set_physics_process(false)
			box.set_process(false)
		
		set_child_colliders_enabled(box, false)

func emit_box_particles(box: Node3D):
	for child in box.get_children():
		if child is GPUParticles3D or child is CPUParticles3D:
			child.restart()

func set_child_colliders_enabled(box: Node3D, enabled: bool) -> void:
	if box is CollisionShape3D:
		box.set_deferred("disabled", not enabled)
	elif box is CollisionObject3D:
		if enabled:
			box.set_deferred("collision_layer", 1)
			box.set_deferred("collision_mask", 1)
		else:
			box.set_deferred("collision_layer", 0)
			box.set_deferred("collision_mask", 0)
	
	for child in box.get_children():
		if child is Node3D:
			set_child_colliders_enabled(child, enabled)

func get_mesh_instance(box: Node3D) -> Node3D:
	for child in box.get_children():
		if child is MeshInstance3D:
			return child
	return null

func sine_ease_out(t: float) -> float:
	return sin(t * PI / 2.0)

func sine_ease_in(t: float) -> float:
	return 1.0 - cos(t * PI / 2.0)

func get_current_box_count() -> int:
	return current_box_amount

func get_max_box_count() -> int:
	return current_box_max

func is_full() -> bool:
	return current_box_amount >= min(stacked_boxes.size(), current_box_max)

func is_empty() -> bool:
	return current_box_amount <= 0
