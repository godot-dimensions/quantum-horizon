extends SceneTree

## PathCreator probes (PLAN.md steps 3-5 and 8, and the first look at library 07):
##   - library 07's nine masters read, flattened and packed (counts printed)
##   - every symbol laid on a white floor, photographed from straight above at the sheet's scale
##   - close up: a primary mark from a metre, to see that the vectors stay sharp
##   - W: a route box with a narrow W band, the slice at W 0, at the band's soft edge and beyond it
##     (local_pos.w reaching the fragment); a W-sheared box climbing from W -2 to +2 seen at three W
##     (the "follow" mode's slanted band)
##   - cost: the frame with the symbols on screen against the same view without them
## To res://smoke_test_output/pathcreator/probe/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_probe res://ramon/CreationLab/PathCreator/scripts/_probe_symbols_runner.gd

const Draw := preload("res://ramon/CreationLab/PathCreator/render/path_draw.gd")
const Spec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const Room := preload("res://ramon/CreationLab/LabKit/lab_room_4d.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const OUT := "res://smoke_test_output/pathcreator/probe/"

var _root: Node4D
var _cam: Camera4D
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


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _shot(what: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


func _top(cx: float, cz: float, height_m: float, w: float = 0.0) -> void:
	_cam.set("projection_type", 0)
	_cam.set("orthographic_size", height_m)
	_cam.global_position = Vector4(cx, 20.0, cz, w)
	_cam.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))


func _run() -> void:
	var t0: int = Time.get_ticks_usec()
	var packed: Dictionary = Draw.symbols()
	print("packed in %.1f ms: segments, shapes, symbols = %s" % [float(Time.get_ticks_usec() - t0) / 1000.0, str(packed["counts"])])
	print("ids: ", packed["ids"])
	_check(Draw.sym("07", "A") >= 0 and Draw.sym("07", "I") >= 0, "library 07 read, A to I")
	_root = Node4D.new()
	root.add_child(_root)
	var room := Node4D.new()
	room.set_script(Room)
	room.set("start_mood", "bright")
	_root.add_child(room)
	# The white walkplane.
	LabGrid.set_swatch("pc_floor", Color(0.96, 0.965, 0.97), Color(0.86, 0.87, 0.89), Color(0.92, 0.925, 0.93), 1.0)
	var floor := MeshInstance4D.new()
	var fsize := Vector4(60, 0.5, 60, Spec.W_REACH * 2.0)
	floor.mesh = preload("res://ramon/CreationLab/LabKit/lab_materials.gd").box_mesh(fsize)
	floor.material_override = LabGrid.material("pc_floor", fsize, Vector4(0, -0.25, 0, 0))
	floor.position = Vector4(0, -0.25, 0, 0)
	_root.add_child(floor)
	var under := Color(0.96, 0.965, 0.97)
	var y: float = Spec.PROUD_M
	var h: float = Spec.BOX_H_M
	var deep: float = Spec.W_REACH * 2.0
	# The destination states, the junction, the frames: one box each, in a row.
	var x: float = -6.0
	for slot in ["D", "E", "F", "G", "C"]:
		var sz: Vector2 = Draw.sym_size(Draw.sym("07", slot)) * Spec.UNIT_M
		var b: MeshInstance4D = Draw.box(_root, "Sym" + slot, Draw.NODE, Vector4(sz.x + 0.1, h, sz.y + 0.1, deep), Vector4(x, y, -2.0, 0))
		Draw.set_param(b, "node_sym", Draw.sym("07", slot))
		Draw.set_param(b, "under_color", under)
		Draw.set_param(b, "focus", 1.0 if slot == "F" else 0.0)
		Draw.set_param(b, "arc_on", 1.0 if slot in ["E", "F"] else 0.0)
		x += 2.0
	# Pivots: a bend's ball and ring, a curve's small ball.
	for i in 2:
		var pb: MeshInstance4D = Draw.box(_root, "Pivot%d" % i, Draw.PIVOT, Vector4(0.4, h, 0.4, deep), Vector4(-6.0 + float(i) * 1.0, y, 0.6, 0))
		Draw.set_param(pb, "ring_on", 1.0 if i == 0 else 0.0)
		Draw.set_param(pb, "ball_r", Spec.BEND_BALL_R * Spec.UNIT_M if i == 0 else Spec.CHORD_BALL_R * Spec.UNIT_M)
		Draw.set_param(pb, "ring_r", Spec.BEND_RING_R * Spec.UNIT_M)
		Draw.set_param(pb, "ring_w", Spec.BEND_RING_W * Spec.UNIT_M)
		Draw.set_param(pb, "under_color", under)
	# A frame grown round a 4 x 3 m footprint, its opening toward +z.
	var hs: Vector2 = Draw.sym_size(Draw.sym("07", "H"))
	var foot := Vector2(4.0, 3.0)
	var fb: MeshInstance4D = Draw.box(_root, "FrameH", Draw.FRAME, Vector4(foot.x + 0.4, h, foot.y + 0.4, deep), Vector4(4.0, y, 1.0, 0))
	Draw.set_param(fb, "frame_sym", Draw.sym("07", "H"))
	Draw.set_param(fb, "frame_grow", (foot / Spec.UNIT_M - hs) * 0.5)
	Draw.set_param(fb, "approach", Vector3(0.0, 1.0, 1.2 / Spec.UNIT_M))
	Draw.set_param(fb, "under_color", under)
	# Two routes: primary (A) and secondary (B), 8 m each, ending short of their pivots.
	for i in 2:
		var slot: String = "A" if i == 0 else "B"
		var sb: MeshInstance4D = Draw.box(_root, "Route" + slot, Draw.SEGMENT, Vector4(8.0, h, 0.8, deep), Vector4(-2.0, y, 3.0 + float(i) * 1.2, 0))
		Draw.set_param(sb, "mark_sym", Draw.sym("07", slot))
		Draw.set_param(sb, "repeat_m", Spec.PRIMARY_REPEAT_M if i == 0 else Spec.SECONDARY_REPEAT_M)
		Draw.set_param(sb, "clear0", 0.3)
		Draw.set_param(sb, "clear1", 0.3)
		Draw.set_param(sb, "under_color", under)
	# W: a narrow band (1 m deep) at W 0, and a box climbing from W -2 to +2 over 10 m.
	var nb: MeshInstance4D = Draw.box(_root, "BandRoute", Draw.SEGMENT, Vector4(8.0, h, 0.8, 1.0), Vector4(-2.0, y, 6.0, 0))
	Draw.set_param(nb, "mark_sym", Draw.sym("07", "A"))
	Draw.set_param(nb, "under_color", under)
	var shear := Projection(Vector4(1, 0, 0, 0.4), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	var cb: MeshInstance4D = Draw.box(_root, "ClimbRoute", Draw.SEGMENT, Vector4(10.0, h, 0.8, 0.8), Vector4(-1.0, y, 7.4, 0), shear)
	Draw.set_param(cb, "mark_sym", Draw.sym("07", "A"))
	Draw.set_param(cb, "under_color", under)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_root.add_child(_cam)
	_cam.current = true
	await _wait(1.5)
	# From above, the whole sheet.
	_top(-1.0, 3.0, 12.0)
	await _wait(0.5)
	await _shot("top_all")
	_top(-4.0, -2.0, 3.0)
	await _wait(0.3)
	await _shot("top_states")
	# Close up, perspective: a metre above the primary route, looking down at it.
	_cam.set("projection_type", 1)
	_cam.global_position = Vector4(-2.0, 0.9, 3.9, 0)
	_cam.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0.5, -0.866, 0), Vector4(0, 0.866, 0.5, 0), Vector4(0, 0, 0, 1))
	await _wait(0.3)
	await _shot("close_primary")
	# W: the slice at 0, at the band's soft edge, beyond it; the climbing route at three W.
	for w in [0.0, 0.42, 0.7, -1.5, 1.5]:
		_top(-1.0, 6.7, 4.0, w)
		await _wait(0.3)
		await _shot("w_%+.2f" % w)
	# Cost: the same overhead view with every path box hidden, then shown.
	_top(-1.0, 3.0, 12.0)
	var boxes: Array = []
	for c in _root.get_children():
		if c is MeshInstance4D and c != floor:
			boxes.append(c)
	var with_ms: float = await _frame_ms(true, boxes)
	var without_ms: float = await _frame_ms(false, boxes)
	print("frame with the symbols %.3f ms, without %.3f ms (%d boxes)" % [with_ms, without_ms, boxes.size()])
	print("PROBE %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _frame_ms(show: bool, boxes: Array) -> float:
	for b in boxes:
		(b as Node4D).visible = show
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _wait(0.5)
	var n: int = 0
	var t0: int = Time.get_ticks_usec()
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		n += 1
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(maxi(n, 1))
