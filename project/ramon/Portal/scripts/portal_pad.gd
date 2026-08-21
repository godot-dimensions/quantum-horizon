extends Node4D
## One portalable surface: a fixed, aperture-sized white panel set into a hole in
## the wall, floor or ceiling.
##
## Portal's own first chambers work this way - specific white panels accept
## portals and everything else refuses - and Valve's placement rules exist only
## because later chambers allow free aim. Fixing the aperture to the panel means
## there is no fit test, no bumping and no partial overlap to get wrong, which is
## the paper's "prove a fixed portal pair before free placement" in its most
## literal form.
##
## The panel is a real hole in the surface, plugged by a blocker. Opening a
## portal detaches the blocker's collider, so the opening is genuinely passable -
## you can fall through it - rather than a picture of an opening over solid wall.
## That is the design rule Valve states outright and the paper repeats: never
## show an aperture over collision that behaves like a wall.

const BlockerTexture: Texture3D = preload("res://textures/dev_finals/ramdev_white.png")
const BlueTexture: Texture3D = preload("res://textures/dev_finals/ramdev_blue.png")
const YellowTexture: Texture3D = preload("res://textures/dev_finals/ramdev_yellow.png")

## Valve's portal is about 1.22 m x 2.17 m (57 and 32 Hammer units of clearance
## from its centre). Rounded here to 1.2 x 2.2, which comfortably clears the
## player capsule at 0.5 m across and 1.75 m tall.
const HALF_WIDTH := 0.6
const HALF_HEIGHT := 1.1
const BLOCKER_THICKNESS := 0.5
const MEMBRANE_THICKNESS := 0.08
## How far the pad extends along w. Large, like every other structural surface
## in this project: a wall that stops existing when the player moves in w is not
## a wall. The portal link is where w is allowed to matter.
const W_HALF_EXTENT := 12.0

## Outward normal, pointing into the room. Always axis-aligned, which is what
## keeps both sides of a crossing axis-aligned and sidesteps the problem Portal 2
## called out - that teleportation is almost never axis-aligned - entirely.
var normal := Vector4(0.0, 0.0, 1.0, 0.0)
## The pad's own up and right within its surface.
var up := Vector4(0.0, 1.0, 0.0, 0.0)
var right := Vector4(1.0, 0.0, 0.0, 0.0)

var colour: StringName = &""
var is_open: bool = false

var _blocker_body: StaticBody4D = null
var _blocker_collider: CollisionShape4D = null
var _blocker_mesh: MeshInstance4D = null
var _membrane: MeshInstance4D = null


func build() -> void:
	var blocker_size: Vector4 = _surface_size(BLOCKER_THICKNESS)

	_blocker_body = StaticBody4D.new()
	_blocker_body.name = &"Blocker"
	add_child(_blocker_body)

	_blocker_collider = CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = blocker_size
	_blocker_collider.shape = shape
	_blocker_body.add_child(_blocker_collider)

	_blocker_mesh = MeshInstance4D.new()
	var blocker_box := BoxTetraMesh4D.new()
	blocker_box.size = blocker_size
	blocker_box.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	_blocker_mesh.mesh = blocker_box
	_blocker_mesh.material_override = _make_material(BlockerTexture)
	_blocker_body.add_child(_blocker_mesh)

	# Sits just proud of the blocker so it is visible either way: as the solid
	# fill of an unpaired portal, and as the surface of an open one.
	_membrane = MeshInstance4D.new()
	var membrane_box := BoxTetraMesh4D.new()
	membrane_box.size = _surface_size(MEMBRANE_THICKNESS)
	membrane_box.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	_membrane.mesh = membrane_box
	_membrane.position = normal * (BLOCKER_THICKNESS * 0.5)
	_membrane.visible = false
	add_child(_membrane)


## Size vector for a box lying in this pad's surface: aperture-sized across the
## two tangents, [param thickness] along the normal, structural in w.
func _surface_size(thickness: float) -> Vector4:
	var size := Vector4.ZERO
	for axis in range(4):
		size[axis] = absf(right[axis]) * HALF_WIDTH * 2.0 \
			+ absf(up[axis]) * HALF_HEIGHT * 2.0 \
			+ absf(normal[axis]) * thickness
	size.w = W_HALF_EXTENT * 2.0
	return size


func _make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	FlatShadingRamon.apply(material)
	material.albedo_texture_3d = texture
	return material


## The pad's orthonormal 4D frame, columns (right, up, normal, ana). Putting the
## normal on the z column matches the engine's camera convention, where -z is
## forward: a traveller heading into the pad is moving along local -z.
func frame() -> Projection:
	return Projection(right, up, normal, Vector4(0.0, 0.0, 0.0, 1.0))


## Signed distance in front of the pad's plane. Positive is the room side.
func signed_distance(point: Vector4) -> float:
	return (point - global_position).dot(normal)


## Whether a point on the plane lies inside the opening. The w axis is not
## tested: the pad spans w structurally, so a traveller at any w is in front of
## the same opening.
func contains(point: Vector4) -> bool:
	var offset: Vector4 = point - global_position
	return absf(offset.dot(right)) <= HALF_WIDTH and absf(offset.dot(up)) <= HALF_HEIGHT


func assign_colour(new_colour: StringName) -> void:
	colour = new_colour
	_membrane.visible = colour != &""
	if colour != &"":
		_membrane.material_override = _make_material(BlueTexture if colour == &"blue" else YellowTexture)


func clear_colour() -> void:
	colour = &""
	_membrane.visible = false
	set_open(false)


## Opening detaches the collider rather than flagging it: CollisionShape4D has no
## `disabled` property, so removal from the tree is the way to take a shape out of
## the physics world. Kept as a reference so closing puts the same shape back.
func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if open:
		_blocker_body.remove_child(_blocker_collider)
		_blocker_mesh.visible = false
	else:
		_blocker_body.add_child(_blocker_collider)
		_blocker_mesh.visible = true
