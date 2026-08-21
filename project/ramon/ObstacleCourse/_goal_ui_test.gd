extends SceneTree

## Triggers the goal directly and checks the overlay it builds.
##
## Deliberately skips the walk: at this collider count the sim runs far below
## realtime, so walking 5 m costs minutes of wall clock and tests the physics
## rather than the thing under test. The trigger is fired by hand; what is being
## checked is that the screen appears, says the right things, and appears ONCE.

var _fires: int = 0
var _goal: Area4D = null
var _player: CharacterBody4D = null
var _frames: int = 0

func _initialize() -> void:
	print("=== COMPLETION SCREEN ===")
	var scene: Node = (load("res://ramon/ObstacleCourse/w_gap.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	set_current_scene(scene)
	_player = scene.get_node_or_null(^"Player") as CharacterBody4D
	# The goal is looked up LATER, not here. Every exported setter on the builder
	# calls rebuild(), which frees and recreates its generated nodes - so a
	# reference captured during _initialize points at a discarded instance and
	# comes back as <Object#null>.

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4:
		var course: Node4D = get_root().get_child(0).get_node_or_null(^"Course") as Node4D
		if course != null:
			_goal = course.get_node_or_null(^"CourseGoal") as Area4D
		if _goal == null or _player == null:
			var course_node: Node = get_root().get_child(0).get_node_or_null(^"Course")
			if course_node != null:
				var names: Array[String] = []
				for c in course_node.get_children():
					var n := String(c.name)
					if n.begins_with("Braid") or n.begins_with("Course") or n.begins_with("WLift"):
						names.append(n)
				print("    course has: %s" % [names])
			print("  FAIL  goal=%s player=%s" % [_goal, _player])
			quit(1)
			return true
		_goal.connect("completed", func(s: float, f: int): _fires += 1)
		# Fire twice: the second must be ignored.
		_goal.emit_signal("body_entered_self", _player)
		_goal.emit_signal("body_entered_self", _player)
		return false
	if _frames < 8:
		return false

	var screen: Node = root.get_node_or_null(^"CompletionScreen")
	var texts: Array[String] = []
	if screen != null:
		var stack: Array[Node] = [screen]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.push_back(child)
				if child is Label:
					texts.append((child as Label).text)
	for t: String in texts:
		print("    %s" % t)
	print("\nfires %d (must be 1), overlay %s, labels %d" % [
			_fires, "present" if screen != null else "MISSING", texts.size()])
	if _fires == 1 and screen != null and texts.size() >= 3:
		print("=== PASS ===")
		quit(0)
	else:
		print("=== FAIL ===")
		quit(1)
	return true
