extends SceneTree

## The murmuration in the pen, headless: it flies, it sleeps while the pen does (the cinema
## and the cave put World to sleep; a laptop trip takes the whole pen out of the tree), and
## it comes back flying. Headless has no GPU, so this is the CPU step, cut to cpu_count.
##
##   godot... --headless --path project --script res://ramon/chickenpen/scripts/_verify_flock_runner.gd

var _room: Node
var _flock: Node4D
var _f: int = 0
var _fails: int = 0
var _mark := Vector4.ZERO


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	_flock = _room.get_node("World/Flock") as Node4D


func _check(ok: bool, what: String, detail: String = "") -> void:
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _first_bird() -> Vector4:
	var pos: PackedVector4Array = _flock.call("positions")
	return pos[0] if pos.size() > 0 else Vector4.ZERO


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		5:
			_check(_flock != null, "the pen has a flock")
			_check(not bool(_flock.call("on_gpu")), "headless steps it on the CPU")
			_check(int(_flock.get("count")) <= int(_flock.get("cpu_count")), "and cuts it to cpu_count there", "%d birds" % int(_flock.get("count")))
			_mark = _first_bird()
		65:
			var moved: float = (_first_bird() - _mark).length()
			_check(moved > 3.0, "it flies", "bird 0 moved %.1f m in 60 frames" % moved)
			var y: float = _first_bird().y
			_check(y > 5.0 and y < 60.0, "in the sky, not the ground", "at %.1f m" % y)
			_room.get_node("Crossing").call("go")
		70:
			_check(not _flock.is_visible_in_tree(), "the cinema hides it")
			_mark = _first_bird()
		130:
			var still: float = (_first_bird() - _mark).length()
			_check(still < 0.001, "and it does not fly on unseen", "moved %.3f m in 60 frames" % still)
			_room.get_node("Crossing").call("come_back")
		135:
			_check(_flock.is_visible_in_tree(), "back from the cinema it shows")
			_mark = _first_bird()
		195:
			var moved: float = (_first_bird() - _mark).length()
			_check(moved > 3.0, "and flies again", "moved %.1f m" % moved)
			# A laptop trip takes the whole pen out of the tree and puts it back.
			root.remove_child(_room)
		200:
			root.add_child(_room)
			current_scene = _room
			_mark = _first_bird()
		260:
			var moved: float = (_first_bird() - _mark).length()
			_check(moved > 3.0, "after the pen was parked and put back, it flies", "moved %.1f m" % moved)
			var hawk_ok: bool = _flock.has_method("call_hawk") and _flock.has_method("hawk_position")
			_check(hawk_ok, "the hawk can be called")
			_flock.call("call_hawk")
		420:
			var seen_hawk: bool = _flock.call("hawk_position") != null
			_check(seen_hawk, "and comes", str(_flock.call("hawk_position")))
			print("%d FAIL(s)" % _fails)
			quit()
			return true
	return false
