extends SceneTree

## The menu's clip of the final range (menu_final's preview pane plays Menu/thumbs/<clip>.ogv): three
## moments filmed from the player's eyes at a fixed 30 fps, each the range's own verb.
##
##   1. Ring gate (01 C): the slice turns until the far core sits inside its ring, and one shot takes it.
##   2. Shell (03 A): a step through W past the grey shell, and the red core inside is shot.
##   3. Skeet (05 A): a chicken from each trap, met on its rise and shot in the air (through 45 degrees).
##
## Only the crosshair and the slice glow are on screen (the HUD's `clean`): the pane is about 3.5:1 and
## shows the middle half of the frame, so the cards and the radar at its edges would be cut in half.
## The camera glides between poses (basis, pitch and W eased together) where the test bot would jump,
## through a 60 degree lens rather than play's 80.
##
## The frames are an intermediate and go to smoke_test_output (ignored by git), never into the menu's
## folder; ffmpeg makes the clip (Menu/scripts/menu_final.gd, "DROP YOUR OWN VIDEO IN"):
##
##   range_run.sh clip menu_clip res://ramon/QuantumRange/scripts/_capture_menu_clip_runner.gd
##   ffmpeg -framerate 30 -i smoke_test_output/quantum_range/clip_frames/%04d.png -c:v libtheora -q:v 8
##       -an ramon/Menu/thumbs/quantum_range_final.ogv

const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/quantum_range/clip_frames/"
const Bot := preload("res://ramon/QuantumRange/scripts/_range_bot.gd")
const Layout := preload("res://ramon/QuantumRange/scripts/range_layout.gd")

var _r: Node
var _d: Node
var _p: CharacterBody4D
var _w: Node
var _bot: RefCounted
var _rec: bool = false
var _n: int = 0
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 600000:
		print("CLIP: gave up after 600 s")
		return true
	return false


## One frame: the world advances 1/30 s, is drawn, and is saved while recording.
func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if _rec:
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%04d.png" % _n))
		_n += 1


func _hold(frames: int) -> void:
	for i in frames:
		await _frame()


func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


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


## Eases from pose `a` to pose `b` over `frames`.
func _glide(a: Dictionary, b: Dictionary, frames: int) -> void:
	var ba: Projection = a["b"]
	var bb: Projection = b["b"]
	for i in frames:
		var k: float = _ease(float(i + 1) / float(frames))
		var m := Projection(ba.x.lerp(bb.x, k), ba.y.lerp(bb.y, k), ba.z.lerp(bb.z, k), ba.w.lerp(bb.w, k))
		m.y = Vector4(0, 1, 0, 0)
		_set_pose({"b": Basis4D.orthonormalized(m), "pitch": lerpf(float(a["pitch"]), float(b["pitch"]), k),
			"pos": (a["pos"] as Vector4).lerp(b["pos"], k)})
		await _frame()


## A quick shot at whatever is under the crosshair: pressed one frame, released the next.
func _tap() -> void:
	_w.call("press")
	await _frame()
	var r: Dictionary = _w.call("release")
	print("CLIP: shot at frame %d: %s" % [_n, str(r)])


func _first_part(role: String, fam: String) -> Dictionary:
	for t in _d.call("alive"):
		if String(t.get("family")) != fam:
			continue
		for p in t.get("parts"):
			if String(p["role"]) == role and bool(p["alive"]):
				return {"t": t, "p": p}
	return {}


## Starts experiment `i` at stage `k`, waits out its card and countdown off camera, and clears the HUD.
func _stage(i: int, k: int) -> void:
	_p.call("place", Layout.STAND, 0.0)
	_d.call("start", i)
	if k > 0:
		_d.call("_begin_stage", k)
	while String(_d.get("state")) != "stage":
		await _frame()
	await _hold(20)
	(_r.get("hud") as Node).set("clean", true)


func _run() -> void:
	var dir: String = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(dir.path_join(f))
	_r = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_r)
	current_scene = _r
	await _hold(30)
	_d = _r.get("director")
	_d.set("keep_bests", false)
	_p = _r.get("player")
	_w = _r.get("weapon")
	# The range takes the mouse when it opens; a real mouse moving anywhere (someone working in another
	# window) then turned the camera mid-take. Nobody's input reaches this player.
	_p.set("input_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_r.get("sfx") as Node).set("muted", true)
	# A longer lens than play's 80 degrees: the pane is small and shows only the middle band.
	(_p.get("camera") as Camera4D).set("field_of_view_4d", deg_to_rad(60.0))
	var rb: Node = _r.get_node_or_null("ReturnButton")
	if rb != null:
		rb.set("visible", false)
	_bot = Bot.new()
	_bot.set("director", _d)
	_bot.set("player", _p)
	_bot.set("weapon", _w)

	# 1. Ring gate: look at the ring, turn the slice until the core is in it, shoot.
	await _stage(0, 2)
	var rg: Dictionary = _first_part("core", "ring")
	if not rg.is_empty():
		var ring: Node4D = (rg["t"] as Node).call("part", "Ring")["node"]
		_p.call("aim_at", ring.global_position)
		var from: Dictionary = _pose()
		var to: Dictionary = _pose_for((rg["p"]["node"] as Node4D).global_position)
		print("CLIP: beat ring from frame %d" % _n)
		_rec = true
		await _hold(14)
		await _glide(from, to, 44)
		await _hold(6)
		await _tap()
		await _hold(26)
		_rec = false

	# 2. Shell: sealed in your slice, then a step through W past it, and the core.
	await _stage(2, 0)
	var sh: Dictionary = _first_part("core", "shell")
	if not sh.is_empty():
		var at: Vector4 = (sh["p"]["node"] as Node4D).global_position
		_p.call("aim_at", at)
		var from2: Dictionary = _pose()
		var to2: Dictionary = _pose_for(at, at.w + 0.48)
		print("CLIP: beat shell from frame %d" % _n)
		_rec = true
		await _hold(16)
		await _glide(from2, to2, 22)
		await _hold(6)
		await _tap()
		await _hold(24)
		_rec = false

	# 3. Skeet: one pull from each trap, each bird met low on its rise, where its flight path (the target's
	# own `path`) says it will be, and shot there.
	await _stage(4, 0)
	var sk: RefCounted = (_d.get("experiments") as Array)[4]
	# Longer again for the birds: they are small at 10 m, and a wide lens tilted up bends the walls.
	(_p.get("camera") as Camera4D).set("field_of_view_4d", deg_to_rad(45.0))
	_p.call("aim_at", Vector4(-4.0, 3.0, Layout.STAND.z - 9.0, 0.0))
	print("CLIP: beat skeet from frame %d" % _n)
	_rec = true
	for side in 2:
		await _hold(5 if side == 0 else 3)
		sk.call("action")
		var bird: Dictionary = {}
		while bird.is_empty():
			await _frame()
			bird = _first_part("core", "chicken")
		var t: Node4D = bird["t"]
		var hit_age: float = 0.4 if side == 0 else 0.42
		var offset: Vector4 = (bird["p"]["node"] as Node4D).global_position - t.global_position
		var meet: Vector4 = (t.get("path") as Callable).call(t, hit_age) + offset
		var frames: int = maxi(4, int(round((hit_age - float(t.get("age"))) * 30.0)))
		await _glide(_pose(), _pose_for(meet), frames)
		_p.call("aim_at", (bird["p"]["node"] as Node4D).global_position)
		_w.call("press")
		await _frame()
		_p.call("aim_at", (bird["p"]["node"] as Node4D).global_position)
		var r: Dictionary = _w.call("release")
		print("CLIP: bird %d at age %.2f, frame %d: %s" % [side + 1, float(t.get("age")), _n, str(r.get("outcome", "missed"))])
		await _hold(16 if side == 0 else 24)
	_rec = false
	print("CLIP: %d frames, %.1f s" % [_n, _n / 30.0])
	print("CLIP: done")
	quit()
