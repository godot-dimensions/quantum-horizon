extends SceneTree

## Checks the writing for the two things that break silently: a reply list longer than the
## budget, and a goto pointing at a node nobody wrote. Both only ever show up in play, at
## the one moment you least want to find them.

func _initialize() -> void:
	var nodes: Dictionary = KeeperScript.NODES
	var problems: Array = []
	var reachable: Dictionary = {}

	for key in nodes:
		var node: Dictionary = nodes[key]
		var choices: Array = node.get("choices", [])
		if choices.size() > 4:
			problems.append("%s offers %d replies (max 4)" % [key, choices.size()])
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
		if key == KeeperScript.START or String(key).begins_with("greet_"):
			continue
		if not reachable.has(key):
			problems.append("%s is unreachable" % key)

	print("nodes: %d   longest reply list: %d" % [nodes.size(), _widest(nodes)])
	if problems.is_empty():
		print("SCRIPT OK")
	else:
		for problem in problems:
			print("PROBLEM: %s" % problem)
	quit()


func _widest(nodes: Dictionary) -> int:
	var most: int = 0
	for key in nodes:
		most = maxi(most, (nodes[key].get("choices", []) as Array).size())
	return most
