extends SceneTree

## The Shooting Range's menu film (menu_final's details pane, Menu/thumbs/<clip>.ogv): five shots of about
## three seconds each, hard cuts, 1920 x 1080 at a fixed 30 fps (film_kit.gd, film_run.sh).
##
##   1. CINEMATIC  the range: a slow push from between the blue bay walls, over the counter, towards the
##                 target gallery's specimens, red cores drifting in and out of the slice among them
##   2. GAMEPLAY   ring gate (01 C): the slice turns until the far core sits inside its ring; one shot
##   3. GAMEPLAY   shell (03 A): a step through W past the grey shell, and the red core inside is shot
##   4. CINEMATIC  wolf run (06 B), a low wide: the wolf leaps the first bar, runs out of the slice
##                 through W, and comes back in over the second
##   5. GAMEPLAY   skeet (05 A): a bird from each trap, met on its rise and shot in the air
##
## Started from the range's own menu clip runner (QuantumRange/scripts/_capture_menu_clip_runner.gd): the
## gameplay shots are its moments, re-timed to three seconds; the two cinematic shots look through a
## camera of this runner's own. The gameplay shots keep only the crosshair and the slice glow (the HUD's
## `clean`); the cinematic ones hide the HUD, the gun and the console.
##
## Nothing in the range is changed or saved: its scripts are preloaded read-only, bests are off, the
## player's input is off and the mouse is free.
##
##   bash Menu/films/film_run.sh shooting_range res://ramon/Menu/films/shooting_range_film_runner.gd

const Kit := preload("res://ramon/Menu/films/film_kit.gd")
const Bot := preload("res://ramon/QuantumRange/scripts/_range_bot.gd")
const Layout := preload("res://ramon/QuantumRange/scripts/range_layout.gd")
const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const PIP := "res://ramon/QuantumRange/scripts/targets/target_pip.gd"
const GUARD_MS := 300000

var _kit: RefCounted
var _r: Node
var _d: Node
var _p: CharacterBody4D
var _w: Node
var _bot: RefCounted
var _pcam: Camera4D
var _cam: Camera4D
var _t0: int = 0
var _done: bool = false


func _initialize() -> void:
	var out: String = ProjectSettings.globalize_path("res://smoke_test_output/menu_films/shooting_range/frames")
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("out="):
			out = String(a).substr(4)
	_kit = Kit.new(self, out)
	_kit.calm_window()
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if not _done and Time.get_ticks_msec() - _t0 > GUARD_MS:
		print("FILM shooting_range: gave up after %d s" % (GUARD_MS / 1000))
		_done = true
		quit(1)
		return true
	return false


# -- helpers ---------------------------------------------------------------------------------------------

func _frame() -> void:
	await _kit.frame()


func _hold(n: int) -> void:
	await _kit.hold(n)


## A gentler ease than smoothstep: a cut lands in motion, and the move settles at its end.
static func _soft(t: float) -> float:
	return lerpf(t, Kit.ease_io(t), 0.6)


## A level look from `eye` at `at` (yaw on the floor, then pitch), as the player's body and head compose.
static func _look(eye: Vector4, at: Vector4) -> Projection:
	var d: Vector4 = at - eye
	var flat: float = Vector2(d.x, d.z).length()
	return Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, maxf(flat, 0.0001)))


func _place_cam(eye: Vector4, at: Vector4) -> void:
	_cam.global_position = eye
	_cam.global_basis = _look(eye, at)


## Cinematic: this runner's camera, nothing of the HUD, no gun. Gameplay: the player's eyes, the HUD clean.
func _cinematic(on: bool, fov_deg: float = 60.0) -> void:
	(_r.get_node("HUD") as CanvasLayer).visible = not on
	(_r.get("gun") as Node4D).visible = not on
	if on:
		_cam.set("field_of_view_4d", deg_to_rad(fov_deg))
		_cam.make_current()
	else:
		_pcam.set("field_of_view_4d", deg_to_rad(fov_deg))
		_pcam.make_current()


func _pose() -> Dictionary:
	return {"b": _p.basis, "pitch": float(_p.get("pitch")), "pos": _p.global_position}


func _set_pose(s: Dictionary) -> void:
	_p.basis = s["b"]
	_p.set("pitch", float(s["pitch"]))
	(_p.get("head") as Node4D).basis = Basis4D.from_yz(float(s["pitch"]))
	_p.global_position = s["pos"]


## Where the test bot would put you to bring `at` under the crosshair, without going there.
func _pose_for(at: Vector4, prefer_w: float = INF) -> Dictionary:
	var s0: Dictionary = _pose()
	_bot.call("align", at, prefer_w)
	var s1: Dictionary = _pose()
	_set_pose(s0)
	return s1


## Eases the player from pose `a` to pose `b` over `frames` (basis, pitch and position together).
func _glide(a: Dictionary, b: Dictionary, frames: int) -> void:
	var ba: Projection = a["b"]
	var bb: Projection = b["b"]
	for i in frames:
		var k: float = Kit.ease_io(float(i + 1) / float(frames))
		var m := Projection(ba.x.lerp(bb.x, k), ba.y.lerp(bb.y, k), ba.z.lerp(bb.z, k), ba.w.lerp(bb.w, k))
		m.y = Vector4(0, 1, 0, 0)
		_set_pose({"b": Basis4D.orthonormalized(m), "pitch": lerpf(float(a["pitch"]), float(b["pitch"]), k),
			"pos": (a["pos"] as Vector4).lerp(b["pos"], k)})
		await _frame()


## A quick shot at whatever is under the crosshair: pressed one frame, released the next.
func _tap() -> String:
	_w.call("press")
	await _frame()
	var r: Dictionary = _w.call("release")
	return String(r.get("outcome", "missed"))


func _first_part(role: String, fam: String) -> Dictionary:
	for t in _d.call("alive"):
		if String(t.get("family")) != fam:
			continue
		for p in t.get("parts"):
			if String(p["role"]) == role and bool(p["alive"]):
				return {"t": t, "p": p}
	return {}


## Experiment `i` from stage `k`, its card and countdown waited out off camera.
func _stage(i: int, k: int, settle: int = 20) -> void:
	_p.call("place", Layout.STAND, 0.0)
	_d.call("start", i, k)
	var guard: int = 0
	while String(_d.get("state")) != "stage" and guard < 300:
		guard += 1
		await _frame()
	await _hold(settle)


# -- the film --------------------------------------------------------------------------------------------

func _run() -> void:
	_r = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_r)
	current_scene = _r
	await _kit.skip(30)
	_d = _r.get("director")
	_d.set("keep_bests", false)
	_p = _r.get("player")
	_w = _r.get("weapon")
	_pcam = _p.get("camera")
	# Nobody's mouse or keys reach the range (memory: test windows steal focus).
	_p.set("input_enabled", false)
	_kit.calm_window()
	_d.set_process_unhandled_key_input(false)
	_r.set_process_unhandled_input(false)
	(_r.get("sfx") as Node).set("muted", true)
	(_r.get("hud") as Node).set("clean", true)
	var rb: Node = _r.get_node_or_null("ReturnButton")
	if rb != null:
		rb.set("visible", false)
	# The console only ever stands in the way of a shot (it tucks beside you while a stage runs).
	(_r.get("console") as Node4D).visible = false
	_cam = Camera4D.new()
	_cam.name = "FilmCamera"
	_cam.set("rendering_engine_name", "Cross-section")
	_cam.set("view_angle_type", 1)
	_r.add_child(_cam)
	_bot = Bot.new()
	_bot.set("director", _d)
	_bot.set("player", _p)
	_bot.set("weapon", _w)

	await _shot_room()
	await _shot_ring()
	await _shot_shell()
	await _shot_wolf()
	await _shot_skeet()

	print("FILM shooting_range: %d frames, %.2f s" % [_kit.count, float(_kit.count) / 30.0])
	_done = true
	quit()


## 1. The room: from between the blue walls, over the counter, towards the specimens (the target gallery),
## with red cores drifting through W among them, in and out of the slice.
func _shot_room() -> void:
	_p.call("place", Layout.STAND, 0.0)
	_d.call("toggle_gallery")
	# [where, phase]: each swings 0.85 m either way through W, so it is in the slice (and swells and shrinks)
	# for about a third of its swing; the last one comes in beside the lens as the push ends.
	var drift: Array = [[Vector4(-7.4, 3.1, -6.8, 0.0), 0.4], [Vector4(7.0, 2.0, -10.8, 0.0), 2.3], [Vector4(0.2, 4.3, -11.5, 0.0), 4.4],
		[Vector4(-3.6, 4.5, -17.0, 0.0), 1.4], [Vector4(3.0, 1.3, -7.6, 0.0), 3.3], [Vector4(1.6, 2.9, -6.0, 0.0), 1.1]]
	for dd in drift:
		var base: Vector4 = dd[0]
		var ph: float = float(dd[1])
		var t: Node4D = _d.call("spawn", PIP, base, {"radius": 0.5})
		t.set("path", func(_tt: Node4D, age: float) -> Vector4: return base + Vector4(0.0, 0.0, 0.0, 0.85 * sin(age * 1.5 + ph)))
	_cinematic(true, 68.0)
	var e0 := Vector4(-0.9, 1.6, 12.3, 0.0)
	var e1 := Vector4(0.5, 2.4, -2.4, 0.0)
	var l0 := Vector4(0.5, 2.0, -16.0, 0.0)
	var l1 := Vector4(-0.3, 2.3, -14.0, 0.0)
	_place_cam(e0, l0)
	await _kit.skip(40)
	print("FILM shooting_range: shot 1 room from frame %d" % _kit.count)
	_kit.recording = true
	for i in 140:
		var k: float = _soft(float(i) / 139.0)
		_place_cam(e0.lerp(e1, k), l0.lerp(l1, k))
		await _frame()
	_kit.recording = false
	_d.call("toggle_gallery")


## 2. Ring gate (01 C): look at the ring, turn the slice until the core is in it, shoot.
func _shot_ring() -> void:
	_cinematic(false, 45.0)
	await _stage(0, 2)
	var rg: Dictionary = _first_part("core", "ring")
	if rg.is_empty():
		print("FILM shooting_range: no ring gate")
		return
	var ring: Node4D = ((rg["t"] as Node).call("part", "Ring") as Dictionary)["node"]
	_p.call("aim_at", ring.global_position)
	var from: Dictionary = _pose()
	var to: Dictionary = _pose_for((rg["p"]["node"] as Node4D).global_position)
	await _kit.skip(4)
	print("FILM shooting_range: shot 2 ring from frame %d" % _kit.count)
	_kit.recording = true
	await _hold(14)
	await _glide(from, to, 46)
	await _hold(6)
	var out: String = await _tap()
	print("FILM shooting_range: ring shot: %s" % out)
	await _hold(23)
	_kit.recording = false


## 3. Shell (03 A): sealed in your slice, then a step through W past it, and the core.
func _shot_shell() -> void:
	_cinematic(false, 50.0)
	await _stage(2, 0)
	var sh: Dictionary = _first_part("core", "shell")
	if sh.is_empty():
		print("FILM shooting_range: no shell")
		return
	var at: Vector4 = (sh["p"]["node"] as Node4D).global_position
	_p.call("aim_at", at)
	var from: Dictionary = _pose()
	var to: Dictionary = _pose_for(at, at.w + 0.48)
	print("FILM shooting_range: shot 3 shell from frame %d" % _kit.count)
	_kit.recording = true
	await _hold(18)
	await _glide(from, to, 34)
	await _hold(8)
	var out: String = await _tap()
	print("FILM shooting_range: shell shot: %s" % out)
	await _hold(29)
	_kit.recording = false


## 4. Wolf Run (06 B), a low wide: it leaps the first bar, runs out of the slice through W, and comes back
## in over the second. The camera dollies along beside the run and pans with it, a little ahead of it.
func _shot_wolf() -> void:
	_cinematic(false, 60.0)
	_p.call("place", Layout.STAND, 0.0)
	_d.call("start", 5, 1)
	var wolf: Node4D = null
	var guard: int = 0
	while wolf == null and guard < 400:
		guard += 1
		for t in _d.call("alive"):
			if String(t.get("family")) == "wolf":
				wolf = t
		await _frame()
	if wolf == null:
		print("FILM shooting_range: no wolf")
		return
	_cinematic(true, 56.0)
	var e0 := Vector4(-5.2, 0.55, -3.3, 0.0)
	var e1 := Vector4(2.6, 0.7, -2.9, 0.0)
	var aim_x: float = wolf.global_position.x + 2.0
	var aim_z: float = wolf.global_position.z
	_place_cam(e0, Vector4(aim_x, 1.0, aim_z, 0.0))
	await _kit.skip(5)
	print("FILM shooting_range: shot 4 wolf from frame %d" % _kit.count)
	_kit.recording = true
	var leaps: int = 0
	var was_leap: bool = false
	var after: int = -1
	var n: int = 0
	while n < 125:
		var k: float = _soft(float(n) / 109.0)
		if is_instance_valid(wolf):
			var wp: Vector4 = wolf.global_position
			# Ahead of the runner by a little: room in front of it in the frame.
			aim_x = lerpf(aim_x, wp.x + 2.2, 1.0 - exp(-4.0 / 30.0))
			aim_z = lerpf(aim_z, wp.z, 1.0 - exp(-4.0 / 30.0))
			var leaping: bool = String(wolf.get("_act")) == "leap"
			if was_leap and not leaping:
				leaps += 1
				if leaps == 2:
					after = n
			was_leap = leaping
		_place_cam(e0.lerp(e1, minf(k, 1.0)), Vector4(aim_x, 1.0, aim_z, 0.0))
		await _frame()
		n += 1
		if after >= 0 and n - after >= 10:
			break
	_kit.recording = false
	print("FILM shooting_range: wolf leaps %d, %d frames" % [leaps, n])
	_cinematic(false, 60.0)


## 5. Skeet (05 A): one pull from each trap, each bird met low on its rise, where its own flight path says
## it will be, and shot there.
func _shot_skeet() -> void:
	_cinematic(false, 45.0)
	await _stage(4, 0)
	var sk: RefCounted = (_d.get("experiments") as Array)[4]
	_p.call("aim_at", Vector4(-4.0, 3.0, Layout.STAND.z - 9.0, 0.0))
	print("FILM shooting_range: shot 5 skeet from frame %d" % _kit.count)
	_kit.recording = true
	for side in 2:
		await _hold(6 if side == 0 else 2)
		sk.call("action")
		var bird: Dictionary = {}
		var guard: int = 0
		while bird.is_empty() and guard < 60:
			guard += 1
			await _frame()
			bird = _first_part("core", "chicken")
		if bird.is_empty():
			break
		var t: Node4D = bird["t"]
		var hit_age: float = 0.42 if side == 0 else 0.45
		var offset: Vector4 = (bird["p"]["node"] as Node4D).global_position - t.global_position
		var meet: Vector4 = (t.get("path") as Callable).call(t, hit_age) + offset
		var frames: int = maxi(6, int(round((hit_age - float(t.get("age"))) * 30.0)))
		await _glide(_pose(), _pose_for(meet), frames)
		_p.call("aim_at", (bird["p"]["node"] as Node4D).global_position)
		_w.call("press")
		await _frame()
		_p.call("aim_at", (bird["p"]["node"] as Node4D).global_position)
		var r: Dictionary = _w.call("release")
		print("FILM shooting_range: bird %d at age %.2f: %s" % [side + 1, float(t.get("age")), str(r.get("outcome", "missed"))])
		await _hold(14 if side == 0 else 26)
	_kit.recording = false
