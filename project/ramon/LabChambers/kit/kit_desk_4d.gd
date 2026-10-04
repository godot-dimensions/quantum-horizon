@tool
extends Node4D

## Kit: the research console. A white wedge with a blue screen leaning back towards you, a dark
## recessed foot with a blue glow line along it, and the exhibit's research printed on the screen
## (Ramon, 4 Oct: "a panel block you can look down at ... for tucking away research data in a non
## intrusive way"; then "improve the block design, display slightly tilted", "it can have some
## relevant info for stakeholders, and add some icons").
##
## THE SCREEN is printed once (rd_build.gd print_box, both moods) when the exhibit's numbers are
## in, and is meant to be read at a glance from the camera, so it holds a few big things:
##   a headline and the project tag
##   WHERE IT EXISTS THROUGH W  the exhibit's W profile (kit_showcase w_profile), its slice stops
##                              along the foot, and a LIVE line on it where the slice you see cuts:
##                              a glowing bar laid on the screen, moved every frame, not printed
##   four numbers with icons    balls, tetrahedra, build stages (measured) and authoring time
##                              (a SAMPLE, tagged as one until it is measured)
## The close reading is the 2D panel that comes up while you stand here (kit_data_panel.gd).
##
## THE BODY is boxes only: a slab tilted by `tilt_degrees` for the top, and under it upright boxes
## (the physics is box-only) stepped so each one's top hides inside the slab, which leaves a clean
## wedge from the side. Faces the node's +Z, turned to `face`; stand on that side to read it.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/LabChambers/scripts/chamber_build.gd")
const RD := preload("res://ramon/LabChambers/scripts/rd_build.gd")
const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")
const Glyphs := preload("res://ramon/LabChambers/kit/kit_glyphs.gd")
## Print resolution of the screen, pixels a metre: high, it carries small type and line icons.
const SCREEN_PPM := 460.0
const FRONT_PPM := 220.0
const LIP := 0.05
const SLAB := 0.3
const FOOT := 0.1
## The screen's layout was drawn for this screen depth; others scale it.
const DRAWN_FOR := 0.98

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var showcase: NodePath
## The way its face looks, in the world (x, z): the node turns itself to it.
@export var face: Vector3 = Vector3(0, 0, 1):
	set(v):
		face = v
		_turn()
## How far the screen leans back, in degrees from flat.
@export_range(10.0, 70.0, 1.0) var tilt_degrees: float = 34.0:
	set(v):
		tilt_degrees = v
		_later()
## Across, in metres.
@export var width: float = 2.6:
	set(v):
		width = v
		_later()
## Front to back of the top, in metres (seen from above).
@export var depth: float = 0.9:
	set(v):
		depth = v
		_later()
## Height of the front edge, in metres.
@export var front_height: float = 0.92:
	set(v):
		front_height = v
		_later()
## The tag and headline printed at the top of the screen.
@export var tag: String = "GOAT 01"
@export var headline: String = "A 4D animal, built by hand"

var _screen: MeshInstance4D
var _front: MeshInstance4D
var _glow_line: MeshInstance4D
var _marker: MeshInstance4D
var _prints: Array = []
var _printed: bool = false
var _t: float = 0.0
var _next_try: float = 0.6
var _queued: bool = false
var _sw: float = 2.4
var _sh: float = 0.98
var _band: Rect2 = Rect2()
var _front_h: float = 0.8


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
	# A basis whose +Z is `face`, upright: a turn about Y.
	basis = Basis4D.from_zx(atan2(f.x, f.y))


func rebuild() -> void:
	_turn()
	Build.clear(self)
	_prints = []
	_printed = false
	_t = 0.0
	_next_try = 0.6
	var th: float = deg_to_rad(tilt_degrees)
	var tn: float = tan(th)
	var yf: float = front_height
	var zf: float = depth * 0.5 + LIP
	var top_depth: float = depth + LIP
	var length: float = top_depth / cos(th)
	# n: the slab's up, leaning towards the reader; its bottom face runs parallel, SLAB below.
	var n := Vector2(cos(th), sin(th))          # (y, z)
	var yb: float = yf + top_depth * tn         # back edge of the top
	var zb: float = zf - top_depth
	var bottom_front := Vector2(yf, zf) - n * SLAB
	var z_back: float = zb - SLAB * n.y         # the back of the whole console
	var body_top: float = yf - 0.06
	# The foot: dark, set in all round, with a glow line along its front.
	Build.box(self, "Foot", Vector3(0.0, FOOT * 0.5, (z_back + depth * 0.5) * 0.5), Vector3(width - 0.2, FOOT, depth * 0.5 - z_back - 0.2), "kit_screen2")
	_glow_line = MeshInstance4D.new()
	_glow_line.name = "GlowLine"
	_glow_line.mesh = Mats.box_mesh(Vector4(width - 0.34, 0.025, 0.02, Build.W_DEPTH))
	_glow_line.position = Vector4(0.0, FOOT * 0.55, depth * 0.5 - 0.1 + 0.012, 0.0)
	_glow_line.set_meta(Build.GENERATED, true)
	add_child(_glow_line)
	# The body: upright steps under the slab, each as tall as the slab's underside at its back
	# edge, so its top stays inside the slab and the side reads as one wedge.
	var steps: int = 6
	var z_front: float = depth * 0.5
	for i in steps:
		var za: float = lerpf(z_back, z_front, float(i) / float(steps))
		var zb2: float = lerpf(z_back, z_front, float(i + 1) / float(steps))
		var under: float = bottom_front.x + (bottom_front.y - za) * tn
		var top: float = maxf(body_top, under) + 0.002
		var b: MeshInstance4D = Build.box(self, "Body%d" % i, Vector3(0.0, (FOOT + top) * 0.5, (za + zb2) * 0.5), Vector3(width, top - FOOT, zb2 - za), "kit_desk")
		if i == steps - 1:
			_front = b
			_front_h = top - FOOT
	# The top: one slab, tilted, its up leaning to the reader; the screen laid on it.
	var slab := MeshInstance4D.new()
	slab.name = "Top"
	var ss := Vector4(width, SLAB, length, Build.W_DEPTH)
	slab.mesh = Mats.box_mesh(ss)
	var mid_top := Vector2((yf + yb) * 0.5, (zf + zb) * 0.5) - n * SLAB * 0.5
	slab.position = Vector4(0.0, mid_top.x, mid_top.y, 0.0)
	slab.basis = Basis4D.from_yz(th)
	slab.material_override = LabGrid.material("kit_desk", ss, global_position if is_inside_tree() else Vector4.ZERO)
	slab.set_meta(Build.GENERATED, true)
	add_child(slab)
	# The screen, a bezel in from the slab's edges (more at the front, where the lip is).
	_sw = width - 0.14
	_sh = length - 0.16
	var sc := Vector4(_sw, 0.02, _sh, Build.W_DEPTH)
	_screen = MeshInstance4D.new()
	_screen.name = "Screen"
	_screen.mesh = Mats.box_mesh(sc)
	_screen.position = Vector4(0.0, SLAB * 0.5 + 0.01, -0.02, 0.0)
	_screen.material_override = LabGrid.material("kit_screen", sc, global_position if is_inside_tree() else Vector4.ZERO)
	slab.add_child(_screen)
	# The live line: where the slice you see cuts the profile, laid on the screen.
	_band = _layout()["band"]
	_marker = MeshInstance4D.new()
	_marker.name = "SliceLine"
	_marker.mesh = Mats.box_mesh(Vector4(0.014, 0.008, _band.size.y + 0.03, Build.W_DEPTH))
	_marker.position = Vector4(_band.get_center().x - _sw * 0.5, 0.014, _band.get_center().y - _sh * 0.5, 0.0)
	_screen.add_child(_marker)
	_paint_parts()


func _paint_parts() -> void:
	if _glow_line != null:
		_glow_line.material_override = Mats.glow(Style.pick(Style.ROUTE), 1.6)
	if _marker != null:
		_marker.material_override = Mats.glow(Color(0.86, 0.96, 1.0), 2.2)


## The screen's layout, in metres from its top-left (the far edge, as you read it), scaled to its
## depth: `s` the scale and `band` the profile's silhouette band (where the live line runs).
func _layout() -> Dictionary:
	var s: float = minf(1.15, _sh / DRAWN_FOR)
	var mg: float = 0.07
	var prof := Rect2(Vector2(mg, 0.34 * s), Vector2(_sw - mg * 2.0, 0.25 * s))
	var band := Rect2(prof.position, Vector2(prof.size.x, prof.size.y * 0.84))
	return {"s": s, "mg": mg, "profile": prof, "band": band}


## Where you stand to read it, in the world.
func near(p: Vector4) -> bool:
	var l: Vector4 = p - global_position
	var front: Vector4 = global_basis * Vector4(0, 0, 1.4, 0)
	return Vector2(l.x - front.x, l.z - front.z).length() < 1.6


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _screen == null:
		return
	var sc: Node = get_node_or_null(showcase)
	if not _printed:
		_t += delta
		if _t >= _next_try:
			_next_try = _t + 0.25
			var ready_now: bool = sc != null and not (sc.call("data") as Dictionary).is_empty() and not (sc.call("profile") as Dictionary).is_empty()
			if ready_now or _t > 12.0:
				_printed = true
				_print_all(sc)
	if sc != null and _marker != null and sc.has_method("slice_fraction"):
		var f: float = float(sc.call("slice_fraction"))
		_marker.position.x = _band.position.x + _band.size.x * (f * 0.5 + 0.5) - _sw * 0.5


func _print_all(sc: Node) -> void:
	var d: Dictionary = sc.call("data") if sc != null else {}
	var prof: Dictionary = sc.call("profile") if sc != null and sc.has_method("profile") else {}
	var stops: Array = sc.call("slice_stops") if sc != null and sc.has_method("slice_stops") else []
	var tree: SceneTree = get_tree()
	var screen_rec: Dictionary = await RD.print_box(tree, _screen, Vector4(0, 1, 0, 0), Vector2(_sw, _sh),
		func(c: Control, ink: Dictionary) -> void: _paint_screen(c, ink, d, prof, stops), {"bright": 0.75, "dark": 0.9}, SCREEN_PPM)
	if not is_instance_valid(_screen):
		return
	_prints.append(screen_rec)
	RD.apply(screen_rec, Style.mood)
	if _front != null:
		var fh: float = _front_h
		var front_rec: Dictionary = await RD.print_box(tree, _front, Vector4(0, 0, 1, 0), Vector2(width, fh), _paint_front, {"bright": 0.0, "dark": 0.05}, FRONT_PPM)
		if is_instance_valid(_front):
			_prints.append(front_rec)
			RD.apply(front_rec, Style.mood)


# -- the prints ------------------------------------------------------------------------------------

func _paint_screen(c: Control, _ink: Dictionary, d: Dictionary, prof: Dictionary, stops: Array) -> void:
	var lay: Dictionary = _layout()
	var k: float = c.size.x / _sw
	var s: float = float(lay["s"])
	var mg: float = float(lay["mg"]) * k
	var white := Color(1, 1, 1)
	var soft := Color(0.84, 0.91, 1.0, 0.92)
	var dim := Color(0.74, 0.83, 0.98, 0.78)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var px := func(m: float) -> int: return int(round(m * s * k))
	var y := func(m: float) -> float: return m * s * k
	var right: float = c.size.x - mg
	# The tag line and the headline.
	var tw: float = Glyphs.tag(c, Vector2(mg, y.call(0.085)), tag, px.call(0.03), white, true)
	c.draw_string(fs, Vector2(mg + tw + px.call(0.03), y.call(0.085) + px.call(0.011)), "R&D PROTOTYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.028), dim)
	var live_w: float = fs.get_string_size("LIVE FROM THE EXHIBIT", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.028)).x
	Glyphs.icon(c, "live", Rect2(Vector2(right - live_w - px.call(0.06), y.call(0.085) - px.call(0.025)), Vector2(px.call(0.05), px.call(0.05))), Color(0.55, 1.0, 0.7))
	c.draw_string(fs, Vector2(right - live_w, y.call(0.085) + px.call(0.011)), "LIVE FROM THE EXHIBIT", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.028), soft)
	c.draw_string(fb, Vector2(mg, y.call(0.215)), headline, HORIZONTAL_ALIGNMENT_LEFT, c.size.x - mg * 2.0, px.call(0.088), white)
	# The W profile.
	var pr: Rect2 = lay["profile"]
	var prect := Rect2(pr.position * k, pr.size * k)
	Glyphs.icon(c, "slice", Rect2(Vector2(mg, y.call(0.272)), Vector2(px.call(0.05), px.call(0.05))), white)
	c.draw_string(fs, Vector2(mg + px.call(0.07), y.call(0.31)), "WHERE IT EXISTS THROUGH W", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.034), white)
	var legend: String = "the slice you see"
	var lw: float = fl.get_string_size(legend, HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.03)).x
	c.draw_line(Vector2(right - lw - px.call(0.05), y.call(0.3)), Vector2(right - lw - px.call(0.05), y.call(0.3) - px.call(0.04)), white, maxf(2.0, px.call(0.012)))
	c.draw_string(fl, Vector2(right - lw, y.call(0.31)), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.03), soft)
	var bins: PackedFloat32Array = prof.get("bins", PackedFloat32Array())
	Glyphs.profile(c, prect, bins, Color(1, 1, 1, 0.34), Color(1, 1, 1, 0.95), stops)
	var cap_y: float = prect.end.y + px.call(0.045)
	c.draw_string(fs, Vector2(mg, cap_y), "-W", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.03), dim)
	c.draw_string(fs, Vector2(mg, cap_y), "+W", HORIZONTAL_ALIGNMENT_RIGHT, c.size.x - mg * 2.0, px.call(0.03), dim)
	var reach: float = float(prof.get("reach", 0.0))
	var cap: String = "Each W cuts a different goat: thickest through the middle, nothing past %.2f m either side" % reach if reach > 0.0 else "Each W cuts a different goat"
	c.draw_string(fl, Vector2(mg, cap_y), cap, HORIZONTAL_ALIGNMENT_CENTER, c.size.x - mg * 2.0, px.call(0.03), soft)
	# The numbers.
	var line_y: float = y.call(0.69)
	c.draw_line(Vector2(mg, line_y), Vector2(right, line_y), Color(1, 1, 1, 0.25), maxf(1.0, px.call(0.004)))
	var st: Dictionary = d.get("stats", {})
	var cells: Array = [
		["ball", str(int(st.get("balls", 0))), "balls, placed by hand", false],
		["tetra", Glyphs.short(int(st.get("tetra", 0))), "tetrahedra in its 4D skin", false],
		["stages", str(int(st.get("stages", 0))), "build stages, baked", false],
		["clock", "1 day", "to author, no code", true],
	]
	var cw: float = (c.size.x - mg * 2.0) / float(cells.size())
	for i in cells.size():
		var cell: Array = cells[i]
		var x0: float = mg + cw * float(i)
		var ic: float = px.call(0.1)
		Glyphs.icon(c, String(cell[0]), Rect2(Vector2(x0, y.call(0.735)), Vector2(ic, ic)), white)
		c.draw_string(fb, Vector2(x0 + ic + px.call(0.03), y.call(0.815)), String(cell[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.09), white)
		var nw: float = fb.get_string_size(String(cell[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.09)).x
		if bool(cell[3]):
			Glyphs.tag(c, Vector2(x0 + ic + px.call(0.05) + nw, y.call(0.785)), "SAMPLE", px.call(0.022), Color(1.0, 0.86, 0.45))
		c.draw_string(fl, Vector2(x0 + ic + px.call(0.03), y.call(0.875)), String(cell[2]), HORIZONTAL_ALIGNMENT_LEFT, cw - ic - px.call(0.05), px.call(0.032), soft)


func _paint_front(c: Control, _ink: Dictionary) -> void:
	var k: float = c.size.x / width
	var ink := Color(0.10, 0.12, 0.16, 0.92)
	var x: float = 0.12 * k
	c.draw_rect(Rect2(Vector2(x, 0.1 * k), Vector2(0.012 * k, 0.16 * k)), Color(0.10, 0.42, 0.95))
	c.draw_string(LabPrint.font("black"), Vector2(x + 0.04 * k, 0.175 * k), "RESEARCH CONSOLE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.065 * k), ink)
	c.draw_string(LabPrint.font("body"), Vector2(x + 0.04 * k, 0.245 * k), "%s  |  step up to read the data" % tag.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.038 * k), Color(ink, 0.7))


func apply_mood(_m: String, _instant: bool = false) -> void:
	_paint_parts()
	for rec in _prints:
		RD.apply(rec, Style.mood)
