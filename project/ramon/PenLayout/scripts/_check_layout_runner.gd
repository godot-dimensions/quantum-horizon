extends SceneTree

## Pen layout, step 34 (6 Oct 2026): checks where the pen's units stand, for after moving or turning
## them in the editor. Prints each unit's footprint, then the rules:
##   - units clear of each other and of the pen, by their parts (x, z and W; height is ignored)
##   - each unit inside the field (the walkable sphere, 46 m round the origin in x, z and W) and
##     nothing of it out in the hills (they start at 50 m)
##   - no chicken's home inside a unit
##   - the professor in front of the cave mouth, 3 to 9 m out and clear of the hill: the story has
##     him pointing people at it, so he goes where the cave goes
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
		_check(gap > PROF_GAP.x and gap < PROF_GAP.y and dw < 0.5 and clear,
			"the professor stands in front of the cave mouth (%.1f m from it, %.1f apart in W, %s; he goes with the cave)" % [gap, dw, "clear of the hill" if clear else "INSIDE the hill"])
	# 5. The balloon's bend toward the pen.
	var lookout: Node = _root.get_node_or_null("Systems/Lookout")
	var balloon: Node = lookout.get("balloon") if lookout != null else null
	if balloon != null and balloon.has_method("_pen_shift"):
		var bend: float = (balloon.call("_pen_shift") as Vector4).length()
		print("    the ride bends %.1f m toward the pen over the farm" % bend)
		if bend > BEND_WARN_M:
			_warn("the balloon swings %.1f m off its drawn line to pass over the pen; worth a look in the ride" % bend)
	print("LAYOUT: %s (%d failed, %d warnings)" % ["PASS" if _fails == 0 else "FAIL", _fails, _warns])
	quit(0 if _fails == 0 else 1)
