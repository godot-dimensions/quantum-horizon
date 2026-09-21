extends SceneTree

## Does the level actually tell the three ways of being lost apart?
##
## The whole claim of the instrument is that each control deforms the quad in its own
## way, so the SHAPE says which control to move. That is only true if the four corner
## heights respond independently, and if the reading it prints names the right one.

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-34s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _state(plane: Node, player: Node4D, rig: Node4D, w: float, xw: float, zw: float) -> Dictionary:
	player.position = Vector4(0.0, 1.3, 0.0, w)
	rig.set("_slice_xw", xw); rig.set("_slice_zw", zw); rig.call("_apply")
	var pen: Rect2 = plane.call("_footprint")
	var h: Array = []
	for c in [Vector2(pen.position.x, pen.position.y), Vector2(pen.end.x, pen.position.y),
			Vector2(pen.end.x, pen.end.y), Vector2(pen.position.x, pen.end.y)]:
		h.append(float(plane.call("_w_above", c.x, c.y)))
	var worst: float = 0.0
	for v in h:
		worst = maxf(worst, absf(v))
	return {"h": h, "worst": worst, "says": plane.call("_reading", h, worst,
		worst <= float(plane.get("home_tolerance")))}


func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var plane: Node = _root.get_node("UI/SlicePlane")
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")

	print("\n--- the level, in each of the four states ---")
	var home: Dictionary = _state(plane, player, rig, 0.0, 0.0, 0.0)
	print("   home        corners %s -> %s" % [_fmt(home.h), home.says])
	_check("home reads as home", home.worst < 0.01 and String(home.says).begins_with("home"),
		"worst corner %+.3f" % home.worst)

	var lifted: Dictionary = _state(plane, player, rig, 1.5, 0.0, 0.0)
	print("   ana 1.5     corners %s -> %s" % [_fmt(lifted.h), lifted.says])
	_check("a step through W lifts it FLAT", _spread(lifted.h) < 0.01 and lifted.worst > 1.4,
		"spread %.3f, height %+.2f" % [_spread(lifted.h), lifted.h[0]])
	_check("and it names the key", String(lifted.says).contains("Q"), String(lifted.says))

	var across: Dictionary = _state(plane, player, rig, 0.0, 0.35, 0.0)
	print("   xw 20 deg   corners %s -> %s" % [_fmt(across.h), across.says])
	# Tilted across the short side: the two x-positive corners go one way, the other two
	# the other, and the two corners at the same x stay together.
	_check("xw tilts it across", absf(across.h[0] - across.h[3]) < 0.01
		and across.h[1] - across.h[0] > 1.0, "corner gap %+.2f" % (across.h[1] - across.h[0]))

	var along: Dictionary = _state(plane, player, rig, 0.0, 0.0, 0.35)
	print("   zw 20 deg   corners %s -> %s" % [_fmt(along.h), along.says])
	_check("zw tilts it lengthways", absf(along.h[0] - along.h[1]) < 0.01
		and absf(along.h[2] - along.h[0]) > 1.0, "corner gap %+.2f" % (along.h[2] - along.h[0]))
	_check("the two tilts are told apart",
		String(across.says).contains("lengthways") != String(along.says).contains("lengthways"),
		"'%s' vs '%s'" % [across.says, along.says])

	# And the degenerate case, which would otherwise divide by nearly nothing.
	var edge: Dictionary = _state(plane, player, rig, 0.0, PI * 0.5, 0.0)
	_check("edge-on does not blow up", is_nan(edge.h[0]) or edge.worst < 1.0e6,
		"first corner %s" % [edge.h[0]])

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true


func _fmt(h: Array) -> String:
	return "[%s]" % ", ".join(h.map(func(v): return "%+.2f" % v))


func _spread(h: Array) -> float:
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	for v in h:
		lo = minf(lo, v); hi = maxf(hi, v)
	return hi - lo
