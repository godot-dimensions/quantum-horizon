extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## FLYING CHICKEN (Ramon, 5 Oct: "would be fun to shoot some flying chickens too ... we already have the
## model"): the pen's chicken, a carried copy baked into rigid pieces (range_shapes.gd chicken()), flown on
## a skeet arc by whoever launched it (its `path`). The whole bird is the target: one quick shot, and it
## bursts into feathers and tumbles out of the air.
##
## HOW IT FLIES (6 Oct, "more natural"), after how a startled chicken actually gets airborne:
##   - Its wings SPREAD. The model's wing is the folded one, lying back along the body; flapping that one
##     only rolled it round its own length. SPREAD turns it out sideways and flat, about the shoulder,
##     a little longer and broader (WING_SCALE).
##   - The beat is quick and uneven: a hard downstroke in under half the beat, then a slower upstroke
##     with the wing half folded back in, as birds do to spare the drag. About 4.6 beats a second, each
##     bird its own rate and phase, so a pair never flaps in step; faster still as it bursts off the trap.
##   - The body heaves up with each downstroke, flies nose-up while it climbs (chickens claw their way up
##     at a steep angle), levels at the top, and wobbles a little in roll: it is not a good flier.
##   - The head stays level: the neck takes back most of the body's pitch, roll and heave, the way birds
##     hold their heads still, and reaches forward.
##   - The legs tuck back from the hips, nearly level, swinging a little with each beat.
##   - Coming down it beats less and glides on held wings.
##   - Shot, it keeps its way and falls, knocked up and tumbling, wings and legs loose, for a moment
##     before it goes; the feathers burst where the shot hit.
##
## THE OTHER WING. The bird is lofted with one wing, on its left. The right one is the same mesh turned
## half a turn in the x/w plane, which sends x to -x and w to -w: for a shape that is the same either side
## of its middle slice through W, as a lofted wing is, that is exactly its mirror image, with no negative
## scale to turn its faces inside out.

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

## The folded wing turned out to spread (chicken space: +X its left, +Y up, +Z ahead): its length, which
## lies back along the body (-Z), out sideways (+X); its outer face (+X) up (+Y); so +Y goes to -Z.
const SPREAD := Projection(Vector4(0, 1, 0, 0), Vector4(0, 0, -1, 0), Vector4(-1, 0, 0, 0), Vector4(0, 0, 0, 1))
## Where things turn, in the model's own space (chicken.tscn): the shoulder, the base of the neck, the
## left hip (the right is its mirror), and the bird's middle (range_shapes.gd).
const SHOULDER := Vector4(0.33, 1.0, 0.08, 0.0)
const NECK := Vector4(0.0, 1.0, 0.42, 0.0)
const HIP := Vector4(0.15, 0.72, 0.06, 0.0)
const MID := Vector4(0.0, 1.05, -0.2, 0.0)
## The share of a beat that is the downstroke.
const DOWN := 0.42
## The wing a little longer and broader than the folded one it is made from (a spread chicken wing is
## big for the bird: folded, this one read as a stub from above): its thickness, its chord, its span, in
## the model's own axes before SPREAD (x, y, z).
const WING_SCALE := Vector3(1.0, 1.35, 1.6)
const G := -9.8

## How big a bird (range_shapes.gd CHICKEN_SCALE, its default, is the skeet's big comic bird; the wolf's
## quarry is a real chicken's size beside it).
var size: float = Shapes.CHICKEN_SCALE
## Not to be shot (the wolf's quarry): its body is a friend, a hit is a penalty.
var friendly: bool = false
## On the ground, legging it: its legs run, its wings half open and beating, its body pitched forward.
var running: bool = false
## In a wolf's jaws: the wolf places it; it only struggles, wings beating hard, legs kicking.
var held: bool = false

var _wings: Array = []      # [pivot, side]
var _legs: Array = []       # [pivot, side]
var _neck: Node4D
var _neck_rest: Vector4 = Vector4.ZERO
var _body: Node4D
var _last: Vector4 = Vector4.INF
var _v: Vector4 = Vector4.ZERO
var _rate: float = 4.6
var _phase: float = 0.0
var _seed: float = 0.0
var _cycle: float = 0.0
var _yaw: float = 0.0
var _fall: float = -1.0
var _spin: Vector2 = Vector2.ZERO


func build() -> void:
	family = "chicken"
	_rate = randf_range(4.2, 5.0)
	_phase = randf()
	_seed = randf() * 10.0
	var s: float = size
	var re: float = size / Shapes.CHICKEN_SCALE
	# The hitbox: the bird, wings folded; the body is the part, everything else hangs off it.
	var k: float = s / 0.5
	var core: Dictionary = add_part("Bird", "friend" if friendly else "core", null, Vector4(0.55, 0.7, 0.85, 0.45) * k, {"radar": true})
	_body = core["node"]
	var hips: Dictionary = {}
	for piece in Shapes.chicken(get_tree()):
		var nm: String = piece[0]
		var mesh: Mesh4D = piece[1]
		var mat: Material4D = piece[2]
		var pos: Vector4 = (piece[3] as Vector4) * re
		var opts: Dictionary = {"basis": Basis4D.from_scale_uniform(s), "material": mat, "radar": false}
		if bool(piece[4]):
			# A wing on its shoulder, twice: the second turned through x/w (see above). Scaled about the
			# shoulder, which stays on its pivot.
			var ws := Vector4(WING_SCALE.x, WING_SCALE.y, WING_SCALE.z, 1.0) * s
			opts["basis"] = Basis4D.from_scale(ws)
			for side in [1.0, -1.0]:
				var pivot := _pivot("Shoulder" + ("L" if side > 0.0 else "R"), Vector4(SHOULDER.x * side, SHOULDER.y, SHOULDER.z, 0.0), s)
				opts["parent"] = pivot
				var p: Dictionary = add_part("Wing" + ("L" if side > 0.0 else "R"), "cover", mesh, Vector4.ZERO, opts.duplicate())
				(p["mesh"] as MeshInstance4D).position = Vector4(-SHOULDER.x * ws.x, -SHOULDER.y * ws.y, -SHOULDER.z * ws.z, 0.0)
				_wings.append([pivot, side])
			continue
		var parent: Node4D = _body
		if nm == "NeckHead":
			_neck = _pivot("Neck", NECK, s)
			_neck_rest = _neck.position
			parent = _neck
		elif nm.begins_with("Leg") or nm.begins_with("Foot"):
			var side2: float = 1.0 if nm.ends_with("L") else -1.0
			if not hips.has(side2):
				hips[side2] = _pivot("Hip" + ("L" if side2 > 0.0 else "R"), Vector4(HIP.x * side2, HIP.y, HIP.z, 0.0), s)
				_legs.append([hips[side2], side2])
			parent = hips[side2]
		opts["parent"] = parent
		var d: Dictionary = add_part(nm, "cover", mesh, Vector4.ZERO, opts)
		(d["mesh"] as MeshInstance4D).position = pos - (parent.position if parent != _body else Vector4.ZERO)


## A joint on the body at model point `at`.
func _pivot(nm: String, at: Vector4, s: float) -> Node4D:
	var p := Node4D.new()
	p.name = nm
	p.position = (at - MID) * s
	_body.add_child(p)
	return p


func on_hit(p: Dictionary, outcome: String) -> void:
	if outcome == "pop":
		Fx.burst(get_parent(), (p["node"] as Node4D).global_position, Color(0.97, 0.95, 0.90), 22, 0.07, 3.2)


## Shot: it does not vanish where it was hit. It keeps its way, knocked up and spinning, and falls for a
## moment before it goes (the base dissolves it when _fall runs out, below).
func destroy() -> void:
	if not alive:
		return
	alive = false
	destroyed.emit(self)
	# The body is the shot part, and every piece hangs off it: the base would shrink it away and hide it
	# (with the whole bird) in a fifth of a second. Its hitbox is already gone; it stays to fall.
	var core: Dictionary = part("Bird")
	if not core.is_empty():
		core["dying"] = -1.0
	_fall = 0.0
	_v += Vector4(0.0, 1.6, 0.0, 0.0)
	_spin = Vector2(randf_range(6.0, 10.0) * (1.0 if randf() < 0.5 else -1.0), randf_range(-7.0, 7.0))


## Turns between two bases by `k` (0 a, 1 b), kept a rotation.
static func _blend(a: Projection, b: Projection, k: float) -> Projection:
	var m := Projection(a.x.lerp(b.x, k), a.y.lerp(b.y, k), a.z.lerp(b.z, k), a.w.lerp(b.w, k))
	return Basis4D.orthonormalized(m)


func _wing(e: float, fold: float) -> void:
	# Spread, part folded back in, then raised or lowered about the bird's length (its z).
	var b: Projection = Basis4D.from_xy(e) * _blend(SPREAD, Projection.IDENTITY, fold)
	for w in _wings:
		var pivot: Node4D = w[0]
		pivot.basis = b if float(w[1]) > 0.0 else Basis4D.from_xw(PI) * b


func animate(t: float, dt: float) -> void:
	if dt <= 0.0:
		return
	# How it is moving, smoothed (its path is set from outside).
	if _last != Vector4.INF:
		_v = _v.lerp((position - _last) / dt, 1.0 - exp(-dt * 12.0))
	if held and alive:
		_struggle(t)
		_last = position
		return
	if not alive:
		_tumble(dt)
		_last = position
		return
	_last = position
	var flat := Vector2(_v.x, _v.z)
	if flat.length() > 0.2:
		_yaw = lerp_angle(_yaw, atan2(flat.x, flat.y), 1.0 - exp(-dt * 10.0))
	# Bursting off the trap at first; gliding on the way down.
	var burst: float = clampf(1.0 - t / 0.35, 0.0, 1.0)
	var glide: float = smoothstep(-0.8, -3.5, _v.y)
	_cycle += dt * _rate * (1.0 + 0.35 * burst) * (1.0 - 0.45 * glide)
	var ph: float = fposmod(_cycle + _phase, 1.0)
	# The wings: a hard downstroke, a slower upstroke half folded.
	var top: float = 1.05 - 0.3 * glide
	var bottom: float = -0.75 + 0.55 * glide
	var e: float
	var fold: float = 0.0
	if ph < DOWN:
		e = lerpf(top, bottom, smoothstep(0.0, 1.0, ph / DOWN))
	else:
		var k: float = (ph - DOWN) / (1.0 - DOWN)
		e = lerpf(bottom, top, smoothstep(0.0, 1.0, k))
		fold = 0.5 * sin(PI * k) * (1.0 - glide)
	_wing(e, fold)
	# The body: up with each downstroke, nose-up as it climbs, a loose roll.
	var s: float = size / 0.5
	if running:
		_run(t, dt, flat)
		return
	var heave: float = 0.035 * s * sin(TAU * ph + 0.9) * (1.0 - 0.7 * glide)
	var nose_up: float = clampf(0.45 + 0.08 * _v.y, -0.4, 0.9) + 0.3 * burst
	var roll: float = 0.1 * sin(t * 2.1 + _seed) + 0.05 * sin(t * 5.3 + _seed * 2.0)
	basis = Basis4D.from_zx(_yaw) * Basis4D.from_yz(-nose_up) * Basis4D.from_xy(roll)
	_body.position = Vector4(0.0, heave, 0.0, 0.0)
	# The head held level: the neck takes back most of the pitch, the roll and the heave, and reaches
	# forward.
	if _neck != null:
		_neck.basis = Basis4D.from_yz(nose_up * 0.8 + 0.3) * Basis4D.from_xy(-roll * 0.8)
		_neck.position = _neck_rest - Vector4(0.0, heave * 0.7, 0.0, 0.0)
	# The legs trail back from the hips, swinging a little with the beat.
	for l in _legs:
		(l[0] as Node4D).basis = Basis4D.from_yz(1.6 + 0.12 * sin(TAU * ph + 1.4 + float(l[1]) * 0.5))


## On the ground, legging it: legs alternating, wings half open and beating, body forward, bobbing.
func _run(t: float, dt: float, flat: Vector2) -> void:
	var stride: float = 4.2
	var ph: float = fposmod(t * stride + _phase, 1.0)
	var s: float = size / 0.5
	_cycle += dt * _rate * 1.2
	var wp: float = fposmod(_cycle + _phase, 1.0)
	_wing(0.35 + 0.55 * sin(TAU * wp), 0.35)
	var lean: float = clampf(flat.length() * 0.06, 0.0, 0.45)
	var roll: float = 0.06 * sin(TAU * ph)
	basis = Basis4D.from_zx(_yaw) * Basis4D.from_yz(lean) * Basis4D.from_xy(roll)
	_body.position = Vector4(0.0, 0.03 * s * absf(sin(TAU * ph)), 0.0, 0.0)
	if _neck != null:
		_neck.basis = Basis4D.from_yz(-lean * 0.8 + 0.1 * sin(TAU * ph * 2.0))
		_neck.position = _neck_rest
	for l in _legs:
		var side: float = float(l[1])
		(l[0] as Node4D).basis = Basis4D.from_yz(0.75 * sin(TAU * ph + (0.0 if side > 0.0 else PI)))


## In the wolf's jaws: wings beating hard and out of step, legs kicking. The wolf sets where it is.
func _struggle(t: float) -> void:
	var b: float = sin(t * 34.0 + _seed)
	_wing(0.4 + 0.6 * b, 0.2 + 0.2 * sin(t * 13.0))
	for l in _legs:
		(l[0] as Node4D).basis = Basis4D.from_yz(0.6 + 0.7 * sin(t * 19.0 + float(l[1]) * 1.7))
	if _neck != null:
		_neck.basis = Basis4D.from_yz(0.3 * sin(t * 9.0)) * Basis4D.from_xy(0.3 * sin(t * 7.0 + 1.0))


func _tumble(dt: float) -> void:
	_fall += dt
	_v.y += G * dt
	position += _v * dt
	basis = Basis4D.orthonormalized(basis * Basis4D.from_yz(_spin.x * dt) * Basis4D.from_xy(_spin.y * dt))
	# Wings and legs gone loose: a last flail that dies away, wings half shut.
	var limp: float = exp(-_fall * 4.0)
	_wing(0.2 + 0.7 * sin(_fall * 15.0) * limp, 0.55)
	for l in _legs:
		(l[0] as Node4D).basis = Basis4D.from_yz(0.5 + 0.6 * sin(_fall * 12.0 + float(l[1])) * limp)
	if _fall > 0.65 and _dissolve < 0.0:
		_dissolve = 0.0
