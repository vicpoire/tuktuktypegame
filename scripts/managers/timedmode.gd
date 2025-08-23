extends "res://.godot/editor/delivery_manager.gd"

@export var start_time: float = 30.0
@export var pickup_time_bonus: float = 5.0 
@export var time_label: Label
@export var points_label: Label
@export var countdown_timer: Timer
@export var near_miss_label_scene: PackedScene 
@export var combo_label_scene: PackedScene 
@export var near_miss_parent: Node 
@export var combo_parent: Node

var time_remaining: float
var total_points: int = 0
var game_active: bool = true
var near_miss_points: int = 0
var combo_manager: ComboManager

func _ready():
	time_remaining = start_time
	update_time_label()
	update_points_label()
	
	if countdown_timer:
		countdown_timer.wait_time = 0.01 # ms precision
		countdown_timer.one_shot = false
		countdown_timer.start()
		countdown_timer.timeout.connect(_on_timer_timeout)
	
	add_to_group("point_manager")
	
	combo_manager = _find_combo_manager()
	if combo_manager:
		combo_manager.combo_achieved.connect(_on_combo_achieved)
		combo_manager.combo_broken.connect(_on_combo_broken)
	
	super._ready()

func _on_timer_timeout():
	if game_active:
		time_remaining -= countdown_timer.wait_time
		if time_remaining <= 0:
			time_remaining = 0
			end_game()
		update_time_label()

func _find_combo_manager() -> ComboManager:
	var possible_paths = [
		"ComboManager", 
		"../ComboManager",
		"../../ComboManager",
		"/root/ComboManager", 
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node and node is ComboManager:
			return node
	
	var combo_nodes = get_tree().get_nodes_in_group("combo_manager")
	if combo_nodes.size() > 0:
		return combo_nodes[0] as ComboManager
	
	return null

func register_delivery(action_type: int, amount: int):
	if not game_active:
		return
		
	if action_type == 0: # pickup
		time_remaining += pickup_time_bonus * amount
		if combo_manager:
			combo_manager.on_delivery_pickup(amount)
			
	elif action_type == 1: # dropoff
		total_points += dropoff_points_per_box * amount
		update_points_label()
		if combo_manager:
			combo_manager.on_delivery_dropoff(amount)
	
	super.register_delivery(action_type, amount)

func add_points(points: int, source_type: String = ""):
	var final_points = points
	
	if combo_manager and combo_manager.is_combo_active() and source_type != "combo":
		var multiplier = combo_manager.get_combo_multiplier()
		final_points = int(points * multiplier)
		
	if source_type == "near_miss":
		near_miss_points += final_points
		
		if combo_manager:
			combo_manager.on_near_miss()
		
		var point_scene = near_miss_label_scene if near_miss_label_scene else point_label_scene
		var parent_node = near_miss_parent if near_miss_parent else point_parent
		
		if point_scene and parent_node:
			var point_label = point_scene.instantiate()
			var point_text = "coming through! +%d" % final_points
			
			if "set_log_text" in point_label:
				point_label.set_log_text(point_text)
			elif point_label is Label:
				point_label.text = point_text
			parent_node.add_child(point_label)
	
	elif source_type == "combo":
		final_points = points
	
	total_points += final_points
	update_points_label()

func test_add_points():
	add_points(50, "near_miss")

func show_combo_notification(combo_count: int):
	if not game_active:
		return
		
	var combo_scene = combo_label_scene if combo_label_scene else point_label_scene
	var parent_node = combo_parent if combo_parent else (near_miss_parent if near_miss_parent else point_parent)
	
	if combo_scene and parent_node:
		var combo_label = combo_scene.instantiate()
		var combo_text = "COMBO x%d!" % combo_count
		
		if "set_log_text" in combo_label:
			combo_label.set_log_text(combo_text)
		elif combo_label is Label:
			combo_label.text = combo_text
		parent_node.add_child(combo_label)

func update_time_label():
	if time_label:
		var minutes = int(time_remaining / 60)
		var seconds = int(time_remaining) % 60
		var milliseconds = int((time_remaining - int(time_remaining)) * 1000)
		time_label.text = "%02d:%02d,%03d" % [minutes, seconds, milliseconds]

func update_points_label():
	if points_label:
		points_label.text = "points: %d" % total_points

func end_game():
	game_active = false
	if countdown_timer:
		countdown_timer.stop()
	
	if combo_manager:
		combo_manager.force_break_combo()
		
	print("gameover, total points: %d (delivery: %d, near miss: %d)" % [total_points, total_points - near_miss_points, near_miss_points])

func _on_combo_achieved(combo_count: int):
	print("combo achieved: x%d" % combo_count)

func _on_combo_broken():
	print("combo broken")

func on_collision():
	if combo_manager:
		combo_manager.on_collision()

func get_total_points() -> int:
	return total_points

func get_near_miss_points() -> int:
	return near_miss_points

func is_game_active() -> bool:
	return game_active

func get_combo_info() -> Dictionary:
	if not combo_manager:
		return {"active": false, "count": 0, "multiplier": 1.0, "time_left": 0.0}
	
	return {
		"active": combo_manager.is_combo_active(),
		"count": combo_manager.get_current_combo(),
		"multiplier": combo_manager.get_combo_multiplier(),
		"time_left": combo_manager.get_time_until_combo_break()
	}
