@tool
extends Node4D

## THE RANGE, built to Ramon's sheet by measurement (PenLayout/refs/range_views.png; PenLayout/
## PLAN_REF_LOCK.md part D; Ramon, 6 Oct: "you can't shoot the boards its just for illustration. the
## block next to the table will give you a button activation to teleport to the shooting range").
##
## EVERY NUMBER HERE IS MEASURED. Cameras were fitted to the sheet's three views (PenLayout/tools/
## ref_fit.py, PenLayout/RefLock/specs/range_fit.json), and every item placed by putting its point in
## the top view on a plane of known height, its heights from the front view (ref_fit.plane_point).
## Where the views disagree (the boards' heights: the side view draws them half a metre higher) the
## front view's numbers win; the top view decides the plan.
##
## THE FRAME: the origin is where the sheet stands the player, at the front of the yard looking down
## it; the boards are 10.5 m away at -z, the table and the rune stone at the front either side, the
## right-hand fence at +x. The unit is turned in the pen so its front faces the path.
##
## THE PARTS: a grass ground with a trodden sand yard (the ground patch: only on the ref stage; in the
## pen, the pen's own ground and its sand); a curved outcrop of designed-cut stones behind the boards
## and round its corners, grass on its ledges; three round stone boards (dot, diamond, triangle runes)
## in square timber frames on a low bank; a three-rail fence each side (fence tech, posts where the
## sheet has them); the table with a red runner and three rifles; the banner on its post; a barrel;
## the rune stone (the button: pen_rune_stone_4d.gd); field stones along the fences; grass.
##
## Illustration only: nothing here can be shot. Built when it loads (and in the editor).
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const StoneSet := preload("res://ramon/chickenpen/scripts/pen_stone_set_4d.gd")
const CutStone := preload("res://ramon/chickenpen/terrain/cut_stone_4d.gd")
const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const MainGreen := preload("res://ramon/chickenpen/terrain/main_green_4d.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var range_seed: int = 9: set = _set_seed
## The sheet's ground: the sand yard and the fringe of grass round it, and with [member turf_mat] the
## grass patch under it all (the ref stage; in the pen the pen's own ground is the grass, and the
## sand and fringe sit [member ground_lift] above it so they do not fight it).
@export var ground_patch: bool = false: set = _set_patch
@export var turf_mat: bool = true: set = _set_turf
@export_range(0.0, 0.2, 0.005, "suffix:m") var ground_lift: float = 0.0: set = _set_lift
## How deep in W the props are, and the outcrop and the ground.
@export_range(0.4, 4.0, 0.05, "suffix:m") var prop_w: float = 1.4: set = _set_prop_w
@export_range(1.0, 8.0, 0.1, "suffix:m") var rock_w: float = 4.0

@export_group("Look")
## The painted timber, cloth and stone (refs/measure/range_measure.json), set under the ref stage's
## neutral light.
@export var timber: Color = Color(0.47, 0.32, 0.19)
@export var timber_dark: Color = Color(0.34, 0.22, 0.13)
@export var stone: Color = Color(0.72, 0.70, 0.66)
@export var stone_dark: Color = Color(0.30, 0.29, 0.29)
@export var iron: Color = Color(0.22, 0.22, 0.24)
@export var cloth: Color = Color(0.45, 0.13, 0.15)
@export var gold: Color = Color(0.86, 0.64, 0.24)
@export var rune_glow: Color = Color(1.0, 0.70, 0.25)
@export var sand: Color = Color(0.62, 0.44, 0.24)
@export var turf: Color = Color(0.40, 0.46, 0.09)

## The yard, measured (metres, the origin where the sheet stands the player).
## Fences: the post positions (x, z) as the top view has them, front to back.
const FENCE_L := [Vector2(-2.6, -2.64), Vector2(-2.6, -5.01), Vector2(-2.6, -6.44), Vector2(-2.6, -8.13), Vector2(-2.6, -9.77)]
const FENCE_R := [Vector2(3.08, -2.94), Vector2(3.08, -5.15), Vector2(3.08, -7.26), Vector2(3.08, -9.95)]
const FENCE_POST_H := 1.25
const FENCE_RAILS := [0.32, 0.66, 1.0]
## The boards: middle (x, z), its rune's height, its ring's radius; the bank they stand on.
const BOARDS := [[Vector2(-1.75, -10.4), 1.62, 0.52, "dot"], [Vector2(0.18, -10.6), 1.96, 0.68, "diamond"], [Vector2(2.0, -10.4), 1.62, 0.52, "triangle"]]
const BANK := Vector4(0.15, 0.5, -11.0, 0.0)
const BANK_SIZE := Vector3(7.2, 0.5, 3.2)
## The front: the rune stone, the table, the banner, the barrel.
const STONE_AT := Vector4(1.1, 0.0, -0.9, 0.0)
const STONE_SIZE := Vector3(1.15, 0.96, 1.2)
const TABLE_AT := Vector4(-1.72, 0.0, -0.12, 0.0)
const TABLE_SIZE := Vector3(2.2, 0.85, 1.25)
const BANNER_AT := Vector4(-3.3, 0.0, -1.35, 0.0)
const BARREL_AT := Vector4(-3.45, 0.0, -0.55, 0.0)
## The ground: the grass patch's extents, and the sand yard's.
const GRASS_X := Vector2(-4.1, 4.4)
const GRASS_Z := Vector2(-13.4, 1.6)
const SAND_X := Vector2(-2.0, 2.4)
const SAND_Z := Vector2(-10.3, 0.4)

const OWN := &"_rune_range_part"

var _pending: bool = false
var _batches: Dictionary = {}
var _glows: Dictionary = {}
var _body: StaticBody4D
var _stones: Array = []
var _tufts: Array = []
var _rng := RandomNumberGenerator.new()
var _wood: TetraMaterial4D


func _set_seed(v: int) -> void: range_seed = v; _later()
func _set_patch(v: bool) -> void: ground_patch = v; _later()
func _set_turf(v: bool) -> void: turf_mat = v; _later()
func _set_lift(v: float) -> void: ground_lift = v; _later()
func _set_prop_w(v: float) -> void: prop_w = v; _later()


func _ready() -> void:
	rebuild()


func _enter_tree() -> void:
	add_to_group(&"ground_sand")
	add_to_group(MainGreen.GROUP)


## New moss baked, or the main green switched on or off: the outcrop's mossy stones built again.
func main_green_changed(_c: Color, baked: bool) -> void:
	if baked:
		rebuild()


## The yard's sand, painted on the pen's ground (grass/pen_grass_4d.gd, the ground_sand group): the
## sheet's sand down the middle of the yard, between the fences, in place of the boxes that stood for it.
func ground_sand() -> Array:
	var b: Projection = global_basis
	var ax := Vector2(b.x.x, b.x.z).normalized()
	var az := Vector2(b.z.x, b.z.z).normalized()
	var mid := Vector4((SAND_X.x + SAND_X.y) * 0.5, 0.0, (SAND_Z.x + SAND_Z.y) * 0.5, 0.0)
	var c: Vector4 = global_position + b * mid
	return [{"centre": c, "half": Vector2((SAND_X.y - SAND_X.x) * 0.5, (SAND_Z.y - SAND_Z.x) * 0.5), "ax": ax, "az": az, "w_half": prop_w * 0.6}]


func _later() -> void:
	if not is_node_ready() or _pending:
		return
	_pending = true
	rebuild.call_deferred()


func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	_batches.clear()
	_glows.clear()
	_stones = []
	_tufts = []
	_rng.seed = range_seed
	_wood = TetraMaterial4D.new()
	_wood.albedo_color = timber
	_body = StaticBody4D.new()
	_body.name = "Solid"
	_own(_body)
	# The sheet's grass ground and the board bank are boxes, and read as boxes (Ramon, 6 Oct: "remove
	# boxy squares that are supposed to resemble the ground"): left out; the pen's ground is the floor.
	if ground_patch and turf_mat:
		_ground()
	_outcrop()
	for b in BOARDS:
		_board(b[0], float(b[1]), float(b[2]), String(b[3]))
	_fence(FENCE_L, "FenceWest")
	_fence(FENCE_R, "FenceEast")
	_table()
	_banner()
	_barrel()
	_rune_stone()
	_field_stones()
	_flush()


# --- The ground ---------------------------------------------------------------------------------

## The sheet's ground: a grass patch with rounded corners, the sand yard down its middle in patches
## (the painting's yard is trodden sand broken by grass).
func _ground() -> void:
	var cx: float = (GRASS_X.x + GRASS_X.y) * 0.5
	var cz: float = (GRASS_Z.x + GRASS_Z.y) * 0.5
	var sx: float = GRASS_X.y - GRASS_X.x
	var sz: float = GRASS_Z.y - GRASS_Z.x
	var lift := Vector4(0, ground_lift, 0, 0)
	if turf_mat:
		_box(turf, Vector4(sx - 1.2, 0.1, sz, rock_w + 1.0), Vector4(cx, -0.05, cz, 0))
		_box(turf, Vector4(sx, 0.1, sz - 1.2, rock_w + 1.0), Vector4(cx, -0.05, cz, 0))
	# The sand: a long patch, its edges broken by overlapping smaller ones.
	_box(sand, Vector4(SAND_X.y - SAND_X.x - 0.8, 0.11, SAND_Z.y - SAND_Z.x - 0.6, rock_w), Vector4((SAND_X.x + SAND_X.y) * 0.5, -0.04, (SAND_Z.x + SAND_Z.y) * 0.5, 0) + lift)
	for k in 16:
		var z: float = lerpf(SAND_Z.x + 0.4, SAND_Z.y - 0.4, float(k) / 15.0)
		for side in [-1.0, 1.0]:
			var x: float = (SAND_X.x + SAND_X.y) * 0.5 + side * ((SAND_X.y - SAND_X.x) * 0.5 - _rng.randf_range(0.1, 0.7))
			_box(sand, Vector4(_rng.randf_range(0.5, 1.1), 0.11, _rng.randf_range(0.5, 1.0), rock_w), Vector4(x, -0.035, z, 0) + lift, _turn_y(_rng.randf_range(-0.5, 0.5)))
	# The patch's edge: a scalloped fringe of grass clumps all round, as painted.
	var per: int = 64
	for k in per:
		var t: float = float(k) / float(per)
		var p: Vector2
		var len_x: float = GRASS_X.y - GRASS_X.x
		var len_z: float = GRASS_Z.y - GRASS_Z.x
		var d: float = t * 2.0 * (len_x + len_z)
		if d < len_x:
			p = Vector2(GRASS_X.x + d, GRASS_Z.y)
		elif d < len_x + len_z:
			p = Vector2(GRASS_X.y, GRASS_Z.y - (d - len_x))
		elif d < 2.0 * len_x + len_z:
			p = Vector2(GRASS_X.y - (d - len_x - len_z), GRASS_Z.x)
		else:
			p = Vector2(GRASS_X.x, GRASS_Z.x + (d - 2.0 * len_x - len_z))
		p = p.lerp(Vector2(0.15, -6.0), 0.03)
		_tuft(Vector4(p.x, 0.0, p.y, _rng.randf_range(-0.8, 0.8)), _rng.randf_range(1.0, 1.5))
	# Grass patches in the sand, as painted.
	for k in 14:
		var at := Vector4(_rng.randf_range(SAND_X.x + 0.5, SAND_X.y - 0.5), -0.02, _rng.randf_range(SAND_Z.x + 1.0, SAND_Z.y - 1.0), 0) + lift
		_box(turf, Vector4(_rng.randf_range(0.5, 1.2), 0.11, _rng.randf_range(0.4, 0.9), rock_w), at, _turn_y(_rng.randf_range(0.0, PI)))


## The low grassy bank the boards stand on, in front of the outcrop.
func _bank() -> void:
	var c: Vector4 = BANK - Vector4(0, BANK_SIZE.y * 0.5, 0, 0)
	_box(turf, Vector4(BANK_SIZE.x, BANK_SIZE.y, BANK_SIZE.z, rock_w), c)
	_box(turf.darkened(0.1), Vector4(BANK_SIZE.x - 0.6, BANK_SIZE.y + 0.05, BANK_SIZE.z + 0.5, rock_w - 0.2), c - Vector4(0, 0.03, 0, 0))
	_solid(Vector4(BANK_SIZE.x, BANK_SIZE.y, BANK_SIZE.z, rock_w), c)


# --- The outcrop --------------------------------------------------------------------------------

## The curved outcrop behind the boards (a U in the top view, 3 m high in the middle falling to a
## metre and a half at its ends by the fences' back posts): two courses of designed-cut stones on
## an arc, the upper course stepped back, grass on every top.
func _outcrop() -> void:
	# The arc's middle and radii (x half-width, z depth), from the top view: back at z -13.2, the
	# ends at x -3.85 and 4.1 by z -10.
	var mid := Vector2(0.12, -10.0)
	var rx: float = 4.0
	var rz: float = 3.0
	var n: int = 9
	for k in n:
		var t: float = lerpf(PI * 0.06, PI * 0.94, float(k) / float(n - 1))
		var a: float = PI + t
		var p := Vector2(mid.x + cos(a) * rx, mid.y + sin(a) * rz)
		# Height falls off toward the ends, as the front view has it (3.0 middle, 1.5 ends).
		var tall: float = lerpf(1.5, 3.0, sin(t))
		var outward := Vector2(cos(a) * rz, sin(a) * rx).normalized()
		var yaw: float = atan2(-outward.x, -outward.y)
		var base: float = 0.0
		# Lower course: one big stone.
		var h1: float = tall * _rng.randf_range(0.55, 0.65)
		var w1: float = _rng.randf_range(1.2, 1.5)
		_stone(["block", "round", "block"][k % 3], Vector4(p.x, base, p.y, _rng.randf_range(-0.6, 0.6)), Vector3(w1, h1, w1 * 0.85), rock_w * 0.55, yaw + _rng.randf_range(-0.15, 0.15), tall <= 1.9)
		# Upper course: a smaller one set back, where the outcrop is tall enough.
		if tall > 1.9:
			var back: Vector2 = p - outward * 0.45
			var h2: float = tall - h1 + 0.15
			var w2: float = _rng.randf_range(1.0, 1.3)
			_stone(["round", "block", "slab"][k % 3], Vector4(back.x, h1 - 0.15, back.y, _rng.randf_range(-0.6, 0.6)), Vector3(w2, h2, w2 * 0.85), rock_w * 0.5, yaw + _rng.randf_range(-0.2, 0.2), true)
		# A filler behind, so no daylight shows between the stones from the front.
		var behind: Vector2 = p - outward * 1.1
		_stone("round", Vector4(behind.x, 0.0, behind.y, 0), Vector3(1.5, tall * 0.8, 1.2), rock_w * 0.6, yaw)
		_solid(Vector4(1.4, tall, 1.4, rock_w), Vector4(p.x, tall * 0.5, p.y, 0))


# --- The boards ---------------------------------------------------------------------------------

## A round stone board facing the yard (+z) in a square timber frame on legs to the bank: its rings
## (light rim, dark band, light band, dark middle), the rune glowing at its centre, iron plates at the
## frame's corners and a strut behind each post.
func _board(at2: Vector2, rune_y: float, r: float, rune: String) -> void:
	var c := Vector4(at2.x, rune_y, at2.y, 0)
	var t: float = 0.16
	_disc_z(stone, c, r, t)
	_disc_z(stone_dark, c + Vector4(0, 0, t * 0.5, 0), r * 0.83, 0.03)
	_disc_z(stone, c + Vector4(0, 0, t * 0.5 + 0.015, 0), r * 0.68, 0.03)
	_disc_z(stone_dark, c + Vector4(0, 0, t * 0.5 + 0.03, 0), r * 0.42, 0.03)
	var face: Vector4 = c + Vector4(0, 0, t * 0.5 + 0.06, 0)
	match rune:
		"dot":
			_disc_z(rune_glow, face, r * 0.13, 0.03, true)
		"diamond":
			for k in 4:
				var a: float = PI * 0.25 + PI * 0.5 * float(k)
				var m := Vector4(cos(a) * r * 0.17, sin(a) * r * 0.17, 0, 0)
				_box(rune_glow, Vector4(r * 0.26, 0.045, 0.03, prop_w * 0.5), face + m, _turn_z(a + PI * 0.5), true)
			# The cross lines either side (the middle board's crosshair).
			for s in [-1.0, 1.0]:
				_box(rune_glow, Vector4(r * 0.2, 0.03, 0.03, prop_w * 0.5), face + Vector4(s * r * 0.5, 0, 0, 0), Projection.IDENTITY, true)
				_box(rune_glow, Vector4(0.03, r * 0.2, 0.03, prop_w * 0.5), face + Vector4(0, s * r * 0.5, 0, 0), Projection.IDENTITY, true)
		"triangle":
			for k in 3:
				var a: float = PI * 0.5 + TAU * float(k) / 3.0
				var b: float = a + TAU / 3.0
				var p0 := Vector4(cos(a) * r * 0.24, sin(a) * r * 0.24, 0, 0)
				var p1 := Vector4(cos(b) * r * 0.24, sin(b) * r * 0.24, 0, 0)
				var d: Vector4 = p1 - p0
				_box(rune_glow, Vector4(d.length() + 0.04, 0.045, 0.03, prop_w * 0.5), face + (p0 + p1) * 0.5, _turn_z(atan2(d.y, d.x)), true)
	# The frame: two posts from the bank, a beam over and a beam under the ring.
	var ground: float = 0.0
	var half: float = r + 0.12
	for s in [-1.0, 1.0]:
		var post := Vector4(c.x + s * half, 0, c.z - 0.05, 0)
		var top: float = c.y + r + 0.1
		_box(timber_dark, Vector4(0.16, top - ground, 0.16, prop_w), post + Vector4(0, (top + ground) * 0.5, 0, 0))
		# The strut behind (the side view's A-frame leg).
		_strut(timber, post + Vector4(0, c.y + 0.1, -0.08, 0), post + Vector4(0, ground, -0.9, 0), 0.1)
		for y in [c.y + r - 0.02, c.y - r + 0.02]:
			_box(iron, Vector4(0.2, 0.2, 0.05, prop_w + 0.02), Vector4(post.x, y, c.z + 0.04, 0))
	_box(timber, Vector4(2.0 * half + 0.3, 0.16, 0.16, prop_w), Vector4(c.x, c.y + r + 0.06, c.z - 0.05, 0))
	_box(timber, Vector4(2.0 * half + 0.1, 0.14, 0.14, prop_w), Vector4(c.x, c.y - r - 0.06, c.z - 0.05, 0))
	_solid(Vector4(2.0 * half + 0.3, c.y + r - ground, 0.5, prop_w), Vector4(c.x, (c.y + r + ground) * 0.5, c.z, 0))


# --- The fences --------------------------------------------------------------------------------

## A three-rail fence through [param posts] (fence tech: a seed strip stretched in W, a post at each
## measured point, three rails as beams).
func _fence(posts: Array, name: String) -> void:
	var seed := ArrayPolyMesh4D.new()
	var hw: float = prop_w * 0.5
	var lo: Array = []
	var hi: Array = []
	for p in posts:
		var q: Vector2 = p
		lo.append(seed.append_vertex(Vector4(q.x, 0, q.y, -hw)))
		hi.append(seed.append_vertex(Vector4(q.x, 0, q.y, hw)))
	for i in posts.size() - 1:
		var e0: int = seed.append_edge_indices(lo[i], lo[i + 1])
		var e1: int = seed.append_edge_indices(lo[i + 1], hi[i + 1])
		var e2: int = seed.append_edge_indices(hi[i + 1], hi[i])
		var e3: int = seed.append_edge_indices(hi[i], lo[i])
		seed.append_poly_cell(2, PackedInt32Array([e0, e1, e2, e3]))
	var f := FenceGenerator4D.new()
	f.name = name
	f.update_automatically = false
	f.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	f.input_shape_type = FenceGenerator4D.INPUT_SHAPE_SEED_MESH_4D
	f.seed_mesh_4d = seed
	f.post_height_meters = FENCE_POST_H
	f.post_thickness_meters = 0.17
	f.rib_height_ratio = 0.999
	f.rib_thickness_ratio = 0.95
	f.beam_count = FENCE_RAILS.size()
	var top: float = float(FENCE_RAILS[FENCE_RAILS.size() - 1]) + 0.06
	f.beam_max_height_ratio = top / FENCE_POST_H
	# Each rail a board 0.13 tall in a slot of top / count.
	f.beam_coverage = clampf(0.13 / (top / float(FENCE_RAILS.size())), 0.02, 1.0)
	f.beam_thickness_ratio = 0.4
	f.desired_spacing_meters = 0.0
	f.post_material = _wood
	f.rib_material = _wood
	f.beam_material = _wood
	_own(f)
	f.update_fence_mesh_now()
	for i in posts.size() - 1:
		var a: Vector2 = posts[i]
		var b: Vector2 = posts[i + 1]
		_solid(Vector4(absf(b.x - a.x) + 0.25, FENCE_POST_H, absf(b.y - a.y) + 0.25, prop_w), Vector4((a.x + b.x) * 0.5, FENCE_POST_H * 0.5, (a.y + b.y) * 0.5, 0))


# --- The front ----------------------------------------------------------------------------------

## The table: a heavy top on four legs, a stretcher, a red runner with a gold edge over its length
## and down its front, three rifles laid across at an angle.
func _table() -> void:
	var c: Vector4 = TABLE_AT
	var s: Vector3 = TABLE_SIZE
	_box(timber, Vector4(s.x, 0.1, s.z, prop_w), c + Vector4(0, s.y - 0.05, 0, 0))
	_box(timber_dark, Vector4(s.x + 0.02, 0.06, s.z + 0.02, prop_w), c + Vector4(0, s.y - 0.13, 0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(timber_dark, Vector4(0.13, s.y - 0.1, 0.13, prop_w), c + Vector4(sx * (s.x * 0.5 - 0.15), (s.y - 0.1) * 0.5, sz * (s.z * 0.5 - 0.12), 0))
	_box(timber_dark, Vector4(s.x - 0.3, 0.08, 0.08, prop_w), c + Vector4(0, 0.25, 0, 0))
	# The runner: over the top, down the front, a gold stripe near each edge.
	_box(cloth, Vector4(s.x * 0.68, 0.02, s.z * 0.8, prop_w - 0.1), c + Vector4(0, s.y + 0.01, 0, 0))
	_box(cloth, Vector4(s.x * 0.68, 0.3, 0.02, prop_w - 0.1), c + Vector4(0, s.y - 0.14, s.z * 0.5 + 0.01, 0))
	for e in [-1.0, 1.0]:
		_box(gold, Vector4(0.035, 0.022, s.z * 0.8, prop_w - 0.08), c + Vector4(e * s.x * 0.31, s.y + 0.015, 0, 0))
		_box(gold, Vector4(0.035, 0.3, 0.025, prop_w - 0.08), c + Vector4(e * s.x * 0.31, s.y - 0.14, s.z * 0.5 + 0.015, 0))
	for k in 3:
		_rifle(c + Vector4(-0.7 + 0.7 * float(k), s.y + 0.08, 0.05 * float(k % 2), 0), -0.55)
	_solid(Vector4(s.x, s.y, s.z, prop_w), c + Vector4(0, s.y * 0.5, 0, 0))


## A rifle lying across the table, its muzzle toward the back right, turned by [param turn]: a wooden
## stock, an iron barrel with a flared muzzle, brass bands, a small rune glowing on the lock.
func _rifle(at: Vector4, turn: float) -> void:
	var rot: Projection = _turn_y(turn)
	var parts: Array = [
		[timber, Vector4(0.52, 0.1, 0.08, 0.15), Vector4(-0.32, 0.0, 0.0, 0.0)],
		[timber_dark, Vector4(0.18, 0.15, 0.08, 0.15), Vector4(-0.64, -0.02, 0.0, 0.0)],
		[iron, Vector4(0.7, 0.06, 0.06, 0.11), Vector4(0.28, 0.02, 0.0, 0.0)],
		[iron, Vector4(0.12, 0.11, 0.11, 0.13), Vector4(0.66, 0.02, 0.0, 0.0)],
		[gold, Vector4(0.035, 0.09, 0.09, 0.14), Vector4(0.08, 0.02, 0.0, 0.0)],
		[gold, Vector4(0.035, 0.09, 0.09, 0.14), Vector4(0.42, 0.02, 0.0, 0.0)],
		[gold, Vector4(0.11, 0.08, 0.1, 0.14), Vector4(-0.08, 0.01, 0.0, 0.0)],
	]
	for p in parts:
		_box(p[0], p[1], at + rot * (p[2] as Vector4), rot)
	_box(rune_glow, Vector4(0.05, 0.045, 0.105, 0.09), at + rot * Vector4(-0.08, 0.03, 0.0, 0.0), rot, true)


## The banner: a post with an arm at the top, a maroon cloth hanging from it, a gold diamond on it and
## gold bands at its foot.
func _banner() -> void:
	var c: Vector4 = BANNER_AT
	var tall: float = 2.85
	_box(timber_dark, Vector4(0.15, tall, 0.15, prop_w), c + Vector4(0, tall * 0.5, 0, 0))
	_box(timber, Vector4(0.95, 0.12, 0.12, prop_w), c + Vector4(0.4, 2.7, 0, 0))
	_strut(timber_dark, c + Vector4(0.05, 2.25, 0, 0), c + Vector4(0.45, 2.66, 0, 0), 0.08)
	_box(iron, Vector4(0.12, 0.12, 0.13, prop_w + 0.02), c + Vector4(0, 2.7, 0, 0))
	var cx: float = c.x + 0.48
	var top: float = 2.62
	var bottom: float = 0.9
	var w: float = 0.62
	_box(cloth, Vector4(w, top - bottom, 0.03, prop_w - 0.2), Vector4(cx, (top + bottom) * 0.5, c.z, 0))
	_box(gold, Vector4(w + 0.02, 0.05, 0.035, prop_w - 0.18), Vector4(cx, bottom + 0.12, c.z, 0))
	_box(gold, Vector4(w + 0.02, 0.03, 0.035, prop_w - 0.18), Vector4(cx, bottom + 0.22, c.z, 0))
	var mid := Vector4(cx, (top + bottom) * 0.5 + 0.08, c.z + 0.02, 0)
	for k in 4:
		var a: float = PI * 0.25 + PI * 0.5 * float(k)
		_box(gold, Vector4(0.33, 0.055, 0.03, prop_w - 0.25), mid + Vector4(cos(a) * 0.12, sin(a) * 0.2, 0, 0), _turn_z(a + PI * 0.5 + (0.35 if k % 2 == 0 else -0.35)))
	_box(gold, Vector4(0.08, 0.13, 0.03, prop_w - 0.25), mid, _turn_z(PI * 0.25))
	_solid(Vector4(0.3, tall, 0.3, prop_w), c + Vector4(0, tall * 0.5, 0, 0))


## A barrel: eight staves round, three iron hoops, a lid.
func _barrel() -> void:
	var c: Vector4 = BARREL_AT
	var r: float = 0.33
	var h: float = 0.9
	var face: float = 2.0 * r * tan(PI / 8.0) * 1.03
	for k in 4:
		var t: float = PI * float(k) / 4.0
		_box(timber, Vector4(r * 2.0, h, face, prop_w * 0.6), c + Vector4(0, h * 0.5, 0, 0), _turn_y(t))
		for y in [0.15, 0.45, 0.75]:
			_box(iron, Vector4(r * 2.0 + 0.03, 0.05, face + 0.012, prop_w * 0.6 + 0.02), c + Vector4(0, y, 0, 0), _turn_y(t))
		_box(timber_dark, Vector4(r * 1.8, 0.04, face * 0.9, prop_w * 0.55), c + Vector4(0, h + 0.01, 0, 0), _turn_y(t))
	_solid(Vector4(0.7, h, 0.7, prop_w * 0.6), c + Vector4(0, h * 0.5, 0, 0))


## The rune stone: a ring of flat stones round its foot, the tapered block on them, and in its top a
## dark iron disc with a glowing diamond. The button is a node on it (pen_rune_stone_4d.gd).
func _rune_stone() -> void:
	var c: Vector4 = STONE_AT
	var s: Vector3 = STONE_SIZE
	# The paving round its foot: four flat stones, as painted.
	for k in 4:
		var a: float = TAU * float(k) / 4.0 + 0.5
		var at := Vector4(c.x + cos(a) * s.x * 0.62, 0.0, c.z + sin(a) * s.z * 0.62, 0)
		_stone("ledge", at - Vector4(0, 0.04, 0, 0), Vector3(0.45, 0.16, 0.4), prop_w + 0.3, -a)
	var block := BoxTetraMesh4D.new()
	block.size = Vector4(s.x, s.y, s.z, prop_w)
	var mesh: ArrayTetraMesh4D = block.to_array_tetra_mesh()
	var corners: PackedVector4Array = mesh.get_vertex_positions()
	for i in corners.size():
		if corners[i].y > 0.0:
			corners[i] = Vector4(corners[i].x * 0.82, corners[i].y, corners[i].z * 0.82, corners[i].w * 0.9)
	mesh.set_vertex_positions(corners)
	_merge(stone, mesh, c + Vector4(0, s.y * 0.5, 0, 0))
	# The chisel marks on its faces: a few darker slabs set into each side.
	for k in 4:
		var a: float = PI * 0.5 * float(k)
		var n := Vector4(cos(a), 0, sin(a), 0)
		var w: float = (s.x if k % 2 == 1 else s.z) * 0.36
		for j in 2:
			var at: Vector4 = c + n * ((s.x if k % 2 == 0 else s.z) * 0.455) + Vector4(0, 0.3 + 0.35 * float(j), 0, 0) + Vector4(-n.z, 0, n.x, 0) * w * (0.5 if j == 0 else -0.4)
			_box(stone.darkened(0.12), Vector4(0.05 if k % 2 == 0 else w, 0.26, w if k % 2 == 0 else 0.05, prop_w * 0.9), at)
	_disc_y(iron, c + Vector4(0, s.y + 0.015, 0, 0), 0.3, 0.035)
	_disc_y(stone_dark, c + Vector4(0, s.y + 0.03, 0, 0), 0.22, 0.02)
	for k in 4:
		var a: float = PI * 0.25 + PI * 0.5 * float(k)
		_box(rune_glow, Vector4(0.2, 0.03, 0.045, prop_w * 0.6), c + Vector4(cos(a) * 0.075, s.y + 0.045, sin(a) * 0.075, 0), _turn_y(-a + PI * 0.5), true)
	_solid(Vector4(s.x, s.y, s.z, prop_w), c + Vector4(0, s.y * 0.5, 0, 0))


## The field stones along the fences and at the yard's corners, where the top view has them.
func _field_stones() -> void:
	var list: Array = [[3.56, -10.16, 0.75], [3.63, -8.4, 0.85], [3.69, -4.47, 0.9], [3.61, -1.34, 0.8], [-3.04, -7.97, 0.7], [-3.17, -5.31, 0.75],
		[-3.17, -3.05, 0.7], [-3.6, 0.3, 0.6], [4.0, 0.6, 0.85], [2.6, -6.0, 0.3], [-1.4, -8.7, 0.25], [1.2, -3.6, 0.25]]
	for p in list:
		var s: float = float(p[2])
		_stone(["round", "chip", "block"][_rng.randi() % 3], Vector4(float(p[0]), -0.15 * s, float(p[1]), _rng.randf_range(-0.6, 0.6)), Vector3(s * 1.1, s * 0.8, s), s * 1.6, _rng.randf_range(0.0, TAU))


## Grass: clumps thick along the fences' outsides and the yard's edges, as painted.
func _grass() -> void:
	for side in [-1.0, 1.0]:
		var x0: float = FENCE_L[0].x if side < 0.0 else FENCE_R[0].x
		for k in 14:
			var z: float = lerpf(-10.0, 0.8, float(k) / 13.0) + _rng.randf_range(-0.3, 0.3)
			_tuft(Vector4(x0 + side * _rng.randf_range(0.2, 1.1), 0.0, z, _rng.randf_range(-0.6, 0.6)), _rng.randf_range(0.9, 1.5))
	for k in 10:
		_tuft(Vector4(_rng.randf_range(-3.5, 3.8), 0.0, _rng.randf_range(0.6, 1.4), _rng.randf_range(-0.6, 0.6)), _rng.randf_range(0.9, 1.3))
	for k in 8:
		_tuft(Vector4(_rng.randf_range(-3.2, 3.4), BANK.y, _rng.randf_range(-11.6, -10.0), _rng.randf_range(-0.6, 0.6)), _rng.randf_range(0.9, 1.4))


# --- Helpers ------------------------------------------------------------------------------------

## [param moss]: the mossy-top variant (grey sides turning green over the top, cut_stone_4d.gd).
func _stone(kind: String, base: Vector4, size: Vector3, wsize: float, yaw: float, moss: bool = false) -> void:
	var half: Vector4 = (CutStone.KINDS[kind][0] as Vector4)
	var scale := Vector4(size.x / (2.0 * half.x), size.y / (2.0 * half.y), size.z / (2.0 * half.z), wsize / (2.0 * half.w))
	_stones.append([kind + ("_moss" if moss else ""), _rng.randi() % CutStone.VARIANTS, base + Vector4(0, size.y * 0.5, 0, 0), scale, yaw, Vector2.ZERO])


func _tuft(at: Vector4, size: float) -> void:
	_tufts.append([_rng.randi() % 6, at, size, _rng.randf_range(0.0, TAU)])


## A round disc in the x-y plane (its face toward +z), [param r] across, [param t] thick in z.
func _disc_z(colour: Color, at: Vector4, r: float, t: float, glow: bool = false) -> void:
	var face: float = 2.0 * r * tan(PI / 16.0) * 1.03
	for k in 8:
		_box(colour, Vector4(face, r * 2.0, t, prop_w), at, _turn_z(PI * float(k) / 8.0), glow)


## A round disc lying flat (its face up).
func _disc_y(colour: Color, at: Vector4, r: float, t: float) -> void:
	var face: float = 2.0 * r * tan(PI / 12.0) * 1.03
	for k in 6:
		_box(colour, Vector4(r * 2.0, t, face, prop_w * 0.7), at, _turn_y(PI * float(k) / 6.0))


func _box(colour: Color, size: Vector4, at: Vector4, basis: Projection = Projection.IDENTITY, glow: bool = false) -> void:
	var box := BoxTetraMesh4D.new()
	box.size = size
	_merge(colour, box.to_array_tetra_mesh(), at, basis, glow)


func _merge(colour: Color, mesh: ArrayTetraMesh4D, at: Vector4, basis: Projection = Projection.IDENTITY, glow: bool = false) -> void:
	var into: Dictionary = _glows if glow else _batches
	var key: String = colour.to_html(false)
	if not into.has(key):
		into[key] = ArrayTetraMesh4D.new()
	(into[key] as ArrayTetraMesh4D).merge_with(mesh, at, basis)


func _strut(colour: Color, a: Vector4, b: Vector4, thick: float) -> void:
	var d: Vector4 = b - a
	var length_: float = d.length()
	if length_ < 0.001:
		return
	_box(colour, Vector4(thick, length_, thick, prop_w), (a + b) * 0.5, _frame_along(d / length_))


func _flush() -> void:
	for key in _batches:
		var node := MeshInstance4D.new()
		node.name = "Props_" + String(key)
		node.mesh = _batches[key]
		var m := TetraMaterial4D.new()
		m.albedo_color = Color.html(key)
		node.material_override = m
		_own(node)
	for key in _glows:
		var node := MeshInstance4D.new()
		node.name = "Glow_" + String(key)
		node.mesh = _glows[key]
		node.material_override = Mats.glow(Color.html(key), 1.0)
		_own(node)
	var merged := ArrayTetraMesh4D.new()
	var count: int = 0
	for s in _stones:
		var mesh: ArrayTetraMesh4D = StoneSet.stone_mesh(String(s[0]), int(s[1]))
		if mesh != null:
			merged.merge_with(mesh, s[2], StoneSet.placement_basis(s[3], float(s[4]), s[5]))
			count += 1
	for t in _tufts:
		var mesh: ArrayTetraMesh4D = StoneSet.stone_mesh("tuft", int(t[0]))
		if mesh != null:
			var sz: float = t[2]
			merged.merge_with(mesh, t[1], Basis4D.from_zx(float(t[3])) * Projection(Vector4(sz, 0, 0, 0), Vector4(0, sz, 0, 0), Vector4(0, 0, sz, 0), Vector4(0, 0, 0, sz)))
			count += 1
	if count > 0:
		var node := MeshInstance4D.new()
		node.name = "Stones"
		node.mesh = merged
		node.material_override = TerrainBake.material()
		_own(node)
	_batches.clear()
	_glows.clear()


func _solid(size: Vector4, at: Vector4) -> void:
	var holder := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	holder.shape = shape
	holder.position = at
	_body.add_child(holder)


static func _frame_along(y: Vector4) -> Projection:
	var picks: Array[Vector4] = []
	for axis in [Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1)]:
		var v: Vector4 = axis - y * y.dot(axis)
		for p in picks:
			v -= p * p.dot(v)
		if v.length() > 0.2:
			picks.append(v.normalized())
		if picks.size() == 3:
			break
	var frame := Projection(picks[0], y, picks[1], picks[2])
	if frame.determinant() < 0.0:
		frame.w = -frame.w
	return frame


## A turn about the up axis by [param t]: x toward -z.
static func _turn_y(t: float) -> Projection:
	return Projection(Vector4(cos(t), 0.0, -sin(t), 0.0), Vector4(0.0, 1.0, 0.0, 0.0), Vector4(sin(t), 0.0, cos(t), 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


## A turn about the z axis by [param t]: x toward y.
static func _turn_z(t: float) -> Projection:
	return Projection(Vector4(cos(t), sin(t), 0.0, 0.0), Vector4(-sin(t), cos(t), 0.0, 0.0), Vector4(0.0, 0.0, 1.0, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


func _own(node: Node) -> void:
	node.set_meta(OWN, true)
	add_child(node)
