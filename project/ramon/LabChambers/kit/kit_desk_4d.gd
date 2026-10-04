@tool
extends Node4D

## Kit: the research panel. A long, thin slab floating low over the floor and tilted towards you:
## a white frame with a raised rim round a recessed blue screen, a glowing line along its
## underside and a soft light on the floor under it (Ramon, 4 Oct, from his concept sheet: "make a
## floating panel like the first top in the ref"; then "not centered but offset on the left side,
## like something you could walk to for more info, and maybe a check button, before you see the
## flipover screen"). In the goat room it stands off the route to the left, under the lesson wall.
##
## THE CHECK BUTTON floats upright above its back edge, CHECK DATA, seen from across the room. Its
## frame lights when you stand at the panel (set_near); the room then lets you click it, and only
## then does the 2D data panel come up (goat_room_4d.gd).
##
## THE SCREEN is printed once (rd_build.gd print_box, both moods) when the exhibit's numbers are
## in, and carries what the 2D data panel shows (kit_data_panel.gd, which comes up while you
## stand here) in the concept's layout:
##   Research data, LIVE           the title, and a live dot
##   the exhibit as a wireframe     its own mesh and balls, seen from the side (kit_glyphs wire())
##   four tiles                     balls, tetrahedra, build stages, reach through W
##   Slice through W                the W profile, its slice stops, and a glowing line laid on the
##                                  screen where the slice you see cuts it, moved every frame
##   Build stage by stage           tetrahedra per stage
## The body is boxes: the slab, its rim and screen are tilted together; the collision is a row of
## upright boxes under it, square to the world (the physics here is box-only). Faces the node's +Z,
## turned to `face`.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/LabChambers/scripts/chamber_build.gd")
const RD := preload("res://ramon/LabChambers/scripts/rd_build.gd")
const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")
const Glyphs := preload("res://ramon/LabChambers/kit/kit_glyphs.gd")
const Batch := preload("res://ramon/LabKit/lab_batch.gd")
## Print resolution of the screen, pixels a metre.
const SCREEN_PPM := 400.0
const SLAB := 0.08
const RIM := 0.07
const RIM_UP := 0.035
## The screen's layout was drawn for this screen depth; others scale it.
const DRAWN_FOR := 1.09

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var showcase: NodePath
## The way its face looks, in the world (x, z): the node turns itself to it.
@export var face: Vector3 = Vector3(0, 0, 1):
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
@export_range(0.1, 1.5, 0.01) var hover: float = 0.5:
	set(v):
		hover = v
		_later()
## The light under it, on the floor: how strong, per mood.
@export var underglow: Dictionary = {"bright": 1.2, "dark": 1.6}:
	set(v):
		underglow = v
		_paint_parts()
@export var title: String = "Research data"
## The floating CHECK DATA button over its back edge.
@export var check_button: bool = true:
	set(v):
		check_button = v
		_later()
## How high the button floats, metres off the floor.
@export_range(0.8, 3.0, 0.05) var button_height: float = 1.6:
	set(v):
		button_height = v
		_later()

var _screen: MeshInstance4D
var _marker: MeshInstance4D
var _glow: Array = []
var _light: OmniLight4D
var _prints: Array = []
var _printed: bool = false
var _t: float = 0.0
var _next_try: float = 0.6
var _queued: bool = false
var _sw: float = 3.24
var _sh: float = 1.09
var _band: Rect2 = Rect2()
var _button: MeshInstance4D
var _button_frame: MeshInstance4D
var _near: bool = false
var _open: bool = false


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
	_glow = []
	_printed = false
	_t = 0.0
	_next_try = 0.6
	var th: float = deg_to_rad(tilt_degrees)
	var w: float = size.x
	var d: float = size.y
	var origin: Vector4 = global_position if is_inside_tree() else Vector4.ZERO
	# The slab, tilted about its own middle so its front edge floats `hover` over the floor.
	var slab := MeshInstance4D.new()
	slab.name = "Slab"
	var ss := Vector4(w, SLAB, d, Build.W_DEPTH)
	slab.mesh = Mats.box_mesh(ss)
	slab.position = Vector4(0.0, hover + d * 0.5 * sin(th) + SLAB * 0.5 * cos(th), 0.0, 0.0)
	slab.basis = Basis4D.from_yz(th)
	slab.material_override = LabGrid.material("kit_bezel", ss, origin)
	slab.set_meta(Build.GENERATED, true)
	add_child(slab)
	# The rim, raised round the screen: front, back, left, right.
	var top: float = SLAB * 0.5
	for r in [[Vector3(0, 0, d * 0.5 - RIM * 0.5), Vector3(w, RIM_UP, RIM)], [Vector3(0, 0, -d * 0.5 + RIM * 0.5), Vector3(w, RIM_UP, RIM)],
			[Vector3(-w * 0.5 + RIM * 0.5, 0, 0), Vector3(RIM, RIM_UP, d - RIM * 2.0)], [Vector3(w * 0.5 - RIM * 0.5, 0, 0), Vector3(RIM, RIM_UP, d - RIM * 2.0)]]:
		var at: Vector3 = r[0]
		var sz: Vector3 = r[1]
		var rim := MeshInstance4D.new()
		rim.name = "Rim"
		var rs := Vector4(sz.x, sz.y, sz.z, Build.W_DEPTH)
		rim.mesh = Mats.box_mesh(rs)
		rim.position = Vector4(at.x, top + RIM_UP * 0.5, at.z, 0.0)
		rim.material_override = LabGrid.material("kit_bezel", rs, origin)
		slab.add_child(rim)
	# The screen, set in the rim.
	_sw = w - RIM * 2.0 - 0.02
	_sh = d - RIM * 2.0 - 0.02
	var sc := Vector4(_sw, 0.02, _sh, Build.W_DEPTH)
	_screen = MeshInstance4D.new()
	_screen.name = "Screen"
	_screen.mesh = Mats.box_mesh(sc)
	_screen.position = Vector4(0.0, top + 0.004, 0.0, 0.0)
	_screen.material_override = LabGrid.material("kit_screen", sc, origin)
	slab.add_child(_screen)
	# The live line: where the slice you see cuts the profile, laid on the screen.
	_band = _layout()["band"]
	_marker = MeshInstance4D.new()
	_marker.name = "SliceLine"
	_marker.mesh = Mats.box_mesh(Vector4(0.016, 0.008, _band.size.y + 0.04, Build.W_DEPTH))
	_marker.position = Vector4(_band.get_center().x - _sw * 0.5, 0.014, _band.get_center().y - _sh * 0.5, 0.0)
	_screen.add_child(_marker)
	# A glowing line round the underside, set in a little from the edge: front, left, right, back.
	var under: float = -SLAB * 0.5 - 0.008
	for g in [[Vector3(0, under, d * 0.5 - 0.05), Vector3(w - 0.12, 0.016, 0.03)], [Vector3(-w * 0.5 + 0.05, under, 0), Vector3(0.03, 0.016, d - 0.12)],
			[Vector3(w * 0.5 - 0.05, under, 0), Vector3(0.03, 0.016, d - 0.12)], [Vector3(0, under, -d * 0.5 + 0.05), Vector3(w - 0.12, 0.016, 0.03)]]:
		var at2: Vector3 = g[0]
		var sz2: Vector3 = g[1]
		var line := MeshInstance4D.new()
		line.name = "Underglow"
		line.mesh = Mats.box_mesh(Vector4(sz2.x, sz2.y, sz2.z, Build.W_DEPTH))
		line.position = Vector4(at2.x, at2.y, at2.z, 0.0)
		slab.add_child(line)
		_glow.append(line)
	# A soft light on the floor under it, so it reads as floating.
	_light = OmniLight4D.new()
	_light.name = "UnderLight"
	_light.position = Vector4(0.0, maxf(0.12, hover * 0.4), 0.0, 0.0)
	_light.set_meta(Build.GENERATED, true)
	add_child(_light)
	# The physics is box-only and a turned box collides as its square in the world, which for a
	# panel turned 45 degrees covers the place you stand to read it. So: a row of upright boxes
	# along the slab, each kept square to the world.
	var high: float = hover + d * sin(th) + SLAB
	var f2 := Vector2(face.x, face.z)
	var square: Projection = Basis4D.from_zx(-atan2(f2.x, f2.y)) if f2.length() > 0.001 else Projection.IDENTITY
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
	_button = null
	_button_frame = null
	if check_button:
		var bs2 := Vector2(1.2, 0.36)
		var at := Vector3(0.0, button_height, -d * 0.5 + 0.1)
		_button = Build.box(self, "CheckButton", at, Vector3(bs2.x, bs2.y, 0.06), "kit_screen", false)
		var bb := Batch.new()
		var bw: float = 0.03
		var bc := Vector4(at.x, at.y, at.z + 0.035, 0.0)
		bb.box("f", Vector4(bs2.x + 0.12, bw, bw, 0.5), bc + Vector4(0, bs2.y * 0.5 + 0.06, 0, 0))
		bb.box("f", Vector4(bs2.x + 0.12, bw, bw, 0.5), bc - Vector4(0, bs2.y * 0.5 + 0.06, 0, 0))
		bb.box("f", Vector4(bw, bs2.y + 0.12, bw, 0.5), bc + Vector4(bs2.x * 0.5 + 0.06, 0, 0, 0))
		bb.box("f", Vector4(bw, bs2.y + 0.12, bw, 0.5), bc - Vector4(bs2.x * 0.5 + 0.06, 0, 0, 0))
		_button_frame = bb.instance("f")
		_button_frame.set_meta(Build.GENERATED, true)
		add_child(_button_frame)
	_paint_parts()


func _paint_parts() -> void:
	var c: Color = Style.pick(Style.COVE)
	for g in _glow:
		if is_instance_valid(g):
			(g as MeshInstance4D).material_override = Mats.glow(c, 1.8)
	if is_instance_valid(_marker):
		_marker.material_override = Mats.glow(Color(0.86, 0.96, 1.0), 2.2)
	if is_instance_valid(_button_frame):
		_button_frame.material_override = Mats.glow(Style.pick(Style.FRAME_LIT) if _near else Style.pick(Style.FRAME_DIM), 2.0 if _open else 1.0)
	if is_instance_valid(_light):
		_light.set("light_energy", float(underglow.get(Style.mood, 1.0)))
		_light.set("light_color", c)
		_light.set("omni_range_meters", maxf(size.x, size.y) * 0.75)
		_light.set("omni_range_attenuation", 0.6)


## The screen's layout, in metres from its top-left (the far edge, as you read it), scaled to its
## depth: `s` the scale, and the rects the paint and the live line share.
func _layout() -> Dictionary:
	var s: float = _sh / DRAWN_FOR
	var mg: float = 0.06
	var right0: float = 1.08 * s
	var right1: float = _sw - mg
	var mid: float = (right0 + right1) * 0.5
	var card_y: float = 0.5 * s
	var prof := Rect2(Vector2(right0 + 0.05, card_y + 0.12 * s), Vector2(mid - 0.025 - right0 - 0.1, 0.26 * s))
	var band := Rect2(prof.position, Vector2(prof.size.x, prof.size.y * 0.84))
	return {"s": s, "mg": mg, "right0": right0, "right1": right1, "mid": mid, "card_y": card_y, "profile": prof, "band": band}


## The room says whether you stand at it (the button lights) and whether the data is open.
func set_near(near_it: bool, open: bool = false) -> void:
	if near_it == _near and open == _open:
		return
	_near = near_it
	_open = open
	_paint_parts()


## Where you stand to read it: in front of it, within its width.
func near(p: Vector4) -> bool:
	var l: Vector4 = global_basis.inverse() * (p - global_position)
	return absf(l.x) < size.x * 0.5 + 0.4 and l.z > size.y * 0.5 - 0.1 and l.z < size.y * 0.5 + 2.0


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
	var shp: Dictionary = sc.call("shape") if sc != null and sc.has_method("shape") else {}
	var stops: Array = sc.call("slice_stops") if sc != null and sc.has_method("slice_stops") else []
	var rec: Dictionary = await RD.print_box(get_tree(), _screen, Vector4(0, 1, 0, 0), Vector2(_sw, _sh),
		func(c: Control, ink: Dictionary) -> void: _paint_screen(c, ink, d, prof, shp, stops), {"bright": 0.8, "dark": 0.9}, SCREEN_PPM)
	if not is_instance_valid(_screen):
		return
	_prints.append(rec)
	RD.apply(rec, Style.mood)
	if is_instance_valid(_button):
		var brec: Dictionary = await RD.print_box(get_tree(), _button, Vector4(0, 0, 1, 0), Vector2(1.2, 0.36), _paint_button, {"bright": 0.85, "dark": 0.95}, 300.0)
		if is_instance_valid(_button):
			_prints.append(brec)
			RD.apply(brec, Style.mood)


# -- the print -------------------------------------------------------------------------------------

func _paint_screen(c: Control, _ink: Dictionary, d: Dictionary, prof: Dictionary, shp: Dictionary, stops: Array) -> void:
	var lay: Dictionary = _layout()
	var k: float = c.size.x / _sw
	var s: float = float(lay["s"])
	var white := Color(1, 1, 1)
	var soft := Color(0.84, 0.91, 1.0, 0.92)
	var dim := Color(0.74, 0.83, 0.98, 0.78)
	var cyan := Color(0.52, 0.84, 1.0)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var px := func(m: float) -> int: return int(round(m * s * k))
	var at := func(x: float, y: float) -> Vector2: return Vector2(x * k, y * s * k)
	var mg: float = float(lay["mg"])
	var r0: float = float(lay["right0"])
	var r1: float = float(lay["right1"])
	var mid: float = float(lay["mid"])
	var st: Dictionary = d.get("stats", {})
	# The title, the live dot.
	c.draw_string(fb, at.call(mg, 0.13), title, HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.075), white)
	var live_w: float = fs.get_string_size("LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.04)).x
	c.draw_circle(at.call(r1, 0.1) - Vector2(live_w + px.call(0.05), 0.0), px.call(0.017), Color(0.45, 1.0, 0.62))
	c.draw_string(fs, at.call(r1, 0.115) - Vector2(live_w, 0.0), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.04), soft)
	# The exhibit, drawn from its own mesh and balls.
	var goat := Rect2(at.call(mg + 0.04, 0.22), at.call(r0 - mg - 0.14, 0.68))
	var card := StyleBoxFlat.new()
	card.bg_color = Color(1, 1, 1, 0.06)
	card.set_corner_radius_all(int(px.call(0.03)))
	card.anti_aliasing = true
	c.draw_style_box(card, Rect2(at.call(mg, 0.18), at.call(r0 - mg - 0.06, 0.86)))
	Glyphs.wire(c, goat, shp, Color(0.70, 0.88, 1.0, 0.7), white, Color(0.55, 0.80, 1.0, 0.12))
	c.draw_string(fl, at.call(mg + 0.04, 0.99), "Goat 01, lofted from %d balls" % int(st.get("balls", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.034), dim)
	# Four tiles.
	var tiles: Array = [
		["ball", str(int(st.get("balls", 0))), "Balls"],
		["tetra", Glyphs.short(int(st.get("tetra", 0))), "Tetrahedra"],
		["stages", str(int(st.get("stages", 0))), "Build stages"],
		["axes", "%.2f m" % float(st.get("reach", 0.0)), "W reach"],
	]
	var gap: float = 0.05
	var tw: float = (r1 - r0 - gap * 3.0) / 4.0
	for i in tiles.size():
		var t: Array = tiles[i]
		var x0: float = r0 + (tw + gap) * float(i)
		c.draw_style_box(card, Rect2(at.call(x0, 0.18), at.call(tw, 0.27)))
		var ic: float = px.call(0.11)
		Glyphs.icon(c, String(t[0]), Rect2(at.call(x0 + 0.04, 0.215), Vector2(ic, ic)), cyan)
		c.draw_string(fb, at.call(x0 + 0.19, 0.3), String(t[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.08), white)
		c.draw_string(fl, at.call(x0 + 0.19, 0.39), String(t[2]), HORIZONTAL_ALIGNMENT_LEFT, (tw - 0.21) * k, px.call(0.038), soft)
	# Slice through W, and the build, stage by stage.
	var cy: float = float(lay["card_y"]) / s
	c.draw_style_box(card, Rect2(at.call(r0, cy), at.call(mid - 0.025 - r0, 0.54)))
	c.draw_style_box(card, Rect2(at.call(mid + 0.025, cy), at.call(r1 - mid - 0.025, 0.54)))
	c.draw_string(fs, at.call(r0 + 0.05, cy + 0.08), "Slice through W", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.042), white)
	var pr: Rect2 = lay["profile"]
	Glyphs.profile(c, Rect2(pr.position * k, pr.size * k), prof.get("bins", PackedFloat32Array()), Color(cyan, 0.35), Color(cyan.lightened(0.3), 1.0), stops)
	var cap: float = cy + 0.48
	c.draw_string(fl, at.call(r0 + 0.05, cap), "-W", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.034), dim)
	c.draw_string(fl, at.call(r0 + 0.05, cap), "+W", HORIZONTAL_ALIGNMENT_RIGHT, (mid - 0.025 - r0 - 0.1) * k, px.call(0.034), dim)
	c.draw_string(fl, at.call(r0 + 0.05, cap), "The line is the slice you see", HORIZONTAL_ALIGNMENT_CENTER, (mid - 0.025 - r0 - 0.1) * k, px.call(0.034), soft)
	c.draw_string(fs, at.call(mid + 0.075, cy + 0.08), "Build stage by stage", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.042), white)
	var bars: Array = d.get("bars", [])
	var labels: Array = []
	for i in bars.size():
		labels.append(str(i + 1))
	Glyphs.bars(c, Rect2(at.call(mid + 0.075, cy + 0.13), at.call(r1 - mid - 0.125, 0.37)), bars, cyan, labels, px.call(0.034), dim)


func _paint_button(c: Control, _ink: Dictionary) -> void:
	var s: float = c.size.y
	var white := Color(1, 1, 1)
	Glyphs.icon(c, "graph", Rect2(Vector2(s * 0.16, s * 0.16), Vector2(s * 0.68, s * 0.68)), white)
	c.draw_string(LabPrint.font("black"), Vector2(s * 1.0, s * 0.6), "CHECK DATA", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.34), white)
	c.draw_string(LabPrint.font("bold"), Vector2(s * 1.0, s * 0.86), "CLICK", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.16), Color(white, 0.75))


func apply_mood(_m: String, _instant: bool = false) -> void:
	_paint_parts()
	for rec in _prints:
		RD.apply(rec, Style.mood)
