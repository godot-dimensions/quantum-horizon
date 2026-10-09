@tool
extends Node

## Kit: text painted on a wall of the KitRoom it is a child of (kit_room_4d.gd). The room does the
## painting; this says what and where. Change anything here and the room repaints.
##
##   kind "lesson"  number, title, a line under it, a paragraph, and a row of control icons, left
##                  aligned, the concept frames' wall of type
##   kind "sign"    a title and a line under it, centred: the CREATION LAB over a doorway
##   kind "label"   VOXEL LAB (carried copy, 9 Oct): a small blue panel painted on the wall over a
##                  specimen, the research board's look: its letter, a title, a line, a diagram
##                  (`diagram`) and an arrow down at the specimen (Ramon: "a simple marker on the wall
##                  above each of the three specimens ... a downward-pointing arrow ... a very short
##                  description")
##
## `along` is where it runs along the wall (from the room's centre, in metres; for "n"/"s" walls
## along x, for "w"/"e" along z) and `up` how high (from the floor). `outside` paints the wall's
## outer face instead (a sign seen from the room next door).
##
## LIVE (Ramon, 4 Oct: "is the 4D basics wall dynamic, the text? if not make it"): `live` prints it
## through a viewport of its own instead of a picture rendered once, redrawn whenever what it says
## changes, so the paragraph can name the animal on the plinth: {name} and {balls} in the body, and
## {action} in an icon's label (the exhibit's E key), are filled in from `showcase`.
##
## SIZES are steps on the lab's type ladder (kit_style.gd), in metres: the title a poster, the line
## under it a hero, the paragraph a headline, the icons' labels a subhead.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")
const RD := preload("res://ramon/VoxelLab/carried/scripts/rd_build.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const PPM := 160.0

@export_enum("n", "s", "w", "e") var side: String = "w":
	set(v):
		side = v
		_changed()
## For a polygon room (KitRoom `outline`): which edge it is painted on (-1: use `side`).
@export var edge: int = -1:
	set(v):
		edge = v
		_changed()
@export var along: Vector2 = Vector2(-2.0, 6.0):
	set(v):
		along = v
		_changed()
@export var up: Vector2 = Vector2(1.4, 7.4):
	set(v):
		up = v
		_changed()
@export var outside: bool = false:
	set(v):
		outside = v
		_changed()
@export_enum("lesson", "sign", "label") var kind: String = "lesson":
	set(v):
		kind = v
		_changed()
@export var number: int = 1:
	set(v):
		number = v
		_changed()
@export var title: String = "4D Basics":
	set(v):
		title = v
		_changed()
@export var subtitle: String = "":
	set(v):
		subtitle = v
		_changed()
@export_multiline var body: String = "":
	set(v):
		body = v
		_changed()
## A label's diagram: "voxels", "inside" or "hidden" (_diagram()).
@export var diagram: String = "":
	set(v):
		diagram = v
		_changed()
## A label's letter (A, B, C).
@export var letter: String = "":
	set(v):
		letter = v
		_changed()
## Control icons under a lesson: [icon kind, label] (rd_build.gd icon()).
@export var icons: Array = []:
	set(v):
		icons = v
		_changed()
## A colour code for the wall it is painted on (kit_style.gd CODES): "blue" paints that whole wall
## blue and the text white; the text and its layout stay as they are.
@export_enum("none", "blue") var code: String = "none":
	set(v):
		code = v
		_changed()
## Printed live (a viewport redrawn when it changes) rather than rendered once; see the note above.
@export var live: bool = false:
	set(v):
		live = v
		_changed()
## The showcase whose animal fills in {name}, {balls} and {action}.
@export var showcase: NodePath
## Pixels a metre for the live print.
@export_range(80.0, 400.0, 10.0) var live_ppm: float = 200.0
## How much the paint glows (0 is plain paint, lit by the room).
@export_range(0.0, 1.0, 0.01) var glow: float = 0.15
## Off: the room paints nothing of it, and its wall goes back to the room's own (a wall panel,
## kit_wall_panel_4d.gd, has taken its place; creation_lab_4d.gd set_walls flips between them).
@export var enabled: bool = true:
	set(v):
		enabled = v
		_changed()


var _said: String = ""


func _process(_delta: float) -> void:
	if not live or not enabled or Engine.is_editor_hint():
		return
	# Redrawn only when what it would say has changed: a new animal, or its numbers arriving.
	var now: String = _filled(body) + "|" + _filled(str(icons))
	if now != _said:
		_said = now
		var room: Node = get_parent()
		if room != null and room.has_method("refresh_text"):
			room.call("refresh_text", self)


## `text` with the animal on the plinth filled in; missing numbers read naturally.
func _filled(text: String) -> String:
	if not text.contains("{"):
		return text
	var sc: Node = get_node_or_null(showcase) if not showcase.is_empty() else null
	var d: Dictionary = sc.call("data") if sc != null and sc.has_method("data") else {}
	var nm: String = String(d.get("name", "")).to_lower()
	var balls: int = int((d.get("stats", {}) as Dictionary).get("balls", 0))
	var act: String = String(sc.call("action_label")) if sc != null and sc.has_method("action_label") else ""
	return text.replace("{name}", nm if not nm.is_empty() else "animal").replace("{balls}", str(balls) if balls > 0 else "a handful of") \
		.replace("{action}", act if not act.is_empty() else "Add a ball")


func _changed() -> void:
	var room: Node = get_parent()
	if room != null and room.has_method("_later"):
		room.call("_later")


func _px(m: float) -> int:
	return int(round(m * PPM))


func paint(c: Control, ink: Dictionary) -> void:
	if kind == "label":
		_paint_label(c)
		return
	if kind == "sign":
		var f: Font = LabPrint.font("black")
		var px: int = _px(minf(0.9, (up.y - up.x) * 0.42))
		c.draw_string(f, Vector2(0.0, c.size.y * 0.52), title, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, px, ink["text"])
		if not subtitle.is_empty():
			c.draw_string(LabPrint.font("bold"), Vector2(0.0, c.size.y * 0.52 + px * 0.62), subtitle, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, int(px * 0.26), ink["accent"])
		return
	var w: float = c.size.x
	var k: float = c.size.x / maxf(absf(along.y - along.x), 0.01)
	var m := func(role: Variant) -> int: return int(round(Style.type_m(role) * k))
	var icon_band: float = 1.55 * k if not icons.is_empty() else 0.0
	LabPrint.block_fit(c, Vector2(0.0, 0.0), w, c.size.y - icon_band, [
		["%02d" % number, "bold", m.call(7), ink["accent"], 0.0],
		[title, "black", m.call("poster"), ink["text"], 0.2 * k],
		[subtitle, "body", m.call("hero"), ink["text"], 0.4 * k],
		[_filled(body), "body", m.call("headline"), ink["dim"], 0.0],
	])
	if not icons.is_empty():
		var filled_icons: Array = []
		for it in icons:
			filled_icons.append([it[0], _filled(String(it[1]))])
		# A label is centred under its icon, so a label wider than the first icon would run off the
		# left edge: the row starts far enough in for it.
		var first_w: float = LabPrint.font("bold").get_string_size(String(filled_icons[0][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, m.call("subhead")).x
		RD.icon_row(c, Vector2(maxf(0.0, (first_w - 0.7 * k) * 0.5), c.size.y - 1.45 * k), 0.7 * k, 0.5 * k, filled_icons, ink["text"], m.call("subhead"))


## A label: the blue of the colour-coded walls and the research board, white type; the letter big at
## the left, the title and a line beside it, the diagram at the right, and an arrow down at the bottom,
## at the specimen under it. Laid out in the canvas's own height (u), so any size reads the same.
func _paint_label(c: Control) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	var u: float = h / 100.0
	var blue: Color = Style.pick(Style.CODE_BLUE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = blue
	sb.set_corner_radius_all(int(6.0 * u))
	c.draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(w, h - 16.0 * u)))
	var white := Color(1, 1, 1)
	var dim := Color(0.84, 0.91, 1.0)
	var accent := Color(0.62, 0.86, 1.0)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var pad: float = 7.0 * u
	var lpx: int = int(34.0 * u)
	c.draw_string(fb, Vector2(pad, pad + lpx * 0.82), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, accent)
	var tx: float = pad + fb.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x + 5.0 * u
	var dg := Rect2(Vector2(w - pad - 36.0 * u, pad), Vector2(36.0 * u, h - 16.0 * u - pad * 2.0))
	var text_w: float = dg.position.x - tx - 4.0 * u
	c.draw_string(fb, Vector2(tx, pad + 13.0 * u), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, text_w, int(12.0 * u), white)
	var lines: PackedStringArray = _wrap(fl, subtitle, text_w, int(8.4 * u))
	for i in mini(lines.size(), 4):
		c.draw_string(fl, Vector2(tx, pad + 26.0 * u + float(i) * 10.5 * u), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(8.4 * u), dim)
	_diagram(c, dg, u, white, accent, blue)
	# The arrow down, under the panel's middle, at the specimen.
	var ax: float = w * 0.5
	var ay: float = h - 16.0 * u
	c.draw_colored_polygon(PackedVector2Array([Vector2(ax - 8.0 * u, ay - 0.5 * u), Vector2(ax + 8.0 * u, ay - 0.5 * u), Vector2(ax, ay + 13.0 * u)]), blue)


static func _wrap(f: Font, text: String, width: float, px: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line: String = ""
	for word in text.split(" ", false):
		var t: String = word if line.is_empty() else line + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width and not line.is_empty():
			out.append(line)
			line = word
		else:
			line = t
	if not line.is_empty():
		out.append(line)
	return out


## The label's diagram in `r`: line drawings in white on the blue.
##   voxels  a grid of voxels and the one surface that runs through them
##   inside  a cut into the ground: the layers (grass, earth, stone) round a round bite
##   hidden  two slices along W: the front one whole, the one ana of it with a room in it
func _diagram(c: Control, r: Rect2, u: float, white: Color, accent: Color, blue: Color) -> void:
	var t: float = maxf(1.0, 1.1 * u)
	match diagram:
		"voxels":
			var n: int = 5
			var cell: float = minf(r.size.x, r.size.y) / float(n)
			var o: Vector2 = r.get_center() - Vector2(cell, cell) * float(n) * 0.5
			for i in n + 1:
				c.draw_line(o + Vector2(cell * i, 0), o + Vector2(cell * i, cell * n), Color(white, 0.55), t * 0.7)
				c.draw_line(o + Vector2(0, cell * i), o + Vector2(cell * n, cell * i), Color(white, 0.55), t * 0.7)
			# The voxels the surface crosses, filled; the surface itself, one line.
			var pts := PackedVector2Array()
			for k in 21:
				var x: float = float(k) / 20.0
				pts.append(o + Vector2(x, 0.62 - 0.22 * sin(x * PI * 1.3)) * cell * float(n))
			for i in n:
				for j in n:
					var mid: Vector2 = o + Vector2(i + 0.5, j + 0.5) * cell
					var x2: float = (mid.x - o.x) / (cell * n)
					var sy: float = o.y + (0.62 - 0.22 * sin(x2 * PI * 1.3)) * cell * n
					if absf(mid.y - sy) < cell * 0.55:
						c.draw_rect(Rect2(o + Vector2(i, j) * cell + Vector2.ONE * t, Vector2.ONE * (cell - t * 2.0)), Color(accent, 0.55))
			c.draw_polyline(pts, white, t * 1.6, true)
		"inside":
			var box := Rect2(r.position + Vector2(0, r.size.y * 0.18), Vector2(r.size.x, r.size.y * 0.72))
			var bands: Array = [[0.0, 0.16, Color(0.40, 0.74, 0.22)], [0.16, 0.55, Color(0.56, 0.32, 0.12)], [0.55, 1.0, Color(0.42, 0.43, 0.46)]]
			for b in bands:
				c.draw_rect(Rect2(box.position + Vector2(0, box.size.y * float(b[0])), Vector2(box.size.x, box.size.y * (float(b[1]) - float(b[0])))), b[2])
			# The bite: what is cut away, the blue showing through, its edge in white.
			var bc := Vector2(box.get_center().x, box.position.y)
			var br: float = box.size.x * 0.32
			c.draw_circle(bc, br, blue)
			c.draw_arc(bc, br, 0.0, PI, 24, white, t * 1.4, true)
			c.draw_rect(box, white, false, t)
		"hidden":
			var s: float = minf(r.size.x, r.size.y) * 0.62
			var back := Rect2(r.position + Vector2(r.size.x - s, 0.0), Vector2(s, s))
			var front := Rect2(r.position + Vector2(0.0, r.size.y - s), Vector2(s, s))
			c.draw_rect(back, Color(white, 0.18))
			c.draw_rect(back, white, false, t)
			c.draw_circle(back.get_center(), s * 0.22, Color(0.66, 0.42, 0.92))
			c.draw_arc(back.get_center(), s * 0.22, 0.0, TAU, 24, white, t, true)
			c.draw_rect(front, blue)
			c.draw_rect(front, Color(white, 0.35))
			c.draw_rect(front, white, false, t)
			# W: from your slice (front) to the one ana of it.
			var a0: Vector2 = front.get_center() + Vector2(s * 0.18, -s * 0.18)
			var a1: Vector2 = back.get_center() - Vector2(s * 0.28, -s * 0.28)
			c.draw_line(a0, a1, accent, t * 1.3, true)
			var d: Vector2 = (a1 - a0).normalized()
			var nn := Vector2(-d.y, d.x)
			c.draw_colored_polygon(PackedVector2Array([a1 + d * 4.0 * u, a1 - d * 2.0 * u + nn * 3.0 * u, a1 - d * 2.0 * u - nn * 3.0 * u]), accent)
		_:
			pass
