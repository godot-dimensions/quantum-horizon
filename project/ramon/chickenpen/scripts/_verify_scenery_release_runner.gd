extends SceneTree

## The pen's two biggest meshes let go deep in the cave and back before you are home
## (pen_scenery_release_4d.gd). Windowed, it prints the video memory at each step.

var _room: Node
var _cave: Node4D
var _release: Node
var _f := 0
var _step := 0
var _t := 0.0
var _failed := 0
var _worst := 0.0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _vram() -> String:
	return "%.0f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)


func _hold(local: Vector4) -> void:
	var p := _room.get_node("Player") as CharacterBody4D
	p.global_position = _cave.global_position + local
	p.linear_velocity = Vector4.ZERO


func _meshes_in() -> bool:
	return (_room.get_node("World/Hills") as MeshInstance4D).mesh != null \
		and (_room.get_node("World/CaveHill") as MeshInstance4D).mesh != null


func _process(d: float) -> bool:
	_f += 1
	if _f == 5:
		_release = _room.get_node("Systems/SceneryRelease")
	if _f == 40:
		print("   in the pen: %s" % _vram())
		_room.get_node("CaveCrossing").call("go")
	if _f == 44:
		for c in _room.get_children():
			if c.name == "Cave":
				_cave = c
	if _f < 50:
		return false
	_t += d
	match _step:
		0:
			_hold(Vector4(0, 0.05, -1.0, 0))
			if _t > 1.0:
				_check("kept at the arrival", _meshes_in() and not bool(_release.call("is_released")), _vram())
				_step = 1; _t = 0.0
		1:
			_hold(Vector4(0, 0.05, -30.0, 0))
			if _t > 1.0:
				_check("let go in the chamber", not _meshes_in() and bool(_release.call("is_released")), _vram())
				_step = 2; _t = 0.0
		2:
			_hold(Vector4(0, 0.05, -6.0, 0))
			_worst = maxf(_worst, d)
			if _meshes_in() or _t > 5.0:
				_check("back on the way out", _meshes_in(), "after %.2f s, longest frame %.1f ms" % [_t, _worst * 1000.0])
				_room.get_node("CaveCrossing").call("come_back")
				_step = 3; _t = 0.0
		3:
			if _t > 1.0:
				_check("home with them", _meshes_in() and not bool(_release.call("is_released")), _vram())
				# The debug way: straight in, down to the chamber, straight out.
				_room.get_node("CaveCrossing").call("go")
				_step = 4; _t = 0.0
		4:
			if _cave != null:
				_hold(Vector4(0, 0.05, -30.0, 0))
			if _t > 1.0:
				_check("let go again", not _meshes_in())
				_room.get_node("CaveCrossing").call("come_back")
				_step = 5; _t = 0.0
		5:
			if _t > 0.5:
				_check("back even when the corridor is skipped", _meshes_in(), _vram())
				print("SCENERY RELEASE: %s" % ("ALL PASS" if _failed == 0 else "%d FAILED" % _failed))
				quit()
				return true
	return false
