extends SceneTree

## Settles one factual question that a code comment now depends on: if two sibling nodes
## both handle the same action in _input, and the first one to run calls
## set_input_as_handled(), does the second one still see the press?
##
## It matters because Nike's grab and his conversation both want F, and the fix written
## for that either rests on propagation order or deliberately does not.

class Watcher extends Node:
	var label: String = ""
	var consume: bool = false
	var log: Array = []

	func _input(event: InputEvent) -> void:
		if not event.is_action_pressed(&"catch_target"):
			return
		log.append(label)
		if consume:
			get_viewport().set_input_as_handled()


var _a: Watcher
var _b: Watcher
var _seen: Array = []
var _f: int = 0


func _initialize() -> void:
	var host := Node.new()
	root.add_child(host)
	_a = Watcher.new()
	_a.label = "first-sibling(consumes)"
	_a.consume = true
	_a.log = _seen
	host.add_child(_a)
	_b = Watcher.new()
	_b.label = "second-sibling"
	_b.log = _seen
	host.add_child(_b)


func _process(_d) -> bool:
	_f += 1
	if _f == 6:
		for down in [true, false]:
			var ev := InputEventAction.new()
			ev.action = &"catch_target"
			ev.pressed = down
			Input.parse_input_event(ev)
	if _f < 20:
		return false
	print("ORDER AND CONSUMPTION: %s" % str(_seen))
	print("both saw it: %s" % str(_seen.size() == 2))
	return true
