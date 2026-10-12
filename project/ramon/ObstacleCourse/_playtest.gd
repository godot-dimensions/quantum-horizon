extends SceneTree

## Plays the game. Actually plays it - real input, real controller, real renderer.
##
## Every earlier probe drove `move_and_slide` directly from a script, which meant
## it tested a reimplementation of the player rather than the player. This one
## presses the same actions a human presses (`Input.action_press`) and lets
## `player.gd` do all the work, WITH a rendering device so frames can be looked
## at afterwards. If this cannot walk the course, neither can a person.
##
## Run with the editor closed and WITHOUT --headless:
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/ObstacleCourse/_playtest.gd -- ascent_wall.tscn
##
## Writes numbered PNGs so the run can be reviewed frame by frame, and prints a
## position trace with a stuck-detector.

const DEFAULT_SCENE := "res://ramon/ObstacleCourse/ascent_wall.tscn"

## Let shaders compile and @tool builders settle before touching anything.
const WARMUP_FRAMES := 30

## How long to spend trying to reach one waypoint before declaring it blocked.
const SECONDS_PER_WAYPOINT := 8.0

## Considered stuck if it moves less than this in a second.
const STUCK_DISTANCE := 0.35

var _scene: Node = null
var _player: CharacterBody4D = null
var _course: Node4D = null
var _waypoints: Array = []
var _index: int = 0
var _frames: int = 0
var _elapsed: float = 0.0
var _shots: int = 0
var _last_sample: Vector4 = Vector4()
var _sample_timer: float = 0.0
var _stuck_for: float = 0.0
var _failures: int = 0
var _scene_name: String = ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else DEFAULT_SCENE
	if not scene_path.begins_with("res://"):
		scene_path = "res://ramon/ObstacleCourse/" + scene_path
	_scene_name = scene_path.get_file().get_basename()
	print("=== PLAYTEST: %s ===" % scene_path)

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("could not load %s" % scene_path)
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	set_current_scene(_scene)
	_player = _scene.get_node_or_null(^"Player") as CharacterBody4D
	_course = _scene.get_node_or_null(^"Course") as Node4D


## Standing surfaces in route order, read off the generated tree.
func _collect_waypoints() -> void:
	var bays: Dictionary = {}
	var stairs: Dictionary = {}
	for child in _course.get_children():
		var n := String(child.name)
		if n.begins_with("Bay_") or n.begins_with("Deck_"):
			bays[n.substr(n.find("_") + 1)] = child
		elif n.begins_with("Phase1Stair_"):
			stairs[n.trim_prefix("Phase1Stair_")] = child
	var ids: Array = bays.keys()
	ids.sort()
	for id: String in ids:
		if stairs.has(id):
			var steps: Array = []
			for step in (stairs[id] as Node).get_children():
				steps.append(step)
			steps.sort_custom(func(a, b): return (a as Node4D).position.y < (b as Node4D).position.y)
			for step in steps:
				_waypoints.append(_surface(step, "%s/%s" % [stairs[id].name, step.name]))
		_waypoints.append(_surface(bays[id], String(bays[id].name)))


func _surface(body: Node, label: String) -> Dictionary:
	var node := body as Node4D
	var top: float = node.global_position.y
	for child in body.get_children():
		var collider := child as CollisionShape4D
		if collider == null:
			continue
		var box := collider.shape as BoxShape4D
		if box != null:
			top += box.size.y * 0.5
	return {"name": label, "pos": node.global_position, "top": top}


## Presses and releases the real movement actions so the real controller runs.
##
## Direction is expressed in the player's own basis, exactly as a human's WASD
## is: `player.gd` builds its motion from `basis * input_dir`, so aiming means
## choosing which of the four actions to hold, not writing a velocity.
func _drive(local_dir: Vector4, want_jump: bool) -> void:
	_set_action(&"move_right", local_dir.x > 0.3)
	_set_action(&"move_left", local_dir.x < -0.3)
	_set_action(&"move_back", local_dir.z > 0.3)
	_set_action(&"move_forward", local_dir.z < -0.3)
	_set_action(&"move_ana", local_dir.w > 0.3)
	_set_action(&"move_kata", local_dir.w < -0.3)
	if want_jump:
		Input.action_press(&"move_jump")
	else:
		Input.action_release(&"move_jump")


func _set_action(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _physics_process(delta: float) -> bool:
	if _player == null or _course == null:
		push_error("scene has no Player or Course")
		quit(1)
		return true
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false

	if _waypoints.is_empty():
		_collect_waypoints()
		if _waypoints.is_empty():
			push_error("no waypoints found")
			quit(1)
			return true
		_index = 1
		_last_sample = _player.global_position
		print("start: %s at y %.2f, %d waypoints\n" % [_waypoints[0]["name"], _player.global_position.y, _waypoints.size()])

	if _index >= _waypoints.size():
		_finish()
		return true

	var target: Dictionary = _waypoints[_index]
	var target_pos: Vector4 = target["pos"]
	var here: Vector4 = _player.global_position

	# World-space direction, expressed in the player's local frame so the
	# movement ACTIONS are the thing being driven.
	var to_target := Vector4(target_pos.x - here.x, 0.0, target_pos.z - here.z, 0.0)
	var basis: Projection = _player.global_basis
	var local := Vector4(
			to_target.dot(basis.x), 0.0, to_target.dot(basis.z), 0.0).normalized()

	var feet: float = here.y - 0.875
	var needs_height: bool = (target["top"] - feet) > 0.05
	var flat_distance: float = Vector2(to_target.x, to_target.z).length()
	_drive(local, needs_height and flat_distance < 3.0 and _player.is_on_floor())

	_elapsed += delta
	_sample_timer += delta
	if _sample_timer >= 1.0:
		var moved: float = (here - _last_sample).length()
		_stuck_for = _stuck_for + 1.0 if moved < STUCK_DISTANCE else 0.0
		_last_sample = here
		_sample_timer = 0.0

	if absf(feet - target["top"]) < 0.45 and flat_distance < 3.4:
		print("  ok    %-26s top %6.2f  (%.1f s)" % [target["name"], target["top"], _elapsed])
		_advance()
	elif _elapsed > SECONDS_PER_WAYPOINT:
		_failures += 1
		print("  STUCK %-26s top %6.2f  player at (%.1f, %.2f, %.1f, %.1f) feet %.2f%s" % [
				target["name"], target["top"], here.x, here.y, here.z, here.w, feet,
				"  [not moving]" if _stuck_for >= 2.0 else ""])
		_shoot("stuck%02d" % _failures)
		# Lift onto the surface and carry on, so one blockage does not hide the
		# state of everything above it.
		_player.global_position = Vector4(target_pos.x, target["top"] + 0.95, target_pos.z, here.w)
		_player.linear_velocity = Vector4()
		_advance()
	return false


func _advance() -> void:
	_index += 1
	_elapsed = 0.0
	_stuck_for = 0.0
	_last_sample = _player.global_position


func _shoot(tag: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		return
	_shots += 1
	var path := "res://ramon/ObstacleCourse/playtest_%s_%s.png" % [_scene_name, tag]
	image.save_png(ProjectSettings.globalize_path(path))


func _finish() -> void:
	_drive(Vector4(), false)
	if _failures == 0:
		print("\n=== WALKED THE WHOLE COURSE ===")
	else:
		print("\n=== %d BLOCKAGE(S); see playtest_*_stuck*.png ===" % _failures)
	quit(0 if _failures == 0 else 1)
