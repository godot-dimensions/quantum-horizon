extends SceneTree

## The keeper's shot is a BEAT: it must hand the camera back on its own after three
## seconds, and immediately if the conversation gives you something before that.

var _s: Node
var _f: int = 0
var _opened: int = 0
var _back: int = 0
var _fired: bool = false


func _initialize() -> void:
	_s = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_s)
	current_scene = _s
	var rig: Node = _s.get_node_or_null("Player/CameraRig") if _s != null else null
	if rig != null:
		rig.set("mouse_sensitivity", 0.0)


func _process(_d) -> bool:
	_f += 1
	var staged: Camera4D = _s.get_node("World/KeeperTalkCam")
	var main: Camera4D = _s.get_node("Player/CameraRig/Pitch/Camera4D")
	if _f == 40:
		var rig: Node4D = _s.get_node("Player/CameraRig")
		_s.get_node("Player").global_position = Vector4(3.52, 1.2, -3.83, 0.0)
		rig.set("yaw", deg_to_rad(30.5))
		rig.call("_apply")
	if _f == 55:
		var driver: Node = _s.get_node("Systems/TalkDriver")
		var talk: Node = _s.get_node("Systems/Talk")
		driver.call("_before_begin")
		talk.call("begin", driver.call("_entry_node"))
		_opened = _f
	var driver: Node = _s.get_node("Systems/TalkDriver")
	if _opened > 0 and _f % 30 == 0:
		print("%5.2f s  stage %d  staged current %s" % [
			float(_f - _opened) / 60.0, int(driver.get("_cine_stage")),
			str(staged.get("current"))])
	if _opened > 0 and _back == 0 and not bool(staged.get("current")):
		_back = _f
		print("camera back with the player after %.2f s   main camera current: %s" % [
			float(_f - _opened) / 60.0, str(main.get("current"))])
	return _f > 300
