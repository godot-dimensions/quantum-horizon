extends SceneTree

## PathCreator's W field under a tilted slice (PLAN.md steps 62, 64 and 66): the pen turns the slice
## into W with the right mouse rather than walking through it, so the same five stations are shot
## from above with the slice tilted, not moved. The slice pivots where each route starts (W 0 at
## z 12), as the pen's rig pivots it on the player. Tilts, one row each:
##   flat; 5° along the route (zw); the tilt that matches the routes' climb (W 0 to 4 over 22 m,
##   10.3°); 20° along; 15° across the route (xw).
## Ink is counted in three stretches of each route (z 12-19, 19-26, 26-34) so the notes rest on
## numbers, and the player's view of stations B and C at flat and matched is saved beside the sheet.
## To res://smoke_test_output/pathcreator/tilt/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_tilt res://ramon/CreationLab/PathCreator/scripts/_capture_tilt_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/tilt/"
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")
const STATIONS := [[-16.0, "A"], [-8.0, "B"], [0.0, "C"], [8.0, "D"], [16.0, "E"]]
## The routes climb W 0 to 4 between z 12 and z 34.
const MATCHED := 10.305
const TILTS := [["flat", "zw", 0.0], ["along 5", "zw", 5.0], ["matched 10.3", "zw", MATCHED], ["along 20", "zw", 20.0], ["across 15", "xw", 15.0]]
const STRETCHES := [[12.0, 19.0], [19.0, 26.0], [26.0, 34.0]]
const TOP := Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))

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


## `basis` tilted by `deg` in the world's zw or xw plane, the way the pen's rig does it (the slice
## rotations outermost), signed so the slice's W rises along +z (zw) or +x (xw).
func _tilted(basis: Projection, plane: String, deg: float) -> Projection:
	if is_zero_approx(deg):
		return basis
	for sgn in [1.0, -1.0]:
		var r: Projection = (Basis4D.from_zw(deg_to_rad(deg) * sgn) if plane == "zw" else Basis4D.from_xw(deg_to_rad(deg) * sgn)) * basis
		var n: Vector4 = r.w
		var rise: float = -(n.z if plane == "zw" else n.x) / n.w
		if rise > 0.0:
			return r
	return basis


## The camera's W that puts the slice through `pivot`, the camera at `at` (xyz) with basis `r`.
func _w_through(at: Vector4, r: Projection, pivot: Vector4) -> float:
	var n: Vector4 = r.w
	var d := Vector3(pivot.x - at.x, pivot.y - at.y, pivot.z - at.z)
	return pivot.w + (n.x * d.x + n.y * d.y + n.z * d.z) / n.w


static func _ink(c: Color) -> bool:
	return c.r < 0.4 and c.b > 0.6 and c.b - c.r > 0.35


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(3.5)
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	(_g.get("player") as Node4D).visible = false
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(_cam)
	_cam.current = true
	var ortho: float = 30.0
	var tile := Vector2i.ZERO
	var sheet: Image = null
	## ink[tilt][station] = [stretch 1, 2, 3] counts.
	var ink: Dictionary = {}
	for ti in TILTS.size():
		var tname: String = TILTS[ti][0]
		ink[tname] = {}
		for si in STATIONS.size():
			var x: float = float(STATIONS[si][0])
			var r: Projection = _tilted(TOP, String(TILTS[ti][1]), float(TILTS[ti][2]))
			var at := Vector4(x + 1.5, 30.0, 24.0, 0.0)
			var pivot := Vector4(x + 1.5, 0.0, 12.0, 0.0) if String(TILTS[ti][1]) == "zw" else Vector4(x + 1.5, 0.0, 24.0, 0.0)
			at.w = _w_through(at, r, pivot)
			_cam.set("projection_type", 0)
			_cam.set("orthographic_size", ortho)
			_cam.global_position = at
			_cam.global_basis = r
			var img: Image = await _grab()
			var ppm: float = float(img.get_height()) / ortho
			var w_px: int = int(8.0 * ppm)
			if sheet == null:
				tile = Vector2i(w_px, img.get_height())
				sheet = Image.create_empty(tile.x * STATIONS.size() + 4 * (STATIONS.size() - 1), tile.y * TILTS.size() + 4 * (TILTS.size() - 1), false, Image.FORMAT_RGB8)
				sheet.fill(Color(0.08, 0.09, 0.12))
			var strip: Image = img.get_region(Rect2i(img.get_width() / 2 - w_px / 2, 0, w_px, img.get_height()))
			strip.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()), Vector2i(si * (tile.x + 4), ti * (tile.y + 4)))
			# Ink per stretch. A zw tilt stretches the image along z by 1 / cos.
			var cosf_: float = cos(deg_to_rad(float(TILTS[ti][2]))) if String(TILTS[ti][1]) == "zw" else 1.0
			var counts: Array = []
			for st in STRETCHES:
				var n_ink: int = 0
				var r0: int = int((float(st[0]) - 24.0) / cosf_ * ppm + float(img.get_height()) * 0.5)
				var r1: int = int((float(st[1]) - 24.0) / cosf_ * ppm + float(img.get_height()) * 0.5)
				for py in range(maxi(r0, 0), mini(r1, img.get_height()), 2):
					for px in range(0, w_px, 2):
						if _ink(strip.get_pixel(px, py)):
							n_ink += 1
				counts.append(n_ink)
			ink[tname][String(STATIONS[si][1])] = counts
	sheet.save_png(OUT + "stations_by_tilt.png")
	print("saved stations_by_tilt (stations A-E across; flat, along 5, matched 10.3, along 20, across 15 down)")
	for tn in ink:
		var line: String = "INK %-13s" % tn
		for sn in ink[tn]:
			line += "  %s %s" % [sn, str(ink[tn][sn])]
		print(line)
	# What the sheet should show, as numbers. Every other pixel is counted, so a chevron is about
	# 4-6 and a stretch of route 45-65; "seen" is more than 15, a couple of marks.
	var seen := func(tn: String, sn: String, k: int, at_least: int = 15) -> bool:
		return int(ink[tn][sn][k]) > at_least
	var static_ok: bool = true
	for t in TILTS:
		for k in 3:
			static_ok = static_ok and seen.call(String(t[0]), "A", k, 30)
	_check(static_ok, "static holds at every tilt, every stretch")
	_check(seen.call("flat", "B", 1) and not seen.call("matched 10.3", "B", 1), "here: its middle goes as the slice tilts off W 0")
	_check(seen.call("matched 10.3", "C", 0, 30) and seen.call("matched 10.3", "C", 1, 30) and seen.call("matched 10.3", "C", 2, 30), "follow at the matched tilt: the whole route at once")
	_check(not seen.call("flat", "D", 1) and seen.call("matched 10.3", "D", 2), "reveal: tilting brings its end into view")
	_check(seen.call("matched 10.3", "E", 0) and seen.call("matched 10.3", "E", 1) and seen.call("matched 10.3", "E", 2), "the ladder at the matched tilt: a piece of every leg")
	# The player's view of B and C, flat and matched (the pen's slice pivots on the player).
	for sn in ["B", "C"]:
		var x: float = -8.0 if sn == "B" else 0.0
		for tn in ["flat", "matched"]:
			_cam.set("projection_type", 1)
			var at := Vector4(x, 2.6, 9.0, 0.0)
			var look: Projection = Mark.basis_looking(at, Vector4(x + 1.5, 0.0, 24.0, 0.0))
			var r: Projection = _tilted(look, "zw", 0.0 if tn == "flat" else MATCHED)
			at.w = _w_through(at, r, Vector4(x, 0.0, 12.0, 0.0))
			_cam.global_position = at
			_cam.global_basis = r
			var pv: Image = await _grab()
			pv.save_png(OUT + "player_%s_%s.png" % [sn.to_lower(), tn])
	print("TILT %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
