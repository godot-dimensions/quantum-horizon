@tool
extends Node4D

## WATER LAB: the sci-fi door, shared by the tank room and the sea (it was seascape_4d.gd's
## _build_door, 8 Oct; Ramon: "a scifi door on the backside"). It stands on this node's floor, its
## opening across x (`width` wide, `height` tall), facing +Z.
##
##   a gunmetal frame (two pillars and a lintel, the top corners chamfered), light strips round the
##   opening and a status light over it, two dark leaves meeting in a lit seam, and behind them
##   either a pale bulkhead plate (`plate`, standing free, the sea's) or nothing (in a wall's
##   doorway, the room's);
##   `light_behind`: a bright panel behind the leaves, so an opened door shows light, not the void.
##
## THE PLAIN STYLE (`style` "plain"; Ramon, 9 Oct: "just put a gray door mechanism in there. So keep it
## minimalist ... just the doors that slide. Make them slide within the white opening, and maybe
## remove the cyan line in the middle, and just make it a little lighter gray line in the middle ...
## when the door opens ... this kind of holographic blue doorway being visible", the Voxel Lab's):
##   no frame, no strips, no status light: two light grey leaves filling the opening, a lighter grey
##   line where they meet, sliding apart into the wall; behind them the Voxel Lab's hologram doorway
##   (VoxelLab/room/vl_shimmer_4d.gd: two dithered sheets of the grid shader's hologram mode, bands
##   drifting up them, a lit line down each side and across the top), showing as the door opens.
##
## IN PLAY: `open` (0 shut, 1 open) slides the leaves apart. With `auto_open` the door opens as
## someone comes within `open_distance` of its front and shuts behind them. With `exit_to` set, a
## step into the opening (`inside(p)`) is what the room asks about to send you through it.
## Everything is `w_depth` deep in W.
##
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/WaterLab/carried/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/WaterLab/carried/LabKit/lab_grid.gd")
const GENERATED := "door_generated"

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
## "scifi" (the frame, strips and dark leaves) or "plain" (grey leaves and the hologram doorway).
@export_enum("scifi", "plain") var style: String = "scifi":
	set(v):
		style = v
		_later()
@export var width: float = 3.2:
	set(v):
		width = v
		_later()
@export var height: float = 3.4:
	set(v):
		height = v
		_later()
@export var w_depth: float = 40.0:
	set(v):
		w_depth = v
		_later()
## A bulkhead plate behind it (a door standing free), and its solid.
@export var plate: bool = false:
	set(v):
		plate = v
		_later()
@export var light_behind: bool = true:
	set(v):
		light_behind = v
		_later()
@export_range(0.0, 1.0, 0.01) var open: float = 0.0:
	set(v):
		open = clampf(v, 0.0, 1.0)
		_place_leaves()
@export var auto_open: bool = false
@export var open_distance: float = 4.0
## A solid behind the leaves, so you cannot walk through: the room sends you on before you reach it.
@export var blocks: bool = true:
	set(v):
		blocks = v
		_later()

var _leaves: Array = []
var _queued: bool = false
var _want: float = 0.0
## The hologram sheets' cross-section materials and their full strengths (the plain style).
var _holo: Array = []


func _ready() -> void:
	rebuild()
	_want = open


func _later() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func rebuild() -> void:
	for c in get_children():
		if c.has_meta(GENERATED):
			remove_child(c)
			c.queue_free()
	_leaves = []
	_holo = []
	if style == "plain":
		_build_plain()
		_place_leaves()
		return
	var frame := Color(0.20, 0.22, 0.26)
	var plate_c := Color(0.78, 0.79, 0.81)
	var leaf := Color(0.13, 0.15, 0.19)
	var glow: TetraMaterial4D = Mats.glow(Color(0.40, 0.86, 1.0), 1.4)
	var h: float = height
	var wd: float = w_depth
	var hw: float = width * 0.5
	if plate:
		_box("Plate", Vector4(0.0, (h + 0.9) * 0.5, -0.55, 0.0), Vector4(width + 2.0, h + 0.9, 0.2, wd), _mat(plate_c))
	for s in [-1.0, 1.0]:
		_box("Pillar%d" % int(s), Vector4(s * (hw + 0.28), (h + 0.5) * 0.5, -0.2, 0.0), Vector4(0.56, h + 0.5, 0.5, wd), _mat(frame))
		var c: MeshInstance4D = _box("Chamfer%d" % int(s), Vector4(s * hw, h, -0.2, 0.0), Vector4(0.5, 0.5, 0.5, wd), _mat(frame))
		c.basis = Basis4D.from_xy(PI * 0.25)
		_box("Strip%d" % int(s), Vector4(s * (hw - 0.02), (h - 0.3) * 0.5, 0.08, 0.0), Vector4(0.06, h - 0.3, 0.06, wd), glow)
	_box("Lintel", Vector4(0.0, h + 0.3, -0.2, 0.0), Vector4(width + 1.12, 0.6, 0.5, wd), _mat(frame))
	_box("StripTop", Vector4(0.0, h - 0.05, 0.08, 0.0), Vector4(width - 0.6, 0.06, 0.06, wd), glow)
	_box("StatusLight", Vector4(0.0, h + 0.32, 0.08, 0.0), Vector4(minf(1.2, width * 0.3), 0.14, 0.06, wd), glow)
	for s in [-1.0, 1.0]:
		var l := Node4D.new()
		l.name = "Leaf%d" % int(s)
		l.set_meta(GENERATED, true)
		add_child(l)
		_box_in(l, "Panel", Vector4(0.0, h * 0.5, 0.0, 0.0), Vector4(hw - 0.04, h, 0.14, wd), _mat(leaf))
		_box_in(l, "Band", Vector4(0.0, h * 0.62, 0.08, 0.0), Vector4(hw - 0.5, 0.08, 0.04, wd), _mat(frame))
		_box_in(l, "Edge", Vector4(-s * (hw * 0.5 - 0.04), h * 0.5, 0.09, 0.0), Vector4(0.05, h - 0.2, 0.05, wd), glow)
		l.set_meta("side", s)
		_leaves.append(l)
	if light_behind:
		_box("Light", Vector4(0.0, h * 0.5, -0.45, 0.0), Vector4(width, h, 0.06, wd), Mats.glow(Color(0.86, 0.95, 1.0), 2.2))
	if blocks:
		var body := StaticBody4D.new()
		body.name = "Block"
		body.position = Vector4(0.0, (h + 0.9) * 0.5, -0.35 if not plate else -0.35, 0.0)
		var shape := CollisionShape4D.new()
		var b := BoxShape4D.new()
		b.size = Vector4(width + (2.0 if plate else 0.6), h + 0.9, 0.6, wd)
		shape.shape = b
		body.add_child(shape)
		body.set_meta(GENERATED, true)
		add_child(body)
	_place_leaves()


## The plain door: grey leaves in the opening, the hologram behind them, a block behind that.
func _build_plain() -> void:
	var h: float = height
	var wd: float = w_depth
	var hw: float = width * 0.5
	var grey := Color(0.70, 0.72, 0.75)
	var seam := Color(0.86, 0.87, 0.89)
	for s in [-1.0, 1.0]:
		var l := Node4D.new()
		l.name = "Leaf%d" % int(s)
		l.set_meta(GENERATED, true)
		add_child(l)
		_box_in(l, "Panel", Vector4(0.0, h * 0.5, 0.0, 0.0), Vector4(hw, h, 0.1, wd), _mat(grey))
		# The meeting line, a lighter grey, on the edge toward the middle.
		_box_in(l, "Seam", Vector4(-s * (hw * 0.5 - 0.02), h * 0.5, 0.055, 0.0), Vector4(0.04, h - 0.02, 0.012, wd), _mat(seam))
		l.set_meta("side", s)
		_leaves.append(l)
	# The hologram doorway behind the leaves.
	var col := Color(0.32, 0.66, 1.0)
	for i in 2:
		var size := Vector4(width - 0.08, h - 0.04, 0.03, wd)
		var sheet: MeshInstance4D = _box("Holo%d" % i, Vector4(0.0, h * 0.5, -0.22 - 0.12 * float(i), 0.0), size, null)
		var m: TetraMaterial4D = LabGrid.material("kit_code_blue", size, Vector4.ZERO)
		var cs: ShaderMaterial = m.get_cross_section_material_3d()
		cs.set_shader_parameter("holo_on", 1.0)
		cs.set_shader_parameter("holo_base", 0.0)
		cs.set_shader_parameter("holo_falloff", 0.7 if i == 0 else 1.1)
		cs.set_shader_parameter("holo_color", col if i == 0 else col.lightened(0.25))
		cs.set_shader_parameter("holo_glow", 0.9)
		cs.set_shader_parameter("holo_scan", 0.7)
		cs.set_shader_parameter("holo_scan_density", 1.4 + 0.5 * float(i))
		cs.set_shader_parameter("holo_scan_speed", 0.42 + 0.15 * float(i))
		cs.set_shader_parameter("holo_fine", 1.0)
		sheet.material_override = m
		sheet.visible = false
		_holo.append([sheet, cs, 0.92 if i == 0 else 0.7])
	var edge_col := Color(0.70, 0.88, 1.0)
	for side in [-1.0, 1.0]:
		var edge: MeshInstance4D = _box("HoloEdge", Vector4(side * (hw - 0.02), h * 0.5, -0.28, 0.0), Vector4(0.035, h, 0.06, wd), Mats.glow(edge_col, 1.4))
		_holo.append([edge, null, 0.0])
	var top: MeshInstance4D = _box("HoloTop", Vector4(0.0, h - 0.02, -0.28, 0.0), Vector4(width, 0.035, 0.06, wd), Mats.glow(edge_col, 1.4))
	_holo.append([top, null, 0.0])
	if blocks:
		var body := StaticBody4D.new()
		body.name = "Block"
		body.position = Vector4(0.0, h * 0.5, -0.65, 0.0)
		var shape := CollisionShape4D.new()
		var b := BoxShape4D.new()
		b.size = Vector4(width + 0.6, h, 0.4, wd)
		shape.shape = b
		body.add_child(shape)
		body.set_meta(GENERATED, true)
		add_child(body)


func _mat(c: Color) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_color = c
	return m


func _box(nm: String, at: Vector4, size: Vector4, mat: Material4D) -> MeshInstance4D:
	var m: MeshInstance4D = _box_in(self, nm, at, size, mat)
	m.set_meta(GENERATED, true)
	return m


func _box_in(parent: Node, nm: String, at: Vector4, size: Vector4, mat: Material4D) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(size)
	m.position = at
	m.material_override = mat
	parent.add_child(m)
	return m


## The leaves at `open`: shut they meet in the middle, open they slide into the pillars.
func _place_leaves() -> void:
	var hw: float = width * 0.5
	var k: float = smoothstep(0.0, 1.0, open)
	for l in _leaves:
		if not is_instance_valid(l):
			continue
		var s: float = float((l as Node4D).get_meta("side", 1.0))
		if style == "plain":
			# Into the wall on each side, all the way.
			(l as Node4D).position = Vector4(s * (hw * 0.5 + k * (hw + 0.05)), 0.0, -0.1, 0.0)
		else:
			(l as Node4D).position = Vector4(s * (hw * 0.5 + 0.02 + k * (hw * 0.5 + 0.1)), 0.0, -0.12, 0.0)
	# The hologram shows as the door opens.
	for hs in _holo:
		var node: MeshInstance4D = hs[0]
		if not is_instance_valid(node):
			continue
		node.visible = k > 0.02
		if hs[1] != null:
			(hs[1] as ShaderMaterial).set_shader_parameter("holo_base", float(hs[2]) * k)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not auto_open:
		return
	if not is_equal_approx(open, _want):
		open = move_toward(open, _want, delta * 1.6)


## Called by the room with where you are: opens as you come near its front, shuts as you go.
func notice(p: Vector4) -> void:
	if not auto_open:
		return
	var local: Vector4 = global_basis.inverse() * (p - global_position)
	_want = 1.0 if (local.z > -0.3 and local.z < open_distance and absf(local.x) < width * 0.5 + 1.5) else 0.0


## Whether `p` (the world) has stepped into the opening, from the front.
func inside(p: Vector4) -> bool:
	var local: Vector4 = global_basis.inverse() * (p - global_position)
	return open > 0.6 and absf(local.x) < width * 0.5 and local.z < 0.75 and local.z > -0.6


## A basis turning +Z to face `dir` (x, z) on the floor.
static func facing(dir: Vector2) -> Projection:
	var want: Vector2 = dir.normalized()
	for s in [1.0, -1.0]:
		var b: Projection = Basis4D.from_zx(s * atan2(want.x, want.y))
		var z: Vector4 = b * Vector4(0, 0, 1, 0)
		if Vector2(z.x, z.z).distance_to(want) < 0.01:
			return b
	return Projection.IDENTITY
