extends Node4D

## WATER LAB: the crab's body, LOFTED IN 4D (round 5: every animal a true 4D loft; until 9 Oct a 3D
## mesh that life/crab.gdshader shrank off the slice and stepped on the GPU). Lofted once by our loft
## builder, baked under life/baked/, its parts rigid pieces on jointed holders: the carapace, the eyes,
## eight legs of two pieces each (the thigh from the hip, the shank from the knee), two claws (the arm
## and hand from the shoulder, the finger from its hinge). The tank's crab (life/crab_4d.gd), the
## showcase and the fish wall pose it.
##
## THE SHAPE is the old crab's, in units of its carapace's width: the carapace an ellipsoid fuller above
## than below, as deep through W as it is from front to back (a 4D crab is round across the floor's two
## directions it does not face along, z and W); the legs and claws tubes, round in all three directions
## across them, so a turned slice cuts the legs away long before the shell.
##
## THE WALK is the old shader's (crab.gdshader): two sets of four legs stepping in turn, on each side
## legs 1 and 3 with 2 and 4 of the other side; a stepping leg lifts at its hip, swings fore and aft,
## and its knee flexes as it reaches; the body bobs with each step; the claws lower to the sand to
## pick and come back, the finger opening and shutting.
##
## Modelled +Z ahead (its face), +X its right, +Y up. NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/WaterLab/carried/chickenpen/scripts/loft_builder_4d.gd")
const Kit := preload("res://ramon/WaterLab/life/loft_kit.gd")
const BAKED := "res://ramon/WaterLab/life/baked/"
const BAKE_VERSION := "v1"
## The carapace: its middle, its half extents above (x, y, z) and its half height below.
const SHELL_C := Vector3(0.0, 0.18, 0.0)
const SHELL_UP := Vector3(0.5, 0.15, 0.38)
const SHELL_DOWN := 0.06
## The texture's rows: shell, eye, claw, finger, thigh, shank.
const ROWS := 6

@export_range(1, 2) var detail: int = 1

var body: Node4D
var material: TetraMaterial4D
var tets: int = 0
var meshes: int = 0
## [{"thigh": Node4D, "shank": Node4D, "slot": int, "side": float}], the eight legs.
var _legs: Array = []
## [{"arm": Node4D, "finger": Node4D, "side": float}], the two claws.
var _claws: Array = []


func _ready() -> void:
	if body == null:
		build()


static func hip(side: float, i: int) -> Vector3:
	return Vector3(side * 0.42, 0.16, 0.14 - 0.13 * float(i))


static func knee(side: float, i: int) -> Vector3:
	return hip(side, i) + Vector3(side * 0.30, 0.12, -0.05 * float(i) + 0.03)


static func foot(side: float, i: int) -> Vector3:
	return knee(side, i) + Vector3(side * 0.16, -0.30, -0.05 * float(i))


static func shoulder(side: float) -> Vector3:
	return Vector3(side * 0.30, 0.14, 0.30)


static func hinge(side: float) -> Vector3:
	return Vector3(side * 0.16, 0.13, 0.64)


func build() -> void:
	material = skin()
	body = Node4D.new()
	body.name = "Body"
	add_child(body)
	_add(body, "Shell", _cached("crab_shell", _shell))
	_add(body, "Eyes", _cached("crab_eyes", _eyes))
	for side in [1.0, -1.0]:
		var sk: String = "r" if side > 0.0 else "l"
		for i in 4:
			var thigh := Node4D.new()
			thigh.name = "Thigh%s%d" % [sk.to_upper(), i]
			var h: Vector3 = hip(side, i)
			thigh.position = Vector4(h.x, h.y, h.z, 0.0)
			body.add_child(thigh)
			var shank := Node4D.new()
			shank.name = "Shank"
			var k: Vector3 = knee(side, i) - h
			shank.position = Vector4(k.x, k.y, k.z, 0.0)
			thigh.add_child(shank)
			# Each tube built from its own joint (the holder's origin).
			_add(thigh, "Tube", _cached("crab_thigh_%s%d" % [sk, i], func() -> ArrayTetraMesh4D: return _tube(Vector3.ZERO, knee(side, i) - hip(side, i), 0.045, 0.035, 4)))
			_add(shank, "Tube", _cached("crab_shank_%s%d" % [sk, i], func() -> ArrayTetraMesh4D: return _tube(Vector3.ZERO, foot(side, i) - knee(side, i), 0.032, 0.01, 5)))
			_legs.append({"thigh": thigh, "shank": shank, "slot": i, "side": side})
		var arm := Node4D.new()
		arm.name = "Claw" + sk.to_upper()
		var s: Vector3 = shoulder(side)
		arm.position = Vector4(s.x, s.y, s.z, 0.0)
		body.add_child(arm)
		var finger := Node4D.new()
		finger.name = "Finger"
		var hg: Vector3 = hinge(side) - s
		finger.position = Vector4(hg.x, hg.y, hg.z, 0.0)
		arm.add_child(finger)
		_add(arm, "Hand", _cached("crab_claw_" + sk, func() -> ArrayTetraMesh4D: return _claw(side)))
		_add(finger, "Finger", _cached("crab_finger_" + sk, func() -> ArrayTetraMesh4D:
			return _tube(Vector3.ZERO, Vector3(side * 0.03, 0.115, 0.67) - hinge(side), 0.028, 0.008, 3)))
		_claws.append({"arm": arm, "finger": finger, "side": side})
	pose(Vector4.ZERO, Projection.IDENTITY, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0)


# -- the walk --------------------------------------------------------------------------------------------------

## Places it: `p` and `frame` (right, up, ahead, ana) in its owner's space, `size` its width in metres;
## the gait's `phase`, how hard it walks (`walk`, 0 still), the claws' `reach` (0 folded, 1 down to the
## sand), the pincers (`pinch`, 0 shut, 1 open), `t` the clock.
func pose(p: Vector4, frame: Projection, size: float, phase: float, walk: float, reach: float, pinch: float, t: float) -> void:
	if body == null:
		return
	# The body bobs with the steps.
	body.position = p + frame.y * (0.02 * walk * sin(phase * 2.0) * size)
	body.basis = Projection(frame.x * size, frame.y * size, frame.z * size, frame.w * size)
	for leg in _legs:
		var side: float = leg["side"]
		var set_: float = fmod(float(leg["slot"]) + (1.0 if side > 0.0 else 0.0), 2.0)
		var ph: float = phase + set_ * PI
		var lift: float = maxf(sin(ph), 0.0) * 0.45 * walk
		var sweep: float = cos(ph) * 0.22 * walk
		var flex: float = (0.25 + 0.35 * maxf(sin(ph), 0.0)) * walk
		(leg["thigh"] as Node4D).basis = Kit.rot_y(sweep) * Kit.rot_z(side * lift)
		(leg["shank"] as Node4D).basis = Kit.rot_z(-side * flex)
	for claw in _claws:
		var side: float = claw["side"]
		var down: float = reach * (0.55 + 0.25 * sin(t * 3.0 + side))
		(claw["arm"] as Node4D).basis = Kit.rot_x(down)
		(claw["finger"] as Node4D).basis = Kit.rot_y(side * 0.5 * pinch)


# -- its shape (lofted once, baked) ----------------------------------------------------------------------------

## The carapace: lofted across x, each section a ball as deep (z) as the shell there and as deep
## through W, its top fuller than its bottom (the section's middle raised, its height scaled).
func _shell() -> ArrayTetraMesh4D:
	var n: int = 9 if detail < 2 else 13
	var r: Vector2i = Vector2i(5, 14) if detail < 2 else Vector2i(7, 20)
	var sections: Array = []
	var hh: float = (SHELL_UP.y + SHELL_DOWN) * 0.5
	var cy: float = SHELL_C.y + (SHELL_UP.y - SHELL_DOWN) * 0.5
	for k in n:
		var u: float = lerpf(-0.94, 0.94, float(k) / float(n - 1))
		var f: float = sqrt(maxf(1.0 - u * u, 0.0))
		var rz: float = SHELL_UP.z * f
		sections.append({"center": Vector4(u * SHELL_UP.x, cy, 0.0, 0.0), "radius": rz, "v_scale": 1.0, "w_scale": 1.0,
			"basis": Kit.scale(1.0, hh / SHELL_UP.z, 1.0, 1.0), "color": Color.WHITE})
	var m: ArrayTetraMesh4D = Loft.build(sections, r.x, r.y, true, false, true, 1, false)
	Kit.paint(m, func(q: Vector4) -> Vector3:
		var rim: float = clampf(Vector3(q.x / SHELL_UP.x, q.z / SHELL_UP.z, q.w / SHELL_UP.z).length(), 0.0, 1.0)
		var under: float = clampf((cy - q.y) / hh, 0.0, 1.0)
		return _coord(rim, 0, under))
	return m


func _eyes() -> ArrayTetraMesh4D:
	var parts: Array = []
	for side in [1.0, -1.0]:
		var c := Vector3(side * 0.1, 0.31, 0.35)
		var sections: Array = []
		for k in 4:
			var t: float = lerpf(-0.8, 0.8, float(k) / 3.0)
			sections.append({"center": Vector4(c.x, c.y + t * 0.035, c.z, 0.0), "radius": 0.035 * sqrt(1.0 - t * t), "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
		parts.append(Loft.build(sections, 3, 8, true, false, true, 0, false))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	Kit.paint(m, func(_q: Vector4) -> Vector3: return _coord(0.5, 1, 0.5))
	return m


## A tapering tube from `a` to `b` (radii r0, r1), round across it in all three directions. `row` its
## colour: 4 a thigh, 5 a shank, 3 a finger.
func _tube(a: Vector3, b: Vector3, r0: float, r1: float, row: int) -> ArrayTetraMesh4D:
	var sections: Array = []
	var n: int = 4
	for k in n:
		var t: float = float(k) / float(n - 1)
		var c: Vector3 = a.lerp(b, t * 0.94)
		sections.append({"center": Vector4(c.x, c.y, c.z, 0.0), "radius": lerpf(r0, r1, t), "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
	var m: ArrayTetraMesh4D = Loft.build(sections, 3, 8, true, false, true, 1, false)
	Kit.paint(m, func(q: Vector4) -> Vector3:
		var along: float = clampf((Vector3(q.x, q.y, q.z) - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
		return _coord(along, row, 0.5))
	return m


## The claw, in the shoulder's frame: the arm forward to the wrist, the hand across the face (an
## ellipsoid lofted along x), black toward its tip.
func _claw(side: float) -> ArrayTetraMesh4D:
	var s: Vector3 = shoulder(side)
	var parts: Array = []
	var wrist := Vector3(side * 0.42, 0.13, 0.52)
	var arm: Array = []
	for k in 4:
		var t: float = float(k) / 3.0
		var c: Vector3 = s.lerp(wrist, t) - s
		arm.append({"center": Vector4(c.x, c.y, c.z, 0.0), "radius": lerpf(0.055, 0.05, t), "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
	parts.append(Loft.build(arm, 3, 8, true, false, true, 1, false))
	var hc := Vector3(side * 0.27, 0.11, 0.61) - s
	var hand: Array = []
	for k in 7:
		var u: float = lerpf(-0.92, 0.92, float(k) / 6.0)
		var f: float = sqrt(maxf(1.0 - u * u, 0.0))
		hand.append({"center": Vector4(hc.x + u * 0.15, hc.y, hc.z, 0.0), "radius": 0.09 * f, "v_scale": 1.0, "w_scale": 1.0,
			"basis": Kit.scale(1.0, 0.075 / 0.09, 1.0, 0.075 / 0.09), "color": Color.WHITE})
	parts.append(Loft.build(hand, 4, 10, true, false, true, 1, false))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	Kit.paint(m, func(q: Vector4) -> Vector3:
		var z: float = q.z + s.z
		return _coord(clampf((z - 0.42) / 0.16, 0.0, 1.0), 2, 0.5))
	return m


## Texture coordinates on texel centres: x a measure along the row (16 texels), y the row, z the third.
static func _coord(x: float, row: int, z: float) -> Vector3:
	return Vector3((0.5 + clampf(x, 0.0, 1.0) * 15.0) / 16.0, (float(row) + 0.5) / float(ROWS), (0.5 + clampf(z, 0.0, 1.0) * 7.0) / 8.0)


## A brown crab's colours (crab.gdshader): a brick-red shell, darker at its rim and pale beneath, a
## faint mottle; black eyes; the claws the shell's red going black at the tips, the fingers black; the
## thighs a paler red, the shanks paler still.
static func skin() -> TetraMaterial4D:
	var shell := Color(0.55, 0.24, 0.12)
	var noise := FastNoiseLite.new()
	noise.seed = 3388
	noise.frequency = 0.4
	var slices: Array = []
	for zi in 8:
		var z: float = float(zi) / 7.0
		var img: Image = Image.create(16, ROWS, false, Image.FORMAT_RGBA8)
		for i in 16:
			var x: float = float(i) / 15.0
			var c: Color = (shell * 1.15).lerp(shell * 0.75, smoothstep(0.6, 1.0, x))
			c = c.lerp(Color(0.86, 0.74, 0.6), smoothstep(0.35, 0.8, z))
			c = c * (0.92 + 0.1 * (0.5 + 0.5 * noise.get_noise_2d(float(i) * 2.0, float(zi) * 3.0)))
			img.set_pixel(i, 0, c)
			img.set_pixel(i, 1, Color(0.02, 0.02, 0.02))
			img.set_pixel(i, 2, (shell * 0.9).lerp(Color(0.05, 0.05, 0.05), smoothstep(0.5, 0.85, x)))
			img.set_pixel(i, 3, Color(0.05, 0.05, 0.05))
			img.set_pixel(i, 4, Color(0.70, 0.40, 0.24))
			img.set_pixel(i, 5, Color(0.85, 0.62, 0.45))
		slices.append(img)
	return Kit.tex_material(slices)


# -- meshes ----------------------------------------------------------------------------------------------------

func _add(holder: Node, nm: String, mesh: ArrayTetraMesh4D) -> void:
	if mesh == null:
		return
	tets += Kit.add_mesh(holder, nm, mesh, material)
	meshes += 1


func _cached(key: String, build_fn: Callable) -> ArrayTetraMesh4D:
	return Kit.cached(BAKED + "%s_d%d_%s.res" % [key, detail, BAKE_VERSION], build_fn)
