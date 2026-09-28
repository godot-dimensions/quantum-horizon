extends SceneTree

## Checks the writing for the two things that break silently: a reply list longer than the
## budget, and a goto pointing at a node nobody wrote. Both only ever show up in play, at
## the one moment you least want to find them.

## Every character's writing, checked in one pass. A new script is one more row.
const _Nike = preload("res://ramon/dialogue/nike_script.gd")
const _Professor = preload("res://ramon/chickenpen/scripts/professor_script.gd")
const _Hale = preload("res://ramon/chickenpen/cave/cave_miner_script.gd")

const SCRIPTS: Array = [
	{"who": "Keeper", "nodes": KeeperScript.NODES, "start": KeeperScript.START},
	{"who": "Mithra", "nodes": MithraScript.NODES, "start": MithraScript.START},
	{"who": "Trym", "nodes": TrymScript.NODES, "start": TrymScript.START},
	{"who": "Nike", "nodes": _Nike.NODES, "start": _Nike.START},
	{"who": "Professor", "nodes": _Professor.NODES, "start": _Professor.START},
	{"who": "Hale", "nodes": _Hale.NODES, "start": _Hale.START},
]


func _initialize() -> void:
	var bad: int = 0
	for entry in SCRIPTS:
		bad += _check(String(entry["who"]), entry["nodes"], String(entry["start"]))
	print("ALL SCRIPTS OK" if bad == 0 else "%d problem(s)" % bad)
	quit()


func _check(who: String, nodes: Dictionary, start: String) -> int:
	var problems: Array = []
	var reachable: Dictionary = {}

	for key in nodes:
		var node: Dictionary = nodes[key]
		var choices: Array = node.get("choices", [])
		# POST_SHOW IS ALLOWED NINE, and it is the only node that is. It is a spectrum
		# rather than a menu - seven positions from "you've got a platform" to "it's a tech
		# demo looking for a game", plus the ask and the way out - so the player is picking
		# a STANCE, and a stance with four options on it is a leading question.
		#
		# The exemption was removed for a day, along with the node itself, and it should not
		# have been: the instruction was that the player should not be FORCED through
		# multiple choice, not that the stakeholder answers should go. Named explicitly so
		# that it cannot spread to any other node by accident.
		var cap: int = 9 if key == "post_show" else 4
		if choices.size() > cap:
			problems.append("%s offers %d replies (max %d)" % [key, choices.size(), cap])
		# Every list must offer a way out, marked `leave`. A conversation you can be held
		# inside is the thing players remember, and never fondly.
		if not choices.is_empty():
			var can_leave: bool = false
			for choice in choices:
				if bool(choice.get("leave", false)) or bool(choice.get("back", false)):
					can_leave = true
			if not can_leave:
				problems.append("%s offers no way out (mark one reply leave, or back)" % key)
		for target_key in ["goto", "instead", "goto_if_asked"]:
			if node.has(target_key):
				var target: String = String(node[target_key])
				if target != "" and not nodes.has(target):
					problems.append("%s %s -> '%s', which does not exist" % [key, target_key, target])
				elif target != "":
					reachable[target] = true
		for choice in choices:
			var target: String = String(choice.get("goto", ""))
			if target != "" and not nodes.has(target):
				problems.append("%s reply '%s' -> '%s', which does not exist" % [key, choice["text"], target])
			elif target != "":
				reachable[target] = true

	# The greet_ nodes are entry points the GAME chooses by state, not destinations any
	# reply points at, so being unreached from START is correct for them and only for them.
	#
	# AND ONE MORE KIND: a node some other scene reads out of this file directly. The
	# theatre has no dialogue player - it delivers the whole presentation through its own
	# caption band - so `after_show_walk` is pulled out of TrymScript.NODES by
	# theatre_after_4d and shown there. The writing stays in the writing file, which is
	# what this check is protecting; it just is not reached by a `goto`. Named here one by
	# one rather than by prefix, so an actually-orphaned node still fails.
	const READ_FROM_OUTSIDE: Array[String] = []
	for key in nodes:
		if key == start or String(key).begins_with("greet_") or READ_FROM_OUTSIDE.has(key):
			continue
		if not reachable.has(key):
			problems.append("%s is unreachable" % key)

	print("%s: %d nodes, longest reply list %d" % [who, nodes.size(), _widest(nodes)])
	for problem in problems:
		print("PROBLEM (%s): %s" % [who, problem])
	return problems.size()


func _widest(nodes: Dictionary) -> int:
	var most: int = 0
	for key in nodes:
		most = maxi(most, (nodes[key].get("choices", []) as Array).size())
	return most
