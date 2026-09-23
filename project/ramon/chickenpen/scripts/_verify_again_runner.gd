extends SceneTree

## The round ends, and five seconds later you are asked whether you want another one.

var _root: Node
var _f := 0
var _fails: Array = []
var _again: Control
var _game: Node
var _stage := 0
var _mark := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 30:
		return false
	if _again == null:
		_again = _root.get_node_or_null("UI/Again") as Control
		_game = _root.get_node_or_null("Systems/Game")
		if _again == null or _game == null:
			_check("the pieces are in the scene", false, "UI/Again / Systems/Game")
			return _finish()
		print("\n--- ask again ---")
		_check("nothing is asked before the round ends", not _again.visible,
			"no panel while you are still catching chickens")
		_check("and it is listening for the end",
			_game.is_connected("completed", Callable(_again, "_on_completed")),
			"Systems/Game -> UI/Again")
		# A second of waiting, not five, or this test is a third of a minute of nothing.
		_again.set("after_seconds", 1.0)
		_game.emit_signal("completed")
		_check("the question waits", not _again.visible,
			"the confetti gets the ending to itself first")
		_mark = _f + 400
		_stage = 1
		return false

	match _stage:
		1:
			if _again.visible:
				_check("then arrives on its own", true,
					"%.1f s after the last chicken went in" % float(_again.get("after_seconds")))
				_stage = 2
			elif _f >= _mark:
				_check("then arrives on its own", false, "nothing came up")
				return _finish()
		2:
			# N is a real answer: it goes away and it stays away, including if the game
			# announced completion twice.
			_press(KEY_N)
			_again.call("_on_completed")
			_mark = _f + 200
			_stage = 3
		3:
			if _f >= _mark:
				_check("N puts it away and keeps it away", not _again.visible,
					"the level is yours again, and it does not nag")
				# And Y restarts. Driven through the same key rather than by calling
				# restart(), because the key is the part that could rot.
				_again.call("reset")
				_again.set("after_seconds", 0.0)
				_again.call("_on_completed")
				_mark = _f + 120
				_stage = 4
		4:
			if _f >= _mark:
				if not _again.visible:
					_check("and Y starts the round over", false, "it never came back")
					return _finish()
				_press(KEY_Y)
				_mark = _f + 120
				_stage = 5
		5:
			if _f >= _mark:
				_check("and Y starts the round over",
					not _again.visible and not bool(_game.get("_finished")),
					"panel gone, the game is running again")
				return _finish()
	return false


func _press(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
	# Delivered straight to the handler as well. The dummy driver does not always run a
	# parsed event all the way out to _unhandled_input, and the point of this test is the
	# handler, not Godot's input plumbing.
	var ev2 := InputEventKey.new()
	ev2.keycode = code
	ev2.pressed = true
	_again.call("_unhandled_input", ev2)


func _finish() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
