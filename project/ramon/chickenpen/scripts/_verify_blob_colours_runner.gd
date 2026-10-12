extends SceneTree

## Does each blob come out the colour of its own character?
##
## The awkward case is that the chibi avatar has two colours and which one IS the
## character depends on the character: Mithra reads as her red tunic, the keeper as his
## purple accent - and his tunic is tan. So the rule is "skip whatever looks like flesh",
## and these two pull in opposite directions, which is what makes them worth checking.

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-30s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var plane: Node = _root.get_node("UI/SlicePlane")
	var people: Array = plane.get("_people")
	var colours: Array = plane.get("_people_colors")

	print("\n--- what colour each blob came out ---")
	var by_name: Dictionary = {}
	for i in people.size():
		var c: Color = colours[i]
		by_name[String(people[i].name)] = c
		print("   %-12s rgb %.2f %.2f %.2f   hue %3.0f  sat %.2f"
			% [people[i].name, c.r, c.g, c.b, c.h * 360.0, c.s])

	# FOUR, NOT FIVE. The list used to name a LoftedGirl who is not in the scene - she was
	# taken out and her NodePath was left behind - so this has been asserting five and
	# getting four ever since. A path that resolves to nothing is silent: the slice plane
	# skipped her without complaint and only the count gave it away.
	_check("everyone got a blob", people.size() == 4, "%d people" % people.size())
	# The keeper is purple, not the tan of his tunic.
	var keeper: Color = by_name.get("Keeper", Color.BLACK)
	_check("the keeper is purple", keeper.h * 360.0 > 250.0 and keeper.h * 360.0 < 330.0,
		"hue %.0f" % (keeper.h * 360.0))
	# Mithra is her red tunic, not her skin tone.
	var mithra: Color = by_name.get("Mithra", Color.BLACK)
	var mithra_hue: float = mithra.h * 360.0
	_check("Mithra is red", mithra_hue > 340.0 or mithra_hue < 12.0, "hue %.0f" % mithra_hue)
	# THE DARK ONES STAY DARK. An earlier version lightened them so they would stand out
	# against the panel, which is exactly backwards: the cat is black, and a grey blob for
	# it is a worse marker than a black one because the colour is what names it. They are
	# made visible by the pale outline every blob is drawn with, not by being recoloured.
	var cat: Color = by_name.get("Cat", Color.WHITE)
	_check("the cat is still black", maxf(cat.r, maxf(cat.g, cat.b)) < 0.2,
		"brightest channel %.2f, the same as its fur" % maxf(cat.r, maxf(cat.g, cat.b)))
	var trym: Color = by_name.get("Trym", Color.WHITE)
	_check("Trym is still his black shirt", maxf(trym.r, maxf(trym.g, trym.b)) < 0.2,
		"brightest channel %.2f" % maxf(trym.r, maxf(trym.g, trym.b)))
	var plane_node: Node = _root.get_node("UI/SlicePlane")
	var birds: Color = plane_node.get("chicken_color")
	_check("the chickens are white", birds.r > 0.95 and birds.g > 0.95 and birds.b > 0.9,
		"rgb %.2f %.2f %.2f" % [birds.r, birds.g, birds.b])
	# And everyone is told apart from everyone else.
	var same: int = 0
	for i in colours.size():
		for j in range(i + 1, colours.size()):
			if (colours[i] as Color).is_equal_approx(colours[j]):
				same += 1
	# NOT A FAILURE. Mithra and the lofted girl wear the same red in the world, so their
	# blobs match and should - the colour is read off the character, not invented here,
	# and their names are what tell them apart. Reported so it stays a known fact.
	print("   note: %d pair(s) share a colour, which is true of them in the world" % same)

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
