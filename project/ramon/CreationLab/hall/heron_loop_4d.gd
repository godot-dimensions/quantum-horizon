extends Node

## The heron's flight in the hall (Creature Lab round 3, 10 Oct 2026; Ramon's item 39: "birds can fly around
## within a limited area near their assigned display ... occasionally leave their pedestal ... eventually return
## to their own pedestal ... their movement should remain reasonably natural").
##
## The lab's heron stands with `idle_only` on (stand, look about; nothing else). Now and then this lets it go:
## idle_only off, its own take-off (crouch, the steep climb, the wingbeats and the croak), then its flight path
## swapped for a loop that rises, swings out to one side and round to the other, and comes down on the very
## spot it left (follow_up/creation_lab_creatures.md: "after perform('take_off') overwrite _path"). Back on the
## deck it is idle again.
##
## NO class_name (engine_gotchas.md).

## The heron.
@export var heron_path: NodePath
## Seconds between flights, at random in this range.
@export var every: Vector2 = Vector2(18.0, 34.0)
## How high and how far to the side the loop goes (m), and how long it takes (s).
@export var rise: float = 2.8
@export var swing: float = 2.4
@export var seconds: float = 6.5
@export var seed: int = 3

# heron_4d.gd's states (STAND, ALERT, ONE_LEG, STALK, STRIKE, TAKE_OFF, FLY, LAND).
const STAND := 0
const TAKE_OFF := 5
const FLY := 6
const LAND := 7

var _heron: Node4D
var _rng := RandomNumberGenerator.new()
var _wait: float = 0.0
var _flying: bool = false


func _ready() -> void:
	_rng.seed = seed
	_heron = get_node_or_null(heron_path) as Node4D
	_wait = _rng.randf_range(every.x * 0.4, every.y * 0.6)


func _process(delta: float) -> void:
	if _heron == null or not is_instance_valid(_heron):
		return
	var st: int = int(_heron.get("state"))
	if _flying:
		if st != TAKE_OFF and st != FLY and st != LAND:
			# Down: standing still again until the next time.
			_flying = false
			_heron.set("idle_only", true)
			_wait = _rng.randf_range(every.x, every.y)
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_heron.set("idle_only", false)
	_heron.call("perform", "take_off")
	if int(_heron.get("state")) != TAKE_OFF:
		_heron.set("idle_only", true)
		_wait = 2.0
		return
	# Its own take-off aims at a marsh or six metres off; the loop instead, from here back to here.
	var p: Vector4 = _heron.position
	var b: Projection = _heron.basis
	var side := Vector4(b.x.x, 0.0, b.x.z, 0.0).normalized()
	var ahead := Vector4(b.z.x, 0.0, b.z.z, 0.0).normalized()
	var up := Vector4(0.0, 1.0, 0.0, 0.0)
	var way: float = 1.0 if _rng.randf() < 0.5 else -1.0
	var path: Array[Vector4] = [p, p + up * rise + side * swing * way + ahead * 1.2, p + up * rise - side * swing * way + ahead * 1.2, p]
	_heron.set("_path", path)
	_heron.set("_flight_len", seconds)
	_heron.set("_state_len", seconds)
	_flying = true
