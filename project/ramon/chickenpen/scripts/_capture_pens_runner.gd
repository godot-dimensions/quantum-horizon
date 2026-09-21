extends SceneTree
## One frame of each pen, from a fixed spot so the three are comparable.
var _scenes := ["chickenpen_plush", "chickenpen_human", "chickenpen_blockwalker"]
var _i := 0
var _root: Node
var _f := 0
func _initialize() -> void: _load()
func _load() -> void:
	if _root != null: _root.queue_free()
	_root = load("res://ramon/chickenpen/%s.tscn" % _scenes[_i]).instantiate()
	root.add_child(_root); current_scene = _root
	_f = 0
func _process(_d) -> bool:
	_f += 1
	# Hold the rig at a three-quarter view so the avatar is not just a back.
	var rig := _root.get_node_or_null("Player/CameraRig")
	if rig:
		rig.set("yaw", 2.5)
		rig.set("pitch", -0.28)
		rig.set("distance", 4.2)
	if _f < 50: return false
	root.get_texture().get_image().save_png("res://smoke_test_output/pen_%s.png" % _scenes[_i].replace("chickenpen_", ""))
	print("SAVED %s" % _scenes[_i])
	_i += 1
	if _i >= _scenes.size(): return true
	_load()
	return false
