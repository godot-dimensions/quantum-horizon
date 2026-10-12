extends SceneTree

## The pen's sandy yard (Ramon, 3 Oct: "the sand in the pen is not slightly yellow, its grey
## now?"): what the painter got (which sand patches, the colours it painted with), and the yard
## seen from above with the paint layer on and with the pen's own ground, sampled at the middle of
## the pen. Saves res://smoke_test_output/yard_<what>.png.
##
##   godot... --path project --windowed --resolution 960x540 --position 40,40
##       --script res://ramon/chickenpen/grass/_probe_yard_runner.gd

var _room: Node
var _grass: Node
var _cam: Camera4D
var _t: float = 0.0
var _step: int = -1


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _sample(what: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png("res://smoke_test_output/yard_%s.png" % what)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var out: Array = []
	for p in [Vector2i(w / 2, h / 2), Vector2i(w / 2 - 60, h / 2 + 40), Vector2i(w / 2 + 70, h / 2 - 30)]:
		var c: Color = img.get_pixelv(p)
		out.append("(%d, %d, %d)" % [roundi(c.r * 255), roundi(c.g * 255), roundi(c.b * 255)])
	print("      %-10s yard pixels %s" % [what, ", ".join(out)])


func _process(d: float) -> bool:
	_t += d
	if _t > 60.0:
		print("YARD FAIL: timed out")
		return true
	match _step:
		-1:
			_grass = _room.get_node_or_null("World/Grass")
			if not bool(_grass.get("mask_ready")) or _t < 9.0:
				return false
			var cells: Dictionary = _grass.get("_sand_cells")
			print("      sand patches found: %s" % str(cells.keys()))
			for k in cells:
				print("        %s: %d cells, w %s" % [k, (cells[k]["cells"] as Array).size(), str([cells[k].get("w0"), cells[k].get("w1")])])
			print("      outlines: %s" % str((_grass.get("_outlines") as Dictionary).keys()))
			print("      clearing_fill %s, sand_round %s, ground_paint %s" % [str(_grass.get("clearing_fill")), str(_grass.get("sand_round")), str(_grass.get("ground_paint"))])
			print("      sand colour %s painted as %s" % [str(_grass.get("sand_colour")), str(_grass.call("_paint_adjust", _grass.get("sand_colour")))])
			var ground := _room.get_node(_grass.get("ground_path")) as MeshInstance4D
			print("      ground material %s" % str(ground.material_override))
			_grass.visible = false
			for c in _room.get_node("UI").get_children():
				if c is CanvasItem:
					(c as CanvasItem).visible = false
			_cam = Camera4D.new()
			_cam.set("rendering_engine_name", "Cross-section")
			_room.add_child(_cam)
			var pen: Vector4 = (_room.get_node("Pen/Fence") as Node4D).global_position
			_cam.global_position = pen + Vector4(0.0, 9.0, 3.0, 0.0)
			_cam.look_at(pen + Vector4(0.0, 0.0, 0.5, 0.0))
			_cam.make_current()
			_step = 0
			_t = 0.0
		0:
			if _t < 1.0:
				return false
			_sample("painted")
			# The pen's own ground, as the panel's Base color does.
			_grass.set("ground_paint", false)
			if _grass.has_method("_apply_ground"):
				_grass.call("_apply_ground")
			_step = 1
			_t = 0.0
		1:
			if _t < 1.0:
				return false
			_sample("own")
			# And the sky fill off, to see what the teal light does to the sand.
			_grass.set("ground_paint", true)
			if _grass.has_method("_apply_ground"):
				_grass.call("_apply_ground")
			(_room.get_node("World/SkyFill") as Node4D).visible = false
			_step = 2
			_t = 0.0
		2:
			if _t < 1.0:
				return false
			_sample("no_skyfill")
			print("YARD DONE")
			return true
	return false
