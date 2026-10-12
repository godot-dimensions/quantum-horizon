@tool
extends Node4D

## THE CREATION LAB (begun as "the goat room", renamed 5 Oct: Ramon, "goat room is essentially
## creation labs so just rename it"): one feature room, done properly, to set the style and grow
## the kit (CreationLab/kit/). Ramon, 4 Oct: "an simple entrance to walk through, and then the goat
## room ... nail the style together. and hence create the kit."
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
## CREATION LAB v2, NOW THE CREATURE LAB (9 Oct 2026; Ramon renamed it the same day: "the experience primarily
## showcases procedural animals ... rather than a general-purpose creation tool"; CreationLab/PLAN_V2.md, from Ramon's walkthrough feedback): a fork of
## creation_lab_4d.gd for creature_lab.tscn; the original lab stays as it was until Ramon says to copy this
## over. What it adds: the route laid as the Voxel Lab's and the Water Lab's (PathCreator's network on right
## angles, built in code, _build_route), R to put the exhibit back whole (the Water Lab's showcase: "R  Whole
## again"), the round pedestal's collision as three boxes following its circle (one box stood 1.6 m proud at
## the diagonals), the floor under the back door closed, and room 2 made a short entry room whose far wall is
## the Voxel Lab's hologram door into the creature hall (hall/creature_hall.tscn, its own scene).
##
## NO class_name (engine_gotchas.md).

const KitPlayer := preload("res://ramon/CreationLab/kit/kit_player.gd")
const LabMath := preload("res://ramon/CreationLab/LabKit/lab_math.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const Hud := preload("res://ramon/CreationLab/scripts/rd_hud.gd")
const Tuner := preload("res://ramon/CreationLab/kit/kit_tuner2.gd")
const DataPanel := preload("res://ramon/CreationLab/kit/kit_data_panel.gd")
const Prompt := preload("res://ramon/CreationLab/kit/kit_prompt.gd")
const SliceView := preload("res://ramon/CreationLab/kit/kit_slice_view.gd")
const Presenter := preload("res://ramon/CreationLab/kit/kit_presenter.gd")
const Plan := preload("res://ramon/CreationLab/kit/kit_room_plan.gd")
const Graph := preload("res://ramon/CreationLab/PathCreator/graph/path_graph.gd")
const Network := preload("res://ramon/CreationLab/PathCreator/graph/path_network_4d.gd")
const Target := preload("res://ramon/CreationLab/v2/lab_target_4d.gd")
const Shimmer := preload("res://ramon/CreationLab/hall/carried/vl_shimmer_4d.gd")
const LoadBoard := preload("res://ramon/CreationLab/hall/carried/vl_load_board.gd")
const Build := preload("res://ramon/CreationLab/scripts/chamber_build.gd")
## The creature hall, behind the entry room's hologram door.
const HALL := "res://ramon/CreationLab/hall/creature_hall.tscn"
## The menu's sounds in the labs: the Frontier Map's cues and music bed (Ramon, 11 Oct).
const LabSounds := preload("res://ramon/Menu/scripts/menu_lab_sounds.gd")
## Where you come back from: "hall" puts you in the entry room by the hall's door, facing room 1.
static var arrive_from: String = ""

## Where the player starts, facing -Z.
@export var start_at: Vector2 = Vector2(0.0, 15.2)
## The arrows painted into the floors, world x/z.
@export var route: PackedVector2Array = PackedVector2Array([Vector2(0, 14.6), Vector2(0, -1.5)])
## The old chevrons painted into the floor along `route` (off: the guide paths under "Guides",
## kit_path_4d.gd, show the way now).
@export var painted_route: bool = false

@export_group("Room shape")
## The room's shape from its plan (kit/kit_room_plan.gd; Ramon, 5 Oct: "change the length of the
## creationlab wall without changing the overal width of the room ... feel free to redesign the
## room modelling system"): a box (half its width, how far its entrance wall and its back wall are
## from the middle) with a corner wall cut across each back corner, each its own length and its own
## angle off its side wall. Lengthening a corner wall slides it into its corner: the box stays as it
## is, and the side wall and back wall it meets get shorter. Both corner walls at 0 m make a
## rectangle. The walls are named ("left", "left_corner" the Creation Lab wall, "back",
## "right_corner", "right" the research wall, "entrance") and what hangs on them follows by name:
## the two wall panels (always in the middle of their walls), the doorways and the sign, the first
## lesson's text, the entrance corridor with its light, the route and where you start.
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
## The Creation Lab wall: the left corner wall, carrying the introduction. Its length, and its angle
## off the left side wall (degrees).
@export_range(0.0, 20.0, 0.1) var creation_wall_length: float = 10.63:
	set(v):
		creation_wall_length = v
		_shape_later()
@export_range(5.0, 85.0, 0.5) var creation_wall_angle: float = 41.2:
	set(v):
		creation_wall_angle = v
		_shape_later()
## The right corner wall, the same way.
@export_range(0.0, 20.0, 0.1) var right_corner_length: float = 10.63:
	set(v):
		right_corner_length = v
		_shape_later()
@export_range(5.0, 85.0, 0.5) var right_corner_angle: float = 41.2:
	set(v):
		right_corner_angle = v
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
## How close to the pedestal the story plays and its text shows, m.
@export_range(2.0, 30.0, 0.5) var story_radius: float = 10.0
## The room's two walls (Ramon, 5 Oct, his Figma handoff): "panels" hangs the kit's wall panels
## (kit/panels/kit_wall_panel_4d.gd: IntroPanel on the angled left wall, ResearchBoard on the first
## wall on the right, and their copies in the review gallery); "first" puts back the first lesson
## text and the painted research wall. Both stay in the scene; this, or F1's REVIEW button, flips.
@export_enum("panels", "first") var walls: String = "panels":
	set(v):
		walls = v
		if is_inside_tree():
			set_walls(v)


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
var _shape_queued: bool = false
var _desk_open: bool = false
var _near_story: bool = false
var _compare_back: Vector4 = Vector4.INF
var presenter: Control
## The room's plan as last built (kit_room_plan.gd chamfered()).
var plan: Dictionary = {}
var _leaving: bool = false
var _route: Node4D
## The Voxel Lab's loading board on the way in (Ramon, 9 Oct: "voxel labs has cool loaders, make a loader
## based on that design when you enter this room"); true until it is gone.
var loading: bool = false
var _board: Control
var _board_t: float = 0.0


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


## The palette switch (B, or the button at the top right): the light surfaces grey or near-black, the
## lights untouched (kit_style.gd palette).
func toggle_palette() -> void:
	_sound("click")
	Style.palette = "grey" if Style.palette == "black" else "black"
	Style.apply(Style.mood)
	for n in get_tree().get_nodes_in_group("lab_mood_listener"):
		if n != self and is_ancestor_of(n) and n.has_method("apply_mood"):
			n.call("apply_mood", Style.mood, true)
	_label_switch()


func _label_switch() -> void:
	if hud != null:
		# The Voxel and Aquatic Labs' words (round 3, item 42).
		hud.set("switch_text", "DARK MODE %s  ·  B" % ("ON" if Style.palette == "black" else "OFF"))
		hud.call("refresh_switch")


func apply_mood(m: String, _instant: bool = false) -> void:
	Style.apply(m)
	if hud != null:
		hud.call("set_mood", m)


## Both corner walls from shape settings saved before the plan (half the back wall's width `b`, and
## where the angled walls began, z `c`), the room's box kept: the room comes back as it was saved.
func from_points(b: float, c: float) -> void:
	var cw: Vector2 = Plan.corner_from_points(room_half_width, room_back, b, c)
	creation_wall_length = snappedf(cw.x, 0.01)
	creation_wall_angle = snappedf(cw.y, 0.1)
	right_corner_length = creation_wall_length
	right_corner_angle = creation_wall_angle


## Every wall's length as the room is now, metres, by name.
func wall_lengths() -> Dictionary:
	return plan.get("lengths", {})


## Hangs the wall panels or the first walls (see `walls`).
func set_walls(which: String) -> void:
	var on: bool = which == "panels"
	for nm in ["IntroPanel", "ResearchBoard", "IntroPanelCopy", "ResearchBoardCopy"]:
		var n: Node = get_node_or_null(nm)
		if n != null:
			n.set("enabled", on)
	for path in ["GoatRoom/Lesson", "WallCompare/LessonCopy", "ResearchWall", "ResearchWallCopy"]:
		var n: Node = get_node_or_null(path)
		if n != null:
			n.set("enabled", not on)
	# A fresh wall for whichever prints on it now.
	for nm in ["GoatRoom", "WallCompare"]:
		var r: Node = get_node_or_null(nm)
		if r != null and r.has_method("_later"):
			r.call("_later")


func _ready() -> void:
	# The menu's sounds in the labs (Menu/scripts/menu_lab_sounds.gd): this room, with the music bed.
	if not Engine.is_editor_hint():
		LabSounds.room(self, true)
	set_walls(walls)
	apply_shape()
	var room: Node = get_node_or_null("Room")
	if room != null:
		room.set("mood_overrides", Style.ROOM_LIGHT.duplicate(true))
		room.call("set_mood", String(room.get("mood")), true, false)
	for r in get_tree().get_nodes_in_group("kit_room"):
		if is_ancestor_of(r):
			r.set("route", route if painted_route else PackedVector2Array())
	if Engine.is_editor_hint():
		return
	showcase = get_node_or_null("Showcase")
	player = KitPlayer.make()
	add_child(player)
	player.global_position = Vector4(start_at.x, 0.05, start_at.y, 0.0)
	player.set("_facing", PI)
	# The specimen picker floats on a spring: it is pushed when you walk into it (v2/picker_float_4d.gd).
	var picker: Node = get_node_or_null("ExhibitPicker")
	if picker != null:
		picker.set("player", player)
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
	# The switch and B flip the palette (grey or black); the room's light stays as it is.
	hud.connect("mood_pressed", toggle_palette)
	if room != null:
		room.set("mood_key", KEY_NONE)
	_label_switch()
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
	presenter = Control.new()
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
	layer.add_child(tuner)
	apply_mood(String(room.get("mood")) if room != null else "bright")
	_build_route()
	_close_door_floor()
	_build_hall_door()
	_pedestal_boxes.call_deferred()
	var from_hall: bool = arrive_from == "hall"
	if from_hall:
		# Inside the back door you went out by, facing into the lab (round 3: no room 2); far enough in that the
		# camera, 5 m behind you, is inside the room and not looking in through the hologram.
		go_to(Vector4(0.0, 0.05, -room_back + 5.6, 0.0), PI)
	arrive_from = ""
	_open_board(from_hall)


# -- the loading board -----------------------------------------------------------------------------

## The Voxel Lab's board (hall/carried/vl_load_board.gd) while the room comes up: the lab's blue, white
## type, what is coming, a bar for each thing the room builds, then white, and the room.
func _open_board(from_hall: bool) -> void:
	loading = true
	_board_t = 0.0
	_board = LoadBoard.open(self)
	_board.set("kicker", "QUANTUM HORIZON  ·  " + ("BACK FROM THE CREATURE SHOWCASE" if from_hall else "R&D GALLERY"))
	_board.set("title", "CREATURE LAB")
	_board.set("subtitle", "Build a 4D animal, then bring it to life")
	_board.set("coming", ["A goat on the pedestal, built ball by ball, then walking",
		"Specimens to swap on the floating panel: the goat, the chicken, the wolf",
		"Through the far door: the Creature Showcase, land and air"])
	_board.set("diagram_title", "THE ROOM, BUILT AS YOU WAIT")
	_board.connect("finished", func() -> void:
		loading = false
		_board = null
		if player != null:
			player.set("input_enabled", true))
	if player != null:
		player.set("input_enabled", false)


func _feed_board(delta: float) -> void:
	_board_t += delta
	var ex: Node = showcase.get("exhibit") if showcase != null else null
	var route_marks: int = _route.get_child_count() if _route != null else 0
	var panels: Node = get_node_or_null("IntroPanel")
	var parts: Array = [
		["The specimen", ex != null and ex.is_inside_tree() and _board_t > 0.6],
		["The route", route_marks > 0],
		["Wall panels", panels != null and panels.get_child_count() > 0],
		["The hall door", get_node_or_null("HallDoor") != null],
	]
	var bars: Array = []
	var ready: int = 0
	for p in parts:
		bars.append([p[0], 1.0 if p[1] else 0.2, "ready" if p[1] else ""])
		ready += 1 if p[1] else 0
	_board.set("bars", bars)
	var picker: Node = get_node_or_null("ExhibitPicker")
	var specimens: int = 0
	if picker != null:
		for s in (picker.get("slot_scripts") as PackedStringArray):
			specimens += 0 if s.is_empty() else 1
	_board.set("numbers", [["Specimens", str(specimens)], ["Route pieces", str(route_marks)], ["Built", "%d of %d" % [ready, parts.size()]]])
	_board.set("progress", float(ready) / float(parts.size()))
	if (ready == parts.size() and _board_t > 1.8) or _board_t > 30.0:
		_board.call("finish")
	if player != null:
		player.set("input_enabled", false)


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
	# The back wall keeps room for its door, the side walls a metre.
	plan = Plan.chamfered(w * 2.0, f, d, Vector2(creation_wall_length, creation_wall_angle), Vector2(right_corner_length, right_corner_angle),
		1.0, maxf(door_width, 0.0) + 0.8)
	var outline: PackedVector2Array = plan["outline"]
	var h: float = (gr.get("size") as Vector3).y
	_set_if(gr, "size", Vector3(w * 2.0, h, f + d))
	_set_if(gr, "wall_names", plan["names"])
	_set_if(gr, "outline", outline)
	# The doorway in the middle of the entrance wall (it runs from (w, f) to (-w, f)), and the back
	# door on the room's middle line (the back wall runs from its left end, x = outline[2].x).
	var back_len: float = float((plan["lengths"] as Dictionary)["back"])
	var bl: float = -outline[2].x
	var dw: float = minf(door_width, back_len - 0.4)
	var doors: Array = [["entrance", w - 2.2, w + 2.2, 3.8]]
	if dw > 0.1:
		doors.append(["back", bl - dw * 0.5, bl + dw * 0.5, minf(door_height, h - 0.5)])
	_set_if(gr, "doorways", doors)
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
			_set_if(r, "route", route if painted_route else PackedVector2Array())


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
		# No floor ring round the pedestal: the route's round frame is round it now.
		var want := Vector3.ZERO
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
	if _board != null:
		_feed_board(delta)
	var p: Vector4 = player.global_position
	var goat_room: Node = get_node_or_null("GoatRoom")
	_in_room = goat_room != null and bool(goat_room.call("inside", p))
	# The story plays near the pedestal only: coming within `story_radius` of it starts it once; the
	# title card and callouts show only while you are that close (Ramon, 5 Oct: "it never stops, even
	# when you're in the other room ... there should be a radius").
	var near_story: bool = _in_room and showcase != null and Vector2(p.x - showcase.global_position.x, p.z - showcase.global_position.z).length() < story_radius
	if near_story and not _near_story and showcase != null and not bool(showcase.get("armed")) and int(showcase.get("seq_index")) < 0:
		showcase.call("replay")
	_near_story = near_story
	if presenter != null:
		presenter.set("active", near_story)
	if showcase != null:
		showcase.call("set_near", _in_room and bool(showcase.call("near_button", p)))
	_read_desk(delta)
	_hall_door_check(p)
	hud.set("strip", _strip() + _menu_key())


func _strip() -> Array:
	if not _in_room or showcase == null:
		return [["WASD", "Move"], ["Mouse", "Look"], ["B", "Black / grey"]]
	if _desk_ease > 0.5:
		if _desk_open:
			return [["← → / Click", "Step through the tool"], ["E", "Close the data"]]
		return [["E / Click", "Check the data"], ["Wheel", "Slice through W"]]
	var out: Array = []
	if bool(showcase.call("near_button", player.global_position)):
		out.append(["Click", "Watch"])
	if int(showcase.get("seq_index")) >= 0:
		out.append(["Click / ← →", "Next part"])
	elif bool(showcase.call("can_skip")):
		out.append(["Click", "Play the story"])
	out.append(["Wheel", "Slice through W"])
	out.append(["Right drag", "Turn in 4D"])
	out.append(["R", "Whole again"])
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
		_sound("swipe")


# -- the mouse and keys ----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	var mb := event as InputEventMouseButton
	if not _cine.is_empty():
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_sound("click")
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
			# A click opens the data; while it is open a click steps through its four steps (E closes).
			if _desk_open:
				_sound("click")
				data_panel.call("select_step", 1)
			else:
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
			_sound("click")
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
		_sound("click")
		if not said.is_empty():
			hud.call("toast", said)
		get_viewport().set_input_as_handled()
		return
	# R: the exhibit back whole, its middle slice and its home turn (the Water Lab's showcase, "R  Whole again").
	if k != null and k.pressed and not k.echo and k.keycode == KEY_R and not k.ctrl_pressed and _in_room:
		whole_again()
		get_viewport().set_input_as_handled()
		return
	# B: the palette, grey or near-black; the light stays (Ramon, 5 Oct).
	if k != null and k.pressed and not k.echo and k.keycode == KEY_B and not k.shift_pressed and not k.ctrl_pressed:
		toggle_palette()
		get_viewport().set_input_as_handled()
		return
	# With the data open the arrow keys step through its four steps.
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_RIGHT or k.keycode == KEY_LEFT) and _desk_open and _at_desk != null:
		_sound("click")
		data_panel.call("select_step", 1 if k.keycode == KEY_RIGHT else -1)
		get_viewport().set_input_as_handled()
		return
	# The arrow keys step through the story as a click does (Ramon, 5 Oct): right on, left back.
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_RIGHT or k.keycode == KEY_LEFT) and bool(showcase.call("can_skip")):
		_sound("click")
		showcase.call("skip" if k.keycode == KEY_RIGHT else "skip_back")
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
		# An empty slot is a refusal; the animal already there says nothing.
		if s == null:
			_sound("error")
		return false
	_sound("click")
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
	_sound("select")
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
		hud.call("show_caption", "CREATURE LAB   ·   " + String(s["title"]), "%d / %d" % [i + 1, seqs.size()], String(s["line"]))
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


## The two blue walls side by side, for review (Ramon, 5 Oct: "make two separate walls next to the
## room, with the two blue panels next to each other, so I can have a clear look"): the gallery
## WallCompare beside the room carries a copy of each, on one back wall, facing the way the Creation
## Lab wall faces and under one light between them, so they are lit alike. The dev panel's button
## puts you in front of them; again, back where you were.
func toggle_compare() -> bool:
	# The wall panels' gallery is the Figma's frame 01 (both panels on one wall); the first walls'
	# is the side-by-side gallery they were reviewed in.
	var cr: Node4D = get_node_or_null("PanelGallery" if walls == "panels" else "WallCompare") as Node4D
	if cr == null or player == null:
		return false
	var rig: Node = player.get_node_or_null("CameraRig")
	if _compare_back != Vector4.INF:
		player.global_position = _compare_back
		player.linear_velocity = Vector4.ZERO
		_compare_back = Vector4.INF
		return false
	_compare_back = player.global_position
	var ol: PackedVector2Array = cr.get("outline")
	var b: Vector2 = ol[1]
	var c: Vector2 = ol[2]
	var dir: Vector2 = (c - b).normalized()
	var inward := Vector2(-dir.y, dir.x)
	# WallCompare's long wall is two edges meeting at its corner 2; PanelGallery's is three, corner 1
	# to corner 4 (each panel in the middle of its own).
	var wall_mid: Vector2 = c if cr.name == "WallCompare" else (b + ol[4]) * 0.5
	var at: Vector2 = Vector2(cr.global_position.x, cr.global_position.z) + wall_mid + inward * 11.0
	player.global_position = Vector4(at.x, 0.05, at.y, 0.0)
	player.linear_velocity = Vector4.ZERO
	var yaw: float = atan2(inward.x, inward.y)
	player.set("_facing", yaw + PI)
	if rig != null:
		rig.set("yaw", yaw)
		rig.call("_apply")
	return true


# -- v2: the route, R, the pedestal's boxes, the hall's door -----------------------------------------------

## The exhibit back whole: the middle of its slices and no turn (the runner calls this too).
func whole_again() -> void:
	if showcase == null:
		return
	_sound("click")
	var mid: int = int(showcase.get_script().get_script_constant_map().get("SLICES", 9)) / 2
	showcase.call("step_slice", mid - int(showcase.get("slice_index")))
	showcase.set("turn", Vector2.ZERO)
	hud.call("toast", "Whole again")


## The route as the newer labs lay theirs (Ramon, 9 Oct: "the clean, grid-aligned layout ... straight sections
## and 90-degree turns, without curves"): PathCreator's network over a graph built here. From the entrance
## straight down the middle to the pedestal's round frame; a crossroad on the way branches left to the
## research desk and right to the research board; from a junction in front of the pedestal a side route
## runs round its right-hand side to the back door. Every stretch along x or z.
func _build_route() -> void:
	var sc: Node4D = get_node_or_null("Showcase") as Node4D
	if sc == null:
		return
	var f: float = room_front
	var d: float = room_back
	var w: float = room_half_width
	var r: float = float(sc.get("radius"))
	var sz: float = sc.position.z
	var paths := Node4D.new()
	paths.name = "Paths"
	add_child(paths)
	var targets := Node4D.new()
	targets.name = "Targets"
	paths.add_child(targets)
	_target(targets, "Pedestal", Vector2(sc.position.x, sz), Vector3(r * 2.0 + 0.3, 1.0, r * 2.0 + 0.3))
	var desk: Node4D = get_node_or_null("ResearchPanel") as Node4D
	var desk_at := Vector2(desk.position.x + 0.6, desk.position.z) if desk != null else Vector2(-w + 0.6, 3.0)
	_target(targets, "Desk", desk_at, Vector3(1.4, 1.0, 3.6))
	_target(targets, "Board", Vector2(w - 0.25, 4.6), Vector3(0.5, 1.0, 4.4))
	_target(targets, "BackDoor", Vector2(0.0, -d - 0.25), Vector3(door_width + 0.4, 1.0, 0.6))
	var g: Resource = Graph.new()
	var cross_z: float = f - 4.6
	var front_z: float = sz + r + 1.2
	var side_x: float = r + 1.6
	var behind_z: float = sz - r - 1.4
	var s: int = g.call("add_node", "start", Vector4(0.0, 0.0, f - 0.8, 0.0), {"band": 1.2})
	var c: int = g.call("add_node", "junction", Vector4(0.0, 0.0, cross_z, 0.0), {"band": 1.2})
	var j: int = g.call("add_node", "junction", Vector4(0.0, 0.0, front_z + 1.2, 0.0), {"band": 1.2})
	var ped: int = g.call("add_node", "destination", Vector4(0.0, 0.0, front_z, 0.0),
		{"band": 1.2, "state": "available", "target": "Pedestal", "frame": "round", "approach": Vector2(0, 1)})
	# Left to the desk: across, then down to it.
	var lb: int = g.call("add_node", "bend", Vector4(desk_at.x + 1.6, 0.0, cross_z, 0.0), {"band": 1.2})
	var dk: int = g.call("add_node", "destination", Vector4(desk_at.x + 1.6, 0.0, desk_at.y + 0.2, 0.0),
		{"band": 1.2, "state": "arrival", "target": "Desk", "frame": "rect", "approach": Vector2(0, 1)})
	# Right to the board, straight across.
	var bd: int = g.call("add_node", "destination", Vector4(w - 2.0, 0.0, cross_z, 0.0),
		{"band": 1.2, "state": "arrival", "target": "Board", "frame": "rect", "approach": Vector2(-1, 0)})
	# Round the pedestal's right to the back door.
	var b1: int = g.call("add_node", "bend", Vector4(side_x, 0.0, front_z + 1.2, 0.0), {"band": 1.2})
	var b2: int = g.call("add_node", "bend", Vector4(side_x, 0.0, behind_z, 0.0), {"band": 1.2})
	var b3: int = g.call("add_node", "bend", Vector4(0.0, 0.0, behind_z, 0.0), {"band": 1.2})
	var dr: int = g.call("add_node", "destination", Vector4(0.0, 0.0, -d + 1.0, 0.0),
		{"band": 1.2, "state": "arrival", "target": "BackDoor", "frame": "rect", "approach": Vector2(0, 1)})
	g.call("add_edge", s, c)
	g.call("add_edge", c, j)
	g.call("add_edge", j, ped)
	g.call("add_edge", c, lb, "secondary")
	g.call("add_edge", lb, dk, "secondary")
	g.call("add_edge", c, bd, "secondary")
	g.call("add_edge", j, b1, "secondary")
	g.call("add_edge", b1, b2, "secondary")
	g.call("add_edge", b2, b3, "secondary")
	g.call("add_edge", b3, dr, "secondary")
	_route = Node4D.new()
	_route.name = "Route"
	_route.set_script(Network)
	_route.set("graph", g)
	_route.set("targets", NodePath("../Targets"))
	_route.set("floor_swatch", "kit_floor")
	_route.set("frame_tint", Color(0.09, 0.38, 0.843))
	# The side routes' dots small and a lighter cyan (round 3, item 26).
	_route.set("dot_size", 0.4)
	_route.set("dot_color", Color(0.55, 0.88, 1.0, 1.0))
	paths.add_child(_route)


func _target(host: Node4D, nm: String, at: Vector2, size: Vector3) -> void:
	var t := Node4D.new()
	t.name = nm
	t.set_script(Target)
	t.set("label", nm)
	t.set("size", size)
	t.position = Vector4(at.x, 0.0, at.y, 0.0)
	host.add_child(t)


## The round pedestal's collision (Ramon, 9 Oct: "the collision around the large central pedestal feels
## strange and unexpectedly rounded"): it was one box 0.3 m wider than the drum, which stood out 1.6 m past
## the round edge at the diagonals, where the drum is not. The physics engine only has boxes along the axes,
## so the circle gets three of them: a square inside it and two bars across it, together within a hand of
## the drum all round.
func _pedestal_boxes() -> void:
	var sc: Node = get_node_or_null("Showcase")
	if sc == null:
		return
	for solid in sc.find_children("PedestalSolid", "", true, false):
		var cs: CollisionShape4D = null
		for ch in solid.get_children():
			if ch is CollisionShape4D:
				cs = ch
		if cs == null or not (cs.shape is BoxShape4D):
			continue
		var old: Vector4 = (cs.shape as BoxShape4D).size
		var r: float = float(sc.get("radius")) + 0.05
		var shapes: Array = [Vector2(r * 1.42, r * 1.42), Vector2(r * 2.0, r * 0.83), Vector2(r * 0.83, r * 2.0)]
		for i in shapes.size():
			var b := BoxShape4D.new()
			b.size = Vector4(shapes[i].x, old.y, shapes[i].y, old.w)
			if i == 0:
				cs.shape = b
			else:
				var extra := cs.duplicate() as CollisionShape4D
				extra.name = "%s%d" % [cs.name, i]
				extra.shape = b
				solid.add_child(extra)


## The floor through the back doorway, the wall's thickness (room 1's floor ends at its wall's face): the
## hologram stands on it.
func _close_door_floor() -> void:
	var d: float = room_back
	Build.box(self, "DoorFloor", Vector3(0.0, -0.25, -d - 0.25), Vector3(door_width + 0.2, 0.5, 0.5), "kit_floor")


## The hologram door into the creature hall, in room 1's back door itself under the CREATURE SHOWCASE sign (round 3,
## Ramon's item 27: "no unnecessary intermediate room ... position the holographic effect within the wall's
## thickness ... align it properly with the actual doorway"): half way through the 0.5 m wall, the doorway's own
## width and height (apply_shape: door_width, door_height).
func _build_hall_door() -> void:
	var gr: Node = get_node_or_null("GoatRoom")
	var h: float = float((gr.get("size") as Vector3).y) if gr != null else 10.0
	var sh := Node4D.new()
	sh.name = "HallDoor"
	sh.set_script(Shimmer)
	sh.set("width", door_width)
	sh.set("height", minf(door_height, h - 0.5))
	sh.position = Vector4(0.0, 0.0, -room_back - 0.25, 0.0)
	add_child(sh)


## Walking into the hall's door takes you there.
func _hall_door_check(p: Vector4) -> void:
	var sh: Node4D = get_node_or_null("HallDoor") as Node4D
	if sh == null or _leaving:
		return
	if p.z < sh.position.z + 0.45 and absf(p.x) < door_width * 0.5:
		_leaving = true
		sh.call("flash_out", self, to_hall)


## Into the creature hall (its own scene: this room is let go while you are there).
func to_hall() -> void:
	_sound("select")
	player.set("input_enabled", false)
	get_tree().change_scene_to_file(HALL)


## Puts the player at `at`, standing still, facing `yaw` (the camera turned to match).
func go_to(at: Vector4, yaw: float) -> void:
	if player == null:
		return
	player.global_position = at
	player.linear_velocity = Vector4.ZERO
	player.set("_facing", yaw + PI)
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null:
		rig.set("yaw", yaw)
		rig.call("_apply")


## The menu's key, listed while this runs from the menu (its way home sits at the root,
## Menu/scripts/menu_way_home.gd; Ramon, 11 Oct: M is the menu everywhere, Esc only stops things).
func _menu_key() -> Array:
	# Tagged "menu": the lab HUD (rd_hud.gd) draws it as its own blue pill beside the strip.
	return [["M", "Menu", "menu"]] if is_inside_tree() and get_tree().root.has_node(^"WayHome") else []


## The menu's sounds in the labs (Menu/scripts/menu_lab_sounds.gd): one of the Frontier Map's cues, never in the editor.
func _sound(which: String) -> void:
	if not Engine.is_editor_hint() and is_inside_tree():
		LabSounds.cue(get_tree(), which)
