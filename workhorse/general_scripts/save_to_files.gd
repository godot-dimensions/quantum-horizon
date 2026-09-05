class_name SaveToFiles
extends Node


@export var save_to_binary_files: bool = true


func save_mesh_4d_to_scene_and_g4mf(mesh_4d: Mesh4D, base_path: String, base_name: String = "") -> void:
	if not mesh_4d.is_mesh_data_valid():
		printerr("Trying to save an invalid Mesh4D.")
		breakpoint
		return
	var folder: String = ProjectSettings.globalize_path(base_path.get_base_dir())
	var err: Error = DirAccess.make_dir_recursive_absolute(folder)
	assert(err == OK)
	var scene_ext: String = ".scn" if save_to_binary_files else ".tscn"
	var g4mf_ext: String = ".g4b" if save_to_binary_files else ".g4tf"
	if base_name.is_empty():
		base_name = base_path.get_file().to_pascal_case()
	if mesh_4d.resource_name.is_empty():
		mesh_4d.resource_name = base_name.to_snake_case() + "_mesh"
	# Save a Godot 3D mesh for the texture map.
	if mesh_4d is TetraMesh4D:
		var tex_map: ArrayMesh = mesh_4d.export_texture_map_mesh()
		ResourceSaver.save(tex_map, base_path + "_texmap.res")
	# Save a Godot PackedScene.
	var node := MeshInstance4D.new()
	node.name = base_name
	node.mesh = mesh_4d
	var packed_scene := PackedScene.new()
	packed_scene.pack(node)
	ResourceSaver.save(packed_scene, base_path + scene_ext)
	# Save a G4MF model.
	var g4mf_doc := G4MFDocument4D.new()
	var g4mf_state := G4MFState4D.new()
	g4mf_doc.export_append_from_godot_mesh(g4mf_state, mesh_4d)
	g4mf_doc.export_write_to_file(g4mf_state, base_path + g4mf_ext)


func save_mesh_inst_to_scene_and_g4mf(node: MeshInstance4D, base_path: String) -> void:
	var folder: String = ProjectSettings.globalize_path(base_path.get_base_dir())
	var err: Error = DirAccess.make_dir_recursive_absolute(folder)
	assert(err == OK)
	var scene_ext: String = ".scn" if save_to_binary_files else ".tscn"
	var g4mf_ext: String = ".g4b" if save_to_binary_files else ".g4tf"
	# Save a Godot 3D mesh for the texture map.
	var tetra_mesh: TetraMesh4D = node.mesh
	var tex_map: ArrayMesh = tetra_mesh.export_texture_map_mesh()
	ResourceSaver.save(tex_map, base_path + "_texmap.res")
	# Save a Godot PackedScene.
	var packed_scene := PackedScene.new()
	packed_scene.pack(node)
	ResourceSaver.save(packed_scene, base_path + scene_ext)
	# Save a G4MF model.
	var g4mf_doc := G4MFDocument4D.new()
	var g4mf_state := G4MFState4D.new()
	g4mf_doc.export_append_from_godot_scene(g4mf_state, node)
	g4mf_doc.export_write_to_file(g4mf_state, base_path + g4mf_ext)


func save_physics_shape_and_mesh_to_scene_and_g4mf(in_shape: Shape4D, in_mesh: Mesh4D, base_path: String, base_name: String = "") -> void:
	var folder: String = ProjectSettings.globalize_path(base_path.get_base_dir())
	var err: Error = DirAccess.make_dir_recursive_absolute(folder)
	assert(err == OK)
	var scene_ext: String = ".scn" if save_to_binary_files else ".tscn"
	var g4mf_ext: String = ".g4b" if save_to_binary_files else ".g4tf"
	var shape_resource: Shape4D = in_shape.duplicate(false)
	var mesh_resource: Mesh4D = in_mesh.duplicate(false)
	# Create a basic physics setup.
	var body_node := StaticBody4D.new()
	var collider_node := CollisionShape4D.new()
	var mesh_node := MeshInstance4D.new()
	# Set the names of everything.
	var base_file: String = base_path.get_file()
	if base_name.is_empty():
		base_name = base_file
	var pascal_name: String = base_name.to_pascal_case()
	var snake_name: String = base_name.to_snake_case()
	body_node.name = pascal_name + "Body"
	collider_node.name = pascal_name + "Collider"
	mesh_node.name = pascal_name + "Mesh"
	shape_resource.resource_name = snake_name + "_shape"
	mesh_resource.resource_name = snake_name + "_mesh"
	# Assign everything.
	collider_node.shape = shape_resource
	mesh_node.mesh = mesh_resource
	body_node.add_child(collider_node)
	body_node.add_child(mesh_node)
	collider_node.owner = body_node
	mesh_node.owner = body_node
	# Save a Godot 3D mesh for the texture map.
	if mesh_resource is TetraMesh4D:
		var tetra_mesh: TetraMesh4D = mesh_resource
		tetra_mesh.get_simplex_cell_vertex_indices()
		#tetra_mesh.get_simplex_cell_boundary_normals()
		#tetra_mesh.get_normal_values()
		var tex_map: ArrayMesh = tetra_mesh.export_texture_map_mesh()
		ResourceSaver.save(tex_map, base_path + "_texmap.res")
	# Save a Godot PackedScene.
	var packed_scene := PackedScene.new()
	packed_scene.pack(body_node)
	ResourceSaver.save(packed_scene, base_path + scene_ext)
	# Save a G4MF model.
	var g4mf_doc := G4MFDocument4D.new()
	var g4mf_state := G4MFState4D.new()
	g4mf_doc.export_append_from_godot_scene(g4mf_state, body_node)
	g4mf_doc.export_write_to_file(g4mf_state, base_path + g4mf_ext)


func load_as_array_mesh_3d(path: String) -> ArrayMesh:
	var res: Resource = ResourceLoader.load(path)
	if res is ArrayMesh:
		return res
	if res is PackedScene:
		var packed_scene := res as PackedScene
		var node: Node = packed_scene.instantiate()
		while node != null:
			if node is MeshInstance3D:
				var mesh_3d: ArrayMesh = node.mesh as ArrayMesh
				if mesh_3d != null:
					return mesh_3d
			node = node.get_child(0)
	printerr("Unhandled type of resource.")
	breakpoint
	return null


func load_as_array_poly_mesh_4d(path: String) -> ArrayPolyMesh4D:
	var res: Resource = ResourceLoader.load(path)
	if res is ArrayPolyMesh4D:
		return res
	if res is PackedScene:
		var packed_scene := res as PackedScene
		var node: Node = packed_scene.instantiate()
		while node != null:
			if node is MeshInstance3D:
				var mesh_3d: Mesh = node.mesh
				return PolyMeshBuilder4D.convert_mesh_3d_to_4d_faces_only(mesh_3d)
			if node is MeshInstance4D:
				var mesh_4d: Mesh4D = node.mesh
				if mesh_4d is ArrayPolyMesh4D:
					return mesh_4d
				elif mesh_4d is TetraMesh4D:
					return PolyMeshBuilder4D.reconstruct_from_tetra_mesh(mesh_4d)
			node = node.get_child(0)
	printerr("Unhandled type of resource.")
	breakpoint
	return null


func search_hierarchy_for_single_3d_mesh_node() -> MeshInstance3D:
	var this = self
	if this is MeshInstance3D:
		if this.mesh is ArrayMesh:
			return this
	var mesh_3d_nodes: Array[Node] = find_children("*", "MeshInstance3D", true, true)
	for node in mesh_3d_nodes:
		var this_node_3d: MeshInstance3D = node as MeshInstance3D
		var this_mesh_3d: ArrayMesh = this_node_3d.mesh as ArrayMesh
		if this_mesh_3d != null:
			return this_node_3d
	return null
