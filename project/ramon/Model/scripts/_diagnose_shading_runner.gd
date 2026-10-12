extends SceneTree

## Checks whether smooth shading is actually reaching the mesh, and if so whether
## the material is set up to use it. Three separate things have to line up: the
## normals must be written, the per-cell-vertex indices must point at them, and the
## material's albedo/normal handling must not be overriding them.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var sections: Array = [
		{"center": Vector4(0, 0, 0, 0), "radius": 1.0, "v_scale": 1.0, "w_scale": 1.0},
		{"center": Vector4(0, 2, 0, 0), "radius": 1.2, "v_scale": 1.0, "w_scale": 1.0},
		{"center": Vector4(0, 4, 0, 0), "radius": 0.8, "v_scale": 1.0, "w_scale": 1.0},
	]
	for smooth in [false, true]:
		var mesh: ArrayTetraMesh4D = _Builder.build(sections, 6, 12, true, false, true, 1, smooth)
		print("smooth_shading=%-6s cells=%d  normal_values=%d  normal_indices=%d  boundary_normals=%d" % [
			smooth,
			mesh.get_simplex_cell_vertex_indices().size() / 4,
			mesh.get_normal_values().size(),
			mesh.get_simplex_cell_normal_indices().size(),
			mesh.get_simplex_cell_boundary_normals().size()])

	var rig: Node = _instance.get_node("Models/Brachio/Spine")
	print("rig smooth_shading = %s" % rig.smooth_shading)
	var live: ArrayTetraMesh4D = rig.mesh
	if live != null:
		print("live brachio mesh: normal_values=%d  normal_indices=%d" % [
			live.get_normal_values().size(), live.get_simplex_cell_normal_indices().size()])
	var material: Material4D = rig.material_override
	if material != null:
		print("material is %s, albedo_source=%s" % [material.get_class(), material.get("albedo_source")])
	return true
