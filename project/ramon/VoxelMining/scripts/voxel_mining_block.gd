@tool
extends Node4D
## First test of a destructible dual-contoured 4D voxel block: one solid,
## axis-aligned box (no water, no noise, no rotation - the simplest possible
## shape) built on [VoxelField4D]/[DualContour4D]/[QEFSolver4D] from
## project/ramon/voxel_port/, plus a per-voxel [BoxShape4D] collider grid so a
## single mined-out voxel can be identified and removed exactly.
##
## Deliberately reuses voxel_port's field/contour/QEF classes directly rather
## than forking them - they are already written as a reusable "field" half
## versus "terrain node" half (see VoxelField4D's own class doc), and nothing
## here needs to change their behaviour, only drive them differently: one
## persistent [VoxelField4D] survives across many [method mine_at_shape]
## calls, each one adding one more small "carve" layer on top of the initial
## box layer rather than rebuilding the field from scratch. This is the same
## add_layer() mechanism voxel_terrain_4d.gd uses to compose water/ground/
## cutoff - carving out rock is nothing more than a subsequent AIR layer with
## a replace_mask of GROUND only.
##
## Collision is one [BoxShape4D] per solid grid point ON THE SURFACE (see
## [method _is_surface_point]) rather than a [ConcaveMeshShape4D] of the
## contoured mesh, per the finding in project/ramon/follow_up/voxel_port.md:
## the only shipped PhysicsEngine4D collapses any non-BoxShape4D shape to a
## single AABB, so a mesh-shaped collider would not give per-voxel collision
## at all. A BoxShape4D is exempt from that collapse, and as a bonus a
## raycast hit against it hands back the exact CollisionShape4D node hit - so
## identifying which voxel got hacked is a dictionary lookup, not geometry.
## Buried interior points get no collider at all - a raycast from outside can
## never reach one anyway, since the surface shell always absorbs the hit
## first, so a collider there is pure node-count cost with no possible payoff.
##
## No incremental/chunked remeshing yet - every mine_at_shape() call reruns
## dual contouring over the whole field, same as voxel_terrain_4d.gd's
## generate(). Fine at this grid size (a few tens of ms); revisit if/when this
## grows past one small object.

const _SCRIPT_PATH_HINT := "res://ramon/VoxelMining/scripts/"

@export_tool_button("Generate") var _generate_action: Callable = generate
@export_tool_button("Clear") var _clear_action: Callable = clear

@export_group("Grid")
## Grid points per axis. The field is grid_size^4 points. Kept small - this is
## one hand-sized rock, not terrain - so a full remesh after every hit stays
## fast enough to feel responsive.
@export_range(4, 16, 1) var grid_size: int = 8
## World size of one grid cell, in meters.
@export_range(0.05, 2.0, 0.05, "or_greater", "suffix:m") var cell_size: float = 0.4

@export_group("Shape")
## Half-extent of the initial solid box, as a fraction of the grid's own
## half-size. Kept under 1.0 so the box sits inside the grid with a margin -
## unlike voxel_terrain_4d.gd's globe/plane layers this box never reaches the
## grid boundary, so no "cutoff" sealing layer is needed here.
@export_range(0.1, 0.9, 0.01) var box_fill_fraction: float = 0.65

@export_group("Mining")
## Radius of one carve, in meters - deliberately real-world units rather than
## grid cells, so a bite stays the same physical size no matter what
## grid_size/cell_size this particular block uses. 0.48m matches what a
## grid-cell radius of 1.2 used to give at the original default cell_size of
## 0.4m, so nothing about existing tuned blocks changes; only future
## resolution/scale changes stop silently resizing the bite.
@export_range(0.05, 2.0, 0.01, "suffix:m") var mining_radius_meters: float = 0.48

@export_group("Appearance")
## World-space Y this block's darkest rock band sits at. Shared across every
## block instance that should read as one continuous gradient (see the
## sidenote in project/ramon/follow_up/voxel_port.md's companion discussion) -
## these two values are deliberately NOT auto-fit to this block's own bounds,
## because auto-fitting would make each block's gradient independent of its
## neighbors' instead of continuing across them.
@export var world_height_min: float = -1.0
@export var world_height_max: float = 3.0
## Optional override. When null, all instances share one procedurally baked
## palette texture (see [method _shared_palette_texture]) so they read as one
## continuous surface rather than each block re-deriving its own colors.
@export var albedo_texture_3d: Texture3D = null

const PALETTE_RESOLUTION := 32
static var _cached_palette_texture: ImageTexture3D = null

var _field: VoxelField4D = null
## CollisionShape4D -> the grid point (Vector4i) it represents. Rebuilt
## wholesale on every remesh; see the class doc for why that is fine here.
var _collider_grid_point: Dictionary = {}


func _ready() -> void:
	var ground: MeshInstance4D = _get_ground_instance()
	if ground != null and ground.mesh == null:
		generate()


## See voxel_terrain_4d.gd's identical method: keeps the generated mesh out of
## the saved .tscn by dropping it right before a save and rebuilding right
## after, since it is fully reproducible from the exported parameters (plus
## whatever has been mined out - see the note on _field there being lost on
## regenerate, which is an accepted limitation of this first test).
func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		clear()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		generate()


func _get_ground_instance() -> MeshInstance4D:
	return get_node_or_null("Ground") as MeshInstance4D


func _get_voxels_body() -> StaticBody4D:
	return get_node_or_null("Voxels") as StaticBody4D


## Builds a fresh field with just the initial box layer, discarding any mining
## done so far. This is the "reset the rock" action, not something mine_at_shape
## calls - see [method _remesh] for the persistent-field path that mining uses.
func generate() -> void:
	print("[VoxelMiningBlock] %s: generate() called." % name)
	var clamped_size: int = clampi(grid_size, 4, 16)
	_field = VoxelField4D.new(clamped_size)

	var center: Vector4 = Vector4.ONE * (float(clamped_size) * 0.5)
	_build_base_shape(center, clamped_size)
	_add_extra_layers(center, clamped_size)
	_remesh()


## Override point for subclasses that want a different base shape entirely -
## see voxel_mining_sphere_block.gd and voxel_mining_boulder_block.gd. Default
## is the axis-aligned box this class is built around. Whatever a subclass
## puts here, everything downstream (dual contouring, per-voxel collision,
## mining, palette coloring) is unchanged - shape is the only thing that
## varies.
func _build_base_shape(center: Vector4, size: int) -> void:
	var half_extent: float = float(size) * 0.5 * box_fill_fraction
	_field.add_layer(
		VoxelField4D.VoxelMaterial.GROUND,
		func(p: Vector4) -> float:
			var d: Vector4 = p - center
			var largest: float = maxf(maxf(absf(d.x), absf(d.y)), maxf(absf(d.z), absf(d.w)))
			return half_extent - largest,
		func(p: Vector4) -> Vector4:
			var d: Vector4 = p - center
			var best_axis := 0
			var best_value := -1.0
			for axis in range(4):
				if absf(d[axis]) > best_value:
					best_value = absf(d[axis])
					best_axis = axis
			# Must point toward increasing density (i.e. toward the box's own
			# center), matching every other layer's convention (see globe's
			# gradient_fn) - VoxelField4D's is_denser flip assumes that
			# direction and negates it into the correct outward-facing edge
			# normal. Getting this backwards (as voxel_terrain_4d.gd's
			# hypercube layer does) renders the whole surface inside-out.
			var gradient := Vector4.ZERO
			gradient[best_axis] = -signf(d[best_axis])
			return gradient,
		1.0)


## Override point for subclasses that want to seed additional field layers
## (a cavity, a differently-placed carve) right after the base shape and
## before the first mesh/collider build - see voxel_mining_gem_block.gd for
## the one subclass that uses this. No-op here, so plain VoxelMiningBlock
## instances are unaffected.
func _add_extra_layers(_center: Vector4, _size: int) -> void:
	pass


func clear() -> void:
	_field = null
	var ground: MeshInstance4D = _get_ground_instance()
	if ground != null:
		ground.mesh = null
	_clear_colliders()


## The mining entry point. [param shape] is exactly what a raycast's "shape"
## result field hands back (see mining_axe.gd) - looked up directly against
## the dictionary [method _remesh] just built, no coordinate math needed.
func mine_at_shape(shape: CollisionShape4D) -> void:
	if _field == null or not _collider_grid_point.has(shape):
		return
	var grid_point: Vector4i = _collider_grid_point[shape]
	if _field.material_at(grid_point) != VoxelField4D.VoxelMaterial.GROUND:
		return

	var origin := Vector4(grid_point.x, grid_point.y, grid_point.z, grid_point.w)
	# Converted from meters to grid cells here, at the point of use, rather
	# than stored that way - see mining_radius_meters' own doc for why.
	var radius_in_cells: float = mining_radius_meters / cell_size
	_field.add_layer(
		VoxelField4D.VoxelMaterial.AIR,
		func(p: Vector4) -> float:
			return radius_in_cells - (p - origin).length(),
		func(p: Vector4) -> Vector4:
			var offset: Vector4 = origin - p
			var length: float = offset.length()
			return Vector4.ZERO if is_zero_approx(length) else offset / length,
		1.0,
		1 << VoxelField4D.VoxelMaterial.GROUND)

	_remesh()


## Reruns dual contouring over the current field (initial box plus however
## many carves have landed so far) and rebuilds the mesh and per-voxel
## colliders to match. Whole-field, same as voxel_terrain_4d.gd's generate() -
## no chunking/dirty-region tracking exists yet, see the class doc.
func _remesh() -> void:
	if _field == null:
		print("[VoxelMiningBlock] _remesh: _field is null, nothing to build.")
		return

	var contour := DualContour4D.new(_field)
	contour.generate()

	var center: float = float(_field.size - 1) * 0.5
	var ground: MeshInstance4D = _get_ground_instance()
	if ground == null:
		print("[VoxelMiningBlock] _remesh: no 'Ground' MeshInstance4D child found - check the scene structure.")
	else:
		ground.mesh = _build_mesh(contour, center)

	print("[VoxelMiningBlock] %s: field size %d, %d ground tetrahedra, mesh %s" % [
		name, _field.size, contour.ground_cells.size() / 4,
		"built" if (ground != null and ground.mesh != null) else "EMPTY"])

	_rebuild_colliders(center)


func _build_mesh(contour: DualContour4D, center: float) -> ArrayTetraMesh4D:
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
				var grid_position: Vector4 = contour.vertices[source_index]
				var world_position: Vector4 = (grid_position - Vector4(center, center, center, center)) * cell_size
				mapped_index = mesh.append_vertex(world_position, false)
				remap[source_index] = mapped_index
			indices[corner] = mapped_index
		mesh.append_tetra_cell_indices(indices[0], indices[1], indices[2], indices[3])

		for corner in range(4):
			var source_index: int = contour.ground_cells[i + corner]
			var grid_position: Vector4 = contour.vertices[source_index]
			var local_y: float = (grid_position.y - center) * cell_size
			texture_map.append(Vector3(
				_slope_at(contour.vertex_normals[source_index]),
				_altitude_at(global_position.y + local_y),
				0.5))

	mesh.simplex_cell_texture_map = texture_map
	var material := TetraMaterial4D.new()
	material.albedo_texture_3d = albedo_texture_3d if albedo_texture_3d != null else _shared_palette_texture()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	mesh.material = material
	return mesh


## Slope as 0 (flat face, "up" as far as a small rock has one) to 1 (vertical
## or overhanging). This block never rotates its "up" concept the way a globe
## would, so it just measures against +Y - see voxel_terrain_4d.gd's radial
## variant if this ever needs to sit on a curved world instead of a floor.
func _slope_at(normal: Vector4) -> float:
	if normal.length_squared() < 1e-8:
		return 0.0
	return clampf(1.0 - absf(normal.dot(Vector4(0, 1, 0, 0))), 0.0, 1.0)


func _altitude_at(world_y: float) -> float:
	var span: float = maxf(world_height_max - world_height_min, 0.001)
	return clampf((world_y - world_height_min) / span, 0.0, 1.0)


## Dark rock deep/low, lighter rock higher up, darkened further on steep faces
## - a simple placeholder ramp, not a final look. Shared across every block
## instance via [method _shared_palette_texture] so the banding lines up
## between them.
static func _rock_color(slope: float, altitude: float) -> Color:
	const ROCK_DARK := Color(0.16, 0.15, 0.14)
	const ROCK_MID := Color(0.42, 0.40, 0.38)
	const ROCK_LIGHT := Color(0.66, 0.64, 0.60)

	var base: Color
	if altitude < 0.5:
		base = ROCK_DARK.lerp(ROCK_MID, clampf(altitude / 0.5, 0.0, 1.0))
	else:
		base = ROCK_MID.lerp(ROCK_LIGHT, clampf((altitude - 0.5) / 0.5, 0.0, 1.0))
	return base.lerp(ROCK_DARK, clampf((slope - 0.5) * 0.6, 0.0, 1.0))


static func _shared_palette_texture() -> ImageTexture3D:
	if _cached_palette_texture != null:
		return _cached_palette_texture

	var image: Image = Image.create_empty(PALETTE_RESOLUTION, PALETTE_RESOLUTION, false, Image.FORMAT_RGB8)
	for y in range(PALETTE_RESOLUTION):
		var altitude: float = float(y) / float(PALETTE_RESOLUTION - 1)
		for x in range(PALETTE_RESOLUTION):
			var slope: float = float(x) / float(PALETTE_RESOLUTION - 1)
			image.set_pixel(x, y, _rock_color(slope, altitude))

	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGB8, PALETTE_RESOLUTION, PALETTE_RESOLUTION, 1, false, [image])
	_cached_palette_texture = texture
	return texture


func _clear_colliders() -> void:
	_collider_grid_point.clear()
	var voxels: StaticBody4D = _get_voxels_body()
	if voxels == null:
		return
	for child in voxels.get_children():
		child.queue_free()


## True if this solid point has at least one non-GROUND neighbor - i.e. it is
## actually part of the reachable surface shell, not buried where a raycast
## from outside could never land regardless of whether a collider exists
## there. See _rebuild_colliders for why that distinction is the one that
## controls collider count.
func _is_surface_point(p: Vector4i) -> bool:
	for axis in range(4):
		for delta in [-1, 1]:
			var neighbor: Vector4i = p
			neighbor[axis] += delta
			if _field.is_inside(neighbor) and _field.material_at(neighbor) != VoxelField4D.VoxelMaterial.GROUND:
				return true
	return false


## One BoxShape4D per solid grid point that actually touches the surface -
## not the buried interior, which a raycast from outside could never hit
## anyway (the surface shell always absorbs the hit first), so a collider
## there is pure waste until mining actually exposes it. Rebuilt from scratch
## every remesh, which re-derives the currently-exposed shell fresh each
## time - a point that was buried becomes a surface point the moment mining
## clears one of its neighbors, and gets a collider on the very next rebuild.
func _rebuild_colliders(center: float) -> void:
	_clear_colliders()
	var voxels: StaticBody4D = _get_voxels_body()
	if voxels == null or _field == null:
		return

	var box := BoxShape4D.new()
	box.size = Vector4.ONE * cell_size

	for x in range(_field.size):
		for y in range(_field.size):
			for z in range(_field.size):
				for w in range(_field.size):
					var grid_point := Vector4i(x, y, z, w)
					if _field.material_at(grid_point) != VoxelField4D.VoxelMaterial.GROUND:
						continue
					if not _is_surface_point(grid_point):
						continue
					var collider := CollisionShape4D.new()
					collider.shape = box
					collider.position = (Vector4(x, y, z, w) - Vector4(center, center, center, center)) * cell_size
					voxels.add_child(collider)
					_collider_grid_point[collider] = grid_point
