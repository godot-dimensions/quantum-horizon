extends SceneTree

## Half the flock now rings the pen. Two things have to hold.
##
## NOBODY SPAWNS IN THE PEN. A bird authored inside the fence is counted as returned on
## the first frame, which has happened here before - and a bird's wander radius can carry
## it in even when its home is out, so the radius counts too.
##
## AND THEY REALLY DO SURROUND IT. The point of the change is that the pen stops being a
## place you only ever approach from one side, so the bearings have to be spread rather
## than clustered.

var _root: Node
var _f := 0
var _fails: Array = []

const PEN := Vector2(0.0, -11.0)


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-34s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var manager: Node = _root.get_node("Chickens")
	# READ FROM THE FENCE, not written down here. Written down, this test went on checking
	# clearances against a pen that had since been made smaller and would have passed a
	# chicken standing in the wall.
	var fence: Node = _root.get_node("Pen/Fence")
	var half := Vector2(maxf(float(fence.get("extend_x_positive")),
			float(fence.get("extend_x_negative"))),
		maxf(float(fence.get("extend_z_positive")), float(fence.get("extend_z_negative"))))
	print("
   the pen measures %.1f by %.1f from its middle" % [half.x, half.y])
	var agents: Array = manager.get("agents")
	var placements: Array = manager.get("PLACEMENTS")

	var inside: Array = []
	var could_wander_in: Array = []
	var bearings: Array = []
	var off_slice: int = 0
	for i in placements.size():
		var at := Vector2(placements[i][0], placements[i][1])
		var w: float = placements[i][2]
		var roam: float = placements[i][3]
		var gap := Vector2(absf(at.x - PEN.x) - half.x, absf(at.y - PEN.y) - half.y)
		var clear: float = maxf(gap.x, gap.y)
		if clear <= 0.0:
			inside.append(i + 1)
		elif clear < roam:
			could_wander_in.append("%d (%.1f clear, roams %.1f)" % [i + 1, clear, roam])
		if absf(w) > 0.1:
			off_slice += 1
			bearings.append(rad_to_deg(atan2(at.x - PEN.x, at.y - PEN.y)))

	_check("the flock is all there", agents.size() == 12, "%d chickens" % agents.size())
	_check("none spawn inside the fence", inside.is_empty(),
		"inside: %s" % [inside] if inside.size() > 0 else "all outside")
	_check("none can wander in either", could_wander_in.is_empty(),
		str(could_wander_in) if could_wander_in.size() > 0 else "every home clears its own roam")
	_check("half of them are off-slice", off_slice == 6, "%d with a W offset" % off_slice)

	# Spread: sort the bearings and check no two are on top of each other and that they
	# cover more than one side.
	bearings.sort()
	var tightest: float = 360.0
	for i in bearings.size():
		var gap2: float = bearings[(i + 1) % bearings.size()] - bearings[i]
		if gap2 < 0.0:
			gap2 += 360.0
		tightest = minf(tightest, gap2)
	_check("they surround the pen", tightest > 30.0,
		"closest two are %.0f deg apart, bearings %s"
			% [tightest, bearings.map(func(b): return "%.0f" % b)])

	# And nobody is standing on the player's spawn.
	var spawn := Vector2(0.0, -1.5)
	var nearest: float = 1.0e9
	for p in placements:
		nearest = minf(nearest, (Vector2(p[0], p[1]) - spawn).length())
	_check("nobody is on the spawn point", nearest > 2.0,
		"closest bird starts %.2f away" % nearest)

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
