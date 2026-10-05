extends SceneTree

## Pen layout, step 34 (6 Oct 2026): checks where the pen's units stand, for after moving or turning
## them in the editor. Prints each unit's footprint, then the rules:
##   - units clear of each other and of the pen, by their parts (x, z and W; height is ignored)
##   - each unit inside the field (the walkable sphere, 46 m round the origin in x, z and W) and
##     nothing of it out in the hills (they start at 50 m)
##   - no chicken's home inside a unit
##   - the professor in front of the cave mouth, 3 to 9 m out and clear of the hill: the story has
##     him pointing people at it, so he goes where the cave goes
##   - room for the wolf: it comes in from 16 m off the pen's far side, whichever side that is
##     (wolf_raid_4d.gd), so a unit 15 to 22 m from the pen blocks a direction (a warning)
##   - the east meadow left open: the meadow film is shot at (16, 2) toward the low sun (a warning)
##   - the starlings: the ride flies into the flock's roost about 70 s in, drawn from the mooring,
##     so a Lookout moved far or turned misses them (a warning)
##   - the balloon ride's bend toward the pen: the ride is drawn for the Lookout where it first
##     stood, and bends its pass over the farm toward the pen wherever the pen now is from the
##     mooring. A small bend is invisible; a big one makes the balloon swing (a warning, not a fail).
##
## A part's footprint is its colliders' boxes if it has colliders (the cave hill is a dome, and its
## mesh's box would cover half the field), otherwise the box round its meshes.
##
##   CreationLab/scripts/lab_run.sh windowed pl_layout res://ramon/PenLayout/scripts/_check_layout_runner.gd [scene]

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const UNITS := ["TrymCabin", "KeeperPost", "Range", "ProfessorPost", "LookoutSite", "RockPileSpot", "Cave"]
## The pen's own parts: units keep clear of these too.
const PEN_PARTS := ["Fence", "Coop", "Upgrades", "Return"]
## Parts closer than this count as touching (metres, in x, z and W).
const GAP_M := 0.5
const FIELD_R := 46.0
const HILLS_R := 50.0
## The professor's distance from the cave mouth (the professor test's own band).
const PROF_GAP := Vector2(3.0, 9.0)
## Above this the balloon's swing toward the pen shows (metres).
const BEND_WARN_M := 25.0
const PEN := Vector2(0.0, -11.0)
## How far out from the pen's middle the wolf's run-in starts and ends, roughly (metres).
const WOLF_RING := Vector2(15.0, 22.0)
## The meadow film's centre (cinematic_meadow_4d.gd, moved there 6 Oct).
const MEADOW := Vector2(28.0, -8.0)
const MEADOW_R := 9.0
## The player's run (block_walker_character_4d.gd speed), for the walk times.
const RUN := 3.0

var _root: Node
var _fails: int = 0
var _warns: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _warn(what: String) -> void:
	print("WARN " + what)
	_warns += 1


## [position, size] round a node and everything under it: its colliders' boxes if it has any,
## otherwise its meshes. Empty when it has neither.
func _box(n: Node4D) -> Array:
	var boxes: Array = []
	for cs in n.find_children("*", "CollisionShape4D", true, false):
		var shape := (cs as CollisionShape4D).shape
		if shape != null:
			var r: PackedVector4Array = shape.get_rect_bounds((cs as Node4D).global_basis, (cs as Node4D).global_position)
			boxes.append([r[0], r[1]])
	if n is CollisionShape4D:
		boxes.append(_shape_box(n as CollisionShape4D))
	if boxes.is_empty():
		var r: PackedVector4Array = n.get_rect_bounds_global_recursive()
		if r[1].length() < 0.01:
			return []
		return [r[0], r[1]]
	var lo: Vector4 = boxes[0][0]
	var hi: Vector4 = lo + (boxes[0][1] as Vector4)
	for b in boxes:
		lo = lo.min(b[0])
		hi = hi.max((b[0] as Vector4) + (b[1] as Vector4))
	return [lo, hi - lo]


func _shape_box(cs: CollisionShape4D) -> Array:
	var r: PackedVector4Array = cs.shape.get_rect_bounds(cs.global_basis, cs.global_position)
	return [r[0], r[1]]


## How far apart two boxes are in x, z and W: negative when they overlap (by how much, on the
## axis they overlap least).
func _apart(a: Array, b: Array) -> float:
	var gap: float = -INF
	for axis in [0, 2, 3]:
		var a0: float = (a[0] as Vector4)[axis]
		var a1: float = a0 + (a[1] as Vector4)[axis]
		var b0: float = (b[0] as Vector4)[axis]
		var b1: float = b0 + (b[1] as Vector4)[axis]
		gap = maxf(gap, maxf(b0 - a1, a0 - b1))
	return gap


func _inside(p: Vector4, b: Array) -> bool:
	var lo: Vector4 = b[0]
	var hi: Vector4 = lo + (b[1] as Vector4)
	return p.x > lo.x and p.x < hi.x and p.z > lo.z and p.z < hi.z and p.w > lo.w and p.w < hi.w


func _fmt(b: Array) -> String:
	var lo: Vector4 = b[0]
	var hi: Vector4 = lo + (b[1] as Vector4)
	return "x %.1f..%.1f  z %.1f..%.1f  W %.1f..%.1f" % [lo.x, hi.x, lo.z, hi.z, lo.w, hi.w]


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "res://ramon/chickenpen/playable_world.tscn"
	_root = (load(scene) as PackedScene).instantiate()
	root.add_child(_root)
	current_scene = _root
	for i in 60:
		await process_frame
	print("LAYOUT of %s" % scene)
	var world: Node = _root.get_node("World")
	# Every part's box, by owner: "<unit>/<part>".
	var parts: Dictionary = {}
	for unit in UNITS:
		var u := world.get_node_or_null(unit) as Node4D
		if u == null:
			_check(false, "%s is in the pen" % unit)
			continue
		var turn: float = rad_to_deg(atan2(u.global_basis.z.x, u.global_basis.z.z))
		print("%s at (%.1f, %.1f, W %.1f), turned %.0f" % [unit, u.global_position.x, u.global_position.z, u.global_position.w, turn])
		for c in u.get_children():
			if c is Node4D:
				var b: Array = _box(c as Node4D)
				if not b.is_empty():
					parts["%s/%s" % [unit, c.name]] = b
					print("    %-34s %s" % [c.name, _fmt(b)])
	var pen := _root.get_node("Pen") as Node4D
	# The fence is a generator, not meshes under a node: its footprint is its own box (x, z, W).
	var fence := pen.get_node_or_null("Fence") as Node4D
	if fence != null and fence.has_method("_bounds"):
		var fb: Array = fence.call("_bounds")
		var at: Vector4 = fence.global_position
		var b: Array = [at + Vector4(fb[0], 0.0, fb[2], fb[4]), Vector4(fb[1] - fb[0], float(fence.get("height")), fb[3] - fb[2], fb[5] - fb[4])]
		parts["Pen/Fence"] = b
		print("Pen/%-31s %s" % ["Fence", _fmt(b)])
	for name in PEN_PARTS:
		if name == "Fence" and parts.has("Pen/Fence"):
			continue
		var p := pen.get_node_or_null(name) as Node4D
		if p != null:
			var b: Array = _box(p)
			if not b.is_empty():
				parts["Pen/%s" % name] = b
				print("Pen/%-31s %s" % [name, _fmt(b)])
	# 1. Clear of each other and of the pen.
	var keys: Array = parts.keys()
	var touching: Array = []
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: String = keys[i]
			var b: String = keys[j]
			if a.get_slice("/", 0) == b.get_slice("/", 0):
				continue
			var gap: float = _apart(parts[a], parts[b])
			if gap < GAP_M:
				touching.append("%s and %s (%s)" % [a, b, ("%.1f m into each other" % -gap) if gap < 0.0 else ("%.1f m apart" % gap)])
	for t in touching:
		print("    touching: " + t)
	_check(touching.is_empty(), "units clear of each other and of the pen by %.1f m (%d touching)" % [GAP_M, touching.size()])
	# 2. In the field.
	var out: Array = []
	var hills: Array = []
	for unit in UNITS:
		var u := world.get_node_or_null(unit) as Node4D
		if u == null:
			continue
		var p: Vector4 = u.global_position
		if Vector3(p.x, p.z, p.w).length() > FIELD_R:
			out.append("%s (%.1f m out)" % [unit, Vector3(p.x, p.z, p.w).length()])
	for k in keys:
		if k.begins_with("Pen/") or k == "LookoutSite/Balloon":
			continue
		var b: Array = parts[k]
		var lo: Vector4 = b[0]
		var hi: Vector4 = lo + (b[1] as Vector4)
		# The box's corner furthest from the origin in x, z and W.
		var far := Vector3(maxf(absf(lo.x), absf(hi.x)), maxf(absf(lo.z), absf(hi.z)), maxf(absf(lo.w), absf(hi.w)))
		if far.length() > HILLS_R and k != "Cave/CaveHill":
			hills.append("%s (a corner %.1f m out)" % [k, far.length()])
	_check(out.is_empty(), "every unit stands in the field, within %.0f m %s" % [FIELD_R, str(out)])
	if not hills.is_empty():
		_warn("parts reaching into the hills (%.0f m): %s" % [HILLS_R, str(hills)])
	# 3. No chicken's home inside a unit.
	var in_unit: Array = []
	var chickens: Node = _root.get_node_or_null("Chickens")
	if chickens != null:
		for c in chickens.get_children():
			if c is Node4D:
				for k in keys:
					if not (k as String).begins_with("Pen/") and _inside((c as Node4D).global_position, parts[k]):
						in_unit.append("%s in %s" % [c.name, k])
	_check(in_unit.is_empty(), "no chicken's home inside a unit %s" % str(in_unit))
	# 4. The professor at the cave mouth.
	var prof := world.get_node_or_null("ProfessorPost/Professor") as Node4D
	var hill: Node4D = CaveHill.node_in(world)
	if prof != null and hill != null:
		var mouth: Vector4 = CaveHill.to_world(hill, CaveHill.MOUTH)
		var gap: float = Vector2(prof.global_position.x - mouth.x, prof.global_position.z - mouth.z).length()
		var dw: float = absf(prof.global_position.w - mouth.w)
		var clear := true
		var at: Vector4 = CaveHill.to_local(hill, prof.global_position + Vector4(0.0, 0.9, 0.0, 0.0))
		for box in CaveHill.new().solid_boxes():
			var d: Vector4 = (at - box[0]).abs() - (box[1] as Vector4) * 0.5
			if d.x < 0.3 and d.y < 0.0 and d.z < 0.3 and d.w < 0.3:
				clear = false
		_check(gap > PROF_GAP.x and gap < PROF_GAP.y and clear,
			"the professor stands in front of the cave mouth (%.1f m from it, %s; he goes with the cave)" % [gap, "clear of the hill" if clear else "INSIDE the hill"])
		if dw > 0.5:
			print("    the door is %.1f m %s of him in W" % [dw, "ana" if mouth.w > prof.global_position.w else "kata"])
	# 5. The balloon's bend toward the pen.
	var lookout: Node = _root.get_node_or_null("Systems/Lookout")
	var balloon: Node = lookout.get("balloon") if lookout != null else null
	if balloon != null and balloon.has_method("_pen_shift"):
		var bend: float = (balloon.call("_pen_shift") as Vector4).length()
		print("    the ride bends %.1f m toward the pen over the farm" % bend)
		if bend > BEND_WARN_M:
			_warn("the balloon swings %.1f m off its drawn line to pass over the pen; worth a look in the ride" % bend)
	# 6. The starlings: where the ride is 70 s in (no bend left by then) against the roost.
	var flock: Node = _root.find_child("Flock", true, false)
	if balloon != null and flock != null and flock.get("roost") != null:
		var host: Node4D = (balloon as Node).get_parent() as Node4D
		var moor: Vector4 = balloon.get("_moor")
		var ride_basis: Projection = balloon.get("ride_basis")
		var at70: Vector4 = host.global_position + host.global_basis * (moor + ride_basis * (balloon.call("_path", 70.0) as Vector4))
		var roost: Vector4 = flock.get("roost")
		var off: float = Vector2(at70.x - roost.x, at70.z - roost.z).length()
		print("    70 s into the ride the basket is %.1f m from the starlings' roost" % off)
		if off > float(flock.get("roost_radius")):
			_warn("the ride misses the starlings (%.1f m from their roost, which is %.0f m across)" % [off, 2.0 * float(flock.get("roost_radius"))])
	# 7. Room for the wolf, in eight directions from the pen.
	var blocked: Array = []
	for i in 8:
		var dir := Vector2(sin(i * PI / 4.0), -cos(i * PI / 4.0))
		for k in keys:
			if (k as String).begins_with("Pen/"):
				continue
			var hit := false
			for r in [WOLF_RING.x, (WOLF_RING.x + WOLF_RING.y) * 0.5, WOLF_RING.y]:
				var q: Vector2 = PEN + dir * r
				if _inside(Vector4(q.x, 0.0, q.y, 0.0), parts[k]):
					hit = true
			if hit:
				blocked.append("%s by %s" % [["N", "NE", "E", "SE", "S", "SW", "W", "NW"][i], k])
				break
	if not blocked.is_empty():
		_warn("the wolf's run-in is blocked to the %s" % str(blocked))
	# 8. The east meadow, where the meadow film is shot toward the low sun.
	var in_meadow: Array = []
	for k in keys:
		var b: Array = parts[k]
		var lo: Vector4 = b[0]
		var hi: Vector4 = lo + (b[1] as Vector4)
		var near := Vector2(clampf(MEADOW.x, lo.x, hi.x), clampf(MEADOW.y, lo.z, hi.z))
		if near.distance_to(MEADOW) < MEADOW_R and lo.w < 1.0 and hi.w > -1.0:
			in_meadow.append(k)
	if not in_meadow.is_empty():
		_warn("in the east meadow, where the meadow film looks at the low sun: %s" % str(in_meadow))
	# 9. Where you start, and how far everything is from there and from the pen (straight lines).
	var player := _root.get_node("Player") as Node4D
	var start: Vector4 = player.global_position
	var in_start: Array = []
	for k in keys:
		if _inside(start, parts[k]):
			in_start.append(k)
	_check(in_start.is_empty(), "you start in the open at (%.1f, %.1f, W %.1f) %s" % [start.x, start.z, start.w, str(in_start)])
	var spots := {"keeper": "KeeperPost/Keeper", "Trym's door": "", "range": "Range/RangeMaster", "professor": "ProfessorPost/Professor",
		"tower": "LookoutSite/Wren", "rock pile": "RockPileSpot/RockPile"}
	var inv: Node = _root.get_node_or_null("Invitation")
	for what in spots:
		var p: Vector4
		if spots[what] == "":
			if inv == null or not inv.has_method("_door_spot"):
				continue
			p = inv.call("_door_spot")
		else:
			var n := world.get_node_or_null(spots[what]) as Node4D
			if n == null:
				continue
			p = n.global_position
		var from_start: float = Vector3(p.x - start.x, p.z - start.z, p.w - start.w).length()
		var from_pen: float = Vector3(p.x - PEN.x, p.z - PEN.y, p.w).length()
		print("    %-12s at (%.1f, %.1f, W %.1f): %.0f m from the start (%.0f s), %.0f m from the pen (%.0f s)" % [what, p.x, p.z, p.w, from_start, from_start / RUN, from_pen, from_pen / RUN])
	if hill != null:
		var m: Vector4 = CaveHill.to_world(hill, CaveHill.MOUTH)
		print("    %-12s at (%.1f, %.1f, W %.1f): %.0f m from the start, %.0f m from the pen" % ["cave mouth", m.x, m.z, m.w, Vector2(m.x - start.x, m.z - start.z).length(), Vector2(m.x - PEN.x, m.z - PEN.y).length()])
	# 10. The paths (World/Paths, if the pen has them): the network's own notes, and no route
	# through a unit, the pen's fence or a chicken's home (sampled every metre, at the route's W).
	var net: Node = world.get_node_or_null("Paths")
	if net != null and net.get("graph") != null:
		for note in net.call("notes"):
			_warn("paths: %s" % note)
		var graph: Resource = net.get("graph")
		var through: Array = []
		for ei in (graph.get("edges") as Array).size():
			var e: Dictionary = graph.edges[ei]
			var a: Vector4 = (graph.call("node", int(e["from"])) as Dictionary)["pos"]
			var b: Vector4 = (graph.call("node", int(e["to"])) as Dictionary)["pos"]
			var steps: int = maxi(1, int(Vector2(b.x - a.x, b.z - a.z).length()))
			for k in range(1, steps):
				var p: Vector4 = a.lerp(b, float(k) / float(steps))
				if String(e.get("w_mode", "")) == "reveal":
					p.w = b.w
				elif String(e.get("w_mode", "")) == "here":
					p.w = a.w
				for key in keys:
					if (key as String).ends_with("Arrival") or (key as String) == "Pen/Coop":
						continue
					var box: Array = parts[key]
					if _inside(p, [(box[0] as Vector4) - Vector4(0.3, 0, 0.3, 0.3), (box[1] as Vector4) + Vector4(0.6, 0, 0.6, 0.6)]):
						through.append("edge %d through %s" % [ei, key])
						break
		var uniq: Array = []
		for t in through:
			if not (t in uniq):
				uniq.append(t)
		_check(uniq.is_empty(), "no route runs through a unit or the pen %s" % str(uniq))
	print("LAYOUT: %s (%d failed, %d warnings)" % ["PASS" if _fails == 0 else "FAIL", _fails, _warns])
	quit(0 if _fails == 0 else 1)
