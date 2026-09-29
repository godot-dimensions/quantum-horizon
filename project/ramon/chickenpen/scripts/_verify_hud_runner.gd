extends SceneTree

## The two corners of the HUD, and a restart that actually restarts.

var _root: Node
var _f := 0
var _fails: Array = []
var _card: Control
var _belt: Control
var _game: Node
var _player: Node4D
var _stage := 0
var _mark := 0
var _moved_to: Vector4


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
	if _f < 40:
		return false
	if _card == null:
		_card = _root.get_node_or_null("UI/InfoCard") as Control
		_belt = _root.get_node_or_null("UI/Inventory") as Control
		_game = _root.get_node_or_null("Systems/Game")
		_player = _root.get_node_or_null("Player") as Node4D
		if _card == null or _belt == null or _game == null or _player == null:
			_check("the pieces are in the scene", false, "InfoCard / Inventory / Game / Player")
			return _finish()

		print("\n--- the readouts sit on something now ---")
		var objective: Label = _root.get_node("UI/Objective") as Label
		_check("the card found the readouts", int(_card.get("_labels").size()) >= 6,
			"%d rows behind it" % _card.get("_labels").size())
		_check("and it is sized to the text, not the screen",
			_card.call("_measure").size.x > 10.0
				and _card.call("_measure").size.x < objective.size.x,
			"%.0f px wide against a Label authored at %.0f"
				% [_card.call("_measure").size.x, objective.size.x])
		# It has to be UNDER them, or it is a grey rectangle over the objective.
		_check("it draws behind them, not over them",
			_root.get_node("UI").get_children()[0] == _card,
			"first child of UI")
		_check("and the text matches the other corner",
			objective.has_theme_font_size_override("font_size"),
			"restyled to %d, like the controls card" % int(_card.get("text_size")))

		print("\n--- and the belt is bigger ---")
		_check("the slots grew", float(_belt.get("slot_size")) > 54.0,
			"%.0f, up from 54" % float(_belt.get("slot_size")))
		var slot: Rect2 = _belt.call("_slot_rect", 0)
		_check("and they still fit on the screen",
			slot.position.x >= 0.0 and slot.end.y <= _belt.get_viewport_rect().size.y,
			"first slot at %.0f, %.0f" % [slot.position.x, slot.position.y])

		print("
--- and it does not twitch ---")
		var obj: Label = _root.get_node("UI/Objective") as Label
		var prog: Label = _root.get_node("UI/Progress") as Label
		var hint: Label = _root.get_node("UI/Hint") as Label
		# A row in the MIDDLE goes quiet. Sized to whatever had text, the panel used to
		# keep its height and punch a hole through itself; packed, the rows below close up
		# and it simply gets one row shorter.
		obj.text = "Nine chickens are loose."
		prog.text = "Chickens returned: 0/9"
		hint.text = "a hint"
		var with_hint: float = (_card.call("_measure") as Rect2).size.y
		var below_before: float = prog.position.y
		hint.text = ""
		var without: float = (_card.call("_measure") as Rect2).size.y
		_check("a row going quiet shortens the card",
			without < with_hint
				and absf(with_hint - without - float(_card.get("row_height"))) < 0.5,
			"%.0f px against %.0f - one row shorter, not a hole" % [without, with_hint])
		_check("and the rows below it close up", prog.position.y <= below_before,
			"packed from the top, so nothing below a silent row is stranded")
		# The frame counter is the widest line and its last number changes twice a second.
		var fps: Label = _root.get_node("UI/Fps") as Label
		fps.text = "60 fps    worst 184 ms"
		_card.call("_process", 0.016)
		var wide: float = (_card.get("_box") as Rect2).size.x
		fps.text = "60 fps    worst   9 ms"
		_card.call("_process", 0.016)
		_check("and the panel does not snap narrower",
			(_card.get("_box") as Rect2).size.x > wide - 5.0,
			"eases in at %.0f px a second instead of stepping"
				% float(_card.get("shrink_rate")))
		print("\n--- ctrl+R means it ---")
		# Walk away, turn round, pick something up, then restart.
		_moved_to = Vector4(-14.0, 1.2, 8.0, 2.5)
		_player.global_position = _moved_to
		_root.get_node("UI/Inventory").call("add_item", "found_azoth")
		_stage = 1
		_mark = _f + 10
		return false

	match _stage:
		1:
			if _f >= _mark:
				# X, Z AND W, NOT Y. He is a CharacterBody4D standing in gravity, so
				# between being put down and being looked at he has fallen a few
				# centimetres towards the floor. Asserting on the height asserts that
				# gravity does not work.
				_check("you really are somewhere else", _flat(_player.position, _moved_to),
					"%.1f, %.1f, %.1f, w %.1f" % [_player.global_position.x,
						_player.global_position.y, _player.global_position.z,
						_player.global_position.w])
				_game.call("restart")
				_stage = 2
				_mark = _f + 10
		2:
			if _f >= _mark:
				# The authored spawn is (4.6, 1.2, -2, 0); read rather than typed, so
				# moving him in the editor moves what this expects.
				var spawn: Array = _game.get("_spawns")[NodePath("../../Player")]
				_check("and the restart puts you back at the spawn",
					_flat(_player.position, spawn[0]),
					"back at %.1f, %.1f, %.1f, w %.1f" % [_player.position.x,
						_player.position.y, _player.position.z, _player.position.w])
				_check("with your pockets emptied",
					not bool(_root.get_node("UI/Inventory").call("has_item", "found_azoth")),
					"the nugget is gone, and so is the trough it bought")
				_check("and the slice brought back to flat",
					float(_root.get_node("Player/CameraRig").get("_homing")) > 0.0,
					"the dial is coming home, the same way plain R does it")
				return _finish()
	return false


## Same place on the floor, and the same slice. Height is gravity's business.
func _flat(a: Vector4, b: Vector4) -> bool:
	return absf(a.x - b.x) < 0.05 and absf(a.z - b.z) < 0.05 and absf(a.w - b.w) < 0.05


func _finish() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
