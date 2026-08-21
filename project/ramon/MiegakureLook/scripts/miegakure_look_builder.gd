extends Node4D
## Minimal terrain for the Miegakure-feel camera test: one BOUNDED floating
## platform with a couple of small props on top, not an open/continuous
## floor - every official Miegakure screenshot analysed in chat (Windmill,
## Temple, Pillars) shows a self-contained square slab with a visible
## underside, floating in void, rather than ground that just keeps going.
## This is a camera-and-avatar feel test, not the eventual layer-crossing
## puzzle - see project chat history, that comes after this once the
## framing is right.
##
## Uses real lighting (Aaron's WorldEnvironment4D/DirectionalLight4D, set up
## on the scene root the same way hub1.tscn does it) rather than the flat-
## shaded unlit trick PhaseMaze/ImpossibleBypass use - the whole point here
## is checking how the dev textures actually read under real light.

const PLATFORM_SIZE := Vector4(16.0, 1.5, 16.0, 24.0) # 1.5m thick, so the underside reads as a slab, not a plane.
const PROP_SIZE := Vector4(1.5, 1.5, 1.5, 24.0)

## Grey, not blue - matches hub_palette.gd's established convention
## (structure/floors = grey, blue is reserved for signage only). Both the
## platform and its props use the same texture - they're both permanent
## structure, just different sizes.
const FloorTexture := preload("res://textures/dev_finals/ramdev_grey.png")


func _ready() -> void:
	_add_panel(Vector4(0, -0.75, 0, 0), PLATFORM_SIZE, _make_material(FloorTexture))
	_add_panel(Vector4(4, 0.75, 3, 0), PROP_SIZE, _make_material(FloorTexture))
	_add_panel(Vector4(-5, 0.75, -4, 0), PROP_SIZE, _make_material(FloorTexture))


func _make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	material.albedo_texture_3d = texture
	return material


func _add_panel(position: Vector4, size: Vector4, material: TetraMaterial4D) -> void:
	var body := StaticBody4D.new()
	body.position = position
	add_child(body)

	var collision_shape := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)

	var mesh_instance := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
