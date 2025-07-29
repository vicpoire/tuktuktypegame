extends Control

@export var speed_text: Label

var car: Node = null

func _ready():
	car = get_node("../Car")
	_modify_speed_text()

func _process(delta):
	_modify_speed_text()

func _modify_speed_text():
	if car and speed_text:
		var speed: float = car.get_current_speed()
		speed_text.text = "speed: %d" % round(car.get_current_speed())
