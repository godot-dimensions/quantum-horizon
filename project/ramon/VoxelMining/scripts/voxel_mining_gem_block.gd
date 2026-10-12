@tool
extends "res://ramon/VoxelMining/scripts/voxel_mining_block.gd"
## Gem-reveal test: seeds a small hollow cavity inside the rock before any
## mining happens, carved the exact same way [method VoxelMiningBlock.
## mine_at_shape] carves anything else, with a bright placeholder gem sitting
## in the middle of it.
##
## Nothing about mining, meshing, or collision changes from VoxelMiningBlock -
## see that class's own doc for how all of that works. This subclass only
## adds one more field layer (the cavity) via the [method _add_extra_layers]
## hook and a plain colored mesh at its center. The "reveal" needs zero
## visibility scripting: the gem mesh is always there, it is just normally
## hidden behind solid rock geometry, the same as an ore block is hidden
## behind stone in any voxel game - once mining opens a path from the surface
## to the cavity, the gem is simply visible, the same as any other occluded
## object would become once whatever was in front of it is gone.

@export_group("Gem")
## Cavity + gem center, in grid coordinates relative to the block's own
## center. Vector4.ZERO is dead center of the grid - as deep inside the rock
## as this shape gets, and the default, since the point of this test is
## having to dig for it.
@export var gem_offset: Vector4 = Vector4.ZERO
## Radius (grid cells) of the hollow pocket carved around the gem before any
## mining starts.
@export_range(0.5, 4.0, 0.05) var cavity_radius: float = 1.3
## Gem size as a fraction of the cavity's diameter, so it sits inside the
## pocket with room around it rather than touching the walls.
@export_range(0.1, 0.9, 0.01) var gem_size_fraction: float = 0.45
@export var gem_color: Color = Color(0.25, 0.85, 0.95, 1.0)


func _add_extra_layers(center: Vector4, _size: int) -> void:
	var cavity_center: Vector4 = center + gem_offset
	_field.add_layer(
		VoxelField4D.VoxelMaterial.AIR,
		func(p: Vector4) -> float:
			return cavity_radius - (p - cavity_center).length(),
		func(p: Vector4) -> Vector4:
			var offset: Vector4 = cavity_center - p
			var length: float = offset.length()
			return Vector4.ZERO if is_zero_approx(length) else offset / length,
		1.0,
		1 << VoxelField4D.VoxelMaterial.GROUND)

	_update_gem(cavity_center)


## Positions and sizes the gem once, at generate() time - unlike the ground
## mesh and colliders, its transform never needs to change as mining
## proceeds, only what happens to be standing between it and the camera does.
func _update_gem(cavity_center_grid: Vector4) -> void:
	var gem: MeshInstance4D = get_node_or_null("Gem") as MeshInstance4D
	if gem == null:
		return

	var grid_center: float = float(_field.size - 1) * 0.5
	var offset := Vector4(grid_center, grid_center, grid_center, grid_center)
	gem.position = (cavity_center_grid - offset) * cell_size

	var box := BoxTetraMesh4D.new()
	box.size = Vector4.ONE * (cavity_radius * 2.0 * cell_size * gem_size_fraction)
	gem.mesh = box

	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	material.albedo_color = gem_color
	gem.material_override = material
