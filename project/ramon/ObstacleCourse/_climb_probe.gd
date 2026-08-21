extends SceneTree

## Can the player actually climb the course? Simulated, not eyeballed.
##
## `_verify_ascent.gd` proves the geometry is well formed; it cannot prove the
## controller can get up it. This drives the REAL `CharacterBody4D` from
## `player.tscn` with the real constants from `player.gd` - SPEED 5.0,
## JUMP_VELOCITY 4.5, project gravity - through the same `move_and_slide()` the
## controller calls, and reports the height actually reached per bay.
##
## Written after a playtest reported "controls are buggy, sometimes stops" and
## "hard to get on the first jumpable part". Both turned out to be one geometry
## defect (stair treads overlapping in plan, so the next step overhung the one
## you stood on), and a simulation like this would have caught it before it ever
## reached a keyboard.
##
## Runs WITHOUT --headless is unnecessary here - no rendering is involved, only
## PhysicsServer4D - but it must not run while the editor is open.
##
##   godot.windows.editor.double.x86_64.console.exe --headless --path project \
##       --script res://ramon/ObstacleCourse/_climb_probe.gd -- ascent_wall.tscn

const DEFAULT_SCENE := "res://ramon/ObstacleCourse/ascent.tscn"

## From player.gd, so the simulation matches the controller rather than an idea
## of it. If these drift, the probe is lying.
const SPEED := 5.0
const JUMP_VELOCITY := 4.5

## Give each bay this long to be reached before calling it blocked.
const SECONDS_PER_BAY := 6.0
const STEP := 1.0 / 60.0

var _scene: Node = null
var _player: CharacterBody4D = null
var _course: Node4D = null
var _targets: Array = []
var _index: int = 0
var _elapsed: float = 0.0
var _best: float = -1e9
var _failures: int = 0


func _initialize() -> void:
	print("=== CLIMB PROBE: can the controller get up it? ===")
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else DEFAULT_SCENE
	if not scene_path.begins_with("res://"):
		scene_path = "res://ramon/ObstacleCourse/" + scene_path
	print("scene: ", scene_path)

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("could not load %s" % scene_path)
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	_player = _scene.get_node_or_null(^"Player") as CharacterBody4D
	_course = _scene.get_node_or_null(^"Course") as Node4D


## Every surface the route actually stands on, in order: bay, then that bay's
## stair treads, then the next bay, and so on.
##
## The first version aimed only at bay centres, and once the flights began to
## switchback it walked straight off the side of every tread and fell - which
## looked exactly like the course being unclimbable when it was the probe that
## could not follow a staircase. A test that cannot do what it asks of the level
## is worse than no test.
func _collect_targets() -> void:
	var bays_by_id: Dictionary = {}
	var stairs_by_id: Dictionary = {}
	for child in _course.get_children():
		var child_name := String(child.name)
		if child_name.begins_with("Bay_") or child_name.begins_with("Deck_"):
			bays_by_id[child_name.substr(child_name.find("_") + 1)] = child
		elif child_name.begins_with("Phase1Stair_"):
			stairs_by_id[child_name.trim_prefix("Phase1Stair_")] = child

	var ids: Array = bays_by_id.keys()
	ids.sort()
	var ordered: Array = []
	for id: String in ids:
		# The stair INTO this bay comes first, lowest tread upward.
		if stairs_by_id.has(id):
			var steps: Array = []
			for step in (stairs_by_id[id] as Node).get_children():
				steps.append(step)
			steps.sort_custom(func(a, b): return (a as Node4D).position.y < (b as Node4D).position.y)
			for step in steps:
				ordered.append(step)
		ordered.append(bays_by_id[id])

	for body in ordered:
		# The deck's TOP, not its centre. A body's origin is half a slab below the
		# surface you stand on, and the player's own origin is half its capsule
		# ABOVE its feet - comparing the two raw makes success unreachable by
		# construction, which is exactly how this probe first "failed" a course
		# it was in fact climbing perfectly well.
		var top: float = (body as Node4D).global_position.y
		for grandchild in body.get_children():
			var collider := grandchild as CollisionShape4D
			if collider == null:
				continue
			var box := collider.shape as BoxShape4D
			if box != null:
				top += box.size.y * 0.5
		var pos: Vector4 = (body as Node4D).global_position
		var parent: Node = (body as Node).get_parent()
		var label: String = String(body.name)
		if parent != null and parent != _course:
			label = "%s/%s" % [parent.name, label]
		_targets.append({"name": label, "pos": pos, "top": top})


func _physics_process(_delta: float) -> bool:
	if _player == null or _course == null:
		push_error("scene has no Player or Course")
		quit(1)
		return true

	if _targets.is_empty():
		_collect_targets()
		if _targets.size() < 2:
			push_error("fewer than two bays generated")
			quit(1)
			return true
		# Start standing on the first bay, exactly where the scene spawns you.
		_index = 1
		_elapsed = 0.0
		_best = _player.global_position.y
		print("\nstart at %s, y = %.2f" % [_targets[0]["name"], _player.global_position.y])

	if _index >= _targets.size():
		_report()
		return true

	var target: Dictionary = _targets[_index]
	var target_pos: Vector4 = target["pos"]
	var target_top: float = target["top"]
	var here: Vector4 = _player.global_position

	# Walk toward the target bay in the horizontal plane, jumping whenever
	# grounded - the crudest possible player, which is the point: if a
	# button-mashing bot can climb it, a human certainly can.
	var to_target := Vector2(target_pos.x - here.x, target_pos.z - here.z)
	var direction := Vector2.ZERO
	if to_target.length() > 0.4:
		direction = to_target.normalized()

	# Deliberately NOT a button-masher. The first version ran at full speed and
	# jumped every grounded frame, which overshot every tread and reported a
	# climbable staircase as impossible. A player approaches a step, then hops.
	var distance: float = to_target.length()
	var needs_height: bool = (target_top - (_player.global_position.y - 0.875)) > 0.05
	# Full speed whenever height is needed: a hop only carries you as far as your
	# horizontal speed does, and easing off is what makes a reachable tread
	# unreachable. Slow only when closing on something at the same level.
	var speed: float = SPEED if (needs_height or distance > 2.5) else SPEED * 0.4

	var velocity: Vector4 = _player.linear_velocity
	if not _player.is_on_floor():
		velocity += _player.get_gravity() * STEP
	elif needs_height and distance < 3.0 and velocity.y <= 0.0:
		velocity.y = JUMP_VELOCITY
	velocity.x = direction.x * speed
	velocity.z = direction.y * speed
	velocity.w = 0.0
	_player.linear_velocity = velocity
	# Use the scene's own controller step-up when it has one, so the probe tests
	# the player that actually ships rather than a jump-only stand-in.
	if _player.has_method("_try_step_up"):
		_player.call("_try_step_up", STEP)
	_player.move_and_slide(STEP)

	_best = maxf(_best, _player.global_position.y)
	_elapsed += STEP

	# Reached when standing at roughly the bay's height, near its centre.
	# Half the player capsule (1.75 m tall), so this compares feet to deck top.
	var feet: float = _player.global_position.y - 0.875
	var reached: bool = (
			absf(feet - target_top) < 0.45
			and Vector2(target_pos.x - _player.global_position.x, target_pos.z - _player.global_position.z).length() < 3.4
	)
	if reached:
		print("  ok    %-26s top %.2f reached after %.1f s" % [target["name"], target_top, _elapsed])
		_index += 1
		_elapsed = 0.0
		_best = _player.global_position.y
	elif _elapsed > SECONDS_PER_BAY:
		_failures += 1
		print("  FAIL  %-26s top %.2f NOT reached (best feet %.2f, ended at %.2f) after %.0f s" % [
				target["name"], target_top, _best - 0.875, feet, SECONDS_PER_BAY])
		# Teleport on so the rest of the course is still measured rather than
		# every later bay failing for one blocked flight.
		_player.global_position = Vector4(target_pos.x, target_top + 0.9, target_pos.z, 0.0)
		_player.linear_velocity = Vector4()
		_index += 1
		_elapsed = 0.0
	return false


func _report() -> void:
	if _failures == 0:
		print("\n=== PASS: every bay reachable by walk+jump ===")
	else:
		print("\n=== %d BAY(S) UNREACHABLE ===" % _failures)
	quit(0 if _failures == 0 else 1)
