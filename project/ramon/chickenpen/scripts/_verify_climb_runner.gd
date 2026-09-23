extends SceneTree

## Can you walk back UP the ramp?
##
## IT WAS A WRONG DICTIONARY KEY, not a limitation of the engine.
##
## The reasoning that nearly stopped this being fixed went: the only 4D physics engine is
## axis_aligned_box_physics_engine_4d, so a sloped collider cannot exist and a ramp has to
## be a staircase of boxes - and CharacterBody4D has no step-up, so every riser is a
## vertical face, and a vertical face is a wall however low it is. All of that is true.
## The conclusion drawn from it - that walking back up was therefore impossible - was not,
## because a step-up can be written, and one had been.
##
## It did nothing, because it asked the raycast result for "position". There is no such
## key: PhysicsServer4D.raycast_physics_objects returns `hit`, `distance`, `normal`,
## `point`, `global_distance`, `global_normal`, `global_point`, `body` and `shape`. The
## probe found the floor every time and the code threw the answer away. The camera rig had
## the same key wrong, so its collision had never once fired either.
##
## IT PRESSES THE KEY. Everything else about the walkway can be measured from its geometry,
## but this cannot: whether a staircase of axis-aligned boxes is climbable depends on the
## character controller, the capsule, the riser height and the physics engine all at once.
## So the test holds "forward" down for a few seconds and looks at where the body ended up,
## which is the same thing a person does.

var _root: Node
var _f := 0
var _fails: Array = []
var _player: Node4D
var _stage: Node4D
var _from := Vector4.ZERO
var _low := 0.0
var _held := 0.0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(delta: float) -> bool:
	_f += 1
	if _f < 30:
		return false
	if _player == null:
		_player = _root.get_node("Player") as Node4D
		_stage = _root.get_node("Stage") as Node4D
		# At the bottom of the rake, on the centre line, facing back UP it.
		var foot: Vector4 = _stage.get("aisle_from")
		_player.global_position = Vector4(foot.x, 1.2, foot.z + 1.2, 0.0)
		# Forward is measured against the CAMERA RIG, not the body, and at the rig's
		# resting yaw "forward" is -Z. Uphill is +Z, so the key to hold is the back one -
		# which walks the same distance and saves arguing with the camera.
		_from = _player.global_position
		_low = _player.global_position.y
		print("\n--- up the ramp ---")
		Input.action_press(&"move_back")
		return false

	_held += delta
	# Facing up the ramp is facing +Z, so forward has to be re-pressed each frame only in
	# the sense that it stays held; the walker reads the axis every frame by itself.
	if _held < 6.0:
		return false
	Input.action_release(&"move_back")
	var now: Vector4 = _player.global_position
	var climbed: float = now.y - _low
	var walked: float = Vector2(now.x - _from.x, now.z - _from.z).length()
	_check("he gets up it", climbed > 0.8,
		"climbed %.2f m in six seconds, from y %.2f to %.2f" % [climbed, _low, now.y])
	_check("and he actually travelled", walked > 3.0, "%.1f m along the floor" % walked)
	_check("and he is still on the walkway",
		float(_stage.call("aisle_gap", now)) < float(_stage.get("aisle_width")),
		"%.1f m off the centre line" % float(_stage.call("aisle_gap", now)))
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
