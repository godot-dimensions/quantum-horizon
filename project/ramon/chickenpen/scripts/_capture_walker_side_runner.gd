extends SceneTree
## Side-on, close, at rest and mid-stride - to see where the limbs actually are.
var _root: Node
var _f := 0
var _shot := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen_proceduralwalker.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 3: return false
	var p: CharacterBody4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	rig.set("yaw", 1.5708)      # straight from the side
	rig.set("pitch", -0.08)
	rig.set("distance", 2.6)
	if _shot > 0: Input.action_press(&"move_back")
	if _f < 60 + _shot * 45: return false
	root.get_texture().get_image().save_png("res://smoke_test_output/walker_%s.png" % ("walk" if _shot > 0 else "rest"))
	print("SAVED %s" % ("walk" if _shot > 0 else "rest"))
	_shot += 1
	return _shot > 1
