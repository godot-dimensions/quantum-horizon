extends SceneTree

## The ground toggles as Ramon uses them, while playing: the scene starts as it does (painted
## ground, centre glow on), the camera held still and the wind stilled, then Shift+O (the pen's
## own ground), Shift+O back, Ctrl+O (glow off), Ctrl+O back, and the same with the grass off
## (Alt+O). A frame after each, and the mean colour of the grass near the camera and of the bare
## ground past it printed, so "does it change, and which way" is a number. Gives up after 90 s.
## Saves res://smoke_test_output/toggles_<n>_<state>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/grass/_ground_toggles_runner.gd

const STEPS := [
	["start", []],
	["own", [["shift"]]],
	["painted_again", [["shift"]]],
	["glow_off", [["ctrl"]]],
	["glow_on_again", [["ctrl"]]],
	["grass_off", [["alt"]]],
	["grass_off_glow_off", [["ctrl"]]],
	["grass_off_own", [["shift"]]],
]

var _room: Node
var _grass: Node
var _cam: Camera4D
var _t: float = 0.0
var _step: int = -1
var _wait: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_toggles_test.cfg")
	_grass = _room.get_node("World/Grass")
	_grass.set("wind_speed", 0.0)
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	if _t > 90.0:
		print("TOGGLES FAIL: timed out at step %d" % _step)
		return true
	if _step < 0:
		if not bool(_grass.get("mask_ready")) or _t < 6.0:
			return false
		for child in _room.get_node("UI").get_children():
			if child is CanvasItem and child.name != "GrassPanel":
				(child as CanvasItem).visible = false
		var player := _room.get_node("Player") as Node4D
		player.set_physics_process(false)
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_cam.set("field_of_view_4d", 1.0)
		player.add_child(_cam)
		_cam.make_current()
		var eye: Vector4 = player.global_position + Vector4(1.5, 3.2, 9.0, 0.0)
		var at: Vector4 = player.global_position + Vector4(0.0, 0.0, -8.0, 0.0)
		_cam.global_position = eye
		var dd: Vector4 = at - eye
		_cam.global_basis = Basis4D.from_zx(atan2(-dd.x, -dd.z)) * Basis4D.from_yz(atan2(dd.y, Vector2(dd.x, dd.z).length()))
		_step = 0
		_wait = 1.0
		_t = 6.0
		return false
	_wait -= d
	if _wait > 0.0:
		return false
	var name: String = STEPS[_step][0]
	var image: Image = root.get_texture().get_image()
	image.save_png("res://smoke_test_output/toggles_%d_%s.png" % [_step, name])
	var ground := _room.get_node("World/Ground/GroundMesh") as MeshInstance4D
	print("      %-20s grass near %s   ground far %s   [painted %s, glow %s, grass %s, mesh %s]" % [name,
		_mean(image, Rect2i(400, 560, 480, 140)), _mean(image, Rect2i(40, 250, 300, 30)),
		_grass.get("ground_paint"), _grass.get("ground_glow"), _grass.get("enabled"), ground.mesh.get_class()])
	_step += 1
	if _step >= STEPS.size():
		print("TOGGLES DONE")
		if FileAccess.file_exists("user://lookout_journal_toggles_test.cfg"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_toggles_test.cfg"))
		return true
	for press in STEPS[_step][1]:
		_press(press[0])
	_wait = 1.2
	return false


func _press(modifier: String) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_O
	e.physical_keycode = KEY_O
	e.shift_pressed = modifier == "shift"
	e.ctrl_pressed = modifier == "ctrl"
	e.alt_pressed = modifier == "alt"
	e.pressed = true
	Input.parse_input_event(e)
	var up: InputEventKey = e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _mean(image: Image, r: Rect2i) -> String:
	var sum := Vector3.ZERO
	var n: int = 0
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			var c: Color = image.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	sum = sum / float(maxi(n, 1)) * 255.0
	return "(%3d, %3d, %3d)" % [roundi(sum.x), roundi(sum.y), roundi(sum.z)]
