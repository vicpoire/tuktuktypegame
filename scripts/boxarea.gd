extends Area3D

@export_enum("pickup", "dropoff") var action_type := 0
@export var amount: int = 1
@export var cooldown_time = 1.0
@export var pickup_color: Color = Color(0, 210, 0, 0)
@export var color_lerp_speed = 7.5
@export var light_to_disable: SpotLight3D
@export var light_flare_time = 0.15 
@export var light_flare_down_time = 0.05 

var on_cooldown := false
var is_flaring := false
var player_in_zone := false
var car_body = null
var box_manager = null
var delivery_manager = null
var ui_manager = null 
var _visuals: Node = null
var original_colors: Dictionary = {}
var current_colors: Dictionary = {}
var target_colors: Dictionary = {}

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	box_manager = get_tree().get_first_node_in_group("box_manager")
	delivery_manager = get_tree().get_first_node_in_group("delivery_manager")
	ui_manager = get_tree().get_first_node_in_group("ui_manager") 
	_visuals = find_child("Visuals", true, false)
	if _visuals:
		for child in _visuals.get_children():
			if has_modulate(child):
				original_colors[child] = child.modulate
				current_colors[child] = child.modulate
				target_colors[child] = child.modulate
func _process(delta: float):
	# Handle color transitions
	if _visuals:
		for child in current_colors.keys():
			if is_instance_valid(child):
				current_colors[child] = current_colors[child].lerp(target_colors[child], delta * color_lerp_speed)
				child.modulate = current_colors[child]
	
	if player_in_zone and not on_cooldown and Input.is_action_just_pressed("box_input"):
		if ui_manager:
			ui_manager.close_ui_after_input()
		handle_delivery_action()
func _on_body_entered(body):
	if on_cooldown or not box_manager:
		return
	
	var current = body
	while current != null and is_instance_valid(current):
		if current.is_in_group("car"):
			player_in_zone = true
			car_body = current
			show_ui_prompt()
			return
		current = current.get_parent()
func _on_body_exited(body):
	var current = body
	while current != null and is_instance_valid(current):
		if current.is_in_group("car"):
			player_in_zone = false
			car_body = null
			hide_ui_prompt() 
			return
		current = current.get_parent()
func handle_delivery_action():
	if not player_in_zone or on_cooldown or not box_manager:
		return
		
	var boxes_affected := 0  
	
	if action_type == 0: # pickup
		for i in range(amount):
			if box_manager.is_full():
				break
			box_manager.add_box()
			boxes_affected += 1
	elif action_type == 1: # dropoff
		for i in range(amount):
			if box_manager.is_empty():
				break
			box_manager.remove_box()
			boxes_affected += 1
	
	if boxes_affected > 0:
		if delivery_manager:
			delivery_manager.register_delivery(action_type, boxes_affected)
		start_cooldown()

# Added these two functions
func show_ui_prompt():
	if ui_manager and box_manager:
		var prompt_text = ""
		if action_type == 0: # pickup
			if box_manager.is_full():
				prompt_text = "truck is full!"
			else:
				prompt_text = "pick up!"
		else: # dropoff
			if box_manager.is_empty():
				prompt_text = "no boxes to deliver!"
			else:
				prompt_text = "deliver!"
		
		ui_manager.change_text(prompt_text)
		ui_manager.open_ui()

func hide_ui_prompt():
	if ui_manager:
		ui_manager.close_ui()

func start_cooldown():
	on_cooldown = true
	
	if light_to_disable:
		var original_energy = light_to_disable.light_energy
		var flared_energy = original_energy * 3.0
		
		light_to_disable.light_energy = flared_energy
		await get_tree().create_timer(light_flare_time).timeout
		
		var tween = create_tween()
		tween.tween_method(
			func(energy): light_to_disable.light_energy = energy,
			flared_energy,
			0.0,
			light_flare_down_time
		)
		await tween.finished
		
		light_to_disable.visible = false
		light_to_disable.light_energy = original_energy
	
	if action_type == 0 and _visuals:
		for child in target_colors.keys():
			if is_instance_valid(child):
				target_colors[child] = pickup_color
	
	await get_tree().create_timer(cooldown_time).timeout
	on_cooldown = false
	
	if light_to_disable:
		light_to_disable.visible = true
	if action_type == 0 and _visuals:
		for child in target_colors.keys():
			if is_instance_valid(child):
				target_colors[child] = original_colors[child]
func has_modulate(o: Object) -> bool:
	for p in o.get_property_list():
		if p.get("name") == "modulate":
			return true
	return false
