extends SaveToFiles


const PRINT_PROGRESS: bool = true

@export var spacing := Vector3(0.5, 0.5, 0.5)
@export var exponent: float = 0.5
@export var max_height: float = 0.0
@export var min_height: float = -10.0
@export var padding: Vector3i = Vector3i(8, 8, 8)
@export var fluff_multiplier: float = 10.0


func _ready() -> void:
	for child in get_children():
		if child.has_method(&"is_visible_in_tree") and not child.call(&"is_visible_in_tree"):
			return
	var mesh_node_3d: MeshInstance3D = search_hierarchy_for_single_3d_mesh_node()
	assert(mesh_node_3d != null)
	var base_path: String = mesh_node_3d.scene_file_path.get_basename()
	var mesh_3d_aabb: AABB = mesh_node_3d.mesh.get_aabb()
	var mesh_3d_extents: Vector3 = mesh_3d_aabb.position.abs().max(mesh_3d_aabb.end.abs())
	var grid_size: Vector3i = Vector3i((mesh_3d_extents * 2.0 / spacing).ceil()) + padding
	var grid_cell_count: int = grid_size.x * grid_size.y * grid_size.z
	print("Generating " + base_path.get_file() + " heightmap with grid size " + str(grid_size) + " which is " + str(grid_cell_count) + " grid cells or " + str(grid_cell_count * 5) + " tets.")
	var heightmap := HeightMapShape4D.new()
	heightmap.grid_spacing = spacing
	heightmap.grid_size = grid_size
	heightmap.fill_from_mesh_3d(mesh_node_3d.mesh, exponent, max_height, min_height)
	if PRINT_PROGRESS:
		print("Filled!")
	heightmap.gaussian_blur(Vector3(1.5, 1.5, 1.5))
	if PRINT_PROGRESS:
		print("Blurred!")
	heightmap.quantize_to_float16()
	if PRINT_PROGRESS:
		print("Quantized!")
	var mesh_4d: ArrayTetraMesh4D = heightmap.to_tetra_mesh()
	mesh_4d.is_mesh_data_valid()
	if PRINT_PROGRESS:
		print("Meshed!")
	fluff_ground_mesh_sides_massively(mesh_4d)
	if PRINT_PROGRESS:
		print("Fluffed!")
	heightmap.resource_name = base_path.get_file() + "_shape"
	mesh_4d.resource_name = base_path.get_file() + "_mesh"
	save_physics_shape_and_mesh_to_scene_and_g4mf(heightmap, mesh_4d, base_path)
	if PRINT_PROGRESS:
		print("Saved!")


func fluff_ground_mesh_sides_massively(tetra_mesh: ArrayTetraMesh4D) -> void:
	var verts: PackedVector4Array = tetra_mesh.vertices
	var texmap: PackedVector3Array = tetra_mesh.texture_map_values
	var max_vert: Vector4 = verts[verts.size() - 1]
	var min_vert: Vector4 = verts[0]
	var size_vec4: Vector4 = max_vert - min_vert
	var extent: float = maxf(size_vec4.x, maxf(size_vec4.z, size_vec4.w))
	var spatial_expand: float = extent * fluff_multiplier
	for i in range(verts.size()):
		var vert: Vector4 = verts[i]
		if vert.x <= min_vert.x:
			vert.x -= spatial_expand
		elif vert.x >= max_vert.x:
			vert.x += spatial_expand
		if vert.z <= min_vert.z:
			vert.z -= spatial_expand
		elif vert.z >= max_vert.z:
			vert.z += spatial_expand
		if vert.w <= min_vert.w:
			vert.w -= spatial_expand
		elif vert.w >= max_vert.w:
			vert.w += spatial_expand
		verts[i] = vert
	# When fluffing the texture map, fluff more on the axes which are spatially smaller.
	for i in range(texmap.size()):
		var texcoord: Vector3 = texmap[i]
		if texcoord.x <= 0.000001:
			texcoord.x -= fluff_multiplier * (extent / size_vec4.x)
		elif texcoord.x >= 0.999999:
			texcoord.x += fluff_multiplier * (extent / size_vec4.x)
		if texcoord.y <= 0.000001:
			texcoord.y -= fluff_multiplier * (extent / size_vec4.z)
		elif texcoord.y >= 0.999999:
			texcoord.y += fluff_multiplier * (extent / size_vec4.z)
		if texcoord.z <= 0.000001:
			texcoord.z -= fluff_multiplier * (extent / size_vec4.w)
		elif texcoord.z >= 0.999999:
			texcoord.z += fluff_multiplier * (extent / size_vec4.w)
		texmap[i] = texcoord
	verts = PackedVector4Array(Math4D.quantize_to_float16(verts))
	texmap = PackedVector3Array(Math4D.quantize_to_float16(texmap))
	tetra_mesh.vertices = verts
	tetra_mesh.texture_map_values = texmap
