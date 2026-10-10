extends RefCounted

## A human hand, lofted: a palm, four fingers and a thumb, each a chain of round sections
## through its joints. For slide VI, where a left hand turned half way round through W comes
## back as a right hand.
##
## MEASURED, NOT GUESSED. The bones are the means of 66 adult hands on X-ray (Buryanov and
## Kotiuk, "Proportions of hand segments", Int. J. Morphol. 28(3), 2010): metacarpal, proximal,
## middle and distal phalanx, and the soft pad past the last bone. Breadth and thickness are
## ordinary hand anthropometry: about 85 mm across the palm, 28 to 30 mm through it, 16 to 21
## mm across a finger, hand length 190 mm from the wrist crease to the tip of the middle finger.
## The pose follows the artists' rules for a relaxed hand: the knuckles on an arc with the
## middle one highest, the fingers fanning out so their tips are further apart than their
## roots, and the thumb coming off the corner of the palm on a diagonal, its tip short of the
## index finger's middle joint.
##
## A FLAT HAND IS NOT A LEFT HAND. A cut-out hand, the same front and back, can be turned over
## in 3D and become the other one, so it could prove nothing - and slide VI lets you turn the
## hand in 3D now. This one is not flat: the fingers curl a little towards the palm, the thumb
## comes forward of it, and the ball of the thumb stands out on the palm side. However you turn
## it in 3D it stays a left hand, which is the claim.
##
## AS DEEP THROUGH W AS IT IS THICK. Every section is as deep in W as it is front to back, and
## centred on w = 0, so the hand is symmetric across its own slice. That is what makes half a
## turn in a plane with W a mirror: x and w both change sign, and a shape that is the same at
## -w as at +w comes back as its mirror image in x.
##
## THE RIGHT HAND IS THE LEFT ONE MIRRORED, not the left one turned: every centre's x is
## negated before lofting, and the loft winds its own tetrahedra, so "the real one" on the
## other side of the drum really is built the other way round.
##
## THREAD-SAFE. Nothing here touches the scene tree or makes a texture: the meshes come back
## without a material. The cinema lofts both hands on its worker thread, with the shapes,
## while you walk in.

const Loft := preload("res://ramon/chickenpen/scripts/loft_builder_4d.gd")

## Stage metres per millimetre of hand: the 240 mm from the cuff to the middle fingertip
## stands about 2.5 m tall on the drum, big enough to read from the back row.
const MM := 0.0105
## Where the mesh's origin is, in the hand's own millimetres (left hand): the middle of the
## palm, so a turn in any plane turns the hand about itself rather than about its wrist.
const CENTRE := Vector2(-8.0, 70.0)

## Round enough to read as flesh from the house, coarse enough to stay cheap: every
## tetrahedron costs about 1.25 KB of video memory whether it is on screen or not.
## Rings run pole to pole through W, and half way through the turn the W profile is the one
## on screen, so it gets more than the rig's default four.
const FINGER_SIDES := 10
const FINGER_RINGS := 5
const PALM_SIDES := 14
const PALM_RINGS := 5
const SMOOTHING := 2

## How much thinner front to back a finger is than it is wide.
const FINGER_DEPTH := 0.86
## The palm side is +z: what faces the house.
const PALM_SIDE := Vector3(0.0, 0.0, 1.0)

## The four fingers of a LEFT hand seen palm first, thumb at -x. `mcp` is the knuckle, in mm
## from the wrist crease; `fan` tilts the finger towards +x in degrees; `bones` the proximal,
## middle and distal phalanx (the distal with its pad); `radii` at the root inside the palm,
## the knuckle, mid proximal, the middle joint, mid middle, the last joint and the tip;
## `flex` bends each joint towards the palm, degrees.
const FINGERS := [
	{"name": "index", "mcp": Vector2(-27.0, 94.0), "fan": -7.0, "bones": [39.8, 22.4, 19.6],
		"radii": [10.4, 10.5, 9.6, 9.4, 8.6, 8.0, 7.2], "flex": [6.0, 14.0, 10.0]},
	{"name": "middle", "mcp": Vector2(-8.0, 98.0), "fan": -1.0, "bones": [44.6, 26.3, 21.4],
		"radii": [11.0, 11.0, 10.0, 9.8, 9.0, 8.4, 7.6], "flex": [6.0, 14.0, 10.0]},
	{"name": "ring", "mcp": Vector2(11.0, 93.0), "fan": 5.0, "bones": [41.4, 25.7, 21.3],
		"radii": [10.2, 10.2, 9.3, 9.2, 8.4, 7.9, 7.1], "flex": [7.0, 16.0, 10.0]},
	{"name": "little", "mcp": Vector2(28.0, 83.0), "fan": 12.0, "bones": [32.7, 18.1, 19.7],
		"radii": [9.0, 9.0, 8.2, 8.0, 7.3, 6.9, 6.2], "flex": [8.0, 18.0, 12.0]},
]

## The palm, wrist to knuckles: [centre (mm), half-width, depth as a share of it, squareness].
## Nearly square, as the artists' rule has it: as wide at the heel of the hand as at the
## knuckles, narrowing to the wrist only below that. Its lower end is inside the cuff, and
## its upper end closes under the middle and ring fingers' roots, so neither of the loft's
## pointed end caps is ever seen.
const PALM := [
	[Vector3(0.0, -30.0, 0.0), 27.0, 0.66, 0.0],
	[Vector3(0.0, -8.0, 0.0), 28.5, 0.64, 0.0],
	[Vector3(-1.0, 8.0, 0.5), 34.0, 0.54, 0.15],
	[Vector3(-1.0, 24.0, 0.5), 39.0, 0.44, 0.25],
	[Vector3(-2.0, 48.0, 0.5), 41.0, 0.37, 0.3],
	[Vector3(-3.0, 72.0, 0.0), 42.0, 0.35, 0.3],
	[Vector3(-4.0, 87.0, 0.0), 39.0, 0.36, 0.25],
	[Vector3(-3.0, 96.0, 0.0), 26.0, 0.50, 0.1],
]

## The ball of the thumb: low on the palm, on the thumb side, standing out on the palm side, a
## broad wedge rather than the root of a stick. The first three sections of the thumb's own
## chain, in skin.
const THENAR := [
	[Vector3(-18.0, 6.0, 4.0), 14.0, 0.85],
	[Vector3(-30.0, 22.0, 9.0), 16.0, 0.80],
	[Vector3(-38.0, 36.0, 12.0), 14.5, 0.85],
]

## The thumb from its knuckle: a short thick digit, not a fifth finger (Ramon, 10 Oct: "shorten
## the thumb, it looks anatomically incorrect"). The knuckle sits at the palm's edge half way up,
## so the web between thumb and index is where it is on a hand, and its tip stops just short of
## the index finger's knuckle (the artists' rule). The X-rays' 31.6 and 27.4 mm phalanges include
## the part buried in the web; what shows is shorter.
##
## AND IT BENDS (Ramon, 10 Oct: "thumb should bend a bit"). A relaxed thumb is flexed a little at
## every joint, most at its base (Lee et al., resting hand posture: the thumb's carpometacarpal
## joint has the largest flexion of its joints, and the thumb rests more flexed than the fingers),
## and because it is turned to face the fingers, its bends carry the tip back in towards the index
## finger and forward of the palm rather than straight down onto it. Artists draw the break at the
## last joint for the same reason: a thumb drawn as one straight line reads as a sausage. Here the
## metacarpal leaves the ball of the thumb at about 30 degrees out from the fingers, the knuckle
## bends the rest about 15 degrees in and forward, and the last joint another 22, a little swollen.
const THUMB_MCP := Vector3(-46.0, 50.0, 14.0)
const THUMB_PROXIMAL := 24.0
const THUMB_DISTAL := 21.0
const THUMB_PROXIMAL_DIR := Vector3(-0.38, 0.86, 0.34)
const THUMB_DISTAL_DIR := Vector3(-0.05, 0.86, 0.50)
## At its knuckle, mid proximal, its last joint, and the tip.
const THUMB_RADII := [11.5, 10.2, 10.4, 8.8]

## A cuff over the wrist, as the old gloves had: a clean end to a hand that has no arm, and
## the loft's pointed end cap turned into a rounded one.
const CUFF := [
	[Vector3(0.0, -54.0, 0.0), 13.0, 0.70],
	[Vector3(0.0, -49.0, 0.0), 27.0, 0.68],
	[Vector3(0.0, -40.0, 0.0), 31.5, 0.68],
	[Vector3(0.0, -22.0, 0.0), 31.5, 0.68],
	[Vector3(0.0, -16.0, 0.0), 27.0, 0.68],
]

## COLOURED THE WAY THE LOFT RIG COLOURS BALLS: every section carries a colour, the loft
## records them in order (its `loft_ramp`), and the material samples them as a strip of one
## texel per section, so the colour blends along a chain between one section and the next.
## The thumb is therefore not a separate piece with a seam at its knuckle (Ramon, 10 Oct: "no
## need to make a thumb cut, use loft ball color technique"): it is one chain from the ball of
## the thumb to its tip, skin running into the indicator over the knuckle.
const SKIN := Color(0.92, 0.74, 0.62)
## The handedness indicator: gold, as on the gloves before (Ramon, 10 Oct, after trying a bright
## orange: "orange looks dirty. make it yellow again").
const INDICATOR := Color(1.0, 0.78, 0.25)
const CUFF_COLOUR := Color(0.30, 0.55, 0.95)


## One hand as one mesh: the palm, four fingers, the thumb with the ball of the thumb, and the
## cuff, each lofted on its own and merged, with their colours in the mesh's `loft_ramp` (see
## theatre_bake_4d.coat for the material that shows them). Null on failure.
static func build(right: bool) -> ArrayTetraMesh4D:
	var side: float = -1.0 if right else 1.0
	var parts: Array = [_loft(_palm_sections(side), PALM_RINGS, PALM_SIDES),
		_loft(_thumb_sections(side), FINGER_RINGS, FINGER_SIDES),
		_loft(_chain(CUFF, side, CUFF_COLOUR), PALM_RINGS, PALM_SIDES)]
	for finger in FINGERS:
		parts.append(_loft(_finger_sections(finger, side), FINGER_RINGS, FINGER_SIDES))
	return _merge(parts)


## A section of the loft at [param mm] (the left hand's millimetres), mirrored by [param side].
static func _section(mm: Vector3, radius: float, depth: float, side: float, squareness: float = 0.0,
		colour: Color = SKIN) -> Dictionary:
	var centre := Vector4((mm.x - CENTRE.x) * side, mm.y - CENTRE.y, mm.z, 0.0) * MM
	return {"center": centre, "radius": radius * MM, "v_scale": depth, "w_scale": depth,
		"squareness": squareness, "color": colour}


static func _palm_sections(side: float) -> Array:
	var out: Array = []
	for p in PALM:
		out.append(_section(p[0], p[1], p[2], side, p[3]))
	return out


## A finger from its root, sunk inside the palm, to its tip. Each joint bends the rest of the
## finger towards the palm, so the tip curls forward of the palm's plane.
static func _finger_sections(finger: Dictionary, side: float) -> Array:
	var fan: float = deg_to_rad(float(finger["fan"]))
	var flat := Vector3(sin(fan), cos(fan), 0.0)
	var bones: Array = finger["bones"]
	var radii: Array = finger["radii"]
	var flex: Array = finger["flex"]
	var mcp := Vector3(finger["mcp"].x, finger["mcp"].y, 0.0)
	var d1: Vector3 = _bent(flat, flex[0])
	var d2: Vector3 = _bent(flat, flex[0] + flex[1])
	var d3: Vector3 = _bent(flat, flex[0] + flex[1] + flex[2])
	var pip: Vector3 = mcp + d1 * bones[0]
	var dip: Vector3 = pip + d2 * bones[1]
	var centres: Array = [mcp - flat * 15.0, mcp, mcp + d1 * bones[0] * 0.5, pip,
		pip + d2 * bones[1] * 0.5, dip]
	var out: Array = []
	for i in centres.size():
		out.append(_section(centres[i], radii[i], FINGER_DEPTH, side))
	out.append_array(_tip(dip, d3, float(bones[2]), float(radii[6]), side, SKIN))
	return out


## The last bone's two closing sections, which round the fingertip off: the loft ends every
## chain with a cone 0.55 of the last radius long, and a full-width last section made that a
## point. A narrower one just short of the end makes the cone a small cap on a dome instead,
## landing where the bone and its pad end.
static func _tip(joint: Vector3, along: Vector3, length: float, radius: float, side: float,
		colour: Color) -> Array:
	return [_section(joint + along * (length - 0.95 * radius), radius, FINGER_DEPTH, side, 0.0, colour),
		_section(joint + along * (length - 0.42 * radius), radius * 0.72, FINGER_DEPTH, side, 0.0, colour)]


## The thumb as one chain: the ball of the thumb in skin, then from the knuckle on in the
## indicator colour, the loft blending the two over the span between them.
static func _thumb_sections(side: float) -> Array:
	var out: Array = _chain(THENAR, side, SKIN)
	var proximal: Vector3 = THUMB_PROXIMAL_DIR.normalized()
	var ip: Vector3 = THUMB_MCP + proximal * THUMB_PROXIMAL
	out.append(_section(THUMB_MCP, THUMB_RADII[0], FINGER_DEPTH, side, 0.0, INDICATOR))
	out.append(_section(THUMB_MCP + proximal * THUMB_PROXIMAL * 0.5, THUMB_RADII[1], FINGER_DEPTH, side,
		0.0, INDICATOR))
	out.append(_section(ip, THUMB_RADII[2], FINGER_DEPTH, side, 0.0, INDICATOR))
	out.append_array(_tip(ip, THUMB_DISTAL_DIR.normalized(), THUMB_DISTAL, THUMB_RADII[3], side, INDICATOR))
	return out


## A chain given as [centre (mm), half-width, depth as a share of it], all in [param colour].
static func _chain(points: Array, side: float, colour: Color) -> Array:
	var out: Array = []
	for p in points:
		out.append(_section(p[0], p[1], p[2], side, 0.0, colour))
	return out


## [param flat] bent [param degrees] towards the palm.
static func _bent(flat: Vector3, degrees: float) -> Vector3:
	var a: float = deg_to_rad(degrees)
	return flat * cos(a) + PALM_SIDE * sin(a)


static func _loft(sections: Array, rings: int, sides: int) -> ArrayTetraMesh4D:
	return Loft.build(sections, rings, sides, true, false, true, SMOOTHING, false)


## Several lofts as one mesh, their colours kept: one draw for the whole hand. Each loft
## points its cells' corners at its own sections' colours (one texture coordinate per section,
## `loft_ramp` holding the colours); merged, the sections are numbered on from the last part's,
## the ramps laid end to end, and the coordinates spread over the whole strip, as the loft rig
## does when it merges its chains.
static func _merge(parts: Array) -> ArrayTetraMesh4D:
	var positions := PackedVector4Array()
	var cells := PackedInt32Array()
	var texture_indices := PackedInt32Array()
	var ramp := PackedColorArray()
	for part in parts:
		if part == null:
			return null
		var mesh: ArrayTetraMesh4D = part
		var offset: int = positions.size()
		var first: int = ramp.size()
		positions.append_array(mesh.get_vertex_positions())
		for index in mesh.get_simplex_cell_vertex_indices():
			cells.append(index + offset)
		for index in mesh.get_simplex_cell_texture_map_indices():
			texture_indices.append(index + first)
		ramp.append_array(mesh.get_meta("loft_ramp", PackedColorArray()))
	var texture_map := PackedVector3Array()
	for i in ramp.size():
		texture_map.append(Vector3((float(i) + 0.5) / float(ramp.size()), 0.5, 0.5))
	var out := ArrayTetraMesh4D.new()
	out.set_vertex_positions(positions)
	out.set_simplex_cell_vertex_indices(cells)
	out.set_texture_map_values(texture_map)
	out.set_simplex_cell_texture_map_indices(texture_indices)
	out.set_meta("loft_ramp", ramp)
	out.calculate_boundary_normals(false)
	return out
