extends SceneTree

## The professor's staged shot: does it hold, push in, and then give the camera back?

var _s: Node
var _f: int = 0
var _opened: int = 0
var _handed: int = 0


func _initialize() -> void:
	_s = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_s)
	current_scene = _s
	var rig: Node = _s.get_node_or_null("Player/CameraRig") if _s != null else null
	if rig != null:
		rig.set("mouse_sensitivity", 0.0)


func _gap(a: Node4D, b: Node4D) -> float:
	var d: Vector4 = a.global_position - b.global_position
	return Vector2(d.x, d.z).length()


func _process(_d) -> bool:
	_f += 1
	var player: Node4D = _s.get_node("Player")
	var staged: Camera4D = _s.get_node("World/ProfessorTalkCam")
	var head: Node4D = _s.get_node("World/ProfessorPost/ProfessorHead")
	if _f == 40:
		var rig: Node4D = _s.get_node("Player/CameraRig")
		player.global_position = Vector4(10.87, 1.2, -15.28, 0.0)
		rig.set("yaw", deg_to_rad(-68.5))
		rig.call("_apply")
	if _f == 55:
		var driver: Node = _s.get_node("Systems/ProfessorDriver")
		var talk: Node = _s.get_node("Systems/ProfessorTalk")
		driver.call("_before_begin")
		talk.call("begin", driver.call("_entry_node"))
		_opened = _f
		print("opened: %s" % str(talk.call("is_running")))
	if _opened > 0 and _handed == 0 and _f > _opened:
		if not bool(staged.get("current")):
			_handed = _f
			print("camera handed back after %.2f s (asked for 5.0)" % [
				float(_f - _opened) / 60.0])
	if _f in [60, 250, 350]:
		print("%4d  staged %.2f m from him, %.2f from you, current=%s" % [
			_f, _gap(staged, head), _gap(staged, player), str(staged.get("current"))])
	return _f > 420
