extends SceneTree
var _root: Node
var _f := 0
var _shot := 0
var _pending := ""
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/slice_%s.png" % _pending)
		_pending = ""
		return false
	if _f % 25 != 0: return false
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var amounts := [0.0, 0.35, 0.7]
	if _shot >= amounts.size(): return true
	rig.set("_slice_xw", amounts[_shot])
	rig.call("_apply")
	_pending = "%02d" % int(amounts[_shot] * 100)
	_shot += 1
	return false
