extends SceneTree

## Checks the writing for the two things that break silently: a reply list longer than the
## budget, and a goto pointing at a node nobody wrote. Both only ever show up in play, at
## the one moment you least want to find them.

## Every character's writing, checked in one pass. A new script is one more row.
const SCRIPTS: Array = [
	{"who": "Keeper", "nodes": KeeperScript.NODES, "start": KeeperScript.START},
	{"who": "Nessa", "nodes": NessaScript.NODES, "start": NessaScript.START},
	{"who": "Trym", "nodes": TrymScript.NODES, "start": TrymScript.START},
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
		if choices.size() > 4:
			problems.append("%s offers %d replies (max 4)" % [key, choices.size()])
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
	for key in nodes:
		if key == start or String(key).begins_with("greet_"):
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
