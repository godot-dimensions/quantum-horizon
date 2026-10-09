extends Node

## The open world's flight: you take off from the deck's helm as a bird and fly from its eyes (Ramon,
## 9 Oct: "rather just fly as a bird or something and have a collision so its limited in a circle of
## flying, and you can rotate the slice while flying").
##
## THE LOOKOUT'S HAWK, CARRIED AS A FEEL (chickenpen/lookout/hawk_flight_4d.gd, not touched, nothing
## preloaded from it): its flight model, its first person view ("you can just spawn in its eyes, no
## need to see the hawk", 2 Oct), rolled into the turns and wider with speed. Slower here: the circle is
## some fifty metres across, not the pen's four hundred.
##   mouse        steer: turn and climb
##   W / S        flap (faster), brake
##   Space        climb
##   Shift        fold the wings: the stoop, as fast as the dive is steep
##   right drag   turn the slice through W (the pen's rotate_4d), up to `slice_limit` degrees
##   R            the slice back to flat
##   Q / E        through W, kata and ana, along the slice's own normal
##
## THE FRAME IS THE PEN'S. Heading and slice are one rotation of the floor's (x, z, w) space, the
## carried GroundBasis (`frame`), pitch and bank on top: turning never re-cuts the world, only the
## slice drag does, exactly as walking in the pen.
##
## WHERE IT MAY GO. The field's world is built once, round the deck, behind the loading board, and never
## streams while you fly (Ramon, 9 Oct: "how it builds as you're moving, is that correct?"). So the
## flight is kept inside it: a circle of `circle` metres round `centre` (from five metres in it turns you
## back, gently, and the field shows its edge as a hologram), W within `w_limit`, above the ground
## (`ground`, the field's height map read off the built meshes, since the voxels have no collision) and
## the sea, and under `ceiling`.
##
## NO class_name (engine_gotchas.md).

const Ground := preload("res://ramon/VoxelLab/carried/LabKit/carried/chickenpen/scripts/ground_basis_4d.gd")
const G := 9.81

@export_range(1.0, 20.0, 0.5, "suffix:m/s") var cruise_speed: float = 4.5
@export_range(1.0, 30.0, 0.5, "suffix:m/s") var flap_speed: float = 7.5
@export_range(0.5, 10.0, 0.1, "suffix:m/s") var slow_speed: float = 2.2
@export_range(4.0, 40.0, 0.5, "suffix:m/s") var stoop_speed: float = 13.0
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity: float = 0.0028
@export_range(0.2, 6.0, 0.1, "suffix:m/s") var w_speed: float = 1.5
@export_range(0.5, 6.0, 0.1, "suffix:m") var clearance: float = 1.6
@export_range(0.0, 1.0, 0.05) var roll_with_bank: float = 0.6
## How far the slice may turn, degrees: the world is built 16 m either side of W 0, and a slice turned
## further than this runs out of it within sight.
@export_range(0.0, 90.0, 1.0) var slice_limit: float = 30.0
## Seconds from the walker's view into the bird's eyes.
@export var take_off_seconds: float = 0.9

## Set by the field before start().
var centre: Vector4
var circle: float = 26.0
var w_limit: float = 6.0
var ceiling: float = 46.0
var sea_level: float = 1.1
## The field: ground_at(x, z, w) -> float, the top of the land there.
var field: Node
var camera: Camera4D

var flying: bool = false
var at: Vector4
## Heading and slice: a level frame (GroundBasis); pitch and bank on top of it.
var frame: Projection = Projection.IDENTITY
var pitch: float = 0.0
var speed: float = 4.5
var bank: float = 0.0
var flapping: float = 0.0
var stooping: bool = false
## Runners steer with this instead of the mouse and keys: {"turn": rad/s, "climb": bool, "flap": bool,
## "slice": Vector2 rad/s, "w": -1 to 1, "pitch": target radians}. Empty: you steer.
var drive: Dictionary = {}

var _turn := Vector2.ZERO
var _slice := Vector2.ZERO
var _yaw_rate: float = 0.0
var _homing: float = 0.0
var _t: float = 0.0
var _from_pos: Vector4
var _from_basis: Projection


func start(from_cam: Camera4D, launch: Vector4, facing: Projection) -> void:
	flying = true
	_t = 0.0
	at = launch
	frame = Ground.cleaned(facing)
	pitch = 0.12
	speed = cruise_speed
	bank = 0.0
	_homing = 0.0
	_from_pos = from_cam.global_position
	_from_basis = from_cam.global_basis
	camera.global_position = _from_pos
	camera.global_basis = _from_basis
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func stop() -> void:
	flying = false
	drive = {}


## How far the slice is turned, degrees.
func slice_degrees() -> float:
	return rad_to_deg(Ground.tilt(frame))


func heading() -> Vector4:
	return frame * Vector4(0.0, sin(pitch), -cos(pitch), 0.0)


func _input(event: InputEvent) -> void:
	if not flying:
		return
	var mm := event as InputEventMouseMotion
	if mm != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_pressed(&"rotate_4d"):
			_slice += mm.relative * mouse_sensitivity
		else:
			_turn += mm.relative * mouse_sensitivity
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_R and not Input.is_key_pressed(KEY_CTRL):
		_homing = 0.6
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not flying:
		return
	_t += delta
	var dt: float = minf(delta, 1.0 / 20.0)
	var auto: bool = not drive.is_empty()
	var turn: Vector2 = _turn
	var slice: Vector2 = _slice
	_turn = Vector2.ZERO
	_slice = Vector2.ZERO
	if auto:
		turn = Vector2(float(drive.get("turn", 0.0)) * dt, 0.0)
		slice = (drive.get("slice", Vector2.ZERO) as Vector2) * dt
		if drive.has("pitch"):
			pitch = lerpf(pitch, float(drive["pitch"]), clampf(dt * 2.0, 0.0, 1.0))
	# Steering: the mouse turns (a turn in place of the frame) and climbs; the turn rate banks it.
	frame = Ground.looked(frame, Vector2(turn.x, 0.0))
	stooping = not auto and Input.is_key_pressed(KEY_SHIFT)
	pitch = clampf(pitch - turn.y, -1.4 if stooping else -1.0, 0.9)
	_yaw_rate = lerpf(_yaw_rate, -turn.x / maxf(dt, 0.0001), clampf(dt * 6.0, 0.0, 1.0))
	bank = lerpf(bank, clampf(atan(_yaw_rate * speed / G), -1.1, 1.1), clampf(dt * 4.0, 0.0, 1.0))
	# The slice: the right drag tilts it, never past the limit; R takes it home, keeping the heading.
	if slice != Vector2.ZERO:
		_homing = 0.0
		var tilted: Projection = Ground.sliced(frame, slice)
		if rad_to_deg(Ground.tilt(tilted)) <= slice_limit or Ground.tilt(tilted) < Ground.tilt(frame):
			frame = tilted
	if _homing > 0.0:
		var step: float = clampf(dt / maxf(_homing, 0.0001), 0.0, 1.0)
		frame = Ground.eased_flat(frame, step)
		_homing = maxf(_homing - dt, 0.0)
		if _homing <= 0.0:
			frame = Ground.flattened(frame)
	frame = Ground.cleaned(frame)
	# Speed: a target from the keys, gravity along the path added in (a climb bleeds speed, a dive
	# builds it), as the Lookout's hawk.
	var flap_key: bool = bool(drive.get("flap", false)) if auto else Input.is_key_pressed(KEY_W)
	var brake: bool = false if auto else Input.is_key_pressed(KEY_S)
	var climb: bool = bool(drive.get("climb", false)) if auto else Input.is_key_pressed(KEY_SPACE)
	var target: float = cruise_speed
	if flap_key:
		target = flap_speed
	if brake:
		target = slow_speed
	if stooping:
		target = lerpf(cruise_speed, stoop_speed, clampf(-sin(pitch) * 1.4, 0.0, 1.0))
	speed += (target - speed) * (0.5 if stooping else 1.1) * dt - G * sin(pitch) * 0.35 * dt
	speed = clampf(speed, slow_speed * 0.8, stoop_speed + 3.0)
	var want_flap: float = 0.0
	if not stooping:
		want_flap = 1.0 if (flap_key or climb) else (0.6 if speed < cruise_speed - 0.5 or pitch > 0.25 else 0.0)
	flapping = lerpf(flapping, want_flap, clampf(dt * 5.0, 0.0, 1.0))
	at += heading() * (speed * dt)
	if climb and not stooping:
		at.y += 2.6 * dt
	# Through W along the slice's own normal (the pen's ana and kata).
	var w_in: float = float(drive.get("w", 0.0)) if auto else float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	at += frame.w * (w_in * w_speed * dt)
	_keep_in(dt)
	_place_camera(dt)


## The circle, the band of W, the ground and the sea, the ceiling.
func _keep_in(dt: float) -> void:
	var off := Vector2(at.x - centre.x, at.z - centre.z)
	var d: float = off.length()
	var soft: float = circle - 5.0
	if d > soft and d > 0.001:
		# Turned back toward the middle, the harder the nearer the edge.
		var k: float = clampf((d - soft) / 5.0, 0.0, 1.0)
		var inward := Vector4(-off.x / d, 0.0, -off.y / d, 0.0)
		frame = Ground.faced(frame, inward, clampf(dt * (0.6 + 2.4 * k), 0.0, 1.0))
	if d > circle:
		at.x = centre.x + off.x / d * circle
		at.z = centre.z + off.y / d * circle
	at.w = clampf(at.w, centre.w - w_limit, centre.w + w_limit)
	var floor_y: float = maxf(sea_level, float(field.call("ground_at", at.x, at.z, at.w)) if field != null else sea_level) + clearance
	if at.y < floor_y:
		at.y = floor_y
		pitch = maxf(pitch, 0.05)
	if at.y > ceiling:
		at.y = ceiling
		pitch = minf(pitch, 0.0)


## The bird's eye, rolled into its turns, wider the faster; on take-off, eased in from the view you had.
func _place_camera(_dt: float) -> void:
	var eye: Vector4 = at + heading() * 0.14 + Vector4(0.0, 0.04, 0.0, 0.0)
	var basis: Projection = frame * Basis4D.from_yz(pitch) * Basis4D.from_xy(bank * roll_with_bank)
	var fast: float = clampf((speed - cruise_speed) / (stoop_speed - cruise_speed), 0.0, 1.0)
	var fov: float = lerpf(1.3, 1.6, fast)
	if _t < take_off_seconds:
		var k: float = smoothstep(0.0, 1.0, _t / take_off_seconds)
		camera.global_position = _from_pos.lerp(eye, k)
		camera.global_basis = _blend_basis(_from_basis, basis, k)
		camera.set("field_of_view_4d", lerpf(1.35, fov, k))
		return
	camera.global_position = eye
	camera.global_basis = basis
	camera.set("field_of_view_4d", fov)


func _blend_basis(a: Projection, b: Projection, k: float) -> Projection:
	var out := Projection(a.x.lerp(b.x, k), a.y.lerp(b.y, k), a.z.lerp(b.z, k), a.w.lerp(b.w, k))
	return Basis4D.orthonormalized(out)
