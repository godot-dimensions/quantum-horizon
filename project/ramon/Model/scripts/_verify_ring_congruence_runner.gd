extends SceneTree
## Guards the bug that the copy-count and orbit-centroid checks both MISSED.
##
## A ring copy can sit at exactly the right place, with exactly the right number of
## cells, and still be wrong: if its cross-sections are spun by a different amount
## than the original's, the copy is not congruent. The centroid of a spun section is
## still on the orbit, and the cell count is unchanged, so both of the earlier checks
## passed while 1040 of 1100 vertices had no partner under the ring's own half turn.
##
## The invariant that actually catches it: the union of a ring's copies must be
## INVARIANT under the group's own elements. Tested at vertex level.

const RIG := "res://ramon/Model/scripts/loft_rig_4d.gd"
const BALL := "res://ramon/Model/scripts/loft_ball_4d.gd"

var _frame := 0
var _world: Node4D
var _failures := 0


func _ball(parent: Node, n: String, pos: Vector4, props: Dictionary) -> MeshInstance4D:
	var b := MeshInstance4D.new()
	b.set_script(load(BALL))
	b.name = n
	parent.add_child(b)
	b.position = pos
	for k in props:
		b.set(k, props[k])
	return b


func _key(v: Vector4) -> String:
	return "%d,%d,%d,%d" % [roundi(v.x * 2000.0), roundi(v.y * 2000.0),
		roundi(v.z * 2000.0), roundi(v.w * 2000.0)]


## A rig whose only sub-y=1.7 geometry is the branch under test.
func _make(sym: int, count: int, leg_x: float, roll: float) -> MeshInstance4D:
	var rig := MeshInstance4D.new()
	rig.set_script(load(RIG))
	rig.name = "R%d_%d_%d" % [sym, count, _frame]
	rig.live_rebuild = false
	rig.verbose = false
	rig.smoothing = 3
	rig.profile_sides = 10
	rig.profile_rings = 5
	_world.add_child(rig)
	_ball(rig, "A", Vector4(0, 2.4, 0, 0), {"radius": 0.58})
	var anchor := _ball(rig, "B", Vector4(1.2, 2.4, 0, 0), {"radius": 0.58})
	var top := _ball(anchor, "LegTop", Vector4(leg_x, -0.7, 0.78, 0), {
		"radius": 0.3, "v_scale": 0.6, "w_scale": 2.2, "starts_branch": true})
	top.symmetry_type = sym
	top.symmetry_count = count
	var mid := _ball(top, "LegMid", Vector4(0, -0.8, 0.22, 0), {
		"radius": 0.22, "v_scale": 0.55, "w_scale": 1.9, "roll": roll})
	_ball(mid, "Hoof", Vector4(0, -0.62, 0.1, 0), {
		"radius": 0.19, "w_scale": 2.7, "squareness": 0.4})
	return rig


func _invariant(rig: MeshInstance4D, label: String, turns: int, reflects: bool) -> void:
	rig.build(false)
	var verts: PackedVector4Array = (rig.mesh as ArrayTetraMesh4D).get_vertex_positions()
	var present := {}
	var group: Array[Vector4] = []
	for v in verts:
		if v.y > 1.7:
			continue
		group.append(v)
		present[_key(v)] = true
	# The anchor sits at (1.2, 2.4, 0, 0), so the mirror plane is x = 1.2 and the
	# rotation plane is (Z, W) about z = w = 0.
	var worst_turn: int = 0
	for k in range(1, turns):
		var angle: float = TAU * float(k) / float(turns)
		var c := cos(angle)
		var s := sin(angle)
		var missing: int = 0
		for v in group:
			var turned := Vector4(v.x, v.y, v.z * c - v.w * s, v.z * s + v.w * c)
			if not present.has(_key(turned)):
				missing += 1
		worst_turn = maxi(worst_turn, missing)
	var missing_reflect: int = -1
	if reflects:
		missing_reflect = 0
		for v in group:
			if not present.has(_key(Vector4(2.4 - v.x, v.y, v.z, v.w))):
				missing_reflect += 1
	var ok: bool = worst_turn == 0 and (not reflects or missing_reflect == 0)
	if not ok:
		_failures += 1
	print("  %-38s %5d verts   turns off by %4d   reflection off by %s   %s" % [
		label, group.size(), worst_turn,
		"n/a " if missing_reflect < 0 else "%4d" % missing_reflect,
		"OK" if ok else "*** FAIL ***"])


func _initialize() -> void:
	_world = Node4D.new()
	root.add_child(_world)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false
	print("ring copies must be congruent, not merely correctly placed:")
	# Off the mirror plane, so a Dihedral keeps both halves.
	_invariant(_make(2, 2, 0.45, 12.0), "Cyclic(2)   off-plane, roll 12", 2, false)
	_invariant(_make(2, 3, 0.45, 12.0), "Cyclic(3)   off-plane, roll 12", 3, false)
	_invariant(_make(2, 5, 0.45, 0.0), "Cyclic(5)   off-plane, roll 0", 5, false)
	_invariant(_make(3, 2, 0.45, 12.0), "Dihedral(2) off-plane, roll 12", 2, true)
	_invariant(_make(3, 3, 0.45, 12.0), "Dihedral(3) off-plane, roll 12", 3, true)
	_invariant(_make(3, 4, 0.45, -20.0), "Dihedral(4) off-plane, roll -20", 4, true)
	# On the mirror plane: the reflection is degenerate, so only the ring applies.
	_invariant(_make(2, 4, 0.0, 12.0), "Cyclic(4)   on-plane, roll 12", 4, false)
	print("")
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
