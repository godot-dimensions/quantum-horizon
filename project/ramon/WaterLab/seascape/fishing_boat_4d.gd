extends Node4D

## WATER LAB, THE SEA: a fishing boat riding the waves offshore (Ramon, 9 Oct, round 2: "these sort of
## rustic ... fisher ships ... white tones, maybe a little bit rusty ... some poles ... metal poles and
## things that it uses to carry the fish ... chunky little boat ... have it wobble on the waves a
## little bit and correspond to each wave manipulation. That way, as you turn the slice, we can also
## make that one be affected by 4D").
##
## AN INSHORE TRAWLER, the harbour kind: a beamy hull, the white topsides with a blue band over a
## rust-red bottom; a white wheelhouse forward with a dark window band and a grey roof; a mast on it
## with a cross-tree, a radar turning and a masthead light; two outrigger booms angled out from the
## mast; an A-frame gantry over the stern; a net drum on the after deck; blue fish crates; tyres hung
## along the sides; rust streaking down from the scuppers and the gantry's feet.
##
## BLOCKY, IN THE LAB'S WAY: the hull is boxes. The bottom steps in under the water line (the water's
## tint hides the steps), the topsides are white with a blue band, the bow is two boxes turned 45
## degrees meeting in a point, the stern a flat transom; bulwarks round a dark deck. (A rounded hull
## would want ConvexHullShape4D, which cannot make a mesh in this build: pen_rock_pile_4d.gd.)
##
## IT IS FOUR-DIMENSIONAL: everything is as deep in W as it is wide, so the boat is as broad in W as
## it is across, and a turned slice cuts it a different shape.
##
## RIDING THE SEA: the surface's own height (water4d_surface.gd height_at, the shader's waves solved on
## the CPU) at the bow, the stern, both sides and both W ends; the boat sits at their mean and leans to
## their slopes, so it pitches, rolls and tilts through W with each sea, eased a little.
##
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/WaterLab/carried/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/WaterLab/carried/LabKit/lab_grid.gd")

## ROUND 3 AND 4 (Ramon: "simplify the boats' visual treatment while preserving their existing
## geometric detail ... the Water Lab's existing gridline texture style ... The boat visible in the
## current active slice should be white with the grid texture. Boats visible in other slices should
## be orange"): every part in the lab grid, one swatch for the whole boat, white while the boat is
## in your slice and the pen's landmark orange (its dev look's saved colour, #F2754C) while it is
## not; only the windows, the tyres and the masthead light keep their own. `viewer` is the camera
## whose slice decides.
## Then (Ramon, 9 Oct: "about the white boat, his copies in W should not be orange. just other boats,
## and those need to be further away in the distance"): `tone` fixes a boat's swatch. The fleet
## gives the white boats and their W copies WHITE, the far boats in other slices ORANGE; empty
## leaves the slice deciding, as before.
const WHITE := "boat_white"
const ORANGE := "boat_orange"
@export var tone: String = ""
## Built simple, for a boat only ever seen far off: the hull, the wheelhouse, the mast, the booms,
## the gantry and the drum; no capping, rust, tyres, stays, crates or flanges (about 36 pieces fewer,
## each one a mesh the slicer handles every frame).
@export var simple: bool = false
static var _swatches_set: bool = false
var viewer: Node4D = null
var _grid: Array = []
var _tone: String = ""
var _tone_check: float = 0.0
## Whether it is near enough your slice to be seen (checked with the tone); a boat that is not rides
## the sea only twice a second (the far ones and the W copies: about 1.5 ms of a frame otherwise,
## seven height samples each), and snaps into place when it comes back.
var _near_slice: bool = true
var _idle: float = 0.0

## The sea (water4d_surface.gd).
var water: Node = null
## Its heading on the water (radians about y: 0 bow to +x).
@export var heading: float = PI * 0.5
## How much it swings at anchor, radians, and how slowly.
@export var swing: float = 0.12
@export var length: float = 11.0
@export var beam: float = 3.8
## How far the hull reaches under the water line, and the deck over it.
@export var draft: float = 1.3
@export var freeboard: float = 1.2

var _anchor := Vector4.ZERO
var _t: float = 0.0
var _y: float = 0.0
var _basis := Projection.IDENTITY
var _radar: Node4D
var _ready_done: bool = false


func _ready() -> void:
	_anchor = position
	_build()
	_ready_done = true


func _mat(c: Color) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_color = c
	return m


func _add(nm: String, mesh: Mesh4D, mat: TetraMaterial4D, at: Vector4 = Vector4.ZERO, b: Projection = Projection.IDENTITY) -> MeshInstance4D:
	var mi := MeshInstance4D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.basis = b
	add_child(mi)
	return mi


func _box(nm: String, at: Vector4, size: Vector4, c: Color, b: Projection = Projection.IDENTITY) -> MeshInstance4D:
	# The windows and the near-black bits keep their own colour; everything else wears the grid.
	if c.v < 0.15:
		return _add(nm, Mats.box_mesh(size), _mat(c), at, b)
	return _add(nm, Mats.box_mesh(size), _grid_mat(size, at), at, b)


## The lab grid in the boat's swatch (white to start), kept for re-tinting.
func _grid_mat(size: Vector4, at: Vector4) -> TetraMaterial4D:
	if not _swatches_set:
		_swatches_set = true
		# The kit's own contrast (kit_style.gd's walls: lines a sixth darker, at 0.6): Ramon, 9 Oct, "why
		# are the lines on the boat so thick, on the pier it looks like small lines". A line is never
		# drawn thinner than a pixel, so at the boats' distance a strong one reads as a thick one.
		LabGrid.set_swatch(WHITE, Color(0.92, 0.92, 0.90), Color(0.79, 0.80, 0.80), Color(0.88, 0.88, 0.87), 0.6)
		LabGrid.set_swatch(ORANGE, Color(0.949, 0.458, 0.298), Color(0.82, 0.39, 0.25), Color(0.91, 0.44, 0.285), 0.6)
	var m: TetraMaterial4D = LabGrid.material(WHITE, size, at)
	_grid.append(m)
	return m


## Its fixed tone, or white in your slice and orange off it (checked four times a second, swapped
## only on a change).
func _retone(delta: float) -> void:
	_tone_check -= delta
	if _tone_check > 0.0:
		return
	_tone_check = 0.25
	var d: float = 0.0
	if viewer != null and is_instance_valid(viewer):
		var wn: Vector4 = (viewer.global_basis * Vector4(0, 0, 0, 1)).normalized()
		d = absf((global_position - viewer.global_position).dot(wn))
	_near_slice = d < beam
	var want: String = tone
	if want.is_empty():
		want = WHITE if d < beam * 0.5 else ORANGE
	if want == _tone:
		return
	_tone = want
	for m in _grid:
		LabGrid.reswatch(m as TetraMaterial4D, want)


## One layer of the bow, from y0 to y1, `bw` wide: two boxes turned 45 degrees about the vertical,
## centred on the hull's line where the bow begins, so their outer corner is the stem.
func _bow(nm: String, x: float, y0: float, y1: float, bw: float, c: Color) -> void:
	var side: float = bw / sqrt(2.0)
	_box(nm, Vector4(x, (y0 + y1) * 0.5, 0.0, 0.0), Vector4(side, y1 - y0, side, bw), c, Basis4D.from_zx(PI * 0.25))


## A drum or a tyre: a cubinder round in x and y (its axis along z), `t` thick along z, as deep in W.
func _drum(nm: String, at: Vector4, r: float, t: float, wd: float, c: Color) -> MeshInstance4D:
	var shape := CubinderShape4D.new()
	shape.radius = r
	shape.height = t
	shape.thickness = wd
	# The cubinder is round in x-z with its height along y: turned a quarter in y-z, its height runs
	# along z.
	var mat: TetraMaterial4D = _mat(c) if c.v < 0.15 else _grid_mat(Vector4(r * 2.0, r * 2.0, t, wd), at)
	return _add(nm, shape.to_tetra_mesh({"segments": 20}), mat, at, Basis4D.from_yz(PI * 0.5))


func _build() -> void:
	var white := Color(0.90, 0.90, 0.87)
	var red := Color(0.46, 0.14, 0.10)
	var blue := Color(0.10, 0.27, 0.48)
	var rust := Color(0.52, 0.26, 0.12)
	var grey := Color(0.46, 0.48, 0.50)
	var dark := Color(0.08, 0.10, 0.12)
	var deck_c := Color(0.30, 0.36, 0.33)
	# The hull. The midbody from the transom to where the bow begins; the bow, two boxes turned 45
	# degrees about the vertical, their outer faces meeting at the stem.
	var bow_at: float = length * 0.5 - beam * 0.5
	var body_len: float = bow_at + length * 0.5
	var body_x: float = (bow_at - length * 0.5) * 0.5
	var steps: Array = [[-draft, -draft * 0.72, 0.5], [-draft * 0.72, -draft * 0.36, 0.78], [-draft * 0.36, 0.12, 0.95]]
	for st in steps:
		var y0: float = float(st[0])
		var y1: float = float(st[1])
		var bw: float = beam * float(st[2])
		_box("Bottom", Vector4(body_x, (y0 + y1) * 0.5, 0.0, 0.0), Vector4(body_len, y1 - y0, bw, bw), red)
		_bow("BowBottom", bow_at, y0, y1, bw, red)
	var bands: Array = [[0.12, freeboard * 0.55, white], [freeboard * 0.55, freeboard * 0.72, blue], [freeboard * 0.72, freeboard, white]]
	for bd in bands:
		_box("Topsides", Vector4(body_x, (float(bd[0]) + float(bd[1])) * 0.5, 0.0, 0.0), Vector4(body_len, float(bd[1]) - float(bd[0]), beam, beam), bd[2])
		_bow("Bow", bow_at, float(bd[0]), float(bd[1]), beam, bd[2])
	# The bow's bulwark, a little higher (the sheer rises forward).
	_bow("BowBulwark", bow_at, freeboard, freeboard + 0.75, beam, white)
	# The deck, inside the bulwarks, and the bulwarks along the sides and across the stern.
	_box("Deck", Vector4(body_x, freeboard + 0.01, 0.0, 0.0), Vector4(body_len - 0.2, 0.04, beam - 0.24, beam - 0.24), deck_c)
	for side in [-1.0, 1.0]:
		_box("Bulwark", Vector4(body_x, freeboard + 0.3, side * (beam * 0.5 - 0.06), 0.0), Vector4(body_len, 0.6, 0.12, beam), white)
	_box("Transom", Vector4(-length * 0.5 + 0.06, freeboard + 0.3, 0.0, 0.0), Vector4(0.12, 0.6, beam, beam), white)
	for side in ([] if simple else [-1.0, 1.0]):
		_box("Capping", Vector4(-0.9, freeboard + 0.02, side * (beam * 0.5 + 0.02), 0.0), Vector4(length * 0.62, 0.07, 0.09, 0.4), rust)
		# Rust running down from the scuppers.
		for k in 5:
			var x: float = lerpf(-length * 0.38, length * 0.18, float(k) / 4.0)
			var h: float = 0.35 + 0.25 * float(k % 2)
			_box("Rust", Vector4(x, freeboard - h * 0.5, side * (beam * 0.5 + 0.035), 0.0), Vector4(0.07, h, 0.02, 0.3), rust)
		# Tyres hung along the side.
		for k in 4:
			var tx: float = lerpf(-length * 0.32, length * 0.12, float(k) / 3.0)
			_drum("Tyre", Vector4(tx, freeboard * 0.42, side * (beam * 0.5 + 0.12), 0.0), 0.3, 0.16, 0.6, dark)
	# The wheelhouse, forward of midships.
	var wh := Vector4(length * 0.12, 0.0, 0.0, 0.0)
	var ww: float = beam * 0.62
	_box("Wheelhouse", wh + Vector4(0.0, freeboard + 1.05, 0.0, 0.0), Vector4(2.6, 2.1, ww, ww), white)
	_box("Windows", wh + Vector4(0.0, freeboard + 1.55, 0.0, 0.0), Vector4(2.64, 0.55, ww + 0.04, ww + 0.04), dark)
	_box("Roof", wh + Vector4(0.0, freeboard + 2.17, 0.0, 0.0), Vector4(2.9, 0.14, ww + 0.3, ww + 0.3), grey)
	_box("Stack", wh + Vector4(-1.6, freeboard + 1.6, 0.6, 0.0), Vector4(0.45, 1.6, 0.45, 0.45), white)
	if not simple:
		_box("StackTop", wh + Vector4(-1.6, freeboard + 2.45, 0.6, 0.0), Vector4(0.48, 0.12, 0.48, 0.48), dark)
	# The mast on the roof: a cross-tree, the radar, the masthead light.
	var mast := wh + Vector4(-0.4, freeboard + 2.24, 0.0, 0.0)
	_box("Mast", mast + Vector4(0.0, 2.0, 0.0, 0.0), Vector4(0.16, 4.0, 0.16, 0.16), grey)
	_box("CrossTree", mast + Vector4(0.0, 3.1, 0.0, 0.0), Vector4(0.1, 0.1, 1.8, 0.3), grey)
	_radar = Node4D.new()
	_radar.name = "Radar"
	_radar.position = mast + Vector4(0.0, 2.5, 0.0, 0.0)
	add_child(_radar)
	var bar := MeshInstance4D.new()
	bar.mesh = Mats.box_mesh(Vector4(1.3, 0.1, 0.22, 0.22))
	bar.material_override = _grid_mat(Vector4(1.3, 0.1, 0.22, 0.22), Vector4.ZERO)
	_radar.add_child(bar)
	_add("Masthead", Mats.box_mesh(Vector4(0.18, 0.22, 0.18, 0.18)), Mats.glow(Color(1.0, 0.96, 0.85), 1.6), mast + Vector4(0.0, 4.1, 0.0, 0.0))
	# The outrigger booms: out from the mast's foot, up and out to each side, and their stays.
	for side in [-1.0, 1.0]:
		var foot := wh + Vector4(-0.9, freeboard + 0.1, side * 0.5, 0.0)
		var tip := foot + Vector4(0.0, 4.6, side * 3.6, 0.0)
		_rod("Boom", foot, tip, 0.13, grey)
		if not simple:
			_rod("Stay", tip, mast + Vector4(0.0, 3.9, 0.0, 0.0), 0.03, dark)
			_box("BoomRust", foot + (tip - foot) * 0.15, Vector4(0.15, 0.3, 0.15, 0.15), rust)
	# The A-frame over the stern.
	var stern_x: float = -length * 0.5 + 0.35
	for side in [-1.0, 1.0]:
		var base := Vector4(stern_x + 0.4, freeboard, side * (beam * 0.5 - 0.35), 0.0)
		var top := Vector4(stern_x - 0.5, freeboard + 3.2, side * (beam * 0.5 - 0.5), 0.0)
		_rod("Gantry", base, top, 0.2, Color(0.30, 0.42, 0.56))
		if not simple:
			_box("GantryRust", base + Vector4(0.0, 0.3, 0.0, 0.0), Vector4(0.24, 0.5, 0.24, 0.24), rust)
	_box("GantryTop", Vector4(stern_x - 0.5, freeboard + 3.2, 0.0, 0.0), Vector4(0.24, 0.24, beam - 0.7, 0.3), Color(0.30, 0.42, 0.56))
	# The net drum and the crates on the after deck.
	_drum("NetDrum", Vector4(-length * 0.26, freeboard + 0.7, 0.0, 0.0), 0.62, beam * 0.6, 0.9, Color(0.16, 0.30, 0.22))
	if simple:
		return
	_box("Block", Vector4(stern_x - 0.5, freeboard + 2.85, 0.0, 0.0), Vector4(0.3, 0.4, 0.3, 0.3), dark)
	for side in [-1.0, 1.0]:
		_drum("DrumFlange", Vector4(-length * 0.26, freeboard + 0.7, side * beam * 0.31, 0.0), 0.72, 0.06, 0.9, grey)
	for k in 6:
		var cx: float = -length * 0.08 - float(k % 3) * 0.62
		var cz: float = (float(k / 3) - 0.5) * 0.9 - 0.4
		_box("Crate", Vector4(cx, freeboard + 0.2 + 0.36 * float(k % 2), cz, 0.0), Vector4(0.58, 0.34, 0.42, 0.42), Color(0.12, 0.40, 0.66))


## A straight rod from a to b, `t` thick (a box along it, as deep in W as it is thick).
func _rod(nm: String, a: Vector4, b: Vector4, t: float, c: Color) -> void:
	var d: Vector4 = b - a
	var L: float = d.length()
	if L < 0.001:
		return
	var x: Vector4 = d / L
	# Two more axes square to it in x-y-z, and W.
	var helper := Vector4(0, 0, 1, 0) if absf(x.z) < 0.9 else Vector4(1, 0, 0, 0)
	var y: Vector4 = helper - x * helper.dot(x)
	y = y.normalized()
	var z := Vector4(x.y * y.z - x.z * y.y, x.z * y.x - x.x * y.z, x.x * y.y - x.y * y.x, 0.0)
	var b4 := Projection(x, y, z, Vector4(0, 0, 0, 1))
	_box(nm, (a + b) * 0.5, Vector4(L, t, t, t), c, b4)


# -- riding the sea -------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _ready_done:
		return
	_retone(delta)
	_t += delta
	if _radar != null:
		_radar.basis = Basis4D.from_zx(_t * 1.6)
	if water == null or not water.has_method("height_at"):
		return
	var snap: bool = _t <= 0.2
	if not _near_slice:
		_idle += delta
		if _idle < 0.5:
			return
		_idle = 0.0
		snap = true
	elif _idle > 0.0:
		_idle = 0.0
		snap = true
	var yaw: float = heading + sin(_t * 0.07) * swing
	var f := Vector4(cos(yaw), 0.0, sin(yaw), 0.0)
	var side := Vector4(-sin(yaw), 0.0, cos(yaw), 0.0)
	var a: Vector4 = _anchor
	var at := func(p: Vector4) -> float: return float(water.call("height_at", Vector3(p.x, p.z, p.w)))
	var hl: float = length * 0.38
	var hb: float = beam * 0.5
	var bow: float = at.call(a + f * hl)
	var stern: float = at.call(a - f * hl)
	var port: float = at.call(a + side * hb)
	var stbd: float = at.call(a - side * hb)
	var ana: float = at.call(a + Vector4(0, 0, 0, hb))
	var kata: float = at.call(a - Vector4(0, 0, 0, hb))
	var mid: float = at.call(a)
	var y: float = (bow + stern + port + stbd + ana + kata + mid * 2.0) / 8.0
	# The axes from the sampled slopes (a boat this size lags the water: halved), made square.
	var fx: Vector4 = (f * (hl * 2.0) + Vector4(0, (bow - stern) * 0.5, 0, 0)).normalized()
	var sx: Vector4 = side * (hb * 2.0) + Vector4(0, (port - stbd) * 0.5, 0, 0)
	var wx: Vector4 = Vector4(0, 0, 0, hb * 2.0) + Vector4(0, (ana - kata) * 0.5, 0, 0)
	sx = (sx - fx * sx.dot(fx)).normalized()
	wx = (wx - fx * wx.dot(fx) - sx * wx.dot(sx)).normalized()
	var up := Vector4(0, 1, 0, 0)
	up = (up - fx * up.dot(fx) - sx * up.dot(sx) - wx * up.dot(wx)).normalized()
	var want := Projection(fx, up, sx, wx)
	var k: float = 1.0 - exp(-delta * 2.5)
	_y = y if snap else lerpf(_y, y, k)
	_basis = want if snap else _lerp_basis(_basis, want, k)
	position = Vector4(a.x, _y, a.z, a.w)
	basis = _basis


## Eased toward `b` column by column, then made square again.
static func _lerp_basis(a: Projection, b: Projection, k: float) -> Projection:
	var x: Vector4 = a.x.lerp(b.x, k).normalized()
	var y: Vector4 = a.y.lerp(b.y, k)
	y = (y - x * y.dot(x)).normalized()
	var z: Vector4 = a.z.lerp(b.z, k)
	z = (z - x * z.dot(x) - y * z.dot(y)).normalized()
	var w: Vector4 = a.w.lerp(b.w, k)
	w = (w - x * w.dot(x) - y * w.dot(y) - z * w.dot(z)).normalized()
	return Projection(x, y, z, w)
