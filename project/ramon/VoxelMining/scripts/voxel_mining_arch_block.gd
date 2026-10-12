@tool
extends "res://ramon/VoxelMining/scripts/voxel_mining_block.gd"
## Fun-demo shape: a walk-through archway - a rounded (hypersphere) mass with
## a round tunnel carved through it, rather than a boxy one. The base shape
## override here is a straight copy of voxel_mining_sphere_block.gd's own
## density/gradient math (already proven correct) rather than a hand-derived
## rounded-box SDF - a superquadric rounded box is doable, but its gradient
## has two branches (flat face vs. rounded corner) and is real new math to
## get right, versus reusing a shape this project has already gotten right
## once. Simpler and safer beats fancier here.
##
## The tunnel itself, via [method _add_extra_layers], is round only in X/Y so
## it runs the full depth of the block along both Z and W. That matters here
## specifically: a tunnel that only punched through along Z would vanish (or
## never have opened at all) at other W-slices, since the cross-section
## renderer only ever shows one slice at a time. Carving through W as well
## means the archway is walkable from any slice, not just the one it
## happened to be carved in.
##
## The tunnel carve itself is exactly [method VoxelMiningBlock.mine_at_shape]'s
## own technique - same AIR material, same replace_mask=GROUND - just an
## infinite cylinder instead of a small sphere.

@export_group("Tunnel")
## Tunnel radius as a fraction of the block's own radius (the same
## box_fill_fraction-derived radius the sphere base shape uses). Kept well
## under 1.0 so there is real archway "stone" left around the opening rather
## than a thin ring.
@export_range(0.1, 0.9, 0.01) var tunnel_radius_fraction: float = 0.55


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


func _add_extra_layers(center: Vector4, size: int) -> void:
	var radius: float = float(size) * 0.5 * box_fill_fraction
	var tunnel_radius: float = radius * tunnel_radius_fraction
	_field.add_layer(
		VoxelField4D.VoxelMaterial.AIR,
		func(p: Vector4) -> float:
			var radial := Vector2(p.x - center.x, p.y - center.y)
			return tunnel_radius - radial.length(),
		func(p: Vector4) -> Vector4:
			var radial := Vector2(p.x - center.x, p.y - center.y)
			var length: float = radial.length()
			if is_zero_approx(length):
				return Vector4(1, 0, 0, 0)
			var normalized: Vector2 = radial / length
			# Inward, toward the tunnel's own axis - see voxel_mining_block.gd's
			# box gradient comment for why that's the convention every layer
			# here has to follow.
			return Vector4(-normalized.x, -normalized.y, 0.0, 0.0),
		1.0,
		1 << VoxelField4D.VoxelMaterial.GROUND)
