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
## The controls line, shown on every slide of both parts. Kept here and read by part two
## rather than written twice, because two copies of a caption that names a key is two
## places to forget when somebody rebinds one.
const NAV := "\u2190  \u2192   step through      \u00b7      click   forward"
## The man in the shed, for his clothes. See _dress_presenter.
const TRYM := preload("res://ramon/chickenpen/scripts/pen_trym_4d.gd")

@export var stage_path: NodePath
@export var caption_path: NodePath
@export var presenter_path: NodePath
## The shot camera, and the chair that hands it the job.
@export var camera_path: NodePath
@export var seat_path: NodePath

@export_group("Pacing")
## Long enough for him to walk the house and for you to follow him down it.
@export_range(1.0, 30.0, 0.5) var opening_seconds: float = 11.0
@export_range(4.0, 40.0, 0.5) var act_seconds: float = 16.0
@export_range(1.0, 20.0, 0.5) var closing_seconds: float = 9.0
@export_range(0.2, 6.0, 0.1) var change_seconds: float = 1.6

@export_group("The presenter")
## Whoever he is talking to, so he addresses the person in the room rather than a fixed
## point the person may well not be standing at.
## The way out, so the end of the talk can light it up.
@export var exit_path: NodePath
## Part two, which is offered rather than played. It only runs on a yes.
@export var part_two_path: NodePath
@export var audience_path: NodePath
## He comes in the same way you do - through the door, down the walkway, ahead of you -
## and then works between two marks: one out front for the claim, one in on the drum for
## the demonstration. A presenter who stands on one spot for a minute is a sign, not a
## speaker, and one who is simply already on stage when you arrive never came from
## anywhere.
@export var wings := Vector4(0.0, 0.0, 16.2, 0.0)
## BEHIND THE PODIUM, which theatre_stage_4d builds at (-4.45, 0, 1.5) - drum_radius plus
## 1.35 out to the left, with its lit strip facing the house at +Z.
##
## The claim mark used to sit at z 2.6, which is over a metre IN FRONT of the stand: he
## delivered the whole talk standing between the audience and his own lectern. Squarely
## behind it is one step further out, in line with it rather than off to one side, so it
## reads as his and not as scenery he happens to be near.
##
## AND NOT BEHIND THE DRUM EITHER, which was the overcorrection. Four metres past the
## turntable put him against the backdrop with every exhibit between him and the house -
## technically "behind the table" and useless to look at.
@export var mark_claim := Vector4(-4.45, 0.0, 0.8, 0.0)
## A step in towards the drum for the demonstration, so he is beside the thing he is
## pointing at rather than talking about it from the lectern.
@export var mark_exhibit := Vector4(-3.9, 0.0, 0.6, 0.0)
## Brisk. He has the length of the house to cover before the first act, and a man
## strolling it at a metre a second is a man the audience overtakes.
@export_range(0.3, 4.0, 0.05) var presenter_speed: float = 1.95
## HOW MUCH OF EACH ACT HE SPENDS AT THE EXHIBIT rather than at his lectern, as a fraction
## of the act. He used to stand out front for the first third and only then step in, which
## made the walk to the stage a thing that happened once and briefly - and it is the best
## thing he does, because it is the only moment he stops being a voice and becomes a man
## showing you an object. So he goes over sooner and stays longer.
@export_range(0.0, 1.0, 0.01) var steps_in_at: float = 0.16
## And when he turns from the house to the thing itself. After he has arrived, so he
## crosses the floor facing the people he is talking to.
@export_range(0.0, 1.0, 0.01) var turns_to_it_at: float = 0.34
## HE WENT THROUGH THE DOOR AHEAD OF YOU, so you should arrive to find him already on his
## way down rather than standing in the dark waiting to be watched. This is how far along
## his walk he is the moment the room appears - 0 is still in the wings, 1 is at the foot
## of the rake. A man who waits offstage until his audience is seated did not go first.
@export_range(0.0, 0.95, 0.01) var presenter_head_start: float = 0.34

@export_group("Waiting for you")
## He holds at his mark until you sit down. This is the cap on that, so a player who never
## finds the chair is not left in a room where nothing ever happens - he starts anyway and
## you watch it standing up, camera untouched.
@export_range(0.0, 120.0, 1.0, "suffix:s") var waits_for_seat: float = 40.0
## And a beat after you land in the chair before he starts, so the camera has somewhere
## to go between the sitting and the first finding - it turns off the chair and finds
## him standing there waiting, which is what a presenter does while an audience settles.
@export_range(0.0, 15.0, 0.5, "suffix:s") var after_sit_seconds: float = 3.5
## And how long the camera stays on you once you are down, before it turns to find him.
@export_range(0.0, 6.0, 0.1, "suffix:s") var hold_on_seat_seconds: float = 1.3

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
## Announced as well as acted on. This is the single point where the talk is over by any
## route - part one ending with no part two, part two ending, or the offer declined - so
## it is the only honest thing for anybody downstream to listen to.
signal finished

## How long the closing caption stays up once the talk is over.
@export_range(0.0, 30.0, 0.5) var caption_hold: float = 3.0
var _clear_in: float = -1.0

var _done: bool = false
## The WHOLE talk is over - both halves, whichever way you went. `_done` is only part one
## finishing, which is not the same thing at all: saying yes to part two means the
## presentation carries on for another nine slides with `_done` already set.
var _over: bool = false
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
var _exit: Node
var _part_two: Node
var _held: int = -1
var _spin: bool = true
var _stride: float = 0.0
var _walking: bool = false
var _face: float = 0.0
var _got_down: bool = false
var _camera: Node
var _seat: Node
var _waited: float = 0.0
var _greeted: bool = false
var _sat_for: float = 0.0
var _lent: bool = false


func _ready() -> void:
	_stage = get_node_or_null(stage_path) as Node4D
	_caption = get_node_or_null(caption_path)
	_presenter = get_node_or_null(presenter_path) as Node4D
	_audience = get_node_or_null(audience_path) as Node4D
	_exit = get_node_or_null(exit_path)
	_part_two = get_node_or_null(part_two_path)
	_camera = get_node_or_null(camera_path)
	_seat = get_node_or_null(seat_path)
	if _stage == null:
		push_warning("TheatreShow: no stage, so there is nowhere to put any of this.")
		return
	if _presenter != null:
		# Already walking. The room is instanced the instant you step through the door, so
		# his _ready and your arrival are the same moment - and placing him at the wings
		# there means you and he come through it together, which is not what happened.
		var foot: Vector4 = _stage.get("aisle_from")
		_presenter.position = wings.lerp(
			Vector4(foot.x, 0.0, foot.z, 0.0), presenter_head_start)
		_face = atan2(foot.x - _presenter.position.x, foot.z - _presenter.position.z)
		_dress_presenter()
		# Past the beat in the doorway, or he would stop dead for a second and then set
		# off, half way down a walkway he is supposed to have been walking along.
		_phase = 1.5
	_table = _stage.get_node_or_null("Turntable") as Node4D
	for panel in (_stage.get_node_or_null("Backdrop").get_children()
			if _stage.get_node_or_null("Backdrop") != null else []):
		if panel is MeshInstance4D:
			_panels.append(panel)
	for beam in (_stage.get_node_or_null("Beams").get_children()
			if _stage.get_node_or_null("Beams") != null else []):
		if beam is MeshInstance4D:
			_beams.append(beam)
	# Built across the next few frames rather than here - see _build_exhibits. Nothing is
	# on stage for the opening anyway; the room is dark and he is still walking on.
	# The way out is NOT switched off here. It stands open from the moment you arrive,
	# at the head of the walkway, because a walkway that leads to nothing for the first
	# seven seconds is a walkway that leads to nothing - and a room you cannot leave is
	# not a room you explore, it is one you sit out.


# ---------------------------------------------------------------- the exhibits

## ONE ACT A FRAME, STARTING IMMEDIATELY.
##
## The same change part two needed and for the same reason, in smaller numbers: these three
## were built inside `_ready`, so they were paid on the frame the door was crossed. 209 ms
## of the theatre's 510 in a debug build - not the disaster part two was, but the largest
## thing left once that was dealt with, and a handful of dropped frames at exactly the
## moment the player is looking for a reaction to having walked through a door.
##
## SPREAD AGAINST WHEN EACH IS ACTUALLY WANTED, which is much further apart than it first
## looks. Act one is needed when the opening ends, eleven seconds in. Act two is not wanted
## until sixteen seconds after that, and act three sixteen after that again - so only ONE
## of the three has any urgency at all, and the other two have half a minute each.
##
## AND A CAMERA MOVE IS THE WORST PLACE TO PUT ONE, not the best. It is tempting to hide
## the work under the arrival, because something is already happening - but a dropped frame
## during motion is exactly when a dropped frame is visible. The image is supposed to be
## changing smoothly and suddenly is not. The same frame lost while you are sitting still
## looking at a slide is close to invisible. So one act is made early enough to be ready
## for the opening, and the rest are made while you are seated and the shot is still.
##
## Anything that needs them sooner calls finish_building(), which `_enter` does.
const ACT_BUILDERS: Array[StringName] = [&"_act_one", &"_act_two", &"_act_three"]
## Before the first one. Early, because act one has to exist by the end of the opening -
## it is the only one of the three that is in any hurry.
@export_range(0.0, 20.0, 0.1) var build_delay: float = 1.2
## And between each. Long, because acts two and three have half a minute apiece and every
## second of that is a second further from the arrival.
@export_range(0.0, 30.0, 0.5) var build_gap: float = 8.0

var _built: int = 0
var _build_wait: float = -1.0


func _build_one() -> void:
	var piece: Node4D = call(ACT_BUILDERS[_built]) as Node4D
	_built += 1
	if piece == null:
		return
	_exhibits.append(piece)
	piece.visible = false


func finish_building() -> void:
	while _built < ACT_BUILDERS.size():
		_build_one()


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
	if _clear_in > 0.0:
		_clear_in -= delta
		if _clear_in <= 0.0 and _caption != null and _caption.has_method("show_act"):
			_caption.call("show_act", "", "", "", "", "")
	# Before anything else: the exhibits are made while the opening plays.
	if _built < ACT_BUILDERS.size():
		if _build_wait < 0.0:
			_build_wait = build_delay
		_build_wait -= delta
		if _build_wait <= 0.0:
			_build_one()
			_build_wait = build_gap
	if _stage == null:
		return
	_clock += delta
	_phase += delta
	if _table != null and _spin:
		# Everything on the turntable turns, slowly, the whole time.
		_table.basis = Basis4D.from_zx(_clock * 0.22)
	_pulse()
	_perform(delta)
	# THE MOMENT YOU LAND IN THE CHAIR. The camera has been watching you sit down; it now
	# turns off the chair and finds him, and he gives it a beat before he begins. Without
	# this the first finding started on the same frame you touched the seat, because the
	# opening clock has been running since you walked in and had long since expired.
	#
	# AND IT HOLDS ON YOU FIRST. The shot used to change on the same frame the player
	# landed, which cut the sitting off at exactly the moment it finished - the one frame
	# it was worth holding on.
	if not _greeted and _act < 0 and _seat != null and _seat.has_method("is_settled") \
			and bool(_seat.call("is_settled")):
		_sat_for += delta
	if not _greeted and _sat_for > 0.0 and _sat_for >= hold_on_seat_seconds:
		_greeted = true
		_phase = maxf(0.0, opening_seconds - after_sit_seconds)
		_frame(-1)
	# The carve is taken early, not when act three starts. Every blow re-contours the whole
	# field - about a sixth of a second each - and four of them is most of a second of
	# frozen frames. Spent while the room is still assembling and nobody is watching
	# anything in particular it is invisible; spent on the turn into the act it is a
	# stutter in the middle of the presentation.
	#
	# BUT NOT BEFORE THE ROCK EXISTS, which is the bit that broke. This used to fire at a
	# third of a second, back when every exhibit was built inside _ready. The acts are made
	# a few seconds apart now, so act three - and `_rock` with it - does not exist until
	# about seventeen seconds in. The carve ran on nothing, took the `_rock == null` exit,
	# and set `_carved` on the way out, so the block went on stage solid. The tunnel you
	# turn a slice to look through was simply never cut.
	if not _carved and _phase > 0.35 and _rock != null:
		_carve_once()

	if _act < 0 and _phase >= opening_seconds and _ready_for_you(delta):
		_enter(0)
	elif _act >= 0 and _act < ACTS.size() and _phase >= act_seconds:
		_enter(_act + 1)
	elif _act == ACTS.size() and _phase >= closing_seconds:
		_finish()

	if _act >= 0 and _act < ACTS.size():
		_demonstrate(_act, _phase)


## HE WAITS FOR YOU TO SIT. The whole opening is him crossing the room and you following
## him down it, and starting the first finding at somebody still on the stairs is starting
## it at nobody. Once he is on his mark he simply stands there, looking at the house,
## until you are in the chair.
##
## CAPPED, though. A player who never finds the chair - or does not want it - is not left
## in a room where nothing ever happens: he gives up waiting and presents to a man
## standing in an aisle, which is a thing that happens at real presentations.
func _ready_for_you(delta: float) -> bool:
	if _seat == null or not _seat.has_method("is_seated"):
		return true
	if bool(_seat.call("is_seated")):
		return true
	_waited += delta
	return _waited >= waits_for_seat


## What the camera is doing, act by act. Most of them hold: see theatre_camera_4d's header
## for why there are no orbits in here.
func _frame(act: int) -> void:
	if _camera == null or not _camera.has_method("shoot"):
		return
	var shot: String = "house"
	var over: float = act_seconds
	if act < 0:
		shot = "presenter"
		over = opening_seconds
	elif act == 0:
		# The exhibit is an ABSENCE. The camera goes toward it anyway, which is the joke.
		shot = "push"
	elif act == 1:
		# A box round a thing that is not a box: a comparison, and comparisons are read
		# from one place. Held.
		shot = "house"
	elif act == 2:
		# The rock turning through W. Held close, because it is already turning and a
		# camera turning with it would cancel the turn out.
		shot = "close"
	else:
		shot = "presenter"
		over = closing_seconds
	_camera.call("shoot", shot, over)


## THE SAME MAN WHO WAS IN THE SHED. The presenter here was a bare block avatar with its
## colours typed into theatre.tscn by eye, and they had drifted - near-black instead of
## his shirt, no eyes, and no trousers at all, so the shared avatar painted his legs in
## the shirt colour and his feet in his face colour and he presented in the dark with bare
## feet. Somebody walks out of one scene and into the other; he cannot change on the way.
##
## THE COLOURS ARE READ OFF pen_trym_4d.gd RATHER THAN COPIED. `new()` on a Node script
## builds the object without parenting it, so none of its _ready runs and no desk, stool
## or shelf of books is made - it is just a bag of defaults to ask, and it is freed on the
## way out. Copying the four colours over would have worked today and drifted again the
## first time anyone recoloured him.
##
## ORDER MATTERS. `hair`, `eyes` and the eye measurements have no setters and so do not
## rebuild the avatar; `skin` and `accent` do. So everything quiet is set first and `skin`
## last, and the one rebuild it triggers picks up all of it.
func _dress_presenter() -> void:
	if _presenter == null:
		return
	var him: Object = TRYM.new()
	_presenter.set("hair", him.get("hair"))
	_presenter.set("wear_cap", false)
	_presenter.set("eyes", true)
	_presenter.set("eye_colour", Color(0.11, 0.12, 0.16))
	_presenter.set("eye_spacing", 0.080)
	_presenter.set("eye_height", 0.035)
	_presenter.set("eye_width", 0.040)
	_presenter.set("eye_tall", 0.044)
	_presenter.set("build", 2)
	_presenter.set("accent", him.get("skin"))
	# Last, and the rebuild this triggers is the one that draws everything above.
	_presenter.set("skin", him.get("shirt"))
	# TROUSERS, sleeved over each leg segment a shade wider so they read as cloth over the
	# limb rather than fighting it, and parented to the joints so they bend with the walk.
	# The shared avatar paints legs, face and hands from ONE colour, so a man in a black
	# shirt comes out bare-legged - which is the whole reason the shed version has these.
	var cloth: Color = him.get("trousers")
	for tag in ["L", "R"]:
		var hip: Node4D = _presenter.get_node_or_null("Hip%s" % tag) as Node4D
		var knee: Node4D = _presenter.get_node_or_null("Hip%s/Knee%s" % [tag, tag]) as Node4D
		if hip != null:
			_trouser(hip, "Trouser%s" % tag, Vector4(0.0, -0.16, 0.0, 0.0),
				Vector3(0.145, 0.33, 0.155), cloth)
		if knee != null:
			_trouser(knee, "TrouserLower%s" % tag, Vector4(0.0, -0.16, 0.0, 0.0),
				Vector3(0.135, 0.33, 0.145), cloth)
	him.free()


func _trouser(parent: Node, part: String, at: Vector4, size: Vector3,
		colour: Color) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	# 0.47 through W, the same as the shed's, so he is as solid off the slice as on it.
	mesh.size = Vector4(size.x, size.y, size.z, 0.47)
	node.mesh = mesh
	var cloth := TetraMaterial4D.new()
	cloth.albedo_color = colour
	node.material_override = cloth
	parent.add_child(node)
	node.position = at


## Part two drives him too, because he is still the one talking. -1 hands him back to the
## act clock; 0 puts him out front where a claim gets made; 1 puts him in on the drum where
## it gets demonstrated. Without this he would stand on his closing mark for five more
## exhibits, which is the difference between a presenter and a hat stand.
func hold_at(mark: int) -> void:
	_held = mark


## Part two switches the turntable off for its comparison exhibits. Three columns of
## different heights are a chart, and a chart that rotates spends half its time with the
## columns lined up behind one another - which is exactly how the first capture of it came
## out. The spin is charm for a single object and an obstacle for three.
func set_spin(on: bool) -> void:
	_spin = on
	if not on and _table != null:
		_table.basis = Basis4D.from_zx(0.0)


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
	if _held >= 0:
		# Part two is running the show now.
		goes_to = mark_exhibit if _held == 1 else mark_claim
		if _held == 1:
			looks_at = drum
	elif _act < 0:
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
		if t >= steps_in_at:
			goes_to = mark_exhibit
		if t >= turns_to_it_at:
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
			# NEGATIVE, because an elbow is not a knee. The sign convention every limb in
			# this project shares - POSITIVE folds the lower segment back under the upper
			# one - is right for a leg and exactly backwards for an arm: it bent his
			# forearms away behind him. Straight when pointing, bent when it is not doing
			# anything in particular.
			elbow.basis = Basis4D.from_yz(
				-(0.38 * (1.0 - lift / 1.35) + absf(counter) * 0.3))
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
	finish_building()
	_act = act
	_phase = 0.0
	_show(act)
	_frame(act)
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
		_caption.call("show_act", title, body, figure, "", NAV)


## THE SAME CONTROLS AS PART TWO, because from a chair the two are one presentation and
## finding that the arrows stop working half way through it is finding a seam. The clock
## still runs underneath either way - stand still and it plays itself.
##
## IT KEEPS ITS HANDS OFF while part two is running or the prompt is up: part two has its
## own handler and the prompt is waiting on a yes, and two things stepping on one click is
## the sort of bug that only shows up in front of somebody.
func _unhandled_input(event: InputEvent) -> void:
	# `_done` IS NOT THE END WHEN THE FLOOR HAS BEEN LENT BACK. Part one sets `_done` when
	# it finishes and offers part two; this used to return on it unconditionally, which
	# killed the arrow keys for the rest of the night. So stepping BACK off part two's
	# first slide worked - part two has its own handler and called in here - and stepping
	# forward again did nothing at all, because the key never got past this line.
	#
	# Both halves then sat waiting for each other: part two had set `_lent_back`, which
	# stops its clock and its input, and the only thing that could clear it was a forward
	# step arriving here. That is the hang - the show frozen on a slide with the player
	# still able to walk about, which is what Ramon saw.
	if (_done and not _lent) or _stage == null:
		return
	# Unless part two has lent the floor back - see step_back_from_part_two.
	if not _lent and _part_two != null and _part_two.has_method("is_running") \
			and bool(_part_two.call("is_running")):
		return
	var step := 0
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		step = 1
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_RIGHT:
			step = 1
		elif key.keycode == KEY_LEFT:
			step = -1
	if step == 0:
		return
	get_viewport().set_input_as_handled()
	# BORROWED, SO FORWARD GIVES IT BACK. Part two lent the floor for one step;
	# stepping forward from here returns to its first slide rather than walking into
	# part one's closing beat and offering part two all over again.
	if _lent and step > 0:
		_lent = false
		if _part_two != null and _part_two.has_method("resume"):
			_part_two.call("resume")
		return
	# FORWARD OFF THE END FINISHES IT, rather than saying the last line again.
	#
	# This is the bug that stopped the offer ever arriving. _enter resets the phase clock,
	# and stepping forward while already on the closing beat clamped to the same index and
	# re-entered it - so every click restarted the nine seconds the offer is waiting on.
	# Clicking to hurry the end along was the one thing that held it open, which is a
	# nasty shape of bug: the more impatient you are, the longer it takes, for ever.
	if step > 0 and _act >= ACTS.size():
		_finish()
		return
	# Backward out of the first act goes to the arrival, which is what it was.
	_enter(clampi(_act + step, -1, ACTS.size()))


## The end of part one: light the way out, and either ask them about part two or let them
## go. Once, whether it was the clock that got here or somebody clicking.
func _finish() -> void:
	if _done:
		return
	_done = true
	# The way out has been usable the whole time - nobody is shut in here - but now it is
	# the thing to look at, so it is turned up.
	if _exit != null:
		_exit.set("highlight", 1.0)
	if _part_two != null and _part_two.has_method("offer"):
		_part_two.call("offer")
	else:
		# Nobody is going to ask them anything, so this is the end of it.
		let_them_go()
	_say("", "That is the lot. The way out is behind you - mind the step, it is further through W than it looks.", "")


## Part two stepping backwards off its own first slide. It has already taken its
## exhibits off the drum and handed the presenter back, so this only has to put the
## last finding up again and start listening.
##
## `_done` is deliberately left set. This is a replay, not the talk running a second
## time, and the offer must not fire again on the way past.
func step_back_from_part_two() -> void:
	_lent = true
	_enter(ACTS.size() - 1)


## Lets go of the chair, hands the camera back, and puts the player on their feet facing
## the way out.
##
## THIS IS WHAT WAS MISSING AT THE END. The show finished, the camera stayed held, and the
## player stayed pinned in a seat with no way out but a movement key nobody had told them
## about - which is not a presentation ending, it is a room that will not let you leave.
## Take part one's exhibits off the stage, without touching anything else.
##
## Part two needs this when it takes the floor back after lending it. Stepping backwards
## off part two's first slide puts part one's last finding up - which means making the
## mined rock visible again - and stepping forward returns to part two. Nothing used to
## clear the rock on the way back, so from then on every part two slide was played with
## act three standing in the middle of it, and the goat came up inside the voxel block.
func clear_stage() -> void:
	_show(-1)


func is_over() -> bool:
	return _over


func let_them_go() -> void:
	if not _over:
		_over = true
		# AND THE BAND GOES AWAY, eventually. The last caption - "that is the case as it
		# stands" after part two, or "that is the lot" after part one - used to sit across
		# the bottom of the screen for the rest of the visit, because nothing ever cleared
		# it. It is the presentation's voice, and the presentation has finished; leaving it
		# up made the room look like it was still mid-sentence while you walked about.
		#
		# Not immediately, though: the line is the closing line and it should be readable
		# after the talk has stopped.
		_clear_in = caption_hold
		finished.emit()
	if _exit != null:
		_exit.set("highlight", 1.0)
	if _seat != null and _seat.has_method("is_seated") and bool(_seat.call("is_seated")):
		_seat.call("stand")


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
