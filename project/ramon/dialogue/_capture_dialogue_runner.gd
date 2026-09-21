extends SceneTree

## Walks the test world through the conversation and saves frames, so the tag, the panel,
## the reply list and the echoed player line can be looked at rather than assumed.

var _root: Node
var _walker: Node4D
var _box: DialogueBox4D
var _talk: DialoguePlayer4D
var _f: int = 0
var _stage: int = 0
var _next: int = 0


func _initialize() -> void:
	_root = load("res://ramon/dialogue/dialogue_test.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root
	_walker = _root.get_node("Walker")
	_box = _root.get_node("UI/Box")
	_talk = _root.get_node("Player")


func _process(_d) -> bool:
	_f += 1
	match _stage:
		0:
			if _f == 6:
				_walker.position = Vector4(0.0, 0.0, -2.4, 0.0)
			if _f == 30:
				_save("tag_01_in_range")
				_walker.position = Vector4(0.0, 0.0, -2.4, 2.6)
				_stage = 1
				_next = _f + 30
		1:
			# Stepped off his slice: the tag should be gone and the keeper faded.
			if _f >= _next:
				_save("tag_02_off_slice")
				_walker.position = Vector4(0.0, 0.0, -2.4, 0.0)
				_stage = 2
				_next = _f + 20
		2:
			if _f >= _next:
				_talk.begin("intro")
				_stage = 3
				_next = _f + 22
		3:
			if _f >= _next:
				_save("dlg_01_opening")
				_stage = 4
				_next = _f + 4
		4:
			if _box.has_choices():
				_stage = 5
				_next = _f + 24
			elif _f >= _next:
				_talk.call("_tap")
				_next = _f + 5
		5:
			if _f >= _next:
				_save("dlg_02_choices")
				_box.pick_index(0)
				_stage = 6
				_next = _f + 18
		6:
			# The player's own reply, echoed back in its own colour before he answers.
			if _f >= _next:
				_save("dlg_03_echo")
				_stage = 7
				_next = _f + 6
		7:
			if _box.has_choices():
				_save("dlg_04_hub")
				return true
			if _f >= _next:
				_box.finish_line()
				_talk.call("_tap")
				_next = _f + 6
			if _f > 1200:
				_save("dlg_04_timeout")
				return true
	return false


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/%s.png" % name)
	print("SAVED %s" % name)
