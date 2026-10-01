extends SceneTree

## The balloon ride, sped up: it inflates by the tower, boards, lifts off, crosses the farm,
## goes through the flock, drifts ana to the marsh (the camera's slice going with it), a
## photo of the heron there sets off the payoff (slow motion, back to normal on time), the
## whistle reaches it, and the balloon lands and gives the pen back.
##
## Windowed, small, unfocused; saves res://smoke_test_output/ride_<n>_<what>.png. Its own
## journal, deleted at the end.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_verify_ride_runner.gd -- speed=3

const TEST_BOOK := "user://lookout_journal_ride_test.cfg"

var _room: Node
var _lookout: Node
var _station: Node
var _balloon: Node4D
var _heron: Node4D
var _t: float = 0.0
var _step: int = 0
var _failed: int = 0
var _n: int = 0
var _speed: float = 3.0
var _next_frame: float = 0.0
var _max_w: float = 0.0
var _heron_seen: bool = false
var _shot_heron: bool = false
var _slow_seen: bool = false
var _flock_seen: int = 0


func _initialize() -> void:
	root.unfocusable = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("speed="):
			_speed = float(arg.substr(6))
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	_lookout = _room.get_node("Systems/Lookout")
	_lookout.set("journal_path", TEST_BOOK)
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("   %s %-60s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _save(what: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/ride_%d_%s.png" % [_n, what])
	_n += 1


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e)


func _process(d: float) -> bool:
	_t += d
	match _step:
		0:
			if _t < 3.0:
				return false
			_station = _lookout.get("station")
			_balloon = _lookout.get("balloon")
			_heron = _lookout.get("heron")
			var journal: Node = _lookout.get("journal")
			for f in ["approached", "met_wren", "first_climb", "first_photo"]:
				journal.call("set_flag", f, true)
			_check("the balloon is not there yet", not _balloon.visible)
			_check("the marsh is out along W", (_lookout.get("marsh") as Node4D).global_position.w > 7.5)
			_balloon.call("set_ready", true)
			# A camera of our own, to watch it inflate.
			var cam := Camera4D.new()
			cam.name = "RunnerCam"
			cam.set("rendering_engine_name", "Cross-section")
			cam.set("field_of_view_4d", 1.0)
			_room.add_child(cam)
			var eye: Vector4 = _balloon.global_position + Vector4(14.0, 4.0, 16.0, 0.0)
			var look: Vector4 = _balloon.global_position + Vector4(0, 6, 0, 0) - eye
			cam.global_position = eye
			cam.global_basis = Basis4D.from_zx(atan2(-look.x, -look.z)) * Basis4D.from_yz(atan2(look.y, Vector2(look.x, look.z).length()))
			cam.make_current()
			_step = 1
			_t = 0.0
		1:
			if _t > 1.5 and _n == 0:
				_save("inflating")
			if _t > float(_balloon.get("inflate_seconds")) + 0.5:
				_save("inflated")
				_check("the balloon is up", _balloon.visible)
				(_room.get_node("RunnerCam") as Camera4D).queue_free()
				(_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).make_current()
				_balloon.set("ride_speed", _speed)
				_balloon.call("board")
				_step = 2
				_t = 0.0
		2:
			_check("riding", bool(_balloon.get("riding")) and int(_station.get("mode")) == 4)
			_check("36 on the roll", int(_station.get("film")) == 36)
			_step = 3
			_t = 0.0
			_next_frame = 0.0
		3:
			var rt: float = float(_balloon.get("ride_time"))
			var cam: Camera4D = _station.get("camera")
			if cam != null:
				_max_w = maxf(_max_w, cam.global_position.w)
			# Look where a passenger would: down at the farm early, into the flock, then at
			# the heron once the marsh is near.
			if rt < 50.0:
				_station.call("look_along", Vector4(-0.2, -0.55, -1.0, 0.0))
				_station.set("zoom_goal", 1.0)
			elif rt < 82.0:
				_station.call("look_along", Vector4(0.0, 0.3, -1.0, 0.0))
				if rt > 62.0 and rt < 64.0 and _flock_seen == 0:
					_flock_seen = 1
					_key(KEY_X)
			else:
				var at: Vector4 = _heron.call("centre")
				_station.call("look_along", at - _station.call("home_eye"))
				_station.set("zoom_goal", 3.0)
				var seen: bool = false
				for v in _lookout.get("subjects").call("in_view", cam, _station.call("home_eye"), _station.call("slice_normal"), 3.0):
					if v["subject"]["id"] == "heron":
						seen = true
						# Pull focus to it, as T would.
						_station.set("focus_goal", clampf(float(v["w"]), -3.0, 3.0))
				if seen:
					_heron_seen = true
				if seen and rt > 118.0 and not _shot_heron and absf(float(_station.get("focus")) - float(_station.get("focus_goal"))) < 0.05:
					_shot_heron = true
					_station.call("take_photo")
					print("      shot the heron at ride time %.1f" % rt)
			if Engine.time_scale < 0.9:
				_slow_seen = true
			if _t >= _next_frame:
				_next_frame += 6.0 / _speed
				_save("ride_t%03d" % int(rt))
			if not bool(_balloon.get("riding")):
				_step = 4
				_t = 0.0
		4:
			if _t < 1.0:
				return false
			var journal: Node = _lookout.get("journal")
			_check("the camera went out along W with the basket", _max_w > 7.0, "max w %.2f" % _max_w)
			_check("the heron was in view from the basket", _heron_seen)
			_check("a photo of the heron was taken", _shot_heron)
			_check("the heron is in the journal", bool(journal.call("found", "heron")), str(journal.get("recent").back() if not (journal.get("recent") as Array).is_empty() else ""))
			_check("the payoff slowed time", _slow_seen)
			_check("and time is back to normal", is_equal_approx(Engine.time_scale, 1.0))
			_check("landed: the pen given back", int(_station.get("mode")) == 0 and (_room.get_node("Player") as Node4D).visible)
			var p: Vector4 = (_room.get_node("Player") as Node4D).global_position
			_check("the player is beside the basket", Vector2(p.x - _balloon.global_position.x, p.z - _balloon.global_position.z).length() < 4.0,
				str(p))
			_check("the ride is in the story", bool(journal.call("flag", "balloon_ridden")))
			_save("landed")
			var book: String = ProjectSettings.globalize_path(TEST_BOOK)
			if FileAccess.file_exists(TEST_BOOK):
				DirAccess.remove_absolute(book)
			var photos: String = ProjectSettings.globalize_path("user://lookout_journal_ride_test_photos")
			if DirAccess.dir_exists_absolute(photos):
				for f in DirAccess.get_files_at(photos):
					DirAccess.remove_absolute(photos + "/" + f)
				DirAccess.remove_absolute(photos)
			print("RIDE RUNNER: %s (%d failed)" % ["PASS" if _failed == 0 else "FAIL", _failed])
			return true
	return false
