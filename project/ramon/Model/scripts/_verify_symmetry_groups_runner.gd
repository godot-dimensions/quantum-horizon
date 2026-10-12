extends SceneTree
## Acceptance cases 2-3 for the branch symmetry extension.

const RIG := "res://ramon/Model/scripts/loft_rig_4d.gd"
const BALL := "res://ramon/Model/scripts/loft_ball_4d.gd"

var _frame: int = 0
var _world: Node4D
var _serial: int = 0

## Offsets from the anchor: one IN the (Z, W) rotation plane, one along the X
## mirror axis. They separate the two midline rules - a ring ignores an offset
## along its excluded axis, a mirror ignores one in the plane.
const IN_PLANE := Vector4(0, -0.75, 0.6, 0)
const ON_MIRROR_AXIS := Vector4(0.6, -0.75, 0, 0)


func _ball(parent: Node, n: String, pos: Vector4, props: Dictionary) -> MeshInstance4D:
	var b := MeshInstance4D.new()
	b.set_script(load(BALL))
	b.name = n
	parent.add_child(b)
	b.position = pos
	for k in props:
		b.set(k, props[k])
	return b


## Two spine balls plus one 3-ball leg branch off the first. The leg sits 0.6 out
## along Z from its anchor, which is IN the rotation plane for mirror_axis = X, so
## a ring has a real radius to sweep.
func _make_rig(sym: int, count: int, leg_offset: Vector4, legacy_mirror_flag: bool = true) -> MeshInstance4D:
	var rig := MeshInstance4D.new()
	rig.set_script(load(RIG))
	rig.name = "R%d_%d_%d" % [sym, count, _serial]
	_serial += 1
	rig.live_rebuild = false
	rig.verbose = false
	rig.smoothing = 1
	rig.profile_sides = 8
	rig.profile_rings = 4
	_world.add_child(rig)
	var root_ball := _ball(rig, "Hip", Vector4(0, 2.4, 0, 0), {"radius": 0.5})
	_ball(rig, "Shoulder", Vector4(0, 2.4, 1.4, 0), {"radius": 0.5})
	var top := _ball(root_ball, "LegTop", leg_offset, {
		"radius": 0.26, "starts_branch": true,
	})
	# Legacy flag set FIRST, then the new one, to prove the new one wins and that
	# the two do not fight during load.
	top.mirror_branch = legacy_mirror_flag
	top.symmetry_type = sym
	top.symmetry_count = count
	var mid := _ball(top, "LegMid", Vector4(0, -0.8, 0, 0), {"radius": 0.2})
	_ball(mid, "LegFoot", Vector4(0, -0.65, 0, 0), {"radius": 0.17})
	return rig


func _tets(rig: MeshInstance4D) -> int:
	var m := rig.mesh as ArrayTetraMesh4D
	return 0 if m == null else m.get_simplex_cell_vertex_indices().size() / 4


func _initialize() -> void:
	_world = Node4D.new()
	_world.name = "W"
	root.add_child(_world)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false

	var probe := _make_rig(0, 2, IN_PLANE)
	probe.get_node("Hip/LegTop").free()
	probe.build(false)
	var spine: int = _tets(probe)
	var lone := _make_rig(0, 2, IN_PLANE)
	lone.build(false)
	var leg: int = _tets(lone) - spine
	print("spine alone: %d tets;  one leg: %d tets" % [spine, leg])
	print("")

	# [label, symmetry, count, leg offset, expected copies]
	var cases := [
		["None            in-plane", 0, 2, IN_PLANE, 1],
		["Mirror          in-plane", 1, 2, IN_PLANE, 1],
		["Cyclic(3)       in-plane", 2, 3, IN_PLANE, 3],
		["Cyclic(5)       in-plane", 2, 5, IN_PLANE, 5],
		["Cyclic(12)      in-plane", 2, 12, IN_PLANE, 12],
		["Dihedral(5)     in-plane", 3, 5, IN_PLANE, 5],
		["Mirror        on-X-axis", 1, 2, ON_MIRROR_AXIS, 2],
		["Cyclic(5)     on-X-axis", 2, 5, ON_MIRROR_AXIS, 1],
		["Dihedral(5)   on-X-axis", 3, 5, ON_MIRROR_AXIS, 2],
	]
	var ok := true
	var built := {}
	print("mode                      tets   expected  copies  note")
	for case in cases:
		var rig: MeshInstance4D = _make_rig(int(case[1]), int(case[2]), case[3])
		rig.build(false)
		built[case[0]] = rig
		var expect: int = spine + leg * int(case[4])
		var got: int = _tets(rig)
		if got != expect:
			ok = false
		print("%-24s  %-5d  %-8d  %-6d  %s" % [
			case[0], got, expect, case[4], "OK" if got == expect else "MISMATCH"])
	print("")
	print("  in-plane Mirror -> 1: a limb ON the mirror plane stays single (unchanged rule)")
	print("  on-X-axis Cyclic -> 1: a limb on the ring's own axis stays single (same rule, 2D)")
	print("  in-plane Dihedral -> 5: reflection maps it onto itself, so it collapses to Cyclic")
	print("  on-X-axis Dihedral -> 2: every rotation lands in one place, so it collapses to Mirror")
	var collapsed: bool = _tets(built["Dihedral(5)   on-X-axis"]) == _tets(built["Mirror        on-X-axis"])
	print("  and that collapse equals Mirror exactly: %s" % ("YES" if collapsed else "NO"))
	if not collapsed:
		ok = false

	# --- legacy flag equivalence ---
	var legacy := _make_rig(1, 2, ON_MIRROR_AXIS, true)
	legacy.build(false)
	var same: bool = _tets(legacy) == _tets(built["Mirror        on-X-axis"])
	print("")
	print("mirror_branch=true == symmetry_type=Mirror: %s" % ("YES" if same else "NO"))
	if not same:
		ok = false

	# --- the orbit, to diff against the independent computation ---
	var cyc: MeshInstance4D = built["Cyclic(5)       in-plane"]
	print("")
	print("plane axes for mirror_axis=X: %s   (expect (2, 3) = Z, W)" % str(cyc._plane_axes()))
	print("attachment orbit, Cyclic(5), anchor (0, 2.4, 0, 0), point (0, 1.65, 0.6, 0):")
	var anchor := Vector4(0, 2.4, 0, 0)
	for k in range(5):
		var t: Vector4 = cyc._rotate_in_plane(Vector4(0, 1.65, 0.6, 0), anchor, TAU * float(k) / 5.0)
		print("  k=%d  (%.6f, %.6f, %.6f, %.6f)" % [k, t.x, t.y, t.z, t.w])

	# --- end-to-end: the ring's five copies must be congruent and evenly spaced ---
	#
	# NOT a vertex-for-vertex round trip. The builder resolves each section's frame
	# against a world-fixed reference direction, so a rotated copy is congruent but
	# carries its own azimuthal start - the same reason a mirrored copy is not
	# vertex-identical either. What must hold is that each copy has the same vertex
	# count and that its centroid sits exactly on the orbit.
	var lone_leg_verts: int = 0
	for v in (lone.mesh as ArrayTetraMesh4D).get_vertex_positions():
		if v.y < 1.5:
			lone_leg_verts += 1
	var lone_centroid := Vector4()
	for v in (lone.mesh as ArrayTetraMesh4D).get_vertex_positions():
		if v.y < 1.5:
			lone_centroid += v
	lone_centroid /= float(lone_leg_verts)

	var m := cyc.mesh as ArrayTetraMesh4D
	var buckets: Array[int] = [0, 0, 0, 0, 0]
	var centroids: Array[Vector4] = [Vector4(), Vector4(), Vector4(), Vector4(), Vector4()]
	for v in m.get_vertex_positions():
		if v.y >= 1.5:
			continue  # spine, which is a single chain and not part of the ring
		var a: float = fposmod(rad_to_deg(atan2(v.w - anchor.w, v.z - anchor.z)) + 36.0, 360.0)
		var bucket: int = clampi(int(a / 72.0), 0, 4)
		buckets[bucket] += 1
		centroids[bucket] += v
	print("")
	print("ring copies (leg vertices bucketed by angle about the anchor):")
	print("  one leg alone: %d vertices, centroid (%.4f, %.4f, %.4f, %.4f)" % [
		lone_leg_verts, lone_centroid.x, lone_centroid.y, lone_centroid.z, lone_centroid.w])
	var worst: float = 0.0
	for k in range(5):
		if buckets[k] != lone_leg_verts:
			ok = false
		var mid_point: Vector4 = centroids[k] / maxf(float(buckets[k]), 1.0)
		var expected: Vector4 = cyc._rotate_in_plane(lone_centroid, anchor, TAU * float(k) / 5.0)
		var err: float = (mid_point - expected).length()
		worst = maxf(worst, err)
		print("  copy %d: %4d verts  centroid (%+.4f, %+.4f, %+.4f, %+.4f)  off orbit by %.12f" % [
			k, buckets[k], mid_point.x, mid_point.y, mid_point.z, mid_point.w, err])
	if worst > 1e-9:
		ok = false
	print("  worst centroid deviation from the computed orbit: %.12f" % worst)

	print("")
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true


## Quantised so the 72-degree round trip is compared at geometric precision rather
## than bit precision.
func _key(v: Vector4) -> String:
	return "%d,%d,%d,%d" % [roundi(v.x * 10000.0), roundi(v.y * 10000.0),
		roundi(v.z * 10000.0), roundi(v.w * 10000.0)]
