extends Control

## M: the map (PLAN.md step 57), black glass, flat panels side by side and never overlapping (the Dead
## Space remake and Control's overlapping floors: RESEARCH.md section 6).
##
## CUT ALONG WHATEVER YOUR VIEW HIDES. Each panel is one flat maze like the one you are looking at:
## with the slice level, one panel per W layer; turned into W, one panel per row or column instead. And
## each is turned so your forward is up the panel (Levine 1982: a map aligned with the world is read
## without turning it in your head). The panel you are in is outlined; you are the arrow.
##
## On it: the walls of the flat maze; the cells you have visited (the trail, newest brightest); dead ends
## you have finished, grey; the exit, green; the start ring, yellow; and the doors along the hidden axis
## as small arrows at the panel's sides, matching in the next panel, the way a building map marks stairs.
## A hint's route (T, third step) lights on it too.
##
## NO class_name (engine_gotchas.md).

const Kit := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")
const Lattice := preload("res://ramon/PhaseMazeRemake/maze/maze_lattice.gd")

const UNIT := [Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]
const NAMES := ["X", "Z", "W"]

var view: Node
var body: Node4D
var lattice: RefCounted
## {cell: age 0..1, 1 newest} from the game.
var trail: Dictionary = {}
var done: Dictionary = {}
## Cells a hint lit (T): {cell: true}.
var lit: Dictionary = {}

var _axes: Array = [0, 1, 2]
var _signs: Array = [1, -1, 1]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


## The view's right, forward and hidden axes, rounded to the nearest world axes (mid-turn too).
func _frame_axes() -> void:
	var rig: Node4D = view.get("rig")
	var b: Projection = rig.basis
	var dirs: Array = [b.x, -b.z, b.w]
	var used: Dictionary = {}
	var axes: Array = []
	var signs: Array = []
	for d in dirs:
		var v: Vector4 = d
		var best: int = -1
		var best_abs: float = -1.0
		for a in 3:
			if used.has(a):
				continue
			var k: float = absf(v.dot(UNIT[a]))
			if k > best_abs:
				best_abs = k
				best = a
		used[best] = true
		axes.append(best)
		signs.append(1 if v.dot(UNIT[best]) >= 0.0 else -1)
	_axes = axes
	_signs = signs


func _draw() -> void:
	if lattice == null or view == null or body == null:
		return
	_frame_axes()
	var vs: Vector2 = get_viewport_rect().size
	var u: float = vs.y / 720.0
	var dims: Array = [lattice.nx, lattice.nz, lattice.nw]
	var ra: int = _axes[0]
	var fa: int = _axes[1]
	var ha: int = _axes[2]
	var nr: int = int(dims[ra])
	var nf: int = int(dims[fa])
	var nh: int = int(dims[ha])
	var cell_px: float = minf(46.0 * u, minf((vs.x * 0.8) / float(nh * nr + nh), (vs.y * 0.5) / float(nf)))
	var pad: float = cell_px * 0.9
	var pw: float = cell_px * float(nr)
	var ph: float = cell_px * float(nf)
	var total := Vector2(float(nh) * pw + float(nh - 1) * pad + 48.0 * u, ph + 96.0 * u)
	var r := Rect2((vs - total) * 0.5 + Vector2(0, -40.0 * u), total)
	draw_style_box(Kit.glass_box(12.0 * u, 1.0, 0.92), r)
	var fs: Font = LabPrint.font("bold")
	var fb: Font = LabPrint.font("black")
	draw_string(fb, r.position + Vector2(24.0 * u, 30.0 * u), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, int(15.0 * u), Kit.UI_INK)
	draw_string(fs, r.position + Vector2(72.0 * u, 30.0 * u), "ONE PANEL PER STEP ALONG %s  ·  YOUR FORWARD IS UP  ·  M CLOSES" % NAMES[ha], HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * u), Kit.UI_GREY)
	var me: Vector3i = lattice.cell_at(body.global_position)
	var origin := r.position + Vector2(24.0 * u, 58.0 * u)
	var hcol: Color = Style.role(["x", "z", "w"][ha])
	for p in nh:
		# Panels left to right along the view's own W (E steps to the right).
		var hi: int = p if int(_signs[2]) > 0 else nh - 1 - p
		var pr := Rect2(origin + Vector2(float(p) * (pw + pad), 0.0), Vector2(pw, ph))
		draw_rect(pr, Color(1, 1, 1, 0.04), true)
		draw_string(fs, Vector2(pr.position.x, pr.end.y + 18.0 * u), "%s %d" % [NAMES[ha], hi + 1], HORIZONTAL_ALIGNMENT_CENTER, pw, int(11.0 * u), hcol)
		for a in nr:
			for b in nf:
				var cell: Vector3i = _cell(ra, fa, ha, a, b, hi, dims)
				var cr := Rect2(pr.position + Vector2(_col(a, nr) * cell_px, _row(b, nf) * cell_px), Vector2(cell_px, cell_px))
				_cell_fill(cell, cr, u)
				# Walls: each cell draws its closed sides along the two panel axes.
				var wall_col := Color(0.85, 0.87, 0.90, 0.9)
				for axis_side in [[ra, 1], [ra, -1], [fa, 1], [fa, -1]]:
					var ax: int = axis_side[0]
					var sd: int = axis_side[1]
					if lattice.passable(cell, ax, sd):
						continue
					var screen_sd: int = sd * (int(_signs[0]) if ax == ra else int(_signs[1]))
					var x0: float = cr.position.x
					var x1: float = cr.end.x
					var y0: float = cr.position.y
					var y1: float = cr.end.y
					if ax == ra:
						var xx: float = x1 if screen_sd > 0 else x0
						draw_line(Vector2(xx, y0), Vector2(xx, y1), wall_col, 2.0 * u, true)
					else:
						var yy: float = y0 if screen_sd > 0 else y1
						draw_line(Vector2(x0, yy), Vector2(x1, yy), wall_col, 2.0 * u, true)
				# Doors along the hidden axis: arrows toward the panel they lead to.
				for sd2 in [1, -1]:
					if lattice.passable(cell, ha, sd2):
						var to_right: bool = (sd2 * int(_signs[2])) > 0
						var c0: Vector2 = cr.get_center() + Vector2((0.3 if to_right else -0.3) * cell_px, 0.0)
						var dx: float = (1.0 if to_right else -1.0) * cell_px * 0.12
						draw_colored_polygon(PackedVector2Array([c0 + Vector2(dx, 0), c0 + Vector2(-dx, -cell_px * 0.12), c0 + Vector2(-dx, cell_px * 0.12)]), hcol)
				if cell == me:
					_me(cr, u)
		if me[ha] == hi:
			draw_rect(pr.grow(3.0 * u), hcol, false, 2.0 * u)


func _cell(ra: int, fa: int, ha: int, a: int, b: int, h: int, _dims: Array) -> Vector3i:
	var idx := [0, 0, 0]
	idx[ra] = a
	idx[fa] = b
	idx[ha] = h
	return Vector3i(idx[0], idx[1], idx[2])


## Screen column of index `a` along the view's right axis, and row of index `b` along its forward (up).
func _col(a: int, n: int) -> float:
	return float(a) if int(_signs[0]) > 0 else float(n - 1 - a)


func _row(b: int, n: int) -> float:
	return float(n - 1 - b) if int(_signs[1]) > 0 else float(b)


func _cell_fill(cell: Vector3i, cr: Rect2, u: float) -> void:
	var inner: Rect2 = cr.grow(-2.0 * u)
	if lit.has(cell):
		draw_rect(inner, Color(Style.role("w"), 0.45), true)
	elif done.has(cell):
		draw_rect(inner, Color(Style.role("done"), 0.35), true)
	elif trail.has(cell):
		draw_rect(inner, Color(Style.role("trail"), 0.15 + 0.45 * float(trail[cell])), true)
	if cell == lattice.exit:
		draw_rect(inner.grow(-cr.size.x * 0.18), Style.role("exit"), true)
	if cell == lattice.start:
		draw_arc(cr.get_center(), cr.size.x * 0.28, 0.0, TAU, 24, Style.role("start"), 2.0 * u, true)


func _me(cr: Rect2, u: float) -> void:
	var c: Vector2 = cr.get_center()
	var s: float = cr.size.x * 0.26
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.75, s * 0.8), c + Vector2(0, s * 0.4), c + Vector2(-s * 0.75, s * 0.8)]), Color.WHITE)
	draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.75, s * 0.8), c + Vector2(0, s * 0.4), c + Vector2(-s * 0.75, s * 0.8), c + Vector2(0, -s)]), Color(0, 0, 0, 0.6), 1.0 * u, true)
