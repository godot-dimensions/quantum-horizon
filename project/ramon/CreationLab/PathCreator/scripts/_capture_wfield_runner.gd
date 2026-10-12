extends SceneTree

## PathCreator's W field (graphs/wfield.tres, PLAN.md part F): the five stations from straight above
## with the slice at W 0, 1, 2, 3 and 4, one picture each, laid out as a contact sheet (station across,
## W down), and each station from the player's height at W 0 and at W 4. To
## res://smoke_test_output/pathcreator/wfield/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_wfield res://ramon/CreationLab/PathCreator/scripts/_capture_wfield_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/wfield/"
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")
const STATIONS := [[-16.0, "A"], [-8.0, "B"], [0.0, "C"], [8.0, "D"], [16.0, "E"]]
const WS := [0.0, 1.0, 2.0, 3.0, 4.0]

var _g: Node
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


func _grab() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(3.5)
	var net: Node = _g.get_node("WFieldNetwork")
	print("W field notes: ", net.call("notes"))
	_check((net.call("notes") as PackedStringArray).is_empty(), "the W field graph is sound")
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	(_g.get("player") as Node4D).visible = false
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(_cam)
	_cam.current = true
	# From above: every station at every W, each tile its own station's 8 m (x-2.5..x+5.5, z 9..39).
	var ortho: float = 30.0
	var tile := Vector2i(0, 0)
	var sheet: Image = null
	for wi in WS.size():
		for si in STATIONS.size():
			var x: float = float(STATIONS[si][0])
			_cam.set("projection_type", 0)
			_cam.set("orthographic_size", ortho)
			_cam.global_position = Vector4(x + 1.5, 30.0, 24.0, float(WS[wi]))
			_cam.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
			var img: Image = await _grab()
			var ppm: float = float(img.get_height()) / ortho
			var w_px: int = int(8.0 * ppm)
			if sheet == null:
				tile = Vector2i(w_px, img.get_height())
				sheet = Image.create_empty(tile.x * STATIONS.size() + 4 * (STATIONS.size() - 1), tile.y * WS.size() + 4 * (WS.size() - 1), false, Image.FORMAT_RGB8)
				sheet.fill(Color(0.08, 0.09, 0.12))
			var strip: Image = img.get_region(Rect2i(img.get_width() / 2 - w_px / 2, 0, w_px, img.get_height()))
			sheet.blit_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()), Vector2i(si * (tile.x + 4), wi * (tile.y + 4)))
	sheet.save_png(OUT + "stations_by_w.png")
	print("saved stations_by_w (stations A-E across, W 0-4 down)")
	# From the player's height, at W 0 and W 4.
	for st in STATIONS:
		for w in [0.0, 4.0]:
			_cam.set("projection_type", 1)
			var x: float = float(st[0])
			_cam.global_position = Vector4(x, 2.6, 9.0, w)
			_cam.global_basis = Mark.basis_looking(_cam.global_position, Vector4(x + 1.5, 0.0, 24.0, w))
			var img2: Image = await _grab()
			img2.save_png(OUT + "station_%s_w%d.png" % [String(st[1]).to_lower(), int(w)])
	# Close, straight down: the ladder's first step at W 0 and W 1, station B's arrival at W 0 and W 4 (the W cue).
	for close in [["cue_ladder_w0", 16.0, 17.0, 0.0], ["cue_ladder_w1", 16.0, 17.0, 1.0], ["cue_b_arrival_w0", -5.0, 34.0, 0.0], ["cue_b_arrival_w4", -5.0, 34.0, 4.0]]:
		_cam.set("projection_type", 0)
		_cam.set("orthographic_size", 4.0)
		_cam.global_position = Vector4(float(close[1]), 30.0, float(close[2]), float(close[3]))
		_cam.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
		var ci: Image = await _grab()
		ci.save_png(OUT + String(close[0]) + ".png")
	print("WFIELD %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
