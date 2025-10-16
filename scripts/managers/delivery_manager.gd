extends Node

@export var car: Node
@export var start_time: float = 30.0
@export var time_frozen: bool

@export var pickup_time_bonus: float = 5.0 
@export var time_label: Label
@export var points_label: Label
@export var per_delivery_time_label: Label
@export var stacked_points_label: Label

@export var countdown_timer: Timer
@export var per_delivery_countdown_timer: Timer

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
@export var delivery_time_limit: float = 45.0
@export var timer_animation_player: AnimationPlayer

@export_group("begining and end")
@export var start_screen: Node
@export var end_screen: Node

@export var time_before_starting: float
@export var play_intro: bool

var time_remaining: float
var total_points: int = 0
var game_active: bool = false
var near_miss_points: int = 0
var combo_manager: ComboManager
var box_manager: Node

var total_boxes_delivered := 0
var current_box_amount := 0
var stacked_delivery_points := 0  # points earned while holding boxes

func _ready():
	if not car:
		car = get_node("../Car")

	box_manager = car.get_node("Trunk/TrunkManager/BOXES")
	time_remaining = start_time
	
	start_game()
	
	update_time_label()
	update_points_label()
	update_deliveries_label()
	update_current_boxes_label()
	#update_per_delivery_time_label(0)

	add_to_group("point_manager")
	add_to_group("delivery_manager")
	
	combo_manager = $ComboManager
	if combo_manager:
		combo_manager.combo_achieved.connect(_on_combo_achieved)
		combo_manager.combo_broken.connect(_on_combo_broken)
		combo_manager.point_scored.connect(_on_combo_point_scored)
	
	if per_delivery_countdown_timer:
		per_delivery_countdown_timer.one_shot = true
		per_delivery_countdown_timer.timeout.connect(_on_per_delivery_timer_timeout)

func _on_combo_point_scored(point_type: String, amount: int):
	if not game_active:
		return
	
	# if holding boxes stack the points otherwise add directly
	if current_box_amount > 0:
		stacked_delivery_points += amount
		update_stacked_points_label()
		trigger_stacked_points_animation(2)
		
	else:
		total_points += amount
	
	update_points_label()
	
	if point_type == "coming through":
		near_miss_points += amount
		
		var point_scene = near_miss_label_scene if near_miss_label_scene else point_label_scene
		var parent_node = near_miss_parent if near_miss_parent else point_parent
		
		if point_scene and parent_node:
			var point_label = point_scene.instantiate()
			var point_text = "coming through! +%d" % amount
			
			if "set_log_text" in point_label:
				point_label.set_log_text(point_text)
			elif point_label is Label:
				point_label.text = point_text
			parent_node.add_child(point_label)

# let combo manager handle
func add_points(points: int, source_type: String = ""):
	if not game_active:
		return
	
	if source_type == "near_miss":
		return
	
	var final_points = points
	if combo_manager and source_type != "combo":
		pass
	
	# if holding boxes stack points otherwise add directly
	if current_box_amount > 0:
		stacked_delivery_points += final_points
		update_stacked_points_label()
	else:
		total_points += final_points
	
	update_points_label()

func _process(delta):
	if Input.is_action_pressed("toggle_time"):
		time_frozen = !time_frozen
	if Input.is_action_pressed("end_timer"):
		time_remaining = -1
	
	if game_active and !time_frozen:
		time_remaining -= delta
		if time_remaining <= 0:
			time_remaining = 0
			end_game()
		update_time_label()
		
		if per_delivery_countdown_timer and per_delivery_countdown_timer.time_left > 0:
			update_per_delivery_time_label(per_delivery_countdown_timer.time_left)
		else:
			update_per_delivery_time_label(0)

func _on_timer_timeout():
	if game_active:
		time_remaining -= countdown_timer.wait_time
		if time_remaining <= 0:
			time_remaining = 0
			end_game()
		update_time_label()

func apply_delivery_multiplier(base_points: int) -> int:
	var multiplied_points = base_points
	
	# Apply combo multiplier if active
	if combo_manager and combo_manager.is_combo_active():
		multiplied_points = int(multiplied_points * combo_manager.get_combo_multiplier())
	
	# Apply any other multipliers here
	# multiplied_points = int(multiplied_points * some_other_multiplier)
	
	return multiplied_points

func register_delivery(action_type: int, amount: int):
	if not game_active:
		return
	
	var log_text := ""
	
	if action_type == 0: # pickup
		
		if current_box_amount == 0:  # just started carrying boxes
			trigger_stacked_points_animation(1)
			
		if current_box_amount >= box_capacity:
			return # if truck full
			
		var actual_amount = min(amount, box_capacity - current_box_amount)
		current_box_amount += actual_amount
		log_text = "picked up %d box%s" % [actual_amount, "" if actual_amount == 1 else "es"]
		
		time_remaining += pickup_time_bonus * actual_amount

		# add proportional time (no reset, deltime limit / box picked up)
		if per_delivery_countdown_timer:
			var per_box_time = delivery_time_limit / float(box_capacity)
			var added_time = per_box_time * actual_amount
			var new_time_left = per_delivery_countdown_timer.time_left + added_time
			
			var was_inactive := per_delivery_countdown_timer.time_left <= 0 or not per_delivery_countdown_timer.is_stopped()
			
			per_delivery_countdown_timer.stop()
			per_delivery_countdown_timer.wait_time = new_time_left
			update_per_delivery_time_label(new_time_left)
			per_delivery_countdown_timer.start()
			per_delivery_countdown_timer.paused = true
			
			if was_inactive:
				timer_animation_player.play("open_timer")
			else:
				timer_animation_player.play("time_added")
			
			await get_tree().create_timer(0.75).timeout
			per_delivery_countdown_timer.paused = false

		if combo_manager:
			var _final_points = combo_manager.on_delivery_pickup(0) 
	
	elif action_type == 1: # dropoff
		if current_box_amount <= 0:
			return # if truck empty
		var actual_amount = min(amount, current_box_amount)
		current_box_amount -= actual_amount
		total_boxes_delivered += actual_amount
		
		if timer_animation_player:
			timer_animation_player.play("close_timer")
		
		if box_manager:
			var count = box_manager.get_current_box_count()
			for i in range(actual_amount): # remove only the delivered boxes
				box_manager.remove_box()
		
		if per_delivery_countdown_timer:
			per_delivery_countdown_timer.stop()
			update_per_delivery_time_label(0)
		
		# Combine base delivery points with stacked points
		var base_points = dropoff_points_per_box * actual_amount
		var combined_points = base_points + stacked_delivery_points
		var final_points = apply_delivery_multiplier(combined_points)
		
		total_points += final_points
		stacked_delivery_points = 0

		trigger_stacked_points_animation(3)
		update_stacked_points_label()
		update_points_label()
		update_deliveries_label()
	
	update_current_boxes_label()

func _on_per_delivery_timer_timeout():
	print("delivery timer expired")
	timer_animation_player.play("close_timer")
	
	var count = box_manager.get_current_box_count()
	for i in range(count):
		box_manager.remove_box()
	
	# lose stacked points if delivery times out
	current_box_amount = 0
	stacked_delivery_points = 0
	update_stacked_points_label()
	trigger_stacked_points_animation(4)
	
	if current_box_amount > 0:
		update_stacked_points_label()

func show_combo_notification(combo_count: int):
	if not game_active:
		return
		
	var combo_scene = combo_label_scene
	var parent_node = combo_parent if combo_parent else (near_miss_parent if near_miss_parent else point_parent)
	
	if combo_scene and parent_node:
		var combo_label = combo_scene.instantiate()
		var combo_text = "COMBO x%d!" % combo_count

func update_deliveries_label():
	if deliveries_count_label:
		deliveries_count_label.text = "boxes delivered: %d" % total_boxes_delivered

func update_current_boxes_label():
	if current_boxes_label:
		current_boxes_label.text = "%d - %d" % [current_box_amount, box_capacity]

# for global timer label
func update_time_label():
	if time_label:
		var minutes = int(time_remaining / 60)
		var seconds = int(time_remaining) % 60
		var milliseconds = int((time_remaining - int(time_remaining)) * 1000)
		time_label.text = "%02d:%02d,%03d" % [minutes, seconds, milliseconds]

func update_stacked_points_label():
	if stacked_points_label:
		stacked_points_label.visible = current_box_amount > 0
		stacked_points_label.text = "delivery points: %d" % stacked_delivery_points


func trigger_stacked_points_animation(anim_type: int):
	match anim_type:
		1:
			# started a new delivery
			# TODO: maybe fade in or slide-in animation
			pass
		2:
			# gained stacked points while carrying boxes
			# TODO: pulse or bounce effect
			pass
		3:
			# delivered boxes 
			# TODO: fade-out or burst animation
			pass
		4:
			# delivery timed out stacked points lost
			# TODO: flash red or shake effect
			pass

	
# for per-delivery timer label
func update_per_delivery_time_label(time_left: float):
	if per_delivery_time_label:
		var seconds = int(time_left)
		var milliseconds = int((time_left - seconds) * 100)
		per_delivery_time_label.text = "%02d,%02d" % [seconds, milliseconds]

func update_points_label():
	if points_label:
		points_label.text = "points: %d" % total_points

func start_game():
	if play_intro:
		await get_tree().create_timer(time_before_starting).timeout
	game_active = true

func end_game():
	game_active = false
	if countdown_timer:
		countdown_timer.stop()
	if per_delivery_countdown_timer:
		per_delivery_countdown_timer.stop()
	
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
