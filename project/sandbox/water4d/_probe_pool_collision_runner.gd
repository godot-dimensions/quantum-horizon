extends SceneTree

## Does the room actually hold the player in?
##
##   godot --path project --rendering-method forward_plus \
##       --script res://sandbox/water4d/_probe_pool_collision_runner.gd
##
## Drives the walker hard at each boundary for a few seconds and reports where it ends up.
## Written because the railing LOOKED right - the bodies exist, the shapes are the right size
## and in the right place - and you could still walk through it. The geometry being correct
## is not the same claim as the physics stopping you, and only one of those was checked.
##
## SECONDS, NOT FRAMES, for the push: with vsync off a frame count is not a duration.

const SCENE := "res://sandbox/water4d/pool_room.tscn"
const PUSH := 3.0
const SETTLE := 0.6

## Each run: a name, where to start, the direction to hold, and the limit it must not pass.
const RUNS := [
	["railing +z", Vector4(0.0, 1.9, 0.0, 0.0), Vector4(0.0, 0.0, 1.0, 0.0), "z", 1.8],
	["railing -z", Vector4(0.0, 1.9, 0.0, 0.0), Vector4(0.0, 0.0, -1.0, 0.0), "z", 1.8],
	["wall +x", Vector4(0.0, 1.9, 0.0, 0.0), Vector4(1.0, 0.0, 0.0, 0.0), "x", 22.5],
	["through W", Vector4(0.0, 1.9, 0.0, 0.0), Vector4(0.0, 0.0, 0.0, 1.0), "w", 13.5],
]

var _root: Node = null
var _player: CharacterBody4D = null
var _frames: int = 0
var _held: float = 0.0
var _index: int = 0
var _settling: bool = true
var _rows: Array[String] = []
var _failures: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load(SCENE) as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		return false
	if _frames == 2:
		_player = _root.get_node_or_null("Player") as CharacterBody4D
		if _player == null:
			print("  FAIL - no Player in the scene, nothing to test")
			quit(1)
			return true
		_start()
		return false

	_held += delta
	if _settling:
		if _held < SETTLE:
			return false
		_held = 0.0
		_settling = false
		return false

	# Hold the body at a steady speed rather than pressing keys: the walker reads its own
	# input, and what is under test is the collision, not the key bindings.
	var dir: Vector4 = RUNS[_index][2]
	_player.linear_velocity = Vector4(dir.x * 4.0, _player.linear_velocity.y, dir.z * 4.0,
			dir.w * 4.0)
	if _held < PUSH:
		return false

	_record()
	_index += 1
	if _index >= RUNS.size():
		return _report()
	_held = 0.0
	_settling = true
	_start()
	return false


func _start() -> void:
	_player.position = RUNS[_index][1]
	_player.linear_velocity = Vector4.ZERO


func _record() -> void:
	var run: Array = RUNS[_index]
	var axis: String = run[3]
	var limit: float = run[4]
	var where: Vector4 = _player.position
	var reached: float = absf(where.x if axis == "x" else (where.z if axis == "z" else where.w))
	var held: bool = reached <= limit
	_rows.append("  %-12s reached %s %6.2f   limit %5.2f   %s"
			% [run[0], axis, reached, limit, "held" if held else "WENT THROUGH"])
	if not held:
		_failures.append("%s: got to %s %.2f, past its %.2f limit" % [run[0], axis, reached, limit])
	# Falling out of the pool is its own failure, and worth naming separately: it is what
	# happens next when a railing does not hold.
	if where.y < -1.0:
		_failures.append("%s: ended up at y %.2f - in the water, not on the walkway"
				% [run[0], where.y])


func _report() -> bool:
	print("")
	for row in _rows:
		print(row)
	print("")
	if _failures.is_empty():
		print("  PASS - every boundary held.")
	else:
		for f in _failures:
			print("  FAIL - %s" % f)
	quit(0 if _failures.is_empty() else 1)
	return true
