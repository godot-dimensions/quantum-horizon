@tool
extends Node4D

## THE VOXEL LAB: the voxel mining prototype remade as a showcase room (Ramon, 6 Oct 2026: "render the
## basic setup, show what it is we want to do. be inspired by the voxel block and what that can do";
## plan and status: VoxelLab/PLAN.md; handover: follow_up/voxel_lab.md). Cutting 4D matter: the
## engine's own voxels (4Denthusiast's VoxelWorld4D), cut live, with every cost measured.
##
## You come in under VOXEL LAB, past a shelf of three pre-cut specimens on your right, to the block on
## its pedestal in the middle. Its story plays once as you come near: it cuts itself (two cuts, a
## tunnel, a hidden room ana of your slice) and is made whole again. On the bench pad in front of it
## you sit down and cut it yourself. Further on, on the left, a column you can cut until it falls; at
## the back, the door to the engine's own test cases.
##
## THIS NODE: the hall's shape (the carried room plan), the player (the kit's grown-up figure, the
## camera behind and above), the HUD (the control strip, the story's title card and callouts, the key
## prompt), which pedestal you are at (its story plays once as you arrive; the wheel slides it through
## W, a right drag turns it), the benches (E or a click on a pad sits you down; the bench has the keys
## until you stand up), the volume view (V) and the grid view (G).
##
## NO class_name (engine_gotchas.md).

const KitPlayer := preload("res://ramon/VoxelLab/carried/kit/kit_player.gd")
const LabMath := preload("res://ramon/VoxelLab/carried/LabKit/lab_math.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const Hud := preload("res://ramon/VoxelLab/carried/scripts/rd_hud.gd")
const Prompt := preload("res://ramon/VoxelLab/carried/kit/kit_prompt.gd")
const Presenter := preload("res://ramon/VoxelLab/carried/kit/kit_presenter.gd")
const Plan := preload("res://ramon/VoxelLab/carried/kit/kit_room_plan.gd")
const Card := preload("res://ramon/VoxelLab/room/vl_card.gd")
const GridView := preload("res://ramon/VoxelLab/room/vl_grid_view.gd")
const DevPanel := preload("res://ramon/VoxelLab/room/vl_dev_panel.gd")
const FIELD := "res://ramon/VoxelLab/field/voxel_field.tscn"

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

@export_group("Visit")
## Where you start (x, z), facing the block.
@export var start_at: Vector2 = Vector2(0.0, 17.5)
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
var card: Control
var dev_panel: Control
var stations: Array = []
var benches: Array = []
## The pedestal you are at (a carried showcase), or null; the bench you sit at, or null.
var active: Node = null
var bench: Node = null
var plan: Dictionary = {}
var volume_view: bool = false
var grid_view: bool = false
var _near: Dictionary = {}
var _visited: Dictionary = {}
var _at_pad: Node = null
var _at_door: bool = false
## What you have done, by route destination (the Paths/Targets names): sat at a bench, looked at the
## shelf, gone through a door.
var _done: Dictionary = {}
var _at_console: Node = null
var _card_open: bool = false
var _card_t: float = 0.0
var _shape_queued: bool = false
var _grid: RefCounted
## The story camera (see _run_film), its state, and the station whose story you took the camera back
## from (it waits for that story to end before it films again).
var _film_cam: Camera4D
var _film: Dictionary = {}
var _film_declined: Node = null


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
	for s in get_tree().get_nodes_in_group("kit_showcase"):
		if is_ancestor_of(s):
			stations.append(s)
	for b in get_tree().get_nodes_in_group("vl_bench"):
		if is_ancestor_of(b):
			benches.append(b)
			b.connect("docked_changed", _on_docked.bind(b))
	player = KitPlayer.make()
	add_child(player)
	go_to(Vector4(start_at.x, 0.05, start_at.y, 0.0), 0.0)
	if arrive_from == "field" and get_node_or_null("FieldDoor") != null:
		var d: Vector4 = (get_node("FieldDoor") as Node4D).position
		# Just inside the far door, facing back into the gallery.
		go_to(Vector4(0.0, 0.05, d.z + 2.2, 0.0), PI)
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
	hud.connect("mood_pressed", toggle_palette)
	_label_switch()
	presenter = Control.new()
	presenter.name = "Presenter"
	presenter.set_script(Presenter)
	presenter.set("room", self)
	layer.add_child(presenter)
	prompt = Control.new()
	prompt.set_script(Prompt)
	prompt.set("camera", camera())
	layer.add_child(prompt)
	card = Control.new()
	card.name = "Card"
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
	# The block's story turns the grid view on for its part about voxels.
	for s in stations:
		var ex: Node = s.get("exhibit")
		if ex != null and "grid_view_hook" in ex:
			ex.set("grid_view_hook", func(on: bool) -> void: _grid_for(s, on))


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
		var gz: float = -d - 0.5 - gallery_depth * 0.5
		gal.position = Vector4(0.0, 0.0, gz, 0.0)
		_set_if(gal, "size", Vector3(gallery_width, gallery_height, gallery_depth))
		var gdoors: Array = [["s", -dw * 0.5, dw * 0.5, minf(door_height, gallery_height - 0.5)]] if dw > 0.1 else []
		# The far door, out to the field (Andrew's landscape, generated round you).
		gdoors.append(["n", -1.6, 1.6, minf(4.2, gallery_height - 0.5)])
		_set_if(gal, "doorways", gdoors)
		var door: Node4D = get_node_or_null("FieldDoor") as Node4D
		if door != null:
			door.position = Vector4(0.0, 2.4, gz - gallery_depth * 0.5 - 0.2, 0.0)


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


func _label_switch() -> void:
	if hud != null:
		hud.set("switch_text", "GREY  ·  B" if Style.palette == "black" else "BLACK  ·  B")
		hud.call("refresh_switch")


func apply_mood(m: String, _instant: bool = false) -> void:
	Style.apply(m)
	if hud != null:
		hud.call("set_mood", m)


# -- each frame ----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	if bench != null:
		hud.set("strip", bench.call("strip"))
		presenter.set("active", false)
		prompt.set("shown", false)
		return
	var p: Vector4 = player.global_position
	_find_active(p)
	_read_pads(p)
	_read_console(delta)
	_run_film(delta)
	if presenter != null:
		presenter.set("showcase", active)
		presenter.set("active", active != null and not _card_open)
	hud.set("strip", _strip())
	_route_states(p)


## The pedestal you are at: the nearest whose edge is within `story_margin`. Arriving at one plays its
## story once; a click or the arrows step through it.
func _find_active(p: Vector4) -> void:
	var best: Node = null
	var best_d: float = INF
	var dist: Dictionary = {}
	for s in stations:
		var sp: Vector4 = (s as Node4D).global_position
		var d: float = Vector2(p.x - sp.x, p.z - sp.z).length() - float(s.get("radius"))
		dist[s] = d
		if d < story_margin and d < best_d:
			best_d = d
			best = s
	# Only the pedestal you are at plays its story: two near ones at once (the block and the column
	# overlap) played both, the block cutting itself while you watched the column (6 Oct).
	for s in stations:
		var d: float = float(dist[s])
		var ex: Node = s.get("exhibit")
		var has_story: bool = ex != null and not (ex.call("chapters") as Array).is_empty()
		var near: bool = s == best
		if has_story and near and not bool(_near.get(s, false)) and not bool(s.get("armed")) and int(s.get("seq_index")) < 0:
			s.call("replay")
			_visited[s] = true
		if (not near) and (bool(s.get("armed")) or int(s.get("seq_index")) >= 0) and d > story_margin * 0.5:
			s.call("_finish")
		_near[s] = near
	active = best


## Standing on a bench's pad pops its prompt.
func _read_pads(p: Vector4) -> void:
	var at: Node = null
	for b in benches:
		if bool(b.call("near", p)):
			at = b
	_at_pad = at
	var door: Node4D = get_node_or_null("FieldDoor") as Node4D
	_at_door = door != null and at == null and Vector2(p.x - door.global_position.x, p.z - door.global_position.z).length() < 2.2
	# A pad's key is on the control strip and painted on the pad itself: a floating prompt over a pad
	# stood right over the block from where you stand (6 Oct), and nothing may cover an exhibit.
	if prompt != null and _at_console == null:
		prompt.set("shown", _at_door)
		if _at_door:
			prompt.set("target", door)
			prompt.set("text", "Out to the field")


func _read_console(delta: float) -> void:
	var at: Node = null
	for c in get_tree().get_nodes_in_group("vl_console"):
		if is_ancestor_of(c) and bool(c.call("near", player.global_position)):
			at = c
	if at != _at_console:
		_card_open = false
	_at_console = at
	if at != null and prompt != null:
		prompt.set("shown", true)
		prompt.set("target", at)
		prompt.set("text", "Close" if _card_open else "About this specimen")
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


func _strip() -> Array:
	if _at_console != null:
		return [["E / Click", "Close the card" if _card_open else "About this specimen"], ["WASD", "Move"]]
	if _at_pad != null:
		return [["E / Click", "Sit at the bench"], ["WASD", "Move"]]
	if _at_door:
		return [["E / Click", "Out to the field"], ["WASD", "Move"]]
	if active == null:
		return [["WASD", "Move"], ["Mouse", "Look"], ["B", "Black / grey"]]
	var out: Array = []
	if int(active.get("seq_index")) >= 0:
		out.append(["Click / ← →", "Next part"])
	elif bool(active.call("can_skip")) and not (active.get("exhibit").call("chapters") as Array).is_empty():
		out.append(["Click", "Play its story"])
	out.append(["Wheel", "Slide through W"])
	out.append(["Right drag", "Turn in 4D"])
	var label: String = String(active.call("action_label"))
	if not label.is_empty():
		out.append(["E", label])
	out.append(["V", "Volume view" if not volume_view else "Slice view"])
	out.append(["B", "Black / grey"])
	return out


# -- the benches ---------------------------------------------------------------------------------------

func sit(b: Node) -> void:
	if b == null or bench != null:
		return
	b.call("dock", self)


func _on_docked(on: bool, b: Node) -> void:
	if on:
		# The bench's camera is already current: the story camera just goes (handing the view to the
		# player's camera here sat you at the bench looking from behind yourself, 6 Oct).
		_film_stop(false)
		bench = b
		_done[String(b.name)] = true
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
	if active != null and String(active.name).begins_with("Shelf"):
		_done["Shelf"] = true
	if active != null and String(active.name) in ["Cell24", "Ladder"]:
		_done[String(active.name)] = true
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
			elif not next_found:
				next_found = true
				var tn: Node4D = get_node_or_null("Paths/Targets/" + target) as Node4D
				var near: bool = tn != null and Vector2(p.x - tn.global_position.x, p.z - tn.global_position.z).length() < 3.0
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
			if _at_console != null:
				toggle_card()
				get_viewport().set_input_as_handled()
				return
			if _at_pad != null:
				sit(_at_pad)
				get_viewport().set_input_as_handled()
				return
			if _at_door:
				to_field()
				get_viewport().set_input_as_handled()
				return
			if active != null and bool(active.call("can_skip")) and not (active.get("exhibit").call("chapters") as Array).is_empty():
				active.call("skip")
				get_viewport().set_input_as_handled()
				return
		if active != null and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			active.call("step_slice", 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			get_viewport().set_input_as_handled()
			return
	var mm := event as InputEventMouseMotion
	# Looking round takes the camera back from the story.
	if mm != null and _film_cam != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) == 0 			and mm.relative.length() > 3.0:
		_film_declined = _film.get("station")
	if mm != null and active != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		active.call("turn_by", mm.relative.x * 0.006, mm.relative.y * 0.006)
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or player == null or bench != null:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_E:
			if _at_console != null:
				toggle_card()
			elif _at_pad != null:
				sit(_at_pad)
			elif _at_door:
				to_field()
			elif active != null and not String(active.call("action_label")).is_empty():
				# The station's own key: the column's tree, the ladder's timed cuts.
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
		KEY_V:
			toggle_volume_view()
			get_viewport().set_input_as_handled()
		KEY_G:
			toggle_grid_view()
			get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_LEFT:
			if active != null and bool(active.call("can_skip")):
				active.call("skip" if k.keycode == KEY_RIGHT else "skip_back")
				get_viewport().set_input_as_handled()


# -- the story camera ----------------------------------------------------------------------------------

## While a pedestal's story plays and you stand still, a camera eases to each part's own shot (the
## exhibit's chapters carry eye, look and lens; the kit's showcase places them in the room with
## shot()), so the cuts read at the size they were made at: from the player's own camera the block's
## holes were a few pixels across (6 Oct). Move or look round and it eases back to you, and waits for
## the next story. Only exhibits whose chapters carry shots are filmed (the block, the column). The
## Arboretum's tour moves its camera the same way.
func _run_film(delta: float) -> void:
	var s: Node = active
	if _film_declined != null and (s != _film_declined or int(_film_declined.get("seq_index")) < 0):
		_film_declined = null
	if _film_cam != null and String(_film.get("phase", "")) == "shot":
		for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]:
			if Input.is_key_pressed(key) and bool(player.get("input_enabled")):
				_film_declined = _film.get("station")
	var want: bool = story_camera and s != null and s != _film_declined and int(s.get("seq_index")) >= 0 and not _card_open and _has_shots(s)
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
	hud.call("toast", "Volume view: the whole 4D specimen, faintly" if volume_view else "Slice view")


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
