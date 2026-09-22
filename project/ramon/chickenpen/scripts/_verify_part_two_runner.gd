extends SceneTree

## Part two: does it stay shut until asked, does it run all five, and are the claims made
## of the things they say they are made of?
##
## The last one matters most. Every moment here asserts something about the programme, and
## the exhibit is supposed to BE the assertion rather than illustrate it - the three solids
## really are one object, the goat is really lofted, the creature really walks, and the
## four unmeasurable stop conditions are really off your slice. A test that only checked
## the captions would pass on a set of props that said the opposite of the words.
##
## THE TWO SLIDES THIS USED TO CHECK ARE GONE. Three plinths with bricks on one, and seven
## little figures losing little cards, were bar charts built out of boxes; a room whose
## whole argument is that you should look at the thing rather than read about it cannot
## open with two diagrams. The playtest claim they carried now stands on the exhibit in
## moment IV, which does the comprehension problem to the person watching it.

var _root: Node
var _f := 0
var _fails: Array = []
var _two: Node
var _seen: Array = []
var _asked_before_answer := false
var _figure_was_up := false
var _built_from: int = 0
var _reshaped: bool = false
var _apart: float = 0.0
var _together: float = INF
var _gaits_seen: Array = []
var _bared: bool = false
var _dressed_again: bool = false
var _foot_rest: Vector4 = Vector4.ZERO
var _foot_moved: float = 0.0


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
		if _two == null:
			print("   FAIL there is no part two")
			quit(1)
			return true
		# Straight to the end of part one, so the offer happens without sitting through it.
		var show: Node = _root.get_node("Show")
		show.set("opening_seconds", 1.0)
		show.set("act_seconds", 0.5)
		show.set("closing_seconds", 0.3)
		# He holds his mark until somebody sits down, and nobody sits down in this test -
		# the chair has a runner of its own.
		show.set("waits_for_seat", 0.0)
		_two.set("moment_seconds", 0.5)
		_two.set("closing_seconds", 0.3)
		return false

	var prompt: Node = _root.get_node("UI/Prompt")
	if bool(prompt.call("is_asking")):
		_asked_before_answer = true

	# Wait for part one to finish and ask, then answer yes the way a keypress would.
	if not bool(_two.call("is_running")) and _seen.is_empty():
		if not _asked_before_answer:
			if _f > 6000:
				print("   FAIL part one never offered part two")
				quit(1)
				return true
			return false
		print("\n--- the ask ---")
		_check("it stays shut until it is asked for",
			int(_two.call("current_moment")) == -1 and not bool(_two.call("is_running")),
			"no moment has run")
		_check("and part one does the asking", _asked_before_answer,
			"the prompt is up at the end of the third finding")
		var key := InputEventKey.new()
		key.keycode = int(prompt.get("yes_key"))
		key.pressed = true
		Input.parse_input_event(key)
		_seen.append(-2)
		return false

	var moment: int = int(_two.call("current_moment"))
	if _seen.is_empty() or _seen[-1] != moment:
		_seen.append(moment)
	# Sampled WHILE a moment is running. The closing beat takes the figure down on purpose,
	# so checking at the end would be checking the one frame it is meant to be gone.
	var hanging: Node = _root.get_node_or_null("UI/Metrics")
	if hanging != null and moment >= 0 and moment < 5:
		if int(hanging.call("count")) > 0:
			_figure_was_up = true

	var table: Node4D = _root.get_node("Stage/Turntable") as Node4D

	# IV, SAMPLED LIVE. The three copies start at their own depths and arrive on one
	# slice; by the end they are together, and by the end of the NEXT moment they have
	# been put back - so neither state can be checked afterwards.
	var same: Node4D = table.get_node_or_null("SameThing") as Node4D
	if same != null and moment == 0:
		var spread: float = _spread(same)
		_apart = maxf(_apart, spread)
		_together = minf(_together, spread)

	# V and VI: watch the build happen rather than inspecting it afterwards. By the end it
	# looks identical to the moment before it, which is the point of the two being adjacent.
	var animal: Node4D = table.get_node_or_null("GoatStand/Goat") as Node4D
	if animal != null and moment == 2:
		var at: int = int(animal.call("shown_stage"))
		var here: int = int(animal.call("balls_shown"))
		if _built_from == 0 and here > 0:
			_built_from = here
		if at >= int(animal.call("first_morph_stage")):
			_reshaped = true

	# VII, sampled live for the same reason: by the end the creature is dressed and
	# walking again, which is exactly how it started.
	var beast: Node4D = table.get_node_or_null("CreatureStand/Walker") as Node4D
	if beast != null and moment == 3:
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

	if moment < 5:
		if _f > 12000:
			print("   FAIL never reached the end, got to %d" % moment)
			quit(1)
			return true
		return false

	print("\n--- the five ---")
	_check("yes started it", bool(_seen.has(0)), "answering the prompt ran moment IV")
	_check("and all five ran, in order",
		_seen.has(0) and _seen.has(1) and _seen.has(2) and _seen.has(3) and _seen.has(4),
		"%s" % [_seen])

	print("\n--- the exhibits say what the captions say ---")
	# IV: the three really are one object. Same parts, same names, same places, same
	# sizes - if any two of them differed by so much as a box the slide would be a lie,
	# and it would be an invisible one because they are never seen side by side at the
	# same depth until the last four seconds.
	var same_now: Node4D = table.get_node_or_null("SameThing") as Node4D
	_check("there are three of them", same_now != null and same_now.get_child_count() == 3,
		"%d copies" % (same_now.get_child_count() if same_now != null else -1))
	_check("and they are genuinely the same object", _identical(same_now),
		"every part matched by name, place and size across all three")
	# And they really were apart, and really did come together.
	_check("they start on three different slices", _apart > 2.0,
		"%.2f between the nearest and furthest copy" % _apart)
	_check("and end on one", _together < 0.05,
		"%.3f apart once they have arrived" % _together)

	# V: a real loft rig, not a goat-shaped import.
	var goat: Node4D = table.get_node_or_null("GoatStand/Goat") as Node4D
	_check("the goat is the authored one, really lofted",
		goat != null and int(goat.call("ball_count")) >= 20
			and int(goat.call("tetra_count")) > 5000,
		"%d handles, %d tetrahedra" % [int(goat.call("ball_count")) if goat != null else -1,
			int(goat.call("tetra_count")) if goat != null else -1])

	# VI: the animal was built in front of you rather than switched on.
	_check("the animal was assembled, not switched on",
		_built_from > 0 and _built_from < int(goat.call("ball_count")),
		"started at %d handles, finished at %d"
			% [_built_from, int(goat.call("ball_count"))])
	_check("and then reshaped without being remodelled",
		_reshaped, "the last stages move handles rather than rebuild the animal")

	# VII: Trym's creature, adopted whole, walking.
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

	# VIII: four of the seven are genuinely not on this slice.
	var stones: Node4D = table.get_node_or_null("Stones") as Node4D
	var here := 0
	var elsewhere := 0
	if stones != null:
		for child in stones.get_children():
			if absf((child as Node4D).position.w) < 0.01:
				here += 1
			else:
				elsewhere += 1
	_check("three stop conditions are readable here", here == 3, "%d at w = 0" % here)
	_check("and four are genuinely off your slice", elsewhere == 4,
		"%d sitting at a W offset, not merely greyed out" % elsewhere)

	print("\n--- and the room says how to drive it ---")
	_check("every moment set figures beside its subject", _figure_was_up,
		"small type, anchored to the exhibit, not a scoreboard over it")
	# The gate countdown is gone: they are reading this AT the gate, and a room telling
	# them how many days are left would be telling them the date they arrived on.
	_check("nothing counts down to the gate",
		table.get_node_or_null("TheDate") == null
			and not String(MOMENTS_OF(_two)).contains("{days}"),
		"no doorways, no days-remaining figure")

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true


## Everything the moment table says, as one string, so a check can ask whether a
## placeholder survived a deletion anywhere in it.
func MOMENTS_OF(two: Node) -> String:
	var all: String = ""
	for moment in two.get_script().get_script_constant_map()["MOMENTS"]:
		all += String(moment.get("title", "")) + String(moment.get("body", "")) \
			+ String(moment.get("figure", ""))
	return all


## How far apart the three copies are along W.
func _spread(same: Node4D) -> float:
	var low: float = INF
	var high: float = -INF
	for copy in same.get_children():
		low = minf(low, (copy as Node4D).position.w)
		high = maxf(high, (copy as Node4D).position.w)
	return high - low if is_finite(low) else 0.0


## Whether all three copies are the same object: same parts, in the same places, at the
## same sizes. Compared against the first one, part by part, by name.
func _identical(same: Node4D) -> bool:
	if same == null or same.get_child_count() < 3:
		return false
	var first: Node4D = same.get_child(0) as Node4D
	for i in range(1, same.get_child_count()):
		var other: Node4D = same.get_child(i) as Node4D
		if other.get_child_count() != first.get_child_count():
			return false
		for part in first.get_children():
			var twin: Node = other.get_node_or_null(String(part.name))
			if twin == null:
				return false
			if not (part as Node4D).position.is_equal_approx((twin as Node4D).position):
				return false
			var a := (part as MeshInstance4D).mesh as BoxTetraMesh4D
			var b := (twin as MeshInstance4D).mesh as BoxTetraMesh4D
			if a == null or b == null or not a.size.is_equal_approx(b.size):
				return false
	return true


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
