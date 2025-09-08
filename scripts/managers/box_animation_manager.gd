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
	if combo_manager and not combo_manager.combo_achieved.is_connected(_on_combo_achieved):
		combo_manager.combo_achieved.connect(_on_combo_achieved)
		combo_manager.combo_broken.connect(_on_combo_broken)

func _on_combo_achieved(combo_count: int):
	var combos_since_last_trigger = combo_count - last_triggered_combo
	
	if combos_since_last_trigger >= combo_trigger_interval:
		trigger_box_animations()
		last_triggered_combo = combo_count

func _on_combo_broken():
	last_triggered_combo = 0

func trigger_box_animations():
	if box_meshes.is_empty():
		return
	
	for i in range(box_meshes.size()):
		if is_instance_valid(box_meshes[i]):
			var delay = i * animation_stagger_delay
			var box_height = base_jump_height + (i * (base_jump_height * 0.3))
			
			if delay > 0:
				get_tree().create_timer(delay).timeout.connect(
					animate_box.bind(box_meshes[i], box_height), 
					CONNECT_ONE_SHOT
				)
			else:
				animate_box(box_meshes[i], box_height)

func animate_box(box: Node3D, jump_height: float):
	if not is_instance_valid(box):
		return
	
	var original_position = box.position
	var original_rotation = box.rotation
	
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
	
	var rotation_tween = create_tween()
	rotation_tween.tween_method(
		func(rot): box.rotation = rot,
		original_rotation,
		original_rotation + Vector3(0, TAU, 0),
		rotation_duration
	)
	rotation_tween.set_trans(Tween.TRANS_BACK)
	rotation_tween.set_ease(Tween.EASE_OUT)
	
	rotation_tween.tween_callback(func(): box.rotation = original_rotation)

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
	trigger_box_animations()

func test_single_box(index: int = 0):
	if index < box_meshes.size() and is_instance_valid(box_meshes[index]):
		var height = base_jump_height + (index * (base_jump_height * 0.3))
		animate_box(box_meshes[index], height)
