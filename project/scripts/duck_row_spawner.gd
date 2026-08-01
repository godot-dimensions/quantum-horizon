extends Node4D
## Shooting gallery experiment: "ducks in a row" - a continuous conveyor of
## yellow targets, spawned at a fixed rate on one end of a diagonal path,
## drifting slowly to the other end, despawning either when shot (hitscan_
## weapon.gd calls try_hit_duck) or when they reach the far end (a silent
## miss, no penalty). Separate, score-free system from the red target's
## catch/timer loop - deliberately not wired into that scoring.
##
## Targets are dumb visual+collision scenes (no script of their own), same
## convention as gallery_target.tscn/gallery_target_spawner.gd - all motion
## and lifecycle logic lives here.

const DuckScene := preload("res://sandbox/shooting_gallery/duck_target.tscn")

## A straight line in the x/w plane (fixed z and y - "a row"), chosen so its
## midpoint is (0, *, PATH_START.z, 0) - directly on the player's default
## forward sightline from the green floor spawn (facing -z, x=0, w=0) - while
## still being a genuine diagonal (not a simple left-right or w-only line),
## per "at an angle, not aligned, but does intersect the player's starting
## view."
const PATH_START := Vector4(-4.0, 1.5, -2.0, -4.0)
const PATH_END := Vector4(4.0, 1.5, -2.0, 4.0)
const SPEED := 1.2 # Meters per second - "slowly."
const SPAWN_INTERVAL_SEC := 2.5

var _velocity: Vector4 = (PATH_END - PATH_START).normalized() * SPEED
var _path_length: float = PATH_START.distance_to(PATH_END)
var _ducks: Array = [] # Array of Node4D, oldest first.
var _spawn_timer_sec: float = 0.0

func _process(delta: float) -> void:
	_spawn_timer_sec += delta
	if _spawn_timer_sec >= SPAWN_INTERVAL_SEC:
		_spawn_timer_sec -= SPAWN_INTERVAL_SEC
		_spawn_duck()

	for i in range(_ducks.size() - 1, -1, -1):
		var duck: Node4D = _ducks[i]
		duck.position += _velocity * delta
		if duck.position.distance_to(PATH_START) >= _path_length:
			duck.queue_free()
			_ducks.remove_at(i)

func _spawn_duck() -> void:
	var duck: Node4D = DuckScene.instantiate()
	add_child(duck)
	duck.position = PATH_START
	_ducks.append(duck)

## Called by hitscan_weapon.gd with the raycast hit's "body" result, after
## the red target has already been checked and missed. Returns whether the
## hit body was actually one of the active ducks, and despawns it if so.
func try_hit_duck(hit_body: Object) -> bool:
	var index: int = _ducks.find(hit_body)
	if index == -1:
		return false
	_ducks[index].queue_free()
	_ducks.remove_at(index)
	return true
