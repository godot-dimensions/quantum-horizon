extends Node4D

## The presentation's opening and its first five slides, staged: how to look at 4D.
##
## ONE PRESENTATION (Ramon, 30 Sept), in two halves that run straight through. This node
## walks Trym in, sits you down and plays slides I to VI - how to look at four dimensions -
## then hands the floor to theatre_part_two_4d for VII to IX, what the team built to work
## in them. No closing line and no question between the two: part two is its own node
## because its exhibits are its own, not because anybody is asked about it.
##
##   I    WHAT YOU SEE IS A SLICE       a flat chicken on a sheet        theatre_primer_4d
##   II   THINGS ARRIVE FROM NOWHERE    a 4D ball and a tesseract        theatre_primer_4d
##   III  A SLICE IS NOT A CAMERA ANGLE the mined rock, turned through W here
##   IV   SHAPES WITH NO 3D TWIN        the tiger, the Klein bottle...   theatre_primer_4d
##   V    NOW YOU TURN IT               you hold the shapes yourself     theatre_primer_4d
##   VI   A LEFT GLOVE, TURNED, IS A RIGHT GLOVE                        theatre_primer_4d
##
## Trym, 30 Sept: show some interesting 4D shapes, borrow the "2D slice of a 3D world"
## intro for now, and let people hold a weird shape and turn it themselves. That is I, IV,
## V and VI; II is the bridge from the chicken's world to ours.
##
## THE EXHIBIT IS NOT AN ILLUSTRATION OF THE FINDING, IT IS THE FINDING. Slide III turns a
## real VoxelMiningBlock through W and the cross-section really does become a different
## solid; the shapes of IV and V are meshed from their own equations and sliced by the same
## renderer as everything else. A presentation that mimes its own subject is a slideshow;
## this one can be checked by walking up to it.
##
## ONE RUNNER, NOT AN ANIMATION PLAYER PER SLIDE. Every act is rise, hold, demonstrate,
## sink, and the differences between them are a handful of numbers and one callback each -
## so the sequence lives in a table and the acts supply only what makes them themselves.
## That is the same shape the dialogue takes, for the same reason.
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
## Slides I, II, IV and V: their exhibits and how they move.
const PRIMER := preload("res://ramon/chickenpen/theatre/theatre_primer_4d.gd")

@export var stage_path: NodePath
@export var caption_path: NodePath
@export var presenter_path: NodePath
## The shot camera, and the chair that hands it the job.
@export var camera_path: NodePath
@export var seat_path: NodePath
## The figures set beside an exhibit, and the screen over the stage (the chicken's flat
## world, and the shadows). Both belong to the primer's slides.
@export var metrics_path: NodePath
@export var screen_path: NodePath

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
## Part two, which takes over the moment the last slide here ends. Nobody is asked.
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

## Each act: the title, the finding in one line, the figure under it, and the colour the
## room turns while it is running. `id` says which exhibit it is; `pace` multiplies the
## shared act length, the way part two's moments do; `shot` is the camera's framing (see
## theatre_camera_4d.SHOTS); `spin` is whether the turntable turns under it. The figures'
## {placeholders} are counted off the exhibits themselves (theatre_primer_4d.fill).
##
## NO SPACED DASHES in any of these lines: they are read by people, and a " - " clause
## reads as machine-written (Ramon's rule for every player-facing line).
const ACTS := [
	{
		"id": "chicken",
		"title": "I. WHAT YOU SEE IS A SLICE",
		"body": "This chicken lives on a flat sheet. It can move only inside it, and it sees only what the sheet cuts through. A ball passing through its world is, to the chicken, a circle that comes from nowhere, grows, shrinks and is gone. Your screen is the chicken's sheet, one dimension up.",
		"figure": "The ball was never in the chicken's world. Only the circle was.",
		"tint": Color(0.10, 0.30, 0.46),
		"shot": "sheet",
		"pace": 1.4,
		"spin": false,
	},
	{
		"id": "visitors",
		"title": "II. THINGS ARRIVE FROM NOWHERE",
		"body": "The same thing, one dimension up. This ball is round in four directions and is travelling along the one you cannot see. Your slice meets it as a point, then a sphere that grows and shrinks, then nothing. A tesseract arrives face first as a cube that is simply there, and corner first as a point that swells into a pyramid and then an octahedron.",
		"figure": "One ball, {ball_tetra} tetrahedra. You only ever see one slice of it. The screen shows its shadow, all of it at once.",
		"tint": Color(0.20, 0.12, 0.40),
		"shot": "push",
		"pace": 1.8,
		"spin": true,
	},
	{
		"id": "rock",
		"title": "III. A SLICE IS NOT A CAMERA ANGLE",
		"body": "Turn through W and you are not looking at the same solid from somewhere else. You are looking at a different solid. The hole stays where it was; the cross-section through it does not.",
		"figure": "One rock. One tunnel. Every angle a shape nobody made on purpose.",
		"aside": "This is the one worth the walk.",
		"tint": Color(0.16, 0.44, 0.24),
		"shot": "close",
		"pace": 1.0,
		"spin": true,
	},
	{
		"id": "zoo",
		"title": "IV. SHAPES WITH NO 3D TWIN",
		"body": "None of these has a three-dimensional version. The tiger is a flat torus given thickness, a surface that only fits in four dimensions. The Klein bottle has to pass through itself in 3D; here it never touches itself. On the drum you see their slices, and on the screen their shadows, coloured by how far along W each part is.",
		"figure": "Five shapes built from their equations, {zoo_tetra} tetrahedra between them.",
		"tint": Color(0.36, 0.14, 0.30),
		"shot": "zoo",
		"pace": 2.4,
		"spin": true,
	},
	{
		"id": "toy",
		"title": "V. NOW YOU TURN IT",
		"body": "Hold the right mouse button and drag to turn it through W, the same way you turn your slice in the field. Scroll for the next shape. Every shape you see here is a slice of the same object, and you are the one choosing which.",
		"figure": "Left alone, it turns itself. Take hold of it and it is yours.",
		"tint": Color(0.12, 0.34, 0.34),
		"shot": "house",
		"pace": 1.5,
		"spin": false,
	},
	{
		"id": "glove",
		"title": "VI. A LEFT GLOVE, TURNED, IS A RIGHT GLOVE",
		"body": "In three dimensions no turn will ever make a left glove into a right one. Only a mirror can. Drag sideways and turn the left one half way round through W: it thins to nothing as it leaves your slice, and comes back the other way round.",
		"figure": "No mirror and no cut. Just a turn, in a direction you cannot point to.",
		"tint": Color(0.30, 0.24, 0.10),
		"shot": "gloves",
		"pace": 1.3,
		"spin": false,
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
## route - part two ending, or this node's closing line in a room without one - so it is
## the only honest thing for anybody downstream to listen to.
signal finished
## And the other direction: somebody sat down again after the end, and it is on again.
signal restarted

## How long the closing caption stays up once the talk is over.
@export_range(0.0, 30.0, 0.5) var caption_hold: float = 3.0
var _clear_in: float = -1.0

var _done: bool = false
## The WHOLE talk is over. `_done` is only this node's slides finishing, which is not the
## same thing at all: part two carries the presentation on for three more slides with
## `_done` already set.
var _over: bool = false
var _rock: Node4D
var _carved: bool = false
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
var _primer: Node
## The way out's highlight while the talk is on, so a second showing can put it back.
var _exit_rest: float = 0.75


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
	# The primer's shapes start on a worker thread now, so they are long made by the time
	# anybody sits down; see theatre_primer_4d.
	_primer = PRIMER.new()
	_primer.name = "Primer"
	add_child(_primer)
	_primer.call("setup", _table, get_node_or_null(metrics_path), get_node_or_null(screen_path), _seat)
	if _exit != null:
		_exit_rest = float(_exit.get("highlight"))
	if _seat != null and _seat.has_signal("sat"):
		_seat.connect("sat", _on_sat)
	# Built across the next few frames rather than here - see _build_exhibits. Nothing is
	# on stage for the opening anyway; the room is dark and he is still walking on.
	# The way out is NOT switched off here. It stands open from the moment you arrive,
	# at the head of the walkway, because a walkway that leads to nothing for the first
	# seven seconds is a walkway that leads to nothing - and a room you cannot leave is
	# not a room you explore, it is one you sit out.


# ---------------------------------------------------------------- the exhibits

## BUILT WHEN YOU SIT DOWN, not when you walk in. All five, one a frame.
##
## These were built inside `_ready` once, so they were paid on the frame the door was
## crossed - a handful of dropped frames at exactly the moment the player is looking for a
## reaction to having walked through a door. Then they were spread out on a timer, the
## first 1.2 seconds in, which was fine while the first exhibit was two plinths and a box.
##
## THE ROCK IS THE EXPENSIVE ONE: a lattice to contour and three blows that re-contour it,
## most of a second between them. A dropped frame during motion is exactly when a dropped
## frame is visible, and 1.2 seconds in you are walking down the rake with the camera
## following. So they are made on the beat the camera holds still on you in the chair
## (theatre_seat_4d's is_settled), which is the one moment in the arrival where losing a
## few frames costs nothing. The primer's four are cheap by then: their meshes were made on
## a worker thread while you walked in, and building them is placing nodes.
##
## SOMEBODY WHO DOES NOT SIT gets it once the opening has run and he is standing on his
## mark waiting for them - the other still point, and still well before the slide. Anything
## that needs it sooner than either gets it from finish_building(), which `_enter` calls.
const ACT_BUILDERS: Array[StringName] = [&"_the_chicken", &"_the_visitors", &"_the_rock",
	&"_the_zoo", &"_the_toy", &"_the_gloves"]

var _built: int = 0


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


func _the_chicken() -> Node4D:
	return _primer.call("build", "chicken") as Node4D


func _the_visitors() -> Node4D:
	return _primer.call("build", "visitors") as Node4D


func _the_zoo() -> Node4D:
	return _primer.call("build", "zoo") as Node4D


func _the_toy() -> Node4D:
	return _primer.call("build", "toy") as Node4D


func _the_gloves() -> Node4D:
	return _primer.call("build", "glove") as Node4D


## A real mined block, turned through W so its cross-section changes.
func _the_rock() -> Node4D:
	var piece := Node4D.new()
	piece.name = "SliceRock"
	_table.add_child(piece)
	var rock: Node4D = ROCK.instantiate()
	rock.name = "Rock"
	piece.add_child(rock)
	rock.position = Vector4(0.0, 1.9, 0.0, 0.0)
	# NOT scaled by a basis - it is a real physics object and its colliders are built in
	# its own frame. It gets bigger the way the professor says a rock gets bigger: fatter
	# CELLS, same 8^4 lattice, so it costs exactly what it cost before.
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
	# Before anything else: the rock is made on the still beat in the chair - or, for
	# somebody who has not sat down by the time the opening has run, while he stands on his
	# mark waiting for them. See the header on ACT_BUILDERS.
	if _built < ACT_BUILDERS.size():
		var settled: bool = _seat != null and _seat.has_method("is_settled") \
			and bool(_seat.call("is_settled"))
		if settled or (_act < 0 and _phase >= opening_seconds):
			_build_one()
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
	# The carve is taken as soon as the rock exists, not when its slide starts. Every blow
	# re-contours the whole field - about a sixth of a second each - and three of them is
	# most of a second of frozen frames. Spent on the still beat in the chair it is
	# invisible; spent on the turn into the slide it is a stutter in the middle of the
	# presentation.
	#
	# NOT BEFORE THE ROCK EXISTS, which is the bit that broke once: the carve ran on
	# nothing, took the `_rock == null` exit, set `_carved` on the way out, and the block
	# went on stage solid. The tunnel you turn a slice to look through was never cut.
	if not _carved and _rock != null:
		_carve_once()

	if _act < 0 and _phase >= opening_seconds and _ready_for_you(delta):
		_enter(0)
	elif _act >= 0 and _act < ACTS.size() and _phase >= _length(_act):
		_enter(_act + 1)
	elif _act == ACTS.size() and not _done and _phase >= closing_seconds:
		_finish()

	if _act >= 0 and _act < ACTS.size():
		_demonstrate(_act, _phase, delta)


## How long an act runs: the shared length times its own pace, so slowing the whole talk
## down still slows the long ones with it.
func _length(act: int) -> float:
	if act < 0 or act >= ACTS.size():
		return act_seconds
	return act_seconds * float(ACTS[act].get("pace", 1.0))


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
	var over: float = _length(act)
	if act < 0:
		shot = "presenter"
		over = opening_seconds
	elif act < ACTS.size():
		# Each act names its own framing. The rock's is held close, because it is already
		# turning and a camera turning with it would cancel the turn out.
		shot = String(ACTS[act].get("shot", "house"))
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
	var t: float = _phase / maxf(_length(_act), 0.01)
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


## Which act is on: -1 while the room is still arriving, 0 to 5 for slides I to VI, then
## ACTS.size() once part two has the floor.
func current_act() -> int:
	return _act


func _enter(act: int) -> void:
	finish_building()
	if act >= ACTS.size() and _part_two != null and _part_two.has_method("begin"):
		_hand_over()
		return
	_act = act
	_phase = 0.0
	_show(act)
	_frame(act)
	if act < ACTS.size():
		var a: Dictionary = ACTS[act]
		set_spin(bool(a.get("spin", true)))
		# The primer's slides are started (and a previous one of theirs ended) here; the
		# rock and the arrival are not the primer's, and leaving it clears its screen.
		var id: String = String(a.get("id", ""))
		if _primer != null:
			if id == "rock":
				_primer.call("leave")
			else:
				_primer.call("enter", id)
		var figure: String = String(a["figure"])
		if _primer != null:
			figure = String(_primer.call("fill", figure))
		_say(String(a["title"]), String(a["body"]), figure)
		_tint(a["tint"])
	elif act < 0:
		if _primer != null:
			_primer.call("leave")
	else:
		# Only without a part two, which the theatre always has. A room assembled without
		# one still ends on a line rather than on the last slide's caption.
		_say("", "That is the lot. The way out is behind you - mind the step, it is further through W than it looks.", "")
		_tint(Color(0.10, 0.12, 0.20))


## STRAIGHT ON INTO PART TWO, off the end of the last slide here - whether the clock got
## there or a click did. No closing line and no question in between: from the chair it is
## one presentation, so there is nothing to close and nobody to ask.
##
## AND IF THE FLOOR WAS ONLY BORROWED, IT GOES BACK. Stepping backwards off part two's
## first slide lends the floor to this node for a replay of slide I; running off the end of
## that replay is the same as stepping forward out of it, and must return to part two
## rather than try to start it a second time. Starting it again does nothing - it is still
## running - so part two sat lent-back with its clock stopped and the room froze.
func _hand_over() -> void:
	_act = ACTS.size()
	_phase = 0.0
	_show(-1)
	if _primer != null:
		_primer.call("leave")
	set_spin(true)
	if _lent:
		_lent = false
		if _part_two.has_method("resume"):
			_part_two.call("resume")
		return
	_done = true
	_part_two.call("begin")


## Which exhibit is on the table. One at a time, and the rest are not merely hidden but
## out of the way, so a slice turn cannot reveal last act's props behind this one.
func _show(act: int) -> void:
	for i in _exhibits.size():
		var on: bool = i == act
		_exhibits[i].visible = on
		_exhibits[i].position = Vector4(0.0, 0.0 if on else -40.0, 0.0, 0.0)


## What each act DOES, as opposed to what it looks like. The rock is this node's; the rest
## are the primer's.
func _demonstrate(act: int, t: float, delta: float = 0.0) -> void:
	var id: String = String(ACTS[act].get("id", ""))
	if id == "rock":
		# The money shot: the block turns through W, not about a spatial axis, so what
		# you are watching is not the rock rotating but the WORLD being cut somewhere
		# else. Paused at the ends so the eye can settle on each cross-section.
		if _rock != null:
			var sweep: float = sin(t * 0.55) * 0.95
			_rock.basis = Basis4D.from_xw(sweep) * Basis4D.from_zw(sweep * 0.45)
	elif _primer != null:
		_primer.call("demonstrate", id, t, _length(act), delta)


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
	# it hands over to part two; this used to return on it unconditionally, which
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
	# ON THE HANDS-ON SLIDES A CLICK IS THE RELEASE, NOT THE PRESS, and only if it was a click:
	# the left button also turns the exhibit there, and moving on the moment it went down
	# would throw away every slide somebody tried to take hold of (see the primer's
	# is_hands_on and was_clean_click).
	var hands_on: bool = _primer != null and bool(_primer.call("is_hands_on"))
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed and not hands_on:
			step = 1
		elif not click.pressed and hands_on and bool(_primer.call("was_clean_click")):
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
	# stepping forward from here returns to its first slide rather than starting it again.
	if _lent and step > 0:
		_lent = false
		if _part_two != null and _part_two.has_method("resume"):
			_part_two.call("resume")
		return
	# FORWARD OFF THE END FINISHES IT, rather than saying the last line again. Only reached
	# in a room without a part two; with one, stepping off slide I hands over in _enter.
	#
	# _enter resets the phase clock, and stepping forward while already on the closing beat
	# once clamped to the same index and re-entered it - so every click restarted the
	# seconds the ending was waiting on. The more impatient you were, the longer it took.
	if step > 0 and _act >= ACTS.size():
		_finish()
		return
	# Backward out of the first act goes to the arrival, which is what it was.
	_enter(clampi(_act + step, -1, ACTS.size()))


## The end of the talk in a room with no part two: light the way out and let them go.
## Once, whether it was the clock that got here or somebody clicking. With a part two,
## that node ends the talk and this is never reached.
func _finish() -> void:
	if _done:
		return
	_done = true
	# The way out has been usable the whole time - nobody is shut in here - but now it is
	# the thing to look at, so it is turned up.
	if _exit != null:
		_exit.set("highlight", 1.0)
	let_them_go()


## Part two stepping backwards off its own first slide. It has already taken its
## exhibits off the drum and handed the presenter back, so this only has to put slide VI
## up again and start listening.
##
## `_done` is deliberately left set. This is a replay, not the talk running a second
## time, and part two must not be started again on the way past - see _hand_over.
func step_back_from_part_two() -> void:
	_lent = true
	_enter(ACTS.size() - 1)


## Lets go of the chair, hands the camera back, and puts the player on their feet facing
## the way out.
##
## THIS IS WHAT WAS MISSING AT THE END. The show finished, the camera stayed held, and the
## player stayed pinned in a seat with no way out but a movement key nobody had told them
## about - which is not a presentation ending, it is a room that will not let you leave.
## Take part one's exhibit off the stage, without touching anything else.
##
## Part two needs this when it takes the floor back after lending it. Stepping backwards
## off part two's first slide puts slide I up again - which means making the mined rock
## visible again - and stepping forward returns to part two. Nothing used to clear the
## rock on the way back, so from then on every part two slide was played with the rock
## standing in the middle of it, and the goat came up inside the voxel block.
func clear_stage() -> void:
	_show(-1)
	# And the primer's screen and figures with it, or slide VI's labels would hang over the
	# goat after a step back and forward across the seam.
	if _primer != null:
		_primer.call("leave")


func is_over() -> bool:
	return _over


## SIT DOWN AGAIN AND IT PLAYS AGAIN. Ramon, 30 Sept: after the presentation, F in the
## chair "I can't watch it over. Instead I'm locked in a freeze." The chair still took the
## camera, and nothing was ever going to give it back: the talk was over, so no slide came
## and nothing stood you up, and the only way out was a movement key nobody had mentioned.
## A chair in a cinema after the film is an offer to see it again, so that is what it is.
func _on_sat() -> void:
	if _over:
		replay()


## Everything back to the moment before slide I, with Trym already on stage - he does not
## walk in a second time, he simply goes to his mark and waits for you to settle, the way
## the first showing waits. The exhibits are kept: they were built once, and the slides put
## each one back where it starts whenever it is entered.
func replay() -> void:
	_over = false
	_done = false
	_lent = false
	_greeted = false
	_sat_for = 0.0
	_waited = 0.0
	_clear_in = -1.0
	_held = -1
	_act = -1
	# Past the beat in the doorway (see _perform), so he heads for his mark, not the wings.
	_phase = 1.5
	_show(-1)
	set_spin(true)
	if _primer != null:
		_primer.call("leave")
	if _part_two != null and _part_two.has_method("reset"):
		_part_two.call("reset")
	if _exit != null:
		_exit.set("highlight", _exit_rest)
	if _caption != null and _caption.has_method("show_act"):
		_caption.call("show_act", "", "", "", "", "")
	restarted.emit()


func let_them_go() -> void:
	if not _over:
		_over = true
		# AND THE BAND GOES AWAY, eventually. The last caption - "that is the case as it
		# stands" - used to sit across
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
