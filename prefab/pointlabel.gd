extends Node

@export var display_duration: float = 2.0
@export var fade_duration: float = 0.5
@export var float_distance: float = 100.0
@export var random_offset_range: float = 150.0

var control: Control
var label: Label
var tween: Tween
var pending_points: int = 0
var is_ready: bool = false

func _ready():
	# Create a Control node to handle positioning
	control = Control.new()
	add_child(control)
	
	# Create the label
	label = Label.new()
	control.add_child(label)
	
	# Style the label
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Position randomly near center
	position_randomly()

func position_randomly():
	# Get screen size
	var screen_size = get_viewport().size
	
	# Calculate center area with some random offset
	var center_x = screen_size.x / 2
	var center_y = screen_size.y / 2
	
	# Add random offset within range
	var random_x = randf_range(-random_offset_range, random_offset_range)
	var random_y = randf_range(-random_offset_range, random_offset_range)
	
	control.position = Vector2(center_x + random_x, center_y + random_y)

func show_points(points: int):
	# If not ready yet, store the points and wait
	if not is_ready:
		pending_points = points
		return
	
	# Set the text
	if label:
		label.text = "+%d" % points
		
		# Adjust label size to fit text
		label.size = label.get_theme_default_font().get_string_size(
			label.text, 
			HORIZONTAL_ALIGNMENT_LEFT, 
			-1, 
			32
		)
		
		# Center the label on its position
		label.position = -label.size / 2
		
		# Create tween for animation
		tween = create_tween()
		tween.set_parallel(true)  # Allow multiple animations simultaneously
		
		# Float upward animation
		var start_pos = control.position
		var end_pos = start_pos + Vector2(0, -float_distance)
		tween.tween_property(control, "position", end_pos, display_duration)
		
		# Fade out animation (starts after display_duration - fade_duration)
		var fade_start_time = display_duration - fade_duration
		tween.tween_method(_set_alpha, 1.0, 0.0, fade_duration).set_delay(fade_start_time)
		
		# Scale animation for impact
		tween.tween_property(control, "scale", Vector2(1.2, 1.2), 0.2)
		tween.tween_property(control, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.2)
		
		# Remove after animation completes
		tween.tween_callback(queue_free).set_delay(display_duration)

func _set_alpha(alpha: float):
	if label:
		var color = label.get_theme_color("font_color")
		color.a = alpha
		label.add_theme_color_override("font_color", color)
		
		# Also fade the shadow
		var shadow_color = label.get_theme_color("font_shadow_color")
		shadow_color.a = alpha
		label.add_theme_color_override("font_shadow_color", shadow_color)
