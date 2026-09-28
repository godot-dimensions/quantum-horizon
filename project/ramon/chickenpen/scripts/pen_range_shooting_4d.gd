extends Node

## Shooting at the boards down the range by Trym's shed (Ramon, 28 Sept: "give the shooting
## range very basic functionality"). Stand at the counter: a sight comes up in the middle
## of the screen, the left button fires down it, and a board that is hit tips over
## backwards and stands up again a few seconds later. A tally of shots and hits sits at
## the top of the screen while you are at the counter.
##
## A RAY AGAINST FOUR BOXES, NOT PHYSICS. Each board's face is a box in its own frame, so a
## shot is a ray-box test in four dimensions (the slab test, one axis at a time) against
## each standing board, nearest wins. No colliders to keep in step with a board that is
## swinging, and nothing else in the pen can be hit by accident.
##
## ONLY WHAT YOU CAN SEE. The shot goes straight down the camera's view, and the view lies
## in the slice you are looking through, so a board on another slice cannot be hit until
## the slice is turned to it - the same rule the gallery the range master sends you to is
## built on.
##
## THE PICKAXE STANDS DOWN AT THE COUNTER. Both answer the same button; the player carries
## meta "at_firing_line" while there, and pen_pickaxe_4d.gd will not swing while it is set.
## A carried chicken wins over both: the button puts it down (chicken_catcher_4d.gd).
##
## THE CAMERA COMES OVER YOUR SHOULDER there (pen_orbit_rig_4d.gd, set_aiming): from the
## usual distance behind, the middle of the screen is the back of your own head.
##
## THE SOUNDS ARE MADE HERE. The project has no gunshot, so the crack and the knock of a
## hit board are synthesized once when the pen opens: a burst of noise that dies in a few
## hundredths of a second over a low thump, and two damped tones for the wood.

const Booth := preload("res://ramon/chickenpen/scripts/pen_range_booth_4d.gd")
const DING := preload("res://ramon/chickenpen/audio/sfx/Ni Sound - Soft UI - Digital Button Select.wav")

@export var booth_path: NodePath = NodePath("../../World/RangeBooth")
@export var player_path: NodePath = NodePath("../../Player")
@export var camera_path: NodePath = NodePath("../../Player/CameraRig/Pitch/Camera4D")
@export var catcher_path: NodePath = NodePath("../../Player/Catcher")
@export var rig_path: NodePath = NodePath("../../Player/CameraRig")
## How far back from the counter still counts as standing at it.
@export_range(0.5, 3.0, 0.05) var line_depth: float = 1.4
## How long a board that is hit stays down.
@export_range(0.5, 10.0, 0.1) var down_seconds: float = 2.5
## Nothing further off than this is hit.
@export_range(10.0, 200.0, 1.0) var reach: float = 60.0
@export_range(-30.0, 6.0, 0.5) var shot_volume_db: float = -4.0

var shots := 0
var hits := 0
var bulls := 0

var _booth: Node4D
var _player: Node4D
var _camera: Camera4D
var _catcher: Node
var _rig: Node
## Per board: seconds left lying down (0 standing), and its tilt now, in radians.
var _down: PackedFloat32Array = []
var _tilt: PackedFloat32Array = []
var _at_line := false
var _hud: CanvasLayer
var _sight: Label
var _tally: Label
var _call: Label
var _call_left := 0.0
var _shot_sound: AudioStreamPlayer
var _knock_sound: AudioStreamPlayer
var _ding_sound: AudioStreamPlayer

## How far a board tips back when it is hit, and how fast it goes over and comes back up.
const DOWN_TILT := 1.35
const FALL_SPEED := 9.0
const RISE_SPEED := 2.6


func _ready() -> void:
	_booth = get_node_or_null(booth_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	_camera = get_node_or_null(camera_path) as Camera4D
	_catcher = get_node_or_null(catcher_path)
	_rig = get_node_or_null(rig_path)
	_build_hud()
	_shot_sound = _player_for(_crack(), shot_volume_db)
	_knock_sound = _player_for(_knock(), -6.0)
	_ding_sound = _player_for(DING, -8.0)


func _boards() -> Array[Node4D]:
	if _booth == null:
		return []
	return _booth.get("board_nodes")


func _process(delta: float) -> void:
	if _booth == null or _player == null:
		return
	var boards: Array[Node4D] = _boards()
	if _down.size() != boards.size():
		_down.resize(boards.size())
		_tilt.resize(boards.size())
		_down.fill(0.0)
		_tilt.fill(0.0)
	for i in boards.size():
		if _down[i] > 0.0:
			_down[i] = maxf(_down[i] - delta, 0.0)
			_tilt[i] = move_toward(_tilt[i], DOWN_TILT, FALL_SPEED * delta)
		else:
			_tilt[i] = move_toward(_tilt[i], 0.0, RISE_SPEED * delta)
		# Tipping +y toward -x: over backwards, away from the counter.
		boards[i].basis = Basis4D.from_xy(_tilt[i])
	var at: bool = at_firing_line()
	if at != _at_line:
		_at_line = at
		_player.set_meta(&"at_firing_line", at)
		if _rig != null and _rig.has_method("set_aiming"):
			_rig.call("set_aiming", at)
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_hud.visible = at
	_sight.visible = at and captured
	_tally.text = "RANGE    shots %d    hits %d    bull's-eyes %d" % [shots, hits, bulls] if shots > 0 else "RANGE    left click to shoot the boards"
	if _call_left > 0.0:
		_call_left = maxf(_call_left - delta, 0.0)
		_call.modulate.a = clampf(_call_left / 0.4, 0.0, 1.0)
	_call.visible = at and _call_left > 0.0


## Standing behind the counter, in the booth, on the booth's own slice.
func at_firing_line() -> bool:
	if _booth == null or _player == null or not _player.is_inside_tree():
		return false
	var local: Vector4 = _booth.global_basis.inverse() * (_player.global_position - _booth.global_position)
	var counter_back: float = -Booth.HALF.x + 0.3 + 0.225
	return local.x > counter_back - 0.2 and local.x < counter_back + line_depth \
		and absf(local.z) < Booth.HALF.y - 0.1 and absf(local.w) < Booth.HALF.z - 0.1 \
		and local.y > -0.5 and local.y < 2.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"fire") or not _at_line:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _camera == null:
		return
	if _catcher != null and _catcher.get("carried") != null:
		return
	var forward: Vector4 = (_camera.global_basis * Vector4(0.0, 0.0, -1.0, 0.0)).normalized()
	shoot(_camera.global_position, forward)
	get_viewport().set_input_as_handled()


## Fires from [param from] along [param direction] (need not be unit length). Returns which
## board was hit, or -1. Public so the test can aim without a mouse.
func shoot(from: Vector4, direction: Vector4) -> int:
	shots += 1
	_shot_sound.play()
	var dir: Vector4 = direction.normalized()
	var best := -1
	var best_t := reach
	var best_local := Vector4.ZERO
	var boards: Array[Node4D] = _boards()
	for i in boards.size():
		if _down[i] > 0.0 or _tilt[i] > 0.2:
			continue
		var board: Node4D = boards[i]
		var inv: Projection = board.global_basis.inverse()
		var o: Vector4 = inv * (from - board.global_position)
		var d: Vector4 = inv * dir
		var t: float = _ray_box(o, d, Booth.FACE[0], Booth.FACE[1] * 0.5)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = i
			best_local = o + d * t
	if best < 0:
		_say("Miss")
		return -1
	hits += 1
	_down[best] = down_seconds
	var off: Vector4 = best_local - Booth.FACE[0]
	var out: float = maxf(absf(off.y), maxf(absf(off.z), absf(off.w)))
	if out <= Booth.BULL_HALF:
		bulls += 1
		_ding_sound.play()
		_say("Bull's-eye!")
	elif out <= Booth.INNER_HALF:
		_say("Close")
	elif out <= Booth.RING_HALF:
		_say("On the red")
	else:
		_say("Hit")
	_knock_sound.play()
	return best


## Where along the ray [param o] + t [param d] it first meets the box at [param centre] with
## half-size [param half], or -1. The slab test: on each axis the ray is inside the box
## between two values of t, and it is inside the box where all four overlap.
static func _ray_box(o: Vector4, d: Vector4, centre: Vector4, half: Vector4) -> float:
	var t_in := -INF
	var t_out := INF
	for axis in 4:
		var lo: float = centre[axis] - half[axis]
		var hi: float = centre[axis] + half[axis]
		if absf(d[axis]) < 1e-9:
			if o[axis] < lo or o[axis] > hi:
				return -1.0
			continue
		var t0: float = (lo - o[axis]) / d[axis]
		var t1: float = (hi - o[axis]) / d[axis]
		t_in = maxf(t_in, minf(t0, t1))
		t_out = minf(t_out, maxf(t0, t1))
	if t_out < maxf(t_in, 0.0):
		return -1.0
	return maxf(t_in, 0.0)


func _say(text: String) -> void:
	_call.text = text
	_call_left = 1.2


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "RangeHud"
	_hud.layer = 5
	_hud.visible = false
	add_child(_hud)
	_sight = _label("+", 40, Control.PRESET_CENTER)
	# Under the sight, not at the top of the screen, where the pen's own panels are.
	_call = _label("", 30, Control.PRESET_CENTER)
	_call.position.y += 54.0
	_tally = _label("", 22, Control.PRESET_CENTER)
	_tally.position.y += 100.0


func _label(text: String, size: int, preset: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.97, 0.9))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override(&"outline_size", 6)
	_hud.add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	return label


func _player_for(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.max_polyphony = 3
	add_child(p)
	return p


## A rifle shot: a crack of noise gone in about 20 ms, over a thump at 70 Hz, with a short
## rough tail for the range.
static func _crack() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1999
	var smooth := [0.0]
	return _synth(0.45, func(t: float) -> float:
		var n: float = rng.randf_range(-1.0, 1.0)
		smooth[0] = lerpf(smooth[0], n, 0.18)
		var crack: float = n * exp(-t / 0.012)
		var thump: float = sin(TAU * 70.0 * t) * exp(-t / 0.07) * 0.7
		var tail: float = smooth[0] * exp(-t / 0.16) * 0.5
		return (crack + thump + tail) * 0.9)


## A hit board: two damped tones, a knock on wood.
static func _knock() -> AudioStreamWAV:
	return _synth(0.18, func(t: float) -> float:
		return (sin(TAU * 610.0 * t) * exp(-t / 0.028) + 0.5 * sin(TAU * 1240.0 * t) * exp(-t / 0.012)) * 0.7)


static func _synth(seconds: float, sample: Callable) -> AudioStreamWAV:
	var rate := 22050
	var n: int = int(seconds * float(rate))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = clampf(float(sample.call(float(i) / float(rate))), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s
