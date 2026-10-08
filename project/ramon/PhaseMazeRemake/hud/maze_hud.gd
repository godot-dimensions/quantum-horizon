extends Control

## The maze's HUD, in the kit's black glass (PLAN.md steps 48, 53, 56, 58 to 60):
##   top left      the level, the stopwatch, your W moves against par
##   bottom left   THE VIEW BADGE: a small axis gizmo seen from above, as 4D Toys draws its axes. The two
##                 axes you see are lines pointing where they point (forward up the screen), the hidden one
##                 a ringed dot into the screen with Q and E beside it. Each axis has its letter and its own
##                 colour, W always cyan, so nothing rests on brightness alone. It swings with a turn.
##                 It answers 4D Miner's players' most asked question: which way am I looking?
##                 THE RULER under it: your cell along the hidden axis as ticks, and the cells before and
##                 after you marked open or closed, so a Q or E step is never blind (4D Miner's players
##                 asked to see one step along the hidden axis).
##   bottom right  the keys
##   top middle    toasts and the hint you asked for
##   middle        the results card at the exit
## Sizes scale with the window height (u = height / 720), so it reads the same at 4K and 145%.
##
## NO class_name (engine_gotchas.md).

const Kit := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")
const Lattice := preload("res://ramon/PhaseMazeRemake/maze/maze_lattice.gd")

const AXIS_NAMES := ["X", "Z", "W"]
const UNIT := [Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]

## Set by the game.
var view: Node
var body: Node4D
var lattice: RefCounted
## {"state": "lobby"|"playing"|"finished", "number": int, "name": String, "time": float, "running": bool,
##  "w_moves": int, "par": int, "best": float, "sight": bool, "first_person": bool}
var info: Dictionary = {}
## The results card, or {} for none: {"title", "time", "best", "new_best", "w_moves", "par", "next"}.
var result: Dictionary = {}
## A crosshair, when there is something to click.
var crosshair: bool = false
## How dark the fade is (0 clear, 1 black): level changes happen behind it.
var fade: float = 0.0

var _toast: String = ""
var _toast_col: Color = Color.WHITE
var _toast_left: float = 0.0
var _hint: String = ""
var _hint_left: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func toast(text: String, col: Color = Color.WHITE, seconds: float = 3.0) -> void:
	_toast = text
	_toast_col = col
	_toast_left = seconds


func show_hint(text: String, seconds: float = 7.0) -> void:
	_hint = text
	_hint_left = seconds


func _process(delta: float) -> void:
	_toast_left = maxf(0.0, _toast_left - delta)
	_hint_left = maxf(0.0, _hint_left - delta)
	queue_redraw()


static func clock(t: float) -> String:
	var m: int = int(t) / 60
	var s: float = t - float(m) * 60.0
	return "%d:%04.1f" % [m, s]


func _draw() -> void:
	var vs: Vector2 = get_viewport_rect().size
	var u: float = vs.y / 720.0
	var state: String = String(info.get("state", "lobby"))
	if state != "lobby":
		_card(u)
	if view != null and body != null and state != "lobby":
		_badge(u, vs)
	_keys(u, vs, state)
	_messages(u, vs)
	if not result.is_empty():
		_results(u, vs)
	if crosshair:
		draw_circle(vs * 0.5, 3.0 * u, Color(1, 1, 1, 0.9))
		draw_arc(vs * 0.5, 7.0 * u, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 1.5 * u, true)
	if fade > 0.001:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.025, 0.035, clampf(fade, 0.0, 1.0)))


func _glass(r: Rect2, u: float) -> void:
	draw_style_box(Kit.glass_box(10.0 * u, 1.0, Kit.UI_GLASS_ALPHA), r)


# -- the level card -----------------------------------------------------------------------------------

func _card(u: float) -> void:
	var r := Rect2(Vector2(18, 18) * u, Vector2(250, 104) * u)
	_glass(r, u)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var x: float = r.position.x + 14.0 * u
	draw_string(fs, Vector2(x, r.position.y + 22.0 * u), "PHASE MAZE  ·  %02d" % int(info.get("number", 1)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * u), Kit.UI_GREY)
	draw_string(fb, Vector2(x, r.position.y + 44.0 * u), String(info.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0 * u, int(17.0 * u), Kit.UI_INK)
	var t: float = float(info.get("time", 0.0))
	var running: bool = bool(info.get("running", false))
	draw_string(fb, Vector2(x, r.position.y + 78.0 * u), clock(t), HORIZONTAL_ALIGNMENT_LEFT, -1, int(26.0 * u), Kit.UI_INK if running or t > 0.0 else Kit.UI_INK_DIM)
	var wm: int = int(info.get("w_moves", 0))
	var par: int = int(info.get("par", 0))
	var line: String = "W MOVES %d  ·  PAR %d" % [wm, par]
	draw_string(fs, Vector2(x, r.position.y + 96.0 * u), line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * u), Style.role("w"))
	var best: float = float(info.get("best", 0.0))
	if best > 0.0:
		draw_string(fs, Vector2(r.end.x - 14.0 * u - 90.0 * u, r.position.y + 78.0 * u), "BEST " + clock(best), HORIZONTAL_ALIGNMENT_RIGHT, 90.0 * u, int(11.0 * u), Kit.UI_LIVE)


# -- the view badge and the ruler ----------------------------------------------------------------------

func _badge(u: float, vs: Vector2) -> void:
	var rig: Node4D = view.get("rig")
	if rig == null:
		return
	var b: Projection = rig.basis
	var right: Vector4 = b.x
	var fwd: Vector4 = -b.z
	var hid: Vector4 = b.w
	var r := Rect2(Vector2(18.0 * u, vs.y - 300.0 * u), Vector2(214, 226) * u)
	_glass(r, u)
	var fs: Font = LabPrint.font("bold")
	var fb: Font = LabPrint.font("black")
	draw_string(fs, r.position + Vector2(14, 22) * u, "YOUR VIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * u), Kit.UI_GREY)
	var centre: Vector2 = r.position + Vector2(r.size.x * 0.5, 96.0 * u)
	var rad: float = 52.0 * u
	# Faint floor of the view: a circle, forward marked.
	draw_arc(centre, rad, 0.0, TAU, 48, Color(1, 1, 1, 0.10), 1.0 * u, true)
	draw_line(centre + Vector2(0, -rad - 6.0 * u), centre + Vector2(0, -rad + 4.0 * u), Color(1, 1, 1, 0.35), 2.0 * u, true)
	var hidden: int = int(view.get("hidden_axis"))
	# Lines first (far ones under), then the dot on top.
	var order: Array = [0, 1, 2]
	order.sort_custom(func(a: int, c: int) -> bool: return absf(UNIT[a].dot(hid)) > absf(UNIT[c].dot(hid)))
	for a in order:
		var e: Vector4 = UNIT[a]
		var col: Color = _axis_col(a)
		var v := Vector2(e.dot(right), -e.dot(fwd))
		var flat: float = v.length()
		if flat > 0.12:
			draw_line(centre - v * rad, centre, Color(col, 0.35), 2.0 * u, true)
			draw_line(centre, centre + v * rad, col, 4.0 * u, true)
			var tip: Vector2 = centre + v * (rad + 14.0 * u)
			draw_string(fb, tip + Vector2(-6.0, 6.0) * u, AXIS_NAMES[a], HORIZONTAL_ALIGNMENT_LEFT, -1, int(15.0 * u), col)
		if absf(e.dot(hid)) > 0.7:
			# Into the screen: a ringed dot, the letter beside it.
			draw_circle(centre, 9.0 * u, Color(Kit.UI_GLASS, 1.0))
			draw_arc(centre, 9.0 * u, 0.0, TAU, 24, col, 2.5 * u, true)
			draw_circle(centre, 3.5 * u, col)
	var seen: PackedStringArray = []
	for a in 3:
		if a != hidden:
			seen.append(AXIS_NAMES[a])
	draw_string(fs, r.position + Vector2(14.0 * u, 180.0 * u), "YOU SEE %s  ·  HIDDEN " % " ".join(seen), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * u), Kit.UI_INK_SOFT)
	var hw: float = fs.get_string_size("YOU SEE %s  ·  HIDDEN " % " ".join(seen), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * u)).x
	draw_string(fb, r.position + Vector2(14.0 * u + hw, 180.0 * u), AXIS_NAMES[hidden], HORIZONTAL_ALIGNMENT_LEFT, -1, int(12.0 * u), _axis_col(hidden))
	_ruler(Rect2(r.position + Vector2(10.0, 190.0) * u, Vector2(r.size.x - 20.0 * u, 28.0 * u)), u, hidden, hid)


func _ruler(r: Rect2, u: float, h: int, hid: Vector4) -> void:
	if lattice == null:
		return
	var dims: Array = [lattice.nx, lattice.nz, lattice.nw]
	var n: int = int(dims[h])
	var c: Vector3i = lattice.cell_at(body.global_position)
	var s: int = 1 if UNIT[h].dot(hid) >= 0.0 else -1
	var idx: int = [c.x, c.y, c.z][h]
	var col: Color = _axis_col(h)
	var fs: Font = LabPrint.font("bold")
	# Q on the left (steps against the view's W), E on the right (along it).
	var q_open: bool = lattice.inside(c) and lattice.is_open(c, h, -s)
	var e_open: bool = lattice.inside(c) and lattice.is_open(c, h, s)
	var cap: float = 22.0 * u
	_cap(Rect2(r.position + Vector2(0, 3.0 * u), Vector2(cap, cap)), "Q", q_open, col, u)
	_cap(Rect2(Vector2(r.end.x - cap, r.position.y + 3.0 * u), Vector2(cap, cap)), "E", e_open, col, u)
	var x0: float = r.position.x + cap + 10.0 * u
	var x1: float = r.end.x - cap - 10.0 * u
	var y: float = r.position.y + 14.0 * u
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(col, 0.35), 2.0 * u, true)
	for i in n:
		# Cells laid out so E is to the right.
		var pos_i: int = i if s > 0 else n - 1 - i
		var x: float = x0 + (x1 - x0) * (float(pos_i) + 0.5) / float(n)
		var here: bool = i == idx
		if here:
			draw_rect(Rect2(Vector2(x - 9.0 * u, y - 9.0 * u), Vector2(18, 18) * u), col, true)
			draw_string(fs, Vector2(x - 9.0 * u, y + 5.0 * u), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 18.0 * u, int(11.0 * u), Color(Kit.UI_GLASS, 1.0))
		else:
			draw_rect(Rect2(Vector2(x - 6.0 * u, y - 6.0 * u), Vector2(12, 12) * u), Color(col, 0.55), false, 1.5 * u)


func _cap(r: Rect2, key: String, open_side: bool, col: Color, u: float) -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(int(5.0 * u))
	box.anti_aliasing = true
	if open_side:
		box.bg_color = col
	else:
		box.bg_color = Color(1, 1, 1, 0.04)
		box.border_color = Color(1, 1, 1, 0.25)
		box.set_border_width_all(int(maxf(1.0, 1.0 * u)))
	draw_style_box(box, r)
	var ink: Color = Color(Kit.UI_GLASS, 1.0) if open_side else Color(1, 1, 1, 0.35)
	draw_string(LabPrint.font("black"), Vector2(r.position.x, r.position.y + r.size.y * 0.72), key, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(13.0 * u), ink)
	if not open_side:
		draw_line(r.position + Vector2(4, r.size.y - 4) * Vector2(1, 1), r.position + Vector2(r.size.x - 4, 4), Color(1, 1, 1, 0.3), 1.5 * u, true)


func _axis_col(a: int) -> Color:
	return Style.role(["x", "z", "w"][a])


# -- the keys ------------------------------------------------------------------------------------------

func _keys(u: float, vs: Vector2, state: String) -> void:
	var rows: Array
	if state == "lobby":
		rows = [["1-6", "choose a level"], ["ENTER", "start"], ["WASD", "walk"], ["H", "back to the menu"], ["F1", "dev panel"]]
	else:
		rows = [["WASD", "walk"], ["F", "turn into W"], ["R", "level the slice"], ["Q E", "step through the hidden axis"],
			["RMB", "hold and drag: tilt"], ["G", "4D sight" + ("  ON" if bool(info.get("sight", false)) else "")], ["M", "map"], ["T", "hint"],
			["V", "first person" if not bool(info.get("first_person", false)) else "third person"], ["TAB", "camera"], ["BACKSPACE", "again"], ["1-6", "levels"]]
	var fs: Font = LabPrint.font("bold")
	var px: int = int(11.0 * u)
	var lh: float = 18.0 * u
	var h: float = lh * float(rows.size()) + 16.0 * u
	var r := Rect2(Vector2(vs.x - 236.0 * u, vs.y - 18.0 * u - h), Vector2(218.0 * u, h))
	_glass(r, u)
	for i in rows.size():
		var y: float = r.position.y + 8.0 * u + lh * float(i) + lh * 0.72
		var key: String = String(rows[i][0])
		var kw: float = fs.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 10.0 * u
		var kr := Rect2(Vector2(r.position.x + 10.0 * u, y - lh * 0.66), Vector2(kw, lh * 0.82))
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(int(4.0 * u))
		box.bg_color = Color(1, 1, 1, 0.10)
		draw_style_box(box, kr)
		draw_string(fs, Vector2(kr.position.x, y), key, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, px, Kit.UI_INK)
		draw_string(fs, Vector2(kr.end.x + 8.0 * u, y), String(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Kit.UI_INK_SOFT)


# -- toasts and hints ----------------------------------------------------------------------------------

func _messages(u: float, vs: Vector2) -> void:
	var fs: Font = LabPrint.font("bold")
	var y: float = 30.0 * u
	for m in [[_toast, _toast_left, _toast_col], [_hint, _hint_left, Style.role("w")]]:
		var text: String = String(m[0])
		var left: float = float(m[1])
		if text == "" or left <= 0.0:
			continue
		var a: float = clampf(left / 0.4, 0.0, 1.0)
		var px: int = int(15.0 * u)
		var tw: float = minf(fs.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, vs.x * 0.6)
		var r := Rect2(Vector2((vs.x - tw) * 0.5 - 18.0 * u, y), Vector2(tw + 36.0 * u, 34.0 * u))
		var box: StyleBoxFlat = Kit.glass_box(17.0 * u, a, Kit.UI_GLASS_ALPHA)
		draw_style_box(box, r)
		draw_string(fs, Vector2(r.position.x, r.position.y + 23.0 * u), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, Color(m[2], a))
		y += 42.0 * u


# -- the results card ----------------------------------------------------------------------------------

func _results(u: float, vs: Vector2) -> void:
	var r := Rect2(Vector2(vs.x * 0.5 - 190.0 * u, vs.y * 0.5 - 150.0 * u), Vector2(380, 196) * u)
	_glass(r, u)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var x: float = r.position.x
	var w: float = r.size.x
	draw_string(fs, Vector2(x, r.position.y + 28.0 * u), String(result.get("title", "")).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w, int(12.0 * u), Kit.UI_GREY)
	draw_string(fb, Vector2(x, r.position.y + 76.0 * u), clock(float(result.get("time", 0.0))), HORIZONTAL_ALIGNMENT_CENTER, w, int(40.0 * u), Kit.UI_INK)
	var best_line: String = "NEW BEST" if bool(result.get("new_best", false)) else "BEST " + clock(float(result.get("best", 0.0)))
	draw_string(fs, Vector2(x, r.position.y + 100.0 * u), best_line, HORIZONTAL_ALIGNMENT_CENTER, w, int(12.0 * u), Kit.UI_LIVE)
	var wl: String = "W MOVES %d  ·  PAR %d" % [int(result.get("w_moves", 0)), int(result.get("par", 0))]
	draw_string(fs, Vector2(x, r.position.y + 126.0 * u), wl, HORIZONTAL_ALIGNMENT_CENTER, w, int(13.0 * u), Style.role("w"))
	draw_line(Vector2(x + 30.0 * u, r.position.y + 142.0 * u), Vector2(r.end.x - 30.0 * u, r.position.y + 142.0 * u), Color(1, 1, 1, 0.12), 1.0 * u)
	draw_string(fs, Vector2(x, r.position.y + 166.0 * u), String(result.get("next", "")), HORIZONTAL_ALIGNMENT_CENTER, w, int(12.0 * u), Kit.UI_INK_SOFT)
	draw_string(fs, Vector2(x, r.position.y + 184.0 * u), "ENTER  NEXT    ·    BACKSPACE  AGAIN    ·    1-6  CHOOSE", HORIZONTAL_ALIGNMENT_CENTER, w, int(10.0 * u), Kit.UI_GREY)
