extends SceneTree

## The walkway: is it actually walkable, and is the way out off the sightline?
##
## THE RAKE IS A PICTURE AND THE STAIRCASE IS THE FLOOR. The physics here keeps boxes and
## throws every other shape away, so a tilted slab would collide as an axis-aligned brick.
## What is checked is the thing that matters: that the steps under it climb in small
## enough increments that walking up reads as a ramp rather than a wall.

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-40s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 40:
		return false
	var stage: Node4D = _root.get_node("Stage")
	var deck: MeshInstance4D = stage.get_node_or_null("Aisle") as MeshInstance4D
	var head: Vector4 = stage.call("aisle_head")
	var foot: Vector4 = stage.get("aisle_from")

	print("\n--- the walkway ---")
	_check("there is one", deck != null, "a single raked box")
	if deck == null:
		print("\n%d FAIL(s)" % _fails.size()); quit(1); return true
	# Its own +Z end should be the high end, which is the whole question about from_yz.
	var half: float = (deck.mesh as BoxTetraMesh4D).size.z * 0.5
	var far: Vector4 = deck.global_position + deck.global_basis * Vector4(0, 0, half, 0)
	var near: Vector4 = deck.global_position - deck.global_basis * Vector4(0, 0, half, 0)
	_check("it is raked the right way up", far.y > near.y + 0.5,
		"far end y %.2f, near end y %.2f" % [far.y, near.y])
	_check("and it runs from the floor to the head", near.y < 0.35 and far.y > 1.2,
		"%.2f up to %.2f" % [near.y, far.y])

	# The steps. Sorted along the aisle, each rise is what a foot has to clear.
	var floor_body: StaticBody4D = stage.get_node("Floor") as StaticBody4D
	var tops: Array[Vector2] = []
	for child in floor_body.get_children():
		var shape := child as CollisionShape4D
		if shape == null or shape.shape == null:
			continue
		var box := shape.shape as BoxShape4D
		if box == null or absf(box.size.y - 0.6) > 0.01:
			continue
		var along: float = Vector2(shape.position.x - foot.x,
			shape.position.z - foot.z).length()
		tops.append(Vector2(along, shape.position.y + box.size.y * 0.5))
	tops.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	_check("it is a staircase underneath", tops.size() >= 8, "%d steps" % tops.size())
	var worst: float = 0.0
	for i in range(1, tops.size()):
		worst = maxf(worst, absf(tops[i].y - tops[i - 1].y))
	_check("with a rise a foot can clear", worst < 0.12,
		"biggest single step %.3f m" % worst)
	# The steps have to be level with the DECK, not with the line it was laid out along,
	# or walking up it means walking shin-deep through it.
	var deck_top: float = near.y + (deck.mesh as BoxTetraMesh4D).size.y * 0.5 + 0.06
	_check("and its steps level with the deck", absf(tops[0].y - deck_top) < 0.12,
		"first step top %.2f, deck surface %.2f" % [tops[0].y, deck_top])
	var stood: Node4D = _root.get_node("Player") as Node4D
	_check("the player is put down on it, not in it",
		float(stage.call("aisle_gap", stood.global_position)) < float(stage.get("aisle_width")) * 0.5,
		"%.1f m from the walkway's centre line"
			% float(stage.call("aisle_gap", stood.global_position)))

	print("\n--- the way out ---")
	var exit: Node4D = _root.get_node("ExitArch")
	var player: Node4D = _root.get_node("Player")
	_check("it stands at the head of the walkway",
		Vector2(exit.global_position.x - head.x,
			exit.global_position.z - head.z).length() < 0.6,
		"%.1f m from the top" % Vector2(exit.global_position.x - head.x,
			exit.global_position.z - head.z).length())
	# The camera sits behind the player along +Z. Anything within a few metres of that
	# line, behind them, is parked in every shot of the stage.
	var behind: Vector4 = exit.global_position - player.global_position
	_check("and it is NOT behind the player's shoulder",
		absf(behind.x) > 4.0 or behind.z < 0.0,
		"%.1f m to the side, %.1f m back" % [behind.x, behind.z])
	# Seats were actually removed, rather than the aisle happening to miss them all: a
	# full house is tiers x seats_per_tier, minus whatever falls off the disc.
	var seated: int = stage.get_node("House").get_child_count() / 2
	var full: int = int(stage.get("tiers")) * int(stage.get("seats_per_tier"))
	_check("the seats got out of its way", seated < full,
		"%d of a possible %d - the rest are the aisle" % [seated, full])
	var blocking: int = 0
	for child in stage.get_node("House").get_children():
		if float(stage.call("aisle_gap", (child as Node4D).position)) \
				< float(stage.get("aisle_width")) * 0.5:
			blocking += 1
	_check("and none are left standing in it", blocking == 0,
		"%d seats inside the walkway" % blocking)
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
