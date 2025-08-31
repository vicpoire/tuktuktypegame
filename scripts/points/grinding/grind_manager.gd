extends Node

@export var point_manager: Node
@export var base_grind_points: int = 25
@export var duration_multiplier: float = 10.0  # Points per second of grinding
@export var speed_multiplier: float = 1.0
@export var grind_acceptance_window: float = 1.0  # Time between grinds
@export var max_grinds_per_second: int = 2

var total_grinds: int = 0
var recent_grinds: Array[float] = []
var longest_grind_duration: float = 0.0
var total_grind_time: float = 0.0

signal grind_registered(grind_data: Dictionary, points_awarded: int)
signal grind_rejected(reason: String)

func _ready():
	add_to_group("grinding_manager")
	print("Grinding Manager ready with %.1f second acceptance window" % grind_acceptance_window)

func register_grind(grind_data: Dictionary):
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = _dict_to_timestamp(current_time)
	
	print("Grind attempt at timestamp: %.2f" % current_timestamp)
	
	# Check acceptance window
	if not _is_within_acceptance_window(current_timestamp):
		print("Grind rejected - outside time window")
		grind_rejected.emit("outside_time_window")
		return
	
	# Check rate limit
	if not _check_rate_limit(current_timestamp):
		print("Grind rejected - rate limited")
		grind_rejected.emit("rate_limited")
		return
	
	print("Grind accepted!")
	
	recent_grinds.append(current_timestamp)
	
	# Calculate points
	var base_points = base_grind_points
	var duration_bonus = int(grind_data.duration * duration_multiplier)
	var speed_bonus = int(grind_data.average_speed * speed_multiplier)
	var total_base_points = base_points + duration_bonus + speed_bonus
	
	# Track stats
	total_grinds += 1
	total_grind_time += grind_data.duration
	if grind_data.duration > longest_grind_duration:
		longest_grind_duration = grind_data.duration
	
	# Send to point manager
	if point_manager and point_manager.has_method("add_points"):
		point_manager.add_points(total_base_points, "grind")
	
	# Prepare complete data
	var complete_grind_data = grind_data.duplicate()
	complete_grind_data["base_points"] = total_base_points
	complete_grind_data["duration_bonus"] = duration_bonus
	complete_grind_data["speed_bonus"] = speed_bonus
	complete_grind_data["total_grinds"] = total_grinds
	complete_grind_data["timestamp"] = current_timestamp
	
	grind_registered.emit(complete_grind_data, total_base_points)
	
	print("Grind registered - Duration: %.2fs, Speed: %.1f, Points: %d (base:%d + duration:%d + speed:%d)" % [
		grind_data.duration, grind_data.average_speed, total_base_points, base_points, duration_bonus, speed_bonus
	])

func _is_within_acceptance_window(current_timestamp: float) -> bool:
	if recent_grinds.is_empty():
		return true
	
	var last_grind_time = recent_grinds[-1]
	var time_since_last = current_timestamp - last_grind_time
	
	print("Time since last grind: %.2f seconds" % time_since_last)
	
	return time_since_last >= grind_acceptance_window

func _check_rate_limit(current_timestamp: float) -> bool:
	_cleanup_old_grinds(current_timestamp)
	
	var recent_count = recent_grinds.size()
	print("GrindingManager: Recent grinds in last second: %d" % recent_count)
	
	return recent_count < max_grinds_per_second

func _cleanup_old_grinds(current_timestamp: float):
	var cutoff_time = current_timestamp - 1.0
	recent_grinds = recent_grinds.filter(func(timestamp): return timestamp > cutoff_time)

func _dict_to_timestamp(time_dict: Dictionary) -> float:
	return time_dict.hour * 3600.0 + time_dict.minute * 60.0 + time_dict.second

func get_total_grinds() -> int:
	return total_grinds

func get_longest_grind_duration() -> float:
	return longest_grind_duration

func get_total_grind_time() -> float:
	return total_grind_time

func get_average_grind_duration() -> float:
	if total_grinds == 0:
		return 0.0
	return total_grind_time / total_grinds

func get_recent_grind_count() -> int:
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = _dict_to_timestamp(current_time)
	_cleanup_old_grinds(current_timestamp)
	return recent_grinds.size()

func test_register_grind():
	var fake_data = {
		"object": self,
		"duration": 2.5,
		"average_speed": 15.0,
		"current_speed": 12.0,
		"start_speed": 18.0,
		"position": Vector3.ZERO,
		"start_position": Vector3(0, 0, -5),
		"car_velocity": Vector3(0, 0, 15),
		"wheels_touching": 0
	}
	register_grind(fake_data)

func test_point_manager_connection():
	if point_manager:
		if point_manager.has_method("add_points"):
			point_manager.add_points(100, "grind_test")
			print("Test grind points sent to point manager")
		else:
			print("Point manager doesn't have add_points method")
	else:
		print("No point manager assigned")
