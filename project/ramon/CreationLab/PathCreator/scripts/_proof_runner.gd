extends SceneTree

## PathCreator's proof (PLAN.md step 89), the sheet's rule 10: "Test at the actual player camera:
## direction readable, equal branches equally weighted, no symbol overlaps, object clearance
## maintained, arrival reachable, and every visible route ends at a valid destination."
##   1. The layout's own half, per network (path_network_4d.gd acceptance(), and validate()).
##   2. Direction readable: from the player's own camera at three places (the yard's entry, the pen
##      patch's start, station C), the marks on screen found and measured (each blob of route ink,
##      its width and height in pixels); the nearest must be big enough to read which way. With the
##      pen's two cameras (its Camera 2, the one it opens on, and Camera 3, the diorama), and at three
##      sizes of P (each network's p_scale 1, 1.5 and 2), so the answer is a size, not just a no.
##   3. Equal branches: the yard's equal choice, from above, the ink on its two branches over the
##      same length, averaged over moments (the marks move).
##   4. Cost: every route in the space on screen at once, the frame with them and without, vsync off.
## Frames, with the measured marks boxed, to res://smoke_test_output/pathcreator/proof/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_proof res://ramon/CreationLab/PathCreator/scripts/_proof_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/proof/"
const TOP := Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
## A mark reads its direction from the player's camera when its blob is at least this big, pixels
## at 1280 x 720 (the pen's own type floor, 10 px at 1080p, is 7 px here; a chevron is read by its
## shape, so it wants more).
const READ_W := 24
const READ_H := 8

var _g: Node
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
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Route ink: the marks' blue (and cyan), not the floor's pale blue-grey.
static func _ink_at(d: PackedByteArray, i: int) -> bool:
	var r: int = d[i * 4]
	var b: int = d[i * 4 + 2]
	return r < 102 and b > 153 and b - r > 89


## The blobs of route ink in `img`: [{x, y, w, h, n}], biggest first.
static func _blobs(img: Image) -> Array:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var d: PackedByteArray = img.get_data()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var out: Array = []
	for i in w * h:
		if seen[i] != 0 or not _ink_at(d, i):
			continue
		var stack: PackedInt32Array = [i]
		seen[i] = 1
		var x0: int = w
		var x1: int = 0
		var y0: int = h
		var y1: int = 0
		var n: int = 0
		while not stack.is_empty():
			var j: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var x: int = j % w
			var y: int = j / w
			n += 1
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
			y0 = mini(y0, y)
			y1 = maxi(y1, y)
			for k in [j - 1, j + 1, j - w, j + w]:
				if k < 0 or k >= w * h or seen[k] != 0:
					continue
				if (k == j - 1 and x == 0) or (k == j + 1 and x == w - 1):
					continue
				if _ink_at(d, k):
					seen[k] = 1
					stack.append(k)
		if n >= 12:
			out.append({"x": x0, "y": y0, "w": x1 - x0 + 1, "h": y1 - y0 + 1, "n": n})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["w"]) > int(b["w"]))
	return out


static func _box(img: Image, b: Dictionary, c: Color) -> void:
	var x0: int = int(b["x"]) - 2
	var y0: int = int(b["y"]) - 2
	var x1: int = int(b["x"]) + int(b["w"]) + 1
	var y1: int = int(b["y"]) + int(b["h"]) + 1
	for x in range(maxi(x0, 0), mini(x1 + 1, img.get_width())):
		for y in [y0, y1]:
			if y >= 0 and y < img.get_height():
				img.set_pixel(x, y, c)
	for y in range(maxi(y0, 0), mini(y1 + 1, img.get_height())):
		for x in [x0, x1]:
			if x >= 0 and x < img.get_width():
				img.set_pixel(x, y, c)


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(3.5)
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	# 1. The layout's own half of rule 10.
	for nn in ["YardNetwork", "WFieldNetwork", "PenNetwork"]:
		var net: Node = _g.get_node(nn)
		var acc: PackedStringArray = net.call("acceptance")
		var val: PackedStringArray = (net.get("graph") as Resource).call("validate")
		for t in acc:
			print("  %s: %s" % [nn, t])
		_check(acc.is_empty(), "%s: no overlaps, objects kept clear, arrivals reachable, every route ends at a destination" % nn)
		_check(val.is_empty(), "%s: the graph is sound %s" % [nn, str(val)])
	# 2. Direction readable, from the player's own camera (the player hidden, so its trim is not
	# taken for a mark; the camera is the rig's, where it would be).
	var p: CharacterBody4D = _g.get("player")
	var rig: Node = p.get_node_or_null("CameraRig")
	# Each with the player 8 m along a route, walking it, so the route runs from under the camera (8 m
	# behind) past the player and on: the way it is seen in play.
	var views: Array = [["yard_entry", Vector4(-13.9, 0.05, -34.0, 0.0), -PI * 0.5], ["pen_steps", Vector4(42.0, 0.55, -9.0, 0.0), PI],
		["station_c", Vector4(0.0, 0.05, 20.0, 1.28), PI]]
	# (Station C is the follow route: 8 m along, it lies at W 1.28, and that is where you walk it.)
	var nets: Array = []
	for c in _g.get_children():
		if c.has_method("next_library"):
			nets.append(c)
	var table: Array = []
	var counts: Dictionary = {}   # "ps|cam|view" -> readable marks
	var sheet: Image = null
	var row: int = 0
	for ps in [1.0, 1.5, 2.0]:
		for nt in nets:
			nt.set("p_scale", ps)
		await _wait(0.5)
		for cam_i in [1, 2]:
			if rig != null:
				rig.call("use_preset", cam_i)
			var line: String = "P x%.1f, Camera %d:" % [ps, cam_i + 1]
			var all_read: bool = true
			for vi in views.size():
				var v: Array = views[vi]
				p.global_position = v[1]
				p.set("_facing", float(v[2]))
				if rig != null:
					rig.set("yaw", float(v[2]))
					rig.call("_apply")
				await _wait(0.8)
				p.visible = false
				await _wait(0.2)
				var img: Image = await _grab()
				p.visible = true
				var blobs: Array = _blobs(img)
				var readable: int = 0
				var biggest: String = "-"
				for b in blobs:
					if int(b["w"]) >= READ_W and int(b["h"]) >= READ_H:
						readable += 1
						_box(img, b, Color(1.0, 0.45, 0.1))
					else:
						_box(img, b, Color(0.9, 0.2, 0.6))
				if not blobs.is_empty():
					biggest = "%dx%d" % [int(blobs[0]["w"]), int(blobs[0]["h"])]
				line += "  %s %d readable (biggest %s)" % [String(v[0]), readable, biggest]
				counts["%.1f|%d|%s" % [ps, cam_i + 1, String(v[0])]] = readable
				all_read = all_read and readable >= 3
				if cam_i == 1:
					if sheet == null:
						sheet = Image.create_empty(640 * 3 + 12, 360 * 3 + 12, false, Image.FORMAT_RGBA8)
						sheet.fill(Color(0.08, 0.09, 0.12))
					var small: Image = img.duplicate()
					small.resize(640, 360, Image.INTERPOLATE_LANCZOS)
					sheet.blit_rect(small, Rect2i(0, 0, 640, 360), Vector2i(vi * 646, row * 366))
			table.append([ps, cam_i + 1, all_read])
			print(line)
		row += 1
	sheet.save_png(OUT + "read_sheet.png")
	print("read_sheet: the pen's Camera 2 at P x1, x1.5 and x2 down; the yard's entry, the pen patch, station C across")
	var first_ok: String = "none up to x2"
	for t in table:
		if bool(t[2]) and first_ok == "none up to x2":
			first_ok = "P x%.1f (%.2f m) from Camera %d" % [float(t[0]), 0.6 * float(t[0]), int(t[1])]
	print("the smallest P that reads everywhere: ", first_ok)
	for nt in nets:
		nt.set("p_scale", 1.0)
	if rig != null:
		rig.call("use_preset", 1)
	await _wait(0.5)
	# What holds at the sheet's own size from the pen's own camera: walking a static route (the yard's
	# way in, the pen patch's over its steps), the direction reads.
	var yard_n: int = int(counts.get("1.0|2|yard_entry", 0))
	var pen_n: int = int(counts.get("1.0|2|pen_steps", 0))
	_check(yard_n >= 3 and pen_n >= 3, "walking a static route, direction reads at the pen's camera at the sheet's P, 0.6 m (yard %d marks, pen patch %d)" % [yard_n, pen_n])
	# A finding, not a check: a follow route shows only its stretch near you (here about 9 m of it).
	var follow_at: String = "beyond x2"
	for ps in [1.0, 1.5, 2.0]:
		if int(counts.get("%.1f|2|station_c" % ps, 0)) >= 3 and follow_at == "beyond x2":
			follow_at = "x%.1f (%.2f m)" % [ps, 0.6 * ps]
	print("FINDING: walking a follow route (station C at its own W), Camera 2 shows %d readable marks at the sheet's P; it takes P %s for three" % [int(counts.get("1.0|2|station_c", 0)), follow_at])
	print("FINDING: the smallest P that reads on every route walked here: %s" % first_ok)
	# 3. Equal branches: the yard's choice (6, 16 on the sheet; -17, -34 here), up to the hut's turn and
	# down to the pen's, from above. Ink over the same 3 m of each, averaged over five moments.
	p.visible = false
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("projection_type", 0)
	cam.set("orthographic_size", 10.0)
	_g.add_child(cam)
	cam.current = true
	cam.global_basis = TOP
	cam.global_position = Vector4(-17.0, 30.0, -34.0, 0.0)
	var up_ink: int = 0
	var down_ink: int = 0
	for k in 5:
		await _wait(0.25)
		var img2: Image = await _grab()
		var ppm: float = float(img2.get_height()) / 10.0
		var d: PackedByteArray = img2.get_data()
		var cx: int = img2.get_width() / 2
		var cy: int = img2.get_height() / 2
		# Image up is world -z: the hut's branch runs up the image, the pen's down.
		for y in range(int(1.0 * ppm), int(4.0 * ppm)):
			for x in range(cx - int(0.4 * ppm), cx + int(0.4 * ppm)):
				if _ink_at(d, (cy - y) * img2.get_width() + x):
					up_ink += 1
				if _ink_at(d, (cy + y) * img2.get_width() + x):
					down_ink += 1
		if k == 0:
			img2.save_png(OUT + "equal_choice.png")
	var ratio: float = float(up_ink) / maxf(float(down_ink), 1.0)
	print("the equal choice: ink up %d, down %d (ratio %.2f)" % [up_ink, down_ink, ratio])
	_check(ratio > 0.8 and ratio < 1.25, "equal branches equally weighted (ink %.2f to 1)" % ratio)
	# 4. Cost: every route in the space on screen at once.
	cam.set("orthographic_size", 100.0)
	cam.global_position = Vector4(5.0, 60.0, -5.0, 0.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var boxes: int = 0
	for c in nets:
		for m in (c as Node).get_children():
			if m is MeshInstance4D:
				boxes += 1
	var on_ms: float = await _frame_ms()
	for n in nets:
		(n as Node4D).visible = false
	var off_ms: float = await _frame_ms()
	for n in nets:
		(n as Node4D).visible = true
	print("every route on screen (%d networks, %d boxes): frame %.3f ms, without them %.3f ms (+%.3f)" % [nets.size(), boxes, on_ms, off_ms, on_ms - off_ms])
	_check(on_ms - off_ms < 1.0, "every route at once costs under a millisecond (%.3f ms)" % (on_ms - off_ms))
	await _grab()
	root.get_texture().get_image().save_png(OUT + "everything.png")
	print("PROOF %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _frame_ms() -> float:
	await _wait(0.5)
	var n: int = 0
	var t0: int = Time.get_ticks_usec()
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		n += 1
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(maxi(n, 1))
