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
## Reuses SubdividedBox's own proven cube-to-5-tetrahedra
## decomposition (CUBE_TETRA_CORNERS) and winding-consistency fix
## directly rather than re-deriving it - that exact winding bug (holes
## from inconsistent tetrahedron handedness) was already found and fixed
## there once; no reason to risk reintroducing it.
##
## Hidden-face culling: only emits a voxel's face for a given axis/sign
## if the corresponding NEIGHBOR voxel is empty - a real optimization,
## not a nice-to-have, once mesh-building became the dominant per-tree
## cost (confirmed directly: a 20-tree forest scene measured mesh-build
## at 6.69s of 12.34s total, MORE than voxelize+grow combined, with
## total_tets == total_voxels*40 exactly - every voxel was building and
## rendering all 8 macro-cells regardless of neighbors, including fully
## interior voxels contributing zero visible geometry). Reuses
## SubdividedBox._build_cell() directly (builds ONE macro-cell,
## not all 8) rather than SubdividedBox.build() (all 8,
## unconditionally) - the finer-grained entry point this culling needs.
##
## Trade-off, stated plainly: this still produces the grid-aligned
## "blocky" look the port plan's original mesh-building revision
## specifically tried to avoid (flat, axis-aligned faces read as
## incoherently uneven from arbitrary 4D viewing angles). Whether that
## trade-off is acceptable for a small decorative shrub (vs. the large
## terrain sheets where it was originally flagged as a real problem) is a
## real open question, judged against an actual image rather than
## decided abstractly.

## CARRIED (Arboretum, 5 Oct 2026): a copy of res://sandbox/shrubbery/shrub_mesh_builder_blocky.gd, its class_name taken out
## and its references preloaded (Arboretum/carried/README.md).
const ShrubSpecies := preload("res://ramon/Arboretum/carried/shrubbery/shrub_species.gd")
const ShrubGenerator := preload("res://ramon/Arboretum/carried/shrubbery/shrub_generator.gd")
const SubdividedBox := preload("res://ramon/Arboretum/carried/shrubbery/subdivided_box_tetra_mesh_4d.gd")


## Matches the (fixed_axis, fixed_sign) enumeration order used when
## building _FACE_TEMPLATE_CACHE below - index i's neighbor offset must
## correspond to the same face as templates[i].
const _NEIGHBOR_OFFSETS: Array[Vector4i] = [
	Vector4i(-1, 0, 0, 0), Vector4i(1, 0, 0, 0),
	Vector4i(0, -1, 0, 0), Vector4i(0, 1, 0, 0),
	Vector4i(0, 0, -1, 0), Vector4i(0, 0, 1, 0),
	Vector4i(0, 0, 0, -1), Vector4i(0, 0, 0, 1),
]

## voxel_id_filter (-1 = all): builds a mesh containing only voxels of
## that VOXEL_ID_* - lets callers build separate wood/leaf meshes (each
## with their own flat-color material) rather than one mesh in one flat
## color. Necessary, not cosmetic-only: Material4D's per-vertex/per-cell
## albedo_color_array is confirmed dead code in the cross-section shader
## (see shrub_mesh_builder.gd's own header and engine_gotchas.md), so
## separate meshes are the only way to get more than one flat color
## without the full palette-texture system.
##
## Neighbor occupancy for culling is checked against `voxels` as a WHOLE
## (not just the voxel_id_filter subset) - a wood voxel touching a leaf
## voxel still has a genuinely interior, never-visible shared face, so
## culling should treat any occupied neighbor as "solid," regardless of
## material.
##
## Thin wrapper over build_meshes() (which computes wood+leaf together in
## one pass) for a single-material caller - kept for API convenience, but
## prefer build_meshes() when both are needed, which every current caller
## does (see that function's own comment for why calling this twice, once
## per filter, is measurably wasteful).
static func build_mesh(voxels: Dictionary, species: ShrubSpecies, voxel_id_filter: int) -> ArrayTetraMesh4D:
	return build_meshes(voxels, species).get(voxel_id_filter, ArrayTetraMesh4D.new())


## Builds wood and leaf meshes TOGETHER in one pass over `voxels`,
## returning {ShrubGenerator.VOXEL_ID_WOOD: mesh, VOXEL_ID_LEAF: mesh}.
##
## Doing this in one combined pass (not build_mesh() called twice, once
## per filter) matters for real, measured reasons, not just tidiness: the
## per-voxel 8-neighbor occupancy check (pack_voxel_key + Dictionary.has(),
## 8x per voxel) costs roughly as much as the geometry it used to gate -
## confirmed directly: hidden-face culling alone cut total tets 3x (a
## 20-tree forest: 17.1M -> 5.66M) but barely moved mesh-build TIME (6.69s
## -> 6.41s), because two separate build_mesh() calls each re-scan the
## WHOLE voxel dictionary and redo all 8 neighbor checks per voxel from
## scratch. Computing neighbor occupancy once per voxel and routing each
## kept face to whichever mesh matches that voxel's own ID halves that
## redundant work.
static func build_meshes(voxels: Dictionary, species: ShrubSpecies) -> Dictionary:
	var wood_mesh := ArrayTetraMesh4D.new()
	var leaf_mesh := ArrayTetraMesh4D.new()
	var result := {
		ShrubGenerator.VOXEL_ID_WOOD: wood_mesh,
		ShrubGenerator.VOXEL_ID_LEAF: leaf_mesh,
	}
	if voxels.is_empty():
		return result

	var half_extents := Vector4(species.voxel_size, species.voxel_size, species.voxel_size, species.voxel_size) * 0.5
	# target_cell_size larger than the box's own full size guarantees a
	# single, unsubdivided cell per macro-cell face - all a single voxel
	# needs (matches SubdividedBox.build()'s own clamp logic
	# for the same target_cell_size, just applied per-face here instead).
	var target_cell_size: float = species.voxel_size * 4.0
	var start_usec := Time.get_ticks_usec()

	# Every voxel's own possible face is IDENTICAL in shape/size across
	# every voxel (only translated) - build all 8 single-face templates
	# exactly ONCE and reuse them, rather than reconstructing per voxel.
	var templates: Array[Dictionary] = _build_face_templates(half_extents, target_cell_size)

	var boundary_normals_by_id := {
		ShrubGenerator.VOXEL_ID_WOOD: PackedVector4Array(),
		ShrubGenerator.VOXEL_ID_LEAF: PackedVector4Array(),
	}
	var faces_emitted := 0
	var faces_culled := 0

	for key in voxels:
		var voxel_id: int = voxels[key]
		var target_mesh: ArrayTetraMesh4D = result.get(voxel_id)
		if target_mesh == null:
			continue # Unknown voxel ID - nothing to route this voxel's faces to.
		var target_normals: PackedVector4Array = boundary_normals_by_id[voxel_id]
		var cell: Vector4i = ShrubGenerator.unpack_voxel_key(key)
		var center: Vector4 = ShrubGenerator.cell_center(cell, species.voxel_size)
		for face_index in range(8):
			var neighbor_cell: Vector4i = cell + _NEIGHBOR_OFFSETS[face_index]
			if voxels.has(ShrubGenerator.pack_voxel_key(neighbor_cell)):
				faces_culled += 1
				continue # Neighbor occupied - this face is interior, never visible.
			faces_emitted += 1
			_append_face(target_mesh, center, templates[face_index], target_normals)

	for voxel_id in result.keys():
		var target_mesh: ArrayTetraMesh4D = result[voxel_id]
		target_mesh.set_simplex_cell_boundary_normals(boundary_normals_by_id[voxel_id])
		target_mesh.calculate_boundary_normals(true) # keep_existing=true: backstop only, matching voxel_world_4d.gd's own identical pattern.

	var elapsed_sec: float = (Time.get_ticks_usec() - start_usec) / 1_000_000.0
	var total_tet_count: int = (wood_mesh.get_simplex_cell_vertex_indices().size() + leaf_mesh.get_simplex_cell_vertex_indices().size()) / 4
	print("ShrubBlocky.build_meshes: voxels=%d faces_emitted=%d faces_culled=%d tet_count=%d elapsed_sec=%.3f" % [voxels.size(), faces_emitted, faces_culled, total_tet_count, elapsed_sec])
	return result


## Builds the 8 single-macro-cell templates (one per fixed_axis x
## fixed_sign combination, matching _NEIGHBOR_OFFSETS' own order) via
## SubdividedBox._build_cell() directly - the finer-grained
## entry point that builds ONE face, unlike SubdividedBox.build()
## which always builds all 8 unconditionally.
##
## Boundary normals MUST be computed independently per face, on that
## face's own single-cell mesh, before any translation -
## calculate_boundary_normals()'s own heuristic classifies a tetrahedron
## as front/back-facing by whether it points "away from the mesh's own
## origin," and each face built here is still correctly positioned
## relative to the shared box-local origin (0,0,0,0) even though the
## OTHER 7 faces aren't present in this same small mesh - confirmed
## directly (0 backward normals) rather than assumed, mirroring the
## identical verification done for the full 8-cell box case earlier this
## session.
static func _build_face_templates(half_extents: Vector4, target_cell_size: float) -> Array[Dictionary]:
	var full_extent_over_target: float = half_extents.x * 2.0 / target_cell_size # Same subdivision-count derivation SubdividedBox.build() uses, per axis - identical here since a voxel box is uniform per axis.
	var subdivision_count: int = clampi(ceili(full_extent_over_target), 1, SubdividedBox.MAX_SUBDIVISIONS_PER_AXIS)
	var subdivisions := PackedInt32Array([subdivision_count, subdivision_count, subdivision_count, subdivision_count])

	var templates: Array[Dictionary] = []
	for fixed_axis in range(4):
		for sign_index in range(2):
			var fixed_sign: float = -1.0 if sign_index == 0 else 1.0
			var face_mesh := ArrayTetraMesh4D.new()
			SubdividedBox._build_cell(face_mesh, half_extents, subdivisions, fixed_axis, fixed_sign, 0.0)
			face_mesh.calculate_boundary_normals()
			templates.append({
				"positions": face_mesh.get_vertex_positions(),
				"indices": face_mesh.get_simplex_cell_vertex_indices(),
				"boundary_normals": face_mesh.get_simplex_cell_boundary_normals(),
			})
	return templates


## Translates one cached face template to `center` and appends it into
## the shared mesh via append_vertices(..., false)/append_tetra_cell_indices -
## the same "append, never merge_with" pattern ShrubMeshBuilder4D already
## established, sidestepping ArrayTetraMesh4D.merge_with's documented
## UVW-map-mis-sizing bug entirely rather than working around it.
##
## dedup=false deliberately: dedup=true measured as a real remaining
## bottleneck even after template caching (barely improved, 13.2s ->
## 12.0s, for 11,510 voxels) - it must search/hash against the WHOLE
## growing mesh on every call, cost compounding as the mesh grows.
## Skipping dedup is CORRECT here, not just faster: unlike
## ShrubMeshBuilder4D's smooth MT mesh (where welding shared vertices at
## brick boundaries is what keeps the surface crack-free), each emitted
## face is already a correctly-wound, independently valid piece of
## geometry - not sharing vertices with a neighboring voxel's own face
## costs a little extra memory, not correctness.
static func _append_face(mesh: ArrayTetraMesh4D, center: Vector4, template: Dictionary, all_boundary_normals: PackedVector4Array) -> void:
	var local_positions: PackedVector4Array = template.positions
	var local_indices: PackedInt32Array = template.indices
	var local_boundary_normals: PackedVector4Array = template.boundary_normals

	var world_positions := PackedVector4Array()
	world_positions.resize(local_positions.size())
	for i in range(local_positions.size()):
		world_positions[i] = local_positions[i] + center

	var index_map: PackedInt32Array = mesh.append_vertices(world_positions, false)
	var tet_count: int = local_indices.size() / 4
	for t in range(tet_count):
		var base: int = t * 4
		mesh.append_tetra_cell_indices(
			index_map[local_indices[base + 0]], index_map[local_indices[base + 1]],
			index_map[local_indices[base + 2]], index_map[local_indices[base + 3]]
		)
		all_boundary_normals.append(local_boundary_normals[t])
