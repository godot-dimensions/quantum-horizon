extends "res://ramon/VoxelLab/stations/vl_exhibit_4d.gd"

## The Voxel Lab's second specimen: BUILD IT. 4D bricks put in place on a grid, then the slice turned
## (round 4, in place of the column's fall; Ramon: "make it only about [building] because we lack a
## 'build system' completely ... like putting blocks in place to build something and then rotate the
## slice").
##
## WHAT IT SHOWS. The engine's voxel edits add matter as well as take it away: a brick is a 4D box of
## a colour written into the voxels (BoxVoxelEdit4D), meshed by the engine's dual contouring in C++
## like any cut. The bricks snap to a grid in all four directions, W included: the wheel steps one W
## layer at a time (each slice stop is the middle of a layer), so what you build in one layer is gone
## from the next. Turn the slice (right drag) and what stands in one layer changes, since in W it is
## one brick thick; built "through W" (every layer at once) it holds.
##
## ROUND 5 (Ramon, 9 Oct, #39 and #41): "make the entire builder noticeably larger, including its main
## interaction area and building blocks", into the front-left corner; "remove the initial solid
## construction block ... replace it with a simple black construction grid ... visually restrained".
## So no stone plate: the bricks stand on thin lines laid on the pedestal's deck (`_grid_lines`), and they
## are 0.5 m now (0.28 m before), on a grid 3.5 m across. The deck under them black, the lines a subtle
## grey (Ramon, 9 Oct: "dont make [it] have a cyan floor. i said i wanted black with sutble grey lines"):
## `_black_deck`, a slab over the pedestal's blue deck, on the pedestal (it does not turn with the slice).
##
## THE GRID. NX x NY x NZ x NW cells of CELL voxels; the recipe's box is the grid, so the grid's floor
## sits on the deck. Every cell edge sits off the voxel grid by the recipe's jitter, so each brick
## covers exactly CELL voxel samples per axis and its faces never lie on a row of samples (they fray
## there). Our copy of what is where is `_cells` (cell -> material); aiming marches through it (and
## meets the grid's floor), not through the cut list, so a hundred bricks cost what one does. NX and NZ
## are odd so a slice turned square through W stands in the middle of a row of cells, never on a face.
##
## TWO SHADES A COLOUR, IN A CHECKER. The voxels hold matter, not objects: two bricks of one material
## side by side fuse into one surface. So each colour comes in two shades laid as a checker over the
## grid (all four directions), and every brick can be counted.
##
## The turntable is off: the grid stays square to the room and to its square pedestal.
##
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/VoxelLab/carried/LabKit/lab_materials.gd")

## Metres a voxel.
const VOXEL := 0.125
## A brick, in voxels a side (0.5 m).
const CELL := 4
const NX := 7
const NY := 5
const NZ := 7
const NW := 5
## The middle W layer, where your slice starts (NW halved).
const MID := 2
## The grid's lines on the deck: their width and colour, a subtle grey on the black deck (DECK_COLOR).
const LINE_M := 0.022
const LINE_COLOR := Color(0.2, 0.21, 0.23)
const DECK_COLOR := Color(0.03, 0.033, 0.04)

## Brick colours: material 2 + colour * 2 + shade (0 and 1 are unused: there is no plate now).
const COLOUR_NAMES := ["TERRACOTTA", "SAND", "TEAL", "AMETHYST"]
const SHADES := [
	[Color(0.76, 0.38, 0.25), Color(0.86, 0.50, 0.34)],
	[Color(0.78, 0.58, 0.30), Color(0.88, 0.70, 0.40)],
	[Color(0.12, 0.54, 0.53), Color(0.22, 0.66, 0.64)],
	[Color(0.50, 0.31, 0.82), Color(0.62, 0.43, 0.92)],
]
const TOOLS := ["brick", "through", "take"]
const TOOL_NAMES := {"brick": "BRICK", "through": "THROUGH W", "take": "TAKE AWAY"}
const LINES := {
	"brick": "A 4D brick, in the W layer you see.",
	"through": "One in every W layer: in every slice.",
	"take": "Lifts away the brick you point at.",
}
## The starter: a doorway spanning z so it faces the bench, in the middle W layer, in sand ([i, j, k] cells).
## A metre behind the middle (x 1, not 3): a slice turned through W pivots on the middle, so there it met the
## doorway wherever it turned and nothing changed (the first frames, 9 Oct); a metre off, a turn of 15
## degrees starts to lose it and 45 has it gone, while what is built through W stays.
const STARTER := [[1, 0, 1], [1, 1, 1], [1, 2, 1], [1, 0, 5], [1, 1, 5], [1, 2, 5], [1, 3, 1], [1, 3, 2], [1, 3, 3], [1, 3, 4], [1, 3, 5]]
const STARTER_COLOUR := 1

var _recipe: Dictionary = {}
## Cell (Vector4i) -> material, for the specimen in hand.
var _cells: Dictionary = {}
## What each placement changed, for undo: [{cell: material before (AIR for none)}, ...].
var _history: Array = []


func _init() -> void:
	code = "BD-02"
	title = "Build it"
	display_scale = 1.0
	turn_speed = 0.0
	spare_on = true


func _ready() -> void:
	super._ready()
	_cells = _starter_cells()
	_grid_lines()
	_black_deck.call_deferred()


## Black over the pedestal's blue deck, as wide as it, on the pedestal itself (the showcase), so it stays
## put while the slice turns; through W as deep as the deck.
func _black_deck() -> void:
	var sc: Node = get_parent().get_parent() if get_parent() != null else null
	if sc == null or sc.get("_ped") == null or (sc.get("_ped") as Dictionary).is_empty():
		return
	var half: float = float(sc.get("radius")) - 0.42
	var m := MeshInstance4D.new()
	m.name = "BlackDeck"
	m.mesh = Mats.box_mesh(Vector4(half * 2.0 + 0.004, 0.005, half * 2.0 + 0.004, 40.0))
	# Just over the deck's top (deck_h); the grid's lines stand a hair over it, the bricks over them.
	m.position = Vector4(0.0, float((sc.get("_ped") as Dictionary)["deck_h"]) + 0.0025, 0.0, 0.0)
	m.material_override = Mats.flat(DECK_COLOR)
	sc.add_child(m)


## The construction grid: a thin grey line on the black deck along every cell edge in x and z, each as deep
## through W as the grid, so every W layer stands on the same lines (and a turned slice cuts them like
## the bricks). On the stand, so it turns with the slice.
func _grid_lines() -> void:
	var g := Node4D.new()
	g.name = "Grid"
	stand.add_child(g)
	var cm: float = CELL * VOXEL * display_scale
	var sx: float = NX * cm
	var sz: float = NZ * cm
	var sw: float = NW * cm
	var mat: Material4D = Mats.flat(LINE_COLOR)
	var y: float = 0.006
	for i in NX + 1:
		var m := MeshInstance4D.new()
		m.mesh = Mats.box_mesh(Vector4(LINE_M, 0.008, sz + LINE_M, sw))
		m.position = Vector4(-sx * 0.5 + cm * float(i), y, 0.0, 0.0)
		m.material_override = mat
		g.add_child(m)
	for k in NZ + 1:
		var m := MeshInstance4D.new()
		m.mesh = Mats.box_mesh(Vector4(sx + LINE_M, 0.008, LINE_M, sw))
		m.position = Vector4(0.0, y, -sz * 0.5 + cm * float(k), 0.0)
		m.material_override = mat
		g.add_child(m)


func recipe() -> Dictionary:
	if not _recipe.is_empty():
		return _recipe
	# Nothing but bricks: the recipe's box is the grid ("empty", so the generator fills it with air).
	var half := Vector4(NX, NY, NZ, NW) * CELL * 0.5
	var r: Dictionary = {"kind": "build", "voxel": VOXEL, "center": Recipe.chunk_middle() + Recipe.JITTER, "half": half, "crust": 0.0,
		"planes": [], "vein": {}, "cavity": {}, "column": {}, "empty": true, "fill_edits": []}
	var colors: Dictionary = {}
	for c in SHADES.size():
		for s in 2:
			colors[mat_of(c, s)] = SHADES[c][s]
	r["colors"] = colors
	var o: Vector4 = _origin_of(r)
	var bricks: Array = []
	var start: Dictionary = _starter_cells()
	for key in start:
		var lo: Vector4 = o + Vector4(key) * CELL
		bricks.append([lo, lo + Vector4.ONE * CELL, int(start[key])])
	r["bricks"] = bricks
	r["voxel_count"] = Recipe.voxel_count(r)
	_recipe = r
	return r


func colour_count() -> int:
	return SHADES.size()


static func mat_of(colour: int, shade: int) -> int:
	return 2 + colour * 2 + shade


## The grid's low corner (voxels): the recipe's box is the grid.
func _origin_of(r: Dictionary) -> Vector4:
	return (r["center"] as Vector4) - (r["half"] as Vector4)


func origin() -> Vector4:
	return _origin_of(recipe())


func _starter_cells() -> Dictionary:
	var out: Dictionary = {}
	for s in STARTER:
		var key := Vector4i(s[0], s[1], s[2], MID)
		out[key] = mat_of(STARTER_COLOUR, _shade(key))
	return out


static func _shade(key: Vector4i) -> int:
	return (key.x + key.y + key.z + key.w) & 1


static func in_grid(key: Vector4i) -> bool:
	return key.x >= 0 and key.x < NX and key.y >= 0 and key.y < NY and key.z >= 0 and key.z < NZ and key.w >= 0 and key.w < NW


func cell_of(p: Vector4) -> Vector4i:
	var q: Vector4 = (p - origin()) / float(CELL)
	return Vector4i(floori(q.x), floori(q.y), floori(q.z), floori(q.w))


func cell_lo(key: Vector4i) -> Vector4:
	return origin() + Vector4(key) * CELL


func bricks() -> int:
	return _cells.size()


## Which W layer the slice stands in (0 to NW - 1), from the showcase's slice stop: each stop is the
## middle of a layer (w_extent below).
func layer() -> int:
	var sc: Node = get_parent().get_parent() if get_parent() != null else null
	if sc == null or sc.get("slice_index") == null:
		return MID
	return clampi(int(sc.get("slice_index")) - 4 + MID, 0, NW - 1)


## The showcase's W stops land a layer apart: a stop is k / 4 of 0.6 of this, so this is a layer's
## width times 4 / 0.6.
func w_extent() -> float:
	return float(CELL) * VOXEL * display_scale * 4.0 / 0.6


## The slice stops that stand in a layer (the showcase clamps its wheel to them).
func slice_range() -> Vector2i:
	return Vector2i(4 - MID, 4 + MID)


## Whole again: the grid with its doorway, the history gone.
func reset() -> void:
	super.reset()
	_cells = _starter_cells()
	_history = []


# -- aiming ---------------------------------------------------------------------------------------------

## The first thing a ray meets (voxel coordinates of the specimen): a brick, or the grid's floor (the
## plane the bricks stand on, inside the grid). The bricks are marched a quarter voxel at a time through
## the grid's box (a brick is four voxels, none is stepped over) and the face found by halving.
## {point, t, material, normal, cell, on}; on the floor, material -1 and on "grid".
func raycast(o: Vector4, d: Vector4) -> Dictionary:
	d = d.normalized()
	var best: Dictionary = {}
	var t_best: float = INF
	var o0: Vector4 = origin()
	if d.y < -1e-6:
		var tf: float = (o0.y - o.y) / d.y
		var p: Vector4 = o + d * tf
		var q: Vector4 = (p - o0) / float(CELL)
		if tf >= 0.0 and q.x >= 0.0 and q.x < NX and q.z >= 0.0 and q.z < NZ and q.w >= 0.0 and q.w < NW:
			t_best = tf
			best = {"point": p, "t": tf, "material": -1, "normal": Vector4(0, 1, 0, 0), "on": "grid"}
	var g_half := Vector4(NX, NY, NZ, NW) * CELL * 0.5
	var g_mid: Vector4 = origin() + g_half
	var g: Vector2 = Recipe._ray_box(o, d, g_mid, g_half)
	if g.x > g.y or g.y < 0.0:
		return best
	var t: float = maxf(g.x, 0.0)
	var end: float = minf(g.y, t_best)
	var prev: Vector4i = cell_of(o + d * t)
	if _cells.has(prev):
		return _hit(o, d, t, prev, Vector4.ZERO)
	while t < end:
		var t1: float = t + 0.25
		var c1: Vector4i = cell_of(o + d * t1)
		if c1 != prev and _cells.has(c1):
			var a: float = t
			var b: float = t1
			for k in 10:
				var mid: float = (a + b) * 0.5
				if cell_of(o + d * mid) == c1:
					b = mid
				else:
					a = mid
			var before: Vector4i = cell_of(o + d * a)
			var n := Vector4.ZERO
			for axis in 4:
				if before[axis] != c1[axis]:
					n[axis] = signf(float(before[axis] - c1[axis]))
					break
			return _hit(o, d, b, c1, n)
		prev = c1
		t = t1
	return best


func _hit(o: Vector4, d: Vector4, t: float, key: Vector4i, n: Vector4) -> Dictionary:
	if n == Vector4.ZERO:
		n = -d
	return {"point": o + d * t, "t": t, "material": int(_cells[key]), "normal": n, "cell": key, "on": "brick"}


## The cell a brick would go in for this hover, or (-1, -1, -1, -1) where none can: next to the brick
## you point at, across the face you point at; on the grid, the cell over it.
func target(hover: Dictionary) -> Vector4i:
	var none := Vector4i(-1, -1, -1, -1)
	if hover.is_empty():
		return none
	var key: Vector4i
	if String(hover.get("on", "")) == "brick":
		var n: Vector4 = hover["normal"]
		key = (hover["cell"] as Vector4i) + Vector4i(roundi(n.x), roundi(n.y), roundi(n.z), roundi(n.w))
	else:
		key = cell_of((hover["point"] as Vector4) + Vector4(0, 0.5, 0, 0))
		key.y = 0
	return key if in_grid(key) and not _cells.has(key) else none


# -- building -----------------------------------------------------------------------------------------------

## The edit for `tool` at the hover in colour `colour`, as a cut (vl_cut.gd's shape, with what it
## changes in "cells"), or {} where it cannot go.
func build_cut(tool: String, colour: int, hover: Dictionary) -> Dictionary:
	var change: Dictionary = {}
	match tool:
		"brick":
			var key: Vector4i = target(hover)
			if key.x < 0:
				return {}
			change[key] = mat_of(colour, _shade(key))
		"through":
			var key: Vector4i = target(hover)
			if key.x < 0 and String(hover.get("on", "")) == "brick":
				# Pointing at a brick's top with no room next to it in this layer: the column through W
				# above it still can.
				key = (hover["cell"] as Vector4i) + Vector4i(0, 1, 0, 0)
			if not (key.y >= 0 and key.y < NY and key.x >= 0 and key.x < NX and key.z >= 0 and key.z < NZ):
				return {}
			for l in NW:
				var k := Vector4i(key.x, key.y, key.z, l)
				if not _cells.has(k):
					change[k] = mat_of(colour, _shade(k))
			if change.is_empty():
				return {}
		"take":
			if String(hover.get("on", "")) != "brick":
				return {}
			change[hover["cell"]] = Recipe.AIR
	var label: String = "Take away"
	if tool != "take":
		label = ("Brick" if tool == "brick" else "Through W x%d" % change.size()) + ", " + String(COLOUR_NAMES[colour]).to_lower()
	return change_cut(change, label)


## Takes the last placement back, as a cut, or {} with nothing to undo.
func undo_cut() -> Dictionary:
	if _history.is_empty():
		return {}
	var cut: Dictionary = change_cut(_history[-1], "Undo")
	cut["undo"] = true
	return cut


## A cut writing `change` (cell -> material, AIR to empty it): one box edit a cell.
func change_cut(change: Dictionary, label: String) -> Dictionary:
	var edits: Array = []
	var lo := Vector4.INF
	var hi := -Vector4.INF
	var boxes: Array = []
	var fill: int = Recipe.AIR
	for key in change:
		var a: Vector4 = cell_lo(key)
		var m: int = int(change[key])
		edits.append(["BoxVoxelEdit4D", {"position": a, "size": Vector4.ONE * CELL, "fill_material": m}])
		boxes.append([a, a + Vector4.ONE * CELL, m])
		lo = Vector4(minf(lo.x, a.x), minf(lo.y, a.y), minf(lo.z, a.z), minf(lo.w, a.w))
		hi = Vector4(maxf(hi.x, a.x + CELL), maxf(hi.y, a.y + CELL), maxf(hi.z, a.z + CELL), maxf(hi.w, a.w + CELL))
		if m != Recipe.AIR:
			fill = m
	var colors: Array = []
	for key in change:
		var m: int = int(change[key]) if int(change[key]) != Recipe.AIR else int(_cells.get(key, -1))
		colors.append(color_of(m))
	return {"kind": "block", "fill": fill, "label": label, "edits": edits, "cells": change, "colors": colors,
		# Each cell covers CELL samples a side (its edges are off the grid by the jitter).
		"voxels": change.size() * CELL * CELL * CELL * CELL,
		"has": func(p: Vector4) -> bool:
			for b in boxes:
				var bl: Vector4 = b[0]
				var bh: Vector4 = b[1]
				if p.x >= bl.x and p.x < bh.x and p.y >= bl.y and p.y < bh.y and p.z >= bl.z and p.z < bh.z and p.w >= bl.w and p.w < bh.w:
					return true
			return false,
		"aabb": [lo, hi]}


## The specimen took `cut`: our copy follows, and the history.
func commit(cut: Dictionary) -> void:
	var change: Dictionary = cut["cells"]
	var before: Dictionary = {}
	for key in change:
		before[key] = int(_cells.get(key, Recipe.AIR))
		if int(change[key]) == Recipe.AIR:
			_cells.erase(key)
		else:
			_cells[key] = int(change[key])
	if bool(cut.get("undo", false)):
		_history.pop_back()
	else:
		_history.append(before)
		if _history.size() > 200:
			_history.remove_at(0)


func color_of(m: int) -> Color:
	if m < 2:
		return LINE_COLOR
	var c: int = clampi((m - 2) >> 1, 0, SHADES.size() - 1)
	return SHADES[c][(m - 2) & 1]


func material_name(m: int) -> String:
	if m < 2:
		return "THE GRID"
	return "%s BRICK" % COLOUR_NAMES[clampi((m - 2) >> 1, 0, COLOUR_NAMES.size() - 1)]


## The words by the cursor.
func hit_text(hover: Dictionary) -> String:
	return "%s  ·  W LAYER %d OF %d" % [material_name(int(hover.get("material", -1))), layer() + 1, NW]


## The outline at the hover, as world polylines [points, closed, accent]: the cube a brick would fill
## (white), or the brick that would go (accent).
func outline(sp: Node, hover: Dictionary, tool: String) -> Array:
	var key: Vector4i
	var accent: bool = false
	if tool == "take":
		if String(hover.get("on", "")) != "brick":
			return []
		key = hover["cell"]
		accent = true
	else:
		key = target(hover)
		if key.x < 0 and tool == "through" and String(hover.get("on", "")) == "brick":
			key = (hover["cell"] as Vector4i) + Vector4i(0, 1, 0, 0)
			if key.y >= NY:
				return []
		elif key.x < 0:
			return []
	var lo: Vector4 = cell_lo(key)
	var w: float = lo.w + CELL * 0.5
	var corners: Array = []
	for i in 8:
		var p := Vector4(lo.x + CELL * float(i & 1), lo.y + CELL * float((i >> 2) & 1), lo.z + CELL * float((i >> 1) & 1), w)
		corners.append(sp.call("to_global", p))
	var out: Array = []
	for top in [0, 4]:
		out.append([PackedVector4Array([corners[top], corners[top + 1], corners[top + 3], corners[top + 2]]), true, accent])
	for i in 4:
		out.append([PackedVector4Array([corners[i], corners[i + 4]]), false, accent])
	return out


## For the bench's card: the colours, the layer and what each holds.
func overlay_info(tool: String, colour: int) -> Dictionary:
	var per: Array = []
	per.resize(NW)
	per.fill(0)
	for key in _cells:
		per[(key as Vector4i).w] += 1
	var swatches: Array = []
	for c in SHADES.size():
		swatches.append(SHADES[c][1])
	return {"name": TOOL_NAMES.get(tool, tool.to_upper()), "line": String(LINES.get(tool, "")), "colour_name": COLOUR_NAMES[colour],
		"colours": swatches, "colour": colour, "layer": layer(), "layers": NW, "per_layer": per, "undo": not _history.is_empty()}


# -- the words ------------------------------------------------------------------------------------------------

func band_line() -> String:
	return "%s  ·  4D BRICKS ON A GRID, LIVE  ·  %d BRICKS IN %d W LAYERS" % [title.to_upper(), bricks(), _layers_used()]


func _layers_used() -> int:
	var seen: Dictionary = {}
	for key in _cells:
		seen[(key as Vector4i).w] = true
	return seen.size()


func card() -> Dictionary:
	var n: Dictionary = numbers()
	return {
		"short": "Put 4D bricks in place on a grid, then turn the slice and watch what you built change.",
		"code": code, "title": title, "kicker": "BUILDING IN 4D",
		"method": "A brick is a 4D box written into the voxels by the engine's own edit, then meshed by dual contouring in C++. Bricks snap to a grid in all four directions: the wheel moves you one W layer at a time.",
		"shows": "Our doorway stands in one W layer. Turn the slice and it is gone, because in W it is one brick thick. Build through W and it holds.",
		"limits": "Bricks of one colour fuse into one surface: voxels hold matter, not objects. So each colour comes in two shades, laid as a checker.",
		"rows": [["Bricks", str(bricks())], ["W layers used", "%d of %d" % [_layers_used(), NW]], ["Tetrahedra", String(n["tets"])]],
		"tier": "MEASURED LIVE", "key": "",
	}


## Three numbers for its floating panel.
func face() -> Array:
	var n: Dictionary = numbers()
	return [["Bricks", str(bricks())], ["W layers used", "%d of %d" % [_layers_used(), NW]], ["Tetrahedra", String(n["tets"])]]
