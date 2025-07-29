extends Node3D

@export var box_scene: PackedScene
@export var anchor_point: Node3D
@export var box_spawn_offset := Vector3(0, 1, 0)

var boxes := []

func _ready():
	if not anchor_point:
		anchor_point = self
	


func add_box():
	var new_box: Node3D
	
	if box_scene:
		new_box = box_scene.instantiate()
	else:
		new_box = create_box_procedurally()
	
	add_child(new_box)
	
	if boxes.size() == 0:
		new_box.global_position = anchor_point.global_position + anchor_point.global_transform.basis * box_spawn_offset
	else:
		var last_box = boxes.back()
		new_box.global_position = last_box.global_position + Vector3.UP * 1.0
	
	boxes.append(new_box)

func create_box_procedurally() -> Node3D:
	var box = Node3D.new()
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE
	mesh_instance.mesh = box_mesh
	box.add_child(mesh_instance)
	
	return box
