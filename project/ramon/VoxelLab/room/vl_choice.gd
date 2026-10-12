extends Control

## The Voxel Lab's choice: what you can do where you stand, in the style of the control strip but
## bigger, just above it (Ramon, 8 Oct: "you get two options ... watch the presentation, maybe with an
## eye icon in front of it, and manipulate the object, and maybe there's a little mining logo").
## It shows only at a ring where there is something to do (the room's spots); each option is a key
## (1, 2) drawn as a button, which a click takes too when the cursor is free (Esc), as the kit's rule
## for numbered boxes asks.
##
##   options   [{"key": "1", "icon": "eye", "label": "Watch the presentation"}, ...]
##   heading   a small line over the pill: what you are standing at
##   chosen(i) the option taken, by key or click
##
## Icons, drawn here: eye, pick (a pickaxe), fall (a column tipping), globe, fly (a paper plane),
## door.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")

signal chosen(index: int)

var options: Array = []:
	set(v):
		if str(v) != str(options):
			options = v
			_hover = -1
var heading: String = ""
## At least this wide (the room makes it the control strip's width under it), and how wide it would be
## on its own, last drawn.
var match_width: float = 0.0
var natural_width: float = 0.0
## Shown or not; it fades.
var shown: bool = false
var _a: float = 0.0
var _rects: Array = []
var _hover: int = -1
var _flash: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	var want: float = 1.0 if shown and not options.is_empty() else 0.0
	_a = move_toward(_a, want, delta * 6.0)
	for k in _flash.keys():
		_flash[k] = float(_flash[k]) - delta
		if float(_flash[k]) <= 0.0:
			_flash.erase(k)
	var m: Vector2 = get_viewport().get_mouse_position()
	_hover = -1
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and _a > 0.5:
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(m):
				_hover = i
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _a < 0.5 or options.is_empty():
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		for i in options.size():
			# The key's label, its place on the keyboard, or the keypad's (round 3: "pressing 2 ... appears
			# to do nothing").
			var want: String = String(options[i].get("key", ""))
			if OS.get_keycode_string(k.keycode) == want or OS.get_keycode_string(k.physical_keycode) == want \
					or OS.get_keycode_string(k.keycode) == "Kp " + want:
				take(i)
				get_viewport().set_input_as_handled()
				return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(mb.position):
				take(i)
				get_viewport().set_input_as_handled()
				return


func take(i: int) -> void:
	if i < 0 or i >= options.size():
		return
	_flash[i] = 0.35
	chosen.emit(i)


func _draw() -> void:
	_rects = []
	if _a <= 0.01 or options.is_empty():
		return
	var u: float = size.y / 720.0
	var fk: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("bold")
	var kpx: int = Style.type_px("lead", u)
	var lpx: int = Style.type_px("subhead", u)
	var h: float = 62.0 * u
	var key_w: float = 34.0 * u
	var icon_w: float = 34.0 * u
	var pad: float = 18.0 * u
	var gap: float = 30.0 * u
	var widths: Array = []
	var total: float = pad * 2.0
	for o in options:
		var lw: float = fl.get_string_size(String(o.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
		var w: float = key_w + 12.0 * u + icon_w + 12.0 * u + lw
		widths.append(w)
		total += w
	total += gap * float(options.size() - 1)
	natural_width = total
	var inner: float = total
	total = maxf(total, match_width)
	# Just above the control strip (which sits 22 px off the bottom, 40 px high).
	var r := Rect2(Vector2((size.x - total) * 0.5, size.y - 62.0 * u - 22.0 * u - h), Vector2(total, h))
	if not heading.is_empty():
		var hpx: int = Style.type_px("caption", u)
		draw_string(LabPrint.font("bold"), Vector2(r.position.x, r.position.y - 9.0 * u), heading, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, hpx,
			Color(Style.UI_INK_DIM, Style.UI_INK_DIM.a * _a))
	draw_style_box(Style.glass_box(h * 0.5, _a), r)
	var x: float = r.position.x + pad + (total - inner) * 0.5
	for i in options.size():
		var o: Dictionary = options[i]
		var w: float = widths[i]
		var cell := Rect2(Vector2(x - gap * 0.4, r.position.y + 6.0 * u), Vector2(w + gap * 0.8, h - 12.0 * u))
		_rects.append(cell)
		var lit: bool = i == _hover or _flash.has(i)
		if lit:
			var hb := StyleBoxFlat.new()
			hb.bg_color = Color(Style.UI_ACCENT, 0.22 * _a)
			hb.set_corner_radius_all(int(cell.size.y * 0.5))
			draw_style_box(hb, cell)
		var ink := Color(Style.UI_INK, _a)
		var kr := Rect2(Vector2(x, r.get_center().y - key_w * 0.5), Vector2(key_w, key_w))
		var kb := StyleBoxFlat.new()
		kb.bg_color = Color(Style.UI_ACCENT, (0.9 if lit else 0.0) * _a)
		kb.draw_center = lit
		kb.border_color = Color(Style.UI_ACCENT if lit else Style.UI_INK, 0.85 * _a)
		kb.set_border_width_all(int(maxf(1.0, 2.0 * u)))
		kb.set_corner_radius_all(int(7 * u))
		draw_style_box(kb, kr)
		draw_string(fk, Vector2(kr.position.x, kr.get_center().y + kpx * 0.36), String(o.get("key", "")), HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, kpx,
			Color(Style.UI_GLASS, _a) if lit else ink)
		var ic := Rect2(Vector2(kr.end.x + 12.0 * u, r.get_center().y - icon_w * 0.5), Vector2(icon_w, icon_w))
		icon(self, String(o.get("icon", "")), ic, Color(Style.UI_ACCENT_SCREEN, _a), u)
		draw_string(fl, Vector2(ic.end.x + 12.0 * u, r.get_center().y + lpx * 0.36), String(o.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, ink)
		x += w + gap
		if i < options.size() - 1:
			draw_line(Vector2(x - gap * 0.5, r.position.y + 14.0 * u), Vector2(x - gap * 0.5, r.end.y - 14.0 * u), Color(Style.UI_INK, 0.22 * _a), maxf(1.0, u))


## The option icons, line drawings in `r`.
static func icon(c: CanvasItem, kind: String, r: Rect2, col: Color, u: float) -> void:
	var w: float = maxf(1.5, 2.2 * u)
	var m: Vector2 = r.get_center()
	var s: float = r.size.x * 0.5
	match kind:
		"eye":
			var pts := PackedVector2Array()
			for i in 25:
				var t: float = float(i) / 24.0 * PI
				pts.append(m + Vector2(-cos(t) * s, -sin(t) * s * 0.52))
			for i in 25:
				var t: float = float(i) / 24.0 * PI
				pts.append(m + Vector2(cos(t) * s, sin(t) * s * 0.52))
			c.draw_polyline(pts, col, w, true)
			c.draw_circle(m, s * 0.30, col)
			c.draw_circle(m, s * 0.12, Color(Style.UI_GLASS, col.a))
		"pick":
			# A pickaxe: a curved head across the top of a handle running down to the left.
			var head := PackedVector2Array()
			for i in 17:
				var t: float = lerpf(-0.95, 0.95, float(i) / 16.0)
				head.append(m + Vector2(sin(t) * s * 0.95, -cos(t) * s * 0.55 - s * 0.05).rotated(0.62))
			c.draw_polyline(head, col, w * 1.6, true)
			c.draw_line(m + Vector2(s * 0.18, -s * 0.42), m + Vector2(-s * 0.72, s * 0.86), col, w * 1.4, true)
		"fall":
			# A column tipping over, its arc of fall dotted behind it.
			var base := m + Vector2(-s * 0.55, s * 0.85)
			var dir := Vector2(0.62, -0.78).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var q := PackedVector2Array([base - nrm * s * 0.2, base + nrm * s * 0.2, base + nrm * s * 0.2 + dir * s * 1.5, base - nrm * s * 0.2 + dir * s * 1.5])
			q.append(q[0])
			c.draw_polyline(q, col, w, true)
			for i in 5:
				var t: float = lerpf(-PI * 0.5, -0.2, float(i) / 4.0)
				c.draw_circle(base + Vector2(cos(t), sin(t)) * s * 1.55, maxf(1.0, 1.4 * u), col)
			c.draw_line(m + Vector2(-s, s * 0.95), m + Vector2(s, s * 0.95), col, w, true)
		"globe":
			c.draw_arc(m, s * 0.9, 0.0, TAU, 40, col, w, true)
			c.draw_line(m + Vector2(-s * 0.9, 0), m + Vector2(s * 0.9, 0), col, w * 0.8, true)
			var mer := PackedVector2Array()
			for i in 25:
				var t: float = float(i) / 24.0 * TAU
				mer.append(m + Vector2(cos(t) * s * 0.38, sin(t) * s * 0.9))
			c.draw_polyline(mer, col, w * 0.8, true)
			c.draw_arc(m + Vector2(0, -s * 0.9), s * 0.95, PI * 0.25, PI * 0.75, 16, col, w * 0.6, true)
		"fly":
			var a := m + Vector2(s * 0.95, -s * 0.7)
			var b := m + Vector2(-s * 0.95, -s * 0.05)
			var d := m + Vector2(-s * 0.05, s * 0.2)
			var e := m + Vector2(s * 0.05, s * 0.9)
			c.draw_polyline(PackedVector2Array([a, b, d, a, e, d]), col, w, true)
		"door":
			c.draw_rect(Rect2(m - Vector2(s * 0.55, s * 0.9), Vector2(s * 1.1, s * 1.8)), col, false, w)
		"build":
			# Bricks in a little wall, the top one going on.
			var bw: float = s * 0.62
			var bh: float = s * 0.42
			for row in [[Vector2(-1.0, 0.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0)], [Vector2(-0.5, -1.0), Vector2(0.5, -1.0)]]:
				for k in row:
					var at: Vector2 = m + Vector2(k.x * bw - bw * 0.5, s * 0.45 + k.y * bh)
					c.draw_rect(Rect2(at, Vector2(bw, bh)), col, false, w)
			c.draw_rect(Rect2(m + Vector2(-bw * 0.5, -s * 0.95), Vector2(bw, bh)), col)
		_:
			c.draw_circle(m, s * 0.35, col)
