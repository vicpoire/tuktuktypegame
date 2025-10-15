extends Node

@export var combo_manager: Node
@export var base_near_miss_points: int = 10
@export var speed_multiplier: float = 0.5
@export var cooldown_time: float = 0.5
@export var max_per_second: int = 3
@export var debug_output: bool = true

var total_near_misses: int = 0
var last_miss_time: float = 0.0
var misses_this_second: Array[float] = []

signal near_miss_registered(miss_data: Dictionary, points: int)
signal near_miss_rejected(reason: String)

func _ready():
	add_to_group("near_miss_manager")
	
func register_near_miss(miss_data: Dictionary) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# check cooldown
	if current_time - last_miss_time < cooldown_time:
		near_miss_rejected.emit("cooldown")
		return
	
	# check rate limit
	_cleanup_old_misses(current_time)
	if misses_this_second.size() >= max_per_second:
		near_miss_rejected.emit("rate_limited")
		return
	
	# calculate points
	var speed_bonus = int(miss_data.get("speed", 0.0) * speed_multiplier)
	var total_points = base_near_miss_points + speed_bonus
	
	# register with combo manager
	var final_points = total_points
	if combo_manager and combo_manager.has_method("on_near_miss"):
		final_points = combo_manager.on_near_miss(total_points)
	
	# update tracking
	last_miss_time = current_time
	misses_this_second.append(current_time)
	total_near_misses += 1
	
	# emit success
	var complete_data = miss_data.duplicate()
	complete_data["timestamp"] = current_time
	complete_data["total_count"] = total_near_misses
	near_miss_registered.emit(complete_data, final_points)

func _cleanup_old_misses(current_time: float) -> void:
	var cutoff = current_time - 1.0
	misses_this_second = misses_this_second.filter(func(t): return t > cutoff)

func get_total_near_misses() -> int:
	return total_near_misses

func get_recent_count() -> int:
	_cleanup_old_misses(Time.get_ticks_msec() / 1000.0)
	return misses_this_second.size()
