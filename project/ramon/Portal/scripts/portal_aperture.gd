extends Node4D
## The opening itself: a circular hole punched through the wall, with a collar
## covering its cut edge, growing when placed and collapsing slowly when
## replaced.
##
## No coloured ring. Portal marks its portals blue and orange and an unpaired one
## is a solid filled oval; both were built here and both were removed on request.
## What is left is meant to read as a hole in the wall and nothing else, so the
## collar is the same white as the surface it is cut into.
##
## Why a collar exists at all: the hole is cut from the wall as horizontal
## strips, and a strip decomposition always leaves a stepped edge. Finer strips
## shrink the steps but never remove them. A ring lying in the wall's own plane,
## a little proud of it, covers that edge with a genuine circle - so the steps
## stop being the silhouette and the cut reads as round.
##
## The node's own basis IS the portal frame (columns right, up, normal, ana) and
## is never scaled, because portal_link.gd reads it to transform travellers and a
## scaled frame would corrupt the mapping. The animation scales a child holder
## and re-cuts the wall in quantised steps.

const WhiteTexture: Texture3D = preload("res://textures/dev_finals/ramdev_white.png")

const RADIUS := 1.4
## Kept as separate names because the link and the surface fit-test think in two
## axes; they are simply equal now.
const HALF_WIDTH := RADIUS
const HALF_HEIGHT := RADIUS

## The hole cut through the wall, slightly inside the collar so the collar always
## has something to cover.
const HOLE_RADIUS := RADIUS - 0.12

## Radius within which a crossing counts, pulled in by roughly the player's own
## half-width: a traveller whose centre is right at the edge would be half inside
## the wall, and axis-aligned collision would have stopped them before they ever
## reached the plane. Must stay inside the collar's inner edge, since that is the
## real visible opening.
const PASS_RADIUS := COLLAR_OUTER - COLLAR_WIDTH - 0.07

const COLLAR_SEGMENTS := 16

## The collar must sit ENTIRELY INSIDE the cut and touch no wall geometry.
##
## This is the fix for the shards around a fresh opening. Earlier versions had
## the collar overlapping the wall - spanning radius 1.20 to 1.40 while the wall
## begins at 1.28 - which put 40 rotated boxes through the middle of the ~100
## stepped strip boxes that form the cut. Interpenetrating solids at every angle
## render as a ring of jagged fragments, which reads exactly like inverted
## normals. Nothing about it was shading; it was two sets of geometry occupying
## the same space.
##
## Held clear by 6 cm, which also covers the strips' own inward protrusion (the
## cut's innermost radius is about 3 cm inside the nominal circle). What remains
## visible between collar and wall is a thin dark ring, which reads as a shadow
## gap rather than a defect.
const COLLAR_CLEARANCE := 0.06
const COLLAR_WIDTH := 0.20
const COLLAR_OUTER := HOLE_RADIUS - COLLAR_CLEARANCE
const COLLAR_CENTRE_RADIUS := COLLAR_OUTER - COLLAR_WIDTH * 0.5
## How far the collar stands proud of each wall face, so it cannot z-fight them.
const COLLAR_PROUD := 0.012
const W_HALF_EXTENT := 12.0

const OPEN_TIME := 0.35
const CLOSE_TIME := 1.40

## How many distinct sizes the wall is re-cut at across the animation. Set from a
## measurement rather than caution: a re-cut rebuilds about a hundred boxes and
## costs 1.2 ms, so 24 steps over a 1.4 s close is nothing, and it keeps the hole
## within about 5 cm of the collar the whole way - comfortably inside the
## collar's 14 cm width, so the cut edge never shows from under it. The first
## version used 6 and the mismatch was visible.
const GEOMETRY_STEPS := 24

signal closed(aperture: Node4D)

var colour: StringName = &"blue"
var surface: Node4D = null
var surface_local := Vector2.ZERO

var is_closing: bool = false
var openness: float = 0.0

var _visual: Node4D = null
var _cut_step: int = -1


static func hole_radius() -> float:
	return HOLE_RADIUS


static func pass_radius() -> float:
	return PASS_RADIUS


func build() -> void:
	_visual = Node4D.new()
	_visual.name = &"Collar"
	add_child(_visual)
	_build_collar()
	_apply_openness(0.0)


func _make_material() -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	FlatShadingRamon.apply(material)
	material.albedo_texture_3d = WhiteTexture
	return material


## A ring of box segments, each tangent to the circle and long enough to meet its
## neighbours - the same approximation hub_gate_4d.gd uses for a circular gate,
## since the 4D module has no disc or torus primitive.
##
## It runs the full depth of the wall rather than sitting on its face, so it
## LINES the bore. That is what makes the opening read as round from an angle as
## well as head-on: the hole itself is cut as strips and its edge is a staircase,
## and a flat ring would only hide that when viewed straight on.
##
## This is also the reason the dual-contouring patch that was considered here was
## dropped. DC's strength is a smooth surface from a coarse grid for shapes with
## no analytic form - mined rock, terrain. A portal bore is a cylinder, and a
## cylinder can be built exactly from ring segments for nothing, where the patch
## would have cost ~130 ms per shot and a fork of the field and contour classes.
func _build_collar() -> void:
	var material: TetraMaterial4D = _make_material()
	# Spans from just proud of the room-side face to just past the far face.
	var wall_thickness: float = surface.thickness if surface != null else 0.6
	var depth: float = wall_thickness + COLLAR_PROUD * 2.0
	var depth_centre: float = -wall_thickness * 0.5
	for i in range(COLLAR_SEGMENTS):
		var angle: float = TAU * float(i) / float(COLLAR_SEGMENTS)
		var next_angle: float = TAU * float(i + 1) / float(COLLAR_SEGMENTS)
		var point := Vector2(cos(angle), sin(angle)) * COLLAR_CENTRE_RADIUS
		var next_point := Vector2(cos(next_angle), sin(next_angle)) * COLLAR_CENTRE_RADIUS
		var midpoint: Vector2 = (point + next_point) * 0.5
		var along: Vector2 = next_point - point
		var length: float = along.length()
		if length < 0.0001:
			continue
		var tangent: Vector2 = along / length

		var segment := MeshInstance4D.new()
		var mesh := BoxTetraMesh4D.new()
		# Overlapped slightly along its length so neighbours leave no gap at the
		# joins once they are rotated apart.
		mesh.size = Vector4(length * 1.02, COLLAR_WIDTH, depth, W_HALF_EXTENT * 2.0)
		mesh.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
		segment.mesh = mesh
		segment.material_override = material
		segment.position = Vector4(midpoint.x, midpoint.y, depth_centre, 0.0)
		segment.basis = Projection(
			Vector4(tangent.x, tangent.y, 0.0, 0.0),
			Vector4(-tangent.y, tangent.x, 0.0, 0.0),
			Vector4(0.0, 0.0, 1.0, 0.0),
			Vector4(0.0, 0.0, 0.0, 1.0))
		_visual.add_child(segment)


func start_closing() -> void:
	is_closing = true


func _process(delta_time: float) -> void:
	if is_closing:
		_apply_openness(openness - delta_time / CLOSE_TIME)
		if openness <= 0.0:
			if surface != null and is_instance_valid(surface):
				surface.close_hole()
			closed.emit(self)
			queue_free()
	elif openness < 1.0:
		_apply_openness(openness + delta_time / OPEN_TIME)


func _apply_openness(value: float) -> void:
	openness = clampf(value, 0.0, 1.0)
	var scale: float = maxf(openness, 0.001)
	_visual.basis = Projection(
		Vector4(scale, 0.0, 0.0, 0.0),
		Vector4(0.0, scale, 0.0, 0.0),
		Vector4(0.0, 0.0, 1.0, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0))
	_update_cut()


## Re-cuts the wall when the quantised size changes, so the hole grows and
## collapses with the collar instead of appearing at full size under a tiny ring.
func _update_cut() -> void:
	if surface == null or not is_instance_valid(surface):
		return
	var step: int = int(round(openness * float(GEOMETRY_STEPS)))
	if step == _cut_step:
		return
	_cut_step = step
	if step <= 0:
		surface.close_hole()
		return
	surface.open_hole(surface_local, HOLE_RADIUS * float(step) / float(GEOMETRY_STEPS), colour)
