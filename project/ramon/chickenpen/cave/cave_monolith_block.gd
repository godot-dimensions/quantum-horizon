@tool
extends "res://ramon/VoxelMining/scripts/voxel_mining_block.gd"

## The rock from the pen, stood on end in the cave as the thing everyone is here for: a
## tall black slab on a ruined plinth, the 2001 monolith by way of a voxel field. It mines
## exactly as it did in the field - same field, same dual contouring, same per-voxel
## colliders, and the pickaxe and the gold seam hang off it unchanged - only the shape and
## the colour are its own.
##
## HOW THIN A SLAB CAN BE. Dual contouring needs a couple of cells across anything it is to
## draw, and this block's grid tops out at 16 (voxel_mining_block.gd clamps it). A slab two
## cells thick and at most ~10 tall is about 1 : 2 : 4, not the film's 1 : 4 : 9. It still
## reads as a slab stood on end, which is what sells it; thinner would have to be a plain
## box and could not be mined.
##
## THE PROPORTIONS ARE IN (x, y, z, w). Its W depth matches its width, so turning the slice
## a quarter into W shows the same face again rather than a sliver - the enclosure rule's
## "match the W depth to the footprint", applied to an object.

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
