extends SceneTree

## THE PLAYABLE WORLD IN SHORT BEATS, PLAYED LIKE A PERSON WOULD (Ramon, 7 Oct, on the old tour film: "it shows you
## walking through tryms house, and just straight ahead, can't you make the character walk like a human operator and
## follow the path, rotate W .. like short bits of walkthrough, and mind when you stop, rotate and what you do. make your
## robot smarter please ... show shorter videos showing different stuff. action paced beats, sometimes longer to show
## how cool it is").
##
## The operator, below: it eases its turns (a turn rate, never a snap), walks only once it roughly faces where it is
## going, slows into a stop, looks round when it arrives, holds still a beat before it does something, and uses the
## game's own keys (I, V, P, R, E, Z, T, the wheel, a click) through Input, as a player's hands would. One beat a run:
##   path        from the start down the road to Trym's house, a look round at the junction, stopping on his circle
##   slice       in the wood: the slice turned into W with the right mouse button, held, walked, then R
##   camp        down the camp's road to the scout, the slice turned until the camp shows, V, and in
##   cave        the cave's road: off the main road, stepping ana with the climb, the open arch, and in
##   toggle      the dev look and the art, switched with I as the camera drifts
##   lookout     on the Watchstone: Z, the wheel, T on the marsh 8 m ana, the heron, a photo
##   projection  P: the ghost of everything ana and kata, the slice turned a little, and off again
##
##   lab_run.sh movie_hd beat_<mode> res://ramon/PenLayout/scripts/_film_beats_runner.gd <mode>

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")

var _room: Node
var _player: CharacterBody4D
var _rig: Node4D
var _mode: String = "path"
var _over: Control
var _say: String = ""
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_mode = args[0] if args.size() > 0 else "path"
	_room = (load(PEN) as PackedScene).instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://film_beats_journal.cfg")
	if FileAccess.file_exists("user://film_beats_journal.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://film_beats_journal.cfg"))
	root.add_child(_room)
	current_scene = _room
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 1500000:
		print("BEATS: gave up")
		return true
	return false


# --- Time, keys and the screen -------------------------------------------------------------------------

func _wait(s: float) -> void:
	await create_timer(s).timeout


func _dt() -> float:
	return maxf(root.get_process_delta_time(), 1.0 / 60.0)


func _key(code: Key, shift: bool = false) -> void:
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.keycode = code
		k.physical_keycode = code
		k.pressed = pressed
		k.shift_pressed = shift
		Input.parse_input_event(k)
		await process_frame


func _caption(text: String) -> void:
	_say = text
	if _over != null:
		_over.queue_redraw()


func _draw_over() -> void:
	if _say == "":
		return
	var font: Font = LabPrint.font("bold")
	var s: Vector2 = _over.size
	var fs: int = 30
	var tw: float = font.get_string_size(_say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(56.0, s.y - 64.0)
	_over.draw_rect(Rect2(at + Vector2(-22.0, -44.0), Vector2(tw + 44.0, 64.0)), Color(0.02, 0.025, 0.03, 0.78))
	_over.draw_string(font, at, _say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))


## The HUD down to what a beat is about: the dial for the W beats, nothing else but the game's own prompts and
## talk (world tags and dialogue boxes are not under these).
func _hud(keep: Array) -> void:
	for c in _room.get_node("UI").get_children():
		if c is CanvasItem and not (String(c.name) in keep):
			var item := c as CanvasItem
			item.visible = false
			c.process_mode = Node.PROCESS_MODE_DISABLED if String(c.name) in ["GrassPanel", "PathsPanel"] else c.process_mode


# --- The operator ----------------------------------------------------------------------------------------

## The heading toward world (x, z): 0 faces -z, PI faces +z, -PI/2 faces +x.
static func _heading(d: Vector2) -> float:
	return atan2(-d.x, -d.y)


## Turns toward [param target] at most [param rate] radians a second; the difference left.
func _steer(target: float, rate: float = 2.4) -> float:
	var cur: float = float(_rig.get("yaw"))
	var diff: float = wrapf(target - cur, -PI, PI)
	_rig.set("yaw", cur + clampf(diff, -rate * _dt(), rate * _dt()))
	return diff


## Turns on the spot to [param target], eased.
func _turn(target: float, seconds: float = 0.8) -> void:
	var from: float = float(_rig.get("yaw"))
	var diff: float = wrapf(target - from, -PI, PI)
	var n: int = maxi(1, int(seconds / _dt()))
	for i in n:
		_rig.set("yaw", from + diff * smoothstep(0.0, 1.0, float(i + 1) / float(n)))
		await process_frame


## A look to one side and back, as someone getting their bearings does.
func _look_round(amount: float = 0.6, seconds: float = 2.0) -> void:
	var home: float = float(_rig.get("yaw"))
	await _turn(home + amount, seconds * 0.35)
	await _wait(seconds * 0.15)
	await _turn(home - amount * 0.5, seconds * 0.3)
	await _turn(home, seconds * 0.2)


## Walks through world (x, z) points: turning before walking when it faces well away, easing off into the last.
## [param w_to] steps ana or kata on the way (E or Q) while the W is short of it; [param w_from] is the distance
## along the walk where the stepping begins.
func _walk(points: Array, w_to: float = NAN, stop_at: float = 0.6) -> void:
	for i in points.size():
		var p: Vector2 = points[i]
		var last: bool = i == points.size() - 1
		var guard: int = 0
		while guard < 1200:
			guard += 1
			var at: Vector4 = _player.global_position
			var d := Vector2(p.x - at.x, p.y - at.z)
			if d.length() < (stop_at if last else 1.2):
				break
			var diff: float = _steer(_heading(d), 2.6 if last else 3.2)
			if absf(diff) < 0.9:
				Input.action_press(&"move_forward")
			else:
				Input.action_release(&"move_forward")
			if not is_nan(w_to):
				var short: float = w_to - at.w
				if absf(short) > 0.05:
					Input.action_press(&"move_ana" if short > 0.0 else &"move_kata")
				else:
					Input.action_release(&"move_ana")
					Input.action_release(&"move_kata")
			await process_frame
	Input.action_release(&"move_forward")
	Input.action_release(&"move_ana")
	Input.action_release(&"move_kata")


## Steps through W on the spot to [param w].
func _step_w(w: float, max_seconds: float = 4.0) -> void:
	var t: float = 0.0
	while absf(_player.global_position.w - w) > 0.05 and t < max_seconds:
		Input.action_press(&"move_ana" if w > _player.global_position.w else &"move_kata")
		t += _dt()
		await process_frame
	Input.action_release(&"move_ana")
	Input.action_release(&"move_kata")


## The slice turned by [param drag] radians (x: across, through xw; y: ahead, through zw) over [param seconds], the
## way holding the right button and dragging turns it.
func _tilt(drag: Vector2, seconds: float) -> void:
	var n: int = maxi(1, int(seconds / _dt()))
	var done := Vector2.ZERO
	for i in n:
		var want: Vector2 = drag * smoothstep(0.0, 1.0, float(i + 1) / float(n))
		_rig.call("drag_slice", want - done)
		done = want
		await process_frame


func _place(at: Vector4, yaw: float) -> void:
	_player.global_position = at
	_player.set("linear_velocity", Vector4.ZERO)
	_rig.call("align_to", at.w)
	_rig.set("yaw", yaw)
	await _wait(0.2)


# --- The beats -------------------------------------------------------------------------------------------

func _run() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	_room.add_child(layer)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	layer.add_child(_over)
	_player = _room.get_node("Player") as CharacterBody4D
	_rig = _room.get_node("Player/CameraRig") as Node4D
	var look: Node = _room.get_node("Systems/Look")
	# Every beat but the toggle in the art look; the toggle starts there.
	await _wait(5.0)
	if bool(look.get("dev")):
		look.call("set_dev", false)
	await _wait(1.0)
	match _mode:
		"path":
			_hud([])
			await _place(Vector4(24.9, 0.05, 25.5, 0.0), PI)
			_caption("Follow the path")
			await _wait(0.6)
			await _look_round(0.5, 1.6)
			await _walk([Vector2(24.9, 36.3)], NAN, 0.9)
			_caption("A junction: the cave west, Trym's house ahead")
			await _turn(PI - 1.2, 0.7)
			await _wait(0.5)
			await _turn(PI, 0.6)
			await _walk([Vector2(24.9, 40.6)], NAN, 0.5)
			_caption("Trym's house")
			await _wait(0.4)
			await _look_round(-0.35, 1.4)
			await _wait(0.6)
		"slice":
			_hud(["SlicePlane"])
			await _place(Vector4(-2.0, 0.05, 30.0, 0.0), -PI * 0.5 + 0.4)
			_caption("Hold the right mouse button: the slice turns into W")
			await _wait(0.8)
			await _tilt(Vector2(0.75, 0.0), 2.6)
			await _wait(0.8)
			_caption("A wood stands through W, so the wood stays")
			await _walk([Vector2(-8.0, 27.0)], NAN, 0.8)
			await _tilt(Vector2(0.0, 0.35), 1.4)
			await _wait(0.6)
			_caption("R: back to your own slice")
			await _key(KEY_R)
			await _wait(1.6)
		"camp":
			_hud(["SlicePlane"])
			await _place(Vector4(-12.0, 0.05, -3.9, 0.0), -PI * 0.5)
			_caption("The camp's road")
			await _walk([Vector2(-6.2, -3.9)], NAN, 0.8)
			_caption("The scout: the camp is right in front of you, just not in your slice")
			await _turn(-PI * 0.5 - 0.5, 0.6)
			await _wait(1.2)
			await _turn(-PI * 0.5, 0.6)
			_caption("Look down the path, turn the slice")
			await _wait(0.4)
			var camp: Node = _room.find_child("EggCamp", true, false)
			var guard: int = 0
			while guard < 90 and not (camp != null and bool(camp.call("can_align"))):
				guard += 1
				_rig.call("drag_slice", Vector2(0.0, 0.004))
				await process_frame
			await _wait(0.5)
			_caption("V: line the slice up with the camp")
			await _key(KEY_V)
			await _wait(1.2)
			await _walk([Vector2(6.0, -4.0)], NAN, 0.8)
			_caption("At the camp's own W")
			await _look_round(0.4, 1.5)
		"cave":
			_hud([])
			await _place(Vector4(13.0, 0.05, 37.1, 0.0), PI * 0.5)
			_caption("The road to the cave")
			await _walk([Vector2(7.6, 37.1)], NAN, 1.0)
			await _turn(0.0, 0.7)
			_caption("Its road climbs ana: walk it and step with it (E)")
			await _walk([Vector2(7.35, 34.4)], NAN, 0.8)
			await _walk([Vector2(7.36, 32.4)], 3.0, 0.8)
			await _step_w(3.0, 1.5)
			_caption("At W 3 the arch stands open")
			await _wait(1.0)
			await _walk([Vector2(7.45, 25.0)], NAN, 0.5)
			await _wait(2.5)
		"toggle":
			_hud([])
			await _place(Vector4(-14.0, 0.05, -15.0, 0.0), 0.35)
			_rig.set("pitch", -0.05)
			_caption("The art look")
			for i in 5:
				var t: float = 0.0
				while t < 1.5:
					_rig.set("yaw", float(_rig.get("yaw")) - 0.12 * _dt())
					t += _dt()
					await process_frame
				await _key(KEY_I)
				# What shows now (the caption names the look on screen).
				_caption("I: the dev look" if i % 2 == 0 else "I: the art look")
			await _wait(1.0)
		"lookout":
			_hud([])
			var lookout: Node = _room.get_node("Systems/Lookout")
			var journal: Node = lookout.get("journal")
			for f in ["approached", "met_wren", "first_raise", "first_photo"]:
				journal.call("set_flag", f, true)
			var wren: Node = lookout.get("wren")
			if wren != null:
				wren.set("has_camera", false)
			var t := _room.get_node("World/LookoutSite/Lookout") as Node4D
			var marsh := lookout.get("marsh") as Node4D
			var head: Vector4 = t.call("_ladder_head")
			var dir := Vector2(head.x, head.z).normalized().rotated(1.1)
			var deck: Vector4 = t.global_position + t.global_basis * Vector4(dir.x * 1.6, 13.70, dir.y * 1.6, 0.0)
			var to_marsh: Vector4 = marsh.global_position - deck
			# At the rail, already looking out (the oak's crown is behind you and pulls the camera in).
			var rail: Vector4 = t.global_position + t.global_basis * Vector4(dir.x * 3.0, 13.70, dir.y * 3.0, 0.0)
			await _place(rail, _heading(Vector2(to_marsh.x, to_marsh.z)))
			_caption("On top of the Watchstone, by the rail")
			await _wait(1.4)
			_caption("Z: Wren's camera")
			await _key(KEY_Z)
			await _wait(1.0)
			# The camera's two info cards away (F3), for the view.
			await _key(KEY_F3)
			await _wait(0.3)
			var station: Node = lookout.get("station")
			var eye: Vector4 = _player.global_position + Vector4(0.0, 1.5, 0.0, 0.0)
			_rig.set("pitch", -atan2(eye.y - marsh.global_position.y, Vector2(to_marsh.x, to_marsh.z).length()))
			_rig.call("drag_slice", Vector2.ZERO)
			_caption("The wheel zooms")
			for i in 5:
				var wheel := InputEventMouseButton.new()
				wheel.button_index = MOUSE_BUTTON_WHEEL_UP
				wheel.pressed = true
				station.call("_input", wheel)
				await _wait(0.18)
			await _wait(0.8)
			_caption("T: the slice lined up with what you look at, 8 m ana")
			await _key(KEY_T)
			await _wait(2.0)
			_caption("Click: a photo")
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			station.call("_input", click)
			await _wait(2.4)
		"projection":
			_hud([])
			# Looking down the camp's road: the camp is 2.5 m kata, not in your slice.
			await _place(Vector4(-7.0, 0.05, -3.9, 0.0), -PI * 0.5)
			_rig.set("pitch", -0.08)
			_caption("The camp is down this road, 2.5 m kata: not in your slice")
			await _wait(1.6)
			_caption("P: a ghost of everything ana and kata")
			await _key(KEY_P)
			await _wait(1.8)
			await _tilt(Vector2(0.0, 0.12), 1.6)
			_caption("Turn the slice toward it, and it comes in")
			await _wait(1.4)
			await _key(KEY_P)
			_caption("P again: just your slice")
			await _wait(1.2)
	_caption("")
	await _wait(0.3)
	print("BEATS %s: done" % _mode)
	quit(0)
