extends SceneTree

## The bot (PLAN.md step 74): plays every level through the real controls and films it. It holds the
## movement actions the walker reads (move_forward, move_ana, move_kata), presses F as a key event the
## view hears, and turns its heading as the mouse would (GroundBasis4D, in the view's own frame). It
## follows the solver's route: a run of two or more cells through W is turned into and walked; a single
## one is stepped, blind, with Q or E; a move along an axis the view hides is turned back first.
## A move that takes longer than 10 s fails the level ("stuck").
##
##   run.sh windowed solve res://ramon/PhaseMazeRemake/scripts/_solve_runner.gd [levels=1,2,3]
##   run.sh movie phase_maze_remake res://ramon/PhaseMazeRemake/scripts/_solve_runner.gd levels=2,3,5 film
## Frames per beat in smoke_test_output/phase_maze_remake/solve/. With "film" (run it in clip mode, a
## fixed 30 fps) every frame goes to solve/film/ for a video, it opens in the lobby, and the levels are
## chosen and started with the console's keys, as a player would. Prints "SOLVE: PASS" or the levels that
## failed. Bests are not saved; the window takes no input from anyone.

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/solve/"
const GB := preload("res://ramon/PhaseMazeRemake/carried/walker/ground_basis_4d.gd")
const Lattice := preload("res://ramon/PhaseMazeRemake/maze/maze_lattice.gd")

var _t0: int = 0
var _m: Node4D
var _view: Node
var _rig: Node4D
var _player: CharacterBody4D
var _film: bool = false
## Every frame as a PNG too (slow: the movie writer is the way to film; this is for a few seconds).
var _save_frames: bool = false
var _frame_no: int = 0
var _level_tag: String = ""


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 600000:
		print("SOLVE: gave up after 600 s")
		return true
	if _save_frames and _m != null:
		_frame_no += 1
		var img: Image = root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + "film/%05d.png" % _frame_no))
	return false


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [_level_tag, name]))


func _release_all() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"move_ana", &"move_kata"]:
		Input.action_release(a)


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var r := InputEventKey.new()
	r.keycode = code
	r.physical_keycode = code
	r.pressed = false
	Input.parse_input_event(r)


## Game time, not wall time: filming runs at a fixed 30 fps however slowly the frames are saved.
## F, as a player presses it, made sure of: if the view has not changed which axis it hides once the
## turn is over, the key is sent again (a key event can be missed by a fixed-rate film's frame).
func _press_f() -> void:
	for attempt in 3:
		var before: int = int(_view.get("hidden_axis"))
		await _key(KEY_F)
		await _while_turning()
		if int(_view.get("hidden_axis")) != before:
			return
	print("SOLVE:   F did not turn the view after three presses")


func _wait(seconds: float) -> void:
	if _film:
		for i in int(seconds * 30.0):
			await process_frame
		return
	var t: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(seconds * 1000.0):
		await process_frame


## The key's event is handled a frame or two after it is sent: wait for the turn to start, then to end.
func _while_turning() -> void:
	var guard: int = 0
	while not bool(_view.call("is_turning")) and guard < 10:
		await process_frame
		guard += 1
	guard = 0
	while bool(_view.call("is_turning")) and guard < 120:
		await process_frame
		guard += 1
	await _wait(0.1)


## Walk to the middle of `cell` in the view you have, steering like the mouse would.
func _walk_to(lv, cell: Vector3i) -> bool:
	var target: Vector4 = lv.cell_centre(cell)
	var ticks: int = 0
	Input.action_press(&"move_forward")
	while ticks < 600:
		ticks += 1
		# Reaching the exit takes you to the reward hall: the walk is over.
		if String(_m.get("state")) == "finished":
			Input.action_release(&"move_forward")
			return true
		var p: Vector4 = _player.global_position
		var d: Vector4 = target - p
		d.y = 0.0
		var b: Projection = _rig.basis
		var flat: Vector4 = d - b.w * d.dot(b.w)
		if flat.length() < 0.35:
			Input.action_release(&"move_forward")
			# Arrived, unless the target lies along the hidden axis (the wrong view): that is no arrival.
			return absf(d.dot(b.w)) < 0.5
		_rig.basis = GB.faced(b, flat, 0.35)
		_rig.call("_apply")
		await physics_frame
	Input.action_release(&"move_forward")
	return false


## Walk to a point in the view you have (the lift's ring on the overlook).
func _walk_to_point(target: Vector4) -> bool:
	var ticks: int = 0
	Input.action_press(&"move_forward")
	while ticks < 600:
		ticks += 1
		var d: Vector4 = target - _player.global_position
		d.y = 0.0
		var b: Projection = _rig.basis
		var flat: Vector4 = d - b.w * d.dot(b.w)
		if flat.length() < 0.4:
			Input.action_release(&"move_forward")
			return true
		_rig.basis = GB.faced(b, flat, 0.35)
		_rig.call("_apply")
		await physics_frame
	Input.action_release(&"move_forward")
	return false


## The overlook: into the yellow ring, and down with the lift.
func _ride_down() -> bool:
	var ov: Dictionary = _m.get("overlook")
	if ov.is_empty() or not bool(_m.get("on_overlook")):
		return true
	await _wait(1.2)
	await _shot("0b_overlook")
	if not await _walk_to_point(ov["centre"]):
		return false
	var ticks: int = 0
	while bool(_m.get("on_overlook")) and ticks < 900:
		ticks += 1
		await physics_frame
	await _wait(0.3)
	return not bool(_m.get("on_overlook"))


## Step along the view's W (E ana, Q kata) until the hidden coordinate is the cell's middle.
func _step_to(lv, cell: Vector3i) -> bool:
	var target: Vector4 = lv.cell_centre(cell)
	var b: Projection = _rig.basis
	var need: float = (target - _player.global_position).dot(b.w)
	var action: StringName = &"move_ana" if need > 0.0 else &"move_kata"
	var ticks: int = 0
	Input.action_press(action)
	while ticks < 720:
		ticks += 1
		var left: float = (target - _player.global_position).dot(b.w)
		if absf(left) < 0.25 or signf(left) != signf(need):
			Input.action_release(action)
			return true
		await physics_frame
	Input.action_release(action)
	print("SOLVE:   stuck stepping: at %s, velocity %s, slice normal %s, input %s, w speed %s" % [str(_player.global_position),
		str(_player.get("linear_velocity")), str(_rig.basis.w), str(_player.get("input_enabled")), str(_player.get("w_speed_scale"))])
	return false


func _play(i: int) -> Dictionary:
	_level_tag = "L%d" % (i + 1)
	if _film:
		# As a player: its number on the console, then ENTER, behind the fade.
		await _key(KEY_1 + i)
		if String(_m.get("state")) != "playing":
			await _key(KEY_ENTER)
		await _wait(1.0)
	else:
		_m.call("_load_level", i)
		_m.set("generated_seed", 7)
		if i == 5:
			_m.call("_load_level", i, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(0.4)
	var lv = _m.get("lattice")
	var route: Array = lv.route()
	await _shot("0_start")
	if not await _ride_down():
		return {"ok": false, "why": "the lift did not take the bot down"}
	var k: int = 0
	var turned_once: bool = false
	while k < route.size() - 1:
		var a: Vector3i = route[k]
		var b: Vector3i = route[k + 1]
		var axis: int = Lattice.axis_of(a, b)
		var run: int = 1
		while k + run < route.size() - 1 and Lattice.axis_of(route[k + run], route[k + run + 1]) == axis:
			run += 1
		var hidden: int = int(_view.get("hidden_axis"))
		# A stair through W cannot be stepped up with Q or E: it is walked, turned, like a long run.
		var stair: bool = false
		for q in run:
			if lv.stairs.has(route[k + q]) or lv.stairs.has(route[k + q + 1]):
				stair = true
		if axis == 2 and (run >= 2 or stair):
			# Turn so W is ahead: level first (heading along any corridor), F, and turn round for kata.
			if hidden != 2:
				await _press_f()
			await _press_f()
			if not turned_once:
				turned_once = true
				await _shot("1_turned")
			var dir_w: int = signi(b.z - a.z)
			if (Vector4(0, 0, 0, float(dir_w))).dot(-_rig.basis.z) < 0.0:
				_rig.basis = GB.turned(_rig.basis, PI)
				_rig.call("_apply")
			for s in run:
				if not await _walk_to(lv, route[k + s + 1]):
					return {"ok": false, "why": "stuck walking through W to %s" % str(route[k + s + 1])}
			k += run
			continue
		if axis == hidden and axis != 2:
			# The view hides this axis: back to level.
			var before: Vector4 = _rig.basis.w
			await _press_f()
			hidden = int(_view.get("hidden_axis"))
			print("SOLVE:   back to level for a move along %s: slice normal %s -> %s, hidden now %d" % [Lattice.AXES[axis], str(before), str(_rig.basis.w), hidden])
		if axis == hidden:
			if not await _step_to(lv, b):
				return {"ok": false, "why": "stuck stepping to %s" % str(b)}
			await _shot("2_stepped_%d" % k)
		else:
			if not await _walk_to(lv, b):
				return {"ok": false, "why": "stuck walking to %s" % str(b)}
		k += 1
	# The exit pad's middle, and a moment for the finish.
	await _wait(0.8)
	await _shot("3_end")
	var st: String = String(_m.get("state"))
	return {"ok": st == "finished", "why": "" if st == "finished" else "not finished (state %s)" % st,
		"time": float(_m.get("time")), "w_moves": int(_m.get("w_moves")), "turns": int(_m.get("turns")), "par": int(lv.par_w())}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "film"))
	var which: Array = [0, 1, 2, 3, 4, 5]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("levels="):
			which = []
			for n in a.substr(7).split(","):
				which.append(int(n) - 1)
		if a == "film":
			_film = true
		if a == "frames":
			_save_frames = true
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 12:
		await process_frame
	_view = _m.get("view")
	_view.set("debug_turns", OS.get_cmdline_user_args().has("debug"))
	_rig = _m.get("rig")
	_player = _m.get("player")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var failed: Array = []
	if _film:
		var film_dir: String = ProjectSettings.globalize_path(OUT + "film")
		for f in DirAccess.get_files_at(film_dir):
			DirAccess.remove_absolute(film_dir + "/" + f)
		_frame_no = 0
		# The lobby first: the walls and the console, a moment to read them.
		await _wait(2.5)
	for i in which:
		var r: Dictionary = await _play(int(i))
		_release_all()
		print("SOLVE: level %d %s  time %.1f s  W moves %d (par %d)  turns %d  %s" % [int(i) + 1, "OK" if r["ok"] else "FAIL",
			float(r.get("time", 0.0)), int(r.get("w_moves", 0)), int(r.get("par", 0)), int(r.get("turns", 0)), String(r.get("why", ""))])
		if not r["ok"]:
			failed.append(int(i) + 1)
		await _wait(6.5 if _film else 1.0)
	print("SOLVE: %s" % ("PASS" if failed.is_empty() else "FAIL levels " + str(failed)))
	quit()
