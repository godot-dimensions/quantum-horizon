extends SceneTree
## What each of part two's exhibits actually costs to build.
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 40:
		var two: Node = _root.get_node("PartTwo")
		print("\n--- part two, exhibit by exhibit ---")
		var total := 0.0
		for name_ in two.get("BUILDERS"):
			var t0: int = Time.get_ticks_usec()
			two.call("_build_one")
			var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			total += ms
			print("   %-18s %8.1f ms" % [name_, ms])
		print("   %-18s %8.1f ms" % ["TOTAL", total])
		quit(0); return true
	return false
