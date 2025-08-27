extends Node
class_name ComboUIManager

@export var combo_progress_bar: ProgressBar
@export var combo_level_label: Label
@export var combo_points_label: Label  # New label for displaying last point and amount
@export var combo_panel: Panel
@export var combo_container: Control  # Optional: container to show/hide entire combo UI
@export var combo_manager: ComboManager

# Public combo state
var current_combo: int = 0
var combo_progress: float = 0.0
var is_combo_active: bool = false
var last_point_type: String = ""  # Store last point type (e.g., "Headshot", "Kill", etc.)
var last_point_amount: int = 0     # Store last point amount

@export_group("Panel Fade")
@export var panel_fade_in_duration: float = 0.3
@export var panel_fade_out_duration: float = 0.3
@export var panel_fade_in_curve: Curve
@export var panel_fade_out_curve: Curve

@export_group("Colors")
@export var progress_color_full: Color = Color.GREEN
@export var progress_color_half: Color = Color.YELLOW
@export var progress_color_low: Color = Color.RED

@export_group("Combo Break Colors")
@export var combo_break_start_color: Color = Color.RED
@export var combo_break_end_color: Color = Color.TRANSPARENT
@export var combo_break_duration: float = 0.5

@export_group("Color Transition")
@export var use_curve_for_colors: bool = false
@export var color_transition_curve: Curve

@export_group("Points Animation")
@export var points_bump_duration: float = 0.3
@export var points_bump_scale: float = 0.3 
@export var points_bump_rotation: float = 3.0 
@export var points_bump_color: Color = Color.YELLOW
@export var points_bump_curve: Curve 

@export_group("Animation Curves")
@export var enable_curve_animations: bool = true
@export var combo_pulse_rotation_curve: Curve
@export var combo_pulse_scale_curve: Curve
@export var combo_break_rotation_curve: Curve
@export var combo_pulse_duration: float = 0.2
@export var combo_pulse_max_rotation: float = 5.0
@export var combo_pulse_max_scale: float = 0.2
@export var combo_break_max_rotation: float = 3.0

var tween: Tween

# Store original transforms for reset
var original_label_rotation: float = 0.0
var original_label_scale: Vector2 = Vector2.ONE
var original_progress_rotation: float = 0.0
var original_points_rotation: float = 0.0  # Store original points label rotation
var original_points_scale: Vector2 = Vector2.ONE  # Store original points label scale

# Animation state to prevent UI hiding during animations
var is_break_animating: bool = false
var is_panel_fade_animating: bool = false

func _ready():
	# Store original transforms
	if combo_level_label:
		original_label_rotation = combo_level_label.rotation
		original_label_scale = combo_level_label.scale
	if combo_progress_bar:
		original_progress_rotation = combo_progress_bar.rotation
	if combo_points_label:
		original_points_rotation = combo_points_label.rotation
		original_points_scale = combo_points_label.scale
	
	# Use exported reference first, then fallback to finding it
	if not combo_manager:
		combo_manager = _find_combo_manager()
	
	if combo_manager:
		print("ComboManager at: ", combo_manager.get_path())
		# Connect to combo manager signals
		combo_manager.combo_achieved.connect(_on_combo_achieved)
		combo_manager.combo_broken.connect(_on_combo_broken)
		# Connect to point scored signal if it exists
		if combo_manager.has_signal("point_scored"):
			combo_manager.point_scored.connect(_on_point_scored)

	_initialize_ui()
	
	add_to_group("combo_ui_manager")

func _find_combo_manager() -> ComboManager:
	# Try different possible paths
	var possible_paths = [
		"../ComboManager",
		"../../ComboManager",
		"/root/ComboManager",
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node and node is ComboManager:
			return node
	
	# Try searching in groups
	var combo_nodes = get_tree().get_nodes_in_group("combo_manager")
	if combo_nodes.size() > 0:
		return combo_nodes[0] as ComboManager
	
	return null

func _initialize_ui():
	# Initialize individual elements (these stay visible within the panel)
	if combo_progress_bar:
		combo_progress_bar.min_value = 0.0
		combo_progress_bar.max_value = 1.0
		combo_progress_bar.value = 0.0
		combo_progress_bar.visible = true
		combo_progress_bar.modulate = Color.WHITE
	
	if combo_level_label:
		combo_level_label.text = ""
		combo_level_label.visible = true
		combo_level_label.modulate = Color.WHITE
	
	if combo_points_label:
		combo_points_label.text = ""
		combo_points_label.visible = true
		combo_points_label.modulate = Color.WHITE
	
	# Initialize panel as hidden
	if combo_panel:
		combo_panel.visible = false
		combo_panel.modulate = Color.TRANSPARENT
	
	if combo_container:
		combo_container.visible = true
		combo_container.modulate = Color.WHITE

func _process(_delta):
	"""Update UI every frame and public combo state"""
	if not combo_manager:
		return
		
	current_combo = combo_manager.get_current_combo()
	var time_left = combo_manager.get_time_until_combo_break()
	var total_timeout = combo_manager.combo_timeout
	combo_progress = time_left / total_timeout if total_timeout > 0 else 0.0
	is_combo_active = current_combo >= 1
	
	_update_combo_ui()

func _update_combo_ui():
	if current_combo >= 1:
		# Combo UI should be open - fade in panel if not visible
		if combo_panel and not combo_panel.visible and not is_panel_fade_animating:
			_fade_in_panel()
		
		# Update progress bar and label content (always update when combo is active)
		if combo_progress_bar:
			combo_progress_bar.value = combo_progress
			_update_progress_bar_color(combo_progress)
		
		if combo_level_label:
			if current_combo >= combo_manager.min_combo_threshold:
				combo_level_label.text = "COMBO x%d" % current_combo
			else:
				combo_level_label.text = "x%d" % current_combo
		
		# Update points label if we have point data
		if combo_points_label and last_point_type != "" and last_point_amount > 0:
			combo_points_label.text = "%s +%d" % [last_point_type, last_point_amount]
	else:
		# Combo UI should be closed - fade out panel if visible and clear points label
		if combo_points_label:
			combo_points_label.text = ""  # Clear when combo not active
			last_point_type = ""
			last_point_amount = 0
		
		if combo_panel and combo_panel.visible and not is_break_animating and not is_panel_fade_animating:
			_fade_out_panel()

func _fade_in_panel():
	"""Fade in the combo panel"""
	if not combo_panel:
		return
	
	is_panel_fade_animating = true
	var fade_tween = create_tween()
	
	# Make panel visible and start transparent
	combo_panel.visible = true
	combo_panel.modulate = Color.TRANSPARENT
	
	if panel_fade_in_curve:
		# Use curve-based fade in
		_animate_panel_with_curve(fade_tween, Color.TRANSPARENT, Color.WHITE, panel_fade_in_duration, panel_fade_in_curve)
	else:
		# Simple linear fade in
		fade_tween.tween_property(combo_panel, "modulate", Color.WHITE, panel_fade_in_duration)
	
	# Mark fade animation as complete
	fade_tween.tween_callback(_on_panel_fade_in_complete).set_delay(panel_fade_in_duration)

func _fade_out_panel():
	"""Fade out the combo panel"""
	if not combo_panel:
		return
	
	is_panel_fade_animating = true
	var fade_tween = create_tween()
	
	if panel_fade_out_curve:
		# Use curve-based fade out
		_animate_panel_with_curve(fade_tween, Color.WHITE, Color.TRANSPARENT, panel_fade_out_duration, panel_fade_out_curve)
	else:
		# Simple linear fade out
		fade_tween.tween_property(combo_panel, "modulate", Color.TRANSPARENT, panel_fade_out_duration)
	
	# Hide panel after fade completes
	fade_tween.tween_callback(func(): combo_panel.visible = false).set_delay(panel_fade_out_duration)
	
	# Mark fade animation as complete
	fade_tween.tween_callback(_on_panel_fade_out_complete).set_delay(panel_fade_out_duration)

func _animate_panel_with_curve(tween: Tween, start_color: Color, end_color: Color, duration: float, curve: Curve):
	"""Animate the panel's modulate property using a curve"""
	var steps = 20
	for step in range(steps + 1):
		var t = float(step) / float(steps)
		var curve_value = curve.sample(t)
		var color = start_color.lerp(end_color, curve_value)
		var step_delay = t * duration
		tween.tween_property(combo_panel, "modulate", color, duration / steps).set_delay(step_delay)

func _on_panel_fade_in_complete():
	"""Called when panel fade in animation completes"""
	is_panel_fade_animating = false

func _on_panel_fade_out_complete():
	"""Called when panel fade out animation completes"""
	is_panel_fade_animating = false

func _update_progress_bar_color(progress: float):
	"""Update progress bar color based on time remaining"""
	if not combo_progress_bar:
		return
		
	var style_box = combo_progress_bar.get_theme_stylebox("fill")
	if not style_box:
		return
	
	var color: Color
	
	if use_curve_for_colors and color_transition_curve:
		# Use curve to determine color transition
		var curve_value = color_transition_curve.sample(1.0 - progress)  # Invert so 0 progress = high curve value
		
		if curve_value > 0.5:
			# High curve value = more urgent color
			var t = (curve_value - 0.5) * 2.0
			color = progress_color_half.lerp(progress_color_low, t)
		else:
			# Low curve value = less urgent color
			var t = curve_value * 2.0
			color = progress_color_full.lerp(progress_color_half, t)
	else:
		# Linear color transition (original behavior)
		if progress > 0.5:
			var t = (1.0 - progress) * 2.0
			color = progress_color_full.lerp(progress_color_half, t)
		else:
			var t = (0.5 - progress) * 2.0
			color = progress_color_half.lerp(progress_color_low, t)
	
	if style_box is StyleBoxFlat:
		(style_box as StyleBoxFlat).bg_color = color

func _on_combo_achieved(combo_count: int):
	if combo_level_label:
		_animate_combo_pulse()
		
func _on_point_scored(point_type: String, amount: int):
	print("point scored - %s +%d" % [point_type, amount])
	
	last_point_type = point_type
	last_point_amount = amount
	
	if combo_points_label:
		if point_type == "pickup" and amount == 0:
			combo_points_label.text = "pickup"  # Just show "pickup" without +0
		else:
			combo_points_label.text = "%s +%d" % [point_type, amount]
		
		# Trigger bump animation
		_animate_points_bump()

func _animate_points_bump():
	"""Animate the points label when new points are scored"""
	if not combo_points_label:
		return
	
	# Kill any existing points animation
	var points_tween = create_tween()
	points_tween.set_parallel(true)
	
	# Color animation
	var original_color = combo_points_label.modulate
	points_tween.tween_property(combo_points_label, "modulate", points_bump_color, points_bump_duration * 0.3)
	points_tween.tween_property(combo_points_label, "modulate", original_color, points_bump_duration * 0.7).set_delay(points_bump_duration * 0.3)
	
	# Scale and rotation animations
	if enable_curve_animations and points_bump_curve:
		# Use curve-based bump animation
		var steps = 12
		for i in range(steps + 1):
			var t = float(i) / float(steps)
			var curve_value = points_bump_curve.sample(t)
			
			# Scale animation
			var scale_multiplier = 1.0 + (curve_value * points_bump_scale)
			var target_scale = original_points_scale * scale_multiplier
			
			# Rotation animation  
			var rotation_value = original_points_rotation + (curve_value * points_bump_rotation * PI / 180.0)
			
			var delay = t * points_bump_duration
			points_tween.parallel().tween_property(combo_points_label, "scale", target_scale, points_bump_duration / steps).set_delay(delay)
			points_tween.parallel().tween_property(combo_points_label, "rotation", rotation_value, points_bump_duration / steps).set_delay(delay)
		
		# Ensure return to original transforms
		points_tween.tween_property(combo_points_label, "scale", original_points_scale, 0.05).set_delay(points_bump_duration)
		points_tween.tween_property(combo_points_label, "rotation", original_points_rotation, 0.05).set_delay(points_bump_duration)
	else:
		# Simple bump animation without curves
		var max_scale = original_points_scale * (1.0 + points_bump_scale)
		var max_rotation_rad = original_points_rotation + (points_bump_rotation * PI / 180.0)
		
		points_tween.tween_property(combo_points_label, "scale", max_scale, points_bump_duration * 0.5)
		points_tween.tween_property(combo_points_label, "scale", original_points_scale, points_bump_duration * 0.5).set_delay(points_bump_duration * 0.5)
		
		points_tween.tween_property(combo_points_label, "rotation", max_rotation_rad, points_bump_duration * 0.5)
		points_tween.tween_property(combo_points_label, "rotation", original_points_rotation, points_bump_duration * 0.5).set_delay(points_bump_duration * 0.5)

func _on_combo_broken():
	print("combo broken")
	
	# Clear points data when combo breaks
	last_point_type = ""
	last_point_amount = 0
	if combo_points_label:
		combo_points_label.text = ""
	
	# Set animation flag to prevent UI from hiding during animation
	is_break_animating = true
	# Don't hide UI immediately, animate the break first
	_animate_combo_break()

func _animate_combo_pulse():
	"""Animate the combo label when combo increases with rotation and scale"""
	if not combo_level_label:
		return
		
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)  
	
	# Color animation
	var original_color = combo_level_label.modulate
	tween.tween_property(combo_level_label, "modulate", Color.LIGHT_CYAN, combo_pulse_duration * 0.5)
	tween.tween_property(combo_level_label, "modulate", original_color, combo_pulse_duration * 0.5).set_delay(combo_pulse_duration * 0.5)
	
	# Scale and rotation animations with curves
	if enable_curve_animations:
		if combo_pulse_scale_curve:
			# Use curve-based scale animation
			var scale_tween = create_tween()
			var steps = 10
			for i in range(steps + 1):
				var t = float(i) / float(steps)
				var curve_value = combo_pulse_scale_curve.sample(t)
				var scale_multiplier = 1.0 + (curve_value * combo_pulse_max_scale)
				var scale_value = original_label_scale * scale_multiplier
				var delay = t * combo_pulse_duration
				scale_tween.parallel().tween_property(combo_level_label, "scale", scale_value, combo_pulse_duration / steps).set_delay(delay)
			
			# Ensure return to original scale
			scale_tween.tween_property(combo_level_label, "scale", original_label_scale, 0.05).set_delay(combo_pulse_duration)
		else:
			# Simple scale animation
			var max_scale = original_label_scale * (1.0 + combo_pulse_max_scale)
			tween.tween_property(combo_level_label, "scale", max_scale, combo_pulse_duration * 0.5)
			tween.tween_property(combo_level_label, "scale", original_label_scale, combo_pulse_duration * 0.5).set_delay(combo_pulse_duration * 0.5)
		
		if combo_pulse_rotation_curve:
			# Use curve-based rotation
			var rotation_tween = create_tween()
			var steps = 10
			for i in range(steps + 1):
				var t = float(i) / float(steps)
				var curve_value = combo_pulse_rotation_curve.sample(t)
				var rotation_value = original_label_rotation + (curve_value * combo_pulse_max_rotation * PI / 180.0)
				var delay = t * combo_pulse_duration
				rotation_tween.parallel().tween_property(combo_level_label, "rotation", rotation_value, combo_pulse_duration / steps).set_delay(delay)
			
			# Ensure return to original rotation
			rotation_tween.tween_property(combo_level_label, "rotation", original_label_rotation, 0.05).set_delay(combo_pulse_duration)
		else:
			# Simple rotation animation
			var max_rotation_rad = combo_pulse_max_rotation * PI / 180.0
			tween.tween_property(combo_level_label, "rotation", original_label_rotation + max_rotation_rad, combo_pulse_duration * 0.5)
			tween.tween_property(combo_level_label, "rotation", original_label_rotation, combo_pulse_duration * 0.5).set_delay(combo_pulse_duration * 0.5)
	else:
		# Fallback simple animations without curves
		var max_scale = original_label_scale * (1.0 + combo_pulse_max_scale)
		tween.tween_property(combo_level_label, "scale", max_scale, combo_pulse_duration * 0.5)
		tween.tween_property(combo_level_label, "scale", original_label_scale, combo_pulse_duration * 0.5).set_delay(combo_pulse_duration * 0.5)

func _animate_combo_break():
	if not combo_level_label:
		return
		
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	# Color animation with public colors
	tween.tween_property(combo_level_label, "modulate", combo_break_start_color, 0.1)
	tween.tween_property(combo_level_label, "modulate", combo_break_end_color, combo_break_duration - 0.1).set_delay(0.1)
	
	# Rotation animation with curve for combo break
	if enable_curve_animations:
		if combo_break_rotation_curve:
			# Use curve-based rotation for break
			var rotation_tween = create_tween()
			var steps = 15
			for i in range(steps + 1):
				var t = float(i) / float(steps)
				var curve_value = combo_break_rotation_curve.sample(t)
				var rotation_value = original_label_rotation + (curve_value * combo_break_max_rotation * PI / 180.0)
				var delay = t * combo_break_duration
				rotation_tween.parallel().tween_property(combo_level_label, "rotation", rotation_value, combo_break_duration / steps).set_delay(delay)
			
			# Ensure return to original rotation
			rotation_tween.tween_property(combo_level_label, "rotation", original_label_rotation, 0.05).set_delay(combo_break_duration)
		else:
			# Simple rotation animation for break
			var max_rotation_rad = combo_break_max_rotation * PI / 180.0
			tween.tween_property(combo_level_label, "rotation", original_label_rotation + max_rotation_rad, combo_break_duration)
	
	# Reset after animation completes
	tween.tween_callback(_reset_combo_ui_after_break).set_delay(combo_break_duration)

func _reset_combo_ui_after_break():
	"""Reset UI after combo break animation"""
	is_break_animating = false  # Allow UI to hide again
	
	if combo_level_label:
		combo_level_label.modulate = Color.WHITE
		combo_level_label.rotation = original_label_rotation
		combo_level_label.scale = original_label_scale
	if combo_progress_bar:
		combo_progress_bar.rotation = original_progress_rotation
		combo_progress_bar.modulate = Color.WHITE
	if combo_points_label:
		combo_points_label.modulate = Color.WHITE
		combo_points_label.rotation = original_points_rotation
		combo_points_label.scale = original_points_scale
		combo_points_label.text = ""  # Clear points text

func force_show_combo(level: int, progress: float):
	"""Force show combo UI with specific values"""
	current_combo = level
	combo_progress = progress
	is_combo_active = level > 0
	is_break_animating = false  # Reset animation state
	is_panel_fade_animating = false
	
	# Show panel
	if combo_panel:
		combo_panel.visible = true
		combo_panel.modulate = Color.WHITE
	
	if combo_level_label:
		combo_level_label.text = "COMBO x%d" % level
		combo_level_label.rotation = original_label_rotation
		combo_level_label.scale = original_label_scale
	
	if combo_progress_bar:
		combo_progress_bar.value = progress
		combo_progress_bar.rotation = original_progress_rotation
		_update_progress_bar_color(progress)
	
	if combo_points_label:
		combo_points_label.rotation = original_points_rotation
		combo_points_label.scale = original_points_scale
		# Don't force points text - let it remain from last scored point or empty

# Public API methods for external access
func get_current_combo() -> int:
	return current_combo

func get_combo_progress() -> float:
	return combo_progress

func is_combo_ui_active() -> bool:
	return is_combo_active

func trigger_combo_pulse_animation():
	"""Manually trigger combo pulse animation"""
	if is_combo_active:
		_animate_combo_pulse()

func trigger_combo_break_animation():
	"""Manually trigger combo break animation"""
	_animate_combo_break()

# Points label API
func update_points_display(point_type: String, amount: int):
	"""Manually update and animate the points display"""
	last_point_type = point_type
	last_point_amount = amount
	if combo_points_label:
		combo_points_label.text = "%s +%d" % [point_type, amount]
		_animate_points_bump()

func clear_points_display():
	"""Clear the points display"""
	last_point_type = ""
	last_point_amount = 0
	if combo_points_label:
		combo_points_label.text = ""

func get_last_point_data() -> Dictionary:
	"""Get the last point data"""
	return {
		"type": last_point_type,
		"amount": last_point_amount
	}

func trigger_panel_fade_in():
	_fade_in_panel()

func trigger_panel_fade_out():
	_fade_out_panel()

func is_panel_visible() -> bool:
	return combo_panel and combo_panel.visible

func is_panel_fading() -> bool:
	return is_panel_fade_animating
