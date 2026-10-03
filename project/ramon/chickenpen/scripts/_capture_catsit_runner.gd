extends SceneTree

## Wait for the cat to be sitting on its crate, then photograph it from the side.

var _root: Node
var _f := 0
var _pending := ""
var _shots := 0
var _cat: Node4D
var _done := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/catsit_%s.png" % _pending)
		_pending = ""
		return false
	if _cat == null:
		_cat = _root.get_node("World/Cat")
		_cat.set("_mood_left", 0.4)

	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	# Watch from a distance it is not scared of, off to one side so it is not hidden.
	var at: Vector4 = _cat.global_position
	var from := Vector4(at.x + 3.4, 1.3, at.z + 3.4, 0.0)
	player.global_position = from
	player.global_basis = Projection.IDENTITY
	player.set("linear_velocity", Vector4.ZERO)
	var to: Vector4 = (at + Vector4(2.2, 0.0, 0.0, 0.0)) - from
	var facing: float = atan2(to.x, to.z)
	player.set("_facing", facing)
	rig.set("yaw", facing + PI)
	rig.set("pitch", deg_to_rad(-6.0))
	rig.set("distance", 3.0)
	rig.set("_zoom_target", 3.0)
	rig.call("_apply")

	if _f % 25 != 0: return false
	if int(_cat.get("_mood")) == 3:
		_done += 1
		if _done == 2:
			_pending = "00_sitting"; _shots += 1
		elif _done == 8:
			_pending = "01_washing"; _shots += 1
		elif _done > 14:
			print("captured the cat sitting at y %.2f" % _cat.global_position.y)
			return true
	return _f > 3000
