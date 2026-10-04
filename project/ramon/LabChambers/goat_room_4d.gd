@tool
extends Node4D

## THE GOAT ROOM: one feature room, done properly, to set the style and grow the kit
## (LabChambers/kit/). Ramon, 4 Oct: "an simple entrance to walk through, and then the goat room
## ... nail the style together. and hence create the kit."
##
## You start in a short entrance, walk under CREATION LAB painted over the doorway, and into a
## grey tiled room in blue light: the lesson on the left wall, the goat on a lit plinth under one
## downlight with its slices standing behind it, the W-slice and cross-section screens on the
## right wall, and the research panel floating off to the left under the lesson, to walk to.
##
## Everything in the room is a kit node in the scene, so it can be moved and tuned in the editor.
## THIS NODE: the moods (kit_style.gd; LabKit's Room owns the light and the B key), the player
## (the gallery's grown-up figure, kit_player.gd; the camera close behind and above, looking down
## past you, as in the concept frames), the HUD strip, the light sliders (kit_tuner.gd), and
## the mouse and keys: the wheel slices, a right drag turns the goat through W, E adds a ball. The
## goat plays its own sequence in place on a loop (the showcase's autoplay); the camera-taking
## cinematic (watch()) is kept for later but nothing starts it yet.
##
## NO class_name (engine_gotchas.md).

const KitPlayer := preload("res://ramon/LabChambers/kit/kit_player.gd")
const LabMath := preload("res://ramon/LabKit/lab_math.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")
const Hud := preload("res://ramon/LabChambers/scripts/rd_hud.gd")
const Tuner := preload("res://ramon/LabChambers/kit/kit_tuner.gd")
const DataPanel := preload("res://ramon/LabChambers/kit/kit_data_panel.gd")
const Prompt := preload("res://ramon/LabChambers/kit/kit_prompt.gd")

## Where the player starts, facing -Z.
@export var start_at: Vector2 = Vector2(0.0, 15.2)
## The arrows painted into the floors, world x/z.
@export var route: PackedVector2Array = PackedVector2Array([Vector2(0, 14.6), Vector2(0, 4.2)])

@export_group("Camera")
## How far behind you the camera sits, in metres. The concept frames have you close and large in
## the lower middle with the room opening up past you (Ramon, 4 Oct: "look more like ref").
@export_range(2.0, 12.0, 0.1) var camera_distance: float = 5.0
## What the camera looks at, metres above your feet: above your head puts you low in the frame.
@export_range(0.5, 3.5, 0.05) var camera_height: float = 2.45
## How far it looks down, in degrees (negative is down).
@export_range(-45.0, 20.0, 0.5) var camera_pitch_degrees: float = -11.0

var player: CharacterBody4D
var hud: Control
var tuner: PanelContainer
var data_panel: Control
var prompt: Control
var showcase: Node
var _cine: Dictionary = {}
var _film: Camera4D
var _desk_ease: float = 0.0
var _rig_pitch: float = 0.0
var _in_room: bool = false
## The research panel you stand at (null: none), and whether you have clicked its CHECK DATA.
var _at_desk: Node = null
var _desk_open: bool = false


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func apply_mood(m: String, _instant: bool = false) -> void:
	Style.apply(m)
	if hud != null:
		hud.call("set_mood", m)


func _ready() -> void:
	var room: Node = get_node_or_null("Room")
	if room != null:
		room.set("mood_overrides", Style.ROOM_LIGHT.duplicate(true))
		room.call("set_mood", String(room.get("mood")), true, false)
	for r in get_tree().get_nodes_in_group("kit_room"):
		if is_ancestor_of(r):
			r.set("route", route)
	if Engine.is_editor_hint():
		return
	showcase = get_node_or_null("Showcase")
	player = KitPlayer.make()
	add_child(player)
	player.global_position = Vector4(start_at.x, 0.05, start_at.y, 0.0)
	player.set("_facing", PI)
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null:
		rig.set("slice_turning", false)
		rig.set("pitch", deg_to_rad(camera_pitch_degrees))
		rig.set("distance", camera_distance)
		rig.set("_zoom_target", camera_distance)
		rig.set("_rest_distance", camera_distance)
		rig.set("pivot_height", camera_height)
		rig.set("_home_pivot", camera_height)
		rig.call("_apply")
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Control.new()
	hud.set_script(Hud)
	layer.add_child(hud)
	hud.connect("mood_pressed", func() -> void:
		if room != null:
			room.call("toggle_mood"))
	data_panel = Control.new()
	data_panel.set_script(DataPanel)
	data_panel.set("showcase", showcase)
	layer.add_child(data_panel)
	prompt = Control.new()
	prompt.set_script(Prompt)
	prompt.set("camera", player.get_node_or_null("CameraRig/Pitch/Camera4D"))
	layer.add_child(prompt)
	tuner = PanelContainer.new()
	tuner.set_script(Tuner)
	tuner.set("room", room)
	tuner.set("spot", get_node_or_null("Downlight"))
	tuner.set("sun", get_node_or_null("Sun"))
	tuner.set("showcase", showcase)
	tuner.set("goat_room", get_node_or_null("GoatRoom"))
	layer.add_child(tuner)
	apply_mood(String(room.get("mood")) if room != null else "bright")


# -- each frame ------------------------------------------------------------------------------------

## Keeps the floor ring round the pedestal and the spot's fixture at the ceiling, when either is
## changed (the light panel's sliders, or the inspector).
func _keep_in_step() -> void:
	var sc: Node = get_node_or_null("Showcase")
	var gr: Node = get_node_or_null("GoatRoom")
	var dl: Node = get_node_or_null("Downlight")
	if sc != null and gr != null:
		var sp: Vector4 = (sc as Node4D).position
		var want := Vector3(sp.x, sp.z, float(sc.get("radius")) + 0.35)
		if gr.get("ring") != want:
			gr.set("ring", want)
	if gr != null and dl != null:
		var top: float = (gr.get("size") as Vector3).y - 0.06
		if absf(float(dl.get("fixture_at")) - top) > 0.001:
			dl.set("fixture_at", top)


func _process(delta: float) -> void:
	_keep_in_step()
	if Engine.is_editor_hint() or player == null:
		return
	if not _cine.is_empty():
		_run_cinematic(delta)
		return
	var p: Vector4 = player.global_position
	var goat_room: Node = get_node_or_null("GoatRoom")
	_in_room = goat_room != null and bool(goat_room.call("inside", p))
	if showcase != null:
		showcase.call("set_near", _in_room and bool(showcase.call("near_button", p)))
	_read_desk(delta)
	hud.set("strip", _strip())


func _strip() -> Array:
	if not _in_room or showcase == null:
		return [["WASD", "Move"], ["Mouse", "Look"], ["B", "Dark / bright"]]
	if _desk_ease > 0.5:
		return [["E", "Close the data" if _desk_open else "Check the data"], ["Wheel", "Slice through W"]]
	var out: Array = []
	if bool(showcase.call("near_button", player.global_position)):
		out.append(["Click", "Watch"])
	out.append(["Wheel", "Slice through W"])
	out.append(["Right drag", "Turn in 4D"])
	out.append(["E", String(showcase.call("action_label"))])
	return out


## Walking up to a research panel pops up a key prompt over it (kit_prompt.gd); E, the engage key,
## or a left click brings up the 2D data panel (kit_data_panel.gd), again or stepping away puts it
## away (Ramon, 4 Oct: "just you get a button that pops up when you get near, with the engage key
## stroke"; "if you see the button to open data, a left mouse click will also open it").
## The camera stays yours.
func _read_desk(_delta: float) -> void:
	var at: Node = null
	for d in get_tree().get_nodes_in_group("kit_desk"):
		if is_ancestor_of(d) and bool(d.call("near", player.global_position)):
			at = d
	if at == null:
		_desk_open = false
	_at_desk = at
	for d in get_tree().get_nodes_in_group("kit_desk"):
		if is_ancestor_of(d) and d.has_method("set_near"):
			d.call("set_near", d == at, d == at and _desk_open)
	_desk_ease = 1.0 if at != null else 0.0
	if data_panel != null:
		data_panel.set("shown", at != null and _desk_open)
	if prompt != null:
		prompt.set("shown", at != null)
		if at != null:
			prompt.set("target", at)
			prompt.set("text", "Close data" if _desk_open else "Check data")


## Opens or closes the data at the panel you stand at (a click; the runner calls it too).
func toggle_desk() -> void:
	if _at_desk != null:
		_desk_open = not _desk_open


# -- the mouse and keys ----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	var mb := event as InputEventMouseButton
	if not _cine.is_empty():
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_begin_out()
			get_viewport().set_input_as_handled()
		return
	if showcase == null or not _in_room:
		return
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			showcase.call("step_slice", 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and _at_desk != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			toggle_desk()
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and bool(showcase.call("near_button", player.global_position)) \
				and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			watch()
			get_viewport().set_input_as_handled()
			return
	var mm := event as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		showcase.call("turn_by", -mm.relative.x * 0.006, mm.relative.y * 0.006)
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or player == null or not _cine.is_empty() or showcase == null:
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_E and _at_desk != null:
		# At a research panel E engages it instead of acting on the exhibit.
		toggle_desk()
		get_viewport().set_input_as_handled()
		return
	if k != null and k.pressed and not k.echo and k.keycode == KEY_E and _in_room:
		var said: String = String(showcase.call("action"))
		if not said.is_empty():
			hud.call("toast", said)
		get_viewport().set_input_as_handled()


# -- the cinematic ---------------------------------------------------------------------------------

## Plays the showcase's shots (the runner calls this too).
func watch() -> void:
	if not _cine.is_empty() or showcase == null:
		return
	var pc: Camera4D = player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D
	if pc == null:
		return
	player.set("input_enabled", false)
	player.linear_velocity = Vector4.ZERO
	_film = pc.duplicate(0) as Camera4D
	_film.name = "CinematicCamera"
	add_child(_film)
	_film.global_position = pc.global_position
	_film.global_basis = pc.global_basis
	_film.make_current()
	showcase.call("begin_cinematic")
	var lens: float = float(pc.get("field_of_view_4d"))
	_cine = {"seqs": showcase.call("sequences"), "i": 0, "t": 0.0, "phase": "shot",
		"from_eye": pc.global_position, "from_ang": _angles_of(pc.global_basis), "from_lens": lens, "player_lens": lens}


func _angles_of(b: Projection) -> Vector2:
	var f: Vector4 = -(b * Vector4(0.0, 0.0, 1.0, 0.0))
	return Vector2(atan2(-f.x, -f.z), atan2(f.y, maxf(Vector2(f.x, f.z).length(), 0.0001)))


func _look(eye: Vector4, at: Vector4) -> Vector2:
	var d: Vector4 = at - eye
	return Vector2(atan2(-d.x, -d.z), atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001)))


func _place(eye: Vector4, ang: Vector2, lens: float) -> void:
	_film.global_position = eye
	_film.global_basis = Basis4D.from_zx(ang.x) * Basis4D.from_yz(ang.y)
	_film.set("field_of_view_4d", lens)


func _begin_out() -> void:
	_cine["phase"] = "out"
	_cine["t"] = 0.0
	_cine["from_eye"] = _film.global_position
	_cine["from_ang"] = _angles_of(_film.global_basis)
	_cine["from_lens"] = float(_film.get("field_of_view_4d"))
	hud.call("hide_caption")


func _run_cinematic(delta: float) -> void:
	_cine["t"] = float(_cine["t"]) + delta
	var t: float = float(_cine["t"])
	if String(_cine["phase"]) == "shot":
		var i: int = int(_cine["i"])
		var seqs: Array = _cine["seqs"]
		var s: Dictionary = seqs[i]
		var shot: Array = showcase.call("shot", i)
		var k: float = LabMath.ease01(t / 1.3)
		var a0: Vector2 = _cine["from_ang"]
		var a1: Vector2 = _look(shot[0], shot[1])
		var drift: Vector4 = ((shot[1] as Vector4) - (shot[0] as Vector4)).normalized() * (t * 0.12)
		_place((_cine["from_eye"] as Vector4).lerp((shot[0] as Vector4) + drift, k),
			Vector2(lerp_angle(a0.x, a1.x, k), lerpf(a0.y, a1.y, k)), lerpf(float(_cine["from_lens"]), float(shot[2]), k))
		showcase.call("play", i, t)
		hud.call("show_caption", "01  4D BASICS   ·   " + String(s["title"]), "%d / %d" % [i + 1, seqs.size()], String(s["line"]))
		if t >= float(s["length"]):
			if i + 1 < seqs.size():
				_cine["i"] = i + 1
				_cine["t"] = 0.0
				_cine["from_eye"] = _film.global_position
				_cine["from_ang"] = _angles_of(_film.global_basis)
				_cine["from_lens"] = float(_film.get("field_of_view_4d"))
			else:
				_begin_out()
		return
	var pc: Camera4D = player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D
	var k2: float = LabMath.ease01(t / 1.1)
	var b0: Vector2 = _cine["from_ang"]
	var b1: Vector2 = _angles_of(pc.global_basis)
	_place((_cine["from_eye"] as Vector4).lerp(pc.global_position, k2), Vector2(lerp_angle(b0.x, b1.x, k2), lerpf(b0.y, b1.y, k2)),
		lerpf(float(_cine["from_lens"]), float(_cine["player_lens"]), k2))
	if k2 >= 1.0:
		pc.make_current()
		_film.queue_free()
		_film = null
		_cine = {}
		player.set("input_enabled", true)
		showcase.call("end_cinematic")
