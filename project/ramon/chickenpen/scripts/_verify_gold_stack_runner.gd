extends SceneTree

## Two nuggets, and then two troughs.
##
## The rock holds six and the keeper sells six troughs, but the belt was a set of unique
## items: the second `found_azoth` hit `if items.has(...)` and was dropped on the floor.
## Silently, which is the worst part - you swung the pick, the rock gave up a nugget, and
## nothing happened. Five of the six were unreachable.

var _root: Node
var _f := 0
var _fails: Array = []


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
	var belt: Node = _root.get_node_or_null("UI/Inventory")
	var up: Node = _root.get_node_or_null("Pen/Upgrades")
	if belt == null or up == null:
		_check("the pieces are in the scene", false, "UI/Inventory / Pen/Upgrades")
		return _finish()

	print("\n--- carrying more than one nugget ---")
	belt.call("add_item", "found_azoth")
	_check("the first one lands", int(belt.call("count_of", "found_azoth")) == 1, "x1")
	belt.call("add_item", "found_azoth")
	_check("and so does the second", int(belt.call("count_of", "found_azoth")) == 2,
		"x2 - it used to be thrown away without a word")
	_check("in one slot, not two",
		(belt.get("items") as Array).count("found_azoth") == 1,
		"a stack, so it does not eat the belt")

	# Nothing else stacks. Two gauntlets would be nonsense.
	belt.call("add_item", "give_gauntlet")
	belt.call("add_item", "give_gauntlet")
	_check("but the gauntlet does not stack",
		int(belt.call("count_of", "give_gauntlet")) == 1, "one-of, as before")

	print("\n--- and both get spent ---")
	_check("the keeper takes the first", bool(up.call("buy", "feeder")), "trough 1")
	_check("and you still have one", int(belt.call("count_of", "found_azoth")) == 1,
		"x1 left on the belt")
	_check("the keeper takes the second", bool(up.call("buy", "feeder")), "trough 2")
	_check("and now the belt is empty of gold",
		not bool(belt.call("has_item", "found_azoth")), "the slot is released")
	_check("two troughs went up", int(up.call("feeder_count")) == 2,
		"%d in the field" % int(up.call("feeder_count")))
	return _finish()


func _finish() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
