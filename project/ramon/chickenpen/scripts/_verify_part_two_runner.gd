extends SceneTree

## Part two: does it stay shut until asked, does it run all seven, and are the claims made
## of the things they say they are made of?
##
## The last one matters most. Every moment here asserts something about the programme, and
## the exhibit is supposed to BE the assertion rather than illustrate it - the empty column
## is empty, the goat is really lofted, the four unmeasurable stop conditions are really
## off your slice. A test that only checked the captions would pass on a set of props that
## said the opposite of the words.

var _root: Node
var _f := 0
var _fails: Array = []
var _two: Node
var _seen: Array = []
var _asked_before_answer := false
var _figure_was_up := false
var _figures_seen: Array = []
var _built_from: int = 0
var _reshaped: bool = false
var _gaits_seen: Array = []
var _bared: bool = false
var _dressed_again: bool = false
var _foot_rest: Vector4 = Vector4.ZERO
var _foot_moved: float = 0.0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _two == null:
		_two = _root.get_node_or_null("PartTwo")
		if _two == null:
			print("   FAIL there is no part two"); quit(1); return true
		# Straight to the end of part one, so the offer happens without sitting through it.
		var show: Node = _root.get_node("Show")
		show.set("opening_seconds", 1.0)
		show.set("act_seconds", 0.5)
		show.set("closing_seconds", 0.3)
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
				print("   FAIL part one never offered part two"); quit(1); return true
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
	if hanging != null and moment >= 0 and moment < 7:
		if int(hanging.call("count")) > 0:
			_figure_was_up = true
	# Watch the build moment happen rather than inspecting it afterwards: by the end it
	# looks identical to the moment before it, which is the point of the two being
	# adjacent and the reason this has to be sampled live.
	var animal: Node4D = _root.get_node_or_null(
		"Stage/Turntable/GoatStand/Goat") as Node4D
	if animal != null and moment == 3:
		var at: int = int(animal.call("shown_stage"))
		var here: int = int(animal.call("balls_shown"))
		if _built_from == 0 and here > 0:
			_built_from = here
		if at >= int(animal.call("first_morph_stage")):
			_reshaped = true

	# MOMENT VIII, SAMPLED LIVE for the same reason moment VII is: by the end the creature
	# is dressed and walking again, which is exactly how it started, so an inspection
	# afterwards would pass on a slide where nothing ever happened.
	var beast: Node4D = _root.get_node_or_null(
		"Stage/Turntable/CreatureStand/Walker") as Node4D
	if beast != null and moment == 4:
		var gait: String = String(beast.call("gait_name"))
		if gait != "" and not _gaits_seen.has(gait):
			_gaits_seen.append(gait)
		if bool(beast.call("showing_rig")):
			_bared = true
		elif _bared:
			_dressed_again = true
		var foot: Node4D = beast.get_node_or_null(
			"Creature/ForeLAFootTarget") as Node4D
		if foot != null:
			if _foot_rest == Vector4.ZERO:
				_foot_rest = foot.position
			_foot_moved = maxf(_foot_moved, (foot.position - _foot_rest).length())

	if moment < 7:
		if _f > 12000:
			print("   FAIL never reached the end, got to %d" % moment); quit(1); return true
		return false

	var stage: Node4D = _root.get_node("Stage")
	var table: Node4D = stage.get_node("Turntable")
	print("\n--- the seven ---")
	_check("yes started it", bool(_seen.has(0)), "answering the prompt ran moment IV")
	_check("and all seven ran, in order",
		_seen.has(0) and _seen.has(1) and _seen.has(2) and _seen.has(3)
			and _seen.has(4) and _seen.has(5) and _seen.has(6),
		"%s" % [_seen])

	print("\n--- the exhibits say what the captions say ---")
	# IV: the middle plinth carries nothing, and the absence IS the exhibit - the same
	# move the first act makes with a box the renderer will never draw.
	var player: Node4D = table.get_node_or_null("Pillars/Player") as Node4D
	var developer: Node4D = table.get_node_or_null("Pillars/Developer") as Node4D
	_check("the player plinth is bare", player != null and _on_top(player) == 0,
		"%d things standing on it" % (_on_top(player) if player != null else -1))
	_check("and nine prototypes stand on the developer one",
		developer != null and _on_top(developer) == 9,
		"%d prototypes" % (_on_top(developer) if developer != null else -1))
	_check("with three hollow gauges on the engine one",
		_notches(table.get_node_or_null("Pillars/Engine")) == 3,
		"%d thresholds, every one an empty frame"
			% _notches(table.get_node_or_null("Pillars/Engine")))

	# V: seven of them, because the sample was seven.
	var seven: Node4D = table.get_node_or_null("Seven") as Node4D
	_check("there are exactly seven playtesters", seven != null
		and seven.get_child_count() == 7, "%d figures" % (seven.get_child_count()
			if seven != null else -1))
	# And all seven are still standing at the end. The sample never shrank; the
	# evidence did, and five written answers are what the form bug actually took.
	var standing := 0
	var answered := 0
	if seven != null:
		for who in seven.get_children():
			if (who as Node4D).visible:
				standing += 1
			var card := (who as Node4D).get_node_or_null("Answer") as MeshInstance4D
			if card != null and card.visible:
				answered += 1
	_check("all seven are still standing", standing == 7,
		"%d of them, with %d written answers left intact" % [standing, answered])
	_check("but five of the answers were taken", answered == 2,
		"%d survived the form bug, which is what the caveat says" % answered)

	# VI: a real loft rig, not a goat-shaped import.
	var goat: Node4D = table.get_node_or_null("GoatStand/Goat") as Node4D
	_check("the goat is the authored one, really lofted",
		goat != null and int(goat.call("ball_count")) >= 20
			and int(goat.call("tetra_count")) > 5000,
		"%d handles, %d tetrahedra" % [int(goat.call("ball_count")) if goat != null else -1,
			int(goat.call("tetra_count")) if goat != null else -1])

	# VII: the animal was built in front of you rather than switched on. The stage that
	# was showing at the start of that moment has to hold fewer balls than the finished
	# one, or nothing was assembled and the moment is a still life with a caption.
	_check("the animal was assembled, not switched on",
		_built_from > 0 and _built_from < int(goat.call("ball_count")),
		"started at %d handles, finished at %d"
			% [_built_from, int(goat.call("ball_count"))])
	_check("and then reshaped without being remodelled",
		_reshaped, "the last stages move handles rather than rebuild the animal")

	# VIII: it has to be TRYM'S creature, adopted whole - the six solvers with it, or the
	# claim about a stack of solvers is a claim about code that is not in the room.
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
	# Walking, not standing there. The gait writes the foot targets, so a target that
	# never left its rest position means the whole stack was switched off by a bad path.
	_check("and it actually walked", _foot_moved > 0.05,
		"a fore foot travelled %.3f from where it started" % _foot_moved)
	# The x-ray: skin off and back on, both observed while the moment was running.
	_check("the skin came off and went back on", _bared and _dressed_again,
		"handles shown, then the surface restored")
	# Three gaits out of one rig. The claim is that changing gait needs no new data, so
	# the test is that the driver really was in more than one of them.
	_check("and it changed gait without new data", _gaits_seen.size() >= 3,
		"%s" % [_gaits_seen])
	# On the deck, not through it or hovering over it.
	var lowest: float = _lowest(beast)
	_check("it stands on the drum", absf(lowest) < 0.35,
		"lowest point of the creature sits %.2f from the deck" % lowest)

	# IX: four of the seven are genuinely not on this slice.
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

	# X: three outcomes, drawn the same.
	var date: Node4D = table.get_node_or_null("TheDate") as Node4D
	# The floating figure is an object in the room, not an overlay: it has to be built
	# out of real geometry or it would sit outside the rules the room is about.
	var numeral: Node = _root.get_node_or_null("UI/Metrics")
	_check("every moment set figures beside its subject", _figure_was_up,
		"small type, anchored to the exhibit, not a scoreboard over it")
	_check("three outcomes, none of them favoured",
		date != null and date.get_child_count() == 3,
		"%d doorways" % (date.get_child_count() if date != null else -1))
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true


## What is standing ON a plinth, as opposed to being the plinth.
func _on_top(plinth: Node4D) -> int:
	if plinth == null:
		return -1
	var count := 0
	for child in plinth.get_children():
		if String(child.name).begins_with("Prototype"):
			count += 1
	return count


func _notches(column: Node) -> int:
	if column == null:
		return -1
	var count := 0
	for child in column.get_children():
		if String(child.name).begins_with("Threshold"):
			count += 1
	return count


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


## The bottom of the creature in the turntable's own frame, measured off the control
## balls, which are where the surface actually reaches.
func _lowest(beast: Node4D) -> float:
	if beast == null:
		return INF
	var low: float = INF
	var stack: Array = [beast]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_method("get_loft_section"):
			low = minf(low, (node as Node4D).global_position.y
				- float(node.get("radius")))
		for child in node.get_children():
			stack.append(child)
	return low - beast.global_position.y
