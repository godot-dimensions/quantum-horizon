extends SceneTree

## H hides the controls card - and leaves a small chip in its corner saying how to get it
## back, which is the part Trym asked for. Then H again puts the card back and the chip away.

var _room: Node
var _f := 0
var _fails := 0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", what, detail])


func _press(card: Node) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_H
	ev.pressed = true
	card.call("_unhandled_input", ev)


func _process(_d: float) -> bool:
	_f += 1
	if _f < 20:
		return false
	var card: Control = null
	for n in _room.find_children("*", "Control", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("pen_controls_4d.gd"):
			card = n
	var hint: Control = card.get_parent().get_node_or_null("ControlsHint") as Control if card else null
	_check("the card is up to begin with", card != null and card.visible, "")
	_check("with its hint made and put away", hint != null and not hint.visible, "")
	if card == null or hint == null:
		return _done()
	_press(card)
	_check("H hides the card", not card.visible, "")
	_check("and leaves the hint in its corner", hint.visible, "\"%s\"" % hint.text.strip_edges())
	_press(card)
	_check("H again brings the card back", card.visible, "")
	_check("and takes the hint away", not hint.visible, "")
	return _done()


func _done() -> bool:
	print("\n%d FAIL(s)" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
