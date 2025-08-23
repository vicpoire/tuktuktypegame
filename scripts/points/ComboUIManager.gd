extends Node
class_name ComboUIManager

@export var combo_progress_bar: ProgressBar
@export var combo_level_label: Label
@export var combo_container: Control  # Optional: container to show/hide entire combo UI
@export var combo_manager: ComboManager
@export_group("Colors")
@export var progress_color_full: Color = Color.GREEN
@export var progress_color_half: Color = Color.YELLOW
@export var progress_color_low: Color = Color.RED
@export_group("Color Transition")
@export var use_curve_for_colors: bool = false
@export var color_transition_curve: Curve
var tween: Tween

func _ready():
	# Use exported reference first, then fallback to finding it
	if not combo_manager:
		combo_manager = _find_combo_manager()
	
	if combo_manager:
		print("✓ ComboUIManager: Using ComboManager at: ", combo_manager.get_path())
		# Connect to combo manager signals
		combo_manager.combo_achieved.connect(_on_combo_achieved)
		combo_manager.combo_broken.connect(_on_combo_broken)
	else:
		print("❌ ComboUIManager: Could not find ComboManager")
		
	# Initialize UI
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
	"""Initialize UI elements to default state"""
	if combo_progress_bar:
		combo_progress_bar.min_value = 0.0
		combo_progress_bar.max_value = 1.0
		combo_progress_bar.value = 0.0
		combo_progress_bar.visible = false
	
	if combo_level_label:
		combo_level_label.text = ""
		combo_level_label.visible = false
	
	if combo_container:
		combo_container.visible = false

func _process(_delta):
	"""Update UI every frame"""
	if not combo_manager:
		return
		
	_update_combo_ui()

func _update_combo_ui():
	var combo_count = combo_manager.get_current_combo()
	var time_left = combo_manager.get_time_until_combo_break()
	var total_timeout = combo_manager.combo_timeout
	
	if combo_count >= 1:
		_show_combo_ui()
		
		if combo_progress_bar:
			var progress = time_left / total_timeout if total_timeout > 0 else 0.0
			combo_progress_bar.value = progress
			
			_update_progress_bar_color(progress)
		
		if combo_level_label:
			if combo_count >= combo_manager.min_combo_threshold:
				combo_level_label.text = "COMBO x%d" % combo_count
			else:
				combo_level_label.text = "x%d" % combo_count
	else:
		_hide_combo_ui()

func _show_combo_ui():
	"""Show the combo UI elements"""
	if combo_container:
		combo_container.visible = true
	else:
		if combo_progress_bar:
			combo_progress_bar.visible = true
		if combo_level_label:
			combo_level_label.visible = true

func _hide_combo_ui():
	"""Hide the combo UI elements"""
	if combo_container:
		combo_container.visible = false
	else:
		if combo_progress_bar:
			combo_progress_bar.visible = false
		if combo_level_label:
			combo_level_label.visible = false

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
	"""Called when a new combo level is achieved"""
	print("🎯 ComboUIManager: Combo achieved x%d" % combo_count)
	
	# Animate the combo level label
	if combo_level_label:
		_animate_combo_label()

func _on_combo_broken():
	"""Called when combo is broken"""
	print("💥 ComboUIManager: Combo broken")
	
	# Animate combo break
	_animate_combo_break()

func _animate_combo_label():
	"""Animate the combo label when combo increases"""
	if not combo_level_label:
		return
		
	# Kill existing tween
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)  # Allow multiple properties to animate simultaneously
	
	# Scale pulse animation
	var original_scale = combo_level_label.scale
	tween.tween_property(combo_level_label, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(combo_level_label, "scale", original_scale, 0.1).set_delay(0.1)
	
	# Color flash animation
	var original_color = combo_level_label.modulate
	tween.tween_property(combo_level_label, "modulate", Color.LIGHT_CYAN, 0.1)
	tween.tween_property(combo_level_label, "modulate", original_color, 0.1).set_delay(0.1)

func _animate_combo_break():
	"""Animate when combo breaks"""
	if not combo_level_label:
		return
		
	# Kill existing tween
	if tween:
		tween.kill()
	
	tween = create_tween()
	
	# Flash red and fade out
	combo_level_label.modulate = Color.RED
	tween.tween_property(combo_level_label, "modulate", Color.TRANSPARENT, 0.3)
	
	# Reset after animation
	tween.tween_callback(_reset_combo_ui_after_break).set_delay(0.3)

func _reset_combo_ui_after_break():
	"""Reset UI after combo break animation"""
	if combo_level_label:
		combo_level_label.modulate = Color.WHITE
	_hide_combo_ui()


func force_show_combo(level: int, progress: float):
	if combo_level_label:
		combo_level_label.text = "COMBO x%d" % level
		combo_level_label.visible = true
	
	if combo_progress_bar:
		combo_progress_bar.value = progress
		combo_progress_bar.visible = true
		_update_progress_bar_color(progress)
	
	if combo_container:
		combo_container.visible = true
