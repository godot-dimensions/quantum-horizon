extends Node

## An animal walking on its pedestal without walking off it (Creation Lab v2, 9 Oct 2026; Ramon: "if an animal's
## walking animation would carry it beyond the boundaries of its platform ... detect when the animal approaches
## the platform boundary, rotate its movement direction inward, redirect it by approximately 35 degrees ...
## allow the existing locomotion animation to continue ... preserve the original animation cycle").
##
## The four-legged walker (strider_walker.gd) moves its parent, the animal, along the animal's own heading when
## `travel` is on (_travel: the planted feet's slide, turned by the animal's basis). It has no steering of its
## own, so this turns the animal itself, a little each frame: the walk carries on as it was and the path bends.
##
##   - Each frame it looks a little ahead along the heading; when that point leaves the deck (less a margin) it
##     starts a turn toward the inside: 35 degrees, or as much as it takes to face back in when it is walking
##     straight out, eased at `turn_rate`.
##   - Now and then a small turn of its own either way, so the walk is not a ruler-straight back and forth.
##
## The deck is round (`radius`) or a rectangle (`half`), round `centre`, both in the animal's parent's space.
## Its heading is read off how it actually moves, not assumed, so a model built facing -Z works the same.
##
## An animal that steers itself (Nike's antics, a chicken's wander) gets `steer` off: then this only keeps
## it on the deck.
##
## NO class_name (engine_gotchas.md).

## The walker driving the animal; the animal is its parent.
@export var walker_path: NodePath
## The deck: round with this radius, or (radius 0) a rectangle with these half sizes, round `centre`.
@export var radius: float = 0.0
@export var half: Vector2 = Vector2(2.0, 2.0)
@export var centre: Vector2 = Vector2.ZERO
## How far inside the edge it turns, and how far ahead it looks (m).
@export var margin: float = 0.5
@export var look_ahead: float = 0.9
## The turn when it meets the edge, and how fast turns go (degrees, degrees a second).
@export var turn_degrees: float = 35.0
@export var turn_rate: float = 45.0
## Seconds between its own small turns, and how big they are at most (degrees).
@export var wander_every: Vector2 = Vector2(4.0, 9.0)
@export var wander_degrees: float = 22.0
@export var seed: int = 1
## Off for an animal that steers itself: then only the clamp to the deck.
@export var steer: bool = true

var _walker: Node
var _animal: Node4D
var _yaw: float = 0.0
var _turn_left: float = 0.0
var _scale: Vector4 = Vector4.ONE
var _forward_sign: float = 1.0
var _last: Vector4
var _have_last: bool = false
var _next_wander: float = 0.0
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0


func _ready() -> void:
	_rng.seed = seed
	_walker = get_node_or_null(walker_path)
	if _walker == null:
		return
	_animal = _walker.get_parent() as Node4D
	if _animal == null:
		return
	if steer:
		_walker.set("travel", true)
	var b: Projection = _animal.basis
	_scale = Vector4(b.x.length(), b.y.length(), b.z.length(), b.w.length())
	_yaw = atan2(b.z.x / maxf(_scale.z, 1e-6), b.z.z / maxf(_scale.z, 1e-6))
	_next_wander = _rng.randf_range(wander_every.x, wander_every.y)


func _physics_process(delta: float) -> void:
	if _animal == null or not is_instance_valid(_animal):
		return
	_t += delta
	var p: Vector4 = _animal.position
	# Which way is forward: the way it actually goes along its +Z, once it has gone a little.
	var fz := Vector2(sin(_yaw), cos(_yaw))
	if _have_last:
		var moved := Vector2(p.x - _last.x, p.z - _last.z)
		if moved.length() > 0.004:
			_forward_sign = 1.0 if moved.dot(fz) >= 0.0 else -1.0
	_last = p
	_have_last = true
	var fwd: Vector2 = fz * _forward_sign
	var here := Vector2(p.x, p.z) - centre
	if steer and absf(_turn_left) < 0.001:
		var ahead: Vector2 = here + fwd * look_ahead
		if _outside(ahead):
			var inward: Vector2 = -here.normalized() if here.length() > 0.001 else -fwd
			var side: float = signf(fwd.cross(inward))
			if side == 0.0:
				side = 1.0 if _rng.randf() < 0.5 else -1.0
			var needed: float = acos(clampf(fwd.dot(inward), -1.0, 1.0))
			# 35 degrees in, or as far as it takes to face back in when it walks straight out.
			var amount: float = maxf(deg_to_rad(turn_degrees), needed - deg_to_rad(10.0)) if needed > deg_to_rad(110.0) else deg_to_rad(turn_degrees)
			# A cross product's sign in x-z is the turn's: positive turns +x toward +z, which is -yaw here.
			_turn_left = -side * amount
		elif _t > _next_wander:
			_turn_left = _rng.randf_range(-1.0, 1.0) * deg_to_rad(wander_degrees)
			_next_wander = _t + _rng.randf_range(wander_every.x, wander_every.y)
	if steer and absf(_turn_left) >= 0.001:
		var step: float = minf(absf(_turn_left), deg_to_rad(turn_rate) * delta) * signf(_turn_left)
		_yaw += step
		_turn_left -= step
		_apply_yaw()
	# Never off the deck, whatever the walk does in a turn.
	var limit: Vector2 = _clamped(here)
	if limit != here:
		_animal.position = Vector4(limit.x + centre.x, p.y, limit.y + centre.y, p.w)


func _outside(q: Vector2) -> bool:
	if radius > 0.0:
		return q.length() > radius - margin
	return absf(q.x) > half.x - margin or absf(q.y) > half.y - margin


func _clamped(q: Vector2) -> Vector2:
	if radius > 0.0:
		var lim: float = maxf(radius - margin * 0.4, 0.05)
		return q if q.length() <= lim else q.normalized() * lim
	var hx: float = maxf(half.x - margin * 0.4, 0.05)
	var hz: float = maxf(half.y - margin * 0.4, 0.05)
	return Vector2(clampf(q.x, -hx, hx), clampf(q.y, -hz, hz))


func _apply_yaw() -> void:
	var r: Projection = Basis4D.from_zx(_yaw)
	_animal.basis = Projection(r.x * _scale.x, r.y * _scale.y, r.z * _scale.z, r.w * _scale.w)
