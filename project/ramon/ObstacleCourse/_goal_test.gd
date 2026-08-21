extends SceneTree

## Does stepping onto the last pad actually produce a completion screen?
##
## Walks onto the goal pad, then checks three things rather than trusting the
## print: the `completed` signal fired, a CompletionScreen exists in the tree, and
## it only ever fires ONCE (the pad is broad and w-deep, so a naive trigger would
## rebuild the overlay every frame the body re-tested against it).
##
## Runs with a renderer so the screen can be grabbed and looked at.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/ObstacleCourse/_goal_test.gd

const SCENE := "res://ramon/ObstacleCourse/w_gap.tscn"
const WARMUP_FRAMES := 30
const HALF_HEIGHT := 0.875
const TIMEOUT := 12.0

var _player: CharacterBody4D = null
var _course: Node4D = null
var _goal: Area4D = null
var _frames: int = 0
var _elapsed: float = 0.0
var _fires: int = 0
var _shot: bool = false


func _initialize() -> void:
	print("=== COURSE GOAL ===")
	var packed: PackedScene = load(SCENE)
	if packed == null:
		push_error("could not load %s" % SCENE)
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	set_current_scene(scene)
	_player = scene.get_node_or_null(^"Player") as CharacterBody4D
	_course = scene.get_node_or_null(^"Course") as Node4D


func _measure() -> void:
	var pad: Node4D = _course.get_node_or_null(^"BraidEnd") as Node4D
	_goal = _course.get_node_or_null(^"CourseGoal") as Area4D
	if pad == null or _goal == null:
		push_error("no BraidEnd / CourseGoal in the room")
		quit(1)
		return
	_goal.connect("completed", _on_completed)
	var top: float = pad.global_position.y
	for child in pad.get_children():
		var collider := child as CollisionShape4D
		if collider == null:
			continue
		var box := collider.shape as BoxShape4D
		if box != null:
			top += box.size.y * 0.5
	print("goal pad at x %.1f, w %.1f, top y %.2f\n" % [pad.global_position.x, pad.global_position.w, top])
	# A short walk-on, so the trigger is entered by MOVING rather than by being
	# spawned already inside it.
	_player.global_position = Vector4(pad.global_position.x - 5.0, top + HALF_HEIGHT + 0.1,
			0.0, pad.global_position.w)
	_player.linear_velocity = Vector4()


func _on_completed(seconds: float, falls: int) -> void:
	_fires += 1
	print("  ok    signal fired: %.1f s, %d fall(s)" % [seconds, falls])


func _physics_process(delta: float) -> bool:
	if _player == null or _course == null:
		push_error("scene is missing Player or Course")
		quit(1)
		return true
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	if _frames == WARMUP_FRAMES:
		_measure()

	_elapsed += delta
	if Input.is_action_pressed(&"move_forward"):
		pass
	Input.action_press(&"move_forward")

	if _fires > 0 and not _shot:
		# Give the deferred overlay a frame to exist, then grab it.
		_shot = true
		return false
	if _shot:
		Input.action_release(&"move_forward")
		_report()
		return true
	if _elapsed > TIMEOUT:
		print("  FAIL  never reached the goal (player at x %.1f)" % _player.global_position.x)
		_report()
		return true
	return false


func _report() -> void:
	var screen: Node = root.get_node_or_null(^"CompletionScreen")
	var labels: int = 0
	if screen != null:
		var stack: Array[Node] = [screen]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.push_back(child)
				if child is Label:
					labels += 1
					print("    text: %s" % (child as Label).text)

	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path("res://ramon/ObstacleCourse/goal_screen.png"))

	var ok: bool = _fires == 1 and screen != null and labels >= 3
	print("\nfires %d (must be 1), overlay %s, labels %d" % [_fires, "present" if screen != null else "MISSING", labels])
	if ok:
		print("=== PASS: the completion screen appears, once ===")
		quit(0)
	else:
		print("=== FAIL ===")
		quit(1)
