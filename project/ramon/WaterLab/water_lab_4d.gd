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
const FloatPanel := preload("res://ramon/WaterLab/carried/voxel_lab/float_panel_4d.gd")
const LabPrint := preload("res://ramon/WaterLab/carried/LabKit/lab_print.gd")
const PenWalk := preload("res://ramon/WaterLab/shared/pen_walk.gd")
const MouseTutorial := preload("res://ramon/WaterLab/shared/mouse_tutorial.gd")

const SEA_SCENE := "res://ramon/WaterLab/seascape/seascape.tscn"
## The tree's meta that says where you are arriving from (the sea sets it on its way back).
const ARRIVE_META := "water_lab_arrive"

@export_group("Visit")
## Where you start (x, z), at the back of the entrance corridor, facing the tank.
@export var start_at: Vector2 = Vector2(-11.0, 13.2)
## The turning square in front of the tank's middle (Ramon, 9 Oct: "a blue square there that you can
## stand on"; a circle cut into the tank's stand): its middle (x, z) and half its side.
@export var turn_spot: Vector2 = Vector2(-5.23, -7.7)
@export var turn_radius: float = 1.5
## The feeding console, on the room's side of the row facing the tank: where it stands (x, z), and
## how near counts as at it.
@export var feed_at: Vector2 = Vector2(-8.7, -8.85)
@export var feed_reach: float = 1.8
## How far beyond its pedestal's edge the showcase counts as the one you are at.
@export var showcase_margin: float = 1.8

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
var tutorial: Control
## Seconds left of following the shark (V): the contents slid so it stays in your slice.
var _follow_shark: float = 0.0
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
var _fed: int = 0
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
	_paint_square.call_deferred()
	_darken_airlock.call_deferred()
	# The route's frames and done ticks in the arrows' blue, its frames closer (round 3).
	var net: Node = get_node_or_null("Paths/Hall")
	if net != null:
		net.set("edge_color", Color("#1761d7"))
		net.set("frame_margin", 0.12)
		# Its arrows' edges follow the floor in dark mode too (round 4).
		net.set("floor_swatch", "kit_floor")
	# The introduction a metre to the left as you face it (round 3).
	var intro: Node = get_node_or_null("IntroPanel")
	if intro != null:
		intro.set("along_shift", 1.0)
	tank = get_node_or_null("Tank") as Node4D
	showcase = get_node_or_null("Showcase") as Node4D
	_door = get_node_or_null("ExitDoor") as Node4D
	player = KitPlayer.make()
	player.name = "Player"
	# The playable world's walk, stepping through W on Q/E included (round 4). E also feeds the koi and
	# pages the showcase's panel, so stepping pauses at those two (_process).
	PenWalk.apply(player)
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
	var feeder: Node = get_node_or_null("Feeder")
	if feeder != null:
		feeder.set("player", player)


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
	# Tab: the lights' dev HUD (round 2).
	var lights_hud := PanelContainer.new()
	lights_hud.name = "LightEditor"
	lights_hud.set_script(load("res://ramon/WaterLab/room/light_editor.gd"))
	lights_hud.set("room", self)
	layer.add_child(lights_hud)
	tutorial = Control.new()
	tutorial.name = "MouseTutorial"
	tutorial.set_script(MouseTutorial)
	tutorial.set("gestures", [["drag_v", "SLIDE THROUGH W"], ["drag_h", "TURN THROUGH W"], ["wheel", "TURN FRONT TO BACK"]])
	layer.add_child(tutorial)
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

## The feeding booth: the Voxel Lab's small white floating panel (Ramon, 9 Oct: "for the feed the koi
## booth, please use the floating panels ... and you can press E to feed the koi there"), facing the
## route, leaning and turning a little toward you as you come. It used to be a dark lectern.
func _build_feeder() -> void:
	var old: Node = get_node_or_null("Feeder")
	if old != null:
		remove_child(old)
		old.queue_free()
	var panel := Node4D.new()
	panel.name = "Feeder"
	panel.set_script(FloatPanel)
	panel.position = Vector4(feed_at.x, 0.0, feed_at.y, 0.0)
	panel.set("face_point", Vector2(feed_at.x, feed_at.y + 4.0))
	panel.set("width", 1.15)
	panel.set("number", 0)
	panel.set("title", "Feed the koi")
	panel.set("kicker", "A PINCH OF PELLETS, SINKING TO THEM")
	panel.set("hint", "E   FEED THE KOI")
	panel.set("rows", _feeder_rows())
	add_child(panel)


## THE TURNING SQUARE IS FLOOR PAINT (Ramon, 9 Oct, round 2: a blue square to stand on, "TURN THE TANK
## THROUGH W" on it; then: "its not blue but cyan ... the blue panel is visible a block above ground.
## should be floor paint so to speak ... check out how the creation lab walls were built"). Painted
## into the hall floor's own surface the way the lab's walls carry their words (LabPrint: drawn once,
## read back, mipmapped, printed into the surface; emitted rather than lit, as the path's own marks
## are, so the spots over the tank do not wash it to cyan): a code-blue square with the path frames' 45-degree corners, the words in
## white. The route ends at its west edge and starts again at its east edge (its node draws no art of
## its own and keeps the route `turn_radius` + a hand clear), and the path's corner brackets frame it.
var _painted_floor: MeshInstance4D = null
var _square_tex: Texture2D = null


func _paint_square() -> void:
	var hall: Node4D = get_node_or_null("Hall") as Node4D
	if hall == null:
		return
	var fl: MeshInstance4D = hall.call("floor_box")
	if fl == null or fl == _painted_floor:
		return
	_painted_floor = fl
	if _square_tex == null:
		var side: float = turn_radius * 2.0
		_square_tex = await LabPrint.render(get_tree(), Vector2i(int(side * 400.0), int(side * 400.0)), _square_picture)
	if _square_tex == null or not is_instance_valid(fl):
		return
	var hs: Vector3 = hall.get("size")
	var hp: Vector4 = hall.global_position
	var x0: float = hp.x - hs.x * 0.5
	var z1: float = hp.z + hs.z * 0.5
	var rect := Rect2(Vector2(turn_spot.x - turn_radius - x0, z1 - (turn_spot.y + turn_radius)), Vector2(turn_radius, turn_radius) * 2.0)
	var m: TetraMaterial4D = fl.material_override as TetraMaterial4D
	LabGrid.set_print(m, _square_tex, Vector4(0, 1, 0, 0), rect, Color.WHITE, 0.0)
	LabGrid.set_print_strength(m, 1.0)
	m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)
	# As light, not paint: lit by the tank's spots the code blue clipped to cyan (the path's marks are
	# emitted the same way, and read as the same blue).
	m.get_cross_section_material_3d().set_shader_parameter("print_emit", 1.0)
	m.get_cross_section_material_3d().set_shader_parameter("print_white_boost", 0.7)


## The airlock behind the far door, dark (Ramon, round 3: "through the jitter holographic door behind
## it, I see a room. This is not great ... Make the room behind it dark, like the black grid lines"):
## every surface of it in the kit's dark swatch, so the hologram shows against a dark grid. Again when
## the room rebuilds (its floor box changes).
var _dark_floor: MeshInstance4D = null


func _darken_airlock() -> void:
	var airlock: Node = get_node_or_null("Airlock")
	if airlock == null or not airlock.has_method("floor_box"):
		return
	var fl: MeshInstance4D = airlock.call("floor_box")
	if fl == null or fl == _dark_floor:
		return
	_dark_floor = fl
	for n in airlock.find_children("*", "MeshInstance4D", true, false):
		var m: TetraMaterial4D = (n as MeshInstance4D).material_override as TetraMaterial4D
		if m != null and m.has_meta("lab_swatch"):
			LabGrid.reswatch(m, "drum")


## The square's picture (premultiplied: opaque blue, white over it).
func _square_picture(c: Control) -> void:
	var sz: Vector2 = c.size
	var u: float = sz.x / (turn_radius * 2.0)
	var blue: Color = Style.pick(Style.CODE_BLUE)
	# The path frames' corners: cut at 45 degrees, 0.21 m.
	var k: float = 0.21 * u
	c.draw_colored_polygon(PackedVector2Array([Vector2(k, 0), Vector2(sz.x - k, 0), Vector2(sz.x, k), Vector2(sz.x, sz.y - k),
		Vector2(sz.x - k, sz.y), Vector2(k, sz.y), Vector2(0, sz.y - k), Vector2(0, k)]), blue)
	# An inset outline (round 3: "a little square outline ... inside the blue panel, a little bit
	# inset, just a little bit of outline at the corners, and then with a break"): a bracket at each
	# corner, cut at 45 degrees as the square's own corners are, and open along the middle of each side.
	var white := Color(1, 1, 1, 1)
	var inset: float = 0.15 * u
	var arm: float = 0.5 * u
	var cut: float = 0.12 * u
	var lw: float = maxf(2.0, 0.022 * u)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var sx: float = 1.0 if corner.x < 0.5 else -1.0
		var sy: float = 1.0 if corner.y < 0.5 else -1.0
		var o := Vector2(inset if corner.x < 0.5 else sz.x - inset, inset if corner.y < 0.5 else sz.y - inset)
		c.draw_polyline(PackedVector2Array([o + Vector2(0, sy * arm), o + Vector2(0, sy * cut), o + Vector2(sx * cut, 0), o + Vector2(sx * arm, 0)]), white, lw, true)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var soft := Color(1, 1, 1, 0.94)
	var margin: float = 0.34 * u
	var w: float = sz.x - margin * 2.0
	var px: int = int(0.30 * u)
	for line in ["TURN THE TANK", "THROUGH W"]:
		while px > 8 and fb.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w:
			px -= 2
	var y: float = sz.y * 0.40
	c.draw_string(fb, Vector2(margin, y), "TURN THE TANK", HORIZONTAL_ALIGNMENT_CENTER, w, px, white)
	c.draw_string(fb, Vector2(margin, y + px * 1.02), "THROUGH W", HORIZONTAL_ALIGNMENT_CENTER, w, px, white)
	var rule_y: float = y + px * 1.02 + 0.17 * u
	c.draw_line(Vector2(sz.x * 0.5 - 0.45 * u, rule_y), Vector2(sz.x * 0.5 + 0.45 * u, rule_y), soft, maxf(2.0, 0.018 * u), true)
	c.draw_string(fs, Vector2(margin, rule_y + 0.17 * u), "RIGHT MOUSE   ·   WHEEL   ·   V THE SHARK", HORIZONTAL_ALIGNMENT_CENTER, w, int(0.085 * u), soft)


func _feeder_rows() -> Array:
	return [["Koi", str(tank.get("koi_count")) if tank != null else "16"], ["A pinch", "16 pellets"], ["Fed", "%d times" % _fed]]


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
		# Round 4 (Ramon: "clearly say Dark Mode On or Dark Mode Off, depending on its current state").
		hud.set("switch_text", "DARK MODE %s  ·  B" % ("ON" if Style.palette == "black" else "OFF"))
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
	if Engine.get_process_frames() % 30 == 0:
		_paint_square()
		_darken_airlock()
	player.set("w_walk_enabled", not (_at_feed or _near_panel))
	_turning(p)
	_following(delta)
	_shark_prompt(p)
	_hum_level(p, delta)
	_feeding(p, delta)
	_find_active(p)
	if _door != null:
		_door.call("notice", p)
		if bool(_door.call("inside", p)):
			_leaving = 0.0
			player.set("input_enabled", false)
	hud.set("strip", _strip())
	hud.set("strip_at", 0.40 if _at_feed else -1.0)
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


## On the square the tank's gizmo and the mouse's tutorial show, and the mouse moves what is IN the tank
## through W (not your slice: the room stays as it is; Ramon, 9 Oct). A right drag forward and back
## slides it, sideways turns it (x-W), the wheel turns it the other way (z-W); V follows the shark.
func _turning(p: Vector4) -> void:
	var on: bool = absf(p.x - turn_spot.x) < turn_radius + 0.1 and absf(p.z - turn_spot.y) < turn_radius + 0.1
	_on_turn = on
	if dial != null:
		dial.set("shown", on)
		dial.set("following", _follow_shark > 0.0)
	if tutorial != null:
		tutorial.set("shown", on)
	if not on:
		_follow_shark = 0.0


## How much of the shark your slice shows now, 0 to 1 (its W thickness against how far off the slice
## its middle is, after the contents' turn and slide).
func shark_visible() -> float:
	if tank == null:
		return 0.0
	var shark: Node = tank.get("shark")
	if shark == null:
		return 0.0
	var q: Vector4 = (tank.call("contents_basis") as Projection) * (shark.get("p") as Vector4)
	var w: float = q.w + float(tank.get("contents_slide"))
	var r: float = 0.05 * float(shark.get("length"))
	return sqrt(maxf(1.0 - (w * w) / (r * r), 0.0))


## Round 4 (Ramon: "When the shark reaches approximately 70% visibility within the current slice, show
## an on-screen prompt: V, Align with Shark ... only when the shark is sufficiently visible and
## alignment is relevant"): over the shark itself, while you are in front of the tank, it is at least
## 70% in your slice and not yet whole; V slides the contents until it is.
var _shark_prompt_on: bool = false


func _shark_prompt(p: Vector4) -> void:
	if prompt == null or tank == null or _at_feed:
		_shark_prompt_on = false
		return
	var front: bool = p.z < tank.global_position.z + 9.0 and absf(p.x - tank.global_position.x) < 12.0
	var v: float = shark_visible()
	var on: bool = front and v >= 0.7 and v < 0.985 and _follow_shark <= 0.0
	_shark_prompt_on = on
	prompt.set("shown", on)
	if on:
		var shark: Node4D = tank.get("shark")
		var body: Node4D = shark.get_node_or_null("Body") as Node4D
		prompt.set("target", body if body != null else shark)
		prompt.set("offset", Vector4(0.0, 0.7, 0.0, 0.0))
		prompt.set("key", "V")
		prompt.set("text", "Align with the shark")


## V: the contents slid until the shark is in your slice, and kept there a while as it swims.
func _following(delta: float) -> void:
	if _follow_shark <= 0.0 or tank == null:
		return
	_follow_shark -= delta
	var shark: Node = tank.get("shark")
	if shark == null:
		_follow_shark = 0.0
		return
	var basis: Projection = tank.call("contents_basis")
	var q: Vector4 = basis * (shark.get("p") as Vector4)
	var want: float = -q.w
	var slide: float = float(tank.get("contents_slide"))
	tank.call("set_contents", float(tank.get("contents_turn")), lerpf(slide, want, 1.0 - exp(-delta * 3.0)))


func _feeding(p: Vector4, delta: float) -> void:
	_feed_cooldown = maxf(_feed_cooldown - delta, 0.0)
	var at: bool = Vector2(p.x - feed_at.x, p.z - feed_at.y).length() < feed_reach
	_at_feed = at
	# The panel says E while you are at it (it was a prompt bubble over the old lectern).
	var feeder: Node = get_node_or_null("Feeder")
	if feeder != null:
		feeder.call("set_near", at)
		feeder.set("hint", "E   FEED THE KOI" if _feed_cooldown <= 0.0 else "THEY ARE EATING")


func feed() -> void:
	if _feed_cooldown > 0.0 or tank == null:
		return
	var koi: Node = tank.get("koi")
	if koi == null or not koi.has_method("drop_food"):
		return
	_feed_cooldown = 6.0
	_fed += 1
	var feeder: Node = get_node_or_null("Feeder")
	if feeder != null:
		feeder.set("rows", _feeder_rows())
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
		return [["E", "Feed the koi"]]
	if _on_turn:
		return [["Right drag", "Slide and turn through W"], ["Wheel", "Turn front to back"], ["V", "Align with the shark"], ["R", "Back"]]
	if active != null:
		var out: Array = [["Left / Right", "Choose"], ["Wheel", "Slide it through W"], ["Right drag", "Turn it through W"], ["Left drag", "Turn it"], ["R", "Whole again"]]
		if _near_panel:
			out.push_front(["E", "Its panel: more"])
		return out
	return [["WASD", "Move"], ["Mouse", "Look"], ["B", "Dark mode"]]


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
			tank.call("turn2_contents", deg_to_rad(3.0) * (1.0 if tb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0))
			_follow_shark = 0.0
			get_viewport().set_input_as_handled()
			return
		var tm := event as InputEventMouseMotion
		if tm != null and (tm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			# Sideways turns (x-W); forward (the mouse pushed away, up the screen) slides into W.
			tank.call("turn_contents", tm.relative.x * 0.004)
			tank.call("slide_contents", -tm.relative.y * 0.008)
			_follow_shark = 0.0
			get_viewport().set_input_as_handled()
			return
	if active == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			active.call("step_slice", 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			get_viewport().set_input_as_handled()
			return
	# RIGHT DRAG TURNS IT THROUGH W, LEFT DRAG TURNS IT IN THE SLICE. Right used to be the
	# only one, and it called `turn_by`, which is yaw and pitch - so the case answered a right
	# drag with a 3D turn while the aquarium beside it answered the same drag by turning its
	# contents through W. Left did nothing at all.
	var mm := event as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		if active.has_method("turn_w_by"):
			active.call("turn_w_by", mm.relative.x * 0.006, mm.relative.y * 0.006)
		get_viewport().set_input_as_handled()
	elif mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
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
				tank.call("reset_contents")
				_follow_shark = 0.0
		KEY_LEFT, KEY_RIGHT:
			if active != null and active.has_method("select_step"):
				active.call("select_step", -1 if k.keycode == KEY_LEFT else 1)
				get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3, KEY_4:
			if active != null and active.has_method("select"):
				active.call("select", k.keycode - KEY_1)
				get_viewport().set_input_as_handled()
		KEY_V:
			if _on_turn or _shark_prompt_on:
				_follow_shark = 8.0
				hud.call("toast", "Aligned with the shark")
				get_viewport().set_input_as_handled()
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
	# The walker's facing is atan2(forward.x, forward.z); the rig's yaw 0 looks along -z. Handing it
	# the yaw itself faced you back at the wall you came in by (round 3: "the character is still
	# rotated to face the wall"). The walker's own _ready makes the same conversion.
	player.set("_facing", atan2(-sin(yaw), -cos(yaw)))
	var avatar: Node4D = player.get_node_or_null("Avatar") as Node4D
	if avatar != null:
		avatar.basis = player.get("_stance")
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
