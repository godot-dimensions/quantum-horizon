extends SceneTree

## Do Hay meadow II's big gusts happen, and do they show? The look is put on, the shader's big
## gust numbers read back, every other wind switched off on the materials (no breeze, gusts or
## waves), so the big gusts are the only thing that can move the grass; then the near field's
## brightness is printed four times a second for 45 s from a still camera. Spikes are big gusts.
## Gives up after 90 s.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/grass/_big_gust_runner.gd

var _room: Node
var _grass: Node
var _cam: Camera4D
var _t: float = 0.0
var _rec: float = -1.0
var _next: float = 0.0
var _line: String = ""
var _peak: float = 0.0
var _low: float = 999.0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_gust_test.cfg")
	_grass = _room.get_node("World/Grass")
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	if _t > 90.0 and _rec < 0.0:
		print("BIG GUST FAIL: no grass")
		return true
	if _rec < 0.0:
		if not bool(_grass.get("mask_ready")) or _t < 5.0:
			return false
		_grass.call("apply_preset", 3)
		for child in _room.get_node("UI").get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
		var bands: Array = _grass.get("_bands")
		var m: ShaderMaterial = bands[0].material
		print("      shader: big_gust_strength %s, every %s, chance %s, width %s, speed %s, lean %s" % [m.get_shader_parameter("big_gust_strength"),
			m.get_shader_parameter("big_gust_every"), m.get_shader_parameter("big_gust_chance"), m.get_shader_parameter("big_gust_width"),
			m.get_shader_parameter("big_gust_speed"), m.get_shader_parameter("big_gust_lean")])
		for band in bands:
			var mat: ShaderMaterial = band.material
			mat.set_shader_parameter("wind_speed", 0.0)
			mat.set_shader_parameter("gustiness", 0.0)
			mat.set_shader_parameter("wave_strength", 0.0)
			for arg in OS.get_cmdline_user_args():
				var kv: PackedStringArray = arg.split("=", true, 1)
				if kv.size() == 2:
					mat.set_shader_parameter(kv[0], float(kv[1]))
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_cam.set("field_of_view_4d", 1.0)
		_room.add_child(_cam)
		_cam.make_current()
		var eye := Vector4(8.0, 2.0, 12.0, 0.0)
		var at := Vector4(-6.0, 0.0, -2.0, 0.0)
		_cam.global_position = eye
		var dd: Vector4 = at - eye
		_cam.global_basis = Basis4D.from_zx(atan2(-dd.x, -dd.z)) * Basis4D.from_yz(atan2(dd.y, Vector2(dd.x, dd.z).length()))
		_rec = 0.0
		_next = 1.0
		return false
	_rec += d
	if _rec >= _next:
		_next += 0.25
		var image: Image = root.get_texture().get_image()
		var sum: float = 0.0
		var n: int = 0
		for y in range(400, 720, 8):
			for x in range(0, 1280, 8):
				sum += image.get_pixel(x, y).get_luminance()
				n += 1
		var v: float = sum / float(n) * 255.0
		_peak = maxf(_peak, v)
		_low = minf(_low, v)
		_line += "%5.1f" % v
	if _rec > 46.0:
		print("      near-field brightness, 4 a second, from 1 s: ", _line)
		print("      lowest %.1f, highest %.1f: %s" % [_low, _peak, "big gusts seen" if _peak - _low > 6.0 else "NO big gust seen"])
		print("BIG GUST DONE")
		return true
	return false
