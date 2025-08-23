extends Node
class_name ComboManager

signal combo_achieved(combo_count: int)
signal combo_broken

@export var combo_timeout: float = 3.0  
@export var min_combo_threshold: int = 2
@export var combo_multiplier_base: float = 1.2
@export var max_combo_level: int = 5

var current_combo: int = 0
var combo_timer: Timer
var delivery_manager: Node
var last_action_time: float = 0.0
var combo_active: bool = false

func _ready():
	combo_timer = Timer.new()
	combo_timer.wait_time = combo_timeout
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)
	add_child(combo_timer)
	
	delivery_manager = _find_delivery_manager()
	add_to_group("combo_manager")

func _find_delivery_manager() -> Node:
	var possible_paths = [
		"../DeliveryManager",
		"../../DeliveryManager", 
		"/root/DeliveryManager"
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node and "is_game_active" in node:
			return node
	
	var point_managers = get_tree().get_nodes_in_group("point_manager")
	for manager in point_managers:
		if "is_game_active" in manager:
			return manager
	
	return null

func register_action(action_type: int, amount: int = 1):
	if not delivery_manager:
		return
		
	var game_active = true
	if "is_game_active" in delivery_manager:
		game_active = delivery_manager.is_game_active()
	elif "game_active" in delivery_manager:
		game_active = delivery_manager.game_active
		
	if not game_active:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var time_since_last = current_time - last_action_time
	
	# Break combo if too much time has passed
	if time_since_last > combo_timeout and combo_active:
		_break_combo()
	
	current_combo += amount
	last_action_time = current_time
	
	combo_timer.wait_time = combo_timeout
	combo_timer.start()
	
	if current_combo >= min_combo_threshold:
		combo_active = true
		_trigger_combo_effects()

func _trigger_combo_effects():
	if delivery_manager and "show_combo_notification" in delivery_manager:
		delivery_manager.show_combo_notification(current_combo)
	
	combo_achieved.emit(current_combo)

func _on_combo_timeout():
	if combo_active:
		_break_combo()

func _break_combo():
	if combo_active:
		combo_broken.emit()
	
	current_combo = 0
	combo_active = false
	combo_timer.stop()

func force_break_combo():
	_break_combo()

func get_current_combo() -> int:
	return current_combo

func get_combo_multiplier() -> float:
	if not combo_active:
		return 1.0
	
	var combo_level = min(current_combo, max_combo_level)
	return pow(combo_multiplier_base, combo_level - 1)

func is_combo_active() -> bool:
	return combo_active

func get_time_until_combo_break() -> float:
	if combo_timer.is_stopped():
		return 0.0
	return combo_timer.time_left

func on_delivery_pickup(amount: int):
	register_action(0, amount)

func on_delivery_dropoff(amount: int):
	register_action(1, amount)

func on_near_miss():
	register_action(2, 1)

func on_collision():
	force_break_combo()
