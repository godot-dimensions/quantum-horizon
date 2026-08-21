extends Node4D
## A small piece of wall, swapped in where you shoot, made of voxels instead of
## boxes - so the hole through it is a genuinely round dual-contoured cut rather
## than a staircase of slabs.
##
## Dual contouring places one vertex per cell at the position the QEF says the
## real surface passes through, so the rim lands ON the circle rather than being
## snapped to the grid. That is why the mining rocks read as rounded at grid 8,
## and it is what a box decomposition can never do.
##
## The grid is ANISOTROPIC, and that is the whole reason this is affordable.
## Cost is the product of the four axis counts, and the field barely varies
## through the wall's thickness or along w - so those axes get 5 cells while the
## face gets 16. A cubic grid fine enough for a smooth rim would be 16^4 = 65,536
## points (seconds per shot); 16 x 16 x 5 x 5 is 6,400 for the same rim quality.
##
## Rim smoothness is set by how many CELLS the circle crosses, not by the cut
## radius: roughly 2*pi*radius_in_cells facets. The cross-section renderer
## computes flat per-triangle normals and discards smooth ones (see
## follow_up/engine_gotchas.md), so every facet is shaded separately and a
## 16-facet circle reads unmistakably as a polygon. ~33 is where it stops
## looking like one.

const PatchTexture: Texture3D = preload("res://textures/dev_finals/ramdev_white.png")

## Cells across the patch face, and metres per cell there.
const FACE_GRID := 16
const FACE_CELL := 0.22
## Cells through the wall's thickness and along w. Small on purpose: the slab is
## uniform along both, so resolution there buys nothing and costs everything.
const THICK_GRID := 5
const W_GRID := 5
## Half the slab's thickness, in cells. Two cells of solid is enough for a front
## and a back face with a gap between them.
const SLAB_HALF_CELLS := 1.0
## Geometry must stay this far from the field boundary: contouring skips boundary
## cells, so anything reaching the edge comes out ragged and open.
const EDGE_MARGIN_CELLS := 1.5

var thickness: float = 0.6
var w_half_extent: float = 12.0

## Cut ball radius in metres, across the face.
var cut_radius: float = 1.15
## Where the ball is centred, in patch-local metres across the face.
var cut_centre := Vector2.ZERO

var field: PatchField4D = null
var build_msec: float = 0.0
var collider_count: int = 0
var tetra_count: int = 0
var rim_facets: int = 0

var _mesh_instance: MeshInstance4D = null
var _voxels: StaticBody4D = null


## Half the patch's face size, in metres. The wall opens a window exactly this
## big for the patch to sit in.
static func face_half_extent() -> float:
	return (float(FACE_GRID) * 0.5 - EDGE_MARGIN_CELLS) * FACE_CELL


func _grid_size() -> Vector4i:
	return Vector4i(FACE_GRID, FACE_GRID, THICK_GRID, W_GRID)


## Metres per cell, per axis. The two face axes share a scale, which is what
## keeps a ball in grid space a circle in the wall.
func _cell_size() -> Vector4:
	return Vector4(
		FACE_CELL,
		FACE_CELL,
		thickness * 0.5 / SLAB_HALF_CELLS,
		w_half_extent * 2.0 / float(W_GRID))


## Centre of the grid in POINT coordinates: (size - 1) / 2, not size / 2.
##
## Both conventions are defensible and mixing them is a half-cell error. The SDF
## layers used size/2 while the mesh and colliders used (size-1)/2, which sat the
## whole patch 0.15 m proud of the wall it was supposed to fill - visible as a
## slab standing off the surface with a shadow gap around it. VoxelMining has the
## same mismatch and gets away with it because a floating rock has nothing to
## line up against.
func _grid_centre() -> Vector4:
	var size: Vector4i = _grid_size()
	return Vector4(float(size.x - 1), float(size.y - 1), float(size.z - 1), float(size.w - 1)) * 0.5


func build() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_mesh_instance = MeshInstance4D.new()
	_mesh_instance.name = &"Surface"
	_mesh_instance.material_override = _make_material()
	add_child(_mesh_instance)
	_voxels = StaticBody4D.new()
	_voxels.name = &"Voxels"
	add_child(_voxels)

	field = PatchField4D.new(_grid_size())
	_add_slab_layer()
	_add_ball_cut()
	_remesh()
	rim_facets = int(round(TAU * cut_radius / FACE_CELL))
	build_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0


## Positive density inside, this project's convention. Bounded across the face
## and in thickness, spanning w entirely - a wall must not stop existing when the
## player moves along w.
func _add_slab_layer() -> void:
	var centre: Vector4 = _grid_centre()
	var face_half: float = float(FACE_GRID) * 0.5 - EDGE_MARGIN_CELLS
	var slab_half: float = SLAB_HALF_CELLS

	field.add_layer(
		PatchField4D.VoxelMaterial.GROUND,
		func(p: Vector4) -> float:
			return minf(
				face_half - absf(p.x - centre.x),
				minf(face_half - absf(p.y - centre.y), slab_half - absf(p.z - centre.z))),
		func(p: Vector4) -> Vector4:
			# Toward increasing density, i.e. inward along whichever face is
			# nearest; the field flips that into the outward edge normal.
			var margins := [
				face_half - absf(p.x - centre.x),
				face_half - absf(p.y - centre.y),
				slab_half - absf(p.z - centre.z)]
			var limiting := 0
			for axis in range(1, 3):
				if margins[axis] < margins[limiting]:
					limiting = axis
			var gradient := Vector4.ZERO
			gradient[limiting] = -signf(p[limiting] - centre[limiting])
			return gradient,
		1.0)


## The cut: a ball of AIR replacing GROUND, the same layer mechanic
## VoxelMining's mine_at_shape uses. Measured only across the face and thickness
## so it runs the full length of w - a hole that existed at some w and not others
## would be a very confusing wall.
func _add_ball_cut() -> void:
	var centre: Vector4 = _grid_centre()
	var origin := Vector4(
		centre.x + cut_centre.x / FACE_CELL,
		centre.y + cut_centre.y / FACE_CELL,
		centre.z,
		0.0)
	# Expressed in FACE cells, and the thickness axis is scaled into face cells
	# so the ball stays a ball in world space rather than in grid space.
	var thickness_to_face: float = (thickness * 0.5 / SLAB_HALF_CELLS) / FACE_CELL
	var radius_cells: float = cut_radius / FACE_CELL

	field.add_layer(
		PatchField4D.VoxelMaterial.AIR,
		func(p: Vector4) -> float:
			var d := Vector3(
				p.x - origin.x,
				p.y - origin.y,
				(p.z - origin.z) * thickness_to_face)
			return radius_cells - d.length(),
		func(p: Vector4) -> Vector4:
			var offset := Vector3(
				origin.x - p.x,
				origin.y - p.y,
				(origin.z - p.z) * thickness_to_face)
			var length: float = offset.length()
			if is_zero_approx(length):
				return Vector4.ZERO
			offset /= length
			return Vector4(offset.x, offset.y, offset.z * thickness_to_face, 0.0),
		1.0,
		1 << PatchField4D.VoxelMaterial.GROUND)


func _remesh() -> void:
	var contour := PatchContour4D.new(field)
	contour.generate()
	tetra_count = contour.ground_cells.size() / 4
	_mesh_instance.mesh = _build_mesh(contour)
	_rebuild_colliders()


func _build_mesh(contour: PatchContour4D) -> ArrayTetraMesh4D:
	if contour.ground_cells.is_empty():
		return null
	var mesh := ArrayTetraMesh4D.new()
	var remap := {}
	var texture_map := PackedVector3Array()
	var grid_centre: Vector4 = _grid_centre()
	var cell: Vector4 = _cell_size()

	for i in range(0, contour.ground_cells.size(), 4):
		var indices := PackedInt32Array()
		indices.resize(4)
		for corner in range(4):
			var source_index: int = contour.ground_cells[i + corner]
			var mapped_index: int
			if remap.has(source_index):
				mapped_index = remap[source_index]
			else:
				var g: Vector4 = contour.vertices[source_index] - grid_centre
				mapped_index = mesh.append_vertex(
					Vector4(g.x * cell.x, g.y * cell.y, g.z * cell.z, g.w * cell.w), false)
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
	FlatShadingRamon.apply(material)
	material.albedo_texture_3d = PatchTexture
	return material


func _is_surface_point(p: Vector4i) -> bool:
	for axis in range(4):
		for delta in [-1, 1]:
			var neighbor: Vector4i = p
			neighbor[axis] += delta
			if field.is_inside(neighbor) and field.material_at(neighbor) != PatchField4D.VoxelMaterial.GROUND:
				return true
	return false


## One BoxShape4D per exposed voxel, as VoxelMining does: the axis-aligned
## physics engine collapses any other shape to a single box. Collision is
## therefore chunky where the mesh is smooth - invisible, and the only option.
func _rebuild_colliders() -> void:
	for child in _voxels.get_children():
		_voxels.remove_child(child)
		child.queue_free()

	var size: Vector4i = _grid_size()
	var cell: Vector4 = _cell_size()
	var box := BoxShape4D.new()
	box.size = cell
	var grid_centre: Vector4 = _grid_centre()
	var count := 0

	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				for w in range(size.w):
					var grid_point := Vector4i(x, y, z, w)
					if field.material_at(grid_point) != PatchField4D.VoxelMaterial.GROUND:
						continue
					if not _is_surface_point(grid_point):
						continue
					var collider := CollisionShape4D.new()
					collider.shape = box
					collider.position = Vector4(
						(float(x) - grid_centre.x) * cell.x,
						(float(y) - grid_centre.y) * cell.y,
						(float(z) - grid_centre.z) * cell.z,
						(float(w) - grid_centre.w) * cell.w)
					_voxels.add_child(collider)
					count += 1
	collider_count = count
