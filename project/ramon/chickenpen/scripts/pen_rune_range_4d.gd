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
## THE YARD IN FOUR DIMENSIONS ([member enclosed_in_w]; 6 Oct, Ramon: "shooting range doesnt slice
## well. you used the fence tech?"; "make the fence tech accurately follow whats there now"). Built
## first as a 3D yard stretched 1.4 m through W, it read as plates once the slice turned, and the
## fences fell out of view. Now the yard is as deep in W as it is wide (W_HALF either side): the
## fences are one fence-tech enclosure, its sides the measured fences exactly (posts, height, three
## rails) and two more fences at the W ends that mirror them, open at the front as before; the boards
## and the barrel are spun round in X and W (PolyMeshBuilder4D.extrude_spin_from_faces_xw) and the
## board frames, the table and the banner made the same both ways, so a quarter turn into W shows
## the same yard; the outcrop and field stones are stood round into W as well. From the farm's slice
## it looks as it did. Off: the yard as built that morning.
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
## The yard in four dimensions (see the header); off, as built on the morning of 6 Oct.
@export var enclosed_in_w: bool = true: set = _set_enclosed

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
## Half the yard's depth in W: half its width between the fences, so a quarter turn keeps its shape.
const W_HALF := (3.08 + 2.6) * 0.5
## The yard's middle in x, between the fences: the axis the field stones are stood round into W about.
const YARD_X := (3.08 - 2.6) * 0.5
## Steps round a spun shape (a multiple of 4, so one lies on the farm's slice).
const SPIN_STEPS := 12

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
func _set_enclosed(v: bool) -> void: enclosed_in_w = v; _later()


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
	return [{"centre": c, "half": Vector2((SAND_X.y - SAND_X.x) * 0.5, (SAND_Z.y - SAND_Z.x) * 0.5), "ax": ax, "az": az, "w_half": W_HALF if enclosed_in_w else prop_w * 0.6}]


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
	_fences()
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
	var first: int = _stones.size()
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
		if enclosed_in_w and absf(p.x - mid.x) > 1.0:
			# The same course turned a quarter into W about the arc's middle: the U is a bowl.
			_solid(Vector4(rock_w, tall, 1.4, 1.4), Vector4(mid.x, tall * 0.5, p.y, p.x - mid.x))
	if enclosed_in_w:
		_turn_stones(first, mid.x, 1.0)


# --- The boards ---------------------------------------------------------------------------------

## A round stone board facing the yard (+z) in a square timber frame on legs to the bank: its rings
## (light rim, dark band, light band, dark middle), the rune glowing at its centre, iron plates at the
## frame's corners and a strut behind each post.
func _board(at2: Vector2, rune_y: float, r: float, rune: String) -> void:
	var c := Vector4(at2.x, rune_y, at2.y, 0)
	var t: float = 0.16
	_round_z(stone, c, r, t)
	_round_z(stone_dark, c + Vector4(0, 0, t * 0.5, 0), r * 0.83, 0.03)
	_round_z(stone, c + Vector4(0, 0, t * 0.5 + 0.015, 0), r * 0.68, 0.03)
	_round_z(stone_dark, c + Vector4(0, 0, t * 0.5 + 0.03, 0), r * 0.42, 0.03)
	var face: Vector4 = c + Vector4(0, 0, t * 0.5 + 0.06, 0)
	if enclosed_in_w and rune != "dot":
		_rune_spun(rune, face, r)
		rune = "done"
	match rune:
		"dot":
			_round_z(rune_glow, face, r * 0.13, 0.03, true)
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
	# The frame: two posts from the bank, a beam over and a beam under the ring. In four dimensions a
	# square of them round the board in X and W: each post a wall as deep in W as the frame is wide,
	# the same turned a quarter, and the beams as deep in W as they are long.
	var ground: float = 0.0
	var half: float = r + 0.12
	var axis := Vector4(c.x, 0, c.z, 0)
	var span: float = 2.0 * half + 0.16
	for s in [-1.0, 1.0]:
		var post := Vector4(c.x + s * half, 0, c.z - 0.05, 0)
		var top: float = c.y + r + 0.1
		_box4(timber_dark, Vector4(0.16, top - ground, 0.16, _ww(prop_w, span)), post + Vector4(0, (top + ground) * 0.5, 0, 0), axis)
		# The strut behind (the side view's A-frame leg).
		_strut4(timber, post + Vector4(0, c.y + 0.1, -0.08, 0), post + Vector4(0, ground, -0.9, 0), 0.1, _ww(prop_w, span), axis)
		for y in [c.y + r - 0.02, c.y - r + 0.02]:
			_box4(iron, Vector4(0.2, 0.2, 0.05, _ww(prop_w + 0.02, span + 0.04)), Vector4(post.x, y, c.z + 0.04, 0), axis)
	_box4(timber, Vector4(2.0 * half + 0.3, 0.16, 0.16, _ww(prop_w, 2.0 * half + 0.3)), Vector4(c.x, c.y + r + 0.06, c.z - 0.05, 0), axis)
	_box4(timber, Vector4(2.0 * half + 0.1, 0.14, 0.14, _ww(prop_w, 2.0 * half + 0.1)), Vector4(c.x, c.y - r - 0.06, c.z - 0.05, 0), axis)
	_solid(Vector4(2.0 * half + 0.3, c.y + r - ground, 0.5, _ww(prop_w, 2.0 * half + 0.3)), Vector4(c.x, (c.y + r + ground) * 0.5, c.z, 0))


# --- The fences --------------------------------------------------------------------------------

func _fences() -> void:
	if not enclosed_in_w:
		_fence(FENCE_L, "FenceWest")
		_fence(FENCE_R, "FenceEast")
		return
	_yard_fence()


## THE YARD'S FENCE IN FOUR DIMENSIONS: one fence-tech seed for the whole yard. Its four long edges run
## along z at the two fences' x and at both W ends (W_HALF); its faces are the two measured side
## fences (x fixed, spanning z and W), cut at their measured posts, and the two W ends (W fixed,
## spanning x and z), cut where the side they mirror has posts (kata the west fence's, ana the
## east's). The fence tech makes a face a stack of rails, an edge a rib and a corner a post, so from
## the farm's slice the side fences, cut across their W edges, show exactly the measured posts and
## three rails, and turned a quarter into W the two ends show the same. Open at the front and back.
func _yard_fence() -> void:
	var seed := ArrayPolyMesh4D.new()
	var verts: Dictionary = {}
	var edges: Dictionary = {}
	var vert := func(x: float, z: float, w: float) -> int:
		var key := "%.3f|%.3f|%.3f" % [x, z, w]
		if not verts.has(key):
			verts[key] = seed.append_vertex(Vector4(x, 0.0, z, w))
		return verts[key]
	var edge := func(a: int, b: int) -> int:
		var key := "%d|%d" % [mini(a, b), maxi(a, b)]
		if not edges.has(key):
			edges[key] = seed.append_edge_indices(a, b)
		return edges[key]
	var xl: float = (FENCE_L[0] as Vector2).x
	var xr: float = (FENCE_R[0] as Vector2).x
	var zl: Array = FENCE_L.map(func(p: Vector2) -> float: return p.y)
	var zr: Array = FENCE_R.map(func(p: Vector2) -> float: return p.y)
	var inner_l: Array = zl.slice(1, zl.size() - 1)
	var inner_r: Array = zr.slice(1, zr.size() - 1)
	# Each long edge's z's: its side's posts and the cuts the W end on it needs, front to back.
	var lines: Dictionary = {"L-": zl.duplicate(), "L+": zl + inner_r, "R-": zr + inner_l, "R+": zr.duplicate()}
	var place: Dictionary = {"L-": [xl, -W_HALF], "L+": [xl, W_HALF], "R-": [xr, -W_HALF], "R+": [xr, W_HALF]}
	for k in lines:
		var l: Array = lines[k]
		l.sort()
		l.reverse()
		lines[k] = l
	var faces: Array = [["L-", "L+", inner_l], ["R-", "R+", inner_r], ["L-", "R-", inner_l], ["L+", "R+", inner_r]]
	for f in faces:
		var cuts: Array = [INF] + (f[2] as Array) + [-INF]
		cuts.sort()
		cuts.reverse()
		for i in cuts.size() - 1:
			var hi: float = cuts[i]
			var lo: float = cuts[i + 1]
			var loop: Array = []
			for side in [f[0], f[1]]:
				var run: Array = (lines[side] as Array).filter(func(z: float) -> bool: return z <= hi + 0.001 and z >= lo - 0.001)
				if side == f[1]:
					run.reverse()
				for z in run:
					loop.append(vert.call(float(place[side][0]), z, float(place[side][1])))
			if loop.size() < 3:
				continue
			var ring := PackedInt32Array()
			for j in loop.size():
				ring.append(edge.call(loop[j], loop[(j + 1) % loop.size()]))
			seed.append_poly_cell(2, ring)
	_fence_generator("YardFence", seed)
	# Solid: the two side fences as deep in W as the yard, and the two W ends across it.
	for posts in [FENCE_L, FENCE_R]:
		for i in posts.size() - 1:
			var a: Vector2 = posts[i]
			var b: Vector2 = posts[i + 1]
			_solid(Vector4(absf(b.x - a.x) + 0.25, FENCE_POST_H, absf(b.y - a.y) + 0.25, 2.0 * W_HALF + 0.25), Vector4((a.x + b.x) * 0.5, FENCE_POST_H * 0.5, (a.y + b.y) * 0.5, 0))
	var z0: float = maxf(float(zl[0]), float(zr[0]))
	var z1: float = minf(float(zl[zl.size() - 1]), float(zr[zr.size() - 1]))
	for s in [-1.0, 1.0]:
		_solid(Vector4(xr - xl + 0.25, FENCE_POST_H, z0 - z1 + 0.25, 0.25), Vector4((xl + xr) * 0.5, FENCE_POST_H * 0.5, (z0 + z1) * 0.5, s * W_HALF))


## The fence tech with the measured fence's numbers (posts 1.25 m and 0.17 thick, three rails as
## boards 0.13 tall at the measured heights), on [param seed].
func _fence_generator(name: String, seed: ArrayPolyMesh4D) -> void:
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


## A three-rail fence through [param posts] (fence tech: a seed strip stretched in W, a post at each
## measured point, three rails as beams). The yard as built on the morning of 6 Oct.
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
	_fence_generator(name, seed)
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
	# In four dimensions as deep in W as it is wide, its legs walls round it both ways.
	var axis := Vector4(c.x, 0, c.z, 0)
	_box4(timber, Vector4(s.x, 0.1, s.z, _ww(prop_w, s.x)), c + Vector4(0, s.y - 0.05, 0, 0), axis)
	_box4(timber_dark, Vector4(s.x + 0.02, 0.06, s.z + 0.02, _ww(prop_w, s.x + 0.02)), c + Vector4(0, s.y - 0.13, 0, 0), axis)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box4(timber_dark, Vector4(0.13, s.y - 0.1, 0.13, _ww(prop_w, s.x - 0.17)), c + Vector4(sx * (s.x * 0.5 - 0.15), (s.y - 0.1) * 0.5, sz * (s.z * 0.5 - 0.12), 0), axis)
	_box4(timber_dark, Vector4(s.x - 0.3, 0.08, 0.08, _ww(prop_w, s.x - 0.3)), c + Vector4(0, 0.25, 0, 0), axis)
	# The runner: over the top, down the front, a gold stripe near each edge.
	_box4(cloth, Vector4(s.x * 0.68, 0.02, s.z * 0.8, _ww(prop_w - 0.1, s.x * 0.68)), c + Vector4(0, s.y + 0.01, 0, 0), axis)
	_box4(cloth, Vector4(s.x * 0.68, 0.3, 0.02, _ww(prop_w - 0.1, s.x * 0.68)), c + Vector4(0, s.y - 0.14, s.z * 0.5 + 0.01, 0), axis)
	for e in [-1.0, 1.0]:
		_box4(gold, Vector4(0.035, 0.022, s.z * 0.8, _ww(prop_w - 0.08, s.x * 0.62 + 0.035)), c + Vector4(e * s.x * 0.31, s.y + 0.015, 0, 0), axis)
		_box4(gold, Vector4(0.035, 0.3, 0.025, _ww(prop_w - 0.08, s.x * 0.62 + 0.035)), c + Vector4(e * s.x * 0.31, s.y - 0.14, s.z * 0.5 + 0.015, 0), axis)
	for k in 3:
		_rifle(c + Vector4(-0.7 + 0.7 * float(k), s.y + 0.08, 0.05 * float(k % 2), 0), -0.55)
	_solid(Vector4(s.x, s.y, s.z, _ww(prop_w, s.x)), c + Vector4(0, s.y * 0.5, 0, 0))


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
	# In four dimensions: a square post, and the arm and its banner once more turned a quarter into W.
	var axis := Vector4(c.x, 0, c.z, 0)
	var w: float = 0.62
	_box(timber_dark, Vector4(0.15, tall, 0.15, _ww(prop_w, 0.15)), c + Vector4(0, tall * 0.5, 0, 0))
	_box4(timber, Vector4(0.95, 0.12, 0.12, _ww(prop_w, 0.12)), c + Vector4(0.4, 2.7, 0, 0), axis)
	_strut4(timber_dark, c + Vector4(0.05, 2.25, 0, 0), c + Vector4(0.45, 2.66, 0, 0), 0.08, _ww(prop_w, 0.08), axis)
	_box(iron, Vector4(0.12, 0.12, 0.13, _ww(prop_w + 0.02, 0.13)), c + Vector4(0, 2.7, 0, 0))
	var cx: float = c.x + 0.48
	var top: float = 2.62
	var bottom: float = 0.9
	_box4(cloth, Vector4(w, top - bottom, 0.03, _ww(prop_w - 0.2, w)), Vector4(cx, (top + bottom) * 0.5, c.z, 0), axis)
	_box4(gold, Vector4(w + 0.02, 0.05, 0.035, _ww(prop_w - 0.18, w + 0.02)), Vector4(cx, bottom + 0.12, c.z, 0), axis)
	_box4(gold, Vector4(w + 0.02, 0.03, 0.035, _ww(prop_w - 0.18, w + 0.02)), Vector4(cx, bottom + 0.22, c.z, 0), axis)
	var mid := Vector4(cx, (top + bottom) * 0.5 + 0.08, c.z + 0.02, 0)
	for k in 4:
		var a: float = PI * 0.25 + PI * 0.5 * float(k)
		_box4(gold, Vector4(0.33, 0.055, 0.03, _ww(prop_w - 0.25, w * 0.6)), mid + Vector4(cos(a) * 0.12, sin(a) * 0.2, 0, 0), axis, _turn_z(a + PI * 0.5 + (0.35 if k % 2 == 0 else -0.35)))
	_box4(gold, Vector4(0.08, 0.13, 0.03, _ww(prop_w - 0.25, w * 0.6)), mid, axis, _turn_z(PI * 0.25))
	_solid(Vector4(0.3, tall, 0.3, _ww(prop_w, 0.3)), c + Vector4(0, tall * 0.5, 0, 0))


## A barrel: eight staves round, three iron hoops, a lid.
func _barrel() -> void:
	var c: Vector4 = BARREL_AT
	var r: float = 0.33
	var h: float = 0.9
	if enclosed_in_w and _barrel_spun(c, r, h):
		_solid(Vector4(0.7, h, 0.7, 0.7), c + Vector4(0, h * 0.5, 0, 0))
		return
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
	if enclosed_in_w:
		_turn_stones(_stones.size() - list.size(), YARD_X, 0.5)


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
	_stones.append([kind + ("_moss" if moss else ""), _rng.randi() % CutStone.VARIANTS, base + Vector4(0, size.y * 0.5, 0, 0), scale, yaw, Vector2.ZERO, Projection.IDENTITY])


## The stones from [param from] on, once more turned a quarter into W about the vertical line at
## [param axis_x] (on their own z), all but those within [param near] of it in x (they would only stand
## in themselves).
func _turn_stones(from: int, axis_x: float, near: float) -> void:
	var r: Projection = _r90()
	var count: int = _stones.size()
	for i in range(maxi(from, 0), count):
		var s: Array = _stones[i]
		var at: Vector4 = s[2]
		if absf(at.x - axis_x) <= near:
			continue
		var turned: Vector4 = r * Vector4(at.x - axis_x, 0.0, 0.0, at.w)
		var copy: Array = s.duplicate()
		copy[2] = Vector4(axis_x + turned.x, at.y, at.z, turned.w)
		copy[6] = r * (s[6] as Projection)
		_stones.append(copy)


func _tuft(at: Vector4, size: float) -> void:
	_tufts.append([_rng.randi() % 6, at, size, _rng.randf_range(0.0, TAU)])


## [param old] as built that morning, [param new] for the yard in four dimensions.
func _ww(old: float, new: float) -> float:
	return new if enclosed_in_w else old


## A quarter turn from X into W.
static func _r90() -> Projection:
	return Basis4D.from_xw(PI * 0.5)


## A box as [method _box] draws it, and for the yard in four dimensions the same box turned a quarter
## into W about the vertical line through [param axis] (its x and W): what stands to one side in x
## stands to the same side in W too, so a quarter turn of the slice shows the same thing. A box on the
## line and as deep in W as it is wide is its own turn, and is drawn once.
func _box4(colour: Color, size: Vector4, at: Vector4, axis: Vector4, basis: Projection = Projection.IDENTITY, glow: bool = false) -> void:
	_box(colour, size, at, basis, glow)
	if not enclosed_in_w:
		return
	var off := Vector4(at.x - axis.x, 0.0, 0.0, at.w - axis.w)
	if off.length() < 0.01 and absf(size.x - size.w) < 0.01 and basis == Projection.IDENTITY:
		return
	var r: Projection = _r90()
	var turned: Vector4 = r * off
	_box(colour, size, Vector4(axis.x + turned.x, at.y, at.z, axis.w + turned.w), r * basis, glow)


## A strut from [param a] to [param b], [param depth] deep in W, and its quarter turn about [param axis].
func _strut4(colour: Color, a: Vector4, b: Vector4, thick: float, depth: float, axis: Vector4) -> void:
	var d: Vector4 = b - a
	var length_: float = d.length()
	if length_ < 0.001:
		return
	_box4(colour, Vector4(thick, length_, thick, depth), (a + b) * 0.5, axis, _frame_along(d / length_))


## A round disc facing +z ([method _disc_z]); for the yard in four dimensions round in X and W too,
## a ball pressed thin in z, so it is the same disc from a turned slice.
func _round_z(colour: Color, at: Vector4, r: float, t: float, glow: bool = false) -> void:
	if enclosed_in_w and _spun(colour, _half_disc(r), t, at, glow):
		return
	_disc_z(colour, at, r, t, glow)


## A half disc of radius [param r] on the x >= 0 side, top to bottom, eight steps round.
static func _half_disc(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 9:
		var a: float = PI * float(k) / 8.0
		out.append(Vector2(sin(a) * r, cos(a) * r))
	return out


## [param poly] (its points at x >= 0, in x and y, the face toward +z) made a slab [param depth] thick
## in z, or with [param plan] laid flat (its points in x and z, [param depth] tall in y), then spun a
## full turn about the vertical line through [param at] in X and W
## (PolyMeshBuilder4D.extrude_spin_from_faces_xw): a solid of revolution, round in X and W. False if
## the engine gave nothing back.
func _spun(colour: Color, poly: PackedVector2Array, depth: float, at: Vector4, glow: bool = false, plan: bool = false) -> bool:
	var m := ArrayPolyMesh4D.new()
	var n: int = poly.size()
	var near := PackedInt32Array()
	var far := PackedInt32Array()
	for p in poly:
		var x: float = maxf(p.x, 0.0)
		if plan:
			near.append(m.append_vertex(Vector4(x, depth * 0.5, p.y, 0.0)))
			far.append(m.append_vertex(Vector4(x, -depth * 0.5, p.y, 0.0)))
		else:
			near.append(m.append_vertex(Vector4(x, p.y, depth * 0.5, 0.0)))
			far.append(m.append_vertex(Vector4(x, p.y, -depth * 0.5, 0.0)))
	var edges: Dictionary = {}
	var edge := func(a: int, b: int) -> int:
		var key := "%d|%d" % [mini(a, b), maxi(a, b)]
		if not edges.has(key):
			edges[key] = m.append_edge_indices(a, b)
		return edges[key]
	var cap_near := PackedInt32Array()
	var cap_far := PackedInt32Array()
	for i in n:
		cap_near.append(edge.call(near[i], near[(i + 1) % n]))
		cap_far.append(edge.call(far[i], far[(i + 1) % n]))
	m.append_poly_cell(2, cap_near)
	m.append_poly_cell(2, cap_far)
	for i in n:
		var j: int = (i + 1) % n
		# A side lying on the axis does not move when spun: the engine takes no face there.
		if poly[i].x <= 0.0001 and poly[j].x <= 0.0001:
			continue
		m.append_poly_cell(2, PackedInt32Array([edge.call(near[i], near[j]), edge.call(near[j], far[j]), edge.call(far[j], far[i]), edge.call(far[i], near[i])]))
	var spun: ArrayPolyMesh4D = PolyMeshBuilder4D.extrude_spin_from_faces_xw(m, SPIN_STEPS)
	if spun == null:
		return false
	var tm: ArrayTetraMesh4D = spun.to_array_tetra_mesh()
	if tm == null or tm.get_simplex_cell_vertex_indices().is_empty():
		return false
	_face_out(tm, poly, depth, plan)
	_merge(colour, tm, at, Projection.IDENTITY, glow)
	return true


## EVERY FACE OUT (Ramon, 7 Oct: "normals look weird on shooting range cylinders, the trings you
## shoot"). The spin hands back tetrahedra wound either way, so the boards and runes were shaded in
## patches, some faces lit as if seen from inside. The engine's own way to turn them out tests each
## face against the mesh's middle, right for the round boards and wrong for the rings (the crosshair,
## the rune bars off the axis), whose inner faces look toward the axis. So each face is tested against
## the solid itself instead: a step either side of it, and the solid is round in X and W, so a point is
## in it when its distance from the axis and its height lie inside [param poly] and it is within
## [param depth]. Faces whose out-side is inside are turned over, then all are shaded flat by their own
## normal (smoothed across a 16-step spin, the rim had gone soft).
static var faces_turned: int = 0
static var faces_seen: int = 0


static func _face_out(tm: ArrayTetraMesh4D, poly: PackedVector2Array, depth: float, plan: bool) -> void:
	var profile := PackedVector2Array()
	for q in poly:
		profile.append(Vector2(maxf(q.x, 0.0), q.y))
	var inside := func(p: Vector4) -> bool:
		var radial: float = Vector2(p.x, p.w).length()
		var across: float = p.y if plan else p.z
		var along: float = p.z if plan else p.y
		return absf(across) <= depth * 0.5 and Geometry2D.is_point_in_polygon(Vector2(radial, along), profile)
	tm.calculate_boundary_normals()
	var normals: PackedVector4Array = tm.get_simplex_cell_boundary_normals()
	var verts: PackedVector4Array = tm.get_vertex_positions()
	var cells: PackedInt32Array = tm.get_simplex_cell_vertex_indices()
	var step: float = minf(depth * 0.2, 0.004)
	var turned: int = 0
	for c in normals.size():
		var k: int = c * 4
		var mid: Vector4 = (verts[cells[k]] + verts[cells[k + 1]] + verts[cells[k + 2]] + verts[cells[k + 3]]) * 0.25
		var n: Vector4 = normals[c].normalized()
		if bool(inside.call(mid + n * step)) and not bool(inside.call(mid - n * step)):
			var first: int = cells[k]
			cells[k] = cells[k + 1]
			cells[k + 1] = first
			turned += 1
	faces_turned += turned
	faces_seen += normals.size()
	if turned > 0:
		tm.set_simplex_cell_vertex_indices(cells)
	tm.set_flat_shading_normals(true)


## A bar from [param a] to [param b] ([param thick] across, in x and y, x >= 0) spun round in X and W.
func _spun_bar(colour: Color, a: Vector2, b: Vector2, thick: float, depth: float, at: Vector4, glow: bool) -> void:
	var d: Vector2 = (b - a).normalized()
	var n := Vector2(-d.y, d.x) * thick * 0.5
	var quad := PackedVector2Array([a + n, b + n, b - n, a - n])
	# Clipped at the axis: what crosses it is the other half's, and the spin makes that.
	var clipped := PackedVector2Array()
	for i in 4:
		var p: Vector2 = quad[i]
		var q: Vector2 = quad[(i + 1) % 4]
		if p.x >= 0.0:
			clipped.append(p)
		if (p.x >= 0.0) != (q.x >= 0.0):
			var f: float = p.x / (p.x - q.x)
			clipped.append(Vector2(0.0, p.y + (q.y - p.y) * f))
	if clipped.size() >= 3:
		_spun(colour, clipped, depth, at, glow)


## The diamond and triangle runes, their right halves spun round in X and W: from the farm's slice the
## same outline, and the same from a turned one.
func _rune_spun(rune: String, face: Vector4, r: float) -> void:
	var t: float = 0.03
	match rune:
		"diamond":
			for sy in [1.0, -1.0]:
				_spun_bar(rune_glow, Vector2(0.028 * r, 0.212 * r * sy), Vector2(0.212 * r, 0.028 * r * sy), 0.045, t, face, true)
			# The crosshair: a ring where its two side bars were, a rod above and below.
			_spun(rune_glow, PackedVector2Array([Vector2(0.4 * r, 0.015), Vector2(0.6 * r, 0.015), Vector2(0.6 * r, -0.015), Vector2(0.4 * r, -0.015)]), t, face, true)
			for sy in [1.0, -1.0]:
				_spun(rune_glow, PackedVector2Array([Vector2(0.0, 0.4 * r * sy), Vector2(0.015, 0.4 * r * sy), Vector2(0.015, 0.6 * r * sy), Vector2(0.0, 0.6 * r * sy)]), t, face, true)
		"triangle":
			var apex := Vector2(0.0, 0.24 * r)
			var corner := Vector2(0.208 * r, -0.12 * r)
			_spun_bar(rune_glow, apex, corner, 0.045, t, face, true)
			_spun_bar(rune_glow, corner + Vector2(0.02, 0.0), Vector2(-0.03, -0.12 * r), 0.045, t, face, true)


## The barrel spun round in X and W: staves, three hoops and the lid, each a half disc in the plan.
func _barrel_spun(c: Vector4, r: float, h: float) -> bool:
	if not _spun(timber, _half_disc(r), h, c + Vector4(0, h * 0.5, 0, 0), false, true):
		return false
	for y in [0.15, 0.45, 0.75]:
		_spun(iron, _half_disc(r + 0.015), 0.05, c + Vector4(0, y, 0, 0), false, true)
	_spun(timber_dark, _half_disc(r * 0.9), 0.04, c + Vector4(0, h + 0.01, 0, 0), false, true)
	return true


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
			merged.merge_with(mesh, s[2], (s[6] as Projection) * StoneSet.placement_basis(s[3], float(s[4]), s[5]))
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
