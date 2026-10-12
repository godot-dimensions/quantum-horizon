extends SceneTree

## The hawk flight (U): take the flock's hawk, fly it into the murmuration and watch the
## birds roll away, slide out of their W and watch them stop caring, put the projection on to
## see them as a ghost, stoop, and land. Checks the state, saves frames, measures the cost.
##
## Windowed, small, unfocused; saves res://smoke_test_output/hawk_<n>_<view>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_verify_hawk_runner.gd

const TEST_BOOK := "user://lookout_journal_hawk_test.cfg"

var _room: Node
var _lookout: Node
var _hawk: Node
var _flock: Node4D
var _t: float = 0.0
var _step: int = 0
var _wait: float = 0.0
var _n: int = 0
var _failed: int = 0
var _steer: bool = false
var _rolled_close: int = 0
var _costs: Array = []


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if FileAccess.file_exists(TEST_BOOK):
		DirAccess.remove_absolute(TEST_BOOK)
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	_lookout = _room.get_node("Systems/Lookout")
	_lookout.set("journal_path", TEST_BOOK)
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("   %s %-62s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _save(view: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/hawk_%d_%s.png" % [_n, view])
	_n += 1


func _next(after: float = 0.0) -> void:
	_step += 1
	_wait = after
	_t = 0.0


func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _middle() -> Vector4:
	return _flock.global_position + _flock.global_basis * (_flock.get("_middle") as Vector4)


## Points the hawk at the flock's middle (or a little to one side of it).
func _aim(offset: Vector4 = Vector4.ZERO) -> void:
	var at: Vector4 = _hawk.get("at")
	var d: Vector4 = _middle() + offset - at
	_hawk.set("yaw", atan2(-d.x, -d.z))
	_hawk.set("pitch", clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.9, 0.6))


func _process(d: float) -> bool:
	_t += d
	if _steer:
		_aim()
	if _step >= 3 and _step <= 6:
		_costs.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	if _t < _wait:
		return false
	match _step:
		0:
			if _t < 5.0:
				return false
			_hawk = _lookout.get("hawk_flight")
			_flock = _room.get_node("World/Flock")
			_check("there is a hawk to fly", _hawk != null and bool(_hawk.call("can_fly")))
			# Out in the field, facing the roost.
			var player := _room.get_node("Player") as Node4D
			player.global_position = Vector4(0.0, 0.05, -20.0, 0.0)
			_next(0.5)
		1:
			var press := InputEventKey.new()
			press.keycode = KEY_U
			press.physical_keycode = KEY_U
			press.pressed = true
			Input.parse_input_event(press)
			_next(0.6)
		2:
			_check("U: you are the hawk", bool(_hawk.get("flying")))
			_check("the flock says its hawk is flown by you", String(_flock.call("stats").get("hawk", "")) == "flown by you", String(_flock.call("stats").get("hawk", "")))
			_check("the pen's HUD is put away", not (_room.get_node("UI/Controls") as CanvasItem).visible if _room.get_node_or_null("UI/Controls") else true)
			_check("the intro first: you watch it come in", bool(_hawk.call("in_intro")) and not bool(_flock.get("hawk_hidden")))
			_save("intro_watching")
			_step = 21
			_wait = 1.9
			_t = 0.0
		21:
			_save("intro_into_its_eyes")
			_next(1.0)
		22:
			_check("after the intro: from its eyes, the hawk itself not drawn", not bool(_hawk.call("in_intro")) and bool(_flock.get("hawk_hidden")))
			_save("from_its_eyes")
			_steer = true
			_step = 3
			_wait = 2.0
			_t = 0.0
		3:
			if not has_meta("chased"):
				set_meta("chased", true)
				_save("chasing")
			var far: float = float((_hawk.get("stats") as Dictionary).get("flock_far", 999.0))
			if far > 12.0 and _t < 25.0:
				_wait = 0.0
				return false
			print("      reached the flock after %.1f s more" % _t)
			_next(0.0)
		4:
			# In among them: the birds round you roll.
			_rolled_close = maxi(_rolled_close, int(_flock.call("stats").get("rolling", 0)))
			if _t > 1.2:
				_save("in_the_flock")
				_check("in among them, birds roll away from you", _rolled_close > 20, "%d rolling" % _rolled_close)
				_next(0.0)
		5:
			# Slide ana out of their W, and keep flying through where they are.
			var at: Vector4 = _hawk.get("at")
			at.w = _middle().w + 2.5
			_hawk.set("at", at)
			_next(2.5)
		6:
			var st: Dictionary = _hawk.get("stats")
			_check("2.5 m ana of them: out of their slice", not bool(st.get("in_slice", true)), "your w %+.1f, flock %+.1f" % [float(st.get("w", 0)), float(st.get("flock_w", 0))])
			_save("out_of_their_w")
			_lookout.call("set_projection", true)
			_next(1.5)
		7:
			_save("out_of_their_w_projection")
			_lookout.call("set_projection", false)
			var at: Vector4 = _hawk.get("at")
			at.w = _middle().w
			_hawk.set("at", at)
			_steer = false
			# Up, then the stoop.
			_hawk.set("pitch", 0.5)
			_next(2.0)
		8:
			_hawk.set("pitch", -1.1)
			_key(KEY_SHIFT, true)
			_next(0.1)
		9:
			# Shift is read live; hold the stoop by holding the pitch down for a second.
			_hawk.set("pitch", -1.1)
			if _t < 1.2:
				_wait = 0.0
				return false
			_save("stoop")
			_check("Shift: the wings fold and it stoops, fast", bool(_hawk.get("stooping")) and float(_hawk.get("speed")) > 20.0, "%.1f m/s" % float(_hawk.get("speed")))
			_key(KEY_SHIFT, false)
			var press := InputEventKey.new()
			press.keycode = KEY_U
			press.physical_keycode = KEY_U
			press.pressed = true
			Input.parse_input_event(press)
			_next(0.8)
		10:
			_check("U again: landed, the hawk given back", not bool(_hawk.get("flying")) and String(_flock.call("stats").get("hawk", "")) != "flown by you", String(_flock.call("stats").get("hawk", "")))
			var player := _room.get_node("Player") as Node4D
			_check("and your legs back", bool(player.get("input_enabled")) and player.process_mode != Node.PROCESS_MODE_DISABLED)
			_check("the pen's camera is drawing again", (_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).is_current())
			_save("landed")
			_costs.sort()
			print("      scripts while flying: median %.3f ms" % float(_costs[_costs.size() / 2]) if not _costs.is_empty() else "")
			print("HAWK RUNNER: %s (%d failed)" % ["PASS" if _failed == 0 else "FAIL", _failed])
			if FileAccess.file_exists(TEST_BOOK):
				DirAccess.remove_absolute(TEST_BOOK)
			return true
	return false
