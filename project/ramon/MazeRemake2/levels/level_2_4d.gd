extends "res://ramon/MazeRemake2/levels/mr2_level_4d.gd"
## LEVEL 2, THE STACKS: the same doorway does not lead to the same room twice.
##
## A forgotten archive: nine 8 m bays in a 3 by 3 grid round a hub, with a glowing pillar in the hub
## that is the one thing the same at every W. Every doorway between bays is a passage through W: open
## at some W, and at the others a plug of wall rises out of the floor to close it. The stripes over a
## doorway say where it is open (amber kata, blue home, teal ana), so the hub's four doors each lead
## somewhere else as you shift.
##
##   HOME  south bay to hub; hub to the west bay, an ARCHIVE of tall shelves; on to a quiet reading room
##   KATA  hub to the north bay, a PIT crossed by an amber bridge to a landing in the middle; the west
##         bay is a dark COMPUTER ROOM here (the shelves sink, partitions rise), with a log and a relic
##   ANA   hub to the east bay, a gallery, and on to a relic; and from the pit's landing a teal bridge to
##         the north-east bay
## So the way out is two routes that meet: kata over the amber bridge to the landing, shift there (the
## landing is there at every W), and ana over the teal one. The north-east bay holds the Lens: taking it
## plays a short film that turns the view into W, and three sculptures that share one plinth stand side
## by side; then the lift.
##
## On paper: PLAN.md section 4. Bays are 8 m; the grid is x -12..12, z -12..12; you arrive from the
## south facing -z.

const W_LO := -3.5
const W_HI := 3.5
const K_HI := -1.25
const A_LO := 1.25
const H := 6.0
const CEIL := 4.4
const LANDMARK := Color(1.0, 0.47, 0.06)

var lens_taken: bool = false
var _lens: Node4D
var _sculptures: Array[Node4D] = []
var _band_k: Array
var _band_h: Array
var _band_a: Array


func _init() -> void:
	number = 2
	title = "THE STACKS"
	w_min = W_LO
	w_max = W_HI
	bands = [[-2.4, Build.KATA, "KATA"], [0.0, Build.HOME, "HOME"], [2.4, Build.ANA, "ANA"]]
	_band_k = [W_LO, K_HI, Build.KATA]
	_band_h = [K_HI, A_LO, Build.HOME]
	_band_a = [A_LO, W_HI, Build.ANA]
	spawn = Vector4(0, 0, 14.6, 0)
	spawn_yaw = 0.0
	checkpoints = [
		{"name": "north bay", "lo": Vector4(-4, -40, -12, W_LO - 1), "hi": Vector4(4, 9, -4, W_HI + 1), "at": Vector4(0, 0, -4.5, -2.4), "yaw": 0.0},
		{"name": "computer room", "lo": Vector4(-12, -1, -4, W_LO - 1), "hi": Vector4(-4, 9, 4, K_HI), "at": Vector4(-5.0, 0, 0, -2.4), "yaw": PI * 0.5},
		{"name": "archive", "lo": Vector4(-12, -1, -4, K_HI), "hi": Vector4(-4, 9, 4, W_HI + 1), "at": Vector4(-5.0, 0, 0, 0), "yaw": PI * 0.5},
		{"name": "reading room", "lo": Vector4(-12, -1, -12, W_LO - 1), "hi": Vector4(-4, 9, -4, W_HI + 1), "at": Vector4(-8, 0, -5.0, 0), "yaw": PI},
		{"name": "gallery", "lo": Vector4(4, -1, -4, W_LO - 1), "hi": Vector4(12, 9, 4, W_HI + 1), "at": Vector4(5.0, 0, 0, 2.4), "yaw": -PI * 0.5},
		{"name": "south-east", "lo": Vector4(4, -1, 4, W_LO - 1), "hi": Vector4(12, 9, 12, W_HI + 1), "at": Vector4(8, 0, 5.0, 2.4), "yaw": PI},
		{"name": "north-east", "lo": Vector4(4, -1, -16, W_LO - 1), "hi": Vector4(12, 9, -4, W_HI + 1), "at": Vector4(5.0, 0, -8, 2.4), "yaw": -PI * 0.5},
		{"name": "hub", "lo": Vector4(-4, -1, -4, W_LO - 1), "hi": Vector4(4, 9, 4, W_HI + 1), "at": Vector4(0, 0, 3.0, 0), "yaw": 0.0},
		{"name": "start", "lo": Vector4(-4, -1, 4, W_LO - 1), "hi": Vector4(4, 9, 16, W_HI + 1), "at": Vector4(0, 0, 9.0, 0), "yaw": 0.0},
	]
	lift_out = {"lo": Vector4(7.0, -1, -15.6, W_LO - 1), "hi": Vector4(9.0, 3, -13.0, W_HI + 1)}


func build_level() -> void:
	var b = build
	var wl: float = W_LO - 1.0
	var wh: float = W_HI + 1.0
	# THE FLOOR: everywhere but the north bay's pit.
	b.floor_rect(-12, -4, 12, 12, wl, wh)
	b.floor_rect(-12, -12, -4, -4, wl, wh)
	b.floor_rect(4, -12, 12, -4, wl, wh)
	b.floor_rect(-1.5, 12, 1.5, 16, wl, wh)
	b.floor_rect(6.5, -16, 9.5, -12, wl, wh)
	# The building's ends in W.
	b.cap(-12.2, -16.2, 12.2, 16.2, W_HI, W_HI + 1.0, H + 0.5)
	b.cap(-12.2, -16.2, 12.2, 16.2, W_LO - 1.0, W_LO, H + 0.5)

	# THE OUTER WALLS, with the two lift openings.
	b.wall_z(-12.2, 12.2, -12.0, wl, wh, H)
	b.wall_z(-12.2, 12.2, 12.0, wl, wh, H)
	b.wall_x(-12.2, -1.0, 12.0, wl, wh, H)
	b.wall_x(1.0, 12.2, 12.0, wl, wh, H)
	b.box(Vector3(-1.0, 3.0, 11.8), Vector3(1.0, H, 12.2), wl, wh)
	b.wall_x(-12.2, 7.0, -12.0, wl, wh, H)
	b.wall_x(9.0, 12.2, -12.0, wl, wh, H)
	b.box(Vector3(7.0, 3.0, -12.2), Vector3(9.0, H, -11.8), wl, wh)

	# THE GRID: walls on x = -4, 4 and z = -4, 4, with a passage or a wall in each bay boundary.
	var K: Array = _band_k
	var Hm: Array = _band_h
	var A: Array = _band_a
	# z = 4 (south row | middle row): W-SW wall, H-S passage (all), E-SE passage (ana).
	_line_x(4.0, [[-8.0, null], [0.0, [K, Hm, A]], [8.0, [A]]])
	# z = -4 (middle row | north row): NW-W passage (home), N-H passage (kata), NE-E wall.
	_line_x(-4.0, [[-8.0, [Hm]], [0.0, [K]], [8.0, null]])
	# x = -4: SW-S wall, W-H passage (kata, home), NW-N wall.
	_line_z(-4.0, [[8.0, null], [0.0, [K, Hm]], [-8.0, null]])
	# x = 4: S-SE wall, H-E passage (ana), N-NE passage (ana).
	_line_z(4.0, [[8.0, null], [0.0, [A]], [-8.0, [A]]])

	# CEILINGS: 4.4 m in the bays; the hub open to 6 m with a skylight; the pit open above too.
	for bx in [-8.0, 0.0, 8.0]:
		for bz in [-8.0, 0.0, 8.0]:
			if (bx == 0.0 and bz == 0.0) or (bx == 0.0 and bz == -8.0):
				continue
			b.ceiling_rect(bx - 4.0, bz - 4.0, bx + 4.0, bz + 4.0, CEIL, wl, wh)
			# Fluorescent tubes.
			for k in [-1.6, 1.6]:
				b.glow(Morph.standing(Vector3(bx + k - 0.08, CEIL - 0.03, bz - 2.6), Vector3(bx + k + 0.08, CEIL, bz + 2.6), wl, wh), Color(0.93, 0.96, 1.0))
	b.ceiling_rect(-4, -4, 4, 4, H, wl, wh)
	b.ceiling_rect(-4, -12, 4, -4, H, wl, wh)
	b.glow(Morph.standing(Vector3(-2.2, H - 0.04, -2.2), Vector3(2.2, H, 2.2), wl, wh), Color(0.95, 0.97, 1.0))

	# THE HUB'S PILLAR: the one thing that is the same at every W. It hangs from the skylight down to
	# just over your head, with its ring on the floor under it, so the doorways behind it stay in view
	# and you can walk under it.
	b.glow(Morph.standing(Vector3(-0.3, 3.1, -0.3), Vector3(0.3, H, 0.3), wl, wh), LANDMARK)
	b.box(Vector3(-0.42, 2.95, -0.42), Vector3(0.42, 3.1, 0.42), wl, wh, "metal", false)
	for ring in [[Vector3(-1.0, 0.0, -1.0), Vector3(1.0, 0.012, -0.94)], [Vector3(-1.0, 0.0, 0.94), Vector3(1.0, 0.012, 1.0)],
			[Vector3(-1.0, 0.0, -1.0), Vector3(-0.94, 0.012, 1.0)], [Vector3(0.94, 0.0, -1.0), Vector3(1.0, 0.012, 1.0)]]:
		b.glow(Morph.standing(ring[0], ring[1], wl, wh), LANDMARK)

	# THE WEST BAY: an ARCHIVE at home (tall shelves), a COMPUTER ROOM kata (partitions, a desk).
	for sx in [-10.6, -7.6]:
		b.add(Morph.standing(Vector3(sx - 0.35, 0.0, -2.6), Vector3(sx + 0.35, 3.4, 2.6), K_HI + 0.15, wh, 0.45), "desk", true)
		for shelf_y in [0.9, 1.8, 2.7]:
			b.add(Morph.standing(Vector3(sx - 0.42, shelf_y, -2.65), Vector3(sx + 0.42, shelf_y + 0.06, 2.65), K_HI + 0.15, wh, 0.45), "metal", false)
	b.add(Morph.standing(Vector3(-12.0, 0.0, 2.4), Vector3(-6.2, 3.4, 2.75), wl, K_HI - 0.15, 0.45), "glass", true)
	b.add(Morph.standing(Vector3(-12.0, 0.0, -2.75), Vector3(-6.2, 3.4, -2.4), wl, K_HI - 0.15, 0.45), "glass", true)
	b.add(Morph.standing(Vector3(-11.85, 0.0, -2.4), Vector3(-11.75, 3.4, 2.4), wl, K_HI - 0.15, 0.45), "glass", false)
	b.add(Morph.standing(Vector3(-11.6, 0.0, -1.0), Vector3(-10.4, 0.78, 1.0), wl, K_HI - 0.15, 0.45), "desk", true)
	b.add(Morph.standing(Vector3(-11.55, 0.78, -0.55), Vector3(-11.42, 1.6, 0.55), wl, K_HI - 0.15, 0.45), "metal", false)
	for zz in [-2.3, 2.3]:
		b.glow(Morph.standing(Vector3(-11.8, 2.7, zz - 0.04), Vector3(-6.3, 2.75, zz + 0.04), wl, K_HI - 0.15, 0.45), Build.KATA)
	b.cap(-11.8, -3.8, -4.2, 3.8, A_LO - 0.15, wh, CEIL)

	# THE READING ROOM (north-west, home only).
	b.box(Vector3(-10.0, 0.0, -9.0), Vector3(-6.0, 0.45, -8.4), wl, wh, "desk")
	b.cap(-11.8, -11.8, -4.2, -4.2, wl, K_HI - 0.15, CEIL)
	b.cap(-11.8, -11.8, -4.2, -4.2, A_LO + 0.15, wh, CEIL)

	# THE GALLERY (east, ana) and the south-east bay beyond it.
	for gz in [-2.2, 2.2]:
		b.box(Vector3(9.4, 0.0, gz - 0.6), Vector3(10.6, 1.0, gz + 0.6), wl, wh, "metal")
	b.cap(4.2, -3.8, 11.8, 3.8, wl, A_LO - 0.15, CEIL)
	b.cap(4.2, 4.2, 11.8, 11.8, wl, A_LO - 0.15, CEIL)

	# THE NORTH BAY: a pit, a ledge at the door from the hub, a landing in the middle (there at every W),
	# an amber bridge (kata) from the ledge to the landing, a teal bridge (ana) from the landing east.
	b.floor_rect(-4, -5.0, 4, -4, wl, wh)
	b.floor_rect(-1.2, -9.5, 1.2, -7.5, wl, wh)
	b.floor_rect(3.0, -9.0, 4.2, -7.0, wl, wh)
	_bridge(Vector3(-0.7, 0.0, -7.5), Vector3(0.7, 0.0, -5.0), "z", wl, K_HI + 0.25, Build.KATA)
	_bridge(Vector3(1.2, 0.0, -8.7), Vector3(3.0, 0.0, -7.3), "x", A_LO - 0.25, wh, Build.ANA)
	# The bottom, far down: lights you see falling towards.
	b.box(Vector3(-4, -14.5, -12), Vector3(4, -14.0, -4), wl, wh, "glass", false)
	for gx in [-2.5, 0.0, 2.5]:
		b.glow(Morph.standing(Vector3(gx - 0.05, -14.0, -11.5), Vector3(gx + 0.05, -13.96, -5.5), wl, wh), Color(0.25, 0.5, 0.9))
	# Pit walls going down (so the drop reads as a shaft).
	b.box(Vector3(-4.2, -14.5, -12.2), Vector3(4.2, -0.02, -11.8), wl, wh, "glass", false)
	b.box(Vector3(-4.2, -14.5, -12.2), Vector3(-3.8, -0.02, -4.0), wl, wh, "glass", false)
	b.box(Vector3(3.8, -14.5, -12.2), Vector3(4.2, -0.02, -4.0), wl, wh, "glass", false)
	b.box(Vector3(-4.2, -14.5, -5.2), Vector3(4.2, -0.52, -5.0), wl, wh, "glass", false)
	# The edges you could fall from, lit.
	var edge := Color(0.92, 0.94, 1.0)
	b.glow(Morph.standing(Vector3(-4.0, -0.01, -5.04), Vector3(-0.7, 0.012, -4.98), wl, wh), edge)
	b.glow(Morph.standing(Vector3(0.7, -0.01, -5.04), Vector3(4.0, 0.012, -4.98), wl, wh), edge)
	for e in [[Vector3(-1.2, -0.01, -9.54), Vector3(1.2, 0.012, -9.48)], [Vector3(-1.2, -0.01, -7.52), Vector3(-0.7, 0.012, -7.46)],
			[Vector3(0.7, -0.01, -7.52), Vector3(1.2, 0.012, -7.46)], [Vector3(-1.26, -0.01, -9.5), Vector3(-1.2, 0.012, -7.5)],
			[Vector3(1.2, -0.01, -9.5), Vector3(1.26, 0.012, -8.7)], [Vector3(1.2, -0.01, -7.3), Vector3(1.26, 0.012, -7.5)],
			[Vector3(2.96, -0.01, -9.0), Vector3(3.02, 0.012, -8.7)], [Vector3(2.96, -0.01, -7.3), Vector3(3.02, 0.012, -7.0)]]:
		b.glow(Morph.standing(e[0], e[1], wl, wh), edge)

	# THE NORTH-EAST BAY: the Lens on its plinth; against the east wall a bench with three sculptures
	# that share one place, one in each band.
	b.box(Vector3(7.3, 0.0, -8.7), Vector3(8.7, 1.0, -7.3), wl, wh, "metal")
	b.glow(Morph.standing(Vector3(7.25, 1.0, -8.75), Vector3(8.75, 1.03, -7.25), wl, wh), Color(0.55, 0.85, 1.0))
	b.box(Vector3(10.4, 0.0, -10.0), Vector3(11.6, 0.9, -6.0), wl, wh, "desk")

	# THE START LIFT (south) and THE LIFT OUT (north of the north-east bay).
	b.wall_z(12.0, 16.2, -1.5, wl, wh, 3.0)
	b.wall_z(12.0, 16.2, 1.5, wl, wh, 3.0)
	b.wall_x(-1.7, 1.7, 16.0, wl, wh, 3.0)
	b.ceiling_rect(-1.7, 12.0, 1.7, 16.2, 3.0, wl, wh)
	b.wall_z(-16.2, -12.0, 6.5, wl, wh, 3.0)
	b.wall_z(-16.2, -12.0, 9.5, wl, wh, 3.0)
	b.wall_x(6.3, 9.7, -16.0, wl, wh, 3.0)
	b.ceiling_rect(6.3, -16.2, 9.7, -12.0, 3.0, wl, wh)
	_lift_ring(b, Vector2(8.0, -14.3), wl, wh)


## A row of bay-boundary walls along x at `z`, one 8 m segment per bay, each with a passage (its open
## bands) or none (`null`: a plain wall).
func _line_x(z: float, cells: Array) -> void:
	for c in cells:
		var cx: float = float(c[0])
		if c[1] == null:
			build.wall_x(cx - 4.2, cx + 4.2, z, W_LO - 1.0, W_HI + 1.0, H)
			continue
		build.wall_x(cx - 4.2, cx - 1.0, z, W_LO - 1.0, W_HI + 1.0, H)
		build.wall_x(cx + 1.0, cx + 4.2, z, W_LO - 1.0, W_HI + 1.0, H)
		build.passage({"name": "doorway", "at": Vector2(cx, z), "along": "x", "open": c[1], "w_lo": W_LO, "w_hi": W_HI, "wall_h": H})


func _line_z(x: float, cells: Array) -> void:
	for c in cells:
		var cz: float = float(c[0])
		if c[1] == null:
			build.wall_z(cz - 4.2, cz + 4.2, x, W_LO - 1.0, W_HI + 1.0, H)
			continue
		build.wall_z(cz - 4.2, cz - 1.0, x, W_LO - 1.0, W_HI + 1.0, H)
		build.wall_z(cz + 1.0, cz + 4.2, x, W_LO - 1.0, W_HI + 1.0, H)
		build.passage({"name": "doorway", "at": Vector2(x, cz), "along": "z", "open": c[1], "w_lo": W_LO, "w_hi": W_HI, "wall_h": H})


## A bridge over the pit from `lo` to `hi` (x, z corners, its top at y 0), there from W `w0` to `w1`;
## beyond its range it narrows to nothing over 0.4 m of W (so standing on it as you shift out, it goes).
## Its edges glow in its band's colour. `along` is the way it runs ("x" or "z"); it narrows across that.
func _bridge(lo: Vector3, hi: Vector3, along: String, w0: float, w1: float, col: Color) -> void:
	var keys: Array = []
	var mid: float = (lo.z + hi.z) * 0.5 if along == "x" else (lo.x + hi.x) * 0.5
	var thin_lo: Vector3 = Vector3(lo.x, -0.5, mid - 0.005) if along == "x" else Vector3(mid - 0.005, -0.5, lo.z)
	var thin_hi: Vector3 = Vector3(hi.x, 0.0, mid + 0.005) if along == "x" else Vector3(mid + 0.005, 0.0, hi.z)
	var full_lo := Vector3(lo.x, -0.5, lo.z)
	var full_hi := Vector3(hi.x, 0.0, hi.z)
	if w0 > W_LO:
		keys.append(Morph.key(w0 - 0.4, thin_lo, thin_hi))
	else:
		keys.append(Morph.key(w0 - 1.0, full_lo, full_hi))
	keys.append(Morph.key(w0, full_lo, full_hi))
	keys.append(Morph.key(w1, full_lo, full_hi))
	if w1 < W_HI:
		keys.append(Morph.key(w1 + 0.4, thin_lo, thin_hi))
	else:
		keys.append(Morph.key(w1 + 1.0, full_lo, full_hi))
	build.add(keys, "floor", true)
	# The edge lights ride along with the planks.
	for side in [-1.0, 1.0]:
		var gk: Array = []
		for k in keys:
			var a: Vector3 = k[1]
			var c: Vector3 = k[2]
			if along == "x":
				var e: float = c.z if side > 0.0 else a.z
				gk.append(Morph.key(float(k[0]), Vector3(a.x, -0.02, e - 0.03), Vector3(c.x, 0.03, e + 0.03)))
			else:
				var e2: float = c.x if side > 0.0 else a.x
				gk.append(Morph.key(float(k[0]), Vector3(e2 - 0.03, -0.02, a.z), Vector3(e2 + 0.03, 0.03, c.z)))
		build.glow(gk, col)


func _lift_ring(b, c: Vector2, w0: float, w1: float) -> void:
	var r: float = 0.95
	var t: float = 0.06
	var col := Color(0.55, 0.85, 1.0)
	b.glow(Morph.standing(Vector3(c.x - r, 0.0, c.y - r), Vector3(c.x + r, 0.02, c.y - r + t), w0, w1), col)
	b.glow(Morph.standing(Vector3(c.x - r, 0.0, c.y + r - t), Vector3(c.x + r, 0.02, c.y + r), w0, w1), col)
	b.glow(Morph.standing(Vector3(c.x - r, 0.0, c.y - r), Vector3(c.x - r + t, 0.02, c.y + r), w0, w1), col)
	b.glow(Morph.standing(Vector3(c.x + r - t, 0.0, c.y - r), Vector3(c.x + r, 0.02, c.y + r), w0, w1), col)


func after_build() -> void:
	var wl: float = W_LO - 1.0
	var wh: float = W_HI + 1.0
	# The lesson in the start bay, on its west wall.
	sign_painted(Vector3(-3.78, 1.0, 5.4), Vector3(-3.74, 3.4, 10.6), wl, wh, Vector4(1, 0, 0, 0), Vector2i(1820, 840),
		lesson_paint("THE ANNEX  ·  2  THE STACKS", "THE SAME DOOR\nDOES NOT LEAD TO THE SAME ROOM",
			"Every doorway here is open at some W and walled at others.\nThe stripes over a doorway show where it opens:\namber kata, blue home, teal ana."))
	# In the hub, by the pillar's south face.
	sign_painted(Vector3(1.4, 1.0, 3.74), Vector3(3.6, 2.6, 3.78), wl, wh, Vector4(0, 0, -1, 0), Vector2i(1100, 800),
		lesson_paint("THE HUB", "THE PILLAR\nNEVER MOVES", "Everything else here does,\nas you shift."))
	# The reading room's notice (home only: the room is not there otherwise).
	sign_painted(Vector3(-10.6, 1.2, -11.78), Vector3(-5.4, 3.4, -11.74), K_HI, A_LO, Vector4(0, 0, 1, 0), Vector2i(1600, 680),
		lesson_paint("ARCHIVE  B7", "THE ARCHIVE IS LARGER\nEACH TIME WE MEASURE IT", "This room is only here at home."))
	# The computer room's terminal (kata): a log, and the hint.
	var log := func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.02, 0.04, 0.03))
		var f: Font = LabPrint.font("bold")
		var s: int = int(c.size.y * 0.06)
		var lines: Array = ["RESEARCH LOG  041", "", "We stopped mapping the stacks.", "The hub's doors never lead to the", "same rooms twice.", "",
			"North, kata, the floor gives way.", "Cross where the bridges meet.", "", "The Lens is in the far corner."]
		var y: float = c.size.y * 0.12
		for t in lines:
			c.draw_string(f, Vector2(c.size.x * 0.06, y), String(t), HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color(1.0, 0.72, 0.32))
			y += s * 1.35
	sign_painted(Vector3(-11.42, 0.82, -0.52), Vector3(-11.38, 1.56, 0.52), wl, K_HI - 0.15, Vector4(1, 0, 0, 0), Vector2i(900, 640), log, "glass", 0.9)
	# The gallery's notice (ana).
	sign_painted(Vector3(11.74, 1.2, -2.0), Vector3(11.78, 3.2, 2.0), A_LO, wh, Vector4(-1, 0, 0, 0), Vector2i(1400, 700),
		lesson_paint("GALLERY  ·  ANA", "ONLY OPEN ANA", "Shift back home and this room is shut.", Color(0.55, 1.0, 0.9)))
	# The lift panels.
	sign_painted(Vector3(-1.0, 1.0, 15.78), Vector3(1.0, 2.2, 15.74), wl, wh, Vector4(0, 0, -1, 0), Vector2i(1000, 600),
		lesson_paint("LIFT", "LEVEL 2\nTHE STACKS", "Ahead: the archive."))
	sign_painted(Vector3(7.0, 1.0, -15.78), Vector3(9.0, 2.2, -15.74), wl, wh, Vector4(0, 0, 1, 0), Vector2i(1000, 600),
		lesson_paint("LIFT", "LEVEL 3\nTHE HEART", "Stand in the square."))
	# The relics: one in the computer room (kata), one in the south-east bay (ana).
	add_relic("the log's key", Vector4(-8.2, 1.4, 1.5, -2.4), 0.7, Build.KATA.lerp(Color.WHITE, 0.3), "the computer room, kata of the archive")
	add_relic("the gallery glint", Vector4(8.0, 1.4, 8.0, 2.4), 0.7, Build.ANA.lerp(Color.WHITE, 0.3), "the south-east bay, ana")
	# The Lens: the Dream Shifter's crystal (a 24-cell), stretched through W so it is there at every W.
	_lens = MeshInstance4D.new()
	_lens.name = "Lens"
	var cell24: Mesh4D = load("res://models/primitives/platonic/24_cell/24_cell.g4b") as Mesh4D
	(_lens as MeshInstance4D).mesh = cell24
	(_lens as MeshInstance4D).material_override = Build.glow_material(Color(0.62, 0.86, 1.0), 1.0)
	_lens.position = Vector4(8.0, 1.75, -8.0, 0.0)
	_lens.scale = Vector4(0.42, 0.42, 0.42, 12.0)
	add_child(_lens)
	# The three sculptures on the east bench: one per band, at one place.
	var shapes: Array = [[OrthoplexTetraMesh4D.new(), Build.KATA, -2.4], [BoxTetraMesh4D.new(), Build.HOME, 0.0], [null, Build.ANA, 2.4]]
	for sp in shapes:
		var mi := MeshInstance4D.new()
		if sp[0] == null:
			mi.mesh = cell24
			mi.scale = Vector4(0.45, 0.45, 0.45, 0.8)
		else:
			(sp[0] as Object).set("size", Vector4(0.9, 0.9, 0.9, 1.4))
			mi.mesh = sp[0]
		mi.material_override = Build.glow_material(sp[1], 1.0)
		mi.position = Vector4(11.0, 1.55, -8.0, float(sp[2]))
		add_child(mi)
		_sculptures.append(mi)


func tick(player: Node4D, delta: float) -> void:
	super.tick(player, delta)
	tick_relics(player, delta)
	if is_instance_valid(_lens):
		_lens.basis = Basis4D.from_zx(_time * 0.6) * Basis4D.from_xy(_time * 0.25)
		_lens.scale = Vector4(0.42, 0.42, 0.42, 12.0)
		_lens.position = Vector4(8.0, 1.75 + sin(_time * 1.3) * 0.06, -8.0, 0.0)
	for i in _sculptures.size():
		var s: Node4D = _sculptures[i]
		var sc: Vector4 = s.scale
		s.basis = Basis4D.from_zx(_time * (0.4 + i * 0.15)) * Basis4D.from_yz(0.35)
		s.scale = sc
	if not lens_taken and game != null:
		var f: Vector4 = player.global_position
		if Vector2(f.x - 8.0, f.z + 8.0).length() < 1.7:
			lens_taken = true
			game.call("take_lens")


## The lift out only once you hold the Lens.
func lift_ready() -> bool:
	return lens_taken


## The Lens film: what you see from the north-east bay's south side, then the view turned into W
## sideways so the three sculptures stand side by side, then back.
func lens_film(player: Node4D) -> Array:
	var w: float = player.global_position.w
	var level_b: Projection = Basis4D.from_zx(0.0) * Basis4D.from_yz(-0.12)
	var turned: Projection = Basis4D.from_xw(PI * 0.5) * Basis4D.from_yz(-0.12)
	var eye := Vector4(11.0, 1.9, -4.4, w)
	return [
		{"eye": eye, "basis": level_b, "seconds": 2.6, "caption": "Three things share this bench. You can only ever see one of them."},
		{"eye": eye, "eye2": Vector4(11.0, 1.9, -4.4, 0.0), "basis": level_b, "basis2": turned, "seconds": 3.2, "caption": "Turn your view into W..."},
		{"eye": Vector4(11.0, 1.9, -4.4, 0.0), "basis": turned, "seconds": 3.6, "caption": "...and they stand side by side. So did every room you crossed."},
		{"eye": Vector4(11.0, 1.9, -4.4, 0.0), "eye2": eye, "basis": turned, "basis2": level_b, "seconds": 2.2, "caption": "The Lens lets you turn too."},
	]
