@tool
extends Node4D

## The room the presentation happens in: a lit disc hanging in nothing, a drum in the
## middle of it to stand exhibits on, and a sky full of motes.
##
## BUILT IN CODE, LIKE EVERYTHING ELSE HERE. A hand-placed .tscn would be forty nodes of
## boxes whose numbers cannot be reasoned about later; built from a radius and a step
## count, the disc can be made bigger by one exported number and stays a disc.
##
## EVERYTHING HAS REAL W EXTENT. A prop thinner through W than the viewer's slice can move
## simply stops existing the moment they turn it - which is the first thing this project
## learned and the easiest to forget in a room that is mostly decoration. The floor is
## especially thick through W, because a floor you fall through when you rotate is not a
## floor, it is a trapdoor.
##
## IT IS A KEYNOTE, NOT A MUSEUM. A drum with a thing on it is a display case; a stage
## with a backdrop, beams coming down out of nothing and a tiered house facing it is an
## event, and the difference is almost entirely furniture. The house is EMPTY on purpose -
## a thousand seats and two people in them is the funniest possible staging of three
## engineering findings, and it costs nothing but boxes.
##
## THE VOID IS NOT EMPTY, IT IS DARK. A genuinely empty background gives the eye nothing to
## measure motion against, and an exhibit that turns on a turntable in a black room reads
## as a still image. The motes are there to be passed, not to be looked at.

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export_group("The floor")
@export_range(4.0, 40.0, 0.5) var radius: float = 17.0: set = _set_radius
@export_range(8, 64, 1) var segments: int = 28: set = _set_segments
@export_range(0.1, 2.0, 0.05) var floor_thickness: float = 0.5
## Through W. Generous on purpose - see the header.
@export_range(1.0, 30.0, 0.5) var floor_w_depth: float = 14.0
@export var floor_color: Color = Color(0.09, 0.10, 0.14): set = _set_floor_color
@export var rim_color: Color = Color(0.20, 0.72, 0.92): set = _set_rim_color

@export_group("The pedestal")
@export_range(1.0, 10.0, 0.1) var drum_radius: float = 3.1
@export_range(0.2, 4.0, 0.05) var drum_height: float = 0.9
@export var drum_color: Color = Color(0.13, 0.15, 0.21)
@export var glow_color: Color = Color(0.25, 0.85, 1.0)

@export_group("The show")
## The wall behind the stage. Tinted per act by the show, which is most of what makes an
## act feel like an act.
@export_range(0, 40, 1) var backdrop_panels: int = 17
@export_range(2.0, 20.0, 0.5) var backdrop_height: float = 7.4
@export_range(3.0, 20.0, 0.5) var backdrop_radius: float = 7.6
@export var backdrop_color: Color = Color(0.07, 0.09, 0.16)
## Columns of light coming down onto the stage out of nothing.
@export_range(0, 12, 1) var beams: int = 5
@export var beam_color: Color = Color(0.32, 0.78, 1.0)
## Tiers of seats facing it, which nobody is ever going to sit in.
@export_range(0, 8, 1) var tiers: int = 4
@export_range(0, 60, 1) var seats_per_tier: int = 22
@export var seat_color: Color = Color(0.16, 0.13, 0.20)

@export_group("The aisle")
## A RAKED BOX AND THEN A FLAT ONE, straight up the middle of the seating arc from the
## edge of the stage to the way out, and the seats get out of their way. There is no ramp
## to the seating itself and there does not need to be - what a room like this actually
## needs is a floor you can read: somewhere obvious to stand, an obvious route off it, and
## the freedom to stop anywhere on the way and watch from that height.
##
## IT IS ON THE CENTRE LINE, and that is the point. An earlier version ran it off
## diagonally to keep the door out of the third-person camera's way, which solved a camera
## problem by putting the room's main axis somewhere nobody would have drawn it. The rig
## already raycasts and pulls in when something is behind the player, so the diagonal was
## buying nothing; what keeps the door out of shot is starting the player at the BOTTOM,
## where it is further back than the camera is.
## The foot sits at the drum's own rim, and it sits 0.18 LOW - which is the deck's own
## thickness above the line it is laid out along. Put the line on the floor and the deck's
## top surface ends up a lip proud of it, so the last thing anybody coming down the ramp
## does is step off an eighteen-centimetre kerb. Sunk by its own thickness, the surface
## arrives flush with the floor and meets the platform instead of stopping short of it.
@export var aisle_from := Vector4(0.0, -0.18, 3.1, 0.0): set = _set_aisle_from
@export var aisle_to := Vector4(0.0, 1.9, 10.6, 0.0): set = _set_aisle_to
## The flat run on the end of it. You arrive at the far end of this, so there is a walk
## along the top of the house before the seating starts and before the floor drops away -
## coming through the door straight onto a downward slope with a back row at your elbow is
## an arrival nobody gets to look at. It is also why the disc is wider than the room
## needs: the landing has to have somewhere to be.
@export_range(0.0, 12.0, 0.1) var aisle_landing: float = 5.0: set = _set_aisle_landing
@export_range(1.0, 6.0, 0.1) var aisle_width: float = 2.8: set = _set_aisle_width
## Steps under the rake. The physics here keeps boxes and nothing else, so a tilted slab
## is a tilted PICTURE with an axis-aligned brick behind it; the thing you actually walk
## on is a staircase of little boxes with their tops on the slope. Enough of them and the
## rise per step is a few centimetres, which walks like a ramp.
@export_range(4, 80, 1) var aisle_steps: int = 44
@export var aisle_color: Color = Color(0.12, 0.14, 0.20)

@export_group("The void")
@export_range(0, 400, 1) var motes: int = 160
@export_range(10.0, 120.0, 1.0) var mote_spread: float = 55.0
@export var mote_color: Color = Color(0.82, 0.88, 1.0)
@export var mote_seed: int = 7777


func _set_radius(v: float) -> void: radius = v; _later()
func _set_segments(v: int) -> void: segments = v; _later()
func _set_floor_color(v: Color) -> void: floor_color = v; _later()
func _set_rim_color(v: Color) -> void: rim_color = v; _later()
func _set_aisle_from(v: Vector4) -> void: aisle_from = v; _later()
func _set_aisle_to(v: Vector4) -> void: aisle_to = v; _later()
func _set_aisle_width(v: float) -> void: aisle_width = v; _later()
func _set_aisle_landing(v: float) -> void: aisle_landing = v; _later()


## The heading of the whole walkway, as a yaw.
func aisle_yaw() -> float:
	return atan2(aisle_to.x - aisle_from.x, aisle_to.z - aisle_from.z)


## The far end of the landing, where the way out stands. Public so the scene does not have
## to keep a second copy of the number.
func aisle_head() -> Vector4:
	var yaw: float = aisle_yaw()
	return aisle_to + Vector4(sin(yaw) * aisle_landing, 0.0, cos(yaw) * aisle_landing, 0.0)


## How far a point on the floor is from the walkway, measured to the SEGMENTS rather than
## to a line - seats beyond either end of it are not in the aisle, they are just near it.
## The rake and the landing are one path, so it is the nearer of the two.
func aisle_gap(at: Vector4) -> float:
	var p := Vector2(at.x, at.z)
	var head: Vector4 = aisle_head()
	return minf(_to_segment(p, Vector2(aisle_from.x, aisle_from.z),
			Vector2(aisle_to.x, aisle_to.z)),
		_to_segment(p, Vector2(aisle_to.x, aisle_to.z), Vector2(head.x, head.z)))


## How high the walkway's surface is over a point, or 0 for a point that is not on it.
## Anything that walks down the aisle needs this - they move in X and Z and would
## otherwise stroll down to the stage through the air at the height they started.
func aisle_height(at: Vector4) -> float:
	if aisle_gap(at) > aisle_width * 0.5 + 0.4:
		return 0.0
	var a := Vector2(aisle_from.x, aisle_from.z)
	var b := Vector2(aisle_to.x, aisle_to.z)
	var p := Vector2(at.x, at.z)
	var run: Vector2 = b - a
	if run.length_squared() < 0.0001:
		return aisle_to.y + 0.18
	# Past the top of the rake is the landing, which is level.
	var along: float = clampf((p - a).dot(run) / run.length_squared(), 0.0, 1.0)
	return lerpf(aisle_from.y, aisle_to.y, along) + 0.18


func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var run: Vector2 = b - a
	if run.length_squared() < 0.0001:
		return p.distance_to(a)
	return p.distance_to(a + run * clampf((p - a).dot(run) / run.length_squared(), 0.0, 1.0))


func _ready() -> void:
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()

	# THE DISC, as a ring of wedge-ish slabs plus a solid core. A true cylinder is not
	# among the 4D primitives and a single huge box is a square room; a ring of boxes
	# laid round a circle reads as a disc from standing height, which is the only height
	# anybody sees it from.
	var body := StaticBody4D.new()
	body.name = "Floor"
	add_child(body)
	_own(body)

	_slab(body, "Core", Vector4(0.0, -floor_thickness * 0.5, 0.0, 0.0),
		Vector3(radius * 0.86, floor_thickness, radius * 0.86), floor_color)
	_floor_collision(body)

	for i in segments:
		var a: float = TAU * float(i) / float(segments)
		var at := Vector4(sin(a) * radius * 0.86, -floor_thickness * 0.5,
			cos(a) * radius * 0.86, 0.0)
		var plate := _slab(body, "Plate%d" % i, at,
			Vector3(radius * 0.34, floor_thickness, radius * 0.34), floor_color)
		plate.basis = Basis4D.from_zx(a)

	# The lit rim. Thin, bright, and the only thing in the room with an edge.
	for i in segments * 2:
		var a: float = TAU * float(i) / float(segments * 2)
		var at := Vector4(sin(a) * radius, 0.06, cos(a) * radius, 0.0)
		var kerb := _slab(self, "Rim%d" % i, at,
			Vector3(radius * 0.13, 0.12, 0.30), rim_color)
		kerb.basis = Basis4D.from_zx(a)

	# THE DRUM. Three stacked rings, narrowing, so it reads as machined rather than as a
	# crate - and a turntable on top that the show rotates.
	for step in 3:
		var t: float = float(step) / 3.0
		var r: float = drum_radius * (1.0 - t * 0.18)
		var h: float = drum_height / 3.0
		for i in segments:
			var a: float = TAU * float(i) / float(segments)
			var at := Vector4(sin(a) * r, h * (float(step) + 0.5), cos(a) * r, 0.0)
			var block := _slab(self, "Drum%d_%d" % [step, i], at,
				Vector3(r * 0.30, h, r * 0.30),
				drum_color if step < 2 else drum_color.lerp(glow_color, 0.22))
			block.basis = Basis4D.from_zx(a)

	var table := Node4D.new()
	table.name = "Turntable"
	add_child(table)
	table.position = Vector4(0.0, drum_height, 0.0, 0.0)
	_own(table)

	# A ring of light let into the top of the drum, which is what makes it a stage.
	for i in segments:
		var a: float = TAU * float(i) / float(segments)
		var at := Vector4(sin(a) * drum_radius * 0.80, 0.02,
			cos(a) * drum_radius * 0.80, 0.0)
		var lamp := _slab(table, "Ring%d" % i, at,
			Vector3(drum_radius * 0.22, 0.05, 0.16), glow_color)
		lamp.basis = Basis4D.from_zx(a)

	# THE BACKDROP. An arc of tall panels standing behind the stage, which the show tints
	# one act at a time. Held apart by a gap each, so it reads as a wall of screens
	# rather than as a wall.
	var wall := Node4D.new()
	wall.name = "Backdrop"
	add_child(wall)
	_own(wall)
	for i in backdrop_panels:
		var t: float = float(i) / float(maxi(backdrop_panels - 1, 1))
		# A half-circle behind the stage, not a full one - the audience has to see past it.
		var a: float = lerpf(PI * 0.62, PI * 1.38, t)
		var at := Vector4(sin(a) * backdrop_radius, backdrop_height * 0.5,
			cos(a) * backdrop_radius, 0.0)
		var panel := _slab(wall, "Panel%d" % i, at,
			Vector3(backdrop_radius * 0.20, backdrop_height, 0.16), backdrop_color)
		panel.basis = Basis4D.from_zx(a)

	# THE BEAMS. Tall, thin, translucent-looking columns standing on the stage edge. They
	# are solid geometry pretending to be light, which at this palette is indistinguishable
	# and costs one box each instead of a lighting rig.
	var rig := Node4D.new()
	rig.name = "Beams"
	add_child(rig)
	_own(rig)
	for i in beams:
		var a: float = lerpf(PI * 0.70, PI * 1.30, float(i) / float(maxi(beams - 1, 1)))
		var at := Vector4(sin(a) * (drum_radius + 1.5), backdrop_height * 0.62,
			cos(a) * (drum_radius + 1.5), 0.0)
		var beam := _slab(rig, "Beam%d" % i, at,
			Vector3(0.22, backdrop_height * 1.2, 0.22), beam_color)
		beam.basis = Basis4D.from_zx(a)

	# THE HOUSE. Tiers rising away from the stage, facing it. Empty.
	var house := Node4D.new()
	house.name = "House"
	add_child(house)
	_own(house)
	for tier in tiers:
		var r: float = drum_radius + 3.4 + float(tier) * 1.5
		var lift: float = 0.25 + float(tier) * 0.55
		for i in seats_per_tier:
			# The near half of the circle only - the audience sits in front of the stage,
			# and a ring of seats with their backs to it is a carousel.
			var a: float = lerpf(-PI * 0.42, PI * 0.42, float(i) / float(maxi(seats_per_tier - 1, 1)))
			var at := Vector4(sin(a) * r, lift, cos(a) * r, 0.0)
			if Vector2(at.x, at.z).length() > radius - 0.8:
				continue
			# An aisle is seats NOT being there. Half the width plus a seat's own width,
			# so the row ends clear of the edge rather than overhanging it.
			if aisle_gap(at) < aisle_width * 0.5 + 0.35:
				continue
			var seat := _slab(house, "Seat%d_%d" % [tier, i], at,
				Vector3(0.46, 0.34, 0.42), seat_color)
			seat.basis = Basis4D.from_zx(a)
			var back := _slab(house, "Back%d_%d" % [tier, i],
				at + Vector4(sin(a) * 0.26, 0.30, cos(a) * 0.26, 0.0),
				Vector3(0.46, 0.44, 0.12), seat_color.lerp(rim_color, 0.12))
			back.basis = Basis4D.from_zx(a)

	_aisle(body)

	# THE PODIUM, off to one side so the presenter never stands in front of the exhibit.
	var podium := Node4D.new()
	podium.name = "Podium"
	add_child(podium)
	podium.position = Vector4(-drum_radius - 1.35, 0.0, 1.5, 0.0)
	_own(podium)
	_slab(podium, "Stem", Vector4(0.0, 0.52, 0.0, 0.0), Vector3(0.40, 1.04, 0.36), drum_color)
	_slab(podium, "Top", Vector4(0.0, 1.10, 0.05, 0.0), Vector3(0.58, 0.10, 0.46),
		drum_color.lerp(glow_color, 0.3))
	_slab(podium, "Strip", Vector4(0.0, 1.15, 0.22, 0.0), Vector3(0.50, 0.03, 0.05), glow_color)

	# THE MOTES. Scattered wide and deep, including through W, so turning the slice
	# changes the sky rather than leaving it frozen - which is itself one of the three
	# things being demonstrated, running quietly in the background the whole time.
	var rng := RandomNumberGenerator.new()
	rng.seed = mote_seed
	var sky := Node4D.new()
	sky.name = "Motes"
	add_child(sky)
	_own(sky)
	for i in motes:
		var at := Vector4(
			rng.randf_range(-mote_spread, mote_spread),
			rng.randf_range(-mote_spread * 0.35, mote_spread * 0.75),
			rng.randf_range(-mote_spread, mote_spread),
			rng.randf_range(-mote_spread * 0.25, mote_spread * 0.25))
		if Vector2(at.x, at.z).length() < radius * 1.6:
			continue
		var size: float = rng.randf_range(0.10, 0.34)
		var mote := _slab(sky, "Mote%d" % i, at, Vector3(size, size, size),
			mote_color.lerp(rim_color, rng.randf()))
		mote.basis = Basis4D.from_zx(rng.randf_range(0.0, TAU))


## The walkway: a raked box, a flat one on the end of it, and the staircase of little
## boxes that makes both of them something you can actually walk up.
func _aisle(body: StaticBody4D) -> void:
	var run := Vector2(aisle_to.x - aisle_from.x, aisle_to.z - aisle_from.z)
	var flat: float = run.length()
	if flat < 0.5:
		return
	var rise: float = aisle_to.y - aisle_from.y
	var length: float = sqrt(flat * flat + rise * rise)
	var yaw: float = aisle_yaw()
	var turn: Projection = Basis4D.from_zx(yaw)

	# The rake. Turned to the heading first, then tilted. from_yz turns the opposite way
	# to the obvious reading - the same note block_gait_4d.gd carries - so the NEGATIVE
	# angle is the one that lifts the far end.
	var deck := _slab(self, "Aisle", (aisle_from + aisle_to) * 0.5
		+ Vector4(0.0, 0.06, 0.0, 0.0),
		Vector3(aisle_width, 0.24, length), aisle_color)
	deck.basis = turn * Basis4D.from_yz(-atan2(rise, flat))
	_aisle_edges(deck, "Rake", aisle_width, length)

	# The landing. Level, so the last few steps to the door are not taken on a slope.
	var head: Vector4 = aisle_head()
	if aisle_landing > 0.1:
		var pad := _slab(self, "Landing", (aisle_to + head) * 0.5
			+ Vector4(0.0, 0.06, 0.0, 0.0),
			Vector3(aisle_width, 0.24, aisle_landing), aisle_color)
		pad.basis = turn
		_aisle_edges(pad, "Landing", aisle_width, aisle_landing)

	# And the steps. Deep enough that each is buried in the one below it, so there is no
	# lip between them for a foot to catch on, and their tops are level with the DECK's
	# top surface rather than with the line it was laid out along - the slab sits 0.06
	# above that line and is 0.24 thick, so its surface is 0.18 up. Stepping on the line
	# means standing shin-deep in the ramp.
	var total: float = length + aisle_landing
	var spacing: float = 0.0
	# Enough that no single step on the RAKE is more than about five centimetres, whatever
	# it is set to. The rise is what a foot has to clear, but the steps are spread over
	# the rake AND the level landing, so the count has to be scaled by how much of the
	# run is actually sloped - otherwise a long landing quietly coarsens the stairs.
	var needed: float = absf(rise) / 0.05 * (length + aisle_landing) / length
	var steps: int = maxi(aisle_steps, int(ceil(needed)))
	spacing = total / float(steps)
	for step in steps:
		var t: float = (float(step) + 0.5) / float(steps)
		var walked: float = t * total
		var at: Vector4 = aisle_from.lerp(aisle_to, minf(walked / length, 1.0))
		if walked > length:
			at = aisle_to + Vector4(sin(yaw), 0.0, cos(yaw), 0.0) * (walked - length)
		# SHALLOW ALONG THE WALKWAY, wide across it. The first version used the aisle's
		# width for both, which made every step a 2.8-metre-deep block: consecutive ones
		# sit 0.18 apart but each reached 1.4 forward, so the box that actually held you
		# up was one from far higher up the slope and the real riser was 0.44 rather than
		# 0.05. Walking down still worked, because walking down is falling. Walking up was
		# a wall.
		var deep: float = spacing * 1.8
		var size := Vector4(aisle_width, 0.6, deep, floor_w_depth)
		if absf(sin(yaw)) > absf(cos(yaw)):
			size = Vector4(deep, 0.6, aisle_width, floor_w_depth)
		_collide(body, Vector4(at.x, at.y + 0.18 - 0.30, at.z, 0.0), size)


## A lit strip down each side, so the edge of the drop is readable in a dark room.
func _aisle_edges(deck: MeshInstance4D, tag: String, wide: float, along: float) -> void:
	for side in [-1.0, 1.0]:
		var strip := _slab(self, "AisleEdge%s%d" % [tag, int(side)],
			deck.position + deck.basis * Vector4(side * wide * 0.48, 0.14, 0.0, 0.0),
			Vector3(wide * 0.04, 0.04, along * 0.99), rim_color)
		strip.basis = deck.basis


func _slab(parent: Node, part: String, at: Vector4, size: Vector3,
		colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	var deep: float = floor_w_depth if parent is StaticBody4D else maxf(size.x, 1.2)
	mesh.size = Vector4(size.x, size.y, size.z, deep)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	_own(node)
	return node


## The floor you can stand on, as a grid rather than as one box per visible plate.
##
## THE PLATES DO NOT TILE. They are drawn as a ring of rotated slabs around a central
## slab, which READS as a disc and is the whole reason it is built that way - but the
## collider for each one is axis-aligned and sits where its middle is, so the ring of
## boxes lands well outside the corners of the middle one. At this radius that left a
## four-metre annulus of nothing, directly under the seating, and anyone who walked out
## there dropped through the world. It had been there at every radius this room has had.
##
## So the collision is its own thing: square cells covering the disc, kept if their middle
## is inside it, overlapping by a whisker so no seam falls between two of them.
func _floor_collision(body: StaticBody4D) -> void:
	var cell: float = maxf(radius * 0.22, 1.0)
	var across: int = int(ceil(radius * 2.0 / cell))
	for ix in across + 1:
		for iz in across + 1:
			var at := Vector4(-radius + float(ix) * cell, -floor_thickness * 0.5,
				-radius + float(iz) * cell, 0.0)
			if Vector2(at.x, at.z).length() > radius:
				continue
			_collide(body, at, Vector4(cell * 1.02, floor_thickness, cell * 1.02,
				floor_w_depth))


## One collision box per floor plate. Boxes, because the physics here collapses anything
## else to a single bounding volume - which is Act II of the presentation standing in the
## room the presentation happens in.
func _collide(body: StaticBody4D, at: Vector4, size: Vector4) -> void:
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	shape.position = at
	_own(shape)


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
