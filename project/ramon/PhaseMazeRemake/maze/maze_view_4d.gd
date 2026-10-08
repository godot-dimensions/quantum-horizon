extends Node

## How you see the maze (PLAN.md steps 34 to 43): the cameras, and the two things the maze adds on top
## of Andrew's walk and view (carried/walker/).
##
## THE CAMERAS. Third person by default (RESEARCH.md: the probe frames and the prior art agree), first
## person one key away.
##   chase     2.1 m up, 3.6 m back, 24 degrees down. In 6 m cells it shows the walker small and low with
##             the way ahead clear, where the pen's own camera was pushed into his back (probe frame 1).
##             When a wall pulls it in it tilts further down instead (Nesky, "50 Camera Mistakes" #14:
##             couple distance to pitch), and the walker is hidden when the camera is right behind him
##             (Valve fades its player the same way).
##   shoulder  the orbit rig's own over-the-shoulder framing (its aiming mode).
##   first     the arm wound in to eye height and the walker hidden (the pen's human test scene does it
##             the same way, chickenpen/scripts/real_character_4d.gd).
## V switches first and third person, Tab chase and shoulder.
##
## THE QUARTER TURN (F). The heading first snaps to the nearest corridor, then what is ahead swings into
## ana over 0.35 s (Miegakure's one button, animated; RESEARCH.md section 3). From a turned view F swings
## you back to level. While it swings, the walking keys do nothing, so they never change meaning half way
## (Nesky #18). Facing along x and pressing F shows z and W; facing along z, x and W.
##
## THE SETTLE. The right-mouse drag is Andrew's, free. Let go and the slice eases to the nearest slice
## square to the maze, keeping your heading: a half-turned view of a grid maze is slivers (probe frame 2;
## 4D Toys and 4D Golf stay on quarter turns for the same reason). The second probe measured it: from
## 23 degrees off, 0.12 s, exact (RESEARCH.md section 5). F1 switches it off.
##
## R LEVELS THE SLICE and keeps your W. The pen's R also walks you to W 0, which in a maze would walk
## you through walls.
##
## NO class_name (engine_gotchas.md).

const GB := preload("res://ramon/PhaseMazeRemake/carried/walker/ground_basis_4d.gd")

signal view_changed(hidden_axis: int)
signal turn_started(kind: String)

var body: CharacterBody4D
var rig: Node4D
var camera: Camera4D
var avatar: Node4D
## "chase", "shoulder" or "first".
var mode: String = "chase"
## The third-person framing V returns to.
var third: String = "chase"
var settle_on: bool = true
var turn_seconds: float = 0.35
## Radians a second the settle and R turn at.
var settle_rate: float = 5.0
var chase: Dictionary = {"distance": 3.6, "pivot": 2.1, "pitch": -24.0}
var first_eye: float = 1.15
## Below this camera distance the walker is hidden (third person).
var hide_within: float = 1.0
## How much further down the chase camera tilts when a wall has pulled it all the way in (degrees).
var tilt_when_pulled: float = 18.0
## Keys off (the console, the finish, runners).
var keys_on: bool = true
## Which world axis the view hides: 0 x, 1 z, 2 w (W when the slice is level).
var hidden_axis: int = 2

var _target: Variant = null
## Prints every eased frame (runners).
var debug_turns: bool = false
var _rate: float = 5.0
var _dragging: bool = false
var _swing_left: float = 0.0
var _extra: float = 0.0


func _ready() -> void:
	set_mode("chase", true)


func _unhandled_input(event: InputEvent) -> void:
	if not keys_on:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_V:
			set_mode(third if mode == "first" else "first")
		KEY_TAB:
			if mode != "first":
				set_mode("shoulder" if mode == "chase" else "chase")
		KEY_F:
			quarter_turn()
		KEY_R:
			if not Input.is_key_pressed(KEY_CTRL):
				level()
		_:
			return
	get_viewport().set_input_as_handled()


## Which way the view hides: the world axis its W column (the slice normal) lies along.
static func axis_hidden(b: Projection) -> int:
	var w: Vector4 = b.w
	var a := Vector3(absf(w.x), absf(w.z), absf(w.w))
	if a.z >= a.x and a.z >= a.y:
		return 2
	return 0 if a.x >= a.y else 1


## Whether the view is turned off level (by more than half a quarter).
func is_turned() -> bool:
	return axis_hidden(rig.basis) != 2


## Busy turning (F, the settle or R): the game holds some things until the view is square again.
func is_turning() -> bool:
	return _target != null


func set_mode(m: String, instant: bool = false) -> void:
	mode = m
	if m != "first":
		third = m
	var first: bool = m == "first"
	rig.set("collide_with_world", not first)
	rig.call("set_aiming", m == "shoulder")
	var dist: float = 0.01 if first else float(chase["distance"])
	var pivot: float = first_eye if first else float(chase["pivot"])
	rig.set("_zoom_target", dist)
	rig.set("_home_pivot", pivot)
	if instant:
		rig.set("distance", dist)
		rig.set("pivot_height", pivot)
	var pitch_deg: float = -4.0 if first else float(chase["pitch"])
	_extra = 0.0
	rig.set("pitch", deg_to_rad(pitch_deg))
	rig.call("_apply")
	if avatar != null:
		avatar.visible = not first


## F: from level, the heading snapped to the nearest corridor, then what is ahead swung into ana; from a
## turned view, back to level with the heading you have.
func quarter_turn() -> void:
	if _target != null:
		return
	var b: Projection = rig.basis
	if is_turned():
		_ease_to(GB.flattened(b), PI * 0.5 / turn_seconds, true, "level")
		return
	var h: float = GB.heading(b)
	var b0: Projection = Basis4D.from_zx(snappedf(h, PI * 0.5))
	# Forward is -z: the new frame's z is -(old w), so forward becomes old W (ana); its W is old z.
	var t := Projection(b0.x, GB.UP, -b0.w, b0.z)
	_ease_to(t, PI * 0.5 / turn_seconds, true, "into_w")


## R: the slice level again, your heading and your W kept.
func level() -> void:
	if _target != null and _swing_left > 0.0:
		return
	_ease_to(GB.flattened(rig.basis), settle_rate, false, "level")


## The drag let go: the slice normal onto the nearest world axis by the shortest turn, the heading kept.
func settle() -> void:
	var b3: Basis = GB._to_3d(rig.basis)
	var w3: Vector3 = b3.z
	var best := Vector3.ZERO
	var best_dot: float = -2.0
	for ax in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		for s in [-1.0, 1.0]:
			var d: float = w3.dot(ax * s)
			if d > best_dot:
				best_dot = d
				best = ax * s
	if best_dot > 0.99999:
		return
	var q := Quaternion(w3.normalized(), best)
	var t: Projection = GB._from_3d(Basis(q) * b3)
	_ease_to(GB.cleaned(t), settle_rate, false, "settle")


func _ease_to(t: Projection, rate: float, swing: bool, kind: String) -> void:
	_target = t
	_rate = rate
	if swing:
		_swing_left = turn_seconds + 0.05
		body.set("input_enabled", false)
	turn_started.emit(kind)


func _process(delta: float) -> void:
	if rig == null:
		return
	var dragging: bool = keys_on and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed(&"rotate_4d")
	if debug_turns and _target != null:
		print("VIEW: easing, %.1f deg left, dragging %s" % [rad_to_deg(_angle(rig.basis, _target)), str(dragging)])
	if dragging:
		_target = null
	elif _dragging and settle_on:
		settle()
	_dragging = dragging
	if _target != null:
		var t: Projection = _target
		var b: Projection = GB.rotated_toward(rig.basis, t, _rate * delta)
		rig.basis = b
		rig.call("_apply")
		if _angle(b, t) < 0.0005:
			rig.basis = t
			rig.call("_apply")
			_target = null
	if _swing_left > 0.0:
		_swing_left -= delta
		if _swing_left <= 0.0 or _target == null:
			_swing_left = 0.0
			body.set("input_enabled", true)
	var h: int = axis_hidden(rig.basis)
	if h != hidden_axis:
		hidden_axis = h
		view_changed.emit(h)
	_frame(delta)


## The chase camera's tilt as a wall pulls it in, and hiding the walker when the camera is on top of him.
func _frame(delta: float) -> void:
	var actual: float = absf(camera.position.z)
	var wanted: float = maxf(float(rig.get("distance")), 0.01)
	var want_extra: float = 0.0
	if mode == "chase":
		var pulled: float = clampf(1.0 - actual / wanted, 0.0, 1.0)
		want_extra = deg_to_rad(tilt_when_pulled) * pulled
	var new_extra: float = lerpf(_extra, want_extra, 1.0 - exp(-delta * 6.0))
	if absf(new_extra - _extra) > 0.0001:
		var user: float = float(rig.get("pitch")) + _extra
		var lo: float = deg_to_rad(float(rig.get("pitch_min_degrees")))
		var hi: float = deg_to_rad(float(rig.get("pitch_max_degrees")))
		rig.set("pitch", clampf(user - new_extra, lo, hi))
		rig.call("_apply")
		_extra = new_extra
	if avatar != null:
		avatar.visible = mode != "first" and actual > hide_within


static func _angle(a: Projection, b: Projection) -> float:
	var q: Quaternion = GB._to_3d(Basis4D.transposed(a) * b).get_rotation_quaternion()
	return 2.0 * acos(clampf(absf(q.w), 0.0, 1.0))


## The view's frame with any tilt taken out: the level heading (for the console and the HUD).
func level_basis() -> Projection:
	return GB.flattened(rig.basis)
