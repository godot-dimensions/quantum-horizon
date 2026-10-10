extends SceneTree

## The Creature Lab's menu film (menu_final's details pane plays it): five shots, hard cuts, 470 frames at
## 30 fps (15.7 s). Room 1 is filmed first (it loads first) but plays second: each shot writes its frames at
## its own place in the film (the kit's `count`), so the clip opens on the hall.
##
##   1  CINEMATIC  the hall, wide: a low crane up the middle path to the brachiosaurus on its deck   100
##   2  GAMEPLAY   room 1: you at the pedestal, the goat placed ball by ball, then its skin lofted     90
##   3  CINEMATIC  low and close beside the wolf walking its deck, the hall behind it                 90
##   4  CINEMATIC  the slice moves through W: the goat, the oak, the crows go; their copies come in    100
##   5  GAMEPLAY   you run up the middle path among the decks, the game's own camera                   90
##
## Shot 4 moves the camera's slice through W to the goat's copy (2.4 m ana, on the same deck), swinging it
## in x-w on the way (the camera's own basis turned, as the right drag turns the rig's) and flat again at the
## end: a cut left tilted misses the lofted animals' thin legs, and the copies arrived as floating bodies.
## The hall is 8 m deep in W, so its walls and decks stay while the animals change.
##
## Cinematic shots use a camera of their own (the player's, duplicated) with the player hidden; gameplay shots
## use the player's orbit camera. The player's input is off throughout and the scenes' own input handlers are
## switched off (nobody's mouse or keys reach the shot); the run of shot 5 is driven by setting the body's
## position and velocity each frame, so its gait runs as it does when you play.
##
##   cd project/ramon && bash Menu/films/film_run.sh creature_lab res://ramon/Menu/films/creature_lab_film_runner.gd
##   (add alt=1 to also record room 1's other take, the walking goat turned in 4D, to creature_lab/alt/)

const Kit := preload("res://ramon/Menu/films/film_kit.gd")
const LAB := "res://ramon/CreationLab/creature_lab.tscn"
const HALL := "res://ramon/CreationLab/hall/creature_hall.tscn"
## Gives up (and quits) after this long, whatever happens.
const GUARD_MS := 480000

## Where each shot starts in the film, and its length (frames).
const S_HALL := 0
const S_LAB := 100
const S_WOLF := 190
const S_SLICE := 280
const S_RUN := 380
const LEN_HALL := 100
const LEN_LAB := 90
const LEN_WOLF := 90
const LEN_SLICE := 100
const LEN_RUN := 90

var _kit: RefCounted
var _out: String = ""
var _alt: bool = false
var _g: Node
var _player: CharacterBody4D
var _rig: Node4D
var _cam: Camera4D
var _t0: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("out="):
			_out = s.substr(4)
		elif s == "alt=1":
			_alt = true
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("res://smoke_test_output/menu_films/creature_lab/frames")
	_kit = Kit.new(self, _out)
	_kit.calm_window()
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _t0 > GUARD_MS:
		print("FILM creature_lab: gave up after %d s (%d frames saved)" % [GUARD_MS / 1000, _kit.count])
		return true
	return false


# -- helpers -----------------------------------------------------------------------------------------

## A softer ease than the kit's: the camera is already moving when the shot cuts in and still moving when
## it cuts out, only gently slower at both ends.
static func _soft(t: float) -> float:
	return lerpf(clampf(t, 0.0, 1.0), Kit.ease_io(t), 0.55)


static func _smoother(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _begin(at: int) -> void:
	_kit.count = at
	_kit.recording = true


func _end() -> void:
	_kit.recording = false


## Opens a scene, waits out its loading board (not recorded), then quiets it and hides its HUD.
func _open(path: String) -> bool:
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		print("FILM creature_lab: could not load ", path)
		return false
	_g = ps.instantiate()
	root.add_child(_g)
	current_scene = _g
	_kit.calm_window()
	_player = _g.get("player") as CharacterBody4D
	_rig = _player.get_node_or_null("CameraRig") as Node4D if _player != null else null
	var n: int = 0
	while bool(_g.get("loading")) and n < 1500:
		await _kit.frame()
		n += 1
	await _kit.skip(6)
	_quiet()
	_kit.hide_layers(_g)
	print("FILM creature_lab: %s up after %d frames (loading %s)" % [path.get_file(), n, str(_g.get("loading"))])
	return _player != null and _rig != null


func _quiet() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _player != null:
		_player.set("input_enabled", false)
	if _rig != null:
		_rig.set_process_unhandled_input(false)
	if _g != null:
		_g.set_process_input(false)
		_g.set_process_unhandled_input(false)
		_g.set_process_unhandled_key_input(false)


## The player standing at (x, z), the orbit camera at `yaw` (radians) and `pitch_deg`, `dist` back, `pivot` up.
func _put(x: float, z: float, yaw: float, pitch_deg: float, dist: float, pivot: float) -> void:
	_player.global_position = Vector4(x, 0.05, z, 0.0)
	_player.linear_velocity = Vector4.ZERO
	_player.set("_facing", yaw + PI)
	_rig.set("yaw", yaw)
	_rig.set("pitch", deg_to_rad(pitch_deg))
	_rig.set("distance", dist)
	_rig.set("_zoom_target", dist)
	_rig.set("_rest_distance", dist)
	_rig.set("pivot_height", pivot)
	_rig.set("_home_pivot", pivot)
	_rig.call("_apply")


func _player_cam() -> Camera4D:
	return _player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D


## The film camera at `eye`, looking at `at` through a `lens_deg` lens. With `k` the slice is turned in x-w:
## the cut's W at any x is w0 + k x (a pivot line along z), the camera on it.
func _aim(eye: Vector4, at: Vector4, lens_deg: float, k: float = 0.0, w0: float = 0.0) -> void:
	var d: Vector4 = at - eye
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001))
	var b: Projection = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)
	if not is_zero_approx(k):
		var th: float = atan(k)
		var c: float = cos(th)
		var s: float = sin(th)
		# x tips into W; the camera's W axis (the slice's normal) becomes (-s, 0, 0, c).
		var turn := Projection(Vector4(c, 0, 0, s), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(-s, 0, 0, c))
		b = turn * b
	_cam.global_position = Vector4(eye.x, eye.y, eye.z, w0 + k * eye.x)
	_cam.global_basis = b
	_cam.set("field_of_view_4d", deg_to_rad(lens_deg))


func _station(nm: String) -> Dictionary:
	for st in _g.get("stations"):
		if String(st["name"]) == nm:
			return st
	return {}


## Station `nm`'s animal `i` (0 its own at W 0, then its copies through W in order).
func _animal(nm: String, i: int) -> Node4D:
	var st: Dictionary = _station(nm)
	if st.is_empty():
		return null
	var a: Array = st["animals"]
	if i < a.size() and is_instance_valid(a[i]):
		return a[i] as Node4D
	return null


# -- the film ----------------------------------------------------------------------------------------

func _run() -> void:
	await _kit.skip(2)
	# Room 1 first: it loads first. Its shot plays second in the film.
	if await _open(LAB):
		await _shot_lab()
	else:
		print("FILM creature_lab: room 1 did not open")
	_g.queue_free()
	current_scene = null
	_g = null
	await _kit.skip(4)
	if not await _open(HALL):
		print("FILM creature_lab: the hall did not open")
		quit(1)
		return
	var pc: Camera4D = _player_cam()
	_cam = pc.duplicate(0) as Camera4D
	_cam.name = "FilmCamera"
	_g.add_child(_cam)
	await _shot_hall()
	await _shot_wolf()
	await _shot_slice()
	await _shot_run()
	print("FILM creature_lab: done, %d frames, %.1f s of film, %d s to make" % [S_RUN + LEN_RUN, (S_RUN + LEN_RUN) / 30.0, (Time.get_ticks_msec() - _t0) / 1000])
	quit()


## 2. GAMEPLAY, room 1: you at the pedestal; the goat's last balls go on and its skin is lofted over them
## (the story's "balls" part into its "skin" part, which plays by itself when you come near).
func _shot_lab() -> void:
	var sc: Node = _g.get("showcase")
	# At the pedestal's front left, so the goat (its stand turned 0.55 for this part) is seen three-quarters on
	# rather than end on; the research board and the door to the hall behind it.
	var yaw0: float = -0.586
	_put(-2.65, 2.5, yaw0, -12.0, 3.8, 2.2)
	var n: int = 0
	while sc != null and int(sc.get("seq_index")) < 0 and n < 450:
		await _kit.frame()
		n += 1
	print("FILM creature_lab: the story started after %d frames (part %s)" % [n, str(sc.get("seq_index")) if sc != null else "-"])
	# The skin comes at 7 s in: 52 frames of balls first.
	if sc != null:
		sc.set("_loop_t", 7.0 - 53.0 / 30.0)
	await _kit.skip(1)
	_begin(S_LAB)
	for i in LEN_LAB:
		_rig.set("yaw", yaw0 + 0.09 - 0.15 * _soft(float(i) / float(LEN_LAB - 1)))
		_rig.call("_apply")
		await _kit.frame()
	_end()
	if _alt and sc != null:
		# The other take, for comparison: the goat walking in place while its slice turns in 4D.
		_kit.out_dir = _out.get_base_dir().path_join("alt")
		DirAccess.make_dir_recursive_absolute(_kit.out_dir)
		sc.set("_loop_t", 29.5)
		await _kit.skip(1)
		_begin(0)
		for i in 90:
			var t: float = float(i) / 89.0
			sc.set("turn", Vector2(0.95, 0.22) * Kit.ease_io(t))
			_rig.set("yaw", yaw0 + 0.09 - 0.15 * _soft(t))
			_rig.call("_apply")
			await _kit.frame()
		_end()
		sc.set("turn", Vector2.ZERO)
		_kit.out_dir = _out


## 1. CINEMATIC: the hall, wide. Low by the door, craning up the middle path to the brachiosaurus.
func _shot_hall() -> void:
	_player.visible = false
	_cam.make_current()
	_aim(Vector4(-1.0, 1.15, 20.2, 0.0), Vector4(0.0, 3.0, -9.0, 0.0), 55.0)
	await _kit.skip(2)
	_begin(S_HALL)
	for i in LEN_HALL:
		var k: float = _soft(float(i) / float(LEN_HALL - 1))
		_aim(Vector4(lerpf(-1.0, 0.4, k), lerpf(1.15, 3.6, k), lerpf(20.2, 11.2, k), 0.0),
			Vector4(0.0, lerpf(3.0, 3.6, k), -9.0, 0.0), 55.0)
		await _kit.frame()
	_end()


## 3. CINEMATIC: low and close beside the wolf as it walks its deck, from the wall side so the hall is behind
## it; the camera follows where it goes (softly), orbits a little toward its front and comes in a little.
func _shot_wolf() -> void:
	var wolf: Node4D = _animal("Wolf", 0)
	_cam.make_current()
	if wolf == null:
		print("FILM creature_lab: no wolf")
		_begin(S_WOLF)
		await _kit.hold(LEN_WOLF)
		_end()
		return
	# From the aisle side, in front of it (+x, +z of the wolf): its lit side (from the wall side it is a black
	# silhouette), with Nike's deck, the oak and the blue back wall behind. The wolf is twice life size, about
	# 1.4 m at the shoulder: a medium shot from 5 m, the lens at chest height.
	var phi: float = deg_to_rad(48.0)
	var spin: float = deg_to_rad(18.0)
	print("FILM creature_lab: wolf at %s" % str(wolf.global_position))
	var ps: Vector4 = wolf.global_position
	_begin(S_WOLF)
	for i in LEN_WOLF:
		var t: float = _soft(float(i) / float(LEN_WOLF - 1))
		ps = ps.lerp(wolf.global_position, 0.12)
		var a: float = phi + spin * t
		var dist: float = lerpf(5.0, 4.3, t)
		var eye := Vector4(ps.x + cos(a) * dist, ps.y + 1.05, ps.z + sin(a) * dist, 0.0)
		eye.x = maxf(eye.x, -14.3)
		_aim(eye, Vector4(ps.x, ps.y + 0.85, ps.z, 0.0), 44.0)
		await _kit.frame()
	_end()


## 4. CINEMATIC, the 4D one: the slice turns. Looking across at the horse's deck with the goat's behind it,
## the cut tips through W (x into W, about 10 degrees, its pivot line easing ana): the horse and the goat
## thin away and the copies standing on the same decks further through W come in.
func _shot_slice() -> void:
	# The goat's deck, the oak and the crows' rail behind it (each has a copy through W). Not the horse: its
	# body draws some metres from where its walker says it is, so from low down it hovers past its deck.
	var goat: Node4D = _animal("Goat", 0)
	var copy: Node4D = _animal("Goat", 1)
	# Run 1 tilted the slice and kept it tilted: a tilted cut misses a lofted animal's thin legs, so the copy
	# arrived as a floating body. Now the cut moves through W to the copy's W (it ends flat, the copy whole)
	# and swings while it travels (the tilt rises and falls), so the change sweeps across the deck. The
	# move is brisk (36 frames, nearly even): a slow ease lingers on the half-cut bodies at both ends.
	var tilt: float = 0.10
	var to_w: float = copy.global_position.w if copy != null else 2.4
	_cam.make_current()
	if copy != null:
		print("FILM creature_lab: goat at %s, its copy at %s" % [str(goat.global_position if goat != null else Vector4.ZERO), str(copy.global_position)])
	_begin(S_SLICE)
	for i in LEN_SLICE:
		var m: float = _soft(float(i) / float(LEN_SLICE - 1))
		var u: float = clampf((float(i) - 24.0) / 36.0, 0.0, 1.0)
		var e: float = lerpf(u, _smoother(u), 0.35)
		var k: float = tilt * sin(PI * e)
		# The pivot line runs through the copy, so the copy itself only sees the step.
		var xp: float = copy.global_position.x if copy != null else 10.5
		_aim(Vector4(lerpf(6.2, 7.0, m), lerpf(1.95, 1.85, m), lerpf(1.0, 0.2, m), 0.0),
			Vector4(lerpf(11.2, 11.0, m), 1.1, lerpf(-4.6, -4.9, m), 0.0), 44.0, k, e * to_w - k * xp)
		await _kit.frame()
	_end()
	if copy != null:
		print("FILM creature_lab: the slice ends at w %.2f; the copy at %s" % [to_w, str(copy.global_position)])


## 5. GAMEPLAY: you run up the middle path past the wolf's and the horse's decks toward the brachiosaurus,
## through the game's own camera. Up to speed before the cut (not recorded), then 90 frames at a run.
func _shot_run() -> void:
	_player.visible = true
	_player_cam().make_current()
	var z: float = 15.6
	_put(0.0, z, 0.10, -9.0, 6.0, 2.45)
	await _kit.skip(3)
	var v: float = 0.0
	var top: float = float(_player.get("run_speed"))
	var pre: int = 18
	for i in pre + LEN_RUN:
		if i == pre:
			_begin(S_RUN)
		v = minf(v + top / float(pre), top)
		z -= v / 30.0
		var p: Vector4 = _player.global_position
		_player.global_position = Vector4(0.0, p.y, z, 0.0)
		_player.linear_velocity = Vector4(0.0, _player.linear_velocity.y, -v, 0.0)
		_player.set("_facing", PI)
		_rig.set("yaw", lerpf(0.10, -0.06, _soft(float(i - pre) / float(LEN_RUN - 1))))
		_rig.call("_apply")
		await _kit.frame()
	_end()
