extends Node4D

## BOTANY LAB, round 3 (follow_up/arboretum.md section 9, step 12): the flower room's butterflies, eight
## species of true 4D lofts (butterfly_4d.gd), flying, landing on the flowers, basking and taking off.
##
## EACH ONE is three MeshInstance4Ds under this node, posed here every frame: the body, and each side's
## wings turned about the body's long axis (the hinge), so the wings beat. Its life is four states:
##   fly       toward a target, a flower to land on (most of the time) or a point in the air; a
##             flutter of beats with short glides, bobbing with each beat, banking into its turns
##   land      a short settle onto the bloom, the wings closing
##   sit       basking: the wings open and close slowly; it stays a few seconds, or until a gust
##   take off  up and away to the next target
## The wingbeat is the species' own (the morpho slow, the small white quick).
##
## THE PERCHES come from the room (`perch_source`, a Callable giving world positions) and are read again
## whenever the room says so (refresh_perches), so a flower turned through W carries its landing point;
## a perch that has left the slice (|w| over a centimetre) is not landed on.
##
## In this node's own space (the room's). NO class_name (engine_gotchas.md).

const Fly := preload("res://ramon/Arboretum/botany_lab/flora/butterfly_4d.gd")
const Kit := preload("res://ramon/Arboretum/botany_lab/flora/flora_kit.gd")

enum {FLY, LAND, SIT, TAKE_OFF}

@export var count: int = 32
## Bigger than life, so they read across a room.
@export var size: float = 1.6
## The air they keep to (this node's space).
@export var bounds_lo: Vector3 = Vector3(-9.0, 0.5, -9.0)
@export var bounds_hi: Vector3 = Vector3(9.0, 6.0, 9.0)
## How far through W they wander either side of the slice, metres.
@export var w_wander: float = 0.006
@export var speed: float = 0.9
@export var seed_value: int = 11

## World positions of the perches (set by the room).
var perch_source: Callable = Callable()
## The room's wind (wind_4d.gd), for gusts that lift them off.
var wind: Node = null

var cpu_us: float = 0.0
var _flies: Array = []
var _perches := PackedVector4Array()
var _taken: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0


func _ready() -> void:
	_rng.seed = seed_value
	var mat: TetraMaterial4D = Fly.material()
	var n: int = mini(count, 120)
	for i in n:
		var key: String = Fly.KEYS[i % Fly.KEYS.size()]
		var ms: Array = Fly.meshes(key)
		var nodes: Array = []
		for k in 3:
			var mi := MeshInstance4D.new()
			mi.name = "%s_%d_%s" % [key, i, ["body", "right", "left"][k]]
			mi.mesh = ms[k]
			mi.material_override = mat
			add_child(mi)
			nodes.append(mi)
		var d: Dictionary = Fly.data(key)
		var p := Vector4(_rng.randf_range(bounds_lo.x, bounds_hi.x), _rng.randf_range(bounds_lo.y + 0.5, bounds_hi.y - 1.0), _rng.randf_range(bounds_lo.z, bounds_hi.z), 0.0)
		_flies.append({
			"key": key, "nodes": nodes, "p": p, "v": Vector4(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1), 0.0).normalized() * speed,
			"head": Vector4(0, 0, 1, 0), "state": FLY, "t": 0.0, "target": p, "perch": -1, "phase": _rng.randf() * TAU,
			"beat": float(d.get("beat", 6.0)) * _rng.randf_range(0.9, 1.1), "flap": 0.4, "bank": 0.0, "glide": 0.0, "from": p,
			"sit_for": 4.0, "seed": _rng.randf() * 100.0,
		})
	refresh_perches()
	for f in _flies:
		_pick_target(f)
		# Some start on a flower.
		if (f["perch"] as int) >= 0 and _rng.randf() < 0.45:
			f["p"] = f["target"]
			f["state"] = SIT
			f["sit_for"] = _rng.randf_range(2.0, 9.0)
	_pose_all()


## Read the perches again from the room (after a turn).
func refresh_perches() -> void:
	if perch_source.is_valid():
		var inv: Projection = global_basis.inverse() if is_inside_tree() else Projection.IDENTITY
		var o: Vector4 = global_position if is_inside_tree() else Vector4.ZERO
		_perches = PackedVector4Array()
		for g in perch_source.call():
			_perches.append(inv * ((g as Vector4) - o))
	for f in _flies:
		var pi: int = f["perch"]
		if pi >= 0 and pi < _perches.size():
			f["target"] = _perch_point(pi)
			if absf((f["target"] as Vector4).w) > 0.01 and int(f["state"]) != FLY:
				_take_off(f)


func perches_count() -> int:
	return _perches.size()


func sitting() -> int:
	var n: int = 0
	for f in _flies:
		if int(f["state"]) == SIT:
			n += 1
	return n


func _perch_point(i: int) -> Vector4:
	return _perches[i] + Vector4(0.0, 0.004 * size, 0.0, 0.0)


func _pick_target(f: Dictionary) -> void:
	var old: int = f["perch"]
	if old >= 0:
		_taken.erase(old)
	f["perch"] = -1
	if not _perches.is_empty() and _rng.randf() < 0.7:
		# A free flower in the slice, preferring ones not too far.
		var best: int = -1
		var best_score: float = INF
		for k in 8:
			var c: int = _rng.randi() % _perches.size()
			if _taken.has(c) or c == old or absf(_perches[c].w) > 0.01:
				continue
			var dd: float = (_perches[c] - (f["p"] as Vector4)).length() * _rng.randf_range(0.6, 1.4)
			if dd < best_score:
				best_score = dd
				best = c
		if best >= 0:
			f["perch"] = best
			_taken[best] = true
			f["target"] = _perch_point(best)
			return
	f["target"] = Vector4(_rng.randf_range(bounds_lo.x, bounds_hi.x), _rng.randf_range(bounds_lo.y + 0.6, bounds_hi.y - 0.5), _rng.randf_range(bounds_lo.z, bounds_hi.z), 0.0)


func _take_off(f: Dictionary) -> void:
	f["state"] = TAKE_OFF
	f["t"] = 0.0
	f["from"] = f["p"]
	_pick_target(f)
	f["v"] = Vector4(_rng.randf_range(-0.4, 0.4), 0.8, _rng.randf_range(-0.4, 0.4), 0.0) * speed


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var dt: float = clampf(delta, 0.0, 0.05)
	_t += dt
	var gusty: bool = false
	if wind != null and is_instance_valid(wind):
		gusty = float(wind.call("_strength")) > 0.45 and float(wind.get("gust_front")) > -999.0
	for f in _flies:
		_step(f, dt, gusty)
	_pose_all()
	cpu_us = lerpf(cpu_us, float(Time.get_ticks_usec() - t0), 0.05)


func _step(f: Dictionary, dt: float, gusty: bool) -> void:
	var state: int = f["state"]
	f["t"] = float(f["t"]) + dt
	var t: float = f["t"]
	var p: Vector4 = f["p"]
	var beat: float = f["beat"]
	match state:
		SIT:
			f["p"] = f["target"]
			# Basking: open and close, slowly.
			var bask: float = 0.5 + 0.5 * cos(_t * 0.9 + float(f["seed"]))
			f["flap"] = lerpf(0.18, 1.38, bask)
			if t > float(f["sit_for"]) or (gusty and _rng.randf() < dt * 1.5):
				_take_off(f)
		LAND:
			var k: float = smoothstep(0.0, 0.8, t)
			f["p"] = (f["from"] as Vector4).lerp(f["target"], k)
			f["phase"] = float(f["phase"]) + dt * beat * TAU * (1.0 - k)
			f["flap"] = lerpf(0.5 + 0.6 * sin(float(f["phase"])), 1.3, k)
			if t >= 0.8:
				f["state"] = SIT
				f["t"] = 0.0
				f["sit_for"] = _rng.randf_range(3.0, 10.0)
		_:
			# FLY and TAKE_OFF: a flutter toward the target.
			var to: Vector4 = (f["target"] as Vector4) - p
			var dist: float = to.length()
			var v: Vector4 = f["v"]
			var sd: float = float(f["seed"])
			var wander := Vector4(sin(_t * 0.7 + sd), sin(_t * 1.1 + sd * 1.3) * 0.6, cos(_t * 0.8 + sd * 0.7), 0.0)
			var want: Vector4 = (to / maxf(dist, 0.001)) * speed * clampf(dist / 0.6, 0.35, 1.0) + wander * 0.35 * speed
			if state == TAKE_OFF and t < 0.6:
				want += Vector4(0, 0.6, 0, 0) * speed
			var steer: float = 2.2 if dist > 0.8 else 4.0
			var nv: Vector4 = v.lerp(want, clampf(steer * dt, 0.0, 1.0))
			# Bank into the turn: how fast the heading swings.
			var h0 := Vector2(v.x, v.z)
			var h1 := Vector2(nv.x, nv.z)
			var turn: float = h0.angle_to(h1) / maxf(dt, 0.001) if h0.length() > 0.01 and h1.length() > 0.01 else 0.0
			f["bank"] = lerpf(float(f["bank"]), clampf(-turn * 0.25, -0.6, 0.6), clampf(dt * 4.0, 0.0, 1.0))
			v = nv
			p += v * dt
			# A beat lifts, a glide sinks a little.
			var glide: float = f["glide"]
			if glide > 0.0:
				f["glide"] = glide - dt
				f["flap"] = lerpf(float(f["flap"]), 0.22, clampf(dt * 8.0, 0.0, 1.0))
				p.y -= 0.12 * dt
			else:
				f["phase"] = float(f["phase"]) + dt * beat * TAU
				var ph: float = f["phase"]
				f["flap"] = 0.35 + 0.95 * (0.5 + 0.5 * sin(ph))
				p.y += cos(ph) * 0.05 * dt * beat
				if _rng.randf() < dt * 0.5 and dist > 1.0:
					f["glide"] = _rng.randf_range(0.3, 0.8)
			p.w = sin(_t * 0.4 + sd * 2.1) * w_wander
			p.x = clampf(p.x, bounds_lo.x, bounds_hi.x)
			p.y = clampf(p.y, bounds_lo.y, bounds_hi.y)
			p.z = clampf(p.z, bounds_lo.z, bounds_hi.z)
			f["p"] = p
			f["v"] = v
			if state == TAKE_OFF and t > 0.9:
				f["state"] = FLY
			var perch: int = f["perch"]
			if perch >= 0 and dist < 0.22:
				f["state"] = LAND
				f["t"] = 0.0
				f["from"] = p
			elif perch < 0 and dist < 0.5:
				_pick_target(f)


func _pose_all() -> void:
	for f in _flies:
		var v: Vector4 = f["v"]
		var h := Vector4(v.x, 0.0, v.z, 0.0)
		if h.length() > 0.05 and int(f["state"]) != SIT:
			f["head"] = h.normalized()
		var fr: Projection = Kit.level_frame(f["head"])
		var bank: float = f["bank"] if int(f["state"]) != SIT else 0.0
		if not is_zero_approx(bank):
			fr = fr * Kit.rot_z(bank)
		var s: float = size
		var b := Projection(fr.x * s, fr.y * s, fr.z * s, fr.w * s)
		var flap: float = f["flap"]
		var nodes: Array = f["nodes"]
		var p: Vector4 = f["p"]
		(nodes[0] as Node4D).position = p
		(nodes[0] as Node4D).basis = b
		(nodes[1] as Node4D).position = p
		(nodes[1] as Node4D).basis = b * Kit.rot_z(flap)
		(nodes[2] as Node4D).position = p
		(nodes[2] as Node4D).basis = b * Kit.rot_z(-flap)


func bench_row(name_: String) -> Array:
	return [name_, str(_flies.size()), "%.3f ms" % (cpu_us / 1000.0), str(_flies.size() * 3), "4D loft, 3 pieces"]
