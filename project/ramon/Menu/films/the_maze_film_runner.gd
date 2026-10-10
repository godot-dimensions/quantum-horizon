extends SceneTree

## The Maze's menu film (Phase Maze remake, PhaseMazeRemake/phase_maze_remake.tscn): five shots, hard cuts,
## no HUD, for menu_final's details pane.
##
##   1. CINEMATIC  level 5, the cube: a slow high arc round the maze, the walker small on the overlook
##                 that hangs 14 m over it.
##   2. GAMEPLAY   level 2: down a corridor to a dead end, then the turn into W, eased, so the hidden
##                 staircase swings in ahead of him.
##   3. GAMEPLAY   the staircase that exists only turned: he climbs it towards the camera.
##   4. GAMEPLAY   at the top, level again, and out onto the exit's pad.
##   5. CINEMATIC  the reward hall: low and looking up, the giant chickens circling over him.
##
## THE CAMERA IS THE FILM'S OWN: a copy of the walker's Camera4D (same renderer, lens settings, W fade),
## made current and placed every frame, after the physics, from process_frame. It is always put in the
## walker's slice (its W column is the walker rig's, its position moved onto his hyperplane), so the
## cross-section it shows is the one the player would see; within that slice it is a free 3D camera
## (eye, look-at) in the rig's frame. The walker walks by the real movement actions (pressed from here;
## the window is unfocusable, so nobody's real keys reach him), and the turns are the view's own quarter
## turn (maze_view_4d.gd quarter_turn: the heading snapped, forward swung into ana), eased here over a
## second instead of 0.35 s so the maze can be seen rearranging.
##
## Nothing is saved: bests are off before the scene enters the tree, the mood is set without `remember`,
## every node's input processing is switched off (no Tab panel, no B, no SAVE), and no key is ever sent.
##
##   bash Menu/films/film_run.sh the_maze res://ramon/Menu/films/the_maze_film_runner.gd

const Kit := preload("res://ramon/Menu/films/film_kit.gd")
const GB := preload("res://ramon/PhaseMazeRemake/carried/walker/ground_basis_4d.gd")
const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const DT := 1.0 / 30.0
const GUARD_MS := 300000

var _kit: RefCounted
var _t0: int = 0
var _m: Node4D
var _p: CharacterBody4D
var _rig: Node4D
var _view: Node
var _cam: Camera4D
## The current shot's camera, called once a frame after the physics; `_f` counts its frames.
var _cam_fn: Callable = Callable()
var _f: int = 0
## A critically damped follow (the camera's lag behind the walker).
var _sm: Vector4 = Vector4.ZERO
var _sv: Vector4 = Vector4.ZERO
## A shot's fixed frame and anchor (the stair and the exit shots).
var _frame: Projection = Projection.IDENTITY
var _anchor: Vector4 = Vector4.ZERO


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	var out: String = ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("out="):
			out = String(a).substr(4)
	_kit = Kit.new(self, out)
	_kit.calm_window()
	process_frame.connect(_direct)
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > GUARD_MS:
		print("FILM the_maze: gave up after %d s" % (GUARD_MS / 1000))
		_release()
		return true
	return false


func _release() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"move_ana", &"move_kata"]:
		Input.action_release(a)


# -- the camera ----------------------------------------------------------------------------------------

func _direct() -> void:
	if _cam == null or not _cam_fn.is_valid():
		return
	_cam_fn.call()
	_f += 1


static func _v(f: Projection, v: Vector3) -> Vector4:
	return f.x * v.x + f.y * v.y + f.z * v.z


static func _local(f: Projection, o: Vector4, p: Vector4) -> Vector3:
	var d: Vector4 = p - o
	return Vector3(d.dot(f.x), d.dot(f.y), d.dot(f.z))


## The camera at `eye` looking at `look`, both in the 3D frame `f` (x right, y up, z back) from `o`, moved
## onto the walker's slice (f's W column through his position), with a vertical lens of `fov` degrees.
func _shoot(f: Projection, o: Vector4, eye: Vector3, look: Vector3, fov: float) -> void:
	var b: Basis = Basis.looking_at(look - eye, Vector3.UP)
	var n: Vector4 = f.w
	var pos: Vector4 = o + _v(f, eye)
	pos += n * (_p.global_position - pos).dot(n)
	_cam.position = pos
	_cam.basis = Projection(_v(f, b.x), _v(f, b.y), _v(f, b.z), n)
	_cam.set("field_of_view_4d", deg_to_rad(fov))


func _reset_follow(p: Vector4) -> void:
	_sm = p
	_sv = Vector4.ZERO


## One frame of a critically damped follow towards `target` (stiffness `omega`).
func _follow(target: Vector4, omega: float) -> Vector4:
	var x: float = omega * DT
	var e: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: Vector4 = _sm - target
	var temp: Vector4 = (_sv + change * omega) * DT
	_sv = (_sv - temp * omega) * e
	_sm = target + (change + temp) * e
	return _sm


func _k(frames: int) -> float:
	return Kit.ease_io(float(_f) / float(maxi(1, frames - 1)))


## 1. Over the cube: a slow arc round the maze, high, the overlook (and him on it) in front of its middle.
func _cam_overlook() -> void:
	var k: float = _k(96)
	var th: float = deg_to_rad(lerpf(-25.0, -6.0, k))
	var r: float = lerpf(29.0, 27.0, k)
	var eye := Vector3(r * sin(th), lerpf(25.0, 26.5, k), -18.0 + r * cos(th))
	_shoot(Projection.IDENTITY, Vector4.ZERO, eye, Vector3(0.0, 4.0, -14.0), 42.0)


## 2. High over his shoulder, riding the rig's frame, so the turn swings the camera with the slice. Close
## enough behind (3.6 m) to stay inside his layer once turned, high enough (9 m) to see over its walls.
func _cam_corridor() -> void:
	var o: Vector4 = _follow(_p.global_position, 6.0)
	_shoot(_rig.basis, o, Vector3(1.8, 9.0, 3.6), Vector3(-0.2, 0.2, -2.6), 52.0)


## 3. From the top of the stair, looking back down it at him climbing, easing back.
func _cam_stairs() -> void:
	var k: float = _k(90)
	var eye: Vector3 = Vector3(-1.2, 4.9, -16.6).lerp(Vector3(-1.0, 5.2, -18.6), k)
	var at: Vector3 = _local(_frame, _anchor, _follow(_p.global_position, 6.0)) + Vector3(0.0, 0.95, 0.0)
	_shoot(_frame, _anchor, eye, at, 40.0)


## 4. Inside the exit's room, the pad in the foreground, as he comes through the opening.
func _cam_exit() -> void:
	var k: float = _k(72)
	var eye: Vector3 = Vector3(10.1, 5.1, -0.8).lerp(Vector3(9.5, 4.9, -1.3), k)
	var h: Vector4 = _follow(_p.global_position, 5.0)
	var look: Vector3 = Vector3(h.x, h.y + 1.0, h.z).lerp(Vector3(7.0, 2.6, -3.0), 0.3)
	_shoot(Projection.IDENTITY, Vector4.ZERO, eye, look, 40.0)


## 5. The hall: low, looking up past him at the flock.
func _cam_hall() -> void:
	var k: float = _k(100)
	var eye: Vector3 = Vector3(5.0, 2.2, -197.5).lerp(Vector3(2.6, 2.3, -198.5), k)
	var look: Vector3 = Vector3(-1.0, 5.5, -221.0).lerp(Vector3(-0.4, 5.8, -221.0), k)
	(_m.get("console") as Node4D).visible = false
	_shoot(Projection.IDENTITY, Vector4.ZERO, eye, look, 50.0)


# -- the maze ------------------------------------------------------------------------------------------

## Nobody's input reaches the scene, the mouse is free, the HUD is hidden, the rig never pulls in.
func _calm() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var all: Array = _m.find_children("*", "", true, false)
	all.append(_m)
	for n in all:
		(n as Node).set_process_input(false)
		(n as Node).set_process_unhandled_input(false)
		(n as Node).set_process_unhandled_key_input(false)
		(n as Node).set_process_shortcut_input(false)
	_view.set("keys_on", false)
	_rig.set("collide_with_world", false)
	_kit.hide_layers(_m)


## The view's own quarter turn (maze_view_4d.gd): from level, the heading snapped to a corridor and what
## is ahead swung into ana.
static func _into_w(b: Projection) -> Projection:
	var b0: Projection = Basis4D.from_zx(snappedf(GB.heading(b), PI * 0.5))
	return Projection(b0.x, GB.UP, -b0.w, b0.z)


static func _angle(a: Projection, b: Projection) -> float:
	var q: Quaternion = GB._to_3d(Basis4D.transposed(a) * b).get_rotation_quaternion()
	return 2.0 * acos(clampf(absf(q.w), 0.0, 1.0))


## The rig eased from where it is to `t` over `frames`, frame by frame (recorded or not as the kit is).
func _turn(t: Projection, frames: int) -> void:
	var b0: Projection = _rig.basis
	var ang: float = _angle(b0, t)
	for i in frames:
		_rig.basis = GB.rotated_toward(b0, t, ang * Kit.ease_io(float(i + 1) / float(frames)))
		_rig.call("_apply")
		await _kit.frame()
	_rig.basis = t
	_rig.call("_apply")


func _place(at: Vector4, face: Vector4) -> void:
	_m.call("_place_player", at, face)
	_p.set("input_enabled", false)


func _run() -> void:
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	_p = _m.get("player")
	_rig = _m.get("rig")
	_view = _m.get("view")
	_calm()
	(_m.get_node("Light") as Node).call("set_mood", "bright", true, false)
	# The film's own camera: the walker's, copied (its renderer and lens settings), made current.
	_cam = (_m.get("camera") as Camera4D).duplicate() as Camera4D
	_cam.name = "FilmCamera"
	_m.add_child(_cam)
	_cam.set("current", true)
	await _kit.skip(30)

	# 1. CINEMATIC: the cube from its overlook. He stands at the north rail, in layer 1 (the overlook spans
	# every layer; layer 0's north half is roofed, layer 1 lies open below).
	_m.call("_load_level", 4)
	_calm()
	_place(Vector4(0.0, 14.1, -4.7, 7.0), Vector4(0, 0, -1, 0))
	_cam_fn = _cam_overlook
	await _kit.skip(40)
	_f = 0
	_kit.recording = true
	await _kit.hold(96)
	_kit.recording = false
	print("FILM the_maze: shot 1 overlook to frame %d" % _kit.count)

	# 2. GAMEPLAY: level 2, from the start cell east to the dead end, and the turn into W.
	_m.call("_load_level", 1)
	_calm()
	_m.set("on_overlook", false)
	var ov: Dictionary = _m.get("overlook")
	(ov["lift"] as Node4D).position.y = float(ov["bottom"])
	_place(Vector4(-5.4, 0.1, -3.0, 0.0), Vector4(1, 0, 0, 0))
	await _kit.skip(20)
	_reset_follow(_p.global_position)
	_cam_fn = _cam_corridor
	_p.set("input_enabled", true)
	Input.action_press(&"move_forward")
	await _kit.skip(12)
	_f = 0
	_kit.recording = true
	var guard: int = 0
	while _p.global_position.x < -0.12 and guard < 120:
		guard += 1
		await _kit.frame()
	_release()
	_p.set("input_enabled", false)
	await _kit.hold(8)
	await _turn(_into_w(_rig.basis), 34)
	_p.call("face_towards", _p.global_position - _rig.basis.z * 6.0)
	await _kit.hold(16)
	_kit.recording = false
	_p.call("stop_facing")
	print("FILM the_maze: shot 2 corridor+F to frame %d (walk %d frames, at %s, hidden axis %s)" % [_kit.count, guard,
		str(_p.global_position), str(_view.get("hidden_axis"))])

	# 3. GAMEPLAY: up the stair through W (turned, forward is +w), filmed from its top.
	_frame = _rig.basis
	_anchor = Vector4(_p.global_position.x, 0.0, -3.0, 0.0)
	_reset_follow(_p.global_position)
	_cam_fn = _cam_stairs
	_p.set("input_enabled", true)
	Input.action_press(&"move_forward")
	guard = 0
	while _p.global_position.w < 3.4 and guard < 120:
		guard += 1
		await _kit.frame()
	_f = 0
	_kit.recording = true
	await _kit.hold(90)
	_kit.recording = false
	print("FILM the_maze: shot 3 stairs to frame %d (at %s)" % [_kit.count, str(_p.global_position)])
	guard = 0
	while _p.global_position.w < 17.8 and guard < 200:
		guard += 1
		await _kit.frame()
	_release()
	_p.set("input_enabled", false)

	# 4. GAMEPLAY: level again at the top, and out east onto the exit.
	await _turn(GB.flattened(_rig.basis), 16)
	var y: float = _p.global_position.y
	_p.global_position = Vector4(-2.4, y, -3.0, 18.0)
	_p.set("linear_velocity", Vector4.ZERO)
	_p.call("face_towards", Vector4(10.0, y, -3.0, 18.0))
	await _kit.skip(12)
	_p.call("stop_facing")
	_reset_follow(_p.global_position)
	_cam_fn = _cam_exit
	_p.set("input_enabled", true)
	Input.action_press(&"move_forward")
	await _kit.skip(4)
	_f = 0
	_kit.recording = true
	guard = 0
	while String(_m.get("state")) != "finished" and guard < 150:
		guard += 1
		await _kit.frame()
	_release()
	await _kit.hold(5)
	_kit.recording = false
	print("FILM the_maze: shot 4 exit to frame %d (state %s, at %s)" % [_kit.count, String(_m.get("state")), str(_p.global_position)])

	# 5. CINEMATIC: the hall, once the game has taken him there (behind its fade, which is HUD and hidden).
	guard = 0
	while _p.global_position.z > -150.0 and guard < 150:
		guard += 1
		await _kit.frame()
	_reset_follow(_p.global_position)
	_cam_fn = _cam_hall
	_calm()
	await _kit.skip(6)
	_f = 0
	_kit.recording = true
	await _kit.hold(100)
	_kit.recording = false
	print("FILM the_maze: shot 5 hall to frame %d (at %s)" % [_kit.count, str(_p.global_position)])

	_release()
	print("FILM the_maze: %d frames, %.1f s" % [_kit.count, float(_kit.count) / 30.0])
	quit()
