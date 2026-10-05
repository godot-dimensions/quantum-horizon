extends SceneTree

## PathCreator, step 35: the vector shader against an independent renderer of the same Figma
## vectors. Each symbol master (sets/<lib>/<slot>.svg) is rasterised by Godot's own SVG renderer at
## 4 px a sheet unit, and drawn by our shader on the floor under a camera straight down at exactly
## 4 px a unit; the two ink masks are compared (intersection over union) and laid side by side with
## their difference. Motion is held still so the arcs sit where the sheet draws them. To
## res://smoke_test_output/pathcreator/overlay/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_overlay res://ramon/CreationLab/PathCreator/scripts/_probe_overlay_runner.gd [-- 06]

const Draw := preload("res://ramon/CreationLab/PathCreator/render/path_draw.gd")
const Spec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const Env := preload("res://ramon/CreationLab/PathCreator/path_environment.gd")
const Room := preload("res://ramon/CreationLab/LabKit/lab_room_4d.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const OUT := "res://smoke_test_output/pathcreator/overlay/"
const PX := 4.0

var _fails: Array = []


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var lib: String = args[0] if args.size() > 0 else "07"
	var r := Node4D.new()
	root.add_child(r)
	var room := Node4D.new()
	room.set_script(Room)
	room.set("mood_overrides", Env.mood_overrides())
	r.add_child(room)
	var floor_col := Color(0.96, 0.965, 0.97)
	# A plain floor (no grid lines) under the symbols.
	LabGrid.set_swatch("pc_plain", floor_col, floor_col, floor_col, 0.0)
	var fsize := Vector4(30, 0.5, 30, 10)
	var floor := MeshInstance4D.new()
	floor.mesh = Mats.box_mesh(fsize)
	floor.material_override = LabGrid.material("pc_plain", fsize, Vector4(0, -0.25, 0, 0))
	floor.position = Vector4(0, -0.25, 0, 0)
	r.add_child(floor)
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("projection_type", 0)
	r.add_child(cam)
	cam.current = true
	await _wait(1.0)
	var vh: float = float(root.get_texture().get_height())
	cam.set("orthographic_size", vh / PX * Spec.UNIT_M)
	cam.global_position = Vector4(0, 10, 0, 0)
	cam.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
	var report: PackedStringArray = PackedStringArray()
	for slot in Spec.SLOTS:
		var svg_path: String = "res://ramon/CreationLab/PathCreator/sets/%s/%s.svg" % [lib, slot]
		if not FileAccess.file_exists(svg_path):
			continue
		var id: int = Draw.sym(lib, slot)
		var sz: Vector2 = Draw.sym_size(id)
		var b: MeshInstance4D = Draw.box(r, "Sym", Draw.NODE, Vector4(sz.x * Spec.UNIT_M + 0.2, 0.01, sz.y * Spec.UNIT_M + 0.2, 4.0), Vector4(0, 0.012, 0, 0))
		Draw.set_param(b, "node_sym", id)
		Draw.set_param(b, "under_color", floor_col)
		Draw.set_param(b, "motion", 0.0)
		Draw.set_param(b, "arc_on", 1.0 if slot in ["E", "F"] else 0.0)
		Draw.set_param(b, "accent_on", 1.0 if slot in ["E", "F"] else 0.0)
		Draw.set_param(b, "focus", 1.0 if slot == "F" else 0.0)
		await _wait(0.4)
		await RenderingServer.frame_post_draw
		var shot: Image = root.get_texture().get_image()
		# The floor as it is lit, read where nothing is drawn: ink is what differs from it.
		var lit_floor: Color = shot.get_pixel(8, 8)
		var w: int = int(round(sz.x * PX))
		var h: int = int(round(sz.y * PX))
		var c := Vector2i(shot.get_width() / 2, shot.get_height() / 2)
		var ours: Image = shot.get_region(Rect2i(c.x - w / 2, c.y - h / 2, w, h))
		# The reference: the same SVG through Godot's SVG renderer at 4 px a unit.
		var ref := Image.new()
		ref.load_svg_from_string(FileAccess.get_file_as_string(svg_path), PX)
		ref.convert(Image.FORMAT_RGBA8)
		var inter: int = 0
		var uni: int = 0
		var diff := Image.create_empty(w * 3, h, false, Image.FORMAT_RGB8)
		diff.fill(Color(1, 1, 1))
		for y in h:
			for x in w:
				var oc: Color = ours.get_pixel(x, y)
				var ink_o: bool = Vector3(oc.r - lit_floor.r, oc.g - lit_floor.g, oc.b - lit_floor.b).length() > 0.25
				var rp: Color = ref.get_pixel(x, y) if x < ref.get_width() and y < ref.get_height() else Color(0, 0, 0, 0)
				# Ink is what is not the floor: a floor-coloured fill (a hollow node) is floor.
				var ink_r: bool = rp.a > 0.5 and Vector3(rp.r - 0.843, rp.g - 0.890, rp.b - 0.937).length() > 0.12
				if ink_o and ink_r:
					inter += 1
				if ink_o or ink_r:
					uni += 1
				diff.set_pixel(x, y, oc)
				if x < ref.get_width() and y < ref.get_height():
					var rc: Color = ref.get_pixel(x, y)
					diff.set_pixel(w + x, y, Color(1, 1, 1).lerp(Color(rc.r, rc.g, rc.b), rc.a))
				diff.set_pixel(w * 2 + x, y, Color(0.2, 0.2, 0.2) if ink_o and ink_r else (Color(0.9, 0.2, 0.2) if ink_o else (Color(0.2, 0.4, 0.95) if ink_r else Color(1, 1, 1))))
		var iou: float = float(inter) / float(maxi(uni, 1))
		diff.save_png(OUT + "%s_%s.png" % [lib, slot])
		report.append("%s/%s  %dx%d px  IoU %.3f" % [lib, slot, w, h, iou])
		if iou < 0.85:
			_fails.append("%s/%s IoU %.3f" % [lib, slot, iou])
		b.free()
	for line in report:
		print(line)
	print("(ours | the SVG renderer's | both dark, ours only red, the reference only blue)")
	print("OVERLAY %s: %d below 0.85" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
