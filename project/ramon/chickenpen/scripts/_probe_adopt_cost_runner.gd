extends SceneTree
## Where the cinema's two adoptions spend their time: loading and instancing the source
## scene, and the adopted branch's own _ready once it is in the tree. Windowed (the wire
## previews and first draws are renderer work).
const GOAT := preload("res://ramon/chickenpen/theatre/theatre_goat_4d.gd")
const CREATURE := preload("res://ramon/chickenpen/theatre/theatre_creature_4d.gd")
var _f := 0


func _initialize() -> void:
	root.unfocusable = true


func _process(_d) -> bool:
	_f += 1
	if _f != 3:
		return _f > 10
	for path in [GOAT.SOURCE, CREATURE.SOURCE]:
		var t0: int = Time.get_ticks_usec()
		var packed: PackedScene = load(path)
		var t1: int = Time.get_ticks_usec()
		var scene: Node = packed.instantiate()
		var t2: int = Time.get_ticks_usec()
		print("%s: load %.0f ms, instantiate %.0f ms (%d nodes)" % [path.get_file(), (t1 - t0) / 1000.0,
			(t2 - t1) / 1000.0, scene.find_children("*", "", true, false).size()])
		scene.free()
	for which in ["goat", "creature"]:
		var node := Node4D.new()
		node.set_script(GOAT if which == "goat" else CREATURE)
		var t3: int = Time.get_ticks_usec()
		root.add_child(node)
		print("%s, whole build with the bake: %.0f ms" % [which, (Time.get_ticks_usec() - t3) / 1000.0])
	return false
