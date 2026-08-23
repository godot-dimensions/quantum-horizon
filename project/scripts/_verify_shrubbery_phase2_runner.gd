extends Node
## TEMPORARY - Phase 2 verification of the shrubbery port using the
## FAST, direct "one box per voxel" mesh builder (ShrubMeshBuilderBlocky4D)
## instead of the smooth marching-tetrahedra one (ShrubMeshBuilder4D),
## after the latter measured 172 seconds for a tiny 11-branch/75-voxel
## shrub - see the port plan's revision history for the full comparison
## against shrubbery's own actual (also cheap, also direct-geometry)
## reference approach.
##
## 1. Numeric crack/watertightness check on the assembled mesh, reusing
##    the same face-adjacency methodology as the MT crack investigation -
##    a blocky per-voxel-box mesh is a much simpler correctness case than
##    MT's implicit-surface output (every voxel's own box is independently
##    watertight; only inter-voxel dedup at shared faces matters), but
##    checked directly rather than assumed.
## 2. Screenshots from a few different camera angles around the shrub -
##    "just get pixels on screen," not a final polished render.

const OUTPUT_DIR := "res://smoke_test_output/"


func _pos_key(p: Vector4) -> String:
	return "%.5f,%.5f,%.5f,%.5f" % [p.x, p.y, p.z, p.w]


func _face_key(positions: PackedVector4Array, a: int, b: int, c: int) -> String:
	var arr := [_pos_key(positions[a]), _pos_key(positions[b]), _pos_key(positions[c])]
	arr.sort()
	return arr[0] + "|" + arr[1] + "|" + arr[2]


func _face_adjacency(mesh: ArrayTetraMesh4D, label: String) -> void:
	var indices: PackedInt32Array = mesh.get_simplex_cell_indices()
	var positions: PackedVector4Array = mesh.get_vertices()
	var tet_count: int = indices.size() / 4
	var face_map: Dictionary = {}
	for t in range(tet_count):
		var base := t * 4
		var v := [indices[base], indices[base + 1], indices[base + 2], indices[base + 3]]
		var faces := [
			[v[0], v[1], v[2]], [v[0], v[1], v[3]], [v[0], v[2], v[3]], [v[1], v[2], v[3]],
		]
		for f in faces:
			var key := _face_key(positions, f[0], f[1], f[2])
			face_map[key] = face_map.get(key, 0) + 1
	var count1 := 0
	var count2 := 0
	var count3plus := 0
	for key in face_map:
		var c: int = face_map[key]
		if c == 1:
			count1 += 1
		elif c == 2:
			count2 += 1
		else:
			count3plus += 1
	var total: int = face_map.size()
	var pct: float = (100.0 * count1 / float(total)) if total > 0 else 0.0
	print("=== FACE ADJACENCY: %s (tet_count=%d) ===" % [label, tet_count])
	print("distinct_faces=%d referenced_1x(HOLE)=%d(%.2f%%) referenced_2x(OK)=%d referenced_3x_plus(OVERLAP)=%d" % [
		total, count1, pct, count2, count3plus
	])


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _aim_player_at(player: Node4D, from_pos: Vector4, target_pos: Vector4) -> void:
	player.global_position = from_pos
	var forward: Vector4 = (target_pos - from_pos).normalized()
	var basis := Projection()
	basis.x = forward
	basis.y = Vector4(0, 1, 0, 0)
	player.global_basis = Basis4D.orthonormalized(basis)


func _run() -> void:
	var species := ShrubSpecies4D.new()
	species.seed = 12345
	# Back to real (not artificially shrunk) defaults now that mesh cost
	# is O(voxel_count) via the blocky builder, not O(dense_grid_samples)
	# via MT - leaf_radius stays at the earlier proportion fix (0.2, down
	# from an initial 0.6 guess that measured wildly oversized against
	# Phase 1's own reported branch extents).

	var generator := ShrubGenerator4D.new(species.seed)
	generator.build_trunk(species)
	generator.spawn_attractors_from_tesseract(species)
	generator.grow(species)
	var voxels: Dictionary = generator.voxelize(species)
	print("branch_count=%d voxel_count=%d" % [generator.branches.size(), voxels.size()])

	var mesh: ArrayTetraMesh4D = ShrubMeshBuilderBlocky4D.build_mesh(voxels, species)
	_face_adjacency(mesh, "shrub (seed=%d, blocky)" % species.seed)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: Control = get_tree().current_scene
	var flat_plane: Node = scene.get_node("FlatPlane")

	# This scene's own MotionLabCreature is reused for its already-set-up
	# Player/Camera4D and HUD, not because it belongs in a shrub check -
	# displaced far away (not hidden/freed - a non-destructive runtime-only
	# change, nothing here is saved to the .tscn) so it doesn't visually
	# clutter or get confused with the shrub itself.
	var creature: Node4D = flat_plane.get_node_or_null("MotionLabCreature")
	if creature != null:
		creature.position += Vector4(500, 0, 500, 0)

	var shrub_position := Vector4(0, 0, 0, 0)
	var shrub := ShrubInstance4D.new()
	shrub.name = "VerifyShrub"
	shrub.species = species
	shrub.position = shrub_position
	flat_plane.add_child(shrub)
	var mesh_instance: MeshInstance4D = shrub._get_or_create_mesh_instance()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ShrubInstance4D._get_shared_material()

	var player: Node4D = flat_plane.get_node("Player")
	var target: Vector4 = shrub_position + Vector4(0, 0.6, 0, 0) # Roughly mid-height of a small shrub.
	_aim_player_at(player, Vector4(2.5, 1.2, 2.5, 0), target)

	# NOT screenshotting/quitting - RenderingServer.frame_post_draw isn't
	# firing in headless mode in this environment right now (confirmed
	# via _verify_screenshot_baseline_runner.gd hanging on it with ZERO
	# shrub content involved at all, even after 90 physics frames of
	# warmup - an environment/session issue, not something about this
	# shrub code). Left running live/windowed instead so it can be viewed
	# directly, matching how HubFinal/the motion lab were shown earlier
	# tonight.
	print("Shrub placed - left running live for windowed viewing.")


func _screenshot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = OUTPUT_DIR + name + ".png"
	img.save_png(path)
	print("saved %s" % path)
