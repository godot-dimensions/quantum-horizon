extends "res://ramon/MazeRemake2/levels/mr2_level_4d.gd"
## LEVEL 3, THE HEART: the room you cannot walk to, only turn towards.
##
## A vast dark atrium with a giant 24-cell crystal hung in the middle: its cut changes as you shift
## through W and as it turns. The atrium's centre is an empty floor ringed in violet, and shifting ana
## there stops dead at W 1.75: something stands ana of you. Shift ana anywhere else and you see it, a
## blue box in the middle with no door on any side. The door is on the side that faces kata, the side
## you can only see once you turn your view into W (the Lens from level 2: right mouse, drag up; V
## finishes the turn). Turned at the centre, the vault stands ahead of you along W, with a cross-shaped
## doorway, sealed by a violet grid and two lights.
##
## THE TWO SEALS, which combine the first two levels:
##   kata   behind an amber door in the west wall (level 1's door, the other way)
##   ana    down a corridor of three gates, each open at one W, so you weave: teal, blue, teal
##          (level 2's passages, read from their stripes)
## With both lit, a short film shows the grid go. Turn at the centre, walk forward along W, into the
## Heart, where the Dreamer waits. Then the finale.
##
## On paper: PLAN.md section 4. The atrium is x -14..14, z -12..16; the vault's footprint x -4..4,
## z -2..6, from W 2 to 8; you arrive from the south facing -z.

const Dreamer := preload("res://ramon/MazeRemake2/carried/dreamer/cave_dreamer_4d.gd")
const Ground := preload("res://ramon/MazeRemake2/carried/ground_basis_4d.gd")

const W_LO := -3.5
const W_HI := 3.5
const V_LO := 2.0
const V_IN := 2.4
const V_HI := 8.0
const H := 12.0
const VH := 6.0
## The vault's footprint.
const FX := 4.0
const FZ0 := -2.0
const FZ1 := 6.0
const CZ := 2.0

var seals: Dictionary = {"kata": false, "ana": false}
var unsealed: bool = false
var finished: bool = false
var _seal_plate: Array[Node] = []
var _seal_lamps: Dictionary = {}
var _crystal: MeshInstance4D
var _dreamer: Node4D
var _blocked_said: bool = false
var _back_said: bool = false
var _turn_taught: bool = false


func _init() -> void:
	number = 3
	title = "THE HEART"
	dark_lift = 2.4
	w_min = W_LO
	w_max = V_HI
	bands = [[-2.4, Build.KATA, "KATA"], [0.0, Build.HOME, "HOME"], [2.4, Build.ANA, "ANA"], [5.0, Build.DEEP, "DEEP"]]
	spawn = Vector4(0, 0, 18.4, 0)
	spawn_yaw = 0.0
	checkpoints = [
		{"name": "the heart", "lo": Vector4(-FX, -1, FZ0, V_IN), "hi": Vector4(FX, 9, FZ1, V_HI), "at": Vector4(0, 0, CZ, 1.7), "yaw": 0.0},
		{"name": "west alcove", "lo": Vector4(-19.5, -1, -1.5, W_LO - 1), "hi": Vector4(-14.0, 9, 5.5, -0.2), "at": Vector4(-15.2, 0, CZ, -1.7), "yaw": PI * 0.5},
		{"name": "the weave", "lo": Vector4(14.0, -1, -1.5, W_LO - 1), "hi": Vector4(31.0, 9, 5.5, W_HI + 1), "at": Vector4(15.0, 0, CZ, 0.0), "yaw": -PI * 0.5},
		{"name": "atrium", "lo": Vector4(-14, -1, -12, W_LO - 1), "hi": Vector4(14, 13, 20, W_HI + 1), "at": Vector4(0, 0, 14.0, 0), "yaw": 0.0},
	]


func build_level() -> void:
	var b = build
	var wl: float = W_LO - 1.0
	var wh: float = W_HI + 1.0
	# FLOORS: the atrium; the vault's floor runs on ana; the arrival lift; the west alcove; the weave.
	b.floor_rect(-14.2, -12.2, 14.2, 16.2, wl, wh)
	b.floor_rect(-FX, FZ0, FX, FZ1, W_HI, V_HI + 0.5)
	b.floor_rect(-1.5, 16, 1.5, 20, wl, wh)
	b.floor_rect(-19.5, -1.5, -14, 5.5, wl, wh)
	b.floor_rect(14, 0.8, 26.2, 3.2, wl, wh)
	b.floor_rect(26, -1.5, 31, 5.5, wl, wh)
	# THE ENDS IN W: kata of everything; ana of everything but the vault, which runs on to W 8.
	b.cap(-20, -13, 32, 21, W_LO - 1.0, W_LO, H + 0.5, "slate_cap")
	b.cap(-20, -13, -FX - 0.2, 21, W_HI, V_HI + 1.0, H + 0.5, "slate_cap")
	b.cap(FX + 0.2, -13, 32, 21, W_HI, V_HI + 1.0, H + 0.5, "slate_cap")
	b.cap(-FX - 0.2, -13, FX + 0.2, FZ0 - 0.2, W_HI, V_HI + 1.0, H + 0.5, "slate_cap")
	b.cap(-FX - 0.2, FZ1 + 0.2, FX + 0.2, 21, W_HI, V_HI + 1.0, H + 0.5, "slate_cap")
	b.cap(-FX - 0.2, FZ0 - 0.2, FX + 0.2, FZ1 + 0.2, V_HI, V_HI + 1.0, H + 0.5, "slate_cap")

	# THE ATRIUM'S WALLS: dark slate, 12 m. The west wall has the amber door; the east wall the weave's
	# opening; the south wall the lift's.
	b.wall_x(-14.2, -1.0, 16.0, wl, wh, H, 0.4, 0.0, "slate")
	b.wall_x(1.0, 14.2, 16.0, wl, wh, H, 0.4, 0.0, "slate")
	b.box(Vector3(-1.0, 3.0, 15.8), Vector3(1.0, H, 16.2), wl, wh, "slate")
	b.wall_x(-14.2, 14.2, -12.0, wl, wh, H, 0.4, 0.0, "slate")
	b.wall_z(-12.2, 1.1, -14.0, wl, wh, H, 0.4, 0.0, "slate")
	b.wall_z(2.9, 16.2, -14.0, wl, wh, H, 0.4, 0.0, "slate")
	b.door({"name": "the amber door", "at": Vector2(-14.0, CZ), "along": "z", "closed_w": -0.4, "open_w": -1.4, "align_w": -1.7,
		"w_lo": wl, "w_hi": wh, "wall_h": H, "color": Build.KATA, "slot": "slate"})
	b.wall_z(-12.2, 1.0, 14.0, wl, wh, H, 0.4, 0.0, "slate")
	b.wall_z(3.0, 16.2, 14.0, wl, wh, H, 0.4, 0.0, "slate")
	b.box(Vector3(13.8, 3.6, 1.0), Vector3(14.2, H, 3.0), wl, wh, "slate")
	b.ceiling_rect(-14.2, -12.2, 14.2, 16.2, H, wl, wh)
	# Columns round the atrium, each with a light down its face.
	for cx in [-10.0, 10.0]:
		# Clear of the line from the centre to the west door and the weave (z -2.4 to 6.4).
		for cz in [-8.0, -3.0, 7.0, 12.0]:
			b.box(Vector3(cx - 0.6, 0.0, cz - 0.6), Vector3(cx + 0.6, H, cz + 0.6), wl, wh, "slate")
			var face: float = 0.61 if cx < 0.0 else -0.61
			b.glow(Morph.standing(Vector3(cx + face - 0.02, 0.4, cz - 0.05), Vector3(cx + face + 0.02, H - 0.4, cz + 0.05), wl, wh), Color(0.55, 0.62, 0.9))
	# The ring round the centre: where the vault stands, ana.
	var deep: Color = Build.DEEP
	for e in [[Vector3(-FX, 0.0, FZ0), Vector3(FX, 0.014, FZ0 + 0.08)], [Vector3(-FX, 0.0, FZ1 - 0.08), Vector3(FX, 0.014, FZ1)],
			[Vector3(-FX, 0.0, FZ0), Vector3(-FX + 0.08, 0.014, FZ1)], [Vector3(FX - 0.08, 0.0, FZ0), Vector3(FX, 0.014, FZ1)]]:
		b.glow(Morph.standing(e[0], e[1], wl, V_LO), deep)
	# A ring of light in the ceiling over the crystal.
	b.glow(Morph.standing(Vector3(-3.0, H - 0.05, CZ - 3.0), Vector3(3.0, H, CZ + 3.0), wl, wh), Color(0.62, 0.55, 1.0))

	# THE VAULT: blue walls and roof from W 2 to 8; its kata face (W 2 to 2.4) with a cross-shaped
	# doorway; its ana face at W 7.6 to 8.
	# The walls start 0.1 ana of the face: stopped at the face (your W half-width, 0.25, short of it) you
	# never touch them, so you can always walk out of the ring.
	var vw0: float = V_LO + 0.1
	b.box(Vector3(-FX - 0.2, 0.0, FZ0 - 0.2), Vector3(-FX + 0.2, VH, FZ1 + 0.2), vw0, V_HI, "blue")
	b.box(Vector3(FX - 0.2, 0.0, FZ0 - 0.2), Vector3(FX + 0.2, VH, FZ1 + 0.2), vw0, V_HI, "blue")
	b.box(Vector3(-FX - 0.2, 0.0, FZ0 - 0.2), Vector3(FX + 0.2, VH, FZ0 + 0.2), vw0, V_HI, "blue")
	b.box(Vector3(-FX - 0.2, 0.0, FZ1 - 0.2), Vector3(FX + 0.2, VH, FZ1 + 0.2), vw0, V_HI, "blue")
	b.box(Vector3(-FX - 0.2, VH, FZ0 - 0.2), Vector3(FX + 0.2, VH + 0.3, FZ1 + 0.2), vw0, V_HI, "blue")
	# The kata face: solid but for one square doorway at the centre, x -0.8..0.8, z 1.2..2.8, 2.8 high.
	# Only standing in that square (marked on the floor) does a turned view look through it.
	var hx: float = 0.8
	var hz0: float = CZ - 0.8
	var hz1: float = CZ + 0.8
	var hh: float = 2.8
	b.box(Vector3(-FX, hh, FZ0), Vector3(FX, VH, FZ1), V_LO, V_IN, "blue")
	b.box(Vector3(-FX, 0.0, FZ0), Vector3(-hx, hh, FZ1), V_LO, V_IN, "blue")
	b.box(Vector3(hx, 0.0, FZ0), Vector3(FX, hh, FZ1), V_LO, V_IN, "blue")
	b.box(Vector3(-hx, 0.0, FZ0), Vector3(hx, hh, hz0), V_LO, V_IN, "blue")
	b.box(Vector3(-hx, 0.0, hz1), Vector3(hx, hh, FZ1), V_LO, V_IN, "blue")
	b.box(Vector3(-FX, 0.0, FZ0), Vector3(FX, VH, FZ1), V_HI - 0.4, V_HI, "blue")
	# The doorway's frame: violet edges on the kata face, seen in a turned view.
	var fw0: float = V_LO - 0.03
	var fw1: float = V_LO + 0.01
	for e in [[Vector3(-hx - 0.07, 0.0, hz0 - 0.07), Vector3(-hx, hh + 0.07, hz1 + 0.07)], [Vector3(hx, 0.0, hz0 - 0.07), Vector3(hx + 0.07, hh + 0.07, hz1 + 0.07)],
			[Vector3(-hx - 0.07, 0.0, hz0 - 0.07), Vector3(hx + 0.07, hh + 0.07, hz0)], [Vector3(-hx - 0.07, 0.0, hz1), Vector3(hx + 0.07, hh + 0.07, hz1 + 0.07)],
			[Vector3(-hx - 0.07, hh, hz0 - 0.07), Vector3(hx + 0.07, hh + 0.07, hz1 + 0.07)]]:
		b.glow(Morph.standing(e[0], e[1], fw0, fw1), deep)
	# The square on the floor where a turned view looks through the doorway.
	for e in [[Vector3(-hx, 0.0, hz0), Vector3(hx, 0.016, hz0 + 0.06)], [Vector3(-hx, 0.0, hz1 - 0.06), Vector3(hx, 0.016, hz1)],
			[Vector3(-hx, 0.0, hz0), Vector3(-hx + 0.06, 0.016, hz1)], [Vector3(hx - 0.06, 0.0, hz0), Vector3(hx, 0.016, hz1)]]:
		b.glow(Morph.standing(e[0], e[1], wl, V_LO), deep.lerp(Color.WHITE, 0.35))
	# Inside: light from the ceiling.
	b.glow(Morph.standing(Vector3(-2.0, VH - 0.04, CZ - 2.0), Vector3(2.0, VH, CZ + 2.0), V_IN, V_HI - 0.4), Color(0.75, 0.7, 1.0))

	# THE WEST ALCOVE (kata of -0.2): seal one.
	b.wall_z(-1.7, 5.7, -19.5, wl, -0.2, 4.0, 0.4, 0.0, "slate")
	b.wall_x(-19.7, -14.0, -1.5, wl, -0.2, 4.0, 0.4, 0.0, "slate")
	b.wall_x(-19.7, -14.0, 5.5, wl, -0.2, 4.0, 0.4, 0.0, "slate")
	b.ceiling_rect(-19.7, -1.7, -14.0, 5.7, 4.0, wl, -0.2)
	b.cap(-19.7, -1.7, -14.2, 5.7, -0.2, wh, 4.2, "slate_cap")
	b.box(Vector3(-18.2, 0.0, CZ - 0.5), Vector3(-17.2, 0.9, CZ + 0.5), wl, -0.2, "metal")

	# THE WEAVE (east): a corridor of three gates, each open at one W; then seal two.
	b.wall_x(14.0, 26.2, 0.8, wl, wh, 3.6, 0.4, 0.0, "slate")
	b.wall_x(14.0, 26.2, 3.2, wl, wh, 3.6, 0.4, 0.0, "slate")
	b.ceiling_rect(14.0, 0.6, 26.2, 3.4, 3.6, wl, wh)
	var A: Array = [1.25, W_HI, Build.ANA]
	var Hm: Array = [-1.25, 1.25, Build.HOME]
	for g in [[17.0, [A]], [21.0, [Hm]], [24.6, [A]]]:
		b.passage({"name": "a gate", "at": Vector2(float(g[0]), CZ), "along": "z", "width": 2.0, "height": 3.0, "wall_h": 3.6, "open": g[1], "w_lo": W_LO, "w_hi": W_HI, "slot": "slate"})
	for gx in [15.4, 19.0, 22.8]:
		b.glow(Morph.standing(Vector3(gx - 0.6, 3.56, CZ - 0.06), Vector3(gx + 0.6, 3.6, CZ + 0.06), wl, wh), Color(0.85, 0.9, 1.0))
	b.wall_z(-1.7, 0.8, 26.0, wl, wh, 4.0, 0.4, 0.0, "slate")
	b.wall_z(3.2, 5.7, 26.0, wl, wh, 4.0, 0.4, 0.0, "slate")
	b.wall_z(-1.7, 5.7, 31.0, wl, wh, 4.0, 0.4, 0.0, "slate")
	b.wall_x(26.0, 31.2, -1.5, wl, wh, 4.0, 0.4, 0.0, "slate")
	b.wall_x(26.0, 31.2, 5.5, wl, wh, 4.0, 0.4, 0.0, "slate")
	b.ceiling_rect(25.8, -1.7, 31.2, 5.7, 4.0, wl, wh)
	b.box(Vector3(28.0, 0.0, CZ - 0.5), Vector3(29.0, 0.9, CZ + 0.5), wl, wh, "metal")

	# THE ARRIVAL LIFT.
	b.wall_z(16.0, 20.2, -1.5, wl, wh, 3.0, 0.4, 0.0, "slate")
	b.wall_z(16.0, 20.2, 1.5, wl, wh, 3.0, 0.4, 0.0, "slate")
	b.wall_x(-1.7, 1.7, 20.0, wl, wh, 3.0, 0.4, 0.0, "slate")
	b.ceiling_rect(-1.7, 16.0, 1.7, 20.2, 3.0, wl, wh)


func after_build() -> void:
	var wl: float = W_LO - 1.0
	var wh: float = W_HI + 1.0
	# The arrival's lesson, on the south wall to the right of the lift's opening.
	sign_painted(Vector3(2.0, 1.2, 15.76), Vector3(8.0, 4.0, 15.8), wl, wh, Vector4(0, 0, -1, 0), Vector2i(1800, 840),
		lesson_paint("THE ANNEX  ·  3  THE HEART", "IT IS HERE.\nNOT LEFT. NOT RIGHT. ANA.",
			"Two lights unseal it: one kata, one ana.\nTo see it, stand in the small square at the centre\nand turn your view into W (right mouse, drag up).", Color(0.78, 0.66, 1.0)))
	# The weave's sign at its mouth, on the atrium side of the east wall.
	sign_painted(Vector3(13.76, 1.0, 3.4), Vector3(13.8, 3.2, 7.4), wl, wh, Vector4(-1, 0, 0, 0), Vector2i(1300, 720),
		lesson_paint("THE WEAVE", "EACH GATE OPENS\nAT ONE W", "Read the stripes over each gate.\nShift between them as you go.", Color(0.55, 1.0, 0.9)))
	# On the vault's kata face, beside the doorway: what you see once turned.
	sign_painted(Vector3(1.3, 0.9, FZ0), Vector3(3.7, 2.7, FZ1), V_LO - 0.05, V_LO - 0.01, Vector4(0, 0, 0, -1), Vector2i(1200, 900),
		lesson_paint("THE HEART", "TWO LIGHTS\nSEAL IT", "One kata, one ana.\nThen walk in along W.", Color(0.78, 0.66, 1.0)))
	# The seal plate in the doorway: a violet grid, until both lights are lit.
	for part in [[Vector3(-0.8, 0.0, CZ - 0.8), Vector3(0.8, 2.8, CZ + 0.8)]]:
		var lo: Vector3 = part[0]
		var hi: Vector3 = part[1]
		var size := Vector4(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, 0.2)
		var centre := Vector4((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, (lo.z + hi.z) * 0.5, V_LO + 0.1)
		var mi := MeshInstance4D.new()
		var bm := BoxTetraMesh4D.new()
		bm.size = size
		mi.mesh = bm
		mi.position = centre
		mi.material_override = Build.glow_material(Color(0.24, 0.13, 0.48), 1.0)
		add_child(mi)
		var body := StaticBody4D.new()
		body.position = centre
		var cs := CollisionShape4D.new()
		var shape := BoxShape4D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
		_seal_plate.append(mi)
		_seal_plate.append(body)
	# The two seal lights: an amber one in the west alcove (kata), a teal one past the weave.
	_seal_lamps["kata"] = _lamp(Vector4(-17.7, 1.45, CZ, -1.9), Build.KATA, 1.4)
	_seal_lamps["ana"] = _lamp(Vector4(28.5, 1.45, CZ, 0.0), Build.ANA, 12.0)
	# The crystal over the centre: a giant 24-cell, turning, its cut changing as you shift.
	_crystal = MeshInstance4D.new()
	_crystal.name = "Crystal"
	_crystal.mesh = load("res://models/primitives/platonic/24_cell/24_cell.g4b") as Mesh4D
	_crystal.material_override = Build.glow_material(Color(0.62, 0.55, 1.0), 1.0)
	_crystal.position = Vector4(0, 8.6, CZ, 0.0)
	_crystal.scale = Vector4(2.3, 2.3, 2.3, 2.3)
	add_child(_crystal)
	# The Dreamer, in the Heart.
	_dreamer = Node4D.new()
	_dreamer.name = "Dreamer"
	_dreamer.set_script(Dreamer)
	_dreamer.position = Vector4(0, 0.0, CZ, 5.2)
	_dreamer.set("creature_scale", 0.36)
	_dreamer.set("core_height", 3.2)
	_dreamer.set("room_radii", Vector4(3.5, 2.7, 3.5, 2.2))
	_dreamer.set("limb_count", 16)
	_dreamer.set("dust_count", 24)
	_dreamer.set("too_close", 1.2)
	# It faces your slice: the player's body holds the slice's frame (no camera rig here).
	_dreamer.set("player_path", NodePath("../../Player"))
	_dreamer.set("camera_rig_path", NodePath("../../Player"))
	add_child(_dreamer)


## A seal light: an orb (a 16-cell) on its plinth, dim until lit. `wr` is its W half-extent.
func _lamp(at: Vector4, col: Color, wr: float) -> MeshInstance4D:
	var mi := MeshInstance4D.new()
	var m := OrthoplexTetraMesh4D.new()
	m.size = Vector4(0.7, 0.7, 0.7, wr * 2.0)
	mi.mesh = m
	mi.material_override = Build.glow_material(col.darkened(0.55), 1.0)
	mi.position = at
	mi.set_meta("colour", col)
	add_child(mi)
	return mi


func tick(player: Node4D, delta: float) -> void:
	super.tick(player, delta)
	if is_instance_valid(_crystal):
		_crystal.basis = Basis4D.from_xw(_time * 0.11) * Basis4D.from_zx(_time * 0.07) * Basis4D.from_yz(0.3)
		_crystal.scale = Vector4(2.3, 2.3, 2.3, 2.3)
	for k in _seal_lamps:
		var lamp: MeshInstance4D = _seal_lamps[k]
		lamp.basis = Basis4D.from_zx(_time * (0.8 if bool(seals[k]) else 0.3))
		var at: Vector4 = lamp.position
		var f: Vector4 = player.global_position
		if not bool(seals[k]) and Vector2(f.x - at.x, f.z - at.z).length() < 1.5 and absf(f.w - at.w) < float((lamp.mesh as OrthoplexTetraMesh4D).size.w) * 0.5:
			seals[k] = true
			lamp.material_override = Build.glow_material(lamp.get_meta("colour"), 1.0)
			if game != null:
				game.call("seal_lit", k, seals.values().count(true))
			if seals["kata"] and seals["ana"]:
				_unseal()
	# Shifting ana at the centre stops dead: say what it is, once.
	if game != null and not _blocked_said and _in_footprint(player.global_position) and bool(player.get("w_blocked")) and player.global_position.w > 1.0:
		_blocked_said = true
		game.call("blocked_by_vault")
	# Turned right up against the vault's face: say how to see it.
	if game != null and not _back_said and _in_footprint(player.global_position) and float(player.call("tilt")) > 1.4 and player.global_position.w > 1.2 and not unsealed:
		_back_said = true
		game.call("hint", "STEP BACK (S) TO SEE IT WHOLE")
	# Into the Heart: the finale.
	if not finished and _in_footprint(player.global_position) and player.global_position.w > V_IN + 0.5:
		finished = true
		if game != null:
			game.call("reach_heart")


func _in_footprint(p: Vector4) -> bool:
	return p.x > -FX + 0.2 and p.x < FX - 0.2 and p.z > FZ0 + 0.2 and p.z < FZ1 - 0.2


func _unseal() -> void:
	unsealed = true
	for n in _seal_plate:
		if is_instance_valid(n):
			n.queue_free()
	_seal_plate.clear()


## What V finishes here once you hold the Lens: the turn into W, at the centre, facing along an axis.
## Offered from about 70 per cent of the quarter turn; the frame it lands on has your heading snapped
## to the nearest quarter and ahead exactly ana, so the vault's doorway stands square in front of you.
func extra_target(player: Node4D) -> Dictionary:
	if not bool(player.get("turn_enabled")):
		return {}
	var p: Vector4 = player.global_position
	if not _in_footprint(p) or p.w > V_LO:
		return {}
	var g: Projection = player.get("ground")
	var t: float = Ground.tilt(g)
	if t < 0.05:
		return {}
	var yaw: float = snappedf(Ground.heading(g), PI * 0.5)
	var best: Projection = g
	var best_fw: float = -INF
	for sgn in [-1.0, 1.0]:
		var f: Projection = Basis4D.from_zx(yaw) * Basis4D.from_zw(sgn * PI * 0.5)
		var fwd: Vector4 = -f.z
		if fwd.w > best_fw:
			best_fw = fwd.w
			best = f
	var share: float = clampf(t / (PI * 0.5), 0.0, 1.0)
	var rec := {"kind": "turn", "name": "the turn", "open": share, "offered": share >= 0.62 and share < 0.985,
		"color": Build.DEEP, "frame": best, "label": "TURNED", "verb": "TURN"}
	# Stopped right at the vault's face, V also steps you back along W, so it stands whole ahead of you.
	if p.w > -0.8:
		rec["w"] = -0.8
	return rec
