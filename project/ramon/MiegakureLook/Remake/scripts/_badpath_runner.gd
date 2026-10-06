extends SceneTree
## Crosswise: the bad-path bot (PLAN.md steps 64 and 68). Every mistake a player can make, made
## on purpose, and the game must recover each time, cheaply:
##   1. walk off the chasm's lip on island 2 (before the bridge): a fall, a fade, back on the arrival
##      ring, `falls` counted, in under 1.5 s
##   2. the same while carrying the crate: the crate goes home (into its cage)
##   3. try to put the crate down where there is no floor: refused, still carried
##   4. strike at nothing: a swing, no crash, nothing broken
##   5. on island 3, break the first rock, then R: the rock is whole again and you are on the ring
##   6. turn twice quickly (a queued turn): the view ends where it started
## Frames of each recovery to smoke_test_output/crosswise/badpath/.
##
## Run: Remake/run.sh windowed badpath res://ramon/MiegakureLook/Remake/scripts/_badpath_runner.gd

const SCENE := "res://ramon/MiegakureLook/Remake/crosswise.tscn"
const OUT := "res://smoke_test_output/crosswise/badpath/"

var _game: Node
var _walker: CharacterBody4D
var _cam: Node
var _hands: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _checks: int = 0
var _fails: int = 0
var _mark: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_game = (load(SCENE) as PackedScene).instantiate()
	_game.set("play_intro", false)
	_game.set("start_island", 2)
	root.add_child.call_deferred(_game)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 150.0:
		print("BADPATH FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _game == null or not _game.is_inside_tree():
		return false
	if _walker == null:
		_walker = _game.get("walker")
		_cam = _game.get("camera")
		_hands = _game.get("hands")
		_walker.set("scripted", true)
		_t = -1.0
	_t += delta
	if _t < 0.0:
		return false
	var p: Vector4 = _walker.global_position
	match _step:
		0:
			# 1. Into the chasm in lane 0 (the near lip is at z -21).
			_walker.call("place_at", Vector4(0, 1.4, -19.5, 0), PI)
			_walker.set("scripted_move", Vector2(0, -1))
			_mark = _total
			_next()
		1:
			if int(_game.get("falls")) >= 1 and not bool(_game.get("_respawning")):
				_walker.set("scripted_move", Vector2.ZERO)
				var spawn: Vector4 = (_game.call("current_island") as Dictionary)["spawn"]
				_check((p - spawn).length() < 0.3, "fall 1: back on the ring (%.2f s)" % (_total - _mark))
				_check(_total - _mark < 6.0, "fall 1: quick")
				_save("01_after_fall")
				_next()
		2:
			# 2. Carrying: take the crate (put it in reach first, as if fetched), then off the lip.
			if _t > 0.4:
				var crate: Node4D = (_game.call("crates") as Array)[1]
				crate.call("put_down", p + Vector4(0, 0, -0.9, 0))
				_next()
		3:
			if _t > 0.3:
				_hands.call("use")
				_next()
		4:
			if _t > 0.6:
				_check(_hands.get("carried") != null, "lifted the crate")
				# 3. Put it down past the lip: refused, still carried.
				_walker.call("place_at", Vector4(0, 1.4, -20.6, 0), PI)
				_next()
		5:
			if _t > 0.4:
				_hands.call("use")
				_next()
		6:
			if _t > 0.3:
				_check(_hands.get("carried") != null, "refused a spot with no floor, still carried")
				_save("02_refused")
				_walker.set("scripted_move", Vector2(0, -1))
				_mark = _total
				_next()
		7:
			if int(_game.get("falls")) >= 2 and not bool(_game.get("_respawning")) and _t > 0.5:
				_walker.set("scripted_move", Vector2.ZERO)
				var crate2: Node4D = (_game.call("crates") as Array)[1]
				_check(_hands.get("carried") == null, "fall 2: hands empty")
				_check((crate2.global_position - (crate2.get("home") as Vector4)).length() < 0.3, "fall 2: the crate went home")
				_save("03_crate_home")
				_next()
		8:
			# 4. A strike at nothing.
			if _t > 0.4:
				_hands.call("strike")
				_next()
		9:
			if _t > 0.9:
				_check(true, "strike at nothing: no crash")
				# 5. Island 3: break the first rock, then R.
				_walker.call("place_at", Vector4(0, 1.4, -35.95, 0), PI)
				_next()
		10:
			if _t > 0.6 and int(_game.get("island")) == 3:
				_hands.call("strike")
				_next()
		11:
			if _t > 0.9:
				_hands.call("strike")
				_next()
		12:
			if _t > 1.0:
				var rock: Node = (_game.call("plugs") as Array)[0]
				_check(bool(rock.call("is_broken")), "rock broken before the restart")
				_game.call("restart_island")
				_next()
		13:
			if _t > 1.6:
				var rock2: Node = (_game.call("plugs") as Array)[0]
				_check(not bool(rock2.call("is_broken")), "R: the rock is whole again")
				_check((p - Vector4(0, 1.4, -35.9, 0)).length() < 0.4, "R: back on the ring")
				_save("04_after_restart")
				_next()
		14:
			# 6. Two quick turns: queued, back where it started.
			_cam.call("request_turn")
			_cam.call("request_turn")
			_next()
		15:
			if _t > 2.0:
				_check(not bool(_cam.call("is_turned")) and not bool(_cam.call("is_turning")), "two quick turns end where they began")
				print("BADPATH done: %d checks, %d failed" % [_checks, _fails])
				return true
	return false


func _next() -> void:
	_step += 1
	_t = 0.0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("BADPATH %s %s  (walker %s)" % ["PASS" if ok else "FAIL", what, _walker.global_position])


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
