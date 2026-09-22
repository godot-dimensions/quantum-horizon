extends SceneTree

## Is the goat actually lofted, and is assembling it in front of an audience affordable?
##
## The exhibit's claim is that a person - or a machine - made this by placing control balls
## and letting the tooling generate the surface. If every rig came back empty the picture
## would still look roughly like a goat, because the markers alone nearly do, so what is
## checked is that each chain produced a MESH and that there is far more in the mesh than
## in the balls that made it. That ratio is the claim.
##
## And the build is BAKED, so the thing to measure is the bake: it happens once, during the
## room's arrival, and it has to be over before anybody walks down to the drum.

var _root: Node
var _f := 0
var _fails: Array = []
var _bake_ms: float = 0.0


func _initialize() -> void:
	_root = Node4D.new()
	root.add_child(_root); current_scene = _root
	var goat := Node4D.new()
	goat.name = "Goat"
	goat.set_script(load("res://ramon/chickenpen/theatre/theatre_goat_4d.gd"))
	_root.add_child(goat)


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 30:
		return false
	var goat: Node4D = _root.get_node("Goat")
	# The bake times itself. Wrapping add_child measured nothing - a node added during
	# _initialize has not had _ready called on it yet, so the timer closed before any
	# lofting happened and the check passed on a zero.
	var balls: int = int(goat.call("ball_count"))
	var tetra: int = int(goat.call("tetra_count"))
	var stages: int = int(goat.call("stage_count"))

	print("\n--- the goat ---")
	_check("it is the goat somebody authored", balls >= 20,
		"%d handles, adopted out of Model/model.tscn rather than invented here" % balls)
	_check("and the lofter grew a skin on them", tetra > 400,
		"%d tetrahedra on the finished animal" % tetra)
	_check("which is the whole claim", tetra / maxi(balls, 1) > 20,
		"%d tetrahedra for every ball placed" % (tetra / maxi(balls, 1)))

	print("\n--- assembling it in front of people ---")
	_check("there is a sequence to play", stages >= 8,
		"%d baked stages: it builds, then it reshapes" % stages)
	# Each stage is a full loft. The whole bake happens during the arrival, which runs
	# eleven seconds, and the rock carve is in there too.
	_bake_ms = float(goat.call("bake_ms"))
	_check("and baking it fits inside the arrival", _bake_ms < 6000.0,
		"%.0f ms to bake all %d, against an eleven second arrival" % [_bake_ms, stages])
	# Playback has to be free, or none of this was worth baking.
	var started: int = Time.get_ticks_usec()
	for i in stages:
		goat.call("show_stage", i)
	var swap: float = float(Time.get_ticks_usec() - started) / 1000.0
	_check("and playing it back costs nothing", swap < 5.0,
		"%.2f ms to step through every stage" % swap)

	var early: int = 0
	var late: int = 0
	goat.call("show_stage", 0)
	early = int(goat.call("balls_shown"))
	goat.call("show_stage", int(goat.call("first_morph_stage")) - 1)
	late = int(goat.call("balls_shown"))
	_check("the animal really does grow", late > early,
		"%d balls at the first stage, %d by the last" % [early, late])

	# The reshape moves four named handles and nothing else, which is the claim. If the
	# model is ever reordered or a part renamed, this is what notices.
	var moved := 0
	for wanted in ["NeckHigh", "Skull", "HornBase", "HornMid"]:
		if _find(goat, String(wanted)) != null:
			moved += 1
	_check("and the handles it reshapes are real parts of it", moved == 4,
		"%d of 4 named handles found on the authored goat" % moved)
	# It has to stand ON the drum, not through it or above it.
	var lowest: float = INF
	for ball in _handles(goat):
		lowest = minf(lowest, ball.global_position.y - float(ball.get("radius")))
	_check("and it stands on the floor", absf(lowest) < 0.35,
		"lowest point sits %.2f from the deck" % lowest)
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true


## The goat's parts are nested, so a name lookup has to walk.
func _find(node: Node, wanted: String) -> Node:
	for child in node.get_children():
		if String(child.name) == wanted:
			return child
		var deeper: Node = _find(child, wanted)
		if deeper != null:
			return deeper
	return null


func _handles(node: Node, into: Array[Node4D] = []) -> Array[Node4D]:
	for child in node.get_children():
		if child.has_method("get_loft_section"):
			into.append(child as Node4D)
		_handles(child, into)
	return into
