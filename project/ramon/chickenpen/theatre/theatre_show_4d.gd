extends Node4D

## The presentation: three findings, staged.
##
## THE EXHIBITS ARE NOT ILLUSTRATIONS OF THE FINDINGS, THEY ARE THE FINDINGS. Act one puts
## a real MeshInstance3D on a plinth and it is really invisible - nothing is faked, the
## renderer simply never draws it. Act two puts a real BoxShape4D hull round a shape that
## is not a box. Act three turns a real VoxelMiningBlock through W and the cross-section
## really does become a different solid. A presentation that mimes its own subject is a
## slideshow; this one can be checked by walking up to it.
##
## ONE RUNNER, NOT THREE ANIMATION PLAYERS. Every act is rise, hold, demonstrate, sink, and
## the differences between them are a handful of numbers and one callback each - so the
## sequence lives in a table and the acts supply only what makes them themselves. That is
## the same shape the dialogue takes, for the same reason.
##
## IT RUNS ON A CLOCK AND CANNOT BE FAILED. There is no input in here beyond walking about.
## A player who wanders off mid-act comes back to the next one, and the way out stands
## open at the head of the walkway the whole time, so nobody is ever held here.

const ROCK := preload("res://ramon/VoxelMining/voxel_mining_block.tscn")

@export var stage_path: NodePath
@export var caption_path: NodePath
@export var presenter_path: NodePath

@export_group("Pacing")
## Long enough for him to walk the house and for you to follow him down it.
@export_range(1.0, 30.0, 0.5) var opening_seconds: float = 11.0
@export_range(4.0, 40.0, 0.5) var act_seconds: float = 16.0
@export_range(1.0, 20.0, 0.5) var closing_seconds: float = 9.0
@export_range(0.2, 6.0, 0.1) var change_seconds: float = 1.6

@export_group("The presenter")
## Whoever he is talking to, so he addresses the person in the room rather than a fixed
## point the person may well not be standing at.
@export var audience_path: NodePath
## He comes in the same way you do - through the door, down the walkway, ahead of you -
## and then works between two marks: one out front for the claim, one in on the drum for
## the demonstration. A presenter who stands on one spot for a minute is a sign, not a
## speaker, and one who is simply already on stage when you arrive never came from
## anywhere.
@export var wings := Vector4(0.0, 0.0, 13.2, 0.0)
@export var mark_claim := Vector4(-5.3, 0.0, 2.6, 0.0)
@export var mark_exhibit := Vector4(-3.9, 0.0, 0.9, 0.0)
## Brisk. He has the length of the house to cover before the first act, and a man
## strolling it at a metre a second is a man the audience overtakes.
@export_range(0.3, 4.0, 0.05) var presenter_speed: float = 1.95

## Each act: the title, the finding in one line, the measured figure, and the colour the
## room turns while it is running.
const ACTS := [
	{
		"title": "I. THE RENDERER DRAWS ONLY FOUR DIMENSIONS",
		"body": "A MeshInstance3D is not badly drawn here. It is never drawn at all - the 4D renderer swaps the viewport onto its own World3D, and everything built for the old one simply stops existing.",
		"figure": "342 lit pixels for a 4D box. 0 for the 3D one beside it.",
		"aside": "Both plinths are loaded. Only one of them has anything on it.",
		"tint": Color(0.10, 0.30, 0.52),
	},
	{
		"title": "II. COLLISION REMEMBERS ONLY BOXES",
		"body": "Hand the physics any shape that is not a BoxShape4D and it keeps the bounding volume and throws the shape away. One enormous invisible crate, and no way to ask which part of it you touched.",
		"figure": "So a mined rock is 544 little boxes, one per surface voxel, and none buried.",
		"aside": "The hull does not move because the hull is all it ever had.",
		"tint": Color(0.46, 0.22, 0.10),
	},
	{
		"title": "III. A SLICE IS NOT A CAMERA ANGLE",
		"body": "Turn through W and you are not looking at the same solid from somewhere else. You are looking at a different solid. The hole stays where it was; the cross-section through it does not.",
		"figure": "One rock. One tunnel. Every angle a shape nobody made on purpose.",
		"aside": "This is the one worth the walk.",
		"tint": Color(0.16, 0.44, 0.24),
	},
]

var _stage: Node4D
var _caption: Node
var _presenter: Node4D
var _table: Node4D
var _panels: Array[MeshInstance4D] = []
var _beams: Array[MeshInstance4D] = []
var _exhibits: Array[Node4D] = []
var _act: int = -1
var _clock: float = 0.0
var _phase: float = 0.0
var _done: bool = false
var _hull: Node4D
var _swarm: Node4D
var _rock: Node4D
var _carved: bool = false
## How much bigger than life the two built exhibits are. They read at arm's length and
## vanish from the back row at 1:1, and there is no reason a thing on a plinth in a
## theatre should be the size it is in the world. Applied as a basis on the piece rather
## than to every number inside it, so the shapes stay described in their own terms.
const EXHIBIT_SCALE: float = 1.5
var _audience: Node4D
var _stride: float = 0.0
var _walking: bool = false
var _face: float = 0.0
var _got_down: bool = false


func _ready() -> void:
	_stage = get_node_or_null(stage_path) as Node4D
	_caption = get_node_or_null(caption_path)
	_presenter = get_node_or_null(presenter_path) as Node4D
	_audience = get_node_or_null(audience_path) as Node4D
	if _presenter != null:
		# Off in the wings, so the room is empty when you arrive and he walks into it.
		_presenter.position = wings
		_face = 0.0
	if _stage == null:
		push_warning("TheatreShow: no stage, so there is nowhere to put any of this.")
		return
	_table = _stage.get_node_or_null("Turntable") as Node4D
	for panel in (_stage.get_node_or_null("Backdrop").get_children()
			if _stage.get_node_or_null("Backdrop") != null else []):
		if panel is MeshInstance4D:
			_panels.append(panel)
	for beam in (_stage.get_node_or_null("Beams").get_children()
			if _stage.get_node_or_null("Beams") != null else []):
		if beam is MeshInstance4D:
			_beams.append(beam)
	_build_exhibits()
	_show(-1)
	# The way out is NOT switched off here. It stands open from the moment you arrive,
	# at the head of the walkway, because a walkway that leads to nothing for the first
	# seven seconds is a walkway that leads to nothing - and a room you cannot leave is
	# not a room you explore, it is one you sit out.


# ---------------------------------------------------------------- the exhibits

func _build_exhibits() -> void:
	_exhibits.append(_act_one())
	_exhibits.append(_act_two())
	_exhibits.append(_act_three())
	for piece in _exhibits:
		piece.visible = false


## Two plinths. One carries a MeshInstance3D and is therefore empty.
func _act_one() -> Node4D:
	var piece := Node4D.new()
	piece.name = "ActOne"
	_table.add_child(piece)
	piece.basis = _bigger()
	for side in [-1.0, 1.0]:
		var tag: String = "Old" if side < 0.0 else "New"
		_block(piece, "Plinth" + tag, Vector4(side * 1.15, 0.30, 0.0, 0.0),
			Vector3(0.9, 0.6, 0.9), Color(0.17, 0.19, 0.26), 1.1)
	# The one that is really there.
	var solid := _block(piece, "FourD", Vector4(1.15, 1.30, 0.0, 0.0),
		Vector3(0.78, 0.78, 0.78), Color(0.35, 0.86, 1.0), 0.9)
	solid.name = "FourD"
	# And the one that really is not. A genuine 3D node, loaded, positioned, lit and
	# invisible - which is the entire finding, standing on a plinth.
	var ghost := MeshInstance3D.new()
	ghost.name = "ThreeD"
	var box := BoxMesh.new()
	box.size = Vector3(0.78, 0.78, 0.78)
	ghost.mesh = box
	piece.add_child(ghost)
	ghost.position = Vector3(-1.15, 1.30, 0.0)
	return piece


## A shape that is not a box, inside the only thing the physics kept of it.
func _act_two() -> Node4D:
	var piece := Node4D.new()
	piece.name = "ActTwo"
	_table.add_child(piece)
	piece.basis = _bigger()
	var form := Node4D.new()
	form.name = "Form"
	piece.add_child(form)
	form.position = Vector4(0.0, 1.35, 0.0, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	for i in 9:
		var at := Vector4(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.42, 0.42),
			rng.randf_range(-0.42, 0.42), 0.0)
		var lump := _block(form, "Lump%d" % i, at,
			Vector3(rng.randf_range(0.22, 0.46), rng.randf_range(0.22, 0.46),
				rng.randf_range(0.22, 0.46)), Color(0.95, 0.62, 0.28), 0.7)
		lump.basis = Basis4D.from_zx(rng.randf_range(0.0, TAU)) \
			* Basis4D.from_yz(rng.randf_range(0.0, TAU))
	# The hull: twelve thin bars, because an outline says "this is not the shape" in a way
	# a translucent block never manages.
	_hull = Node4D.new()
	_hull.name = "Hull"
	piece.add_child(_hull)
	_hull.position = Vector4(0.0, 1.35, 0.0, 0.0)
	var r: float = 0.78
	for axis in 3:
		for a in [-1.0, 1.0]:
			for b in [-1.0, 1.0]:
				var at := Vector4.ZERO
				var size := Vector3.ONE * 0.05
				match axis:
					0:
						at = Vector4(0.0, a * r, b * r, 0.0)
						size = Vector3(r * 2.0, 0.05, 0.05)
					1:
						at = Vector4(a * r, 0.0, b * r, 0.0)
						size = Vector3(0.05, r * 2.0, 0.05)
					_:
						at = Vector4(a * r, b * r, 0.0, 0.0)
						size = Vector3(0.05, 0.05, r * 2.0)
				_block(_hull, "Edge%d_%d_%d" % [axis, int(a), int(b)], at, size,
					Color(0.98, 0.86, 0.35), 0.5)
	# And the answer: the grid of small boxes a mined rock actually uses.
	_swarm = Node4D.new()
	_swarm.name = "Swarm"
	piece.add_child(_swarm)
	_swarm.position = Vector4(0.0, 1.35, 0.0, 0.0)
	_swarm.visible = false
	for x in 3:
		for y in 3:
			for z in 3:
				if x == 1 and y == 1 and z == 1:
					continue
				var at := Vector4((float(x) - 1.0) * 0.5, (float(y) - 1.0) * 0.5,
					(float(z) - 1.0) * 0.5, 0.0)
				_block(_swarm, "Cell%d%d%d" % [x, y, z], at, Vector3.ONE * 0.42,
					Color(0.55, 0.92, 0.70), 0.5)
	return piece


## A real mined block, turned through W so its cross-section changes.
func _act_three() -> Node4D:
	var piece := Node4D.new()
	piece.name = "ActThree"
	_table.add_child(piece)
	var rock: Node4D = ROCK.instantiate()
	rock.name = "Rock"
	piece.add_child(rock)
	rock.position = Vector4(0.0, 1.9, 0.0, 0.0)
	# Act three is NOT scaled by a basis - it is a real physics object and its colliders
	# are built in its own frame. It gets bigger the way the professor says a rock gets
	# bigger: fatter CELLS, same 8^4 lattice, so it costs exactly what it cost before.
	rock.set("grid_size", 8)
	rock.set("cell_size", 0.42)
	# A theatre blow is a bigger blow. At the size a pickaxe takes out of the rock in the
	# field the cavity is a dent you cannot see from the third row, and a finding nobody
	# at the back can see is not a finding.
	rock.set("mining_radius_meters", 1.05)
	_rock = rock
	return piece


# ---------------------------------------------------------------- the run

func _process(delta: float) -> void:
	if _stage == null:
		return
	_clock += delta
	_phase += delta
	if _table != null:
		# Everything on the turntable turns, slowly, the whole time.
		_table.basis = Basis4D.from_zx(_clock * 0.22)
	_pulse()
	_perform(delta)
	# The carve is taken during the ARRIVAL, not when act three starts. Every blow
	# re-contours the whole field - about a sixth of a second each - and four of them is
	# most of a second of frozen frames. Spent while the room is still assembling and
	# nobody is watching anything in particular, it is invisible; spent on the turn into
	# the act it is a stutter in the middle of the presentation.
	if not _carved and _phase > 0.35:
		_carve_once()

	if _act < 0 and _phase >= opening_seconds:
		_enter(0)
	elif _act >= 0 and _act < ACTS.size() and _phase >= act_seconds:
		_enter(_act + 1)
	elif _act == ACTS.size() and _phase >= closing_seconds and not _done:
		_done = true
		_say("", "That is the lot. The way out is behind you - mind the step, it is further through W than it looks.", "")

	if _act >= 0 and _act < ACTS.size():
		_demonstrate(_act, _phase)


## Trym giving the talk: where he stands, which way he is turned, and what his arms are
## doing - all of it read off the act clock rather than stored in a state machine, because
## every beat of this is "how far through the act are we" and nothing else.
##
## HE WALKS TO THE POINT HE IS MAKING. Out front while he states the finding, in on the
## drum when he demonstrates it, and the arm that points is whichever one the exhibit is
## on - worked out from his own frame, so it stays the right arm however he is turned.
##
## THE STRIDE IS TRYM'S, because it is Trym. Same sign convention as the walk out of the
## shed: NEGATIVE hip swings the thigh forward, POSITIVE knee folds the shin back under it.
func _perform(delta: float) -> void:
	if _presenter == null:
		return
	var house := Vector4(0.0, 1.5, 9.0, 0.0)
	if _audience != null:
		house = _audience.global_position
	var drum := Vector4(0.0, 1.3, 0.0, 0.0)
	var goes_to: Vector4 = mark_claim
	var looks_at: Vector4 = house
	var t: float = _phase / maxf(act_seconds, 0.01)
	if _act < 0:
		# He waits in the dark while the room assembles, then walks on.
		# A beat in the doorway, then he sets off - so you see him arrive rather than
		# finding him already walking.
		#
		# AND HE COMES DOWN THE AISLE, not straight at his mark. A line from the door to
		# a spot beside the stage leaves the walkway about half way down; he would step
		# off the side of the ramp, drop to the floor and walk the rest of it THROUGH the
		# thing he had been standing on. So the foot of the rake is a waypoint, and only
		# once he is on the flat does he cut across to where he presents from.
		goes_to = wings
		if _phase > 1.4:
			var foot: Vector4 = _stage.get("aisle_from") if _stage != null else Vector4.ZERO
			if not _got_down and Vector2(_presenter.position.x - foot.x,
					_presenter.position.z - foot.z).length() < 0.8:
				_got_down = true
			goes_to = mark_claim if _got_down else Vector4(foot.x, 0.0, foot.z, 0.0)
	elif _act < ACTS.size():
		if t >= 0.30:
			goes_to = mark_exhibit
		if t >= 0.58:
			looks_at = drum
	else:
		goes_to = mark_claim

	var to := Vector4(goes_to.x - _presenter.position.x, 0.0,
		goes_to.z - _presenter.position.z, 0.0)
	var flat: float = Vector2(to.x, to.z).length()
	_walking = flat > 0.12
	if _walking:
		var step: float = minf(presenter_speed * delta, flat)
		_presenter.position += (to / flat) * step
		_stride += step * 3.4
		# Walking, he faces where he is going - a man who crosses a stage sideways while
		# still looking at you is a dolly shot, not a person.
		looks_at = _presenter.position + to

	# Down the ramp, not through the air above it. He moves in X and Z; the walkway says
	# how high the floor is under him at each step, and off the walkway that is zero.
	if _stage != null and _stage.has_method("aisle_height"):
		# Rebuilt rather than assigned into: `position` is a property, and writing one
		# component of a property is a trick worth not relying on.
		var stand: Vector4 = _presenter.position
		_presenter.position = Vector4(stand.x,
			float(_stage.call("aisle_height", stand)), stand.z, stand.w)

	var aim := Vector4(looks_at.x - _presenter.position.x, 0.0,
		looks_at.z - _presenter.position.z, 0.0)
	if Vector2(aim.x, aim.z).length() > 0.05:
		_face = rotate_toward(_face, atan2(aim.x, aim.z), 3.0 * delta)
	_presenter.basis = Basis4D.from_zx(_face)

	var swing: float = sin(_stride) * 0.40 if _walking else 0.0
	for side in ["left", "right"]:
		var lead: float = -swing if side == "left" else swing
		var hip: Node4D = _presenter.get("hip_%s" % side) as Node4D
		var knee: Node4D = _presenter.get("knee_%s" % side) as Node4D
		var ankle: Node4D = _presenter.get("ankle_%s" % side) as Node4D
		var knee_angle: float = maxf(0.0, lead) * 0.75
		if hip != null:
			hip.basis = Basis4D.from_yz(lead)
		if knee != null:
			knee.basis = Basis4D.from_yz(knee_angle)
		if ankle != null:
			ankle.basis = Basis4D.from_yz(-(lead + knee_angle))

	# The gesture. It arrives with the demonstration and goes away with it, and the other
	# arm keeps the counter-swing so he does not look like he is being operated.
	var reach: float = 0.0
	if _act >= 0 and _act < ACTS.size():
		reach = smoothstep(0.52, 0.70, t) - smoothstep(0.93, 1.0, t)
	var toward: Vector4 = _presenter.basis.inverse() * (drum - _presenter.position)
	var pointing: String = "right" if toward.x > 0.0 else "left"
	# A breath, so standing still is not standing frozen.
	var idle: float = sin(_clock * 1.6) * 0.05
	for side in ["left", "right"]:
		var counter: float = swing if side == "left" else -swing
		var lift: float = reach * 1.35 if side == pointing else reach * 0.25
		var shoulder: Node4D = _presenter.get("shoulder_%s" % side) as Node4D
		var elbow: Node4D = _presenter.get("elbow_%s" % side) as Node4D
		if shoulder != null:
			shoulder.basis = Basis4D.from_yz(-lift + counter * 0.55 + idle)
		if elbow != null:
			# Straight when pointing, bent when it is not doing anything in particular.
			elbow.basis = Basis4D.from_yz(0.38 * (1.0 - lift / 1.35) + absf(counter) * 0.3)
	var torso: Node4D = _presenter.get("torso") as Node4D
	if torso != null:
		torso.basis = Basis4D.from_yz(-reach * 0.14 + idle * 0.5)
	var head: Node4D = _presenter.get("head") as Node4D
	if head != null:
		head.basis = Basis4D.from_yz(idle * 1.4)


## Takes a bite out of the rock, once, before anybody sees it.
##
## IT MINES THROUGH THE ROCK'S OWN API rather than reaching into its field. mine_at_shape
## wants one of the block's own colliders, and the block rebuilds ALL of them after every
## blow - so the shapes have to be found again between each one, and a list gathered up
## front would be a list of freed nodes by the second carve.
func _carve_once() -> void:
	_carved = true
	if _rock == null or not _rock.has_method("mine_at_shape"):
		return
	var body: Node = _rock.get_node_or_null("Voxels")
	if body == null:
		return
	# Three blows walking inwards from the near face: a tunnel, not a dent. The whole point
	# of the act is that turning through W shows you cross-sections nobody carved, and a
	# shallow scrape gives W nothing interesting to find. Three and not ten because each
	# one re-contours the entire field.
	for blow in 3:
		var aim := Vector4(0.0, 0.15, 1.45 - 0.62 * float(blow), 0.0)
		var best: CollisionShape4D = null
		var nearest: float = INF
		for child in body.get_children():
			var shape := child as CollisionShape4D
			if shape == null:
				continue
			var gap: float = (shape.position - aim).length()
			if gap < nearest:
				nearest = gap
				best = shape
		if best == null:
			return
		_rock.call("mine_at_shape", best)


## A uniform scale as a 4D basis. Node4D has no scale property of its own; the basis IS
## the transform, so a scale is the identity with its diagonal opened up.
func _bigger() -> Projection:
	var k: float = EXHIBIT_SCALE
	return Projection(Vector4(k, 0.0, 0.0, 0.0), Vector4(0.0, k, 0.0, 0.0),
		Vector4(0.0, 0.0, k, 0.0), Vector4(0.0, 0.0, 0.0, k))


## Which act is on: -1 while the room is still arriving, then 0..2, then 3 for the close.
func current_act() -> int:
	return _act


func _enter(act: int) -> void:
	_act = act
	_phase = 0.0
	_show(act)
	if act < ACTS.size():
		var a: Dictionary = ACTS[act]
		_say(String(a["title"]), String(a["body"]), String(a["figure"]))
		_tint(a["tint"])
	else:
		_say("", "Three findings. One field. I should like it recorded that I asked for a lectern and was given a drum.", "")
		_tint(Color(0.10, 0.12, 0.20))


## Which exhibit is on the table. One at a time, and the rest are not merely hidden but
## out of the way, so a slice turn cannot reveal last act's props behind this one.
func _show(act: int) -> void:
	for i in _exhibits.size():
		var on: bool = i == act
		_exhibits[i].visible = on
		_exhibits[i].position = Vector4(0.0, 0.0 if on else -40.0, 0.0, 0.0)
	if _hull != null:
		_hull.visible = true
	if _swarm != null:
		_swarm.visible = false


## What each act DOES, as opposed to what it looks like.
func _demonstrate(act: int, t: float) -> void:
	match act:
		0:
			# The real one turns; the absent one would too, if it were there.
			var solid: Node4D = _exhibits[0].get_node_or_null("FourD") as Node4D
			if solid != null:
				solid.basis = Basis4D.from_zx(t * 1.1) * Basis4D.from_yz(t * 0.7)
		1:
			# The form tumbles inside a hull that cannot follow it, and half way through
			# the hull gives way to the grid of boxes that is the real answer.
			var form: Node4D = _exhibits[1].get_node_or_null("Form") as Node4D
			if form != null:
				form.basis = Basis4D.from_zx(t * 0.8) * Basis4D.from_yz(t * 0.55)
			var swap: bool = t > act_seconds * 0.62
			if _hull != null:
				_hull.visible = not swap
			if _swarm != null:
				_swarm.visible = swap
		2:
			# The money shot: the block turns through W, not about a spatial axis, so what
			# you are watching is not the rock rotating but the WORLD being cut somewhere
			# else. Paused at the ends so the eye can settle on each cross-section.
			if _rock != null:
				var sweep: float = sin(t * 0.55) * 0.95
				_rock.basis = Basis4D.from_xw(sweep) * Basis4D.from_zw(sweep * 0.45)


## The backdrop drifts to the act's colour and the beams breathe. Nothing here is a light -
## they are boxes - but a box that changes colour on a beat is read as one.
func _tint(to: Color) -> void:
	for panel in _panels:
		var material: TetraMaterial4D = panel.material_override as TetraMaterial4D
		if material != null:
			material.albedo_color = to


func _pulse() -> void:
	for i in _beams.size():
		var material: TetraMaterial4D = _beams[i].material_override as TetraMaterial4D
		if material == null:
			continue
		var beat: float = 0.5 + 0.5 * sin(_clock * 1.7 + float(i) * 0.8)
		material.albedo_color = Color(0.20, 0.55, 0.95).lerp(Color(0.55, 0.95, 1.0), beat)


func _say(title: String, body: String, figure: String) -> void:
	if _caption != null and _caption.has_method("show_act"):
		_caption.call("show_act", title, body, figure)


func _block(parent: Node, part: String, at: Vector4, size: Vector3, colour: Color,
		w_depth: float) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(size.x, size.y, size.z, w_depth)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node
