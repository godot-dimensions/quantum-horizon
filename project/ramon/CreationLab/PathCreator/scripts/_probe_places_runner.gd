extends SceneTree

## PathCreator's places (Ramon, 5 Oct: "how do i spawn at the other places"): keys 1 to 5 while
## walking put you at the start, the yard, the W field, the pen patch and the W targets; T in the
## builder puts you at the mouse. Each key pressed through the scene's own input, each place
## checked and seen from the player's camera; then the builder with its bigger text. To
## res://smoke_test_output/pathcreator/places/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_places res://ramon/CreationLab/PathCreator/scripts/_probe_places_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/places/"

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


func _shot(what: String) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + what + ".png")
	return img


func _key(code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	_g.call("_unhandled_input", k)
	await process_frame


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(3.0)
	var p: CharacterBody4D = _g.get("player")
	var places: Array = _g.get("PLACES")
	var tiles: Array = []
	for i in places.size():
		# Tilt the slice first, so the key is seen to flatten it.
		var rig: Node = p.get_node_or_null("CameraRig")
		rig.set("_slice_zw", 0.3)
		rig.call("_apply")
		await _key(KEY_1 + i)
		await _wait(1.2)
		var want: Vector4 = places[i][1]
		var at: Vector4 = p.global_position
		var flat: bool = absf(float(_g.call("slice_tilt"))) < 0.5
		_check(Vector2(at.x - want.x, at.z - want.z).length() < 0.3 and absf(at.w - want.w) < 0.05 and flat,
			"%d puts you at %s (%.1f, %.1f, W %+.1f), the slice flat" % [i + 1, String(places[i][0]), at.x, at.z, at.w])
		tiles.append(await _shot("place_%d" % (i + 1)))
	var w: int = 640
	var h: int = 360
	var sheet := Image.create_empty(w * 3 + 12, h * 2 + 6, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.09, 0.12))
	for i in tiles.size():
		var t: Image = tiles[i]
		t.convert(Image.FORMAT_RGBA8)
		t.resize(w, h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(t, Rect2i(0, 0, w, h), Vector2i((i % 3) * (w + 6), (i / 3) * (h + 6)))
	sheet.save_png(OUT + "places.png")
	# The builder, its text bigger; T walks you from the mouse.
	await _key(KEY_1)
	await _wait(0.6)
	_g.call("set_build", true)
	await _wait(0.6)
	var b: Control = _g.get("builder")
	await _shot("builder_text")
	var spot: Vector2 = b.call("to_screen", 4.0, 2.0)
	b.set("_mouse", spot)
	var t := InputEventKey.new()
	t.keycode = KEY_T
	t.pressed = true
	b.call("_unhandled_key_input", t)
	await _wait(0.6)
	var at2: Vector4 = p.global_position
	_check(not bool(_g.get("building")) and Vector2(at2.x - 4.0, at2.z - 2.0).length() < 0.3, "T in the builder walks you from the mouse (%.1f, %.1f)" % [at2.x, at2.z])
	# 1-5 belong to the builder while it is open: there they pick a node's kind, not a place.
	_g.call("set_build", true)
	await _wait(0.3)
	var before: Vector4 = p.global_position
	await _key(KEY_4)
	_check(p.global_position.distance_to(before) < 0.01, "in the builder, 4 does not move you")
	_g.call("set_build", false)
	print("PLACES %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
