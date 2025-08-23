extends Label

@export var lifetime: float = 2.0
@export var position_curve: Curve
@export var opacity_curve: Curve
@export var point_marker: bool = false
@export var combo_marker: bool = false  # NEW: Flag for combo labels
@export var random_offset_range: float = 150.0

var elapsed_time := 0.0
var start_pos: Vector2
var pending_text: String

func set_log_text(t: String):
	pending_text = t
	if is_inside_tree():
		text = t

func show_points(points: int):
	text = "+%d" % points
	pending_text = text

func show_point_formula(boxes: int, points_per_box: int):
	var formula_text = "+%d×%d" % [boxes, points_per_box]
	text = formula_text
	pending_text = formula_text

func _ready():
	start_pos = position
	
	# Only randomize position for point markers, not combo markers
	if point_marker and not combo_marker:
		position_randomly()
		start_pos = position
	
	modulate.a = 0.0
	
	if pending_text != "":
		text = pending_text

func position_randomly():
	var container_size: Vector2
	if get_parent() and get_parent() is Control:
		container_size = get_parent().size
		if container_size == Vector2.ZERO:
			container_size = get_viewport().size
	else:
		container_size = get_viewport().size
	
	var center_x = container_size.x / 2
	var center_y = container_size.y / 2
	
	var random_x = randf_range(-random_offset_range, random_offset_range)
	var random_y = randf_range(-random_offset_range, random_offset_range)
	
	var new_x = clamp(center_x + random_x, 0, container_size.x)
	var new_y = clamp(center_y + random_y, 0, container_size.y)
	
	position = Vector2(new_x, new_y)

func _process(delta):
	elapsed_time += delta
	var t = elapsed_time / lifetime
	
	if t >= 1.0:
		queue_free()
		return
	
	if position_curve:
		var y_offset = position_curve.sample(t)
		position = start_pos + Vector2(0, y_offset)
	
	if opacity_curve:
		modulate.a = opacity_curve.sample(t)
