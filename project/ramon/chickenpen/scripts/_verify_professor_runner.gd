extends SceneTree

## The professor: is he there, does he talk, and does his script hold together?
##
## THE GRAPH CHECK IS THE ONE THAT EARNS ITS KEEP. Every `goto` and every choice names a
## node by string, so a typo is not an error - it is a conversation that silently stops.
## Nothing in the engine will ever tell you; a player finds it by picking the third reply.

const Script4 := preload("res://ramon/chickenpen/scripts/professor_script.gd")

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-40s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false

	print("\n--- the man ---")
	var prof: Node4D = _root.get_node_or_null("World/Professor") as Node4D
	_check("he is in the scene", prof != null, "beside the rock")
	if prof == null:
		quit(1); return true
	var rock: Node4D = _root.get_node("World/MiningRock")
	var gap: float = Vector2(prof.global_position.x - rock.global_position.x,
		prof.global_position.z - rock.global_position.z).length()
	# BESIDE IT, NOT IN IT. The rock's solid half-width is grid * cell / 2 * box_fill,
	# which is 2.08 here - the first placement had him 2.56 from its centre and therefore
	# standing inside the boulder, which a distance check alone happily passed.
	var solid: float = float(rock.get("grid_size")) * float(rock.get("cell_size")) 		* 0.5 * float(rock.get("box_fill_fraction"))
	_check("and he is standing beside it, not in it", gap > solid + 0.6 and gap < 5.5,
		"%.2f from its centre, and it is solid to %.2f" % [gap, solid])
	_check("with a helmet on", prof.get_node_or_null("Figure/Tunic/Head/Helmet") != null,
		"and a lamp: %s" % [prof.get_node_or_null("Figure/Tunic/Head/Lamp") != null])
	_check("and a pick", prof.get_node_or_null("Pick/Collar") != null, "over his shoulder")

	print("\n--- his script ---")
	var nodes: Dictionary = Script4.NODES
	_check("it starts somewhere real", nodes.has(Script4.START),
		"START is '%s'" % Script4.START)
	var dangling: Array = []
	var reachable := {Script4.START: true}
	for key in nodes:
		var node: Dictionary = nodes[key]
		for field in ["goto", "goto_if_asked", "instead"]:
			var to: String = String(node.get(field, ""))
			if to != "" and not nodes.has(to):
				dangling.append("%s -> %s (%s)" % [key, to, field])
			elif to != "":
				reachable[to] = true
		for choice in node.get("choices", []):
			var to2: String = String((choice as Dictionary).get("goto", ""))
			if to2 != "" and not nodes.has(to2):
				dangling.append("%s -> %s (choice)" % [key, to2])
			elif to2 != "":
				reachable[to2] = true
	_check("every link goes somewhere", dangling.is_empty(),
		"dangling: %s" % [dangling] if dangling.size() > 0 else "%d nodes, all linked" % nodes.size())
	var orphans: Array = []
	for key in nodes:
		if not reachable.has(key):
			orphans.append(key)
	_check("and nothing is unreachable", orphans.is_empty(),
		"orphans: %s" % [orphans] if orphans.size() > 0 else "all %d reachable" % nodes.size())
	# Four replies maximum, the budget the keeper keeps.
	var too_many: Array = []
	for key in nodes:
		if (nodes[key] as Dictionary).get("choices", []).size() > 4:
			too_many.append(key)
	_check("no menu is longer than four", too_many.is_empty(),
		"over budget: %s" % [too_many] if too_many.size() > 0 else "the longest is four")

	print("\n--- what he opens on ---")
	var driver: Node = _root.get_node("Systems/ProfessorDriver")
	var first: String = String(driver.call("_entry_node"))
	_check("first meeting is the introduction", first == Script4.START, "'%s'" % first)
	var second: String = String(driver.call("_entry_node"))
	_check("before you have mined, he tells you how", second == "how_to_mine", "'%s'" % second)
	driver.call("note_mined")
	var third: String = String(driver.call("_entry_node"))
	_check("after you have mined, the topics open", third == "menu", "'%s'" % third)

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
