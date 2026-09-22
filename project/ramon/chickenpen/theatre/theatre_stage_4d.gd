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
@export_range(4.0, 40.0, 0.5) var radius: float = 13.0: set = _set_radius
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

@export_group("The void")
@export_range(0, 400, 1) var motes: int = 160
@export_range(10.0, 120.0, 1.0) var mote_spread: float = 55.0
@export var mote_color: Color = Color(0.82, 0.88, 1.0)
@export var mote_seed: int = 7777


func _set_radius(v: float) -> void: radius = v; _later()
func _set_segments(v: int) -> void: segments = v; _later()
func _set_floor_color(v: Color) -> void: floor_color = v; _later()
func _set_rim_color(v: Color) -> void: rim_color = v; _later()


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

	var core := _slab(body, "Core", Vector4(0.0, -floor_thickness * 0.5, 0.0, 0.0),
		Vector3(radius * 0.86, floor_thickness, radius * 0.86), floor_color)
	_collide(body, core.position, (core.mesh as BoxTetraMesh4D).size)

	for i in segments:
		var a: float = TAU * float(i) / float(segments)
		var at := Vector4(sin(a) * radius * 0.86, -floor_thickness * 0.5,
			cos(a) * radius * 0.86, 0.0)
		var plate := _slab(body, "Plate%d" % i, at,
			Vector3(radius * 0.34, floor_thickness, radius * 0.34), floor_color)
		plate.basis = Basis4D.from_zx(a)
		_collide(body, at, (plate.mesh as BoxTetraMesh4D).size)

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
			var seat := _slab(house, "Seat%d_%d" % [tier, i], at,
				Vector3(0.46, 0.34, 0.42), seat_color)
			seat.basis = Basis4D.from_zx(a)
			var back := _slab(house, "Back%d_%d" % [tier, i],
				at + Vector4(sin(a) * 0.26, 0.30, cos(a) * 0.26, 0.0),
				Vector3(0.46, 0.44, 0.12), seat_color.lerp(rim_color, 0.12))
			back.basis = Basis4D.from_zx(a)

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
