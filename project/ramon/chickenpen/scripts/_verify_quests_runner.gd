extends SceneTree

## The checklist ticks when the world changes, and only then.
##
## It reads every fact from the system that owns it, so the test changes the facts the way
## play would - an item on the belt, Mithra's driver told she has her watch back, a visit
## recorded - and asks whether the right line ticked. Then a full restart has to clear it.

## By path, not by class_name: a new class_name is only registered when the editor scans
## the project, so a headless run on a fresh checkout would not know it.
const QUESTS := preload("res://ramon/chickenpen/scripts/pen_quests_4d.gd")

var _room: Node
var _q: Node
var _f := 0
var _fails := 0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", what, detail])


func _done_for(text_start: String) -> Variant:
	for row in _q.get("_rows"):
		if String(row[0]).begins_with(text_start):
			return bool(row[1])
	return null


func _process(_d: float) -> bool:
	_f += 1
	if _f == 20:
		_q = _room.get_node_or_null("UI/Quests")
		_check("the checklist is in the scene", _q != null, "UI/Quests")
		if _q == null:
			return _done()
		_q.call("_poll")
		var rows: Array = _q.get("_rows")
		_check("with a line for everything there is to do", rows.size() == 7, "%d lines" % rows.size())
		_check("nothing is ticked at the start", _done_for("Find Mithra") == false
			and _done_for("Give it back") == false and _done_for("Find the way") == false, "")
		# The watch reaches the belt.
		_room.get_node("UI/Inventory").call("add_item", "found_watch")
		_q.call("_poll")
		_check("finding the watch ticks its line", _done_for("Find Mithra") == true, "")
		_check("but not the handing back", _done_for("Give it back") == false, "")
		# And goes back to her.
		_room.get_node("Systems/MithraDriver").set("_gave_watch", true)
		_q.call("_poll")
		_check("giving it back ticks that one", _done_for("Give it back") == true, "")
		# A visit, recorded the way the cave records it.
		QUESTS.mark_visited("cave")
		_q.call("_poll")
		_check("a visit to the hill ticks it", _done_for("Find the way") == true, "")
		_check("and nothing else it should not", _done_for("Try the shooting") == false, "")
		# The full restart puts the run back.
		_q.call("reset")
		_check("a restart clears the visits", _done_for("Find the way") == false, "")
		return _done()
	return false


func _done() -> bool:
	print("\n%d FAIL(s)" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
