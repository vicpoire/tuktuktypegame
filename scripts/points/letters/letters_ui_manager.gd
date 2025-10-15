extends Control

@export var color_off: Color 
@export var color_on: Color
@export var inv_color_off: Color
@export var inv_color_on: Color
@export var animation_speed: float = 2.0
@export var fade_out_delay: float = 2.0
@export var fade_out_speed: float = 0.75
@export var anim_player: AnimationPlayer

var letter_labels: Array[Label]
var animation_data: Dictionary = {}
var letter_manager: Node
var picked_letters: Array[bool] = []
var pending_fade: bool = false

func _ready():
	var nodes = get_tree().get_nodes_in_group("letters_ui")
	for node in nodes:
		if node is Label:
			letter_labels.append(node)
	
	picked_letters.resize(letter_labels.size())
	for i in range(picked_letters.size()):
		picked_letters[i] = false
	
	await get_tree().process_frame
	letter_manager = get_tree().get_first_node_in_group("letter_manager")
	
	if letter_manager:
		if letter_manager.has_signal("letter_picked_up"):
			letter_manager.letter_picked_up.connect(_on_letter_picked_up)
	
	on_start_text_anim()

func _process(delta):
	for label in animation_data.keys():
		var data = animation_data[label]
		data.progress += delta * data.speed
		data.progress = min(data.progress, 1.0)
		
		label.modulate = data.start_color.lerp(data.target_color, data.progress)
		
		if data.progress >= 1.0:
			animation_data.erase(label)

func trigger_animation_on_letter(label: Label, target_color: Color, speed: float = 1.0):
	animation_data[label] = {
		"start_color": label.modulate,
		"target_color": target_color,
		"progress": 0.0,
		"speed": speed
	}

func on_start_text_anim():
	for i in range(letter_labels.size()): 
		trigger_animation_on_letter(letter_labels[i], color_off, 0.75)
	
	await get_tree().create_timer(fade_out_delay).timeout
	
	for i in range(letter_labels.size()): 
		trigger_animation_on_letter(letter_labels[i], inv_color_off, fade_out_speed)

func _on_letter_picked_up(letter_index: int):
	if letter_index >= 0 and letter_index < letter_labels.size():
		picked_letters[letter_index] = true
		
		for i in range(letter_labels.size()):
			if picked_letters[i]:
				trigger_animation_on_letter(letter_labels[i], color_on, animation_speed)
				await get_tree().create_timer(0.025).timeout
				anim_player.play("on_pick_up")
			else:
				trigger_animation_on_letter(letter_labels[i], color_off, animation_speed)
		
		if all_letters_picked():
			pending_fade = false
			on_all_letters_picked()
			return
		
		pending_fade = true
		await get_tree().create_timer(fade_out_delay).timeout
		
		if not pending_fade:
			return
		
		for i in range(letter_labels.size()):
			if picked_letters[i]:
				trigger_animation_on_letter(letter_labels[i], inv_color_on, fade_out_speed)
			else:
				trigger_animation_on_letter(letter_labels[i], inv_color_off, fade_out_speed)

func all_letters_picked() -> bool:
	for picked in picked_letters:
		if not picked:
			return false
	return true

func on_all_letters_picked():
	await get_tree().create_timer(0.2).timeout
	for i in range(letter_labels.size()):
		if picked_letters[i]:
			trigger_animation_on_letter(letter_labels[i], color_on, animation_speed)
	
	anim_player.play("all_picked_up")
	await get_tree().create_timer(2.25).timeout
	
	for i in range(letter_labels.size()):
		if picked_letters[i]:
			trigger_animation_on_letter(letter_labels[i], inv_color_on, fade_out_speed)
