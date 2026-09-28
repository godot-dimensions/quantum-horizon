extends SceneTree

## The far room streams (cave_far_stream_4d.gd): not there when you arrive, loaded once you
## turn the slice through W, let go after you are back on the flat slice, loaded again by
## stepping off w = 0, its standing stones solid, and let go when you leave the cave.
## Windowed, it also prints the video memory at each step - the point of all of it.

var _room: Node
var _cave: Node4D
var _stream: Node
var _f := 0
var _step := 0
var _t := 0.0
var _failed := 0
## The longest frame while the room was coming in, and the ones either side of it.
var _worst := 0.0
var _hitch_after := 0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _rig() -> Node4D:
	return _room.get_node("Player/CameraRig") as Node4D


func _hold(local: Vector4) -> void:
	var p := _room.get_node("Player") as CharacterBody4D
	p.global_position = _cave.global_position + local
	p.linear_velocity = Vector4.ZERO


func _vram() -> String:
	return "%.0f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)


func _loaded() -> bool:
	return bool(_stream.call("is_loaded"))


func _process(d: float) -> bool:
	_f += 1
	if _f == 10:
		_room.get_node("CaveCrossing").call("go")
	if _f == 14:
		for c in _room.get_children():
			if c.name == "Cave":
				_cave = c
		_stream = _cave.get_node("FarStream")
	if _f < 20:
		return false
	_t += d
	match _step:
		0:
			_hold(Vector4(0, 0.05, -30, 0))
			if _t > 1.0:
				_check("not loaded on arrival", not _loaded(), _vram())
				_rig().set("_slice_xw", deg_to_rad(40.0))
				_rig().call("_apply")
				_step = 1; _t = 0.0
		1:
			_hold(Vector4(0, 0.05, -30, 0))
			_worst = maxf(_worst, d)
			if _loaded() and _hitch_after < 10:
				# A few frames more: the rock's first draw is the one that builds it.
				_hitch_after += 1
				return false
			if _loaded():
				_check("loaded by turning the slice", true, "after %.2f s, %s" % [_t, _vram()])
				print("   longest frame while it came in: %.1f ms" % (_worst * 1000.0))
				_check("its rock is there", _cave.find_child("RockFar", true, false) != null)
				_rig().set("_slice_xw", 0.0)
				_rig().call("_apply")
				_step = 2; _t = 0.0
			elif _t > 5.0:
				_check("loaded by turning the slice", false, "not after 5 s")
				_step = 2; _t = 0.0
		2:
			_hold(Vector4(0, 0.05, -30, 0))
			if _t > float(_stream.get("linger")) + 1.0:
				_check("let go back on the flat slice", not _loaded(), _vram())
				_step = 3; _t = 0.0
		3:
			_hold(Vector4(0, 0.05, -34, 5.5))
			if _loaded() and _t > 0.5:
				_check("loaded by stepping off w = 0", true, "after %.2f s" % _t)
				_step = 4; _t = 0.0
			elif _t > 5.0:
				_check("loaded by stepping off w = 0", false, "not after 5 s")
				_step = 4; _t = 0.0
		4:
			_hold(Vector4(0, 0.05, -36, 33.0))
			if _t > 0.5:
				var far: Node = _cave.find_child("FarRoom", true, false)
				var solid: Node = far.get_node_or_null("Solid") if far != null else null
				_check("the standing stones are solid", solid != null and solid.get_child_count() == 12,
					"%d colliders" % (solid.get_child_count() if solid != null else -1))
				_room.get_node("CaveCrossing").call("come_back")
				_step = 5; _t = 0.0
		5:
			if _t > 0.5:
				_check("let go on leaving the cave", not _loaded() and _cave.find_child("FarRoom", true, false) == null, _vram())
				print("CAVE FAR: %s" % ("ALL PASS" if _failed == 0 else "%d FAILED" % _failed))
				quit()
				return true
	return false
