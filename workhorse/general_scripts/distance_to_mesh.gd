@tool
extends Node4D


@export var mesh_node: MeshInstance4D = null
@export var point_node: Node4D = null


func _process(_delta: float) -> void:
	if mesh_node == null or point_node == null:
		for child in get_children():
			if child is MeshInstance4D:
				mesh_node = child
			elif child is Node4D:
				point_node = child
	if mesh_node == null or point_node == null:
		return
	var tetra_mesh_4d := mesh_node.mesh as ArrayTetraMesh4D
	if tetra_mesh_4d == null:
		return
	print("Signed distance: ", tetra_mesh_4d.get_signed_distance_to_mesh(point_node.position))
