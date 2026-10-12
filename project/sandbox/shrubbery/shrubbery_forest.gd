extends Node4D
## Composite "forest" scene: tree_count trees placed at random root
## positions in the XZ ground plane, each one's attractor sampling volume
## (its own default box, per ShrubSpecies4D.build_default_attractor_shape())
## intersected with its own Voronoi cell among all root positions - the
## region strictly closer to its own root than to any other tree's root -
## and that intersection eroded by crown_shyness_voxels for a visible gap
## between neighboring canopies, matching real "crown shyness."
##
## No explicit Voronoi diagram is ever built: VoronoiAttractorShape4D's
## own nearest-site distance comparison IS the Voronoi cell test, done
## per attractor-candidate point rather than as a separate geometric
## construction step - see that class's own header for why this
## generalizes to 4D for free where explicit polytope construction would
## not.
##
## species_template's per-species knobs (iterations, attractors, leaf
## radius, etc.) apply to EVERY tree identically except for a distinct
## per-tree seed (deterministic from forest_seed + tree index, so
## re-running the same forest_seed reproduces the same forest) - a real
## species-per-tree-varying system is future work, not part of this pass.

var species_template: ShrubSpecies4D = ShrubSpecies4D.new()
var tree_count: int = 30
## Whole voxels of Euclidean clearance each tree is pulled back from the
## Voronoi boundary with its neighbors - 0 disables crown shyness
## entirely (plain Voronoi partition, canopies can touch the boundary).
var crown_shyness_voxels: int = 1
var use_blocky_builder: bool = true
var forest_seed: int = 0

## Metrics from the most recent regenerate() call, for the controller's
## HUD - summed across every tree in the forest.
var last_voxel_count: int = 0
var last_tet_count: int = 0
var last_elapsed_sec: float = 0.0

var _tree_instances: Array[ShrubInstance4D] = []
var _root_positions: Array[Vector4] = []


func _ready() -> void:
	regenerate()


## Dispatches each tree's own generation (grow+voxelize+mesh-build) as an
## independent WorkerThreadPool task - the real remaining lever after
## single-threaded optimizations (segment-rasterization rewrite,
## hidden-face culling, combined wood+leaf mesh pass) only brought a
## 20-tree forest from ~0.94s/tree to ~0.6s/tree, still tens of seconds
## total. Each tree's generation only READS shared, already-finalized
## data (its own species duplicate, its own precomputed attractor shape,
## and other trees' root positions, which are float coordinates fixed
## before any task starts) and WRITES only to objects it allocates
## itself (its own ShrubGenerator4D, Dictionary, ArrayTetraMesh4D) - no
## cross-task mutable state, which is what makes this safe to parallelize
## at all. Scene-tree mutation (add_child, assigning meshes to
## MeshInstance4D) happens back on the MAIN thread only, after every task
## completes - Godot requires scene-tree structure changes to happen
## there regardless of where the data backing them was computed.
func regenerate() -> void:
	for instance in _tree_instances:
		instance.free()
	_tree_instances.clear()

	_place_roots()

	# See voronoi_attractor_shape_4d.gd's own header: crown_shyness_margin
	# is a margin on (distance-to-other minus distance-to-own), and the
	# actual Euclidean clearance from the bisector plane is margin/2 - so
	# requesting crown_shyness_voxels of REAL clearance needs the margin
	# doubled here.
	var crown_shyness_margin: float = 2.0 * float(crown_shyness_voxels) * species_template.voxel_size
	var start_usec := Time.get_ticks_usec()

	# Precompute all per-tree inputs sequentially (cheap: species
	# duplication and shape construction, no growth/voxelize/mesh work
	# yet) BEFORE dispatching the expensive part in parallel.
	var per_tree_species: Array[ShrubSpecies4D] = []
	var per_tree_shapes: Array[AttractorShape4D] = []
	for i in range(tree_count):
		var species: ShrubSpecies4D = species_template.duplicate()
		# Deterministic per-tree seed: reproducible per forest_seed, and
		# distinct enough per tree that neighboring trees don't grow
		# identically - the exact multiplier has no special meaning
		# beyond spreading seeds apart.
		species.seed = forest_seed * 1000003 + i
		per_tree_species.append(species)

		var base_shape: AttractorShape4D = species.build_default_attractor_shape()
		var other_sites: Array[Vector4] = []
		for j in range(tree_count):
			if j != i:
				other_sites.append(_root_positions[j])
		var shape: AttractorShape4D = base_shape
		if not other_sites.is_empty():
			shape = VoronoiAttractorShape4D.new(base_shape, _root_positions[i], other_sites, crown_shyness_margin)
		per_tree_shapes.append(shape)

	var results: Array = []
	results.resize(tree_count)
	if tree_count > 0:
		var task_id: int = WorkerThreadPool.add_group_task(
			_generate_tree_task.bind(per_tree_species, per_tree_shapes, results), tree_count
		)
		WorkerThreadPool.wait_for_group_task_completion(task_id)

	var total_voxels := 0
	var total_tets := 0
	for i in range(tree_count):
		var result: Dictionary = results[i]
		total_voxels += result.voxel_count
		total_tets += result.tet_count

		var instance := ShrubInstance4D.new()
		instance.name = "Tree%d" % i
		instance.species = per_tree_species[i]
		instance.position = _root_positions[i]
		add_child(instance)
		var wood_instance: MeshInstance4D = instance._get_or_create_wood_mesh_instance()
		wood_instance.mesh = result.wood_mesh
		wood_instance.material_override = ShrubInstance4D._get_wood_material()
		var leaf_instance: MeshInstance4D = instance._get_or_create_leaf_mesh_instance()
		leaf_instance.mesh = result.leaf_mesh
		leaf_instance.material_override = ShrubInstance4D._get_leaf_material()
		_tree_instances.append(instance)

	last_voxel_count = total_voxels
	last_tet_count = total_tets
	last_elapsed_sec = (Time.get_ticks_usec() - start_usec) / 1_000_000.0
	print("ShrubberyForest.regenerate: trees=%d total_voxels=%d total_tets=%d elapsed=%.2fs (parallel, %d logical CPUs)" % [
		tree_count, total_voxels, total_tets, last_elapsed_sec, OS.get_processor_count()
	])


## Runs on a WorkerThreadPool worker thread - must not touch the scene
## tree (no add_child/get_node/etc.), only compute data and write it into
## this task's own slot of `results`. Each index's own species/shape were
## already fully constructed sequentially on the main thread before any
## task started, so reading per_tree_species[index]/per_tree_shapes[index]
## here is safe (no other task writes to a DIFFERENT index's data, and
## nothing mutates these arrays once dispatch begins).
func _generate_tree_task(index: int, per_tree_species: Array[ShrubSpecies4D], per_tree_shapes: Array[AttractorShape4D], results: Array) -> void:
	var species: ShrubSpecies4D = per_tree_species[index]
	var shape: AttractorShape4D = per_tree_shapes[index]

	var generator := ShrubGenerator4D.new(species.seed)
	generator.build_trunk(species)
	generator.spawn_attractors_from_shape(shape, species.attractor_count)
	generator.grow(species)
	var voxels: Dictionary = generator.voxelize(species)

	var wood_mesh: ArrayTetraMesh4D
	var leaf_mesh: ArrayTetraMesh4D
	if use_blocky_builder:
		var meshes: Dictionary = ShrubMeshBuilderBlocky4D.build_meshes(voxels, species)
		wood_mesh = meshes[ShrubGenerator4D.VOXEL_ID_WOOD]
		leaf_mesh = meshes[ShrubGenerator4D.VOXEL_ID_LEAF]
	else:
		wood_mesh = ShrubMeshBuilder4D.build_mesh(voxels, species)
		leaf_mesh = ArrayTetraMesh4D.new() # Smooth builder doesn't split by voxel ID yet - wood-only for now.

	results[index] = {
		"voxel_count": voxels.size(),
		"tet_count": wood_mesh.get_simplex_cell_vertex_indices().size() / 4 + leaf_mesh.get_simplex_cell_vertex_indices().size() / 4,
		"wood_mesh": wood_mesh,
		"leaf_mesh": leaf_mesh,
	}


## Root positions are sampled with uniform AREA density (sqrt(random) for
## radius, not raw random) over a disc whose area scales with tree_count -
## keeping roughly constant tree density as tree_count changes, rather
## than a fixed-size disc that would get implausibly crowded or sparse.
## Deterministic from forest_seed alone (a separate RNG from any
## per-tree generator), so re-running the same forest_seed reproduces
## the same root layout even if species parameters change.
func _place_roots() -> void:
	var placement_rng := RandomNumberGenerator.new()
	placement_rng.seed = forest_seed
	_root_positions.clear()
	var area_per_tree: float = 9.0 # A loose "typical small-tree spacing" guess, not derived from species geometry - tune per how crowded the forest should look.
	var placement_radius: float = sqrt(float(maxi(tree_count, 1)) * area_per_tree / PI)
	for _i in range(tree_count):
		var angle: float = placement_rng.randf_range(0.0, TAU)
		var r: float = sqrt(placement_rng.randf()) * placement_radius
		_root_positions.append(Vector4(cos(angle) * r, 0.0, sin(angle) * r, 0.0))


func randomize_seed() -> void:
	forest_seed = randi()
	regenerate()
