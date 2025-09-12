extends Node
class_name ComboManager

signal combo_achieved(combo_count: int)
signal combo_broken
signal point_scored(point_type: String, amount: int)
signal pickup_occurred

@export var combo_timeout: float = 3.0  
@export var min_combo_threshold: int = 2
@export var combo_multiplier_base: float = 1.2
@export var max_combo_level: int = 5
@export var debug_output: bool = false

var current_combo: int = 0
var combo_timer: Timer
var delivery_manager: Node
var last_action_time: float = 0.0
var combo_active: bool = false

# State tracking for debugging
var last_registered_action: String = ""
var combo_break_reason: String = ""

func _ready():
	combo_timer = Timer.new()
	combo_timer.wait_time = combo_timeout
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)
	add_child(combo_timer)
	
	delivery_manager = _find_delivery_manager()
	add_to_group("combo_manager")
	
	if debug_output:
		print("ComboManager initialized - timeout: ", combo_timeout, " threshold: ", min_combo_threshold)

func _find_delivery_manager() -> Node:
	var possible_paths = [
		"../DeliveryManager",
		"../../DeliveryManager", 
		"/root/DeliveryManager"
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node and ("is_game_active" in node or "game_active" in node):
			if debug_output:
				print("Found delivery manager at: ", path)
			return node
	
	var point_managers = get_tree().get_nodes_in_group("point_manager")
	for manager in point_managers:
		if "is_game_active" in manager or "game_active" in manager:
			if debug_output:
				print("Found delivery manager in group: ", manager.get_path())
			return manager
	
	if debug_output:
		print("WARNING: No delivery manager found!")
	return null

func _is_game_active() -> bool:
	if not delivery_manager:
		return false
		
	var game_active = true
	if "is_game_active" in delivery_manager:
		game_active = delivery_manager.is_game_active()
	elif "game_active" in delivery_manager:
		game_active = delivery_manager.game_active
	
	return game_active

func register_action(action_type: int, base_points: int = 0, action_name: String = "") -> int:
	if not _is_game_active():
		if debug_output:
			print("Game not active, ignoring action: ", action_name)
		return base_points
	
	var current_time = Time.get_unix_time_from_system()
	
	last_registered_action = action_name if action_name != "" else "action_" + str(action_type)
	
	if debug_output:
		print("Registering action: ", last_registered_action, " | Current combo: ", current_combo, " | Combo active: ", combo_active)
	
	combo_timer.wait_time = combo_timeout
	combo_timer.start()
	if debug_output:
		print("Timer restarted with ", combo_timeout, " seconds")
	
	# Update combo count
	current_combo += 1
	last_action_time = current_time
	
	# Check if combo should become active
	if current_combo >= min_combo_threshold and not combo_active:
		combo_active = true
		if debug_output:
			print("Combo activated at level ", current_combo)
	
	# Calculate final points with combo multiplier
	var final_points = base_points
	var multiplier = get_combo_multiplier()
	if multiplier > 1.0:
		final_points = int(base_points * multiplier)
		if debug_output:
			print("Applying multiplier ", multiplier, ": ", base_points, " -> ", final_points)
	
	# Trigger combo effects if active
	if combo_active:
		_trigger_combo_effects()
	
	if debug_output:
		print("Action registered. New combo: ", current_combo, " Active: ", combo_active, " Timer left: ", combo_timer.time_left)
	
	return final_points

func _trigger_combo_effects():
	if delivery_manager and "show_combo_notification" in delivery_manager:
		delivery_manager.show_combo_notification(current_combo)
	
	if debug_output:
		print("Triggering combo effects for level ", current_combo)
	
	combo_achieved.emit(current_combo)

func _on_combo_timeout():
	if combo_active or current_combo > 0:
		combo_break_reason = "timer_timeout"
		_break_combo()

func _break_combo():
	var was_active = combo_active
	var old_combo = current_combo
	
	if debug_output:
		print("Breaking combo - Reason: ", combo_break_reason, " Was active: ", was_active, " Level: ", old_combo)
	
	# Reset state
	current_combo = 0
	combo_active = false
	combo_timer.stop()
	combo_break_reason = ""
	
	if was_active:
		combo_broken.emit()
		if debug_output:
			print("Combo broken signal emitted")

func force_break_combo():
	combo_break_reason = "forced"
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

func on_delivery_pickup(base_points: int) -> int:
	var final_points = register_action(0, base_points, "pickup")
	
	pickup_occurred.emit()
	
	if base_points == 0:
		point_scored.emit("pickup", 0)
	else:
		point_scored.emit("pickup", final_points)
	
	if debug_output:
		print("pickup processed: ", base_points, " = ", final_points)
	
	return final_points

func on_delivery_dropoff(base_points: int) -> int:
	var final_points = register_action(1, base_points, "delivery")
	point_scored.emit("delivery", final_points)
	
	if debug_output:
		print("dropoff processed: ", base_points, " = ", final_points)
	
	return final_points

func on_near_miss(base_points: int = 0) -> int:
	var final_points = register_action(2, base_points, "near_miss")
	point_scored.emit("coming through", final_points)
	
	if debug_output:
		print("coming through processed ", base_points, " = ", final_points)
	
	return final_points

func on_collision():
	if debug_output:
		print("Collision detected - breaking combo")
	combo_break_reason = "collision"
	force_break_combo()

func get_debug_info() -> Dictionary:
	return {
		"current_combo": current_combo,
		"combo_active": combo_active,
		"timer_left": get_time_until_combo_break(),
		"last_action": last_registered_action,
		"break_reason": combo_break_reason,
		"game_active": _is_game_active(),
		"delivery_manager_found": delivery_manager != null
	}
