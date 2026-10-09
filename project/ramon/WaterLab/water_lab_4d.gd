@tool
extends Node4D

## THE WATER LAB (Ramon, 9 Oct 2026): a showcase of water in 4D, opening on a koi tank. Plan and
## handover: follow_up/water_lab.md. Two scenes, this room and the sea through its far door
## (seascape/seascape.tscn).
##
## YOU COME IN at the bottom left, from a short corridor under WATER LAB, and the tank is in front of
## you across the back of the hall: koi, an eel, a crab, weed, corals and stones, in water drawn per
## pixel against the tank as a 4D box (tank/). The floor route (the carried PathCreator) is straight
## runs and square turns (Ramon: "make sure the main path stays straight. at most a little subpath
## branch"): north up the left, right along the glass, north up the gap by the tank's end to the
## sci-fi door. Its one branch leaves the second turn the other way, south along the research wall,
## to the koi showcase in the south-east corner.
##
##   THE TURNING CIRCLE  half way along the glass, the route passes through a big round destination
##                     (Ramon: "a spinnable path creator circle ... in the mid of the fishtank"): in it
##                     a right drag turns your slice (the pen's rig, Andrew's directions), and the
##                     koi that live off the level slice swim into view. Step out and it levels.
##   FEEDING           the console at the glass: E drops a pinch of pellets on the surface, and the
##                     koi rise for them.
##   THE SHOWCASE      in the south-east corner: a koi four times life size swimming on the spot in a column of
##                     blue light (room/koi_showcase_4d.gd): the wheel slides it through W, a right
##                     drag turns it, and its floating panel (the Voxel Lab's) pages through more
##                     with E.
##   THE WALLS         the introduction (left) and the research board (right), which turns its own
##                     pages: the waves, the slice, the tank's water, the koi, the cost.
##   THE DOOR          slides open as you come; walk in and the sea loads.
##
## THIS NODE: the player (the pen's walk and rig, the Creation Lab's camera), the HUD, which spot or
## pedestal you are at, the door, the route's states. Everything else is a node of its own in the
## scene. NO class_name (engine_gotchas.md).

const KitPlayer := preload("res://ramon/WaterLab/carried/kit/kit_player.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")
const Hud := preload("res://ramon/WaterLab/carried/scripts/rd_hud.gd")
const Prompt := preload("res://ramon/WaterLab/carried/kit/kit_prompt.gd")
const Mats := preload("res://ramon/WaterLab/carried/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/WaterLab/carried/LabKit/lab_grid.gd")
const Build := preload("res://ramon/WaterLab/carried/scripts/chamber_build.gd")
const GB := preload("res://ramon/WaterLab/carried/LabKit/carried/chickenpen/scripts/ground_basis_4d.gd")
const Builder := preload("res://ramon/WaterLab/carried/PathCreator/builder/pc_builder.gd")
const Dial := preload("res://ramon/WaterLab/room/tank_dial.gd")

const SEA_SCENE := "res://ramon/WaterLab/seascape/seascape.tscn"
## The tree's meta that says where you are arriving from (the sea sets it on its way back).
const ARRIVE_META := "water_lab_arrive"

@export_group("Visit")
## Where you start (x, z), in the entrance corridor, facing the tank.
@export var start_at: Vector2 = Vector2(-11.0, 18.0)
## The turning circle (a destination on the route half way along the glass, its big round frame
## round Paths/Targets/TurnSpot): its middle (x, z) and radius.
@export var turn_spot: Vector2 = Vector2(-4.23, -8.2)
@export var turn_radius: float = 1.5
## The feeding console, on the room's side of the row facing the tank: where it stands (x, z), and
## how near counts as at it.
@export var feed_at: Vector2 = Vector2(-9.2, -6.9)
@export var feed_reach: float = 1.8
## How far beyond its pedestal's edge the showcase counts as the one you are at.
@export var showcase_margin: float = 2.6

@export_group("Camera")
## The Creation Lab's (creation_lab_4d.gd: 5.0, 2.45, -11), as Ramon asked for this room.
@export_range(2.0, 12.0, 0.1) var camera_distance: float = 5.0
@export_range(0.5, 3.5, 0.05) var camera_height: float = 2.45
@export_range(-45.0, 20.0, 0.5) var camera_pitch_degrees: float = -11.0

var player: CharacterBody4D
var hud: Control
var prompt: Control
var builder: Control
var dial: Control
var tank: Node4D
var showcase: Node4D
## The showcase while you are at it (the wheel and a right drag are its), else null.
var active: Node = null
var building: bool = false
var _rig: Node
var _door: Node4D
var _fade: ColorRect
var _leaving: float = -1.0
var _on_turn: bool = false
var _at_feed: bool = false
var _feed_cooldown: float = 0.0
var _visited: Dictionary = {}
var _near_panel: bool = false
var _build_cam: Camera4D
var _mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func _ready() -> void:
	var room: Node = get_node_or_null("Room")
	if room != null:
		room.set("mood_overrides", Style.ROOM_LIGHT.duplicate(true))
		room.call("set_mood", "bright", true, false)
		room.set("mood_key", KEY_NONE)
	Style.apply("bright")
	var old_spot: Node = get_node_or_null("TurnSpot")
	if old_spot != null:
		remove_child(old_spot)
		old_spot.queue_free()
	_build_feeder()
	if Engine.is_editor_hint():
		return
	tank = get_node_or_null("Tank") as Node4D
	showcase = get_node_or_null("Showcase") as Node4D
	_door = get_node_or_null("ExitDoor") as Node4D
	player = KitPlayer.make()
	player.name = "Player"
	add_child(player)
	_rig = player.get_node_or_null("CameraRig")
	if _rig != null:
		_rig.set("slice_turning", false)
		_rig.set("pitch", deg_to_rad(camera_pitch_degrees))
		_rig.set("distance", camera_distance)
		_rig.set("_zoom_target", camera_distance)
		_rig.set("_rest_distance", camera_distance)
		_rig.set("pivot_height", camera_height)
		_rig.set("_home_pivot", camera_height)
		_rig.call("_apply")
	if tank != null:
		var dn: Node = tank.get("dunes")
		var rf: Node = tank.get("reef")
		print("WATER LAB built: dunes %.0f ms (%d tets), reef %.0f ms (%d tets)" % [float(dn.get("build_ms")) if dn != null else -1.0,
			int(dn.get("tets")) if dn != null else 0, float(rf.get("build_ms")) if rf != null else -1.0, int(rf.get("tets")) if rf != null else 0])
	var from_sea: bool = String(get_tree().root.get_meta(ARRIVE_META, "")) == "sea"
	get_tree().root.remove_meta(ARRIVE_META)
	if from_sea and _door != null:
		# Back from the sea: just inside the far door, facing into the room, the door shutting.
		var d: Vector4 = _door.global_position
		go_to(Vector4(d.x, 0.05, d.z + 2.2, 0.0), PI)
		_door.set("open", 1.0)
	else:
		go_to(Vector4(start_at.x, 0.05, start_at.y, 0.0), 0.0)
	_build_hud()
	_build_hum()
	if showcase != null:
		showcase.call("set_player", player)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Control.new()
	hud.set_script(Hud)
	hud.set("glass", true)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	hud.connect("mood_pressed", toggle_palette)
	_label_switch()
	dial = Control.new()
	dial.name = "TankDial"
	dial.set_script(Dial)
	layer.add_child(dial)
	dial.set("tank", get_node_or_null("Tank"))
	prompt = Control.new()
	prompt.set_script(Prompt)
	prompt.set("camera", player.get_node_or_null("CameraRig/Pitch/Camera4D"))
	prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(prompt)
	var fl := CanvasLayer.new()
	fl.name = "Fade"
	fl.layer = 20
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.add_child(_fade)
	var blayer := CanvasLayer.new()
	blayer.name = "Builder"
	blayer.layer = 6
	add_child(blayer)
	builder = Control.new()
	builder.set_script(Builder)
	builder.set("space", self)
	builder.visible = false
	blayer.add_child(builder)


# -- the turning spot and the feeder ------------------------------------------------------------------

## The feeding console at the glass: a small dark lectern with a lit amber button on its top.
func _build_feeder() -> void:
	var old: Node = get_node_or_null("Feeder")
	if old != null:
		remove_child(old)
		old.queue_free()
	var holder := Node4D.new()
	holder.name = "Feeder"
	holder.position = Vector4(feed_at.x, 0.0, feed_at.y, 0.0)
	add_child(holder)
	var dark := Color(0.13, 0.14, 0.16)
	var post := MeshInstance4D.new()
	post.name = "Post"
	post.mesh = Mats.box_mesh(Vector4(0.5, 1.0, 0.4, Build.W_DEPTH))
	post.position = Vector4(0.0, 0.5, 0.0, 0.0)
	post.material_override = Mats.flat(dark)
	holder.add_child(post)
	var top := MeshInstance4D.new()
	top.name = "Top"
	top.mesh = Mats.box_mesh(Vector4(0.8, 0.08, 0.55, Build.W_DEPTH))
	top.position = Vector4(0.0, 1.04, 0.0, 0.0)
	top.basis = Basis4D.from_yz(0.25)
	top.material_override = Mats.flat(Style.lip())
	holder.add_child(top)
	var button := MeshInstance4D.new()
	button.name = "Button"
	button.mesh = Build._cubinder(0.13, 0.05, 32)
	button.position = Vector4(0.0, 1.1, 0.02, 0.0)
	button.basis = Basis4D.from_yz(0.25)
	button.material_override = Mats.glow(Color(1.0, 0.62, 0.22), 1.6)
	holder.add_child(button)
	var body := StaticBody4D.new()
	body.name = "Solid"
	body.position = Vector4(0.0, 0.55, 0.0, 0.0)
	var shape := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = Vector4(0.8, 1.1, 0.55, Build.W_DEPTH)
	shape.shape = bs
	body.add_child(shape)
	holder.add_child(body)


# -- looks ------------------------------------------------------------------------------------------------

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


# -- each frame -------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	if _leaving >= 0.0:
		_leave(delta)
		return
	if building:
		return
	var p: Vector4 = player.global_position
	if tank != null and tank.has_method("set_viewer"):
		tank.call("set_viewer", p + Vector4(0.0, 1.5, 0.0, 0.0))
	_turning(p)
	_hum_level(p, delta)
	_feeding(p, delta)
	_find_active(p)
	if _door != null:
		_door.call("notice", p)
		if bool(_door.call("inside", p)):
			_leaving = 0.0
			player.set("input_enabled", false)
	hud.set("strip", _strip())
	_route_states(p)


var _hum: AudioStreamPlayer


## The tank's sound: the filter pump's hum, the air stone's bubbles, a trickle (audio/tank_hum.wav,
## looped in code: the import's loop settings do nothing in this build). Louder near the glass.
func _build_hum() -> void:
	var path := "res://ramon/WaterLab/audio/tank_hum.wav"
	if not ResourceLoader.exists(path):
		return
	var s: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * float(s.mix_rate))
	_hum = AudioStreamPlayer.new()
	_hum.name = "TankHum"
	_hum.stream = s
	_hum.volume_db = -40.0
	add_child(_hum)
	_hum.play()


## -14 dB at the glass, falling off with distance to -36 dB across the hall.
func _hum_level(p: Vector4, delta: float) -> void:
	if _hum == null or tank == null:
		return
	var front := Vector2(clampf(p.x, tank.global_position.x - 9.0, tank.global_position.x + 9.0), tank.global_position.z + 2.0)
	var d: float = Vector2(p.x, p.z).distance_to(front)
	var want: float = lerpf(-14.0, -36.0, clampf((d - 1.0) / 20.0, 0.0, 1.0))
	_hum.volume_db = lerpf(_hum.volume_db, want, minf(delta * 3.0, 1.0))


## In the circle the tank's gizmo shows, and a right drag turns what is IN the tank through W (not your
## slice: the room stays as it is; Ramon, 9 Oct).
func _turning(p: Vector4) -> void:
	var on: bool = Vector2(p.x - turn_spot.x, p.z - turn_spot.y).length() < turn_radius + 0.1
	if on != _on_turn:
		_on_turn = on
		if on:
			hud.call("toast", "Right drag: turn the tank's contents through W")
	if dial != null:
		dial.set("shown", on)


func _feeding(p: Vector4, delta: float) -> void:
	_feed_cooldown = maxf(_feed_cooldown - delta, 0.0)
	var at: bool = Vector2(p.x - feed_at.x, p.z - feed_at.y).length() < feed_reach
	_at_feed = at
	if prompt == null:
		return
	var feeder: Node4D = get_node_or_null("Feeder") as Node4D
	prompt.set("shown", at)
	if at and feeder != null:
		prompt.set("target", feeder)
		prompt.set("offset", Vector4(0.0, 1.5, 0.0, 0.0))
		prompt.set("text", "Feed the koi" if _feed_cooldown <= 0.0 else "They are eating")


func feed() -> void:
	if _feed_cooldown > 0.0 or tank == null:
		return
	var koi: Node = tank.get("koi")
	if koi == null or not koi.has_method("drop_food"):
		return
	_feed_cooldown = 6.0
	# Over the water in front of the console, near the glass.
	var life: Node4D = tank.get("life")
	var at: Vector4 = life.global_basis.inverse() * (Vector4(feed_at.x, 0.0, feed_at.y, 0.0) - life.global_position)
	koi.call("drop_food", at.x)
	hud.call("toast", "A pinch of food on the water")


## The showcase: you are at it within `showcase_margin` of its pedestal's edge; at its floating panel,
## E pages through it.
func _find_active(p: Vector4) -> void:
	active = null
	_near_panel = false
	if showcase == null:
		return
	var sp: Vector4 = showcase.global_position
	var d: float = Vector2(p.x - sp.x, p.z - sp.z).length() - float(showcase.get("radius"))
	if d < showcase_margin:
		active = showcase
	_near_panel = bool(showcase.call("near_panel", p))


func _strip() -> Array:
	if _at_feed:
		return [["E", "Feed the koi"], ["WASD", "Move"]]
	if _on_turn:
		return [["Right drag", "Turn the tank through W"], ["Wheel", "Slide it through W"], ["R", "Back"], ["WASD", "Move"]]
	if active != null:
		var out: Array = [["Wheel", "Slide it through W"], ["Right drag", "Turn it"], ["R", "Whole again"]]
		if _near_panel:
			out.push_front(["E", "Its panel: more"])
		return out
	return [["WASD", "Move"], ["Mouse", "Look"], ["B", "Black / grey"]]


# -- the route ----------------------------------------------------------------------------------------------

## The destinations completed once you have been to them; the next one along lit.
func _route_states(p: Vector4) -> void:
	var net: Node = get_node_or_null("Paths/Hall")
	if net == null or net.get("graph") == null:
		return
	var targets: Node = get_node_or_null("Paths/Targets")
	if targets != null:
		for t in targets.get_children():
			var tp: Vector4 = (t as Node4D).global_position
			var fp: Vector2 = t.call("footprint") if t.has_method("footprint") else Vector2(2, 2)
			if Vector2(p.x - tp.x, p.z - tp.z).length() < maxf(fp.x, fp.y) * 0.5 + 2.6:
				_visited[String(t.name)] = true
	var graph: Resource = net.get("graph")
	var changed: bool = false
	var next_found: bool = false
	for n in graph.get("nodes"):
		if String(n.get("kind", "")) != "destination":
			continue
		var target: String = String(n.get("target", ""))
		var want: String
		if _visited.has(target):
			want = "completed"
		elif not next_found:
			want = "available"
			next_found = true
		else:
			want = "arrival"
		if String(n.get("state", "")) != want:
			n["state"] = want
			changed = true
	if changed:
		graph.emit_changed()


# -- leaving for the sea -------------------------------------------------------------------------------------

func _leave(delta: float) -> void:
	_leaving += delta
	_fade.color.a = clampf(_leaving / 0.6, 0.0, 1.0)
	if _leaving >= 0.65:
		_leaving = -100.0
		get_tree().root.set_meta(ARRIVE_META, "lab")
		get_tree().change_scene_to_file(SEA_SCENE)


# -- the mouse and keys ------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or player == null or building:
		return
	if _on_turn and tank != null:
		var tb := event as InputEventMouseButton
		if tb != null and tb.pressed and (tb.button_index == MOUSE_BUTTON_WHEEL_UP or tb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			tank.call("slide_contents", 0.25 if tb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.25)
			get_viewport().set_input_as_handled()
			return
		var tm := event as InputEventMouseMotion
		if tm != null and (tm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			tank.call("turn_contents", tm.relative.x * 0.004)
			get_viewport().set_input_as_handled()
			return
	if active == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			active.call("step_slice", 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			get_viewport().set_input_as_handled()
			return
	var mm := event as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
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
	match k.keycode:
		KEY_E:
			if _at_feed:
				feed()
				get_viewport().set_input_as_handled()
			elif _near_panel and showcase != null:
				showcase.call("activate")
				get_viewport().set_input_as_handled()
		KEY_R:
			# At the showcase R makes the koi whole again; in the circle it puts the tank's contents
			# back (the rig levels the slice, as everywhere).
			if active != null:
				active.call("reset")
			if _on_turn and tank != null:
				tank.call("set_contents", 0.0, 0.0)
		KEY_B:
			if not k.shift_pressed and not k.ctrl_pressed:
				toggle_palette()
				get_viewport().set_input_as_handled()


# -- helpers ------------------------------------------------------------------------------------------------------

func camera() -> Camera4D:
	return player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D if player != null else null


## Whether the guided tour is running (the presenter asks; this room has none).
func touring() -> bool:
	return false


## How far the slice is tilted from level, degrees (the panels read it).
func slice_degrees() -> float:
	if _rig == null:
		return 0.0
	return rad_to_deg(GB.tilt((_rig as Node4D).basis))


## Puts the player at `at`, standing still, facing `yaw` (the pen's rig: 0 faces -z and the tank, PI
## faces +z, -PI/2 faces +x).
func go_to(at: Vector4, yaw: float) -> void:
	if player == null:
		return
	player.global_position = at
	player.set("linear_velocity", Vector4.ZERO)
	player.set("_facing", yaw)
	if _rig != null:
		_rig.set("yaw", yaw)
		_rig.call("_apply")


func networks() -> Array:
	var out: Array = []
	var paths: Node = get_node_or_null("Paths")
	if paths != null:
		for c in paths.get_children():
			if c.has_method("next_library"):
				out.append(c)
	return out


func target_nodes() -> Array:
	var out: Array = []
	var t: Node = get_node_or_null("Paths/Targets")
	if t != null:
		for c in t.get_children():
			if c.has_method("footprint"):
				out.append(c)
	return out


## F4: the path builder (the carried PathCreator's), as in the Arboretum.
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
	else:
		Input.mouse_mode = _mouse_mode
		builder.visible = false
		hud.visible = true
		player.process_mode = Node.PROCESS_MODE_INHERIT
		var c: Camera4D = camera()
		if c != null:
			c.current = true
