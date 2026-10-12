extends SceneTree

## The Voxel Lab's menu film (menu_final's details pane plays Menu/thumbs/voxel_lab.ogv): five shots,
## hard cuts, about 16 s, recorded with the kit (film_kit.gd) at a fixed 30 fps.
##
##   1. CINEMATIC  the hall: an eased dolly in across it to the block turning on its pedestal.
##   2. GAMEPLAY   the bench: from its own camera, the aim ring finds the block's face, a 4D ball is
##                 cut, then a 4D box beside it.
##   3. CINEMATIC  the same two holes close up while the slice slides through W: the ball's hole shrinks,
##                 the box's holds its size and then is gone (the lab's own "two cuts" story).
##   4. GAMEPLAY   Build it: a teal tower put up through W in front of the sand doorway, then the slice
##                 turned 32 degrees: the doorway (one W layer) slides away, the tower (every layer) stays.
##   5. CINEMATIC  the open world: a glide in from over the sea to the island and its survey deck.
##
## Nothing of the lab is changed or saved: the runner calls the lab's own functions (sit, the bench's
## aim and cut, the showcase's slice) as its runners do, and its own cameras are added at run time.
## No HUD: every CanvasLayer of the scene is hidden; the aim's outline is drawn by a copy of the bench
## overlay that draws only that. Nobody's mouse or keys reach the scene (input processing off on every
## node, the cursor free).
##   bash Menu/films/film_run.sh voxel_lab res://ramon/Menu/films/voxel_lab_film_runner.gd

const Kit := preload("res://ramon/Menu/films/film_kit.gd")
const LAB := "res://ramon/VoxelLab/voxel_lab.tscn"
const FIELD := "res://ramon/VoxelLab/field/voxel_field.tscn"
const OVERLAY := "res://ramon/VoxelLab/room/vl_bench_overlay.gd"
## Wall-clock guard: the runner quits by itself whatever happens.
const GUARD_MS := 420000

var _kit: RefCounted
var _t0: int = 0
var _scene: Node
var _cam: Camera4D
var _aim_layer: CanvasLayer
var _aim: Control


func _initialize() -> void:
	var out: String = ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("out="):
			out = String(a).substr(4)
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://smoke_test_output/menu_films/voxel_lab/frames")
	_kit = Kit.new(self, out)
	_kit.calm_window()
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > GUARD_MS:
		print("FILM voxel_lab: gave up after %d s (%d frames)" % [GUARD_MS / 1000, _kit.count])
		return true
	return false


# -- frames ---------------------------------------------------------------------------------------------

## One frame, with the cursor free and the player's own input off before it.
func _f() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_scene):
		var p: Node = _scene.get("player")
		if p != null:
			p.set("input_enabled", false)
	await _kit.frame()


func _skip(n: int) -> void:
	var was: bool = _kit.recording
	_kit.recording = false
	for i in n:
		await _f()
	_kit.recording = was


## Plays `frames` frames, calling step(i, eased t) before each.
func _shot(frames: int, step: Callable) -> void:
	for i in frames:
		step.call(i, Kit.ease_io(float(i) / float(maxi(1, frames - 1))))
		await _f()


## Waits (unrecorded) until `ok` says yes, up to `limit` frames; false if it never did.
func _wait(ok: Callable, limit: int) -> bool:
	for i in limit:
		if ok.call():
			return true
		await _skip(1)
	return false


## No real input reaches anything in the scene (his mouse and keys belong to his other windows).
func _mute(n: Node) -> void:
	n.set_process_input(false)
	n.set_process_unhandled_input(false)
	n.set_process_unhandled_key_input(false)
	n.set_process_shortcut_input(false)
	for c in n.get_children():
		_mute(c)


# -- cameras ---------------------------------------------------------------------------------------------

## The film camera looking from `eye` at `at` (the lab's own story camera's way of aiming).
func _look(eye: Vector4, at: Vector4, lens: float) -> void:
	var d: Vector4 = at - eye
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001))
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)
	_cam.set("field_of_view_4d", lens)


## A camera like the one given (its fades and engine), added to the scene and made current.
func _film_cam(like: Camera4D) -> void:
	if is_instance_valid(_cam):
		_cam.queue_free()
	_cam = like.duplicate(0) as Camera4D
	_cam.name = "FilmCamera"
	_scene.add_child(_cam)
	_cam.make_current()


## The bench overlay's aim outline only (no card, no costs, no label): a copy of its script made here,
## nothing written to disk. The bench is pointed at it in place of its own overlay, whose layer is hidden.
func _aim_overlay(bench: Node) -> void:
	_drop_aim()
	var s := GDScript.new()
	s.source_code = "extends \"%s\"\n\nfunc _draw() -> void:\n\tif camera == null or not is_instance_valid(camera):\n\t\treturn\n\thit_text = \"\"\n\t_draw_outline(maxf(get_viewport_rect().size.y, 360.0) / 720.0)\n" % OVERLAY
	if s.reload() != OK:
		print("FILM voxel_lab: the aim overlay did not compile")
		return
	_aim_layer = CanvasLayer.new()
	_aim_layer.name = "FilmAim"
	_aim_layer.layer = 4
	root.add_child(_aim_layer)
	_aim = Control.new()
	_aim.set_script(s)
	_aim.set("camera", bench.call("camera"))
	_aim_layer.add_child(_aim)
	bench.set("_overlay", _aim)


func _drop_aim() -> void:
	if is_instance_valid(_aim_layer):
		_aim_layer.queue_free()
	_aim_layer = null
	_aim = null


# -- the film --------------------------------------------------------------------------------------------

func _run() -> void:
	_scene = (load(LAB) as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	await _skip(10)
	var lab: Node = _scene
	var ok: bool = await _wait(func() -> bool:
		if lab.get("player") == null or bool(lab.get("loading")):
			return false
		for s in lab.get("stations"):
			var ex: Node = s.get("exhibit")
			if ex == null or not bool(ex.call("is_ready")):
				return false
		return true, 2400)
	print("FILM voxel_lab: lab ready %s after %.1f s" % [str(ok), (Time.get_ticks_msec() - _t0) / 1000.0])
	_mute(_scene)
	# The player out of every shot: in the corridor, behind the cameras, hidden.
	lab.call("go_to", Vector4(0.0, 0.05, 17.5, 0.0), 0.0)
	var av: Node4D = (lab.get("player") as Node).get_node_or_null("Avatar") as Node4D
	if av != null:
		av.visible = false
	_kit.hide_layers(_scene)
	await _skip(40)

	var hero: Node = lab.get_node("Hero")
	var hero_bench: Node = lab.get_node("HeroBench")
	var build: Node = lab.get_node("Build")
	var build_bench: Node = lab.get_node("BuildBench")

	# 1. The hall: a dolly in across it, from the front-right corner, to the block on its ring.
	_film_cam(lab.call("camera"))
	print("FILM voxel_lab: shot 1 (hall) from frame %d" % _kit.count)
	_kit.recording = true
	await _shot(96, func(_i: int, t: float) -> void:
		var eye: Vector4 = Vector4(7.4, 5.0, 10.6, 0.0).lerp(Vector4(3.6, 3.1, 5.6, 0.0), t)
		var at: Vector4 = Vector4(-0.8, 1.5, -3.2, 0.0).lerp(Vector4(-0.1, 1.7, -1.4, 0.0), t)
		_look(eye, at, lerpf(1.1, 0.95, t)))
	_kit.recording = false

	# 2. The bench: sat down out of shot, the block turned to face it, then the aim and two cuts.
	lab.call("sit", hero_bench)
	await _skip(2)
	_mute(_scene)
	_kit.hide_layers(_scene)
	_aim_overlay(hero_bench)
	hero_bench.set("tool", "ball")
	hero_bench.set("size_index", 2)
	# A longer lens than play's, from a little further back: the block larger, the pedestal less bent.
	(hero_bench.call("camera") as Camera4D).set("field_of_view_4d", 0.95)
	hero_bench.set("_dist", 4.7)
	hero_bench.set("_pitch", deg_to_rad(-9.0))
	hero_bench.set("_yaw", 0.30)
	await _skip(60)
	var ex: Node = hero.get("exhibit")
	var sp: Node4D = ex.get("specimen")
	var r: Dictionary = sp.get("recipe")
	var v: float = float(r.get("voxel", 0.12))
	var cen: Vector4 = r["center"]
	var half: Vector4 = r["half"]
	var ball_at: Vector4 = sp.call("to_global", cen + Vector4(-0.62 / v, 0.14 / v, half.z, 0.0))
	var box_at: Vector4 = sp.call("to_global", cen + Vector4(0.62 / v, 0.14 / v, half.z, 0.0))
	var mid_at: Vector4 = sp.call("to_global", cen + Vector4(-0.1 / v, -0.35 / v, half.z, 0.0))
	var bcam: Camera4D = hero_bench.call("camera")
	print("FILM voxel_lab: shot 2 (bench) from frame %d" % _kit.count)
	_kit.recording = true
	var cuts: Array = [0]
	await _shot(92, func(i: int, t: float) -> void:
		hero_bench.set("_yaw", lerpf(0.30, 0.12, t))
		# The aim: from low in the middle to the ball's spot (frames 4 to 22), the cut at 24; on to
		# the box's spot (34 to 52), the cut at 54.
		var p: Vector4
		if i < 24:
			p = mid_at.lerp(ball_at, Kit.ease_io(float(i - 4) / 18.0))
		elif i < 54:
			p = ball_at.lerp(box_at, Kit.ease_io(float(i - 34) / 18.0))
		else:
			p = box_at.lerp(mid_at, Kit.ease_io(float(i - 62) / 30.0) * 0.35)
		hero_bench.call("aim_at_screen", bcam.world_to_viewport(p))
		if i == 24 or i == 54:
			if i == 54:
				hero_bench.set("tool", "block")
			var rec: Dictionary = hero_bench.call("cut_here")
			print("FILM voxel_lab: cut %s at frame %d: %s" % [String(hero_bench.get("tool")), _kit.count, "made" if not rec.is_empty() else "MISSED"])
			if not rec.is_empty():
				cuts[0] += 1)
	_kit.recording = false

	# 3. The two holes close up while the slice slides kata through W: the ball's hole shrinks, the
	# box's keeps its size and then is gone.
	hero_bench.call("undock")
	_drop_aim()
	await _skip(1)
	_mute(_scene)
	ex.set("held", true)
	hero.set("cinematic", true)
	hero.set("_cine_slice", float(ex.call("_fraction", 0.0)))
	_film_cam(lab.get("player").get_node("CameraRig/Pitch/Camera4D"))
	var face: Vector4 = sp.call("to_global", cen + Vector4(0.0, 0.1 / v, half.z, 0.0))
	_look(face + Vector4(0.55, 0.3, 3.1, 0.0), face + Vector4(0.0, 0.05, 0.0, 0.0), 0.85)
	await _skip(20)
	print("FILM voxel_lab: shot 3 (through W) from frame %d" % _kit.count)
	_kit.recording = true
	await _shot(96, func(i: int, t: float) -> void:
		# A slow push in that settles on the ball's hole as the box's goes.
		_look(face + Vector4(0.55, 0.3, 3.1, 0.0).lerp(Vector4(-0.1, 0.2, 2.5, 0.0), t), face + Vector4(0.0, 0.05, 0.0, 0.0).lerp(Vector4(-0.42, 0.1, 0.0, 0.0), t), 0.85)
		var w: float = -0.385 * Kit.ease_io(float(i - 14) / 62.0)
		hero.set("_cine_slice", float(ex.call("_fraction", w))))
	_kit.recording = false
	hero.set("cinematic", false)
	hero.set("_cine_slice", -3.0)

	# 4. Build it: a teal tower through W in front of the sand doorway, then the slice turned.
	lab.call("sit", build_bench)
	await _skip(2)
	_mute(_scene)
	_kit.hide_layers(_scene)
	_aim_overlay(build_bench)
	build_bench.set("tool", "through")
	build_bench.set("size_index", 2)
	(build_bench.call("camera") as Camera4D).set("field_of_view_4d", 0.9)
	build_bench.set("_dist", 5.4)
	build_bench.set("_pitch", deg_to_rad(-30.0))
	build_bench.set("_yaw", 2.02)
	await _skip(30)
	var bex: Node = build.get("exhibit")
	var bsp: Node4D = bex.get("specimen")
	var lcam: Camera4D = build_bench.call("camera")
	var cell := func(key: Vector4i) -> Vector4:
		return bsp.call("to_global", (bex.call("cell_lo", key) as Vector4) + Vector4(2.0, 0.0, 2.0, 2.0))
	var spots: Array = [cell.call(Vector4i(3, 0, 3, 2)), cell.call(Vector4i(3, 1, 3, 2)), cell.call(Vector4i(3, 2, 3, 2))]
	var start_at: Vector4 = cell.call(Vector4i(5, 0, 5, 2))
	print("FILM voxel_lab: shot 4 (build) from frame %d, %d bricks" % [_kit.count, int(bex.call("bricks"))])
	_kit.recording = true
	var turned: Array = [0.0]
	var pitch4: float = deg_to_rad(-30.0)
	var yaw4 := func(i: int) -> float: return lerpf(2.02, 1.84, Kit.ease_io(float(i) / 101.0))
	await _shot(44, func(i: int, _t: float) -> void:
		build_bench.set("_yaw", yaw4.call(i))
		# Three bricks, one on another (frames 10, 22, 34), the aim gliding to each.
		var p: Vector4
		if i < 10:
			p = start_at.lerp(spots[0], Kit.ease_io(float(i) / 9.0))
		elif i < 22:
			p = spots[0].lerp(spots[1], Kit.ease_io(float(i - 12) / 9.0))
		elif i < 34:
			p = spots[1].lerp(spots[2], Kit.ease_io(float(i - 24) / 9.0))
		else:
			p = spots[2]
		build_bench.call("aim_at_screen", lcam.world_to_viewport(p))
		if i == 10 or i == 22 or i == 34:
			var rec: Dictionary = build_bench.call("cut_here")
			print("FILM voxel_lab: brick at frame %d: %s (%d bricks)" % [_kit.count, "made" if not rec.is_empty() else "MISSED", int(bex.call("bricks"))]))
	# The bench's camera circles the specimen's node, which a turned slice moves (the view slid away in
	# the first takes), so between two frames a camera of ours takes over at the bench camera's own pose
	# and keeps its orbit round where the grid stood.
	var c4: Vector4 = build_bench.call("_centre")
	var dist4: float = float(build_bench.get("_dist"))
	build_bench.call("undock")
	_drop_aim()
	_film_cam(lcam)
	_mute(_scene)
	await _shot(58, func(j: int, _t: float) -> void:
		var i: int = j + 44
		var yaw: float = yaw4.call(i)
		# Easing back a little as the slice turns: cut on the slant, the pedestal reaches further toward
		# the camera (its width over cos of the turn).
		var back: float = dist4 * lerpf(1.0, 1.1, Kit.ease_io(float(j) / 57.0))
		_cam.global_position = c4 + Vector4(sin(yaw) * cos(pitch4), -sin(pitch4), cos(yaw) * cos(pitch4), 0.0) * back
		_cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch4)
		# Frames 46 to 98: the slice turned 32 degrees through W (the doorway, a metre off the middle and
		# one layer thick, is gone by about 18).
		var want: float = deg_to_rad(32.0) * Kit.ease_io(float(i - 46) / 52.0)
		if want > turned[0] + 0.0001:
			build.call("turn_by", want - turned[0], 0.0)
			turned[0] = want)
	_kit.recording = false
	await _skip(2)

	# 5. The open world: the lab let go, the field built behind its board, then a glide in from over the
	# sea to the island and its deck.
	_scene.queue_free()
	_scene = null
	await _skip(10)
	_scene = (load(FIELD) as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	await _skip(5)
	var field: Node = _scene
	ok = await _wait(func() -> bool:
		return field.get("player") != null and not bool(field.get("loading")), 4000)
	# The grass is made on a worker once the ground is mapped.
	await _wait(func() -> bool: return field.get("grass") != null, 600)
	print("FILM voxel_lab: field ready %s after %.1f s" % [str(ok), (Time.get_ticks_msec() - _t0) / 1000.0])
	_mute(_scene)
	_kit.hide_layers(_scene)
	await _skip(45)
	_film_cam(field.get("bird_cam"))
	_cam.set("depth_fade_start", 90.0)
	var deck: Vector4 = (field.get("raft") as Node4D).position
	print("FILM voxel_lab: shot 5 (open world) from frame %d, deck at %s" % [_kit.count, str(deck)])
	_kit.recording = true
	# An arc round the deck, coming down and in: from out over the sea on its right to its front right.
	await _shot(105, func(_i: int, t: float) -> void:
		var az: float = deg_to_rad(lerpf(62.0, 30.0, t))
		var rad: float = lerpf(50.0, 30.0, t)
		var eye: Vector4 = deck + Vector4(sin(az) * rad, lerpf(13.0, 6.0, t), cos(az) * rad - 3.0, 0.0)
		var at: Vector4 = deck + Vector4(0.0, lerpf(-4.5, -2.0, t), -4.0, 0.0)
		_look(eye, at, 0.95))
	_kit.recording = false
	print("FILM voxel_lab: %d frames, %.1f s, %d cuts; took %.0f s" % [_kit.count, _kit.count / 30.0, int(cuts[0]), (Time.get_ticks_msec() - _t0) / 1000.0])
	quit()
