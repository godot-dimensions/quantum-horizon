extends SceneTree

## Pen layout A, phase 4 (6 Oct 2026, PenLayout/PLAN_A.md steps 36-43): the pen's routes, written
## from here so they can be rebuilt and compared, into res://ramon/PenLayout/paths/pen_a.tres. The
## network (CreationLab/PathCreator/graph/path_network_4d.gd) stands at the field's origin, so these
## are field coordinates: x east, z south, and W.
##
## THE ROUTES
##   main     the start, round the hill's west shoulder (its turns curves, as the sheet draws them),
##            through the ruined wall's arch on the farm's slice (a fallen pillar lies across it: turn
##            the slice, or step, to get round), past the rock pile, into the cross-road where the
##            tower and range roads branch, and on to the pen's gate where the keeper stands
##   east     the long way round: the hill's sunny side, the meadow and its ring, to the gate
##   ring     round the meadow (secondary, chords 30 degrees apart, junctions east, south and west)
##   spurs    the professor; the cave door four metres ana (its stretch lies at the door's W, so on
##            the farm's slice it stops at four W dots); Trym's shed; the range; the tower
##   eggs     two thin ones: from the ring's south kata to the stone ring, and from the hill's east
##            side ana to the cairn
## Destinations stand at each unit's Arrival marker (an empty in its scene) and are anchored to it,
## so moving a unit in the pen carries its destination.
##
## Every stretch on the farm's slice is "here" with a band of 2.4 m: it reads from the farm's slice
## and is gone a little over a metre off it.
##
##   CreationLab/scripts/lab_run.sh headless pl_paths res://ramon/PenLayout/scripts/_make_pen_paths_runner.gd

const Graph := preload("res://ramon/CreationLab/PathCreator/graph/path_graph.gd")
const OUT := "res://ramon/PenLayout/paths/pen_a.tres"
const BAND := 2.4
const EGG_BAND := 2.0
## The meadow's ring: its middle, and a radius that makes its 12 chords a whole number of the
## secondary marks' 1.3 m spacing (28 of them), so they flow round without a jump.
## (20, -2): north-east of the hill's foot (at (16, 2) its south side ran onto the hill, 6 Oct).
const RING_AT := Vector2(20.0, -2.0)
const RING_R := 5.86


func _initialize() -> void:
	var g: Resource = Graph.new()
	var n := func(kind: String, x: float, z: float, w: float = 0.0, extra: Dictionary = {}) -> int:
		var ex: Dictionary = {"band": BAND if absf(w) < 0.01 else EGG_BAND}
		ex.merge(extra, true)
		return g.call("add_node", kind, Vector4(x, 0.0, z, w), ex)
	var dest := func(x: float, z: float, w: float, target: String, approach: Vector2, band: float = BAND) -> int:
		return g.call("add_node", "destination", Vector4(x, 0.0, z, w), {"band": band, "state": "available",
			"target": target, "frame": "none", "approach": approach, "anchor": true})
	var e := func(a: int, b: int, priority: String = "primary", mode: String = "here", band: float = BAND) -> void:
		g.call("add_edge", a, b, priority, mode, band)

	# The start, and the first choice right in front of it.
	var start: int = n.call("start", 4.0, 37.0)
	var choice: int = n.call("junction", 5.5, 35.0)
	e.call(start, choice)
	# Trym's shed, back beside you.
	var trym: int = dest.call(-5.0, 39.0, 0.0, "TrymArrival", Vector2(1, 0))
	e.call(start, trym, "secondary")
	# The professor, and the door behind him four metres ana.
	var prof: int = dest.call(3.6, 33.3, 0.0, "ProfessorArrival", Vector2(0, 1))
	e.call(choice, prof, "secondary")
	var to_door: int = n.call("bend", 7.2, 30.5)
	var door: int = dest.call(7.5, 27.8, 4.0, "CaveArrival", Vector2(0, 1), EGG_BAND)
	e.call(choice, to_door)
	e.call(to_door, door, "primary", "reveal", EGG_BAND)

	# The main route: round the west shoulder, through the ruined wall's arch, down to the gate.
	var w1: int = n.call("bend", -5.0, 31.0)
	var w2: int = n.call("bend", -10.0, 23.0)
	# Through the ruined wall's arch (World/StoneWall, pen_ruin_wall_4d.gd: the arch at x -11.2, the
	# wall at z 16), straight, on the farm's slice. 6 Oct: the path used to step 1.5 ana over the old
	# dry stone wall; the wall is a barrier now and the arch the way through.
	var arch_s: int = n.call("chord", -11.2, 19.0)
	var arch_n: int = n.call("chord", -11.2, 13.4)
	var w3: int = n.call("bend", -10.0, 7.0)
	# A junction: the rock pile branches off here.
	var w4: int = n.call("junction", -4.0, 0.0)
	var gate: int = n.call("junction", 4.0, -3.5)
	e.call(choice, w1)
	e.call(w1, w2)
	e.call(w2, arch_s)
	e.call(arch_s, arch_n)
	e.call(arch_n, w3)
	e.call(w3, w4)
	var rock: int = dest.call(-5.8, 1.4, 0.0, "RockArrival", Vector2(1, 0))
	e.call(w4, rock, "secondary")
	var keeper: int = dest.call(3.2, -4.4, 0.0, "KeeperArrival", Vector2(0, 1))
	e.call(gate, keeper, "secondary")

	# The east route, the long way round by the meadow.
	var e1: int = n.call("bend", 14.0, 37.0)
	var e2: int = n.call("bend", 25.0, 30.0)
	var e3: int = n.call("junction", 27.5, 16.0)
	var e4: int = n.call("bend", 25.5, 7.0)
	e.call(choice, e1)
	e.call(e1, e2)
	e.call(e2, e3)
	e.call(e3, e4)

	# The meadow's ring: 12 points, junctions east (from the east route), south (the egg) and west
	# (on to the gate).
	var ring: Array = []
	for i in 12:
		var a: float = deg_to_rad(30.0 * i)
		var p: Vector2 = RING_AT + Vector2(cos(a), sin(a)) * RING_R
		ring.append(n.call("junction" if i in [0, 3, 6] else "chord", p.x, p.y))
	for i in 12:
		e.call(ring[i], ring[(i + 1) % 12], "secondary")
	e.call(e4, ring[0])
	e.call(ring[6], gate)

	# The spurs from the gate: the range, and the tower beyond the pen.
	# The cross-road. Ramon, 6 Oct ("change road see ref"): the main road from the south runs
	# straight on into it, and the diagonal that cut from the rock pile's fork to the gate is gone;
	# the gate is along the cross-road to the east.
	var west: int = n.call("junction", -6.0, -3.0)
	e.call(w4, west)
	e.call(west, gate)
	var range_at: int = dest.call(-16.0, -7.5, 0.0, "RangeArrival", Vector2(1, 0))
	e.call(west, range_at)
	var t1: int = n.call("bend", -9.0, -16.0)
	var t2: int = n.call("bend", -12.0, -24.5)
	var tower: int = dest.call(-12.7, -27.6, 0.0, "TowerArrival", Vector2(0, 1))
	e.call(west, t1)
	e.call(t1, t2)
	e.call(t2, tower)

	# The eggs. Kata from the ring's south to the stones in the meadow's middle; ana from the hill's
	# east side to the cairn.
	var egg1: int = dest.call(RING_AT.x, RING_AT.y + 1.4, -2.5, "", Vector2(0, 1), EGG_BAND)
	g.call("node", egg1)["anchor"] = false
	e.call(ring[3], egg1, "secondary", "reveal", EGG_BAND)
	# In front of the cairn (at 25, 12), on the side the path comes from, not over its stones.
	var egg2: int = dest.call(25.8, 13.3, 7.0, "", Vector2(0, -1), EGG_BAND)
	g.call("node", egg2)["anchor"] = false
	e.call(e3, egg2, "secondary", "reveal", EGG_BAND)

	# The turns walked round as curves, the way the sheet draws them (CASE_STUDY.md, the curve
	# tool): chords between small balls on an arc that meets both legs. A field path bends; the
	# ball and ring are kept for the turn by the cave door, where the W dots stand. Junctions, the
	# wall's steps and the ring stay as they are.
	for corner in [[w1, 4.0], [w2, 4.0], [w3, 4.0], [e1, 4.0], [e2, 7.0], [e4, 4.0], [t1, 4.0], [t2, 4.0]]:
		g.call("round_corner", corner[0], corner[1])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ramon/PenLayout/paths/"))
	var err: int = ResourceSaver.save(g, OUT)
	print("PEN PATHS: %d nodes, %d edges -> %s (%d)" % [g.nodes.size(), g.edges.size(), OUT, err])
	for note in g.call("validate"):
		print("  note: %s" % note)
	quit(0 if err == OK else 1)
