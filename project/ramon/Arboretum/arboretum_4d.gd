@tool
extends Node4D

## THE ARBORETUM: the Shrubbery Lab's remake (Ramon, 5 Oct 2026: "expand the existing tree showcase
## into three exhibits in one room ... a lofted tree with leaves, like an oak ... on a fourth
## pedestal ... the largest"; plan and handover: follow_up/arboretum.md). One 4D skeleton, four ways
## to build a tree on it, and a grove behind to see each at the scale of a wood.
##
## You come in through a short corridor under ARBORETUM, into a tall grey hall. Down its middle the
## oak stands at the far end in its pool of light between the two blue walls; the three other trees
## stand on alternating sides on the way to it: 01 voxels (left), 02 smooth voxels (right), 03 lofted
## (left). The floor route (the carried PathCreator) leads from one to the next, to the oak, and round
## it to the door of the grove.
##
## THIS NODE: the hall's shape (the carried room plan), the player (the kit's grown-up figure, the
## camera behind and above), the HUD (the control strip, the story's title card and callouts, the
## key prompt, the tree card), which pedestal you are at (the nearest within its story radius: its
## story plays once as you arrive; the wheel slides its tree through W, a right drag turns it, E
## does its action), the consoles and their cards, the guided tour (PLAY THE SHOWCASE), the route's
## states, the volume view (V) and the path builder (F4).
##
## Everything else is a node of its own in the scene: the rooms, the stations (carried showcases
## holding exhibits/ex_*.gd), the consoles, the lights, the wall panels, the paths, the grove.
##
## NO class_name (engine_gotchas.md).

const KitPlayer := preload("res://ramon/Arboretum/carried/kit/kit_player.gd")
const LabMath := preload("res://ramon/Arboretum/carried/LabKit/lab_math.gd")
const Style := preload("res://ramon/Arboretum/carried/kit/kit_style.gd")
const Hud := preload("res://ramon/Arboretum/carried/scripts/rd_hud.gd")
const Prompt := preload("res://ramon/Arboretum/carried/kit/kit_prompt.gd")
const Presenter := preload("res://ramon/Arboretum/carried/kit/kit_presenter.gd")
const Plan := preload("res://ramon/Arboretum/carried/kit/kit_room_plan.gd")
const Card := preload("res://ramon/Arboretum/room/tree_card.gd")
const Builder := preload("res://ramon/Arboretum/carried/PathCreator/builder/pc_builder.gd")
const WindScript := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")
const DevPanel := preload("res://ramon/Arboretum/room/arb_dev_panel.gd")
const Presentation := preload("res://ramon/Arboretum/carried/kit/kit_presentation.gd")

## The part of each method's story the guided tour shows.
## How far back from the entrance end of the hall's right-hand wall the water door sits.
## WaterAnnex in arboretum.tscn is placed to meet it, so the two have to agree.
const WATER_DOOR_INSET := 5.5

const TOUR_PART := {"voxel": "cells", "dc": "contour", "loft": "skin", "oak": "leaves"}

@export_group("Hall")
## The hall's plan (kit_room_plan.gd): a box (half its width, how far its entrance wall and its back
## wall are from the middle) with a corner wall cut across each back corner, where the two wall
## panels hang, either side of the oak.
@export_range(8.0, 30.0, 0.1) var room_half_width: float = 14.0:
	set(v):
		room_half_width = v
		_shape_later()
@export_range(6.0, 30.0, 0.1) var room_front: float = 16.0:
	set(v):
		room_front = v
		_shape_later()
@export_range(6.0, 40.0, 0.1) var room_back: float = 22.0:
	set(v):
		room_back = v
		_shape_later()
@export_range(0.0, 20.0, 0.1) var corner_length: float = 11.4:
	set(v):
		corner_length = v
		_shape_later()
@export_range(5.0, 85.0, 0.5) var corner_angle: float = 42.0:
	set(v):
		corner_angle = v
		_shape_later()
@export_range(6.0, 20.0, 0.1) var hall_height: float = 12.0:
	set(v):
		hall_height = v
		_shape_later()
## The grove's door, in the middle of the back wall.
@export_range(0.0, 8.0, 0.1) var door_width: float = 3.2:
	set(v):
		door_width = v
		_shape_later()
@export_range(2.0, 8.0, 0.1) var door_height: float = 4.4:
	set(v):
		door_height = v
		_shape_later()

@export_group("Grove")
@export_range(16.0, 80.0, 0.5) var grove_width: float = 40.0:
	set(v):
		grove_width = v
		_shape_later()
@export_range(16.0, 80.0, 0.5) var grove_depth: float = 36.0:
	set(v):
		grove_depth = v
		_shape_later()
@export_range(6.0, 20.0, 0.1) var grove_height: float = 12.0:
	set(v):
		grove_height = v
		_shape_later()
## How far into the grove (m) the hall's trees are hidden.
@export_range(0.0, 30.0, 0.5) var hall_hide_depth: float = 6.0
## The volume view's (V) ghost: the camera's projection_opacity_base, which the engine divides the
## projected colour by (colour / (alpha + base)), so LOWER is stronger. The engine's 1.0 left the
## trees barely there; Slice Garden uses 0.06.
@export_range(0.01, 1.0, 0.01) var volume_strength: float = 0.12

@export_group("Visit")
## Where you start (x, z), facing the oak.
@export var start_at: Vector2 = Vector2(0.0, 22.0)
## The PLAY THE SHOWCASE pad (x, z) and how near counts as standing on it.
@export var tour_pad: Vector2 = Vector2(5.2, 12.6)
@export var tour_pad_radius: float = 1.5
## How far beyond its pedestal's edge a pedestal counts as the one you are at (its story plays).
@export_range(1.0, 12.0, 0.5) var story_margin: float = 4.5

@export_group("Camera")
@export_range(2.0, 12.0, 0.1) var camera_distance: float = 5.5
@export_range(0.5, 3.5, 0.05) var camera_height: float = 2.6
@export_range(-45.0, 20.0, 0.5) var camera_pitch_degrees: float = -9.0

var player: CharacterBody4D
var hud: Control
var prompt: Control
var presenter: Control
var card: Control
var builder: Control
var dev_panel: Control
var stations: Array = []
var _hall_hidden: bool = false
var consoles: Array = []
## The pedestal you are at (a carried showcase), or null.
var active: Node = null
var plan: Dictionary = {}
var building: bool = false
var volume_view: bool = false
var _near: Dictionary = {}
var _visited: Dictionary = {}
var _at_console: Node = null
var _card_open: bool = false
var _card_t: float = 0.0
var _on_pad: bool = false
var _cine: Dictionary = {}
var _film: Camera4D
var _build_cam: Camera4D
var _mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _shape_queued: bool = false


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func _ready() -> void:
	apply_shape()
	var room: Node = get_node_or_null("Room")
	if room != null:
		room.set("mood_overrides", Style.ROOM_LIGHT.duplicate(true))
		room.call("set_mood", "bright", true, false)
		room.set("mood_key", KEY_NONE)
	Style.apply("bright")
	if Engine.is_editor_hint():
		return
	for i in 4:
		var s: Node = get_node_or_null("Station%02d" % (i + 1))
		if s != null:
			stations.append(s)
	for c in get_tree().get_nodes_in_group("arb_console"):
		if is_ancestor_of(c):
			consoles.append(c)
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
	hud.set("glass", true)
	layer.add_child(hud)
	hud.connect("mood_pressed", toggle_palette)
	_label_switch()
	presenter = Control.new()
	presenter.name = "Presenter"
	presenter.set_script(Presenter)
	presenter.set("room", self)
	layer.add_child(presenter)
	prompt = Control.new()
	prompt.set_script(Prompt)
	prompt.set("camera", player.get_node_or_null("CameraRig/Pitch/Camera4D"))
	layer.add_child(prompt)
	card = Control.new()
	card.name = "TreeCard"
	card.set_script(Card)
	layer.add_child(card)
	var dlayer := CanvasLayer.new()
	dlayer.name = "Dev"
	dlayer.layer = 5
	add_child(dlayer)
	dev_panel = PanelContainer.new()
	dev_panel.set_script(DevPanel)
	dev_panel.set("room", self)
	dlayer.add_child(dev_panel)
	var blayer := CanvasLayer.new()
	blayer.name = "Builder"
	blayer.layer = 6
	add_child(blayer)
	builder = Control.new()
	builder.set_script(Builder)
	builder.set("space", self)
	builder.visible = false
	blayer.add_child(builder)


# -- the shape ---------------------------------------------------------------------------------------

func _shape_later() -> void:
	if _shape_queued or not is_inside_tree():
		return
	_shape_queued = true
	(func() -> void:
		_shape_queued = false
		apply_shape()).call_deferred()


## The hall from its plan, the corridor in front of it and the grove room behind it.
func apply_shape() -> void:
	var hall: Node = get_node_or_null("Hall")
	if hall == null:
		return
	var w: float = room_half_width
	var f: float = room_front
	var d: float = room_back
	plan = Plan.chamfered(w * 2.0, f, d, Vector2(corner_length, corner_angle), Vector2(corner_length, corner_angle), 1.0, maxf(door_width, 0.0) + 0.8)
	var outline: PackedVector2Array = plan["outline"]
	_set_if(hall, "size", Vector3(w * 2.0, hall_height, f + d))
	_set_if(hall, "wall_names", plan["names"])
	_set_if(hall, "outline", outline)
	var back_len: float = float((plan["lengths"] as Dictionary)["back"])
	var bl: float = -outline[2].x
	var dw: float = minf(door_width, back_len - 0.4)
	var doors: Array = [["entrance", w - 2.4, w + 2.4, 4.2]]
	if dw > 0.1:
		doors.append(["back", bl - dw * 0.5, bl + dw * 0.5, minf(door_height, hall_height - 0.5)])
		# OUT ONTO THE WATER. The hall's right-hand wall, a few metres in from the entrance,
		# so it is in view as the player walks in rather than something to be hunted for.
		#
		# Measured from that edge's FIRST corner, which is its BACK end - hence the subtraction
		# from the wall's own length. It has to be set here and not in arboretum.tscn: this
		# function rewrites `doorways` wholesale on every layout pass, so a doorway set on the
		# node is discarded before the room is ever built.
		var right_len: float = float((plan["lengths"] as Dictionary).get("right", 0.0))
		if right_len > WATER_DOOR_INSET + dw:
			var centre: float = right_len - WATER_DOOR_INSET
			doors.append(["right", centre - dw * 0.5, centre + dw * 0.5,
					minf(door_height, hall_height - 0.5)])
	_set_if(hall, "doorways", doors)
	var ent: Node4D = get_node_or_null("Entrance") as Node4D
	if ent != null:
		ent.position = Vector4(0.0, 0.0, f + 7.5, 0.0)
	var grove: Node4D = get_node_or_null("GroveRoom") as Node4D
	if grove != null:
		var gz: float = -d - 0.5 - grove_depth * 0.5
		grove.position = Vector4(0.0, 0.0, gz, 0.0)
		_set_if(grove, "size", Vector3(grove_width, grove_height, grove_depth))
		_set_if(grove, "doorways", [["s", -dw * 0.5, dw * 0.5, minf(door_height, grove_height - 0.5)]] if dw > 0.1 else [])
		var g: Node = get_node_or_null("Grove")
		if g != null:
			(g as Node4D).position = Vector4(0.0, 0.0, gz, 0.0)
			_set_if(g, "area", Vector2(grove_width, grove_depth))


static func _set_if(n: Object, key: String, v: Variant) -> void:
	if n.get(key) != v:
		n.set(key, v)


## Every wall's length as the hall is now, metres, by name (the dev panel shows them).
func wall_lengths() -> Dictionary:
	return plan.get("lengths", {})


# -- looks ---------------------------------------------------------------------------------------------

## The palette switch (B, or the button at the top right): the light surfaces grey or near-black, the
## light untouched (kit_style.gd palette), as in the Creation Lab.
func toggle_palette() -> void:
	Style.palette = "grey" if Style.palette == "black" else "black"
	Style.apply(Style.mood)
	for n in get_tree().get_nodes_in_group("lab_mood_listener"):
		if n != self and is_ancestor_of(n) and n.has_method("apply_mood"):
			n.call("apply_mood", Style.mood, true)
	_label_switch()


func _label_switch() -> void:
	if hud != null:
		hud.set("switch_text", "GREY  ·  B" if Style.palette == "black" else "BLACK  ·  B")
		hud.call("refresh_switch")


func apply_mood(m: String, _instant: bool = false) -> void:
	Style.apply(m)
	if hud != null:
		hud.call("set_mood", m)


func wind() -> Node:
	return get_node_or_null("Wind")


# -- each frame ------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	if not _cine.is_empty():
		_run_tour(delta)
		return
	if building:
		return
	var p: Vector4 = player.global_position
	_find_active(p)
	_read_console(delta)
	_on_pad = Vector2(p.x - tour_pad.x, p.z - tour_pad.y).length() < tour_pad_radius
	if presenter != null:
		presenter.set("showcase", active)
		presenter.set("active", active != null and not _card_open)
	hud.set("strip", _strip())
	var g: Node = get_node_or_null("Grove")
	if g != null and g.has_method("update_player"):
		g.call("update_player", p)
		# Deep in the grove the hall's four trees are hidden, for the same reason the grove is hidden
		# from the hall (grove_4d.gd show_from): drawn is paid for, seen or not.
		var deep: bool = float(g.call("depth_inside", p)) > hall_hide_depth
		if deep != _hall_hidden:
			_hall_hidden = deep
			for s in stations:
				(s as Node4D).visible = not deep
	_route_states(p)


## The pedestal you are at: the nearest whose edge is within `story_margin`. Arriving at one plays
## its story once (as the Creation Lab's pedestal does); a click or the arrows step through it.
func _find_active(p: Vector4) -> void:
	var best: Node = null
	var best_d: float = INF
	for s in stations:
		var sp: Vector4 = (s as Node4D).global_position
		var d: float = Vector2(p.x - sp.x, p.z - sp.z).length() - float(s.get("radius"))
		var near: bool = d < story_margin
		if near and not bool(_near.get(s, false)) and not bool(s.get("armed")) and int(s.get("seq_index")) < 0:
			s.call("replay")
			_visited[stations.find(s)] = true
		# Walked well away mid-story: the tree is handed back whole, so from across the room every
		# pedestal shows its finished tree rather than a skeleton left halfway.
		if d > story_margin + 1.5 and (bool(s.get("armed")) or int(s.get("seq_index")) >= 0):
			s.call("_finish")
		_near[s] = near
		if near and d < best_d:
			best_d = d
			best = s
	active = best


func _strip() -> Array:
	if _at_console != null:
		return [["E / Click", "Close the card" if _card_open else "About this tree"], ["WASD", "Move"]]
	if _on_pad:
		return [["E / Click", "Play the showcase"], ["WASD", "Move"]]
	# Standing on the water annex's rotation ring. The strip is where this gallery says what
	# works where you stand, so the ring belongs here rather than in a label of its own - and
	# the reset is named, because it is the half of the behaviour no key reveals.
	#
	# Guarded both ways: the gallery runs perfectly well without the annex, and the question
	# is asked in the ANNEX's frame, since `is_on_rotation_point` measures from that node and
	# the annex does not sit at the origin.
	var annex: Node4D = get_node_or_null("WaterAnnex") as Node4D
	if annex != null and annex.has_method("is_on_rotation_point") and bool(
			annex.call("is_on_rotation_point", annex.global_to_local(player.global_position))):
		return [["Right drag", "Turn the slice in 4D"], ["R", "Reset the slice"],
				["G", "Gust of wind"], ["WASD", "Move"]]
	var g: Node = get_node_or_null("Grove")
	if g != null and g.has_method("is_inside") and bool(g.call("is_inside", player.global_position)):
		return [["Q / E", "Walk through W"], ["WASD", "Move"], ["G", "Gust of wind"], ["V", "Volume view" if not volume_view else "Slice view"]]
	if active == null:
		return [["WASD", "Move"], ["Mouse", "Look"], ["G", "Gust of wind"], ["B", "Black / grey"]]
	var out: Array = []
	if int(active.get("seq_index")) >= 0:
		out.append(["Click / ← →", "Next part"])
	elif bool(active.call("can_skip")):
		out.append(["Click", "Play its story"])
	out.append(["Wheel", "Slide through W"])
	out.append(["Right drag", "Turn in 4D"])
	var label: String = String(active.call("action_label"))
	if not label.is_empty():
		out.append(["E", label])
	out.append(["G", "Gust"])
	out.append(["V", "Volume view" if not volume_view else "Slice view"])
	return out


## Walking up to a console pops its key prompt; E or a click opens its tree's card, again or
## stepping away closes it.
func _read_console(delta: float) -> void:
	var at: Node = null
	for c in consoles:
		if bool(c.call("near", player.global_position)):
			at = c
	if at != _at_console:
		_card_open = false
	_at_console = at
	if prompt != null:
		prompt.set("shown", at != null)
		if at != null:
			prompt.set("target", at)
			prompt.set("text", "Close" if _card_open else "About this tree")
	_card_t -= delta
	if _card_open and at != null:
		if _card_t <= 0.0:
			_card_t = 0.25
			var st: Node = at.get_node_or_null(at.get("station")) if at.get("station") != null else null
			var ex: Node = st.get("exhibit") if st != null else null
			card.set("data", ex.call("card") if ex != null and ex.has_method("card") else {})
		card.set("shown", true)
	else:
		card.set("shown", false)


func toggle_card() -> void:
	if _at_console != null:
		_card_open = not _card_open
		_card_t = 0.0
		if _card_open:
			var st: Node = _at_console.get_node_or_null(_at_console.get("station"))
			if st != null:
				_visited[stations.find(st)] = true


# -- the route ------------------------------------------------------------------------------------------

## The route's destinations follow the visit (the sheet's rule 07): the pedestals you have seen
## completed, the next one available, the one you stand at focused.
func _route_states(p: Vector4) -> void:
	var net: Node = get_node_or_null("Paths/Hall")
	if net == null or net.get("graph") == null:
		return
	var graph: Resource = net.get("graph")
	var changed: bool = false
	var next_found: bool = false
	for i in stations.size():
		var want: String
		if _visited.has(i):
			want = "completed"
		elif not next_found:
			want = "focused" if stations[i] == active else "available"
			next_found = true
		else:
			want = "arrival"
		changed = _set_state(graph, "P%d" % (i + 1), want) or changed
	if changed:
		graph.emit_changed()


func _set_state(graph: Resource, target: String, state: String) -> bool:
	for n in graph.get("nodes"):
		if String((n as Dictionary).get("target", "")) == target and String(n.get("kind", "")) == "destination":
			if String(n.get("state", "")) != state:
				n["state"] = state
				return true
	return false


# -- the mouse and keys ------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or player == null or building:
		return
	var mb := event as InputEventMouseButton
	if not _cine.is_empty():
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_tour_next()
			get_viewport().set_input_as_handled()
		return
	if mb != null and mb.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _at_console != null:
				toggle_card()
				get_viewport().set_input_as_handled()
				return
			if _on_pad:
				watch()
				get_viewport().set_input_as_handled()
				return
			if active != null and bool(active.call("can_skip")):
				active.call("skip")
				get_viewport().set_input_as_handled()
				return
		if active != null and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			active.call("step_slice", 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			get_viewport().set_input_as_handled()
			return
	var mm := event as InputEventMouseMotion
	if mm != null and active != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		active.call("turn_by", mm.relative.x * 0.006, mm.relative.y * 0.006)
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F4:
		set_build(not building)
		get_viewport().set_input_as_handled()
		return
	if building:
		return
	if not _cine.is_empty():
		if k.keycode == KEY_ESCAPE:
			_tour_out()
			get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_E:
			if _at_console != null:
				toggle_card()
			elif _on_pad:
				watch()
			elif active != null:
				var said: String = String(active.call("action"))
				if not said.is_empty():
					hud.call("toast", said)
			else:
				return
			get_viewport().set_input_as_handled()
		KEY_B:
			if not k.shift_pressed and not k.ctrl_pressed:
				toggle_palette()
				get_viewport().set_input_as_handled()
		KEY_G:
			var w: Node = wind()
			if w != null:
				w.call("gust")
			# The same gust out on the water: the sea gets whipped up and settles again on its
			# own, taking the next sea in its list each time so repeated taps keep changing the
			# weather. Guarded, so the gallery still runs without the annex.
			#
			# `sea_name`, not `name`: a local called `name` shadows Node's own property.
			var sea: Node = get_node_or_null("WaterAnnex")
			var sea_name: String = ""
			if sea != null and sea.has_method("gust"):
				sea_name = String(sea.call("gust"))
			if w != null or not sea_name.is_empty():
				hud.call("toast", ("A gust of wind - %s" % sea_name) if not sea_name.is_empty()
						else "A gust of wind")
			get_viewport().set_input_as_handled()
		KEY_V:
			set_volume_view(not volume_view)
			hud.call("toast", "Volume view: the whole 4D tree, faintly" if volume_view else "Slice view")
			get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_LEFT:
			if active != null and bool(active.call("can_skip")):
				active.call("skip" if k.keycode == KEY_RIGHT else "skip_back")
				get_viewport().set_input_as_handled()


# -- the guided tour ------------------------------------------------------------------------------------

## PLAY THE SHOWCASE: the camera visits each pedestal while it shows its key part, then looks into
## the grove, and is handed back. A click goes on to the next shot, Esc leaves.
func watch() -> void:
	if not _cine.is_empty():
		return
	var pc: Camera4D = player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D
	if pc == null:
		return
	var shots: Array = []
	for i in stations.size():
		var s: Node = stations[i]
		var ex: Node = s.get("exhibit")
		if ex == null:
			continue
		var seqs: Array = s.call("sequences")
		var want: String = String(TOUR_PART.get(String(ex.get("method")), ""))
		var part: int = 0
		for k in seqs.size():
			if String(seqs[k]["key"]) == want:
				part = k
		var info: Dictionary = ex.call("info")
		var line: String = Presentation.fill(String(seqs[part]["line"]), s.call("numbers"))
		shots.append({"station": s, "part": part, "length": float(seqs[part]["length"]),
			"title": "%02d  ·  %s" % [i + 1, String(info.get("name", "")).to_upper()], "line": line})
	shots.append({"grove": true, "length": 6.0, "title": "THE GROVE", "line": "Behind the oak: each method again, at the scale of a wood."})
	player.set("input_enabled", false)
	player.linear_velocity = Vector4.ZERO
	_film = pc.duplicate(0) as Camera4D
	_film.name = "TourCamera"
	add_child(_film)
	_film.global_position = pc.global_position
	_film.global_basis = pc.global_basis
	_film.make_current()
	var lens: float = float(pc.get("field_of_view_4d"))
	_cine = {"shots": shots, "i": -1, "t": 0.0, "phase": "shot", "from_eye": pc.global_position, "from_ang": _angles_of(pc.global_basis),
		"from_lens": lens, "player_lens": lens}
	_tour_next()
	var g: Node = get_node_or_null("Grove")
	if g != null and g.has_method("preload_all"):
		g.call("preload_all")


func _tour_next() -> void:
	var shots: Array = _cine["shots"]
	var i: int = int(_cine["i"])
	if i >= 0 and i < shots.size() and (shots[i] as Dictionary).has("station"):
		shots[i]["station"].call("end_cinematic")
	if i + 1 >= shots.size():
		_tour_out()
		return
	_cine["i"] = i + 1
	_cine["t"] = 0.0
	_cine["from_eye"] = _film.global_position
	_cine["from_ang"] = _angles_of(_film.global_basis)
	_cine["from_lens"] = float(_film.get("field_of_view_4d"))
	var s: Dictionary = shots[i + 1]
	if s.has("station"):
		s["station"].call("begin_cinematic")
	elif s.has("grove"):
		# The grove is drawn only near its door (grove_4d.gd show_from), and you are at the pad.
		var g: Node4D = get_node_or_null("Grove")
		if g != null:
			g.visible = true
	hud.call("show_caption", "ARBORETUM   ·   " + String(s["title"]), "%d / %d" % [i + 2, shots.size()], String(s["line"]))


func _shot_of(s: Dictionary) -> Array:
	if s.has("station"):
		return s["station"].call("shot", int(s["part"]))
	# From just inside the grove's door, past the oak's crown.
	var hall_back: float = -room_back
	return [Vector4(0.0, 3.0, hall_back + 1.2, 0.0), Vector4(0.0, 2.6, hall_back - grove_depth * 0.5, 0.0), 0.95]


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


func _tour_out() -> void:
	if _cine.is_empty():
		return
	var shots: Array = _cine["shots"]
	var i: int = int(_cine["i"])
	if i >= 0 and i < shots.size() and (shots[i] as Dictionary).has("station"):
		shots[i]["station"].call("end_cinematic")
	_cine["phase"] = "out"
	_cine["t"] = 0.0
	_cine["from_eye"] = _film.global_position
	_cine["from_ang"] = _angles_of(_film.global_basis)
	_cine["from_lens"] = float(_film.get("field_of_view_4d"))
	hud.call("hide_caption")


func _run_tour(delta: float) -> void:
	_cine["t"] = float(_cine["t"]) + delta
	var t: float = float(_cine["t"])
	if String(_cine["phase"]) == "shot":
		var s: Dictionary = (_cine["shots"] as Array)[int(_cine["i"])]
		var shot: Array = _shot_of(s)
		var k: float = LabMath.ease01(t / 1.6)
		var a0: Vector2 = _cine["from_ang"]
		var a1: Vector2 = _look(shot[0], shot[1])
		var drift: Vector4 = ((shot[1] as Vector4) - (shot[0] as Vector4)).normalized() * (t * 0.1)
		_place((_cine["from_eye"] as Vector4).lerp((shot[0] as Vector4) + drift, k),
			Vector2(lerp_angle(a0.x, a1.x, k), lerpf(a0.y, a1.y, k)), lerpf(float(_cine["from_lens"]), float(shot[2]), k))
		if s.has("station"):
			s["station"].call("play", int(s["part"]), t)
		if t >= float(s["length"]):
			_tour_next()
		return
	var pc: Camera4D = player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D
	var k2: float = LabMath.ease01(t / 1.2)
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


## Whether the guided tour is running (the presenter hides while it has its own captions).
func touring() -> bool:
	return not _cine.is_empty()


# -- views and the builder --------------------------------------------------------------------------

func camera() -> Camera4D:
	return player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D if player != null else null


## The Combined renderer on the player's camera: the slice as before, and faintly everything ana and
## kata of it, so the whole 4D tree shows. The root is handed a 3D world first: switching from
## Cross-section to Combined in one run crashes the engine otherwise (PathCreator's F7, the 30 Sept
## engine bug).
func set_volume_view(on: bool) -> void:
	var cam: Camera4D = camera()
	if cam == null:
		return
	var tree: SceneTree = get_tree()
	if tree.root.world_3d == null:
		tree.root.world_3d = World3D.new()
	volume_view = on
	if on:
		_projection_trees_only()
	cam.set("rendering_engine_name", "Combined" if on else "Cross-section")
	cam.set("projection_opacity_base", volume_strength)


## The Combined renderer projects every mesh it is allowed to; projected, the room's walls, floor and
## pedestals are a haze over everything and the trees are lost in it (the first try, 6 Oct). Only the
## trees, the pedestals' and the grove's, are let into the projection (MeshInstance4D
## allow_projection, as Slice Garden's 4D sight does). Run each time, as live rebuilds add meshes.
func _projection_trees_only() -> void:
	var trees: Dictionary = {}
	for s in stations:
		var ex: Node = s.get("exhibit")
		var t: Node = ex.get("tree") if ex != null else null
		if t != null:
			trees[t] = true
	var g: Node = get_node_or_null("Grove")
	for m in find_children("*", "MeshInstance4D", true, false):
		var n: Node = m
		var keep: bool = false
		while n != null and n != self:
			if trees.has(n) or (g != null and n.get_parent() != null and String(n.get_parent().name).begins_with("Plot_")):
				keep = true
				break
			n = n.get_parent()
		(m as MeshInstance4D).set("allow_projection", keep)


## The path networks (the builder edits them).
func networks() -> Array:
	var out: Array = []
	var paths: Node = get_node_or_null("Paths")
	if paths != null:
		for c in paths.get_children():
			if c.has_method("next_library"):
				out.append(c)
	return out


## Every object a route can lead to (the builder's map).
func target_nodes() -> Array:
	var out: Array = []
	var t: Node = get_node_or_null("Paths/Targets")
	if t != null:
		for c in t.get_children():
			if c.has_method("footprint"):
				out.append(c)
	return out


## Puts the player at `at` (x, y, z, W), standing still, facing `yaw` (NAN keeps the camera's).
func go_to(at: Vector4, yaw: float = NAN) -> void:
	if player == null:
		return
	player.global_position = at
	player.set("linear_velocity", Vector4.ZERO)
	var rig: Node = player.get_node_or_null("CameraRig")
	if is_nan(yaw):
		yaw = float(rig.get("yaw")) if rig != null else PI
	player.set("_facing", yaw)
	if rig != null:
		rig.set("yaw", yaw)
		rig.call("_apply")


## F4: the path builder (the carried PathCreator's): a camera straight down over you, every route
## drawn over it, drag, add, save; F4 again to walk it.
func set_build(on: bool) -> void:
	if player == null or builder == null or on == building:
		return
	building = on
	if on:
		_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _build_cam == null:
			_build_cam = Camera4D.new()
			_build_cam.name = "BuilderCamera"
			_build_cam.set("rendering_engine_name", "Cross-section")
			_build_cam.set("projection_type", 0)
			_build_cam.set("orthographic_size", 30.0)
			add_child(_build_cam)
		var p: Vector4 = player.global_position
		_build_cam.global_position = Vector4(p.x, 40.0, p.z, p.w)
		_build_cam.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
		_build_cam.current = true
		player.process_mode = Node.PROCESS_MODE_DISABLED
		builder.set("cam", _build_cam)
		builder.call("set_slice", p.w)
		builder.call("fit")
		builder.visible = true
		builder.grab_focus()
		hud.visible = false
		presenter.visible = false
	else:
		Input.mouse_mode = _mouse_mode
		builder.visible = false
		hud.visible = true
		presenter.visible = true
		player.process_mode = Node.PROCESS_MODE_INHERIT
		var c: Camera4D = camera()
		if c != null:
			c.current = true
