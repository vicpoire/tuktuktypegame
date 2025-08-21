extends "res://.godot/editor/delivery_manager.gd"

# Existing timed delivery exports
@export var start_time: float = 30.0
@export var pickup_time_bonus: float = 5.0 
@export var time_label: Label
@export var points_label: Label
@export var countdown_timer: Timer

# New near miss related exports
@export var near_miss_label_scene: PackedScene  # Special scene for near miss points
@export var combo_label_scene: PackedScene     # Scene for combo notifications
@export var near_miss_parent: Node             # Parent node for near miss labels
@export var combo_parent: Node                 # Separate parent node for combo labels (NEW)

# Game state
var time_remaining: float
var total_points: int = 0
var game_active: bool = true

# Near miss tracking
var near_miss_points: int = 0

func _ready():
	print("Enhanced Point Manager: Starting up...")
	
	time_remaining = start_time
	update_time_label()
	update_points_label()
	
	if countdown_timer:
		countdown_timer.wait_time = 0.01 # ms precision
		countdown_timer.one_shot = false
		countdown_timer.start()
		countdown_timer.timeout.connect(_on_timer_timeout)
	
	# Add to point manager group for near miss system
	add_to_group("point_manager")
	print("Enhanced Point Manager: Added to point_manager group")
	
	super._ready()

func _on_timer_timeout():
	if game_active:
		time_remaining -= countdown_timer.wait_time
		if time_remaining <= 0:
			time_remaining = 0
			end_game()
		update_time_label()

func register_delivery(action_type: int, amount: int):
	if not game_active:
		return
		
	if action_type == 0: # pickup
		time_remaining += pickup_time_bonus * amount
	elif action_type == 1: # dropoff
		total_points += dropoff_points_per_box * amount
		update_points_label()
	
	super.register_delivery(action_type, amount)

# NEW: Add points method for near miss system
func add_points(points: int, source_type: String = ""):
	print("Enhanced Point Manager: Adding %d points from %s" % [points, source_type])
	
	if not game_active:
		print("Enhanced Point Manager: Game not active, ignoring points")
		return
		
	if source_type == "near_miss":
		near_miss_points += points
		print("Enhanced Point Manager: Near miss points now: ", near_miss_points)
		
		# Use special near miss label scene if available
		var point_scene = near_miss_label_scene if near_miss_label_scene else point_label_scene
		# Use dedicated near miss parent if available, otherwise use general point parent
		var parent_node = near_miss_parent if near_miss_parent else point_parent
		
		if point_scene and parent_node:
			print("Enhanced Point Manager: Creating near miss UI label")
			var point_label = point_scene.instantiate()
			var point_text = "Near Miss! +%d" % points
			
			if "set_log_text" in point_label:
				point_label.set_log_text(point_text)
			elif point_label is Label:
				point_label.text = point_text
			parent_node.add_child(point_label)
		else:
			print("Enhanced Point Manager: No point scene or parent assigned! Scene: ", point_scene != null, " Parent: ", parent_node != null)
	
	total_points += points
	print("Enhanced Point Manager: Total points now: ", total_points)
	update_points_label()

# DEBUG: Test method you can call from anywhere
func test_add_points():
	print("Enhanced Point Manager: Testing add points...")
	add_points(50, "near_miss")

# NEW: Handle combo notifications from near miss manager
func show_combo_notification(combo_count: int):
	if not game_active:
		return
	
	print("Enhanced Point Manager: Showing combo notification for x%d" % combo_count)
		
	var combo_scene = combo_label_scene if combo_label_scene else point_label_scene
	# Use dedicated combo parent if available, otherwise fall back to near miss parent, then general parent
	var parent_node = combo_parent if combo_parent else (near_miss_parent if near_miss_parent else point_parent)
	
	if combo_scene and parent_node:
		print("Enhanced Point Manager: Creating combo UI label in: ", parent_node.name)
		var combo_label = combo_scene.instantiate()
		var combo_text = "COMBO x%d!" % combo_count
		
		if "set_log_text" in combo_label:
			combo_label.set_log_text(combo_text)
		elif combo_label is Label:
			combo_label.text = combo_text
		parent_node.add_child(combo_label)
	else:
		print("Enhanced Point Manager: No combo scene or parent assigned! Scene: ", combo_scene != null, " Parent: ", parent_node != null)

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
	print("Game Over! Total Points: %d (Delivery: %d, Near Miss: %d)" % [total_points, total_points - near_miss_points, near_miss_points])

# NEW: Utility functions for other systems
func get_total_points() -> int:
	return total_points

func get_near_miss_points() -> int:
	return near_miss_points

func is_game_active() -> bool:
	return game_active
