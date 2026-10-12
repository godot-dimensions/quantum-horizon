extends RefCounted

## The Arboretum: space colonization as Runions, Lane and Prusinkiewicz describe it (Modeling Trees
## with a Space Colonization Algorithm, 2007), in 4D, for the oak.
##
## The Shrubbery Lab's generator (carried/shrubbery/shrub_generator.gd), which pedestals 01 to 03
## keep, lets every attraction point pull every tip in reach, and only tips grow. Grown in a wide
## crown that made the oak's trunk wander off to one side and spent its whole node budget on a few
## long limbs (case study 4). Here, as in the paper:
##
##   NEAREST    each attraction point pulls only the node nearest to it (within the radius of
##              influence), so neighbouring branches share out the space instead of all chasing one
##              cluster of points
##   ANY NODE   any node with points of its own grows a new node toward their average, so limbs
##              sprout from the side of the trunk and of each other (lateral buds), not only at tips
##   CONE       a node only perceives points within a cone round its own direction (the paper's
##              perception angle), so nothing grows back on itself
##   KILL       a point is removed once any node comes within the kill distance
##
## The trunk is grown straight first, to `trunk` metres, before the crown is let in (case study 3).
## Each point remembers its nearest node so far; each step only the nodes added since the last step
## are checked against it, which keeps a 2,000-node 4D tree to a second or two in GDScript.
##
## grow(points, opts) returns {"positions": PackedVector4Array, "parents": PackedInt32Array,
## "steps": int, "left": int (points never reached)}.
##
## NO class_name (engine_gotchas.md): preload it.


## `points` the attraction points (the tree's own space, root at the origin). `opts`: "segment" (m),
## "influence" (radius of influence, m), "kill" (m), "trunk" (m of straight trunk), "cone" (perception
## half-angle, degrees), "tropism" (a direction added to every step, its length the strength),
## "max_nodes", "steps".
static func grow(points: PackedVector4Array, opts: Dictionary) -> Dictionary:
	var seg: float = float(opts.get("segment", 0.3))
	var di: float = float(opts.get("influence", 2.0))
	var dk: float = float(opts.get("kill", 0.6))
	var trunk: float = float(opts.get("trunk", 1.5))
	var cos_cone: float = cos(deg_to_rad(float(opts.get("cone", 90.0))))
	var trop: Vector4 = opts.get("tropism", Vector4.ZERO)
	var max_nodes: int = int(opts.get("max_nodes", 2000))
	var steps: int = int(opts.get("steps", 120))

	var pos := PackedVector4Array([Vector4.ZERO])
	var par := PackedInt32Array([-1])
	var dirs := PackedVector4Array([Vector4(0, 1, 0, 0)])
	var n_trunk: int = int(ceil(trunk / seg))
	for k in n_trunk:
		pos.append(Vector4(0.0, trunk * float(k + 1) / float(n_trunk), 0.0, 0.0))
		par.append(k)
		dirs.append(Vector4(0, 1, 0, 0))

	var na: int = points.size()
	var alive := PackedByteArray()
	alive.resize(na)
	alive.fill(1)
	var near := PackedInt32Array()
	near.resize(na)
	near.fill(-1)
	var near_d := PackedFloat32Array()
	near_d.resize(na)
	near_d.fill(INF)
	# Each node's children's directions, so a node never grows the same child twice.
	var kids: Dictionary = {}
	var checked: int = 0
	var step: int = 0
	var left: int = na
	while step < steps and pos.size() < max_nodes:
		step += 1
		# The new nodes against every living point: nearest, and the kill.
		var n_now: int = pos.size()
		for a in na:
			if alive[a] == 0:
				continue
			var p: Vector4 = points[a]
			for n in range(checked, n_now):
				var v: Vector4 = p - pos[n]
				var d: float = v.length()
				if d <= dk:
					alive[a] = 0
					left -= 1
					break
				if d < di and d < near_d[a] and v.dot(dirs[n]) >= cos_cone * d:
					near_d[a] = d
					near[a] = n
		checked = n_now
		# Every node with points of its own grows one node toward their average.
		var pull: Dictionary = {}
		for a in na:
			if alive[a] == 0 or near[a] < 0:
				continue
			var n: int = near[a]
			var v: Vector4 = (points[a] - pos[n]) / maxf(near_d[a], 0.0001)
			pull[n] = (pull[n] as Vector4) + v if pull.has(n) else v
		var grew: int = 0
		for n in pull:
			if pos.size() >= max_nodes:
				break
			var s: Vector4 = pull[n]
			if s.length() < 0.0001:
				continue
			var dir: Vector4 = (s.normalized() + trop).normalized()
			var dup: bool = false
			for prev in (kids.get(n, []) as Array):
				if (prev as Vector4).dot(dir) > 0.995:
					dup = true
					break
			if dup:
				continue
			if not kids.has(n):
				kids[n] = []
			(kids[n] as Array).append(dir)
			pos.append(pos[n] + dir * seg)
			par.append(n)
			dirs.append(dir)
			grew += 1
		if grew == 0:
			break
	return {"positions": pos, "parents": par, "steps": step, "left": left}


## Attraction points inside `shape` (a crown_shape_4d.gd), `count` of them, by rejection inside its
## bounds.
static func sample(shape: RefCounted, count: int, seed: int) -> PackedVector4Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var b: Dictionary = shape.call("get_bounds")
	var lo: Vector4 = b["min"]
	var hi: Vector4 = b["max"]
	var out := PackedVector4Array()
	var tries: int = 0
	while out.size() < count and tries < count * 60:
		tries += 1
		var c := Vector4(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y), rng.randf_range(lo.z, hi.z), rng.randf_range(lo.w, hi.w))
		if bool(shape.call("contains", c)):
			out.append(c)
	return out
