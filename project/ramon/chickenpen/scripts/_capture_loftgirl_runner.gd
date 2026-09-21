extends SceneTree

var _root: Node
var _f := 0
var _t0 := 0
var _pending := ""
var _shots := 0
var _from := Vector4.ZERO


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/loftgirl_%s.png" % _pending)
		_pending = ""
		return false
	var cat: Node4D = _root.get_node("World/LoftedGirl")
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	if _t0 == 0:
		_t0 = Time.get_ticks_msec()
		_from = cat.global_position
		print("lofted girl built with %d parts" % cat.get_child_count())
	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0

	var at: Vector4 = cat.global_position
	var from := Vector4(at.x + 2.6, 1.3, at.z + 2.6, 0.0)
	player.global_position = from
	player.global_basis = Projection.IDENTITY
	player.set("linear_velocity", Vector4.ZERO)
	var to: Vector4 = (at + Vector4(1.3, 0.0, 0.0, 0.0)) - from
	var facing: float = atan2(to.x, to.z)
	player.set("_facing", facing)
	rig.set("yaw", facing + PI)
	rig.set("pitch", deg_to_rad(-9.0))
	rig.set("distance", 3.2)
	rig.set("_zoom_target", 3.2)
	rig.call("_apply")

	if _f % 40 != 0: return false
	if _shots == 0 and elapsed > 1.2:
		_pending = "00"; _shots += 1
	elif _shots == 1 and elapsed > 4.0:
		_pending = "01"; _shots += 1
	elif _shots >= 2 and elapsed > 6.0:
		print("lofted girl wandered %.2f units in %.1f s" % [
			Vector2(cat.global_position.x - _from.x, cat.global_position.z - _from.z).length(), elapsed])
		return true
	return false
