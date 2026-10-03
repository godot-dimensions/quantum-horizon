extends SceneTree

## The dreamer's mouth, twice: from where _play_at_dreamer_runner.gd puts you, and from
## 2.5 m straight in front of it. Windowed. Writes res://smoke_test_output/mouth_play.png and
## mouth_close.png.

var _room: Node
var _cave: Node4D
var _f := 0
var _t := 0.0
var _eye: Camera4D
func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room); current_scene = _room
func _process(d: float) -> bool:
	_f += 1
	if _f == 10:
		_room.get_node("CaveCrossing").call("go")
	if _f == 14:
		for c in _room.get_children():
			if c.name == "Cave": _cave = c
		for c in _room.get_node("UI").get_children():
			if c is CanvasItem: (c as CanvasItem).visible = false
	if _f < 14 or _cave == null:
		return false
	var p := _room.get_node("Player") as CharacterBody4D
	p.global_position = _cave.global_position + Vector4(0.0, 0.05, -27.0, 46.0)
	p.linear_velocity = Vector4.ZERO
	var rig := p.get_node("CameraRig") as Node4D
	var dd: Vector4 = _cave.global_position + Vector4(0, 10.5, -36, 46) - p.global_position
	rig.set("yaw", atan2(-dd.x, -dd.z)); rig.set("pitch", deg_to_rad(12.0)); rig.call("_apply")
	var far: Node = _cave.find_child("FarRoom", true, false)
	if far == null:
		return false
	_t += d
	if _t > 2.5 and _t - d <= 2.5:
		root.get_texture().get_image().save_png("res://smoke_test_output/mouth_play.png")
		# Now a free camera, 5 m in front of the mouth, straight at it.
		var mouth: Node4D = far.get_node("Dreamer/Mouth")
		_eye = Camera4D.new(); _eye.set("rendering_engine_name", "Cross-section")
		_cave.add_child(_eye); _eye.current = true
		var fwd: Vector4 = mouth.global_basis.z.normalized()
		var at: Vector4 = mouth.global_position + fwd * 5.0
		var f: Vector4 = (mouth.global_position - at).normalized()
		_eye.global_position = at
		_eye.global_basis = Basis4D.from_zx(atan2(-f.x, -f.z)) * Basis4D.from_yz(asin(clampf(f.y, -1.0, 1.0)))
	if _t > 3.2:
		root.get_texture().get_image().save_png("res://smoke_test_output/mouth_close.png")
		print("saved")
		quit(); return true
	return false
