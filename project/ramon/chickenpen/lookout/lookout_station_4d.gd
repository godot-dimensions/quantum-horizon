extends Node

## The camera at the Lookout: the climb, the hide's windows, and the camera in your hands.
##
## A STATION, NOT A ROOM TO WALK ROUND. In a real hide you sit still at the slot and wait;
## walking about is what scares everything off. So up here you do not walk: you stand at
## whichever window you look out of (the eye leans to it, LEAN), turn, zoom and focus. It
## is also what keeps this cheap and solid - no body to collide with a 4 m cab in 4D.
##
## THE FOCUS RING IS THE 4D IDEA. It does not focus in depth. E and Q - the keys that step
## you ana and kata on foot - slide the camera's slice along its own W, up to
## [member focus_range] either way, without moving you. A 4D body off your slice shows a
## smaller cross-section, and none at all past its own W radius, so pulling focus is finding
## a thing in W: the owl outside the north window is there only at w +1.5. T is autofocus:
## it pulls to whatever is nearest the middle of the frame.
##
## THE SLICE TURN IS THE PEN'S OWN: hold the right button and move the mouse to tilt the
## slice through W (xw and zw, outermost, so looking round never re-cuts the world - the
## orbit rig's header explains why); R straightens it and brings the focus home.
##
## THE SHUTTER IS STATE, NOT PIXELS. On the press, the judge (photo_judge_4d.gd) reads who is
## in frame, how big, how central, how sharp in W and what they are doing, from the game's
## own state - Pokemon Snap's way. The picture itself is grabbed the next frame with the
## viewfinder hidden, so the photo is the view, not the overlay; the overlay then plays the
## mirror's blackout. A roll is [member roll] shots; in the cab an empty roll reloads itself
## on a 1.2 s winder.
##
## IT BORROWS THE PEN AS THE CINEMATIC DOES: the player frozen and hidden at the ladder's
## foot, the HUD put away, its own Camera4D standing in the world (a camera parented to
## nothing that moves cannot be dragged anywhere - pen_npc_talk_4d.gd's header). The farm's
## sounds keep playing: you are still there.

signal mode_changed(mode: int)
signal shot(photo: Dictionary)

enum Mode { OFF, CLIMB_UP, CAB, CLIMB_DOWN, RIDE }

const VIEWFINDER := preload("res://ramon/chickenpen/lookout/lookout_viewfinder_4d.gd")

@export_group("Climb")
@export_range(0.5, 10.0, 0.1, "suffix:s") var climb_seconds: float = 3.4
@export_range(0.5, 10.0, 0.1, "suffix:s") var down_seconds: float = 2.2
## How high the eye stands above the cab floor.
@export_range(1.0, 2.0, 0.01, "suffix:m") var eye_height: float = 1.55
## How close to the window you face the eye leans: this far inside the wall.
@export_range(0.1, 1.5, 0.01, "suffix:m") var lean_gap: float = 0.33

@export_group("Lens")
## The widest the lens goes, vertical field of view.
##
## SET AS field_of_view_4d, NOT field_of_view_3d: a Camera4D's projection type defaults to
## PERSPECTIVE_4D, and then the cross-section renderer's 3D camera takes its angle from the
## 4D field of view (godot_3d_rendering_engine_4d.cpp _update_3d_camera) - the 3D one is
## ignored. The pen's own camera sets only the 3D one, so it actually draws at the 4D
## default, 77 degrees.
@export_range(0.3, 1.6, 0.01) var wide_fov: float = 1.15
@export_range(1.0, 20.0, 0.1) var zoom_max: float = 12.0
## One wheel notch.
@export_range(1.02, 1.6, 0.01) var zoom_step: float = 1.18
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity: float = 0.0032
@export_range(-1.5, 0.0, 0.01) var pitch_min: float = -1.15
@export_range(0.0, 1.5, 0.01) var pitch_max: float = 0.95

@export_group("Focus")
@export_range(0.5, 6.0, 0.1, "suffix:m") var focus_range: float = 3.0
@export_range(0.1, 6.0, 0.05, "suffix:m/s") var focus_speed: float = 1.2
## Shift held: the fine ring.
@export_range(0.05, 1.0, 0.05) var focus_fine: float = 0.25

@export_group("Film")
@export_range(1, 72) var roll: int = 24
@export_range(0.2, 4.0, 0.1, "suffix:s") var reload_seconds: float = 1.2
@export_range(0.02, 0.5, 0.01, "suffix:s") var blackout_seconds: float = 0.11

var mode: int = Mode.OFF
var yaw: float = 0.0
var pitch: float = 0.0
var slice_xw: float = 0.0
var slice_zw: float = 0.0
var zoom: float = 1.0
var zoom_goal: float = 1.0
var focus: float = 0.0
var focus_goal: float = 0.0
var film: int = 24
## Seconds left on the winder, while a new roll goes in.
var reloading: float = 0.0
## Shots on this roll so far, for the counter.
var exposures: int = 0
## Whether this roll reloads itself when it runs out (the cab) or not (the balloon).
var reloads: bool = true

var lookout: Node
var camera: Camera4D
var view: Control

var _room: Node
var _tower: Node4D
var _player: Node4D
var _farm_camera: Camera4D
var _layer: CanvasLayer
var _saved: Dictionary = {}
var _t: float = 0.0
var _straightening: float = 0.0
var _shutter_cool: float = 0.0
var _grab_pending: Dictionary = {}
## The climb, as eye points and look angles over time.
var _path: Array = []
## For the ride: where the eye is, each frame.
var _ride_eye: Callable = Callable()
var _ride_yaw_centre: float = 0.0
var _ride_yaw_half: float = PI
var _eye_now: Vector4 = Vector4.ZERO
var _last_rung: int = -1
var _ride_lean: Vector4 = Vector4.ZERO


func setup(owner_lookout: Node) -> void:
	lookout = owner_lookout
	_room = lookout.get("room")
	_tower = lookout.get("tower")
	_player = lookout.get("player")
	_farm_camera = lookout.get("farm_camera")
	film = roll


func _ready() -> void:
	set_process(false)
	set_process_input(false)


func busy() -> bool:
	return mode != Mode.OFF


func in_cab() -> bool:
	return mode == Mode.CAB


## Up the ladder, from wherever the player is standing at its foot.
func climb() -> void:
	if mode != Mode.OFF or _tower == null:
		return
	_borrow()
	_make_camera()
	reloads = true
	if film <= 0:
		film = roll
		exposures = 0
	var from_eye: Vector4 = _player.global_position + Vector4(0.0, 1.55, 0.0, 0.0)
	_plan_climb(from_eye, true)
	_set_mode(Mode.CLIMB_UP)
	lookout.call("sound", &"rung_start")


## Back down, and the pen handed back with the player at the ladder's foot.
func climb_down() -> void:
	if mode != Mode.CAB:
		return
	_plan_climb(_eye_now, false)
	_set_mode(Mode.CLIMB_DOWN)


## A ride - the balloon's basket. [param eye] is called each frame for where the eye is;
## the view may turn [param yaw_half] either side of [param yaw_centre].
func ride(eye: Callable, film_count: int, yaw_centre: float = 0.0, yaw_half: float = PI) -> void:
	if mode == Mode.OFF:
		_borrow()
		_make_camera()
	_ride_eye = eye
	_ride_yaw_centre = yaw_centre
	_ride_yaw_half = yaw_half
	film = film_count
	exposures = 0
	reloads = false
	reloading = 0.0
	_set_mode(Mode.RIDE)


## The ride is over: the pen back, the player put down at [param at].
func end_ride(at: Vector4, facing_yaw: float) -> void:
	if mode != Mode.RIDE:
		return
	_ride_eye = Callable()
	_player.global_position = at
	_give_back(facing_yaw)


## Look along [param direction], for a cutscene or the first view out of the window.
func look_along(direction: Vector4) -> void:
	var flat := Vector2(direction.x, direction.z)
	if flat.length() > 0.0001:
		yaw = atan2(-flat.x, -flat.y)
	pitch = clampf(atan2(direction.y, maxf(flat.length(), 0.0001)), pitch_min, pitch_max)


func set_view_visible(on: bool) -> void:
	if view != null:
		view.visible = on


# --- Borrowing the pen, and giving it back -------------------------------------------------

func _borrow() -> void:
	var hud: Dictionary = {}
	for child in _room.get_node("UI").get_children():
		if child is CanvasItem:
			hud[child] = (child as CanvasItem).visible
			(child as CanvasItem).visible = false
	var label := _room.get_node_or_null("Player/StateLabel") as CanvasItem
	_saved = {
		"hud": hud,
		"player_mode": _player.process_mode,
		"player_shown": _player.visible,
		"input": _player.get("input_enabled"),
		"label": label.visible if label else false,
		"mouse": Input.mouse_mode,
	}
	if label:
		label.visible = false
	_player.set("input_enabled", false)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_layer = CanvasLayer.new()
	_layer.name = "LookoutView"
	_layer.layer = 6
	add_child(_layer)
	view = Control.new()
	view.name = "Viewfinder"
	view.set_script(VIEWFINDER)
	view.set("station", self)
	_layer.add_child(view)
	set_process(true)
	set_process_input(true)


func _give_back(facing_yaw: float) -> void:
	var hud: Dictionary = _saved.get("hud", {})
	for item in hud:
		if is_instance_valid(item):
			(item as CanvasItem).visible = hud[item]
	var label := _room.get_node_or_null("Player/StateLabel") as CanvasItem
	if label:
		label.visible = _saved.get("label", false)
	_player.process_mode = _saved.get("player_mode", Node.PROCESS_MODE_INHERIT)
	_player.visible = _saved.get("player_shown", true)
	_player.set("input_enabled", _saved.get("input", true))
	# Facing away from the tower, and the orbit camera behind, so the first thing you see on
	# the ground is the field you were just looking at from above, not a ladder.
	var rig: Node = _room.get_node_or_null("Player/CameraRig")
	if rig != null:
		rig.set("yaw", facing_yaw)
		rig.set("pitch", -0.2)
		if rig.has_method("_apply"):
			rig.call("_apply")
	if _farm_camera != null:
		_farm_camera.make_current()
	if is_instance_valid(camera):
		camera.queue_free()
	camera = null
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	view = null
	_set_mode(Mode.OFF)
	set_process(false)
	set_process_input(false)


func _make_camera() -> void:
	camera = Camera4D.new()
	camera.name = "LookoutCamera"
	camera.set("rendering_engine_name", "Cross-section")
	camera.set("field_of_view_4d", wide_fov)
	_room.add_child(camera)
	camera.make_current()
	zoom = 1.0
	zoom_goal = 1.0
	focus = 0.0
	focus_goal = 0.0
	slice_xw = 0.0
	slice_zw = 0.0


func _set_mode(value: int) -> void:
	mode = value
	_t = 0.0
	mode_changed.emit(mode)


# --- The climb -------------------------------------------------------------------------------

## Where to face when you are back on the ground: the pen, so the orbit camera swings out
## beside the tower rather than into its frame (an 8 m arm straight back from the ladder
## ends up inside it).
func _home_ground() -> Vector4:
	var pen := _room.get_node_or_null("Pen") as Node4D
	return pen.global_position if pen != null else Vector4.ZERO


## The climb as a list of [time share, eye point, yaw, pitch]: from your head to the ladder,
## up it rung by rung, over the top onto the catwalk, through the door and to the north
## window. The ladder is on the south face, so you face north the whole way up, and arrive
## facing the way the windows look.
func _plan_climb(from_eye: Vector4, up: bool) -> void:
	var t: Node4D = _tower
	var h: float = float(t.get("deck_height"))
	var half: float = float(t.get("cab_size")) * 0.5
	var splay: float = float(t.get("splay"))
	var ladder_z: float = half + splay * 0.8 + 0.35
	var base: Vector4 = t.global_position
	var at_ladder: Vector4 = base + Vector4(0.0, 1.6, ladder_z + 0.5, 0.0)
	var at_top: Vector4 = base + Vector4(0.0, h + 1.6, ladder_z + 0.5, 0.0)
	var on_walk: Vector4 = base + Vector4(0.0, h + eye_height, half + 0.55, 0.0)
	var in_door: Vector4 = base + Vector4(0.0, h + eye_height, half - 0.3, 0.0)
	var window: Vector4 = _cab_eye(0.0, 0.0)
	var keys: Array = [
		[0.0, from_eye, _yaw_to(from_eye, at_ladder), 0.0],
		[0.14, at_ladder, 0.0, 0.32],
		[0.74, at_top, 0.0, 0.12],
		[0.84, on_walk, 0.0, -0.05],
		[0.92, in_door, 0.0, -0.08],
		[1.0, window, 0.0, -0.12],
	]
	if not up:
		# Down: out of the door, over the top, down the ladder, and a step back from it -
		# turning round to face the field at the bottom.
		var foot: Vector4 = base + Vector4(0.0, 1.55, ladder_z + 1.4, 0.0)
		keys = [
			[0.0, from_eye, yaw, pitch],
			[0.1, in_door, PI, -0.1],
			[0.2, on_walk, PI, -0.35],
			[0.3, at_top, 0.0, -0.1],
			[0.88, at_ladder, 0.0, 0.18],
			[1.0, foot, PI, -0.05],
		]
	_path = keys
	_last_rung = -1


func _yaw_to(from: Vector4, to: Vector4) -> float:
	var d: Vector4 = to - from
	return atan2(-d.x, -d.z) if Vector2(d.x, d.z).length() > 0.01 else 0.0


func _run_climb(delta: float, up: bool) -> void:
	_t += delta
	var length: float = climb_seconds if up else down_seconds
	var k: float = clampf(_t / length, 0.0, 1.0)
	var i: int = 0
	while i < _path.size() - 2 and k > float(_path[i + 1][0]):
		i += 1
	var a: Array = _path[i]
	var b: Array = _path[i + 1]
	var u: float = clampf((k - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
	var eye: Vector4
	var on_ladder: bool = (up and i == 1) or (not up and i == 3)
	if on_ladder:
		# Rung by rung: each rung a pull and a pause, and the weight going from hand to hand.
		var rungs: float = 18.0
		var r: float = u * rungs
		var step: float = floorf(r) + smoothstep(0.15, 0.85, r - floorf(r))
		var s: float = step / rungs
		eye = (a[1] as Vector4).lerp(b[1], s)
		eye.x += sin(r * PI) * 0.045
		if int(r) != _last_rung:
			_last_rung = int(r)
			lookout.call("sound", &"rung")
	else:
		eye = (a[1] as Vector4).lerp(b[1], smoothstep(0.0, 1.0, u))
	yaw = lerp_angle(float(a[2]), float(b[2]), smoothstep(0.0, 1.0, u))
	pitch = lerpf(float(a[3]), float(b[3]), smoothstep(0.0, 1.0, u))
	_eye_now = eye
	_place_camera(eye)
	if k >= 1.0:
		if up:
			_set_mode(Mode.CAB)
			lookout.call("on_cab_entered")
		else:
			_player.global_position = _tower.global_position + Vector4(0.0, 0.05, float(_tower.get("cab_size")) * 0.5 + float(_tower.get("splay")) * 0.8 + 1.4, 0.0)
			_give_back(_yaw_to(_player.global_position, _home_ground()))
			lookout.call("on_cab_left")


# --- In the cab ------------------------------------------------------------------------------

## The eye at the window you face: [param look_yaw] decides which, leaning out to it.
func _cab_eye(look_yaw: float, look_pitch: float) -> Vector4:
	var h: float = float(_tower.get("deck_height"))
	var inner: float = float(_tower.get("cab_size")) * 0.5 - 0.12
	var forward := Vector2(-sin(look_yaw), -cos(look_yaw))
	var most: float = maxf(absf(forward.x), absf(forward.y))
	var lean: float = clampf((inner - lean_gap) / maxf(most, 0.0001), 0.0, 1.6)
	# Leaning over the sill to look down, a little further out.
	lean += clampf(-look_pitch, 0.0, 1.0) * 0.12
	return _tower.global_position + Vector4(forward.x * lean, h + eye_height, forward.y * lean, 0.0)


func _process(delta: float) -> void:
	match mode:
		Mode.CLIMB_UP:
			_run_climb(delta, true)
		Mode.CLIMB_DOWN:
			_run_climb(delta, false)
		Mode.CAB, Mode.RIDE:
			_run_camera(delta)
	if view != null:
		view.queue_redraw()


func _run_camera(delta: float) -> void:
	if _shutter_cool > 0.0:
		_shutter_cool -= delta
	# The lens: zoom eased in log space, so every notch takes the same time.
	zoom = exp(lerpf(log(zoom), log(zoom_goal), clampf(delta * 9.0, 0.0, 1.0)))
	camera.set("field_of_view_4d", 2.0 * atan(tan(wide_fov * 0.5) / zoom))
	# The focus ring: held keys turn it, fine with Shift; it eases after the hand.
	var turn: float = Input.get_axis(&"move_kata", &"move_ana")
	if absf(turn) > 0.01:
		_straightening = 0.0
		var rate: float = focus_speed * (focus_fine if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		focus_goal = clampf(focus_goal + turn * rate * delta, -focus_range, focus_range)
	if _straightening > 0.0:
		_straightening = maxf(_straightening - delta, 0.0)
		var step: float = clampf(delta / maxf(_straightening + delta, 0.0001), 0.0, 1.0)
		slice_xw = lerpf(slice_xw, 0.0, step)
		slice_zw = lerpf(slice_zw, 0.0, step)
		focus_goal = lerpf(focus_goal, 0.0, step)
	var before: float = focus
	focus = lerpf(focus, focus_goal, clampf(delta * 10.0, 0.0, 1.0))
	if absf(focus - before) > 0.0005:
		lookout.call("sound", &"focus", absf(focus - before) / maxf(delta, 0.001))
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			film = roll
			exposures = 0
	var eye: Vector4
	if mode == Mode.RIDE and _ride_eye.is_valid():
		var off: float = wrapf(yaw - _ride_yaw_centre, -PI, PI)
		yaw = _ride_yaw_centre + clampf(off, -_ride_yaw_half, _ride_yaw_half)
		# Leaning on the rim towards where you look, and over it to look down - or the
		# basket's own walls fill the bottom of every picture.
		var forward := Vector2(-sin(yaw), -cos(yaw))
		var lean: float = 0.3 + 0.55 * clampf(-pitch / 0.9, 0.0, 1.0)
		var target: Vector4 = (_ride_eye.call() as Vector4) + Vector4(forward.x * lean, -0.08 * clampf(-pitch, 0.0, 1.0), forward.y * lean, 0.0)
		_ride_lean = _ride_lean.lerp(target - (_ride_eye.call() as Vector4), clampf(delta * 6.0, 0.0, 1.0))
		eye = (_ride_eye.call() as Vector4) + _ride_lean
	else:
		var target: Vector4 = _cab_eye(yaw, pitch)
		eye = _eye_now.lerp(target, clampf(delta * 6.0, 0.0, 1.0)) if _eye_now != Vector4.ZERO else target
	_eye_now = eye
	_place_camera(eye)


## The slice turns outermost, then yaw, then pitch - the orbit rig's order - and the focus
## slides the eye along the slice's normal, which yaw and pitch never touch.
func _place_camera(eye: Vector4) -> void:
	if camera == null:
		return
	var frame: Projection = _slice_frame() * Basis4D.from_zx(yaw)
	camera.global_basis = Basis4D.orthonormalized(frame * Basis4D.from_yz(pitch))
	camera.global_position = eye + slice_normal() * focus


func _slice_frame() -> Projection:
	var frame: Projection = Projection.IDENTITY
	if not is_zero_approx(slice_xw):
		frame *= Basis4D.from_xw(slice_xw)
	if not is_zero_approx(slice_zw):
		frame *= Basis4D.from_zw(slice_zw)
	return frame


## The direction the focus ring slides along, in the world.
func slice_normal() -> Vector4:
	return (_slice_frame() * Vector4(0.0, 0.0, 0.0, 1.0)).normalized()


## Where the eye is with the focus ring at zero - what the W-meter measures from.
func home_eye() -> Vector4:
	return _eye_now


## The lens as a full-frame focal length: 12 mm is half a 24 mm sensor's height.
func lens_mm() -> float:
	return 12.0 / tan(float(camera.get("field_of_view_4d")) * 0.5) if camera != null else 0.0


func _input(event: InputEvent) -> void:
	if mode == Mode.OFF:
		return
	var handled: bool = true
	var taking: bool = mode == Mode.CAB or mode == Mode.RIDE
	if event is InputEventMouseMotion:
		if not taking:
			return
		var motion: Vector2 = (event as InputEventMouseMotion).relative * mouse_sensitivity
		if Input.is_action_pressed(&"rotate_4d"):
			_straightening = 0.0
			slice_xw -= motion.x
			slice_zw += motion.y
		else:
			# Slower the longer the lens, so a 10x view does not whip about.
			var scale: float = 1.0 / zoom
			yaw -= motion.x * scale
			pitch = clampf(pitch - motion.y * scale, pitch_min, pitch_max)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button: int = (event as InputEventMouseButton).button_index
		if not taking:
			handled = false
		elif button == MOUSE_BUTTON_WHEEL_UP:
			zoom_goal = clampf(zoom_goal * zoom_step, 1.0, zoom_max)
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_goal = clampf(zoom_goal / zoom_step, 1.0, zoom_max)
		elif event.is_action_pressed(&"fire"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			take_photo()
		else:
			handled = false
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var code: int = (event as InputEventKey).keycode
		if not taking:
			# Mid-climb, keys wait; Escape is still yours.
			handled = code == KEY_ESCAPE
		elif code == KEY_ESCAPE or event.is_action_pressed(&"catch_target"):
			if mode == Mode.CAB:
				climb_down()
			else:
				lookout.call("on_ride_escape")
		elif code == KEY_X and mode == Mode.RIDE:
			lookout.call("on_whistle")
		elif code == KEY_R:
			_straightening = 0.45
		elif code == KEY_T:
			autofocus()
		else:
			handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Pulls the focus to whatever is nearest the middle of the frame and in front of you.
func autofocus() -> void:
	var best: Dictionary = lookout.get("subjects").call("nearest_to_centre", camera, home_eye(), slice_normal(), focus_range)
	if best.is_empty():
		lookout.call("sound", &"af_miss")
		return
	_straightening = 0.0
	focus_goal = clampf(float(best["w"]), -focus_range, focus_range)
	lookout.call("sound", &"af")


# --- The shutter -----------------------------------------------------------------------------

func take_photo() -> void:
	if camera == null or _shutter_cool > 0.0:
		return
	if film <= 0 or reloading > 0.0:
		lookout.call("sound", &"empty")
		if view != null:
			view.call("flash_note", "Reloading" if reloading > 0.0 else "Out of film")
		return
	_shutter_cool = 0.32
	film -= 1
	exposures += 1
	var photo: Dictionary = lookout.get("judge").call("judge", camera, _viewport_size())
	photo["time"] = Time.get_unix_time_from_system()
	photo["from"] = "balloon" if mode == Mode.RIDE else "tower"
	photo["focus"] = focus
	photo["zoom"] = zoom
	lookout.call("sound", &"shutter")
	# The picture: the next drawn frame, with the overlay hidden for it.
	if view != null:
		view.visible = false
	_grab_pending = photo
	RenderingServer.frame_post_draw.connect(_grab, CONNECT_ONE_SHOT)
	if film <= 0 and reloads:
		reloading = reload_seconds
		lookout.call("sound", &"reload")


func _grab() -> void:
	var photo: Dictionary = _grab_pending
	_grab_pending = {}
	var image: Image = get_viewport().get_texture().get_image()
	photo["image"] = image
	if view != null:
		view.visible = true
		view.call("blackout", blackout_seconds)
	shot.emit(photo)
	lookout.call("on_photo", photo)
	if film > 0:
		lookout.call("sound", &"winder")


func _viewport_size() -> Vector2:
	return Vector2(get_viewport().get_size())
