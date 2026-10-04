@tool
extends Node4D

## Kit: the research panel. A long, thin slab with rounded corners floating over the floor and
## tilted towards you: a white frame round a blue screen and a glowing line along its underside
## (Ramon, 4 Oct, from his concept sheet: "make a floating panel like the first top in the ref";
## "not centered but offset on the left side, like something you could walk to for more info";
## "place info floater higher"; "rounded edges"). It stands and faces as its node does (move and
## turn it with the editor's gizmo).
##
## WALK UP and the room pops up a key prompt over it (kit_prompt.gd); the engage key or a click
## opens the 2D data panel (goat_room_4d.gd). set_near() tells it you are there.
##
## THE SCREEN IS A UI MADE OF PARTS, not a picture (Ramon, 4 Oct: "it is still a rasterized image,
## I wanted it to be a dynamically designed UI almost"): rounded cards standing a few millimetres
## proud of the screen, each with its own crisp print (mipmapped, so it holds up from across the
## room), and the live things as real pieces that move:
##   the title, a pulsing LIVE light
##   the exhibit card     its wireframe printed (kit_glyphs wire), a glowing dot on every ball,
##                        bright while the build has it, dim before
##   four tiles           their numbers printed afresh when they change: balls in view,
##                        tetrahedra now, build stage now, the slice's offset
##   Slice through W      the W profile as a row of bars, the slice stops, and a glowing line
##                        gliding to wherever the slice you see cuts
##   Build stage by stage a bar per stage, easing to its height, the stage on show lifted and white
## The physics is a row of upright boxes under it, square to the world (box-only physics).
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/LabChambers/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")
const Glyphs := preload("res://ramon/LabChambers/kit/kit_glyphs.gd")
const Batch := preload("res://ramon/LabKit/lab_batch.gd")
const SLAB := 0.08
const SCREEN := 0.02
const CARD := 0.008
## The screen's layout was drawn for this screen depth; others scale it.
const DRAWN_FOR := 1.09
## Print sharpness, pixels a metre.
const PPM := 420.0
const WHITE := Color(1, 1, 1)
const CYAN := Color(0.52, 0.84, 1.0)

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var showcase: NodePath
## The way its face looks, in the world (x, z), if set: the node turns itself to it. Left at zero,
## the node's own rotation (the editor's rotate gizmo) decides.
@export var face: Vector3 = Vector3.ZERO:
	set(v):
		face = v
		_turn()
## How far it leans back towards you, in degrees from flat.
@export_range(0.0, 60.0, 1.0) var tilt_degrees: float = 18.0:
	set(v):
		tilt_degrees = v
		_later()
## Across, and front to back, in metres.
@export var size: Vector2 = Vector2(3.4, 1.25):
	set(v):
		size = v
		_later()
## How high its front edge floats over the floor, in metres.
@export_range(0.1, 1.5, 0.01) var hover: float = 0.85:
	set(v):
		hover = v
		_later()
## The radius of its rounded corners, in metres.
@export_range(0.0, 0.4, 0.01) var corner: float = 0.14:
	set(v):
		corner = v
		_later()
@export var title: String = "Research data"

var _glow: Array = []
var _queued: bool = false
var _sw: float = 3.24
var _sh: float = 1.09
var _near: bool = false
var _open: bool = false
var _clock: float = 0.0
# The screen's parts, in the screen's own space (x right, z towards you, y up off it).
var _ui: Node4D
var _base: MeshInstance4D
var _built: bool = false
var _data: Dictionary = {}
var _profile: Dictionary = {}
var _stops: Array = []
var _shape: Dictionary = {}
var _dots: Array = []
var _bars: Array = []
var _bar_h: Array = []
var _bar_base: float = 0.0
var _bar_max: float = 0.0
var _ticks: Array = []
var _marker: MeshInstance4D
var _band: Rect2 = Rect2()
var _live: MeshInstance4D
var _values: Array = []
var _shown_values: Array = ["", "", "", ""]
var _value_wait: float = 0.0
var _printing: Dictionary = {}


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")
	add_to_group("kit_desk")


func _ready() -> void:
	rebuild()


func _later() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func _turn() -> void:
	var f := Vector2(face.x, face.z)
	if f.length() < 0.001:
		return
	basis = Basis4D.from_zx(atan2(f.x, f.y))


func rebuild() -> void:
	_turn()
	Build.clear(self)
	_glow = []
	_built = false
	_dots = []
	_bars = []
	_bar_h = []
	_ticks = []
	_values = []
	_shown_values = ["", "", "", ""]
	var th: float = deg_to_rad(tilt_degrees)
	var w: float = size.x
	var d: float = size.y
	var origin: Vector4 = global_position if is_inside_tree() else Vector4.ZERO
	# The slab, tilted about its own middle so its front edge floats `hover` over the floor.
	var slab := Node4D.new()
	slab.name = "Slab"
	slab.position = Vector4(0.0, hover + d * 0.5 * sin(th) + SLAB * 0.5 * cos(th), 0.0, 0.0)
	slab.basis = Basis4D.from_yz(th)
	slab.set_meta(Build.GENERATED, true)
	add_child(slab)
	_rounded(slab, "Frame", Vector2(w, d), SLAB, 0.0, corner, "kit_bezel", origin)
	var margin: float = 0.08
	_sw = w - margin * 2.0
	_sh = d - margin * 2.0
	var rs: float = maxf(corner - margin * 0.6, 0.02)
	_base = _rounded(slab, "Screen", Vector2(_sw, _sh), SCREEN, SLAB * 0.5 + SCREEN * 0.5 + 0.002, rs, "kit_screen", origin)
	_ui = Node4D.new()
	_ui.name = "UI"
	_ui.position = Vector4(0.0, SLAB * 0.5 + SCREEN + 0.002, 0.0, 0.0)
	slab.add_child(_ui)
	# A glowing line round the underside, set in from the edge.
	var under: float = -SLAB * 0.5 - 0.008
	var inset: float = corner + 0.04
	for g in [[Vector3(0, under, d * 0.5 - 0.05), Vector3(w - inset * 2.0, 0.016, 0.03)], [Vector3(-w * 0.5 + 0.05, under, 0), Vector3(0.03, 0.016, d - inset * 2.0)],
			[Vector3(w * 0.5 - 0.05, under, 0), Vector3(0.03, 0.016, d - inset * 2.0)], [Vector3(0, under, -d * 0.5 + 0.05), Vector3(w - inset * 2.0, 0.016, 0.03)]]:
		var at2: Vector3 = g[0]
		var sz2: Vector3 = g[1]
		var line := MeshInstance4D.new()
		line.name = "Underglow"
		line.mesh = Mats.box_mesh(Vector4(sz2.x, sz2.y, sz2.z, Build.W_DEPTH))
		line.position = Vector4(at2.x, at2.y, at2.z, 0.0)
		slab.add_child(line)
		_glow.append(line)
	# The physics: a row of upright boxes along the slab, each kept square to the world.
	var high: float = hover + d * sin(th) + SLAB
	var fwd: Vector4 = (global_basis if is_inside_tree() else basis) * Vector4(0, 0, 1, 0)
	var square: Projection = Basis4D.from_zx(-atan2(fwd.x, fwd.z))
	var cell: float = minf(d * cos(th), 0.8)
	var count: int = maxi(1, int(ceil(w / (cell * 0.7))))
	for i in count:
		var body := StaticBody4D.new()
		body.name = "Body%d" % i
		var lx: float = lerpf(-w * 0.5 + cell * 0.5, w * 0.5 - cell * 0.5, float(i) / maxf(float(count - 1), 1.0))
		body.position = Vector4(lx, high * 0.5, 0.0, 0.0)
		body.basis = square
		var shape := CollisionShape4D.new()
		var bs := BoxShape4D.new()
		bs.size = Vector4(cell, high, cell, Build.W_DEPTH)
		shape.shape = bs
		body.add_child(shape)
		body.set_meta(Build.GENERATED, true)
		add_child(body)
	_paint_parts()


## A rounded plate `s` (x, z) by `t` thick, `y` up its parent at `at` (x, z): a box the full width
## with the corners' depth taken off, a box the full depth with their width taken off, and a
## cylinder in each corner. The second box sits a hair lower, so where the two overlap only the
## first one shows. Returns the first (the one a print goes on).
func _rounded(parent: Node4D, nm: String, s: Vector2, t: float, y: float, r: float, swatch: String, origin: Vector4, at: Vector2 = Vector2.ZERO) -> MeshInstance4D:
	var a := MeshInstance4D.new()
	a.name = nm
	var sa := Vector4(s.x, t, s.y - r * 2.0, Build.W_DEPTH)
	a.mesh = Mats.box_mesh(sa)
	a.position = Vector4(at.x, y, at.y, 0.0)
	a.material_override = LabGrid.material(swatch, sa, origin)
	parent.add_child(a)
	if r <= 0.001:
		return a
	var b := MeshInstance4D.new()
	b.name = nm + "Ends"
	var sb := Vector4(s.x - r * 2.0, t - 0.002, s.y, Build.W_DEPTH)
	b.mesh = Mats.box_mesh(sb)
	b.position = Vector4(at.x, y - 0.001, at.y, 0.0)
	b.material_override = LabGrid.material(swatch, sb, origin)
	parent.add_child(b)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var c := MeshInstance4D.new()
			c.name = nm + "Corner"
			c.mesh = Build._cubinder(r, t - 0.002, 24)
			c.position = Vector4(at.x + cx * (s.x * 0.5 - r), y - 0.001, at.y + cz * (s.y * 0.5 - r), 0.0)
			c.material_override = LabGrid.material(swatch, Vector4(r * 2.0, t, r * 2.0, Build.W_DEPTH), origin)
			parent.add_child(c)
	return a


func _paint_parts() -> void:
	var c: Color = Style.pick(Style.COVE)
	for g in _glow:
		if is_instance_valid(g):
			(g as MeshInstance4D).material_override = Mats.glow(c, 1.8)


## The room says whether you stand at it and whether the data is open.
func set_near(near_it: bool, open: bool = false) -> void:
	_near = near_it
	_open = open


## Where you stand to read it: in front of it, within its width.
func near(p: Vector4) -> bool:
	var l: Vector4 = global_basis.inverse() * (p - global_position)
	return absf(l.x) < size.x * 0.5 + 0.4 and l.z > size.y * 0.5 - 0.1 and l.z < size.y * 0.5 + 2.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _ui == null:
		return
	_clock += delta
	var sc: Node = get_node_or_null(showcase)
	if sc == null:
		return
	if not _built:
		if _data.is_empty():
			_data = sc.call("data")
		if _profile.is_empty() and sc.has_method("profile"):
			_profile = sc.call("profile")
			_stops = sc.call("slice_stops") if sc.has_method("slice_stops") else []
		if _shape.is_empty() and sc.has_method("shape"):
			_shape = sc.call("shape")
		if not _data.is_empty() and not _profile.is_empty():
			_built = true
			_build_ui()
		return
	_animate(sc, delta)


# -- the screen's layout ---------------------------------------------------------------------------

## The layout in metres from the screen's top-left (the far edge, as you read it), scaled to its
## depth.
func _layout() -> Dictionary:
	var s: float = _sh / DRAWN_FOR
	var mg: float = 0.06
	var right0: float = 1.08 * s
	var right1: float = _sw - mg
	var mid: float = (right0 + right1) * 0.5
	var card_y: float = 0.5 * s
	return {"s": s, "mg": mg, "right0": right0, "right1": right1, "mid": mid, "card_y": card_y,
		"goat": Rect2(Vector2(mg, 0.18 * s), Vector2(right0 - mg - 0.06, 0.86 * s)),
		"slice": Rect2(Vector2(right0, card_y), Vector2(mid - 0.025 - right0, 0.54 * s)),
		"build": Rect2(Vector2(mid + 0.025, card_y), Vector2(right1 - mid - 0.025, 0.54 * s)),
		"tile_y": 0.18 * s, "tile_h": 0.27 * s}


## A point of the layout (metres from the top-left) in the UI node's space, `lift` off the screen.
func _at(p: Vector2, lift: float) -> Vector4:
	return Vector4(p.x - _sw * 0.5, lift, p.y - _sh * 0.5, 0.0)


## A box over layout rect `r`, `t` thick, standing `lift` off the screen.
func _box(nm: String, r: Rect2, t: float, lift: float, material: Material4D) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(Vector4(r.size.x, t, r.size.y, Build.W_DEPTH))
	m.position = _at(r.get_center(), lift + t * 0.5)
	m.material_override = material
	_ui.add_child(m)
	return m


## A card: a rounded plate over layout rect `r`, a few millimetres proud of the screen, with
## `paint` printed on it (crisp, mipmapped). Returns the plate.
func _card(nm: String, r: Rect2, paint: Callable) -> MeshInstance4D:
	var rr: float = 0.03
	var plate: MeshInstance4D = _rounded(_ui, nm, r.size, CARD, CARD * 0.5, rr, "kit_card", global_position,
		Vector2(r.get_center().x - _sw * 0.5, r.get_center().y - _sh * 0.5))
	_print(plate, r.size, Rect2(Vector2(0.0, -rr), r.size), paint)
	return plate


## Prints `paint` (drawn on a canvas `size_m` metres at PPM) on `box`'s top face, over `rect`.
func _print(box: MeshInstance4D, size_m: Vector2, rect: Rect2, paint: Callable) -> void:
	var tex: Texture2D = await LabPrint.render(get_tree(), Vector2i(int(size_m.x * PPM), int(size_m.y * PPM)), paint)
	if tex == null or not is_instance_valid(box):
		return
	LabGrid.set_print(box.material_override as TetraMaterial4D, tex, Vector4(0, 1, 0, 0), rect, Color.WHITE, 0.8)


# -- building it -----------------------------------------------------------------------------------

func _build_ui() -> void:
	var lay: Dictionary = _layout()
	var s: float = float(lay["s"])
	var st: Dictionary = _data.get("stats", {})
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var soft := Color(0.88, 0.94, 1.0, 0.92)
	var mg: float = float(lay["mg"])
	var r1: float = float(lay["right1"])
	# The title and LIVE, printed on the screen itself (its printed box is short of the corners).
	var rs: float = maxf(corner - 0.08 * 0.6, 0.02)
	_print(_base, Vector2(_sw, _sh), Rect2(Vector2(0.0, -rs), Vector2(_sw, _sh)), func(c: Control) -> void:
		var k: float = c.size.x / _sw
		c.draw_string(fb, Vector2(mg * k, 0.13 * s * k), title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.075 * s * k), WHITE)
		var lw: float = fs.get_string_size("LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.04 * s * k)).x
		c.draw_string(fs, Vector2(r1 * k - lw, 0.115 * s * k), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.04 * s * k), soft))
	_live = _box("Live", Rect2(Vector2(r1 - 0.17, 0.085 * s), Vector2(0.03, 0.03)), 0.01, 0.0, Mats.glow(Color(0.45, 1.0, 0.62), 1.5))
	# The exhibit card: its wireframe printed, a dot on every ball.
	var gr: Rect2 = lay["goat"]
	var art := Rect2(Vector2(0.04, 0.04), Vector2(gr.size.x - 0.08, gr.size.y - 0.16))
	var geo: Dictionary = Glyphs.wire_geometry(Rect2(art.position * PPM, art.size * PPM), _shape)
	var balls_n: int = int(st.get("balls", 0))
	_card("GoatCard", gr, func(c: Control) -> void:
		Glyphs.wire_draw(c, geo, Color(0.80, 0.92, 1.0, 0.75), Color(1, 1, 1, 0.0), Color(0.70, 0.88, 1.0, 0.16), 0)
		c.draw_string(fl, Vector2(0.04 * PPM, (gr.size.y - 0.045) * PPM), "Goat 01, lofted from %d balls" % balls_n, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.034 * PPM), soft))
	for p in (geo.get("balls", PackedVector2Array()) as PackedVector2Array):
		var lp: Vector2 = gr.position + p / PPM
		_dots.append(_box("Dot", Rect2(lp - Vector2(0.011, 0.011), Vector2(0.022, 0.022)), 0.008, CARD, Mats.glow(WHITE, 1.4)))
	# Four tiles: a printed caption and icon, and a value plate printed when it changes.
	var tiles: Array = [["ball", "Balls in view"], ["tetra", "Tetrahedra now"], ["stages", "Build stage"], ["axes", "Slice, of %.2f m reach" % float(st.get("reach", 0.0))]]
	var right0: float = float(lay["right0"])
	var gap: float = 0.05
	var tw: float = (r1 - right0 - gap * 3.0) / 4.0
	for i in tiles.size():
		var t: Array = tiles[i]
		var rect := Rect2(Vector2(right0 + (tw + gap) * float(i), float(lay["tile_y"])), Vector2(tw, float(lay["tile_h"])))
		_card("Tile%d" % i, rect, func(c: Control) -> void:
			var ic: float = 0.11 * PPM
			Glyphs.icon(c, String(t[0]), Rect2(Vector2(0.04, 0.035) * PPM, Vector2(ic, ic)), CYAN)
			c.draw_string(fl, Vector2(0.19 * PPM, (rect.size.y - 0.05) * PPM), String(t[1]), HORIZONTAL_ALIGNMENT_LEFT, (tw - 0.21) * PPM, int(0.034 * PPM), soft))
		var vr := Rect2(rect.position + Vector2(0.18, 0.04), Vector2(tw - 0.21, 0.12))
		var plate: MeshInstance4D = _box("Value%d" % i, vr, 0.004, CARD, LabGrid.material("kit_card", Vector4(vr.size.x, 0.004, vr.size.y, Build.W_DEPTH), global_position))
		_values.append([plate, vr.size])
	# Slice through W: the card, the profile as bars, the stops, the gliding line.
	var sr: Rect2 = lay["slice"]
	_card("SliceCard", sr, func(c: Control) -> void:
		c.draw_string(fs, Vector2(0.05, 0.08) * PPM, "Slice through W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.042 * PPM), WHITE)
		c.draw_string(fl, Vector2(0.05 * PPM, (sr.size.y - 0.05) * PPM), "-W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.034 * PPM), soft)
		c.draw_string(fl, Vector2(0.05 * PPM, (sr.size.y - 0.05) * PPM), "+W", HORIZONTAL_ALIGNMENT_RIGHT, (sr.size.x - 0.1) * PPM, int(0.034 * PPM), soft)
		c.draw_string(fl, Vector2(0.05 * PPM, (sr.size.y - 0.05) * PPM), "The line is the slice you see", HORIZONTAL_ALIGNMENT_CENTER, (sr.size.x - 0.1) * PPM, int(0.034 * PPM), soft))
	_band = Rect2(sr.position + Vector2(0.06, 0.12), Vector2(sr.size.x - 0.12, 0.22))
	var bins: PackedFloat32Array = _profile.get("bins", PackedFloat32Array())
	if bins.size() > 1:
		var pb := Batch.new()
		var step: float = _band.size.x / float(bins.size())
		for i in bins.size():
			var hh: float = maxf(0.004, _band.size.y * float(bins[i]))
			pb.box("p", Vector4(step * 0.62, 0.006, hh, Build.W_DEPTH), _at(Vector2(_band.position.x + step * (float(i) + 0.5), _band.get_center().y), CARD + 0.004))
		var prof: MeshInstance4D = pb.instance("p")
		prof.name = "Profile"
		prof.material_override = Mats.glow(CYAN, 0.6)
		_ui.add_child(prof)
	for i in _stops.size():
		var x: float = _band.position.x + _band.size.x * (float(_stops[i]) * 0.5 + 0.5)
		_ticks.append(_box("Tick", Rect2(Vector2(x - 0.004, _band.end.y + 0.02), Vector2(0.008, 0.03)), 0.006, CARD, Mats.glow(CYAN, 0.6)))
	_marker = _box("SliceLine", Rect2(Vector2(_band.get_center().x - 0.008, _band.position.y - 0.02), Vector2(0.016, _band.size.y + 0.04)), 0.012, CARD, Mats.glow(WHITE, 2.0))
	# Build stage by stage: the card, a bar a stage.
	var br: Rect2 = lay["build"]
	var bars: Array = _data.get("bars", [])
	_card("BuildCard", br, func(c: Control) -> void:
		c.draw_string(fs, Vector2(0.05, 0.08) * PPM, "Build stage by stage", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.042 * PPM), WHITE)
		var bw: float = (br.size.x - 0.1) / float(maxi(bars.size(), 1))
		for i in bars.size():
			c.draw_string(fl, Vector2((0.05 + bw * float(i)) * PPM, (br.size.y - 0.04) * PPM), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, bw * PPM, int(0.032 * PPM), soft))
	_bar_base = br.end.y - 0.085
	_bar_max = br.size.y - 0.21
	var most: float = 0.0001
	for b in bars:
		most = maxf(most, float(b))
	var bw2: float = (br.size.x - 0.1) / float(maxi(bars.size(), 1))
	for i in bars.size():
		var x0: float = br.position.x + 0.05 + bw2 * float(i) + bw2 * 0.18
		var bar := _box("Bar%d" % i, Rect2(Vector2(x0, _bar_base - 1.0), Vector2(bw2 * 0.64, 1.0)), 0.01, CARD, Mats.glow(CYAN, 0.5))
		_bars.append([bar, float(bars[i]) / most])
		_bar_h.append(0.0)


# -- moving it -------------------------------------------------------------------------------------

func _animate(sc: Node, delta: float) -> void:
	var ex: Node = sc.get("exhibit")
	var st: Dictionary = _data.get("stats", {})
	var balls_now: int = int(ex.call("balls_in_view")) if ex != null and ex.has_method("balls_in_view") else int(st.get("balls", 0))
	var stage_now: int = int(ex.call("stage_in_view")) if ex != null and ex.has_method("stage_in_view") else -1
	# The live light breathes.
	if is_instance_valid(_live):
		var k: float = 0.75 + 0.35 * sin(_clock * 4.0)
		_live.basis = _scale(Vector3(k, 1.0, k))
	# The balls the build has are lit.
	for i in _dots.size():
		_set_mat(_dots[i], Mats.glow(WHITE, 1.4) if i < balls_now else Mats.glow(Color(0.55, 0.75, 1.0), 0.25))
	# The slice line glides; the stop it is at is picked out.
	var frac: float = float(sc.call("slice_fraction")) if sc.has_method("slice_fraction") else 0.0
	if is_instance_valid(_marker):
		var want: Vector4 = _at(Vector2(_band.position.x + _band.size.x * (frac * 0.5 + 0.5), _band.get_center().y), CARD + 0.006)
		_marker.position = _marker.position.lerp(want, 1.0 - exp(-12.0 * delta))
	var lit: int = int(sc.get("slice_index"))
	for i in _ticks.size():
		var on2: bool = i == lit
		_set_mat(_ticks[i], Mats.glow(WHITE, 1.6) if on2 else Mats.glow(CYAN, 0.6))
		(_ticks[i] as MeshInstance4D).basis = _scale(Vector3(1.6 if on2 else 1.0, 1.0, 1.5 if on2 else 1.0))
	# The bars ease to their heights; the stage on show stands taller and white.
	for i in _bars.size():
		var bar: MeshInstance4D = _bars[i][0]
		var on3: bool = i == stage_now
		var want_h: float = maxf(0.006, _bar_max * float(_bars[i][1]) * (1.08 if on3 else 1.0))
		_bar_h[i] = lerpf(float(_bar_h[i]), want_h, 1.0 - exp(-6.0 * delta))
		var h: float = float(_bar_h[i])
		bar.basis = _scale(Vector3(1.0, 1.6 if on3 else 1.0, h))
		bar.position = Vector4(bar.position.x, CARD + 0.005 * (1.6 if on3 else 1.0), _bar_base - h * 0.5 - _sh * 0.5, 0.0)
		_set_mat(bar, Mats.glow(WHITE, 1.3) if on3 else Mats.glow(CYAN, 0.5))
	# The tiles' numbers, printed afresh when they change (a few times a second at most).
	_value_wait -= delta
	if _value_wait <= 0.0:
		_value_wait = 0.25
		var bars_d: Array = _data.get("bars", [])
		var tetra_now: int = int(bars_d[stage_now]) if stage_now >= 0 and stage_now < bars_d.size() else int(st.get("tetra", 0))
		var texts: Array = [
			"%d" % balls_now,
			Glyphs.short(tetra_now),
			("%d / %d" % [stage_now + 1, int(st.get("stages", 0))]) if stage_now >= 0 else "coat",
			"%+.2f m" % float(sc.get("_slice_w")),
		]
		for i in mini(texts.size(), _values.size()):
			if String(texts[i]) != String(_shown_values[i]) and not bool(_printing.get(i, false)):
				_shown_values[i] = texts[i]
				_print_value(i, String(texts[i]))


func _print_value(i: int, text: String) -> void:
	_printing[i] = true
	var plate: MeshInstance4D = _values[i][0]
	var sz: Vector2 = _values[i][1]
	var tex: Texture2D = await LabPrint.render(get_tree(), Vector2i(int(sz.x * PPM), int(sz.y * PPM)), func(c: Control) -> void:
		c.draw_string(LabPrint.font("black"), Vector2(0.0, c.size.y * 0.8), text, HORIZONTAL_ALIGNMENT_LEFT, c.size.x, int(c.size.y * 0.78), WHITE))
	_printing[i] = false
	if tex != null and is_instance_valid(plate):
		LabGrid.set_print(plate.material_override as TetraMaterial4D, tex, Vector4(0, 1, 0, 0), Rect2(Vector2.ZERO, sz), Color.WHITE, 0.9)


## Sets a material only when it is a different one (the parts are told every frame).
static func _set_mat(m: MeshInstance4D, mat: Material4D) -> void:
	if m.material_override != mat:
		m.material_override = mat


static func _scale(k: Vector3) -> Projection:
	return Projection(Vector4(k.x, 0, 0, 0), Vector4(0, k.y, 0, 0), Vector4(0, 0, k.z, 0), Vector4(0, 0, 0, 1))


func apply_mood(_m: String, _instant: bool = false) -> void:
	_paint_parts()
