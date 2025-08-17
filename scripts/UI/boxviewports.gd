extends SubViewport

@onready var box_mesh: MeshInstance3D = $Node3D/MeshParent/BOX2

@export var box_mesh_paths: Array[String] = [
	"res://3d/meshes/box1mesh.tres",
	"res://3d/meshes/box2mesh.tres"
	] 

func set_box(mesh_index: int):
	if mesh_index >= 0 and mesh_index < box_mesh_paths.size():
		var mesh_res: Mesh = load(box_mesh_paths[mesh_index])
		if mesh_res:
			box_mesh.mesh = mesh_res
			box_mesh.visible = true
		else:
			box_mesh.visible = false
	else:
		box_mesh.visible = false

func _process(delta):
	if box_mesh.visible:
		box_mesh.rotate_y(delta)
