extends SceneTree

## Walks Mithra's whole quest: that she can be addressed, that she stops searching to talk,
## that turning up with her coin opens a different conversation, and that handing it over
## empties the coin slot and fills the egg one.

var _root: Node
var _player: Node4D
var _mithra: Node4D
var _talk: DialoguePlayer4D
var _box: DialogueBox4D
var _inventory: Node
var _driver: Node
var _f: int = 0
var _stage: int = 0
var _next: int = 0
var _next_shot: int = 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root
	_player = _root.get_node("Player")
	_mithra = _root.get_node("Mithra")
	_talk = _root.get_node("Systems/MithraTalk")
	_box = _root.get_node("UI/MithraBox")
	_inventory = _root.get_node("UI/Inventory")
	_driver = _root.get_node("Systems/MithraDriver")


func _process(_d) -> bool:
	_f += 1
	match _stage:
		0:
			if _f == 12:
				_stand_by_her()
			if _f == 40:
				print("can talk to her: %s" % _driver.call("_can_talk"))
				_press()
				_stage = 1
				_next = _f + 24
		1:
			if _f >= _next:
				print("talking: %s   she stopped searching: %s" % [
					_talk.is_running(), _mithra.get("halted")])
				_save("mithra_01_opening")
				_stage = 2
				_next = _f + 4
		2:
			# Through to her first set of replies, then take the "I'll look for it" branch.
			if _box.has_choices() and _next_shot == 0:
				_next_shot = _f + 12
			if _next_shot > 0 and _f >= _next_shot:
				var sp: Control = _box.get_node("Speech")
				var ch: Control = _box.get_node("Choices")
				print("speech %s %s   choices %s %s" % [sp.position, sp.size, ch.position, ch.size])
				_save("mithra_02_choices")
				_box.pick_index(1)
				_stage = 3
				_next = _f + 8
			elif _f >= _next:
				_box.finish_line()
				_talk.call("_tap")
				_next = _f + 5
			if _f > 700:
				print("PROBLEM: never reached her replies")
				return true
		3:
			# Tap through the rest of her answer. Waiting a fixed number of frames was the
			# first version of this and it pressed on mid-sentence, which made her look
			# stuck when she was only still speaking.
			if not _talk.is_running():
				print("she walks again after it ends: %s" % (not bool(_mithra.get("halted"))))
				# Now turn up carrying the coin, as if it had been found off-slice.
				_inventory.call("add_item", "found_coin")
				_stand_by_her()
				_stage = 4
				_next = _f + 10
			elif _f >= _next:
				_box.finish_line()
				_talk.call("_tap")
				_next = _f + 5
		4:
			if _f >= _next:
				_press()
				_stage = 5
				_next = _f + 20
		5:
			if _box.has_choices():
				_save("mithra_03_has_coin")
				_box.pick_index(0)
				_stage = 6
				_next = _f + 8
			elif _f >= _next:
				_box.finish_line()
				_talk.call("_tap")
				_next = _f + 5
			if _f > 1400:
				print("PROBLEM: she never noticed the coin")
				return true
		6:
			# Walk the handover out to the end and check what changed hands.
			if not _talk.is_running():
				print("coin gone from the belt: %s   egg on it: %s" % [
					not bool(_inventory.call("has_item", "found_coin")),
					_inventory.call("has_item", "found_egg")])
				_save("mithra_04_reward")
				return true
			if _f >= _next:
				_box.finish_line()
				_talk.call("_tap")
				_next = _f + 5
			if _f > 2000:
				print("PROBLEM: the handover never finished")
				return true
	return false


## She roams, so stand where she actually is rather than where the scene put her.
func _stand_by_her() -> void:
	var here: Vector4 = _mithra.global_position
	_player.global_position = Vector4(here.x + 1.4, 1.2, here.z + 0.6, here.w)
	_player.linear_velocity = Vector4.ZERO


func _press() -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"catch_target"
		ev.pressed = down
		Input.parse_input_event(ev)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/%s.png" % name)
	print("SAVED %s" % name)
