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
## THE LOFT BUILDER SCREEN (Ramon, 4 Oct: "maybe the panel can be more about the loft builder"; "think of what to do with the info panel ... make sure the
## infos on the panel and overlay are different from the blue graphs"): the research wall tells the
## story and its measurements, so this screen shows the one thing it does not, what a designer
## actually sets. Every ball of the animal from the side, sized as placed, one picked out at a time
## (stepping on every few seconds, or following the build while its balls arrive); that ball's
## cross-section drawn large, with its width, its height and how far it reaches into W, and the ring
## of points the builder makes of it at the rig's own resolution; and its handful of numbers and how
## it is lofted. `screen_page` "metrics" puts back the first screen. Type on the lab's ladder
## (kit_style.gd), in metres.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/VoxelLab/carried/scripts/chamber_build.gd")
const RD := preload("res://ramon/VoxelLab/carried/scripts/rd_build.gd")
const LabGrid := preload("res://ramon/VoxelLab/carried/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")
const Mats := preload("res://ramon/VoxelLab/carried/LabKit/lab_materials.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const Glyphs := preload("res://ramon/VoxelLab/carried/kit/kit_glyphs.gd")
const Batch := preload("res://ramon/VoxelLab/carried/LabKit/lab_batch.gd")
const LoftBuilder := preload("res://ramon/VoxelLab/carried/LabKit/carried/chickenpen/scripts/loft_builder_4d.gd")
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
## What the screen shows: the ball inspector, or the first version's metrics.
@export_enum("inspector", "metrics") var screen_page: String = "inspector"
## Seconds on each ball before the inspector steps on.
@export_range(0.5, 10.0, 0.1) var inspect_seconds: float = 2.4
## Whether it stands in the way (a row of boxes under it); off for a panel hung on a wall.
@export var collide: bool = true
## The screen's own colour under its picture: black glass, as every screen (kit_style.gd: blue is
## for walls, black for screens).
@export var screen_swatch: String = "kit_glass":
	set(v):
		screen_swatch = v
		_later()

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
	_screen.material_override = LabGrid.material(screen_swatch, sc, origin)
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
	if screen_page == "inspector":
		_draw_inspector()
		return
	_draw_metrics()


var _inspect_i: int = 0
var _inspect_at: float = 0.0
var _inspect_seen: int = -1


## The ball inspector (see the note at the top). Laid out on a page 1000 units wide.
func _draw_inspector() -> void:
	var c: Control = _canvas
	var k: float = c.size.x / 1000.0
	var ph: float = c.size.y / k
	var sc: Node = get_node_or_null(showcase)
	var balls: Array = sc.call("ball_sections") if sc != null and sc.has_method("ball_sections") else []
	var ex: Node = sc.get("exhibit") if sc != null else null
	var white: Color = Style.UI_INK
	var soft: Color = Style.UI_INK_SOFT
	var dim: Color = Style.UI_INK_DIM
	var acc: Color = Style.UI_ACCENT_SCREEN
	var fb: Font = Style.ui_font("title")
	var fs: Font = Style.ui_font("heading")
	var fl: Font = Style.ui_font("text")
	var upm: float = 1000.0 / maxf(_sw, 0.1)
	var tp := func(step: int) -> int: return int(round(Style.type_m(step) * upm * k))
	var at := func(x: float, y: float) -> Vector2: return Vector2(x, y) * k
	var card := func(r: Rect2) -> void: c.draw_style_box(Style.veil_box(14.0 * k), Rect2(r.position * k, r.size * k))
	# The header.
	var nm: String = String(_data.get("name", "specimen"))
	c.draw_string(fb, at.call(24, 46), "Loft builder", HORIZONTAL_ALIGNMENT_LEFT, -1, tp.call(-2), white)
	c.draw_string(fl, at.call(26, 72), "The balls a designer sets for the %s, and the rings the builder lofts between them." % nm.to_lower(), HORIZONTAL_ALIGNMENT_LEFT, -1, tp.call(-5), dim)
	if balls.is_empty():
		c.draw_string(fl, at.call(26, 150), "Waiting for a specimen.", HORIZONTAL_ALIGNMENT_LEFT, -1, tp.call(-4), dim)
		return
	# Which ball: following the build while its balls arrive, otherwise one after another.
	var in_view: int = int(ex.call("balls_in_view")) if ex != null and ex.has_method("balls_in_view") else balls.size()
	var building: bool = ex != null and ex.has_method("stage_in_view") and int(ex.call("stage_in_view")) >= 0
	if building and in_view != _inspect_seen:
		_inspect_seen = in_view
		_inspect_i = clampi(in_view - 1, 0, balls.size() - 1)
		_inspect_at = _clock
	elif not building and _clock - _inspect_at > inspect_seconds:
		_inspect_i = (_inspect_i + 1) % balls.size()
		_inspect_at = _clock
	_inspect_i = clampi(_inspect_i, 0, balls.size() - 1)
	var b: Dictionary = balls[_inspect_i]
	var count := "Ball %d of %d" % [_inspect_i + 1, balls.size()]
	var cw: float = fs.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, tp.call(-5)).x / k
	c.draw_string(fs, at.call(976 - cw, 46), count, HORIZONTAL_ALIGNMENT_LEFT, -1, tp.call(-5), soft)
	var pulse: float = 0.55 + 0.45 * sin(_clock * 4.0)
	c.draw_circle(at.call(966 - cw - 14, 40), 5.0 * k, Color(Style.UI_LIVE, pulse))
	# Left: every ball from the side, sized as placed, the one inspected picked out.
	var lr := Rect2(20, 92, 360, ph - 112)
	card.call(lr)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for e in balls:
		var p: Vector2 = e["at"]
		var r: float = float(e["radius"])
		lo = Vector2(minf(lo.x, p.x - r), minf(lo.y, p.y - r))
		hi = Vector2(maxf(hi.x, p.x + r), maxf(hi.y, p.y + r))
	var span: Vector2 = (hi - lo).max(Vector2(0.001, 0.001))
	var inner := Rect2(lr.position + Vector2(18, 18), lr.size - Vector2(36, 36))
	var fit: float = minf(inner.size.x / span.x, inner.size.y / span.y)
	var o: Vector2 = inner.get_center() - Vector2((lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5) * fit
	for i in balls.size():
		var e: Dictionary = balls[i]
		var q: Vector2 = (o + Vector2((e["at"] as Vector2).x, -(e["at"] as Vector2).y) * fit) * k
		var rr: float = maxf(float(e["radius"]) * fit, 2.0) * k
		if i == _inspect_i:
			c.draw_circle(q, rr, Color(acc, 0.35))
			c.draw_arc(q, rr, 0.0, TAU, 40, acc, maxf(1.5, 3.0 * k), true)
		else:
			c.draw_arc(q, rr, 0.0, TAU, 32, Color(white, 0.35 if i < in_view else 0.12), maxf(1.0, 1.4 * k), true)
	# Middle: that ball's cross-section, large, its width and height marked, its reach into W below.
	var mr := Rect2(394, 92, 270, ph - 112)
	card.call(mr)
	var rad: float = float(b["radius"])
	var vs: float = float(b["v"])
	var ws: float = float(b["w"])
	var expo: float = LoftBuilder._squareness_exponent(float(b["square"]))
	var big: float = maxf(rad, rad * vs)
	var box_h: float = mr.size.y - 128.0
	var sfit: float = minf((mr.size.x - 80.0) * 0.5, box_h * 0.5) / maxf(big, 0.001)
	var cc := Vector2(mr.position.x + mr.size.x * 0.5, mr.position.y + 24.0 + box_h * 0.5)
	var roll: float = float(b["roll"])
	var pts := PackedVector2Array()
	for n in 64:
		var t: float = TAU * float(n) / 64.0
		var d: Vector3 = LoftBuilder._apply_squareness(Vector3(cos(t), sin(t), 0.0), expo)
		var v2 := Vector2(d.x * rad, -d.y * rad * vs).rotated(-roll) * sfit
		pts.append((cc + v2) * k)
	c.draw_colored_polygon(pts, Color(acc, 0.14))
	pts.append(pts[0])
	c.draw_polyline(pts, Color(acc, 0.45), maxf(1.0, 1.4 * k), true)
	# The ring the builder makes of it: as many points as the rig's profile has sides, the faces between
	# them flat; the next ball's ring is joined to this one by tetrahedra.
	var sides: int = maxi(3, int(b.get("sides", 12)))
	var ring := PackedVector2Array()
	for n in sides:
		var t2: float = TAU * float(n) / float(sides)
		var d2: Vector3 = LoftBuilder._apply_squareness(Vector3(cos(t2), sin(t2), 0.0), expo)
		ring.append((cc + Vector2(d2.x * rad, -d2.y * rad * vs).rotated(-roll) * sfit) * k)
	var ring_closed := PackedVector2Array(ring)
	ring_closed.append(ring[0])
	c.draw_polyline(ring_closed, acc, maxf(1.5, 2.6 * k), true)
	for q2 in ring:
		c.draw_circle(q2, maxf(2.0, 3.6 * k), white)
	var wx: float = rad * sfit
	var hy: float = rad * vs * sfit
	_dim_line(c, (cc + Vector2(-wx, hy + 16)) * k, (cc + Vector2(wx, hy + 16)) * k, "%.2f m" % (rad * 2.0), soft, tp.call(-6), k)
	_dim_line(c, (cc + Vector2(wx + 18, -hy)) * k, (cc + Vector2(wx + 18, hy)) * k, "%.2f m" % (rad * vs * 2.0), soft, tp.call(-6), k)
	var wy: float = mr.end.y - 30.0
	var wmax: float = (mr.size.x - 60.0) * 0.5
	var wlen: float = clampf(rad * ws * sfit, 4.0, wmax)
	c.draw_line(at.call(cc.x - wmax, wy), at.call(cc.x + wmax, wy), Color(white, 0.12), maxf(1.0, 6.0 * k), true)
	c.draw_line(at.call(cc.x - wlen, wy), at.call(cc.x + wlen, wy), Style.UI_GOLD, maxf(1.0, 6.0 * k), true)
	c.draw_string(fs, at.call(mr.position.x + 16, wy - 12), "REACH INTO W", HORIZONTAL_ALIGNMENT_LEFT, -1, tp.call(-6), Style.UI_GOLD)
	c.draw_string(fl, at.call(mr.position.x, wy - 12), "± %.2f m" % (rad * ws), HORIZONTAL_ALIGNMENT_RIGHT, (mr.size.x - 16.0) * k, tp.call(-6), soft)
	# Right: its numbers.
	var rr2 := Rect2(678, 92, 302, ph - 112)
	card.call(rr2)
	var x: float = rr2.position.x + 20.0
	var y: float = rr2.position.y + 44.0
	c.draw_string(fb, at.call(x, y), String(b["name"]), HORIZONTAL_ALIGNMENT_LEFT, (rr2.size.x - 70.0) * k, tp.call(-3), white)
	var col: Color = b["color"]
	var sw := Rect2(rr2.end.x - 48, rr2.position.y + 20, 28, 28)
	c.draw_style_box(_swatch_box(col, k), Rect2(sw.position * k, sw.size * k))
	var rows: Array = [["Size", "%.2f m across" % (rad * 2.0)], ["Up and down", "× %.2f" % vs], ["Into W", "× %.2f" % ws],
		["Squareness", ("round" if absf(float(b["square"])) < 0.05 else ("%.2f, boxier" % float(b["square"]) if float(b["square"]) > 0.0 else "%.2f, pointier" % float(b["square"])))],
		["Roll", "%d°" % int(round(rad_to_deg(roll)))],
		["Lofted as", "%d sides × %d rings" % [int(b.get("sides", 12)), int(b.get("rings", 4))]]]
	y += 24.0
	var row_h: float = (rr2.end.y - 44.0 - y) / float(rows.size())
	for i in rows.size():
		var ry: float = y + row_h * float(i) + row_h * 0.62
		c.draw_string(fl, at.call(x, ry), String(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, tp.call(-5), dim)
		c.draw_string(fs, at.call(x, ry), String(rows[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, (rr2.size.x - 40.0) * k, tp.call(-5), white)
		if i < rows.size() - 1:
			c.draw_line(at.call(x, y + row_h * float(i + 1)), at.call(rr2.end.x - 20.0, y + row_h * float(i + 1)), Color(white, 0.08), maxf(1.0, k), true)
	c.draw_multiline_string(fl, at.call(x, rr2.end.y - 30.0), "A handful of numbers per ball. The builder does the rest.", HORIZONTAL_ALIGNMENT_LEFT, (rr2.size.x - 40.0) * k, tp.call(-6), 2, acc)


## A measured line with end ticks and its length written beside it.
func _dim_line(c: Control, a: Vector2, b: Vector2, text: String, col: Color, px: int, k: float) -> void:
	c.draw_line(a, b, Color(col, 0.7), maxf(1.0, 1.4 * k), true)
	var n: Vector2 = (b - a).normalized().orthogonal() * 5.0 * k
	c.draw_line(a - n, a + n, Color(col, 0.7), maxf(1.0, 1.4 * k), true)
	c.draw_line(b - n, b + n, Color(col, 0.7), maxf(1.0, 1.4 * k), true)
	var mid: Vector2 = (a + b) * 0.5
	var f: Font = Style.ui_font("text")
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if absf(b.x - a.x) > absf(b.y - a.y):
		c.draw_string(f, mid + Vector2(-w * 0.5, float(px) * 1.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	else:
		c.draw_string(f, mid + Vector2(8.0 * k, float(px) * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _swatch_box(col: Color, k: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(int(maxf(1.0, 1.5 * k)))
	sb.set_corner_radius_all(int(6.0 * k))
	sb.anti_aliasing = true
	return sb


## The first screen: the exhibit's wireframe, four live tiles, its W profile and its build.
func _draw_metrics() -> void:
	var c: Control = _canvas
	var sc: Node = get_node_or_null(showcase)
	var ex: Node = sc.get("exhibit") if sc != null else null
	var lay: Dictionary = _layout()
	var k: float = c.size.x / _sw
	var s: float = float(lay["s"])
	var white: Color = Style.UI_INK
	var soft: Color = Style.UI_INK_SOFT
	var dim: Color = Style.UI_INK_DIM
	var cyan: Color = Style.UI_ACCENT_SCREEN
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
	card.bg_color = Style.UI_VEIL
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
		_stops, lit, frac, Style.UI_GOLD)
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
