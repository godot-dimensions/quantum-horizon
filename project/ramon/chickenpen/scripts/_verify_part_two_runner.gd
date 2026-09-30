extends SceneTree

## One presentation: does slide V hand straight on to VI with nobody asked, do all eight
## slides run in order and carry the numbers I to VIII, and are the claims made of the
## things they say they are made of?
##
## ONE PRESENTATION SINCE 30 SEPT. This used to wait for a yes to "there's a second part,
## want it?" and then check five moments. Ramon cut the question and four of the eight
## slides; what is checked now is that the seam is gone - no prompt, no pause, no closing
## line between slide I and slide II - and that the slides that were cut are really gone,
## exhibits included, rather than merely skipped.
##
## The exhibit checks matter most. Every slide asserts something about the programme, and
## the exhibit is supposed to BE the assertion rather than illustrate it - the goat is
## really lofted, it is really built in front of you, the creature really walks. A test
## that only checked the captions would pass on a set of props that said the opposite of
## the words.

var _root: Node
var _f := 0
var _fails: Array = []
var _show: Node
var _two: Node
var _seen: Array = []
var _part_two_before_slide_one := false
var _slide_one_seen := false
var _handed_over_at_act := -99
var _prev_act := -99
var _figure_was_up := false
var _built_from: int = 0
var _reshaped: bool = false
var _gaits_seen: Array = []
var _bared: bool = false
var _dressed_again: bool = false
var _foot_rest: Vector4 = Vector4.ZERO
var _foot_moved: float = 0.0
var _titles: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _two == null:
		_two = _root.get_node_or_null("PartTwo")
		_show = _root.get_node_or_null("Show")
		if _two == null or _show == null:
			print("   FAIL there is no show or no part two")
			quit(1)
			return true
		_show.set("opening_seconds", 1.0)
		_show.set("act_seconds", 0.5)
		_show.set("closing_seconds", 0.3)
		# He holds his mark until somebody sits down, and nobody sits down in this test -
		# the chair has a runner of its own.
		_show.set("waits_for_seat", 0.0)
		_two.set("moment_seconds", 0.5)
		_two.set("closing_seconds", 0.3)
		return false

	var act: int = int(_show.call("current_act"))
	var running: bool = bool(_two.call("is_running"))
	if act >= 0 and act < 5:
		_slide_one_seen = true
		if running:
			_part_two_before_slide_one = true
	# The first frame part two has the floor: which act was part one on the frame BEFORE?
	# Not this frame's - handing over moves part one past its last act in the same call.
	if running and _handed_over_at_act == -99:
		_handed_over_at_act = _prev_act
	_prev_act = act

	var moment: int = int(_two.call("current_moment"))
	if running and (_seen.is_empty() or _seen[-1] != moment):
		_seen.append(moment)
	# Sampled WHILE a moment is running. The closing beat takes the figure down on purpose,
	# so checking at the end would be checking the one frame it is meant to be gone.
	var hanging: Node = _root.get_node_or_null("UI/Metrics")
	var count: int = _moments().size()
	if hanging != null and moment >= 0 and moment < count:
		if int(hanging.call("count")) > 0:
			_figure_was_up = true

	var table: Node4D = _root.get_node("Stage/Turntable") as Node4D

	# II and III: watch the build happen rather than inspecting it afterwards. By the end
	# it looks identical to the slide before it, which is the point of the two being
	# adjacent.
	var animal: Node4D = table.get_node_or_null("GoatStand/Goat") as Node4D
	if animal != null and moment == 1:
		var at: int = int(animal.call("shown_stage"))
		var here: int = int(animal.call("balls_shown"))
		if _built_from == 0 and here > 0:
			_built_from = here
		if at >= int(animal.call("first_morph_stage")):
			_reshaped = true

	# IV, sampled live for the same reason: by the end the creature is dressed and
	# walking again, which is exactly how it started.
	var beast: Node4D = table.get_node_or_null("CreatureStand/Walker") as Node4D
	if beast != null and moment == 2:
		var gait: String = String(beast.call("gait_name"))
		if gait != "" and not _gaits_seen.has(gait):
			_gaits_seen.append(gait)
		if bool(beast.call("showing_rig")):
			_bared = true
		elif _bared:
			_dressed_again = true
		var foot: Node4D = beast.get_node_or_null("Creature/ForeLAFootTarget") as Node4D
		if foot != null:
			if _foot_rest == Vector4.ZERO:
				_foot_rest = foot.position
			_foot_moved = maxf(_foot_moved, (foot.position - _foot_rest).length())

	# The caption as the audience reads it, slide by slide.
	var caption: Node = _root.get_node_or_null("UI/Caption")
	if caption != null:
		var title: String = String(caption.get("_title"))
		if title != "" and (_titles.is_empty() or _titles[-1] != title):
			_titles.append(title)

	if moment < count:
		if _f > 12000:
			print("   FAIL never reached the end, got to act %d, moment %d" % [act, moment])
			quit(1)
			return true
		return false

	print("\n--- one presentation ---")
	_check("nobody is asked anything", _root.get_node_or_null("UI/Prompt") == null
			and not _two.has_method("offer"),
		"no prompt in the room and no offer on part two")
	_check("slides I to V play first", _slide_one_seen and not _part_two_before_slide_one,
		"part two was not running while part one's slides were up")
	_check("and V hands straight on to VI", _handed_over_at_act == 4,
		"part two took the floor off act %d, with no closing beat between" % _handed_over_at_act)
	_check("and all three of part two's ran, in order", _seen == [0, 1, 2, count],
		"%s" % [_seen])
	var numerals: Array = ["I. ", "II. ", "III. ", "IV. ", "V. ", "VI. ", "VII. ", "VIII. "]
	var in_order: bool = _titles.size() == numerals.size()
	for i in mini(_titles.size(), numerals.size()):
		in_order = in_order and String(_titles[i]).begins_with(numerals[i])
	_check("numbered I to VIII, in the order they are shown", in_order, "%s" % [_titles])

	print("\n--- the cut slides are gone, exhibits and all ---")
	var gone: Array = []
	for name in ["ActOne", "ActTwo", "SameThing", "Stones"]:
		if table.find_child(name, true, false) != null:
			gone.append(name)
	_check("nothing of I, II, IV or VIII is built", gone.is_empty(),
		"left over: %s" % [gone] if not gone.is_empty() else "no invisible box, hull, copies or stones")
	var words: String = MOMENTS_OF(_two) + ACTS_OF(_show)
	_check("and their titles are not in the talk", not words.contains("SAME OBJECT")
			and not words.contains("WHAT WOULD STOP THIS") and not words.contains("ONLY BOXES")
			and not words.contains("DRAWS ONLY FOUR"), "none of the four titles survives")

	print("\n--- the exhibits say what the captions say ---")
	# II: a real loft rig, not a goat-shaped import.
	var goat: Node4D = table.get_node_or_null("GoatStand/Goat") as Node4D
	_check("the goat is the authored one, really lofted",
		goat != null and int(goat.call("ball_count")) >= 20
			and int(goat.call("tetra_count")) > 5000,
		"%d handles, %d tetrahedra" % [int(goat.call("ball_count")) if goat != null else -1,
			int(goat.call("tetra_count")) if goat != null else -1])

	# III: the animal was built in front of you rather than switched on.
	_check("the animal was assembled, not switched on",
		_built_from > 0 and goat != null and _built_from < int(goat.call("ball_count")),
		"started at %d handles, finished at %d"
			% [_built_from, int(goat.call("ball_count")) if goat != null else -1])
	_check("and then reshaped without being remodelled",
		_reshaped, "the last stages move handles rather than rebuild the animal")

	# IV: Trym's creature, adopted whole, walking.
	_check("the creature came with its whole solver stack",
		beast != null and _solvers(beast) == 6,
		"%d of 6 solvers adopted alongside it" % (_solvers(beast) if beast != null else -1))
	_check("and it is the eight-legged one, really lofted",
		beast != null and int(beast.call("leg_count")) == 8
			and int(beast.call("tetra_count")) > 10000,
		"%d legs, %d segments, %d tetrahedra"
			% [int(beast.call("leg_count")) if beast != null else -1,
				int(beast.call("segment_count")) if beast != null else -1,
				int(beast.call("tetra_count")) if beast != null else -1])
	_check("and it actually walked", _foot_moved > 0.05,
		"a fore foot travelled %.3f from where it started" % _foot_moved)
	_check("the skin came off and went back on", _bared and _dressed_again,
		"handles shown, then the surface restored")
	_check("and it changed gait without new data", _gaits_seen.size() >= 3,
		"%s" % [_gaits_seen])

	print("\n--- and the room says how to drive it ---")
	_check("every slide here set figures beside its subject", _figure_was_up,
		"small type, anchored to the exhibit, not a scoreboard over it")

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true


func _moments() -> Array:
	return _two.get_script().get_script_constant_map()["MOMENTS"]


## Everything the moment table says, as one string, so a check can ask whether a title
## survived a deletion anywhere in it.
func MOMENTS_OF(two: Node) -> String:
	var all: String = ""
	for moment in two.get_script().get_script_constant_map()["MOMENTS"]:
		all += String(moment.get("title", "")) + String(moment.get("body", "")) \
			+ String(moment.get("figure", ""))
	return all


func ACTS_OF(show: Node) -> String:
	var all: String = ""
	for act in show.get_script().get_script_constant_map()["ACTS"]:
		all += String(act.get("title", "")) + String(act.get("body", ""))
	return all


## The six solver nodes, which live beside the creature rather than under it because every
## one of them resolves NodePath("../Creature").
func _solvers(beast: Node4D) -> int:
	if beast == null:
		return -1
	var count := 0
	for name in ["IKGaitDriver", "FootGroundSolver", "TailSway", "SpineNeckSolver",
			"IdleLayer", "HeadAttention"]:
		var solver: Node = beast.get_node_or_null(String(name))
		if solver != null and solver.is_physics_processing():
			count += 1
	return count
