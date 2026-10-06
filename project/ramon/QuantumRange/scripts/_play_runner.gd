extends SceneTree

## Plays experiments end to end with the test player (_range_bot.gd), the way a person would, and
## photographs every stage: its card, a moment in, and the results card. Proves each stage can be
## finished (plan steps 49 to 59 and 66). Frames in smoke_test_output/quantum_range/play/.
##
##   range_run.sh windowed play res://ramon/QuantumRange/scripts/_play_runner.gd exps=1,2 scale=2
##
## exps: which experiments (1 to 5); scale: time scale (2 plays twice as fast; the frames are the same).

const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/quantum_range/play/"
const Bot := preload("res://ramon/QuantumRange/scripts/_range_bot.gd")
const STAGE_LIMIT := 75.0

var _r: Node
var _d: Node
var _bot: RefCounted
var _t0: int = 0
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d2: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 860000:
		print("PLAY: gave up after 860 s")
		return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var exps: Array = [1, 2, 3, 4, 5]
	var scale: float = 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("exps="):
			exps = []
			for s in a.substr(5).split(","):
				exps.append(int(s))
		elif a.begins_with("scale="):
			scale = float(a.substr(6))
	_r = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_r)
	current_scene = _r
	for i in 20:
		await process_frame
	_d = _r.get("director")
	var player: CharacterBody4D = _r.get("player")
	player.call("place", Vector4(0, 0.05, 1.5, 0), 0.0)
	(_r.get("sfx") as Node).set("muted", true)
	await create_timer(0.5).timeout
	await _shot("00_lobby")
	_bot = Bot.new()
	_bot.set("director", _d)
	_bot.set("player", player)
	_bot.set("weapon", _r.get("weapon"))
	_bot.set("tree", self)
	Engine.time_scale = scale
	for n in exps:
		await _play(int(n) - 1)
	Engine.time_scale = 1.0
	print("PLAY: %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


func _play(i: int) -> void:
	var e: RefCounted = (_d.get("experiments") as Array)[i]
	var nm: String = String(e.get("id"))
	_d.call("select", i)
	_d.call("start", i)
	var last_stage: int = -1
	var shot_mid: bool = false
	var t_stage: float = 0.0
	var t_pull: float = 0.0
	var last: int = Time.get_ticks_usec()
	while true:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var dt: float = float(now - last) / 1000000.0 * Engine.time_scale
		last = now
		var state: String = String(_d.get("state"))
		var stage: int = int(_d.get("stage"))
		if stage != last_stage:
			last_stage = stage
			shot_mid = false
			t_stage = 0.0
			await _shot("%s_%d_card" % [nm, stage])
		if state == "stage":
			t_stage += dt
			_bot.call("step", dt)
			# The skeet's pulls: as soon as the last bird is down.
			if nm == "skeet" and bool(e.get("_waiting")):
				t_pull += dt
				if t_pull > 0.6:
					t_pull = 0.0
					e.call("action")
			if not shot_mid and t_stage > 0.9:
				shot_mid = true
				await _shot("%s_%d_play" % [nm, stage])
			if t_stage > STAGE_LIMIT:
				_check(false, "%s stage %s finishes within %d s" % [nm, char(65 + stage), int(STAGE_LIMIT)])
				_d.call("start", (i + 1) % 5)
				return
		elif state == "failed":
			_check(false, "%s stage %s did not fail (%s)" % [nm, char(65 + stage), _d.get("_fail_reason")])
			return
		elif state == "results":
			await create_timer(0.6).timeout
			await _shot("%s_9_results" % nm)
			var r: Dictionary = (_d.get("results") as Dictionary)[nm]
			_check(true, "%s finished: %.1f s (par %.0f), %d shots, %d%% accurate, %d wasted, %.1f m of W, %d degrees of slice, %.0f us a ray, stages %s" % [nm, float(r["time"]), float(r["par"]),
				int(r["shots"]), int(round(float(r["accuracy"]))), int(r["wasted"]), float(r["w"]), int(round(float(r["slice"]))), float(r["ray_us"]), str(r["stage_times"])])
			return
