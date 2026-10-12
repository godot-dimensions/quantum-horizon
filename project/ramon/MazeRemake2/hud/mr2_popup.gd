extends Control
## THE POPUP EXPLAINER (12 Oct, Ramon: "a little more explainer ... when you see the first walker, that the
## point is the walkers dont see you, and that you have to escape to another slice. maybe with a popup
## explainer. and maybe in the beginning a quick explainer that how each level unlocks different slicing
## controls"). A card in the middle of the screen; the game holds you still while it shows, and Space,
## Enter or a click carries on.
##
##   "controls"  at the start of each level: the slicing controls, each marked YOURS, NEW or LATER, and
##               one line on what this level asks of them
##   "walkers"   after the first sighting's film: a small diagram acts it out (a Tall One in one slice, you
##               in it, its eyes going red, you shifting to the next slice, the red fading) beside three lines
##
## open(kind, data) shows it; close() fades it out. data: kicker, title, rows [[key, what, status]], line.

const D := preload("res://ramon/MazeRemake2/hud/mr2_draw.gd")
const Build := preload("res://ramon/MazeRemake2/world/mr2_build.gd")

var kind: String = ""
var data: Dictionary = {}
var _open: bool = false
var _a: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func open(k: String, d: Dictionary) -> void:
	kind = k
	data = d
	_open = true
	_t = 0.0


func close() -> void:
	_open = false


func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	_t += delta
	var was: float = _a
	_a = move_toward(_a, 1.0 if _open else 0.0, delta * 4.0)
	if _a > 0.0 or was > 0.0:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.01:
		return
	var u: float = D.u_of(self)
	var vs: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.45 * _a))
	var w: float = (640.0 if kind == "walkers" else 560.0) * u
	var h: float = (300.0 if kind == "walkers" else 320.0) * u
	var r := Rect2((vs.x - w) * 0.5, (vs.y - h) * 0.5, w, h)
	D.glass(self, r, 14.0 * u, _a)
	var x0: float = r.position.x + 30.0 * u
	D.text(self, Vector2(x0, r.position.y + 38.0 * u), String(data.get("kicker", "")), "key", "caption", u, Color(D.ACCENT, _a))
	D.text(self, Vector2(x0, r.position.y + 78.0 * u), String(data.get("title", "")), "title", "headline", u, Color(1, 1, 1, _a))
	if kind == "walkers":
		_walkers(Rect2(x0, r.position.y + 100.0 * u, 230.0 * u, 140.0 * u), u)
		var tx: float = x0 + 254.0 * u
		var y: float = r.position.y + 118.0 * u
		for line in data.get("lines", []):
			y = _para(tx, y, String(line), r.end.x - tx - 26.0 * u, u) + 12.0 * u
	else:
		var y: float = r.position.y + 118.0 * u
		for row in data.get("rows", []):
			_row(x0, y, r.end.x - 30.0 * u, row, u)
			y += 42.0 * u
		_para(x0, y + 12.0 * u, String(data.get("line", "")), w - 60.0 * u, u)
	# Carry on.
	var label: String = "Continue"
	var kw: float = D.keycap_width("SPACE", u)
	var lw: float = D.text_width(label, "text", "caption", u)
	var kx: float = r.end.x - 30.0 * u - lw - 8.0 * u - kw
	var ky: float = r.end.y - 44.0 * u
	D.keycap(self, Rect2(kx, ky, kw, 24.0 * u), "SPACE", u, fmod(_t, 1.6) < 0.25, _a)
	D.text(self, Vector2(kx + kw + 8.0 * u, ky + 17.0 * u), label, "text", "caption", u, Color(1, 1, 1, _a))


## `text` wrapped to `width` from (x, y), one body line after another; returns the y under the last.
func _para(x: float, y: float, text: String, width: float, u: float) -> float:
	var line: String = ""
	var words: PackedStringArray = text.split(" ", false)
	for i in words.size():
		var next: String = words[i] if line == "" else line + " " + words[i]
		if line != "" and D.text_width(next, "text", "body", u) > width:
			D.text(self, Vector2(x, y), line, "text", "body", u, Color(D.INK_SOFT, _a))
			y += 20.0 * u
			line = words[i]
		else:
			line = next
	if line != "":
		D.text(self, Vector2(x, y), line, "text", "body", u, Color(D.INK_SOFT, _a))
		y += 20.0 * u
	return y


## A control: its key, what it does, and whether it is yours yet.
func _row(x: float, y: float, right: float, row: Array, u: float) -> void:
	var status: String = String(row[2]) if row.size() > 2 else "yours"
	var later: bool = status == "later"
	var a: float = _a * (0.45 if later else 1.0)
	var key: String = String(row[0])
	var kw: float = maxf(D.keycap_width(key, u), 54.0 * u)
	D.keycap(self, Rect2(x, y, kw, 26.0 * u), key, u, status == "new" and fmod(_t, 1.2) < 0.6, a)
	D.text(self, Vector2(x + kw + 14.0 * u, y + 18.0 * u), String(row[1]), "text", "body", u, Color(1, 1, 1, a))
	var chip: String = {"yours": "YOURS", "new": "NEW", "later": "LATER"}.get(status, "")
	var cw: float = D.text_width(chip, "key", "micro", u) + 18.0 * u
	var cr := Rect2(right - cw, y + 3.0 * u, cw, 20.0 * u)
	var col: Color = D.ACCENT if status == "new" else Color(1, 1, 1, 0.5)
	D.rounded(self, cr, 10.0 * u, Color(col, (0.22 if status == "new" else 0.06) * a), Color(col, 0.7 * a), maxi(1, int(u)))
	D.text(self, Vector2(cr.position.x + 9.0 * u, cr.position.y + 14.0 * u), chip, "key", "micro", u, Color(1, 1, 1, a))


## The diagram: three slices (kata, home, ana), a Tall One standing in the middle one, you (a dot)
## coming into its slice, its eyes going red, you shifting up into the next slice, the red fading.
func _walkers(s: Rect2, u: float) -> void:
	var p: float = fmod(_t, 6.0)
	# Where you are: 0 its slice, 1 the next one up.
	var up: float = smoothstep(2.6, 3.4, p) * (1.0 - smoothstep(5.2, 5.9, p))
	var red: float = smoothstep(0.6, 2.2, p) * (1.0 - smoothstep(3.0, 4.2, p))
	var rows: Array = [["ANA", Build.ANA], ["HOME", Build.HOME], ["KATA", Build.KATA]]
	var rh: float = s.size.y / 3.0
	for i in 3:
		var y: float = s.position.y + rh * (float(i) + 0.5)
		var col: Color = rows[i][1]
		draw_line(Vector2(s.position.x + 44.0 * u, y + rh * 0.32), Vector2(s.end.x, y + rh * 0.32), Color(col, 0.55 * _a), 2.0 * u)
		D.text(self, Vector2(s.position.x, y + rh * 0.32 + 4.0 * u), String(rows[i][0]), "key", "micro", u, Color(col.lerp(Color.WHITE, 0.3), 0.8 * _a))
	# The Tall One, standing on the home slice's line.
	var base := Vector2(s.position.x + s.size.x * 0.72, s.position.y + rh * 1.5 + rh * 0.32)
	var fh: float = rh * 0.9
	var grey := Color(0.62, 0.64, 0.68, _a)
	var neck := base + Vector2(0, -fh * 0.78)
	draw_line(base + Vector2(-5.0 * u, 0), base + Vector2(0, -fh * 0.45), grey, 2.0 * u)
	draw_line(base + Vector2(5.0 * u, 0), base + Vector2(0, -fh * 0.45), grey, 2.0 * u)
	draw_line(base + Vector2(0, -fh * 0.45), neck, grey, 2.4 * u)
	draw_line(neck + Vector2(-7.0 * u, 2.0 * u), base + Vector2(-9.0 * u, -fh * 0.2), grey, 1.6 * u)
	draw_line(neck + Vector2(7.0 * u, 2.0 * u), base + Vector2(9.0 * u, -fh * 0.2), grey, 1.6 * u)
	var head := neck + Vector2(0, -fh * 0.12)
	draw_circle(head, fh * 0.09, grey)
	var eye: Color = Color(0.75, 0.78, 0.8).lerp(Color(1.0, 0.1, 0.06), red)
	draw_circle(head + Vector2(-2.6 * u, -0.5 * u), (1.2 + red) * u, Color(eye, _a))
	draw_circle(head + Vector2(2.6 * u, -0.5 * u), (1.2 + red) * u, Color(eye, _a))
	# You: a white dot walking in from the left along its slice, then up into the next.
	var walk: float = smoothstep(0.0, 1.6, p) * (1.0 - smoothstep(5.2, 5.9, p))
	var you := Vector2(lerpf(s.position.x + 60.0 * u, base.x - 54.0 * u, walk), lerpf(base.y - 7.0 * u, base.y - rh - 7.0 * u, up))
	draw_circle(you, 6.0 * u, Color(1, 1, 1, _a))
	if up > 0.05 and up < 0.95:
		draw_line(you + Vector2(0, 10.0 * u), you + Vector2(0, 22.0 * u), Color(1, 1, 1, 0.5 * _a), 1.5 * u)
	if red > 0.3:
		D.text(self, Vector2(base.x + 14.0 * u, head.y + 4.0 * u), "SEEN", "key", "micro", u, Color(1.0, 0.36, 0.3, red * _a))
