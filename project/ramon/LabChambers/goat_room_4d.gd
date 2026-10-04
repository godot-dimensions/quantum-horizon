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
const SliceView := preload("res://ramon/LabChambers/kit/kit_slice_view.gd")
const Presenter := preload("res://ramon/LabChambers/kit/kit_presenter.gd")

## Where the player starts, facing -Z.
@export var start_at: Vector2 = Vector2(0.0, 15.2)
## The arrows painted into the floors, world x/z.
@export var route: PackedVector2Array = PackedVector2Array([Vector2(0, 14.6), Vector2(0, -1.5)])

@export_group("Room shape")
## The goat room's shape in five numbers (Ramon, 4 Oct: "sliders to manipulate the walls' sizes in
## this octagonal-ish room"): half its width, how far its back wall and its entrance wall are from
## the middle, half the back wall's width, and how far forward (z) the angled walls begin. The
## outline is built from them, and everything that hangs off a wall follows: the doorway and its
## sign, the lesson's text (keeping its share of its wall), the two screens on the right (flush to
## their wall), the entrance corridor with its light, the route and where you start.
@export_range(5.0, 20.0, 0.1) var room_half_width: float = 10.0:
	set(v):
		room_half_width = v
		_shape_later()
@export_range(4.0, 20.0, 0.1) var room_back: float = 9.0:
	set(v):
		room_back = v
		_shape_later()
@export_range(4.0, 20.0, 0.1) var room_front: float = 9.0:
	set(v):
		room_front = v
		_shape_later()
@export_range(1.0, 10.0, 0.1) var back_wall_half: float = 3.0:
	set(v):
		back_wall_half = v
		_shape_later()
@export_range(-15.0, 15.0, 0.1) var corner_z: float = -1.0:
	set(v):
		corner_z = v
		_shape_later()
## The door in the middle of the back wall, into the big square room behind (Ramon, 4 Oct: "a
## door opening behind the goat that leads in to a new room, just a much bigger square room";
## "customizable"). 0 wide: no door.
@export_range(0.0, 8.0, 0.1) var door_width: float = 2.4:
	set(v):
		door_width = v
		_shape_later()
@export_range(2.0, 8.0, 0.1) var door_height: float = 3.6:
	set(v):
		door_height = v
		_shape_later()

## The control strip, the toasts and the mood switch in the lab's dark glass (kit_style.gd); off
## puts back the strip that follows the mood (light in bright, dark in dark).
@export var glass_hud: bool = true

## Room 2, the big room behind the back door (Ramon, 4 Oct: "size attributes for room 2, and one
## large spot in the middle which will need to light the whole giant room"): its width, depth and
## height; its spot (BigSpot) stays over its middle with its fixture on the ceiling.
@export_range(10.0, 80.0, 0.5) var big_room_width: float = 30.0:
	set(v):
		big_room_width = v
		_shape_later()
@export_range(10.0, 80.0, 0.5) var big_room_depth: float = 30.0:
	set(v):
		big_room_depth = v
		_shape_later()
@export_range(4.0, 24.0, 0.1) var big_room_height: float = 10.0:
	set(v):
		big_room_height = v
		_shape_later()

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
var tuner_room2: PanelContainer
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
var _shape_queued: bool = false
var _desk_open: bool = false


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func apply_mood(m: String, _instant: bool = false) -> void:
	Style.apply(m)
	if hud != null:
		hud.call("set_mood", m)


func _ready() -> void:
	apply_shape()
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
	# The lab's one style: the control strip, the toasts and the mood switch in dark glass.
	hud.set("glass", glass_hud)
	layer.add_child(hud)
	hud.connect("mood_pressed", func() -> void:
		if room != null:
			room.call("toggle_mood"))
	data_panel = Control.new()
	data_panel.set_script(DataPanel)
	data_panel.set("showcase", showcase)
	layer.add_child(data_panel)
	var slice_view := Control.new()
	slice_view.name = "SliceView"
	slice_view.set_script(SliceView)
	slice_view.set("showcase", showcase)
	layer.add_child(slice_view)
	# The presentation on screen: a title card as each part begins, its callouts as it plays.
	var presenter := Control.new()
	presenter.name = "Presenter"
	presenter.set_script(Presenter)
	presenter.set("showcase", showcase)
	presenter.set("room", self)
	layer.add_child(presenter)
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
	tuner.set("shape_root", self)
	# Room 2's own panel, on the right.
	var tuner2 := PanelContainer.new()
	tuner2.set_script(Tuner)
	tuner2.set("panel", "room2")
	tuner2.set("room", room)
	tuner2.set("spot", get_node_or_null("BigSpot"))
	tuner2.set("shape_root", self)
	layer.add_child(tuner2)
	tuner_room2 = tuner2
	layer.add_child(tuner)
	apply_mood(String(room.get("mood")) if room != null else "bright")


# -- each frame ------------------------------------------------------------------------------------

func _shape_later() -> void:
	if _shape_queued or not is_inside_tree():
		return
	_shape_queued = true
	(func() -> void:
		_shape_queued = false
		apply_shape()).call_deferred()


## Builds the room's outline from the five numbers and moves what hangs off its walls.
func apply_shape() -> void:
	var gr: Node = get_node_or_null("GoatRoom")
	if gr == null:
		return
	var w: float = room_half_width
	var f: float = room_front
	var d: float = room_back
	var b: float = minf(back_wall_half, w - 0.5)
	var c: float = clampf(corner_z, -d + 0.5, f - 1.0)
	var outline := PackedVector2Array([Vector2(-w, f), Vector2(-w, c), Vector2(-b, -d), Vector2(b, -d), Vector2(w, c), Vector2(w, f)])
	var h: float = (gr.get("size") as Vector3).y
	_set_if(gr, "size", Vector3(w * 2.0, h, f + d))
	_set_if(gr, "outline", outline)
	# The doorway in the middle of the entrance wall (edge 5 runs from (w, f) to (-w, f)), and the
	# back door in the middle of the back wall (edge 2 runs from (-b, -d) to (b, -d)).
	var dw: float = minf(door_width, b * 2.0 - 0.4)
	var doors: Array = [[5, w - 2.2, w + 2.2, 3.8]]
	if dw > 0.1:
		doors.append([2, b - dw * 0.5, b + dw * 0.5, minf(door_height, h - 0.5)])
	_set_if(gr, "doorways", doors)
	# The big room behind it, its own front wall just behind the back wall, a door to match.
	var big: Node4D = get_node_or_null("BigRoom") as Node4D
	if big != null:
		var bz: float = -d - 1.0 - big_room_depth * 0.5
		big.position = Vector4(0.0, 0.0, bz, 0.0)
		_set_if(big, "size", Vector3(big_room_width, big_room_height, big_room_depth))
		_set_if(big, "doorways", [["s", -dw * 0.5, dw * 0.5, minf(door_height, minf(h, big_room_height) - 0.5)]] if dw > 0.1 else [])
		var bs: Node4D = get_node_or_null("BigSpot") as Node4D
		if bs != null:
			var by: float = minf(bs.position.y, big_room_height - 0.3)
			if bs.position.x != 0.0 or absf(bs.position.z - bz) > 0.001 or bs.position.y != by:
				bs.position = Vector4(0.0, by, bz, 0.0)
			_set_if(bs, "aim", Vector3(0.0, 0.0, bz))
			_set_if(bs, "fixture_at", big_room_height - 0.06)
	var sign: Node = gr.get_node_or_null("Sign")
	if sign != null:
		_set_if(sign, "along", Vector2(w - 3.8, w + 3.8))
	# The lesson keeps its share of the angled wall on the left (edge 1).
	var lesson: Node = gr.get_node_or_null("Lesson")
	if lesson != null:
		var len1: float = outline[1].distance_to(outline[2])
		_set_if(lesson, "along", Vector2(snappedf(len1 * 0.094, 0.01), snappedf(len1 * 0.903, 0.01)))
	# The research wall stays flush to its wall (its `wall_edge`: the first wall on the right, edge 4),
	# facing into the room; painted, it is printed into that wall itself.
	for nm in ["ResearchWall"]:
		var panel: Node4D = get_node_or_null(nm) as Node4D
		if panel == null:
			continue
		var we: int = int(panel.get("wall_edge")) if panel.get("wall_edge") != null else 3
		var a: Vector2 = outline[we % outline.size()]
		var e: Vector2 = outline[(we + 1) % outline.size()]
		var dir: Vector2 = (e - a).normalized()
		var inward := Vector2(-dir.y, dir.x)
		var mid: Vector2 = (a + e) * 0.5 + inward * 0.13
		panel.position = Vector4(mid.x, panel.position.y, mid.y, 0.0)
		panel.set("face", Vector3(inward.x, 0.0, inward.y))
	# The entrance corridor and its light sit outside the entrance wall.
	var ent: Node4D = get_node_or_null("Entrance") as Node4D
	if ent != null:
		ent.position = Vector4(0.0, 0.0, f + 7.5, 0.0)
	var el: Node4D = get_node_or_null("EntranceLight") as Node4D
	if el != null:
		el.position = Vector4(0.0, el.position.y, f + 3.5, 0.0)
		el.set("aim", Vector3(0.0, 0.0, f + 3.5))
	# The arrows run on under the pedestal and vanish there.
	route = PackedVector2Array([Vector2(0.0, f + 5.6), Vector2(0.0, -1.5)])
	start_at = Vector2(0.0, f + 6.2)
	for r in get_tree().get_nodes_in_group("kit_room"):
		if is_ancestor_of(r):
			_set_if(r, "route", route)


## Sets a property only when it changes: each change rebuilds a room, and rebuilding one that is
## still printing its walls wastes the print.
static func _set_if(n: Object, key: String, v: Variant) -> void:
	if n.get(key) != v:
		n.set(key, v)


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
	if int(showcase.get("seq_index")) >= 0:
		out.append(["Click", "Next part"])
	elif bool(showcase.call("can_skip")):
		out.append(["Click", "Play from the start"])
	out.append(["Wheel", "Slice through W"])
	out.append(["Right drag", "Turn in 4D"])
	out.append(["E", String(showcase.call("action_label"))])
	out.append(["1 to 6", "Specimen"])
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
		if (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
		# While the presentation plays, a left click goes on to its next part (Ramon, 4 Oct: "skip
		# to the next sequence by pressing left mouse button").
		if mb.button_index == MOUSE_BUTTON_LEFT and bool(showcase.call("can_skip")) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			showcase.call("skip")
			get_viewport().set_input_as_handled()
			return
	var mm := event as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		showcase.call("turn_by", mm.relative.x * 0.006, mm.relative.y * 0.006)
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
		return
	# 1 to 6: another animal on the plinth, from the specimen picker's slots (Ramon, 4 Oct: "press
	# 1, is goat. press 2, and you get the same presentation for the chicken").
	if k != null and k.pressed and not k.echo and k.keycode >= KEY_1 and k.keycode <= KEY_6:
		pick(int(k.keycode - KEY_1))
		get_viewport().set_input_as_handled()


## Puts slot `i`'s animal on the plinth (the runner calls this too). False for an empty slot or the
## animal already there.
func pick(i: int) -> bool:
	var picker: Node = get_node_or_null("ExhibitPicker")
	var s: Script = picker.call("choose", i) if picker != null else null
	if s == null or s == showcase.get("exhibit_script"):
		return false
	showcase.call("set_exhibit", s)
	var names: PackedStringArray = picker.get("slot_names")
	if i < names.size():
		hud.call("toast", "%s on the plinth" % names[i].capitalize())
	return true


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
