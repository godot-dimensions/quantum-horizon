extends SceneTree

## Pen layout, Phase C0 (6 Oct 2026): on a pen whose units have been moved and turned
## (PenLayout/scratch/moved_pen.tscn, from _make_moved_pen_runner.gd), checks the things that went
## with their units but that the pen's own tests do not look at:
##   - the colliders went with the turned buildings (a ray down finds the shed where it now stands,
##     including a corner only a turned shed covers, and not where it stood)
##   - Trym's door goes up in the cabin's frame
##   - the balloon's pass over the farm still has the pen below it
##   - the cave's way in is where the cave is now, and not where it was (last: it starts the crossing)
##   - no chicken's home is inside a building
##
##   CreationLab/scripts/lab_run.sh windowed pl_moved_check res://ramon/PenLayout/scripts/_verify_moved_runner.gd [scene]

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const UNITS := ["TrymCabin", "KeeperPost", "Range", "ProfessorPost", "LookoutSite", "RockPileSpot", "Cave"]

var _root: Node
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The body a ray straight down at (x, z, w) lands on, and which unit owns it ("" for none).
func _down(x: float, z: float, w: float) -> Array:
	var params := RaycastParameters4D.new()
	params.global_ray_origin = Vector4(x, 30.0, z, w)
	params.global_ray_direction = Vector4(0, -1, 0, 0)
	params.max_distance = 40.0
	var player: Node = _root.get_node_or_null("Player")
	var skip: Array[Node4D] = []
	if player is Node4D:
		skip.append(player as Node4D)
	params.set_exclude_nodes(skip)
	var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
	if hit.is_empty() or not bool(hit.get("hit", false)):
		return [null, ""]
	var body: Node = hit.get("body")
	var unit: String = ""
	var n: Node = body
	while n != null and n != _root:
		if n.get_parent() != null and n.get_parent().name == "World" and String(n.name) in UNITS:
			unit = String(n.name)
		n = n.get_parent()
	return [body, unit]


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "res://ramon/PenLayout/scratch/moved_pen.tscn"
	_root = (load(scene) as PackedScene).instantiate()
	root.add_child(_root)
	current_scene = _root
	await _frames(90)
	var world: Node = _root.get_node("World")
	# 1. Colliders went with the turned units: the range booth (turned 90) and the cave hill (turned
	# -90) are the units with colliders (the shed has none). For each, its biggest box: a ray down
	# at its middle and near the end of its length finds the unit; one just past its width does not.
	# (Past its width only for the range: the cave hill's other rock boxes fill the space beside
	# any one of them.)
	for unit in ["Range", "Cave"]:
		var biggest: CollisionShape4D = null
		var size := Vector4.ZERO
		for cs in world.get_node(unit).find_children("*", "CollisionShape4D", true, false):
			var bs := (cs as CollisionShape4D).shape as BoxShape4D
			if bs != null and absf(bs.size.x - bs.size.z) > 0.5 and bs.size.x * bs.size.z > size.x * size.z:
				biggest = cs
				size = bs.size
		if biggest == null:
			_check(false, "%s has a box collider to test" % unit)
			continue
		var c: Vector4 = biggest.global_position
		var along_x: bool = size.x >= size.z
		var long_axis: Vector4 = biggest.global_basis * (Vector4(size.x * 0.42, 0, 0, 0) if along_x else Vector4(0, 0, size.z * 0.42, 0))
		var past_width: Vector4 = biggest.global_basis * (Vector4(0, 0, size.z * 0.5 + 0.4, 0) if along_x else Vector4(size.x * 0.5 + 0.4, 0, 0, 0))
		var at_c: Array = _down(c.x, c.z, c.w)
		var at_long: Array = _down(c.x + long_axis.x, c.z + long_axis.z, c.w)
		var past: Array = _down(c.x + past_width.x, c.z + past_width.z, c.w)
		print("%s box %s: middle %s, along its length %s, past its width %s" % [unit, str(size), at_c[1], at_long[1], past[1]])
		_check(at_c[1] == unit and at_long[1] == unit, "%s's collider is where the turned unit stands, all along its length" % unit)
		if unit == "Range":
			_check(past[0] != at_c[0], "%s's collider turned with it (nothing of that box past its width)" % unit)
	var old_booth: Array = _down(-19.0, -9.0, 0.0)
	_check(old_booth[1] != "Range", "nothing of the range is left where it stood")
	# 2. Trym's door goes up in the cabin's frame.
	var inv: Node = _root.get_node("Invitation")
	var cabin: Node4D = world.get_node("TrymCabin")
	var want: Vector4 = cabin.global_position + cabin.global_basis * Vector4(1.0, 0.0, 10.7, 0.0)
	var got: Vector4 = inv.call("_door_spot")
	_check(Vector2(got.x - want.x, got.z - want.z).length() < 0.01, "Trym's door goes up in front of his cabin, wherever it is (%s)" % str(got))
	# 3. The balloon's pass over the farm has the pen below it.
	var lookout: Node = _root.get_node_or_null("Systems/Lookout")
	var balloon: Node4D = lookout.get("balloon") as Node4D if lookout != null else null
	if balloon != null:
		var host: Node4D = balloon.get_parent() as Node4D
		var moor: Vector4 = balloon.get("_moor")
		var ride_basis: Projection = balloon.get("ride_basis")
		var at: Vector4 = moor + ride_basis * ((balloon.call("_path", 38.0) as Vector4) + (balloon.call("_pen_shift") as Vector4))
		var g: Vector4 = host.global_position + host.global_basis * at
		var pen: Vector4 = (_root.get_node("Pen") as Node4D).global_position
		var d: float = Vector2(g.x - pen.x, g.z - pen.z).length()
		_check(d < 5.0, "38 s into the ride the pen is below the basket (%.1f m off; 4.0 as drawn)" % d)
	else:
		_check(false, "the balloon exists")
	# 4. No chicken's home is inside a building.
	var inside: Array = []
	for c in _root.get_node("Chickens").get_children():
		if c is Node4D:
			var home: Vector4 = (c as Node4D).global_position
			var hit: Array = _down(home.x, home.z, home.w)
			if hit[1] != "" and hit[1] != "Cave":
				inside.append("%s in %s" % [c.name, hit[1]])
	_check(inside.is_empty(), "no chicken starts inside a building %s" % str(inside))
	# 5. The cave's way in: not where it was, and where it is now (last: it starts the crossing).
	var hill: Node4D = CaveHill.node_in(world.get_node("Cave"))
	var player: Node4D = _root.get_node("Player")
	var recipe = CaveHill.new()
	var way_in: Vector4 = (recipe.way_in() as Array)[0]
	player.global_position = way_in + Vector4(0.0, 0.2, 0.0, 0.0)
	await _frames(20)
	_check(not bool(hill.get("_used")), "standing where the cave's way in was does nothing now")
	var now_at: Vector4 = CaveHill.to_world(hill, way_in)
	player.global_position = now_at + Vector4(0.0, 0.2, 0.0, 0.0)
	await _frames(20)
	_check(bool(hill.get("_used")), "standing where it is now takes you in (%s)" % str(now_at))
	print("MOVED PEN %s: %d failed" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)
