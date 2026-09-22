extends Node

## PART TWO. The three engine findings were for whoever builds this. These five are for
## whoever funds it, and the audience is the October gate: Scott, Brandon, Aggelos,
## Nicolas, Charles — not designers, not 4D specialists, and several of them have
## questioned the funding of the comprehension seat specifically.
##
## EVERY CLAIM CARRIES ITS TIER, because that is the rule the real deck runs on: MEASURED,
## OBSERVED n=7, or NOT YET MEASURED, stated rather than implied. Overclaiming has cost
## this project credibility once already and the honesty is the deck's main asset with this
## audience. Nothing here softens a gap, and the accent marks the gap rather than the
## achievement — which is a deliberate inversion of normal practice and the reason the
## first exhibit's loudest column is the empty one.
##
## THE NUMBERS COME FROM THE PROGRAMME, NOT FROM ME. The three engine thresholds and the
## 0-of-3, the N=7 playtest and its caveats, the seven stop conditions and which of them
## cannot be read until 2027, the gate date and the three outcomes — all of it is from the
## stakeholder deck in follow_up/presentation temp, the Notion Work Log (current to
## 16 September 2026) and the Round 1 playtest results page. Where the source says a figure
## is provisional, so does the caption.
##
## IT IS GATED ON A QUESTION. Part one ends, Trym asks, and this only runs on a yes.
##
## THE TWO EXHIBITS THAT ARE REAL WORK RATHER THAN DIAGRAM - the goat and the walking
## creature - are both ADOPTED out of the Model scene rather than invented for the
## theatre. An earlier goat WAS invented here, lofted into a wedge, and cost most of a day
## before the obvious question got asked; the rule that came out of it is that a slide
## about something the team built has to be standing on the thing the team built.

const GOAT := preload("res://ramon/chickenpen/theatre/theatre_goat_4d.gd")
const CREATURE := preload("res://ramon/chickenpen/theatre/theatre_creature_4d.gd")

@export var stage_path: NodePath
@export var caption_path: NodePath
@export var prompt_path: NodePath
@export var show_path: NodePath
@export var presenter_path: NodePath
@export var metrics_path: NodePath
@export var camera_path: NodePath

@export_group("Pacing")
@export_range(4.0, 60.0, 0.5) var moment_seconds: float = 17.0
@export_range(1.0, 20.0, 0.5) var closing_seconds: float = 10.0

## Seven moments. `tint` recolours the backdrop; the palette is the deck's own chapter
## coding - Engine lime, Player pink, Developer violet, and the gate itself amber. The
## walking creature is teal rather than lime ON PURPOSE: it carries a real engine
## measurement, but it is not one of the three thresholds moment IV says are unmeasured,
## and colouring it as though it were would fill that empty column by implication.
##
## `shot` is how the camera frames the moment once you are sitting down, and every one of
## them is named in theatre_camera_4d.SHOTS. Four of the seven hold still. The two that
## move, move because the move IS the sentence: the camera drifts toward the plinth with
## nothing on it, and tracks away from the stop conditions that are not on your slice and
## finds empty floor where they would be.
##
## Two optional keys, both used by the walking creature and by nothing else yet. `pace`
## multiplies the shared moment length for a slide that needs longer than the rest - a
## MULTIPLIER rather than a number of seconds, so changing the pace of the presentation
## still changes this one too - and `later` re-issues the figures part way through, at a
## fraction of that length.
## How far apart the three copies of moment IV stand along W. The parts of the solid are
## built at these same depths, so each copy has exactly one of them on your slice.
const DEPTHS: PackedFloat32Array = [0.0, 1.45, 2.90]

const MOMENTS := [
	{
		"title": "IV. THESE THREE ARE THE SAME OBJECT",
		"body": "One solid, standing at three different depths along the axis you cannot see, so your slice cuts it in three different places. Nobody reads them as one thing on their first look - and everybody can be taught to. That is the whole player question, and it is the only pillar with evidence from outside this room.",
		"figure": "Seven testers, seven who had it by the end of one session, 8.4 of 10 forward interest. Recruited Cardano-adjacent, no non-gamers, and a form bug destroyed 5 of 7 written answers.",
		"tier": "OBSERVED - N=7, ROUND 1, MAY-JUNE 2026",
		"tint": Color(0.78, 0.35, 0.51),
		"piece": 0,
		"shot": "low",
		"pace": 1.7,
		"metrics": [
			{"at": Vector4(-4.6, 3.9, 0.0, 0.0), "value": "7 / 7", "side": -1.0,
				"label": "developed 4D intuition", "colour": Color(1.0, 0.55, 0.74)},
			{"at": Vector4(4.6, 2.6, 0.0, 0.0), "value": "8.4", "side": 1.0,
				"label": "forward interest, out of 10", "colour": Color(1.0, 0.55, 0.74)},
		],
		"later": [
			{"at": 0.44, "metrics": [
				{"at": Vector4(2.4, 4.4, 0.0, 0.0), "value": "1", "side": 1.0,
					"label": "object, on one slice at last",
					"colour": Color(1.0, 0.55, 0.74)},
			]},
			{"at": 0.64, "metrics": [
				{"at": Vector4(2.4, 4.4, 0.0, 0.0), "value": "3", "side": 1.0,
					"label": "of its cross-sections, in lockstep",
					"colour": Color(1.0, 0.55, 0.74)},
			]},
		],
	},
	{
		"title": "V. NOBODY BUILT THIS SURFACE",
		"body": "A designer made this goat, and made it without modelling anything. {balls} handles were placed - rump, barrel, chest, neck, skull, horns - and the tool generated every tetrahedron between them. Two of the four people who have built on this engine are not engine programmers, and nine Godot prototypes have come out of it.",
		"figure": "{tetra} tetrahedra from {balls} handles. {each} generated for every one placed.",
		"tier": "MEASURED - THIS BUILD, THIS SCENE",
		"tint": Color(0.52, 0.42, 0.85),
		"piece": 1,
		"shot": "close",
		"metrics": [
			{"at": Vector4(-2.7, 2.5, 0.0, 0.0), "value": "{balls}", "side": -1.0,
				"label": "handles placed by a designer", "colour": Color(0.72, 0.62, 1.0)},
			{"at": Vector4(2.7, 1.0, 0.0, 0.0), "value": "{tetra}", "side": 1.0,
				"label": "tetrahedra generated by the tool",
				"colour": Color(0.72, 0.62, 1.0)},
		],
		"later": [
			{"at": 0.60, "metrics": [
				{"at": Vector4(-2.7, 2.5, 0.0, 0.0), "value": "9", "side": -1.0,
					"label": "prototypes built on this engine",
					"colour": Color(0.72, 0.62, 1.0)},
				{"at": Vector4(2.7, 1.0, 0.0, 0.0), "value": "2 of 4", "side": 1.0,
					"label": "of us are not engine programmers",
					"colour": Color(0.72, 0.62, 1.0)},
			]},
		],
	},
	{
		"title": "VI. IT IS A TOOL, NOT A GOAT",
		"body": "Watch it being made, and then watch four handles move: the neck, the skull and both horns. Nothing is remodelled and no surface is touched - the tool regenerates it. That is what separates something an artist shapes creatures and characters with from a pipeline that happened to produce one goat. And a handle is something a machine can take hold of just as easily: the interface a designer uses is the interface an AI can drive.",
		"figure": "Same {balls} handles, same tool. Four of them moved; {tetra} tetrahedra followed.",
		"tier": "DEMONSTRATED - BUILT AND RESHAPED IN FRONT OF YOU",
		"tint": Color(0.42, 0.56, 0.92),
		"piece": 1,
		"shot": "quarter",
		"metrics": [
			{"at": Vector4(-2.7, 2.5, 0.0, 0.0), "value": "{balls}", "side": -1.0,
				"label": "handles, placed by hand or by machine",
				"colour": Color(0.62, 0.78, 1.0)},
		],
	},
	{
		"title": "VII. NOBODY ANIMATED THIS WALK EITHER",
		"body": "There is no 4D motion capture and no 4D animation package, so there is no clip to play. This is procedural animation in the strict sense - every frame of it is solved. A gait clock fires the footfalls, a FABRIK chain resolves each of the {legs} legs onto its own moving target, and the solvers above it flex the spine, hold the head steady against the bob and lag the tail behind the sway. Then the skin comes off, and the handles that shaped this animal turn out to be the joints that move it.",
		"figure": "{segments} rigid transforms a frame, under the noise floor. Skinning what has to deform instead: 79.31 ms to 19.76.",
		"tier": "MEASURED - ONE MACHINE, VSYNC OFF, 350 FRAMES AVERAGED, 19 SEP 2026",
		"tint": Color(0.10, 0.34, 0.40),
		"piece": 3,
		"shot": "profile",
		"pace": 1.55,
		"metrics": [
			{"at": Vector4(-4.6, 4.1, 0.0, 0.0), "value": "{creature_tetra}", "side": -1.0,
				"label": "tetrahedra in motion", "colour": Color(0.42, 0.88, 0.92)},
			{"at": Vector4(4.2, 2.2, 0.0, 0.0), "value": "~0 ms", "side": 1.0,
				"label": "this walk, per frame", "colour": Color(0.42, 0.88, 0.92)},
		],
		"later": [
			{"at": 0.31, "metrics": [
				{"at": Vector4(-4.6, 4.1, 0.0, 0.0), "value": "{segments}", "side": -1.0,
					"label": "rigid segments",
					"colour": Color(0.42, 0.88, 0.92)},
				{"at": Vector4(4.2, 2.2, 0.0, 0.0), "value": "{handles}", "side": 1.0,
					"label": "handles, doubling as the skeleton",
					"colour": Color(0.42, 0.88, 0.92)},
			]},
			{"at": 0.62, "metrics": [
				{"at": Vector4(-4.6, 4.1, 0.0, 0.0), "value": "{gaits}", "side": -1.0,
					"label": "gaits, one rig",
					"colour": Color(0.42, 0.88, 0.92)},
				{"at": Vector4(4.2, 2.2, 0.0, 0.0), "value": "~0 ms", "side": 1.0,
					"label": "this walk, per frame", "colour": Color(0.42, 0.88, 0.92)},
			]},
		],
	},
	{
		"title": "VIII. WHAT WOULD STOP THIS",
		"body": "Seven conditions, written down before the tests rather than after them. Three can be read today. The other four cannot be evaluated until the end of 2027 - so they are not standing where you are standing. Turn your slice and they are there.",
		"figure": "3 readable now. 4 not yet measurable. One of the three is whether 4D content still needs a specialist.",
		"tier": "PROPOSED - DELIVERABLE 2 SEVEN IS THE RECORD",
		"tint": Color(0.62, 0.30, 0.24),
		"piece": 2,
		"shot": "drift",
		"metrics": [
			{"at": Vector4(0.0, 2.2, -1.2, 0.0), "value": "3 of 7", "side": 1.0,
				"label": "readable today", "colour": Color(1.0, 0.52, 0.38)},
		],
	},
]

var _stage: Node4D
var _caption: Node
var _prompt: Node
var _show: Node
var _presenter: Node4D
var _table: Node4D
var _panels: Array[MeshInstance4D] = []

var _running: bool = false
var _moment: int = -1
var _phase: float = 0.0
var _pieces: Array[Node4D] = []
var _goat: Node4D
var _creature: Node4D
var _camera: Node
var _told: int = 0
var _copies: Array[Node4D] = []
var _stones: Array[Node4D] = []
var _metrics: Node
var _turned: bool = false
var _done: bool = false


func _ready() -> void:
	_stage = get_node_or_null(stage_path) as Node4D
	_caption = get_node_or_null(caption_path)
	_prompt = get_node_or_null(prompt_path)
	_show = get_node_or_null(show_path)
	_presenter = get_node_or_null(presenter_path) as Node4D
	_metrics = get_node_or_null(metrics_path)
	_camera = get_node_or_null(camera_path)
	if _stage == null:
		push_warning("TheatrePartTwo: no stage, so there is nowhere to put any of this.")
		return
	_table = _stage.get_node_or_null("Turntable") as Node4D
	for panel in (_stage.get_node_or_null("Backdrop").get_children()
			if _stage.get_node_or_null("Backdrop") != null else []):
		if panel is MeshInstance4D:
			_panels.append(panel)
	if _prompt != null and _prompt.has_signal("answered"):
		_prompt.connect("answered", _on_answered)
	_build()
	_show_piece(-1)


## Asked by the first show when it runs out of findings.
func offer() -> void:
	if _done or _running:
		return
	if _prompt != null:
		_prompt.call("ask")


func _on_answered(yes: bool) -> void:
	if not yes:
		_say("", "Fair enough. The way out is behind you.", "", "")
		_done = true
		return
	begin()


func begin() -> void:
	if _running or _done:
		return
	_running = true
	_done = true
	_enter(0)


func is_running() -> bool:
	return _running


func current_moment() -> int:
	return _moment


## LEFT MOUSE FORWARD, ARROWS EITHER WAY. The clock still runs underneath - stand still
## and it plays itself - but a presentation you cannot skip or go back in is a video, and
## the one thing an audience always wants is the slide they just missed.
func _unhandled_input(event: InputEvent) -> void:
	if not _running:
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
	_enter(clampi(_moment + step, 0, MOMENTS.size()))


## How long a moment runs. Most take the shared pace; the walking creature asks for
## half again, because it has three things to show in sequence and hurrying any one of
## them turns the slide into a flicker.
func _length(which: int) -> float:
	if which < 0 or which >= MOMENTS.size():
		return moment_seconds
	return moment_seconds * float(MOMENTS[which].get("pace", 1.0))


func _process(delta: float) -> void:
	if not _running or _stage == null:
		return
	_phase += delta
	if _moment >= 0 and _moment < MOMENTS.size() and _phase >= _length(_moment):
		_enter(_moment + 1)
	elif _moment == MOMENTS.size() and _phase >= closing_seconds:
		_running = false
		if _show != null and _show.has_method("hold_at"):
			_show.call("hold_at", -1)
		return
	if _moment >= 0 and _moment < MOMENTS.size():
		_later(_moment, _phase)
		_demonstrate(_moment, _phase)


## Figures that change part way through a moment, because the thing they measure does.
## Issued once each - `_told` counts how many of this moment's later beats have gone - so
## a step backward and forward through a slide cannot double-issue one.
func _later(which: int, t: float) -> void:
	var beats: Array = MOMENTS[which].get("later", [])
	while _told < beats.size() and t >= float(beats[_told]["at"]) * _length(which):
		_issue(beats[_told]["metrics"] as Array)
		_told += 1


func _enter(which: int) -> void:
	_moment = which
	_phase = 0.0
	_told = 0
	_show_piece(which)
	if _camera != null and _camera.has_method("shoot"):
		_camera.call("shoot",
			String(MOMENTS[which].get("shot", "house")) if which < MOMENTS.size() else "house",
			_length(which) if which < MOMENTS.size() else closing_seconds)
	# Square again, or the next slide inherits a rotation it never asked for.
	for piece in _pieces:
		piece.basis = Basis4D.from_zx(0.0)
	# In on the drum for the goat, which is small enough to stand beside. Out front for
	# everything else - the three copies fill the drum and the creature is very nearly as
	# long as the drum is wide.
	if _show != null and _show.has_method("hold_at"):
		_show.call("hold_at", 1 if which == 1 or which == 2 else 0)
	# Still for everything that is a comparison; turning for the goat, which is one object
	# and wants to be seen from more than one side.
	if _show != null and _show.has_method("set_spin"):
		_show.call("set_spin", which == 1)
	if which < MOMENTS.size():
		var m: Dictionary = MOMENTS[which]
		_say(String(m["title"]), _fill(String(m["body"])), _fill(String(m["figure"])),
			String(m["tier"]))
		_tint(m["tint"])
		_issue(m["metrics"] as Array)
	else:
		if _metrics != null and _metrics.has_method("clear"):
			_metrics.call("clear")
		_say("", "That is the case as it stands, gaps included. The rest is somebody else's decision, which is the correct place for it to be.", "", "")
		_tint(Color(0.10, 0.12, 0.20))


## The goat's figures are whatever the goat actually came out at. Writing them into the
## caption by hand meant they were wrong within an hour of the first time its proportions
## were adjusted - the shape changed, the tetrahedron count changed with it, and the slide
## went on claiming the old number. The room measures its own exhibit.
func _fill(text: String) -> String:
	var out: String = text
	if _goat != null:
		var balls: int = int(_goat.call("ball_count"))
		var tetra: int = int(_goat.call("tetra_count"))
		out = out.replace("{balls}", str(balls)).replace("{tetra}", str(tetra)) \
			.replace("{each}", str(tetra / maxi(balls, 1)))
	if _creature != null:
		out = out.replace("{legs}", str(int(_creature.call("leg_count")))) \
			.replace("{segments}", str(int(_creature.call("segment_count")))) \
			.replace("{handles}", str(int(_creature.call("ball_count")))) \
			.replace("{gaits}", str(int(_creature.call("gait_count")))) \
			.replace("{creature_tetra}", _grouped(int(_creature.call("tetra_count"))))
	return out


## Twenty thousand tetrahedra written as 20,160 rather than 20160. Five digits in a row is
## a serial number; the comma is what makes it a quantity.
func _grouped(value: int) -> String:
	var digits: String = str(value)
	var out: String = ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out


## Fills a moment's figures and puts them up. One path for the figures a moment opens with
## and the figures it changes to part way through, so the two cannot drift apart.
func _issue(metrics: Array) -> void:
	if _metrics == null or not _metrics.has_method("show_metrics"):
		return
	var filled: Array = []
	for metric in metrics:
		var copy: Dictionary = (metric as Dictionary).duplicate()
		copy["value"] = _fill(String(copy["value"]))
		filled.append(copy)
	_metrics.call("show_metrics", filled)


## Re-issues a moment's figures without changing anything else, for the one moment whose
## number is still moving while you look at it.
func _retell(which: int) -> void:
	if _metrics == null or not _metrics.has_method("show_metrics"):
		return
	var live: int = int(_goat.call("balls_shown")) if _goat != null else 0
	var filled: Array = []
	for metric in (MOMENTS[which]["metrics"] as Array):
		var copy: Dictionary = (metric as Dictionary).duplicate()
		copy["value"] = str(live)
		filled.append(copy)
	_metrics.call("show_metrics", filled, true)


## THE CONTROLS ARE ON SCREEN, because a presentation you can step through is only worth
## having if somebody knows they can. Part one does not draw this: it runs on a clock and
## the only input in it is walking about.
const NAV := "\u2190  \u2192   step through      \u00b7      click   forward"


func _say(title: String, body: String, figure: String, tier: String) -> void:
	if _caption != null and _caption.has_method("show_act"):
		_caption.call("show_act", title, body, figure, tier, NAV if tier != "" else "")


func _tint(to: Color) -> void:
	for panel in _panels:
		var material: TetraMaterial4D = panel.material_override as TetraMaterial4D
		if material != null:
			material.albedo_color = to


# ---------------------------------------------------------------- the exhibits

func _build() -> void:
	_pieces.append(_the_same_thing())
	_pieces.append(_the_goat())
	_pieces.append(_stop_conditions())
	_pieces.append(_the_creature())
	for piece in _pieces:
		piece.visible = false
## One at a time, and the rest are not merely hidden but moved out of the way, so a turn of
## the slice cannot reveal the last exhibit standing behind this one. Two moments stand on
## the SAME exhibit - the goat is placed in one and reshaped in the next - so the moment
## names its piece rather than the index being assumed to be it.
func _show_piece(which: int) -> void:
	var wanted: int = -1
	if which >= 0 and which < MOMENTS.size():
		wanted = int(MOMENTS[which].get("piece", which))
	for i in _pieces.size():
		var on: bool = i == wanted
		_pieces[i].visible = on
		_pieces[i].position = Vector4(0.0, 0.0 if on else -40.0, 0.0, 0.0)
	if _goat != null and _goat.has_method("set_markers_visible"):
		_goat.call("set_markers_visible", which == 1)
	if _goat != null:
		# Moment V wants the finished animal in its own colours; moment VI starts it from
		# nothing and plain, so the geometry is the thing being looked at.
		if which == 2:
			_goat.call("show_stage", 0)
		else:
			_goat.call("show_finished")
	# And the three copies back to their own depths, whichever way this slide was reached.
	for i in _copies.size():
		_copies[i].position.w = -DEPTHS[i]
	# Back to a dressed creature walking, whichever slide this is and whichever direction
	# it was arrived from. Stepping backward out of moment VIII half way through used to
	# leave a skinless animal cantering behind the next exhibit.
	if _creature != null:
		_creature.call("show_rig", false)
		_creature.call("set_gait", "walk")


## THREE PLINTHS, AND ONE OF THEM IS EMPTY.
##
## Built the way the first act was built, because that act worked: two plinths, one
## carrying something and one carrying a thing the renderer will never draw, and the
## ABSENCE is the exhibit. A bar chart would have said the same and been a bar chart.
##
## The developer plinth stacks up nine prototypes, one at a time, while you watch. The
## engine plinth holds three gauges that are open frames with nothing in them - the
## thresholds exist and the measurements do not. The player plinth holds nothing at all
## and nothing arrives on it, which is the whole slide.
## THE SAME OBJECT, STANDING AT THREE DEPTHS.
##
## THIS REPLACED TWO SLIDES AND IS BETTER THAN EITHER. One was three plinths with bricks
## stacked on one of them, the other was seven little figures in a row losing five little
## cards; both were bar charts built out of boxes, and a room whose whole argument is that
## you should look at the thing rather than read about it cannot open with two diagrams.
##
## ONE SOLID IS BUILT, AND THREE COPIES OF IT ARE STOOD AT DIFFERENT W. Every copy is the
## same parts in the same places - the only difference between them is where they sit
## along the axis you cannot see, so your slice cuts each in a different place and you get
## three solids that share no visible feature. Then they slide to w = 0 together and are
## revealed as identical, which is the whole 4D comprehension problem in one move and
## takes eight seconds.
##
## THE SHAPE IS DESIGNED TO CUT DIFFERENTLY, which is the only demanding part. A column
## that runs the full depth is in every slice and gives the eye something to hold on to;
## the arms and the cap sit at their own depths with a shallow reach through W, so each
## one belongs to exactly one of the three cross-sections.
func _the_same_thing() -> Node4D:
	var piece := Node4D.new()
	piece.name = "SameThing"
	_table.add_child(piece)
	_copies.clear()
	for i in DEPTHS.size():
		var copy := Node4D.new()
		copy.name = "Copy%d" % i
		piece.add_child(copy)
		# NEGATIVE, and that sign is the whole exhibit. A part built at local w = +1.45
		# only lands on the viewer's slice when its copy is standing at w = -1.45; the
		# first version offset them the other way, so every copy showed the one feature
		# that lives at the far end of W and the three came out nearly identical from the
		# start. It looked like a bug in the geometry and was a sign.
		copy.position = Vector4((float(i) - 1.0) * 2.35, 0.0, 0.0, -DEPTHS[i])
		_one_solid(copy)
		_copies.append(copy)
	return piece


## One object, built once and built three times over. Nothing here is per-copy: if two of
## these differed by so much as a colour the slide would be a lie, and an invisible one,
## because they are never seen at the same depth until the last four seconds.
##
## EACH FEATURE IS ITS OWN COLOUR, which is not decoration. The three cross-sections have
## to be told apart at a glance from the back of a house, and a pale slab with a pale slab
## on it reads as one shape however differently it is cut. The colour belongs to the PART,
## so all three copies still carry all four of them.
func _one_solid(into: Node4D) -> void:
	# The column runs the full depth, so it is in every slice there is. Without it the
	# three cross-sections share nothing at all and read as three objects somebody put on
	# a table rather than as one object cut three ways.
	_block(into, "Column", Vector4(0.0, 1.10, 0.0, 0.0),
		Vector3(0.46, 2.20, 0.46), Color(0.90, 0.86, 0.92), 7.0)
	# A low cross, at the depth you are standing on.
	for side in [-1.0, 1.0]:
		_block(into, "Arm%d" % int(side), Vector4(side * 0.66, 0.66, 0.0, 0.0),
			Vector3(1.18, 0.30, 0.30), Color(1.0, 0.55, 0.74), 0.90)
	# A ring of blades one step further along W, which that first slice has no trace of.
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		var blade := _block(into, "Blade%d" % i,
			Vector4(sin(a) * 0.74, 1.62, cos(a) * 0.74, DEPTHS[1]),
			Vector3(0.22, 0.58, 0.54), Color(1.0, 0.85, 0.42), 0.90)
		blade.basis = Basis4D.from_zx(a)
	# And a wide cap at the far depth, which neither of the others sees.
	_block(into, "Cap", Vector4(0.0, 2.42, 0.0, DEPTHS[2]),
		Vector3(1.60, 0.30, 1.60), Color(0.62, 0.78, 1.0), 0.90)
	_block(into, "Finial", Vector4(0.0, 2.84, 0.0, DEPTHS[2]),
		Vector3(0.34, 0.54, 0.34), Color(0.78, 0.88, 1.0), 0.90)


## THE WALKING CREATURE. Added last so the five exhibits that were here first keep the
## indices their moments already name - a moment says which piece it stands on, and
## renumbering the list to put this one in narrative order would have silently moved four
## other slides onto the wrong exhibit.
func _the_creature() -> Node4D:
	var piece := Node4D.new()
	piece.name = "CreatureStand"
	_table.add_child(piece)
	var beast := Node4D.new()
	# Not "Creature": the branch adopted UNDER it is called that, and two nodes of the
	# same name one inside the other made every path in the tests read twice.
	beast.name = "Walker"
	beast.set_script(CREATURE)
	piece.add_child(beast)
	_creature = beast
	return piece


func _the_goat() -> Node4D:
	var piece := Node4D.new()
	piece.name = "GoatStand"
	_table.add_child(piece)
	var goat := Node4D.new()
	goat.name = "Goat"
	goat.set_script(GOAT)
	piece.add_child(goat)
	goat.position = Vector4(0.0, 0.0, 0.0, 0.0)
	_goat = goat
	return piece


## SEVEN STONES, AND FOUR OF THEM ARE NOT HERE. The three readable this October stand at
## w = 0 where you are. The four that cannot be evaluated until the end of 2027 sit at a W
## offset, so they are genuinely absent from your slice until you turn it — which is the
## same sentence as "not yet measurable", written in geometry instead of in a caption.
func _stop_conditions() -> Node4D:
	var piece := Node4D.new()
	piece.name = "Stones"
	_table.add_child(piece)
	_stones.clear()
	var now := [
		["Bespoke", 0.0],
		["Engine", 0.0],
		["Roadmap", 0.0],
	]
	var later := [
		["NoUnderstanding", 3.4],
		["NoAppeal", -3.4],
		["NoTurnout", 3.4],
		["NoPartner", -3.4],
	]
	var all: Array = now + later
	for i in all.size():
		var a: float = lerpf(-1.15, 1.15, float(i) / float(all.size() - 1))
		var readable: bool = i < now.size()
		var stone := Node4D.new()
		stone.name = String(all[i][0])
		piece.add_child(stone)
		stone.position = Vector4(sin(a) * 2.4, 0.0, cos(a) * 2.4 - 1.2, float(all[i][1]))
		stone.basis = Basis4D.from_zx(a)
		var shade: Color = Color(0.72, 0.30, 0.24) if readable \
			else Color(0.30, 0.30, 0.34)
		_block(stone, "Stone", Vector4(0.0, 0.70, 0.0, 0.0),
			Vector3(0.44, 1.40, 0.30), shade, 0.7)
		_block(stone, "Cap", Vector4(0.0, 1.44, 0.0, 0.0),
			Vector3(0.50, 0.10, 0.36),
			shade.lerp(Color(1.0, 0.85, 0.42), 0.5 if readable else 0.0), 0.7)
		_stones.append(stone)
	return piece


func _demonstrate(which: int, t: float) -> void:
	# Every fraction below is a fraction of THIS moment's length, which is not the shared
	# pace for all of them.
	var span: float = _length(which)
	match which:
		0:
			# THREE SOLIDS, AND THEN ONE. They stand at their own depths for the first
			# half, which is long enough to be sure they have nothing in common. Then the
			# two that are further along W slide back to where you are standing, and every
			# feature that was only in one of them arrives in all three at once.
			#
			# THEY SLIDE, THEY DO NOT TURN. A rotation through W changes the cross-section
			# in a way that depends on where each part sits, so the three would resolve at
			# different rates and the moment they become identical would be a smear. A
			# translation moves the whole object through your slice at one speed, which is
			# the same sentence said cleanly.
			# THREE BEATS. Apart, together, and then together THROUGH the whole depth.
			#
			# It used to stop at the second one, which proved the point and then threw
			# away the better half of it: once the three are on one slice they all show
			# the near cross-section, which is the plainest of the three, so the reveal
			# was three identical dull things. Sweeping the shared depth afterwards makes
			# all three become the ring and then the cap IN LOCKSTEP - which says the same
			# sentence a second time and much louder, because now you are watching one
			# object contain all of it rather than being told that it does.
			var home: float = clampf((t - span * 0.42) / maxf(span * 0.16, 0.01), 0.0, 1.0)
			home = home * home * (3.0 - 2.0 * home)
			var sweep: float = clampf((t - span * 0.60) / maxf(span * 0.36, 0.01), 0.0, 1.0)
			sweep = sweep * sweep * (3.0 - 2.0 * sweep)
			for i in _copies.size():
				_copies[i].position.w = lerpf(-DEPTHS[i],
					-DEPTHS[DEPTHS.size() - 1] * sweep, home)
		1:
			# The handles first, then the finished animal turning through W.
			#
			# THE STAND TURNS, NOT THE GOAT. The goat's own basis carries the uniform scale
			# that fits it to this stage, and writing a rotation onto it threw that away -
			# the animal jumped to its authored size half way through the slide.
			if _goat == null:
				return
			_goat.call("set_markers_visible", t < span * 0.34)
			if t > span * 0.45:
				var sweep: float = sin((t - span * 0.45) * 0.55) * 0.95
				_pieces[1].basis = Basis4D.from_xw(sweep) * Basis4D.from_zw(sweep * 0.4)
		2:
			# THE BUILD, PLAYED BACK. Every stage was lofted during the arrival, so this is
			# a sequence of node swaps and costs nothing - which is the only reason it can
			# happen while somebody is watching. It assembles over the first two thirds and
			# reshapes over the last.
			var count: int = int(_goat.call("stage_count"))
			var step: int = mini(count - 1, int(floor(t / span * float(count))))
			if step != int(_goat.call("shown_stage")):
				_goat.call("show_stage", step)
				# The handle count climbs with it, so the figure beside the animal is
				# counting the thing you are watching arrive.
				_retell(2)
			_goat.call("set_markers_visible", step < int(_goat.call("first_morph_stage")))
		3:
			# THREE BEATS, AND THE CAMERA DOES NOT MOVE. A walk cycle is read side-on -
			# turning the drum under it would hide the one thing the slide is about - so
			# everything that changes here is the creature itself.
			#
			#   walk, dressed        the animal, doing the ordinary thing
			#   skin off             the handles and the eight foot targets, still walking
			#   dressed again, trot  then canter: same rig, no new data, a different gait
			#
			# set_gait is called every frame and is a no-op when the gait is already the
			# one asked for, so scrubbing backward and forward lands in the right one.
			if _creature == null:
				return
			_creature.call("show_rig", t > span * 0.31 and t < span * 0.60)
			if t > span * 0.84:
				_creature.call("set_gait", "canter_right")
			elif t > span * 0.62:
				_creature.call("set_gait", "trot")
			else:
				_creature.call("set_gait", "walk")
		4:
			# Nothing moves. Four of the seven are simply not on this slice, and the way to
			# make that land is to let the player notice the gap rather than animate it.
			pass


func _block(parent: Node, part: String, at: Vector4, size: Vector3, colour: Color,
		w: float) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	# A real extent through W, or it vanishes the moment the player turns their slice.
	mesh.size = Vector4(size.x, size.y, size.z, w)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node
