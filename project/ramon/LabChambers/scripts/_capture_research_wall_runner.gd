extends SceneTree

## The research wall and the presenter: each part of the story skipped to with a left click's
## call (showcase skip()), the screen photographed as the title card shows and again at a callout,
## the wall's own page saved at full size; the goat first, then the chicken. To
## res://smoke_test_output/goat_room/wall/.
##
##   LabChambers/scripts/lab_run.sh windowed wall res://ramon/LabChambers/scripts/_capture_research_wall_runner.gd

const SCENE := "res://ramon/LabChambers/goat_room.tscn"
const OUT := "res://smoke_test_output/goat_room/wall/"

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


func _page(what: String) -> void:
	var wall: Node = _g.get_node_or_null("ResearchWall")
	var vp: SubViewport = wall.get("_vp") if wall != null else null
	if vp != null:
		vp.get_texture().get_image().save_png("%spage_%s.png" % [OUT, what])
		print("page ", what)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _put(x: float, z: float, face: float) -> void:
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(x, 0.05, z, 0.0)
	p.linear_velocity = Vector4.ZERO
	p.set("_facing", face + PI)
	var rig: Node = p.get_node_or_null("CameraRig")
	rig.set("yaw", face)
	rig.set("pitch", deg_to_rad(float(_g.get("camera_pitch_degrees"))))
	rig.call("_apply")


## Waits for the loop to be playing, then steps through its five parts.
func _story(sc: Node, tag: String) -> void:
	var until: int = Time.get_ticks_msec() + 20000
	while int(sc.get("seq_index")) < 0 and Time.get_ticks_msec() < until:
		await process_frame
	_check(int(sc.get("seq_index")) >= 0, "%s: the story plays" % tag)
	_page("%s_summary_or_first" % tag)
	for part in 5:
		while int(sc.get("seq_index")) != part:
			var was: int = int(sc.get("seq_index"))
			sc.call("skip")
			await _wait(0.05)
			if int(sc.get("seq_index")) == was:
				break
		_check(int(sc.get("seq_index")) == part, "%s: a skip reaches part %d" % [tag, part + 1])
		await _wait(0.9)
		await _shot("%s_%d_card" % [tag, part + 1])
		await _wait(1.9 if part < 4 else 3.4)
		await _shot("%s_%d_callout" % [tag, part + 1])
		_page("%s_%d" % [tag, part + 1])


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	for nm in ["tuner", "tuner_room2"]:
		var t: Control = _g.get(nm)
		if t != null:
			t.visible = false
	_g.get_node("Room").call("set_mood", "dark", true, false)
	await _wait(4.0)
	var sc: Node = _g.get_node("Showcase")
	_check(_g.get_node_or_null("ResearchWall") != null, "the research wall is on the wall")
	_check(_g.get_node_or_null("WSlicePanel") == null, "the old W-slice screens are gone")
	_put(0.8, 5.5, -0.5)
	await _wait(0.5)
	await _story(sc, "goat")
	var b: Dictionary = sc.call("bench")
	print("goat bench: ", b.get("build_ms"), " build, ", b.get("limb_ms"), " limb, ", b.get("anim_ms"), " walk")
	_check(float(b.get("build_ms", -1.0)) > 0.0, "the goat's loft is timed")
	_check(float(b.get("anim_ms", -1.0)) > 0.0, "the goat's walk is timed")
	# The wall from straight on, the page close.
	_put(2.4, -0.9, -0.85)
	await _wait(0.5)
	await _shot("goat_wall_close")
	_put(0.8, 5.5, -0.5)
	_g.call("pick", 1)
	await _wait(0.6)
	_page("chicken_arriving")
	await _story(sc, "chicken")
	b = sc.call("bench")
	print("chicken bench: ", b.get("build_ms"), " build, ", b.get("limb_ms"), " limb, ", b.get("anim_ms"), " walk")
	_check(float(b.get("anim_ms", -1.0)) > 0.0, "the chicken's walk is timed")
	sc.call("turn_by", 0.0, 0.0)
	await _wait(0.6)
	_page("chicken_in_your_hands")
	await _shot("chicken_in_your_hands")
	# 3: the wolf, arriving from its real size, then its story.
	_put(0.8, 5.5, -0.5)
	var t_pick: int = Time.get_ticks_usec()
	_g.call("pick", 2)
	print("wolf picked in %.1f ms" % (float(Time.get_ticks_usec() - t_pick) / 1000.0))
	var s3: Script = sc.get("exhibit_script")
	_check(s3 != null and s3.resource_path.ends_with("rd_wolf_4d.gd"), "3 puts the wolf on the plinth")
	await _wait(0.4)
	await _shot("wolf_arriving")
	await _story(sc, "wolf")
	b = sc.call("bench")
	print("wolf bench: ", b.get("build_ms"), " build, ", b.get("limb_ms"), " limb, ", b.get("anim_ms"), " walk")
	_check(float(b.get("anim_ms", -1.0)) > 0.0, "the wolf's walk is timed")
	# Close, side on, walking and in the x-ray.
	var rig: Node = (_g.get("player") as Node).get_node("CameraRig")
	rig.set("_zoom_target", 3.0)
	rig.set("distance", 3.0)
	rig.set("pivot_height", 2.3)
	rig.set("_home_pivot", 2.3)
	_put(0.9, 4.4, 0.2)
	sc.set("autoplay", false)
	sc.set("cinematic", true)
	for i in 40:
		sc.call("play", 4, 2.0 + float(i) * 0.03)
		await process_frame
	await _shot("wolf_walk_close")
	for i in 20:
		sc.call("play", 3, 1.0 + float(i) * 0.03)
		await process_frame
	await _shot("wolf_rig_close")
	sc.call("end_cinematic")
	await _wait(0.4)
	await _shot("wolf_standing_close")
	print("WALL %s: %d failed, %.1f s" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size(), (Time.get_ticks_msec() - started) / 1000.0])
	for f in _fails:
		print("  failed: ", f)
	quit(0 if _fails.is_empty() else 1)
