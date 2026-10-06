extends RefCounted

## The Voxel Lab's grid view (G, and part 2 of the block's story): a specimen's chunks wear a material
## that keeps their own colours and draws every voxel's edges, with a stronger line every 8 voxels,
## which are the engine's mesh chunks (shaders/vl_voxel_grid.gdshader).
##
## The colours come from the world's own palette texture, read off a chunk's mesh material (the
## world's material is not exposed to GDScript, its meshes' are), so the grid view shows exactly the
## colours the engine draws.
##
## apply(specimen, on)
##
## NO class_name (engine_gotchas.md).

const GridShader := preload("res://ramon/VoxelLab/shaders/vl_voxel_grid.gdshader")

static var _by_texture: Dictionary = {}


static func apply(specimen: Node, on: bool) -> void:
	if specimen == null:
		return
	if not on:
		specimen.call("set_chunk_material", null)
		return
	var tex: Texture3D = null
	for ch in specimen.call("chunk_nodes"):
		var mat: Resource = ((ch as MeshInstance4D).mesh as Mesh4D).get("material") if (ch as MeshInstance4D).mesh != null else null
		if mat is TetraMaterial4D:
			tex = mat.get("albedo_texture_3d")
			if tex != null:
				break
	if tex == null:
		return
	specimen.call("set_chunk_material", material_for(tex))


static func material_for(tex: Texture3D) -> TetraMaterial4D:
	var key: int = tex.get_instance_id()
	if _by_texture.has(key):
		return _by_texture[key]
	var m := TetraMaterial4D.new()
	m.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	# The shader before the texture: Material4D only assigns its built-in shader while the slot is
	# empty, and setting the texture re-runs the update that binds it (engine_gotchas.md).
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	cs.shader = GridShader
	m.albedo_texture_3d = tex
	_by_texture[key] = m
	return m
