extends SceneTree

## The range's moments that have to read, set up one by one and photographed from the player's eyes
## (plan steps 51 to 61 and 67): the console, the free range with its tags, the hitbox view, the light
## panel, a ring gate with its core in the ring, a shell sealed then stepped past, the cluster's hidden
## satellite, a capsule open, the sentinel, a drone arriving from another slice, a bird at the top of its
## swing through W, and the spot over a running stage. Frames in smoke_test_output/quantum_range/moments/.
##
##   range_run.sh windowed moments res://ramon/QuantumRange/scripts/_capture_moments_runner.gd

const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/quantum_range/moments/"
const Bot := preload("res://ramon/QuantumRange/scripts/_range_bot.gd")

var _r: Node
var _d: Node
var _p: CharacterBody4D
var _bot: RefCounted
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 200000:
		print("MOMENTS: gave up after 200 s")
		return true
	return false


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("MOMENTS: ", name)


func _wait(s: float) -> void:
	await create_timer(s).timeout


## Starts experiment `i` and jumps straight to stage `k`, waiting until its targets are out.
func _stage(i: int, k: int) -> void:
	_d.call("start", i)
	if k > 0:
		_d.call("_begin_stage", k)
	while String(_d.get("state")) != "stage":
		await process_frame
	await _wait(0.6)


func _first_part(role: String, fam: String = "") -> Dictionary:
	for t in _d.call("alive"):
		if not fam.is_empty() and String(t.get("family")) != fam:
			continue
		for p in t.get("parts"):
			if String(p["role"]) == role and bool(p["alive"]):
				return {"t": t, "p": p}
	return {}


func _home() -> void:
	_p.call("place", Vector4(0, 0.05, 1.5, 0), 0.0)
	await physics_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_r = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_r)
	current_scene = _r
	for i in 20:
		await process_frame
	_d = _r.get("director")
	_d.set("keep_bests", false)
	_p = _r.get("player")
	# Nobody's mouse reaches this player (the range takes the mouse when it opens; see _capture_menu_clip_runner.gd).
	_p.set("input_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Nobody's keys reach the range either (typing in another window once started a run here).
	_d.set_process_unhandled_key_input(false)
	_r.set_process_unhandled_input(false)
	(_r.get("sfx") as Node).set("muted", true)
	_bot = Bot.new()
	_bot.set("director", _d)
	_bot.set("player", _p)
	_bot.set("weapon", _r.get("weapon"))
	# The console as you come in: floating in the middle of the bay, facing you.
	_p.call("place", Vector4(0, 0.05, 11.0, 0), 0.0)
	await _wait(1.2)
	_p.call("aim_at", Vector4(0, 1.0, 6.5, 0))
	await _shot("01_console")
	# Close, as you stand at it; and each tile's hitbox where its picture is (aim at a tile's middle,
	# and the weapon must say that button).
	_p.call("place", Vector4(0, 0.05, 8.7, 0), 0.0)
	await _wait(0.3)
	var con: Node4D = _r.get("console")
	_p.call("aim_at", con.local_to_global(con.call("_on_glass", Vector2(0.95, 0.21))))
	await _wait(0.2)
	await _shot("01a_console_close")
	var hits: Array = []
	for i in 6:
		var tr: Rect2 = con.call("_tile_m", i)
		_p.call("aim_at", con.local_to_global(con.call("_on_glass", tr.get_center())))
		await physics_frame
		await process_frame
		hits.append(int(_r.get("weapon").get("hover_button")))
	print("MOMENTS: console tiles aimed at 0 to 5 read buttons %s" % str(hits))
	_p.call("aim_at", con.local_to_global(con.call("_on_glass", Vector2(0.95, 0.21))))
	# Experiment 3, then 3 again twice: stage C chosen, lit on its tile.
	_d.call("select", 2)
	_d.call("select", 2)
	_d.call("select", 2)
	await _wait(0.3)
	await _wait(0.2)
	await _shot("01b_console_stage_c")
	_d.call("select", 0)
	# Started: it flies out of the view to beside you, facing you.
	_d.call("start_pressed")
	await _wait(0.5)
	await _shot("01c_console_flying")
	_p.call("place", Vector4(0, 0.05, 1.5, 0), 0.0)
	await _wait(2.5)
	await _shot("01d_console_beside_downrange")
	_p.call("aim_at", (_r.get("console") as Node4D).local_to_global(_r.get("console").call("_on_glass", Vector2(0.95, 0.21))))
	await _wait(0.2)
	await _shot("01e_console_beside")
	_d.call("_finish")
	await _wait(0.4)
	await _home()
	# The free range, its tags, the hitboxes, the light panel.
	_d.call("toggle_gallery")
	await _wait(1.0)
	_p.call("aim_at", Vector4(0, 2.4, -12.0, 0))
	await _shot("02_gallery")
	(_r.get("hud") as Node).set("show_hitboxes", true)
	await _shot("03_hitboxes")
	(_r.get("hud") as Node).set("show_hitboxes", false)
	(_r.get("dev_panel") as Control).visible = true
	await _shot("04_light_panel")
	(_r.get("dev_panel") as Control).visible = false
	_d.call("toggle_gallery")
	# 01 C: a ring gate, the core brought into the ring by turning the slice.
	await _home()
	await _stage(0, 2)
	var rg: Dictionary = _first_part("core", "ring")
	if not rg.is_empty():
		_p.call("aim_at", ((rg["t"] as Node).call("part", "Ring")["node"] as Node4D).global_position)
		await _shot("05_ring_before")
		_bot.call("align", (rg["p"]["node"] as Node4D).global_position)
		await _wait(0.2)
		await _shot("06_ring_aligned")
	# 03 A: the shell, sealed, then stepped past.
	await _home()
	await _stage(2, 0)
	var sh: Dictionary = _first_part("core", "shell")
	if not sh.is_empty():
		var at: Vector4 = (sh["p"]["node"] as Node4D).global_position
		_p.call("aim_at", at)
		await _wait(0.2)
		await _shot("07_shell_sealed")
		_bot.call("align", at, at.w + 0.48)
		await _wait(0.3)
		await _shot("08_shell_stepped_past")
	# 03 B: the cluster, then the satellite a step ana.
	await _home()
	await _stage(2, 1)
	var cl: Dictionary = _first_part("core", "cluster")
	if not cl.is_empty():
		_p.call("aim_at", (cl["p"]["node"] as Node4D).global_position)
		await _shot("09_cluster")
		var wp: Dictionary = (cl["t"] as Node).call("part", "SatWP")
		_bot.call("align", (wp["node"] as Node4D).global_position)
		await _wait(0.3)
		await _shot("10_cluster_ana_satellite")
	# 03 C: a capsule, waiting for it to open.
	await _home()
	await _stage(2, 2)
	var cap: Dictionary = _first_part("core", "capsule")
	if not cap.is_empty():
		_p.call("aim_at", (cap["p"]["node"] as Node4D).global_position)
		await _shot("11_capsule_closed")
		var waited: float = 0.0
		while float((cap["t"] as Node).get("openness")) < 0.95 and waited < 6.0:
			await process_frame
			waited += 1.0 / 60.0
		await _shot("12_capsule_open")
	# 03 D: the sentinel.
	await _home()
	await _stage(2, 3)
	var se: Dictionary = _first_part("core", "sentinel")
	if not se.is_empty():
		_p.call("aim_at", (se["p"]["node"] as Node4D).global_position)
		await _wait(0.4)
		await _shot("13_sentinel")
		await _wait(1.1)
		await _shot("14_sentinel_later")
	# 04 B: a drone from another slice, the radar showing it before you can see it.
	await _home()
	await _stage(3, 1)
	await _wait(1.2)
	_p.call("aim_at", Vector4(4.5, 2.0, -24.0, 0))
	await _shot("15_incoming_from_another_slice")
	await _wait(3.0)
	await _shot("16_incoming_arriving")
	# 05 C: a bird swinging through W, met at the top of its swing.
	await _home()
	await _stage(4, 2)
	var sk: RefCounted = (_d.get("experiments") as Array)[4]
	sk.call("action")
	await _wait(0.2)
	var ch: Dictionary = _first_part("core", "chicken")
	var got: bool = false
	var tt: float = 0.0
	while not ch.is_empty() and is_instance_valid(ch["t"]) and tt < 3.0:
		await process_frame
		tt += 1.0 / 60.0
		var b: Node4D = ch["t"]
		if not got and float(b.get("age")) > 1.25:
			_bot.call("align", b.global_position)
			await _shot("17_skeet_bird_at_the_top")
			got = true
			break
	# The spot over a running stage.
	await _home()
	await _stage(1, 0)
	await _wait(0.8)
	_p.call("aim_at", Vector4(0, 1.2, -10.0, 0))
	await _shot("18_spot_on_a_stage")
	print("MOMENTS: done")
	quit()
