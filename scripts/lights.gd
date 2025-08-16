extends Node3D

@export var lights_to_toggle: Array[Node3D]
var light_state := false

func _process(delta):
	if Input.is_action_just_pressed("lights"):
		toggle_lights()

	update_lights_visibility()

func toggle_lights():
	light_state = !light_state

func update_lights_visibility():
	for light in lights_to_toggle:
		light.visible = light_state
