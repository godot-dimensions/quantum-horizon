extends SceneTree

## The leaves and bits on the wind (pen_wind_bits.gdshader): from a still camera looking across
## the field and up a little, at the wind scale 0 (calm), 1 (the look's own) and 2.5 (a gale),
## two frames half a second apart at each (they should move), and how many are up. Gives up
## after 90 s. Saves res://smoke_test_output/leaves_<scale>_<a|b>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/grass/_leaves_runner.gd

const SCALES := [0.0, 1.0, 2.5]

var _room: Node
var _grass: Node
var _cam: Camera4D
var _t: float = 0.0
var _step: int = -1
var _wait: float = 0.0
var _shot: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_leaves_test.cfg")
	_grass = _room.get_node("World/Grass")
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	if _t > 120.0:
		print("LEAVES FAIL: timed out")
		return true
	if _step < 0:
		if not bool(_grass.get("mask_ready")) or _t < 5.0:
			return false
		if _t < 90.0 and _t > 89.0:
			print("LEAVES FAIL: no grass")
			return true
		for child in _room.get_node("UI").get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_cam.set("field_of_view_4d", 1.1)
		_room.add_child(_cam)
		_cam.make_current()
		var eye := Vector4(6.0, 1.6, 10.0, 0.0)
		var at := Vector4(-10.0, 4.0, -6.0, 0.0)
		_cam.global_position = eye
		var dd: Vector4 = at - eye
		_cam.global_basis = Basis4D.from_zx(atan2(-dd.x, -dd.z)) * Basis4D.from_yz(atan2(dd.y, Vector2(dd.x, dd.z).length()))
		_step = 0
		_grass.set("wind_scale", SCALES[0])
		_wait = 4.0
		_shot = 0
		return false
	_wait -= d
	if _wait > 0.0:
		return false
	var scale: float = SCALES[_step]
	var tag: String = "a" if _shot == 0 else "b"
	root.get_texture().get_image().save_png("res://smoke_test_output/leaves_%.1f_%s.png" % [scale, tag])
	if _shot == 0:
		print("      wind x%.1f: %d leaves and bits up" % [scale, int(_grass.call("bits_count"))])
		_shot = 1
		_wait = 0.5
		return false
	_shot = 0
	_step += 1
	if _step >= SCALES.size():
		print("LEAVES DONE")
		if FileAccess.file_exists("user://lookout_journal_leaves_test.cfg"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_leaves_test.cfg"))
		return true
	_grass.set("wind_scale", SCALES[_step])
	_wait = 4.0
	return false
