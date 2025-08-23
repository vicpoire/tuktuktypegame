extends Node

@export var point_manager: Node

@export var base_near_miss_points: int = 10
@export var speed_multiplier: float = 0.5 
@export var combo_multiplier: float = 1.2 
@export var combo_window_time: float = 3.0  
@export var max_combo_multiplier: float = 3.0

@export var near_miss_acceptance_window: float = 0.5  
@export var max_near_misses_per_second: int = 3 

var current_combo: int = 0
var last_near_miss_time: float = 0.0
var total_near_misses: int = 0

var recent_near_misses: Array[float] = [] 

signal near_miss_registered(miss_data: Dictionary, points_awarded: int)
signal combo_started(combo_count: int)
signal combo_ended(final_combo: int, total_points: int)
signal near_miss_rejected(reason: String) 

func _ready():
	add_to_group("near_miss_manager")
	print("ready with %s second acceptance window" % near_miss_acceptance_window)

func register_near_miss(miss_data: Dictionary):
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = _dict_to_timestamp(current_time)
	
	print("near miss attempt at timestamp: ", current_timestamp)
	
	if not _is_within_acceptance_window(current_timestamp):
		print("near miss rejected - outside time window")
		near_miss_rejected.emit("outside_time_window")
		return
	
	if not _check_rate_limit(current_timestamp):
		print("near miss rejected - rate limited")
		near_miss_rejected.emit("rate_limited")
		return
	
	print("near miss accepted!")
	
	recent_near_misses.append(current_timestamp)
	
	var base_points = base_near_miss_points
	var speed_bonus = int(miss_data.speed * speed_multiplier)
	_update_combo(current_timestamp)
	
	var combo_bonus = 1.0
	if current_combo > 1:
		combo_bonus = min(1.0 + (current_combo - 1) * (combo_multiplier - 1.0), max_combo_multiplier)
	
	var final_points = int((base_points + speed_bonus) * combo_bonus)
	
	total_near_misses += 1
	last_near_miss_time = current_timestamp
	
	if point_manager and point_manager.has_method("add_points"):
		point_manager.add_points(final_points, "near_miss")
	
	if current_combo > 1 and point_manager and point_manager.has_method("show_combo_notification"):
		point_manager.show_combo_notification(current_combo)
	
	var complete_miss_data = miss_data.duplicate()
	complete_miss_data["points_awarded"] = final_points
	complete_miss_data["combo_count"] = current_combo
	complete_miss_data["total_near_misses"] = total_near_misses
	complete_miss_data["timestamp"] = current_timestamp
	
	near_miss_registered.emit(complete_miss_data, final_points)
	
	print("nearmiss points: %d, combo: x%d" % [final_points, current_combo])

func _is_within_acceptance_window(current_timestamp: float) -> bool:
	if recent_near_misses.is_empty():
		return true
	
	var last_miss_time = recent_near_misses[-1] 
	var time_since_last = current_timestamp - last_miss_time
	
	print("time since last near miss: %s seconds" % time_since_last)
	
	return time_since_last >= near_miss_acceptance_window

func _check_rate_limit(current_timestamp: float) -> bool:
	_cleanup_old_near_misses(current_timestamp)
	
	var recent_count = recent_near_misses.size()
	print("NearMissManager: Recent near misses in last second: ", recent_count)
	
	return recent_count < max_near_misses_per_second

func _cleanup_old_near_misses(current_timestamp: float):
	var cutoff_time = current_timestamp - 1.0  
	
	recent_near_misses = recent_near_misses.filter(func(timestamp): return timestamp > cutoff_time)

func _update_combo(current_timestamp: float):
	if current_timestamp - last_near_miss_time <= combo_window_time:
		current_combo += 1
		if current_combo == 2:
			combo_started.emit(current_combo)
	else:
		if current_combo > 1:
			combo_ended.emit(current_combo, 0) 
		current_combo = 1

func _dict_to_timestamp(time_dict: Dictionary) -> float:
	return time_dict.hour * 3600.0 + time_dict.minute * 60.0 + time_dict.second

func get_current_combo() -> int:
	return current_combo

func get_total_near_misses() -> int:
	return total_near_misses

func get_recent_near_miss_count() -> int:
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = _dict_to_timestamp(current_time)
	_cleanup_old_near_misses(current_timestamp)
	return recent_near_misses.size()

func test_register_near_miss():
	var fake_data = {"speed": 10.0, "position": Vector3.ZERO, "object": self}
	register_near_miss(fake_data)

func test_point_manager_connection():
	if point_manager:
		if point_manager.has_method("add_points"):
			point_manager.add_points(100, "test")
