extends SceneTree

## Does the cat go to the crate, get on it, sit, wash - and STAY there when you walk up?
##
## The last one is the point of this run. The cat used to bolt the moment you came within
## a couple of units, which read as skittish and made it impossible to pick up: the only
## way to reach it was to corner it against something. It now only runs after it has
## scratched its way out of your arms, so this checks both halves - that being approached
## does nothing, and that being dropped does.

const MOODS := ["WANDER", "TO_CRATE", "JUMP", "SIT", "FLEE", "CARRIED", "THROWN", "TO_PERCH"]

var _root: Node
var _f := 0
var _t0 := 0
var _cat: Node4D
var _player: Node4D
var _seen: Array = []
var _peak_y: float = -99.0
var _chased := false
var _chase_at: float = 0.0
var _chase_pos: Vector4 = Vector4.ZERO
var _dropped := false
var _drop_pos: Vector4 = Vector4.ZERO
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-40s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _cat == null:
		_cat = _root.get_node("World/Cat")
		_player = _root.get_node("Player")
		# Park the player far away so it settles before being disturbed.
		_player.position = Vector4(20.0, 1.3, 20.0, 0.0)
		# Hurry it along: a short patience so the test does not wait a minute.
		_cat.set("_mood_left", 0.6)
		_t0 = Time.get_ticks_msec()
		return false

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var mood: int = int(_cat.get("_mood"))
	if _seen.is_empty() or _seen[-1] != MOODS[mood]:
		_seen.append(MOODS[mood])
		print("   %5.1fs  %-8s  cat y %.2f" % [elapsed, MOODS[mood], _cat.global_position.y])
	_peak_y = maxf(_peak_y, _cat.global_position.y)

	# Once it has sat down, walk up to it and stand there.
	if not _chased and MOODS[mood] == "SIT" and elapsed > 2.0:
		_chased = true
		_chase_at = elapsed
		_chase_pos = _cat.global_position
		var at: Vector4 = _cat.global_position
		_player.position = Vector4(at.x + 1.0, 1.3, at.z + 1.0, at.w)
		print("   -- player walks up to it and stays --")
		return false

	# Four seconds of being stood next to should not have moved it.
	if _chased and not _dropped and elapsed > _chase_at + 4.0:
		print("\n-- standing next to it --")
		var moved: float = (_cat.global_position - _chase_pos).length()
		_check("it stayed put", moved < 0.20, "moved %.3f in four seconds" % moved)
		_check("it is still sat on the crate", MOODS[mood] == "SIT",
			"mood %s, y %.2f" % [MOODS[mood], _cat.global_position.y])
		# Now scratch its way out of your arms, which is the one thing that does start it.
		_cat.call("drop_and_flee")
		_dropped = true
		_drop_pos = _cat.global_position
		print("   -- it scratches you and goes --")
		return false

	if _dropped and elapsed > _chase_at + 9.5:
		print("\n-- after the scratch --")
		var gone: float = (_cat.global_position - _drop_pos).length()
		_check("it bolted", gone > 5.0, "covered %.2f units getting away" % gone)
		_check("and settled back to wandering", MOODS[mood] == "WANDER",
			"mood %s - it does not run for ever" % MOODS[mood])
		print("\nmoods in order: %s" % [_seen])
		print("highest the cat got: %.2f (crate top is about 0.85)" % _peak_y)
		print("\n%d FAIL(s)" % _fails.size())
		quit(1 if _fails.size() > 0 else 0)
		return true

	return false
