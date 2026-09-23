extends SceneTree
## Where the second actually goes when you walk through the door.
##
## Three separately timed things that get lumped together as "loading":
##   1. LOADING the PackedScene off disk. Already done before you press anything, because
##      the Crossing holds it as an exported reference.
##   2. INSTANTIATE - turning that blueprint into live nodes. Main thread, unavoidable.
##   3. _READY plus the first few frames - where the theatre builds its own floor, house,
##      backdrop, beams, sky, turntable and three exhibits, and carves the rock.
var _root: Node
var _f := 0
var _theatre: Node
var _added_at := 0
var _worst := 0.0


func _initialize() -> void:
	var t0: int = Time.get_ticks_usec()
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root
	print("\nthe farm itself took %.0f ms to build" % ((Time.get_ticks_usec() - t0) / 1000.0))


func _process(delta: float) -> bool:
	_f += 1
	if _f == 90:
		var crossing: Node = _root.get_node("Crossing")
		var packed: PackedScene = crossing.get("theatre_scene")
		print("\n--- 1. loading the resource ---")
		var t0: int = Time.get_ticks_usec()
		var again: Resource = load("res://ramon/chickenpen/theatre/theatre.tscn")
		print("   load()            %7.1f ms   %s" % [(Time.get_ticks_usec() - t0) / 1000.0,
			"already resident - this is a cache hit, which is the point"
				if again == packed else "NOT the same object as the export"])

		print("\n--- 2. instantiate ---")
		t0 = Time.get_ticks_usec()
		_theatre = packed.instantiate()
		var made: float = (Time.get_ticks_usec() - t0) / 1000.0
		print("   instantiate()     %7.1f ms   nodes exist, nothing has run yet" % made)

		print("
--- 3. _ready, child by child ---")
		# Timed one at a time by taking the children OFF the theatre first and putting
		# them back after it is in the tree. Each _ready then fires on its own add_child,
		# and the bill is itemised instead of arriving as one number.
		var kids: Array[Node] = []
		for kid in _theatre.get_children():
			kids.append(kid)
		for kid in kids:
			_theatre.remove_child(kid)
		t0 = Time.get_ticks_usec()
		_root.add_child(_theatre)
		var total: float = (Time.get_ticks_usec() - t0) / 1000.0
		for kid in kids:
			var k0: int = Time.get_ticks_usec()
			_theatre.add_child(kid)
			var ms: float = (Time.get_ticks_usec() - k0) / 1000.0
			total += ms
			if ms >= 1.0:
				print("   %-16s %7.1f ms" % [kid.name, ms])
		print("   %-16s %7.1f ms   (the lot, shell included)" % ["TOTAL", total])
		_added_at = _f
		return false

	if _added_at > 0 and _f <= _added_at + 12:
		var ms: float = delta * 1000.0
		_worst = maxf(_worst, ms)
		print("   frame +%-2d         %7.1f ms" % [_f - _added_at, ms])
		if _f == _added_at + 12:
			print("\n   worst frame after it was added: %.1f ms" % _worst)
			quit(0)
			return true
	return false
