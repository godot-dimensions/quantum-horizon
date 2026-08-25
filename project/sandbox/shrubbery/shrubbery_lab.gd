extends Node4D
## Root node for the shrubbery lab scene - owns the current
## ShrubSpecies4D config and the live ShrubInstance4D, exposing simple
## methods shrubbery_lab_controller.gd calls to tweak parameters and
## regenerate. A dedicated scene for testing/tweaking the shrub
## generation algorithm in isolation - NOT the motion-lab scene (that
## one's Player/HUD/controls are specific to the creature/gait system
## and shouldn't be repurposed for unrelated work).

var species: ShrubSpecies4D = ShrubSpecies4D.new()
## Toggle between the fast direct "one box per voxel" builder and the
## smooth marching-tetrahedra one - see shrub_mesh_builder_blocky.gd's
## and shrub_mesh_builder.gd's own headers for the full comparison.
## WARNING: the smooth builder measured 172s to mesh a tiny 75-voxel
## shrub - switching to it with anything but a very small
## iterations/attractor_count will freeze this scene for a long time
## (GDScript is single-threaded; regenerate() runs synchronously).
var use_blocky_builder: bool = true

## Metrics from the most recent regenerate() call, for the controller's
## HUD - not part of species (species is config; this is a result).
var last_voxel_count: int = 0
var last_tet_count: int = 0
var last_elapsed_sec: float = 0.0

var _shrub: ShrubInstance4D = null


func _ready() -> void:
	regenerate()


## Builds separate wood/leaf meshes directly (not via
## ShrubInstance4D.generate(), which always uses the fast blocky builder)
## so the B toggle here can still compare against the smooth builder for
## experimentation - see shrub_mesh_builder_blocky.gd's own
## voxel_id_filter comment for why two meshes/materials are needed for
## more than one flat color at all.
func regenerate() -> void:
	if _shrub != null:
		_shrub.free()
		_shrub = null

	var t0 := Time.get_ticks_usec()
	var generator := ShrubGenerator4D.new(species.seed)
	generator.build_trunk(species)
	generator.spawn_attractors_from_tesseract(species)
	generator.grow(species)
	print("grow() done: branches=%d elapsed=%.3fs" % [generator.branches.size(), (Time.get_ticks_usec() - t0) / 1_000_000.0])
	var t1 := Time.get_ticks_usec()
	var voxels: Dictionary = generator.voxelize(species)
	last_voxel_count = voxels.size()
	print("voxelize() done: voxels=%d elapsed=%.3fs" % [voxels.size(), (Time.get_ticks_usec() - t1) / 1_000_000.0])

	var start_usec := Time.get_ticks_usec()
	var wood_mesh: ArrayTetraMesh4D
	var leaf_mesh: ArrayTetraMesh4D
	if use_blocky_builder:
		var meshes: Dictionary = ShrubMeshBuilderBlocky4D.build_meshes(voxels, species)
		wood_mesh = meshes[ShrubGenerator4D.VOXEL_ID_WOOD]
		leaf_mesh = meshes[ShrubGenerator4D.VOXEL_ID_LEAF]
	else:
		wood_mesh = ShrubMeshBuilder4D.build_mesh(voxels, species)
		leaf_mesh = ArrayTetraMesh4D.new() # Smooth builder doesn't split by voxel ID yet - wood-only for now.
	last_elapsed_sec = (Time.get_ticks_usec() - start_usec) / 1_000_000.0
	last_tet_count = wood_mesh.get_simplex_cell_indices().size() / 4 + leaf_mesh.get_simplex_cell_indices().size() / 4

	_shrub = ShrubInstance4D.new()
	_shrub.name = "Shrub"
	_shrub.species = species
	add_child(_shrub)
	var wood_instance: MeshInstance4D = _shrub._get_or_create_wood_mesh_instance()
	wood_instance.mesh = wood_mesh
	wood_instance.material_override = ShrubInstance4D._get_wood_material()
	var leaf_instance: MeshInstance4D = _shrub._get_or_create_leaf_mesh_instance()
	leaf_instance.mesh = leaf_mesh
	leaf_instance.material_override = ShrubInstance4D._get_leaf_material()


func randomize_seed() -> void:
	species.seed = randi()
	regenerate()
