extends SceneTree

## THE TALL ONES' SENSES, MEASURED (level 1's Tall One, at its post facing up the Long Hall). For each case
## the walker is reset, you are placed (standing still unless the case moves you) and the clock runs until
## it turns suspicious (awareness 0.3) and until it has you (notice), at most 8 s. Then its paces: how fast
## it hunts far off and close, and how long it searches where it lost you. Prints a table; checks the
## orderings that make the design (central faster than peripheral, peripheral out of reach unseen, behind
## unseen unless right at its back, a running step heard, the edge of its slice slower).
##   run.sh windowed senses res://ramon/MazeRemake2/scripts/_walker_senses_runner.gd

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"

var _t0: int = 0
var _game: Node
var _player: CharacterBody4D
var _w: Node4D
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 150000:
		print("SENSES FAIL: timeout")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _check(ok: bool, what: String) -> void:
	print("SENSES %s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


## Where you stand for `angle` off its gaze (0 straight ahead) at `dist`, `dw` off its W.
func _spot(angle: float, dist: float, dw: float) -> Vector4:
	var post: Vector4 = _w.get("post")
	var a: float = float(_w.get("post_yaw")) + angle
	return Vector4(post.x - sin(a) * dist, 0.0, post.z - cos(a) * dist, post.w + dw)


## Seconds to suspicious and to notice (-1: not within `limit`). `run` paces you back and forth at 5.4 m/s.
func _case(name: String, angle: float, dist: float, dw: float, run: bool = false, limit: float = 8.0) -> Vector2:
	_w.call("reset")
	var at: Vector4 = _spot(angle, dist, dw)
	_player.call("place", at, 0.0)
	for f in 4:
		await physics_frame
	_w.call("reset")
	var t_sus: float = -1.0
	var t_note: float = -1.0
	var frames: int = int(limit * 60.0)
	for f in frames:
		if run:
			var k: float = sin(float(f) * 0.2) * 0.9
			_player.global_position = at + Vector4(k, 0, 0, 0)
		await physics_frame
		var t: float = float(f + 1) / 60.0
		if t_sus < 0.0 and float(_w.get("awareness")) >= 0.3:
			t_sus = t
		if String(_w.get("state")) in ["notice", "hunt"]:
			t_note = t
			break
	print("SENSES  %-36s suspicious %5s s   notice %5s s" % [name, "-" if t_sus < 0.0 else "%.2f" % t_sus, "-" if t_note < 0.0 else "%.2f" % t_note])
	_w.call("reset")
	return Vector2(t_sus, t_note)


func _run() -> void:
	_game = (load(SCENE) as PackedScene).instantiate()
	_game.set("capture_mouse", false)
	_game.set("popups", false)
	root.add_child(_game)
	for i in 600:
		if String(_game.get("mode")) == "play":
			break
		await physics_frame
	_game.set("sighted", true)
	_player = _game.get("player")
	_player.set("input_enabled", false)
	_w = ((_game.get("level") as Node).get("walkers") as Array)[0]
	# The cases (its notice range here is 7 m).
	var front3: Vector2 = await _case("ahead, 3 m", 0.0, 3.0, 0.0)
	var front6: Vector2 = await _case("ahead, 6 m", 0.0, 6.0, 0.0)
	var per3: Vector2 = await _case("50 deg off, 3 m (peripheral)", deg_to_rad(50.0), 3.0, 0.0)
	var per5: Vector2 = await _case("50 deg off, 5 m (past its reach)", deg_to_rad(50.0), 5.0, 0.0)
	var side: Vector2 = await _case("90 deg off, 2.5 m (beside)", deg_to_rad(90.0), 2.5, 0.0)
	var back3: Vector2 = await _case("behind, 3 m", PI, 3.0, 0.0)
	var back1: Vector2 = await _case("behind, 1.2 m (at its back)", PI, 1.2, 0.0)
	var runb: Vector2 = await _case("behind, 3.5 m, running", PI, 3.5, 0.0, true)
	var edge: Vector2 = await _case("ahead 4 m, 0.4 m off its W (edge)", 0.0, 4.0, 0.4)
	var full: Vector2 = await _case("ahead 4 m, in its W", 0.0, 4.0, 0.0)
	var out: Vector2 = await _case("ahead 3 m, 0.6 m off its W (out)", 0.0, 3.0, 0.6, false, 4.0)
	_check(front3.y > 0.0 and front6.y > front3.y, "ahead: it has you, sooner when close (%.2f s at 3 m, %.2f s at 6 m)" % [front3.y, front6.y])
	_check(per3.y > front3.y, "peripheral is slower than central (%.2f s vs %.2f s)" % [per3.y, front3.y])
	_check(per5.x < 0.0, "past the peripheral reach it does not see you")
	_check(back3.x < 0.0, "behind, 3 m away, it does not see you")
	_check(back1.y > 0.0, "right at its back it feels you (%.2f s)" % back1.y)
	_check(runb.x > 0.0, "running behind it, it hears you (suspicious at %.2f s)" % runb.x)
	_check(edge.y < 0.0 or edge.y > full.y, "at the edge of its slice it is slower (%.2f s vs %.2f s)" % [edge.y, full.y])
	_check(out.x < 0.0, "out of its slice it perceives nothing")
	print("SENSES  (beside, 2.5 m: suspicious %.2f, notice %.2f)" % [side.x, side.y])
	# Its paces: hunting you from 8 m, far and close.
	_w.call("reset")
	_player.call("place", _spot(0.0, 8.5, 0.0), 0.0)
	await physics_frame
	_w.call("hunt_now")
	for f in 70:
		await physics_frame
	var q0: Vector4 = _w.global_position
	for f in 60:
		await physics_frame
	var far_speed: float = Vector2(_w.global_position.x - q0.x, _w.global_position.z - q0.z).length()
	for f in 600:
		var d: Vector4 = _player.global_position - _w.global_position
		if Vector2(d.x, d.z).length() < 3.4:
			break
		await physics_frame
	var q1: Vector4 = _w.global_position
	for f in 30:
		await physics_frame
	var close_speed: float = Vector2(_w.global_position.x - q1.x, _w.global_position.z - q1.z).length() * 2.0
	print("SENSES  hunting pace: %.2f m/s far, %.2f m/s within 4 m (you walk 3.4)" % [far_speed, close_speed])
	_check(far_speed > 1.1 and far_speed < 1.6 and close_speed > far_speed, "it hunts a little faster than it paces, and faster again close")
	# Searching: you shift out of its slice; it goes to where you were and looks about, then gives up.
	_player.global_position = _player.global_position + Vector4(0, 0, 0, 1.2)
	var t_search: float = -1.0
	var t_give: float = -1.0
	for f in 900:
		await physics_frame
		var st: String = String(_w.get("state"))
		if t_search < 0.0 and st == "search":
			t_search = float(f) / 60.0
		if st in ["return", "idle"]:
			t_give = float(f) / 60.0
			break
	print("SENSES  out of its slice: searching after %.2f s, gives up after %.2f s" % [t_search, t_give])
	_check(t_search >= 0.0 and t_search < 1.5 and t_give > 4.0, "it searches where it lost you, then gives up")
	print("SENSES DONE fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
