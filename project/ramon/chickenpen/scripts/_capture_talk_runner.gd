extends SceneTree

## The whole talk as a seated player sees it, one frame at each slide's key moments.
##
## SEATED, SO THE PICTURES ARE THE REAL ONES. Sitting down hands the camera to the shot rig,
## which is what frames every slide; a capture that never sits photographs the player's own
## orbit camera and none of the framing anybody will actually get.
##
## Windowed (--headless has no rendering device). Args after --: fast=<seconds> sets the
## shared act length (default 9, which keeps each beat in proportion but the run short).
## Writes res://smoke_test_output/talk_<nn>_<what>.png.

var _root: Node
var _f := 0
var _show: Node
var _two: Node
var _seat: Node
var _player: CharacterBody4D
var _sat := false
var _n := 0
var _seen := {}
var _pending := ""
var _wait := 0
var _fast := 9.0

## Part one's beats: [act, fraction of its length, name].
const ONE := [
	[0, 0.05, "i_chicken_alone"], [0, 0.24, "i_ball_coming"], [0, 0.30, "i_ball_cut"],
	[0, 0.72, "i_cone_cut"],
	[1, 0.20, "ii_ball"], [1, 0.30, "ii_ball_wide"], [1, 0.54, "ii_face"], [1, 0.76, "ii_corner"],
	[1, 0.84, "ii_corner_mid"],
	[2, 0.70, "iii_rock"],
	[3, 0.05, "iv_tiger_slice"], [3, 0.12, "iv_tiger_turned"],
	[3, 0.25, "iv_spheritorus_slice"], [3, 0.32, "iv_spheritorus_turned"],
	[3, 0.45, "iv_ditorus_slice"], [3, 0.52, "iv_ditorus_turned"],
	[3, 0.65, "iv_duocylinder_slice"], [3, 0.72, "iv_duocylinder_turned"],
	[3, 0.85, "iv_klein_slice"], [3, 0.92, "iv_klein_turned"],
	[4, 0.20, "v_toy"], [4, 0.45, "v_toy_later"], [4, 0.62, "v_gloves"], [4, 0.88, "v_glove_turning"],
	[4, 0.99, "v_gloves_matched"],
]
const TWO := [[0, 0.6, "vi_goat"], [1, 0.6, "vii_tool"], [2, 0.4, "viii_walk"]]


func _initialize() -> void:
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("fast="):
			_fast = float(a.substr(5))
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f == 1:
		_show = _root.get_node("Show")
		_two = _root.get_node("PartTwo")
		_seat = _root.get_node("UI/Seat")
		_player = _root.get_node("Player") as CharacterBody4D
		_show.set("opening_seconds", 3.0)
		_show.set("act_seconds", _fast)
		_show.set("hold_on_seat_seconds", 0.4)
		_show.set("after_sit_seconds", 0.6)
		_two.set("moment_seconds", _fast * 1.1)
		_seat.set("sit_seconds", 0.4)
		return false
	if _f == 3:
		print("on arrival   video memory %.0f MB"
			% (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
		var stage: Node4D = _root.get_node("Stage") as Node4D
		var top: Vector4 = stage.get("aisle_to")
		var foot: Vector4 = stage.get("aisle_from")
		_player.set_physics_process(false)
		_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18,
			lerpf(top.z, foot.z, 0.5), 0.0)
		return false
	if not _sat and bool(_seat.call("is_offering")):
		_sat = true
		_seat.call("sit")
	if _pending != "":
		if _wait > 0:
			_wait -= 1
			return false
		var path := "res://smoke_test_output/talk_%02d_%s.png" % [_n, _pending]
		root.get_texture().get_image().save_png(path)
		# Video memory is the budget for this room's exhibits, not frame time.
		print("saved %s   video memory %.0f MB" % [path.get_file(),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
		_n += 1
		_pending = ""
		return false

	var act: int = int(_show.call("current_act"))
	var phase: float = float(_show.get("_phase"))
	if act >= 0 and act < 5:
		var span: float = float(_show.call("_length", act))
		for beat in ONE:
			if int(beat[0]) == act and phase >= span * float(beat[1]) and not _seen.has(beat[2]):
				_seen[beat[2]] = true
				_pending = beat[2]
				_wait = 2
				return false
	if bool(_two.call("is_running")):
		var moment: int = int(_two.call("current_moment"))
		var tphase: float = float(_two.get("_phase"))
		var tspan: float = float(_two.call("_length", moment))
		for beat in TWO:
			if int(beat[0]) == moment and tphase >= tspan * float(beat[1]) and not _seen.has(beat[2]):
				_seen[beat[2]] = true
				_pending = beat[2]
				_wait = 2
				return false
	if _seen.has("viii_walk") or _f > 60000:
		print("%d pictures" % _n)
		quit()
		return true
	return false
