extends Camera4D
## Crosswise's camera: a diorama view of the little walker, and the quarter turn into W.
##
## A fork of ../../scripts/miegakure_camera_3.gd, keeping its two load-bearing fixes (follow_up/
## miegakure_look.md): the camera's position is derived from the SAME basis as its orientation, so
## the slice always passes through what it follows, and the turn is composed as (turn * tilt),
## never (tilt * turn), which reads as the whole world tumbling.
##
## THE TURN. A click of the right mouse button, or Tab, swaps which horizontal axis the view shows:
## Z (normal) or W (turned). It is a quarter turn in the Z-W plane about the walker, eased over
## `swap_seconds`; X and Y never change (Miegakure's rule: never the vertical, and one horizontal
## axis always stays). `turn_sign` picks which way: -1 makes "forward" after the turn walk ana
## (+W), so the W key walks into W. A press during a turn is remembered and played after it.
##
## THE DRAG (Ramon, 6 Oct: "yeah do the drag too"). Hold the right mouse button and drag sideways
## and the view turns smoothly by as much as you drag, anywhere between the two views, and stays
## where you let go: the slice in realtime, cutting walls and lanes on the diagonal. A click after a
## drag goes to the nearer of the two views. The walker's keys follow the angle (W/S walk the view's
## own depth axis), so you still only walk in what you see.
##
## THE SLICE STAYS ON HIM. The view follows a smoothed focus, but only within the slice: the
## focus's component along the slice's normal is snapped to the walker's every frame, or a lagging
## focus would slice half a metre beside him and cut him in half after a turn.
##
## THE OPENING SHOT. `start_intro()` begins high over the first island looking down the whole chain
## to the tower on the last (the destination you can see from the start: the weenie of
## follow_up/lab_case_study), and eases down onto the walker over `intro_seconds`; any key cuts it
## short. It is a normal-view camera all the way, so the slice stays at his W.
##
## FRAMING. `frame_center` (set per island by the game) pulls the focus a share of the way toward
## the island's middle, so the island fills the frame (Marc ten Bosch: a diorama that doesn't fill a
## large area hasn't enough to look at); a little look-ahead leads the way he walks.
##
## NO class_name (engine_gotchas.md).

signal turn_started(turned: bool)
signal turn_finished(turned: bool)

## The diorama's angles and lens (picked by eye in probe 9, PLAN.md).
@export_range(20.0, 85.0, 0.5) var pitch_degrees: float = 54.0
@export_range(-90.0, 90.0, 0.5) var yaw_degrees: float = 32.0
@export_range(4.0, 60.0, 0.1) var distance: float = 10.5
@export_range(8.0, 90.0, 0.5) var fov_degrees: float = 32.0
@export_range(0.2, 2.0, 0.05) var swap_seconds: float = 0.65
## -1: after the turn, forward walks toward +W (ana). +1: toward -W.
@export var turn_sign: float = -1.0
## How quickly the focus catches up with him, per second (in the slice only).
@export_range(0.5, 20.0, 0.1) var follow_rate: float = 5.0
## Share of the way toward `frame_center` the focus leans (0 follows him exactly).
@export_range(0.0, 0.9, 0.01) var frame_lean: float = 0.22
@export_range(0.0, 3.0, 0.05) var look_ahead: float = 0.9
## What it follows (a Node4D, normally the walker).
@export var target_path: NodePath
## The environment whose moods follow the turn (mk_env_4d.gd), optional.
@export var env_path: NodePath

@export_group("Opening shot")
@export var intro_seconds: float = 4.5
@export var intro_focus: Vector4 = Vector4(0, 0, -34, 0)
@export var intro_pitch: float = 24.0
@export var intro_yaw: float = 8.0
@export var intro_distance: float = 62.0

## Radians of turn per pixel of drag (about 260 px for the quarter turn), and how far the mouse must
## move with the button held before a press counts as a drag rather than a click.
@export var drag_rate: float = 0.006
@export var drag_start_px: float = 6.0

var frame_center: Vector4 = Vector4.ZERO
var _intro_t: float = -1.0
var frame_active: bool = false
## Set by the game while a cutscene owns the camera (the finale): the follow and input stop.
var locked: bool = false
var swaps: int = 0

var _target: Node4D
var _env: Node
var _look: Projection
var _angle: float = 0.0
var _from: float = 0.0
var _to: float = 0.0
var _t: float = 1.0
var _queued: bool = false
var _focus: Vector4 = Vector4.ZERO
var _focus_ready: bool = false
var _ahead: Vector4 = Vector4.ZERO
var _last_target: Vector4 = Vector4.ZERO
var _rmb_down: bool = false
var _dragging: bool = false
var _drag_px: float = 0.0


func _ready() -> void:
	current = true
	rendering_engine_name = "Cross-section"
	set_field_of_view_3d(deg_to_rad(fov_degrees))
	_target = get_node_or_null(target_path) as Node4D
	_env = get_node_or_null(env_path)
	_look = _look_basis(_direction(pitch_degrees, yaw_degrees))
	_update_transform(0.0)


## Re-reads the angles and lens (after a runner or a tuner changes them).
func refresh_lens() -> void:
	set_field_of_view_3d(deg_to_rad(fov_degrees))
	_look = _look_basis(_direction(pitch_degrees, yaw_degrees))


func start_intro() -> void:
	_intro_t = 0.0


func in_intro() -> bool:
	return _intro_t >= 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _intro_t >= 0.0:
		var fk := event as InputEventKey
		if fk != null and fk.keycode in [KEY_F1, KEY_F2]:
			return # the dev panel's keys pass through the opening shot
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			_intro_t = maxf(_intro_t, intro_seconds * 0.8)
			get_viewport().set_input_as_handled()
		return
	if locked:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_TAB:
		request_turn()
		get_viewport().set_input_as_handled()
		return
	# The right mouse button: a click turns a quarter, a drag turns by as much as you drag.
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed:
			_rmb_down = true
			_dragging = false
			_drag_px = 0.0
		else:
			if _rmb_down and not _dragging:
				request_turn()
			_rmb_down = false
			_dragging = false
		get_viewport().set_input_as_handled()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _rmb_down:
		_drag_px += absf(mm.relative.x)
		if not _dragging and _drag_px >= drag_start_px:
			_dragging = true
			_t = 1.0
			_queued = false
			turn_started.emit(true)
		if _dragging:
			# Drag right to turn toward the W view, left to turn back.
			drag_by(mm.relative.x * drag_rate * turn_sign)
		get_viewport().set_input_as_handled()


## Turn the view by `radians` at once (the drag), kept between the two views.
func drag_by(radians: float) -> void:
	var q: float = turn_sign * PI * 0.5
	_angle = clampf(_angle + radians, minf(0.0, q), maxf(0.0, q))
	_from = _angle
	_to = _angle
	_t = 1.0


## Swap the view (or queue one swap if a turn is already under way). From in between (after a drag)
## it goes to the nearer of the two views.
func request_turn() -> void:
	if is_turning():
		_queued = true
		return
	var q: float = turn_sign * PI * 0.5
	_from = _angle
	if absf(_angle) < 0.02:
		_to = q
	elif absf(_angle - q) < 0.02:
		_to = 0.0
	else:
		_to = q if absf(_angle - q) < absf(_angle) else 0.0
	_t = 0.0
	swaps += 1
	turn_started.emit(is_turned())


## Straight to a view with no animation (resets, runners).
func set_turned(turned: bool) -> void:
	_to = turn_sign * PI * 0.5 if turned else 0.0
	_from = _to
	_angle = _to
	_t = 1.0
	_queued = false
	_update_transform(0.0)


func is_turning() -> bool:
	return _t < 1.0


## True when the view shows W (or is heading there; past halfway, during a drag).
func is_turned() -> bool:
	return absf(sin(_to)) > 0.5


## True while the right mouse button is turning the view by hand.
func is_dragging() -> bool:
	return _dragging


## The view's quarter turn as an angle, radians (0 normal; turn_sign * PI/2 turned).
func slice_angle() -> float:
	return _angle


## 0 in the normal view, 1 turned, eased in between.
func turn_amount() -> float:
	return absf(sin(_angle))


## The rotation that carries the normal view's axes onto the current view's: the walker's body,
## the carried crate and the lights all turn by this.
func slice_rotation() -> Projection:
	return Basis4D.from_zw(_angle)


## The slice's normal in the world (the axis you cannot see right now).
func slice_normal() -> Vector4:
	return global_basis.w


## Jump the focus to the target (after a respawn), so the camera does not drift across the gap.
func snap_focus() -> void:
	_focus_ready = false
	_update_transform(0.0)


func _process(delta: float) -> void:
	if _intro_t >= 0.0:
		_intro_t += delta
		if _intro_t >= intro_seconds:
			_intro_t = -1.0
			_look = _look_basis(_direction(pitch_degrees, yaw_degrees))
	if _t < 1.0:
		_t = minf(_t + delta / maxf(swap_seconds, 0.01), 1.0)
		var e: float = _t * _t * (3.0 - 2.0 * _t)
		_angle = lerpf(_from, _to, e)
		if _t >= 1.0:
			_angle = _to
			turn_finished.emit(is_turned())
			if _queued:
				_queued = false
				request_turn()
	_update_transform(delta)


## The links, found when first needed: a node added to a running tree has its _ready before the
## caller can set its paths (found 6 Oct: the camera never followed, and its turned slice sat at z 0).
func _links() -> void:
	if _target == null and not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node4D
	if _env == null and not env_path.is_empty():
		_env = get_node_or_null(env_path)


func _update_transform(delta: float) -> void:
	_links()
	var turn := Basis4D.from_zw(_angle)
	global_basis = turn * _look
	var n: Vector4 = global_basis.w
	var aim: Vector4 = _target.global_position if _target != null else Vector4.ZERO
	if _target != null and not locked:
		var moved: Vector4 = aim - _last_target
		_last_target = aim
		if delta > 0.0:
			var v: Vector4 = moved / delta
			v.y = 0.0
			var want: Vector4 = v.normalized() * look_ahead if v.length() > 0.4 else Vector4.ZERO
			_ahead = _ahead.lerp(want, clampf(delta * 1.6, 0.0, 1.0))
		var goal: Vector4 = aim + _ahead
		if frame_active:
			var lean: Vector4 = frame_center - aim
			lean.y = 0.0
			goal += lean * frame_lean
		if not _focus_ready or delta <= 0.0:
			_focus = goal
			_focus_ready = true
		else:
			_focus = _focus.lerp(goal, clampf(delta * follow_rate, 0.0, 1.0))
		# In the slice only: the focus's height lags a little less (jumps), and its component
		# along the slice's normal is HIS, exactly, every frame.
		_focus += n * n.dot(aim - _focus)
	if _intro_t >= 0.0:
		# Ease from the opening shot's angles, distance and focus to the follow framing.
		# Held wide for the first quarter, then eased down.
		var k: float = clampf(_intro_t / maxf(intro_seconds, 0.01), 0.0, 1.0)
		var hold: float = clampf((k - 0.25) / 0.75, 0.0, 1.0)
		var e: float = hold * hold * (3.0 - 2.0 * hold)
		_look = _look_basis(_direction(lerpf(intro_pitch, pitch_degrees, e), lerpf(intro_yaw, yaw_degrees, e)))
		global_basis = Basis4D.from_zw(_angle) * _look
		var f: Vector4 = intro_focus.lerp(_focus, e)
		f.w = _focus.w
		global_position = f + global_basis * Vector4(0.0, 0.0, lerpf(intro_distance, distance, e), 0.0)
	elif not locked:
		global_position = _focus + global_basis * Vector4(0.0, 0.0, distance, 0.0)
	if _env != null and _env.has_method("set_turn"):
		_env.call("set_turn", turn_amount(), turn)


## The focus point (the middle of the frame), for the HUD and runners.
func focus() -> Vector4:
	return _focus


static func _direction(pitch: float, yaw: float) -> Vector4:
	var p := deg_to_rad(pitch)
	var y := deg_to_rad(yaw)
	var horizontal := cos(p)
	return Vector4(sin(y) * horizontal, sin(p), cos(y) * horizontal, 0.0)


## A fixed orthonormal basis whose local +Z points back along `direction` (toward the camera), the
## v3 camera's Gram-Schmidt construction.
static func _look_basis(direction: Vector4) -> Projection:
	var z_axis := direction.normalized()
	var world_up := Vector4(0.0, 1.0, 0.0, 0.0)
	var y_axis := (world_up - z_axis * z_axis.dot(world_up)).normalized()
	var world_x := Vector4(1.0, 0.0, 0.0, 0.0)
	var x_axis := (world_x - z_axis * z_axis.dot(world_x) - y_axis * y_axis.dot(world_x)).normalized()
	return Projection(x_axis, y_axis, z_axis, Vector4(0.0, 0.0, 0.0, 1.0))
