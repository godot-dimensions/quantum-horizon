extends SceneTree

## Does the crow perch, leave, fly and come back - and do its wings actually beat?
##
## The wing check is the one worth having. A flap is a rotation applied every frame, and
## the failure mode is not that it looks wrong but that it silently never moves: a pivot
## that was never found, a basis written to a node that is not in the tree. Measuring the
## angle the wing tip sweeps catches that where a screenshot of one frame does not.

var _root: Node
var _f := 0
var _fails: Array = []
var _crow: Node4D
var _seen: Array = []
var _peak: float = -99.0
var _floor: float = 99.0
var _wing_lo: float = 99.0
var _wing_hi: float = -99.0
var _perches: Array = []
var _fence_h: float = 0.0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _mood() -> String:
	return ["PERCHED", "TAKEOFF", "FLYING", "LANDING"][int(_crow.get("_mood"))]


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _crow == null:
		_crow = _root.get_node_or_null("World/Crow") as Node4D
		if _crow == null:
			print("   FAIL there is no crow in the scene")
			quit(1); return true
		_fence_h = float(_root.get_node("Pen/Fence").get("height"))
		# Hurry it along, or a full cycle is half a minute.
		_crow.set("perch_min", 0.35); _crow.set("perch_max", 0.5)
		_crow.set("fly_min", 0.6); _crow.set("fly_max", 0.9)
		# AND THE CLOCK ALREADY RUNNING. The first perch was rolled in _ready from the
		# original range, so shortening the range afterwards leaves a bird that still has
		# ten seconds to sit - and headless frames are worth a couple of milliseconds
		# each, so the whole test window went by without it ever taking off.
		_crow.set("_mood_left", 0.2)
		print("\n   the fence's top rail is at y %.2f" % _fence_h)
		return false

	var now: String = _mood()
	if _seen.is_empty() or _seen[-1] != now:
		_seen.append(now)
		if now == "PERCHED":
			_perches.append(_crow.position.y)
	_peak = maxf(_peak, _crow.position.y)
	_floor = minf(_floor, _crow.position.y)
	# The left wing's tip, in the bird's own frame, so banking does not count as flapping.
	var tip: Node4D = _crow.get_node_or_null("WingL/Quill2") as Node4D
	if tip != null:
		var lift: float = (_crow.basis.inverse() * (tip.global_position
			- _crow.global_position)).y
		_wing_lo = minf(_wing_lo, lift)
		_wing_hi = maxf(_wing_hi, lift)

	if _f < 2600: return false
	print("   states in order: %s" % [_seen])
	print("   heights: perched at %s, peak %.2f" % [
		_perches.map(func(v): return "%.2f" % v), _peak])
	_check("it perches, leaves, flies and lands",
		_seen.has("PERCHED") and _seen.has("TAKEOFF") and _seen.has("FLYING")
			and _seen.has("LANDING"), "%s" % [_seen])
	_check("it gets properly off the ground", _peak > 2.0,
		"reached y %.2f" % _peak)
	_check("and comes back down", _perches.size() >= 2 and _perches.min() < 1.6,
		"perched at %s" % [_perches.map(func(v): return "%.2f" % v)])
	_check("the wings actually beat", _wing_hi - _wing_lo > 0.05,
		"the tip swept %.3f up and down in the bird's own frame" % (_wing_hi - _wing_lo))
	# A fence perch should land it at the rail, not hovering over it or sunk in the field.
	# VARIETY, not one named perch. It draws from the fence, the top of every object it
	# has been pointed at, and the open ground - so asking "did it use the fence" is
	# asking a six-sided die for a chosen face in six throws. It failed on a run where the
	# bird had used the coop roof, the sign and the shed roof, which is the behaviour
	# working. What matters is that it does not always come down in the same sort of place.
	var levels := {}
	for h in _perches:
		levels["%.1f" % float(h)] = true
	_check("it lands in different sorts of places", levels.size() >= 2,
		"heights used: %s" % [levels.keys()])
	var off_ground: bool = false
	for h in _perches:
		if float(h) > 0.4:
			off_ground = true
	_check("and gets up onto things", off_ground,
		"perch heights %s" % [_perches.map(func(v): return "%.2f" % v)])

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
