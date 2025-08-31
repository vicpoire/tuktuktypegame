extends Node3D

@export var lights: Array[Light3D] = []
@export var flat_lights: Array[MeshInstance3D] = []

@export var trigger_area: Area3D 
@export var flicker_time: float = 0.5
@export var flicker_interval: float = 0.1
@export var light_color: Color = Color(1, 1, 1, 1) : set = set_light_color

var _flicker_timer: Timer
var _original_energy: Array[float] = []
var _original_flat_colors: Array[Color] = []
var _is_flickering := false

func _ready():
	# store original light energies + set initial color
	for light in lights:
		_original_energy.append(light.light_energy)
		light.light_color = light_color
	
	# store original flat_light colors
	for flat in flat_lights:
		var mat := flat.get_active_material(0)
		if mat and mat is StandardMaterial3D:
			_original_flat_colors.append(mat.albedo_color)
		else:
			_original_flat_colors.append(Color(1,1,1,1)) # fallback
	
	# flicker timer
	_flicker_timer = Timer.new()
	_flicker_timer.one_shot = false
	_flicker_timer.wait_time = flicker_interval
	add_child(_flicker_timer)
	_flicker_timer.timeout.connect(_on_flicker_timeout)
	
	# connect area signal
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)


func set_light_color(value: Color) -> void:
	light_color = value
	for light in lights:
		light.light_color = value
	# flat lights keep their base material color, so we don’t override here


func _on_body_entered(body: Node) -> void:
	if not _is_flickering:
		_is_flickering = true
		_flicker_timer.start()
		await get_tree().create_timer(flicker_time).timeout
		_flicker_timer.stop()
		_reset_lights()
		_is_flickering = false


func _on_flicker_timeout() -> void:
	# toggle real lights
	for light in lights:
		light.visible = not light.visible
	
	# toggle flat lights between base color and transparent
	for i in range(flat_lights.size()):
		var flat := flat_lights[i]
		var mat := flat.get_active_material(0)
		if mat and mat is StandardMaterial3D:
			var base_color := _original_flat_colors[i]
			if mat.albedo_color.a > 0.01:
				mat.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.0)
			else:
				mat.albedo_color = base_color


func _reset_lights() -> void:
	for i in range(lights.size()):
		lights[i].visible = true
		lights[i].light_energy = _original_energy[i]
	
	for i in range(flat_lights.size()):
		var mat := flat_lights[i].get_active_material(0)
		if mat and mat is StandardMaterial3D:
			mat.albedo_color = _original_flat_colors[i]
