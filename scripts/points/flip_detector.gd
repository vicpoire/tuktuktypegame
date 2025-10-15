extends Node

@export var car: RigidBody3D
@export var min_air_time:= 0.3
@export var rotation_threshold:= 360.0
@export var backflip_points:= 50
@export var frontflip_points:= 60
@export var sideflip_points:= 30


var is_airborne:= false
var air_time:= 0.0
var last_rotation: Basis
var accumulated_rotation:= Vector3.ZERO

var front_flips:= 0
var back_flips:= 0
var left_flips:= 0
var right_flips:= 0

var first_flip_done := false

var combo_manager : Node

func _ready():
	if not car:
		car = $".."
	if not combo_manager:
		combo_manager = get_tree().get_first_node_in_group("combo_manager")

func _physics_process(delta):
	if not car:
		return
	
	if _is_grounded():
		if is_airborne:
			_end_airtime()
	else:
		if not is_airborne:
			_start_airtime()
		air_time += delta
		_track_rotation()

func _is_grounded() -> bool:
	if "get_wheels" in car:
		for wheel in car.get_wheels():
			if wheel.is_colliding():
				return true
	return false

func _start_airtime():
	is_airborne = true
	air_time = 0.0
	accumulated_rotation = Vector3.ZERO
	last_rotation = car.global_transform.basis
	first_flip_done = false  # Reset for this airtime

func _end_airtime():
	is_airborne = false
	if air_time >= min_air_time:
		_report_flips()
	_reset_air_data()

func _track_rotation():
	var current_basis = car.global_transform.basis
	var delta_basis = last_rotation.inverse() * current_basis
	var delta_euler = delta_basis.get_euler() * 180 / PI  # convert to degrees
	last_rotation = current_basis
	
	accumulated_rotation += delta_euler

	# first flip uses rotation_threshold then 360 for when flipping up a ramp or something
	var threshold = rotation_threshold if not first_flip_done else 360.0

	# front/back flips
	if abs(accumulated_rotation.x) >= threshold:
		if accumulated_rotation.x > 0:
			back_flips += 1
			if combo_manager:
				combo_manager.on_back_flip(backflip_points)
		else:	
			front_flips += 1
			if combo_manager:
				combo_manager.on_front_flip(frontflip_points)
		accumulated_rotation.x = 0
		first_flip_done = true

	# left/right flips
	if abs(accumulated_rotation.z) >= threshold:
		if accumulated_rotation.z > 0:
			right_flips += 1
			if combo_manager:
				combo_manager.on_side_flip(sideflip_points)
		else:
			left_flips += 1
			if combo_manager:
				combo_manager.on_side_flip(sideflip_points)
		accumulated_rotation.z = 0
		first_flip_done = true

func _report_flips():
	print("flip report:")
	if front_flips: print("front:", front_flips)
	if back_flips: print("back:", back_flips)
	if left_flips: print("left:", left_flips)
	if right_flips: print("right:", right_flips)

func _reset_air_data():
	front_flips = 0
	back_flips = 0
	left_flips = 0
	right_flips = 0
	accumulated_rotation = Vector3.ZERO
