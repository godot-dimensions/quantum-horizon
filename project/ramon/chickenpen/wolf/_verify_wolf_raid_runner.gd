extends SceneTree

## The wolf's raid (wolf_raid_4d.gd), start to finish: a chicken put home, the wolf sent, a frame
## saved at each beat of the cutscene (res://smoke_test_output/wolf_raid_<n>_<beat>.png), and then
## everything checked as handed back: your input, the HUD, the farm's camera, the wolf gone and
## out of the grass, and the chicken loose again - not home, out of the pen, a little ana, where
## the locator can find it. Prints PASS or FAIL per check; gives up after 70 s.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/wolf/_verify_wolf_raid_runner.gd

const PHASES := ["IDLE", "APPROACH", "LEAP_IN", "TO_CHICKEN", "GRAB", "TO_FENCE", "LEAP_OUT", "RUN_OFF", "FACE"]

var _room: Node
var _raid: Node
var _manager: Node
var _player: Node4D
var _bird: Node = null
var _t: float = 0.0
var _step: int = -1
var _fails: int = 0
var _home_before: int = 0
var _seen: Dictionary = {}
var _n: int = 0
var _input_held: bool = false
var _carried: bool = false


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-50s %s" % ["PASS" if ok else "FAIL", what, detail])


func _process(d: float) -> bool:
	_t += d
	if _t > 70.0:
		print("WOLF RAID FAIL: timed out at step %d, phase %s" % [_step, PHASES[int(_raid.get("phase"))] if _raid != null else "-"])
		return true
	match _step:
		-1:
			var grass: Node = _room.get_node_or_null("World/Grass")
			if (grass != null and not bool(grass.get("mask_ready"))) or _t < 6.0:
				return false
			_raid = _room.get_node("Systems/WolfRaid")
			_manager = _room.get_node("Chickens")
			_player = _room.get_node("Player") as Node4D
			# One chicken home: set down in the pen, as a throw would.
			var agent: Node = (_manager.get("agents") as Array)[0]
			var bird := agent.get_parent() as Node4D
			var pen: Vector4 = (_room.get_node("Pen/Fence") as Node4D).global_position
			bird.global_position = Vector4(pen.x + 1.0, 0.0, pen.z + 0.5, 0.0)
			agent.call("on_landed", true)
			_home_before = int(_manager.call("returned_count"))
			_check("a chicken is home to take", _home_before >= 1, "%d home" % _home_before)
			_check("the wolf is hidden until it comes", not (_room.get_node("World/Wolf") as Node4D).visible)
			_check("it comes when sent", bool(_raid.call("start_raid")))
			_bird = _raid.get("_chicken")
			_step = 0
		0:
			var phase: String = PHASES[int(_raid.get("phase"))]
			if phase != "IDLE":
				_input_held = _input_held or _player.get("input_enabled") == false
				if _bird != null and int(_bird.get("state")) == 4:
					_carried = true
				# A frame at each beat, a moment into it.
				# (Your face a little later, once the line is up.)
				if not _seen.has(phase) and float(_raid.get("_phase_t")) > (1.4 if phase == "FACE" else 0.25):
					_seen[phase] = true
					root.get_texture().get_image().save_png("res://smoke_test_output/wolf_raid_%d_%s.png" % [_n, phase.to_lower()])
					_n += 1
				return false
			_step = 1
		1:
			_check("your input was held during it", _input_held)
			_check("it went through every beat", _seen.size() == PHASES.size() - 1, str(_seen.keys()))
			_check("the chicken was carried off in its mouth", _carried)
			_check("your input is back", _player.get("input_enabled") == true)
			_check("the HUD is back", (_room.get_node("UI/Controls") as CanvasItem).visible)
			_check("the farm's camera is back", (_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).current)
			_check("the wolf is gone", not (_room.get_node("World/Wolf") as Node4D).visible)
			_check("and out of the grass", (_room.get_node("World/Grass").get("_walkers") as Array).is_empty())
			var home_now: int = int(_manager.call("returned_count"))
			_check("one chicken fewer at home", home_now == _home_before - 1, "%d -> %d" % [_home_before, home_now])
			var bird := _bird.get_parent() as Node4D
			var pen: Vector4 = (_room.get_node("Pen/Fence") as Node4D).global_position
			var off := Vector2(bird.global_position.x - pen.x, bird.global_position.z - pen.z)
			_check("the chicken is loose, out of the pen", not bool(_bird.get("returned")) and (absf(off.x) > 4.2 or absf(off.y) > 3.8),
				"at %.1v" % bird.global_position)
			_check("a little ana, where the wolf left the slice", absf(bird.global_position.w - float(_raid.get("exit_w"))) < 0.05)
			_check("and the locator can find it", bool(_bird.call("can_be_caught")))
			print("WOLF RAID %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
			return true
	return false
