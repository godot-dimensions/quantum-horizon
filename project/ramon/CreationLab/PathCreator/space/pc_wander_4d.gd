extends Node

## PathCreator: moves its parent (a Node4D, the pen patch's hen) round a slow loop on the floor while
## it drifts ana and kata, so an anchored destination has something to follow (PLAN.md step 86).
## Game only; in the editor the parent stays where it was put.
##
## NO class_name (engine_gotchas.md).

## The loop's radius on the floor, metres, and how long one lap takes, seconds.
@export var radius: float = 1.6
@export var lap_s: float = 14.0
## How far it drifts in W either side of where it was put, metres, and how long one swing takes.
@export var w_swing: float = 1.5
@export var w_period_s: float = 9.0

var _home: Vector4
var _t: float = 0.0


func _ready() -> void:
	var p := get_parent() as Node4D
	if p != null:
		# Put as the loop's start (angle 0), so the home is the loop's middle.
		_home = p.position - Vector4(radius, 0.0, 0.0, 0.0)


func _process(dt: float) -> void:
	var p := get_parent() as Node4D
	if p == null or Engine.is_editor_hint():
		return
	_t += dt
	var a: float = TAU * _t / maxf(lap_s, 0.1)
	p.position = _home + Vector4(cos(a) * radius, 0.0, sin(a) * radius, sin(TAU * _t / maxf(w_period_s, 0.1)) * w_swing)
