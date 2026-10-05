@tool
extends Node4D

## PATHCREATOR: the dev space for designing and play-testing the direction path system (Ramon,
## 5 Oct 2026; the plan is PLAN.md, what was learned CASE_STUDY.md). A big white walkplane under
## the Creation Lab's light (path_environment.gd), no spot; coloured targets standing at different
## W (space/pc_target_4d.gd); the Figma's 46 x 30 m yard at true scale; and the path network drawn
## over the floor as vectors (graph/, render/).
##
## YOU walk as in the pen (the carried walker, LabKit/lab_player.gd): WASD, Q and E to walk through
## W, the right mouse held to tilt the slice into W. The HUD says where you are in W and how far
## the slice is tilted.
##
## KEYS (checked free in the project and the walker, 5 Oct):
##   F4  build mode (the builder: from above, every node, drag, save)
##   F5  the next symbol set (library) for every slot
##   F6  the look: DEV (the sheet's colours, emitted) or WALK (one sand, lit like paint)
##   F7  volume view: the Combined renderer, which also shows faintly what is ana and kata of you
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const Env := preload("res://ramon/CreationLab/PathCreator/path_environment.gd")
const Hud := preload("res://ramon/CreationLab/PathCreator/space/pc_hud.gd")
const Builder := preload("res://ramon/CreationLab/PathCreator/builder/pc_builder.gd")
const LabPlayer := preload("res://ramon/CreationLab/LabKit/lab_player.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const GENERATED := "pc_generated"

## The floor's albedo: white (the room's blue light makes it read a light blue-grey, as the lab's do).
const FLOOR := Color(0.96, 0.965, 0.97)

## Where you start, x/z.
@export var start_at: Vector2 = Vector2(0, 6)

## Where the number keys take you while walking (Ramon, 5 Oct: "how do i spawn at the other
## places"): name, where you stand (x, y, z, W), the way you face (the rig's yaw: 0 faces -z, PI
## faces +z, -PI/2 faces +x). Each stands a few metres before the place, looking at it.
const PLACES: Array = [
	["the start", Vector4(0.0, 0.05, 6.0, 0.0), PI],
	["the yard", Vector4(-25.5, 0.05, -34.0, 0.0), -PI * 0.5],
	["the W field", Vector4(1.5, 0.05, 5.0, 0.0), PI],
	["the pen patch", Vector4(42.0, 0.05, -20.0, 0.0), PI],
	["the W targets", Vector4(40.0, 0.05, 12.0, 0.0), PI],
]
## The walkplane, metres (x, z); it is W_REACH deep either side of W 0.
@export var floor_size: Vector2 = Vector2(120, 120):
	set(v):
		floor_size = v
		if is_inside_tree():
			_build_floor()

var player: CharacterBody4D
var hud: Control
var volume_view: bool = false
## The look every network shows: "dev" or "walk".
var look: String = "dev"
var builder: Control
var building: bool = false
var _build_cam: Camera4D
var _mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _floor: MeshInstance4D


func _ready() -> void:
	var room: Node = get_node_or_null("Room")
	if room != null:
		room.set("mood_overrides", Env.mood_overrides())
		if room.has_method("set_mood"):
			room.call("set_mood", "bright", true, false)
	_build_floor()
	if Engine.is_editor_hint():
		return
	player = LabPlayer.make(LabPlayer.GREY_SUIT, LabPlayer.GREY_TRIM, LabPlayer.GREY_HAIR)
	# The pen's way through W: Q and E walk ana and kata (the lab turns it off).
	player.set("w_speed_scale", 0.3)
	add_child(player)
	player.global_position = Vector4(start_at.x, 0.05, start_at.y, 0.0)
	player.set("_facing", PI)
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Control.new()
	hud.set_script(Hud)
	hud.set("root_node", self)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	var blayer := CanvasLayer.new()
	blayer.name = "Builder"
	add_child(blayer)
	builder = Control.new()
	builder.set_script(Builder)
	builder.set("space", self)
	builder.visible = false
	blayer.add_child(builder)


func _build_floor() -> void:
	if is_instance_valid(_floor):
		_floor.queue_free()
	LabGrid.set_swatch("pc_floor", FLOOR, Color(0.86, 0.87, 0.89), Color(0.92, 0.925, 0.93), 1.0)
	var s4 := Vector4(floor_size.x, 0.5, floor_size.y, Spec.W_REACH * 2.0)
	_floor = MeshInstance4D.new()
	_floor.name = "Walkplane"
	_floor.mesh = Mats.box_mesh(s4)
	_floor.position = Vector4(0, -0.25, 0, 0)
	_floor.material_override = LabGrid.material("pc_floor", s4, _floor.position)
	_floor.set_meta(GENERATED, true)
	add_child(_floor)
	var body := StaticBody4D.new()
	body.name = "WalkplaneBody"
	# A child of the floor, so it is already where the floor is (copying the floor's position here
	# put the collision 0.25 m below the surface you see, and the player walked sunk into it).
	var cs := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = s4
	cs.shape = bs
	body.add_child(cs)
	body.set_meta(GENERATED, true)
	_floor.add_child(body)


func camera() -> Camera4D:
	return player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D if player != null else null


## How far the slice is tilted into W, degrees: the angle between the camera's own W axis and the
## world's.
func slice_tilt() -> float:
	var cam: Camera4D = camera()
	if cam == null:
		return 0.0
	var w: Vector4 = cam.global_basis.w
	return rad_to_deg(acos(clampf(absf(w.w) / maxf(w.length(), 1e-6), -1.0, 1.0)))


## Every path network in the space.
func networks() -> Array:
	var out: Array = []
	for c in get_children():
		if c.has_method("next_library"):
			out.append(c)
	return out


func hud_text() -> String:
	var w: float = player.global_position.w if player != null else 0.0
	var lines: PackedStringArray = PackedStringArray()
	lines.append("PATHCREATOR  ·  dev space")
	lines.append("W %+.2f m      slice tilted %.0f°" % [w, slice_tilt()])
	var lib: String = String(networks()[0].get("default_library")) if not networks().is_empty() else "-"
	lines.append("LOOK %s    SET %s    VIEW %s" % [look.to_upper(), lib, "volume (Combined)" if volume_view else "slice"])
	var notes: int = 0
	for n in networks():
		notes += (n.call("notes") as PackedStringArray).size()
	if notes > 0:
		lines.append("%d route note%s (F4 shows them)" % [notes, "" if notes == 1 else "s"])
	lines.append("Q / E  walk through W    right mouse  tilt the slice")
	lines.append("F4 build    F5 set    F6 DEV / WALK    F7 volume view")
	lines.append("1 start   2 yard   3 W field   4 pen patch   5 W targets")
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_F4:
			set_build(not building)
		KEY_F5:
			for n in networks():
				n.call("next_library")
		KEY_F6:
			set_look("walk" if look == "dev" else "dev")
		KEY_F7:
			set_volume_view(not volume_view)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			# The builder has its own use for the number keys (a new node's kind).
			if not building:
				var place: Array = PLACES[int((event as InputEventKey).keycode) - KEY_1]
				go_to(place[1], float(place[2]))
				get_viewport().set_input_as_handled()


## Puts the player at `at` (x, y, z, W), standing still, the slice flat, facing `yaw` (the rig's;
## NAN keeps the way the camera faces now).
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
		rig.set("_slice_xw", 0.0)
		rig.set("_slice_zw", 0.0)
		rig.set("_homing", 0.0)
		rig.set("yaw", yaw)
		rig.call("_apply")


## Every target in the space (for the builder's map).
func target_nodes() -> Array:
	var out: Array = []
	for group in ["Targets", "Yard", "PenPatch"]:
		var g: Node = get_node_or_null(group)
		if g != null:
			for c in g.get_children():
				if c.has_method("footprint"):
					out.append(c)
	return out


## Build mode (F4): a camera straight down over where you are, at your W, the walker paused, the
## builder over it all. Off again: back on the walker's camera, where you were.
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
			_build_cam.set("rendering_engine_name", "Combined" if volume_view else "Cross-section")
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
	else:
		Input.mouse_mode = _mouse_mode
		builder.visible = false
		hud.visible = true
		player.process_mode = Node.PROCESS_MODE_INHERIT
		var c: Camera4D = camera()
		if c != null:
			c.current = true


## DEV (the sheet's colours, emitted) or WALK (one sand, lit like paint) on every network.
func set_look(l: String) -> void:
	look = l
	for n in networks():
		n.set("look", l)


## The Combined renderer on the player's camera, or the plain slice. The root is handed a 3D world
## first: switching from Cross-section to Combined in one run crashes the engine otherwise
## (menu_final.gd ensure_root_world_3d, the 30 Sept engine bug).
func set_volume_view(on: bool) -> void:
	var cam: Camera4D = camera()
	if cam == null:
		return
	var tree: SceneTree = get_tree()
	if tree.root.world_3d == null:
		tree.root.world_3d = World3D.new()
	volume_view = on
	cam.set("rendering_engine_name", "Combined" if on else "Cross-section")
