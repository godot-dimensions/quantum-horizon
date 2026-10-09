extends RefCounted

## A maze whose cells run along x, z AND w (PLAN.md steps 11 to 16, and round 2's R3, R5, R6). Cell
## (i, j, k): column i along +x, row j along +z (row 0 is the far one, -z, the way you face at the start),
## layer k along +w (layer 0 is kata-most). Every cell has six faces, open or closed; the open ones are
## kept as edges between two cells. This file knows nothing about nodes: the builder
## (maze_builder_4d.gd) turns it into walls, and the solver here gives the route, the par, the hints and
## the bot.
##
## THE LEVEL FILE (levels/*.txt), written by hand: a few "key = value" lines, then each W layer as a
## square character grid, layers separated by a line "---", layer 0 first:
##
##     name = Step
##     x_sizes = 6, 9, 6        optional: the cells' sizes along x, z and w in metres (default 6), so a
##     ---                      level can have narrow corridors and wide halls (round 2, R3)
##     #######      '#' wall (or the corner posts), ' ' open between two cells
##     #^ .#E#      cells: '.' plain, 'S' start, 'E' exit, '^' a door to the layer above (ana, +w),
##     # ### #             'v' a door to the layer below (kata), 'x' both. A door needs marking in only
##     #S .#.#             one of its two layers (both is fine).
##     #######
##     h 000        optional, one line per row: each cell's floor height in steps of RISE (1.2 m), or
##     h 0>1        a stair that rises from its low neighbour's height to its high one's: '>' toward
##     h 000        +x, '<' toward -x, 'n' toward -z, 's' toward +z, '+' toward +w (ana), '-' toward -w
##     r 110        optional, one line per row: '1' roofs the cell (an indoor stretch; Ramon, 9 Oct: "some
##                  parts where you're in an indoor maze again")
##
## Lines run from -z down to +z, characters along +x. A stair connects only along its own axis, and two
## open cells connect only where their floors meet at the same height, so a ledge is a wall to the solver
## (the walker steps 0.32 m, and jumps about 1.1).
##
## NO class_name (engine_gotchas.md): preload it.

## Axes as used everywhere in the maze: 0 = x, 1 = z, 2 = w.
const AXES := ["x", "z", "w"]
const STEPS := [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
## One height step in the level file, in metres: four 0.3 m stairs.
const RISE := 1.2
## The stair characters: [axis, sign of the rise].
const STAIR_CHARS := {">": [0, 1], "<": [0, -1], "s": [1, 1], "n": [1, -1], "+": [2, 1], "-": [2, -1]}

var nx: int = 0
var nz: int = 0
var nw: int = 0
var start := Vector3i.ZERO
var exit := Vector3i.ZERO
var meta: Dictionary = {}
## Open edges: key Vector4i(i, j, k, axis) for the edge from cell (i, j, k) to the next cell along axis.
var open: Dictionary = {}
## The lattice's low corner in the world (x, z, w; y is the ground, 0). fit_origin() sets it.
var origin := Vector4.ZERO
## Each cell's size along x, z and w, in metres.
var sizes: Array = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
## Where each cell starts along each axis, from the low corner (prefix sums of sizes).
var starts: Array = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
## Floor heights in metres by cell (missing: 0), and stairs by cell: [axis, sign]; roofed cells.
var heights: Dictionary = {}
var stairs: Dictionary = {}
var roofs: Dictionary = {}
## The default cell size, for levels that give none.
var cell: float = 6.0


static func load_file(path: String) -> RefCounted:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("maze: cannot read %s" % path)
		return null
	return parse(f.get_as_text())


static func parse(text: String) -> RefCounted:
	var lv = load("res://ramon/PhaseMazeRemake/maze/maze_lattice.gd").new()
	var parts: PackedStringArray = text.replace("\r", "").split("\n---")
	for line in parts[0].split("\n"):
		var eq: int = line.find("=")
		if eq > 0:
			lv.meta[line.substr(0, eq).strip_edges()] = line.substr(eq + 1).strip_edges()
	var grids: Array = []
	var hgrids: Array = []
	var rgrids: Array = []
	for p in range(1, parts.size()):
		var rows: Array = []
		var hrows: Array = []
		var rrows: Array = []
		for line in parts[p].split("\n"):
			var t: String = line.strip_edges(false, true)
			if t.begins_with("#"):
				rows.append(t)
			elif t.begins_with("h "):
				hrows.append(t.substr(2))
			elif t.begins_with("r "):
				rrows.append(t.substr(2))
		if not rows.is_empty():
			grids.append(rows)
			hgrids.append(hrows)
			rgrids.append(rrows)
	lv.nw = grids.size()
	lv.nz = (grids[0].size() - 1) / 2
	lv.nx = (String(grids[0][0]).length() - 1) / 2
	var found_s := false
	var found_e := false
	for k in lv.nw:
		var g: Array = grids[k]
		var hg: Array = hgrids[k]
		var rg: Array = rgrids[k]
		for j in lv.nz:
			for i in lv.nx:
				var ch: String = String(g[2 * j + 1]).substr(2 * i + 1, 1)
				var c := Vector3i(i, j, k)
				if ch == "S":
					lv.start = c
					found_s = true
				elif ch == "E":
					lv.exit = c
					found_e = true
				if i < lv.nx - 1 and String(g[2 * j + 1]).substr(2 * i + 2, 1) == " ":
					lv.set_open(c, 0)
				if j < lv.nz - 1 and String(g[2 * j + 2]).substr(2 * i + 1, 1) == " ":
					lv.set_open(c, 1)
				if (ch == "^" or ch == "x") and k + 1 < lv.nw:
					lv.set_open(c, 2)
				if (ch == "v" or ch == "x") and k > 0:
					lv.set_open(c - Vector3i(0, 0, 1), 2)
				if j < rg.size() and i < String(rg[j]).length() and String(rg[j]).substr(i, 1) == "1":
					lv.roofs[c] = true
				if j < hg.size() and i < String(hg[j]).length():
					var hc: String = String(hg[j]).substr(i, 1)
					if STAIR_CHARS.has(hc):
						lv.stairs[c] = STAIR_CHARS[hc]
					elif hc.is_valid_int():
						lv.heights[c] = float(hc.to_int()) * RISE
	if not found_s or not found_e:
		push_error("maze: level has no S or no E")
	for a in 3:
		var key: String = ["x_sizes", "z_sizes", "w_sizes"][a]
		var n: int = [lv.nx, lv.nz, lv.nw][a]
		var arr := PackedFloat32Array()
		var given: PackedStringArray = String(lv.meta.get(key, "")).split(",", false)
		for i in n:
			arr.append(float(given[i].strip_edges()) if i < given.size() else lv.cell)
		lv.sizes[a] = arr
	lv._stair_heights()
	lv._prefix()
	return lv


## The old level 2's recipe (PhaseMaze/scripts/phase_maze_2_builder.gd) in three directions: a
## depth-first spanning tree, then the two ends of its longest path (two breadth-first passes) become the
## start and the exit, the start on the near row (+z) so the overlook and its lift stand over it.
static func generate(gx: int, gz: int, gw: int, seed_value: int) -> RefCounted:
	var lv = load("res://ramon/PhaseMazeRemake/maze/maze_lattice.gd").new()
	lv.nx = gx
	lv.nz = gz
	lv.nw = gw
	lv.meta = {"name": "Generated", "seed": str(seed_value)}
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed_value
	var first := Vector3i.ZERO
	var seen: Dictionary = {first: true}
	var stack: Array = [first]
	while not stack.is_empty():
		var c: Vector3i = stack.back()
		var opts: Array = []
		for a in 3:
			for s in [-1, 1]:
				var n: Vector3i = c + STEPS[a] * s
				if lv.inside(n) and not seen.has(n):
					opts.append(n)
		if opts.is_empty():
			stack.pop_back()
			continue
		var n: Vector3i = opts[rnd.randi_range(0, opts.size() - 1)]
		lv.connect_cells(c, n)
		seen[n] = true
		stack.append(n)
	# Irregular sizes, so a generated maze has halls and lanes too.
	for a in 3:
		var arr := PackedFloat32Array()
		for i in [gx, gz, gw][a]:
			arr.append([5.0, 6.0, 8.0][rnd.randi_range(0, 2)])
		lv.sizes[a] = arr
	lv._prefix()
	var far_a: Vector3i = lv.farthest(first)
	var far_b: Vector3i = lv.farthest(far_a)
	# The exit at one end; the start the farthest cell from it on the near row.
	var from_exit: Dictionary = lv.distances(far_b)
	var best := Vector3i(-1, -1, -1)
	for c in from_exit:
		var cc: Vector3i = c
		if cc.y == gz - 1 and (best.x < 0 or int(from_exit[cc]) > int(from_exit[best])):
			best = cc
	lv.start = best if best.x >= 0 else far_a
	lv.exit = far_b
	return lv


func _prefix() -> void:
	for a in 3:
		var pre := PackedFloat32Array()
		var acc: float = 0.0
		for s in sizes[a]:
			pre.append(acc)
			acc += float(s)
		starts[a] = pre


## A stair's ends are its low and high neighbours' heights.
func _stair_heights() -> void:
	pass


## Places the lattice: centred on x 0, its near (+z) edge on z 0, layer 0's middle on w 0.
func fit_origin() -> void:
	var tx: float = total(0)
	var tz: float = total(1)
	origin = Vector4(-tx * 0.5, 0.0, -tz, -float(sizes[2][0]) * 0.5)


func total(a: int) -> float:
	var t: float = 0.0
	for s in sizes[a]:
		t += float(s)
	return t


func inside(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < nx and c.y < nz and c.z < nw


func set_open(c: Vector3i, axis: int) -> void:
	open[Vector4i(c.x, c.y, c.z, axis)] = true


func connect_cells(a: Vector3i, b: Vector3i) -> void:
	var d: Vector3i = b - a
	var axis: int = 0 if d.x != 0 else (1 if d.y != 0 else 2)
	var lo: Vector3i = a if (d.x + d.y + d.z) > 0 else b
	set_open(lo, axis)


## Whether the face of `c` on side `sign` (+1 or -1) of `axis` is open. Faces on the edge are closed.
func is_open(c: Vector3i, axis: int, sign: int) -> bool:
	var lo: Vector3i = c if sign > 0 else c - STEPS[axis]
	if not inside(lo) or not inside(lo + STEPS[axis]):
		return false
	return open.has(Vector4i(lo.x, lo.y, lo.z, axis))


## The floor's height where cell `c` meets its face on side `sign` of `axis`: a flat cell's height; a
## stair's low or high end on its own axis; NAN where a stair meets a face across its axis.
func face_height(c: Vector3i, axis: int, sign: int) -> float:
	if stairs.has(c):
		var st: Array = stairs[c]
		if int(st[0]) != axis:
			return NAN
		var ends: Vector2 = stair_ends(c)
		return ends.y if sign == int(st[1]) else ends.x
	return float(heights.get(c, 0.0))


## A stair's [low, high] heights. Every stair rises one RISE (1.2 m, four steps) from the floor at its
## low side: a flat neighbour's height, or the top of a stair below it, so stairs chain into a flight.
func stair_ends(c: Vector3i) -> Vector2:
	var st: Array = stairs[c]
	var a: int = int(st[0])
	var s: int = int(st[1])
	var lo_n: Vector3i = c - STEPS[a] * s
	var lo: float = float(heights.get(c, 0.0))
	if inside(lo_n):
		if stairs.has(lo_n) and int(stairs[lo_n][0]) == a and int(stairs[lo_n][1]) == s:
			lo = stair_ends(lo_n).y
		elif not stairs.has(lo_n):
			lo = float(heights.get(lo_n, 0.0))
	return Vector2(lo, lo + RISE)


## The floor's highest point in a cell (for its walls).
func top_height(c: Vector3i) -> float:
	if stairs.has(c):
		return stair_ends(c).y
	return float(heights.get(c, 0.0))


## Whether you can walk from `c` across its face on `sign` of `axis`: open, and the floors meet.
func passable(c: Vector3i, axis: int, sign: int) -> bool:
	if not is_open(c, axis, sign):
		return false
	var n: Vector3i = c + STEPS[axis] * sign
	var h1: float = face_height(c, axis, sign)
	var h2: float = face_height(n, axis, -sign)
	if is_nan(h1) or is_nan(h2):
		return false
	return absf(h1 - h2) < 0.35


func neighbours(c: Vector3i) -> Array:
	var out: Array = []
	for a in 3:
		for s in [1, -1]:
			if passable(c, a, s):
				out.append(c + STEPS[a] * s)
	return out


## Breadth-first from `a`: {cell: previous cell or null}, in the order reached.
func bfs(a: Vector3i) -> Dictionary:
	var prev: Dictionary = {a: null}
	var q: Array = [a]
	var head: int = 0
	while head < q.size():
		var c: Vector3i = q[head]
		head += 1
		for n in neighbours(c):
			if not prev.has(n):
				prev[n] = c
				q.append(n)
	return prev


func distances(a: Vector3i) -> Dictionary:
	var dist: Dictionary = {a: 0}
	var q: Array = [a]
	var head: int = 0
	while head < q.size():
		var c: Vector3i = q[head]
		head += 1
		for n in neighbours(c):
			if not dist.has(n):
				dist[n] = int(dist[c]) + 1
				q.append(n)
	return dist


func farthest(a: Vector3i) -> Vector3i:
	var prev: Dictionary = bfs(a)
	return prev.keys().back()


## The shortest route from `from` (the start by default) to the exit, both ends included; [] if none.
func route(from: Variant = null) -> Array:
	var a: Vector3i = start if from == null else from
	var prev: Dictionary = bfs(a)
	if not prev.has(exit):
		return []
	var p: Array = [exit]
	while prev[p.back()] != null:
		p.append(prev[p.back()])
	p.reverse()
	return p


static func axis_of(a: Vector3i, b: Vector3i) -> int:
	var d: Vector3i = b - a
	return 0 if d.x != 0 else (1 if d.y != 0 else 2)


func par_w() -> int:
	var p: Array = route()
	var n: int = 0
	for i in range(1, p.size()):
		if axis_of(p[i - 1], p[i]) == 2:
			n += 1
	return n


func shortest_routes() -> int:
	var dist: Dictionary = {start: 0}
	var ways: Dictionary = {start: 1}
	var q: Array = [start]
	var head: int = 0
	while head < q.size():
		var c: Vector3i = q[head]
		head += 1
		for n in neighbours(c):
			if not dist.has(n):
				dist[n] = int(dist[c]) + 1
				ways[n] = int(ways[c])
				q.append(n)
			elif int(dist[n]) == int(dist[c]) + 1:
				ways[n] = int(ways[n]) + int(ways[c])
	return int(ways.get(exit, 0))


func dead_ends() -> Array:
	var out: Array = []
	for c in bfs(start):
		if neighbours(c).size() == 1 and c != start and c != exit:
			out.append(c)
	return out


## Problems that make a level unfit to ship (PLAN.md step 14): an empty list is a pass.
func validate() -> Array:
	var out: Array = []
	if nx < 1 or nz < 1 or nw < 1:
		out.append("empty")
		return out
	if not inside(start) or not inside(exit):
		out.append("start or exit outside the maze")
	if route().is_empty():
		out.append("exit unreachable")
	if meta.has("route"):
		var want: String = String(meta["route"])
		var got: String = route_text()
		if want != got:
			out.append("route changed: want %s, got %s" % [want, got])
	for c in stairs:
		var st: Array = stairs[c]
		var ends: Vector2 = stair_ends(c)
		if ends.y - ends.x < 0.3:
			out.append("stair at %s does not rise" % str(c))
		for a in 3:
			if a == int(st[0]):
				continue
			for s in [-1, 1]:
				if is_open(c, a, s):
					out.append("stair at %s is open across its axis (%s)" % [str(c), AXES[a]])
	if stairs.has(start) or stairs.has(exit):
		out.append("start or exit on a stair")
	return out


func route_text() -> String:
	var p: Array = route()
	var out: PackedStringArray = []
	var last: int = -1
	var count: int = 0
	for i in range(1, p.size()):
		var a: int = axis_of(p[i - 1], p[i])
		if a == last:
			count += 1
		else:
			if last >= 0:
				out.append("%s%d" % [AXES[last], count])
			last = a
			count = 1
	if last >= 0:
		out.append("%s%d" % [AXES[last], count])
	return " ".join(out)


# -- the world ----------------------------------------------------------------------------------------

## A cell's size along x, z and w.
func size_of(c: Vector3i) -> Vector3:
	return Vector3(sizes[0][c.x], sizes[1][c.y], sizes[2][c.z])


## A cell's low corner (x, z, w; y 0).
func cell_min(c: Vector3i) -> Vector4:
	return origin + Vector4(starts[0][c.x], 0.0, starts[1][c.y], starts[2][c.z])


## A cell's middle, at its floor (a stair's middle height).
func cell_centre(c: Vector3i) -> Vector4:
	var s: Vector3 = size_of(c)
	var y: float = float(heights.get(c, 0.0))
	if stairs.has(c):
		var e: Vector2 = stair_ends(c)
		y = (e.x + e.y) * 0.5
	return cell_min(c) + Vector4(s.x * 0.5, y, s.y * 0.5, s.z * 0.5)


## The cell a world point is in (may be outside the maze: check inside()).
func cell_at(p: Vector4) -> Vector3i:
	var q: Vector4 = p - origin
	return Vector3i(_index(0, q.x), _index(1, q.z), _index(2, q.w))


func _index(a: int, v: float) -> int:
	var pre: PackedFloat32Array = starts[a]
	var n: int = pre.size()
	if v < 0.0:
		return -1
	for i in n:
		if v < pre[i] + float(sizes[a][i]):
			return i
	return n


## The maze's extent in metres, as [min corner, max corner] in (x, z, w).
func bounds() -> Array:
	return [origin, origin + Vector4(total(0), 0.0, total(1), total(2))]


## The floor height under a world point in cell `c` (a stair's step there).
func floor_y(c: Vector3i, p: Vector4) -> float:
	if not stairs.has(c):
		return float(heights.get(c, 0.0))
	var st: Array = stairs[c]
	var a: int = int(st[0])
	var s: int = int(st[1])
	var e: Vector2 = stair_ends(c)
	var lo: Vector4 = cell_min(c)
	var size: float = size_of(c)[a]
	var along: float = [p.x - lo.x, p.z - lo.z, p.w - lo.w][a] / size
	if s < 0:
		along = 1.0 - along
	var n: int = maxi(1, roundi((e.y - e.x) / 0.3))
	var step: int = clampi(int(along * float(n)), 0, n - 1)
	return e.x + (e.y - e.x) * float(step + 1) / float(n)
