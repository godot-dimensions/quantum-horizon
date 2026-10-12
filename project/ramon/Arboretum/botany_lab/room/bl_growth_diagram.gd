@tool
extends "res://ramon/Arboretum/botany_lab/carried/kit/panels/kit_panel_elements.gd".El

## BOTANY LAB, round 2 (section 8, steps 27-31; Ramon: "a simple diagram illustrating how the shrubbery or
## branching system works ... based on the real algorithm rather than a generic procedural-tree
## illustration"): the research wall's moving diagram of how pedestals 01 to 03 grow their tree.
##
## IT IS THE REAL ALGORITHM, RUN IN 2D. The rules are shrub_generator.gd's (carried/shrubbery/, TanTanDev's
## shrubbery ported to 4D by Trym), with the specimen's own settings (botany/tree_species.gd "specimen"):
##   POINTS   attraction points scattered through the crown's shape
##   TRUNK    a straight trunk first (1.2 m)
##   GROW     every tip looks at every point within reach (1.25 m), turns toward their average (plus a
##            little gravity) and grows one segment (0.34 m); when its points split into two groups
##            more than 45 degrees apart (3 points or more, 2 times in 5) it forks; a point a new
##            segment comes within 0.34 m of is used up
##   THICKEN  each branch as thick as the twigs it carries (the pipe model, exponent 2.5)
##   SURFACE  what each pedestal makes of it: cells (01), one smooth surface (02), a loft (03); then
##            the leaves
## Only the dimension differs: here x and y, in the room x, y, z and W. Grown once (the seed is fixed) and
## played back step by step, round and round; the wall redraws while it is shown.
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/Arboretum/botany_lab/carried/kit/panels/kit_panel_spec.gd")
const GOLD := Color(1.0, 0.80, 0.35)
const LEAF := Color(0.55, 0.85, 0.45)

## The specimen's settings (tree_species.gd PRESETS "specimen" gen), metres.
const SEG := 0.34
const REACH := 1.25
const KILL := 0.34
const FORK_MIN := 3
const FORK_DEG := 45.0
const FORK_P := 0.4
const GRAVITY := 0.02
const TRUNK := 1.2
const MAX_BRANCHES := 420
const ITERATIONS := 60
## The crown, as the specimen's: its middle and half extents (x, y).
const CROWN_C := Vector2(0.0, 3.2)
const CROWN_R := Vector2(1.9, 1.55)
const POINTS := 300
const PIPE_N := 2.5
## Up, in the tree's own metres (y up). NOT Vector2.UP, which is (0, -1), screen up: with it the straight
## trunk grew downward and its loop never reached the trunk's height, eating memory until Windows
## itself died (two PC crashes on 9 Oct, bugcheck 0xEF). Every loop here is bounded now as well.
const UP_M := Vector2(0.0, 1.0)

## The parts and how long each plays (seconds).
const PARTS := [["POINTS", 2.2], ["TRUNK", 1.4], ["GROW", 8.0], ["THICKEN", 2.4], ["CELLS", 2.0], ["SMOOTH", 2.0], ["LOFT", 2.0], ["LEAVES", 2.6]]

var animated: bool = true
## branches: [{p: Vector2, parent: int, step: int, gen: int}], points: [{p: Vector2, used: int (step, -1 never)}].
var _br: Array = []
var _pts: Array = []
var _steps: int = 0
var _width: PackedFloat32Array = PackedFloat32Array()
var _tips: Array = []
var _cells: Array = []
## The grown tree's extent (metres): the drawing is fitted to it, not to the crown's nominal size (the
## first frames spilled the cells over the wall's other columns).
var _lo := Vector2.ZERO
var _hi := Vector2.ONE


func _init(nm: String = "", px_per_unit: float = Spec.PPU) -> void:
	super(nm, px_per_unit)
	clip_contents = true
	_grow()


## The part playing now and how far into it (0-1), from the clock.
func now() -> Array:
	var total: float = 0.0
	for p in PARTS:
		total += float(p[1])
	var t: float = fmod(float(Time.get_ticks_msec()) / 1000.0, total)
	for i in PARTS.size():
		var dur: float = PARTS[i][1]
		if t < dur:
			return [i, t / dur]
		t -= dur
	return [PARTS.size() - 1, 1.0]


# -- the growth (shrub_generator.gd's rules, in 2D) ----------------------------------------------------------

func _grow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	_pts = []
	for attempt in POINTS * 4:
		if _pts.size() >= POINTS:
			break
		var q := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if q.length_squared() <= 1.0:
			_pts.append({"p": CROWN_C + q * CROWN_R, "used": -1})
	_br = [{"p": Vector2.ZERO, "dir": UP_M, "parent": -1, "step": 0, "gen": 0}]
	# The straight trunk, one segment a step.
	var step: int = 0
	for seg_i in int(ceil(TRUNK / SEG)):
		step += 1
		var last: Dictionary = _br[_br.size() - 1]
		_br.append({"p": (last["p"] as Vector2) + UP_M * SEG, "dir": UP_M, "parent": _br.size() - 1, "step": step, "gen": 0})
	for it in ITERATIONS:
		step += 1
		if _br.size() >= MAX_BRANCHES:
			break
		var has_child: Dictionary = {}
		for b in _br:
			if int(b["parent"]) >= 0:
				has_child[int(b["parent"])] = true
		var fresh: Array = []
		for ti in _br.size():
			if has_child.has(ti) or _br.size() + fresh.size() >= MAX_BRANCHES:
				continue
			var tip: Dictionary = _br[ti]
			for d in _directions(tip, rng, _br.size() + fresh.size() + 1 < MAX_BRANCHES):
				fresh.append({"p": (tip["p"] as Vector2) + (d as Vector2) * SEG, "dir": d, "parent": ti, "step": step, "gen": int(tip["gen"]) + 1})
		if fresh.is_empty():
			break
		for b in fresh:
			_br.append(b)
			for pt in _pts:
				if int(pt["used"]) < 0 and (pt["p"] as Vector2).distance_to(b["p"]) <= KILL:
					pt["used"] = step
	_steps = step
	_thicken()
	_lo = Vector2(INF, 0.0)
	_hi = Vector2(-INF, -INF)
	for b in _br:
		var q: Vector2 = b["p"]
		_lo = Vector2(minf(_lo.x, q.x - 0.25), 0.0)
		_hi = Vector2(maxf(_hi.x, q.x + 0.25), maxf(_hi.y, q.y + 0.25))
	for pt in _pts:
		var q2: Vector2 = pt["p"]
		_lo.x = minf(_lo.x, q2.x)
		_hi = Vector2(maxf(_hi.x, q2.x), maxf(_hi.y, q2.y))


## One or two directions for a tip: toward the average of its points in reach, or a fork when they split.
func _directions(tip: Dictionary, rng: RandomNumberGenerator, allow_fork: bool) -> Array:
	var dirs: Array = []
	for pt in _pts:
		if int(pt["used"]) >= 0:
			continue
		var to: Vector2 = (pt["p"] as Vector2) - (tip["p"] as Vector2)
		var dl: float = to.length()
		if dl <= REACH and dl > 0.0001:
			dirs.append(to / dl)
	var own: Vector2 = tip["dir"]
	if allow_fork and dirs.size() >= FORK_MIN and rng.randf() < FORK_P:
		var best: float = 2.0
		var a: int = 0
		var b: int = 0
		for i in dirs.size():
			for j in range(i + 1, dirs.size()):
				var dd: float = (dirs[i] as Vector2).dot(dirs[j])
				if dd < best:
					best = dd
					a = i
					b = j
		if best <= cos(deg_to_rad(FORK_DEG)):
			var sa := Vector2.ZERO
			var sb := Vector2.ZERO
			for d in dirs:
				if (d as Vector2).dot(dirs[a]) >= (d as Vector2).dot(dirs[b]):
					sa += d
				else:
					sb += d
			if sa.length() > 0.0 and sb.length() > 0.0:
				return [_bias(own + sa.normalized()), _bias(own + sb.normalized())]
	var pull := Vector2.ZERO
	for d in dirs:
		pull += d
	if pull.length() > 0.0001:
		pull = pull.normalized()
	return [_bias(own + pull)]


static func _bias(d: Vector2) -> Vector2:
	return (d.normalized() - UP_M * GRAVITY).normalized()


## The pipe model: a tip is a twig; a branch's thickness to the 2.5 is the sum of its children's. And
## the cells (01's): every 0.25 m cell a branch passes through.
func _thicken() -> void:
	_width.resize(_br.size())
	var kids: Dictionary = {}
	for i in _br.size():
		_width[i] = 0.0
		var pa: int = int(_br[i]["parent"])
		if pa >= 0:
			kids[pa] = true
	_tips = []
	for i in _br.size():
		if not kids.has(i):
			_tips.append(i)
	var acc := PackedFloat32Array()
	acc.resize(_br.size())
	for i in range(_br.size() - 1, -1, -1):
		if not kids.has(i):
			acc[i] += 1.0
		var pa: int = int(_br[i]["parent"])
		if pa >= 0:
			acc[pa] += acc[i]
	for i in _br.size():
		_width[i] = pow(acc[i], 1.0 / PIPE_N)
	var seen: Dictionary = {}
	_cells = []
	for i in range(1, _br.size()):
		var a: Vector2 = _br[int(_br[i]["parent"])]["p"]
		var b: Vector2 = _br[i]["p"]
		for s in 4:
			var q: Vector2 = a.lerp(b, float(s) / 3.0)
			var key := Vector2i(int(floor(q.x / 0.25)), int(floor(q.y / 0.25)))
			if not seen.has(key):
				seen[key] = true
				_cells.append(key)


# -- the drawing ----------------------------------------------------------------------------------------------

func _draw() -> void:
	var nw: Array = now()
	var part: int = nw[0]
	var f: float = nw[1]
	var box := Rect2(Vector2(12, 12) * k, size - Vector2(24, 20) * k)
	# The tree's metres into the box: 4.8 m tall, centred.
	var ext: Vector2 = _hi - _lo
	var sc: float = minf((box.size.y - 34.0 * k) / maxf(ext.y, 0.5), box.size.x * 0.96 / maxf(ext.x, 0.5))
	var base := Vector2(box.position.x + box.size.x * 0.5 - (_lo.x + ext.x * 0.5) * sc, box.end.y - 4.0 * k)
	var to_px := func(q: Vector2) -> Vector2: return base + Vector2(q.x, -q.y) * sc
	var white := Spec.ink("white")
	var faint := Spec.ink("white", 0.35)
	_label(Vector2(box.position.x, box.position.y + 2.0 * k), "%d  %s" % [part + 1, String(PARTS[part][0])], GOLD, "label")
	# How far the growth is (in its own steps) at this moment.
	var trunk_steps: int = 0
	for b in _br:
		if int(b["gen"]) == 0:
			trunk_steps = maxi(trunk_steps, int(b["step"]))
	var shown: float = 0.0
	match part:
		0:
			shown = 0.0
		1:
			shown = f * float(trunk_steps)
		2:
			shown = float(trunk_steps) + f * float(_steps - trunk_steps)
		_:
			shown = float(_steps)
	# The points: appearing, then used up as the branches reach them.
	if part <= 2:
		var appear: float = clampf(f * 1.4, 0.0, 1.0) if part == 0 else 1.0
		var n_show: int = int(float(_pts.size()) * appear)
		for i in n_show:
			var pt: Dictionary = _pts[i]
			if int(pt["used"]) >= 0 and float(pt["used"]) <= shown:
				continue
			draw_circle(to_px.call(pt["p"]), 1.3 * k, faint)
	# The pulls of this step: the newest tips toward the points in their reach.
	if part == 2:
		var cur: int = int(floor(shown))
		var drawn_tips: int = 0
		for i in _br.size():
			if int(_br[i]["step"]) != cur or drawn_tips >= 6:
				continue
			drawn_tips += 1
			var tp: Vector2 = _br[i]["p"]
			for pt in _pts:
				if (int(pt["used"]) >= 0 and float(pt["used"]) <= shown) or (pt["p"] as Vector2).distance_to(tp) > REACH:
					continue
				draw_line(to_px.call(tp), to_px.call(pt["p"]), Color(GOLD, 0.35), maxf(1.0, 0.5 * k))
			draw_arc(to_px.call(tp), REACH * sc, 0.0, TAU, 40, Color(GOLD, 0.25), maxf(1.0, 0.6 * k))
	# The branches so far.
	var thick: float = 0.0
	if part == 3:
		thick = f
	elif part > 3:
		thick = 1.0
	var surface: String = ""
	if part >= 4 and part <= 6:
		surface = ["cells", "smooth", "loft"][part - 4]
	elif part == 7:
		surface = "loft"
	if surface == "cells":
		var cs: float = 0.25 * sc
		for c in _cells:
			var p0: Vector2 = to_px.call(Vector2(float(c.x) * 0.25, float(c.y + 1) * 0.25))
			draw_rect(Rect2(p0, Vector2(cs, cs)).grow(-0.4 * k), Spec.ink("white", 0.85))
	else:
		for i in range(1, _br.size()):
			if float(_br[i]["step"]) > shown:
				continue
			var a: Vector2 = to_px.call(_br[int(_br[i]["parent"])]["p"])
			var b: Vector2 = to_px.call(_br[i]["p"])
			var w: float = lerpf(1.1 * k, maxf(1.1 * k, _width[i] * 0.022 * sc), thick)
			if surface == "smooth":
				draw_line(a, b, white, w * 1.6)
				draw_circle(b, w * 0.8, white)
			elif surface == "loft":
				var side: Vector2 = (b - a).orthogonal().normalized() * w * 0.5
				draw_line(a + side, b + side, white, maxf(1.0, 0.5 * k))
				draw_line(a - side, b - side, white, maxf(1.0, 0.5 * k))
				if i % 2 == 0:
					draw_line(b + side, b - side, Color(GOLD, 0.8), maxf(1.0, 0.5 * k))
			else:
				var lit: bool = part == 2 and int(_br[i]["step"]) == int(floor(shown))
				draw_line(a, b, GOLD if lit else white, w)
	# The leaves: round each twig end.
	if part == 7:
		var grow: float = clampf(f * 1.6, 0.0, 1.0)
		for ti in _tips:
			draw_circle(to_px.call(_br[ti]["p"]), 3.2 * k * grow, Color(LEAF, 0.85))
	# What it shows, under the label.
	var line: String = ["Attraction points fill the crown's shape.", "The trunk grows straight first.",
		"Each tip turns toward the points in its reach; split points make a fork; reached points are used up.",
		"Every branch as thick as the twigs it carries (the pipe model).", "01  cells: every cell a branch passes through is filled.",
		"02  one smooth surface run through them (dual contouring).", "03  a loft: a cross-section at every point, a skin between.",
		"Leaves at the twig ends."][part]
	_label(Vector2(box.position.x, box.position.y + 14.0 * k), line, Spec.ink("muted"), "small")


func _label(p: Vector2, s: String, col: Color, role: String = "micro") -> void:
	draw_string(Spec.font(role), p, s, HORIZONTAL_ALIGNMENT_LEFT, size.x - p.x, int(round(Spec.size_of(role) * k)), col)
