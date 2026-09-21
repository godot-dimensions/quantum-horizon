extends SceneTree

## One wide shot of everything that has been added: both girls, the cat, the pen.

var _root: Node
var _f := 0
var _t0 := 0
var _pending := ""
var _shots := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/cast_%s.png" % _pending)
		_pending = ""
		return false
	if _t0 == 0:
		_t0 = Time.get_ticks_msec()
	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0

	# Stand east of the group, looking west across all of them.
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	player.global_position = Vector4(-1.5, 1.3, 7.0, 0.0)
	player.global_basis = Projection.IDENTITY
	player.set("linear_velocity", Vector4.ZERO)
	var facing: float = atan2(-1.0, -0.35)
	player.set("_facing", facing)
	rig.set("yaw", facing + PI)
	rig.set("pitch", deg_to_rad(-12.0))
	rig.set("distance", 5.5)
	rig.set("_zoom_target", 5.5)
	rig.call("_apply")

	if _f % 40 != 0: return false
	if _shots == 0 and elapsed > 2.0:
		_pending = "00"; _shots += 1
	elif _shots == 1 and elapsed > 6.0:
		_pending = "01"; _shots += 1
	elif _shots >= 2 and elapsed > 7.0:
		return true
	return false
