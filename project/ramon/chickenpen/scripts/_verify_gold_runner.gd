extends SceneTree

## Is there gold in the rock, is it hidden until you dig, and does digging find it?
##
## THE ROCK IS IN THE CAVE NOW (28 Sept 2026): stood on end in the hill as the monolith,
## with the same seam script. So this goes in through the pen's cave crossing first and
## digs there, with the pen's own pickaxe - which is also the point: the tool is the
## field's and the gold ends up in the field's belt.
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
var _cave: Node4D


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
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


## The point on the slab's surface nearest [param p]: out along whichever axis of the slab
## it is closest to the face of.
func _face_point(p: Vector4) -> Vector4:
	var local: Vector4 = p - _rock.global_position
	var half := Vector4(0.0, 0.0, 0.0, 0.0)
	var cells: float = float(_rock.get("grid_size")) * 0.5 * float(_rock.get("box_fill_fraction")) * float(_rock.get("cell_size"))
	var shape: Vector4 = _rock.get("proportions")
	half = shape * cells
	var best := 0
	var gap := INF
	for axis in 4:
		var g: float = half[axis] - absf(local[axis])
		if g < gap:
			gap = g
			best = axis
	local[best] = signf(local[best]) * (half[best] + 0.05)
	return _rock.global_position + local


func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		_root.get_node("CaveCrossing").call("go")
	if _f < 70: return false
	if _gold == null:
		for child in _root.get_children():
			if child.name == "Cave":
				_cave = child
		_gold = _cave.get_node_or_null("Gold") as Node4D if _cave != null else null
		if _gold == null:
			print("   FAIL there is no seam in the rock")
			quit(1); return true
		_pick = _root.get_node("Systems/Pickaxe")
		_rock = _cave.get_node("Monolith")
		_player = _root.get_node("Player")
		print("\n   the seam holds %d nuggets" % _gold.get_child_count())
		_check("it is buried to start with", _showing() == 0,
			"%d of %d showing" % [_showing(), _gold.get_child_count()])
		_check("and none is in the belt yet",
			not bool(_root.get_node("UI/Inventory").call("has_item", "found_azoth")),
			"belt: %s" % [_root.get_node("UI/Inventory").get("items")])
		return false

	if _step == 0:
		# Dig at the slab's face nearest each nugget in turn, the way a swing would - a
		# swing lands on the surface, not inside the rock.
		for orb in _gold.get_children():
			_pick.emit_signal("mined", _face_point((orb as Node4D).global_position),
				float(_rock.get("mining_radius_meters")))
		_step = 1
		return false

	if _step == 1:
		_check("digging uncovers them", _showing() == _gold.get_child_count(),
			"%d of %d showing after a swing at each"
				% [_showing(), _gold.get_child_count()])
		# Now walk onto one. Stood on the plinth in front of the slab, with the piece
		# brought down to it - a revealed piece sits where the blow landed, which can be
		# three metres up the slab. Moved through its parent: Node4D.global_position is
		# wrong two levels below an offset node (follow_up/engine_gotchas.md).
		var first: Node4D = _gold.get_child(0) as Node4D
		var stand: Vector4 = _cave.global_position + Vector4(0.0, 1.05, -33.1, 0.0)
		_player.global_position = stand
		first.position = _gold.global_basis.inverse() * (stand + Vector4(0.0, 0.8, -0.4, 0.0) - _gold.global_position)
		_step = 2
		_f = 0
		return false

	if _f < 90: return false
	_check("walking into one pockets it",
		bool(_root.get_node("UI/Inventory").call("has_item", "found_azoth")),
		"belt: %s" % [_root.get_node("UI/Inventory").get("items")])
	_check("and the rock itself is untouched by all this",
		_rock.get_node("Ground") != null and _rock.get_node("Voxels") != null,
		"the block still has its mesh and its colliders")
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
