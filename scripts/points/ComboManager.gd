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

# state tracking for debug
var last_registered_action: String = ""
var combo_break_reason: String = ""

# to add new action or point giving thing:
	# add method (on_[whatever]():)
	# need to use action type next available num


func _ready():
	combo_timer = Timer.new()
	combo_timer.wait_time = combo_timeout
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)
	add_child(combo_timer)
	
	delivery_manager = $".."
	add_to_group("combo_manager")
	


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
		return base_points
	
	var current_time = Time.get_unix_time_from_system()
	
	last_registered_action = action_name if action_name != "" else "action_" + str(action_type)
	
	if debug_output:
		print("registering action: ", last_registered_action, " current combo: ", current_combo, " combo active: ", combo_active)
	
	combo_timer.wait_time = combo_timeout
	combo_timer.start()
	if debug_output:
		print("timer restarted ", combo_timeout, " seconds")
	
	current_combo += 1
	last_action_time = current_time
	
	if current_combo >= min_combo_threshold and not combo_active:
		combo_active = true
		if debug_output:
			print("Combo activated at level ", current_combo)
	
	# calculate final points with combo multiplier
	var final_points = base_points
	var multiplier = get_combo_multiplier()
	if multiplier > 1.0:
		final_points = int(base_points * multiplier)
	
	# trigger combo effects if active
	if combo_active:
		_trigger_combo_effects()
	
	if debug_output:
		print("new combo: ", current_combo, " active: ", combo_active)
	
	return final_points

func _trigger_combo_effects():
	if delivery_manager and "show_combo_notification" in delivery_manager:
		delivery_manager.show_combo_notification(current_combo)
	
	if debug_output:
		print("triggering combo effects for level ", current_combo)
	
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
	
	# reset state
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

#region pointgivers
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
	
func on_airtime(base_points: int = 0) -> int:
	var final_points = register_action(3, base_points, "airtime")
	point_scored.emit("airtime", final_points)
	
	if debug_output:
		print("airtime processed ", base_points, " = ", final_points)
	
	return final_points

func on_letter_pickup(base_points: int = 0) -> int:
	var final_points = register_action(3, base_points, "letter_pickup")
	point_scored.emit("letter picked up", final_points)
	
	if debug_output:
		print("letter_pickup processed ", base_points, " = ", final_points)
	
	return final_points

#region flips

func on_front_flip(base_points: int = 0):
	var final_points = register_action(3, base_points, "front_flip")
	point_scored.emit("frontflip!", final_points)
	
	if debug_output:
		print("letter_pickup processed ", base_points, " = ", final_points)

func on_back_flip(base_points: int = 0):
	var final_points = register_action(3, base_points, "back_flip")
	point_scored.emit("backflip!", final_points)
	
	if debug_output:
		print("letter_pickup processed ", base_points, " = ", final_points)

func on_side_flip(base_points: int = 0):
	var final_points = register_action(3, base_points, "side_flip")
	point_scored.emit("sideflip!", final_points)
	
	if debug_output:
		print("letter_pickup processed ", base_points, " = ", final_points)

#endregion

#endregion

func on_collision():
	combo_break_reason = "collision"
	force_break_combo()
