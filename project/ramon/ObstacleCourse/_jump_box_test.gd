extends SceneTree

## Which boxes can actually be jumped onto? Real input, real controller, renderer
## attached. One question, answered per box height.
##
## Reference numbers to judge the result against, both measured earlier:
##   step-up allowance 0.70 m - anything at or under this is WALKED, not jumped
##   jump apex         1.03 m - the absolute ceiling, before landing margin
##
## So the expected shape of the answer is: low box walked, middle box jumped,
## tall box refused. If that is not what comes back, the controller and not the
## level is the thing to look at.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/ObstacleCourse/_jump_box_test.gd

const SCENE := "res://ramon/ObstacleCourse/w_gap.tscn"
const WARMUP_FRAMES := 30

## Long enough for a run-up and several attempts at one box.
const SECONDS_PER_BOX := 7.0

const STEP_UP_ALLOWANCE := 0.7
const JUMP_APEX := 1.033
const HALF_HEIGHT := 0.875

var _player: CharacterBody4D = null
var _course: Node4D = null
var _boxes: Array = []
var _index: int = 0
var _frames: int = 0
var _elapsed: float = 0.0
var _best_feet: float = -1e9
var _results: Array = []


func _initialize() -> void:
	print("=== JUMP BOXES: what can be climbed? ===")
	print("    step-up allowance %.2f m, jump apex %.2f m\n" % [STEP_UP_ALLOWANCE, JUMP_APEX])
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


func _collect_boxes() -> void:
	for child in _course.get_children():
		if not String(child.name).begins_with("JumpBox_"):
			continue
		var node := child as Node4D
		var top: float = node.global_position.y
		for grandchild in child.get_children():
			var collider := grandchild as CollisionShape4D
			if collider == null:
				continue
			var box := collider.shape as BoxShape4D
			if box != null:
				top += box.size.y * 0.5
		_boxes.append({"name": String(child.name), "x": node.global_position.x, "z": node.global_position.z, "top": top})
	_boxes.sort_custom(func(a, b): return a["x"] < b["x"])
	if _boxes.is_empty():
		push_error("no JumpBox_* found - nothing to test")
		quit(1)
		return
	print("found %d boxes\n" % _boxes.size())


func _hold(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _physics_process(delta: float) -> bool:
	if _player == null or _course == null:
		push_error("scene is missing Player or Course")
		quit(1)
		return true
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	if _frames == WARMUP_FRAMES:
		_collect_boxes()
		_player.global_position = Vector4(_boxes[0]["x"] - 4.2, 1.0, _boxes[0]["z"], 0.0)
		_best_feet = _player.global_position.y - HALF_HEIGHT

	if _index >= _boxes.size():
		_report()
		return true

	var box: Dictionary = _boxes[_index]
	var here: Vector4 = _player.global_position
	var feet: float = here.y - HALF_HEIGHT
	_best_feet = maxf(_best_feet, feet)
	_elapsed += delta

	# Run at it, and PULSE the jump. `player.gd` jumps on
	# `is_action_just_pressed`, so a key held down fires exactly one jump ever -
	# the first version held it and then reported boxes as unreachable that had
	# simply never been jumped at a second time. Pressing only while grounded
	# gives a clean press/release edge on every landing.
	var distance: float = box["x"] - here.x
	_hold(&"move_forward", distance > 0.6)
	_hold(&"move_jump", _player.is_on_floor() and distance < 1.7 and distance > -0.6)

	# Landed on top: feet AT the box's height, horizontally over it, and actually
	# supported. The tolerance is tight on purpose - at 0.25 m a 1.20 m box
	# counted as climbed when the feet only ever reached 0.96, which is how this
	# test first reported three passes and zero real climbs.
	if absf(feet - box["top"]) < 0.12 and absf(distance) < 1.0 and _player.is_on_floor():
		_record(box, true, feet)
	elif _elapsed > SECONDS_PER_BOX:
		_record(box, false, _best_feet)
	return false


func _record(box: Dictionary, landed: bool, reached: float) -> void:
	var expected: String = "walk" if box["top"] <= STEP_UP_ALLOWANCE else ("jump" if box["top"] < JUMP_APEX else "impossible")
	print("  %-11s top %.2f m -> %-8s (best feet %.2f, expected %s)" % [
			box["name"], box["top"], "ON TOP" if landed else "blocked", reached, expected])
	_results.append({"top": box["top"], "landed": landed, "expected": expected})
	_shoot("box%d" % _index)
	_index += 1
	_elapsed = 0.0
	# Reset to a clean run-up BEFORE the next box, whether or not this one was
	# climbed, so one blocked box cannot hide every result after it. Placing the
	# player relative to the next box rather than the last one matters: stepping
	# 2.6 m past a box landed it inside the following one, and with no
	# depenetration in this engine an overlapping body simply stops moving.
	if _index < _boxes.size():
		# In the boxes' own lane, not the walkway's - they sit off to one side.
		_player.global_position = Vector4(_boxes[_index]["x"] - 4.2, 1.0, _boxes[_index]["z"], 0.0)
		_player.linear_velocity = Vector4()
		_best_feet = _player.global_position.y - HALF_HEIGHT


func _shoot(tag: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path("res://ramon/ObstacleCourse/jump_%s.png" % tag))


func _report() -> void:
	_hold(&"move_forward", false)
	_hold(&"move_jump", false)
	var surprises: int = 0
	for r: Dictionary in _results:
		var should_climb: bool = r["expected"] != "impossible"
		if r["landed"] != should_climb:
			surprises += 1
	print("\n%d of %d boxes climbed" % [_results.filter(func(r): return r["landed"]).size(), _results.size()])
	if surprises == 0:
		print("=== matches the measured limits ===")
		quit(0)
	else:
		print("=== %d box(es) behaved unlike the measured limits - look at the controller ===" % surprises)
		quit(1)
