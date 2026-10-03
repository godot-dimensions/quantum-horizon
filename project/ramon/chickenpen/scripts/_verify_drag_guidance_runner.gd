extends SceneTree

## Does the guidance actually work if you just do what it says?
##
## The test reads the word on screen - "left", "right", "up", "down" - and drags that way,
## knowing nothing about xw, zw or which plane matters. If the advice is wrong the offset
## goes UP and this never converges, which is exactly what a player would experience.

var _root: Node
var _f := 0
var _assist: Node
var _player: Node4D
var _rig: Node4D
var _bird: Node
var _body: Node4D
var _armed := false
var _drags := 0
var _first := 0.0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
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

	# Stand beside it on slice zero, facing it. Never press E or Q.
	var here: Vector4 = _body.global_position
	_player.position = Vector4(here.x, 1.3, here.z + 1.1, 0.0)
	_player.set("_facing", PI)

	if not _armed:
		_root.get_node("Systems/Locator").set("target", _bird)
		_assist.set("_held", _bird)
		_assist.set("tracking", true)
		_armed = true
		_first = absf(_offset())
		print("chicken 7 sits %.2f off the slice. Doing only what the screen says:\n" % _first)
		return false
	if _f % 12 != 0: return false

	var line: String = (_root.get_node("UI/LockOn") as Label).text
	var offset: float = _offset()
	print("   offset %6.3f   %s" % [offset, line])
	if line.contains("on your slice"):
		print("\n   arrived after %d drags, never touching E or Q." % _drags)
		print("   catch prompt: '%s'" % (_root.get_node("UI/CatchPrompt") as Label).text)
		return true
	if _drags > 40:
		print("\n   FAILED to converge after %d drags - the advice does not lead anywhere." % _drags)
		return true

	# Do what it said. A drag of 0.08, in the named direction only.
	var step := 0.08
	if line.contains("drag left"):
		_rig.set("_slice_xw", float(_rig.get("_slice_xw")) + step)
	elif line.contains("drag right"):
		_rig.set("_slice_xw", float(_rig.get("_slice_xw")) - step)
	elif line.contains("drag down"):
		_rig.set("_slice_zw", float(_rig.get("_slice_zw")) + step)
	elif line.contains("drag up"):
		_rig.set("_slice_zw", float(_rig.get("_slice_zw")) - step)
	else:
		return false
	_rig.call("_apply")
	_drags += 1
	return false


func _offset() -> float:
	return float(BearingUtility4D.compute_raw(
		_player.global_position, _rig.global_basis, _body.global_position)["ana_offset"])
