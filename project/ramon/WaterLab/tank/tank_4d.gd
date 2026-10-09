@tool
extends Node4D

## WATER LAB: the big tank across the back of the room. This node stands on the floor under the
## middle of it; +z is the glass you look through, x runs along it.
##
##   THE STAND   a long lab pedestal in the kit's manner (kit_pedestal.gd's square one, stretched):
##               a dark foot set in, the dark metal body, a dark band, the white lip. Deep in W, as
##               the room is, so a turned slice never cuts it away.
##   THE TANK    the water is a 4D box (`water_size`: x, y, z, W). Its glass is invisible; its frame
##               is gunmetal bars along the edges a level slice shows, a dark hood over the top with
##               a light strip under its front edge, a deep blue backdrop and a sand bed inside.
##   THE WATER   tank_water_4d.gd: one full-screen pass that meets every view ray with the water's
##               4D box (the colour by depth, caustics, the surface from below, shafts of light).
##   THE LIFE    built in play only, under "Life" at the water's middle (the water's own frame: x
##               along, y up, z toward the glass, W): the koi (life/koi_school_4d.gd), the eel, the
##               weed, the reef, the stones and the bubbles. The stones and the reef hand the swimmers
##               the spheres to swim round.
##
## The frame and the stand are built in the editor too (so the room can be laid out round them);
## the water and the life only in play.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/WaterLab/carried/scripts/chamber_build.gd")
const Mats := preload("res://ramon/WaterLab/carried/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/WaterLab/carried/LabKit/lab_grid.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")
const Pedestal := preload("res://ramon/WaterLab/carried/kit/kit_pedestal.gd")
const WaterScript := preload("res://ramon/WaterLab/tank/tank_water_4d.gd")
const KoiSchool := preload("res://ramon/WaterLab/life/koi_school_4d.gd")
const Reef := preload("res://ramon/WaterLab/life/reef_4d.gd")
const Eel := preload("res://ramon/WaterLab/life/eel_4d.gd")
const Crab := preload("res://ramon/WaterLab/life/crab_4d.gd")
const Weed := preload("res://ramon/WaterLab/life/weed_4d.gd")
const Bubbles := preload("res://ramon/WaterLab/life/bubbles_4d.gd")
const Dunes := preload("res://ramon/WaterLab/life/dunes_4d.gd")
const Snow := preload("res://ramon/WaterLab/life/snow_4d.gd")

const GENERATED := "tank_generated"

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
## The water: x along the glass, y its depth, z front to back, W. Ramon, 9 Oct: "roughly 8 m wide by
## 4 m high, filling the entire back space"; wider here, as the back wall is. 7 m DEEP IN W: from the
## turning spot in front of the glass a slice turned 25 degrees cuts the back of the tank 3 m off
## the level one; 3.2 m and the whole tank left the slice at 30 degrees (the frames of 9 Oct).
@export var water_size: Vector4 = Vector4(14.0, 4.8, 3.2, 7.0):
	set(v):
		water_size = v
		_later()
@export_range(0.4, 3.0, 0.05) var stand_height: float = 1.15:
	set(v):
		stand_height = v
		_later()
## How far the stand reaches past the tank's glass all round.
@export_range(0.0, 1.5, 0.05) var stand_margin: float = 0.45:
	set(v):
		stand_margin = v
		_later()
@export_range(0.04, 0.3, 0.01) var frame_bar: float = 0.12:
	set(v):
		frame_bar = v
		_later()
## Air between the water's surface and the hood.
@export_range(0.1, 1.0, 0.05) var air_gap: float = 0.38:
	set(v):
		air_gap = v
		_later()
@export_range(0.1, 1.0, 0.02) var hood_height: float = 0.42:
	set(v):
		hood_height = v
		_later()
## The sand's depth above the tank's glass floor.
@export_range(0.05, 0.6, 0.01) var sand_depth: float = 0.26:
	set(v):
		sand_depth = v
		_later()
@export_range(0, 40) var koi_count: int = 16

var water: Node4D
var life: Node4D
var koi: Node4D
var reef: Node4D
var eel: Node4D
var crab: Node4D
var dunes: Node4D
## The contents turned through W (in the x-W plane, along the tank, so nothing turns out through the
## glass) and slid through W, by the room's gizmo (Ramon: "W rotate whats in the fish tank but not the
## rest"). The glass, the frame, the stand and the water stay as they are.
var contents_turn: float = 0.0
var contents_slide: float = 0.0
var _queued: bool = false


func _ready() -> void:
	rebuild()


func _later() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


## The middle of the water, in this node's frame.
func water_centre() -> Vector4:
	return Vector4(0.0, stand_height + glass_floor() + water_size.y * 0.5, 0.0, 0.0)


func glass_floor() -> float:
	return 0.06


func half_extents() -> Vector4:
	return water_size * 0.5


## The top of the hood, from the floor.
func top() -> float:
	return water_centre().y + water_size.y * 0.5 + air_gap + hood_height


func rebuild() -> void:
	for c in get_children():
		if c.has_meta(GENERATED):
			remove_child(c)
			c.queue_free()
	water = null
	life = null
	koi = null
	_build_stand()
	_build_frame()
	_build_inside()
	if Engine.is_editor_hint():
		return
	_build_water()
	_build_life()


func _mark(n: Node) -> Node:
	n.set_meta(GENERATED, true)
	return n


func _box(parent: Node, nm: String, centre: Vector4, size: Vector4, mat: Material4D) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(size)
	m.position = centre
	m.material_override = mat
	parent.add_child(m)
	return m


## The stand: the kit pedestal's parts, long instead of square.
func _build_stand() -> void:
	var holder := Node4D.new()
	holder.name = "Stand"
	add_child(_mark(holder))
	# 2 cm short of a wall it is set against: flush, its end and the wall's face fought for the pixels.
	var hx: float = water_size.x * 0.5 + frame_bar + stand_margin - 0.02
	var hz: float = water_size.z * 0.5 + frame_bar + stand_margin - 0.02
	var wd: float = Build.W_DEPTH
	var h: float = stand_height
	var body_top: float = h - Pedestal.LIP - Pedestal.BAND
	var ph: float = body_top - Pedestal.FOOT
	var dark: Color = Style.pick(Style.PLINTH) * 0.7
	dark.a = 1.0
	_box(holder, "Foot", Vector4(0, Pedestal.FOOT * 0.5, 0, 0), Vector4((hx - 0.13) * 2.0, Pedestal.FOOT, (hz - 0.13) * 2.0, wd), Mats.flat(dark))
	var body_size := Vector4((hx - 0.04) * 2.0, ph, (hz - 0.04) * 2.0, wd)
	var body_at := Vector4(0, Pedestal.FOOT + ph * 0.5, 0, 0)
	_box(holder, "Body", body_at, body_size, LabGrid.material("kit_metal", body_size, global_position + body_at if is_inside_tree() else body_at))
	_box(holder, "Band", Vector4(0, body_top + Pedestal.BAND * 0.5, 0, 0), Vector4((hx - 0.11) * 2.0, Pedestal.BAND, (hz - 0.11) * 2.0, wd), Mats.flat(dark))
	_box(holder, "Lip", Vector4(0, h - Pedestal.LIP * 0.5, 0, 0), Vector4(hx * 2.0, Pedestal.LIP, hz * 2.0, wd), Mats.flat(Style.lip()))
	# A thin light line along the stand's front under the lip, the kit's cyan.
	_box(holder, "Glow", Vector4(0, body_top - 0.06, hz - 0.035, 0), Vector4((hx - 0.3) * 2.0, 0.035, 0.02, wd), Mats.glow(Color(0.40, 0.86, 1.0), 1.2))
	# One solid for the stand and the tank on it: nothing walks into the water.
	var body := StaticBody4D.new()
	body.name = "Solid"
	var t: float = top()
	body.position = Vector4(0, t * 0.5, 0, 0)
	var shape := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = Vector4(hx * 2.0, t, hz * 2.0, wd)
	shape.shape = bs
	body.add_child(shape)
	holder.add_child(body)


## The tank's frame: posts at the four corners, rims round the top and the bottom, the hood.
func _build_frame() -> void:
	var holder := Node4D.new()
	holder.name = "Frame"
	add_child(_mark(holder))
	var c: Vector4 = water_centre()
	var he: Vector4 = half_extents()
	var b: float = frame_bar
	var wd: float = water_size.w + b * 2.0
	var metal: Material4D = Mats.flat(Color(0.17, 0.18, 0.21))
	var y0: float = stand_height
	var y1: float = c.y + he.y + air_gap
	var px: float = he.x + b * 0.5
	var pz: float = he.z + b * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(holder, "Post%d%d" % [int(sx), int(sz)], Vector4(sx * px, (y0 + y1) * 0.5, sz * pz, 0), Vector4(b, y1 - y0, b, wd), metal)
	for y in [y0 + glass_floor() * 0.5, y1 - b * 0.5]:
		var nm: String = "Base" if y < c.y else "Rim"
		for sz in [-1.0, 1.0]:
			_box(holder, "%sX%d" % [nm, int(sz)], Vector4(0, y, sz * pz, 0), Vector4(px * 2.0 + b, b if nm == "Rim" else glass_floor() + 0.04, b, wd), metal)
		for sx in [-1.0, 1.0]:
			_box(holder, "%sZ%d" % [nm, int(sx)], Vector4(sx * px, y, 0, 0), Vector4(b, b if nm == "Rim" else glass_floor() + 0.04, pz * 2.0 + b, wd), metal)
	# The glass floor: dark, under the sand.
	_box(holder, "GlassFloor", Vector4(0, y0 + glass_floor() * 0.5, 0, 0), Vector4(he.x * 2.0, glass_floor(), he.z * 2.0, water_size.w), Mats.flat(Color(0.08, 0.10, 0.12)))
	# The hood, with its light strip under the front edge.
	var hood_at := Vector4(0, y1 + hood_height * 0.5, 0, 0)
	_box(holder, "Hood", hood_at, Vector4(px * 2.0 + b + 0.12, hood_height, pz * 2.0 + b + 0.12, wd), Mats.flat(Color(0.11, 0.12, 0.14)))
	_box(holder, "HoodLip", Vector4(0, y1 + 0.03, pz + b * 0.5 + 0.04, 0), Vector4(px * 2.0 + b + 0.1, 0.06, 0.04, wd), metal)
	_box(holder, "HoodLight", Vector4(0, y1 - 0.01, pz - 0.25, 0), Vector4(px * 2.0 - 0.6, 0.03, 0.18, water_size.w), Mats.glow(Color(0.82, 0.93, 1.0), 1.6))


## Inside: the backdrop and the sand.
func _build_inside() -> void:
	var holder := Node4D.new()
	holder.name = "Inside"
	add_child(_mark(holder))
	var c: Vector4 = water_centre()
	var he: Vector4 = half_extents()
	_box(holder, "Backdrop", Vector4(0, c.y, -he.z + 0.03, 0), Vector4(he.x * 2.0, he.y * 2.0, 0.06, water_size.w), Mats.flat(Color(0.05, 0.11, 0.17)))
	var sand := Color(0.50, 0.44, 0.35)
	_box(holder, "Sand", Vector4(0, c.y - he.y + sand_depth * 0.5, 0, 0), Vector4(he.x * 2.0, sand_depth, he.z * 2.0, water_size.w), Mats.flat(sand))
	# A low bank of sand rising toward the back, so the bed is not a flat shelf.
	# The hills on it are the dunes (life/dunes_4d.gd), part of what is in the tank.


func _build_water() -> void:
	water = Node4D.new()
	water.name = "Water"
	water.set_script(WaterScript)
	water.position = water_centre()
	water.set("half_extents", half_extents())
	add_child(_mark(water))


func _build_life() -> void:
	life = Node4D.new()
	life.name = "Life"
	life.position = water_centre()
	add_child(_mark(life))
	var he: Vector4 = half_extents()
	var floor_y: float = -he.y + sand_depth
	# The dunes first: everything stands on them. Then the stones and corals: the swimmers go round
	# them, and the eel lives under them.
	dunes = _life_node("Dunes", Dunes, he, floor_y)
	reef = Node4D.new()
	reef.name = "Reef"
	reef.set_script(Reef)
	reef.set("half_extents", he)
	reef.set("floor_y", floor_y)
	reef.set("ground", dunes)
	life.add_child(reef)
	var obstacles: Array = reef.get("obstacles")
	for scr in [[Weed, "Weed"], [Bubbles, "Bubbles"], [Snow, "Snow"]]:
		var n: Node4D = Node4D.new()
		n.name = String(scr[1])
		n.set_script(scr[0])
		n.set("half_extents", he)
		n.set("floor_y", floor_y)
		if n.get("ground") != null or scr[1] == "Weed":
			n.set("ground", dunes)
		life.add_child(n)
	eel = Node4D.new()
	eel.name = "Eel"
	eel.set_script(Eel)
	eel.set("half_extents", he)
	eel.set("floor_y", floor_y)
	eel.set("cave_mouth", reef.get("cave_mouth"))
	eel.set("cave_out", reef.get("cave_out"))
	eel.set("obstacles", obstacles)
	eel.set("ground", dunes)
	life.add_child(eel)
	crab = Node4D.new()
	crab.name = "Crab"
	crab.set_script(Crab)
	crab.set("half_extents", he)
	crab.set("floor_y", floor_y)
	crab.set("ground", dunes)
	life.add_child(crab)
	koi = Node4D.new()
	koi.name = "Koi"
	koi.set_script(KoiSchool)
	koi.set("count", koi_count)
	koi.set("half_extents", he)
	koi.set("floor_height", sand_depth + 0.12)
	koi.set("obstacles", obstacles)
	koi.set("ground", dunes)
	koi.set("arches", reef.get("arches"))
	life.add_child(koi)
	set_contents(contents_turn, contents_slide)


## The contents turned through W by `turn` (radians, x-W plane) and slid `slide` metres along W.
func set_contents(turn: float, slide: float) -> void:
	contents_turn = clampf(turn, deg_to_rad(-75.0), deg_to_rad(75.0))
	contents_slide = clampf(slide, -water_size.w * 0.45, water_size.w * 0.45)
	if life != null:
		life.basis = Basis4D.from_xw(contents_turn)
		life.position = water_centre() + Vector4(0.0, 0.0, 0.0, contents_slide)


func turn_contents(d: float) -> void:
	set_contents(contents_turn + d, contents_slide)


func slide_contents(d: float) -> void:
	set_contents(contents_turn, contents_slide + d)


func _life_node(nm: String, script: Script, he: Vector4, floor_y: float) -> Node4D:
	var n := Node4D.new()
	n.name = nm
	n.set_script(script)
	n.set("half_extents", he)
	n.set("floor_y", floor_y)
	life.add_child(n)
	return n


## Each frame: you, in the water's frame, for the koi that come to the glass.
func set_viewer(world_point: Vector4) -> void:
	if koi == null or life == null:
		return
	koi.set("viewer", life.global_basis.inverse() * (world_point - life.global_position))
