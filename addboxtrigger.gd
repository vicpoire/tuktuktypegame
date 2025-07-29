extends Area3D

@export var is_add_trigger := true

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name != "Car":
		return
	
	#if is_add_trigger:
		#BoxPilerManager.add_box()
	#else:
		#BoxPilerManager.remove_box()
