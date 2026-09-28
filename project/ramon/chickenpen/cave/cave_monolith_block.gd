@tool
extends "res://ramon/VoxelMining/scripts/voxel_mining_block.gd"

## The thing everyone in the cave is here for: a black cube on a ruined plinth, found in
## the hill, and nobody knows who put it there. It is the pen's own voxel block - same field,
## same dual contouring, same per-voxel colliders, and the pickaxe and the seam hang off it
## unchanged - and only its colour is its own.
##
## IT WAS A SLAB FOR AN AFTERNOON AND THAT WAS WORSE (Ramon, 28 Sept). Stood on end as a
## 2001 monolith it was two cells thick: two blows went through it, the bites came out
## square, and it no longer felt like dual contouring. The cube in cave.tscn is the field
## rock's exact settings - 8^4 at 0.8 m, a 0.96 m bite - which are what cut away in round
## pieces and could be walked round and dug from several sides.
##
## THE PROPORTIONS ARE STILL THERE, per axis of (x, y, z, w), for anything that wants a
## block of another shape; cave.tscn sets them all to 1.

## Each half-extent as a fraction of the base shape's half-size (voxel_mining_block's
## box_fill_fraction of half the grid).
@export var proportions: Vector4 = Vector4(0.44, 1.0, 0.24, 0.44)
## The face colour, and the colour its edges and the steeper cuts catch.
@export var face_colour: Color = Color(0.05, 0.055, 0.065)
@export var sheen_colour: Color = Color(0.32, 0.35, 0.42)

static var _dark_palette: ImageTexture3D


func _ready() -> void:
	if albedo_texture_3d == null:
		albedo_texture_3d = _palette()
	super()


func _build_base_shape(center: Vector4, size: int) -> void:
	var half: float = float(size) * 0.5 * box_fill_fraction
	var extent := Vector4(half * proportions.x, half * proportions.y, half * proportions.z, half * proportions.w)
	_field.add_layer(
		VoxelField4D.VoxelMaterial.GROUND,
		func(p: Vector4) -> float:
			# A box with unequal sides: inside while every axis is inside its own half-size.
			# Measured in cells from the nearest face, so the density keeps the units the
			# plain box's does.
			var d: Vector4 = (p - center).abs()
			return minf(minf(extent.x - d.x, extent.y - d.y), minf(extent.z - d.z, extent.w - d.w)),
		func(p: Vector4) -> Vector4:
			# Toward the centre along whichever face is nearest - the plain box's rule, with
			# "nearest" judged against each axis's own half-size.
			var d: Vector4 = p - center
			var best_axis := 0
			var best_gap := INF
			for axis in 4:
				var gap: float = extent[axis] - absf(d[axis])
				if gap < best_gap:
					best_gap = gap
					best_axis = axis
			var gradient := Vector4.ZERO
			gradient[best_axis] = -signf(d[best_axis])
			return gradient,
		1.0)


## Near-black faces, a cold sheen where the surface turns - the palette is indexed by
## slope along x and height along y, like the rock's, so a fresh cut into the slab shows
## lighter than its polished faces.
func _palette() -> ImageTexture3D:
	if _dark_palette != null:
		return _dark_palette
	var n := 16
	var image: Image = Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var slope: float = float(x) / float(n - 1)
			var height: float = float(y) / float(n - 1)
			image.set_pixel(x, y, face_colour.lerp(sheen_colour, pow(slope, 1.6) * 0.8 + height * 0.12))
	_dark_palette = ImageTexture3D.new()
	_dark_palette.create(Image.FORMAT_RGB8, n, n, 1, false, [image])
	return _dark_palette
