class_name PatchContour4D
extends RefCounted
## PORTAL-LOCAL FORK of project/ramon/voxel_port/scripts/dual_contour_4d.gd.
##
## The only change is that the grid size is a Vector4i instead of one int, so
## the field can be fine across the patch face and coarse through its thickness
## and along w. That is not a micro-optimisation: cost is the product of the four
## axis counts, and a cubic grid fine enough for a circular rim (16 cells across)
## costs 65,536 points, while 16 x 16 x 4 x 4 costs 4,096 for the SAME rim
## quality. It is what makes a clean dual-contoured cut affordable per shot.
##
## Forked rather than edited because VoxelMining and voxel_port both depend on
## the originals and neither needs anisotropy. Kept deliberately close to the
## source so differences stay easy to diff.
## Extracts a tetrahedral 4D surface mesh from a [PatchField4D] by dual
## contouring, one dimension up from the usual 3D formulation.
##
## Dual contouring in 3D: every grid edge whose endpoints straddle the surface
## is shared by 4 cells, each cell solves for one vertex, and those 4 vertices
## form a quad. One dimension up, a straddling edge is shared by 8 cells (two
## choices - before or after the edge - along each of the other 3 axes), and
## those 8 vertices form a hexahedron.
##
## Two things here go beyond the project's existing height-field generator:
##
## 1. A cell can emit more than one vertex. The straddling edges within a cell
##    are first connected into a graph across the cell's 2D faces, and each
##    connected component gets its own vertex. Without this, two unrelated
##    sheets of surface passing through the same cell get welded into a single
##    vertex and the geometry tears. A height field never hits this - it has
##    one sheet by construction - but a volumetric field hits it constantly
##    (a cave roof above a cave floor, a shoreline where water meets ground).
##
## 2. Vertex placement goes through [QEFSolver4D]'s singular-value-clamped
##    solve, which keeps sharp creases sharp instead of rounding every corner.
##
## All coordinates here are grid coordinates (0 .. size-1). Scaling to world
## meters is the caller's job.

## The 8 corners of a hexahedron, indexed by which side of the shared edge
## they sit on along each of the 3 non-edge axes: bit 2 is the first such
## axis, bit 1 the second, bit 0 the third. Corner 0 (all "before") and
## corner 7 (all "after") are opposite ends of the main diagonal.
const _HEXAHEDRON_APEX_LOW := 0
const _HEXAHEDRON_APEX_HIGH := 7

## The other 6 corners, in cyclic order around that main diagonal. Consecutive
## entries differ by exactly one bit, which is what makes them a genuine
## hexagonal ring rather than an arbitrary ordering - so pairing each with its
## successor and both apexes tiles the hexahedron with 6 tetrahedra that share
## the diagonal and overlap nowhere.
const _HEXAHEDRON_RING: Array[int] = [4, 6, 2, 3, 1, 5]

## Minimum ratio of a tetrahedron's 3-volume to the product of its edge
## lengths. Tetrahedra below this are dropped rather than submitted.
##
## Deliberately a *ratio* rather than an absolute volume: a tetrahedron can be
## physically large and still be degenerate if it is flat, and an absolute
## threshold would wave those through while also punishing genuinely small but
## well-formed ones. This measures shape, not size, so it behaves identically
## regardless of cell_size.
##
## The specific value is pinned by [ConcaveMeshShape4D], which inverts each
## tetrahedron's Gram matrix to build its closest-point cache and hard-fails
## the [i]entire[/i] shape - not just the offending cell - if any one of them
## is singular. So a sliver too thin to see is still enough to cost the whole
## mesh its collision.
##
## Geometry4D::compute_inverse_metric_3x3 normalizes the basis vectors and
## then requires the resulting correlation matrix's determinant to exceed
## CMP_EPSILON (1e-5). That determinant is exactly this ratio squared, so the
## engine's real cutoff is sqrt(1e-5) = 0.00316. This sits at roughly twice
## that - 3.6x margin in determinant terms, enough to absorb the fact that the
## engine recomputes the quantity by a different route than we do here.
##
## Measured cost on the default 12^4 globe: 22 of 20184 tetrahedra, 0.11%.
const MIN_NORMALIZED_VOLUME := 0.006

## Vertices are allowed to leave their own cell by this many cells before
## being clamped. Dual contouring deliberately lets a vertex sit slightly
## outside its cell - that is how a corner shared between cells resolves to
## one sharp point instead of several rounded ones - so a tight clamp would
## undo the whole benefit of the QEF solve. This is purely a backstop against
## a pathological solve throwing a vertex across the map.
const VERTEX_ESCAPE_MARGIN := 1.0

## Scales the QEF's singular-value cutoff by the number of crossings feeding
## it, because the QEF matrix is a sum over crossings and so grows with their
## count - a fixed cutoff would be strict for a 3-crossing cell and permissive
## for a 20-crossing one.
const SINGULAR_CUTOFF_PER_CROSSING := 0.03

var _field: PatchField4D

## Reverses every tetrahedron's orientation. Tetrahedra are wound so their
## outward direction agrees with the density gradient, which is
## self-consistent - but whether that matches the direction the cross-section
## shader treats as front-facing is a convention this code cannot derive. If
## the surface renders inside-out (you see through the near side and the far
## side is lit), flip this rather than hunting through the winding logic.
var flip_winding := false

# Output.
var vertices := PackedVector4Array()
var vertex_normals := PackedVector4Array()
var vertex_layers := PackedByteArray()
## Tetrahedra as flat runs of 4 vertex indices, split by whether the surface
## bounds something opaque. They need separate meshes because water wants a
## transparent material and ground does not.
var ground_cells := PackedInt32Array()
var water_cells := PackedInt32Array()
## The subset of [member ground_cells] well-conditioned enough for
## [ConcaveMeshShape4D] to invert. Kept separate rather than filtering
## ground_cells itself because the two consumers have genuinely different
## tolerances: the renderer draws a sliver as a sliver and nobody notices,
## while the collision builder rejects the whole shape over a single one. On
## flat-faceted models the slivers are a large fraction of all tetrahedra -
## measured at 27% for the 24-cell - so dropping them from the visible mesh
## too would tear visible holes in it.
var ground_collision_cells := PackedInt32Array()

var stats := {}

# Maps each existing field edge to a compact id, then each (compact id, which
# of the 8 surrounding cells) to the vertex that cell assigned to it. Compact
# rather than direct because only a small fraction of grid edges ever carry a
# crossing, and the direct form would be 8 ints per grid edge whether used or
# not.
var _compact_edge_id := PackedInt32Array()
var _edge_cell_vertex := PackedInt32Array()

## Hexahedra containing at least one tetrahedron whose own normal disagrees
## with the orientation chosen for the hexahedron as a whole, and the total
## count of such tetrahedra. Both are health metrics rather than errors - the
## disagreeing tetrahedra are slivers whose normals are numerical noise, and
## they are deliberately wound to match their neighbours anyway. A rising rate
## means the decomposition is producing badly-shaped cells.
var _contested_hexahedra := 0
var _contested_tetrahedra := 0


func _init(p_field: PatchField4D) -> void:
	_field = p_field


static func _corner_index(c: Vector4i) -> int:
	return c.x * 8 + c.y * 4 + c.z * 2 + c.w


static func _corner_from_index(index: int) -> Vector4i:
	return Vector4i((index >> 3) & 1, (index >> 2) & 1, (index >> 1) & 1, index & 1)


## Weight of an axis in the corner index above. Kept as a helper because the
## face-connection logic needs to step "one corner along axis N" repeatedly.
static func _axis_step(axis: int) -> int:
	return 8 >> axis


static func _other_axes(axis: int) -> PackedInt32Array:
	var others := PackedInt32Array()
	for a in range(4):
		if a != axis:
			others.append(a)
	return others


func generate() -> void:
	var t0: int = Time.get_ticks_usec()
	_build_compact_edge_ids()
	var t1: int = Time.get_ticks_usec()
	_build_cell_vertices()
	var t2: int = Time.get_ticks_usec()
	_build_hexahedra()
	var t3: int = Time.get_ticks_usec()
	_normalize_vertex_normals()
	var t4: int = Time.get_ticks_usec()
	phase_msec = {
		"edge_ids": float(t1 - t0) / 1000.0,
		"cell_vertices": float(t2 - t1) / 1000.0,
		"hexahedra": float(t3 - t2) / 1000.0,
		"normals": float(t4 - t3) / 1000.0,
	}


func _build_compact_edge_ids() -> void:
	var slot_count: int = _field.point_count() * 4
	_compact_edge_id.resize(slot_count)
	_compact_edge_id.fill(-1)
	var next_id := 0
	for point_index in range(_field.point_count()):
		for axis in range(4):
			if _field.has_edge(point_index, axis):
				_compact_edge_id[point_index * 4 + axis] = next_id
				next_id += 1
	_edge_cell_vertex.resize(next_id * 8)
	_edge_cell_vertex.fill(-1)
	stats["crossing_edges"] = next_id


## Solves every cell's dual vertices and records, for each crossing, which
## vertex represents it in this cell.
func _build_cell_vertices() -> void:
	var size: Vector4i = _field.size
	var cells_with_geometry := 0
	for x in range(size.x - 1):
		for y in range(size.y - 1):
			for z in range(size.z - 1):
				for w in range(size.w - 1):
					if _process_cell(Vector4i(x, y, z, w)):
						cells_with_geometry += 1
	stats["cells_with_geometry"] = cells_with_geometry
	stats["vertices"] = vertices.size()


## Returns true if this cell produced at least one vertex.
func _process_cell(cell_origin: Vector4i) -> bool:
	# Slot layout matches the corner indexing so the face walk below can address
	# a crossing as "axis A of corner C" arithmetically: 4 axes x 16 corners,
	# with only the 32 combinations where corner[axis] == 0 ever populated (an
	# edge belongs to its low end, so each of the tesseract's 32 edges appears
	# exactly once).
	# Cheap rejection before anything is allocated. A cell whose sixteen corners
	# all hold the same material cannot contain a crossing, because a crossing is
	# only ever recorded on an edge whose two ends differ - so this is exact, not
	# a heuristic.
	#
	# It matters because the original order of business was to allocate a 64-slot
	# array and a 16-entry buffer, walk all sixteen corners times four axes, and
	# only THEN notice the cell was empty. Profiling put 45 of a 62 ms chunk
	# rebuild in this function.
	var first_material: int = _field._material[_field._point_index_v(cell_origin)]
	var mixed := false
	for corner_index in range(1, 16):
		var corner_point: Vector4i = cell_origin + _corner_from_index(corner_index)
		if _field._material[_field._point_index_v(corner_point)] != first_material:
			mixed = true
			break
	if not mixed:
		return false

	var crossing_slots: Array = []
	crossing_slots.resize(64)
	var corner_materials := PackedInt32Array()
	corner_materials.resize(16)

	var crossing_count := 0
	for corner_index in range(16):
		var corner: Vector4i = _corner_from_index(corner_index)
		var point: Vector4i = cell_origin + corner
		var point_index: int = _field._point_index_v(point)
		corner_materials[corner_index] = _field._material[point_index]
		for axis in range(4):
			if corner[axis] != 0:
				continue
			if not _field.has_edge(point_index, axis):
				continue
			var local_position := Vector4(corner.x, corner.y, corner.z, corner.w)
			local_position[axis] = _field.edge_position(point_index, axis)
			crossing_slots[axis + 4 * corner_index] = {
				"position": local_position,
				"normal": _field.edge_normal(point_index, axis),
				"near": _field.edge_near_material(point_index, axis),
				"far": _field.edge_far_material(point_index, axis),
				"layer": _field.edge_layer(point_index, axis),
				"point_index": point_index,
				"axis": axis,
				"corner": corner,
				"connections": [],
				"unvisited": true,
			}
			crossing_count += 1

	if crossing_count == 0:
		return false

	_connect_crossings(crossing_slots, corner_materials)

	var produced := false
	while true:
		var component: Array = _take_next_component(crossing_slots)
		if component.is_empty():
			break
		_emit_component_vertex(cell_origin, component)
		produced = true
	return produced


## Walks the tesseract's 24 two-dimensional faces, connecting the crossings on
## each into the graph whose components become vertices.
func _connect_crossings(crossing_slots: Array, corner_materials: PackedInt32Array) -> void:
	for corner_index in range(16):
		var corner: Vector4i = _corner_from_index(corner_index)
		for axis in range(4):
			if corner[axis] != 0:
				continue
			for axis2 in range(axis):
				if corner[axis2] != 0:
					continue
				var step_a: int = _axis_step(axis)
				var step_b: int = _axis_step(axis2)
				var face_crossings: Array = [
					crossing_slots[axis2 + 4 * corner_index],
					crossing_slots[axis2 + 4 * (corner_index + step_a)],
					crossing_slots[axis + 4 * corner_index],
					crossing_slots[axis + 4 * (corner_index + step_b)],
				]
				var face_materials := PackedInt32Array([
					corner_materials[corner_index],
					corner_materials[corner_index + step_a],
					corner_materials[corner_index + step_b],
					corner_materials[corner_index + step_a + step_b],
				])
				_connect_face(axis, axis2, face_crossings, face_materials)


## Resolves how the (up to 4) crossings on one 2D face join up.
##
## With all 4 present the face is ambiguous: the surface could pass through it
## as two separate strips, and there are two ways to pair the crossings. The
## score below is a heuristic - it compares how the crossings are displaced
## along each axis and how their normals lean - and the pairing it prefers is
## only accepted if the diagonal materials agree with it. This is inherited
## from the reference demo, whose author explicitly flags the formula as
## non-rigorous; it is the known-soft spot of this algorithm, and the place to
## look first if the surface ever tears along a diagonal.
##
## Fewer than 4 crossings is unambiguous - just chain them together.
func _connect_face(axis: int, axis2: int, face_crossings: Array, face_materials: PackedInt32Array) -> void:
	var all_present: bool = true
	for crossing in face_crossings:
		if crossing == null:
			all_present = false
			break

	if all_present:
		var c0: Dictionary = face_crossings[0]
		var c1: Dictionary = face_crossings[1]
		var c2: Dictionary = face_crossings[2]
		var c3: Dictionary = face_crossings[3]
		var score: float = 0.0
		score += c1["position"][axis2] - c0["position"][axis2]
		score += c3["position"][axis] - c2["position"][axis]
		score += c0["normal"][axis] * signf(c0["normal"][axis2])
		score += c1["normal"][axis] * signf(c1["normal"][axis2])
		score += c2["normal"][axis2] * signf(c2["normal"][axis])
		score += c3["normal"][axis2] * signf(c3["normal"][axis])

		var preferred_pairing_agrees: bool
		if score > 0.0:
			preferred_pairing_agrees = face_materials[1] == face_materials[2]
		else:
			preferred_pairing_agrees = face_materials[0] == face_materials[3]

		if preferred_pairing_agrees:
			if score <= 0.0:
				var swap: Dictionary = face_crossings[2]
				face_crossings[2] = face_crossings[3]
				face_crossings[3] = swap
			_link(face_crossings[0], face_crossings[2])
			_link(face_crossings[1], face_crossings[3])
			return

	var previous = null
	for crossing in face_crossings:
		if crossing == null:
			continue
		if previous != null:
			_link(previous, crossing)
		previous = crossing


static func _link(a: Dictionary, b: Dictionary) -> void:
	a["connections"].append(b)
	b["connections"].append(a)


## Depth-first search for one connected component of unvisited crossings.
func _take_next_component(crossing_slots: Array) -> Array:
	var frontier: Array = []
	for crossing in crossing_slots:
		if crossing != null and crossing["unvisited"]:
			frontier.append(crossing)
			break
	if frontier.is_empty():
		return []

	var component: Array = []
	while not frontier.is_empty():
		var crossing: Dictionary = frontier.pop_back()
		if not crossing["unvisited"]:
			continue
		crossing["unvisited"] = false
		component.append(crossing)
		for neighbor in crossing["connections"]:
			if neighbor["unvisited"]:
				frontier.append(neighbor)
	return component


## Solves one component's QEF and registers the resulting vertex against every
## crossing in it.
##
## A single component can still need more than one vertex: crossings within it
## that separate different material pairs (ground/air versus ground/water)
## are geometrically coincident but belong to different surfaces, and sharing
## one vertex between them would force the ground mesh and the water mesh to
## share geometry they need to shade differently. So the solved position is
## shared, but a distinct vertex is emitted per material pairing.
## Crossings whose normals all point the same way describe a flat patch of
## surface, and there the QEF has nothing to decide: the least-squares solution
## set is the plane itself, and the mass point already lies on it. So the answer
## is simply the average crossing.
##
## This is worth a special case because a wall is mostly flat. Profiling one
## chunk rebuild put 51 of its 62 ms inside the contour, and the great majority
## of its cells sit on the slab's two faces with a single shared normal - every
## one of those was running a full 4x4 singular value decomposition to be told
## the average. The curved rim, where the decomposition genuinely earns its keep,
## is a small minority of cells and still takes the real path.
const FLAT_NORMAL_TOLERANCE := 0.999


func _solve_component(positions: Array[Vector4], normals: Array[Vector4], cutoff: float) -> Vector4:
	var first: Vector4 = normals[0]
	var flat := true
	for index in range(1, normals.size()):
		if absf(normals[index].dot(first)) < FLAT_NORMAL_TOLERANCE:
			flat = false
			break
	if not flat:
		return QEFSolver4D.solve(positions, normals, cutoff)
	var average := Vector4.ZERO
	for position in positions:
		average += position
	return average / float(positions.size())


func _emit_component_vertex(cell_origin: Vector4i, component: Array) -> void:
	var positions: Array[Vector4] = []
	var normals: Array[Vector4] = []
	for crossing in component:
		positions.append(crossing["position"])
		normals.append(crossing["normal"])

	var cutoff: float = SINGULAR_CUTOFF_PER_CROSSING * float(component.size())
	var local_position: Vector4 = _solve_component(positions, normals, cutoff)

	local_position.x = clampf(local_position.x, -VERTEX_ESCAPE_MARGIN, 1.0 + VERTEX_ESCAPE_MARGIN)
	local_position.y = clampf(local_position.y, -VERTEX_ESCAPE_MARGIN, 1.0 + VERTEX_ESCAPE_MARGIN)
	local_position.z = clampf(local_position.z, -VERTEX_ESCAPE_MARGIN, 1.0 + VERTEX_ESCAPE_MARGIN)
	local_position.w = clampf(local_position.w, -VERTEX_ESCAPE_MARGIN, 1.0 + VERTEX_ESCAPE_MARGIN)

	var world_position := Vector4(
		cell_origin.x + local_position.x,
		cell_origin.y + local_position.y,
		cell_origin.z + local_position.z,
		cell_origin.w + local_position.w,
	)

	# One vertex per distinct (material pair, layer) within this component.
	var vertices_by_attribute: Dictionary = {}
	for crossing in component:
		var low_material: int = mini(crossing["near"], crossing["far"])
		var high_material: int = maxi(crossing["near"], crossing["far"])
		# Keyed on the material pair alone, matching the reference demo, which
		# keys on the material pair plus the layer's altitude *function* - and
		# every layer that does not define one shares a single default, so its
		# split is much coarser than keying on layer identity would be. Until
		# per-layer altitude functions are wired up here, the layer index
		# carries no meaning worth splitting on.
		#
		# Note this is not the cause of the unmatched faces documented in
		# _emit_hexahedron: removing the layer from the key was measured and
		# moved the vertex count only from 7525 to 7517. The ~1.94 dual
		# vertices per cell come from genuine connected components, not from
		# this key - the water sphere and the ground surface sit only ~0.24
		# grid units apart in radius, so most surface cells legitimately
		# contain two separate sheets.
		var attribute_key: int = (low_material << 8) | high_material
		var vertex_index: int
		if vertices_by_attribute.has(attribute_key):
			vertex_index = vertices_by_attribute[attribute_key]
		else:
			vertex_index = vertices.size()
			vertices.append(world_position)
			vertex_normals.append(Vector4.ZERO)
			vertex_layers.append(crossing["layer"])
			vertices_by_attribute[attribute_key] = vertex_index
		_record_edge_vertex(cell_origin, crossing, vertex_index)


## Notes that, for the crossing's edge, this cell contributes the given vertex.
## The hexahedron pass later collects all 8 cells' contributions for one edge.
func _record_edge_vertex(cell_origin: Vector4i, crossing: Dictionary, vertex_index: int) -> void:
	var axis: int = crossing["axis"]
	var compact_id: int = _compact_edge_id[crossing["point_index"] * 4 + axis]
	if compact_id < 0:
		return
	var corner: Vector4i = crossing["corner"]
	var others: PackedInt32Array = _other_axes(axis)
	# The crossing's grid point is cell_origin + corner, so along each non-edge
	# axis this cell sits "before" the point when corner is 1 and "at" it when
	# corner is 0 - which is exactly the inverse of the corner bit.
	var choice: int = 0
	for k in range(3):
		var bit: int = 1 - corner[others[k]]
		choice |= bit << (2 - k)
	_edge_cell_vertex[compact_id * 8 + choice] = vertex_index


## For every crossing edge whose full ring of 8 surrounding cells produced a
## vertex, tetrahedralizes the resulting hexahedron and emits it.
##
## Edges missing part of their ring sit on the outermost layer of the grid,
## where the surface is deliberately left open rather than being closed with
## geometry that has nothing on the other side of it.
## Which grid points this contour is allowed to emit geometry for. Defaults to
## everything; a chunk narrows it to the region it OWNS, so its ghost cells feed
## the solver without also emitting a duplicate copy of its neighbour's surface.
##
## Every chunk samples the same field, so a vertex computed in one chunk's ghost
## cell sits at exactly the position the neighbour computes for its own cell -
## which is why the two halves meet with no crack even though only one of them
## emits the hexahedra spanning the boundary.
## Timing breakdown of the last generate(), for profiling.
var phase_msec: Dictionary = {}

var emit_min := Vector4i(0, 0, 0, 0)
var emit_max := Vector4i(1 << 30, 1 << 30, 1 << 30, 1 << 30)


func _is_owned(point: Vector4i) -> bool:
	return point.x >= emit_min.x and point.y >= emit_min.y 		and point.z >= emit_min.z and point.w >= emit_min.w 		and point.x <= emit_max.x and point.y <= emit_max.y 		and point.z <= emit_max.z and point.w <= emit_max.w


func _build_hexahedra() -> void:
	var size: Vector4i = _field.size
	var attempted := 0
	var kept := 0
	var skipped_degenerate := 0
	var incomplete := 0

	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				for w in range(size.w):
					var point := Vector4i(x, y, z, w)
					if not _is_owned(point):
						continue
					var point_index: int = _field._point_index_v(point)
					for axis in range(4):
						if not _field.has_edge(point_index, axis):
							continue
						attempted += 1
						var compact_id: int = _compact_edge_id[point_index * 4 + axis]
						var corners := PackedInt32Array()
						corners.resize(8)
						var complete := true
						for choice in range(8):
							var vertex_index: int = _edge_cell_vertex[compact_id * 8 + choice]
							if vertex_index < 0:
								complete = false
								break
							corners[choice] = vertex_index
						if not complete:
							incomplete += 1
							continue
						var is_opaque: bool = _field.edge_near_material(point_index, axis) == PatchField4D.VoxelMaterial.GROUND \
							or _field.edge_far_material(point_index, axis) == PatchField4D.VoxelMaterial.GROUND
						var result: Vector2i = _emit_hexahedron(corners, _field.edge_normal(point_index, axis), is_opaque)
						kept += result.x
						skipped_degenerate += result.y

	stats["hexahedra_attempted"] = attempted
	stats["hexahedra_incomplete"] = incomplete
	stats["tetrahedra"] = kept
	stats["tetrahedra_degenerate"] = skipped_degenerate
	stats["ground_tetrahedra"] = ground_cells.size() / 4
	stats["water_tetrahedra"] = water_cells.size() / 4
	stats["contested_hexahedra"] = _contested_hexahedra
	stats["contested_tetrahedra"] = _contested_tetrahedra
	stats["collision_tetrahedra"] = ground_collision_cells.size() / 4
	stats["tetrahedra_too_thin_for_collision"] = (ground_cells.size() - ground_collision_cells.size()) / 4


## Splits one hexahedron into 6 tetrahedra around its main diagonal and
## appends the non-degenerate ones. Returns (kept, skipped).
##
## The winding is decided [b]once for the whole hexahedron[/b] and every
## tetrahedron inherits it. Deciding it per tetrahedron looks more careful and
## is actively wrong: all 6 bound the same patch of surface so they must agree,
## but a sliver's own normal is numerical noise and will cheerfully contradict
## its neighbours. A contradicting tetrahedron comes out wound backwards, gets
## discarded by backface culling, and leaves a visible hole in the terrain.
## Measured with the per-tetrahedron test: 10.5% of hexahedra were internally
## inconsistent, and 3.8% of tetrahedra had an orientation test too
## ill-conditioned to mean anything.
func _emit_hexahedron(corners: PackedInt32Array, surface_normal: Vector4, is_opaque: bool) -> Vector2i:
	var apex_low: int = corners[_HEXAHEDRON_APEX_LOW]
	var apex_high: int = corners[_HEXAHEDRON_APEX_HIGH]
	var apex_position: Vector4 = vertices[apex_low]
	var apex_edge: Vector4 = vertices[apex_high] - apex_position

	# Pass 1: a single orientation vote for the whole hexahedron. The summed
	# alignments are deliberately left unnormalized, which weights each
	# tetrahedron by its own volume - so the large well-formed ones decide the
	# outcome while slivers, whose perpendiculars are nearly zero-length,
	# contribute almost nothing to it.
	var orientation_vote := 0.0
	for i in range(6):
		var ring_a: Vector4 = vertices[corners[_HEXAHEDRON_RING[i]]] - apex_position
		var ring_b: Vector4 = vertices[corners[_HEXAHEDRON_RING[(i + 1) % 6]]] - apex_position
		orientation_vote += Vector4D.perpendicular(apex_edge, ring_a, ring_b).dot(surface_normal)
	var reverse_ring: bool = (orientation_vote < 0.0) != flip_winding

	# Pass 2: emit. Swapping a tetrahedron's two ring corners reverses the sign
	# of its perpendicular, so applying the swap uniformly flips all 6 together
	# and they stay mutually consistent by construction.
	var kept := 0
	var skipped := 0
	var contested := 0
	for i in range(6):
		var ring_a_index: int = corners[_HEXAHEDRON_RING[i]]
		var ring_b_index: int = corners[_HEXAHEDRON_RING[(i + 1) % 6]]
		if reverse_ring:
			var swap: int = ring_a_index
			ring_a_index = ring_b_index
			ring_b_index = swap
		var indices := PackedInt32Array([apex_low, apex_high, ring_a_index, ring_b_index])

		# The 4D analogue of a triangle's normal: the vector perpendicular to
		# all three edge vectors at once. Its length is proportional to the
		# tetrahedron's 3-volume, so it doubles as the degeneracy test.
		var edge_b: Vector4 = vertices[ring_a_index] - apex_position
		var edge_c: Vector4 = vertices[ring_b_index] - apex_position
		var normal: Vector4 = Vector4D.perpendicular(apex_edge, edge_b, edge_c)
		var volume: float = normal.length()
		# Normalizing by the edge lengths turns this into the same conditioning
		# question the engine's Gram-matrix inverse asks, rather than a raw
		# size comparison that a flat-but-large tetrahedron would pass.
		var edge_scale: float = apex_edge.length() * edge_b.length() * edge_c.length()
		if is_nan(volume) or edge_scale <= 0.0 or volume <= 0.0:
			# Genuinely broken rather than merely thin - no usable orientation,
			# so it cannot be drawn or collided with either way.
			skipped += 1
			continue
		if normal.dot(surface_normal) < 0.0:
			contested += 1

		var unit_normal: Vector4 = normal / volume
		for index in indices:
			vertex_normals[index] += unit_normal

		if is_opaque:
			ground_cells.append_array(indices)
			if (volume / edge_scale) >= MIN_NORMALIZED_VOLUME:
				ground_collision_cells.append_array(indices)
		else:
			water_cells.append_array(indices)
		kept += 1

	if contested > 0:
		_contested_hexahedra += 1
	_contested_tetrahedra += contested

	return Vector2i(kept, skipped)


func _normalize_vertex_normals() -> void:
	for i in range(vertex_normals.size()):
		var normal: Vector4 = vertex_normals[i]
		var length: float = normal.length()
		if length > 0.0:
			vertex_normals[i] = normal / length
