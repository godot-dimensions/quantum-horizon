extends SceneTree

## The Annex's menu film (Maze Remake 2, MazeRemake2/maze_remake_2.tscn): six shots, hard cuts, no HUD,
## in the dark look (round 2, 11 Oct), for menu_final's details pane. Every shot is the player's own
## first-person camera:
##
##   1. GAMEPLAY   level 1: down the corridor at the teal door; W rises and its leaves slide apart.
##   2. CINEMATIC  level 1's garden hall, the bright room: a slow drift past the oak as W climbs.
##   3. CINEMATIC  level 1's Long Hall: a slow push toward a Tall One; its head turns, its eyes go red.
##   4. GAMEPLAY   level 2's ambush: the kennel's slab sinks and its Tall Ones walk out, ana.
##   5. GAMEPLAY   level 2's pit: on the landing, W sweeps from kata to ana; the amber bridge behind
##                 narrows away and the teal one grows ahead.
##   6. CINEMATIC  level 3: at the atrium's centre the view turns into W, and the Heart stands ahead,
##                 white, with the Dreamer inside.
##
## The player's physics is switched off and the body placed every frame (it is a camera here); nothing
## is saved, no key is sent, the mood is set without remembering it.
##
##   bash Menu/films/film_run.sh the_annex res://ramon/Menu/films/the_annex_film_runner.gd

const Kit := preload("res://ramon/Menu/films/film_kit.gd")
const GB := preload("res://ramon/MazeRemake2/carried/ground_basis_4d.gd")
const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const GUARD_MS := 300000

var _kit: RefCounted
var _t0: int = 0
var _g: Node
var _p: CharacterBody4D


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	var out: String = ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("out="):
			out = String(a).substr(4)
	_kit = Kit.new(self, out)
	_kit.calm_window()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > GUARD_MS:
		print("FILM the_annex: gave up after %d s" % (GUARD_MS / 1000))
		quit(1)
		return true
	return false


## The eye at `feet` (x, z, w; standing), heading `yaw` (0 faces -z), pitch `pitch`, frame `extra` after
## the heading (a turn into W).
func _pose(feet: Vector4, yaw: float, pitch: float, extra: Projection = Projection.IDENTITY) -> void:
	var g: Projection = GB.cleaned(Basis4D.from_zx(yaw) * extra)
	_p.set("ground", g)
	_p.basis = g
	_p.global_position = Vector4(feet.x, 0.875, feet.z, feet.w)
	(_p.get("head") as Node4D).basis = Basis4D.from_yz(pitch)


func _level(n: int) -> void:
	_g.call("load_level", n, true)
	for i in 300:
		if String(_g.get("mode")) == "play" and int(_g.get("level_index")) == n:
			break
		await _kit.skip(1)
	_p.set("input_enabled", false)
	_p.set_physics_process(false)
	_kit.hide_layers(_g)
	await _kit.skip(10)


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	_g.set("capture_mouse", false)
	root.add_child(_g)
	_p = _g.get("player")
	for i in 600:
		if String(_g.get("mode")) == "play":
			break
		await _kit.skip(1)
	(_g.get("light") as Node).call("set_dark", true, false)
	_g.set("sighted", true)
	# 1. The first door.
	await _level(0)
	_g.set("sighted", true)
	_kit.recording = true
	await _kit.glide(84, func(t: float) -> void:
		_pose(Vector4(0.0, 0.0, lerpf(-2.6, -4.6, t), lerpf(-0.1, 1.75, t)), 0.0, 0.02))
	# 2. The garden hall: past the oak, W climbing.
	await _kit.glide(84, func(t: float) -> void:
		_pose(Vector4(lerpf(2.6, 1.2, t), 0.0, lerpf(-11.2, -13.0, t), lerpf(1.2, 3.2, t)), lerpf(0.55, 0.85, t), 0.18))
	# 3. The Long Hall: a push toward the Tall One; its head turns to us and its eyes flicker red.
	var tall: Node = ((_g.get("level") as Node).get("walkers") as Array)[0]
	_kit.recording = false
	_pose(Vector4(0.2, 0.0, -25.0, 3.4), 0.19, 0.12)
	tall.call("start_film", _p.get("camera"))
	_kit.recording = true
	var tq: Vector4 = (tall as Node4D).global_position
	await _kit.glide(126, func(t: float) -> void:
		# The heading follows the Tall One, so it holds the middle of the frame as we close in.
		var e := Vector2(lerpf(0.2, -0.3, t), lerpf(-25.0, -30.8, t))
		_pose(Vector4(e.x, 0.0, e.y, 3.4), atan2(e.x - tq.x, e.y - tq.z), lerpf(0.1, 0.3, t)))
	tall.call("end_film")
	# 4. Level 2's ambush: the kennel's slab sinks, and they come.
	_kit.recording = false
	await _level(1)
	_g.set("sighted", true)
	var l2: Node = _g.get("level")
	l2.set("lens_taken", true)
	_pose(Vector4(8.6, 0.0, -11.25, 2.4), -1.64, 0.04)
	await _kit.skip(4)
	l2.call("after_lens")
	_kit.recording = true
	await _kit.glide(120, func(t: float) -> void:
		_pose(Vector4(lerpf(8.6, 7.4, t), 0.0, lerpf(-11.25, -11.4, t), 2.4), lerpf(-1.64, -1.6, t), 0.04))
	# 5. The pit: on the landing, kata to ana.
	await _kit.glide(96, func(t: float) -> void:
		_pose(Vector4(-0.6, 0.0, -8.1, lerpf(-2.4, 2.4, t)), lerpf(-1.05, -1.25, t), -0.22))
	# 6. The Heart: at the centre, the turn into W, the vault ahead with the Dreamer.
	_kit.recording = false
	await _level(2)
	var lvl: Node = _g.get("level")
	lvl.call("_unseal")
	_kit.recording = true
	var turned: Projection = GB.cleaned(Basis4D.from_zw(PI * 0.5))
	if (-turned.z).w < 0.0:
		turned = GB.cleaned(Basis4D.from_zw(-PI * 0.5))
	await _kit.glide(110, func(t: float) -> void:
		var q: Quaternion = GB._to_3d(turned).get_rotation_quaternion()
		var f: Projection = GB._from_3d(Basis(Quaternion.IDENTITY.slerp(q, t)))
		_pose(Vector4(0.0, 0.0, 2.0, lerpf(0.0, -1.1, t)), 0.0, lerpf(0.25, 0.02, t), f))
	await _kit.hold(24)
	_kit.recording = false
	print("FILM the_annex: %d frames" % int(_kit.get("count")))
	quit(0)
