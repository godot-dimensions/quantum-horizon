extends SceneTree

## Frames of the grass, for judging it by eye: the farm camera as you play, low across the
## field into the sun, a wide view, the wind over six frames, a step through W, the marsh and
## the tower's foot (where the mask should leave bare ground), then from high above the player
## (the near ring should be a disc round them). Prints the blade count and the
## mask's numbers. Saves res://smoke_test_output/grass_<n>_<view>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/grass/_capture_grass_runner.gd

var _room: Node
var _grass: Node4D
var _cam: Camera4D
var _t: float = 0.0
var _step: int = 0
var _wait: float = 0.0
var _n: int = 0
var _shots: Array = []


## After "--": tag=<name> prefixes the frames' names; any other key=value is set on the Grass
## node before it is ready (numbers, or colours as r,g,b), for A/B looks.
var _tag: String = ""


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_grass_test.cfg")
	var grass: Node = _room.get_node("World/Grass")
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		if kv.size() != 2:
			continue
		if kv[0] == "tag":
			_tag = kv[1] + "_"
		elif kv[1].count(",") == 2:
			var c: PackedFloat64Array = kv[1].split_floats(",")
			grass.set(kv[0], Color(c[0], c[1], c[2]))
		else:
			grass.set(kv[0], float(kv[1]))
		print("      grass.%s = %s" % [kv[0], kv[1]])
	root.add_child(_room)
	current_scene = _room


func _save(view: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/grass_%s%d_%s.png" % [_tag, _n, view])
	_n += 1


func _look(eye: Vector4, at: Vector4) -> void:
	if _cam == null:
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_cam.set("field_of_view_4d", 1.0)
		_room.add_child(_cam)
	_cam.make_current()
	_cam.global_position = eye
	var d: Vector4 = at - eye
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))


func _hide_hud() -> void:
	for child in _room.get_node("UI").get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false


func _next(after: float) -> void:
	_step += 1
	_wait = after
	_t = 0.0


func _process(d: float) -> bool:
	_t += d
	if _t < _wait:
		return false
	match _step:
		0:
			_grass = _room.get_node("World/Grass")
			if not bool(_grass.get("mask_ready")) and _t < 20.0:
				return false
			print("      grass: %d blades in view, mask %d cells marked in %d ms, script %d us a frame" % [int(_grass.call("blade_count")), int(_grass.get("mask_cells")),
				int(_grass.get("mask_msec")), int(_grass.get("prerender_usec"))])
			print("      clearings: %d cells, %d ms" % [int(_grass.get("clearing_cells")), int(_grass.get("clearing_msec"))])
			for row in _grass.call("band_report"):
				print("        band %4.1f-%4.1f m: gap %.3f m, %d cells a side a tile (%.2f m), %d vertices, %d tiles in view" % row)
			for f in ["approached", "met_wren"]:
				_room.get_node("Systems/Lookout").get("journal").call("set_flag", f, true)
			_hide_hud()
			_next(1.0)
		1:
			_save("farm_camera")
			_look(Vector4(4.0, 0.55, 8.0, 0.0), Vector4(-6.0, 0.35, -8.0, 0.0))
			_next(0.5)
		2:
			_save("low_across")
			_look(Vector4(2.0, 1.7, 6.0, 0.0), Vector4(-2.0, 0.0, -2.0, 0.0))
			_next(0.5)
		3:
			_save("standing_look_down")
			_look(Vector4(10.0, 7.0, 18.0, 0.0), Vector4(-6.0, 0.0, -10.0, 0.0))
			_next(0.5)
		4:
			_save("wide")
			_look(Vector4(4.0, 1.2, 8.0, 0.0), Vector4(-8.0, 0.2, -4.0, 0.0))
			_next(0.4)
		5, 6, 7, 8, 9, 10:
			_save("wind_%d" % (_step - 5))
			_next(0.35)
		11:
			# A step through W, the same view: the grass round you shrinks and the next grows.
			_look(Vector4(2.0, 1.0, 5.0, 0.12), Vector4(-2.0, 0.1, 0.0, 0.12))
			_next(0.3)
		12:
			_save("w_plus_012")
			_look(Vector4(2.0, 1.0, 5.0, 0.0), Vector4(-2.0, 0.1, 0.0, 0.0))
			_next(0.3)
		13:
			_save("w_0")
			var tower: Node4D = _room.get_node("World/LookoutSite/Lookout")
			var t: Vector4 = tower.global_position
			_look(t + Vector4(7.0, 2.2, 9.0, 0.0), t + Vector4(1.5, 0.3, 1.5, 0.0))
			_next(0.5)
		14:
			_save("tower_foot")
			var marsh: Node4D = _room.get_node("World/AnaMarsh")
			var m: Vector4 = marsh.global_position
			_look(m + Vector4(10.0, 2.0, 7.0, 0.0), m + Vector4(0.0, 0.2, 0.0, 0.0))
			_next(0.6)
		15:
			_save("marsh")
			var shed: Node4D = _room.get_node_or_null("World/TrymCabin/Shed")
			if shed != null:
				var s: Vector4 = shed.global_position
				_look(s + Vector4(4.0, 1.6, 5.0, 0.0), s + Vector4(0.0, 0.5, 0.0, 0.0))
			_next(0.5)
		16:
			_save("shed")
			var wood: Node4D = _room.get_node("World/KataWood")
			var w: Vector4 = wood.global_position
			_look(w + Vector4(6.0, 1.6, 7.0, 0.0), w + Vector4(0.0, 0.8, 0.0, 0.0))
			_next(0.6)
		17:
			_save("kata_wood")
			# From high above the player, on a camera that is the player's own (a child of it, as
			# the farm camera is): the near ring should be a disc round them.
			var top := Camera4D.new()
			top.set("rendering_engine_name", "Cross-section")
			top.set("field_of_view_4d", 1.0)
			_room.get_node("Player").add_child(top)
			top.make_current()
			top.global_position = (_room.get_node("Player") as Node4D).global_position + Vector4(0.0, 34.0, 14.0, 0.0)
			top.global_basis = Basis4D.from_yz(-1.18)
			_next(0.8)
		18:
			_save("above_player")
			# Into the low sun (it is in the +x, 14 degrees up): where the tips should glow.
			_look(Vector4(-8.0, 1.1, 3.0, 0.0), Vector4(8.0, 0.4, 5.0, 0.0))
			_next(0.6)
		19:
			_save("into_sun")
			print("GRASS CAPTURE DONE")
			if FileAccess.file_exists("user://lookout_journal_grass_test.cfg"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_grass_test.cfg"))
			return true
	return false
