extends Node4D
## One chunk of a voxel wall: an anisotropic field over its own slice of the
## wall, contoured to a tetrahedral mesh with per-exposed-voxel collision.
##
## A chunk samples the WALL's field function, not a field of its own, and that
## single fact is what makes chunking work here. The field is a pure function of
## world position - a slab minus every carve recorded so far - so two chunks
## sampling the same point get the same number by construction. That is the
## condition under which ghost cells need no synchronisation at all, which is the
## usual hard part of chunked contouring.
##
## The grid extends GHOST_CELLS beyond the region the chunk owns. Those extra
## cells feed the QEF so the owned boundary cells have complete neighbourhoods,
## and the contour is told to emit geometry only for owned points - so
## neighbouring chunks tile exactly rather than each drawing a copy of the seam.

const PortalShading := preload("res://ramon/Portal/scripts/portal_shading.gd")
const ChunkTexture: Texture3D = preload("res://textures/dev_finals/ramdev_white.png")

## Cells this chunk owns along each face axis, and how many it borrows past them.
const OWNED_CELLS := 8
const GHOST_CELLS := 1
const FACE_GRID := OWNED_CELLS + GHOST_CELLS * 2
## Through the wall and along w the field barely varies, so these stay as small
## as the contour allows - cost is the PRODUCT of all four axis counts, so
## trimming these two from 5 to 4 takes a rebuild from ~95 ms to ~60 ms without
## touching the rim quality, which only the face axes control.
##
## 3 is the floor for w and it is enough: hexahedra need a complete ring, so only
## points 1..size-2 carry geometry, which at 3 is the single layer w=1 - and the
## rings that layer anchors still span both w cells, so the wall covers its whole
## w extent. The thickness axis cannot go to 3, because there the slab would fill
## the grid and its faces would fall on the boundary, leaving them uncontoured.
const THICK_GRID := 4
const W_GRID := 3
const SLAB_HALF_CELLS := 1.0

## Set by the wall before build().
var wall: Node4D = null
## This chunk's owned region on the wall face, in wall-local metres.
var owned_centre := Vector2.ZERO
var face_cell: float = 0.25
var thickness: float = 0.6
var w_half_extent: float = 12.0

var field: PatchField4D = null
var tetra_count: int = 0
var collider_count: int = 0
var rebuild_msec: float = 0.0
## Where the last rebuild's time went, by phase.
var last_phase_msec: Dictionary = {}
var contour_phase_msec: Dictionary = {}
var last_cells_with_geometry: int = 0

var _mesh_instance: MeshInstance4D = null
var _voxels: StaticBody4D = null


static func owned_size(cell: float) -> float:
	return float(OWNED_CELLS) * cell


func build() -> void:
	_mesh_instance = MeshInstance4D.new()
	_mesh_instance.name = &"Surface"
	_mesh_instance.material_override = _make_material()
	add_child(_mesh_instance)
	_voxels = StaticBody4D.new()
	_voxels.name = &"Voxels"
	add_child(_voxels)
	rebuild()


func _grid_size() -> Vector4i:
	return Vector4i(FACE_GRID, FACE_GRID, THICK_GRID, W_GRID)


func _cell_size() -> Vector4:
	return Vector4(
		face_cell,
		face_cell,
		thickness * 0.5 / SLAB_HALF_CELLS,
		# Sized so the MESH spans the full w extent, which is not the same as the
		# grid spanning it. Contour vertices sit inside cells, and only the layers
		# that can anchor a complete ring produce any, so the geometry reaches
		# across (W_GRID - 2) cells rather than all of them. Divide by anything
		# larger and the wall is solid out at the edges of w but invisible there.
		w_half_extent * 2.0 / float(W_GRID - 2))


func _grid_centre() -> Vector4:
	var size: Vector4i = _grid_size()
	return Vector4(float(size.x - 1), float(size.y - 1), float(size.z - 1), float(size.w - 1)) * 0.5


## Grid point -> position in the CHUNK's local metres.
func _grid_to_local(g: Vector4) -> Vector4:
	var centre: Vector4 = _grid_centre()
	var cell: Vector4 = _cell_size()
	return Vector4(
		(g.x - centre.x) * cell.x,
		(g.y - centre.y) * cell.y,
		(g.z - centre.z) * cell.z,
		(g.w - centre.w) * cell.w)


## Rebuilds this chunk from the wall's current carve list.
func rebuild() -> void:
	var started_usec: int = Time.get_ticks_usec()
	field = PatchField4D.new(_grid_size())
	_add_wall_layer()
	var field_usec: int = Time.get_ticks_usec()
	_add_carves()
	var carves_usec: int = Time.get_ticks_usec()

	var contour := PatchContour4D.new(field)
	# Own everything except the ghost ring, so neighbours meet without either
	# duplicating the shared boundary or leaving a crack in it.
	contour.emit_min = Vector4i(GHOST_CELLS, GHOST_CELLS, 0, 0)
	contour.emit_max = Vector4i(
		FACE_GRID - GHOST_CELLS - 1, FACE_GRID - GHOST_CELLS - 1, THICK_GRID, W_GRID)
	contour.generate()

	var contour_usec: int = Time.get_ticks_usec()
	contour_phase_msec = contour.phase_msec
	last_cells_with_geometry = contour.stats.get("cells_with_geometry", 0)
	tetra_count = contour.ground_cells.size() / 4
	_mesh_instance.mesh = _build_mesh(contour)
	var mesh_usec: int = Time.get_ticks_usec()
	_rebuild_colliders()
	var end_usec: int = Time.get_ticks_usec()
	rebuild_msec = float(end_usec - started_usec) / 1000.0
	last_phase_msec = {
		"slab": float(field_usec - started_usec) / 1000.0,
		"carves": float(carves_usec - field_usec) / 1000.0,
		"contour": float(contour_usec - carves_usec) / 1000.0,
		"mesh": float(mesh_usec - contour_usec) / 1000.0,
		"colliders": float(end_usec - mesh_usec) / 1000.0,
	}


## The wall itself: solid through the slab, and bounded at the WALL's outer edge
## rather than running off the end of the grid.
##
## The first version bounded only the thickness, on the reasoning that a
## neighbouring chunk continues the surface sideways. True between chunks, false
## at the outside of the wall - there the surface simply stopped, with no cap, so
## the wall was an open shell and you could see straight into its top edge. That
## is the "faces lost on the upper surface" artifact.
##
## Bounds are expressed in the WALL's frame, so the edge lands in the same place
## for every chunk that touches it, and the wall's solid extent is inset one cell
## inside the chunk coverage so the crossing falls in owned cells with ghost
## cells beyond it - which is what lets the contour close the cap properly.
func _add_wall_layer() -> void:
	var centre: Vector4 = _grid_centre()
	var slab_half: float = SLAB_HALF_CELLS
	var cell: float = face_cell
	var offset: Vector2 = owned_centre
	var solid_half_a: float = wall.solid_half_a
	var solid_half_b: float = wall.solid_half_b

	field.add_layer(
		PatchField4D.VoxelMaterial.GROUND,
		func(p: Vector4) -> float:
			var wall_a: float = offset.x + (p.x - centre.x) * cell
			var wall_b: float = offset.y + (p.y - centre.y) * cell
			return minf(
				slab_half - absf(p.z - centre.z),
				minf((solid_half_a - absf(wall_a)) / cell, (solid_half_b - absf(wall_b)) / cell)),
		func(p: Vector4) -> Vector4:
			var wall_a: float = offset.x + (p.x - centre.x) * cell
			var wall_b: float = offset.y + (p.y - centre.y) * cell
			var margins := [
				(solid_half_a - absf(wall_a)) / cell,
				(solid_half_b - absf(wall_b)) / cell,
				slab_half - absf(p.z - centre.z)]
			var limiting := 0
			for axis in range(1, 3):
				if margins[axis] < margins[limiting]:
					limiting = axis
			var gradient := Vector4.ZERO
			if limiting == 0:
				gradient.x = -signf(wall_a)
			elif limiting == 1:
				gradient.y = -signf(wall_b)
			else:
				gradient.z = -signf(p.z - centre.z)
			return gradient,
		1.0)


## Every carve the wall has recorded, applied in order. This is what makes cuts
## cumulative: a new ball overlapping an old one produces one merged opening,
## because both are just AIR layers over the same slab - exactly how VoxelMining
## makes each chip interact with the ones before it.
func _add_carves() -> void:
	var cell: Vector4 = _cell_size()
	var thickness_to_face: float = cell.z / face_cell
	for carve in wall.carves:
		var local_centre: Vector2 = carve.centre - owned_centre
		var radius_cells: float = carve.radius / face_cell
		var origin_x: float = _grid_centre().x + local_centre.x / face_cell
		var origin_y: float = _grid_centre().y + local_centre.y / face_cell
		var origin_z: float = _grid_centre().z
		# Bail out early for carves that cannot reach this chunk at all: the
		# lambda would still be evaluated at every grid point otherwise, and the
		# sweep is the whole cost of a rebuild.
		if absf(local_centre.x) - carve.radius > owned_size(face_cell) * 0.5 + face_cell * float(GHOST_CELLS + 1) \
			or absf(local_centre.y) - carve.radius > owned_size(face_cell) * 0.5 + face_cell * float(GHOST_CELLS + 1):
			continue
		field.add_layer(
			PatchField4D.VoxelMaterial.AIR,
			func(p: Vector4) -> float:
				var d := Vector3(
					p.x - origin_x,
					p.y - origin_y,
					(p.z - origin_z) * thickness_to_face)
				return radius_cells - d.length(),
			func(p: Vector4) -> Vector4:
				var offset := Vector3(
					origin_x - p.x,
					origin_y - p.y,
					(origin_z - p.z) * thickness_to_face)
				var length: float = offset.length()
				if is_zero_approx(length):
					return Vector4.ZERO
				offset /= length
				return Vector4(offset.x, offset.y, offset.z * thickness_to_face, 0.0),
			1.0,
			1 << PatchField4D.VoxelMaterial.GROUND)


func _build_mesh(contour: PatchContour4D) -> ArrayTetraMesh4D:
	if contour.ground_cells.is_empty():
		return null
	var mesh := ArrayTetraMesh4D.new()
	var remap := {}
	var texture_map := PackedVector3Array()

	for i in range(0, contour.ground_cells.size(), 4):
		var indices := PackedInt32Array()
		indices.resize(4)
		for corner in range(4):
			var source_index: int = contour.ground_cells[i + corner]
			var mapped_index: int
			if remap.has(source_index):
				mapped_index = remap[source_index]
			else:
				mapped_index = mesh.append_vertex(_grid_to_local(contour.vertices[source_index]), false)
				remap[source_index] = mapped_index
			indices[corner] = mapped_index
		mesh.append_tetra_cell_indices(indices[0], indices[1], indices[2], indices[3])
		for corner in range(4):
			texture_map.append(Vector3(0.5, 0.5, 0.5))

	mesh.simplex_cell_texture_map = texture_map
	return mesh


func _make_material() -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	PortalShading.apply(material)
	material.albedo_texture_3d = ChunkTexture
	return material


func _is_surface_point(p: Vector4i) -> bool:
	for axis in range(4):
		for delta in [-1, 1]:
			var neighbor: Vector4i = p
			neighbor[axis] += delta
			if field.is_inside(neighbor) and field.material_at(neighbor) != PatchField4D.VoxelMaterial.GROUND:
				return true
	return false


## Colliders only for owned cells, or neighbouring chunks would stack duplicate
## boxes along every shared boundary.
func _rebuild_colliders() -> void:
	for child in _voxels.get_children():
		_voxels.remove_child(child)
		child.queue_free()

	var cell: Vector4 = _cell_size()
	var box := BoxShape4D.new()
	box.size = cell
	var count := 0

	for x in range(GHOST_CELLS, FACE_GRID - GHOST_CELLS):
		for y in range(GHOST_CELLS, FACE_GRID - GHOST_CELLS):
			for z in range(THICK_GRID):
				for w in range(W_GRID):
					var grid_point := Vector4i(x, y, z, w)
					if field.material_at(grid_point) != PatchField4D.VoxelMaterial.GROUND:
						continue
					if not _is_surface_point(grid_point):
						continue
					var collider := CollisionShape4D.new()
					collider.shape = box
					collider.position = _grid_to_local(
						Vector4(float(x), float(y), float(z), float(w)))
					_voxels.add_child(collider)
					count += 1
	collider_count = count
