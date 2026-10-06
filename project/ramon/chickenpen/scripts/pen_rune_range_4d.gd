@tool
extends Node4D

## The range, remade (6 Oct 2026, PenLayout/PLAN_WATCHSTONE.md part C; Ramon, with a concept
## painting: "the shooting range also needs to completely be replaced. and remove all mechanics ...
## you can't shoot the boards its just for illustration. the block next to the table will give you
## a button activation to teleport to the shooting range").
##
## A yard of trodden sand (the pen's own painted sand, the Grass node's `sand_round`) in a timber
## rail fence on its two long sides (the fence tech). At its far end three round stone-faced target
## boards on timber stands, each with a rune glowing at its centre (a dot, a diamond, a triangle),
## against a mossy outcrop from the rock kit. At the near end a table with three ritual-tech rifles
## on a red runner, a banner on a timber frame (maroon, a gold diamond), a barrel, and the rune
## stone: a tapered block with a glowing diamond set in its top, the button to the Quantum Range
## (scripts/pen_rune_stone_4d.gd). The runes glow through the lab kit's unshaded glow, since the
## renderer has no emission.
##
## In the unit's frame: the yard's long axis along x, the near end (+x) where the path arrives, the
## boards at the far end (-x). Built when it loads (and in the editor); nothing generated is saved.
##
## NO class_name (engine_gotchas.md).

const Pile := preload("res://ramon/chickenpen/scripts/pen_boulder_pile_4d.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var range_seed: int = 9: set = _set_seed
## The yard: how far the boards stand from the near end, and its half-width.
@export_range(6.0, 20.0, 0.1, "suffix:m") var length: float = 11.0: set = _set_length
@export_range(2.0, 8.0, 0.1, "suffix:m") var half_width: float = 4.3: set = _set_half_width
## How deep in W the props are.
@export_range(0.4, 4.0, 0.05, "suffix:m") var prop_w: float = 1.4: set = _set_prop_w

@export_group("Look")
@export var timber: Color = Color(0.53, 0.38, 0.24)
@export var timber_dark: Color = Color(0.35, 0.24, 0.15)
@export var stone: Color = Color(0.70, 0.69, 0.66)
@export var stone_dark: Color = Color(0.30, 0.30, 0.33)
@export var iron: Color = Color(0.22, 0.22, 0.24)
@export var cloth: Color = Color(0.42, 0.10, 0.11)
@export var gold: Color = Color(0.82, 0.62, 0.22)
@export var rune_glow: Color = Color(1.0, 0.74, 0.30)
@export var leaf: Color = Color(0.36, 0.52, 0.16)

## The rune stone, the table, the banner and the barrel (in the unit's frame).
const STONE_AT := Vector4(0.2, 0.0, 1.2, 0.0)
const TABLE_AT := Vector4(1.7, 0.0, 3.1, 0.0)
const BANNER_AT := Vector4(2.9, 0.0, 4.3, 0.0)
const BARREL_AT := Vector4(3.3, 0.0, 3.2, 0.0)

const OWN := &"_rune_range_part"

var _pending: bool = false
var _batches: Dictionary = {}
var _glows: Dictionary = {}
var _body: StaticBody4D


func _set_seed(v: int) -> void: range_seed = v; _later()
func _set_length(v: float) -> void: length = v; _later()
func _set_half_width(v: float) -> void: half_width = v; _later()
func _set_prop_w(v: float) -> void: prop_w = v; _later()


func _ready() -> void:
	rebuild()


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
	_body = StaticBody4D.new()
	_body.name = "Solid"
	_own(_body)
	var rng := RandomNumberGenerator.new()
	rng.seed = range_seed
	_outcrop(rng)
	_fences()
	var boards: Array = [[-2.9, 1.0, "dot"], [0.0, 1.25, "diamond"], [2.9, 1.0, "triangle"]]
	for b in boards:
		_board(Vector4(-length + 0.6, 0.0, float(b[0]), 0.0), float(b[1]), String(b[2]))
	_table()
	_banner()
	_barrel()
	_rune_stone()
	_clumps(rng)
	_flush()


## The outcrop behind the boards: big mossy boulders in a ragged bank, a few round its ends.
func _outcrop(rng: RandomNumberGenerator) -> void:
	var rocks: Array = []
	var x0: float = -length - 1.6
	for k in 8:
		var z: float = lerpf(-half_width - 1.2, half_width + 1.2, float(k) / 7.0) + rng.randf_range(-0.4, 0.4)
		var variant: int = [0, 3, 1, 4, 0, 3, 4, 1][k]
		var s: float = rng.randf_range(1.5, 2.1)
		rocks.append([variant, Vector4(x0 + rng.randf_range(-0.8, 0.6), rng.randf_range(1.0, 1.5), z, rng.randf_range(-0.8, 0.8)),
			Vector4(s, s * rng.randf_range(0.9, 1.3), s * 0.9, rng.randf_range(2.6, 3.4)), rng.randf_range(0.0, TAU),
			Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))])
	# A second row behind, higher, so the bank rises.
	for k in 5:
		var z2: float = lerpf(-half_width, half_width, float(k) / 4.0) + rng.randf_range(-0.5, 0.5)
		var s2: float = rng.randf_range(1.6, 2.2)
		rocks.append([[3, 0, 1, 3, 0][k], Vector4(x0 - 2.0 + rng.randf_range(-0.4, 0.4), rng.randf_range(2.0, 2.6), z2, rng.randf_range(-0.8, 0.8)),
			Vector4(s2, s2 * 1.1, s2, 3.0), rng.randf_range(0.0, TAU), Vector2(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1))])
	# Loose stones along the fences.
	for k in 8:
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var at := Vector4(rng.randf_range(-length + 1.0, -1.5), 0.25, side * (half_width + rng.randf_range(0.5, 1.3)), rng.randf_range(-0.8, 0.8))
		var s3: float = rng.randf_range(0.4, 0.75)
		rocks.append([5, at, Vector4(s3, s3, s3, s3 * 1.3), rng.randf_range(0.0, TAU)])
	var pile := Node4D.new()
	pile.name = "Outcrop"
	pile.set_script(Pile)
	pile.set("rocks", rocks)
	_own(pile)


## The two long fences, from the fence tech: posts every two metres or so, two rails.
func _fences() -> void:
	var run: float = length - 1.4
	for side in [-1.0, 1.0]:
		var f := FenceGenerator4D.new()
		f.name = "Fence%s" % ("N" if side < 0.0 else "S")
		f.update_automatically = false
		f.input_shape_type = FenceGenerator4D.INPUT_SHAPE_BOX
		f.box_size = Vector3(run, 0.12, 2.4)
		f.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
		f.desired_spacing_meters = 2.2
		f.post_height_meters = 1.15
		f.post_thickness_meters = 0.18
		f.rib_height_ratio = 1.0
		f.rib_thickness_ratio = 1.0
		f.beam_count = 2
		f.beam_coverage = 0.18
		f.beam_max_height_ratio = 0.92
		f.beam_thickness_ratio = 0.6
		var wood := TetraMaterial4D.new()
		wood.albedo_color = timber
		f.post_material = wood
		f.rib_material = wood
		f.beam_material = wood
		f.position = Vector4(-run * 0.5 - 1.0, 0.0, side * half_width, 0.0)
		f.set_meta(OWN, true)
		add_child(f)
		f.update_fence_mesh_now()
		_solid(Vector4(run, 1.2, 0.3, 2.4), Vector4(-run * 0.5 - 1.0, 0.6, side * half_width, 0.0))


## A round target board facing the near end, on a timber stand: stone-faced rings, iron straps, and
## a rune at its centre glowing ([param rune]: "dot", "diamond" or "triangle").
func _board(foot: Vector4, r: float, rune: String) -> void:
	var c: Vector4 = foot + Vector4(0.0, 0.55 + r, 0.0, 0.0)
	var t: float = 0.14
	_disc(stone, c, r, t)
	_disc(stone_dark, c + Vector4(t * 0.5, 0.0, 0.0, 0.0), r * 0.80, 0.03)
	_disc(stone, c + Vector4(t * 0.5 + 0.02, 0.0, 0.0, 0.0), r * 0.66, 0.03)
	_disc(stone_dark, c + Vector4(t * 0.5 + 0.04, 0.0, 0.0, 0.0), r * 0.40, 0.03)
	var face: Vector4 = c + Vector4(t * 0.5 + 0.07, 0.0, 0.0, 0.0)
	match rune:
		"dot":
			_disc(rune_glow, face, r * 0.12, 0.03, true)
		"diamond":
			for k in 4:
				var a: float = PI * 0.25 + PI * 0.5 * float(k)
				var mid := Vector4(0.0, cos(a) * r * 0.2, sin(a) * r * 0.2, 0.0)
				_box(rune_glow, Vector4(0.03, 0.05, r * 0.3, prop_w * 0.5), face + mid, _turn_x(a), true)
			_box(rune_glow, Vector4(0.03, r * 0.09, r * 0.09, prop_w * 0.5), face, _turn_x(PI * 0.25), true)
		"triangle":
			for k in 3:
				var a: float = PI * 0.5 + TAU * float(k) / 3.0
				var a_next: float = a + TAU / 3.0
				var p0 := Vector4(0.0, sin(a) * r * 0.26, cos(a) * r * 0.26, 0.0)
				var p1 := Vector4(0.0, sin(a_next) * r * 0.26, cos(a_next) * r * 0.26, 0.0)
				var d: Vector4 = p1 - p0
				_box(rune_glow, Vector4(0.03, 0.05, d.length() + 0.04, prop_w * 0.5), face + (p0 + p1) * 0.5, _turn_x(atan2(-d.y, d.z)), true)
	# Iron straps across the face, top and bottom.
	for sy in [-1.0, 1.0]:
		_box(iron, Vector4(0.03, 0.08, r * 1.5, prop_w), c + Vector4(t * 0.5 + 0.01, sy * r * 0.72, 0.0, 0.0))
	# The stand: two posts either side, a beam over the top, feet braced out, a rail under it.
	for sz in [-1.0, 1.0]:
		var post: Vector4 = foot + Vector4(-0.1, 0.0, sz * (r + 0.18), 0.0)
		var tall: float = c.y + r + 0.25
		_box(timber_dark, Vector4(0.16, tall, 0.16, prop_w), post + Vector4(0.0, tall * 0.5, 0.0, 0.0))
		_strut(timber, post + Vector4(-0.7, 0.0, 0.0, 0.0), post + Vector4(0.0, 0.9, 0.0, 0.0), 0.1)
		_strut(timber, post + Vector4(0.7, 0.0, 0.0, 0.0), post + Vector4(0.0, 0.9, 0.0, 0.0), 0.1)
		_box(iron, Vector4(0.2, 0.06, 0.2, prop_w), post + Vector4(0.0, c.y + r * 0.72, 0.0, 0.0))
	_box(timber, Vector4(0.2, 0.18, 2.0 * (r + 0.18) + 0.4, prop_w), foot + Vector4(-0.1, c.y + r + 0.3, 0.0, 0.0))
	_box(timber, Vector4(0.14, 0.12, 2.0 * (r + 0.18), prop_w), foot + Vector4(-0.1, 0.45, 0.0, 0.0))
	_solid(Vector4(0.6, c.y + r, 2.0 * (r + 0.3), prop_w), foot + Vector4(-0.1, (c.y + r) * 0.5, 0.0, 0.0))


## The table, its long side toward the way in (+x): a heavy top on four legs and a stretcher, a red
## runner with a gold edge hanging over its near side, and three ritual-tech rifles laid on it.
func _table() -> void:
	var c: Vector4 = TABLE_AT
	var top_y: float = 0.85
	_box(timber, Vector4(0.95, 0.09, 2.4, prop_w), c + Vector4(0.0, top_y, 0.0, 0.0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(timber_dark, Vector4(0.12, top_y, 0.12, prop_w), c + Vector4(sx * 0.36, top_y * 0.5, sz * 1.05, 0.0))
	_box(timber_dark, Vector4(0.08, 0.08, 2.1, prop_w), c + Vector4(0.0, 0.25, 0.0, 0.0))
	_box(cloth, Vector4(0.55, 0.02, 2.5, prop_w - 0.1), c + Vector4(0.05, top_y + 0.055, 0.0, 0.0))
	_box(cloth, Vector4(0.02, 0.38, 2.5, prop_w - 0.1), c + Vector4(0.33, top_y - 0.14, 0.0, 0.0))
	_box(gold, Vector4(0.025, 0.03, 2.5, prop_w - 0.1), c + Vector4(0.335, top_y - 0.31, 0.0, 0.0))
	for k in 3:
		var at: Vector4 = c + Vector4(0.02 - 0.08 * float(k % 2), top_y + 0.1, -0.75 + 0.75 * float(k), 0.0)
		_rifle(at, PI * 0.5 + 0.18 - 0.14 * float(k))
	_solid(Vector4(0.95, top_y + 0.1, 2.4, prop_w), c + Vector4(0.0, (top_y + 0.1) * 0.5, 0.0, 0.0))


## A ritual-tech rifle lying down, its barrel toward -x turned by [param turn]: a wooden stock, an
## iron barrel with a flared muzzle, brass bands, and a small rune glowing on the lock.
func _rifle(at: Vector4, turn: float) -> void:
	var rot: Projection = _turn_y(turn)
	var parts: Array = [
		[timber, Vector4(0.5, 0.09, 0.07, 0.14), Vector4(0.3, 0.0, 0.0, 0.0)],
		[timber_dark, Vector4(0.18, 0.14, 0.07, 0.14), Vector4(0.6, -0.02, 0.0, 0.0)],
		[iron, Vector4(0.75, 0.05, 0.05, 0.1), Vector4(-0.3, 0.02, 0.0, 0.0)],
		[iron, Vector4(0.1, 0.09, 0.09, 0.12), Vector4(-0.7, 0.02, 0.0, 0.0)],
		[gold, Vector4(0.03, 0.08, 0.08, 0.13), Vector4(-0.1, 0.02, 0.0, 0.0)],
		[gold, Vector4(0.03, 0.08, 0.08, 0.13), Vector4(-0.45, 0.02, 0.0, 0.0)],
		[gold, Vector4(0.1, 0.07, 0.09, 0.13), Vector4(0.08, 0.01, 0.0, 0.0)],
	]
	for p in parts:
		_box(p[0], p[1], at + rot * (p[2] as Vector4), rot)
	_box(rune_glow, Vector4(0.04, 0.04, 0.095, 0.08), at + rot * Vector4(0.08, 0.02, 0.0, 0.0), rot, true)


## The banner, facing the way in (+x): two posts and a beam, a maroon cloth hanging from it with a
## darker hem, a gold diamond on it.
func _banner() -> void:
	var c: Vector4 = BANNER_AT
	var tall: float = 2.7
	for sz in [-1.0, 1.0]:
		_box(timber_dark, Vector4(0.14, tall, 0.14, prop_w), c + Vector4(0.0, tall * 0.5, sz * 0.62, 0.0))
	_box(timber, Vector4(0.14, 0.12, 1.6, prop_w), c + Vector4(0.0, tall - 0.1, 0.0, 0.0))
	_box(iron, Vector4(0.04, 0.04, 1.0, prop_w), c + Vector4(0.06, tall - 0.25, 0.0, 0.0))
	var cy: float = tall - 1.05
	_box(cloth, Vector4(0.03, 1.55, 0.96, prop_w - 0.2), c + Vector4(0.08, cy, 0.0, 0.0))
	_box(cloth.darkened(0.3), Vector4(0.035, 0.06, 1.0, prop_w - 0.2), c + Vector4(0.08, cy - 0.78, 0.0, 0.0))
	var mid0: Vector4 = c + Vector4(0.1, cy + 0.15, 0.0, 0.0)
	for k in 4:
		var a: float = PI * 0.25 + PI * 0.5 * float(k)
		var mid := Vector4(0.0, cos(a) * 0.17, sin(a) * 0.17, 0.0)
		_box(gold, Vector4(0.035, 0.05, 0.27, prop_w - 0.25), mid0 + mid, _turn_x(a))
	_box(gold, Vector4(0.035, 0.09, 0.09, prop_w - 0.25), mid0, _turn_x(PI * 0.25))
	_solid(Vector4(0.3, tall, 1.4, prop_w), c + Vector4(0.0, tall * 0.5, 0.0, 0.0))


## A barrel: eight staves round (four boxes turned), three iron hoops and a lid.
func _barrel() -> void:
	var c: Vector4 = BARREL_AT
	var r: float = 0.32
	var h: float = 0.9
	var face: float = 2.0 * r * tan(PI / 8.0) * 1.03
	for k in 4:
		var t: float = PI * float(k) / 4.0
		_box(timber, Vector4(r * 2.0, h, face, prop_w * 0.6), c + Vector4(0.0, h * 0.5, 0.0, 0.0), _turn_y(t))
		for y in [0.15, 0.45, 0.75]:
			_box(iron, Vector4(r * 2.0 + 0.03, 0.05, face + 0.012, prop_w * 0.6 + 0.02), c + Vector4(0.0, y, 0.0, 0.0), _turn_y(t))
		_box(timber_dark, Vector4(r * 1.8, 0.04, face * 0.9, prop_w * 0.55), c + Vector4(0.0, h + 0.01, 0.0, 0.0), _turn_y(t))
	_solid(Vector4(0.7, h, 0.7, prop_w * 0.6), c + Vector4(0.0, h * 0.5, 0.0, 0.0))


## The rune stone: a dark base slab, a tapered light block on it, and in its top an iron plate with
## a glowing diamond. The button to the Quantum Range is a node beside it (pen_rune_stone_4d.gd).
func _rune_stone() -> void:
	var c: Vector4 = STONE_AT
	_box(stone_dark, Vector4(1.35, 0.14, 1.35, prop_w + 0.2), c + Vector4(0.0, 0.07, 0.0, 0.0))
	var block := BoxTetraMesh4D.new()
	block.size = Vector4(1.0, 0.95, 1.0, prop_w)
	var mesh: ArrayTetraMesh4D = block.to_array_tetra_mesh()
	var corners: PackedVector4Array = mesh.get_vertex_positions()
	for i in corners.size():
		if corners[i].y > 0.0:
			corners[i] = Vector4(corners[i].x * 0.74, corners[i].y, corners[i].z * 0.74, corners[i].w * 0.85)
	mesh.set_vertex_positions(corners)
	_merge(stone, mesh, c + Vector4(0.0, 0.14 + 0.475, 0.0, 0.0))
	var top_y: float = 0.14 + 0.95
	_disc_y(iron, c + Vector4(0.0, top_y + 0.015, 0.0, 0.0), 0.3, 0.03)
	_box(rune_glow, Vector4(0.3, 0.03, 0.3, prop_w * 0.6), c + Vector4(0.0, top_y + 0.035, 0.0, 0.0), _turn_y(PI * 0.25), true)
	_solid(Vector4(1.1, top_y, 1.1, prop_w), c + Vector4(0.0, top_y * 0.5, 0.0, 0.0))


## Grass clumps along the fences and the outcrop: three crossed blades of leaf each, so the yard's
## edges are green as the painting's are.
func _clumps(rng: RandomNumberGenerator) -> void:
	for k in 22:
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var at: Vector4
		if k < 14:
			at = Vector4(rng.randf_range(-length + 0.5, -0.5), 0.0, side * (half_width + rng.randf_range(-0.4, 0.5)), rng.randf_range(-0.6, 0.6))
		else:
			at = Vector4(-length - rng.randf_range(0.2, 0.9), 0.0, rng.randf_range(-half_width, half_width), rng.randf_range(-0.6, 0.6))
		var h: float = rng.randf_range(0.3, 0.6)
		for j in 3:
			_box(leaf.lerp(Color(0.48, 0.62, 0.2), rng.randf()), Vector4(0.06, h, 0.35, 0.3), at + Vector4(0.0, h * 0.5, 0.0, 0.0),
				_turn_y(PI * float(j) / 3.0 + rng.randf_range(0.0, 1.0)) * _turn_x(rng.randf_range(-0.25, 0.25)))


# --- Helpers ----------------------------------------------------------------------------------

## A round disc in the y-z plane (its face toward +x), [param r] across, [param t] thick in x.
func _disc(colour: Color, at: Vector4, r: float, t: float, glow: bool = false) -> void:
	var face: float = 2.0 * r * tan(PI / 12.0) * 1.03
	for k in 6:
		_box(colour, Vector4(t, r * 2.0, face, prop_w), at, _turn_x(PI * float(k) / 6.0), glow)


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


## A bar of square section [param thick] from [param a] to [param b].
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


## A turn about the x axis by [param t]: y toward z.
static func _turn_x(t: float) -> Projection:
	return Projection(Vector4(1.0, 0.0, 0.0, 0.0), Vector4(0.0, cos(t), sin(t), 0.0), Vector4(0.0, -sin(t), cos(t), 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


## A turn about the z axis by [param t]: x toward y.
static func _turn_z(t: float) -> Projection:
	return Projection(Vector4(cos(t), sin(t), 0.0, 0.0), Vector4(-sin(t), cos(t), 0.0, 0.0), Vector4(0.0, 0.0, 1.0, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


func _own(node: Node) -> void:
	node.set_meta(OWN, true)
	add_child(node)
