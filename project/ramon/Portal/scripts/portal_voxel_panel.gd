extends Node4D
## One portalable panel: a destructible dual-contoured 4D slab you can shoot
## holes in, built on [VoxelField4D]/[DualContour4D] from
## project/ramon/voxel_port/ exactly the way VoxelMining's block does - a
## persistent field with carves added as further AIR layers, plus one
## [BoxShape4D] per solid grid point on the surface so a hit resolves to an
## exact voxel.
##
## Why a panel rather than a whole voxel chamber. A VoxelField4D is finite in
## every axis including w, so a voxel wall only exists across grid_size cells of
## w and vanishes if the player moves past that - the chamber shell has to be
## ordinary w-invariant box geometry (the PhaseMaze/hub convention) or the room
## stops being a room. Portal's own design happens to want exactly that split:
## most surfaces refuse portals, specific panels accept them. So the expensive,
## finite, destructible thing is confined to the surfaces that need it, and the
## cheap, infinite, structural thing carries the room. See PORTAL_GAME_RESEARCH.md.
##
## Deliberately NOT @tool. Everything here is generated at runtime and never
## owned by the scene, which sidesteps the MeshInstance4D-serialises-its-mesh
## trap in follow_up/engine_gotchas.md entirely.

const PANEL_TEXTURE: Texture3D = preload("res://textures/dev_finals/ramdev_white.png")

## Grid points per axis; the field is grid_size^4 points, so this is the number
## that governs cost. 8 is what VoxelMining proved responsive for a per-hit full
## remesh - raising it to 16 is 16x the points, not 2x.
var grid_size: int = 8
## Metres per grid cell. Physical panel size is grid_size * cell_size, so this
## is the free parameter for "how big is the panel" once grid_size is fixed by
## the cost budget.
var cell_size: float = 0.5
## Half-extent of the slab across its face, in cells. Must leave the grid margin
## the boulder/box shapes learned the hard way: solid geometry within 1.1 cells
## of the boundary cannot be contoured and leaves a ragged open face that looks
## exactly like a flipped normal. See feedback in VoxelMining's notes.
var face_half_cells: float = 2.9
## Half-thickness along the panel's normal, in cells. Portal apertures are
## shallow recesses, never tunnels (Valve: portals sit 0-8 units off the host
## surface), so this only has to be thick enough to carve into.
var thickness_half_cells: float = 1.5
## Which axis the panel faces: 0 = x, 2 = z. The chamber only ever builds
## axis-aligned panels, which is what keeps both sides of a crossing
## axis-aligned and sidesteps Portal 2's hardest problem - see the research note.
var normal_axis: int = 2

var field: VoxelField4D = null
var last_remesh_msec: float = 0.0
var last_carve_msec: float = 0.0
var collider_count: int = 0
var tetra_count: int = 0

var _collider_grid_point: Dictionary = {}
var _mesh_instance: MeshInstance4D = null
var _voxels: StaticBody4D = null


## Builds the slab and its colliders. Call once after setting the vars above.
func build() -> void:
	_mesh_instance = MeshInstance4D.new()
	_mesh_instance.name = &"Surface"
	# One material for the panel's whole life, not one per remesh - a carve
	# rebuilds the mesh many times and the material never changes.
	_mesh_instance.material_override = _make_material()
	add_child(_mesh_instance)
	_voxels = StaticBody4D.new()
	_voxels.name = &"Voxels"
	add_child(_voxels)

	field = VoxelField4D.new(grid_size)
	_add_slab_layer()
	_remesh()


## Positive density inside, as this project's fields define it (the opposite of
## the usual SDF convention - the note in feedback_voxel_mining_lessons about
## re-deriving formulas by hand applies, so this is the box layer's own logic
## generalised to unequal extents rather than a fresh derivation).
func _add_slab_layer() -> void:
	var center: Vector4 = Vector4.ONE * (float(grid_size) * 0.5)
	var half_extents := Vector4(face_half_cells, face_half_cells, face_half_cells, face_half_cells)
	half_extents[normal_axis] = thickness_half_cells

	field.add_layer(
		VoxelField4D.VoxelMaterial.GROUND,
		func(p: Vector4) -> float:
			var d: Vector4 = p - center
			var smallest_margin: float = INF
			for axis in range(4):
				smallest_margin = minf(smallest_margin, half_extents[axis] - absf(d[axis]))
			return smallest_margin,
		func(p: Vector4) -> Vector4:
			var d: Vector4 = p - center
			# The limiting axis is the one whose face is nearest; the gradient
			# must point toward increasing density (inward), which VoxelField4D
			# then flips into the outward-facing edge normal itself.
			var limiting_axis := 0
			var smallest_margin: float = INF
			for axis in range(4):
				var margin: float = half_extents[axis] - absf(d[axis])
				if margin < smallest_margin:
					smallest_margin = margin
					limiting_axis = axis
			var gradient := Vector4.ZERO
			gradient[limiting_axis] = -signf(d[limiting_axis])
			return gradient,
		1.0)


## The carve. [param shape] is what a raycast hands back directly, so which
## voxel was hit is a dictionary lookup rather than coordinate math - the same
## trick voxel_mining_block.gd uses, and the reason per-voxel BoxShape4D
## colliders are worth their node count.
func carve_at_shape(shape: CollisionShape4D, radius_metres: float) -> bool:
	if field == null or not _collider_grid_point.has(shape):
		return false
	var grid_point: Vector4i = _collider_grid_point[shape]
	if field.material_at(grid_point) != VoxelField4D.VoxelMaterial.GROUND:
		return false

	var started_usec: int = Time.get_ticks_usec()
	var origin := Vector4(grid_point.x, grid_point.y, grid_point.z, grid_point.w)
	var radius_in_cells: float = radius_metres / cell_size
	field.add_layer(
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
	last_carve_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0
	return true


func _remesh() -> void:
	var started_usec: int = Time.get_ticks_usec()
	var contour := DualContour4D.new(field)
	contour.generate()
	var center: float = float(field.size - 1) * 0.5
	_mesh_instance.mesh = _build_mesh(contour, center)
	tetra_count = contour.ground_cells.size() / 4
	_rebuild_colliders(center)
	last_remesh_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0


func _build_mesh(contour: DualContour4D, center: float) -> ArrayTetraMesh4D:
	if contour.ground_cells.is_empty():
		return null

	var mesh := ArrayTetraMesh4D.new()
	var remap := {}
	var texture_map := PackedVector3Array()
	var grid_centre := Vector4(center, center, center, center)

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
				mapped_index = mesh.append_vertex((grid_position - grid_centre) * cell_size, false)
				remap[source_index] = mapped_index
			indices[corner] = mapped_index
		mesh.append_tetra_cell_indices(indices[0], indices[1], indices[2], indices[3])
		# The dev textures are flat colour, so every cell vertex samples the same
		# point rather than carrying a slope/altitude ramp like the mining rock.
		# A panel wants to read as one clean manufactured surface, not as rock.
		for corner in range(4):
			texture_map.append(Vector3(0.5, 0.5, 0.5))

	mesh.simplex_cell_texture_map = texture_map
	return mesh


## Flat/unlit shading, as PhaseMaze and the shooting gallery use: this chamber
## has no Light4D, and without one every TetraMaterial4D surface renders pure
## black since Aaron's lighting landed. The swap must happen before the texture
## is assigned - setting the texture re-runs update_cross_section_material(),
## which only fills an empty shader slot.
func _make_material() -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	FlatShadingRamon.apply(material)
	material.albedo_texture_3d = PANEL_TEXTURE
	return material


## True if this solid point touches anything non-solid, i.e. is on the reachable
## shell. Buried points get no collider: a ray from outside always hits the shell
## first, so an interior collider is pure node count. Carving exposes new points,
## which pick up colliders on the next rebuild.
func _is_surface_point(p: Vector4i) -> bool:
	for axis in range(4):
		for delta in [-1, 1]:
			var neighbor: Vector4i = p
			neighbor[axis] += delta
			if field.is_inside(neighbor) and field.material_at(neighbor) != VoxelField4D.VoxelMaterial.GROUND:
				return true
	return false


func _rebuild_colliders(center: float) -> void:
	_collider_grid_point.clear()
	for child in _voxels.get_children():
		# Detached from the tree before being freed, not merely queue_free()'d.
		# queue_free() is deferred to the end of the frame, so the old colliders
		# would still answer get_children() and still be in the physics world
		# alongside their replacements for the rest of this frame - a shot landing
		# in that window resolves to a shape that is no longer in the grid-point
		# map and is silently refused. Caught by _verify_chamber.gd's second carve.
		_voxels.remove_child(child)
		child.queue_free()

	var box := BoxShape4D.new()
	box.size = Vector4.ONE * cell_size
	var grid_centre := Vector4(center, center, center, center)
	var count := 0

	for x in range(field.size):
		for y in range(field.size):
			for z in range(field.size):
				for w in range(field.size):
					var grid_point := Vector4i(x, y, z, w)
					if field.material_at(grid_point) != VoxelField4D.VoxelMaterial.GROUND:
						continue
					if not _is_surface_point(grid_point):
						continue
					var collider := CollisionShape4D.new()
					collider.shape = box
					collider.position = (Vector4(x, y, z, w) - grid_centre) * cell_size
					_voxels.add_child(collider)
					_collider_grid_point[collider] = grid_point
					count += 1

	collider_count = count
