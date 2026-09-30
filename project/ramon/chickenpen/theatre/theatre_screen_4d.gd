extends Control

## A second picture over the stage: either the chicken's whole world, flat, or the shadow
## of the four-dimensional thing on the drum.
##
## TWO WAYS OF LOOKING, SIDE BY SIDE. The drum shows a slice - everything this room can
## show you is a slice - and this panel shows what the slice leaves out. On slide I that is
## the chicken's view of its own sheet: the ball is not in it, only the circle the ball
## makes. From slide II on it is the shadow: every point of the shape projected down, W
## included, so the whole of it is there at once while the drum shows one cut through it.
## Trym asked for wireframes if that was all we could do; the cross-section renderer draws
## no wires, so the wireframe is drawn here, in screen space, from lines on each shape's
## own skeleton (theatre_shapes_4d.shadow_lines).
##
## COLOUR IS W. A shadow throws away one direction, and without something standing in for
## it the tesseract's inner and outer cubes are indistinguishable and the Klein bottle
## looks like it passes through itself. So each line is coloured by how far along W it
## is - blue one way, red the other - and where two lines cross in the picture in
## different colours, they did not cross in 4D.
##
## STYLED LIKE THE CAPTION BAND it sits above: the same dark panel, the same thin rule,
## sized from the viewport's height so it holds its proportions at any resolution.

@export_file("*.ttf") var font_file: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf"
@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.6
## Where the panel sits, as fractions of the screen: left, top, width. Its height follows
## from what it is showing.
@export var placement: Vector3 = Vector3(0.655, 0.075, 0.30)
@export var panel_color: Color = Color(0.03, 0.04, 0.08, 0.78)
@export var rule_color: Color = Color(0.25, 0.85, 1.0, 0.9)
@export var title_color: Color = Color(0.72, 0.86, 0.98)

## How far the eye stands along W for the shadow's perspective, and along Z for the
## picture's own. Close enough that depth reads, far enough that nothing crosses the eye.
@export_range(1.5, 10.0, 0.1) var w_eye: float = 3.4
@export_range(2.0, 20.0, 0.1) var z_eye: float = 7.0

var _font: Font
var _mode: String = ""
var _title: String = ""
var _fade: float = 0.0
var _showing: bool = false

# The flat world: the sheet's own coordinates, x across and y up from its floor line.
var _flat_view := Rect2(-2.2, -0.35, 4.4, 2.5)
var _shapes: Array = []
var _chicken := Vector3(-1.3, 0.0, 1.0)

# The shadow.
var _lines: Array = []
var _basis: Projection = Projection.IDENTITY
var _offset: Vector4 = Vector4.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load(font_file) as Font if ResourceLoader.exists(font_file) else ThemeDB.fallback_font


## The chicken's sheet, face on. [param view] is the part of the sheet to show.
func show_flat(title: String, view: Rect2) -> void:
	_mode = "flat"
	_title = title
	_flat_view = view
	_showing = true


## What is on the sheet this frame: [param shapes] as [outline, colour] pairs in sheet
## coordinates, and the chicken as (x, hop, facing).
func set_flat(shapes: Array, chicken: Vector3) -> void:
	_shapes = shapes
	_chicken = chicken


func show_shadow(title: String, lines: Array) -> void:
	_mode = "shadow"
	_title = title
	_lines = lines
	_showing = true


## How the shape is turned this frame, and where it is relative to the slice.
func set_shadow(basis: Projection, offset: Vector4 = Vector4.ZERO) -> void:
	_basis = basis
	_offset = offset


func hide_screen() -> void:
	_showing = false


func is_showing() -> bool:
	return _showing


func mode() -> String:
	return _mode if _showing else ""


func _process(delta: float) -> void:
	var was: float = _fade
	_fade = move_toward(_fade, 1.0 if _showing else 0.0, delta / maxf(fade_seconds, 0.01))
	# ONE MORE REDRAW ON THE WAY TO NOTHING. A CanvasItem keeps its last drawing until it is
	# told to draw again, so stopping the redraws when the fade reached zero left the last,
	# nearly transparent frame on screen for good - a ghost of the tesseract hanging over
	# the gloves and the goat, which the captures caught.
	if _fade > 0.0 or was > 0.0 or _showing:
		queue_redraw()


func _panel() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	var w: float = screen.x * placement.z
	var aspect: float = _flat_view.size.x / _flat_view.size.y if _mode == "flat" else 1.25
	return Rect2(screen.x * placement.x, screen.y * placement.y, w, w / aspect)


func _draw() -> void:
	if _fade <= 0.001 or _mode == "":
		return
	var screen: Vector2 = get_viewport_rect().size
	var r: Rect2 = _panel()
	var a: float = _fade
	var box := StyleBoxFlat.new()
	box.bg_color = Color(panel_color, panel_color.a * a)
	box.border_color = Color(rule_color, 0.35 * a)
	box.set_border_width_all(maxi(1, int(screen.y / 900.0)))
	box.set_corner_radius_all(int(screen.y * 0.008))
	draw_style_box(box, r)
	var title_size: int = maxi(10, int(screen.y * 0.019))
	var pad: float = screen.y * 0.016
	draw_string(_font, r.position + Vector2(pad, pad + _font.get_ascent(title_size)), _title,
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0, title_size, Color(title_color, 0.9 * a))
	var inner := Rect2(r.position + Vector2(pad, pad * 2.2 + title_size),
		r.size - Vector2(pad * 2.0, pad * 3.2 + title_size))
	if _mode == "flat":
		_draw_flat(inner, a, screen.y)
	else:
		_draw_shadow(inner, a, screen.y)


# ---------------------------------------------------------------- flat

func _to_flat(inner: Rect2, p: Vector2) -> Vector2:
	var k: float = minf(inner.size.x / _flat_view.size.x, inner.size.y / _flat_view.size.y)
	var centre: Vector2 = inner.get_center()
	var mid: Vector2 = _flat_view.get_center()
	return centre + Vector2(p.x - mid.x, -(p.y - mid.y)) * k


func _draw_flat(inner: Rect2, a: float, h: float) -> void:
	var line: float = maxf(1.5, h / 540.0)
	# The floor: the whole of "down" there is.
	draw_line(_to_flat(inner, Vector2(_flat_view.position.x, 0.0)),
		_to_flat(inner, Vector2(_flat_view.end.x, 0.0)), Color(0.55, 0.78, 0.95, 0.8 * a), line * 1.4)
	for shape in _shapes:
		var outline: PackedVector2Array = shape[0]
		if outline.size() < 3:
			continue
		var points := PackedVector2Array()
		for p in outline:
			points.append(_to_flat(inner, p))
		var colour: Color = shape[1]
		draw_colored_polygon(points, Color(colour, 0.92 * a))
	_draw_chicken(inner, a)


## The chicken as the chicken would draw itself: flat, side on, facing along x.
func _draw_chicken(inner: Rect2, a: float) -> void:
	var face: float = _chicken.z
	var base := Vector2(_chicken.x, _chicken.y)
	var body: Color = Color(0.97, 0.95, 0.90, a)
	var red: Color = Color(0.92, 0.18, 0.16, a)
	var yellow: Color = Color(1.0, 0.76, 0.18, a)
	var at := func(dx: float, dy: float) -> Vector2:
		return _to_flat(inner, base + Vector2(dx * face, dy))
	_ellipse(at.call(0.0, 0.30), _scale(inner) * Vector2(0.24, 0.15), body)
	_ellipse(at.call(-0.22, 0.40), _scale(inner) * Vector2(0.08, 0.10), body)
	_ellipse(at.call(0.19, 0.55), _scale(inner) * Vector2(0.085, 0.085), body)
	_ellipse(at.call(0.20, 0.655), _scale(inner) * Vector2(0.06, 0.03), red)
	draw_colored_polygon(PackedVector2Array([at.call(0.26, 0.57), at.call(0.35, 0.545),
		at.call(0.26, 0.52)]), yellow)
	_ellipse(at.call(0.22, 0.575), _scale(inner) * Vector2(0.014, 0.014), Color(0.05, 0.05, 0.08, a))
	var leg: float = maxf(1.5, _scale(inner) * 0.02)
	for dx in [-0.05, 0.05]:
		draw_line(at.call(dx, 0.16), at.call(dx, 0.0), yellow, leg)
		draw_line(at.call(dx, 0.0), at.call(dx + 0.07, 0.0), yellow, leg)


func _scale(inner: Rect2) -> float:
	return minf(inner.size.x / _flat_view.size.x, inner.size.y / _flat_view.size.y)


func _ellipse(centre: Vector2, radii: Vector2, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var t: float = TAU * float(i) / 20.0
		points.append(centre + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	draw_colored_polygon(points, colour)


# ---------------------------------------------------------------- shadow

func _project(inner: Rect2, p: Vector4) -> Vector3:
	var q: Vector4 = _basis * p + _offset
	var k: float = w_eye / maxf(w_eye - q.w, 0.2)
	var v := Vector3(q.x, q.y, q.z) * k
	# A fixed three-quarter view of the 3D shadow, looking a little down on it.
	var tilt: float = 0.32
	v = Vector3(v.x, v.y * cos(tilt) - v.z * sin(tilt), v.y * sin(tilt) + v.z * cos(tilt))
	var s: float = z_eye / maxf(z_eye - v.z, 0.5)
	var scale: float = minf(inner.size.x, inner.size.y) * 0.29
	return Vector3(inner.get_center().x + v.x * s * scale, inner.get_center().y - v.y * s * scale, q.w)


func _draw_shadow(inner: Rect2, a: float, h: float) -> void:
	var width: float = maxf(1.2, h / 720.0)
	for line in _lines:
		var pts: PackedVector4Array = line
		if pts.size() < 2:
			continue
		var prev: Vector3 = _project(inner, pts[0])
		for i in range(1, pts.size()):
			var here: Vector3 = _project(inner, pts[i])
			var w: float = clampf((prev.z + here.z) * 0.5 / 1.2, -1.0, 1.0)
			draw_line(Vector2(prev.x, prev.y), Vector2(here.x, here.y), _w_colour(w, a), width)
			prev = here


## Blue one way along W, red the other, white on the slice.
func _w_colour(w: float, a: float) -> Color:
	var mid := Color(0.92, 0.95, 1.0)
	var c: Color = mid.lerp(Color(1.0, 0.35, 0.35), w) if w > 0.0 else mid.lerp(Color(0.30, 0.55, 1.0), -w)
	return Color(c, 0.85 * a)
