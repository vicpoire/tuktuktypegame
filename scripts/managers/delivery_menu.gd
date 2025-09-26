extends Node

@export var drop_ui: Node
@export var drop_ui_animator: AnimationPlayer
@export var drop_ui_label: Label

var box_manager: Node = null

func _ready():
	if drop_ui.visible:
		drop_ui.visible = false
	
	add_to_group("delivery_manager")
	add_to_group("ui_manager") 
	box_manager = get_tree().get_first_node_in_group("box_manager")

func open_ui():
	toggle_drop_ui(true)
	drop_ui_animator.play("box_prompt_open")
	
func close_ui():
	drop_ui_animator.play("box_prompt_close")
	await get_tree().create_timer(1).timeout
	toggle_drop_ui(false)
	
func close_ui_after_input():
	drop_ui_animator.play("box_prompt_close_after_input")
	await get_tree().create_timer(1).timeout
	toggle_drop_ui(false)
	drop_ui_animator.play("RESET")
	
func change_text(newtext: String):
	drop_ui_label.text = newtext

func toggle_drop_ui(visible: bool):
	drop_ui.visible = visible
