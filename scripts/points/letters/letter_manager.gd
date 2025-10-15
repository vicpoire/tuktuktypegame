extends Node

signal letter_picked_up(letter_index: int)
signal all_letters_collected

@export var letters: Array[Node3D]
@export var letters_status: Array[int]
@export var letters_in_word: Array[String]
@export var points_on_pickup: int = 25

var max_letters: int = 0
var combo_manager: Node

func _ready():
	add_to_group("letter_manager")
	max_letters = letters.size()
	letters_status.resize(max_letters)
	combo_manager = get_tree().get_first_node_in_group("combo_manager")

	for i in range(letters.size()):
		var letter = letters[i]
		if letter.has_signal("picked_up"):
			letter.picked_up.connect(_on_letter_collected.bind(i))
	
	update_letter_status()

func update_letter_status():
	for i in range(letters.size()):
		var letter = letters[i]
		if letter.is_on:
			letters_status[i] = 1  
		else:
			letters_status[i] = 0 

func _on_letter_collected(letter_index: int):
	update_letter_status()
	give_points()
	letter_picked_up.emit(letter_index)
	
	if all_letters_disabled():
		all_letters_collected.emit()
	
	check_letter_status()

func give_points():
	combo_manager.on_letter_pickup(points_on_pickup)

func get_active_letters_count():
	return letters_status.count(1)

func all_letters_on():
	return get_active_letters_count() == max_letters

func all_letters_disabled() -> bool:
	return get_active_letters_count() == 0

func check_letter_status():
	var active = get_active_letters_count()
