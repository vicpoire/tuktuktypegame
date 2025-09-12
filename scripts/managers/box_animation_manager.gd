extends Node
class_name BoxAnimationManager

@export var combo_manager: ComboManager
@export var box_meshes: Array[Node3D] = []
@export var combo_trigger_interval: int = 5
@export var base_jump_height: float = 2.0
@export var height_multiplier: float = 1.2
@export var jump_duration: float = 0.6
@export var rotation_duration: float = 0.8
@export var animation_stagger_delay: float = 0.1

var last_triggered_combo: int = 0
var box_original_positions: Dictionary = {}
var box_original_rotations: Dictionary = {}

func _ready():
	if combo_manager:
		connect_to_combo_manager()
	else:
		call_deferred("find_combo_manager")

func find_combo_manager():
	var combo_managers = get_tree().get_nodes_in_group("combo_manager")
	if combo_managers.size() > 0:
		combo_manager = combo_managers[0]
		connect_to_combo_manager()

func connect_to_combo_manager():
	if combo_manager:
		# Connect to combo signals if not already connected
		if not combo_manager.combo_achieved.is_connected(_on_combo_achieved):
			combo_manager.combo_achieved.connect(_on_combo_achieved)
		if not combo_manager.combo_broken.is_connected(_on_combo_broken):
			combo_manager.combo_broken.connect(_on_combo_broken)
		
		# Connect to the new point_scored signal to differentiate action types
		if combo_manager.has_signal("point_scored") and not combo_manager.point_scored.is_connected(_on_point_scored):
			combo_manager.point_scored.connect(_on_point_scored)

func _on_combo_achieved(combo_count: int):
	# This will handle non-delivery combo actions (like near miss)
	# Only trigger jump animations for actions that aren't pickups/deliveries
	var combos_since_last_trigger = combo_count - last_triggered_combo
	
	if combos_since_last_trigger >= combo_trigger_interval:
		trigger_box_jump_animations()
		last_triggered_combo = combo_count

func _on_combo_broken():
	last_triggered_combo = 0

# New function to handle point scoring events and determine animation type
func _on_point_scored(point_type: String, amount: int):
	if point_type == "pickup" or point_type == "delivery":
		# For pickups and deliveries, do rotation animation
		trigger_single_box_rotation()
	# For other types like "coming through" (near miss), let combo_achieved handle jump animations

# Function to rotate just one box (for pickups/deliveries)
func trigger_single_box_rotation():
	if box_meshes.is_empty():
		return
	
	# Pick a random box or use a sequential pattern
	var box_index = randi() % box_meshes.size()
	var box = box_meshes[box_index]
	
	if is_instance_valid(box):
		animate_box_rotation_only(box)

# Function that only does rotation (no jumping)
func animate_box_rotation_only(box: Node3D):
	if not is_instance_valid(box):
		return
	
	# Store and ensure we return to original rotation
	var original_rotation = box.rotation
	if not box_original_rotations.has(box):
		box_original_rotations[box] = original_rotation
	
	var rotation_tween = create_tween()
	rotation_tween.tween_method(
		func(rot): box.rotation = rot,
		original_rotation,
		original_rotation + Vector3(0, TAU, 0),
		rotation_duration
	)
	rotation_tween.set_trans(Tween.TRANS_BACK)
	rotation_tween.set_ease(Tween.EASE_OUT)
	
	# Reset to original stored rotation to prevent drift
	rotation_tween.tween_callback(func(): box.rotation = box_original_rotations[box])

# Renamed from trigger_box_animations to be more specific
func trigger_box_jump_animations():
	if box_meshes.is_empty():
		return
	
	for i in range(box_meshes.size()):
		if is_instance_valid(box_meshes[i]):
			var delay = i * animation_stagger_delay
			var box_height = base_jump_height + (i * (base_jump_height * 0.3))
			
			if delay > 0:
				get_tree().create_timer(delay).timeout.connect(
					animate_box_jump.bind(box_meshes[i], box_height), 
					CONNECT_ONE_SHOT
				)
			else:
				animate_box_jump(box_meshes[i], box_height)

# Renamed and improved to ensure position resets properly
func animate_box_jump(box: Node3D, jump_height: float):
	if not is_instance_valid(box):
		return
	
	# Store original positions to prevent drift
	var original_position = box.position
	var original_rotation = box.rotation
	if not box_original_positions.has(box):
		box_original_positions[box] = original_position
	if not box_original_rotations.has(box):
		box_original_rotations[box] = original_rotation
	
	# Jump animation
	var position_tween = create_tween()
	
	position_tween.tween_method(
		func(pos): box.position = pos,
		original_position,
		original_position + Vector3.UP * jump_height,
		jump_duration * 0.5
	)
	position_tween.set_trans(Tween.TRANS_QUART)
	position_tween.set_ease(Tween.EASE_OUT)
	
	position_tween.tween_method(
		func(pos): box.position = pos,
		original_position + Vector3.UP * jump_height,
		original_position,
		jump_duration * 0.5
	)
	position_tween.set_trans(Tween.TRANS_QUART)
	position_tween.set_ease(Tween.EASE_IN)
	
	position_tween.tween_callback(func(): box.position = box_original_positions[box])
	
	# Rotation animation
	var rotation_tween = create_tween()
	rotation_tween.tween_method(
		func(rot): box.rotation = rot,
		original_rotation,
		original_rotation + Vector3(0, TAU, 0),
		rotation_duration
	)
	rotation_tween.set_trans(Tween.TRANS_BACK)
	rotation_tween.set_ease(Tween.EASE_OUT)
	
	rotation_tween.tween_callback(func(): box.rotation = box_original_rotations[box])

func set_combo_trigger_interval(new_interval: int):
	combo_trigger_interval = max(1, new_interval)

func add_box_mesh(box: Node3D):
	if box and not box in box_meshes:
		box_meshes.append(box)
		box_original_positions[box] = box.position
		box_original_rotations[box] = box.rotation

func remove_box_mesh(box: Node3D):
	if box in box_meshes:
		box_meshes.erase(box)
		box_original_positions.erase(box)
		box_original_rotations.erase(box)

func clear_box_meshes():
	box_meshes.clear()
	box_original_positions.clear()
	box_original_rotations.clear()

func test_animation():
	trigger_box_jump_animations()

func test_single_box(index: int = 0):
	if index < box_meshes.size() and is_instance_valid(box_meshes[index]):
		var height = base_jump_height + (index * (base_jump_height * 0.3))
		animate_box_jump(box_meshes[index], height)

func test_pickup_rotation():
	trigger_single_box_rotation()

func test_delivery_rotation():
	trigger_single_box_rotation()

func test_jump_animation():
	trigger_box_jump_animations()
