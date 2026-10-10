extends SceneTree

## The menu film of Crosswise (Menu/films/film_kit.gd says how a menu film is made): five shots, hard
## cuts, no HUD, about 17 s at 30 fps.
##
##   1. CINEMATIC  the chain of floating islands, a slow eased crane down and along it to the shrine tower
##   2. GAMEPLAY   The Wall: a quarter turn into W, two lanes ana, the turn back: the wall is gone, and
##                 he walks through the torii where it stood
##   3. GAMEPLAY   The Cage: turned into W the cage is open; in, lift the crate, out, and the turn back
##                 leaves him on the cage's painted outline with the crate and no cage
##   4. GAMEPLAY   The Seam: turned, two strikes break the rock in the fence's door, and he walks through
##   5. CINEMATIC  The Shrine: he reaches the door, the tower's lamps light, the camera pulls out
##
## The gameplay shots use the game's own diorama camera (its follow, its turn), a little closer than
## play's 10.5 m for the small pane; the cinematic ones take the camera off its script and ease it by
## hand. The sky is lifted most of the way to Crosswise's own pale mint (the dev panel's "Sky lift" at
## 0.85, set at runtime, never saved), so the islands do not float in black and the turned view still
## shifts to violet (stills of 0, 0.15, 0.85 and 1 compared on 9 Oct; half-way read as a muddy fog). The
## cinematic shots look from the -X side: from +X the fill light's sky disc sits in the top of the frame
## as a dark smudge.
##
## The walker is driven the way the solver bot drives him (scripts/_solve_runner.gd): his scripted keys,
## the camera's request_turn, the hands' use() and strike(). Nothing is saved into the scene.
##
##   bash Menu/films/film_run.sh crosswise res://ramon/Menu/films/crosswise_film_runner.gd

const Kit := preload("res://ramon/Menu/films/film_kit.gd")
const SCENE := "res://ramon/Crosswise/crosswise.tscn"
const Y2 := 1.35
const SHRINE_Y := 2.95
const SKY_LIFT := 0.85
const GUARD_MS := 300000

var _kit: RefCounted
var _game: Node
var _walker: CharacterBody4D
var _cam: Camera4D
var _hands: Node
var _env: Node
var _t0: int = 0


func _initialize() -> void:
	var out: String = ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("out="):
			out = String(a).substr(4)
	_kit = Kit.new(self, out)
	_kit.calm_window()
	_t0 = Time.get_ticks_msec()
	_game = (load(SCENE) as PackedScene).instantiate()
	_game.set("play_intro", false)
	root.add_child(_game)
	current_scene = _game
	_run.call_deferred()


## The guard: quits on its own whatever happens to the film.
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _t0 > GUARD_MS:
		print("FILM crosswise: gave up after %d s at %d frames" % [GUARD_MS / 1000, int(_kit.get("count"))])
		return true
	return false


func _run() -> void:
	await _kit.skip(20)
	_walker = _game.get("walker")
	_cam = _game.get("camera")
	_hands = _game.get("hands")
	_env = _game.get("env")
	# Nobody's keys or mouse reach the game: the walker takes only scripted keys, the hands, the camera's
	# turn, the game's keys (R, [ ], V, F), the dev panel and the menu button are all switched off.
	_walker.set("scripted", true)
	_hands.set("input_enabled", false)
	_cam.set_process_unhandled_input(false)
	_game.set_process_unhandled_key_input(false)
	var tuner: Node = _game.get("tuner")
	if tuner != null:
		tuner.set_process_unhandled_key_input(false)
	var rb: Node = _game.get_node_or_null("ReturnButton")
	if rb != null:
		rb.set_process_unhandled_input(false)
	_kit.hide_layers(_game)
	_env.call("set_value", "sky_lift", SKY_LIFT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await _shot_islands()
	await _shot_wall()
	await _shot_cage()
	await _shot_seam()
	await _shot_shrine()

	_kit.set("recording", false)
	print("FILM crosswise: %d frames, %.1f s" % [int(_kit.get("count")), float(int(_kit.get("count"))) / 30.0])
	quit()


# ---------------------------------------------------------------------------------------------
# The shots


## 1. The islands: high over the Cage, craning down and along the chain to the shrine tower.
func _shot_islands() -> void:
	_free_camera(true, 36.0)
	await _kit.skip(10)
	print("FILM crosswise: shot 1 (islands) from frame %d" % int(_kit.get("count")))
	_kit.set("recording", true)
	var a := {"f": Vector4(0, 2.0, -28.0, 0), "p": 22.0, "y": -38.0, "d": 31.0}
	var b := {"f": Vector4(0, 6.0, -62.0, 0), "p": 14.0, "y": -20.0, "d": 29.0}
	await _kit.glide(100, func(t: float) -> void: _cam_between(a, b, t))
	_kit.set("recording", false)


## 2. The Wall: turn, walk two lanes ana, turn back: the wall is not in this world; through the torii.
func _shot_wall() -> void:
	_free_camera(false)
	_game.call("skip_to", 1)
	_walker.call("place_at", Vector4(0, 0.05, 1.3, 0), PI)
	_game_camera(9.2, 50.0, 30.0, 0.1)
	await _kit.skip(30)
	print("FILM crosswise: shot 2 (wall) from frame %d" % int(_kit.get("count")))
	_kit.set("recording", true)
	await _kit.hold(8)
	await _turn()
	await _walk(0.0, 3.2, 50)
	await _turn()
	await _walk(0.0, -1.9, 32)
	await _kit.hold(4)
	_kit.set("recording", false)
	_walker.set("scripted_move", Vector2.ZERO)


## 3. The Cage: turned, the cage's open side faces him; in, lift, out, and the turn back.
func _shot_cage() -> void:
	_game.call("skip_to", 2)
	_walker.call("place_at", Vector4(-2.4, Y2 + 0.05, -14.6, -1.75), PI)
	_cam.call("set_turned", true)
	_game_camera(7.8, 50.0, 30.0, 0.1)
	await _kit.skip(30)
	print("FILM crosswise: shot 3 (cage) from frame %d" % int(_kit.get("count")))
	_kit.set("recording", true)
	await _kit.hold(6)
	await _walk(-2.4, -0.62, 30)
	_hands.call("use")
	await _kit.hold(20)
	await _walk(-2.4, -1.6, 30)
	await _turn()
	await _kit.hold(16)
	_kit.set("recording", false)


## 4. The Seam: turned, at the rock in the fence's door; two strikes, and through.
func _shot_seam() -> void:
	_game.call("skip_to", 3)
	_walker.call("place_at", Vector4(0, Y2 + 0.05, -44.2, 0.9), PI)
	_cam.call("set_turned", true)
	_game_camera(7.8, 50.0, 30.0, 0.1)
	await _kit.skip(30)
	print("FILM crosswise: shot 4 (seam) from frame %d" % int(_kit.get("count")))
	_kit.set("recording", true)
	await _kit.hold(4)
	await _walk(0.0, 1.62, 30)
	_hands.call("strike")
	await _kit.hold(18)
	_hands.call("strike")
	await _kit.hold(22)
	await _walk(0.0, 3.3, 30)
	await _kit.hold(6)
	_kit.set("recording", false)
	_walker.set("scripted_move", Vector2.ZERO)


## 5. The Shrine: the crate on its mark (as he left it), he walks to the door, the lamps light, the
## camera pulls out and up round the tower.
func _shot_shrine() -> void:
	_game.call("skip_to", 4)
	var crates: Array = _game.call("crates")
	if crates.size() > 2:
		crates[2].call("put_down", Vector4(0, Y2 + 0.02, -62.5, 0))
	_cam.call("set_turned", false)
	_walker.call("place_at", Vector4(0, SHRINE_Y + 0.05, -63.25, 0), PI)
	_free_camera(true, 34.0)
	var a := {"f": Vector4(0, 4.4, -64.4, 0), "p": 14.0, "y": -22.0, "d": 10.5}
	var b := {"f": Vector4(0, 6.8, -66.2, 0), "p": 16.0, "y": -34.0, "d": 16.5}
	_cam_between(a, b, 0.0)
	await _kit.skip(20)
	print("FILM crosswise: shot 5 (shrine) from frame %d" % int(_kit.get("count")))
	_kit.set("recording", true)
	var frames: int = 104
	for i in frames:
		if not bool(_game.get("done")):
			_walker.set("scripted_move", Vector2(0, -1))
			_walker.set("scripted_walk", true)
		else:
			_walker.set("scripted_move", Vector2.ZERO)
		_cam_between(a, b, Kit.ease_io(float(i) / float(frames - 1)))
		await _kit.frame()
	_kit.set("recording", false)
	print("FILM crosswise: finale %s" % str(_game.get("done")))


# ---------------------------------------------------------------------------------------------
# The walker and the turn (the solver bot's way)


## The axis W/S walk along: world Z in the normal view, world W turned.
func _coord(p: Vector4) -> float:
	return p.w if bool(_cam.call("is_turned")) else p.z


## Walks in the current view to world x and depth `c`, for at most `max_frames`.
func _walk(x: float, c: float, max_frames: int) -> void:
	for i in max_frames:
		var p: Vector4 = _walker.global_position
		var dx: float = x - p.x
		var dd: float = c - _coord(p)
		var far: float = Vector2(dx, dd).length()
		if far < 0.09 and _walker.is_on_floor():
			break
		var turned: bool = bool(_cam.call("is_turned"))
		var mv := Vector2(dx, -dd if turned else dd)
		_walker.set("scripted_walk", far < 0.6)
		_walker.set("scripted_move", mv.normalized() * clampf(far * 3.0, 0.35, 1.0))
		await _kit.frame()
	_walker.set("scripted_move", Vector2.ZERO)


## The quarter turn, played out.
func _turn() -> void:
	_cam.call("request_turn")
	await _kit.frame()
	var n: int = 0
	while bool(_cam.call("is_turning")) and n < 60:
		await _kit.frame()
		n += 1


# ---------------------------------------------------------------------------------------------
# The camera


## The game's own camera, at the given distance and angles, snapped onto the walker.
func _game_camera(distance: float, pitch: float, yaw: float, lean: float) -> void:
	_cam.set("distance", distance)
	_cam.set("pitch_degrees", pitch)
	_cam.set("yaw_degrees", yaw)
	_cam.set("fov_degrees", 32.0)
	_cam.set("frame_lean", lean)
	_cam.call("refresh_lens")
	_cam.call("snap_focus")


## Takes the camera off its script (true) for a hand-eased shot, or gives it back (false).
func _free_camera(on: bool, fov: float = 32.0) -> void:
	_cam.set_process(not on)
	_cam.set("fov_degrees", fov)
	_cam.set_field_of_view_3d(deg_to_rad(fov))


## The free camera between two poses ({f focus, p pitch, y yaw, d distance}), `t` 0..1 (already eased).
func _cam_between(a: Dictionary, b: Dictionary, t: float) -> void:
	var f: Vector4 = (a["f"] as Vector4).lerp(b["f"], t)
	var basis: Projection = _look_basis(_direction(lerpf(a["p"], b["p"], t), lerpf(a["y"], b["y"], t)))
	_cam.global_basis = basis
	_cam.global_position = f + basis * Vector4(0, 0, lerpf(a["d"], b["d"], t), 0)


static func _direction(pitch: float, yaw: float) -> Vector4:
	var p := deg_to_rad(pitch)
	var y := deg_to_rad(yaw)
	return Vector4(sin(y) * cos(p), sin(p), cos(y) * cos(p), 0.0)


## The camera script's own construction (scripts/mk_camera_4d.gd _look_basis): local +Z back along
## `direction`, Y as near world up as it can be, W the world's W.
static func _look_basis(direction: Vector4) -> Projection:
	var z_axis := direction.normalized()
	var up := Vector4(0.0, 1.0, 0.0, 0.0)
	var y_axis := (up - z_axis * z_axis.dot(up)).normalized()
	var wx := Vector4(1.0, 0.0, 0.0, 0.0)
	var x_axis := (wx - z_axis * z_axis.dot(wx) - y_axis * y_axis.dot(wx)).normalized()
	return Projection(x_axis, y_axis, z_axis, Vector4(0.0, 0.0, 0.0, 1.0))
