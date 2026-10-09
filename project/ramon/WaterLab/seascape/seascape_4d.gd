extends Node4D

## RAMON'S WATER (8 Oct 2026): his version of Trym's 4D water test (sandbox/water4d/water4d_test.tscn,
## from Trym's water-annex branch; everything of Trym's this needs is carried into WaterLab/carried/).
## Plan and handover: follow_up/water_ramon.md (the sea), follow_up/water_lab.md (the Water Lab it is now part of).
##
## Trym's sea: a 4D height field whose waves run in x, z and W, drawn on a 3D grid in the renderer's
## own world and solved for your slice (WaterLab/carried/water4d/README.md).
##
## ROUND 2 (Ramon's walkthrough, 9 Oct; follow_up/water_lab.md, "Round 2"):
##   THE TUNNEL  you come in through a plain sliding door in a short white room with no front (the
##               kit's room, the lab's dev texture), its two pages on its side walls ("4D Water" and
##               "how the sea is made"), a metre of white wall past them, a ceiling; out of it onto
##               the pier. The door behind you leads back to the tank room.
##   THE PIER    straight on to the platform.
##   THE PLATFORM smaller, in code blue, TURN THE SLICE printed big in its middle (the page printed
##               into the deck itself) and a ring of slowly turning lines near its edge. A right drag
##               turns your slice: the sea is cut a new way and the platform stays SET (it hangs in
##               a frame that turns with the slice, about where the turn began, so it is drawn as if
##               nothing had turned). Its rail is kept in code (the physics is box-only), the way out
##               shut until the slice is level again.
##   PIER 2 IS GONE ("I want to keep the pier with the round circle and kill the other one").
##   Trym's pole stands by the platform, the walkway's grey with a darker cap; his plesiosaur swims
##   under the pier; the sardines school off it; the gulls sit on the rails, the ring, the pole and
##   the tunnel's roof; a fishing boat rides the waves offshore.
##
## KEYS: 1-4 the seas, G the Gerstner (off, 1, 2, 3), R levels the slice (the rig's), F the foam map,
## Tab the dev HUD (seascape_hud.gd). The overlay (seascape_overlay.gd) shows the keys and the numbers.
##
## NO class_name (engine_gotchas.md).

const Presets := preload("res://ramon/WaterLab/carried/water4d/water4d_presets.gd")
const KitPlayer := preload("res://ramon/WaterLab/carried/kit/kit_player.gd")
const WallPanel := preload("res://ramon/WaterLab/carried/kit/panels/kit_wall_panel_4d.gd")
const Spec := preload("res://ramon/WaterLab/carried/kit/panels/kit_panel_spec.gd")
const LabGrid := preload("res://ramon/WaterLab/carried/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/WaterLab/carried/LabKit/lab_materials.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")
const Hud := preload("res://ramon/WaterLab/seascape/seascape_hud.gd")
const GB := preload("res://ramon/WaterLab/carried/LabKit/carried/chickenpen/scripts/ground_basis_4d.gd")
const PenWalk := preload("res://ramon/WaterLab/shared/pen_walk.gd")
const LabPrint := preload("res://ramon/WaterLab/carried/LabKit/lab_print.gd")

@export_group("Sea")
@export var start_preset: int = 1
## Trym's seas are open-ocean sized; at 1.0 a storm's crests reach a few metres. Smaller keeps the
## sea under the decks.
@export var wave_scale: float = 0.8
@export var floor_depth: float = 35.0
@export var creature_length: float = 15.0
@export var creature_speed: float = 1.5

@export_group("Piers")
## The decks' top, above the still water line (y 0). "Floating right above the ocean." Raised from
## 2.2 m in round 2 ("the blue circle a little bit higher, or at least stop it from clipping").
@export var deck_height: float = 2.8
## Door to platform (Ramon, 8 Oct: shorter; it was 26 m and turned left halfway).
@export var pier1_length: float = 14.0
@export var pier1_width: float = 3.4
## Round 2: smaller (it was 7 m).
@export var platform_radius: float = 5.2
## How far through W the decks reach (Trym's walkway: 4.2).
@export var pier1_w_depth: float = 4.2
@export var railing_height: float = 1.0
## The door at the tunnel's back: the opening's height and width.
@export var door_height: float = 3.2
@export var door_width: float = 2.6

@export_group("Tunnel")
## The white room at the pier's back, its two pages on its side walls (Ramon, 9 Oct: "two panels on a
## wall next to you left and a wall next to you right ... Then one meter of white after that ... a
## ceiling"): inside width and height; the pages' size as a share of the kit's 9.6 x 5.9 m.
@export var tunnel_width: float = 6.4
@export var tunnel_height: float = 7.0
@export var tunnel_panel_scale: float = 0.85

@export_group("Pole")
## Beside the platform (round 2: "closer to the blue round circle"): x and z from the platform's
## middle, and W.
@export var pole_offset: Vector3 = Vector3(5.8, -11.2, 0.0)
@export var pole_size: float = 2.3
@export var pole_above_water: float = 3.6

@export_group("Panels")
## TURN THE SLICE on the platform, as a share of the kit's 9.6 x 5.9 m page.
@export var platform_panel_scale: float = 0.66

@export_group("Camera")
## How far back the camera sits. Locked: the wheel does not zoom here (Ramon, 8 Oct: "more zoomed
## out and locked"); the HUD's CAMERA slider sets it, and SAVE keeps it.
@export var camera_distance: float = 10.0
@export var camera_height: float = 2.4
@export var camera_pitch_degrees: float = -12.0

var player: CharacterBody4D
var hud: Control
## What everyone sees (seascape_overlay.gd); `hud` is the dev HUD behind Tab.
var overlay: Control
var _water: Node
var _rig: Node
var _set_frame: Node4D
var _door: Node4D
var _site: String = ""
var _last_site: String = ""
## The one time near an edge you are told to look down (round 2).
var _looked_down: bool = false
var _reached: Dictionary = {}
var _rebuild_in: float = -1.0
## The set platform while the slice is turned on it (_hold_set_frame).
var _turned_here: bool = false
var _pivot := Vector4.ZERO
var _visual := Vector4.ZERO
## The doors back to the tank room: armed once you have walked away from them; walking into one
## fades and loads the Water Lab's tank room (water_lab.tscn), which puts you at its far door.
const LAB_SCENE := "res://ramon/WaterLab/water_lab.tscn"
const ARRIVE_META := "water_lab_arrive"
var _doors_armed: bool = false
## Off for runners that walk you about (they would trip the doors).
var doors_enabled: bool = true
var _leaving: float = -1.0
var _fade: ColorRect

## The HUD's HARBOUR section (seascape_hud.gd): how many gulls, how many sardines, how often the
## plesiosaur comes by (seconds between its visits, on average). Each passes straight to its node.
var harbour_gulls: int = 12:
	set(v):
		harbour_gulls = clampi(v, 0, 30)
		var h: Node = get_node_or_null("Harbour")
		if h != null:
			h.set("count", harbour_gulls)
var harbour_fish: int = 3000:
	set(v):
		harbour_fish = clampi(v, 0, 8000)
		# A new size respawns the school: once the slider has stopped (coalesced, as a drag sends a
		# value every step).
		_fish_in = 0.3
var _fish_in: float = -1.0
var plesiosaur_visit_every: int = 55:
	set(v):
		plesiosaur_visit_every = clampi(v, 10, 300)
		var pilot: Node = get_node_or_null("SeaLife/Plesiosaur/Pilot")
		if pilot != null:
			pilot.set(&"visit_every", Vector2(plesiosaur_visit_every * 0.75, plesiosaur_visit_every * 1.25))
## The harbour's sound bed (audio/harbour_lap.wav), looped.
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var harbour_sound_db: float = -16.0


# -- where things are ---------------------------------------------------------------------------------------

func platform_centre() -> Vector4:
	return Vector4(pier1_length + platform_radius - 0.6, deck_height, 0.0, 0.0)


## The tunnel's length: its pages, and a metre of white before and after them.
func tunnel_length() -> float:
	return Spec.PANEL.x * Spec.UNIT_M * tunnel_panel_scale + 2.0


## Where you stand when you come in: just inside the door (i is kept for the runners; there is one).
func door(_i: int = 1) -> Vector4:
	return Vector4(0.8, deck_height + 0.05, 0.0, 0.0)


func pole_at() -> Vector3:
	var c: Vector4 = platform_centre()
	return Vector3(c.x + pole_offset.x, c.z + pole_offset.y, pole_offset.z)


# -- building -----------------------------------------------------------------------------------------------

func _ready() -> void:
	Style.apply("bright")
	_water = get_node_or_null("Water")
	if _water != null:
		# The sea out to the horizon (the far ring, carried water4d_surface.gd).
		_water.set(&"far_extent", 900.0)
	if _water != null and _water.has_method(&"set_preset"):
		_water.set(&"wave_scale", wave_scale)
		_water.call(&"set_preset", start_preset)
	_saved_pier_sizes()
	_build_piers()
	_build_pole()
	_build_floor()
	_build_player()
	_build_creature()
	_build_boat()
	_build_gulls()
	_build_hud()
	_place_targets()
	process_physics_priority = 100


## The routes' targets where the platform and the circle are now (they follow the settings above).
func _place_targets() -> void:
	var platform: Node4D = get_node_or_null("Paths/Targets/Platform") as Node4D
	if platform != null:
		platform.position = platform_centre()
		platform.set("size", Vector3(platform_radius * 2.0, 1.0, platform_radius * 2.0))
	# The route at the decks' height, its destination just short of the platform, its start inside the
	# door; no frame round the platform (round 2: "I don't know what this line is around the blue
	# panel ... you can remove that"), the guide line in the marks' own blue.
	var net: Node4D = get_node_or_null("Paths/Pier1") as Node4D
	var graph: Resource = net.get("graph") if net != null else null
	if graph == null:
		return
	net.position.y = deck_height
	net.set("guide_color", Color("#1761d7"))
	net.set("floor_swatch", "kit_floor")
	for n in graph.get("nodes"):
		match String((n as Dictionary).get("kind", "")):
			"destination":
				n["pos"] = Vector4(pier1_length - 1.2, 0.0, 0.0, 0.0)
				n["frame"] = "none"
			"start":
				n["pos"] = Vector4(1.4, 0.0, 0.0, 0.0)
	graph.emit_changed()


## The pier sizes and the camera saved from the HUD (seascape_tuning.cfg, PIERS and CAMERA),
## read before anything is built, so the scene opens at them rather than building once and
## rebuilding at once.
func _saved_pier_sizes() -> void:
	var cf := ConfigFile.new()
	if cf.load(Hud.SAVE_PATH) != OK:
		return
	for sec in ["PIERS", "CAMERA"]:
		if not cf.has_section(sec):
			continue
		for key in cf.get_section_keys(sec):
			if get(key) != null:
				set(key, cf.get_value(sec, key))


## The camera at `camera_distance` and `camera_height`, its zoom locked there: the wheel's step is 0.
## NOT BY NARROWING ITS RANGE: the rig never pulls the camera in closer than half its minimum
## distance when something is in the way, so a minimum of 10 m left it behind the sci-fi door at the
## start, looking at the door's back.
func apply_camera() -> void:
	if _rig == null:
		return
	_rig.set("zoom_speed", 0.0)
	_rig.set("max_distance", maxf(float(_rig.get("max_distance")), camera_distance))
	_rig.set("distance", camera_distance)
	_rig.set("_zoom_target", camera_distance)
	_rig.set("_rest_distance", camera_distance)
	_rig.set("pivot_height", camera_height)
	_rig.set("_home_pivot", camera_height)
	_rig.call("_apply")


## The tunnel and its door, the pier and the platform. Called again by rebuild_piers() when the HUD's
## PIERS sliders change the pier's length or width.
func _build_piers() -> void:
	_build_tunnel()
	_build_pier1()
	_build_platform()


## The piers again at their new size: the old ones freed in the same frame, so nothing you stand on
## is missing for a physics step; the routes' ends follow. Coalesced, as a slider sends a value
## every step of a drag.
func rebuild_piers_later() -> void:
	_rebuild_in = 0.25


func rebuild_piers() -> void:
	for nm in ["Tunnel", "Door1", "Pier1", "PlatformSet", "PlatformBody", "Pages"]:
		var n: Node = get_node_or_null(nm)
		if n != null:
			remove_child(n)
			n.queue_free()
	_set_frame = null
	_door = null
	_build_piers()
	_place_targets()
	_gull_perches()


## THE TUNNEL (Ramon, 9 Oct: "when you just leave the door to go on the pier, we have these two panels
## on a wall next to you left and a wall next to you right ... Then one meter of white after that
## ... a ceiling. So it's kind of like you walk through this little tunnel of thin walls with these
## panels"; and the door: "just a white enclosure with the dev texture, and then again the same door
## that you entered from"): the kit's room, open toward the sea, its back wall a doorway with the
## plain sliding door in it (shared/scifi_door_4d.gd "plain", the tank room's), the two pages on
## its side walls (kit wall panels, as on the tank room's walls). Its floor is the walk's first
## metres; the pier's deck starts where it ends.
func _build_tunnel() -> void:
	var L: float = tunnel_length()
	var room := Node4D.new()
	room.name = "Tunnel"
	room.set_script(load("res://ramon/WaterLab/carried/kit/kit_room_4d.gd"))
	room.set("size", Vector3(L, tunnel_height, tunnel_width))
	room.set("open_sides", ["e"])
	room.set("flush_open", true)
	room.set("doorways", [["w", -door_width * 0.5, door_width * 0.5, door_height]])
	room.set("cove", false)
	room.position = Vector4(L * 0.5, deck_height, 0.0, 0.0)
	add_child(room)
	_door = Node4D.new()
	_door.name = "Door1"
	_door.set_script(load("res://ramon/WaterLab/shared/scifi_door_4d.gd"))
	_door.set("style", "plain")
	_door.set("width", door_width)
	_door.set("height", door_height)
	_door.set("w_depth", 40.0)
	_door.set("light_behind", false)
	_door.set("auto_open", true)
	_door.set("open_distance", 3.0)
	_door.position = Vector4(0.0, deck_height, 0.0, 0.0)
	_door.basis = _facing(Vector2(1.0, 0.0))
	add_child(_door)
	if get_node_or_null("PanelSource") == null:
		var source := Node.new()
		source.name = "PanelSource"
		source.set_script(load("res://ramon/WaterLab/seascape/seascape_panel_source.gd"))
		add_child(source)
	var info: Resource = load("res://ramon/WaterLab/seascape/seascape_info.tres")
	for pair in [["intro", "n"], ["research", "s"]]:
		var panel := Node4D.new()
		panel.name = "%sPanel" % String(pair[0]).capitalize()
		panel.set_script(WallPanel)
		panel.set("kind", pair[0])
		panel.set("info", info)
		panel.set("scale_factor", tunnel_panel_scale)
		panel.set("wall_side", pair[1])
		room.add_child(panel)
		panel.set("room_path", panel.get_path_to(room))
		panel.set("source", panel.get_path_to(get_node("PanelSource")))


## A deck on the kit's floor grid, with its collision.
func _deck(parent: Node, nm: String, centre: Vector4, size: Vector4) -> void:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(size)
	m.position = centre
	m.material_override = LabGrid.material("kit_floor", size, centre)
	parent.add_child(m)
	_solid(parent, nm + "Body", centre, size)


func _solid(parent: Node, nm: String, centre: Vector4, size: Vector4) -> void:
	var body := StaticBody4D.new()
	body.name = nm
	body.position = centre
	var shape := CollisionShape4D.new()
	var b := BoxShape4D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	parent.add_child(body)


static func _material(colour: Color) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_color = colour
	return m


func _box(parent: Node, nm: String, centre: Vector4, size: Vector4, colour: Color) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(size)
	m.position = centre
	m.material_override = _material(colour)
	parent.add_child(m)
	return m


## Pier 1: straight out from door 1 onto the platform (Ramon, 8 Oct: "remove the corner on the
## first pier and just make me go forward"; it first turned left halfway).
func _build_pier1() -> void:
	var holder := Node4D.new()
	holder.name = "Pier1"
	add_child(holder)
	var y: float = deck_height - 0.15
	var hw: float = pier1_width * 0.5
	var wd: float = pier1_w_depth
	# From the tunnel's mouth (its floor is the walk's first metres) to the platform.
	var x0: float = tunnel_length()
	var run: float = maxf(pier1_length - x0, 1.0)
	var mid: float = x0 + run * 0.5
	_deck(holder, "Run", Vector4(mid, y, 0.0, 0.0), Vector4(run, 0.3, pier1_width, wd))
	# Trym's fence along it, open at the tunnel and where it meets the platform.
	_fence(holder, "RunRail", Vector3(run, pier1_width, wd), Vector4(mid, deck_height, 0.0, 0.0), ["-x", "+x"])
	# What stops you, on each side that is closed (the fence is mesh only).
	var h: float = railing_height
	var ry: float = deck_height + h * 0.5
	_solid(holder, "RunSideA", Vector4(mid, ry, hw, 0.0), Vector4(run, h, 0.16, wd))
	_solid(holder, "RunSideB", Vector4(mid, ry, -hw, 0.0), Vector4(run, h, 0.16, wd))
	for s in [-1.0, 1.0]:
		_solid(holder, "RunCapW%d" % int(s), Vector4(mid, ry, 0.0, s * wd * 0.5), Vector4(run, h, pier1_width, 0.16))


## The platform at the pier's end, in code blue. Its collision is a square slab deep in W, square to the
## world; its deck and rail hang in `_set_frame`, which turns with the slice so they read as set.
##
## ROUND 2 (Ramon, 9 Oct): smaller; TURN THE SLICE (the page that stood on pier 2) printed into the
## deck's own surface, big, in its middle, the only thing on it ("I want it to be the only thing ...
## scaled up"); the cyan tiles round the edge gone; instead a ring of lines turning slowly near the
## edge, a lighter blue than the deck (the lab floor's ring, lab_grid.gdshader); a few centimetres
## proud of the pier so the two never fight.
func _build_platform() -> void:
	var c: Vector4 = platform_centre()
	# Deep in W: walking while the slice is turned carries you through W (_hold_set_frame).
	_solid(self, "PlatformBody", Vector4(c.x, c.y - 0.15 + 0.04, c.z, 0.0), Vector4(platform_radius * 2.0, 0.3, platform_radius * 2.0, 80.0))
	_set_frame = Node4D.new()
	_set_frame.name = "PlatformSet"
	_set_frame.position = c
	add_child(_set_frame)
	# The deck: a cubinder, round in x and z, square in y and W, in the kit's code blue; turned so the
	# floor print's top (its -z) points out to sea (+x), away from you walking on from the pier.
	var shape := CubinderShape4D.new()
	shape.radius = platform_radius
	shape.height = 0.3
	shape.thickness = pier1_w_depth
	var disc := MeshInstance4D.new()
	disc.name = "Deck"
	disc.mesh = shape.to_tetra_mesh()
	disc.position = Vector4(0.0, -0.15 + 0.04, 0.0, 0.0)
	disc.basis = _facing(Vector2(-1.0, 0.0))
	var size := Vector4(platform_radius * 2.0, 0.3, platform_radius * 2.0, pier1_w_depth)
	var m: TetraMaterial4D = LabGrid.material(Style.code_swatch("blue"), size, c)
	disc.material_override = m
	_set_frame.add_child(disc)
	LabGrid.set_ring(m, Vector2(c.x, c.z), platform_radius - 0.95, 1.0, Color(0.52, 0.74, 1.0), 0.05)
	# The rail: Trym's fence round a 32-sided ring, open where the pier comes in (-x).
	var r: float = platform_radius - 0.15
	var gap: float = asin(clampf((pier1_width * 0.5 + 0.3) / r, 0.0, 1.0))
	_fence_from(_set_frame, "Rail", _ring_seed(r, 32, pier1_w_depth, gap, PI), Vector4(0.0, 0.04, 0.0, 0.0), pier1_w_depth)
	# Waves breaking on it: spray and wet patches where a crest reaches the deck (round 4).
	var spray := Node4D.new()
	spray.name = "Spray"
	spray.set_script(load("res://ramon/WaterLab/seascape/wave_spray_4d.gd"))
	spray.set("water", _water)
	spray.set("deck", m)
	spray.set("centre", Vector4(c.x, 0.0, c.z, 0.0))
	spray.set("radius", platform_radius)
	spray.set("deck_y", deck_height)
	add_child(spray)
	# TURN THE SLICE: a square page, centred, printed into the deck (round 4, Ramon: "Center the Turn the
	# Slice presentation. Remove the top-right information ... Change the presentation area ... to a
	# square ... Center this square within the overall station").
	_print_square_later(disc)


## The square page: drawn once (LabPrint, as the lab's walls carry their words), printed into the
## deck's top in its middle, inside the line ring.
func _print_square_later(disc: MeshInstance4D) -> void:
	var side: float = (platform_radius - 1.4) * sqrt(2.0)
	var tex: Texture2D = await LabPrint.render(get_tree(), Vector2i(1400, 1400), _square_page)
	if tex == null or not is_instance_valid(disc):
		return
	var m: TetraMaterial4D = disc.material_override as TetraMaterial4D
	var r: float = platform_radius
	LabGrid.set_print(m, tex, Vector4(0, 1, 0, 0), Rect2(Vector2(r - side * 0.5, r - side * 0.5), Vector2(side, side)), Color.WHITE, 0.15)
	LabGrid.set_print_strength(m, 1.0)
	m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)


## The page: the title, a line, three controls, in white on clear (the deck's blue shows).
func _square_page(c: Control) -> void:
	var sz: Vector2 = c.size
	var u: float = sz.x / 1000.0
	var white := Color(1, 1, 1, 1)
	var soft := Color(1, 1, 1, 0.82)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	# A thin frame, inset, with the path frames' cut corners.
	var k: float = 34.0 * u
	var m: float = 20.0 * u
	var pts := PackedVector2Array([Vector2(m + k, m), Vector2(sz.x - m - k, m), Vector2(sz.x - m, m + k), Vector2(sz.x - m, sz.y - m - k),
		Vector2(sz.x - m - k, sz.y - m), Vector2(m + k, sz.y - m), Vector2(m, sz.y - m - k), Vector2(m, m + k), Vector2(m + k, m)])
	c.draw_polyline(pts, Color(1, 1, 1, 0.55), maxf(2.0, 4.0 * u), true)
	# Every line fitted inside the frame (frames of 9 Oct: the title had run off the square's edge).
	var inner: float = sz.x - 2.0 * (m + 70.0 * u)
	c.draw_string(fs, Vector2(0, 250.0 * u), "THE PLATFORM", HORIZONTAL_ALIGNMENT_CENTER, sz.x, _fit(fs, "THE PLATFORM", 34.0 * u, inner), soft)
	c.draw_string(fb, Vector2(0, 390.0 * u), "TURN THE SLICE", HORIZONTAL_ALIGNMENT_CENTER, sz.x, _fit(fb, "TURN THE SLICE", 118.0 * u, inner), white)
	c.draw_string(fl, Vector2(0, 470.0 * u), "Stand here and right-drag.", HORIZONTAL_ALIGNMENT_CENTER, sz.x, _fit(fl, "Stand here and right-drag.", 40.0 * u, inner), soft)
	c.draw_string(fl, Vector2(0, 520.0 * u), "The sea is cut a new way.", HORIZONTAL_ALIGNMENT_CENTER, sz.x, _fit(fl, "Stand here and right-drag.", 40.0 * u, inner), soft)
	c.draw_line(Vector2(sz.x * 0.5 - 140.0 * u, 580.0 * u), Vector2(sz.x * 0.5 + 140.0 * u, 580.0 * u), Color(1, 1, 1, 0.5), maxf(2.0, 3.0 * u), true)
	# The three controls, each a cap and its words.
	var items: Array = [["RIGHT DRAG", "Turn the slice"], ["R", "Level it again"], ["1 - 4", "Change the sea"]]
	for i in items.size():
		var cx: float = sz.x * (0.23 + 0.27 * float(i))
		var cap := Rect2(Vector2(cx - 110.0 * u, 640.0 * u), Vector2(220.0 * u, 96.0 * u))
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = white
		sb.set_border_width_all(int(maxf(2.0, 5.0 * u)))
		sb.set_corner_radius_all(int(18.0 * u))
		c.draw_style_box(sb, cap)
		var key_size: int = _fit(fs, String(items[i][0]), 36.0 * u, cap.size.x - 36.0 * u)
		c.draw_string(fs, Vector2(cap.position.x, cap.get_center().y + key_size * 0.36), String(items[i][0]), HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, key_size, white)
		c.draw_string(fl, Vector2(cx - 130.0 * u, 800.0 * u), String(items[i][1]), HORIZONTAL_ALIGNMENT_CENTER, 260.0 * u, _fit(fl, "Change the sea", 32.0 * u, 250.0 * u), soft)


## The font size, at most `size`, at which `text` is no wider than `width`.
func _fit(font: Font, text: String, size: float, width: float) -> int:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	return int(size if w <= width else floorf(size * width / w))


## The page's live picture printed into the deck's top, in its middle; the page's own slab hidden.
func _print_deck_later(disc: MeshInstance4D, page: Node4D, pm: Vector2) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(page) or not is_instance_valid(disc):
		return
	var vp: SubViewport = page.get("_vp")
	var slab: Node4D = page.get("_slab")
	if slab != null:
		slab.visible = false
	if vp == null:
		return
	var m: TetraMaterial4D = disc.material_override as TetraMaterial4D
	var r: float = platform_radius
	LabGrid.set_print(m, vp.get_texture(), Vector4(0, 1, 0, 0), Rect2(Vector2(r - pm.x * 0.5, r - pm.y * 0.5), pm), Color.WHITE, 0.15)
	LabGrid.set_print_strength(m, 1.0)
	m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)


## A kit panel drawing its page out of sight (it is printed elsewhere; its own slab is hidden).
func _page(kind: String, info: Resource, scale: float, at: Vector4) -> Node4D:
	var holder: Node = get_node_or_null("Pages")
	if holder == null:
		holder = Node4D.new()
		holder.name = "Pages"
		add_child(holder)
	var p := Node4D.new()
	p.name = "%sPage%d" % [kind.capitalize(), holder.get_child_count()]
	p.set_script(WallPanel)
	p.set("kind", kind)
	p.set("info", info)
	p.set("scale_factor", scale)
	p.position = at
	holder.add_child(p)
	var source: Node = get_node_or_null("PanelSource")
	if source != null:
		p.set("source", p.get_path_to(source))
	return p


## Trym's banded pillar: the sea floor to above the water, so the depth fade has a ruler.
## Round 2 (Ramon, 9 Oct): beside the platform, in the walkway's grey (the deck's own grid), a cap of a
## darker grey on its top.
func _build_pole() -> void:
	var holder := Node4D.new()
	holder.name = "Pole"
	add_child(holder)
	var height: float = floor_depth + pole_above_water
	var pa: Vector3 = pole_at()
	var x: float = pa.x
	var z: float = pa.y
	var w: float = pa.z
	var shaft_size := Vector4(pole_size, height, pole_size, pole_size * 2.4)
	var shaft_at := Vector4(x, -floor_depth + height * 0.5, z, w)
	var shaft := MeshInstance4D.new()
	shaft.name = "Shaft"
	shaft.mesh = Mats.box_mesh(shaft_size)
	shaft.position = shaft_at
	shaft.material_override = LabGrid.material("kit_floor", shaft_size, shaft_at)
	holder.add_child(shaft)
	_box(holder, "Cap", Vector4(x, pole_above_water + 0.09, z, w), Vector4(pole_size + 0.16, 0.18, pole_size + 0.16, pole_size * 2.4 + 0.16), Color(0.34, 0.36, 0.40))
	for i in range(1, 7):
		var y: float = -floor_depth + float(i) * (height / 7.0)
		_box(holder, "Band%d" % i, Vector4(x, y, z, w), Vector4(pole_size * 1.12, 0.22, pole_size * 1.12, pole_size * 2.4), Color(0.86, 0.33, 0.22))


## The sea floor, with Trym's stripes for the absorption to work against.
func _build_floor() -> void:
	var holder := Node4D.new()
	holder.name = "SeaFloor"
	add_child(holder)
	var size := Vector4(124.0, 1.0, 124.0, 124.0)
	var centre := Vector4(14.0, -floor_depth - 0.5, 4.0, 0.0)
	_box(holder, "Floor", centre, size, Color(0.30, 0.31, 0.29))
	for i in range(-5, 6):
		_box(holder, "Stripe%d" % (i + 5), Vector4(centre.x + float(i) * 12.0, -floor_depth + 0.03, centre.z, 0.0), Vector4(0.6, 0.08, 122.0, 124.0), Color(0.46, 0.47, 0.44))


func _build_player() -> void:
	player = KitPlayer.make()
	player.name = "Player"
	# The playable world's walk, Q/E stepping through W included (round 4).
	PenWalk.apply(player)
	add_child(player)
	_rig = player.get_node_or_null("CameraRig")
	if _rig != null:
		_rig.set("slice_turning", false)
		_rig.set("pitch", deg_to_rad(camera_pitch_degrees))
		apply_camera()
	go_to(Vector4(5.0, deck_height + 0.05, 0.0, 0.0), -PI * 0.5)


## Trym's plesiosaur, wandering under pier 1 (the pool room's _build_creature, with this sea's bounds).
func _build_creature() -> void:
	var scene: PackedScene = load("res://ramon/WaterLab/carried/water4d/plesiosaur.tscn") as PackedScene
	if scene == null:
		return
	var sea := Node4D.new()
	sea.name = "SeaLife"
	sea.position = Vector4(16.0, 0.0, -8.0, 0.0)
	add_child(sea)
	var creature: Node4D = scene.instantiate() as Node4D
	creature.name = "Plesiosaur"
	sea.add_child(creature)
	var rig: Node4D = creature.get_node_or_null(^"Hide") as Node4D
	var swimmer: Node = creature.get_node_or_null(^"Swimmer")
	if rig != null and swimmer != null and swimmer.has_method(&"rest_length"):
		var built: float = swimmer.call(&"rest_length")
		if built > 0.1:
			rig.set_uniform_scale(creature_length / built)
	var pilot := Node4D.new()
	pilot.name = "Pilot"
	pilot.set_script(load("res://ramon/WaterLab/carried/water4d/plesiosaur_pilot.gd"))
	pilot.set(&"body_path", NodePath(".."))
	pilot.set(&"swimmer_path", NodePath("../Swimmer"))
	pilot.set(&"player_path", NodePath("../../../Player"))
	pilot.set(&"bounds", Vector3(36.0, 36.0, 6.0))
	# Nearer the surface (Ramon, 9 Oct: "a bit higher toward the surface so you can see it"), and it comes
	# past you every minute or so (the pilot's visits).
	pilot.set(&"depth_range", Vector2(2.5, 9.0))
	pilot.set(&"speed", creature_speed)
	creature.add_child(pilot)
	# THE SEAMS STAY AS BUILT. Trym's swimmer re-bends the patches between its 13 pieces every
	# physics tick, rewriting their vertices: measured here at about 6 ms a tick (the slow frames,
	# 95th percentile 8 ms against 1.8 ms with this off). Deep under the water the seams do not
	# show; the pieces still swim.
	if swimmer != null:
		swimmer.set(&"blend_joints", false)
	# Round 4 (Ramon: "another Loch Ness-type creature lower in the water ... subtle ... rewards
	# observation"): a second, smaller one, deep (14 to 26 m, a blue-green shadow through the water),
	# slow, never coming to visit. Its own copy of the hide's material.
	var deep: Node4D = scene.instantiate() as Node4D
	deep.name = "DeepPlesiosaur"
	var deep_rig: Node4D = deep.get_node_or_null(^"Hide") as Node4D
	if deep_rig != null and deep_rig.get("material_override") != null:
		deep_rig.set("material_override", (deep_rig.get("material_override") as Resource).duplicate())
	sea.add_child(deep)
	var deep_swim: Node = deep.get_node_or_null(^"Swimmer")
	if deep_rig != null and deep_swim != null and deep_swim.has_method(&"rest_length"):
		var built2: float = deep_swim.call(&"rest_length")
		if built2 > 0.1:
			deep_rig.set_uniform_scale(creature_length * 0.75 / built2)
	if deep_swim != null:
		deep_swim.set(&"blend_joints", false)
	var deep_pilot := Node4D.new()
	deep_pilot.name = "Pilot"
	deep_pilot.set_script(load("res://ramon/WaterLab/carried/water4d/plesiosaur_pilot.gd"))
	deep_pilot.set(&"body_path", NodePath(".."))
	deep_pilot.set(&"swimmer_path", NodePath("../Swimmer"))
	deep_pilot.set(&"player_path", NodePath(""))
	deep_pilot.set(&"bounds", Vector3(40.0, 40.0, 6.0))
	deep_pilot.set(&"depth_range", Vector2(14.0, 26.0))
	deep_pilot.set(&"speed", creature_speed * 0.6)
	deep_pilot.set(&"visit_every", Vector2(0.0, 0.0))
	deep.add_child(deep_pilot)
	# Three hammerheads cruising together, and eels round the pole (round 4).
	var life := Node4D.new()
	life.name = "MoreLife"
	life.set_script(load("res://ramon/WaterLab/seascape/sea_life_4d.gd"))
	var pa: Vector3 = pole_at()
	life.set("pole", Vector2(pa.x, pa.y))
	var pc: Vector4 = platform_centre()
	life.set("loop_centre", Vector2(pc.x, pc.z))
	add_child(life)
	# The sardines' school, off pier 1, under the water; the plesiosaur its hunter.
	var school := Node4D.new()
	school.name = "School"
	school.set_script(load("res://ramon/WaterLab/seascape/fish_school_4d.gd"))
	school.position = Vector4(12.0, 0.0, -6.5, 0.0)
	school.set("hunter", creature)
	add_child(school)


## The harbour's gulls, round both piers, the wind off the sea (+x); they hear through the camera.
## The boats (seascape/boat_fleet_4d.gd): two white ones at anchor offshore, with their copies spread
## through W; orange ones far out in other slices.
func _build_boat() -> void:
	var fleet := Node4D.new()
	fleet.name = "Boat"
	fleet.set_script(load("res://ramon/WaterLab/seascape/boat_fleet_4d.gd"))
	var c: Vector4 = platform_centre()
	fleet.set("principals", [[c.x + 24.0, 9.0, PI * 0.5], [c.x + 15.0, -26.0, 0.35]])
	fleet.set("clear_x", c.x + platform_radius + 4.0)
	fleet.set("centre", Vector4(c.x, 0.0, c.z, 0.0))
	fleet.set("water", _water)
	var cams: Array = player.find_children("*", "Camera4D", true, false) if player != null else []
	fleet.set("viewer", cams[0] if not cams.is_empty() else null)
	add_child(fleet)


func _build_gulls() -> void:
	var harbour := Node4D.new()
	harbour.name = "Harbour"
	harbour.set_script(load("res://ramon/WaterLab/gull/gull_flock_4d.gd"))
	# None until the perches are in, so the ones that start sitting find a place.
	harbour.set("count", 0)
	harbour.set("home", Vector4(14.0, 9.0, 2.0, 0.0))
	harbour.set("roam_radius", 28.0)
	harbour.set("altitude", Vector2(5.0, 15.0))
	harbour.set("wind", Vector4(1.0, 0.0, 0.25, 0.0))
	add_child(harbour)
	harbour.set("walker", player)
	harbour.set("school", get_node_or_null("School"))
	_gull_perches()
	harbour.set("count", harbour_gulls)
	_build_sound()
	if player != null:
		var cams: Array = player.find_children("*", "Camera4D", true, false)
		if not cams.is_empty():
			harbour.set("listener_4d", cams[0])


## The harbour's bed: small waves on the piles and the open sea's wash, looped (the import's loop
## settings do nothing in this build: pen_sfx_4d.gd), under the gulls' calls.
func _build_sound() -> void:
	var path := "res://ramon/WaterLab/audio/harbour_lap.wav"
	if not ResourceLoader.exists(path):
		return
	var s: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * float(s.mix_rate))
	var p := AudioStreamPlayer.new()
	p.name = "HarbourSound"
	p.stream = s
	p.volume_db = harbour_sound_db
	add_child(p)
	p.play(randf() * s.get_length())


## Where the gulls may sit, from the pier as built now: the rails' top beam (Trym's fence: its top beam
## sits at 0.97 of the posts, 2.5 cm thick; round 2: "make sure they really stand on the rails"), the
## platform's ring, the pole's cap, the tunnel's roof edges.
func _gull_perches() -> void:
	var harbour: Node = get_node_or_null("Harbour")
	if harbour == null:
		return
	harbour.call("clear_perches")
	var top: float = deck_height + railing_height * 0.97 + 0.0125
	var x0: float = tunnel_length() + 0.6
	for s in [-1.0, 1.0]:
		harbour.call("add_rail", Vector4(x0, top, s * pier1_width * 0.5, 0.0), Vector4(pier1_length - 0.8, top, s * pier1_width * 0.5, 0.0), 1.6)
	var c: Vector4 = platform_centre()
	var r: float = platform_radius - 0.15
	var gap: float = asin(clampf((pier1_width * 0.5 + 0.3) / r, 0.0, 1.0)) + 0.12
	var n: int = int(TAU * r / 1.6)
	for i in n:
		var a: float = TAU * (float(i) + 0.5) / float(n)
		if absf(wrapf(a - PI, -PI, PI)) < gap:
			continue
		harbour.call("add_perch", Vector4(c.x + cos(a) * r, top + 0.04, c.z + sin(a) * r, 0.0))
	var pa: Vector3 = pole_at()
	for o in [Vector2(-0.55, 0.1), Vector2(0.45, 0.45), Vector2(0.3, -0.55)]:
		harbour.call("add_perch", Vector4(pa.x + o.x, pole_above_water + 0.18, pa.y + o.y, pa.z))
	# The tunnel's roof: its ceiling slab's top, along both side edges.
	var roof: float = deck_height + tunnel_height + 0.25
	for s in [-1.0, 1.0]:
		harbour.call("add_rail", Vector4(0.6, roof, s * (tunnel_width * 0.5 + 0.2), 0.0), Vector4(tunnel_length() - 0.4, roof, s * (tunnel_width * 0.5 + 0.2), 0.0), 1.5)


func _build_hud() -> void:
	var fl := CanvasLayer.new()
	fl.name = "Fade"
	fl.layer = 20
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.add_child(_fade)
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_script(load("res://ramon/WaterLab/seascape/seascape_overlay.gd"))
	overlay.set("room", self)
	layer.add_child(overlay)
	hud = Control.new()
	hud.name = "Hud"
	hud.set_script(Hud)
	hud.set("room", self)
	layer.add_child(hud)


# -- Trym's fence, with the faces where pieces meet left open ------------------------------------------------

## A box footprint in x, z and W as a seed mesh, without the faces named in `omit` ("+x", "-x",
## "+z", "-z"). The W faces always stay, so W is railed too. See Trym's pool_room_4d.gd: a seed's
## faces are the fence's beams and its edges its ribs, so a face left out is an opening that keeps
## its jambs.
func _footprint(half: Vector3, omit: Array) -> ArrayPolyMesh4D:
	var mesh := ArrayPolyMesh4D.new()
	var corner: Dictionary = {}
	for i in 2:
		for j in 2:
			for k in 2:
				corner[Vector3i(i, j, k)] = mesh.append_vertex(Vector4(half.x if i == 1 else -half.x, 0.0,
						half.y if j == 1 else -half.y, half.z if k == 1 else -half.z), true)
	var quads: Dictionary = {
		"+x": [Vector3i(1, 0, 0), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(1, 1, 0)],
		"-x": [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 1, 1), Vector3i(0, 0, 1)],
		"-z": [Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 0, 0)],
		"+z": [Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(1, 1, 1), Vector3i(0, 1, 1)],
		"-w": [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0)],
		"+w": [Vector3i(0, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1), Vector3i(1, 0, 1)],
	}
	for key in quads:
		if key in omit:
			continue
		var quad: Array = quads[key]
		var edges := PackedInt32Array()
		for n in quad.size():
			edges.append(mesh.append_edge_indices(corner[quad[n]], corner[quad[(n + 1) % quad.size()]], true))
		mesh.append_poly_cell(2, edges, true)
	mesh.calculate_face_normals(Vector4(0.0, 1.0, 0.0, 0.0), false)
	return mesh


## A railing round a box footprint (x, z, W), the faces where pieces meet left open.
func _fence(parent: Node, nm: String, footprint: Vector3, at: Vector4, omit: Array) -> void:
	_fence_from(parent, nm, _footprint(footprint * 0.5, omit), at, footprint.z)


## Trym's railing (pool_room_4d.gd _build_walkway), with Ramon's two notes (8 Oct): THREE BEAM LINES,
## and THIN. Rib, post and beam all slim, so it reads as a pier rail and not a wall.
##
## THE SPACING SPLITS W IN THIRDS. `desired_spacing_meters` subdivides every face, and a rib that
## runs along a pier is a wall the whole pier long wherever it lands in W; a subdivision line at
## w = 0 puts that wall in your slice. Pier 2 is 5 m deep in W, and Trym's 1.4 m spacing cut it into
## four, one line exactly at 0: the first frames showed it as closed white walls. Thirds put the
## lines at +-1/6 of the depth, never at 0, whatever the pier's depth.
func _fence_from(parent: Node, nm: String, seed: ArrayPolyMesh4D, at: Vector4, w_depth: float) -> FenceGenerator4D:
	var fence := FenceGenerator4D.new()
	fence.name = nm
	fence.update_automatically = false
	fence.input_shape_type = FenceGenerator4D.INPUT_SHAPE_SEED_MESH_4D
	fence.seed_mesh_4d = seed
	fence.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	fence.desired_spacing_meters = w_depth / 3.0
	fence.post_height_meters = railing_height
	fence.post_thickness_meters = 0.07
	fence.top_footprint_ratio = 1.0
	fence.rib_height_ratio = 0.95
	fence.rib_thickness_ratio = 0.35
	fence.beam_thickness_ratio = 0.35
	fence.beam_count = 3
	fence.beam_coverage = 0.08
	fence.beam_max_height_ratio = 0.97
	var material := _material(Color(0.74, 0.75, 0.77))
	fence.post_material = material
	fence.rib_material = material
	fence.beam_material = material
	fence.position = at
	parent.add_child(fence)
	fence.update_fence_mesh_now()
	return fence


## The platform's round rail as a seed: `n` sides at radius `r`, each a face `w_depth` deep in W,
## the sides within `gap` radians of the angle `gap_at` (the way in; 0 is +x, PI/2 +z) left out. No faces across W: the platform is
## drawn in the set frame, always level, so nothing ana or kata of it is ever in view.
func _ring_seed(r: float, n: int, w_depth: float, gap: float, gap_at: float) -> ArrayPolyMesh4D:
	var mesh := ArrayPolyMesh4D.new()
	var lo: Array = []
	var hi: Array = []
	for i in n:
		var a: float = TAU * float(i) / float(n)
		lo.append(mesh.append_vertex(Vector4(cos(a) * r, 0.0, sin(a) * r, -w_depth * 0.5), true))
		hi.append(mesh.append_vertex(Vector4(cos(a) * r, 0.0, sin(a) * r, w_depth * 0.5), true))
	for i in n:
		var j: int = (i + 1) % n
		var mid: float = TAU * (float(i) + 0.5) / float(n)
		if absf(wrapf(mid - gap_at, -PI, PI)) < gap:
			continue
		var corners: Array = [lo[i], lo[j], hi[j], hi[i]]
		var edges := PackedInt32Array()
		for k in 4:
			edges.append(mesh.append_edge_indices(int(corners[k]), int(corners[(k + 1) % 4]), true))
		mesh.append_poly_cell(2, edges, true)
	mesh.calculate_face_normals(Vector4(0.0, 1.0, 0.0, 0.0), false)
	return mesh


## A basis that turns a node's +Z to face `dir` (x, z) on the floor.
static func _facing(dir: Vector2) -> Projection:
	var want: Vector2 = dir.normalized()
	for s in [1.0, -1.0]:
		var b: Projection = Basis4D.from_zx(s * atan2(want.x, want.y))
		var z: Vector4 = b * Vector4(0, 0, 1, 0)
		if Vector2(z.x, z.z).distance_to(want) < 0.01:
			return b
	return Projection.IDENTITY


# -- every frame --------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_doors(delta)
	if _fish_in >= 0.0:
		_fish_in -= delta
		if _fish_in < 0.0:
			var school: Node = get_node_or_null("School")
			if school != null and int(school.get("count")) != harbour_fish:
				school.set("count", harbour_fish)
	if _rebuild_in >= 0.0:
		_rebuild_in -= delta
		if _rebuild_in < 0.0:
			rebuild_piers()
	if player == null or _rig == null:
		return
	var p: Vector4 = player.global_position
	var site: String = ""
	if _on_platform(p):
		site = "platform"
	_edge_prompt(p)
	if site != _site:
		_site = site
		if site != "":
			_last_site = site
			_rig.set("slice_turning", true)
		else:
			_rig.set("slice_turning", false)
			_rig.call("go_home")
	_track_look(delta)
	_hold_set_frame()
	_route_states(p)


## Near the edge of the pier or the platform the first time, a thought (round 2: "if you get close to
## the edge, maybe you can get a little prompt ... I should really look down and see what creatures I
## could spot ... You can have this happen once").
func _edge_prompt(p: Vector4) -> void:
	if _looked_down or overlay == null:
		return
	var near_edge: bool = false
	var x0: float = tunnel_length()
	if p.x > x0 + 1.0 and p.x < pier1_length and absf(absf(p.z) - pier1_width * 0.5) < 0.75:
		near_edge = true
	var rel: Vector4 = p - platform_centre()
	if absf(rel.y) < 2.0 and Vector2(rel.x, rel.z).length() > platform_radius - 1.3 and Vector2(rel.x, rel.z).length() < platform_radius and rel.x > 0.0:
		near_edge = true
	if near_edge:
		_looked_down = true
		overlay.call("thought", "Oh wow. I should really look down and see what creatures I can spot.")


## The doors at the piers' backs lead back to the tank room. The scene opens out of black (it came in
## through one); walk 4 m from the doors and they arm; walk back into either and it fades to black and
## the tank room loads.
func _doors(delta: float) -> void:
	if _fade != null and _leaving < 0.0:
		_fade.color.a = maxf(_fade.color.a - delta * 1.6, 0.0)
	if player == null or not doors_enabled:
		return
	if _leaving >= 0.0:
		_leaving += delta
		if _fade != null:
			_fade.color.a = clampf(_leaving / 0.6, 0.0, 1.0)
		if _leaving >= 0.65:
			_leaving = -100.0
			get_tree().root.set_meta(ARRIVE_META, "sea")
			get_tree().change_scene_to_file(LAB_SCENE)
		return
	var p: Vector4 = player.global_position
	var d: Vector4 = door(1)
	var near: bool = absf(p.z - d.z) < 1.6 and absf(p.w) < 1.5 and absf(p.y - d.y) < 1.5 and p.x < d.x + 3.0
	if _door != null:
		_door.call("notice", p if _doors_armed else Vector4(1000, 0, 0, 0))
	if near and _doors_armed and p.x < d.x + 0.45 and (_door == null or float(_door.get("open")) > 0.5):
		_leaving = 0.0
		player.set("input_enabled", false)
	if not near:
		_doors_armed = true


## The tilt the rig's slice has, as a rotation of the world: the rig's ground basis G against the level
## frame you are looking along (`_look`), turned into world axes.
##
## ROUND 4 (Ramon: "When rotating through W, the platform itself appears to rotate or shift left and
## right ... the platform should remain visually stable"). This was G against the level frame NEAREST
## G (flattened(G)), whose heading drifts as the slice tilts: a drag that only tilts the slice turned
## that heading a little, and the platform swung by it. Now the heading is kept by hand
## (_track_look): it follows only a look round (a turn of G in its own floor, which leaves its W
## where it was), never a slice drag. Drawn with G times that frame's inverse, the platform is
## exactly as it was in your view while you drag, whatever the drag does; it turns only when you
## look round. Coming level again, the kept heading eases onto the actual one, so nothing snaps.
var _look := Projection.IDENTITY
var _g_prev := Projection.IDENTITY
var _look_set: bool = false


func _track_look(delta: float) -> void:
	if _rig == null:
		return
	var g: Projection = (_rig as Node4D).basis
	if not _look_set:
		_look = GB.flattened(g)
		_g_prev = g
		_look_set = true
	var d: Projection = Basis4D.transposed(_g_prev) * g
	# A look round turns the frame in its own floor: its W stays. A slice drag moves W.
	if absf(d.w.w - 1.0) < 1e-5:
		_look = _look * d
		_look = GB.cleaned(_look)
	_g_prev = g
	var tilt: float = GB.tilt(g)
	if tilt < 0.0005:
		_look = GB.flattened(g)
	else:
		_look = GB.rotated_toward(_look, GB.flattened(g), delta * 2.0 * (1.0 - smoothstep(0.0, 0.35, tilt)))


func _world_tilt() -> Projection:
	var g: Projection = (_rig as Node4D).basis
	var s: Projection = g * Basis4D.transposed(_look)
	var bp: Projection = (_rig.get_parent() as Node4D).global_basis
	return bp * s * bp.inverse()


## The platform drawn as if the slice were level, while the sea is cut a new way: it stays SET.
##
## ABOUT WHERE YOU STOOD WHEN THE TURN BEGAN. The camera turns about you, not about the platform, so
## the platform is turned by the slice's tilt about the point the turn began at (`_pivot`): seen
## from there it is exactly the level platform. Walking while turned moves you through the tilted
## slice, S v in the world for a step v on screen; measured back into the platform's own level frame
## (`_visual`) that is the step v, so you cross the platform as you see it. The first version turned
## it about its own centre: from its edge, turned 60 degrees, the platform slid out of the slice and
## all but vanished (the frames of 8 Oct, standing where pier 1 meets it). When the slice is level
## again you are put where the level platform showed you.
func _hold_set_frame() -> void:
	if _set_frame == null:
		return
	var c: Vector4 = platform_centre()
	var o: Vector4 = (_rig as Node4D).global_position
	var tilted: bool = slice_degrees().x > 0.2
	if tilted and (_turned_here or _site == "platform"):
		var s: Projection = _world_tilt()
		if not _turned_here:
			_turned_here = true
			_pivot = o
		_visual = _pivot + s.inverse() * (o - _pivot) - c
		_set_frame.global_basis = s
		_set_frame.global_position = _pivot + s * (c - _pivot)
		return
	if _turned_here:
		_turned_here = false
		var off: Vector4 = o - player.global_position
		player.global_position = Vector4(c.x + _visual.x - off.x, player.global_position.y, c.z + _visual.z - off.z, 0.0)
	_set_frame.global_basis = Projection.IDENTITY
	_set_frame.global_position = c


## Pier 1's platform has a round rail, kept here: the physics is box-only. The way back to the pier
## is open only while the slice is level; walk toward the edge while it is turned and the slice
## goes home first.
func _physics_process(_delta: float) -> void:
	if player == null or _rig == null:
		return
	var c: Vector4 = platform_centre()
	var limit_turned: float = platform_radius - 0.45
	if _turned_here:
		# Turned: the rail is kept where you see it, in the platform's level frame.
		var flat2 := Vector2(_visual.x, _visual.z)
		var rv: float = flat2.length()
		if rv > limit_turned - 1.4:
			_rig.call("go_home")
		if rv > limit_turned:
			var nv: Vector2 = flat2 * (limit_turned / rv)
			var o: Vector4 = (_rig as Node4D).global_position
			var q := Vector4(c.x + nv.x, o.y, c.z + nv.y, 0.0)
			var world: Vector4 = _pivot + _world_tilt() * (q - _pivot)
			player.global_position = world - (o - player.global_position)
		return
	var p: Vector4 = player.global_position
	var rel: Vector4 = p - c
	if absf(rel.y) > 2.5:
		return
	var flat := Vector3(rel.x, rel.z, rel.w)
	var r: float = flat.length()
	if r > platform_radius + 1.2:
		return
	var limit: float = platform_radius - 0.45
	var level: bool = slice_degrees().length() < 0.5
	if r > limit - 1.4 and not level and _site == "platform":
		_rig.call("go_home")
	if r <= limit:
		return
	var in_gap: bool = rel.x < 0.0 and absf(rel.z) < pier1_width * 0.5 - 0.2 and absf(rel.w) < pier1_w_depth * 0.5
	if in_gap and level:
		return
	var back: Vector3 = flat * (limit / r)
	player.global_position = Vector4(c.x + back.x, p.y, c.z + back.y, c.w + back.z)


func _on_platform(p: Vector4) -> bool:
	if _turned_here:
		return Vector2(_visual.x, _visual.z).length() < platform_radius - 0.3
	var rel: Vector4 = p - platform_centre()
	return absf(rel.y) < 2.5 and Vector3(rel.x, rel.z, rel.w).length() < platform_radius - 0.3


## The routes' destinations completed once you have stood at them.
func _route_states(p: Vector4) -> void:
	for pair in [["Paths/Pier1", "Platform", platform_centre(), platform_radius - 1.0]]:
		var net: Node = get_node_or_null(String(pair[0]))
		if net == null or bool(_reached.get(pair[1], false)):
			continue
		var at: Vector4 = pair[2]
		if Vector2(p.x - at.x, p.z - at.z).length() > float(pair[3]):
			continue
		_reached[pair[1]] = true
		var graph: Resource = net.get("graph")
		if graph == null:
			continue
		for n in graph.get("nodes"):
			if String((n as Dictionary).get("target", "")) == String(pair[1]):
				n["state"] = "completed"
		graph.emit_changed()


# -- what the HUD and the panels read -------------------------------------------------------------------------

## How far the slice is tilted from level, in degrees (x; y is 0). The pen's rig holds one tilt of
## the slice's normal rather than two plane angles (GroundBasis4D.tilt).
func slice_degrees() -> Vector2:
	if _rig == null:
		return Vector2.ZERO
	return Vector2(rad_to_deg(GB.tilt((_rig as Node4D).basis)), 0.0)


func where_text() -> String:
	match _site:
		"platform":
			return "On the platform: right drag turns the slice of the sea, the platform stays set."
	return ""


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


# -- keys -----------------------------------------------------------------------------------------------------

## The four seas on 1 to 4 (round 2: "always visible presets ... toggle it by pressing 1, 2 ... the
## one that's active now should definitely be one of these"): the moderate swell you come in to,
## then the swell that runs through W, the crossing seas, the storm.
const SEAS := [1, 3, 7, 2]


func seas() -> Array:
	return SEAS


## Which of the four seas is running (-1: none of them).
func sea_index() -> int:
	if _water == null:
		return -1
	return SEAS.find(int(_water.get(&"preset_index")))


## The Gerstner: 0 off (plain sines), else its look, 1 to 3 (water4d.gdshader gerstner_style).
func gerstner() -> int:
	if _water == null or int(_water.get(&"solve_iterations")) <= 0:
		return 0
	return int(_water.get(&"gerstner_style"))


func set_gerstner(g: int) -> void:
	if _water == null:
		return
	_water.set(&"solve_iterations", 0 if g == 0 else 2)
	if g > 0:
		_water.set(&"gerstner_style", g)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			if _water != null:
				var preset: int = SEAS[key.keycode - KEY_1]
				_water.call(&"set_preset", preset)
				_toast(Presets.preset_name(preset))
		KEY_F:
			if _water != null:
				_water.set(&"debug_jacobian", not bool(_water.get(&"debug_jacobian")))
		KEY_G:
			var g: int = (gerstner() + 1) % 4
			set_gerstner(g)
			_toast("Gerstner off: plain sines" if g == 0 else "Gerstner %d" % g)
		_:
			return
	get_viewport().set_input_as_handled()


func _toast(text: String) -> void:
	if hud != null and hud.has_method("toast"):
		hud.call("toast", text)
