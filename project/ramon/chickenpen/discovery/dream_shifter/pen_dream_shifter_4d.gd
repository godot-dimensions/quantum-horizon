@tool
extends Node4D

## THE DREAM SHIFTER (9 Oct 2026, Ramon's onboarding brief for the dev and art looks; follow_up/pen_dream_shifter.md).
## "a short, stumpy Greek-style pillar, about neck height, with a small floating 24-cell hovering above it ... the
## pillar should be connected to a path but very very close to the main path, impossible to miss."
##
## WHERE: halfway down the first road there is, from the start to Trym's house, on the right-hand side as you walk it,
## at the end of a two-metre spur of path (PenLayout/paths/pen_b.tres, node 25 on the road and 24 at the pillar). The
## first objective is "Follow the path to Trym's house", so nobody can start the game without passing within three
## metres of it, ten seconds in, and from the start it stands in plain view down the road.
##
## WHAT IT IS: a column in marble (a square step, a round base, a shaft that swells a little, a flared capital and a
## square top), round through W as it is across (the loft builder's sections are balls through X, Z and W), and over
## it a 24-cell in crystal. The 24-cell turns slowly through W as well as round, so its slice is never the same shape
## twice: an octahedron, then a cuboctahedron, then something in between. That is the point of it: the one object in
## the valley whose look you cannot pin down. Inside it a smaller one turns the other way; three little 16-cells orbit.
## It wakes when you come near (brighter, faster), and flares when it shifts the world
## (discovery/dream_shifter/pen_look_guide_4d.gd does the shift; this only shows it).
##
## THE LOOKS: the crystal is the Look's own (_look_own), so it is the same crystal in both; the pillar is a landmark
## (orange in the dev look: "DreamShifter" is in the Look's orange_units).
##
## THE STONE ALTAR (10 Oct 2026, Ramon's walkthrough items 30-32: "The current design reminds me too much of 4D Golf ...
## ancient technology, tribal / mystical engineering, rustic magical machinery ... Laputa-style ancient tech ... a
## stone altar pedestal ... a solid base, a main upper slab or block supporting the orb, simple stacked-stone logic ...
## two smaller flanking pillars or stones on each side, then one smaller set beyond those ... two tapering arms
## extending outward from the center ... rustic, blocky, slightly gothic or runic ... Do not overdecorate it."). The
## pen's Dream Shifter is style "altar" now; "unit" is his Alternative A (a simple sci-fi cylinder, for comparison,
## World/DreamShifterAltA); "column" is the 9 Oct Greek column, kept in the script for going back.
## The altar: a low base slab, a stacked block with a cap slab, a row of thin glowing runes on its front, and two arms of
## standing stones curving out to either side toward the road, each smaller than the last; one more stone each side
## ana and kata, out of the farm's slice (step or turn and the altar is a little bigger than it looked).
##
## THE TEMPLE PEDESTAL (10 Oct, later, Ramon with a reference picture of a carved square stone pedestal: "give the
## toggle entity a pedestal more like the ref, but without that weird xtra bottom. then a thick stone circle slab it
## stands on. and 2 small pillar units next to it"). Style "temple", the pen's now: a thick round slab; on it the
## reference's pedestal from its wide sloped skirt up (the skirt, a base block, a square shaft with a raised frame and
## a bronze boss on its front panel, a band, a capital, a top slab), the crystal over it, on a thin round plaque; and a
## small pillar of the same stone either side. Square parts are lofted with square sections (round
## through W as across, as everything here), so the steps and the skirt's slope are one mesh.
##
## Built when it loads (and in the editor, to place it), never saved into the scene. Move or turn this node to move it;
## its front (+z) faces the road. NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/chickenpen/scripts/loft_builder_4d.gd")
const CELL24 := "res://models/primitives/platonic/24_cell/24_cell.g4b"
const CrystalShader := preload("res://ramon/chickenpen/discovery/dream_shifter/dream_crystal.gdshader")

@export var player_path: NodePath = ^"../../Player"
## "altar" (the stone altar, the pen's since 10 Oct), "unit" (Alternative A, simple sci-fi), "column" (the 9 Oct column).
@export_enum("temple", "altar", "unit", "column") var style: String = "temple":
	set(v):
		style = v
		_later()
@export var stone: Color = Color(0.53, 0.51, 0.47)
@export var stone_dark: Color = Color(0.40, 0.38, 0.35)
@export var rune: Color = Color(0.55, 0.85, 1.0)
@export var metal: Color = Color(0.30, 0.32, 0.35)
## The crystal's centre above the ground, and its size (the 24-cell model scaled by this).
@export_range(1.0, 3.5, 0.05, "suffix:m") var orb_height: float = 1.92:
	set(v):
		orb_height = v
		_later()
@export_range(0.1, 1.0, 0.01) var orb_scale: float = 0.38:
	set(v):
		orb_scale = v
		_later()
@export var marble: Color = Color(0.86, 0.84, 0.78)
@export var marble_shadow: Color = Color(0.70, 0.68, 0.63)
@export var core_colour: Color = Color(0.20, 0.34, 0.95)
@export var rim_colour: Color = Color(0.72, 0.96, 1.0)
@export var light_colour: Color = Color(0.55, 0.80, 1.0)
## How near (on the ground) it starts to wake, and how near it is fully awake.
@export_range(2.0, 20.0, 0.5, "suffix:m") var wake_range: float = 9.0
@export_range(1.0, 10.0, 0.5, "suffix:m") var awake_range: float = 3.5

## The column's height to the top of its capital.
const PILLAR_H := 1.36

var _player: Node4D
var _orb: Node4D
var _cell: MeshInstance4D
var _core: MeshInstance4D
var _shards: Array[Node4D] = []
var _cell_mat: ShaderMaterial
var _core_mat: ShaderMaterial
var _light: OmniLight4D
var _anchor: Node4D
var _t: float = 0.0
var _awake: float = 0.0
var _flare: float = 0.0
var _flare_len: float = 1.0
var _band: float = 0.0
## Held fully awake (while it talks and shifts), whatever the distance.
var hold_awake: bool = false


func _later() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()
	if not Engine.is_editor_hint():
		_player = get_node_or_null(player_path) as Node4D
		_out_of_projection()


## Out of the projection (P), which counts every mesh twice against the engine's instance limit: the crystal's core and
## its orbiting shards always, and everything of the comparison unit (style "unit", temporary).
func _out_of_projection() -> void:
	for mi in find_children("*", "MeshInstance4D", true, false):
		var n: String = String(mi.name)
		if style == "unit" or n in ["Core", "Shard", "Runes"]:
			mi.set("allow_projection", false)


func rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"_ds_part"):
			remove_child(child)
			child.free()
	_shards.clear()
	_light = null
	match style:
		"temple":
			_temple()
		"altar":
			_altar()
		"unit":
			_unit()
		_:
			_pillar()
			_solid()
	_crystal()


func _part(node: Node, parent: Node = null) -> void:
	if parent == null:
		node.set_meta(&"_ds_part", true)
		add_child(node)
	else:
		parent.add_child(node)


func _flat(colour: Color) -> TetraMaterial4D:
	var mat := TetraMaterial4D.new()
	mat.albedo_color = colour
	return mat


## The column: two square steps, a round base (a torus, a hollow, a torus), the shaft with a little swell, a ring at
## its neck, the flared echinus and the square abacus on top. Round parts are lofted (sections are balls through X, Z
## and W, so it is as round in W as across); square parts are boxes.
func _pillar() -> void:
	var col := Node4D.new()
	col.name = "Column"
	_part(col)
	var steps := ArrayTetraMesh4D.new()
	for s in [[Vector4(0.0, 0.06, 0.0, 0.0), Vector4(0.96, 0.12, 0.96, 0.96)], [Vector4(0.0, 0.17, 0.0, 0.0), Vector4(0.80, 0.10, 0.80, 0.80)]]:
		var box := BoxTetraMesh4D.new()
		box.size = s[1]
		steps.merge_with(box.to_array_tetra_mesh(), s[0], Projection.IDENTITY)
	var top := BoxTetraMesh4D.new()
	top.size = Vector4(0.72, 0.09, 0.72, 0.72)
	steps.merge_with(top.to_array_tetra_mesh(), Vector4(0.0, PILLAR_H - 0.045, 0.0, 0.0), Projection.IDENTITY)
	_mesh(col, "Steps", steps, _flat(marble_shadow))
	# The round body, bottom to top: [height, radius]. The base's torus and hollow, the shaft swelling a little a third
	# of the way up (entasis) and narrowing to its neck ring, then the echinus flaring out under the abacus.
	var profile: Array = [
		[0.22, 0.31], [0.26, 0.335], [0.30, 0.31], [0.33, 0.27], [0.36, 0.29], [0.40, 0.255],
		[0.62, 0.262], [0.95, 0.248], [1.13, 0.228], [1.15, 0.24], [1.17, 0.226], [1.21, 0.25], [1.27, 0.31], [1.30, 0.34],
	]
	var secs: Array = []
	for p in profile:
		secs.append({"center": Vector4(0.0, float(p[0]), 0.0, 0.0), "radius": float(p[1]), "v_scale": 1.0, "w_scale": 1.0})
	var body: ArrayTetraMesh4D = Loft.build(secs, 5, 12, false, false, false, 1, false)
	if body != null:
		_mesh(col, "Shaft", body, _flat(marble))


## The temple pedestal (see the header). The top slab's top at 1.52 m.
func _temple() -> void:
	var root := Node4D.new()
	root.name = "Temple"
	_part(root)
	# The slab: a thick stone disc, round through W too.
	var slab_secs: Array = []
	# A thin plaque (Ramon, 10 Oct: "thin the bottom ground slab a lot. just a small plaque").
	for p in _flat_capped([[0.0, 1.24], [0.05, 1.26], [0.07, 1.23]]):
		slab_secs.append({"center": Vector4(0.0, float(p[0]), 0.0, 0.0), "radius": float(p[1]), "v_scale": 1.0, "w_scale": 1.0})
	var slab: ArrayTetraMesh4D = Loft.build(slab_secs, 4, 18, false, false, false, 0, false)
	if slab != null:
		_mesh(root, "Slab", slab, _flat(stone_dark))
	_pedestal(root, Vector4(0.0, 0.07, 0.0, 0.0), 1.0, true)
	# The two small pillars, either side on the plaque, a little back.
	for side in [-1.0, 1.0]:
		_pedestal(root, Vector4(side * 0.95, 0.07, -0.2, 0.0), 0.38, false)
	_solid_box(Vector4(0.9, 1.52, 0.9, 0.9), Vector4(0.0, 0.76, 0.0, 0.0))


## [param profile] ([height, radius] pairs) closed flat at both ends: a near-zero section a hair inside each end, so the
## loft's end is a flat disc. (Its own taper_ends closes an end with a cone: the slab came out a dome, the top a point.)
static func _flat_capped(profile: Array) -> Array:
	var out: Array = []
	out.append([float(profile[0][0]), 0.002])
	out.append([float(profile[0][0]) + 0.002, float(profile[0][1])])
	for i in range(1, profile.size() - 1):
		out.append(profile[i])
	out.append([float(profile[-1][0]) - 0.002, float(profile[-1][1])])
	out.append([float(profile[-1][0]), 0.002])
	return out


## One pedestal at [param at] (its foot), [param k] its size (1 the big one): the profile lofted with square sections,
## and on the big one the front panel's frame and its bronze boss. (The corbels under the top slab went on 10 Oct,
## Ramon: "remove the little blocks under the top plaque".)
func _pedestal(root: Node4D, at: Vector4, k: float, main: bool) -> void:
	# [height above the foot, half width], measured off the reference from its skirt up (its "extra bottom" left off):
	# the skirt's thick edge and its slope (10% of the height), the base block (10%), the shaft (53%), the band (6%),
	# the capital (14%), the top slab (7%); widths as a share of the skirt's.
	var profile: Array = [
		[0.0, 0.50], [0.06, 0.50], [0.061, 0.49], [0.145, 0.37], [0.146, 0.36], [0.29, 0.36],
		[0.291, 0.27], [1.06, 0.27], [1.061, 0.31], [1.15, 0.31], [1.151, 0.33], [1.35, 0.33],
		[1.351, 0.42], [1.45, 0.42],
	]
	var secs: Array = []
	for p in _flat_capped(profile):
		secs.append({"center": Vector4(0.0, float(p[0]) * k, 0.0, 0.0), "radius": float(p[1]) * k, "v_scale": 1.0, "w_scale": 1.0, "squareness": 1.0})
	var body: ArrayTetraMesh4D = Loft.build(secs, 4, 16, false, false, false, 0, false)
	var node := Node4D.new()
	node.name = "Pedestal" if main else "SmallPillar"
	root.add_child(node)
	node.position = at
	if body != null:
		_mesh(node, "Body", body, _flat(stone))
	if not main:
		return
	# The front panel's raised frame (two strips and a sill) and the bronze boss at its foot.
	var trim := ArrayTetraMesh4D.new()
	for side in [-1.0, 1.0]:
		_merge_box(trim, Vector4(side * 0.21, 0.67, 0.275, 0.0), Vector4(0.06, 0.70, 0.03, 0.45))
	_merge_box(trim, Vector4(0.0, 0.33, 0.275, 0.0), Vector4(0.48, 0.04, 0.03, 0.45))
	_mesh(node, "Frame", trim, _flat(stone_dark))
	var boss_secs: Array = []
	for i in range(1, 6):
		var th: float = PI * float(i) / 6.0
		boss_secs.append({"center": Vector4(0.0, -cos(th) * 0.075, 0.0, 0.0), "radius": sin(th) * 0.075, "v_scale": 1.0, "w_scale": 1.0})
	var boss_mesh: ArrayTetraMesh4D = Loft.build(boss_secs, 3, 8, true, false, false, 0, false)
	if boss_mesh != null:
		var boss := _mesh(node, "Boss", boss_mesh, _flat(Color(0.70, 0.52, 0.24)))
		boss.position = Vector4(0.08, 0.42, 0.29, 0.0)
	# A carved mark on the panel, lit faintly, as the reference's scroll is carved.
	var runes := ArrayTetraMesh4D.new()
	for st in [[0.0, 0.76, 0.36, 0.0], [-0.06, 0.82, 0.14, 0.8], [0.06, 0.82, 0.14, -0.8], [-0.06, 0.68, 0.14, -0.8], [0.06, 0.68, 0.14, 0.8]]:
		runes.merge_with(_box_mesh(Vector4(0.03, float(st[2]), 0.02, 0.4)), Vector4(float(st[0]) + 0.04, float(st[1]), 0.278, 0.0), Basis4D.from_xy(float(st[3])))
	var glow := MeshInstance4D.new()
	glow.name = "Runes"
	glow.mesh = runes
	glow.material_override = preload("res://ramon/CreationLab/LabKit/lab_materials.gd").glow(rune.darkened(0.25), 1.0)
	glow.set_meta(&"_look_own", true)
	node.add_child(glow)


## The stone altar. Front (+z) to the road. Heights: the cap's top at 1.5 m.
func _altar() -> void:
	var root := Node4D.new()
	root.name = "Altar"
	_part(root)
	var dark := ArrayTetraMesh4D.new()
	var main := ArrayTetraMesh4D.new()
	# The base slab and the step on it (darker), the block, the cap slab (lighter).
	_merge_box(dark, Vector4(0.0, 0.14, 0.0, 0.0), Vector4(1.70, 0.28, 1.45, 1.45))
	_merge_box(dark, Vector4(0.0, 0.34, 0.0, 0.0), Vector4(1.30, 0.12, 1.10, 1.15))
	_merge_box(main, Vector4(0.0, 0.85, 0.0, 0.0), Vector4(0.90, 0.90, 0.78, 0.82))
	_merge_box(main, Vector4(0.0, 1.38, 0.0, 0.0), Vector4(1.22, 0.20, 1.04, 1.06))
	# A raised lip under the cap, a little in from its edge: the stacked-stone line.
	_merge_box(dark, Vector4(0.0, 1.255, 0.0, 0.0), Vector4(1.02, 0.07, 0.88, 0.9))
	# The arms: standing stones out to either side, curving toward the road, each smaller. [angle from front, radius,
	# height, width]
	var arms: Array = [[52.0, 1.75, 1.15, 0.46], [70.0, 2.5, 0.80, 0.38], [84.0, 3.2, 0.50, 0.32]]
	for side in [-1.0, 1.0]:
		for k in arms.size():
			var a: Array = arms[k]
			var ang: float = deg_to_rad(float(a[0])) * side
			var at := Vector4(sin(ang) * float(a[1]), float(a[2]) * 0.5, cos(ang) * float(a[1]), 0.0)
			var turn: Projection = Basis4D.from_zx(-ang + 0.12 * side)
			main.merge_with(_box_mesh(Vector4(float(a[3]), float(a[2]), float(a[3]) * 0.85, float(a[3]))), at, turn)
			# A flat cap stone on the first pair.
			if k == 0:
				dark.merge_with(_box_mesh(Vector4(float(a[3]) * 1.3, 0.10, float(a[3]) * 1.1, float(a[3]) * 1.2)), at + Vector4(0.0, float(a[2]) * 0.5 + 0.05, 0.0, 0.0), turn)
	# One more stone each side, ana and kata, behind the altar: out of the farm's slice.
	for w in [-1.6, 1.6]:
		main.merge_with(_box_mesh(Vector4(0.42, 0.95, 0.38, 0.40)), Vector4(0.0, 0.475, -1.1, w), Projection.IDENTITY)
	_mesh(root, "Stones", main, _flat(stone))
	_mesh(root, "Footing", dark, _flat(stone_dark))
	# Runes: three glyphs cut into the block's front (a stem and its angled branches, the old futhark's way of
	# being carved: no curves), over a line. [x, then strokes: [dx, dy, length, angle]] from the glyph's middle.
	var runes := ArrayTetraMesh4D.new()
	var glyphs: Array = [
		[-0.24, [[0.0, 0.0, 0.30, 0.0], [0.05, 0.06, 0.14, 0.9], [0.05, -0.04, 0.14, 0.9]]],
		[0.0, [[-0.05, 0.0, 0.30, 0.0], [0.05, 0.0, 0.30, 0.0], [0.0, 0.07, 0.16, -0.75]]],
		[0.24, [[0.0, 0.0, 0.30, 0.0], [0.0, 0.0, 0.22, 0.85], [0.0, 0.0, 0.22, -0.85]]],
	]
	for g in glyphs:
		for st in g[1]:
			var c := Vector4(float(g[0]) + float(st[0]), 0.88 + float(st[1]), 0.395, 0.0)
			runes.merge_with(_box_mesh(Vector4(0.035, float(st[2]), 0.02, 0.5)), c, Basis4D.from_xy(float(st[3])))
	_merge_box(runes, Vector4(0.0, 0.66, 0.395, 0.0), Vector4(0.62, 0.025, 0.02, 0.5))
	var glow := MeshInstance4D.new()
	glow.name = "Runes"
	glow.mesh = runes
	glow.material_override = preload("res://ramon/CreationLab/LabKit/lab_materials.gd").glow(rune, 1.0)
	glow.set_meta(&"_look_own", true)
	root.add_child(glow)
	# Colliders: the altar, and each arm stone.
	_solid_box(Vector4(1.5, 1.5, 1.3, 1.3), Vector4(0.0, 0.75, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		for a in arms:
			var ang: float = deg_to_rad(float(a[0])) * side
			_solid_box(Vector4(float(a[3]), float(a[2]), float(a[3]), float(a[3])), Vector4(sin(ang) * float(a[1]), float(a[2]) * 0.5, cos(ang) * float(a[1]), 0.0))


## Alternative A: a simple sci-fi unit. A round base, a plain cylinder with two lit rings, a cap. Top at 1.3 m.
func _unit() -> void:
	var root := Node4D.new()
	root.name = "Unit"
	_part(root)
	var secs: Array = []
	for p in [[0.0, 0.55], [0.10, 0.55], [0.14, 0.42], [1.16, 0.40], [1.22, 0.50], [1.30, 0.50]]:
		secs.append({"center": Vector4(0.0, float(p[0]), 0.0, 0.0), "radius": float(p[1]), "v_scale": 1.0, "w_scale": 1.0})
	var body: ArrayTetraMesh4D = Loft.build(secs, 4, 14, false, false, false, 0, false)
	if body != null:
		_mesh(root, "Body", body, _flat(metal))
	for y in [0.42, 0.88]:
		var ring_secs: Array = []
		for p in [[y - 0.025, 0.415], [y + 0.025, 0.415]]:
			ring_secs.append({"center": Vector4(0.0, float(p[0]), 0.0, 0.0), "radius": float(p[1]), "v_scale": 1.0, "w_scale": 1.0})
		var ring: ArrayTetraMesh4D = Loft.build(ring_secs, 4, 14, false, false, false, 0, false)
		if ring != null:
			var gm := MeshInstance4D.new()
			gm.name = "Ring%d" % int(y * 100.0)
			gm.mesh = ring
			gm.material_override = preload("res://ramon/CreationLab/LabKit/lab_materials.gd").glow(rune, 1.0)
			gm.set_meta(&"_look_own", true)
			root.add_child(gm)
	_solid_box(Vector4(1.0, 1.3, 1.0, 1.0), Vector4(0.0, 0.65, 0.0, 0.0))


static func _box_mesh(size: Vector4) -> ArrayTetraMesh4D:
	var box := BoxTetraMesh4D.new()
	box.size = size
	return box.to_array_tetra_mesh()


static func _merge_box(into: ArrayTetraMesh4D, at: Vector4, size: Vector4) -> void:
	into.merge_with(_box_mesh(size), at, Projection.IDENTITY)


func _solid_box(size: Vector4, at: Vector4) -> void:
	var body := StaticBody4D.new()
	body.name = "Solid"
	_part(body)
	var holder := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	holder.shape = shape
	holder.position = at
	body.add_child(holder)


func _mesh(parent: Node, part: String, mesh: Mesh4D, mat: Material4D) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	return node


## One box for the column, so you walk round it, not through it.
func _solid() -> void:
	var body := StaticBody4D.new()
	body.name = "Solid"
	_part(body)
	var holder := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = Vector4(0.8, PILLAR_H, 0.8, 0.8)
	holder.shape = shape
	holder.position = Vector4(0.0, PILLAR_H * 0.5, 0.0, 0.0)
	body.add_child(holder)


## The crystal: the 24-cell, a smaller one inside turning the other way, three 16-cells in orbit, its light, and the
## point the prompt and the talking hang off.
func _crystal() -> void:
	_orb = Node4D.new()
	_orb.name = "Orb"
	_part(_orb)
	_orb.position = Vector4(0.0, orb_height, 0.0, 0.0)
	# The small parts stay out of the projection (the instance limit); the comparison unit stays out altogether.
	var mesh: Mesh4D = load(CELL24) as Mesh4D
	if mesh == null:
		var fallback := OrthoplexTetraMesh4D.new()
		mesh = fallback
	var cell_mat: TetraMaterial4D = _crystal_material(core_colour, rim_colour)
	_cell_mat = cell_mat.get_cross_section_material_3d()
	_cell = _crystal_mesh("Cell", mesh, orb_scale, cell_mat)
	var core_mat: TetraMaterial4D = _crystal_material(rim_colour, Color(1.0, 1.0, 1.0))
	_core_mat = core_mat.get_cross_section_material_3d()
	_core = _crystal_mesh("Core", mesh, orb_scale * 0.42, core_mat)
	var shard_mesh := OrthoplexTetraMesh4D.new()
	for i in 3:
		var pivot := Node4D.new()
		pivot.name = "Orbit%d" % i
		_orb.add_child(pivot)
		var shard := MeshInstance4D.new()
		shard.name = "Shard"
		shard.mesh = shard_mesh
		shard.material_override = _cell.material_override
		shard.set_meta(&"_look_own", true)
		pivot.add_child(shard)
		shard.position = Vector4(orb_scale * 1.9, 0.0, 0.0, 0.0)
		shard.basis = Basis4D.from_scale_uniform(orb_scale * 0.16)
		_shards.append(pivot)
	# The scene's own Head (under this node, saved with it) is what the prompt and the dialogue box hang off; without
	# one, a point under the crystal.
	_anchor = get_node_or_null(^"Head") as Node4D
	if _anchor == null:
		_anchor = Node4D.new()
		_anchor.name = "TalkAnchor"
		_part(_anchor)
		_anchor.position = Vector4(0.0, orb_height - 0.25, 0.0, 0.0)
	if not Engine.is_editor_hint():
		_light = OmniLight4D.new()
		_light.name = "Glow"
		_light.set("omni_range_meters", 5.0)
		_light.light_color = light_colour
		_light.light_energy = 0.6
		_orb.add_child(_light)


func _crystal_material(core: Color, rim: Color) -> TetraMaterial4D:
	var mat := TetraMaterial4D.new()
	mat.albedo_color = Color.WHITE
	var cs: ShaderMaterial = mat.get_cross_section_material_3d()
	cs.shader = CrystalShader
	cs.set_shader_parameter("core_color", core)
	cs.set_shader_parameter("rim_color", rim)
	cs.set_shader_parameter("energy", 1.0)
	return mat


func _crystal_mesh(part: String, mesh: Mesh4D, s: float, mat: TetraMaterial4D) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = mesh
	node.material_override = mat
	node.set_meta(&"_look_own", true)
	_orb.add_child(node)
	node.basis = Basis4D.from_scale_uniform(s)
	return node


## Where the prompt and the conversation hang (the WorldTag's and the dialogue box's anchor).
func anchor() -> Node4D:
	return _anchor


## The crystal's centre, in the world.
func orb_position() -> Vector4:
	return _orb.global_position if _orb != null else global_position + Vector4(0.0, orb_height, 0.0, 0.0)


## A flash of light and a sweep up through the crystal, [param seconds] long: it shifting the world.
func flare(seconds: float = 1.2) -> void:
	_flare_len = maxf(seconds, 0.1)
	_flare = _flare_len


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _orb == null:
		return
	_t += delta
	var want: float = 0.0
	if hold_awake:
		want = 1.0
	elif _player != null:
		var gap: Vector4 = _player.global_position - global_position
		var d: float = Vector2(gap.x, gap.z).length()
		if absf(gap.w) < 3.0:
			want = 1.0 - smoothstep(awake_range, wake_range, d)
	_awake = move_toward(_awake, want, delta * 1.5)
	var f: float = 0.0
	if _flare > 0.0:
		_flare = maxf(_flare - delta, 0.0)
		var k: float = 1.0 - _flare / _flare_len
		f = sin(PI * k)
		_band = k * 2.0
	else:
		_band = fmod(_band + delta * (0.12 + 0.25 * _awake), 1.0)
	var spin: float = 0.25 + 0.45 * _awake + 2.5 * f
	# Round in three planes at three speeds, two of them into W: its slice keeps changing shape.
	var a: float = _t * spin
	_cell.basis = Basis4D.from_zx(a * 0.7) * Basis4D.from_xw(a * 0.43) * Basis4D.from_wy(a * 0.29) * Basis4D.from_scale_uniform(orb_scale * (1.0 + 0.18 * f))
	_core.basis = Basis4D.from_zx(-a * 1.3) * Basis4D.from_zw(-a * 0.8) * Basis4D.from_scale_uniform(orb_scale * 0.42 * (1.0 + 0.5 * f))
	for i in _shards.size():
		var ph: float = _t * (0.9 + 0.5 * _awake + 3.0 * f) + TAU * float(i) / 3.0
		_shards[i].basis = Basis4D.from_zx(ph) * Basis4D.from_xy(0.35 * sin(_t * 0.7 + float(i))) * Basis4D.from_xw(0.5 * sin(_t * 0.4 + float(i) * 2.0))
	_orb.position = Vector4(0.0, orb_height + sin(_t * 1.3) * 0.05 + 0.08 * f, 0.0, 0.0)
	var energy: float = 0.85 + 0.35 * _awake + 1.4 * f
	_cell_mat.set_shader_parameter("energy", energy)
	_cell_mat.set_shader_parameter("band", _band)
	_core_mat.set_shader_parameter("energy", 1.0 + 0.3 * _awake + 1.0 * f)
	if _light != null:
		_light.light_energy = 0.5 + 1.2 * _awake + 3.0 * f
		_light.set("omni_range_meters", 4.0 + 3.0 * _awake + 6.0 * f)
