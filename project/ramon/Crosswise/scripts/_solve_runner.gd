extends SceneTree
## Crosswise: the solver bot (PLAN.md steps 65-66). Plays the whole sequence, all four islands,
## through the game's own code: the walker's movement (its scripted keys go through the same
## _physics_process as the keyboard), the camera's turn (request_turn, what the right mouse calls),
## and the hands' use() and strike() (what E and the left mouse call). Asserts that each island's
## beat happens (the gate passed, the crate out of the cage, the plate down and the bridge laid, both
## rocks broken, the finale) and saves a frame at every beat to
## smoke_test_output/crosswise/solve/.
##
## Steps: ["walk", x, c]       walk in the current view to world x and world c along the axis W/S
##                              walk (z in the normal view, w once turned)
##        ["turn"]             turn the view (and wait for it)
##        ["lift"] / ["place"] / ["strike"]
##        ["jump_to", x, depth] walk there jumping as it starts
##        ["shot", name]       save a frame
##        ["check", name]      assert a named condition
##        ["face", angle]      face a way inside the slice (PI: away from the camera), as a player
##                              would by tapping the key: he faces the way he last walked
##        ["wait", seconds]
##
## Run: Crosswise/run.sh windowed solve res://ramon/Crosswise/scripts/_solve_runner.gd
## Film (PLAN.md step 67): Crosswise/run.sh movie crosswise res://.../_solve_runner.gd film
## (the opening shot plays first, no frames are saved, the sound is recorded).

const SCENE := "res://ramon/Crosswise/crosswise.tscn"
const OUT := "res://smoke_test_output/crosswise/solve/"
const ARRIVE := 0.09

var STEPS := [
	# 1. THE WALL
	["shot", "i1_01_start"],
	["walk", 0.0, 1.25],
	["shot", "i1_02_at_wall"],
	["turn"],
	["shot", "i1_03_turned_lanes"],
	["walk", 0.0, 3.2],
	["shot", "i1_04_in_gate_lane"],
	["turn"],
	["shot", "i1_05_gate_open"],
	["walk", 0.0, -1.7],
	["shot", "i1_06_through"],
	["turn"],
	["walk", 0.0, 0.0],
	["turn"],
	["shot", "i1_07_back_in_lane0"],
	["walk", -1.6, -2.05],
	["lift"],
	["shot", "i1_08_lifted"],
	["walk", 0.0, -2.8],
	["face", PI],
	["place"],
	["check", "crate_at_terrace"],
	["shot", "i1_09_placed"],
	["walk", 0.0, -2.75],
	["jump_to", 0.0, -3.75],
	["wait", 0.3],
	["jump_to", 0.0, -4.9],
	["check", "on_terrace"],
	["shot", "i1_10_on_terrace"],
	# 2. THE CAGE
	["walk", 0.0, -12.4],
	["check", "island_2"],
	["shot", "i2_01_start"],
	["turn"],
	["walk", 0.0, -1.6],
	["turn"],
	["walk", -2.4, -14.6],
	["shot", "i2_02_on_footprint"],
	["turn"],
	["shot", "i2_03_cage_open_in_w"],
	["walk", -2.4, -0.62],
	["lift"],
	["shot", "i2_04_crate_lifted_in_cage"],
	["walk", -2.4, -1.6],
	["turn"],
	["walk", 2.2, -18.55],
	["turn"],
	["walk", 2.2, 0.0],
	["turn"],
	["face", PI],
	["shot", "i2_05_at_plate"],
	["place"],
	["wait", 1.8],
	["check", "plate_down"],
	["shot", "i2_06_bridge_laid"],
	["walk", 0.0, -19.4],
	["walk", 0.0, -27.0],
	["check", "crossed_chasm"],
	["shot", "i2_07_across"],
	# 3. THE SEAM
	["walk", 0.0, -35.95],
	["check", "island_3"],
	["shot", "i3_01_rock_a"],
	["strike"],
	["wait", 0.5],
	["shot", "i3_02_rock_a_struck_once"],
	["strike"],
	["wait", 0.6],
	["check", "rock_a_broken"],
	["walk", 0.0, -44.2],
	["shot", "i3_03_on_band"],
	["turn"],
	["shot", "i3_04_seam_in_view"],
	["walk", 0.0, 1.62],
	["strike"],
	["wait", 0.5],
	["shot", "i3_05_rock_b_struck_once"],
	["strike"],
	["wait", 0.6],
	["check", "rock_b_broken"],
	["walk", 0.0, 3.2],
	["turn"],
	["walk", 0.0, -49.0],
	["shot", "i3_06_to_bridge"],
	# 4. THE SHRINE
	["walk", 0.0, -55.0],
	["check", "island_4"],
	["shot", "i4_01_start"],
	["walk", 2.2, -56.75],
	["lift"],
	["walk", 0.0, -55.4],
	["turn"],
	["shot", "i4_02_strip_turned"],
	["walk", 0.0, 0.0],
	["turn"],
	["walk", 0.0, -61.6],
	["face", PI],
	["place"],
	["check", "crate_at_mark"],
	["shot", "i4_03_crate_placed"],
	["walk", 0.0, -61.55],
	["jump_to", 0.0, -62.5],
	["wait", 0.3],
	["jump_to", 0.0, -63.6],
	["check", "on_shrine_terrace"],
	["to_finale", 0.0, -64.6],
	["wait", 1.0],
	["check", "finished"],
	["shot", "i4_04_finale"],
]

var _game: Node
var _walker: CharacterBody4D
var _cam: Node
var _hands: Node
var _i: int = 0
var _t: float = 0.0
var _total: float = 0.0
var _started: bool = false
var _jumped: bool = false
## Whether this step's one action (turn, use, strike) has been sent: by a flag, never by "the first
## 0.05 s", because a slow first frame skipped it (5-6 Oct).
var _acted: bool = false
var _fails: int = 0
var _checks: int = 0
var _film: bool = false


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_film = "film" in OS.get_cmdline_user_args()
	_game = (load(SCENE) as PackedScene).instantiate()
	if not _film:
		_game.set("play_intro", false)
	root.add_child.call_deferred(_game)


## The coordinate the view's W/S keys walk along: world Z in the normal view, world W turned.
func _coord(p: Vector4) -> float:
	return p.w if bool(_cam.call("is_turned")) else p.z


func _process(delta: float) -> bool:
	_total += delta
	if _total > 300.0:
		print("SOLVE FAIL: timed out at step %d %s" % [_i, str(STEPS[_i]) if _i < STEPS.size() else ""])
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _game == null or not _game.is_inside_tree():
		return false
	if not _started:
		_walker = _game.get("walker")
		_cam = _game.get("camera")
		_hands = _game.get("hands")
		_walker.set("scripted", true)
		_started = true
		_t = -1.0
	_t += delta
	if _t < 0.0:
		return false
	if _film and bool(_cam.call("in_intro")):
		_t = -0.6
		return false
	if _i >= STEPS.size():
		if _film and _t < 7.0:
			return false
		print("SOLVE done: %d steps, %d checks, %d failed, %.1f s" % [STEPS.size(), _checks, _fails, _total])
		return true
	var s: Array = STEPS[_i]
	match String(s[0]):
		"to_finale":
			# Walk at the shrine door until the finale takes over.
			if bool(_game.get("done")):
				_walker.set("scripted_move", Vector2.ZERO)
				_next()
			elif _t > 20.0:
				print("SOLVE FAIL: the finale never started")
				_fails += 1
				_next()
			else:
				_walker.set("scripted_move", Vector2(0, -1))
		"walk", "jump_to":
			if _t > 25.0:
				print("SOLVE FAIL: could not reach %s from %s" % [str(s), _walker.global_position])
				_fails += 1
				_next()
				return false
			if String(s[0]) == "jump_to" and not _jumped:
				_walker.call("jump")
				_jumped = true
			var p: Vector4 = _walker.global_position
			var dx: float = float(s[1]) - p.x
			var dd: float = float(s[2]) - _coord(p)
			var far: float = Vector2(dx, dd).length()
			if far < ARRIVE and (_walker as CharacterBody4D).is_on_floor():
				_walker.set("scripted_move", Vector2.ZERO)
				_next()
			else:
				# Local keys: +x right, +y toward the camera: +Z in the normal view, -W once turned
				# (the camera's turn_sign of -1 puts it on the kata side).
				var mv := Vector2(dx, -dd if bool(_cam.call("is_turned")) else dd)
				_walker.set("scripted_walk", far < 0.6)
				_walker.set("scripted_move", mv.normalized() * clampf(far * 3.0, 0.35, 1.0))
		"turn":
			if not _acted:
				_cam.call("request_turn")
				_acted = true
			elif not bool(_cam.call("is_turning")) and _t > 0.2:
				_next()
		"lift", "place":
			if not _acted:
				_hands.call("use")
				_acted = true
			elif _t > 0.6:
				var carrying: bool = _hands.get("carried") != null
				var ok: bool = carrying if String(s[0]) == "lift" else not carrying
				if not ok and String(s[0]) == "place":
					var spot: Array = _hands.call("place_spot")
					var foot: Vector4 = spot[1]
					print("SOLVE place refused: spot %s ok %s, blocker '%s'" % [foot, str(spot[0]),
						_game.call("blocker", foot + Vector4(0, 0.35, 0, 0), Vector4(0.7, 0.7, 0.7, 0.7), _hands.get("carried"))])
				_report(ok, "%s at %s" % [s[0], _walker.global_position])
				_next()
		"strike":
			if not _acted:
				_hands.call("strike")
				_acted = true
			elif _t > 0.7:
				_next()
		"wait":
			if _t > float(s[1]):
				_next()
		"face":
			_walker.call("set_facing_angle", float(s[1]))
			if _t > 0.15:
				_next()
		"shot":
			if _t > 0.25:
				_save(String(s[1]))
				_next()
		"check":
			_report(_condition(String(s[1])), String(s[1]))
			_next()
	return false


func _next() -> void:
	_i += 1
	_t = 0.0
	_jumped = false
	_acted = false


func _condition(name: String) -> bool:
	var p: Vector4 = _walker.global_position
	var crates: Array = _game.call("crates")
	var plugs: Array = _game.call("plugs")
	match name:
		"crate_at_terrace":
			var c: Vector4 = (crates[0] as Node4D).global_position
			return absf(c.x) < 0.3 and absf(c.z + 3.75) < 0.3 and absf(c.w) < 0.1
		"on_terrace":
			return p.y > 1.2 and p.z < -4.3
		"island_2":
			return int(_game.get("island")) == 2
		"plate_down":
			return bool(_game.get_node("Level/I2Plate").get("pressed"))
		"crossed_chasm":
			return p.z < -25.5 and p.y > 1.0
		"island_3":
			return int(_game.get("island")) == 3
		"rock_a_broken":
			return bool((plugs[0] as Node).call("is_broken"))
		"rock_b_broken":
			return bool((plugs[1] as Node).call("is_broken"))
		"island_4":
			return int(_game.get("island")) == 4
		"crate_at_mark":
			var c4: Vector4 = (crates[2] as Node4D).global_position
			return absf(c4.x) < 0.3 and absf(c4.z + 62.5) < 0.3 and absf(c4.w) < 0.1
		"on_shrine_terrace":
			return p.y > 2.8
		"finished":
			return bool(_game.get("done"))
	return false


func _report(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("SOLVE %s %s  (walker %s, island %d, turned %s)" % ["PASS" if ok else "FAIL", what, _walker.global_position, int(_game.get("island")), str(_cam.call("is_turned"))])


func _save(name: String) -> void:
	if _film:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("SOLVE saved %s at %s" % [name, _walker.global_position])
