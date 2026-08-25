class_name ShrubMeshBuilderBlocky4D
extends RefCounted
## Fast, direct "one box per voxel" mesh builder - the cheap alternative
## to ShrubMeshBuilder4D's smooth marching-tetrahedra approach.
##
## ShrubMeshBuilder4D's implicit-density-field + dense-grid MT approach
## measured 172 SECONDS to mesh a tiny 11-branch/75-voxel shrub (see the
## approved port plan's revision history) - the cost is dominated by
## ~457,000 GDScript-Callable density-sample evaluations, an algorithm
## class shrubbery's OWN reference project never uses at all: its own
## voxelize() step is a cheap, sparse, O(voxel_count) rasterization
## (confirmed via direct source reading to run in ~300 microseconds for
## a full tree in the original Rust), and its own demo renders that
## sparse output by spawning one literal cube mesh per voxel - exactly
## the same class of direct, cheap geometry this class produces here,
## just merged into one ArrayTetraMesh4D instead of one node per voxel
## (see terrain4d_chunk_pool.gd's own reasoning on why: no
## MultiMeshInstance4D exists in this engine, so one-node-per-voxel would
## reintroduce a real node-count/per-frame-uniform cost that a single
## merged mesh avoids entirely).
##
## Reuses SubdividedBoxTetraMesh4D's own proven cube-to-5-tetrahedra
## decomposition (CUBE_TETRA_CORNERS) and winding-consistency fix
## directly rather than re-deriving it - that exact winding bug (holes
## from inconsistent tetrahedron handedness) was already found and fixed
## there once; no reason to risk reintroducing it.
##
## Trade-off, stated plainly: this produces the grid-aligned "blocky"
## look the port plan's original mesh-building revision specifically
## tried to avoid (flat, axis-aligned faces read as incoherently uneven
## from arbitrary 4D viewing angles). Whether that trade-off is
## acceptable for a small decorative shrub (vs. the large terrain sheets
## where it was originally flagged as a real problem) is a real open
## question - this class exists to get a fast, real result on screen so
## that question can be judged against an actual image instead of
## decided abstractly. No hidden-face culling between adjacent solid
## voxels yet either - a first cut, not a final optimized version.

## voxel_id_filter (-1 = all): builds a mesh containing only voxels of
## that VOXEL_ID_* - lets callers build separate wood/leaf meshes (each
## with their own flat-color material) rather than one mesh in one flat
## color. Necessary, not cosmetic-only: Material4D's per-vertex/per-cell
## albedo_color_array is confirmed dead code in the cross-section shader
## (see shrub_mesh_builder.gd's own header and engine_gotchas.md), so
## separate meshes are the only way to get more than one flat color
## without the full palette-texture system.
static func build_mesh(voxels: Dictionary, species: ShrubSpecies4D, voxel_id_filter: int = -1) -> ArrayTetraMesh4D:
	var mesh := ArrayTetraMesh4D.new()
	if voxels.is_empty():
		return mesh

	var half_extents := Vector4(species.voxel_size, species.voxel_size, species.voxel_size, species.voxel_size) * 0.5
	# target_cell_size larger than the box's own full size guarantees
	# SubdividedBoxTetraMesh4D.build() picks exactly 1 subdivision/axis
	# (clampi(ceili(full_extent/target_cell_size), 1, MAX)) - i.e. one
	# plain, unsubdivided box, which is all a single voxel needs.
	var target_cell_size: float = species.voxel_size * 4.0
	var start_usec := Time.get_ticks_usec()

	# Every voxel's box is IDENTICAL in shape/size (only translated) -
	# build the local template (including boundary normals, which MUST be
	# computed on this origin-centered box - see _build_local_box_template's
	# own comment) exactly ONCE and reuse it, rather than calling
	# SubdividedBoxTetraMesh4D.build() + calculate_boundary_normals() once
	# PER VOXEL. Confirmed as a real, not theoretical, cost: rebuilding
	# per-voxel measured 13.2s for 11,510 voxels (460,400 tets) - almost
	# entirely redundant construction of the same 40-tet box shape over
	# and over, not fundamental to the geometry.
	var template: Dictionary = _build_local_box_template(half_extents, target_cell_size)
	var local_positions: PackedVector4Array = template.positions
	var local_indices: PackedInt32Array = template.indices
	var local_boundary_normals: PackedVector4Array = template.boundary_normals
	var tets_per_voxel: int = local_indices.size() / 4

	var all_boundary_normals := PackedVector4Array()
	var included_count := 0

	for key in voxels:
		var voxel_id: int = voxels[key]
		if voxel_id_filter != -1 and voxel_id != voxel_id_filter:
			continue
		included_count += 1
		var cell: Vector4i = ShrubGenerator4D.unpack_voxel_key(key)
		var center: Vector4 = ShrubGenerator4D.cell_center(cell, species.voxel_size)
		_append_voxel_box(mesh, center, local_positions, local_indices, local_boundary_normals, tets_per_voxel, all_boundary_normals)

	mesh.set_simplex_cell_boundary_normals(all_boundary_normals)
	mesh.calculate_boundary_normals(true) # keep_existing=true: backstop only, matching voxel_world_4d.gd's own identical pattern.

	var elapsed_sec: float = (Time.get_ticks_usec() - start_usec) / 1_000_000.0
	var tet_count: int = mesh.get_simplex_cell_indices().size() / 4
	print("ShrubMeshBuilderBlocky4D.build_mesh: voxels=%d (filter=%d) tet_count=%d elapsed_sec=%.3f" % [included_count, voxel_id_filter, tet_count, elapsed_sec])
	return mesh


## Builds ONE voxel-sized box (via the already-proven
## SubdividedBoxTetraMesh4D.build()) and its correct boundary normals,
## for reuse across every voxel - see build_mesh's own comment for why
## this must be computed once, not per voxel.
##
## Boundary normals MUST be computed on this LOCAL, origin-centered box,
## before any translation - calculate_boundary_normals()'s own heuristic
## classifies a tetrahedron as front/back-facing by whether it points
## "away from the mesh's own origin" (the same heuristic the MT backend's
## own comments document as wrong for anything not actually centered on
## the point it's computed against). Computing it on a mesh already
## translated to scattered world positions derives "away from origin"
## against the wrong reference point for every voxel except the one
## nearest world (0,0,0,0) - confirmed as the actual cause of the
## fragmentary, wedge-like broken first render (most tetrahedra
## misclassified and back-face-culled). Boundary normals are direction
## vectors, translation-invariant, so computing them once here and
## reusing them for every translated copy is correct.
static func _build_local_box_template(half_extents: Vector4, target_cell_size: float) -> Dictionary:
	var box_mesh: ArrayTetraMesh4D = SubdividedBoxTetraMesh4D.build(half_extents, target_cell_size)
	box_mesh.calculate_boundary_normals()
	return {
		"positions": box_mesh.get_vertices(),
		"indices": box_mesh.get_simplex_cell_indices(),
		"boundary_normals": box_mesh.get_simplex_cell_boundary_normals(),
	}


## Translates the cached local box template to `center` and appends it
## into the shared mesh via append_vertices(..., false)/
## append_tetra_cell_indices - the same "append, never merge_with"
## pattern ShrubMeshBuilder4D already established, sidestepping
## ArrayTetraMesh4D.merge_with's documented UVW-map-mis-sizing bug
## entirely rather than working around it.
##
## dedup=false deliberately: dedup=true measured as the actual remaining
## bottleneck after caching the box template (barely improved, 13.2s ->
## 12.0s, for 11,510 voxels) - it must search/hash against the WHOLE
## growing mesh on every call, cost compounding as the mesh grows.
## Skipping dedup is CORRECT here, not just faster: unlike
## ShrubMeshBuilder4D's smooth MT mesh (where welding shared vertices at
## brick boundaries is what keeps the surface crack-free), every voxel's
## box here is ALREADY an independently fully-closed, correctly-wound
## solid on its own (see this class's own header - the class's stated
## known trade-off is redundant internal walls between touching voxels,
## never a missing/cracked wall) - two touching voxels not sharing
## vertices costs a little extra memory, not correctness.
static func _append_voxel_box(mesh: ArrayTetraMesh4D, center: Vector4, local_positions: PackedVector4Array, local_indices: PackedInt32Array, local_boundary_normals: PackedVector4Array, tets_per_voxel: int, all_boundary_normals: PackedVector4Array) -> void:
	var world_positions := PackedVector4Array()
	world_positions.resize(local_positions.size())
	for i in range(local_positions.size()):
		world_positions[i] = local_positions[i] + center

	var index_map: PackedInt32Array = mesh.append_vertices(world_positions, false)
	for t in range(tets_per_voxel):
		var base: int = t * 4
		mesh.append_tetra_cell_indices(
			index_map[local_indices[base + 0]], index_map[local_indices[base + 1]],
			index_map[local_indices[base + 2]], index_map[local_indices[base + 3]]
		)
		all_boundary_normals.append(local_boundary_normals[t])
