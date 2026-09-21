extends SceneTree

## Lock onto an off-slice chicken and walk up to it, without ever pressing E or Q.

var _root: Node
var _f := 0
var _t0 := 0
var _assist: Node
var _player: Node4D
var _rig: Node4D
var _bird: Node
var _body: Node4D
var _armed := false


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _assist == null:
		_assist = _root.get_node("Systems/SliceAssist")
		_player = _root.get_node("Player")
		_rig = _root.get_node("Player/CameraRig")
		for a in (_root.get_node("Chickens").get("agents") as Array):
			if int(a.get("chicken_id")) == 7:
				_bird = a
		_body = _bird.get_parent() as Node4D
		_t0 = Time.get_ticks_msec()

	# Stand beside it, on slice zero, facing it. Never touch E or Q.
	var here: Vector4 = _body.global_position
	_player.position = Vector4(here.x, 1.3, here.z + 1.1, 0.0)
	_player.set("_facing", PI)

	if not _armed:
		_root.get_node("Systems/Locator").set("target", _bird)
		_assist.set("_held", _bird)
		_assist.set("tracking", true)
		_armed = true
		print("chicken 7 is at w %.2f; player stays at w 0.00 throughout.\n" % here.w)
		print("   %-7s %-9s %-9s %s" % ["t", "ana", "prompt", "lock-on line"])
		return false

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	if _f % 20 != 0: return false
	var rel: Vector4 = _body.global_position - _player.global_position
	print("   %-7.2f %-9.3f %-9s %s" % [
		elapsed, rel.dot(_rig.global_basis.w),
		"CATCH" if (_root.get_node("UI/CatchPrompt") as Label).text != "" else "-",
		(_root.get_node("UI/LockOn") as Label).text])
	return elapsed > 3.0
