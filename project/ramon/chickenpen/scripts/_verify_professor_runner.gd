extends SceneTree

## The professor: is he there, does he talk, and does his script hold together?
##
## THE GRAPH CHECK IS THE ONE THAT EARNS ITS KEEP. Every `goto` and every choice names a
## node by string, so a typo is not an error - it is a conversation that silently stops.
## Nothing in the engine will ever tell you; a player finds it by picking the third reply.

const Script4 := preload("res://ramon/chickenpen/scripts/professor_script.gd")
const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	# Never takes focus, so a mouse moving over the window cannot turn its camera.
	root.unfocusable = true
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-40s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false

	print("\n--- the man ---")
	var prof: Node4D = _root.get_node_or_null("World/ProfessorPost/Professor") as Node4D
	_check("he is in the scene", prof != null, "by the hill")
	if prof == null:
		quit(1); return true
	# THE ROCK HAS GONE INTO THE HILL (28 Sept 2026), and he stands in front of the hole it
	# went into, pointing people at it - near the mouth, and clear of the rock face and the
	# hill's colliders, which a distance check alone would not prove.
	# Since 6 Oct the cave is a unit that can be moved and turned, so the mouth and the hill's
	# boxes are taken in the hill's own frame and put where the hill now stands.
	var hill = CaveHill.new()
	var hill_node: Node4D = CaveHill.node_in(prof)
	var mouth: Vector4 = CaveHill.to_world(hill_node, CaveHill.MOUTH) if hill_node != null else CaveHill.MOUTH
	var gap: float = Vector2(prof.global_position.x - mouth.x, prof.global_position.z - mouth.z).length()
	var clear := true
	for box in hill.solid_boxes():
		var at: Vector4 = CaveHill.to_local(hill_node, prof.global_position + Vector4(0.0, 0.9, 0.0, 0.0))
		var d: Vector4 = (at - box[0]).abs() - (box[1] as Vector4) * 0.5
		if d.x < 0.3 and d.y < 0.0 and d.z < 0.3 and d.w < 0.3:
			clear = false
	_check("he stands in front of the cave mouth", gap > 3.0 and gap < 9.0 and clear,
		"%.2f from the mouth, %s" % [gap, "clear of the hill" if clear else "INSIDE the hill"])
	# Rustic and mystical since 7 Oct (Ramon: "don't make the proffesor look like a typical wizard, more like brown
	# and red tones and mystical in a rustic way, maybe a hoody"): the hood up, the cape, the amber amulet, the staff
	# holding its stone; no wizard's hat, no lens. The ring at his feet is the pen's NPC marker now.
	_check("a hood up, and a cape", prof.get_node_or_null("Figure/Tunic/Head/HoodTop") != null
		and prof.get_node_or_null("Figure/Tunic/Cape") != null, "")
	_check("an amber amulet", prof.get_node_or_null("Figure/Tunic/Amulet") != null, "")
	_check("legs, no robe, no staff (7 Oct: \"give the proffesor legs, not this weird dress. remove the stick\")",
		prof.get_node_or_null("Figure/RobeLower") == null and prof.get_node_or_null("Staff") == null, "")
	_check("his ears under the hood", prof.get_node_or_null("Figure/Tunic/Head/EarL") == null, "")
	_check("no wizard's hat or lens", prof.get_node_or_null("Figure/Tunic/Head/Hat0") == null
		and prof.get_node_or_null("Figure/Tunic/Head/Lens") == null, "")
	_check("and no pick or helmet any more", prof.get_node_or_null("Pick") == null and prof.get_node_or_null("Figure/Tunic/Head/Helmet") == null, "")

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
