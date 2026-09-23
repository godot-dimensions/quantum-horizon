extends SceneTree

## Mithra's errand, end to end, as the player actually walks it.
##
## WHAT THIS USED TO TEST IS GONE. The errand ended with her sprinting off to catch you a
## chicken and hand it over - `fetch_chicken`, `hand_over_chicken`, `mithra_leaves` - and
## this runner drove `pen_mithra_fetch_4d` directly to watch her do it. Ramon cut that
## beat: thanking somebody for returning a coin by fetching them poultry was a strange
## trade, and it made the one character who physically cannot reach the fourth direction
## better at the fourth-direction job than the player is.
##
## So the errand is now coin in, gold out, and a nudge toward the theatre. Which is worth
## testing for a reason the old shape was not: the reward is no longer a trinket. A nugget
## is `found_gold`, the same token the rock drops, and `pen_upgrades_4d` spends it on a
## feeding trough - so this errand now feeds the game's one economy instead of ending in
## an item nothing reads.

const MithraScript = preload("res://ramon/dialogue/mithra_script.gd")

var _root: Node
var _f := 0
var _fails: Array = []
var _talk: Node
var _inventory: Node
var _stage := 0
var _next := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _has(item: String) -> bool:
	return _inventory != null and bool(_inventory.call("has_item", item))


func _process(_d) -> bool:
	_f += 1
	if _f < 20:
		return false
	if _talk == null:
		_talk = _root.get_node_or_null("Systems/MithraTalk")
		_inventory = _root.get_node_or_null("Systems/Collector")
		if _inventory == null:
			_inventory = _root.get_node_or_null("UI/Inventory")
		if _talk == null or _inventory == null:
			_check("the pieces are in the scene", false, "MithraTalk / the belt")
			return _finish()
		print("\n--- the errand, as rewritten ---")
		# Both discarded names, not just the last one: she has been renamed twice and a
		# check that only knows the most recent one would miss a stray node.
		_check("the character is Mithra", _root.get_node_or_null("Mithra") != null
			and _root.get_node_or_null("Nessa") == null
			and _root.get_node_or_null("Hydra") == null, "node, driver, dialogue and tag")

		# The script itself, read rather than played - these are the claims the rewrite
		# makes, and they are the ones that would rot silently.
		var nodes: Dictionary = MithraScript.NODES
		_check("no chicken is fetched any more",
			not nodes.has("delivery") and not nodes.has("farewell"),
			"the delivery beats are gone from the script, not just unreachable")
		var fires := ""
		for key in nodes:
			fires += String((nodes[key] as Dictionary).get("do", ""))
		_check("and nothing fires the fetch", not fires.contains("fetch_chicken")
			and not fires.contains("hand_over_chicken"),
			"effects still fired: coin_hinted, take_coin, give_nugget")
		_check("she pays in gold, not in trinkets", fires.contains("give_nugget"),
			"found_gold - the same token the rock drops and the keeper spends")

		# The close has to send you to Trym and end without asking anything.
		var close: Dictionary = nodes.get("reward_close", {})
		var said := ""
		for line in (close.get("lines", []) as Array):
			said += String(line)
		_check("and she points you at the theatre on the way out",
			said.to_lower().contains("trym") and said.to_lower().contains("presentation"),
			"named in reward_close")
		_check("without waiting for an answer",
			(close.get("choices", []) as Array).is_empty() and String(close.get("goto", "x")) == "",
			"no reply list, and the conversation ends there")
		return _finish()
	return false


func _finish() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
