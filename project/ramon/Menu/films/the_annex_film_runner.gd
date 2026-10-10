extends SceneTree

## The Annex's menu film (Maze Remake 2, MazeRemake2/maze_remake_2.tscn): five shots, hard cuts, no HUD,
## for menu_final's details pane. Every shot is the player's own first-person camera with W moving, so
## what changes on screen is what shifting through W does:
##
##   1. GAMEPLAY   level 1: down the corridor at the teal door; W rises and its leaves slide apart, the
##                 floor turning teal.
##   2. CINEMATIC  level 1's garden hall: a slow drift past the oak as W climbs, the tree's cut changing.
##   3. GAMEPLAY   level 2's hub: the north doorway, walled at home; W falls kata and the wall sinks
##                 into the floor under its amber stripe.
##   4. GAMEPLAY   level 2's pit: on the landing, W sweeps from kata to ana; the amber bridge behind
##                 narrows away and the teal one grows ahead.
##   5. CINEMATIC  level 3: at the atrium's centre the view turns into W, and the vault stands ahead
##                 with the Dreamer inside.
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
	(_g.get("light") as Node).call("set_dark", false, false)
	# 1. The first door.
	await _level(0)
	_kit.recording = true
	await _kit.glide(96, func(t: float) -> void:
		_pose(Vector4(0.0, 0.0, lerpf(-2.6, -4.6, t), lerpf(-0.1, 1.75, t)), 0.0, 0.02))
	# 2. The garden hall: past the oak, W climbing.
	await _kit.glide(90, func(t: float) -> void:
		_pose(Vector4(lerpf(2.6, 1.2, t), 0.0, lerpf(-11.2, -13.0, t), lerpf(1.2, 3.2, t)), lerpf(0.55, 0.85, t), 0.18))
	# 3. The hub: the north doorway's wall sinks as W falls kata.
	_kit.recording = false
	await _level(1)
	_kit.recording = true
	await _kit.glide(100, func(t: float) -> void:
		_pose(Vector4(-0.6, 0.0, 2.6, lerpf(0.0, -2.4, t)), lerpf(0.05, -0.05, t), 0.05))
	# 4. The pit: on the landing, kata to ana.
	await _kit.glide(104, func(t: float) -> void:
		_pose(Vector4(-0.6, 0.0, -8.1, lerpf(-2.4, 2.4, t)), lerpf(-1.05, -1.25, t), -0.22))
	# 5. The Heart: at the centre, the turn into W, the vault ahead with the Dreamer.
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
