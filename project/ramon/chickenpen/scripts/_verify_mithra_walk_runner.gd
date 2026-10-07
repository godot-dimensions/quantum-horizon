extends SceneTree

## Mithra keeps walking (Ramon, 7 Oct: "mirtha is crying against the wall or too close to the wall and
## not walking ... once again, mirtha is stuck and not walking. it worries me"). Three minutes of her
## searching, the player far off so nothing stops her, sampled every physics frame:
##   1. she is never stuck: walking (not in one of her pauses) yet not moving, for over 2 s at a time
##   2. she never presses against the town wall (its south face at z 11.7; her body is 0.3 m round)
##   3. she gets about: at least 12 spots reached, and over 40 m walked
##   4. she stays in her patch (her roam radius plus a metre round where she started)
##
##   lab_run.sh fast mithra res://ramon/chickenpen/scripts/_verify_mithra_walk_runner.gd

const WATCH_SECONDS := 180.0
const WALL_FACE_Z := 11.7

var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _run() -> void:
	var room: Node = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	for node in room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(room)
	current_scene = room
	var player := room.get_node("Player") as CharacterBody4D
	player.set("input_enabled", false)
	player.global_position = Vector4(30.0, 1.2, 40.0, 0.0)
	var her := room.get_node("Mithra") as CharacterBody4D
	if OS.get_cmdline_user_args().has("old"):
		# Her walk as it was before 7 Oct, to show this test catches what Ramon saw.
		her.set_script(load("res://ramon/chickenpen/.backup/2026-10-07_round2/chickenpen/scripts/pen_searcher_4d.gd"))
		her.set("roam_radius", 6.5)
		her.call("_ready")
		print("   (her old walk)")
	var home: Vector4 = her.global_position
	var radius: float = float(her.get("roam_radius"))
	for i in 30:
		await physics_frame
	var t: float = 0.0
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var last: Vector4 = her.global_position
	var walked: float = 0.0
	var still: float = 0.0
	var worst_still: float = 0.0
	var worst_at := Vector4.ZERO
	var max_z: float = -INF
	var max_off: float = 0.0
	var spots: int = 0
	var was_paused: bool = true
	while t < WATCH_SECONDS:
		await physics_frame
		t += dt
		var p: Vector4 = her.global_position
		var moved: float = Vector2(p.x - last.x, p.z - last.z).length()
		walked += moved
		last = p
		var paused: bool = float(her.get("_pause")) > 0.0
		if paused and not was_paused:
			spots += 1
		was_paused = paused
		if not paused and moved / dt < 0.15:
			still += dt
			if still > worst_still:
				worst_still = still
				worst_at = p
		else:
			still = 0.0
		max_z = maxf(max_z, p.z)
		max_off = maxf(max_off, Vector2(p.x - home.x, p.z - home.z).length())
	print("   watched %.0f s: walked %.1f m, %d stops, furthest %.1f m from her start, nearest the wall z %.2f" % [
		t, walked, spots, max_off, max_z])
	_check(worst_still <= 2.0, "1 never stuck: longest stand while meaning to walk %.1f s (at %.1f, %.1f)" % [worst_still, worst_at.x, worst_at.z])
	_check(max_z < WALL_FACE_Z - 0.45, "2 never against the town wall: nearest z %.2f (wall face %.1f)" % [max_z, WALL_FACE_Z])
	_check(spots >= 12 and walked > 40.0, "3 she gets about: %d spots, %.0f m" % [spots, walked])
	_check(max_off <= radius + 1.0, "4 stays in her patch: %.1f m out (roam %.1f)" % [max_off, radius])
	print("MITHRA TEST: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0)
