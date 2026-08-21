@tool
extends "res://ramon/VoxelMining/scripts/voxel_mining_block.gd"
## The presentation block for `voxel_mining_final.tscn`: an ordinary mining
## block whose colour says whether a surface is ORIGINAL CRUST or FRESHLY CUT -
## dark grey rock outside, hot orange core wherever the axe has broken through.
##
## A subclass rather than an edit of voxel_mining_block.gd because that script's
## palette lives in a `static var` shared by every block in the project (arch,
## boulder, gem and sphere all inherit it), so retinting it there would repaint
## four other test scenes. Nothing about mining, meshing or collision changes -
## see the base class for all of that.
##
## HOW THE REVEAL WORKS - no shader, no second mesh, no visibility scripting.
## The base class already hands the cross-section shader a per-vertex UVW and
## looks the colour up in a small baked palette image; a Texture3D sampled by
## cell UVW is the only colour path that reaches that shader at all (see
## project/ramon/follow_up/engine_gotchas.md). The base spends the palette's V
## axis on world altitude, which means nothing on a single hand-sized rock, so
## this class spends it on DEPTH instead: how far the vertex sits inside the
## block's original box surface.
##
## A vertex on the untouched outer box has depth 0 and comes out grey. A vertex
## that only exists because mining carved a crater is further in, and fades to
## orange across [member crust_metres]. So the orange is not revealed by any
## code - it is simply what the inside of the rock has always been, and cutting
## is what creates surface down there for the palette to colour. Same reasoning
## as voxel_mining_gem_block.gd's cavity, one step more general.
##
## Assumes the base box shape, since the depth measure is that box's own
## distance field. A subclass that overrode [method _build_base_shape] would
## need to override [method _depth_at] to match.

const PALETTE_SIZE := 32

## Rows/columns held back at each end of the palette as duplicates of the extreme
## colours, so the usable ramp never sits near the texture's wrap seam. See
## [method _texel_center] for the measurement that forced this.
const PALETTE_GUARD := 2

## How a single bite measures distance from the point that was hit.
enum BiteShape {
	## Euclidean. A round crater, and the shape the base class always uses.
	ROUND,
	## Largest-axis (chebyshev). A cube-shaped crater.
	BOXY,
}

@export_group("Mining")
## THE PROBLEM THIS EXISTS TO SOLVE. The carve is sampled only at whole grid
## points, so a ROUND bite of radius r removes a point only when its euclidean
## distance is under r. At the stock 1.2 cells that is the hit point and its
## eight axis neighbours - 9 of the 81 points in a 3^4 neighbourhood. Every
## diagonal neighbour sits at 1.414 cells or more and survives, so two craters
## landing diagonally leave a one-cell wall of rock standing between them: the
## thin plates that show up along the block's edges as you mine it out.
##
## Raising [member mining_radius_meters] past sqrt(2) * cell_size fixes it too,
## and that is the route voxel_mining_final_block.tscn takes: it ships a radius
## of 0.60 m against the default 0.40 m cell, which is 1.50 cells - just over the
## 1.414 threshold. Measured by sweeping two diagonal bites: a plate survives at
## 1.38 cells and is gone at 1.45, exactly where the arithmetic says.
##
## BOXY fixes it at any radius instead: largest-axis distance is 1.0 for every
## neighbour in the 3^4 block, diagonals included, so radius 1 clears all 81 and
## nothing can be left behind. The trade is that craters read as cubes rather
## than bowls, which is why round plus a wide enough radius is the default.
##
## Worth knowing before reaching for a smaller round bite: the ratio of bite to
## rock is fixed by grid_size and box_fill_fraction, not by cell_size, because
## the sqrt(2) threshold is measured in cells. At grid 8 and fill 0.65 the rock
## is 5.2 cells across, so the narrowest ridge-free round bite is already 58% of
## its width. Smaller bites need a HIGHER grid_size, which costs grid_size^4 -
## see the cost table in the tuner.
@export var bite_shape: BiteShape = BiteShape.ROUND

@export_group("Crust")
## Thickness of the dark outer shell, in meters. A cut shallower than this still
## reads as grey rock; past it the cut face is fully orange. Roughly one voxel
## is the useful default - one bite of the axe should break through, or the
## reveal never reads.
@export_range(0.05, 2.0, 0.01, "suffix:m") var crust_metres: float = 0.45:
	set(value):
		crust_metres = value
		_refresh_palette()

## Crust on a flat face. Steep and overhanging faces darken toward
## [member crust_shadow], which is the only shading cue a faceted mesh has
## beyond the scene lighting.
@export var crust_color: Color = Color(0.42, 0.425, 0.43):
	set(value):
		crust_color = value
		_refresh_palette()

@export var crust_shadow: Color = Color(0.19, 0.195, 0.205):
	set(value):
		crust_shadow = value
		_refresh_palette()

## Core on a flat cut face, and on a steep one. Kept saturated rather than
## emissive: TetraMaterial4D has no emission channel, so the orange has to earn
## its punch from albedo plus whatever light reaches into the crater.
@export var core_color: Color = Color(0.97, 0.44, 0.09):
	set(value):
		core_color = value
		_refresh_palette()

@export var core_shadow: Color = Color(0.55, 0.17, 0.03):
	set(value):
		core_shadow = value
		_refresh_palette()

## Baked per instance rather than in a `static var` like the base class, because
## the colours above are per-instance exports - a shared cache would hand the
## first block's palette to every later one and silently ignore their settings.
## It is a 32x32 RGB8 image, so there is nothing to save by sharing it.
var _palette_texture: ImageTexture3D = null

## Wall time of the most recent contour-and-collider rebuild, in milliseconds.
## Read by voxel_mining_tuner.gd so the cost of raising grid_size is a number on
## screen rather than a feeling - the field sweep is O(grid_size^4), so it climbs
## far faster than the slider suggests.
var last_remesh_msec: float = 0.0


## The base's carve, with [member bite_shape] choosing how distance is measured.
## Forked whole because the base builds its density and gradient callables inline
## inside add_layer, with no hook to swap them.
##
## Both gradients point toward the carve's own centre - i.e. toward INCREASING
## density, which is the convention every layer in VoxelField4D uses and which
## its is_denser flip assumes. Getting that backwards renders the surface
## inside-out. The boxy pair is lifted from [method _build_base_shape], which
## already solves exactly this for a box, rather than derived fresh: this
## project's density sign is the opposite of the usual SDF convention and a
## hand-rolled formula gets it wrong in a way that looks like a normals bug.
func mine_at_shape(shape: CollisionShape4D) -> void:
	if _field == null or not _collider_grid_point.has(shape):
		return
	var grid_point: Vector4i = _collider_grid_point[shape]
	if _field.material_at(grid_point) != VoxelField4D.VoxelMaterial.GROUND:
		return

	var origin := Vector4(grid_point.x, grid_point.y, grid_point.z, grid_point.w)
	var radius_in_cells: float = mining_radius_meters / cell_size
	var density_fn: Callable
	var gradient_fn: Callable

	if bite_shape == BiteShape.BOXY:
		density_fn = func(p: Vector4) -> float:
			var d: Vector4 = p - origin
			var largest: float = maxf(maxf(absf(d.x), absf(d.y)), maxf(absf(d.z), absf(d.w)))
			return radius_in_cells - largest
		gradient_fn = func(p: Vector4) -> Vector4:
			var d: Vector4 = p - origin
			var best_axis := 0
			var best_value := -1.0
			for axis in range(4):
				if absf(d[axis]) > best_value:
					best_value = absf(d[axis])
					best_axis = axis
			var gradient := Vector4.ZERO
			gradient[best_axis] = -signf(d[best_axis])
			return gradient
	else:
		density_fn = func(p: Vector4) -> float:
			return radius_in_cells - (p - origin).length()
		gradient_fn = func(p: Vector4) -> Vector4:
			var offset: Vector4 = origin - p
			var length: float = offset.length()
			return Vector4.ZERO if is_zero_approx(length) else offset / length

	_field.add_layer(
		VoxelField4D.VoxelMaterial.AIR,
		density_fn,
		gradient_fn,
		1.0,
		1 << VoxelField4D.VoxelMaterial.GROUND)
	_remesh()


## Times the base's remesh. Everything else about it is unchanged.
func _remesh() -> void:
	var started_usec := Time.get_ticks_usec()
	super()
	last_remesh_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0


## Rebuilt from the base's [method _remesh] path rather than by poking the
## existing material, since the palette is baked into a texture the mesh's
## material already holds a reference to. Cheap at this grid size, and only
## happens on an inspector edit.
func _refresh_palette() -> void:
	_palette_texture = null
	# Setters fire during scene load, before generate() has ever run. Nothing to
	# remesh then, and the first generate() will pick the new colours up anyway.
	if _field != null:
		_remesh()


## Identical to the base's, except the palette's V axis carries crust depth
## instead of world altitude, and the palette is this instance's own. Forked
## whole because the base builds the mesh and its UVW map in one pass with no
## per-vertex hook to override.
func _build_mesh(contour: DualContour4D, center: float) -> ArrayTetraMesh4D:
	if contour.ground_cells.is_empty():
		return null

	var mesh := ArrayTetraMesh4D.new()
	var remap := {}
	var texture_map := PackedVector3Array()

	# The base box in grid coordinates, matching what _build_base_shape laid
	# down. Note generate() centres that box on size * 0.5 while the MESH is
	# centred on (size - 1) * 0.5 - the two really are different, and measuring
	# depth against the mesh's centre would skew the crust half a cell to one
	# side of the rock and leave the opposite face permanently orange.
	var box_center: Vector4 = Vector4.ONE * (float(_field.size) * 0.5)
	var box_half_extent: float = float(_field.size) * 0.5 * box_fill_fraction

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
			texture_map.append(Vector3(
				_texel_center(_slope_at(contour.vertex_normals[source_index])),
				_texel_center(_depth_at(contour.vertices[source_index], box_center, box_half_extent)),
				0.5))

	mesh.simplex_cell_texture_map = texture_map
	var material := TetraMaterial4D.new()
	material.albedo_texture_3d = albedo_texture_3d if albedo_texture_3d != null else _palette()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	mesh.material = material
	return mesh


## Maps 0..1 onto the centres of the palette's usable texels - the ones inside
## [constant PALETTE_GUARD] - instead of onto the texture's outer edges.
##
## THE BUG THIS FIXES, worth knowing for ANY palette sampled through
## TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY. The palette wraps and filters
## linearly, so a lookup at 0.0 sits on the seam between texel 0 and the
## wrapped-around LAST texel and returns a 50/50 blend of the two. With crust at
## one end of the ramp and core at the other, every untouched face on this block
## rendered half-orange. It does not read as a sampling artifact, it reads as a
## broken depth measure. What settled it was swapping in a marker palette banded
## by row (0-10 red, 11-20 green, 21-31 blue): the block came back MAGENTA - the
## two ends of the ramp mixed, with the green middle nowhere on screen.
##
## Landing exactly on texel 0's centre is not enough on its own, and this is the
## part that is easy to miss. The mesh packs one of its four corner UVWs into the
## vertex NORMAL (see TetraMesh4D::update_cross_section_mesh, which stores
## `vec3(u, v, 1)` and has the shader recover `NORMAL.xy / NORMAL.z`), and Godot
## compresses normals to octahedral, so that corner's coordinates come back with
## a few thousandths of error. Enough to fall a hair BELOW the first texel's
## centre, reach across the seam again, and speckle the whole rock warm - which
## is exactly what the second render still showed. The guard rows put real
## headroom around the ramp instead of relying on hitting a centre exactly.
func _texel_center(value: float) -> float:
	var span := float(PALETTE_SIZE - 1 - 2 * PALETTE_GUARD)
	return (float(PALETTE_GUARD) + clampf(value, 0.0, 1.0) * span + 0.5) / float(PALETTE_SIZE)


## 0 on the block's original outer face, 1 once [member crust_metres] inside it.
##
## Reuses the base box's own distance function (largest-axis distance from
## centre, i.e. a chebyshev/box SDF) so the crust follows the block's real
## surface rather than a bounding sphere - a sphere would leave the corners
## looking freshly cut before anyone touched them.
func _depth_at(grid_position: Vector4, box_center: Vector4, box_half_extent: float) -> float:
	var offset: Vector4 = grid_position - box_center
	var largest: float = maxf(maxf(absf(offset.x), absf(offset.y)), maxf(absf(offset.z), absf(offset.w)))
	var inside_metres: float = (box_half_extent - largest) * cell_size
	return clampf(inside_metres / maxf(crust_metres, 0.001), 0.0, 1.0)


func _palette() -> ImageTexture3D:
	if _palette_texture == null:
		_palette_texture = _bake_palette()
	return _palette_texture


## X across the image is slope, Y is crust depth. One slice deep, which is what
## TetraMaterial4D's UVW lookup wants - the third UVW component is left at 0.5
## by [method _build_mesh] and carries nothing.
##
## The ramp is clamped into the guard rows rather than stretched across the whole
## image, so the outermost rows/columns simply repeat the extremes. Combined with
## [method _texel_center], that means even a lookup that strays over the wrap
## seam picks up the colour it was already going to get.
func _bake_palette() -> ImageTexture3D:
	var image: Image = Image.create_empty(PALETTE_SIZE, PALETTE_SIZE, false, Image.FORMAT_RGB8)
	var span := float(PALETTE_SIZE - 1 - 2 * PALETTE_GUARD)
	for y in range(PALETTE_SIZE):
		var depth: float = clampf((float(y) - PALETTE_GUARD) / span, 0.0, 1.0)
		for x in range(PALETTE_SIZE):
			var slope: float = clampf((float(x) - PALETTE_GUARD) / span, 0.0, 1.0)
			image.set_pixel(x, y, _surface_color(slope, depth))

	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGB8, PALETTE_SIZE, PALETTE_SIZE, 1, false, [image])
	return texture


## Smoothstepped rather than linear so the transition reads as a thin rim of
## scorched rock around a cut instead of a wide muddy gradient - a linear ramp
## over one voxel spends most of its range on colours that are neither grey nor
## orange, which is exactly the part that looks like a bug.
##
## The dead zone below 0.3 is deliberately generous. Untouched faces measure a
## depth of at most ~0.09 (dual contouring places its vertices a little inside
## the true isosurface, and the shader interpolates UVW along every sliced edge
## on top of that), so anything tighter lets a warm cast bleed across a rock
## nobody has touched. Measured: at 0.12 the untouched faces came back visibly
## brown; at 0.3 they are neutral grey and the crater is unaffected, since a
## carved face measures 0.6 or more.
func _surface_color(slope: float, depth: float) -> Color:
	var crust: Color = crust_color.lerp(crust_shadow, slope)
	var core: Color = core_color.lerp(core_shadow, slope)
	return crust.lerp(core, smoothstep(0.3, 0.85, depth))
