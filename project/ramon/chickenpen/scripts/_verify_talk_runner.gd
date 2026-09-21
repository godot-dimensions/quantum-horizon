extends SceneTree

## Checks the keeper conversation inside chickenpen itself: that the locator starts hidden,
## that the talk prompt appears over his head, that the catch key opens the conversation
## rather than grabbing at a chicken, and that the gauntlet switches the locator on.

var _root: Node
var _player: Node4D
var _box: DialogueBox4D
var _talk: DialoguePlayer4D
var _locator: Label
var _radar: Control
var _f: int = 0
var _stage: int = 0
var _next: int = 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root
	_player = _root.get_node("Player")
	_box = _root.get_node("UI/TalkBox")
	_talk = _root.get_node("Systems/Talk")
	_locator = _root.get_node("UI/Locator")
	_radar = _root.get_node("UI/Radar")


func _process(_d) -> bool:
	_f += 1
	match _stage:
		0:
			if _f == 10:
				# Stand just in front of him. He is at (2.3, 0, -4.3).
				_player.global_position = Vector4(2.3, 1.2, -2.7, 0.0)
				_player.linear_velocity = Vector4.ZERO
			if _f == 45:
				var driver: Node = _root.get_node("Systems/TalkDriver")
				print("locator hidden at start: %s   radar hidden: %s   can_talk: %s" % [
					not _locator.visible, not _radar.visible, driver.call("_can_talk")])
				_save("pen_01_prompt")
				_press(true)
				_stage = 1
				_next = _f + 2
		1:
			if _f >= _next:
				_press(false)
				_stage = 2
				_next = _f + 26
		2:
			if _f >= _next:
				print("conversation running: %s" % _talk.is_running())
				_save("pen_02_opening")
				_stage = 3
				_next = _f + 4
		3:
			if _box.has_choices():
				_stage = 4
				_next = _f + 22
			elif _f >= _next:
				_box.finish_line()
				_talk.call("_tap")
				_next = _f + 5
			if _f > 900:
				_save("pen_timeout")
				return true
		4:
			if _f >= _next:
				print("locator on after the gauntlet: %s   radar on: %s" % [_locator.visible, _radar.visible])
				_save("pen_03_choices")
				return true
	return false


func _press(down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = &"catch_target"
	ev.pressed = down
	Input.parse_input_event(ev)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/%s.png" % name)
	print("SAVED %s" % name)
