extends SceneTree

## The interior shot: walk up to Trym, open the conversation, and let the camera and the
## step-inside settle before looking. Also one frame of the shed closed up, from outside.

var _root: Node
var _player: Node4D
var _talk: DialoguePlayer4D
var _f: int = 0
var _stage: int = 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root
	_player = _root.get_node("Player")
	_talk = _root.get_node("Systems/TrymTalk")


func _process(_d) -> bool:
	_f += 1
	match _stage:
		0:
			if _f == 6:
				var eye := Vector4(-4.0, 4.0, -7.0, 0.0)
				_player.global_position = eye
				_player.global_basis = Basis4D.looking_at(Vector4(-10.0, 1.2, -14.0, 0.0) - eye)
				_player.linear_velocity = Vector4.ZERO
			if _f == 34:
				_save("shed_outside")
				_stage = 1
		1:
			if _f == 40:
				# Level the body again: the exterior shot aimed it with Basis4D.looking_at,
				# which leaves a roll, and the interior frames came out tilted because of it.
				_player.global_basis = Projection.IDENTITY
				_player.global_position = Vector4(-10.0, 1.2, -12.4, 0.0)
				_player.linear_velocity = Vector4.ZERO
			if _f == 62:
				for down in [true, false]:
					var ev := InputEventAction.new()
					ev.action = &"catch_target"
					ev.pressed = down
					Input.parse_input_event(ev)
				_stage = 2
		2:
			if _f == 130:
				print("talking: %s" % _talk.is_running())
				var driver: Node = _root.get_node("Systems/TrymDriver")
				print("can talk: %s   player at %s" % [driver.call("_can_talk"), _player.global_position])
				_save("shed_interior")
				return true
			if _f > 300:
				return true
	return false


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/%s.png" % name)
	print("SAVED %s" % name)
