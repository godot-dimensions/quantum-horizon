extends SceneTree

## Trym never repeats himself, and the ticket he gives you on the third conversation
## actually opens the theatre.
##
## The conversation ORDER is checked by asking his driver which node it would open on,
## stepping its state the way the game would. That is the thing that broke: once the
## post-show conversation was spent, the driver fell through to greet_back, which returns
## to the original topic list - so a third visit rewound to the introduction.

const _DIR: String = "res://smoke_test_output/"

var _scene: Node
var _driver: Node
var _inv: Node
var _crossing: Node
var _f: int = 0
var _stage: int = 0
var _seen: Array = []


func _initialize() -> void:
	_scene = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_driver = _scene.get_node("Systems/TrymDriver")
	_inv = _scene.get_node("UI/Inventory")
	_crossing = _scene.get_node("Crossing")


func _process(_d) -> bool:
	_f += 1
	if _f < 25:
		return false
	match _stage:
		0:
			# Talk one: the introduction.
			_seen.append(_driver.call("_entry_node"))
			# He offers until you accept; accepting is what the invitation reports.
			_driver.call("_on_effect", "trym_invite")
			# Talk two, on coming home: the conversation about what you just watched.
			_driver.call("ask_what_you_thought")
			_seen.append(_driver.call("_entry_node"))
			# Talks three and four.
			_seen.append(_driver.call("_entry_node"))
			_seen.append(_driver.call("_entry_node"))
			print("CONVERSATION ORDER: %s" % str(_seen))
			var repeats: bool = _seen.size() != _seen.duplicate().size()
			var uniq := {}
			for n in _seen:
				uniq[n] = true
			print("no repeats: %s   ends on a non-hub node: %s" % [
				uniq.size() == _seen.size(), String(_seen[3]) == "greet_after"])
			_stage = 1
			_f = 0
		1:
			# The item itself, and using it.
			_inv.call("add_item", "rewatch_ticket")
			print("TICKET IN BELT: %s" % str(_inv.call("has_item", "rewatch_ticket")))
			_inv.set("selected", int(_inv.get("items").size()) - 1)
			_stage = 2
			_f = 0
		2:
			if _f < 6:
				return false
			print("PROMPTING: %s   (away before: %s)" % [
				str(_scene.get_node("Systems/Rewatch").get("_asking")),
				str(_crossing.call("is_away"))])
			for down in [true, false]:
				var ev := InputEventKey.new()
				ev.keycode = KEY_Y
				ev.pressed = down
				Input.parse_input_event(ev)
			_stage = 3
			_f = 0
		3:
			if _f < 30:
				return false
			print("AFTER YES: away %s   ticket still held %s" % [
				str(_crossing.call("is_away")), str(int(_inv.get("selected")) >= 0)])
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_DIR))
			var image: Image = root.get_texture().get_image()
			if image != null:
				image.save_png(_DIR + "ticket_theatre.png")
				print("SAVED ticket_theatre")
			return true
	if _f > 400:
		print("TIMED OUT in stage %d" % _stage)
		return true
	return false
