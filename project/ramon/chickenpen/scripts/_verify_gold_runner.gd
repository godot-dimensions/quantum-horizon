extends SceneTree

## Is there gold in the rock, is it hidden until you dig, and does digging find it?
##
## The whole point of the arrangement is that VoxelMining knows nothing about gold, so the
## only thing tying the two together is the pickaxe's signal - which makes it the thing
## worth testing. A seam that is visible from the start, or one that never appears, both
## look like "no gold" from outside.

var _root: Node
var _f := 0
var _step := 0
var _fails: Array = []
var _gold: Node4D
var _pick: Node
var _rock: Node4D
var _player: Node4D


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _showing() -> int:
	var n: int = 0
	for orb in _gold.get_children():
		if (orb as Node4D).visible:
			n += 1
	return n


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _gold == null:
		_gold = _root.get_node_or_null("World/RockGold") as Node4D
		if _gold == null:
			print("   FAIL there is no seam in the rock")
			quit(1); return true
		_pick = _root.get_node("Systems/Pickaxe")
		_rock = _root.get_node("World/MiningRock")
		_player = _root.get_node("Player")
		print("\n   the seam holds %d nuggets" % _gold.get_child_count())
		_check("it is buried to start with", _showing() == 0,
			"%d of %d showing" % [_showing(), _gold.get_child_count()])
		_check("and none is in the belt yet",
			not bool(_root.get_node("UI/Inventory").call("has_item", "found_gold")),
			"belt: %s" % [_root.get_node("UI/Inventory").get("items")])
		return false

	if _step == 0:
		# Dig straight at each nugget in turn, the way the pickaxe does.
		for orb in _gold.get_children():
			_pick.emit_signal("mined", (orb as Node4D).global_position,
				float(_rock.get("mining_radius_meters")))
		_step = 1
		return false

	if _step == 1:
		_check("digging uncovers them", _showing() == _gold.get_child_count(),
			"%d of %d showing after a swing at each"
				% [_showing(), _gold.get_child_count()])
		# Now walk onto one.
		var first: Node4D = _gold.get_child(0) as Node4D
		_player.position = first.global_position - Vector4(0.0, 0.4, 0.0, 0.0)
		_step = 2
		_f = 0
		return false

	if _f < 90: return false
	_check("walking into one pockets it",
		bool(_root.get_node("UI/Inventory").call("has_item", "found_gold")),
		"belt: %s" % [_root.get_node("UI/Inventory").get("items")])
	_check("and the rock itself is untouched by all this",
		_rock.get_node("Ground") != null and _rock.get_node("Voxels") != null,
		"the block still has its mesh and its colliders")
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
