@tool
extends Node4D

## THE BOTANY LAB (fork of arboretum_4d.gd, 9 Oct; plan in follow_up/arboretum.md section 7): Ramon's
## walkthrough, part 1: the Arboretum brought in line with the Voxel Lab and the Aquatic Lab. On the
## newer carried kit (botany_lab/carried/: the Aquatic Lab's, with the Voxel Lab's showcase, doorway and
## loading board): the playable world's walk, the dev HUD on Tab (the lights' editor and the artist
## panel), a raised corridor. The grove is gone from this scene: the back door leads to the second
## room, its own scene (botany_lab/compare/). arboretum.tscn and arboretum_4d.gd are untouched.
##
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

const KitPlayer := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_player.gd")
const LabMath := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_math.gd")
const Ground := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/carried/chickenpen/scripts/ground_basis_4d.gd")
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")
const Hud := preload("res://ramon/Arboretum/botany_lab/carried/scripts/rd_hud.gd")
const Prompt := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_prompt.gd")
const Presenter := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_presenter.gd")
const Plan := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_room_plan.gd")
const Builder := preload("res://ramon/Arboretum/botany_lab/carried/PathCreator/builder/pc_builder.gd")
const WindScript := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")
const DevPanel := preload("res://ramon/Arboretum/botany_lab/room/bl_dev_panel.gd")
const LightEditor := preload("res://ramon/Arboretum/botany_lab/room/bl_light_editor.gd")
const PenWalk := preload("res://ramon/Arboretum/botany_lab/pen_walk.gd")
const Shimmer := preload("res://ramon/Arboretum/botany_lab/carried/voxel_lab/vl_shimmer_4d.gd")
## The second room (plan steps 66-76): its own scene, through the holographic doorway in the back wall.
const COMPARE := "res://ramon/Arboretum/botany_lab/compare/botany_compare.tscn"
## Round 3: the flower room, its own scene (Ramon, 10 Oct: "the flower room should be its own tscn with
## transporter door"), through the holographic doorway in the hall's right wall.
const FLOWERS := "res://ramon/Arboretum/botany_lab/flowers/flower_room.tscn"
const Border := preload("res://ramon/Arboretum/botany_lab/room/bl_border_4d.gd")
const Drift := preload("res://ramon/Arboretum/botany_lab/flora/flora_drift_4d.gd")
const Air := preload("res://ramon/Arboretum/botany_lab/flora/flora_air_4d.gd")
const Mats := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_grid.gd")
const FloraSpecies := preload("res://ramon/Arboretum/botany_lab/flora/flora_species.gd")
const Sprigs := preload("res://ramon/Arboretum/botany_lab/flora/flora_sprigs_4d.gd")
const Grass := preload("res://ramon/Arboretum/botany_lab/carried/grass/bl_grass_4d.gd")
const LabPrint := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd")
const ARRIVE_META := "botany_arrive"
const Presentation := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_presentation.gd")

## The part of each method's story the guided tour shows.
const TOUR_PART := {"voxel": "cells", "dc": "contour", "loft": "skin", "oak": "leaves"}
## The tour's timing (round 2, Ramon: "Synchronize the camera movement with the actual generation ...
## Make sure the camera stays on the completed model long enough"): the flight onto a shot comes first
## and the tree grows only once the camera is there; the shot ends `TOUR_HOLD` seconds after the
## exhibit says its geometry has all arrived ("done"), never on a timer while it is still growing
## (`TOUR_GIVE_UP` past the part's own length is only a safety net).
const TOUR_ARRIVE := 1.8
const TOUR_HOLD := 3.5
const TOUR_GIVE_UP := 12.0
## How far the camera circles the tree while it grows and holds (radians), so the branching reads in
## depth instead of drifting toward it.
const TOUR_ORBIT := 0.45
## The tour's own angle per method: [eye, look] from the pedestal's deck middle, and the lens. The parts'
## own angles were made for standing at the pedestal, and in the tour (frames of 9 Oct,
## smoke_test_output/botany_lab/showcase/) they sat low behind the next pedestal, the subject half out of
## the picture. Now each of 01 to 03 is seen side on from the hall's middle aisle, against its own side
## wall, far enough back for the whole tree (4.3 m on its deck); the oak from the front, the back wall
## behind it.
const TOUR_SHOT := {
	"voxel": [Vector4(6.3, 1.7, 0.8, 0.0), Vector4(0.0, 2.1, 0.0, 0.0), 0.9],
	"dc": [Vector4(6.3, 1.7, 0.8, 0.0), Vector4(0.0, 2.1, 0.0, 0.0), 0.9],
	"loft": [Vector4(6.3, 1.7, 0.8, 0.0), Vector4(0.0, 2.1, 0.0, 0.0), 0.9],
	"oak": [Vector4(0.6, 2.6, 9.2, 0.0), Vector4(0.0, 3.6, 0.0, 0.0), 0.95],
}

@export_group("Hall")
## The hall's plan (kit_room_plan.gd): a box (half its width, how far its entrance wall and its back
## wall are from the middle) with a corner wall cut across each back corner, where the two wall
## panels hang, either side of the oak.
@export_range(8.0, 30.0, 0.1) var room_half_width: float = 12.0:
	set(v):
		room_half_width = v
		_shape_later()
## Round 5 (Ramon, #35: "Give the new flower corner enough room. Reduce unnecessary empty width elsewhere ...
## Avoid awkward wall intersections"): the right side's own half width (0: the same as the left). The right
## wall comes in; its corner wall keeps its angle and still meets the back wall where it did, so the back
## wall and its door stay on the spine. The left keeps its width for the flowers in its entrance corner.
## Round 6 (Ramon, #47: "Move the existing blue wall on the right side 5 meters to the left"): 5.5.
@export_range(0.0, 30.0, 0.1) var room_right_width: float = 5.5:
	set(v):
		room_right_width = v
		_shape_later()
## Round 6 (#50: "Maintain approximately 3 meters between the first tree showcase platform and the adjacent wall"):
## 01's platform ends at z 9.1, so the entrance wall stands at 12.1.
@export_range(6.0, 30.0, 0.1) var room_front: float = 12.1:
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
## Round 6 (#45: "Replace the irregular rear wall with one continuous, flat wall. Use the furthest existing rear wall
## plane as the reference"): a plain rectangle, the back wall across the whole width at `room_back` (its back wall's
## plane before), the side walls run on to it; the corner walls (corner_length, corner_angle) are not built.
@export var rect_room: bool = true:
	set(v):
		rect_room = v
		_shape_later()
## The grove's door in the back wall: round 6 (#48: "Position the doorway 3 meters from the left side of the back
## wall"), `door_from_left` metres from the left wall's inner face to the opening's near edge.
@export_range(0.0, 20.0, 0.1) var door_from_left: float = 3.0:
	set(v):
		door_from_left = v
		_shape_later()
@export_range(0.0, 8.0, 0.1) var door_width: float = 3.2:
	set(v):
		door_width = v
		_shape_later()
@export_range(2.0, 8.0, 0.1) var door_height: float = 4.4:
	set(v):
		door_height = v
		_shape_later()
## The arrival corridor's ceiling and the entrance doorway into the hall (Ramon, 9 Oct: "Raise the
## ceiling slightly in the arrival corridor to create a more spacious entrance"; it was 6 m and 4.2 m).
@export_range(4.5, 11.0, 0.1) var corridor_height: float = 7.5:
	set(v):
		corridor_height = v
		_shape_later()
@export_range(3.5, 8.0, 0.1) var entrance_height: float = 5.0:
	set(v):
		entrance_height = v
		_shape_later()

@export_group("Views")
## The volume view's (V) ghost: the camera's projection_opacity_base, which the engine divides the
## projected colour by (colour / (alpha + base)), so LOWER is stronger. The engine's 1.0 left the
## trees barely there; Slice Garden uses 0.06.
@export_range(0.01, 1.0, 0.01) var volume_strength: float = 0.12

@export_group("Visit")
## Where you start (x, z), facing the oak.
@export var start_at: Vector2 = Vector2(0.0, 22.0)
## The PLAY THE SHOWCASE pad (x, z) and how near counts as standing on it.
## (Round 5: on the right, the flowers having the left corner by the entrance.)
## (Round 6: back on the left, between the entrance wall and 01, the flowers taking the right of the path; smaller,
## the entrance strip being 3 m deep.)
@export var tour_pad: Vector2 = Vector2(-3.0, 10.6)
@export var tour_pad_radius: float = 1.1
## Round 3: the flower room's door, in the right wall at this z; the roof open to the sky. Round 4 (Ramon:
## "Remove the newly added ceiling lines and decorative roof structures"; "I don't think we need the
## separate Flower Room in the active experience ... Preserve the existing Flower Room TSCN"): the
## ceiling back, and the flower room shelved behind `flower_room_open` (its scene kept; the wall whole).
@export var flower_door_z: float = -3.0
@export var roof_open: bool = false
@export var flower_room_open: bool = false
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
var light_editor: Control
var stations: Array = []
var _hall_hidden: bool = false
var consoles: Array = []
## The floating panels (plan step 28: the Aquatic Lab's, beside each ring; the pad's), the one you
## are at (within `panel_reach`), and how near counts.
var panels: Array = []
var _at_panel: Node = null
@export var panel_reach: float = 1.7
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
var _leaving: bool = false
## Round 3: the flower border (room/bl_border_4d.gd), the planter you are at in it ({} when none) and the
## species its caption names.
var border: Node4D
var _at_border: Dictionary = {}
var _border_caption: String = ""
var _border_key: String = ""


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func _ready() -> void:
	apply_shape()
	# Round 8 (Ramon: "for dark mode exclusively, can you push the spotlights in this room 40% brighter?"): the
	# spots in the black palette (kit_style.gd spot_black; the dev panel's "Spots in dark mode" row tunes it).
	Style.spot_black = DARK_SPOTS
	var room: Node = get_node_or_null("Room")
	if room != null:
		room.set("mood_overrides", _garden_light())
		room.call("set_mood", "bright", true, false)
		room.set("mood_key", KEY_NONE)
	Style.apply("bright")
	_garden_palette()
	if Engine.is_editor_hint():
		return
	for i in 4:
		var s: Node = get_node_or_null("Station%02d" % (i + 1))
		if s != null:
			stations.append(s)
	for c in get_children():
		if String(c.name).begins_with("Panel") and c.has_method("activate"):
			panels.append(c)
	player = KitPlayer.make()
	player.name = "Player"
	# The playable world's walk (Andrew's walker's own values, Q/E stepping through W): pen_walk.gd.
	PenWalk.apply(player)
	add_child(player)
	player.global_position = Vector4(start_at.x, 0.05, start_at.y, 0.0)
	player.set("_facing", PI)
	var arrived: String = String(get_tree().root.get_meta(ARRIVE_META, ""))
	var from_compare: bool = arrived == "compare"
	var from_flowers: bool = arrived == "flowers"
	get_tree().root.remove_meta(ARRIVE_META)
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
	for pn in panels:
		pn.set("player", player)
	var dlayer := CanvasLayer.new()
	dlayer.name = "Dev"
	dlayer.layer = 5
	add_child(dlayer)
	dev_panel = PanelContainer.new()
	dev_panel.set_script(DevPanel)
	dev_panel.set("room", self)
	dlayer.add_child(dev_panel)
	# Tab: the dev HUD, the lights' editor on the right (the Aquatic Lab's) with the artist panel on the
	# left; F1 opens the same.
	light_editor = PanelContainer.new()
	light_editor.name = "LightEditor"
	light_editor.set_script(LightEditor)
	light_editor.set("room", self)
	light_editor.set("own_key", false)
	# (Round 8: its lights under "hall." in the lights' file, which the second room shares.)
	light_editor.set("section_prefix", "hall.")
	dlayer.add_child(light_editor)
	# The back door: the Voxel Lab's holographic doorway, the opening exactly, just inside the wall.
	var sh := Node4D.new()
	sh.name = "Shimmer"
	sh.set_script(Shimmer)
	# Round 4 (14): in the middle of the wall's thickness (the kit's walls are 0.5 m), the opening's size.
	sh.set("width", door_width)
	sh.set("height", minf(door_height, hall_height - 0.5) - 0.01)
	sh.position = Vector4(back_door_x(), 0.0, -room_back - 0.25, 0.0)
	add_child(sh)
	if from_compare:
		# Back from the second room: just inside the back door, facing into the hall.
		go_to.call_deferred(Vector4(back_door_x(), 0.05, -room_back + 2.4, 0.0), PI)
		Shimmer.flash_in(self)
	# Round 3: the flower room's door, the same holographic doorway turned to the right wall.
	if flower_room_open:
		var fs := Node4D.new()
		fs.name = "FlowerShimmer"
		fs.set_script(Shimmer)
		fs.set("width", door_width)
		fs.set("height", minf(door_height, hall_height - 0.5) - 0.01)
		fs.position = Vector4(room_half_width + 0.25, 0.0, flower_door_z, 0.0)
		fs.basis = Basis4D.from_zx(PI * 0.5)
		add_child(fs)
	if from_flowers and flower_room_open:
		# Back from the flower room: just inside its door, facing into the hall.
		go_to.call_deferred(Vector4(room_half_width - 2.4, 0.05, flower_door_z, 0.0), PI * 0.5)
		Shimmer.flash_in(self)
	_build_garden()
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


## The hall from its plan and the corridor in front of it (its height and the entrance doorway's).
func apply_shape() -> void:
	var hall: Node = get_node_or_null("Hall")
	if hall == null:
		return
	var w: float = room_half_width
	var wr: float = room_right_width if room_right_width > 0.0 else w
	var f: float = room_front
	var d: float = room_back
	plan = Plan.chamfered(w * 2.0, f, d, Vector2(corner_length, corner_angle), Vector2(corner_length, corner_angle), 1.0, maxf(door_width, 0.0) + 0.8)
	var outline: PackedVector2Array = plan["outline"]
	if rect_room:
		outline = PackedVector2Array([Vector2(-w, f), Vector2(-w, -d), Vector2(wr, -d), Vector2(wr, f)])
		var rnames := PackedStringArray(["left", "back", "right", "entrance"])
		var rl: Dictionary = {}
		for i in rnames.size():
			rl[rnames[i]] = outline[i].distance_to(outline[(i + 1) % rnames.size()])
		plan = {"outline": outline, "names": rnames, "lengths": rl}
	elif not is_equal_approx(wr, w):
		# The right side at its own width: its corner wall from where the back wall ends, at the same angle.
		var run_x: float = maxf(wr - outline[3].x, 0.0)
		var run_z: float = run_x / tan(deg_to_rad(clampf(corner_angle, 1.0, 89.0)))
		outline[4] = Vector2(wr, -d + run_z)
		outline[5] = Vector2(wr, f)
		var lengths: Dictionary = {}
		var names: PackedStringArray = plan["names"]
		for i in names.size():
			lengths[names[i]] = outline[i].distance_to(outline[(i + 1) % names.size()])
		plan["outline"] = outline
		plan["lengths"] = lengths
	_set_if(hall, "size", Vector3(w + wr, hall_height, f + d))
	_set_if(hall, "wall_names", plan["names"])
	_set_if(hall, "outline", outline)
	var back_len: float = float((plan["lengths"] as Dictionary)["back"])
	var bl: float = -outline[2].x
	var dw: float = minf(door_width, back_len - 0.4)
	# (The entrance wall runs from the right wall's end: the spine is `wr` along it.)
	var doors: Array = [["entrance", wr - 2.4, wr + 2.4, minf(entrance_height, corridor_height - 0.4)]]
	if dw > 0.1 and rect_room:
		# Along the back wall from its left end.
		doors.append(["back", door_from_left, door_from_left + dw, minf(door_height, hall_height - 0.5)])
	elif dw > 0.1:
		doors.append(["back", bl - dw * 0.5, bl + dw * 0.5, minf(door_height, hall_height - 0.5)])
	# Round 3: the flower room's door in the right wall (its edge runs from the right corner's end, +z).
	if flower_room_open:
		var fa: float = flower_door_z - outline[4].y
		doors.append(["right", fa - door_width * 0.5, fa + door_width * 0.5, minf(door_height, hall_height - 0.5)])
	_set_if(hall, "doorways", doors)
	_set_if(hall, "ceiling", not roof_open)
	# Round 8 (#59: "Position Two Gardens above the holographic doorway at the far end of the main room. Center it
	# relative to the doorway"): the two signs on the rectangle's walls, from its shape. TWO GARDENS on the back
	# wall over the back door, centred on it (round 6 had left it on the edge that became the right wall); BOTANY
	# LAB outside over the entrance, centred on the spine. Along is the edge's own, from its start, on either face
	# (rd_build.gd print_wall turns it round for the outer one): the entrance wall starts at the right wall, so the
	# spine is `wr` along it.
	if rect_room:
		var ds: Node = hall.get_node_or_null("DoorSign")
		if ds != null and dw > 0.1:
			var dm: float = door_from_left + dw * 0.5
			_set_if(ds, "edge", 1)
			_set_if(ds, "along", Vector2(maxf(dm - DOOR_SIGN_HALF, 0.2), minf(dm + DOOR_SIGN_HALF, back_len - 0.2)))
		var es2: Node = hall.get_node_or_null("Sign")
		if es2 != null:
			_set_if(es2, "edge", 3)
			_set_if(es2, "along", Vector2(wr - ENTRANCE_SIGN_HALF, wr + ENTRANCE_SIGN_HALF))
	var ent: Node4D = get_node_or_null("Entrance") as Node4D
	if ent != null:
		ent.position = Vector4(0.0, 0.0, f + 7.5, 0.0)
		var es: Vector3 = ent.get("size")
		_set_if(ent, "size", Vector3(es.x, corridor_height, es.z))


## The spots' gain in dark mode (the black palette), against the grey's.
const DARK_SPOTS := 1.4
## Half the length of the sign over the back door and of the one over the entrance, m (as they were).
const DOOR_SIGN_HALF := 3.77
const ENTRANCE_SIGN_HALF := 4.4


## The back door's middle (x): in the middle of the back wall, or (round 6) `door_from_left` from the left wall.
func back_door_x() -> float:
	return -room_half_width + door_from_left + door_width * 0.5 if rect_room else 0.0


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
	_garden_palette()
	for n in get_tree().get_nodes_in_group("lab_mood_listener"):
		if n != self and is_ancestor_of(n) and n.has_method("apply_mood"):
			n.call("apply_mood", Style.mood, true)
	_label_switch()


## Round 3 (Ramon: "make it aesthetically pleasing. dreamy and impressive"): the hall under an open sky, a
## soft blue afternoon through the roof's frame, its walls a cool blue-grey and its floor warm pale stone, so
## the trees' warm pools and the border's colours carry the room instead of the lab's grey grid. Only the
## grey palette (B keeps the black one as it was); every other scene's Style.apply puts the kit's back.
func _garden_light() -> Dictionary:
	var light: Dictionary = Style.ROOM_LIGHT.duplicate(true)
	var b: Dictionary = light["bright"]
	b["sky_top"] = Color(0.26, 0.42, 0.7)
	b["sky_horizon"] = Color(0.82, 0.74, 0.7)
	b["sky_bottom"] = Color(0.5, 0.48, 0.5)
	b["ambient"] = Color(0.3, 0.33, 0.4)
	b["ambient_sky"] = 0.15
	b["key_color"] = Color(1.0, 0.9, 0.76)
	b["key_energy"] = 0.62
	b["key_elevation"] = 52.0
	b["fill_color"] = Color(0.7, 0.8, 1.0)
	b["fill_energy"] = 0.12
	return light


func _garden_palette() -> void:
	if Style.palette == "black":
		return
	LabGrid.set_swatch("kit_wall", Color(0.47, 0.53, 0.64), Color(0.41, 0.47, 0.58), Color(0.45, 0.51, 0.62), 0.35)
	LabGrid.set_swatch("kit_floor", Color(0.74, 0.71, 0.66), Color(0.66, 0.63, 0.58), Color(0.71, 0.68, 0.63), 0.3)


func _label_switch() -> void:
	if hud != null:
		hud.set("switch_text", "GREY  ·  B" if Style.palette == "black" else "BLACK  ·  B")
		hud.call("refresh_switch")


func apply_mood(m: String, _instant: bool = false) -> void:
	Style.apply(m)
	_garden_palette()
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
	_read_panels()
	# Through the right wall's shimmer: a flash, then the flower room.
	if flower_room_open and not _leaving and p.x > room_half_width - 0.35 and absf(p.z - flower_door_z) < door_width * 0.5:
		_leaving = true
		player.set("input_enabled", false)
		var fsh: Node = get_node_or_null("FlowerShimmer")
		if fsh != null:
			fsh.call("flash_out", self, to_flowers)
		else:
			to_flowers()
	_border_near(p)
	if Engine.get_process_frames() % 30 == 0 and not _specimen_prints.is_empty():
		_specimen_check()
	# Round 5: by the flowers the camera comes in (they are small beside the trees), and goes back after.
	var at_flowers: bool = border != null and active == null and bool(border.call("near", p))
	if at_flowers != _flower_cam:
		_flower_cam = at_flowers
		var rig: Node = player.get_node_or_null("CameraRig")
		if rig != null:
			rig.set("_zoom_target", FLOWER_CAMERA if at_flowers else camera_distance)
	# Through the back door's shimmer: a flash, then the second room.
	if not _leaving and p.z < -room_back + 0.35 and absf(p.x - back_door_x()) < door_width * 0.5:
		_leaving = true
		player.set("input_enabled", false)
		var sh: Node = get_node_or_null("Shimmer")
		if sh != null:
			sh.call("flash_out", self, to_compare)
		else:
			to_compare()
	_on_pad = Vector2(p.x - tour_pad.x, p.z - tour_pad.y).length() < tour_pad_radius
	if presenter != null:
		presenter.set("showcase", active)
		presenter.set("active", active != null)
	hud.set("strip", _strip())
	# Q/E steps through W (the pen's walk) except where E is taken: a pedestal, a console, the pad.
	player.set("w_walk_enabled", active == null and _at_panel == null and not _on_pad and _at_border.is_empty())
	_route_states(p)


## The pedestal you are at: the nearest whose edge is within `story_margin`. Its finished tree stands
## on its turntable; a click plays its story, and the arrows step through it. (Round 2, Ramon: "Load
## the finished, static tree models by default ... Avoid running expensive generation sequences for
## every tree during normal exploration": arriving no longer plays the story, as it did since round 1.)
func _find_active(p: Vector4) -> void:
	var best: Node = null
	var best_d: float = INF
	for s in stations:
		var sp: Vector4 = (s as Node4D).global_position
		var d: float = Vector2(p.x - sp.x, p.z - sp.z).length() - float(s.get("radius"))
		var near: bool = d < story_margin
		if near and not bool(_near.get(s, false)):
			_visited[stations.find(s)] = true
		# Walked well away mid-story: the tree is handed back whole, so from across the room every
		# pedestal shows its finished tree rather than a skeleton left halfway.
		if d > story_margin + 1.5 and (bool(s.get("armed")) or int(s.get("seq_index")) >= 0):
			s.call("_finish")
		# Turned and left: put back as it stood (plan step 39), so the next visitor finds it upright and
		# on its middle slice.
		if d > story_margin + 1.5 and (s.get("turn_basis") != Projection.IDENTITY or int(s.get("slice_index")) != 4):
			s.call("reset_view")
		_near[s] = near
		if near and d < best_d:
			best_d = d
			best = s
	# Round 5: the flowers stand in the corner by 01, inside its story margin; by them (nearer their pots than
	# the pedestal's edge) they are yours, not the tree's.
	if best != null and border != null and bool(border.call("near", p)) and float(border.call("footprint_distance", p)) < best_d:
		best = null
	active = best


func _strip() -> Array:
	if _at_panel != null:
		if bool(_at_panel.get_node("Words").get("tour")):
			return [["E / Click", "Play the showcase"], ["WASD", "Move"]]
		return [["E / Click", "More about it" if int(_at_panel.get("page_index")) < 0 else "Next page"], ["WASD", "Move"]]
	if _on_pad:
		return [["E / Click", "Play the showcase"], ["WASD", "Move"]]
	if active == null and border != null and bool(border.call("near", player.global_position)):
		# Round 5: the flowers slide and tip through W (bl_border_4d.gd), no longer turned about their stems.
		var bo: Array = [["WASD", "Move"], ["Wheel", "Slide them through W"], ["Right drag", "Slide (forward, back), tip (sideways)"]]
		if not _at_border.is_empty():
			bo.push_front(["E / Click", "About this flower"])
		if bool(border.call("moved")):
			bo.append(["%+.0f cm, %+.0f°" % [float(border.get("slide_w")) * 100.0, rad_to_deg(float(border.get("tip")))], "through W"])
			bo.append(["R", "Back in the slice"])
		bo.append(["G", "Gust of wind"])
		return bo
	if active == null:
		return [["WASD", "Move"], ["Mouse", "Look"], ["Q / E", "Step through W"], ["G", "Gust of wind"], ["B", "Black / grey"]]
	var out: Array = []
	if int(active.get("seq_index")) >= 0:
		# Round 4: in a growing part (the oak's), the first click speeds it up.
		var ex: Node = active.get("exhibit")
		var seqs: Array = active.call("sequences")
		var si: int = int(active.get("seq_index"))
		var grows: bool = ex != null and ex.has_method("accelerates") and si < seqs.size() and bool(ex.call("accelerates", String(seqs[si]["key"])))
		if grows and float(active.get("speed")) <= 1.0:
			out.append(["Click", "Faster"])
			out.append(["← →", "Next part"])
		else:
			out.append(["Click / ← →", "Next part"])
	elif bool(active.call("can_skip")):
		out.append(["Click", "Play its story"])
	out.append(["Wheel", "Slide through W"])
	out.append(["Right drag", "Turn in 4D"])
	if active.get("turn_basis") != Projection.IDENTITY or int(active.get("slice_index")) != 4:
		# How far it is turned, as it turns (round 2: the turn has no limit now, so it says where it is).
		var tilt: float = rad_to_deg(Ground.tilt(active.get("turn_basis")))
		if tilt > 0.5:
			out.append(["%d°" % int(round(tilt)), "turned through W"])
		out.append(["R", "Whole again"])
	var label: String = String(active.call("action_label"))
	if not label.is_empty():
		out.append(["E", label])
	out.append(["G", "Gust"])
	out.append(["V", "Volume view" if not volume_view else "Slice view"])
	return out


## Walking up to a floating panel lights it (its hint shows) and pops the key prompt; E or a click turns
## its pages (the pad's plays the showcase). Walking away puts it back on its face.
func _read_panels() -> void:
	var p: Vector4 = player.global_position
	var at: Node = null
	var best: float = panel_reach
	for pn in panels:
		var pp: Vector4 = (pn as Node4D).global_position
		var d: float = Vector2(p.x - pp.x, p.z - pp.z).length()
		if d < best:
			best = d
			at = pn
	if at != _at_panel and _at_panel != null and int(_at_panel.get("page_index")) >= 0:
		_at_panel.set("page_index", -1)
		_at_panel.call("_read")
	_at_panel = at
	for pn in panels:
		pn.call("set_near", pn == at)
	if prompt != null:
		prompt.set("shown", at != null)
		if at != null:
			prompt.set("target", at)
			var tour: bool = bool(at.get_node("Words").get("tour"))
			prompt.set("text", "Play the showcase" if tour else ("More about it" if int(at.get("page_index")) < 0 else "Next page"))


## E or a click at a panel: its next page, or the showcase from the pad's.
func use_panel() -> void:
	if _at_panel == null:
		return
	if bool(_at_panel.get_node("Words").get("tour")):
		watch()
		return
	_at_panel.call("activate")
	var st: Node = get_node_or_null(_at_panel.get_node("Words").get("station"))
	if st == null:
		st = _at_panel.get_node("Words").get_node_or_null(_at_panel.get_node("Words").get("station"))
	if st != null:
		_visited[stations.find(st)] = true


# -- the route ------------------------------------------------------------------------------------------

## The route's destinations follow the visit (the sheet's rule 07), the Voxel Lab's way: the pedestal
## you stand at focused (cyan), the ones you have been to and left completed, the next one available,
## the rest arrival; the pad completed once stood on; the door available once all four are seen.
## (The Arboretum marked a pedestal completed the moment you arrived, so its ring turned the
## completed grey under your feet and the focused cyan was never seen.)
func _route_states(_p: Vector4) -> void:
	var net: Node = get_node_or_null("Paths/Hall")
	if net == null or net.get("graph") == null:
		return
	var graph: Resource = net.get("graph")
	if _on_pad:
		_visited["Tour"] = true
	var changed: bool = false
	var next_found: bool = false
	for i in stations.size():
		var want: String
		if stations[i] == active:
			want = "focused"
		elif _visited.has(i):
			want = "completed"
		elif not next_found:
			want = "available"
			next_found = true
		else:
			want = "arrival"
		changed = _set_state(graph, "P%d" % (i + 1), want) or changed
	changed = _set_state(graph, "Tour", "completed" if _visited.has("Tour") else "available") or changed
	changed = _set_state(graph, "Door", "arrival" if next_found else "available") or changed
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
	if Engine.is_editor_hint() or player == null:
		return
	# Tab here, before the GUI (Ramon: "when i press tab, it opens, but i cant close it with tab again"): it was
	# read in _unhandled_key_input, and once a slider or field on the open panel had focus, the GUI took Tab
	# to move its focus on and it never reached the room.
	var tk := event as InputEventKey
	if tk != null and tk.pressed and not tk.echo and tk.keycode == KEY_TAB:
		toggle_dev()
		get_viewport().set_input_as_handled()
		return
	if building:
		return
	var mb := event as InputEventMouseButton
	if not _cine.is_empty():
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_tour_next()
			get_viewport().set_input_as_handled()
		return
	if mb != null and mb.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			# Round 4 (11): at the border a click opens the flower's caption, and closes it again.
			if _at_panel == null and active == null and not _on_pad and not _at_border.is_empty():
				if _border_caption.is_empty():
					open_flower()
				else:
					close_flower()
				get_viewport().set_input_as_handled()
				return
			if _at_panel != null:
				use_panel()
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
		# Round 5: by the flowers the wheel slides them through W, 6 mm a step.
		if active == null and border != null and bool(border.call("near", player.global_position)) and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			border.call("slide_by", 0.006 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.006)
			get_viewport().set_input_as_handled()
			return
	var mm := event as InputEventMouseMotion
	if mm != null and active != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		active.call("turn_by", mm.relative.x * 0.006, mm.relative.y * 0.006)
		get_viewport().set_input_as_handled()
	elif mm != null and active == null and border != null and bool(border.call("near", player.global_position)) and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		border.call("turn_by", mm.relative.x * 0.006, mm.relative.y * 0.006)
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
			if _at_panel == null and active == null and not _on_pad and not _at_border.is_empty():
				if _border_caption.is_empty():
					open_flower()
				else:
					close_flower()
				get_viewport().set_input_as_handled()
				return
			if _at_panel != null:
				use_panel()
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
		KEY_R:
			# The tree as it stood: upright, its middle slice (the Voxel Lab's reset_view).
			if active != null:
				active.call("reset_view")
				hud.call("toast", "Back as it stood")
				get_viewport().set_input_as_handled()
			elif border != null and bool(border.call("near", player.global_position)):
				border.call("level")
				hud.call("toast", "The flowers upright and back in your slice")
				get_viewport().set_input_as_handled()
		KEY_G:
			var w: Node = wind()
			if w != null:
				w.call("gust")
				hud.call("toast", "A gust of wind")
			get_viewport().set_input_as_handled()
		KEY_V:
			set_volume_view(not volume_view)
			hud.call("toast", "Volume view: the whole 4D tree, faintly" if volume_view else "Slice view")
			get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_LEFT:
			if active != null and bool(active.call("can_skip")):
				if k.keycode == KEY_RIGHT:
					active.call("skip", true)
				else:
					active.call("skip_back")
				get_viewport().set_input_as_handled()


## Round 3, the garden in the hall (follow_up/arboretum.md section 9, steps 34-39): the flower border down
## the right side (room/bl_border_4d.gd), the air its flowers feel (flora/flora_air_4d.gd), leaves on the
## wind from the oak's crown toward the door (flora/flora_drift_4d.gd, the pen's flying leaves carried:
## "maybe the wind creates some leaves in the wind"), and the open roof's frame.
func _build_garden() -> void:
	border = Node4D.new()
	border.name = "Border"
	border.set_script(Border)
	add_child(border)
	var air := Node.new()
	air.name = "Air"
	air.set_script(Air)
	air.set("wind", wind())
	add_child(air)
	var oak: Node4D = get_node_or_null("Station04") as Node4D
	var src: Vector4 = oak.position if oak != null else Vector4(0.0, 0.0, -13.5, 0.0)
	# Round 4 (8; Ramon: "too intense ... sometimes extending toward the opposite end of the room"): a few,
	# small, in a box of air round the crown (wrapped there, so none leaves it), from high up.
	var leaves := Node4D.new()
	leaves.name = "OakLeaves"
	leaves.set_script(Drift)
	leaves.set("stream", false)
	leaves.set("box_centre", Vector2(src.x, src.z))
	leaves.set("box_size", Vector2(9.0, 9.0))
	leaves.set("floor_y", 1.2)
	leaves.set("top_y", 8.5)
	leaves.set("amount", 120)
	leaves.set("gust_extra", 1.0)
	leaves.set("leaf_share", 0.7)
	leaves.set("leaf_size", 0.035)
	leaves.set("bit_size", 0.01)
	leaves.set("colours", PackedColorArray([Color(0.5, 0.62, 0.2), Color(0.86, 0.68, 0.22), Color(0.74, 0.4, 0.16), Color(1.0, 0.9, 0.62)]))
	leaves.set("wind", wind())
	add_child(leaves)
	if roof_open:
		_roof_frame()
	_meadows()
	_oak_grass()
	_specimen_walls.call_deferred()
	# Every new mesh's 3D proxy built now, not on its first draw (round 2's lesson: the hall's arrival
	# hitches were first draws; round 3's perf2 showed one 28-34 ms frame at three arrivals again).
	(func() -> void:
		var seen: Dictionary = {}
		for mi in find_children("*", "MeshInstance4D", true, false):
			var m: Mesh4D = (mi as MeshInstance4D).mesh
			if m != null and not seen.has(m.get_instance_id()):
				seen[m.get_instance_id()] = true
				m.get_proxy_mesh_3d()).call_deferred()


## A meadow on every planter's soil (the pen's grass trick, flora/flora_sprigs_4d.gd: blades drawn where your
## slice crosses them, each with a home in W) with wildflowers in it, and tufts in the border's planters, so
## each tree stands in a garden of its own rather than on a disc.
func _meadows() -> void:
	var s := Node4D.new()
	s.name = "Meadows"
	s.set_script(Sprigs)
	s.set("w_radius", 0.8)
	s.set("wind", wind())
	s.set("colours", {"blade": [Color(0.26, 0.44, 0.16), Color(0.5, 0.62, 0.24)], "petal": [Color(0.98, 0.97, 0.94), Color(1.0, 0.84, 0.28)],
		"floret": [Color(0.62, 0.5, 0.86), Color(0.92, 0.88, 0.98)]})
	add_child(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1013
	var beds: Array = []
	# Round 4 (5, 7): the three technical specimens stand on flat green, and the oak on the pen's own grass
	# (_oak_grass); these sprigs are only the border's tufts now.
	if border != null:
		for pl in border.get("planters"):
			var n4: Node4D = pl["node"]
			beds.append([Vector3(n4.position.x, float(border.get("height")) + 0.02, n4.position.z), float(border.get("soil_radius")) - 0.04, false, 0.0])
	for bed in beds:
		var c: Vector3 = bed[0]
		var r: float = bed[1]
		var square: bool = bed[2]
		var clear: float = bed[3]
		var area: float = (r * 2.0) * (r * 2.0) if square else PI * r * r
		for k in mini(int(area * 160.0), 9000):
			var p: Vector2
			if square:
				p = Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
			else:
				var a: float = rng.randf() * TAU
				p = Vector2(cos(a), sin(a)) * r * sqrt(rng.randf())
			if p.length() < clear:
				continue
			var at := Vector3(c.x + p.x, c.y, c.z + p.y)
			var lean := (Vector3.UP + Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))).normalized()
			s.call("add", Sprigs.BLADE, at, lean, Vector3(lean.z, 0.0, -lean.x), rng.randf_range(0.12, 0.34), rng.randf(), 1.0, rng.randf_range(-1.4, 1.4))
		# Wildflowers among it: white and yellow five-petalled heads on a stalk, now and then a lilac spike.
		for k in mini(int(area * 5.0), 300):
			var a: float = rng.randf() * TAU
			var p := Vector2(cos(a), sin(a)) * r * sqrt(rng.randf())
			if square:
				p = Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
			if p.length() < clear:
				continue
			var hgt: float = rng.randf_range(0.14, 0.3)
			var base := Vector3(c.x + p.x, c.y, c.z + p.y)
			var home: float = rng.randf_range(-1.4, 1.4)
			s.call("add", Sprigs.STEM, base, Vector3.UP, Vector3.FORWARD, hgt, 0.5, 0.6, home)
			var head: Vector3 = base + Vector3.UP * hgt
			if rng.randf() < 0.2:
				for j in 6:
					s.call("add", Sprigs.FLORET, head - Vector3.UP * (float(j) * 0.018), Vector3(rng.randf_range(-1, 1), 0.3, rng.randf_range(-1, 1)).normalized(), Vector3.UP, 0.02, rng.randf(), 0.6, home)
			else:
				var pick: float = 0.2 if rng.randf() < 0.6 else 0.8
				for q in 5:
					var ang: float = TAU * float(q) / 5.0
					s.call("add", Sprigs.PETAL, head, Vector3(cos(ang), 0.15, sin(ang)).normalized(), Vector3.UP, 0.018, pick, 0.6, home)
	s.call("commit")


## The open roof's frame: dark beams across the walls' tops (the hall a glasshouse with its glass out, as
## the flower room is: the engine draws no glass), the sky between them.
func _roof_frame() -> void:
	var holder := Node4D.new()
	holder.name = "RoofFrame"
	add_child(holder)
	var mat: TetraMaterial4D = Mats.flat(Color(0.14, 0.15, 0.17))
	var y: float = hall_height + 0.1
	for z in [13.0, 7.0, 1.0, -5.0, -11.0, -17.0]:
		# Across the hall at z, as wide as it is there (narrower past the back corners).
		var half_w: float = room_half_width
		if z < -room_back + corner_length * sin(deg_to_rad(corner_angle)) + 0.01:
			var c0: Vector2 = Vector2(-room_half_width, -13.528)
			var c1: Vector2 = Vector2(-6.372, -room_back)
			var outline: PackedVector2Array = (get_node_or_null("Hall") as Node).get("outline")
			if outline.size() >= 3:
				c0 = outline[1]
				c1 = outline[2]
			var k: float = clampf((z - c0.y) / (c1.y - c0.y), 0.0, 1.0)
			half_w = -lerpf(c0.x, c1.x, k)
		var m := MeshInstance4D.new()
		m.mesh = Mats.box_mesh(Vector4(half_w * 2.0, 0.26, 0.16, 6.0))
		m.position = Vector4(0.0, y, z, 0.0)
		m.material_override = mat
		holder.add_child(m)
	for x in [-5.0, 5.0]:
		var m := MeshInstance4D.new()
		m.mesh = Mats.box_mesh(Vector4(0.16, 0.22, room_front + room_back - 3.0, 6.0))
		m.position = Vector4(x, y + 0.02, (room_front - room_back) * 0.5 - 1.0, 0.0)
		m.material_override = mat
		holder.add_child(m)


## Where in the border you are (the planter within its reach, when no pedestal is yours). Round 4 (11;
## Ramon: "Stop opening the full information overlay automatically through proximity alone ... Make sure
## the overlay can be dismissed reliably"): near a planter a small key prompt only; E (or a click) opens
## its caption, and E, a click or walking away closes it.
func _border_near(p: Vector4) -> void:
	_at_border = border.call("nearest", p) if border != null and active == null and _at_panel == null else {}
	if not _cine.is_empty():
		return
	var key: String = String(_at_border.get("key", ""))
	if key != _border_key:
		_border_key = key
		# Walked to another planter or away: whatever was open closes.
		if not _border_caption.is_empty():
			close_flower()
	if not key.is_empty() and prompt != null and _border_caption.is_empty():
		prompt.set("target", _at_border["node"])
		prompt.set("text", "About this flower")
		prompt.set("offset", Vector4(0.0, 1.25, 0.0, 0.0))
		prompt.set("shown", true)


## The planter you are at: its caption, its common and Latin names and what is 4D about it.
func open_flower() -> void:
	var key: String = String(_at_border.get("key", ""))
	if key.is_empty():
		return
	_border_caption = key
	var sp: Dictionary = FloraSpecies.by_key(key)
	hud.call("show_caption", String(sp["name"]).to_upper(), String(sp["latin"]), String(sp["line"]))
	if prompt != null:
		prompt.set("shown", false)


func close_flower() -> void:
	if _border_caption.is_empty():
		return
	_border_caption = ""
	hud.call("hide_caption")


## Round 4 (7; Ramon: "the Oak should retain actual grass. Reuse the attractive grass implementation from the
## Playable World"): the pen's grass (carried/grass/bl_grass_4d.gd, through the Voxel Lab's copy) on the
## oak's green platform. Its ground is the platform's flat top, so its height grid is filled here directly
## (the platform's disc, a clearing round the trunk) rather than baked from a mesh. Shorter and finer than
## the island's meadow; deep enough in W for the crown.
var oak_grass: Node4D


func _oak_grass() -> void:
	var oak: Node4D = get_node_or_null("Station04") as Node4D
	if oak == null:
		return
	var r: float = float(oak.get("radius")) - 0.24
	var top: float = float(oak.get("height")) + 0.02
	var c: Vector4 = oak.position
	var half: float = r + 0.25
	var cells: int = int(ceil(half * 2.0 / Grass.CELL))
	var rect := Vector4(c.x - half, c.z - half, Grass.CELL, float(cells))
	var w_reach: float = 1.2
	var wl := Vector3(-w_reach - 1.0, Grass.DW, (w_reach + 1.0) * 2.0 / Grass.DW + 1.0)
	var layers: int = int(wl.z)
	var heights := PackedFloat32Array()
	heights.resize(cells * cells * layers)
	for l in layers:
		for j in cells:
			for i in cells:
				var x: float = rect.x + (float(i) + 0.5) * Grass.CELL
				var z: float = rect.y + (float(j) + 0.5) * Grass.CELL
				var d: float = Vector2(x - c.x, z - c.z).length()
				heights[(l * cells + j) * cells + i] = top if d < r and d > 0.5 else Grass.NONE
	oak_grass = Node4D.new()
	oak_grass.name = "OakGrass"
	oak_grass.set_script(Grass)
	oak_grass.set("coverage", 1.0)
	oak_grass.set("w_reach", w_reach)
	oak_grass.set("height_m", 0.34)
	oak_grass.set("width_scale", 1.6)
	oak_grass.set("radius", 24.0)
	oak_grass.set("band_radii", [7.0, 14.0])
	add_child(oak_grass)
	oak_grass.set("player", player)
	oak_grass.call("start", heights, rect, wl, top)


## Round 4 (Ramon, on the white titles: "the white descrips on the wall look very dry. maybe make a rectangle
## with heads and some subtext. and the bracket more or less the size of the showcase so that it feels it
## corresponds. and in the blue wall style"): behind each of 01 to 03, on the grey wall, a blue panel as wide
## as its pedestal and, as every blue backing in the lab, floor to ceiling. Above the tree's crown, its
## number, its name, its method's line and how its tree was grown, white, inside corner brackets like the
## pedestals' decals.
const SPECIMEN_WALLS := [
	{"station": "Station01", "number": "01", "title": "VOXELS", "kicker": "THE SHRUBBERY LAB'S METHOD",
		"line": "Grown by shrubbery's rules; every cell a branch passes through is filled."},
	{"station": "Station02", "number": "02", "title": "SMOOTH VOXELS", "kicker": "THE ENGINE'S OWN VOXEL WORLD",
		"line": "The same skeleton, one smooth surface run through it."},
	{"station": "Station03", "number": "03", "title": "LOFTED", "kicker": "OUR LOFT TOOL",
		"line": "The same skeleton, lofted branch by branch."},
]
## The panels' text, metres up the wall (over the crowns, under the ceiling).
const SPECIMEN_TEXT_Y := Vector2(5.2, 8.0)


##
## ROUND 5 (Ramon, #34: "Left wall: Remove the three decorative blue stripes. Make this wall a continuous blue
## surface instead"): the panels are no longer slabs on a grey wall. Each claims its stretch of the left wall
## (the kit room's claim: the whole wall goes code blue, split where each panel's words begin and end), and
## its words are printed into that piece of the wall itself, as the wall panels are. The wall's pieces are
## made again whenever the room rebuilds, so the prints are looked at twice a second and put back if a
## rebuild took them (_specimen_check).
var _specimen_prints: Array = []
## The camera's distance by the flowers (round 5), and whether it is there now.
const FLOWER_CAMERA := 2.9
var _flower_cam: bool = false


func _specimen_walls() -> void:
	var hall: Node = get_node_or_null("Hall")
	if hall == null:
		return
	var holder := Node4D.new()
	holder.name = "SpecimenWalls"
	add_child(holder)
	var spans: Array = []
	for spec in SPECIMEN_WALLS:
		var st: Node4D = get_node_or_null(String(spec["station"])) as Node4D
		if st == null:
			continue
		var w: float = float(st.get("radius")) * 2.0 + 0.2
		# Along the left wall: from its corner at the entrance (z room_front) toward the back.
		var mid: float = room_front - st.position.z
		var claimer := Node.new()
		claimer.name = "Claim_" + String(spec["number"])
		holder.add_child(claimer)
		hall.call("claim_wall", "left", "blue", claimer, mid - w * 0.5, mid + w * 0.5)
		spans.append([spec, mid - w * 0.5, mid + w * 0.5, w])
	# The wall is rebuilt with its new pieces a frame or two later.
	await get_tree().process_frame
	await get_tree().process_frame
	var ppm: float = 220.0
	var th: float = SPECIMEN_TEXT_Y.y - SPECIMEN_TEXT_Y.x
	for sp in spans:
		var spec: Dictionary = sp[0]
		var tex: Texture2D = await LabPrint.render(get_tree(), Vector2i(int(float(sp[3]) * ppm), int(th * ppm)), func(c: Control) -> void: _specimen_page(c, spec))
		if tex != null:
			_specimen_prints.append([tex, float(sp[1]), float(sp[2])])
	_specimen_check()


## Each specimen's words on its piece of the left wall, put back if the room's rebuild took them.
func _specimen_check() -> void:
	var hall: Node = get_node_or_null("Hall")
	if hall == null:
		return
	for pr in _specimen_prints:
		for tg in hall.call("print_targets", "left", float(pr[1]), float(pr[2]), SPECIMEN_TEXT_Y.x, SPECIMEN_TEXT_Y.y):
			var m: TetraMaterial4D = (tg[0] as MeshInstance4D).material_override as TetraMaterial4D
			if m == null:
				continue
			var cs: ShaderMaterial = m.get_cross_section_material_3d()
			if cs.get_shader_parameter("print_texture") == pr[0]:
				continue
			LabGrid.set_print(m, pr[0], tg[1], tg[2], Color.WHITE, 0.25)
			LabGrid.set_print_strength(m, 1.0)
			cs.set_shader_parameter("print_aa", 1.0)


## A specimen panel's text: white on clear (the panel's blue shows), corner brackets round it.
func _specimen_page(c: Control, spec: Dictionary) -> void:
	var sz: Vector2 = c.size
	var u: float = sz.y / 616.0
	var white := Color(1, 1, 1, 1)
	var soft := Color(1, 1, 1, 0.82)
	var x: float = 70.0 * u
	c.draw_string(LabPrint.font("bold"), Vector2(x, 120.0 * u), String(spec["kicker"]), HORIZONTAL_ALIGNMENT_LEFT, sz.x - x * 2.0, int(30 * u), soft)
	c.draw_string(LabPrint.font("black"), Vector2(x, 250.0 * u), String(spec["number"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(120 * u), white)
	var black: Font = LabPrint.font("black")
	var nw: float = black.get_string_size(String(spec["number"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(120 * u)).x
	# The name as large as fits beside the number (a long one steps down, never clipped).
	var room: float = sz.x - x * 2.0 - nw - 34.0 * u
	var px: int = int(84 * u)
	for k in 12:
		if black.get_string_size(String(spec["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= room:
			break
		px = int(float(px) * 0.9)
	c.draw_string(black, Vector2(x + nw + 34.0 * u, 250.0 * u), String(spec["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, white)
	c.draw_line(Vector2(x, 300.0 * u), Vector2(sz.x - x, 300.0 * u), Color(1, 1, 1, 0.45), maxf(1.0, 3.0 * u))
	c.draw_multiline_string(LabPrint.font("body"), Vector2(x, 370.0 * u), String(spec["line"]), HORIZONTAL_ALIGNMENT_LEFT, sz.x - x * 2.0, int(40 * u), 4, soft)
	# The corner brackets (the pedestals' decals).
	var arm: float = 60.0 * u
	var tk: float = maxf(2.0, 5.0 * u)
	var pad: float = 26.0 * u
	for cx in [pad, sz.x - pad]:
		var dir: float = 1.0 if cx < sz.x * 0.5 else -1.0
		for cy in [pad, sz.y - pad]:
			var dy: float = 1.0 if cy < sz.y * 0.5 else -1.0
			c.draw_line(Vector2(cx, cy), Vector2(cx + arm * dir, cy), white, tk)
			c.draw_line(Vector2(cx, cy), Vector2(cx, cy + arm * dy), white, tk)


## The flower room (its own scene, its own loading board).
func to_flowers() -> void:
	get_tree().root.set_meta(ARRIVE_META, "hall")
	get_tree().change_scene_to_file(FLOWERS)


## The second room (its own scene, built behind its loading board).
func to_compare() -> void:
	get_tree().change_scene_to_file(COMPARE)


## Tab (or F1): the dev HUD, the lights' editor and the artist panel together; the mouse is freed while
## it is open and captured again after (the editor's own open and close do that).
func toggle_dev() -> void:
	var on: bool = not (light_editor != null and light_editor.visible)
	if light_editor != null:
		light_editor.call("open" if on else "close")
	if dev_panel != null:
		dev_panel.visible = on
	# Closed: whatever slider or field had focus lets go, so the keys are the walk's again.
	if not on and get_viewport() != null:
		get_viewport().gui_release_focus()


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
		shots.append({"station": s, "part": part, "length": float(seqs[part]["length"]), "method": String(ex.get("method")),
			"title": "%02d  ·  %s" % [i + 1, String(info.get("name", "")).to_upper()], "line": line, "done_at": -1.0})
	# Round 3: the tour as a short film. It opens down the hall's middle toward the oak and the leaves on
	# its wind, and closes along the flower border to the flower room's door.
	# (Round 6: the hall shorter, the oak at -2, -12.5, the flowers in two rows right of the path.)
	var oak_at: Vector4 = (get_node_or_null("Station04") as Node4D).position if get_node_or_null("Station04") != null else Vector4(-2.0, 0.0, -12.5, 0.0)
	shots.push_front({"scenic": true, "eye0": Vector4(0.0, 2.3, room_front - 1.2, 0.0), "eye1": Vector4(0.0, 2.7, 3.5, 0.0),
		"look0": oak_at + Vector4(0.0, 3.2, 0.0, 0.0), "look1": oak_at + Vector4(0.0, 3.8, 0.0, 0.0), "length": 6.5, "lens": 0.95,
		"title": "THE GARDEN HALL", "line": "Four ways to grow a tree in 4D, from blocks to an oak, and sixteen 4D flowers."})
	shots.append({"scenic": true, "eye0": Vector4(-0.6, 1.4, 10.4, 0.0), "eye1": Vector4(-0.4, 1.3, 1.0, 0.0),
		"look0": Vector4(2.2, 0.6, 8.2, 0.0), "look1": Vector4(2.2, 0.7, 2.4, 0.0), "length": 8.5, "lens": 0.9,
		"title": "THE FLOWERS", "line": "Every flower here is lofted in 4D: petals in the slice, and more through W."})
	player.set("input_enabled", false)
	player.linear_velocity = Vector4.ZERO
	# The pad's key prompt off for the tour (it hung in the middle of every shot).
	if prompt != null:
		prompt.set("shown", false)
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
	hud.call("show_caption", "BOTANY LAB   ·   " + String(s["title"]), "%d / %d" % [i + 2, shots.size()], String(s["line"]))


## A shot's eye, look and lens: the tour's own angle for the method where it has one (TOUR_SHOT), else the
## part's; the eye turned `orbit` radians round the look point (about up), kept inside the room.
func _shot_of(s: Dictionary, orbit: float = 0.0) -> Array:
	var st: Node4D = s["station"]
	var base: Array = st.call("shot", int(s["part"]))
	var eye: Vector4 = base[0]
	var look: Vector4 = base[1]
	var lens: float = base[2]
	var own: Array = TOUR_SHOT.get(String(s.get("method", "")), [])
	if not own.is_empty():
		var c: Vector4 = st.global_position + Vector4(0.0, float(st.get("height")), 0.0, 0.0)
		eye = c + (own[0] as Vector4)
		look = c + (own[1] as Vector4)
		lens = float(own[2])
	var off: Vector4 = eye - look
	var co: float = cos(orbit)
	var sn: float = sin(orbit)
	eye = look + Vector4(off.x * co + off.z * sn, off.y, -off.x * sn + off.z * co, off.w)
	var b: Rect2 = st.get("bounds")
	eye.x = clampf(eye.x, b.position.x + 0.7, b.end.x - 0.7)
	eye.z = clampf(eye.z, b.position.y + 0.7, b.end.y - 0.7)
	return [eye, look, lens]


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
		if s.has("scenic"):
			# A dolly: from its first eye and look to its last over its length, flown onto as any shot is.
			var u: float = LabMath.ease01(clampf((t - TOUR_ARRIVE * 0.5) / float(s["length"]), 0.0, 1.0))
			var eye: Vector4 = (s["eye0"] as Vector4).lerp(s["eye1"], u)
			var look: Vector4 = (s["look0"] as Vector4).lerp(s["look1"], u)
			var ks: float = LabMath.ease01(t / TOUR_ARRIVE)
			var sa0: Vector2 = _cine["from_ang"]
			var sa1: Vector2 = _look(eye, look)
			_place((_cine["from_eye"] as Vector4).lerp(eye, ks), Vector2(lerp_angle(sa0.x, sa1.x, ks), lerpf(sa0.y, sa1.y, ks)),
				lerpf(float(_cine["from_lens"]), float(s["lens"]), ks))
			if t > TOUR_ARRIVE * 0.5 + float(s["length"]) + 0.6:
				_tour_next()
			return
		# Arriving: the flight onto the shot, the tree held at its first stage. Then it grows, the camera
		# circling slowly, until it says it is done; then the hold on the finished tree.
		var gen_t: float = maxf(t - TOUR_ARRIVE, 0.0)
		var span: float = float(s["length"]) + TOUR_HOLD
		var orbit: float = TOUR_ORBIT * LabMath.ease01(clampf(gen_t / span, 0.0, 1.0)) - TOUR_ORBIT * 0.5
		var shot: Array = _shot_of(s, orbit)
		var k: float = LabMath.ease01(t / TOUR_ARRIVE)
		var a0: Vector2 = _cine["from_ang"]
		var a1: Vector2 = _look(shot[0], shot[1])
		_place((_cine["from_eye"] as Vector4).lerp(shot[0] as Vector4, k),
			Vector2(lerp_angle(a0.x, a1.x, k), lerpf(a0.y, a1.y, k)), lerpf(float(_cine["from_lens"]), float(shot[2]), k))
		var r: Dictionary = s["station"].call("play", int(s["part"]), gen_t)
		if float(s["done_at"]) < 0.0 and t > TOUR_ARRIVE and bool(r.get("done", gen_t >= float(s["length"]))):
			s["done_at"] = t
		var held: bool = float(s["done_at"]) >= 0.0 and t - float(s["done_at"]) >= TOUR_HOLD
		if held or t > TOUR_ARRIVE + float(s["length"]) + TOUR_GIVE_UP:
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
	for m in find_children("*", "MeshInstance4D", true, false):
		var n: Node = m
		var keep: bool = false
		while n != null and n != self:
			if trees.has(n):
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
