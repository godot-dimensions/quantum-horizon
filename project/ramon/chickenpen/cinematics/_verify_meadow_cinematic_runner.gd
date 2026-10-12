extends SceneTree

## The meadow cinematic (cinematic_meadow_4d.gd) borrows the pen and gives it all back. Plays
## it from the Cinematics node: the title waits for the grass; the wind is raised in the wind
## shot; the walk-through shot lays a trail with no one there; Escape in the last shot skips to
## the end; then the wind, the big gusts, the player, the HUD, the buses and the farm's camera
## are as they were, and the walker is gone. Saves a frame from each shot:
## res://smoke_test_output/meadow_<n>.png. Prints PASS or FAIL per check; gives up after 140 s.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/cinematics/_verify_meadow_cinematic_runner.gd

var _room: Node
var _grass: Node
var _cinematics: Node
var _film: Node
var _t: float = 0.0
var _step: int = -1
var _fails: int = 0
var _saved: Dictionary = {}
var _shot_seen: int = -1
var _wind_peak: float = 0.0
var _trail_peak: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-52s %s" % ["PASS" if ok else "FAIL", what, detail])


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up: InputEventKey = e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _process(d: float) -> bool:
	_t += d
	if _t > 140.0:
		print("MEADOW FAIL: timed out at step %d, shot %d" % [_step, _shot_seen])
		return true
	match _step:
		-1:
			# Started at once, as from the menu: the grass is not grown yet.
			_grass = _room.get_node("World/Grass")
			_cinematics = _room.get_node("Cinematics")
			_saved = {"wind_scale": float(_grass.get("wind_scale")), "big": float(_grass.get("big_gust_chance")),
				"player": (_room.get_node("Player") as Node4D).visible, "music": AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music"))}
			_check("the grass is not grown yet as it starts", not bool(_grass.get("mask_ready")))
			_check("it starts", bool(_cinematics.call("play", "meadow")))
			_film = _cinematics.get("_playing")
			_step = 0
		0:
			var shot: int = int(_film.get("_shot"))
			if shot == 0 and _shot_seen < 0:
				_check("the first shot waits for the grass", bool(_grass.get("mask_ready")))
				_check("the player is hidden for it", not (_room.get_node("Player") as Node4D).visible)
			if shot != _shot_seen:
				_shot_seen = shot
			# A frame from each shot, halfway through it.
			var into: float = float(_film.get("_shot_t"))
			var shots: Array = (_film.get_script() as GDScript).get_script_constant_map()["SHOTS"]
			var length: float = float(shots[maxi(shot, 0)][2])
			if shot >= 0 and into >= length * 0.5 and not _film.has_meta("saved_%d" % shot):
				_film.set_meta("saved_%d" % shot, true)
				root.get_texture().get_image().save_png("res://smoke_test_output/meadow_%d.png" % shot)
			if shot == 4:
				_wind_peak = maxf(_wind_peak, float(_grass.get("wind_scale")))
			if shot == 6:
				var trails: Dictionary = _grass.get("_trails")
				var walker: Node = _room.get_node_or_null("World/CinematicWalker")
				if walker != null and trails.has(walker.get_instance_id()):
					_trail_peak = maxi(_trail_peak, (trails[walker.get_instance_id()] as Array).size())
			if shot == 7 and into > 1.5:
				_check("the wind shot raised the wind", _wind_peak > float(_saved["wind_scale"]) * 1.3,
					"%.2f -> %.2f" % [float(_saved["wind_scale"]), _wind_peak])
				_check("the walk-through laid a trail", _trail_peak >= 4, "%d points" % _trail_peak)
				_key(KEY_ESCAPE)
				_step = 1
				_t = 0.0
		1:
			if not bool(_cinematics.call("is_playing")) and _t > 0.5:
				_check("Escape skipped it", true, "%.1f s" % _t)
				_check("the wind as it was", is_equal_approx(float(_grass.get("wind_scale")), float(_saved["wind_scale"])),
					"%.2f" % float(_grass.get("wind_scale")))
				_check("the big gusts as they were", is_equal_approx(float(_grass.get("big_gust_chance")), float(_saved["big"])))
				_check("the walker gone", _room.get_node_or_null("World/CinematicWalker") == null)
				_check("the grass lends nothing", (_grass.get("_walkers") as Array).is_empty())
				_check("the player back", (_room.get_node("Player") as Node4D).visible == bool(_saved["player"]))
				_check("the Music bus as it was", AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")) == bool(_saved["music"]))
				_check("the HUD back", (_room.get_node("UI/Controls") as CanvasItem).visible)
				_check("the farm's own camera back", (_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).current)
				print("MEADOW %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
				return true
			elif _t > 10.0:
				_check("Escape skipped it", false, "still playing")
				print("MEADOW FAIL (%d)" % _fails)
				return true
	return false
