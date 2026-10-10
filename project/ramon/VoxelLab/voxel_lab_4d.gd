@tool
extends Node4D

## THE VOXEL LAB: the voxel mining prototype remade as a showcase room (Ramon, 6 Oct 2026: "render the
## basic setup, show what it is we want to do. be inspired by the voxel block and what that can do";
## plan and status: VoxelLab/PLAN.md; handover: follow_up/voxel_lab.md). Cutting 4D matter: the
## engine's own voxels (4Denthusiast's VoxelWorld4D), cut live, with every cost measured.
##
## You come in under VOXEL LAB to a quiet junction level with the shelf. On the right, three pre-cut
## specimens (A, B, C: a click at each says what it shows); ahead, the block on its pedestal. At its ring
## you choose (Ramon, 8 Oct): watch its presentation, a story that cuts it live (two cuts, a tunnel, a
## hidden room ana of your slice) with a camera that frames each part, or cut it yourself at the bench.
## Nothing plays by walking up to it. Past the shelf, the right wall (the block's live numbers); along
## the back, the gallery door and the left wall (the lab's introduction); on the left, the column, which
## you watch fall. Floating panels beside the block and the column; one soft light on each item.
## Behind the gallery's far door a blue shimmer takes you to the field; O goes straight there from
## anywhere in the lab (Ramon, 9 Oct: "a shortcut o in the scene for going directly to the open world").
##
## THIS NODE: the hall's shape (the carried room plan), the player (the kit's grown-up figure, the
## camera behind and above), the HUD (the control strip, the choice, the pop-up, the presentation's
## title card and callouts), the spots (Spots/*: where you can act, from the scene's metadata), which
## pedestal you are at (the wheel slides it through W, a right drag turns it), the benches (the choice
## sits you down; the bench has the keys until you stand up), the lights (vl_lights.gd), the volume
## view (V) and the grid view (G).
##
## NO class_name (engine_gotchas.md).

const KitPlayer := preload("res://ramon/VoxelLab/carried/kit/kit_player.gd")
const LabMath := preload("res://ramon/VoxelLab/carried/LabKit/lab_math.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const Hud := preload("res://ramon/VoxelLab/carried/scripts/rd_hud.gd")
const Prompt := preload("res://ramon/VoxelLab/carried/kit/kit_prompt.gd")
const Presenter := preload("res://ramon/VoxelLab/carried/kit/kit_presenter.gd")
const Plan := preload("res://ramon/VoxelLab/carried/kit/kit_room_plan.gd")
const Choice := preload("res://ramon/VoxelLab/room/vl_choice.gd")
const PopupCard := preload("res://ramon/VoxelLab/room/vl_popup.gd")
const LightRig := preload("res://ramon/VoxelLab/room/vl_lights.gd")
const Shimmer := preload("res://ramon/VoxelLab/room/vl_shimmer_4d.gd")
const LoadBoard := preload("res://ramon/VoxelLab/room/vl_load_board.gd")
const GridView := preload("res://ramon/VoxelLab/room/vl_grid_view.gd")
const DevPanel := preload("res://ramon/VoxelLab/room/vl_dev_panel.gd")
const Escape := preload("res://ramon/VoxelLab/room/vl_escape.gd")
const Generating := preload("res://ramon/VoxelLab/room/vl_generating.gd")
const LightsPanel := preload("res://ramon/VoxelLab/room/vl_lights_panel.gd")
const MouseTutorial := preload("res://ramon/VoxelLab/field/vl_mouse_tutorial.gd")
const Build := preload("res://ramon/VoxelLab/carried/scripts/chamber_build.gd")
const FIELD := "res://ramon/VoxelLab/field/voxel_field.tscn"
## Destinations lit blue whatever their turn (the others wait theirs in the muted colour).
const ALWAYS_LIT := ["Build"]

## Where you come from when the room opens: "field" (back through the gallery's far door) puts you at
## that door; anything else at the entrance. Set by the field before it hands back (static: it outlives
## the scene change).
static var arrive_from: String = ""

@export_group("Hall")
@export_range(8.0, 30.0, 0.1) var room_half_width: float = 11.0:
	set(v):
		room_half_width = v
		_shape_later()
@export_range(6.0, 30.0, 0.1) var room_front: float = 12.0:
	set(v):
		room_front = v
		_shape_later()
@export_range(6.0, 40.0, 0.1) var room_back: float = 14.0:
	set(v):
		room_back = v
		_shape_later()
@export_range(0.0, 20.0, 0.1) var corner_length: float = 8.6:
	set(v):
		corner_length = v
		_shape_later()
@export_range(5.0, 85.0, 0.5) var corner_angle: float = 42.0:
	set(v):
		corner_angle = v
		_shape_later()
@export_range(6.0, 20.0, 0.1) var hall_height: float = 9.0:
	set(v):
		hall_height = v
		_shape_later()
## The door at the back, to the engine's test cases.
@export_range(0.0, 8.0, 0.1) var door_width: float = 3.0:
	set(v):
		door_width = v
		_shape_later()
@export_range(2.0, 8.0, 0.1) var door_height: float = 4.2:
	set(v):
		door_height = v
		_shape_later()

@export_group("Gallery")
## The room behind the back door (Ramon, 6 Oct: "a testcase of [Andrew's] work featuring on different
## pedestals").
@export_range(10.0, 60.0, 0.5) var gallery_width: float = 26.0:
	set(v):
		gallery_width = v
		_shape_later()
@export_range(8.0, 40.0, 0.5) var gallery_depth: float = 16.0:
	set(v):
		gallery_depth = v
		_shape_later()
@export_range(5.0, 20.0, 0.1) var gallery_height: float = 8.0:
	set(v):
		gallery_height = v
		_shape_later()
## Metres between the hall's back wall and the gallery's front wall (Ramon, 9 Oct: "consider moving the
## entire second room approximately one meter backward"): each room's walls, floor and ceiling run half
## a metre past its own walls, and with the rooms touching, the gallery's ceiling showed on the hall's
## back wall and the hall's corner walls ran on into the gallery. A short passage fills the gap.
@export_range(0.0, 4.0, 0.1) var gallery_gap: float = 1.0:
	set(v):
		gallery_gap = v
		_shape_later()

@export_group("Visit")
## Where you start (x, z), facing the block.
@export var start_at: Vector2 = Vector2(0.0, 17.5)
## The lab's own loading board on the way in, while the engine builds the specimens (round 5, Ramon, 9 Oct:
## "i want to keep the loading screens ... some protos need time to load"; the menu's loading screen covers
## only the scene's file, not the voxels built after it). Off: straight in, as round 3 had it.
@export var board_on_arrival: bool = true
## How far beyond its pedestal's edge a pedestal counts as the one you are at (its story plays).
@export_range(1.0, 12.0, 0.5) var story_margin: float = 5.5
## The volume view's ghost: the camera's projection_opacity_base (lower is stronger).
@export_range(0.01, 1.0, 0.01) var volume_strength: float = 0.1

@export_group("Camera")
## While a story plays and you stand still, a camera eases to each part's own shot (plan step 40).
@export var story_camera: bool = true
@export_range(2.0, 12.0, 0.1) var camera_distance: float = 4.6
@export_range(0.5, 3.5, 0.05) var camera_height: float = 2.5
@export_range(-45.0, 20.0, 0.5) var camera_pitch_degrees: float = -9.0

var player: CharacterBody4D
var hud: Control
var prompt: Control
var presenter: Control
var choice: Control
var popup: Control
var dev_panel: Control
var lights_panel: Control
## "GENERATING WORLD" while the world's pedestal builds a new look (round 7, #82; room/vl_generating.gd).
var generating: Control
## The light rig (vl_lights.gd): every soft spot, the room values, the light file.
var lights: Node
var stations: Array = []
var benches: Array = []
## The pedestal you are at (a carried showcase), or null; the bench you sit at, or null.
var active: Node = null
var bench: Node = null
var plan: Dictionary = {}
var volume_view: bool = false
var grid_view: bool = false
var _near: Dictionary = {}
## Where you can act (Spots/*): [{"node", "kind", "radius", "station", "bench", "options", "target"}].
var spots: Array = []
## The spot you are standing at, or {}; how long you have stood there.
var spot: Dictionary = {}
## The Water Lab's mouse card (field/vl_mouse_tutorial.gd), at the gallery world's ring.
var tutorial: Control
var _spot_t: float = 0.0
## The station whose presentation is playing (chosen at its ring), and one waiting to be made whole first.
var watching: Node = null
var _watch_next: Node = null
var _popup_open: bool = false
var _leaving: bool = false
## The loading board while the specimens are built (vl_load_board.gd); true until it is gone.
var loading: bool = false
var _board: Control
var _board_t: float = 0.0
## What you have done, by route destination (the Paths/Targets names): taken a choice, stood at a wall,
## gone through a door.
var _done: Dictionary = {}
var _shape_queued: bool = false
var _grid: RefCounted
## The story camera (see _run_film), its state, and the station whose story you took the camera back
## from (it waits for that story to end before it films again).
var _film_cam: Camera4D
var _film: Dictionary = {}
var _film_declined: Node = null


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


## Esc's guard on the root (room/vl_escape.gd): it hears Esc and H before the menu and asks escape_step.
var _escape: CanvasLayer


func _ready() -> void:
	apply_shape()
	if not Engine.is_editor_hint():
		_escape = Escape.guard(self)
	var room: Node = get_node_or_null("Room")
	if room != null:
		room.set("mood_overrides", Style.ROOM_LIGHT.duplicate(true))
		room.call("set_mood", "bright", true, false)
		room.set("mood_key", KEY_NONE)
	Style.apply("bright")
	if Engine.is_editor_hint():
		return
	for s in get_tree().get_nodes_in_group("kit_showcase"):
		if is_ancestor_of(s):
			stations.append(s)
	for b in get_tree().get_nodes_in_group("vl_bench"):
		if is_ancestor_of(b):
			benches.append(b)
			b.connect("docked_changed", _on_docked.bind(b))
	var holder: Node = get_node_or_null("Spots")
	if holder != null:
		for n in holder.get_children():
			var st: Node = n.get_node_or_null(n.get_meta("station")) if n.has_meta("station") else null
			var bn: Node = n.get_node_or_null(n.get_meta("bench")) if n.has_meta("bench") else null
			spots.append({"node": n, "kind": String(n.get_meta("kind", "view")), "radius": float(n.get_meta("radius", 1.3)),
				"station": st, "bench": bn, "options": n.get_meta("options", []), "target": String(n.get_meta("target", "")),
				"near": float(n.get_meta("near", 0.0))})
	lights = Node.new()
	lights.name = "LightRig"
	lights.set_script(LightRig)
	add_child(lights)
	lights.call("setup", get_node_or_null("Lights"))
	player = KitPlayer.make()
	add_child(player)
	go_to(Vector4(start_at.x, 0.05, start_at.y, 0.0), 0.0)
	var from_field: bool = arrive_from == "field"
	if from_field and get_node_or_null("FieldDoor") != null:
		var d: Vector4 = (get_node("FieldDoor") as Node4D).position
		# Inside the far door, facing back into the gallery, the shimmer behind you; far enough in that
		# the camera behind you is in the gallery too (at 2.4 m it sat beyond the shimmer and saw only it).
		go_to(Vector4(0.0, 0.05, d.z + 5.6, 0.0), PI)
	arrive_from = ""
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
	generating = Control.new()
	generating.name = "Generating"
	generating.set_script(Generating)
	layer.add_child(generating)
	hud.connect("mood_pressed", toggle_palette)
	_label_switch()
	_route_floor()
	presenter = Control.new()
	presenter.name = "Presenter"
	presenter.set_script(Presenter)
	presenter.set("room", self)
	layer.add_child(presenter)
	prompt = Control.new()
	prompt.set_script(Prompt)
	prompt.set("camera", camera())
	layer.add_child(prompt)
	choice = Control.new()
	choice.name = "Choice"
	choice.set_script(Choice)
	layer.add_child(choice)
	choice.connect("chosen", _on_choice)
	popup = Control.new()
	popup.name = "Popup"
	popup.set_script(PopupCard)
	layer.add_child(popup)
	tutorial = Control.new()
	tutorial.name = "MouseTutorial"
	tutorial.set_script(MouseTutorial)
	# Round 6 (#61): a drag sweeps the world's slice through W; its square stays put.
	tutorial.set("gestures", [["drag_h", "SWEEP IT THROUGH W"], ["drag_v", "SWEEP IT THROUGH W"], ["wheel", "STEP THROUGH W"]])
	tutorial.set("footer", "R  ·  BACK AS IT WAS")
	layer.add_child(tutorial)
	# The floating panels wobble when you walk into them.
	for c in get_children():
		if c.get_script() != null and "face_point" in c:
			c.set("player", player)
	# The board on the way in as well as coming back from the open world (round 5: "keep the loading
	# screens"; round 3 had left it to the menu's, which ends before the voxels are built).
	if from_field or board_on_arrival:
		_open_board(from_field)
	# The blue shimmer in the gallery's far door: walk through it to the field.
	var door: Node4D = get_node_or_null("FieldDoor") as Node4D
	if door != null:
		var sh := Node4D.new()
		sh.name = "Shimmer"
		sh.set_script(Shimmer)
		# The opening exactly (round 3: "adjust the bright outline so it follows the opening precisely"):
		# its width and height, standing just inside the wall's face so its lit edges line the jambs.
		sh.set("width", 3.2)
		sh.set("height", minf(4.2, gallery_height - 0.5))
		sh.position = Vector4(0.0, 0.0, door.position.z + 0.17, 0.0)
		add_child(sh)
	var dlayer := CanvasLayer.new()
	dlayer.name = "Dev"
	dlayer.layer = 5
	add_child(dlayer)
	dev_panel = PanelContainer.new()
	dev_panel.set_script(DevPanel)
	dev_panel.set("room", self)
	dlayer.add_child(dev_panel)
	# Tab: every light on its own (round 3).
	var lp := PanelContainer.new()
	lights_panel = lp
	lp.name = "LightsPanel"
	lp.set_script(LightsPanel)
	lp.set("room", self)
	dlayer.add_child(lp)
	# The block's story turns the grid view on for its part about voxels.
	for s in stations:
		var ex: Node = s.get("exhibit")
		if ex != null and "grid_view_hook" in ex:
			ex.set("grid_view_hook", func(on: bool) -> void: _grid_for(s, on))


# -- the loading board -----------------------------------------------------------------------------

static func _thousands(v: int) -> String:
	var t: String = str(v)
	var out: String = ""
	while t.length() > 3:
		out = "," + t.substr(t.length() - 3) + out
		t = t.substr(0, t.length() - 3)
	return t + out


## The board while every specimen is built (Ramon, 9 Oct: the open world's board, and "if other things
## need building in the other two rooms, think of smart ways to optimize for performance"): the engine
## meshes them all at once, 16 chunks a frame per world on the main thread, and those first seconds of
## spikes and specimens popping in are now behind it.
func _open_board(from_field: bool) -> void:
	loading = true
	_board = LoadBoard.open(self)
	_board.set("kicker", "QUANTUM HORIZON  ·  " + ("BACK FROM THE OPEN WORLD" if from_field else "THE ENGINE'S OWN VOXELS"))
	_board.set("title", "VOXEL LAB")
	_board.set("subtitle", "Cutting 4D matter")
	_board.set("coming", ["A block of 4D rock: watch it cut, or cut it yourself",
		"Sections, a 4D builder, the numbers of every cut",
		"Behind it: how our world is made, and the door into it"])
	_board.set("diagram_title", "SPECIMENS, BUILT BY THE ENGINE AS YOU WAIT")
	_board.connect("finished", func() -> void:
		loading = false
		_board = null
		if player != null and bench == null:
			player.set("input_enabled", true))


func _feed_board(delta: float) -> void:
	_board_t += delta
	var bars: Array = []
	var ready: int = 0
	var tets: int = 0
	for s in stations:
		var ex: Node = s.get("exhibit")
		var sp: Node = ex.get("specimen") if ex != null else null
		var f: float = 0.0
		if ex != null and bool(ex.call("is_ready")):
			f = 1.0
			ready += 1
		elif sp != null:
			f = {"loading": 0.25, "meshing": 0.6, "proxies": 0.85}.get(String(sp.get("phase")), 0.1)
		var t: int = int(sp.call("tets")) if sp != null else 0
		tets += t
		bars.append([String(ex.get("title")) if ex != null else String(s.name), f, "%dk" % int(round(float(t) / 1000.0))])
	_board.set("bars", bars)
	_board.set("numbers", [["Specimens built", "%d of %d" % [ready, stations.size()]], ["Tetrahedra", _thousands(tets)], ["Video memory", "%.0f MB" % (float(tets) * 1.25 / 1024.0)]])
	_board.set("progress", float(ready) / maxf(1.0, float(stations.size())))
	if (ready == stations.size() and _board_t > 2.0) or _board_t > 40.0:
		_board.call("finish")
	if player != null:
		player.set("input_enabled", false)


# -- the shape ---------------------------------------------------------------------------------------

func _shape_later() -> void:
	if _shape_queued or not is_inside_tree():
		return
	_shape_queued = true
	(func() -> void:
		_shape_queued = false
		apply_shape()).call_deferred()


## The hall from its plan, the corridor in front of it and the gallery behind it.
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
	_set_if(hall, "doorways", doors)
	var ent: Node4D = get_node_or_null("Entrance") as Node4D
	if ent != null:
		ent.position = Vector4(0.0, 0.0, f + 7.5, 0.0)
	var gal: Node4D = get_node_or_null("GalleryRoom") as Node4D
	if gal != null:
		var gz: float = -d - 0.5 - gallery_gap - gallery_depth * 0.5
		gal.position = Vector4(0.0, 0.0, gz, 0.0)
		_set_if(gal, "size", Vector3(gallery_width, gallery_height, gallery_depth))
		var gdoors: Array = [["s", -dw * 0.5, dw * 0.5, minf(door_height, gallery_height - 0.5)]] if dw > 0.1 else []
		# The far door, out to the field (Andrew's landscape, generated round you).
		gdoors.append(["n", -1.6, 1.6, minf(4.2, gallery_height - 0.5)])
		_set_if(gal, "doorways", gdoors)
		var door: Node4D = get_node_or_null("FieldDoor") as Node4D
		if door != null:
			door.position = Vector4(0.0, 2.4, gz - gallery_depth * 0.5 - 0.2, 0.0)
		_passage(-d - 0.5, gz + gallery_depth * 0.5 + 0.5, dw)
		_far_walk(gz - gallery_depth * 0.5, minf(4.2, gallery_height - 0.5))


## Between the hall's back door and the gallery's: from the outer face of one wall to the outer face of
## the other, a floor you walk on, a wall either side of the door and a ceiling at the door's height, so
## nothing of either room shows in the gap and nothing reaches into either.
func _passage(z_hall: float, z_gallery: float, dw: float) -> void:
	var old: Node = get_node_or_null("Passage")
	if old != null:
		remove_child(old)
		old.queue_free()
	if z_hall - z_gallery < 0.05 or dw < 0.1:
		return
	var p := Node4D.new()
	p.name = "Passage"
	add_child(p)
	var len: float = z_hall - z_gallery
	var zc: float = (z_hall + z_gallery) * 0.5
	var h: float = minf(door_height, minf(hall_height, gallery_height) - 0.5)
	# The floor reaches under both rooms' walls, which stand on nothing at their outer half.
	Build.box(p, "Floor", Vector3(0.0, -0.25, zc), Vector3(dw + 1.2, 0.5, len + 1.0), "kit_floor")
	for side in [-1.0, 1.0]:
		Build.box(p, "Wall", Vector3(side * (dw * 0.5 + 0.25), h * 0.5, zc), Vector3(0.5, h, len), "kit_wall")
	Build.box(p, "Ceiling", Vector3(0.0, h + 0.2, zc), Vector3(dw + 1.0, 0.4, len), "kit_ceiling", false)


## Past the gallery's far door, a short walkway (round 4, #25: "extend the walkway past the gallery's far
## door so the player doesn't drop"): floor, walls and a ceiling 4.5 m on from the wall, closed at its
## end, so the steps after the shimmer still land on something while the wash plays.
func _far_walk(z_wall: float, h: float) -> void:
	var old: Node = get_node_or_null("FarWalk")
	if old != null:
		remove_child(old)
		old.queue_free()
	var p := Node4D.new()
	p.name = "FarWalk"
	add_child(p)
	var half: float = 1.6
	var reach: float = 4.5
	# The room's walls stand outside its edge, half a metre thick: the floor starts at the edge (a hair
	# lower than the gallery's, so where they meet nothing flickers), the walls at the wall's outer face.
	Build.box(p, "Floor", Vector3(0.0, -0.253, z_wall - reach * 0.5), Vector3(half * 2.0 + 1.2, 0.5, reach), "kit_floor")
	var zc: float = z_wall - 0.5 - (reach - 0.5) * 0.5
	for side in [-1.0, 1.0]:
		Build.box(p, "Wall", Vector3(side * (half + 0.25), h * 0.5, zc), Vector3(0.5, h, reach - 0.5), "kit_wall")
	Build.box(p, "End", Vector3(0.0, h * 0.5, z_wall - reach - 0.25), Vector3(half * 2.0 + 1.0, h, 0.5), "kit_wall")
	Build.box(p, "Ceiling", Vector3(0.0, h + 0.2, zc), Vector3(half * 2.0 + 1.0, 0.4, reach - 0.5), "kit_ceiling", false)


static func _set_if(n: Object, key: String, v: Variant) -> void:
	if n.get(key) != v:
		n.set(key, v)


func wall_lengths() -> Dictionary:
	return plan.get("lengths", {})


# -- looks ---------------------------------------------------------------------------------------------

## The palette switch (B, or the button at the top right): the light surfaces grey or near-black, the
## light untouched (kit_style.gd palette), as in the Creation Lab and the Arboretum.
func toggle_palette() -> void:
	Style.palette = "grey" if Style.palette == "black" else "black"
	Style.apply(Style.mood)
	# The black palette keeps less of the sky fill (the dev panel's "black palette: fill kept"), so the
	# specimens stand out in their downlights.
	if dev_panel != null:
		dev_panel.call("apply", "fill")
	for n in get_tree().get_nodes_in_group("lab_mood_listener"):
		if n != self and is_ancestor_of(n) and n.has_method("apply_mood"):
			n.call("apply_mood", Style.mood, true)
	_label_switch()
	_route_floor()


## The routes' marks blend their edges into the floor's own colour; on the black palette's floor that
## was still the grey one, and every blue mark had a thin light rim (Ramon, 9 Oct: "so its just blue to
## black for that toggle").
func _route_floor() -> void:
	var floor_c: Color = (Style.BLACK["kit_floor"][0] as Color) if Style.palette == "black" else (Style.SWATCHES["bright"]["kit_floor"][0] as Color)
	for nm in ["Hall", "Gallery"]:
		var net: Node = get_node_or_null("Paths/" + nm)
		if net != null:
			net.set("under_color", floor_c)


func _label_switch() -> void:
	if hud != null:
		# Round 3: the switch says what the room is now ("Dark Mode On / Dark Mode Off").
		hud.set("switch_text", "DARK MODE ON  ·  B" if Style.palette == "black" else "DARK MODE OFF  ·  B")
		hud.call("refresh_switch")


func apply_mood(m: String, _instant: bool = false) -> void:
	Style.apply(m)
	if hud != null:
		hud.call("set_mood", m)


# -- each frame ----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	if _board != null:
		_feed_board(delta)
	_show_generating()
	if bench != null:
		hud.set("strip", bench.call("strip"))
		presenter.set("active", false)
		prompt.set("shown", false)
		choice.set("shown", false)
		popup.set("shown", false)
		return
	var p: Vector4 = player.global_position
	_find_active(p)
	_follow_watch()
	_read_spot(p, delta)
	_run_film(delta)
	if presenter != null:
		presenter.set("showcase", watching)
		presenter.set("active", watching != null)
	prompt.set("shown", false)
	hud.set("strip", _strip())
	_match_widths()
	_route_states(p)
	_field_door(p)


## The choice and the control strip under it, one width: the wider of the two.
func _match_widths() -> void:
	var showing: bool = bool(choice.get("shown"))
	var w: float = maxf(float(hud.get("strip_width")), float(choice.get("natural_width"))) if showing else 0.0
	hud.set("min_strip_width", w)
	choice.set("match_width", w)


## The pedestal you are at, for the wheel and a right drag: the nearest whose edge is within
## `story_margin`. Nothing plays by walking up to it (Ramon, 8 Oct: the presentation is a choice);
## a presentation stops when you walk well away from it.
func _find_active(p: Vector4) -> void:
	var best: Node = null
	var best_d: float = INF
	for s in stations:
		var sp: Vector4 = (s as Node4D).global_position
		var d: float = Vector2(p.x - sp.x, p.z - sp.z).length() - float(s.get("radius"))
		if d < story_margin and d < best_d:
			best_d = d
			best = s
		if s == watching and d > story_margin:
			stop_watching()
	active = best


## The presentation chosen at a ring: started once its exhibit is whole (the column is made whole
## first), and over when its story has played or been stopped.
func _follow_watch() -> void:
	if _watch_next != null:
		var ex: Node = _watch_next.get("exhibit")
		if ex == null or not ex.has_method("ready_to_watch") or bool(ex.call("ready_to_watch")):
			watching = _watch_next
			_watch_next = null
			_film_declined = null
			watching.call("replay")
		return
	if watching != null and not bool(watching.get("armed")) and int(watching.get("seq_index")) < 0:
		watching = null


func watch(s: Node) -> void:
	if s == null:
		return
	if watching != null and watching != s:
		stop_watching()
	var ex: Node = s.get("exhibit")
	if ex != null and ex.has_method("ready_to_watch") and not bool(ex.call("ready_to_watch")):
		if bool(ex.call("is_ready")):
			ex.call("reset")
		hud.call("toast", "Making it whole first")
	_watch_next = s


func stop_watching() -> void:
	_watch_next = null
	if watching != null:
		watching.call("_finish")
	watching = null


## The spot you stand at: its choice, its pop-up, or a wall you have come to read.
func _read_spot(p: Vector4, delta: float) -> void:
	var best: Dictionary = {}
	var best_d: float = INF
	for sp in spots:
		var at: Vector4 = (sp["node"] as Node4D).global_position
		var d: float = Vector2(p.x - at.x, p.z - at.z).length()
		# Round 7 (#78: "activate Build It Yourself when standing close to the specimen or builder itself"):
		# a spot with `near` also counts anywhere that close to its pedestal's sides; standing on a ring
		# still wins.
		if d >= float(sp["radius"]) and float(sp.get("near", 0.0)) > 0.0 and sp.get("station") != null:
			var sc: Vector4 = (sp["station"] as Node4D).global_position
			var half: float = float(sp["station"].get("radius"))
			var out := Vector2(maxf(absf(p.x - sc.x) - half, 0.0), maxf(absf(p.z - sc.z) - half, 0.0))
			if out.length() < float(sp["near"]):
				d = float(sp["radius"]) - 0.01
		if d < float(sp["radius"]) and d < best_d:
			best_d = d
			best = sp
	if best.get("node") != spot.get("node"):
		_spot_t = 0.0
		_popup_open = false
	spot = best
	_spot_t += delta
	if not spot.is_empty() and _spot_t > 1.2 and not String(spot["target"]).is_empty() and String(spot["kind"]) == "view":
		_done[String(spot["target"])] = true
	var kind: String = String(spot.get("kind", ""))
	choice.set("shown", kind == "choice" and watching == null and _watch_next == null)
	if kind == "choice":
		choice.set("heading", _heading(spot))
		choice.set("options", _options(spot))
	popup.set("shown", kind == "popup" and _popup_open)
	if kind == "popup" and _popup_open:
		popup.set("data", _popup_data(spot["station"]))
	# The mouse card at the world's ring (round 4: "reuse the animated mouse tutorial from the Water Lab
	# aquarium ... adapt it to demonstrate slice rotation"), ten seconds each time you come to it.
	if tutorial != null:
		var st: Node = spot.get("station")
		tutorial.set("shown", st != null and String(st.name) == "Terrain" and watching == null)


func _heading(sp: Dictionary) -> String:
	var st: Node = sp.get("station")
	var ex: Node = st.get("exhibit") if st != null else null
	return ("%s  ·  %s" % [String(ex.get("code")), String(ex.get("title")).to_upper()]) if ex != null else ""


## A spot's options as the choice shows them (keys 1 and 2).
func _options(sp: Dictionary) -> Array:
	var out: Array = []
	var ex: Node = sp["station"].get("exhibit") if sp.get("station") != null else null
	for o in sp["options"]:
		var item: Dictionary = {"key": str(out.size() + 1), "id": String(o)}
		match String(o):
			"watch":
				item.merge({"icon": "eye", "label": "Watch the presentation"})
			"cut":
				item.merge({"icon": "pick", "label": "Cut it yourself"})
			"build":
				item.merge({"icon": "build", "label": "Build it yourself"})
			"biome":
				# Round 7 (#83: "how many world variations are available ... 1 of 3"): which, of how many.
				var now: String = String(ex.call("biome_count_label")) if ex != null and ex.has_method("biome_count_label") else ""
				item.merge({"icon": "globe", "label": "Change the land (now %s)" % now})
		out.append(item)
	return out


func _on_choice(i: int) -> void:
	if spot.is_empty() or i < 0 or i >= (spot["options"] as Array).size():
		return
	var st: Node = spot.get("station")
	if not String(spot["target"]).is_empty():
		_done[String(spot["target"])] = true
	match String(spot["options"][i]):
		"watch":
			watch(st)
		"cut", "build":
			sit(spot.get("bench"))
		"biome":
			var ex: Node = st.get("exhibit") if st != null else null
			if ex != null and ex.has_method("next_biome"):
				ex.call("next_biome")
				hud.call("toast", "The land: " + String(ex.call("biome_count_label")))


## The pop-up's words, from the exhibit's card.
func _popup_data(st: Node) -> Dictionary:
	var ex: Node = st.get("exhibit") if st != null else null
	if ex == null or not ex.has_method("card"):
		return {}
	var c: Dictionary = ex.call("card")
	var text: String = String(c.get("text", c.get("short", "")))
	return {"code": String(c.get("code", "")), "title": String(c.get("title", "")), "kicker": String(c.get("kicker", "")),
		"text": text, "rows": (c.get("rows", []) as Array).slice(0, 3)}


func _strip() -> Array:
	if watching != null or _watch_next != null:
		return [["Click / ← →", "Next part"], ["Esc", "Stop"], ["Wheel", "Slide through W"]]
	var kind: String = String(spot.get("kind", ""))
	var out: Array = []
	if kind == "popup":
		out.append(["Click", "Close" if _popup_open else "About this specimen"])
	if active != null:
		out.append(["Wheel", "Slide through W"])
		var ex: Node = active.get("exhibit")
		# The big landscape is swept through W, never turned (round 6, #61).
		out.append(["Right drag", "Sweep through W" if ex != null and ex.get("sweep_w") == true else "Turn in 4D"])
		out.append(["R", "Reset slice"])
		out.append(["V", "Projection view" if not volume_view else "Slice view"])
	else:
		out.append(["WASD", "Move"])
		# Round 7 (#86: "Holding Shift should make the player move somewhat faster"): the walker's own
		# sprint (kit_player.gd: 4.2 m/s against the 2.8 m/s run), named here so it is found.
		out.append(["Shift", "Run"])
		out.append(["Mouse", "Look"])
	if active == null:
		out.append(["O", "The open world"])
	return out


## Walking through the far door's shimmer takes you to the field.
func _field_door(p: Vector4) -> void:
	var door: Node4D = get_node_or_null("FieldDoor") as Node4D
	if door == null or _leaving:
		return
	if p.z < door.position.z + 0.35 and absf(p.x) < 1.6:
		_leaving = true
		var sh: Node = get_node_or_null("Shimmer")
		if sh != null and sh.has_method("flash_out"):
			sh.call("flash_out", self, to_field)
		else:
			to_field()


# -- the benches ---------------------------------------------------------------------------------------

func sit(b: Node) -> void:
	if b == null or bench != null:
		return
	stop_watching()
	b.call("dock", self)


func _on_docked(on: bool, b: Node) -> void:
	if on:
		# The bench's camera is already current: the story camera just goes (handing the view to the
		# player's camera here sat you at the bench looking from behind yourself, 6 Oct).
		_film_stop(false)
		bench = b
		player.set("input_enabled", false)
		player.set("linear_velocity", Vector4.ZERO)
		hud.call("toast", "At the bench. F stands you up.")
	else:
		bench = null
		player.set("input_enabled", true)
		var pc: Camera4D = camera()
		if pc != null:
			pc.current = true
		_apply_view_to(pc)


# -- the route ------------------------------------------------------------------------------------------

## The floor route's destinations follow the visit (the Path_Indicator sheet's rule 07): what you have
## done completed, the next one available (focused while you stand at it), the rest waiting.
func _route_states(p: Vector4) -> void:
	if p.z < -15.6:
		_done["GalleryDoor"] = true
	for nm in ["Hall", "Gallery"]:
		var net: Node = get_node_or_null("Paths/" + nm)
		if net == null or net.get("graph") == null:
			continue
		var graph: Resource = net.get("graph")
		var changed: bool = false
		var next_found: bool = false
		for n in graph.get("nodes"):
			var d: Dictionary = n
			if String(d.get("kind", "")) != "destination":
				continue
			var target: String = String(d.get("target", ""))
			var want: String
			if _done.has(target):
				want = "completed"
			elif target in ALWAYS_LIT:
				# Round 4: the column's ring a proper blue from the start ("rather than the current muted
				# gray-blue"), though it comes late in the hall's order.
				var at2: Vector4 = d.get("pos", Vector4.ZERO)
				want = "focused" if Vector2(p.x - at2.x, p.z - at2.z).length() < 2.0 else "available"
			elif not next_found:
				next_found = true
				var at: Vector4 = d.get("pos", Vector4.ZERO)
				var near: bool = Vector2(p.x - at.x, p.z - at.z).length() < 2.0
				want = "focused" if near else "available"
			else:
				want = "arrival"
			if String(d.get("state", "")) != want:
				d["state"] = want
				changed = true
		if changed:
			graph.emit_changed()


# -- the mouse and keys --------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or player == null or bench != null:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if watching != null:
				watching.call("skip")
				get_viewport().set_input_as_handled()
				return
			if String(spot.get("kind", "")) == "popup":
				_popup_open = not _popup_open
				get_viewport().set_input_as_handled()
				return
		if active != null and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			active.call("step_slice", 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			get_viewport().set_input_as_handled()
			return
	var kr := event as InputEventKey
	if kr != null and kr.pressed and not kr.echo and kr.keycode == KEY_R and active != null and watching == null:
		# Round 3: R puts the pedestal's specimen back as it stood: no turn, the middle slice.
		active.call("reset_view")
		get_viewport().set_input_as_handled()
		return
	var mm := event as InputEventMouseMotion
	# Looking round takes the camera back from the story.
	if mm != null and _film_cam != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) == 0 \
			and mm.relative.length() > 3.0:
		_film_declined = _film.get("station")
	if mm != null and active != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		active.call("turn_by", mm.relative.x * 0.006, mm.relative.y * 0.006)
		get_viewport().set_input_as_handled()


## ESC, IN ORDER (round 7, #79: "1. If a modal dialog is open, Escape closes or cancels that dialog. 2. If
## the developer HUD or another interface is open, Escape closes that interface. 3. Otherwise, Escape opens
## the return-to-menu confirmation"): asked by the guard (room/vl_escape.gd), which has the key before
## anything else. The top thing open closes and this returns true; nothing open, false, and the guard asks
## "Return to the main menu?". H is only ever the guard's question here.
func escape_step(key: Key) -> bool:
	if key != KEY_ESCAPE:
		return false
	for panel in [dev_panel, lights_panel]:
		if panel != null and (panel as Control).visible:
			(panel as Control).visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if bench != null else Input.MOUSE_MODE_CAPTURED
			return true
	if _popup_open:
		_popup_open = false
		return true
	if watching != null or _watch_next != null:
		stop_watching()
		return true
	if bench != null:
		bench.call("undock")
		return true
	return false


## The pill while the world's pedestal builds a new look, saying which world of how many.
func _show_generating() -> void:
	if generating == null:
		return
	var on: bool = false
	for s in stations:
		var ex: Node = s.get("exhibit")
		if ex != null and ex.has_method("generating") and bool(ex.call("generating")):
			on = true
			generating.set("text", "GENERATING WORLD %s" % String(ex.call("biome_count_label")).to_upper())
	generating.set("shown", on)


func _exit_tree() -> void:
	if _escape != null and is_instance_valid(_escape):
		_escape.queue_free()
	_escape = null


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or player == null or bench != null:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# Esc is the guard's (escape_step above): it never reaches here.
	match k.keycode:
		KEY_B:
			if not k.shift_pressed and not k.ctrl_pressed:
				toggle_palette()
				get_viewport().set_input_as_handled()
		KEY_V:
			toggle_volume_view()
			get_viewport().set_input_as_handled()
		KEY_G:
			toggle_grid_view()
			get_viewport().set_input_as_handled()
		KEY_O:
			straight_to_field()
			get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_LEFT:
			if watching != null:
				watching.call("skip" if k.keycode == KEY_RIGHT else "skip_back")
				get_viewport().set_input_as_handled()


# -- the story camera ----------------------------------------------------------------------------------

## While a pedestal's story plays and you stand still, a camera eases to each part's own shot (the
## exhibit's chapters carry eye, look and lens; the kit's showcase places them in the room with
## shot()), so the cuts read at the size they were made at: from the player's own camera the block's
## holes were a few pixels across (6 Oct). Move or look round and it eases back to you, and waits for
## the next story. Only exhibits whose chapters carry shots are filmed (the block, the column). The
## Arboretum's tour moves its camera the same way.
func _run_film(delta: float) -> void:
	var s: Node = watching
	if _film_declined != null and (s != _film_declined or int(_film_declined.get("seq_index")) < 0):
		_film_declined = null
	if _film_cam != null and String(_film.get("phase", "")) == "shot":
		for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]:
			if Input.is_key_pressed(key) and bool(player.get("input_enabled")):
				_film_declined = _film.get("station")
	var want: bool = story_camera and s != null and s != _film_declined and int(s.get("seq_index")) >= 0 and _has_shots(s)
	if want and _film_cam == null:
		_film_begin(s)
	if _film_cam == null:
		return
	if (not want or _film.get("station") != s) and String(_film["phase"]) != "out":
		_film_ease_from("out")
	_film_step(delta)


func _has_shots(s: Node) -> bool:
	var ex: Node = s.get("exhibit")
	var chs: Array = ex.call("chapters") if ex != null and ex.has_method("chapters") else []
	return not chs.is_empty() and (chs[0] as Dictionary).has("eye")


func _player_cam() -> Camera4D:
	return player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D if player != null else null


func _film_begin(s: Node) -> void:
	var pc: Camera4D = _player_cam()
	if pc == null:
		return
	_film_cam = pc.duplicate(0) as Camera4D
	_film_cam.name = "StoryCamera"
	add_child(_film_cam)
	_film_cam.global_position = pc.global_position
	_film_cam.global_basis = pc.global_basis
	_film_cam.make_current()
	_film = {"station": s, "part": -1, "player_lens": float(pc.get("field_of_view_4d"))}
	# You step out of the shots, as in a cutscene (your figure stood in the column's, 9 Oct).
	_avatar_shown(false)
	_film_ease_from("shot")


## Starts an ease (to a shot, or "out" to the player) from wherever the story camera is now.
func _film_ease_from(phase: String) -> void:
	_film["phase"] = phase
	_film["t"] = 0.0
	_film["from_eye"] = _film_cam.global_position
	_film["from_ang"] = _angles_of(_film_cam.global_basis)
	_film["from_lens"] = float(_film_cam.get("field_of_view_4d"))


func _film_step(delta: float) -> void:
	_film["t"] = float(_film["t"]) + delta
	if String(_film["phase"]) == "shot":
		var s: Node = _film["station"]
		var part: int = int(s.get("seq_index"))
		if part != int(_film["part"]):
			_film_ease_from("shot")
			_film["part"] = part
		var t: float = float(_film["t"])
		var shot: Array = s.call("shot", part)
		var k: float = LabMath.ease01(t / 1.6)
		var a0: Vector2 = _film["from_ang"]
		var a1: Vector2 = _look(shot[0], shot[1])
		# A slow push in while the part plays, so a held shot is never quite still.
		var drift: Vector4 = ((shot[1] as Vector4) - (shot[0] as Vector4)).normalized() * (t * 0.05)
		_film_place((_film["from_eye"] as Vector4).lerp((shot[0] as Vector4) + drift, k), Vector2(lerp_angle(a0.x, a1.x, k), lerpf(a0.y, a1.y, k)),
			lerpf(float(_film["from_lens"]), float(shot[2]), k))
		return
	var pc: Camera4D = _player_cam()
	var k2: float = LabMath.ease01(float(_film["t"]) / 0.7)
	var b0: Vector2 = _film["from_ang"]
	var b1: Vector2 = _angles_of(pc.global_basis)
	_film_place((_film["from_eye"] as Vector4).lerp(pc.global_position, k2), Vector2(lerp_angle(b0.x, b1.x, k2), lerpf(b0.y, b1.y, k2)),
		lerpf(float(_film["from_lens"]), float(_film["player_lens"]), k2))
	if k2 >= 1.0:
		_film_stop()


## Ends the story camera at once, handing the view back to the player's camera (unless another camera,
## the bench's, has taken it).
func _film_stop(to_player: bool = true) -> void:
	if _film_cam == null:
		return
	var pc: Camera4D = _player_cam()
	if pc != null and to_player:
		pc.make_current()
	_film_cam.queue_free()
	_film_cam = null
	_film = {}
	_avatar_shown(true)


func _avatar_shown(on: bool) -> void:
	var av: Node4D = player.get_node_or_null("Avatar") as Node4D if player != null else null
	if av != null:
		av.visible = on


func _film_place(eye: Vector4, ang: Vector2, lens: float) -> void:
	_film_cam.global_position = eye
	_film_cam.global_basis = Basis4D.from_zx(ang.x) * Basis4D.from_yz(ang.y)
	_film_cam.set("field_of_view_4d", lens)


func _angles_of(b: Projection) -> Vector2:
	var f: Vector4 = -(b * Vector4(0.0, 0.0, 1.0, 0.0))
	return Vector2(atan2(-f.x, -f.z), atan2(f.y, maxf(Vector2(f.x, f.z).length(), 0.0001)))


func _look(eye: Vector4, at: Vector4) -> Vector2:
	var d: Vector4 = at - eye
	return Vector2(atan2(-d.x, -d.z), atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001)))


# -- views ---------------------------------------------------------------------------------------------

## The camera in use: the bench's while you sit, the player's otherwise.
func camera() -> Camera4D:
	if bench != null and bench.call("camera") != null:
		return bench.call("camera")
	return player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D if player != null else null


## V: the Combined renderer on the camera in use (the slice, and faintly everything ana and kata of
## it), with only the specimens let into the projection (as the Arboretum does with its trees). The
## root is handed a 3D world first: switching to Combined in one run crashes the engine otherwise (the
## 30 Sept engine bug).
func toggle_volume_view() -> void:
	volume_view = not volume_view
	_apply_view_to(camera())
	_apply_view_to(_film_cam)
	hud.call("toast", "Projection view: the whole 4D specimen, faintly" if volume_view else "Slice view")


func _apply_view_to(cam: Camera4D) -> void:
	if cam == null:
		return
	var tree: SceneTree = get_tree()
	if tree.root.world_3d == null:
		tree.root.world_3d = World3D.new()
	if volume_view:
		_projection_specimens_only()
	cam.set("rendering_engine_name", "Combined" if volume_view else "Cross-section")
	cam.set("projection_opacity_base", volume_strength)


func _projection_specimens_only() -> void:
	for m in find_children("*", "MeshInstance4D", true, false):
		var n: Node = m
		var keep: bool = false
		while n != null and n != self:
			if n.has_method("chunk_nodes"):
				keep = true
				break
			n = n.get_parent()
		(m as MeshInstance4D).set("allow_projection", keep)


## G: the voxel grid on every specimen (room/vl_grid_view.gd).
func toggle_grid_view() -> void:
	grid_view = not grid_view
	for s in stations:
		_grid_for(s, grid_view)
	hud.call("toast", "Grid view: every voxel's edges" if grid_view else "Grid view off")


func _grid_for(s: Node, on: bool) -> void:
	var ex: Node = s.get("exhibit")
	var sp: Node = ex.get("specimen") if ex != null else null
	if sp != null:
		GridView.apply(sp, on)


## O: to the open world from wherever you are, with the far door's blue wash.
func straight_to_field() -> void:
	if _leaving:
		return
	_leaving = true
	var sh: Node = get_node_or_null("Shimmer")
	if sh != null and sh.has_method("flash_out"):
		sh.call("flash_out", self, to_field)
	else:
		to_field()


## Out through the gallery's far door to the field (field/voxel_field.tscn): this room is let go, so its
## memory is free for the landscape; the field brings you back to this door.
func to_field() -> void:
	player.set("input_enabled", false)
	get_tree().change_scene_to_file(FIELD)


## Puts the player at `at` (x, y, z, W), standing still, facing `yaw` (NAN keeps the camera's).
func go_to(at: Vector4, yaw: float = NAN) -> void:
	if player == null:
		return
	player.global_position = at
	player.set("linear_velocity", Vector4.ZERO)
	var rig: Node = player.get_node_or_null("CameraRig")
	if is_nan(yaw):
		yaw = float(rig.get("yaw")) if rig != null else 0.0
	player.set("_facing", yaw + PI)
	if rig != null:
		rig.set("yaw", yaw)
		rig.call("_apply")


func touring() -> bool:
	return false
