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
## The stage-complete title: {"kicker", "text", "sub", "left": seconds}, or {} for none.
var title: Dictionary = {}
## The light's mood, for the chip (B).
var mood: String = "bright"
## How opaque the results card's glass is: see-through while the camera circles after a stage.
var result_glass: float = 0.86
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


func clear_messages() -> void:
	_toast_left = 0.0
	_hint_left = 0.0


func show_hint(text: String, seconds: float = 7.0) -> void:
	_hint = text
	_hint_left = seconds


func _process(delta: float) -> void:
	_toast_left = maxf(0.0, _toast_left - delta)
	if not title.is_empty():
		title["left"] = float(title["left"]) - delta
		if float(title["left"]) <= 0.0:
			title = {}
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
	if view != null and body != null and state == "playing":
		_badge(u, vs)
	_mood_chip(u, vs)
	if not title.is_empty():
		_title(u, vs)
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
		draw_string(fs, Vector2(r.end.x - 14.0 * u - 90.0 * u, r.position.y + 78.0 * u), "BEST " + clock(best), HORIZONTAL_ALIGNMENT_RIGHT, 90.0 * u, int(11.0 * u), Style.role("exit"))


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
	var centre: Vector2 = r.position + Vector2(r.size.x * 0.5, 100.0 * u)
	var rad: float = 50.0 * u
	# THE SLICE AS A PLANE IN A CUBE (round 2; Ramon: "is there nothing we can do to make the whole thing
	# look and feel a little less tick tack toe?"): x, z and w drawn as an isometric cube, w up, and the
	# slice you see as a plane through its middle, spanned by your right and your forward. It tilts with
	# any drag, not only by quarters; the hidden direction is the arrow out of it.
	var iso: Array = [Vector2(0.866, 0.5), Vector2(-0.866, 0.5), Vector2(0.0, -1.0)]
	var proj := func(v: Vector4) -> Vector2:
		return (iso[0] * v.x + iso[1] * v.z + iso[2] * v.w) * rad
	# The cube's edges, faint.
	var corners: Array = []
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			for cw in [-1.0, 1.0]:
				corners.append(Vector4(cx, 0.0, cz, cw) * 0.62)
	for i in 8:
		for j in range(i + 1, 8):
			var d: Vector4 = (corners[i] as Vector4) - (corners[j] as Vector4)
			if absf(absf(d.x) + absf(d.z) + absf(d.w) - 1.24) < 0.01:
				draw_line(centre + proj.call(corners[i]), centre + proj.call(corners[j]), Color(1, 1, 1, 0.13), 1.0 * u, true)
	# The three axes with their letters.
	for a in 3:
		var e: Vector4 = UNIT[a]
		var col: Color = _axis_col(a)
		var tip: Vector2 = centre + proj.call(e * 0.9)
		draw_line(centre, tip, Color(col, 0.5), 1.5 * u, true)
		draw_string(fb, tip + (tip - centre).normalized() * 9.0 * u + Vector2(-5.0, 5.0) * u, AXIS_NAMES[a], HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * u), col)
	# Your slice: the square spanned by right and forward, a plane in the cube.
	var plane := PackedVector2Array()
	for q in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		plane.append(centre + proj.call(right * q.x * 0.72 + fwd * q.y * 0.72))
	draw_colored_polygon(plane, Color(Style.role("start"), 0.22))
	plane.append(plane[0])
	draw_polyline(plane, Color(Style.role("start"), 0.85), 1.5 * u, true)
	# Forward on it, and the hidden direction out of it.
	var f_tip: Vector2 = centre + proj.call(fwd * 0.72)
	draw_line(centre, f_tip, Color.WHITE, 2.5 * u, true)
	draw_circle(f_tip, 3.0 * u, Color.WHITE)
	var hidden: int = int(view.get("hidden_axis"))
	var h_tip: Vector2 = centre + proj.call(hid * 0.95)
	draw_line(centre, h_tip, Style.role("w"), 3.0 * u, true)
	var hd: Vector2 = (h_tip - centre).normalized()
	draw_colored_polygon(PackedVector2Array([h_tip + hd * 7.0 * u, h_tip + Vector2(-hd.y, hd.x) * 4.0 * u, h_tip - Vector2(-hd.y, hd.x) * 4.0 * u]), Style.role("w"))
	# How far off a square view: the angle between the hidden direction and the axis nearest it.
	var tilt: float = rad_to_deg(acos(clampf(absf(hid.dot(UNIT[hidden])), 0.0, 1.0)))
	var seen: PackedStringArray = []
	for a in 3:
		if a != hidden:
			seen.append(AXIS_NAMES[a])
	var line: String = ("YOU SEE %s  ·  HIDDEN " % " ".join(seen)) if tilt < 3.0 else ("TILTED %d°  ·  MOSTLY HIDDEN " % int(round(tilt)))
	draw_string(fs, r.position + Vector2(14.0 * u, 180.0 * u), line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * u), Kit.UI_INK_SOFT)
	var hw: float = fs.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * u)).x
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
	var q_open: bool = lattice.inside(c) and lattice.passable(c, h, -s)
	var e_open: bool = lattice.inside(c) and lattice.passable(c, h, s)
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


# -- the title and the mood chip ---------------------------------------------------------------------------

func _title(u: float, vs: Vector2) -> void:
	var a: float = clampf(float(title["left"]) / 0.6, 0.0, 1.0) * clampf((4.5 - float(title["left"])) / 0.5, 0.0, 1.0)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var y: float = vs.y * 0.3
	draw_string(fs, Vector2(0, y - 46.0 * u), String(title.get("kicker", "")), HORIZONTAL_ALIGNMENT_CENTER, vs.x, int(14.0 * u), Color(1, 1, 1, 0.8 * a))
	draw_string(fb, Vector2(0, y + 8.0 * u), String(title.get("text", "")), HORIZONTAL_ALIGNMENT_CENTER, vs.x, int(52.0 * u), Color(1, 1, 1, a))
	draw_string(fs, Vector2(0, y + 44.0 * u), String(title.get("sub", "")), HORIZONTAL_ALIGNMENT_CENTER, vs.x, int(16.0 * u), Color(Style.role("w"), a))


## Top right, as in the Creation Lab: which mood, and that B switches it.
func _mood_chip(u: float, vs: Vector2) -> void:
	var fs: Font = LabPrint.font("bold")
	var text: String = "%s  ·  B" % mood.to_upper()
	var px: int = int(10.0 * u)
	var tw: float = fs.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var r := Rect2(Vector2(vs.x - tw - 40.0 * u, 16.0 * u), Vector2(tw + 22.0 * u, 22.0 * u))
	draw_style_box(Kit.glass_box(11.0 * u, 1.0, Kit.UI_GLASS_ALPHA), r)
	draw_string(fs, Vector2(r.position.x, r.position.y + 15.0 * u), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, Kit.UI_INK)


# -- the keys ------------------------------------------------------------------------------------------

func _keys(u: float, vs: Vector2, state: String) -> void:
	var rows: Array
	if state == "lobby":
		rows = [["1-6", "choose a level"], ["ENTER", "start"], ["WASD", "walk"], ["B", "dark / bright"], ["TAB", "tune the light"], ["H", "back to the menu"]]
	else:
		rows = [["WASD", "walk"], ["F", "turn into W"], ["R", "level the slice"], ["Q E", "step through the hidden axis"],
			["RMB", "hold and drag: tilt"], ["G", "4D sight" + ("  ON" if bool(info.get("sight", false)) else "")], ["M", "map"], ["T", "hint"],
			["V", "first person" if not bool(info.get("first_person", false)) else "third person"], ["C", "camera"], ["B", "dark / bright"], ["TAB", "tune the light"], ["BACKSPACE", "again"], ["1-6", "levels"]]
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
	var r := Rect2(Vector2(vs.x * 0.5 - 190.0 * u, vs.y * 0.62 - 98.0 * u), Vector2(380, 196) * u)
	draw_style_box(Kit.glass_box(10.0 * u, 1.0, result_glass), r)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var x: float = r.position.x
	var w: float = r.size.x
	draw_string(fs, Vector2(x, r.position.y + 28.0 * u), String(result.get("title", "")).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w, int(12.0 * u), Kit.UI_GREY)
	draw_string(fb, Vector2(x, r.position.y + 76.0 * u), clock(float(result.get("time", 0.0))), HORIZONTAL_ALIGNMENT_CENTER, w, int(40.0 * u), Kit.UI_INK)
	var best_line: String = "NEW BEST" if bool(result.get("new_best", false)) else "BEST " + clock(float(result.get("best", 0.0)))
	draw_string(fs, Vector2(x, r.position.y + 100.0 * u), best_line, HORIZONTAL_ALIGNMENT_CENTER, w, int(12.0 * u), Style.role("exit"))
	var wl: String = "W MOVES %d  ·  PAR %d" % [int(result.get("w_moves", 0)), int(result.get("par", 0))]
	draw_string(fs, Vector2(x, r.position.y + 126.0 * u), wl, HORIZONTAL_ALIGNMENT_CENTER, w, int(13.0 * u), Style.role("w"))
	draw_line(Vector2(x + 30.0 * u, r.position.y + 142.0 * u), Vector2(r.end.x - 30.0 * u, r.position.y + 142.0 * u), Color(1, 1, 1, 0.12), 1.0 * u)
	draw_string(fs, Vector2(x, r.position.y + 166.0 * u), String(result.get("next", "")), HORIZONTAL_ALIGNMENT_CENTER, w, int(12.0 * u), Kit.UI_INK_SOFT)
	draw_string(fs, Vector2(x, r.position.y + 184.0 * u), "ENTER  NEXT    ·    BACKSPACE  AGAIN    ·    1-6  CHOOSE", HORIZONTAL_ALIGNMENT_CENTER, w, int(10.0 * u), Kit.UI_GREY)
