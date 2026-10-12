extends SceneTree

## BOTANY LAB, round 3 (section 9, step 64): the walk as a film, played beats (the dev logs' style: a
## human-like operator, the loading cut). The runner holds the walk key and eases the camera's turn
## toward each next point, as the pen's walk film does (chickenpen/grass/_film_walk_runner.gd). No HUD.
## Recorded by the movie writer at a fixed 30 fps; prints the film time each beat starts at, so the
## loading board can be cut (ffmpeg -ss).
##
##   -- hall      the hall: down its middle, across to the border, a planter turned through W, on to the
##                flower room's door and through it (the film ends on the flash)
##   -- flowers   the flower room: in from the door, round its walls from the middle, up to a pocket, the
##                flowers turned through W and back, a gust

const HALL := "res://ramon/Arboretum/botany_lab.tscn"
const FLOWERS := "res://ramon/Arboretum/botany_lab/flowers/flower_room.tscn"
const FPS := 30.0

var _room: Node
var _player: Node4D
var _rig: Node
var _which: String = "hall"
var _t: float = 0.0
var _beat: int = -1
var _bt: float = 0.0
var _started: bool = false
var _film_t: float = 0.0
var _yaw_target: float = 0.0
var _walking: bool = false
var _done_t: float = -1.0


func _initialize() -> void:
	root.unfocusable = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_which = "flowers" if "flowers" in args else "hall"
	_room = (load(FLOWERS if _which == "flowers" else HALL) as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room


func _ready_to_film() -> bool:
	if _which == "flowers":
		return bool(_room.call("ready_to_visit")) and _room.get("_board") == null
	return _t > 3.0


func _set_up() -> void:
	_player = _room.get("player") as Node4D
	_rig = _player.get_node_or_null("CameraRig")
	_player.set("input_enabled", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for layer in _room.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var w: Node = _room.get_node_or_null("Wind")
	if w != null:
		w.set("gust_every", 0.0)
	if _which == "flowers":
		_place(Vector4(0.0, 0.05, 5.4, 0.0), 0.0, -0.12, 3.2)
	else:
		_place(Vector4(0.0, 0.05, 15.6, 0.0), 0.0, -0.1, 5.0)


func _place(at: Vector4, yaw: float, pitch: float, dist: float) -> void:
	_room.call("go_to", at, yaw)
	_yaw_target = yaw
	if _rig != null:
		_rig.set("pitch", pitch)
		_rig.set("distance", dist)
		_rig.set("_zoom_target", dist)
		_rig.call("_apply")


func _walk(on: bool) -> void:
	if on == _walking:
		return
	_walking = on
	if on:
		Input.action_press(&"move_forward")
	else:
		Input.action_release(&"move_forward")


## Ease the camera's yaw toward the target, the operator's hand: a little lag, no snap.
func _steer(d: float, rate: float = 1.6) -> void:
	if _rig == null:
		return
	var y: float = float(_rig.get("yaw"))
	_rig.set("yaw", lerp_angle(y, _yaw_target, clampf(d * rate, 0.0, 1.0)))
	_rig.call("_apply")


func _toward(x: float, z: float) -> void:
	var p: Vector4 = _player.global_position
	_yaw_target = atan2(-(x - p.x), -(z - p.z))


func _pitch_to(v: float, d: float, rate: float = 1.0) -> void:
	if _rig != null:
		_rig.set("pitch", lerpf(float(_rig.get("pitch")), v, clampf(d * rate, 0.0, 1.0)))
		_rig.call("_apply")


func _next() -> void:
	_beat += 1
	_bt = 0.0
	print("FILM beat %d at %.2f s" % [_beat, _film_t])


func _process(d: float) -> bool:
	_t += d
	if not _started:
		if _t > 90.0:
			print("FILM FAIL: never ready")
			return true
		if _ready_to_film():
			_started = true
			_set_up()
			print("FILM starts at %.2f s (cut the board before this)" % _t)
			_next()
		return false
	_film_t += d
	_bt += d
	if _done_t >= 0.0:
		_walk(false)
		if _film_t - _done_t > 1.2:
			print("FILM done at %.2f s" % _film_t)
			return true
		return false
	if _which == "hall":
		_hall(d)
	else:
		_flowers(d)
	return false


func _hall(d: float) -> void:
	var p: Vector4 = _player.global_position
	match _beat:
		0:
			# Down the middle toward the oak, the leaves coming toward you.
			_walk(true)
			_toward(0.0, -6.0)
			_steer(d, 1.0)
			_pitch_to(-0.06, d, 0.5)
			if p.z < 9.0:
				_next()
		1:
			# Across to the border, then down it.
			_toward(5.4, 6.0)
			_steer(d, 1.2)
			if Vector2(p.x - 5.4, p.z - 6.0).length() < 1.2 or _bt > 7.0:
				_next()
		2:
			_toward(5.4, 2.0)
			_steer(d, 1.4)
			_pitch_to(-0.22, d, 1.0)
			if p.z < 3.4 or _bt > 5.0:
				_walk(false)
				_next()
		3:
			# Stop, face the planter, turn its flowers through W and back.
			_yaw_target = -PI * 0.5
			_steer(d, 2.0)
			var border: Node = _room.get_node_or_null("Border")
			if border != null and _bt > 0.8:
				var k: float = clampf((_bt - 0.8) / 3.0, 0.0, 1.0)
				# (Round 5: the flowers tip through W now, bl_border_4d.gd.)
				var want: float = sin(k * PI) * 0.6
				var have: float = float(border.get("tip"))
				border.call("turn_by", (want - have) * 0.25 / 0.7, 0.0)
			if _bt > 4.6:
				if border != null:
					border.call("level")
				_next()
		4:
			# On to the flower room's door, and through it.
			_walk(true)
			_pitch_to(-0.08, d, 1.0)
			_toward(14.2, -3.0)
			_steer(d, 1.6)
			if bool(_room.get("_leaving")):
				_done_t = _film_t


func _flowers(d: float) -> void:
	var p: Vector4 = _player.global_position
	match _beat:
		0:
			# In to the middle, the north wall ahead.
			_walk(true)
			_toward(0.0, -2.0)
			_steer(d, 1.0)
			if p.z < 0.4:
				_walk(false)
				_next()
		1:
			# Round the walls, slowly: a half turn to the left and back.
			var k: float = clampf(_bt / 7.0, 0.0, 1.0)
			_yaw_target = sin(k * PI) * PI * 0.55
			_steer(d, 2.0)
			_pitch_to(0.02, d, 0.6)
			if _bt > 7.2:
				_next()
		2:
			# Up to a pocket on the north wall.
			_walk(true)
			_toward(-1.2, -6.6)
			_steer(d, 1.4)
			_pitch_to(0.06, d, 0.8)
			if p.z < -5.8 or _bt > 6.0:
				_walk(false)
				_next()
		3:
			# Every flower turned through W, held, and back; the pockets stay.
			_yaw_target = 0.0
			_steer(d, 2.0)
			var k: float = clampf(_bt / 5.0, 0.0, 1.0)
			var target: float = sin(k * PI) * deg_to_rad(75.0)
			var tb: Projection = _room.get("turn_basis")
			var have: float = acos(clampf(tb.w.w, -1.0, 1.0))
			_room.call("turn_by", (target - have) * 0.3, 0.0)
			if _bt > 5.3:
				_room.call("level")
				_next()
		4:
			# Back a little, and a gust.
			if _bt < 0.05:
				_room.call("gust")
			_pitch_to(-0.04, d, 0.6)
			if _bt > 5.0:
				_done_t = _film_t
