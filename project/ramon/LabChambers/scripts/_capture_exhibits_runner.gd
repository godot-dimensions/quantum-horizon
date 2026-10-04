extends SceneTree

## The goat room's specimen picker: the goat, then 2 for the chicken (growing in from its real size,
## then walking, pecking and fluttering on the spot, then its x-ray), then 1 for the goat again.
## Photographs to res://smoke_test_output/goat_room/exhibits/<nn>_<what>.png and saves the picker's
## and the research panel's screens as they are drawn.
##
##   CreationLab/scripts/lab_run.sh windowed exhibits res://ramon/LabChambers/scripts/_capture_exhibits_runner.gd

const SCENE := "res://ramon/LabChambers/goat_room.tscn"
const OUT := "res://smoke_test_output/goat_room/exhibits/"
const CHICKEN := "res://ramon/LabChambers/scripts/rd_chicken_4d.gd"
const GOAT := "res://ramon/LabChambers/scripts/rd_goat_4d.gd"

var _g: Node
var _n: int = 0
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


func _shot(what: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s%02d_%s.png" % [OUT, _n, what])
	print("shot ", what)
	_n += 1


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _put(x: float, z: float, face: float, pitch_deg: float = NAN) -> void:
	if not is_finite(pitch_deg):
		pitch_deg = float(_g.get("camera_pitch_degrees"))
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(x, 0.05, z, 0.0)
	p.linear_velocity = Vector4.ZERO
	p.set("_facing", face + PI)
	var rig: Node = p.get_node_or_null("CameraRig")
	rig.set("yaw", face)
	rig.set("pitch", deg_to_rad(pitch_deg))
	rig.call("_apply")


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var u := InputEventKey.new()
	u.keycode = code
	u.physical_keycode = code
	Input.parse_input_event(u)
	await process_frame


func _save_screen(node_name: String, what: String) -> void:
	var n: Node = _g.get_node_or_null(node_name)
	var vp: SubViewport = n.get("_vp") if n != null else null
	if vp != null:
		vp.get_texture().get_image().save_png("%s%s.png" % [OUT, what])
		print("screen ", what)


## Drives the showcase's sequence `i` by hand for `seconds`, photographing at the times in `at`.
func _drive(sc: Node, i: int, seconds: float, at: Array, prefix: String) -> void:
	var t: float = 0.0
	var last: int = Time.get_ticks_msec()
	var next: int = 0
	while t < seconds:
		await process_frame
		var now: int = Time.get_ticks_msec()
		t += float(now - last) / 1000.0
		last = now
		sc.call("play", i, t)
		if next < at.size() and t >= float(at[next]):
			var m: Node4D = (sc.get("exhibit") as Node).get("_model") if (sc.get("exhibit") as Node).get("_model") != null else null
			if m != null:
				var wing: Node4D = m.get_node_or_null("Wing")
				print("  %s %.1f: bird y %.3f, wing width %.2f, halted %s" % [prefix, t, m.position.y, wing.basis.x.x if wing != null else 1.0, str(m.get_node("Walker").get("halted"))])
			await _shot("%s_%.1f" % [prefix, t])
			next += 1


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(5.0)
	for nm in ["tuner", "tuner_room2"]:
		var t: Control = _g.get(nm)
		if t != null:
			t.visible = false
	_g.get_node("Room").call("set_mood", "dark", true, false)
	var sc: Node = _g.get_node("Showcase")
	_check(_g.get_node_or_null("ExhibitPicker") != null, "the specimen picker is in the room")
	_put(2.2, 7.4, 0.3)
	await _wait(0.6)
	await _shot("goat")
	# The picker, close: low and in front of the plinth.
	var rig: Node = (_g.get("player") as Node).get_node("CameraRig")
	rig.set("_zoom_target", 2.6)
	rig.set("distance", 2.6)
	rig.set("pivot_height", 1.3)
	rig.set("_home_pivot", 1.3)
	_put(0.0, 5.6, 0.0, -24.0)
	await _wait(0.8)
	await _shot("picker_goat")
	_save_screen("ExhibitPicker", "picker_screen_goat")
	# 2: the chicken.
	await _key(KEY_2)
	if int(sc.get("serial")) == 0:
		print("note: the key did not reach the room in this window; picking directly")
		_g.call("pick", 1)
	_check(int(sc.get("serial")) == 1, "2 swaps the exhibit")
	var s: Script = sc.get("exhibit_script")
	_check(s != null and s.resource_path == CHICKEN, "the chicken is on the plinth")
	await _wait(0.3)
	await _shot("picker_chicken")
	_save_screen("ExhibitPicker", "picker_screen_chicken")
	for k in [["_zoom_target", "camera_distance"], ["distance", "camera_distance"], ["pivot_height", "camera_height"], ["_home_pivot", "camera_height"]]:
		rig.set(k[0], _g.get(k[1]))
	_put(2.2, 7.4, 0.3)
	await _wait(0.2)
	await _shot("chicken_arrives")
	await _wait(1.1)
	await _shot("chicken_growing")
	await _wait(1.6)
	var ex: Node = sc.get("exhibit")
	_check(ex != null and bool(ex.call("grown")), "the chicken has grown")
	await _shot("chicken_grown")
	await _wait(0.5)
	_save_screen("ResearchPanel", "research_screen_chicken")
	var desk_data: Dictionary = _g.get_node("ResearchPanel").get("_data")
	_check(String(desk_data.get("name", "")) == "Chicken", "the research panel reads the chicken (%s)" % String(desk_data.get("name", "?")))
	# Its walk, peck and flutter, then the x-ray, driven by hand rather than waiting for the loop.
	sc.set("autoplay", false)
	sc.set("cinematic", true)
	rig.set("_zoom_target", 3.0)
	rig.set("distance", 3.0)
	rig.set("pivot_height", 2.3)
	rig.set("_home_pivot", 2.3)
	_put(0.9, 4.4, 0.2, -6.0)
	await _wait(0.5)
	await _drive(sc, 4, 10.0, [0.8, 1.6, 2.6, 3.9, 4.3, 4.6, 6.0, 8.9, 9.3, 9.6], "walk")
	await _drive(sc, 3, 3.0, [1.0, 2.2], "rig")
	sc.call("end_cinematic")
	await _wait(0.5)
	await _shot("chicken_standing")
	sc.call("turn_by", 0.6, 0.4)
	await _wait(0.8)
	await _shot("chicken_sliced_turned")
	# 1: the goat again.
	sc.set("autoplay", true)
	await _key(KEY_1)
	if int(sc.get("serial")) == 1:
		_g.call("pick", 0)
	s = sc.get("exhibit_script")
	_check(s != null and s.resource_path == GOAT, "1 brings the goat back")
	_put(2.2, 7.4, 0.3)
	await _wait(0.3)
	await _shot("goat_arrives")
	await _wait(2.8)
	await _shot("goat_grown")
	print("EXHIBITS %s: %d failed, %.1f s" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size(), (Time.get_ticks_msec() - started) / 1000.0])
	for f in _fails:
		print("  failed: ", f)
	quit(0 if _fails.is_empty() else 1)
