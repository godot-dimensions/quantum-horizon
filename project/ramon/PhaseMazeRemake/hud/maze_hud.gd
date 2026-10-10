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
## The console's prompt (round 3): {"number", "name", "next", "click", "flash"}, or {} for none.
var menu: Dictionary = {}
## The camera, for labels on things in the world (the beacon's).
var camera: Camera4D
## The top of the exit's beacon (the builder's "beacon_top"), or Vector4.INF for none.
var beacon_top: Vector4 = Vector4.INF
## Standing on a blue plate (a door through W): {"up": bool, "down": bool}, or {} for none.
var plate: Dictionary = {}
## Q or E held: -1 kata, 1 ana, 0 neither (the ruler's caps light while held).
var stepping: int = 0
## When you last changed W layer, and which: the ruler's segment and a line flash for it.
var _layer_flash: float = -10.0
var _last_layer: int = -1
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
		_beacon_label(u, vs)
		_badge(u, vs)
	_mood_chip(u, vs)
	if not title.is_empty():
		_title(u, vs)
	_keys(u, vs, state)
	_messages(u, vs)
	if not result.is_empty():
		_results(u, vs)
	elif not menu.is_empty():
		_menu_prompt(u, vs)
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
	var r := Rect2(Vector2(18.0 * u, vs.y - 330.0 * u), Vector2(214, 256) * u)
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
	_ruler(Rect2(r.position + Vector2(10.0, 190.0) * u, Vector2(r.size.x - 20.0 * u, 58.0 * u)), u, hidden, hid)


## THE RULER (round 3, adapted from Crosswise's W ruler; the gizmo survey in PLAN.md round 3: "the old
## maze's aids reacted continuously while you held Q or E ... the remake's ruler only changes when you
## cross into the next 6 m cell"). Along the axis your view hides (W when level):
##   a line naming it: "W  LAYER 2 OF 4", and on the right where the exit is along it
##   a bar of its cells, each as long as the cell, in the floor's own layer colour when it is W, so the
##   bar is the legend of the ground you stand on; the exit's cell carries an orange diamond
##   your needle, placed continuously, so holding Q or E visibly moves you before the cell changes
##   Q and E at the ends: lit when the step that way is open, struck through when it is a wall, and
##   pressed while you hold them
func _ruler(r: Rect2, u: float, h: int, hid: Vector4) -> void:
	if lattice == null:
		return
	var dims: Array = [lattice.nx, lattice.nz, lattice.nw]
	var n: int = int(dims[h])
	var p: Vector4 = body.global_position
	var c: Vector3i = lattice.cell_at(p)
	var s: int = 1 if UNIT[h].dot(hid) >= 0.0 else -1
	var idx: int = [c.x, c.y, c.z][h]
	var ex: int = [lattice.exit.x, lattice.exit.y, lattice.exit.z][h]
	var col: Color = _axis_col(h)
	var fs: Font = LabPrint.font("bold")
	var fb: Font = LabPrint.font("black")
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if h == 2 and idx != _last_layer:
		if _last_layer >= 0:
			_layer_flash = now
		_last_layer = idx
	var flash: float = clampf(1.0 - (now - _layer_flash) / 1.2, 0.0, 1.0) if h == 2 else 0.0
	# The line over the bar.
	var noun: String = ["COLUMN", "ROW", "LAYER"][h]
	var here_col: Color = Style.layer_colour(idx) if h == 2 else col
	var label: String = "%s  %s %d OF %d" % [AXIS_NAMES[h], noun, clampi(idx + 1, 1, n), n]
	draw_string(fb, r.position + Vector2(0.0, 12.0 * u), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int((12.0 + 3.0 * flash) * u), here_col.lightened(0.25 + 0.5 * flash))
	var exit_text: String = "EXIT HERE" if idx == ex else "EXIT %s %d" % [noun, ex + 1]
	draw_string(fs, Vector2(r.position.x, r.position.y + 12.0 * u), exit_text, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x, int(10.0 * u), Style.role("exit"))
	# Q on the left (steps against the view's W), E on the right (along it).
	var q_open: bool = lattice.inside(c) and lattice.passable(c, h, -s)
	var e_open: bool = lattice.inside(c) and lattice.passable(c, h, s)
	var cap: float = 24.0 * u
	var bar_y: float = r.position.y + 22.0 * u
	_cap(Rect2(Vector2(r.position.x, bar_y), Vector2(cap, cap)), "Q", q_open, col, u, stepping < 0)
	_cap(Rect2(Vector2(r.end.x - cap, bar_y), Vector2(cap, cap)), "E", e_open, col, u, stepping > 0)
	var x0: float = r.position.x + cap + 8.0 * u
	var x1: float = r.end.x - cap - 8.0 * u
	var total: float = lattice.total(h)
	var starts: PackedFloat32Array = lattice.starts[h]
	var sizes: PackedFloat32Array = lattice.sizes[h]
	for i in n:
		var f0: float = float(starts[i]) / total
		var f1: float = (float(starts[i]) + float(sizes[i])) / total
		if s < 0:
			var t0: float = 1.0 - f1
			f1 = 1.0 - f0
			f0 = t0
		var seg := Rect2(Vector2(lerpf(x0, x1, f0) + 1.5 * u, bar_y), Vector2((f1 - f0) * (x1 - x0) - 3.0 * u, cap))
		var segc: Color = Style.layer_colour(i) if h == 2 else Color(0.62, 0.66, 0.74)
		var here: bool = i == idx
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(int(4.0 * u))
		box.anti_aliasing = true
		box.bg_color = Color(segc, (0.85 if here else 0.28) + 0.15 * flash * float(here))
		if here:
			box.border_color = Color(1, 1, 1, 0.9)
			box.set_border_width_all(int(maxf(1.0, 1.5 * u)))
		draw_style_box(box, seg)
		draw_string(fs, Vector2(seg.position.x, seg.position.y + 16.0 * u), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, seg.size.x, int(10.0 * u),
			Color(Kit.UI_GLASS, 1.0) if here else Color(1, 1, 1, 0.75))
		if i == ex:
			var dc := Vector2(seg.get_center().x, bar_y - 1.0 * u)
			var dd: float = 5.5 * u
			draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -dd), dc + Vector2(dd, 0), dc + Vector2(0, dd), dc + Vector2(-dd, 0)]), Style.role("exit"))
	# Your needle, continuous along the axis.
	var pa: float = [p.x - lattice.origin.x, p.z - lattice.origin.z, p.w - lattice.origin.w][h]
	var f: float = clampf(pa / total, 0.0, 1.0)
	if s < 0:
		f = 1.0 - f
	var nxp: float = lerpf(x0, x1, f)
	draw_line(Vector2(nxp, bar_y - 3.0 * u), Vector2(nxp, bar_y + cap + 3.0 * u), Color(Kit.UI_GLASS, 0.9), 5.0 * u)
	draw_line(Vector2(nxp, bar_y - 3.0 * u), Vector2(nxp, bar_y + cap + 3.0 * u), Color.WHITE, 2.5 * u)
	draw_colored_polygon(PackedVector2Array([Vector2(nxp - 5.0 * u, bar_y + cap + 9.0 * u), Vector2(nxp + 5.0 * u, bar_y + cap + 9.0 * u), Vector2(nxp, bar_y + cap + 3.0 * u)]), Color.WHITE)


## The exit's beacon, named where it stands on screen (round 3): "EXIT" in its own layer; in any other,
## "EXIT IS IN LAYER 3" and which key's way that is, so the hollow frame over you never reads as there.
func _beacon_label(u: float, vs: Vector2) -> void:
	if camera == null or lattice == null or beacon_top == Vector4.INF:
		return
	# At the beacon's middle, not its top (a toast can cover the top of the screen), and kept below the
	# messages.
	var mid: Vector4 = beacon_top - Vector4(0.0, 7.0, 0.0, 0.0)
	if camera.is_position_behind(mid):
		return
	var at: Vector2 = camera.world_to_viewport(mid)
	if at.x < 0.0 or at.y < 0.0 or at.x > vs.x or at.y > vs.y:
		return
	at.y = maxf(at.y, 150.0 * u)
	var c: Vector3i = lattice.cell_at(body.global_position)
	var here: bool = c.z == lattice.exit.z
	var text: String = "EXIT"
	if not here:
		var d: int = lattice.exit.z - c.z
		var w_axis: Vector4 = (view.get("rig") as Node4D).basis.w
		var key: String = ""
		if int(view.get("hidden_axis")) == 2:
			key = " (%s)" % ("E" if float(d) * w_axis.w > 0.0 else "Q")
		text = "EXIT: W LAYER %d  ·  %d %s %s%s" % [lattice.exit.z + 1, absi(d), "LAYER" if absi(d) == 1 else "LAYERS", "ANA" if d > 0 else "KATA", key]
	var fs: Font = LabPrint.font("bold")
	var px: int = int(11.0 * u)
	var tw: float = fs.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var r := Rect2(Vector2(at.x - tw * 0.5 - 10.0 * u, at.y - 34.0 * u), Vector2(tw + 20.0 * u, 22.0 * u))
	# Kept whole on screen when the beacon stands near an edge.
	r.position.x = clampf(r.position.x, 12.0 * u, vs.x - r.size.x - 12.0 * u)
	var box: StyleBoxFlat = Kit.glass_box(11.0 * u, 1.0, 0.8)
	box.border_color = Color(Style.role("exit"), 0.9 if here else 0.45)
	box.set_border_width_all(int(maxf(1.0, 1.5 * u)))
	draw_style_box(box, r)
	draw_string(fs, Vector2(r.position.x, r.position.y + 15.0 * u), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, Style.role("exit") if here else Kit.UI_INK_SOFT)


func _cap(r: Rect2, key: String, open_side: bool, col: Color, u: float, held: bool = false) -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(int(5.0 * u))
	box.anti_aliasing = true
	if held:
		box.border_color = Color.WHITE
		box.set_border_width_all(int(maxf(1.0, 2.0 * u)))
	if open_side:
		box.bg_color = col.lightened(0.25) if held else col
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
		rows = [["1-6", "choose a level"], ["ENTER", "play it"], ["CLICK", "a tile or START"], ["WASD", "walk"], ["B", "dark / bright"], ["TAB", "tune the light"],
			["ESC", "close a panel, or the menu"], ["H", "back to the menu"]]
	else:
		# F's row says whether a turn here opens a way (round 3: "visual feedback when rotation is
		# available or unavailable"): lit on a blue plate in the level view.
		var f_row: Array = ["F", "turn into W"]
		if not plate.is_empty() and bool(plate.get("level", false)):
			f_row = ["F", "turn: the way is HERE", true]
		elif view != null and int(view.get("hidden_axis")) == 2:
			f_row = ["F", "turn into W (no door)"]
		rows = [["WASD", "walk"], f_row, ["R", "level the slice"], ["Q E", "step through the hidden axis"],
			["RMB", "hold and drag: tilt"], ["G", "4D sight" + ("  ON" if bool(info.get("sight", false)) else "")], ["M", "map"], ["T", "hint"],
			["V", "first person" if not bool(info.get("first_person", false)) else "third person"], ["C", "camera"], ["B", "dark / bright"], ["TAB", "tune the light"], ["BACKSPACE", "again"], ["1-6", "levels"], ["ESC", "menu (asks first)"]]
	var fs: Font = LabPrint.font("bold")
	var px: int = int(11.0 * u)
	var lh: float = 18.0 * u
	var h: float = lh * float(rows.size()) + 16.0 * u
	var r := Rect2(Vector2(vs.x - 236.0 * u, vs.y - 18.0 * u - h), Vector2(218.0 * u, h))
	_glass(r, u)
	for i in rows.size():
		var y: float = r.position.y + 8.0 * u + lh * float(i) + lh * 0.72
		var key: String = String(rows[i][0])
		var lit: bool = (rows[i] as Array).size() > 2 and bool(rows[i][2])
		var kw: float = fs.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 10.0 * u
		var kr := Rect2(Vector2(r.position.x + 10.0 * u, y - lh * 0.66), Vector2(kw, lh * 0.82))
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(int(4.0 * u))
		box.bg_color = Style.role("w") if lit else Color(1, 1, 1, 0.10)
		draw_style_box(box, kr)
		draw_string(fs, Vector2(kr.position.x, y), key, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, px, Kit.UI_INK)
		draw_string(fs, Vector2(kr.end.x + 8.0 * u, y), String(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Style.role("w").lightened(0.3) if lit else Kit.UI_INK_SOFT)


# -- the console's prompt ----------------------------------------------------------------------------------

## Bottom middle while the console is up (round 3, Ramon: "provide a clear Click or Enter to Start
## prompt"): the level chosen, big, and the three ways on, as key chips. It flashes when the choice
## changes, so pressing a number visibly did something.
func _menu_prompt(u: float, vs: Vector2) -> void:
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var flash: float = clampf(1.0 - (now - float(menu.get("flash", -10.0))) / 0.7, 0.0, 1.0)
	var title: String = "%02d  %s" % [int(menu.get("number", 1)), String(menu.get("name", ""))]
	var kicker: String = "NEXT LEVEL" if bool(menu.get("next", false)) else "LEVEL CHOSEN"
	var chips: Array = [["ENTER", "PLAY"], [String(menu.get("click", "CLICK START")), ""], ["1-6", "ANOTHER LEVEL"]]
	var px_chip: int = int(12.0 * u)
	var chips_w: float = 0.0
	for c in chips:
		chips_w += fs.get_string_size(String(c[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px_chip).x + 16.0 * u
		if String(c[1]) != "":
			chips_w += fs.get_string_size(String(c[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px_chip).x + 8.0 * u
		chips_w += 22.0 * u
	var tw: float = fb.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24.0 * u)).x
	var w: float = maxf(tw, chips_w) + 48.0 * u
	var r := Rect2(Vector2((vs.x - w) * 0.5, vs.y - 128.0 * u), Vector2(w, 98.0 * u))
	var box: StyleBoxFlat = Kit.glass_box(14.0 * u, 1.0, Kit.UI_GLASS_ALPHA)
	box.border_color = Color(Kit.UI_ACCENT, 0.35 + 0.65 * flash)
	box.set_border_width_all(int(maxf(1.0, (1.5 + 2.0 * flash) * u)))
	draw_style_box(box, r)
	draw_string(fs, Vector2(r.position.x, r.position.y + 22.0 * u), kicker, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(11.0 * u), Kit.UI_GREY)
	draw_string(fb, Vector2(r.position.x, r.position.y + 52.0 * u), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(24.0 * u), Kit.UI_INK.lerp(Kit.UI_ACCENT, flash))
	var x: float = r.position.x + (r.size.x - chips_w) * 0.5
	var y: float = r.position.y + 80.0 * u
	for c in chips:
		var key: String = String(c[0])
		var kw: float = fs.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, px_chip).x + 16.0 * u
		var kr := Rect2(Vector2(x, y - 15.0 * u), Vector2(kw, 21.0 * u))
		var kb := StyleBoxFlat.new()
		kb.set_corner_radius_all(int(5.0 * u))
		kb.bg_color = Color(Kit.UI_ACCENT, 0.9) if key == "ENTER" else Color(1, 1, 1, 0.14)
		draw_style_box(kb, kr)
		draw_string(fs, Vector2(kr.position.x, y), key, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, px_chip, Color(Kit.UI_GLASS, 1.0) if key == "ENTER" else Kit.UI_INK)
		x += kw + 8.0 * u
		if String(c[1]) != "":
			draw_string(fs, Vector2(x, y), String(c[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px_chip, Kit.UI_INK_SOFT)
			x += fs.get_string_size(String(c[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px_chip).x
		x += 22.0 * u


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
