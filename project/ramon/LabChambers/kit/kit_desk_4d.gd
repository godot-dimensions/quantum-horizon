@tool
extends Node4D

## Kit: the research panel. A long, thin slab with rounded corners floating over the floor and
## tilted towards you: a white frame round a blue screen and a glowing line along its underside
## (Ramon, 4 Oct, from his concept sheet: "make a floating panel like the first top in the ref";
## "not centered but offset on the left side, like something you could walk to for more info";
## "place info floater higher"; "can the info panel have rounded edges, and is it truly dynamic?
## because it looks like an image"). In the goat room it stands off the route to the left, under
## the lesson wall.
##
## WALK UP and the room pops up a key prompt over it (kit_prompt.gd); the engage key opens the 2D
## data panel (goat_room_4d.gd). set_near() tells it you are there and whether the data is open.
##
## THE SCREEN IS LIVE: a 2D canvas in a SubViewport, redrawn `refresh_hz` times a second and shown
## on the screen through the grid shader's print (LabGrid.set_print takes the viewport's texture),
## in the concept's layout:
##   Research data, LIVE           the title, and a pulsing live dot
##   the exhibit as a wireframe     its own mesh and balls seen from the side (kit_glyphs wire);
##                                  the balls it has in view now are lit, the rest dim
##   four tiles                     balls in view, tetrahedra now, build stage now, W reach and the
##                                  slice's offset
##   Slice through W                the W profile, its slice stops, the slice you see as a line
##   Build stage by stage           tetrahedra per stage, the stage on show picked out
## FLAT AND CRISP (Ramon, 4 Oct: "I asked you to make a 2D interface, a dynamic texture in a manner
## of speaking", after a version built of raised cards): the screen is one flat face carrying the
## whole picture; the picture is drawn at `live_ppm` with 2D anti-aliasing, and since a viewport
## texture has no mipmaps the grid shader samples it several times when it is small on screen
## (print_aa), so it does not shimmer from across the room.
## The body is boxes and cylinders: the slab and the screen are tilted together; the collision is a
## row of upright boxes under it, square to the world (the physics here is box-only). Faces the
## node's +Z, turned to `face`.
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
const SLAB := 0.08
const SCREEN := 0.02
## The screen's layout was drawn for this screen depth; others scale it.
const DRAWN_FOR := 1.09

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var showcase: NodePath
## The way its face looks, in the world (x, z), if set: the node turns itself to it. Left at zero,
## the node's own rotation (the editor's rotate gizmo) decides (Ramon, 4 Oct: "give it a gizmo in
## the editor so I can move it, and rotate it").
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
## How sharp the live screen is drawn, pixels a metre, and how often it is redrawn.
@export_range(100.0, 900.0, 10.0) var live_ppm: float = 600.0
@export_range(1.0, 60.0, 1.0) var refresh_hz: float = 20.0
## Whether it stands in the way (a row of boxes under it); off for a panel hung on a wall.
@export var collide: bool = true

var _screen: MeshInstance4D
var _glow: Array = []
var _prints: Array = []
var _queued: bool = false
var _sw: float = 3.24
var _sh: float = 1.09
var _screen_rect: Rect2 = Rect2()
var _near: bool = false
var _open: bool = false
# The live screen.
var _vp: SubViewport
var _canvas: Control
var _redraw: float = 0.0
var _clock: float = 0.0
var _data: Dictionary = {}
var _profile: Dictionary = {}
var _stops: Array = []
var _wire: Dictionary = {}
var _shape: Dictionary = {}
var _serial: int = -1


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
	_vp = null
	_canvas = null
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
	# The screen on it, a margin in, its corners rounded to match.
	var margin: float = 0.08
	_sw = w - margin * 2.0
	_sh = d - margin * 2.0
	# The screen: one flat box, so the whole picture is on its face (the frame round it is rounded).
	_screen = MeshInstance4D.new()
	_screen.name = "Screen"
	var sc := Vector4(_sw, SCREEN, _sh, Build.W_DEPTH)
	_screen.mesh = Mats.box_mesh(sc)
	_screen.position = Vector4(0.0, SLAB * 0.5 + SCREEN * 0.5 + 0.002, 0.0, 0.0)
	_screen.material_override = LabGrid.material("kit_screen", sc, origin)
	slab.add_child(_screen)
	_screen_rect = Rect2(Vector2.ZERO, Vector2(_sw, _sh))
	# A glowing line round the underside, set in from the edge: front, left, right, back.
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
	# The physics is box-only and a turned box collides as its square in the world, which for a
	# panel turned 45 degrees covers the place you stand to read it. So: a row of upright boxes
	# along the slab, each kept square to the world.
	var high: float = hover + d * sin(th) + SLAB
	var fwd: Vector4 = (global_basis if is_inside_tree() else basis) * Vector4(0, 0, 1, 0)
	var square: Projection = Basis4D.from_zx(-atan2(fwd.x, fwd.z))
	var cell: float = maxf(minf(d * cos(th), 0.8), 0.05)
	var count: int = maxi(1, int(ceil(w / (cell * 0.7)))) if collide else 0
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
	if not Engine.is_editor_hint() and is_inside_tree():
		_start_screen()


## A rounded plate `s` (x, z) by `t` thick, `y` up its parent: a box the full width with the corners'
## depth taken off, a box the full depth with their width taken off, and a cylinder in each corner.
## The second box sits a hair lower, so where the two overlap only the first one shows. Returns the
## first (the one a print goes on).
func _rounded(parent: Node4D, nm: String, s: Vector2, t: float, y: float, r: float, swatch: String, origin: Vector4) -> MeshInstance4D:
	var a := MeshInstance4D.new()
	a.name = nm
	var sa := Vector4(s.x, t, s.y - r * 2.0, Build.W_DEPTH)
	a.mesh = Mats.box_mesh(sa)
	a.position = Vector4(0.0, y, 0.0, 0.0)
	a.material_override = LabGrid.material(swatch, sa, origin)
	parent.add_child(a)
	if r <= 0.001:
		return a
	var b := MeshInstance4D.new()
	b.name = nm + "Ends"
	var sb := Vector4(s.x - r * 2.0, t - 0.002, s.y, Build.W_DEPTH)
	b.mesh = Mats.box_mesh(sb)
	b.position = Vector4(0.0, y - 0.001, 0.0, 0.0)
	b.material_override = LabGrid.material(swatch, sb, origin)
	parent.add_child(b)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var c := MeshInstance4D.new()
			c.name = nm + "Corner"
			c.mesh = Build._cubinder(r, t - 0.002, 32)
			c.position = Vector4(cx * (s.x * 0.5 - r), y - 0.001, cz * (s.y * 0.5 - r), 0.0)
			c.material_override = LabGrid.material(swatch, Vector4(r * 2.0, t, r * 2.0, Build.W_DEPTH), origin)
			parent.add_child(c)
	return a


func _paint_parts() -> void:
	var c: Color = Style.pick(Style.COVE)
	for g in _glow:
		if is_instance_valid(g):
			(g as MeshInstance4D).material_override = Mats.glow(c, 1.8)
	if is_instance_valid(_screen) and _vp != null:
		LabGrid.set_print(_screen.material_override as TetraMaterial4D, _vp.get_texture(), Vector4(0, 1, 0, 0), _screen_rect, Color.WHITE,
			0.8 if Style.mood == "bright" else 0.9)
		LabGrid.set_print_strength(_screen.material_override as TetraMaterial4D, 1.0)
		(_screen.material_override as TetraMaterial4D).get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)


## The room says whether you stand at it and whether the data is open.
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
	if Engine.is_editor_hint():
		return
	_clock += delta
	# The screen.
	if _canvas == null:
		return
	var sc: Node = get_node_or_null(showcase)
	if sc != null:
		if int(sc.get("serial")) != _serial:
			_serial = int(sc.get("serial"))
			_data = {}
			_profile = {}
			_stops = []
			_shape = {}
			_wire = {}
		if _data.is_empty():
			_data = sc.call("data")
		if _profile.is_empty() and sc.has_method("profile"):
			_profile = sc.call("profile")
			_stops = sc.call("slice_stops") if sc.has_method("slice_stops") else []
		if _shape.is_empty() and sc.has_method("shape"):
			_shape = sc.call("shape")
	_redraw -= delta
	if _redraw <= 0.0:
		_redraw = 1.0 / refresh_hz
		_canvas.queue_redraw()


# -- the live screen -------------------------------------------------------------------------------

func _start_screen() -> void:
	_vp = SubViewport.new()
	_vp.name = "ScreenView"
	_vp.size = Vector2i(int(_sw * live_ppm), int(_sh * live_ppm))
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.msaa_2d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.set_meta(Build.GENERATED, true)
	_canvas = Control.new()
	_canvas.size = Vector2(_vp.size)
	_canvas.draw.connect(_draw_screen)
	_vp.add_child(_canvas)
	add_child(_vp)
	_paint_parts()


func _draw_screen() -> void:
	var c: Control = _canvas
	var sc: Node = get_node_or_null(showcase)
	var ex: Node = sc.get("exhibit") if sc != null else null
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
	var st: Dictionary = _data.get("stats", {})
	var bars: Array = _data.get("bars", [])
	var balls_now: int = int(ex.call("balls_in_view")) if ex != null and ex.has_method("balls_in_view") else int(st.get("balls", 0))
	var stage_now: int = int(ex.call("stage_in_view")) if ex != null and ex.has_method("stage_in_view") else -1
	# The title, the live dot.
	c.draw_string(fb, at.call(mg, 0.13), title, HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.075), white)
	var live_w: float = fs.get_string_size("LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.04)).x
	var pulse: float = 0.55 + 0.45 * sin(_clock * 4.0)
	c.draw_circle(at.call(r1, 0.1) - Vector2(live_w + px.call(0.05), 0.0), px.call(0.017), Color(0.45, 1.0, 0.62, pulse))
	c.draw_string(fs, at.call(r1, 0.115) - Vector2(live_w, 0.0), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.04), soft)
	# The exhibit, drawn from its own mesh and balls; the balls it has in view lit.
	var card := StyleBoxFlat.new()
	card.bg_color = Color(1, 1, 1, 0.06)
	card.set_corner_radius_all(int(px.call(0.03)))
	card.anti_aliasing = true
	c.draw_style_box(card, Rect2(at.call(mg, 0.18), at.call(r0 - mg - 0.06, 0.86)))
	if _wire.is_empty() and not _shape.is_empty():
		_wire = Glyphs.wire_geometry(Rect2(at.call(mg + 0.04, 0.22), at.call(r0 - mg - 0.14, 0.68)), _shape)
	Glyphs.wire_draw(c, _wire, Color(0.70, 0.88, 1.0, 0.7), white, Color(0.55, 0.80, 1.0, 0.12), balls_now)
	c.draw_string(fl, at.call(mg + 0.04, 0.99), "%s %s, %d of %d balls in view" % [String(_data.get("name", "Specimen")), String(_data.get("code", "XX-01")).get_slice("-", 1), balls_now, int(st.get("balls", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.034), dim)
	# Four tiles, live.
	var tetra_now: int = int(bars[stage_now]) if stage_now >= 0 and stage_now < bars.size() else int(st.get("tetra", 0))
	var slice_w: float = float(sc.get("_slice_w")) if sc != null else 0.0
	var tiles: Array = [
		["ball", "%d" % balls_now, "Balls in view"],
		["tetra", Glyphs.short(tetra_now), "Tetrahedra now"],
		["stages", ("%d / %d" % [stage_now + 1, int(st.get("stages", 0))]) if stage_now >= 0 else "coat", "Build stage"],
		["axes", "%+.2f m" % slice_w, "Slice, of %.2f m reach" % float(st.get("reach", 0.0))],
	]
	var gap: float = 0.05
	var tw: float = (r1 - r0 - gap * 3.0) / 4.0
	for i in tiles.size():
		var t: Array = tiles[i]
		var x0: float = r0 + (tw + gap) * float(i)
		c.draw_style_box(card, Rect2(at.call(x0, 0.18), at.call(tw, 0.27)))
		var ic: float = px.call(0.11)
		Glyphs.icon(c, String(t[0]), Rect2(at.call(x0 + 0.04, 0.215), Vector2(ic, ic)), cyan)
		c.draw_string(fb, at.call(x0 + 0.19, 0.3), String(t[1]), HORIZONTAL_ALIGNMENT_LEFT, (tw - 0.21) * k, px.call(0.075), white)
		c.draw_string(fl, at.call(x0 + 0.19, 0.39), String(t[2]), HORIZONTAL_ALIGNMENT_LEFT, (tw - 0.21) * k, px.call(0.034), soft)
	# Slice through W, and the build, stage by stage.
	var cy: float = float(lay["card_y"]) / s
	c.draw_style_box(card, Rect2(at.call(r0, cy), at.call(mid - 0.025 - r0, 0.54)))
	c.draw_style_box(card, Rect2(at.call(mid + 0.025, cy), at.call(r1 - mid - 0.025, 0.54)))
	c.draw_string(fs, at.call(r0 + 0.05, cy + 0.08), "Slice through W", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.042), white)
	var pr: Rect2 = lay["profile"]
	var lit: int = int(sc.get("slice_index")) if sc != null else -1
	var frac: float = float(sc.call("slice_fraction")) if sc != null and sc.has_method("slice_fraction") else NAN
	Glyphs.profile(c, Rect2(pr.position * k, pr.size * k), _profile.get("bins", PackedFloat32Array()), Color(cyan, 0.35), Color(cyan.lightened(0.3), 1.0),
		_stops, lit, frac, white)
	var cap: float = cy + 0.48
	c.draw_string(fl, at.call(r0 + 0.05, cap), "-W", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.034), dim)
	c.draw_string(fl, at.call(r0 + 0.05, cap), "+W", HORIZONTAL_ALIGNMENT_RIGHT, (mid - 0.025 - r0 - 0.1) * k, px.call(0.034), dim)
	c.draw_string(fl, at.call(r0 + 0.05, cap), "The line is the slice you see", HORIZONTAL_ALIGNMENT_CENTER, (mid - 0.025 - r0 - 0.1) * k, px.call(0.034), soft)
	c.draw_string(fs, at.call(mid + 0.075, cy + 0.08), "Build stage by stage", HORIZONTAL_ALIGNMENT_LEFT, -1, px.call(0.042), white)
	var labels: Array = []
	for i in bars.size():
		labels.append(str(i + 1))
	var br := Rect2(at.call(mid + 0.075, cy + 0.13), at.call(r1 - mid - 0.125, 0.37))
	Glyphs.bars(c, br, bars, cyan, labels, px.call(0.034), dim)
	if stage_now >= 0 and stage_now < bars.size():
		# The stage on show, picked out in white over its bar.
		var most: float = 0.0001
		for b in bars:
			most = maxf(most, float(b))
		var lab_h: float = float(px.call(0.034)) * 1.5
		var hh: float = br.size.y - lab_h
		var bw: float = br.size.x / float(bars.size())
		var bh: float = maxf(1.0, hh * float(bars[stage_now]) / most)
		c.draw_rect(Rect2(Vector2(br.position.x + bw * float(stage_now) + bw * 0.16, br.position.y + hh - bh), Vector2(bw * 0.68, bh)), white)


## The screen's layout, in metres from its top-left (the far edge, as you read it), scaled to its
## depth: `s` the scale, and the profile's rect.
func _layout() -> Dictionary:
	var s: float = _sh / DRAWN_FOR
	var mg: float = 0.06
	var right0: float = 1.08 * s
	var right1: float = _sw - mg
	var mid: float = (right0 + right1) * 0.5
	var card_y: float = 0.5 * s
	var prof := Rect2(Vector2(right0 + 0.05, card_y + 0.12 * s), Vector2(mid - 0.025 - right0 - 0.1, 0.26 * s))
	return {"s": s, "mg": mg, "right0": right0, "right1": right1, "mid": mid, "card_y": card_y, "profile": prof}


func apply_mood(_m: String, _instant: bool = false) -> void:
	_paint_parts()
	for rec in _prints:
		RD.apply(rec, Style.mood)
