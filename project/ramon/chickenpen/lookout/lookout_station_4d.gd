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
## THE CAMERA ANYWHERE (HELD). Ramon, 2 Oct: "maybe we should just allow the player to walk as
## in first person mode". Z raises the camera wherever you are, once Wren has given it to you:
## the view goes to your eyes, you walk as ever (WASD, the orbit rig still turning you and the
## slice), and the camera's keys are live - wheel, E and Q as the focus ring, T, click. On the
## balcony that is how you are up there: you walk round the deck with the camera raised.
## E and Q are the pen's ana/kata keys; while the camera is up their bindings are lifted out
## of the InputMap (so you do not step through W) and read here as the ring, and put back
## the moment it comes down.
##
## IT BORROWS THE PEN AS THE CINEMATIC DOES: the player frozen and hidden at the ladder's
## foot, the HUD put away, its own Camera4D standing in the world (a camera parented to
## nothing that moves cannot be dragged anywhere - pen_npc_talk_4d.gd's header). The farm's
## sounds keep playing: you are still there.

signal mode_changed(mode: int)
signal shot(photo: Dictionary)

enum Mode { OFF, CLIMB_UP, CAB, CLIMB_DOWN, RIDE, HELD }

const VIEWFINDER := preload("res://ramon/chickenpen/lookout/lookout_viewfinder_4d.gd")

@export_group("Climb")
@export_range(0.5, 10.0, 0.1, "suffix:s") var climb_seconds: float = 3.4
@export_range(0.5, 10.0, 0.1, "suffix:s") var down_seconds: float = 2.2
## How high the eye stands above the cab floor.
@export_range(1.0, 2.0, 0.01, "suffix:m") var eye_height: float = 1.55
## How close to the window you face the eye leans: this far inside the wall.
@export_range(0.1, 1.5, 0.01, "suffix:m") var lean_gap: float = 0.33

@export_group("Held")
## The key that raises and lowers the camera, anywhere. Z was free in the pen.
@export var raise_key: Key = KEY_Z
## Eye height above your feet, with the camera up.
@export_range(1.0, 2.0, 0.01, "suffix:m") var held_eye_height: float = 1.5
## Walking pace with the camera up: a photographer's, not a run.
@export_range(0.5, 6.0, 0.1, "suffix:m/s") var held_walk_speed: float = 2.4

@export_group("Lens")
## The widest the lens goes, vertical field of view.
##
## SET AS field_of_view_4d, NOT field_of_view_3d: a Camera4D's projection type defaults to
## PERSPECTIVE_4D, and then the cross-section renderer's 3D camera takes its angle from the
## 4D field of view (godot_3d_rendering_engine_4d.cpp _update_3d_camera) - the 3D one is
## ignored. (The pen's own camera used to set only the 3D one; it now says the 77.3 it draws at.)
##
## 1.176 rad is an 18 mm lens on a full-frame camera (12 / tan(fov / 2)), so the widest lens
## is a round number and the primes below are true multiples of it.
@export_range(0.3, 1.6, 0.001) var wide_fov: float = 1.176
@export_range(1.0, 20.0, 0.1) var zoom_max: float = 12.0
## One wheel notch.
@export_range(1.02, 1.6, 0.01) var zoom_step: float = 1.18
## L steps through these, as a photographer swaps primes (Ramon, 2 Oct: "a camera lens toggle
## button to have different mm lenses, or degrees"); Shift+L steps back. The wheel still zooms
## between them. Full-frame focal lengths in mm; the viewfinder gives each its angle too.
@export var lenses: PackedInt32Array = PackedInt32Array([18, 24, 35, 50, 85, 135, 200])
@export var lens_key: Key = KEY_L
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
## The prime last chosen with L, in mm, and how long ago (for the viewfinder's big readout).
var lens_chosen: int = 0
var lens_chosen_t: float = 99.0
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
var _on_ladder: bool = false
var _climb_player: AudioStreamPlayer
var _climb_db: float = -8.0
var _climb_fade: Tween
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
## Which segment of the climb path is the ladder itself (rung by rung).
var _ladder_seg: int = 1
## What raising the camera changed, to put back.
var _held_saved: Dictionary = {}
## The ana/kata key bindings, lifted out while the camera is up.
var _held_keys: Dictionary = {}
var _rig: Node
var _pitch_node: Node4D
## The pen's world tags, pointed at the raised camera while it is up.
var _tags: Array = []


func setup(owner_lookout: Node) -> void:
	lookout = owner_lookout
	_room = lookout.get("room")
	_tower = lookout.get("tower")
	_player = lookout.get("player")
	_farm_camera = lookout.get("farm_camera")
	_rig = _room.get_node_or_null("Player/CameraRig")
	_pitch_node = _room.get_node_or_null("Player/CameraRig/Pitch") as Node4D
	film = roll


func _ready() -> void:
	set_process(false)
	set_process_input(false)


func busy() -> bool:
	return mode != Mode.OFF


func in_cab() -> bool:
	return mode == Mode.CAB


## Up the tower with the camera: in the cab, or on the balcony with it raised.
func up_tower() -> bool:
	if mode == Mode.CAB:
		return true
	return mode == Mode.HELD and _tower != null and bool(_tower.call("on_deck", _player.global_position))


## Whether Z would raise the camera now: Wren has given it to you, you are on your feet and
## free, nobody is talking to you - and you are up on the lookout's deck.
##
## THE CAMERA IS THE LOOKOUT'S (Ramon, 2 Oct: "Tower and balloon only"). Round two let Z raise
## it anywhere, which turned the whole pen into camera country; now the pen is the pen, and the
## tower and the balloon are where photographs are taken. [param anywhere] asks the same
## question without the deck, so a Z on the ground can say why nothing happened.
func can_raise(anywhere: bool = false) -> bool:
	if not anywhere and not on_lookout():
		return false
	if mode != Mode.OFF or _player == null or not _player.is_visible_in_tree():
		return false
	if _player.get("input_enabled") == false or _player.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	if not bool(lookout.get("journal").call("flag", "met_wren")) or bool(lookout.call("story_busy")):
		return false
	for talker in get_tree().get_nodes_in_group(&"npc_talk"):
		var talk: Node = talker.get("_talk")
		if talk != null and bool(talk.call("is_running")):
			return false
	return true


## Whether you are standing on the lookout's deck (the balcony; the cab design has no deck to
## walk, its camera comes with the climb).
func on_lookout() -> bool:
	return _tower != null and _player != null and bool(_tower.call("is_balcony")) and bool(_tower.call("on_deck", _player.global_position))


## Up to your eye, on the deck.
func raise() -> void:
	if mode != Mode.OFF:
		return
	_hold_borrow()
	_make_camera()
	reloads = true
	if film <= 0:
		film = roll
		exposures = 0
	_set_mode(Mode.HELD)
	_place_held_camera()
	# No winder (Ramon, 3 Oct: "no i dont want a winder sound").
	if view != null:
		view.call("raised")
	lookout.call("on_camera_raised")


## Down again: the orbit camera back behind you.
func lower() -> void:
	if mode != Mode.HELD:
		return
	_hold_give_back()
	lookout.call("sound", &"hatch")


## Up the ladder, from wherever the player is standing at its foot.
func climb() -> void:
	if mode == Mode.HELD:
		lower()
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


## Back down, and the pen handed back with the player at the ladder's foot. From the cab, or
## from the balcony's ladder gap (camera up or not).
func climb_down() -> void:
	if mode == Mode.HELD:
		lower()
	if mode == Mode.OFF and _tower != null and bool(_tower.call("is_balcony")):
		var from_eye: Vector4 = _player.global_position + Vector4(0.0, held_eye_height, 0.0, 0.0)
		_borrow()
		_make_camera()
		_eye_now = from_eye
		yaw = _rig_yaw()
		pitch = 0.0
		_plan_climb(from_eye, false)
		_set_mode(Mode.CLIMB_DOWN)
		return
	if mode != Mode.CAB:
		return
	_plan_climb(_eye_now, false)
	_set_mode(Mode.CLIMB_DOWN)


## A ride - the balloon's basket. [param eye] is called each frame for where the eye is;
## the view may turn [param yaw_half] either side of [param yaw_centre].
func ride(eye: Callable, film_count: int, yaw_centre: float = 0.0, yaw_half: float = PI) -> void:
	if mode == Mode.HELD:
		lower()
	if mode == Mode.OFF:
		_borrow()
		_make_camera()
	_ride_eye = eye
	# Anything a hand's breadth from the eye is not drawn: the burner's rods pass right by
	# it in the basket, and drawn they cut across the picture as great orange bars.
	camera.set("clip_near", 0.6)
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


## Look along [param direction], for a cutscene or the first view out of the window. With the
## camera held, it turns you: the orbit rig owns the look then.
func look_along(direction: Vector4) -> void:
	var flat := Vector2(direction.x, direction.z)
	if flat.length() > 0.0001:
		yaw = atan2(-flat.x, -flat.y)
	pitch = clampf(atan2(direction.y, maxf(flat.length(), 0.0001)), pitch_min, pitch_max)
	if mode == Mode.HELD and _rig != null:
		_rig.set("yaw", yaw)
		_rig.set("pitch", pitch)
		_rig.call("_apply")


func set_view_visible(on: bool) -> void:
	if view != null:
		view.visible = on


# --- Holding the camera up, anywhere ------------------------------------------------------------

func _hold_borrow() -> void:
	var hud: Dictionary = {}
	_tags.clear()
	for child in _room.get_node("UI").get_children():
		# The people's "F talk" tags stay, drawn through the raised camera: F still talks.
		if child is WorldTag4D:
			_tags.append(child)
			continue
		if child is CanvasItem:
			hud[child] = (child as CanvasItem).visible
			(child as CanvasItem).visible = false
	var label := _room.get_node_or_null("Player/StateLabel") as CanvasItem
	var avatar := _room.get_node_or_null("Player/Avatar") as Node4D
	_held_saved = {
		"hud": hud, "label": label.visible if label else false,
		"avatar": avatar.visible if avatar else true,
		"pitch_min": _rig.get("pitch_min_degrees") if _rig else -75.0,
		"pitch_max": _rig.get("pitch_max_degrees") if _rig else 25.0,
		"sensitivity": _rig.get("mouse_sensitivity") if _rig else 0.005,
		"run": _player.get("run_speed"), "sprint": _player.get("sprint_speed"),
	}
	if label:
		label.visible = false
	# Your own head would fill the picture.
	if avatar:
		avatar.visible = false
	if _rig:
		_rig.set("pitch_min_degrees", -80.0)
		_rig.set("pitch_max_degrees", 80.0)
	_player.set("run_speed", held_walk_speed)
	_player.set("sprint_speed", held_walk_speed * 1.6)
	_held_keys.clear()
	for action in [&"move_ana", &"move_kata"]:
		if InputMap.has_action(action):
			_held_keys[action] = InputMap.action_get_events(action)
			InputMap.action_erase_events(action)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_make_view()
	set_process(true)
	set_process_input(true)


func _hold_give_back() -> void:
	for tag in _tags:
		if is_instance_valid(tag):
			tag.set("_camera", _farm_camera)
	_tags.clear()
	var hud: Dictionary = _held_saved.get("hud", {})
	for item in hud:
		if is_instance_valid(item):
			(item as CanvasItem).visible = hud[item]
	var label := _room.get_node_or_null("Player/StateLabel") as CanvasItem
	if label:
		label.visible = _held_saved.get("label", false)
	var avatar := _room.get_node_or_null("Player/Avatar") as Node4D
	if avatar:
		avatar.visible = _held_saved.get("avatar", true)
	if _rig:
		_rig.set("pitch_min_degrees", _held_saved.get("pitch_min", -75.0))
		_rig.set("pitch_max_degrees", _held_saved.get("pitch_max", 25.0))
		_rig.set("mouse_sensitivity", _held_saved.get("sensitivity", 0.005))
		# The orbit camera allows only 25 degrees up: bring a skyward look back within it.
		_rig.set("pitch", clampf(float(_rig.get("pitch")), deg_to_rad(float(_held_saved.get("pitch_min", -75.0))), deg_to_rad(float(_held_saved.get("pitch_max", 25.0)))))
		_rig.call("_apply")
	_player.set("run_speed", _held_saved.get("run", 3.0))
	_player.set("sprint_speed", _held_saved.get("sprint", 4.2))
	_restore_keys()
	if _farm_camera != null:
		_farm_camera.make_current()
	if is_instance_valid(camera):
		camera.queue_free()
	camera = null
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	view = null
	lookout.call("sound_loop", &"wind", false)
	_set_mode(Mode.OFF)
	set_process(false)
	set_process_input(false)


func _restore_keys() -> void:
	for action in _held_keys:
		if InputMap.has_action(action):
			for e in _held_keys[action]:
				InputMap.action_add_event(action, e)
	_held_keys.clear()


## The pen going away with the camera up (a scene change, a quit): the keys must come back.
func _exit_tree() -> void:
	_restore_keys()


## The focus ring's keys while held: the lifted ana/kata bindings, read directly.
func _held_axis() -> float:
	var axis: float = 0.0
	for action in _held_keys:
		var pressed: bool = false
		for e in _held_keys[action]:
			var key := e as InputEventKey
			if key == null:
				continue
			var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
			if Input.is_physical_key_pressed(code) or Input.is_key_pressed(code):
				pressed = true
		if pressed:
			axis += 1.0 if action == &"move_ana" else -1.0
	return axis


func _talking() -> bool:
	for talker in get_tree().get_nodes_in_group(&"npc_talk"):
		var talk: Node = talker.get("_talk")
		if talk != null and bool(talk.call("is_running")):
			return true
	return false


func _someone_to_talk_to() -> bool:
	for talker in get_tree().get_nodes_in_group(&"npc_talk"):
		if talker.is_inside_tree() and talker.can_process() and talker.has_method("_in_reach") and bool(talker.call("_in_reach")):
			return true
	return false


func _rig_yaw() -> float:
	return float(_rig.get("yaw")) if _rig != null else 0.0


## The camera at your eyes, looking where the orbit rig looks - its slice turns and all - and
## the focus ring sliding it along that slice's normal.
func _place_held_camera() -> void:
	if camera == null or _pitch_node == null:
		return
	var basis: Projection = _pitch_node.global_basis
	_eye_now = _player.global_position + Vector4(0.0, held_eye_height, 0.0, 0.0)
	camera.global_basis = basis
	camera.global_position = _eye_now + basis.w.normalized() * focus
	yaw = _rig_yaw()
	pitch = float(_rig.get("pitch"))
	slice_xw = float(_rig.get("_slice_xw"))
	slice_zw = float(_rig.get("_slice_zw"))


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
	_make_view()
	set_process(true)
	set_process_input(true)


func _make_view() -> void:
	if is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.name = "LookoutView"
	_layer.layer = 6
	add_child(_layer)
	view = Control.new()
	view.name = "Viewfinder"
	view.set_script(VIEWFINDER)
	view.set("station", self)
	_layer.add_child(view)


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
	lookout.call("sound_loop", &"wind", false)
	_set_mode(Mode.OFF)
	set_process(false)
	set_process_input(false)


func _make_camera() -> void:
	camera = Camera4D.new()
	camera.name = "LookoutCamera"
	# The projection toggle's renderer from the start, so raising the camera is one switch.
	camera.set("rendering_engine_name", "Combined" if bool(lookout.get("projection")) else "Cross-section")
	camera.set("projection_opacity", float(lookout.get("projection_opacity")))
	camera.set("projection_opacity_base", float(lookout.get("projection_opacity_base")))
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
	var ladder_z: float = float(t.call("ladder_z"))
	var base: Vector4 = t.global_position
	if bool(t.call("is_balcony")):
		# Up the ladder and over the edge of the deck, through the gap in the rail, facing
		# north - the way the deck looks out over the field to the starlings.
		var b_ladder: Vector4 = base + Vector4(0.0, 1.6, ladder_z + 0.5, 0.0)
		var b_top: Vector4 = base + Vector4(0.0, h + 1.5, ladder_z + 0.5, 0.0)
		var b_on: Vector4 = (t.call("ladder_top") as Vector4) + Vector4(0.0, held_eye_height, 0.0, 0.0)
		_ladder_seg = 1
		_path = [
			[0.0, from_eye, _yaw_to(from_eye, b_ladder), 0.0],
			[0.14, b_ladder, 0.0, 0.32],
			[0.84, b_top, 0.0, 0.1],
			[1.0, b_on, 0.0, -0.05],
		]
		if not up:
			var b_foot: Vector4 = (t.call("ladder_foot") as Vector4) + Vector4(0.0, 1.55, 0.25, 0.0)
			_path = [
				[0.0, from_eye, yaw, pitch],
				[0.16, b_top, 0.0, -0.2],
				[0.86, b_ladder, 0.0, 0.15],
				[1.0, b_foot, PI, -0.05],
			]
		_last_rung = -1
		return
	_ladder_seg = 1
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
		_ladder_seg = 3
	_path = keys
	_last_rung = -1
	_on_ladder = false


## THE LADDER'S SOUND is one recording of a climb (Ramon, 3 Oct: "use climbin off metalic ladder
## for when climbin the ladder"), not a clank a rung: on as you step onto the ladder, up or down,
## and faded out over a quarter of a second as you step off it.
func _climb_noise(on: bool) -> void:
	var sounds: Node = lookout.get("sounds")
	if _climb_player == null and sounds != null and bool(sounds.call("has", &"climb")):
		_climb_player = sounds.call("held", &"climb")
		_climb_db = _climb_player.volume_db
	if _climb_player == null:
		return
	if _climb_fade != null:
		_climb_fade.kill()
		_climb_fade = null
	if on:
		_climb_player.volume_db = _climb_db
		_climb_player.play()
	elif _climb_player.playing:
		_climb_fade = create_tween()
		_climb_fade.tween_property(_climb_player, "volume_db", -50.0, 0.25)
		_climb_fade.tween_callback(_climb_player.stop)


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
	var on_ladder: bool = i == _ladder_seg
	if on_ladder != _on_ladder:
		_on_ladder = on_ladder
		_climb_noise(on_ladder)
	if on_ladder:
		# Rung by rung: each rung a pull and a pause, and the weight going from hand to hand.
		var rungs: float = 18.0
		var r: float = u * rungs
		var step: float = floorf(r) + smoothstep(0.15, 0.85, r - floorf(r))
		var s: float = step / rungs
		eye = (a[1] as Vector4).lerp(b[1], s)
		eye.x += sin(r * PI) * 0.045
		_last_rung = int(r)
	else:
		eye = (a[1] as Vector4).lerp(b[1], smoothstep(0.0, 1.0, u))
	yaw = lerp_angle(float(a[2]), float(b[2]), smoothstep(0.0, 1.0, u))
	pitch = lerpf(float(a[3]), float(b[3]), smoothstep(0.0, 1.0, u))
	_eye_now = eye
	_place_camera(eye)
	if k >= 1.0:
		_on_ladder = false
		_climb_noise(false)
		if up and bool(_tower.call("is_balcony")):
			# On the deck: on your feet, the camera already up.
			_player.global_position = (_tower.call("ladder_top") as Vector4) + Vector4(0.0, 0.05, 0.0, 0.0)
			_player.set("linear_velocity", Vector4.ZERO)
			# Facing out over the farm, towards the pen: the cabin is behind you.
			_give_back(_yaw_to(_player.global_position, _home_ground()))
			raise()
			lookout.call("on_cab_entered")
		elif up:
			_set_mode(Mode.CAB)
			lookout.call("on_cab_entered")
		else:
			_player.global_position = (_tower.call("ladder_foot") as Vector4) + Vector4(0.0, 0.05, 0.4, 0.0)
			_player.set("linear_velocity", Vector4.ZERO)
			_give_back(_yaw_to(_player.global_position, _home_ground()))
			lookout.call("on_cab_left")


# --- In the cab ------------------------------------------------------------------------------

## The eye at the window you face: [param look_yaw] decides which, leaning out to it.
##
## AT THE WALL YOU LOOK MOST TOWARDS, AND NEVER INTO A CORNER. Leaning straight along the
## view put the eye on the cab's diagonal whenever you looked diagonally - right behind the
## corner post, which a long lens then filled the frame with. So the eye goes to the wall
## facing the view, slides along it towards the view's side, and stops short of the corner;
## a diagonal view then goes out through that wall's end pane.
func _cab_eye(look_yaw: float, look_pitch: float) -> Vector4:
	var h: float = float(_tower.get("deck_height"))
	var inner: float = float(_tower.get("cab_size")) * 0.5 - 0.12
	var forward := Vector2(-sin(look_yaw), -cos(look_yaw))
	var out: float = inner - lean_gap + clampf(-look_pitch, 0.0, 1.0) * 0.12
	var along_limit: float = inner - 1.0
	var at := Vector2.ZERO
	if absf(forward.x) >= absf(forward.y):
		at.x = signf(forward.x) * out
		at.y = clampf(forward.y / maxf(absf(forward.x), 0.0001) * out, -along_limit, along_limit)
	else:
		at.y = signf(forward.y) * out
		at.x = clampf(forward.x / maxf(absf(forward.y), 0.0001) * out, -along_limit, along_limit)
	return _tower.global_position + Vector4(at.x, h + eye_height, at.y, 0.0)


func _process(delta: float) -> void:
	match mode:
		Mode.CLIMB_UP:
			_run_climb(delta, true)
		Mode.CLIMB_DOWN:
			_run_climb(delta, false)
		Mode.CAB, Mode.RIDE, Mode.HELD:
			_run_camera(delta)
	if view != null:
		view.queue_redraw()


func _run_camera(delta: float) -> void:
	if _shutter_cool > 0.0:
		_shutter_cool -= delta
	# Wind: a breath of it at the cab's windows, more of it in the open basket, rising with
	# the height.
	var height: float = _eye_now.y if _eye_now != Vector4.ZERO else 10.0
	if mode == Mode.HELD and height < 6.0:
		lookout.call("sound_loop", &"wind", false)
	else:
		lookout.call("sound_loop", &"wind", true, (-4.0 if mode != Mode.RIDE else 4.0) + clampf((height - 10.0) * 0.2, -4.0, 3.0))
	lens_chosen_t += delta
	# The lens: zoom eased in log space, so every notch takes the same time.
	zoom = exp(lerpf(log(zoom), log(zoom_goal), clampf(delta * 9.0, 0.0, 1.0)))
	camera.set("field_of_view_4d", 2.0 * atan(tan(wide_fov * 0.5) / zoom))
	# The focus ring: held keys turn it, fine with Shift; it eases after the hand.
	var turn: float = _held_axis() if mode == Mode.HELD else Input.get_axis(&"move_kata", &"move_ana")
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
	if mode == Mode.HELD:
		# Off the deck (a fall, a teleport): the camera comes down, it is the lookout's.
		if not on_lookout():
			lower()
			return
		if _rig != null:
			# Slower the longer the lens: the rig turns you, at a rate cut by the zoom.
			_rig.set("mouse_sensitivity", float(_held_saved.get("sensitivity", 0.005)) / zoom)
		_place_held_camera()
		for tag in _tags:
			if is_instance_valid(tag):
				tag.set("_camera", camera)
		# A conversation took you out of it: the camera comes down. (Not for the owl's reveal:
		# that borrows the picture for a moment and gives the raised camera back.)
		if _talking():
			lower()
		return
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
	if mode == Mode.HELD and _pitch_node != null:
		return _pitch_node.global_basis.w.normalized()
	return (_slice_frame() * Vector4(0.0, 0.0, 0.0, 1.0)).normalized()


## Where the eye is with the focus ring at zero - what the W-meter measures from.
func home_eye() -> Vector4:
	return _eye_now


## The lens as a full-frame focal length: 12 mm is half a 24 mm sensor's height.
func lens_mm() -> float:
	return 12.0 / tan(float(camera.get("field_of_view_4d")) * 0.5) if camera != null else 0.0


## The widest lens, in mm: what zoom 1 is.
func base_mm() -> float:
	return 12.0 / tan(wide_fov * 0.5)


## The vertical angle a lens of [param mm] sees, in degrees.
func lens_degrees(mm: float) -> float:
	return rad_to_deg(2.0 * atan(12.0 / maxf(mm, 1.0)))


## The next prime up from the lens the zoom is heading for (or back down, [param step] -1),
## round to the widest after the longest.
func next_lens(step: int = 1) -> void:
	if lenses.is_empty():
		return
	var now: float = base_mm() * zoom_goal
	var pick: int = -1
	if step > 0:
		for mm in lenses:
			if float(mm) > now + 0.5:
				pick = mm
				break
		if pick < 0:
			pick = lenses[0]
	else:
		for k in range(lenses.size() - 1, -1, -1):
			if float(lenses[k]) < now - 0.5:
				pick = lenses[k]
				break
		if pick < 0:
			pick = lenses[lenses.size() - 1]
	zoom_goal = clampf(float(pick) / base_mm(), 1.0, zoom_max)
	lens_chosen = pick
	lens_chosen_t = 0.0


func _input(event: InputEvent) -> void:
	if mode == Mode.OFF:
		return
	var handled: bool = true
	var taking: bool = mode == Mode.CAB or mode == Mode.RIDE or mode == Mode.HELD
	if event is InputEventMouseMotion:
		# Held, the orbit rig turns you (and the slice); the camera follows it.
		if not taking or mode == Mode.HELD:
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
		elif code == lens_key:
			next_lens(-1 if (event as InputEventKey).shift_pressed else 1)
		elif mode == Mode.HELD and (code == KEY_ESCAPE or code == raise_key):
			lower()
		elif mode == Mode.HELD and code == KEY_R:
			# The rig straightens the slice and brings you home in W; the ring comes home too.
			focus_goal = 0.0
			handled = false
		elif mode == Mode.HELD and event.is_action_pressed(&"catch_target") and _someone_to_talk_to():
			# F to somebody: the camera comes down first, and the conversation has the view.
			lower()
			handled = false
		elif mode == Mode.HELD and code != KEY_T:
			# Everything else is the pen's: F to climb down, WASD, the belt.
			handled = false
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
	photo["from"] = "balloon" if mode == Mode.RIDE else ("tower" if up_tower() else "ground")
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
	# One sound for a photo, the shutter (Ramon, 3 Oct: "right now you hear 2 sounds when
	# snapping a picture, should be just one"): no winder after it. The winder is for the camera
	# coming up and a new roll going in.


func _viewport_size() -> Vector2:
	return Vector2(get_viewport().get_size())
