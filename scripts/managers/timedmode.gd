extends Node

@export var start_time: float = 30.0
@export var pickup_time_bonus: float = 5.0 
@export var time_label: Label
@export var points_label: Label
@export var countdown_timer: Timer
@export var near_miss_label_scene: PackedScene 
@export var combo_label_scene: PackedScene 
@export var near_miss_parent: Node 
@export var combo_parent: Node

@export var deliveries_count_label: Label
@export var current_boxes_label: Label3D
@export var log_label_scene: PackedScene   
@export var point_label_scene: PackedScene
@export var log_parent: Node 
@export var point_parent: Node 
@export var box_capacity: int = 3
@export var dropoff_points_per_box: int = 5 

@export_group("begining and end")
@export var start_screen: Node
@export var end_screen: Node

@export var time_before_starting: float

var time_remaining: float
var total_points: int = 0
var game_active: bool = false
var near_miss_points: int = 0
var combo_manager: ComboManager

var total_boxes_delivered := 0
var current_box_amount := 0

func _ready():
	
	time_remaining = start_time
	
	start_game()
	
	update_time_label()
	update_points_label()
	update_deliveries_label()
	update_current_boxes_label()
	
	
	add_to_group("point_manager")
	add_to_group("delivery_manager")
	
	combo_manager = _find_combo_manager()
	if combo_manager:
		combo_manager.combo_achieved.connect(_on_combo_achieved)
		combo_manager.combo_broken.connect(_on_combo_broken)
	

func _process(delta):
	if game_active:
		time_remaining -= delta
		if time_remaining <= 0:
			time_remaining = 0
			end_game()
		update_time_label()


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
	
	var log_text := ""
	
	if action_type == 0: # pickup
		if current_box_amount >= box_capacity:
			return # if truck full
		var actual_amount = min(amount, box_capacity - current_box_amount)
		current_box_amount += actual_amount
		log_text = "picked up %d box%s" % [actual_amount, "" if actual_amount == 1 else "es"]
		
		time_remaining += pickup_time_bonus * actual_amount
		if combo_manager:
			var final_points = combo_manager.on_delivery_pickup(0) 
			
	elif action_type == 1: # dropoff
		if current_box_amount <= 0:
			return # if truck empty
		var actual_amount = min(amount, current_box_amount)
		current_box_amount -= actual_amount
		total_boxes_delivered += actual_amount
		
		var base_points = dropoff_points_per_box * actual_amount
		var final_points = base_points
		if combo_manager:
			final_points = combo_manager.on_delivery_dropoff(base_points)
		
		total_points += final_points
		update_points_label()
		show_point_gain(final_points, actual_amount)
		update_deliveries_label()
	
	update_current_boxes_label()
	
	if log_text != "" and log_label_scene and log_parent:
		var new_label = log_label_scene.instantiate()
		if "set_log_text" in new_label:
			new_label.set_log_text(log_text)
		elif new_label is Label:
			new_label.text = log_text
		log_parent.add_child(new_label)

func add_points(points: int, source_type: String = ""):
	if not game_active:
		return
	
	var final_points = points
	
	if source_type == "near_miss":
		if combo_manager:
			final_points = combo_manager.on_near_miss(points)
		
		near_miss_points += final_points
		
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
	
	else:
		# For other point sources, let combo manager handle if applicable
		if combo_manager:
			# You can create specific methods for other point types
			# For now, treat as general points
			final_points = points  # Or handle through combo manager if needed
	
	total_points += final_points
	update_points_label()

func test_add_points():
	add_points(50, "near_miss")

func show_point_gain(points: int, boxes_delivered: int = 0):
	if point_label_scene and point_parent:
		var point_label = point_label_scene.instantiate()
		
		# If boxes_delivered is 0, calculate from points
		if boxes_delivered == 0:
			boxes_delivered = points / dropoff_points_per_box
		
		var point_text: String
		if boxes_delivered == 1:
			point_text = "delivery! +%d points" % points
		else:
			point_text = "delivery! +%d points" % points
		
		if "set_log_text" in point_label:
			point_label.set_log_text(point_text)
		elif point_label is Label:
			point_label.text = point_text
		point_parent.add_child(point_label)

func show_combo_notification(combo_count: int):
	if not game_active:
		return
		
	var combo_scene = combo_label_scene
	var parent_node = combo_parent if combo_parent else (near_miss_parent if near_miss_parent else point_parent)
	
	if combo_scene and parent_node:
		var combo_label = combo_scene.instantiate()
		var combo_text = "COMBO x%d!" % combo_count
		
		if "set_log_text" in combo_label:
			combo_label.set_log_text(combo_text)
		elif combo_label is Label:
			combo_label.text = combo_text
		parent_node.add_child(combo_label)

func find_label_in_children(node: Node) -> Label:
	if node is Label:
		return node
	
	for child in node.get_children():
		if child is Label:
			return child
		var found = find_label_in_children(child)
		if found:
			return found
	
	return null

func update_deliveries_label():
	if deliveries_count_label:
		deliveries_count_label.text = "boxes delivered: %d" % total_boxes_delivered

func update_current_boxes_label():
	if current_boxes_label:
		current_boxes_label.text = "%d - %d" % [current_box_amount, box_capacity]

func update_time_label():
	if time_label:
		var minutes = int(time_remaining / 60)
		var seconds = int(time_remaining) % 60
		var milliseconds = int((time_remaining - int(time_remaining)) * 1000)
		time_label.text = "%02d:%02d,%03d" % [minutes, seconds, milliseconds]

func update_points_label():
	if points_label:
		points_label.text = "points: %d" % total_points

func start_game():
	#if start_screen:
		#start_screen.update_label()
		#
	await get_tree().create_timer(time_before_starting).timeout
	game_active = true
	
func end_game():
	game_active = false
	if countdown_timer:
		countdown_timer.stop()
	
	if combo_manager:
		combo_manager.force_break_combo()
	
	if end_screen:
		end_screen.on_game_end()

func _on_combo_achieved(combo_count: int):
	print("combo achieved: x%d" % combo_count)
	show_combo_notification(combo_count)

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
