extends SceneTree

## The Botany Lab's menu film (Menu/films/film_kit.gd; Ramon, 9 Oct: "about 5 shots for each prototype
## ... cinematic, immersive, cool, and also gameplay shots"). Five shots, hard cuts, about 16 s:
##
##   1. CINEMATIC  the oak: its leaves grow in on the wood while a gust runs through it; a slow crane
##                 round its left side, rising.
##   2. GAMEPLAY   the player runs the blue route down the spine and turns onto 02's branch.
##   3. CINEMATIC  02, the smooth-voxel tree, slid through W: its leaf masses swell and melt as the
##                 slice moves; a slow push in.
##   4. GAMEPLAY   the player at 01 turns the voxel tree through W (the right drag), its cells re-cut.
##   5. CINEMATIC  the second room, TWO VOXEL WORLDS: a dolly down the middle path between the blocky
##                 and the smooth land, drifting a little through W so both sets of hills change.
##
## The scenes are loaded one after the other (the hall freed before the second room is built), their
## HUDs hidden, nobody's input let in (the window unfocusable, the mouse free, every node deaf), and
## nothing saved. The stories are driven the way the hall's own guided tour drives them
## (begin_cinematic / play / end_cinematic), with the room's own arrival logic paused so it cannot
## start a story mid-shot.
##
##   bash Menu/films/film_run.sh botany_lab res://ramon/Menu/films/botany_lab_film_runner.gd

const Kit := preload("res://ramon/Menu/films/film_kit.gd")
const HALL := "res://ramon/Arboretum/botany_lab.tscn"
const COMPARE := "res://ramon/Arboretum/botany_lab/compare/botany_compare.tscn"
## Wall-clock guard: the runner quits by itself whatever happens.
const GUARD_MS := 300000

var _kit: Kit
var _t0: int = 0
var _room: Node4D
var _cam: Camera4D


func _initialize() -> void:
	var out: String = ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("out="):
			out = String(a).substr(4)
	_kit = Kit.new(self, out)
	_kit.calm_window()
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > GUARD_MS:
		print("FILM botany_lab: gave up after %d s (%d frames saved)" % [GUARD_MS / 1000, int(_kit.get("count"))])
		quit(2)
		return true
	return false


# -- helpers -------------------------------------------------------------------------------------------

## One frame, the mouse kept free (the rigs capture it when they start).
func _f() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _kit.frame()


func _skip(n: int) -> void:
	var was: bool = _kit.recording
	_kit.recording = false
	for i in n:
		await _f()
	_kit.recording = was


## No real input reaches anything in the scene.
func _deaf(n: Node) -> void:
	n.set_process_input(false)
	n.set_process_unhandled_input(false)
	n.set_process_unhandled_key_input(false)
	n.set_process_shortcut_input(false)
	for c in n.get_children():
		_deaf(c)


## Mostly eased, never quite at rest: a glide that still moves at the cut.
static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return lerpf(t, Kit.ease_io(t), 0.7)


func _player() -> CharacterBody4D:
	return _room.get("player") as CharacterBody4D


func _rig() -> Node:
	return _player().get_node_or_null("CameraRig")


func _player_cam() -> Camera4D:
	return _player().get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D


func _go(x: float, z: float, yaw_deg: float, w: float = 0.0) -> void:
	_room.call("go_to", Vector4(x, 0.05, z, w), deg_to_rad(yaw_deg))
	_player().set("input_enabled", false)


func _frame_rig(pitch_deg: float, dist: float) -> void:
	var rig: Node = _rig()
	rig.set("pitch", deg_to_rad(pitch_deg))
	rig.set("distance", dist)
	rig.set("_zoom_target", dist)
	rig.call("_apply")


## The film camera: a copy of the player's (its renderer and settings), placed by hand.
func _film_cam() -> void:
	_cam = _player_cam().duplicate(0) as Camera4D
	_cam.name = "FilmCamera"
	_room.add_child(_cam)
	_cam.make_current()


func _place(eye: Vector4, at: Vector4, fov: float) -> void:
	var d: Vector4 = at - eye
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001))
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)
	_cam.set("field_of_view_4d", fov)


## The index of a station's story part by its key.
func _part(st: Node, key: String) -> int:
	var seqs: Array = st.call("sequences")
	for k in seqs.size():
		if String(seqs[k]["key"]) == key:
			return k
	return 0


func _fail(why: String) -> void:
	print("FILM botany_lab: FAILED: " + why)
	quit(1)


# -- the film ------------------------------------------------------------------------------------------

func _run() -> void:
	_room = (load(HALL) as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	await _skip(90)
	if _room.get("player") == null or _room.get_node_or_null("Station04") == null:
		_fail("the hall has no player or no Station04")
		return
	_deaf(_room)
	# The room's own arrival logic would start a pedestal's story (or reset a turned tree) mid-shot.
	_room.set_process(false)
	_player().set("input_enabled", false)
	_kit.hide_layers(_room)
	print("FILM botany_lab: player lens %.3f" % float(_player_cam().get("field_of_view_4d")))
	_film_cam()

	await _shot_oak()
	await _shot_walk()
	await _shot_slice()
	await _shot_turn()

	# The second room: the hall goes first (both are heavy), then the room builds behind its board.
	_room.queue_free()
	_room = null
	_cam = null
	await _skip(5)
	_room = (load(COMPARE) as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	var waited: int = 0
	while waited < 3000 and (not bool(_room.call("ready_to_visit")) or _room.get("_board") != null):
		await _f()
		waited += 1
	print("FILM botany_lab: second room ready after %d frames" % waited)
	await _skip(45)
	_deaf(_room)
	_kit.hide_layers(_room)
	_player().set("input_enabled", false)
	_go(0.0, 21.0, 0.0)
	_film_cam()
	await _shot_worlds()

	print("FILM botany_lab: done, %d frames, %.1f s" % [int(_kit.get("count")), float(int(_kit.get("count"))) / 30.0])
	quit(0)


## 1. The oak, its leaves growing in, a gust through them; a crane round its left side.
func _shot_oak() -> void:
	var st: Node = _room.get_node("Station04")
	var k: int = _part(st, "leaves")
	_go(0.0, 15.5, 0.0)
	st.call("begin_cinematic")
	st.call("play", k, 0.0)
	# The oak's floating panel stands between this lens and the pedestal (a black slab across the bottom
	# of the frame): out of this one shot only, back after it.
	var label: Node4D = _room.get_node_or_null("Panel04") as Node4D
	if label != null:
		label.visible = false
	var c := Vector4(0.0, 1.1, -13.5, 0.0)
	var n: int = 105
	var pose := func(t: float) -> void:
		var e: float = _ease(t)
		var a: float = lerpf(-0.36, -0.10, e)
		var r: float = lerpf(11.0, 13.0, e)
		var eye: Vector4 = c + Vector4(sin(a) * r, lerpf(1.1, 2.2, e), cos(a) * r, 0.0)
		_place(eye, Vector4(0.0, lerpf(5.4, 5.1, e), -13.5, 0.0), lerpf(0.95, 0.9, e))
	_cam.make_current()
	pose.call(0.0)
	var wind: Node = _room.call("wind")
	await _skip(10)
	if wind != null:
		wind.call("gust")
	await _skip(20)
	_kit.recording = true
	for i in n:
		var t: float = float(i) / float(n - 1)
		pose.call(t)
		# The leaves arrive by birth order over the first 80 % of the shot (the part's own grow curve:
		# grow = t / 6.75 s), easing out, then the full crown moves in the wind.
		var x: float = clampf(t / 0.8, 0.0, 1.0)
		var g: float = 0.02 + 0.98 * (1.0 - (1.0 - x) * (1.0 - x))
		st.call("play", k, 6.75 * g)
		await _f()
	_kit.recording = false
	st.call("end_cinematic")
	if label != null:
		label.visible = true


## 2. Gameplay: running the route down the spine and onto 02's branch, the view turning with you.
func _shot_walk() -> void:
	var p: CharacterBody4D = _player()
	_player_cam().make_current()
	_go(0.0, 11.4, 0.0)
	_frame_rig(-12.0, 5.5)
	await _skip(6)
	p.set("input_enabled", true)
	Input.action_press(&"move_forward")
	await _skip(10)
	var rig: Node = _rig()
	var n: int = 100
	_kit.recording = true
	for i in n:
		# The mouse's turn onto the branch: eased in as you reach the junction (z 4.5), 45 degrees right.
		var z: float = p.global_position.z
		var b: float = Kit.ease_io(clampf((6.0 - z) / 2.6, 0.0, 1.0))
		rig.set("yaw", -PI * 0.25 * b)
		rig.call("_apply")
		await _f()
	_kit.recording = false
	Input.action_release(&"move_forward")
	print("FILM botany_lab: walk ended at (%.2f, %.2f)" % [p.global_position.x, p.global_position.z])
	p.set("input_enabled", false)
	await _skip(10)


## 3. 02 slid through W: the slice moves from one side of the tree to the other; a slow push in.
func _shot_slice() -> void:
	var st: Node = _room.get_node("Station02")
	var k: int = _part(st, "slice")
	_go(0.0, 15.5, 0.0)
	st.call("begin_cinematic")
	st.call("play", k, 1.0)
	st.set("_cine_slice", -0.75)
	var n: int = 95
	var pose := func(t: float) -> void:
		var e: float = _ease(t)
		_place(Vector4(2.53, 3.4, 7.15, 0.0).lerp(Vector4(3.12, 3.5, 6.34, 0.0), e), Vector4(7.0, 3.6, 1.0, 0.0).lerp(Vector4(7.0, 3.55, 1.0, 0.0), e), 0.85)
	_cam.make_current()
	pose.call(0.0)
	await _skip(40)
	_kit.recording = true
	for i in n:
		var t: float = float(i) / float(n - 1)
		pose.call(t)
		st.set("_cine_slice", lerpf(-0.75, 0.75, Kit.ease_io(t)))
		await _f()
	_kit.recording = false
	st.call("end_cinematic")


## 4. Gameplay: at 01, the voxel tree turned through W by a right drag (the showcase's own turn_by).
func _shot_turn() -> void:
	var st: Node = _room.get_node("Station01")
	_player_cam().make_current()
	_go(-4.2, 8.0, 70.0)
	_frame_rig(-6.0, 5.0)
	var lens: float = float(_player_cam().get("field_of_view_4d"))
	# A longer lens than play's 77 degrees: the pane is small, the tree should fill it.
	_player_cam().set("field_of_view_4d", 1.0)
	st.call("reset_view")
	await _skip(30)
	var n: int = 90
	var prev := Vector2.ZERO
	_kit.recording = true
	for i in n:
		var t: float = float(i) / float(n - 1)
		var e: float = Kit.ease_io(t)
		var want := Vector2(0.5 * e, 0.28 * e)
		st.call("turn_by", want.x - prev.x, want.y - prev.y)
		prev = want
		await _f()
	_kit.recording = false
	print("FILM botany_lab: 01 turned by %s" % str(st.get("turn")))
	st.call("reset_view")
	_player_cam().set("field_of_view_4d", lens)


## 5. The second room: down the middle path between the blocky and the smooth land, drifting through W.
func _shot_worlds() -> void:
	var n: int = 105
	var pose := func(t: float) -> void:
		var e: float = _ease(t)
		var w: float = 0.3 * e
		_place(Vector4(0.0, lerpf(3.3, 2.9, e), lerpf(16.5, 9.5, e), w), Vector4(0.0, lerpf(1.0, 0.9, e), lerpf(-12.0, -14.0, e), w), 0.95)
	pose.call(0.0)
	await _skip(10)
	_kit.recording = true
	for i in n:
		pose.call(float(i) / float(n - 1))
		await _f()
	_kit.recording = false
