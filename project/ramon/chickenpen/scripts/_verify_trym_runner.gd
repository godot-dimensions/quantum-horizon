extends SceneTree

## Does Trym sit properly at his desk, and does he stand up and turn when you come over?
##
## The two things worth measuring are the ones a screenshot would not settle: whether his
## feet are on the floor in BOTH poses (a folded leg that misses the ground is the standard
## failure here), and whether the figure he turns to face is really the player rather than
## some angle that happens to look right from one side.

var _root: Node
var _f := 0
var _trym: Node4D
var _player: Node4D
var _phase := 0
var _t0 := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _boot_bottom() -> float:
	var low: float = 99.0
	for tag in ["L", "R"]:
		var boot: Node4D = _trym.get_node_or_null("Figure/Hip%s/Knee%s/Ankle%s/Boot%s" % [tag, tag, tag, tag])
		if boot == null:
			continue
		var half: float = (boot.mesh.size.y) * 0.5
		low = minf(low, boot.global_position.y - half)
	return low


func _head_y() -> float:
	var head: Node4D = _trym.get_node_or_null("Figure/Tunic/Head")
	return head.global_position.y if head != null else -99.0


func _knee_ahead() -> float:
	# How far the knee is in front of the hip, along the direction he is facing.
	var hip: Node4D = _trym.get_node_or_null("Figure/HipL")
	var knee: Node4D = _trym.get_node_or_null("Figure/HipL/KneeL")
	if hip == null or knee == null:
		return 0.0
	var figure: Node4D = _trym.get_node("Figure")
	var fwd: Vector4 = (figure.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
	return (knee.global_position - hip.global_position).dot(fwd)


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-34s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _trym == null:
		_trym = _root.get_node_or_null("World/TrymCabin/Trym") as Node4D
		_player = _root.get_node("Player")
		if _trym == null:
			print("   FAIL Trym is not in the scene at all.")
			quit(1)
			return true
		# Well out of the way, so he settles into the seated pose undisturbed.
		_player.position = Vector4(25.0, 1.3, 25.0, 0.0)
		_t0 = Time.get_ticks_msec()
		return false

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0

	if _phase == 0 and elapsed > 1.5:
		print("\n-- seated at the desk --")
		var low: float = _boot_bottom()
		_check("feet on the floor, seated", absf(low) < 0.10, "boot bottom at y %+.3f" % low)
		var ahead: float = _knee_ahead()
		_check("knees under the desk", ahead > 0.20, "knee %.2f forward of the hip" % ahead)
		var head: float = _head_y()
		_check("head clears the desk top", head > 0.72, "head at y %.2f, desk top 0.62" % head)
		_check("not standing yet", not _trym.call("is_standing"), "rise held down")
		# Now walk up behind him.
		var at: Vector4 = _trym.global_position
		_player.position = Vector4(at.x + 0.4, 1.3, at.z + 2.4, at.w)
		_phase = 1
		_t0 = Time.get_ticks_msec()
		return false

	if _phase == 1 and elapsed > 3.5:
		print("\n-- after you walk up to him --")
		_check("he got up", _trym.call("is_standing"), "standing")
		var low: float = _boot_bottom()
		_check("feet on the floor, standing", absf(low) < 0.06, "boot bottom at y %+.3f" % low)
		# Facing: the same atan2(x, z) convention the rest of the scene uses.
		var figure: Node4D = _trym.get_node("Figure")
		var gap: Vector4 = _player.global_position - figure.global_position
		var want: float = atan2(gap.x, gap.z)
		var got: float = atan2(figure.global_basis.z.x, figure.global_basis.z.z)
		var off: float = absf(wrapf(want - got, -PI, PI))
		_check("he turned to face you", off < 0.12, "%.3f rad off the player" % off)
		var head: float = _head_y()
		_check("he is taller standing than sat", head > 1.10, "head at y %.2f" % head)
		# Now leave.
		_player.position = Vector4(25.0, 1.3, 25.0, 0.0)
		_phase = 2
		_t0 = Time.get_ticks_msec()
		return false

	if _phase == 2 and elapsed > 2.5:
		print("\n-- after you wander off --")
		_check("he sat back down", not _trym.call("is_standing"), "seated again")
		var low: float = _boot_bottom()
		_check("feet still on the floor", absf(low) < 0.10, "boot bottom at y %+.3f" % low)
		print("\n%d FAIL(s)" % _fails.size())
		quit(1 if _fails.size() > 0 else 0)
		return true

	return false
