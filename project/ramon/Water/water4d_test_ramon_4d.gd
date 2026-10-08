extends Node4D

## RAMON'S WATER (8 Oct 2026): his version of Trym's 4D water test (sandbox/water4d/water4d_test.tscn,
## from Trym's water-annex branch; everything of Trym's this needs is carried into Water/carried/).
## Plan and handover: follow_up/water_ramon.md.
##
## You come in from the Arboretum through a door in the kit's sea wall and stand on a pier over
## Trym's sea: a 4D height field whose waves run in x, z and W, drawn on a 3D grid in the renderer's
## own world and solved for your slice (Water/carried/water4d/README.md).
##
##   PIER 1  from door 1 straight out onto a big round platform in code blue with the lab's two
##           pages printed on its floor. On the platform a right drag turns your slice: the sea is cut a new way, but the
##           platform stays SET. Its deck, rail and panels hang in a frame that turns WITH the slice
##           (the camera rig's own xw and zw angles, about the platform's centre), so they are drawn
##           as if nothing had turned. Its collision stays square to the world and deep in W, and its
##           round rail is kept in code (the physics is box-only), with the way out shut until the
##           slice is level again; walk toward the edge while turned and the slice goes home first.
##   PIER 2  P, from door 2: wider, its last ten metres code blue with a circle and a page on the
##           floor. On the circle the slice turns too, but nothing is set: the pier is world, and
##           turns with it. Past a moderate turn its page hands over to a copy on a plate 40 m deep
##           in W wearing the same live picture (Ramon's suggestion: "a box with a rasterized
##           texture ... to sell the illusion").
##
## Trym's pole (the banded pillar, the sea floor to above the water, so the depth fade has a ruler)
## stands in the corner of pier 1's turn; his plesiosaur swims under pier 1.
##
## KEYS: 1-8 seas, F foam map, G Gerstner on/off, N detail noise (Trym's), P the other pier, R levels
## the slice (the rig's), Tab the HUD's modes (water4d_hud_ramon.gd).
##
## NO class_name (engine_gotchas.md).

const Presets := preload("res://ramon/Water/carried/water4d/water4d_presets.gd")
const KitPlayer := preload("res://ramon/Water/carried/kit/kit_player.gd")
const WallPanel := preload("res://ramon/Water/carried/kit/panels/kit_wall_panel_4d.gd")
const Spec := preload("res://ramon/Water/carried/kit/panels/kit_panel_spec.gd")
const LabGrid := preload("res://ramon/Water/carried/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/Water/carried/LabKit/lab_materials.gd")
const Style := preload("res://ramon/Water/carried/kit/kit_style.gd")
const Hud := preload("res://ramon/Water/water4d_hud_ramon.gd")

@export_group("Sea")
@export var start_preset: int = 1
## Trym's seas are open-ocean sized; at 1.0 a storm's crests reach a few metres. Smaller keeps the
## sea under the decks.
@export var wave_scale: float = 0.8
@export var floor_depth: float = 35.0
@export var creature_length: float = 15.0
@export var creature_speed: float = 1.5

@export_group("Piers")
## The decks' top, above the still water line (y 0). "Floating right above the ocean."
@export var deck_height: float = 2.2
## Door to platform (Ramon, 8 Oct: shorter; it was 26 m and turned left halfway).
@export var pier1_length: float = 14.0
@export var pier1_width: float = 3.4
@export var platform_radius: float = 7.0
## How far through W the decks reach (Trym's walkway: 4.2).
@export var pier1_w_depth: float = 4.2
@export var pier2_z: float = 24.0
## Door to its end, the blue end included (Ramon, 8 Oct: shorter; it was 33 m).
@export var pier2_length: float = 20.0
@export var pier2_width: float = 5.0
@export var pier2_w_depth: float = 5.0
@export var ring_radius: float = 2.2
## Pier 2's blue end: the circle and its page, in its last this many metres.
@export var pier2_info_length: float = 10.0
@export var railing_height: float = 1.0
## The sci-fi doors at the piers' backs: the opening's height.
@export var door_height: float = 3.2

@export_group("Pole")
## x, z, W.
@export var pole_at: Vector3 = Vector3(8.0, -7.0, 0.0)
@export var pole_size: float = 2.3
@export var pole_above_water: float = 3.6

@export_group("Panels")
## The pages' size on the floors, as a share of the kit's 9.6 x 5.9 m.
@export var platform_panel_scale: float = 0.55
@export var pier2_panel_scale: float = 0.45
## Past this turn of the slice (degrees), pier 2's page hands over to its deep plate.
@export var panel_swap_degrees: float = 28.0

@export_group("Camera")
@export var camera_distance: float = 6.0
@export var camera_height: float = 2.4
@export var camera_pitch_degrees: float = -12.0

var player: CharacterBody4D
var hud: Control
var _water: Node
var _rig: Node
var _set_frame: Node4D
var _pier2_plate: MeshInstance4D
var _pier2_deep: MeshInstance4D
var _site: String = ""
var _last_site: String = ""
var _at_pier2: bool = false
var _reached: Dictionary = {}
var _rebuild_in: float = -1.0


# -- where things are ---------------------------------------------------------------------------------------

func platform_centre() -> Vector4:
	return Vector4(pier1_length + platform_radius - 0.6, deck_height, 0.0, 0.0)


func ring_centre() -> Vector4:
	return Vector4(pier2_length - pier2_info_length + 2.5, deck_height, pier2_z, 0.0)


func door(i: int) -> Vector4:
	return Vector4(0.8, deck_height + 0.05, 0.0 if i == 1 else pier2_z, 0.0)


# -- building -----------------------------------------------------------------------------------------------

func _ready() -> void:
	Style.apply("bright")
	_water = get_node_or_null("Water")
	if _water != null and _water.has_method(&"set_preset"):
		_water.set(&"wave_scale", wave_scale)
		_water.call(&"set_preset", start_preset)
	_build_piers()
	_build_pole()
	_build_floor()
	_build_player()
	_build_creature()
	_build_hud()
	_place_targets()
	process_physics_priority = 100


## The routes' targets where the platform and the circle are now (they follow the settings above).
func _place_targets() -> void:
	var platform: Node4D = get_node_or_null("Paths/Targets/Platform") as Node4D
	if platform != null:
		platform.position = platform_centre()
	var circle: Node4D = get_node_or_null("Paths/Targets/Circle") as Node4D
	if circle != null:
		circle.position = ring_centre()
	# Each route's destination just short of what it leads to, its start at its door.
	var ends: Array = [["Paths/Pier1", Vector4(pier1_length - 1.2, 0.0, 0.0, 0.0), Vector4(1.4, 0.0, 0.0, 0.0)],
		["Paths/Pier2", Vector4(ring_centre().x - ring_radius - 0.7, 0.0, pier2_z, 0.0), Vector4(1.4, 0.0, pier2_z, 0.0)]]
	for e in ends:
		var net: Node = get_node_or_null(String(e[0]))
		var graph: Resource = net.get("graph") if net != null else null
		if graph == null:
			continue
		for n in graph.get("nodes"):
			match String((n as Dictionary).get("kind", "")):
				"destination":
					n["pos"] = e[1]
				"start":
					n["pos"] = e[2]
		graph.emit_changed()


## Both piers, their doors and the platform. Called again by rebuild_piers() when the HUD's PIERS
## sliders change their length or width.
func _build_piers() -> void:
	_build_door("Door1", 0.0, pier1_width, pier1_w_depth)
	_build_door("Door2", pier2_z, pier2_width, pier2_w_depth)
	_build_pier1()
	_build_platform()
	_build_pier2()


## The piers again at their new size: the old ones freed in the same frame, so nothing you stand on
## is missing for a physics step; the routes' ends follow. Coalesced, as a slider sends a value
## every step of a drag.
func rebuild_piers_later() -> void:
	_rebuild_in = 0.25


func rebuild_piers() -> void:
	for nm in ["Door1", "Door2", "Pier1", "Pier2", "PlatformSet", "PlatformBody", "Pages"]:
		var n: Node = get_node_or_null(nm)
		if n != null:
			remove_child(n)
			n.queue_free()
	_set_frame = null
	_pier2_plate = null
	_pier2_deep = null
	_build_piers()
	_place_targets()


## A sci-fi door standing at the back of each pier, the way you came in (Ramon, 8 Oct: "a scifi door
## on the backside. no whole housing or door/room system connecting the 2"; the first version was a
## kit room on the shore with a doorway for each pier). Closed, facing out along the pier (+x):
## a gunmetal frame on a pale bulkhead plate, two leaves meeting in a lit seam, light strips round
## the opening, a status light over it. A wall behind the leaves stops you stepping off the back.
func _build_door(nm: String, z: float, width: float, w_depth: float) -> void:
	var d := Node4D.new()
	d.name = nm
	d.position = Vector4(0.0, deck_height, z, 0.0)
	add_child(d)
	var frame := Color(0.20, 0.22, 0.26)
	var plate := Color(0.78, 0.79, 0.81)
	var leaf := Color(0.13, 0.15, 0.19)
	var glow: TetraMaterial4D = Mats.glow(Color(0.40, 0.86, 1.0), 1.4)
	var h: float = door_height
	var wd: float = w_depth + 0.4
	var hw: float = width * 0.5
	# The bulkhead plate behind, a little bigger than the frame.
	_box(d, "Plate", Vector4(-0.55, (h + 0.9) * 0.5, 0.0, 0.0), Vector4(0.2, h + 0.9, width + 2.0, wd), plate)
	# The frame: two pillars and a lintel, the opening's top corners chamfered.
	for s in [-1.0, 1.0]:
		_box(d, "Pillar%d" % int(s), Vector4(-0.2, (h + 0.5) * 0.5, s * (hw + 0.28), 0.0), Vector4(0.5, h + 0.5, 0.56, wd), frame)
		var c: MeshInstance4D = _box(d, "Chamfer%d" % int(s), Vector4(-0.2, h, s * hw, 0.0), Vector4(0.5, 0.5, 0.5, wd), frame)
		c.basis = Basis4D.from_yz(PI * 0.25)
		var strip := MeshInstance4D.new()
		strip.name = "Strip%d" % int(s)
		strip.mesh = Mats.box_mesh(Vector4(0.06, h - 0.3, 0.06, wd))
		strip.position = Vector4(0.08, (h - 0.3) * 0.5, s * (hw - 0.02), 0.0)
		strip.material_override = glow
		d.add_child(strip)
	_box(d, "Lintel", Vector4(-0.2, h + 0.3, 0.0, 0.0), Vector4(0.5, 0.6, width + 1.12, wd), frame)
	var top := MeshInstance4D.new()
	top.name = "StripTop"
	top.mesh = Mats.box_mesh(Vector4(0.06, 0.06, width - 0.6, wd))
	top.position = Vector4(0.08, h - 0.05, 0.0, 0.0)
	top.material_override = glow
	d.add_child(top)
	var lamp := MeshInstance4D.new()
	lamp.name = "StatusLight"
	lamp.mesh = Mats.box_mesh(Vector4(0.06, 0.14, minf(1.2, width * 0.3), wd))
	lamp.position = Vector4(0.08, h + 0.32, 0.0, 0.0)
	lamp.material_override = glow
	d.add_child(lamp)
	# The two leaves, closed, and the lit seam where they meet.
	for s in [-1.0, 1.0]:
		_box(d, "Leaf%d" % int(s), Vector4(-0.12, h * 0.5, s * (hw * 0.5 + 0.02), 0.0), Vector4(0.14, h, hw - 0.04, wd), leaf)
		_box(d, "LeafBand%d" % int(s), Vector4(-0.04, h * 0.62, s * (hw * 0.5 + 0.02), 0.0), Vector4(0.04, 0.08, hw - 0.5, wd), frame)
	var seam := MeshInstance4D.new()
	seam.name = "Seam"
	seam.mesh = Mats.box_mesh(Vector4(0.05, h - 0.2, 0.05, wd))
	seam.position = Vector4(-0.03, h * 0.5, 0.0, 0.0)
	seam.material_override = glow
	d.add_child(seam)
	_solid(d, "Back", Vector4(-0.2, h * 0.5, 0.0, 0.0), Vector4(0.4, h, width + 1.2, wd))


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
	_deck(holder, "Run", Vector4(pier1_length * 0.5, y, 0.0, 0.0), Vector4(pier1_length, 0.3, pier1_width, wd))
	# Trym's fence along it, open at the door and where it meets the platform.
	_fence(holder, "RunRail", Vector3(pier1_length, pier1_width, wd), Vector4(pier1_length * 0.5, deck_height, 0.0, 0.0), ["-x", "+x"])
	# What stops you, on each side that is closed (the fence is mesh only).
	var h: float = railing_height
	var ry: float = deck_height + h * 0.5
	_solid(holder, "RunSideA", Vector4(pier1_length * 0.5, ry, hw, 0.0), Vector4(pier1_length, h, 0.16, wd))
	_solid(holder, "RunSideB", Vector4(pier1_length * 0.5, ry, -hw, 0.0), Vector4(pier1_length, h, 0.16, wd))
	for s in [-1.0, 1.0]:
		_solid(holder, "RunCapW%d" % int(s), Vector4(pier1_length * 0.5, ry, 0.0, s * wd * 0.5), Vector4(pier1_length, h, pier1_width, 0.16))


## Pier 1's round platform, in code blue, its two pages printed on its floor. Its collision is a
## square slab deep in W, square to the world; its deck, rail, ring and pages hang in `_set_frame`,
## which turns with the slice so they read as set.
##
## THE PAGES ARE ON THE FLOOR (Ramon, 8 Oct: "it should be displayed on the floor, and the platform
## should be blue"; the first version stood the two panels up at the back, like walls). The kit's
## panels still draw them (kit_wall_panel_4d.gd: a live page in a viewport of its own), standing out
## of sight under the water; their pages are printed onto plates lying on the deck, the kit's floor
## print (lab_grid.gdshader print_uv: on a floor the text's top points to -z, away from someone
## walking in from +z, which is the way in here).
func _build_platform() -> void:
	var c: Vector4 = platform_centre()
	_solid(self, "PlatformBody", Vector4(c.x, c.y - 0.15, c.z, 0.0), Vector4(platform_radius * 2.0, 0.3, platform_radius * 2.0, platform_radius * 2.0))
	_set_frame = Node4D.new()
	_set_frame.name = "PlatformSet"
	_set_frame.position = c
	add_child(_set_frame)
	# The deck: a cubinder, round in x and z, square in y and W, in the kit's code blue.
	var shape := CubinderShape4D.new()
	shape.radius = platform_radius
	shape.height = 0.3
	shape.thickness = pier1_w_depth
	var disc := MeshInstance4D.new()
	disc.name = "Deck"
	disc.mesh = shape.to_tetra_mesh()
	disc.position = Vector4(0.0, -0.15, 0.0, 0.0)
	var size := Vector4(platform_radius * 2.0, 0.3, platform_radius * 2.0, pier1_w_depth)
	disc.material_override = LabGrid.material(Style.code_swatch("blue"), size, c)
	_set_frame.add_child(disc)
	# The rail: Trym's fence round a 32-sided ring, open where the pier comes in (-x).
	var r: float = platform_radius - 0.15
	var gap: float = asin(clampf((pier1_width * 0.5 + 0.3) / r, 0.0, 1.0))
	_fence_from(_set_frame, "Rail", _ring_seed(r, 32, pier1_w_depth, gap, PI), Vector4.ZERO, pier1_w_depth)
	# Trym's cyan ring, near the rail, round the pages.
	var cyan := Color(0.25, 0.72, 0.85)
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		if absf(wrapf(a - PI, -PI, PI)) < gap:
			continue
		_box(_set_frame, "Tile%d" % i, Vector4(cos(a) * (platform_radius - 0.65), 0.02, sin(a) * (platform_radius - 0.65), 0.0), Vector4(0.42, 0.05, 0.42, 0.6), cyan)
	# The pages, side by side on the floor: the introduction on the left as you walk in (-z, walking
	# +x), the research on the right. Each plate is turned so its page's top points away from you,
	# toward +x (the floor print's own top is -z).
	if get_node_or_null("PanelSource") == null:
		var source := Node.new()
		source.name = "PanelSource"
		source.set_script(load("res://ramon/Water/water_panel_source.gd"))
		add_child(source)
	var info: Resource = load("res://ramon/Water/water_info.tres")
	var pm: Vector2 = Spec.PANEL * Spec.UNIT_M * platform_panel_scale
	for i in 2:
		var page: Node4D = _page("intro" if i == 0 else "research", info, platform_panel_scale, Vector4(c.x + float(i) * 12.0, -30.0, c.z, 0.0))
		var z: float = (float(i) - 0.5) * (pm.x + 0.5)
		var plate: MeshInstance4D = _plate(_set_frame, "Page%d" % i, Vector4(-0.3, 0.01, z, 0.0), pm, pier1_w_depth)
		plate.basis = _facing(Vector2(-1.0, 0.0))
		_print_later(plate, page, pm)


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


## A thin blue plate for a page lying on a deck: the page and a 0.3 m border, `w_depth` deep in W.
func _plate(parent: Node4D, nm: String, at: Vector4, pm: Vector2, w_depth: float) -> MeshInstance4D:
	var size := Vector4(pm.x + 0.6, 0.04, pm.y + 0.6, w_depth)
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(size)
	m.position = at
	m.material_override = LabGrid.material(Style.code_swatch("blue"), size, parent.global_position + at)
	parent.add_child(m)
	return m


## The page's live texture onto the plate's top face, once the page has drawn; the page's own slab
## hidden.
func _print_later(plate: MeshInstance4D, page: Node4D, pm: Vector2) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var vp: SubViewport = page.get("_vp")
	var slab: Node4D = page.get("_slab")
	if slab != null:
		slab.visible = false
	if vp == null or not is_instance_valid(plate):
		return
	var m: TetraMaterial4D = plate.material_override as TetraMaterial4D
	LabGrid.set_print(m, vp.get_texture(), Vector4(0, 1, 0, 0), Rect2(Vector2(0.3, 0.3), pm), Color.WHITE, 0.15)
	LabGrid.set_print_strength(m, 1.0)
	m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)


## Pier 2: wider, from door 2 straight out. Its last `pier2_info_length` metres are code blue: the
## circle, and its page printed on the floor beyond it, read as you stand on the circle looking on
## out to sea. When the slice turns, that floor turns with the pier; past `panel_swap_degrees` the
## page hands over to a copy on a plate 40 m deep in W, which the turn cannot cut away (Ramon: "a
## box with rasterized texture temporarily to sell the illusion").
func _build_pier2() -> void:
	var holder := Node4D.new()
	holder.name = "Pier2"
	add_child(holder)
	var y: float = deck_height - 0.15
	var hw: float = pier2_width * 0.5
	var wd: float = pier2_w_depth
	var blue_from: float = pier2_length - pier2_info_length
	_deck(holder, "Deck", Vector4(blue_from * 0.5, y, pier2_z, 0.0), Vector4(blue_from, 0.3, pier2_width, wd))
	var info_size := Vector4(pier2_info_length, 0.3, pier2_width, wd)
	var info_at := Vector4(blue_from + pier2_info_length * 0.5, y, pier2_z, 0.0)
	var blue := MeshInstance4D.new()
	blue.name = "InfoDeck"
	blue.mesh = Mats.box_mesh(info_size)
	blue.position = info_at
	blue.material_override = LabGrid.material(Style.code_swatch("blue"), info_size, info_at)
	holder.add_child(blue)
	_solid(holder, "InfoDeckBody", info_at, info_size)
	_fence(holder, "Rail", Vector3(pier2_length, pier2_width, wd), Vector4(pier2_length * 0.5, deck_height, pier2_z, 0.0), ["-x"])
	var h: float = railing_height
	var ry: float = deck_height + h * 0.5
	_solid(holder, "SideA", Vector4(pier2_length * 0.5, ry, pier2_z + hw, 0.0), Vector4(pier2_length, h, 0.16, wd))
	_solid(holder, "SideB", Vector4(pier2_length * 0.5, ry, pier2_z - hw, 0.0), Vector4(pier2_length, h, 0.16, wd))
	_solid(holder, "End", Vector4(pier2_length, ry, pier2_z, 0.0), Vector4(0.16, h, pier2_width, wd))
	for s in [-1.0, 1.0]:
		_solid(holder, "CapW%d" % int(s), Vector4(pier2_length * 0.5, ry, pier2_z, s * wd * 0.5), Vector4(pier2_length, h, pier2_width, 0.16))
	# The circle, in Trym's cyan.
	var c: Vector4 = ring_centre()
	var cyan := Color(0.25, 0.72, 0.85)
	for i in 14:
		var a: float = TAU * float(i) / 14.0
		_box(holder, "Tile%d" % i, Vector4(c.x + cos(a) * ring_radius, deck_height + 0.02, c.z + sin(a) * ring_radius, 0.0), Vector4(0.4, 0.05, 0.4, wd), cyan)
	# The page beyond the circle, its top toward the sea (+x): a plate turned so its -z faces +x.
	var pm: Vector2 = Spec.PANEL * Spec.UNIT_M * pier2_panel_scale
	var page: Node4D = _page("intro", load("res://ramon/Water/pier2_info.tres"), pier2_panel_scale, Vector4(pier2_length, -30.0, pier2_z + 12.0, 0.0))
	var at := Vector4(pier2_length - 0.45 - (pm.y + 0.6) * 0.5, deck_height + 0.01, pier2_z, 0.0)
	_pier2_plate = _plate(holder, "InfoPage", at, pm, wd)
	_pier2_plate.basis = _facing(Vector2(-1.0, 0.0))
	_print_later(_pier2_plate, page, pm)
	_pier2_deep = _plate(holder, "InfoPageDeep", at, pm, 40.0)
	_pier2_deep.basis = _facing(Vector2(-1.0, 0.0))
	_pier2_deep.visible = false
	_print_later(_pier2_deep, page, pm)


## Trym's banded pillar: the sea floor to above the water, so the depth fade has a ruler.
func _build_pole() -> void:
	var holder := Node4D.new()
	holder.name = "Pole"
	add_child(holder)
	var height: float = floor_depth + pole_above_water
	var x: float = pole_at.x
	var z: float = pole_at.y
	var w: float = pole_at.z
	_box(holder, "Shaft", Vector4(x, -floor_depth + height * 0.5, z, w), Vector4(pole_size, height, pole_size, pole_size * 2.4), Color(0.88, 0.86, 0.80))
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
	go_to(door(1), -PI * 0.5)


## Trym's plesiosaur, wandering under pier 1 (the pool room's _build_creature, with this sea's bounds).
func _build_creature() -> void:
	var scene: PackedScene = load("res://ramon/Water/carried/water4d/plesiosaur.tscn") as PackedScene
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
	pilot.set_script(load("res://ramon/Water/carried/water4d/plesiosaur_pilot.gd"))
	pilot.set(&"body_path", NodePath(".."))
	pilot.set(&"swimmer_path", NodePath("../Swimmer"))
	pilot.set(&"player_path", NodePath("../../../Player"))
	pilot.set(&"bounds", Vector3(30.0, 30.0, 8.0))
	pilot.set(&"depth_range", Vector2(6.0, floor_depth - maxf(4.0, creature_length * 0.3)))
	pilot.set(&"speed", creature_speed)
	creature.add_child(pilot)
	# THE SEAMS STAY AS BUILT. Trym's swimmer re-bends the patches between its 13 pieces every
	# physics tick, rewriting their vertices: measured here at about 6 ms a tick (the slow frames,
	# 95th percentile 8 ms against 1.8 ms with this off). Deep under the water the seams do not
	# show; the pieces still swim.
	if swimmer != null:
		swimmer.set(&"blend_joints", false)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
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
	elif _on_ring(p):
		site = "ring"
	if site != _site:
		_site = site
		if site != "":
			_last_site = site
			_rig.set("slice_turning", true)
		else:
			_rig.set("slice_turning", false)
			_rig.call("go_home")
	_hold_set_frame()
	_pier2_picture()
	_route_states(p)


## The platform's frame turned by the slice the rig is turned by, about the platform's centre, so the
## platform is drawn as if the slice were level: it stays set while the sea is cut a new way.
func _hold_set_frame() -> void:
	if _set_frame == null:
		return
	var turn := Projection.IDENTITY
	if _last_site == "platform":
		var a: float = float(_rig.get("_slice_xw"))
		var b: float = float(_rig.get("_slice_zw"))
		var s: Projection = Basis4D.from_xw(a) * Basis4D.from_zw(b)
		var parent_basis: Projection = (_rig.get_parent() as Node4D).global_basis
		turn = parent_basis * s * parent_basis.inverse()
	_set_frame.global_basis = turn
	_set_frame.global_position = platform_centre()


## Pier 2's page or its deep copy, by how far the slice is turned.
func _pier2_picture() -> void:
	if _pier2_plate == null or _pier2_deep == null:
		return
	var deep: bool = _last_site == "ring" and slice_degrees().length() > panel_swap_degrees
	_pier2_deep.visible = deep
	_pier2_plate.visible = not deep


## Pier 1's platform has a round rail, kept here: the physics is box-only. The way back to the pier
## is open only while the slice is level; walk toward the edge while it is turned and the slice
## goes home first.
func _physics_process(_delta: float) -> void:
	if player == null or _rig == null:
		return
	var c: Vector4 = platform_centre()
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
	var rel: Vector4 = p - platform_centre()
	return absf(rel.y) < 2.5 and Vector3(rel.x, rel.z, rel.w).length() < platform_radius - 0.3


func _on_ring(p: Vector4) -> bool:
	var rel: Vector4 = p - ring_centre()
	return absf(rel.y) < 2.5 and Vector2(rel.x, rel.z).length() < ring_radius + 0.2 and absf(rel.w) < pier2_w_depth * 0.5


## The routes' destinations completed once you have stood at them.
func _route_states(p: Vector4) -> void:
	for pair in [["Paths/Pier1", "Platform", platform_centre(), 5.0], ["Paths/Pier2", "Circle", ring_centre(), ring_radius + 0.3]]:
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

## The slice's turn in degrees: (xw, zw).
func slice_degrees() -> Vector2:
	if _rig == null:
		return Vector2.ZERO
	return Vector2(rad_to_deg(float(_rig.get("_slice_xw"))), rad_to_deg(float(_rig.get("_slice_zw"))))


func where_text() -> String:
	match _site:
		"platform":
			return "On pier 1's platform: right drag turns the slice of the sea, the platform stays set."
		"ring":
			return "On pier 2's circle: right drag turns the slice, and the pier turns with it."
	return ""


func go_to(at: Vector4, yaw: float) -> void:
	if player == null:
		return
	player.global_position = at
	player.set("linear_velocity", Vector4.ZERO)
	player.set("_facing", yaw)
	if _rig != null:
		_rig.set("yaw", yaw)
		_rig.call("_apply")


# -- keys -----------------------------------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			if _water != null:
				_water.call(&"set_preset", key.keycode - KEY_1)
				_toast(Presets.preset_name(key.keycode - KEY_1))
		KEY_F:
			if _water != null:
				_water.set(&"debug_jacobian", not bool(_water.get(&"debug_jacobian")))
		KEY_G:
			if _water != null:
				var n: int = int(_water.get(&"solve_iterations"))
				_water.set(&"solve_iterations", 0 if n > 0 else 2)
				_toast("Gerstner solve off: plain sines" if n > 0 else "Gerstner solve on")
		KEY_N:
			if _water != null:
				var d: float = float(_water.get(&"detail_strength"))
				_water.set(&"detail_strength", 0.0 if d > 0.0 else 0.085)
		KEY_P:
			_at_pier2 = not _at_pier2
			if _rig != null:
				_rig.call("go_home")
			go_to(door(2 if _at_pier2 else 1), -PI * 0.5)
			_toast("Pier 2: the pier turns with the slice" if _at_pier2 else "Pier 1: the platform stays set")
		_:
			return
	get_viewport().set_input_as_handled()


func _toast(text: String) -> void:
	if hud != null and hud.has_method("toast"):
		hud.call("toast", text)
