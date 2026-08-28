extends Node4D
## A large white portalable wall/floor/ceiling section, which can open a hole
## anywhere on itself.
##
## Portal's actual rule, which the fixed-pad version of this scene got wrong: a
## portal goes wherever you aim, on any surface that is white, flat and big
## enough. So a surface is not a door-sized panel any more - it is a whole face,
## and the hole is cut into it at the point you hit.
##
## The section is full wall thickness rather than a veneer, because the hole has
## to go all the way through: a hole in a facing panel with solid wall behind it
## is exactly the "convincing portal view over collision that behaves like an
## ordinary wall" that Valve's own commentary warns against.
##
## The hole is a DISC, approximated as horizontal strips. It was a rectangle at
## first, and through a circular rim you could plainly see the wall's corners
## still filling the opening. Strips are conservative - each one is cut to the
## NARROWEST chord it spans - so the hole always sits inside the visible circle
## and there is nowhere you can pass that does not look open.

const PortalShading := preload("res://ramon/Portal/scripts/portal_shading.gd")
const WhiteTexture: Texture3D = preload("res://textures/dev_finals/ramdev_white.png")

## Panel extents across its own face, in metres.
var half_a: float = 3.0
var half_b: float = 2.0
var thickness: float = 0.6
var w_half_extent: float = 12.0

## Orthonormal frame. `normal` faces into the room.
var normal := Vector4(0.0, 0.0, 1.0, 0.0)
var up := Vector4(0.0, 1.0, 0.0, 0.0)
var right := Vector4(1.0, 0.0, 0.0, 0.0)

## Which colour currently holds a hole here, if any. One at a time: the framing
## decomposition below cuts a single rectangle, and two overlapping holes would
## need a general box-minus-boxes split for very little gameplay gain.
var hole_colour: StringName = &""

## How many horizontal strips approximate the disc.
##
## Lowered from 48 to 12 deliberately. More strips do NOT read as smoother here:
## at 48 the steps are 5 cm and the eye resolves them as a band of fine hatching
## around the opening, which looks like noise or broken geometry. At 12 they are
## chunky but coherent, and there are four times fewer pieces for the collar to
## fight with.
const HOLE_STRIPS := 12
## Half-width the opening never drops below, in metres: the player capsule is
## 0.5 m across, so 0.8 m of clearance leaves room to walk in off-centre.
const MIN_HALF_CHORD := 0.4
## The corner-fill strips were recessed behind the wall face at first, to stop
## them z-fighting it. They do not need to be: the pieces TILE rather than
## overlap, so no two front faces share depth, and the recess only bought a
## visible square halo of shadowed step around every opening. Left at zero, and
## kept as a named constant so the reasoning survives the next person who sees a
## seam and reaches for a depth offset.
const FILL_RECESS := 0.0
## How far neighbouring wall pieces bury themselves in each other, in metres.
## Solids that merely touch leave a seam the renderer can show through; solids
## that overlap cannot. Only ever applied to edges that do not face the hole.
const SEAM_OVERLAP := 0.01

var _solid: StaticBody4D = null
var _hole_centre_a: float = 0.0
var _hole_centre_b: float = 0.0
var _hole_radius: float = 0.0


func build() -> void:
	_solid = StaticBody4D.new()
	_solid.name = &"Solid"
	add_child(_solid)
	_rebuild_solid()


## Local (a, b) coordinates of a world point on this surface, where a runs along
## `right` and b along `up`.
func local_of(world_point: Vector4) -> Vector2:
	var offset: Vector4 = world_point - global_position
	return Vector2(offset.dot(right), offset.dot(up))


func world_of(local: Vector2) -> Vector4:
	return global_position + right * local.x + up * local.y


## Portal's placement helper, in its simplest correct form: slide the requested
## centre until the whole aperture sits on the surface. Valve calls this bumping
## and allows up to about 0.6 m of it; clamping is the same idea without needing
## a search, because these surfaces are flat rectangles. Returns false when the
## surface is too small to hold the aperture at all.
func fit(requested: Vector2, aperture_half_a: float, aperture_half_b: float) -> Dictionary:
	var margin_a: float = half_a - aperture_half_a
	var margin_b: float = half_b - aperture_half_b
	if margin_a < 0.0 or margin_b < 0.0:
		return {"ok": false, "local": requested}
	var fitted := Vector2(
		clampf(requested.x, -margin_a, margin_a),
		clampf(requested.y, -margin_b, margin_b))
	return {"ok": true, "local": fitted, "bumped": not fitted.is_equal_approx(requested)}


func open_hole(local: Vector2, radius: float, colour: StringName) -> void:
	hole_colour = colour
	_hole_centre_a = local.x
	_hole_centre_b = local.y
	_hole_radius = radius
	_rebuild_solid()


func close_hole() -> void:
	hole_colour = &""
	_hole_radius = 0.0
	_rebuild_solid()


func has_hole() -> bool:
	return _hole_radius > 0.0


func _make_material() -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	PortalShading.apply(material)
	material.albedo_texture_3d = WhiteTexture
	return material


## One box when solid, four framing boxes when a hole is open. Rebuilt wholesale
## rather than patched: at four boxes it is far cheaper to think about than to
## optimise, and it keeps "solid" and "holed" from drifting apart.
func _rebuild_solid() -> void:
	for child in _solid.get_children():
		_solid.remove_child(child)
		child.queue_free()

	if not has_hole():
		_add_piece(-half_a, half_a, -half_b, half_b)
		return

	var hole_min_b: float = _hole_centre_b - _hole_radius
	var hole_max_b: float = _hole_centre_b + _hole_radius
	var box_min_a: float = _hole_centre_a - _hole_radius
	var box_max_a: float = _hole_centre_a + _hole_radius

	# Four big pieces around the disc's bounding box, so the wall away from the
	# opening stays whole. The first version cut every strip across the FULL wall
	# width, which put twenty coplanar seams right across it and z-fought into
	# visible stripes metres from the portal.
	_add_piece(-half_a, half_a, -half_b, hole_min_b)
	_add_piece(-half_a, half_a, hole_max_b, half_b)
	_add_piece(-half_a, box_min_a + SEAM_OVERLAP, hole_min_b, hole_max_b)
	_add_piece(box_max_a - SEAM_OVERLAP, half_a, hole_min_b, hole_max_b)

	# Then the corner fill between the circle and that box, one strip per row,
	# each cut back to the narrowest chord it spans so the opening never eats
	# into the visible circle.
	#
	# The floor-clearance minimum is scaled by the CURRENT radius, not taken as a
	# constant. The hole animates open and shut, and a fixed 0.4 m minimum is
	# wider than the hole itself for the first third of that animation: every
	# strip then collapses to a negative span, gets skipped, and the opening
	# becomes the disc's full square bounding box shrinking underneath a round
	# collar. That is what the flickering "inverted normals" was.
	var min_half_chord: float = minf(MIN_HALF_CHORD, _hole_radius * 0.92)
	var strip_height: float = (_hole_radius * 2.0) / float(HOLE_STRIPS)
	for strip in range(HOLE_STRIPS):
		var strip_min_b: float = hole_min_b + strip_height * float(strip)
		var strip_max_b: float = strip_min_b + strip_height
		var furthest: float = maxf(absf(strip_min_b - _hole_centre_b), absf(strip_max_b - _hole_centre_b))
		var half_chord: float = 0.0
		if furthest < _hole_radius:
			half_chord = sqrt(_hole_radius * _hole_radius - furthest * furthest)
		# Never narrower than a person. The extreme strips of a true disc taper
		# to nothing, and on a floor-tangent portal that leaves a 13 cm sliver of
		# wall across the bottom of the opening - which, with no step-up in
		# CharacterBody4D, is a wall you cannot walk through. Measured: it blocked
		# every wall crossing. Widening the end strips costs about 6 cm of arc at
		# each end and buys an opening you can actually walk into.
		half_chord = maxf(half_chord, min_half_chord)
		# Overlapped outward and vertically, never inward: the hole-facing edge
		# stays exact while every other edge buries itself in its neighbour. Butt
		# joints leave T-junctions - 48 strips each ending against one long side
		# piece - and a T-junction shows as a hairline you can see straight
		# through, which is the other half of the "look-through" artifact.
		_add_piece(box_min_a - SEAM_OVERLAP, _hole_centre_a - half_chord,
			strip_min_b - SEAM_OVERLAP, strip_max_b + SEAM_OVERLAP, FILL_RECESS)
		_add_piece(_hole_centre_a + half_chord, box_max_a + SEAM_OVERLAP,
			strip_min_b - SEAM_OVERLAP, strip_max_b + SEAM_OVERLAP, FILL_RECESS)


## Pieces are built in the surface's own local frame, so a, b and the normal are
## simply x, y and z here - the node's basis does the orienting.
func _add_piece(min_a: float, max_a: float, min_b: float, max_b: float, recess: float = 0.0) -> void:
	var span_a: float = max_a - min_a
	var span_b: float = max_b - min_b
	if span_a <= 0.001 or span_b <= 0.001:
		return
	var size := Vector4(span_a, span_b, thickness - recess * 2.0, w_half_extent * 2.0)
	var local_position := Vector4((min_a + max_a) * 0.5, (min_b + max_b) * 0.5, 0.0, 0.0)

	var body := Node4D.new()
	body.position = local_position
	_solid.add_child(body)

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
	mesh_instance.material_override = _make_material()
	body.add_child(mesh_instance)
