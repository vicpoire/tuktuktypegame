extends Node

@export var _car: Node3D

@export var idle_player: AudioStreamPlayer3D
@export var drive_player: AudioStreamPlayer3D
@export var rev_player: AudioStreamPlayer3D  # optional one-shot (can be null)

# tuning
@export_range(0.0, 1.0, 0.01) var start_drive_fade := 0.15  # when drive loop begins to fade in
@export var smoothing_time := 0.12
@export var min_pitch := 0.9
@export var max_pitch := 2.0
@export var idle_volume_db := -6.0
@export var drive_volume_db := 0.0
@export var silent_db := -40.0

# optional override for max speed (if you want a different value than car.max_speed)
@export var max_speed_override := 0.0  # 0 = use car.max_speed

# rev blip behavior
@export var rev_threshold := 0.6      # throttle intensity over which we might play a rev blip
@export var rev_cooldown := 0.35
@export var rev_volume_db := -3.0

# internal
var _smooth_speed: float = 0.0
var _prev_throttle: float = 0.0
var _time_since_rev: float = 1.0

func _ready() -> void:
	# try to find the car: prefer parent, then group "car"
	_car = get_parent()

	# safety checks
	if not idle_player or not drive_player:
		push_error("CarAudio: assign idle_player and drive_player in the inspector.")
		return

	# start players, but keep one effectively silent
	if not idle_player.playing:
		idle_player.play()
	if not drive_player.playing:
		drive_player.play()
	drive_player.volume_db = silent_db
	idle_player.volume_db = idle_volume_db
	idle_player.pitch_scale = min_pitch
	_smooth_speed = 0.0
	_prev_throttle = 0.0
	_time_since_rev = rev_cooldown

func _process(delta: float) -> void:
	if not _car:
		return

	_time_since_rev += delta

	# get speed and throttle (safe access)
	var speed: float = 0.0
	if "linear_velocity" in _car:
		speed = _car.linear_velocity.length()
	elif _car.has_method("get_current_speed"):
		speed = _car.get_current_speed()

	# determine max speed
	var max_speed: float = max_speed_override
	if max_speed <= 0.0 and ("max_speed" in _car):
		max_speed = _car.max_speed
	if max_speed <= 0.0:
		max_speed = 1.0

	# speed ratio 0..1
	var speed_ratio: float = clamp(speed / max_speed, 0.0, 1.0)

	# smooth the ratio so audio changes feel natural
	var alpha: float = 1.0 - exp(-delta / max(smoothing_time, 0.001))
	_smooth_speed = lerp(_smooth_speed, speed_ratio, alpha)

	# throttle (motor_input is a var on your RaycastCar; default to 0 if missing)
	var throttle: float = 0.0
	if "motor_input" in _car:
		throttle = float(_car.motor_input)
	elif _car.has_method("get"):
		if _car.has_meta("motor_input"):
			throttle = float(_car.get("motor_input"))

	_smooth_speed = 0.0

	# crossfade between idle and drive based on smoothed speed
	var drive_fade: float = smoothstep(start_drive_fade, 1.0, _smooth_speed)
	idle_player.volume_db = lerp(idle_volume_db, silent_db, drive_fade)
	drive_player.volume_db = lerp(silent_db, drive_volume_db, drive_fade)

	# pitch mapping: prefer non-linear mapping for better feel (square)
	var pitch_factor: float = lerp(min_pitch, max_pitch, pow(_smooth_speed, 0.9))
	idle_player.pitch_scale = pitch_factor * 0.85
	drive_player.pitch_scale = pitch_factor

	# optional rev blip when throttle suddenly increases
	if rev_player and _time_since_rev >= rev_cooldown:
		if throttle > _prev_throttle and throttle > 0.0 and _smooth_speed < 0.9 and speed > 1.0:
			if _smooth_speed > rev_threshold or abs(throttle - _prev_throttle) > 0.0:
				rev_player.volume_db = rev_volume_db
				rev_player.pitch_scale = clamp(1.0 + (_smooth_speed * 0.6), 0.8, 1.6)
				rev_player.play()
				_time_since_rev = 0.0

	_prev_throttle = throttle
