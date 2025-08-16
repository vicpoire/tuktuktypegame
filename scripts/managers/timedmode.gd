extends "res://.godot/editor/delivery_manager.gd"

@export var start_time: float = 30.0
@export var pickup_time_bonus: float = 5.0 
@export var time_label: Label
@export var points_label: Label
@export var countdown_timer: Timer

var time_remaining: float
var total_points: int = 0
var game_active: bool = true

func _ready():
	time_remaining = start_time
	_update_time_label()
	_update_points_label()

	if countdown_timer:
		countdown_timer.wait_time = 0.01 # ms precision
		countdown_timer.one_shot = false
		countdown_timer.start()
		countdown_timer.timeout.connect(_on_timer_timeout)

	super._ready()

func _on_timer_timeout():
	if game_active:
		time_remaining -= countdown_timer.wait_time
		if time_remaining <= 0:
			time_remaining = 0
			_end_game()
		_update_time_label()

func register_delivery(action_type: int, amount: int):
	if not game_active:
		return

	if action_type == 0: # pickup
		time_remaining += pickup_time_bonus * amount

	elif action_type == 1: # dropoff
		total_points += dropoff_points_per_box * amount
		_update_points_label()

	super.register_delivery(action_type, amount)

func _update_time_label():
	if time_label:
		var minutes = int(time_remaining / 60)
		var seconds = int(time_remaining) % 60
		var milliseconds = int((time_remaining - int(time_remaining)) * 1000)
		time_label.text = "%02d:%02d,%03d" % [minutes, seconds, milliseconds]

func _update_points_label():
	if points_label:
		points_label.text = "points: %d" % total_points

func _end_game():
	game_active = false
	if countdown_timer:
		countdown_timer.stop()
