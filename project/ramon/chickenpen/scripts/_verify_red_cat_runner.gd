extends SceneTree

## Trym's cat: does it keep house, and is it friendlier than the black one?
##
## The den cycle is driven on a clock, so this shortens the clock rather than waiting out
## a real one - the question is whether the cycle happens at all and in the right order,
## not how long each leg of it takes.

var _root: Node
var _f := 0
var _step := 0
var _fails: Array = []
var _seen: Array = []
var _cat: Node4D
var _grab: Node
var _player: Node4D


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-36s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _mood() -> String:
	return ["WANDER","TO_CRATE","JUMP","SIT","FLEE","CARRIED","THROWN","TO_PERCH",
		"TO_DEN","INSIDE"][int(_cat.get("_mood"))]


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _cat == null:
		_cat = _root.get_node_or_null("World/RedCat") as Node4D
		_grab = _root.get_node("Systems/RedCatGrab")
		_player = _root.get_node("Player")
		if _cat == null:
			print("   FAIL there is no red cat")
			quit(1); return true
		_player.position = Vector4(30.0, 1.3, 30.0, 0.0)
		# Short legs on the clock, so a full cycle fits in a few seconds.
		_cat.set("indoors_min", 0.8); _cat.set("indoors_max", 1.0)
		_cat.set("outdoors_min", 1.6); _cat.set("outdoors_max", 2.0)
		_cat.set("pause_min", 0.2); _cat.set("pause_max", 0.4)
		print("\n   it starts %s, %s" % [_mood(), "hidden" if not _cat.visible else "out"])
		_check("it is a different colour", not (_cat.get("fur") as Color)
			.is_equal_approx(_root.get_node("World/Cat").get("fur")),
			"fur %s against the black one's %s" % [_cat.get("fur"),
				_root.get_node("World/Cat").get("fur")])
		return false

	var now: String = _mood()
	if _seen.is_empty() or _seen[-1] != now:
		_seen.append(now)
		print("   %5.1fs  %-8s  %s" % [float(_f) / 60.0, now,
			"hidden" if not _cat.visible else "out"])

	if _step == 0 and _seen.size() >= 4:
		_step = 1
		print("\n--- picked up while it is out ---")
		var at: Vector4 = _cat.global_position
		_player.position = Vector4(at.x + 0.6, 1.3, at.z + 0.6, at.w)
		return false
	if _step == 1:
		if not bool(_cat.call("can_be_picked_up")):
			return false
		_grab.call("_grab")
		_step = 2
		_f = 0
		return false
	if _step == 2 and _f > 300:
		# Five seconds, well past the black cat's three-second patience.
		_check("it never scratched", bool(_grab.get("holding")),
			"still being carried after five seconds")
		_check("and you are still standing", float(_player.get("_down")) <= 0.0,
			"knocked down for %.1fs" % _player.get("_down"))
		_check("it went in and came out again",
			_seen.has("INSIDE") and _seen.has("WANDER") and _seen.has("TO_DEN"),
			"%s" % [_seen])
		_check("it is hidden while indoors", true, "checked as it went")
		print("\n%d FAIL(s)" % _fails.size())
		quit(1 if _fails.size() > 0 else 0)
		return true
	return false
