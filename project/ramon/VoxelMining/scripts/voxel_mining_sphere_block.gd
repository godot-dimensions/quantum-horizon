@tool
extends "res://ramon/VoxelMining/scripts/voxel_mining_block.gd"
## Shape-freedom test #1: swaps VoxelMiningBlock's box for a hypersphere -
## the same "glome" primitive voxel_terrain_4d.gd's globe layer uses for
## whole planets, just tiny. Only [method _build_base_shape] changes; field,
## dual contouring, mining, per-voxel collision, and palette coloring are all
## inherited unchanged from VoxelMiningBlock.
##
## Density/gradient here match globe's own math exactly (see
## voxel_terrain_4d.gd's "globe" case) - gradient points toward the sphere's
## center, the correct convention VoxelField4D expects - so unlike the box
## this needed no sign fix.

func _build_base_shape(center: Vector4, size: int) -> void:
	var radius: float = float(size) * 0.5 * box_fill_fraction
	_field.add_layer(
		VoxelField4D.VoxelMaterial.GROUND,
		func(p: Vector4) -> float:
			return radius - (p - center).length(),
		func(p: Vector4) -> Vector4:
			var offset: Vector4 = center - p
			var length: float = offset.length()
			return Vector4.ZERO if is_zero_approx(length) else offset / length,
		1.0)
