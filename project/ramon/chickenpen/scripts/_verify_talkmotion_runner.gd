extends SceneTree

## Do people move while they talk, and does the movement avoid looking looped?
##
## THREE THINGS, and the third is the one worth having:
##
##   1. STILL WHEN SILENT. A figure that fidgets with no dialogue box open is worse than
##      one that stands still, because it reads as a bug rather than as a person.
##   2. MOVING WHEN TALKING. Head and arms, measured as an angle swept rather than as a
##      property being written - a pose assigned every frame to the same value is not
##      movement.
##   3. NOT REPETITIVE. Sampled over a long run, the motion is sliced into windows and
##      the windows compared. If the idle were two waves at 2 and 4 seconds, window N and
##      window N+1 would match closely and this would catch it. Three incommensurable
##      periods plus gestures should keep every window different.

var _root: Node
var _f := 0
var _fails: Array = []
var _motion: Node
var _talk: Node
var _figure: Node4D
var _stage := 0
var _quiet: Array = []
var _trace: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: _fails.append(label)


## The head's forward direction, as a plain vector we can measure the sweep of.
func _aim() -> Vector4:
	# LOCAL, not global. Mithra is a searcher and walks about, and her body turning would
	# show up here as her head moving - which made the silent baseline fail against a
	# figure that was doing nothing but walking.
	var head: Node4D = _figure.get("head") as Node4D
	return Vector4.ZERO if head == null else head.basis * Vector4(0.0, 0.0, 1.0, 0.0)


func _arm_angle() -> float:
	var s: Node4D = _figure.get("shoulder_left") as Node4D
	return 0.0 if s == null else (s.basis * Vector4(0.0, -1.0, 0.0, 0.0)).z


func _spread(rows: Array) -> float:
	var lo := 99.0
	var hi := -99.0
	for v in rows:
		lo = minf(lo, v); hi = maxf(hi, v)
	return hi - lo


func _process(_d) -> bool:
	_f += 1
	if _f < 5: return false
	if _motion == null:
		_motion = _root.get_node_or_null("Systems/TalkMotion")
		_talk = _root.get_node_or_null("Systems/MithraTalk")
		_figure = _root.get_node_or_null("Mithra/Avatar") as Node4D
		if _motion == null or _talk == null or _figure == null:
			_check("the pieces are in the scene", false, "TalkMotion / MithraTalk / Mithra/Avatar")
			_finish(); return true
		print("\n--- standing quietly ---")
		return false
	# 40 frames of silence first.
	if _stage == 0:
		_quiet.append(_aim().y)
		if _quiet.size() < 40: return false
		_check("still while nobody is talking", _spread(_quiet) < 0.01,
			"head swept %.4f over %d frames" % [_spread(_quiet), _quiet.size()])
		# Now start her talking, through the real dialogue player.
		_talk.call("use_script", {"a": {"text": "Talking.", "exit": "a"}}, "a")
		_talk.call("begin", "a")
		_check("and the dialogue is running", bool(_talk.call("is_running")), "")
		print("\n--- while talking ---")
		_stage = 1
		return false
	# A NOD TILTS FORWARD, so it shows up in the forward vector's Y. Reading Z measures
	# almost nothing - forward stays pointing forward - which is why this first reported
	# a head sweep of 0.001 on a head that was visibly nodding.
	# A CONTROL CHANNEL, recorded on the same frames: a plain two-second loop. The window
	# comparison below is run over both, so the question stops being "is 8% a big number"
	# - which nobody can answer - and becomes "does the real motion diverge more than
	# something we KNOW repeats", which is checkable.
	# KEYED TO THE FRAME INDEX, not to the clock, so it repeats EXACTLY once per 600-frame
	# window and scores near zero. Keyed to time it only scored near zero when the window
	# happened to be a whole number of periods long, which it was not - the first control
	# read 14% and was useless.
	var control: float = sin(float(_trace.size()) / 600.0 * TAU) * 0.08
	_trace.append([_aim().y, _aim().x, _arm_angle(), control])
	# LONG ENOUGH TO OUTLAST THE SLOWEST WAVE. The idle's longest period is 4.3 seconds,
	# so six windows have to be about that long each or the comparison below is really
	# asking "did this change much in one second", and the answer to that is no even for
	# motion that never repeats. Six windows of 600 frames is roughly 4 seconds apiece.
	if _trace.size() < 3600: return false

	var nod: Array = []
	var turn: Array = []
	var arm: Array = []
	for row in _trace:
		nod.append(row[0]); turn.append(row[1]); arm.append(row[2])
	_check("the head moves", _spread(nod) > 0.05 and _spread(turn) > 0.02,
		"nod %.3f, turn %.3f" % [_spread(nod), _spread(turn)])
	_check("and so do the arms", _spread(arm) > 0.05, "swept %.3f" % _spread(arm))

	print("\n--- and it does not loop ---")
	# Six windows, compared pairwise. Two windows of a repeating signal line up almost
	# exactly; two windows of this should not.
	var worst_match: float = _closest_pair(_trace, 0)
	var real_part: float = worst_match / maxf(_spread(nod), 0.0001)
	var loop_part: float = _closest_pair(_trace, 3) / maxf(_spread(_column(_trace, 3)), 0.0001)
	# A FLOOR AS WELL AS THE RATIO. The control now measures exactly 0%, which is the
	# right answer for a true loop and makes "beat the control by 2.5x" a comparison
	# against zero - trivially true, and a check that cannot fail is not a check. The
	# floor is what the assertion actually rests on; the ratio guards against the day
	# the control stops being a clean loop.
	_check("it diverges more than a thing that repeats",
		real_part > maxf(loop_part * 2.5, 0.05),
		"head %.0f%% against the control loop's %.0f%%, floor 5%%"
			% [real_part * 100.0, loop_part * 100.0])

	_talk.call("stop")
	_check("subtle, not a performance", _spread(nod) < 0.5 and _spread(arm) < 0.9,
		"head sweeps %.2f rad, arm %.2f" % [_spread(nod), _spread(arm)])
	_whole_cast()
	_finish()
	return true


## Everyone who talks in the field is wired, and nobody who should not be.
##
## PAIRED BY INDEX, so the two arrays are checked against each other rather than just for
## length - a figures list one entry short silently animates the wrong person, and a
## mismatched pair looks exactly like a working one until somebody speaks.
func _whole_cast() -> void:
	print("
--- the rest of the cast ---")
	var speakers: Array = _motion.get("speakers")
	var figures: Array = _motion.get("figures")
	_check("every dialogue has a figure", speakers.size() == figures.size()
		and speakers.size() == 4, "%d speakers, %d figures" % [speakers.size(), figures.size()])
	for i in mini(speakers.size(), figures.size()):
		var talk: Node = _motion.get_node_or_null(speakers[i])
		var figure: Node = _motion.get_node_or_null(figures[i])
		var ok: bool = talk != null and figure != null 			and talk.has_method("is_running") and figure.get("head") != null 			and figure.get("shoulder_left") != null
		_check("  %s" % String(figures[i]).get_file(), ok,
			"%s -> %s" % [String(speakers[i]).get_file(),
				"head and shoulders found" if ok else "MISSING"])
	# Nike is a pig and the theatre blocks its own presenter. Neither belongs here.
	var names: String = str(speakers)
	_check("the pig is not in it", not names.contains("NikeTalk"), "no shoulders on a pig")
	_check("and neither is the theatre", not names.contains("Theatre")
		and not str(figures).contains("Theatre"),
		"theatre_show_4d choreographs its own presenter")


## The most similar pair among six equal windows of one channel, as a mean absolute
## difference. A signal that repeats on the window length scores near zero here.
func _closest_pair(rows: Array, channel: int) -> float:
	var window: int = int(rows.size() / 6.0)
	var closest: float = 99.0
	for i in 5:
		for j in range(i + 1, 6):
			var diff: float = 0.0
			for k in window:
				diff += absf(float(rows[i * window + k][channel])
					- float(rows[j * window + k][channel]))
			closest = minf(closest, diff / float(window))
	return closest


func _column(rows: Array, channel: int) -> Array:
	var out: Array = []
	for row in rows:
		out.append(row[channel])
	return out


func _finish() -> void:
	if _fails.is_empty(): print("\nALL PASS")
	else: print("\n%d FAILED: %s" % [_fails.size(), ", ".join(_fails)])
	quit(1 if _fails.size() > 0 else 0)
