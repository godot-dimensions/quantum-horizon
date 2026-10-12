@tool
extends Resource

## The Arboretum: a tree's skeleton, the one source every way of building a tree in the room starts
## from (follow_up/arboretum.md, part C). Grown by the Shrubbery Lab's own 4D space colonization
## (carried/shrubbery/shrub_generator.gd: attraction points in a 4D crown, tips growing toward the
## ones in reach, points removed once reached), then made into a tree the way Runions, Lane and
## Prusinkiewicz do (Modeling Trees with a Space Colonization Algorithm, 2007):
##
##   SMOOTHED   the generator grows in straight 0.5 m steps, so a limb zigzags; each branch's inner
##              points are relaxed toward their neighbours a few times (its fork and its tip stay)
##   PIPES      every limb as thick as the twigs it carries: r^n = sum of the children's r^n (the pipe
##              model; n between 2 and 3 in real trees; in 4D a branch's cross-section is a ball, so
##              pipes that add up by cross-section make it 3), counted from a twig radius up
##   BRANCHES   the graph cut into branches (chains): at every fork the child carrying the most twigs
##              goes on as the same branch, the others start new ones; a branch's order is how many
##              forks it is from the trunk (0 the trunk, 1 a limb, ...), and it knows the branch it
##              grows from and how far along that one it starts
##   PIVOTS     each branch's base, direction, length and parent, with a flexibility (thin and long
##              is flexible) and its own sway frequency (the trunk slowest, twigs fastest) and phase:
##              what the wind needs (tree_pivots.gd packs them for the shaders)
##
## Saved as a .tres, so a baked tree and a tree grown again live share one source.
##
## NO class_name (engine_gotchas.md): preload it.

const Gen := preload("res://ramon/Arboretum/carried/shrubbery/shrub_generator.gd")
const Species := preload("res://ramon/Arboretum/carried/shrubbery/shrub_species.gd")

## Node positions (metres, the tree's own space, the root at the origin), parents (-1 for the root),
## radii (metres), how many twigs each carries, and the branch each node is on with how far along it.
@export var positions: PackedVector4Array = PackedVector4Array()
@export var parents: PackedInt32Array = PackedInt32Array()
@export var radii: PackedFloat32Array = PackedFloat32Array()
@export var twigs: PackedInt32Array = PackedInt32Array()
@export var node_branch: PackedInt32Array = PackedInt32Array()
@export var node_along: PackedFloat32Array = PackedFloat32Array()
## Branches: each a Dictionary {nodes: PackedInt32Array (its fork node first, then root to tip),
## parent: int (-1 for the trunk), attach: float (along the parent, 0 to 1), order: int,
## length: float, flex: float, freq: float, phase: float}.
@export var branches: Array = []
## How it was grown, for the cards: the generator's own node count, and milliseconds per stage.
@export var stats: Dictionary = {}


# -- growing ------------------------------------------------------------------------------------------

## Grows a skeleton from `sp` (a ShrubSpecies resource), then smooths it, sizes it by the pipe
## model and cuts it into branches. `pipe_n` the pipe exponent, `twig_r` a twig's radius (metres),
## `smooth_passes` how many relaxations.
static func grow(sp: Resource, pipe_n: float = 2.5, twig_r: float = 0.018, smooth_passes: int = 3, root_flare: float = 1.25, w_squash: float = 1.0) -> Resource:
	var sk: Resource = load("res://ramon/Arboretum/botany/tree_skeleton_4d.gd").new()
	var t0: int = Time.get_ticks_usec()
	var g: RefCounted = Gen.new(int(sp.get("seed")))
	g.call("build_trunk", sp)
	g.call("spawn_attractors_from_tesseract", sp)
	g.call("grow", sp)
	var t1: int = Time.get_ticks_usec()
	var src: Array = g.get("branches")
	var pos := PackedVector4Array()
	var par := PackedInt32Array()
	for b in src:
		pos.append(b.position)
		par.append(int(b.parent_index))
	sk.call("_build", pos, par, pipe_n, twig_r, smooth_passes, root_flare, w_squash)
	sk.stats = {"generator_nodes": src.size(), "grow_ms": (t1 - t0) / 1000.0, "shape_ms": (Time.get_ticks_usec() - t1) / 1000.0,
		"seed": int(sp.get("seed")), "pipe_n": pipe_n, "twig_r": twig_r, "w_squash": w_squash}
	return sk


## From a raw graph (positions and parents, parents before children): the tree.
## `w_squash` scales every point's W after growing: below 1 the tree is flatter through W than
## across (see follow_up/arboretum.md, the first pivot: a slice catches more of a flat tree, but a
## flat tree turned through W shows its edge).
func _build(pos: PackedVector4Array, par: PackedInt32Array, pipe_n: float, twig_r: float, smooth_passes: int, root_flare: float, w_squash: float = 1.0) -> void:
	var n: int = pos.size()
	positions = pos.duplicate()
	parents = par.duplicate()
	var children: Array = []
	children.resize(n)
	for i in n:
		children[i] = PackedInt32Array()
	for i in n:
		if parents[i] >= 0:
			var list: PackedInt32Array = children[parents[i]]
			list.append(i)
			children[parents[i]] = list
	# Twigs carried: a tip carries one; a node carries the sum of its children (children come after
	# their parents in the generator's order, so one backward pass).
	twigs = PackedInt32Array()
	twigs.resize(n)
	for i in range(n - 1, -1, -1):
		var c: PackedInt32Array = children[i]
		if c.is_empty():
			twigs[i] = 1
		else:
			var s: int = 0
			for k in c:
				s += twigs[k]
			twigs[i] = s
	# The pipe model: r = twig_r * twigs^(1/n). The root flares a little into the ground.
	radii = PackedFloat32Array()
	radii.resize(n)
	for i in n:
		radii[i] = twig_r * pow(float(twigs[i]), 1.0 / maxf(pipe_n, 1.0))
	if n > 0:
		radii[0] *= root_flare
	# Branches: from the root, the child with the most twigs goes on as the same branch.
	branches = []
	node_branch = PackedInt32Array()
	node_branch.resize(n)
	node_along = PackedFloat32Array()
	node_along.resize(n)
	_chain(0, -1, -1, 0, children)
	_smooth(smooth_passes)
	if w_squash != 1.0:
		for i in positions.size():
			var p: Vector4 = positions[i]
			p.w *= w_squash
			positions[i] = p
	_measure()


## Walks one branch from `start` (a node whose parent is `fork`, or the root), recursing into the
## branches that leave it.
func _chain(start: int, fork: int, parent_branch: int, order: int, children: Array) -> void:
	var nodes := PackedInt32Array()
	if fork >= 0:
		nodes.append(fork)
	var at: int = start
	var leaving: Array = []
	while true:
		nodes.append(at)
		var c: PackedInt32Array = children[at]
		if c.is_empty():
			break
		var best: int = c[0]
		for k in c:
			if twigs[k] > twigs[best]:
				best = k
		for k in c:
			if k != best:
				leaving.append([k, at])
		at = best
	var index: int = branches.size()
	branches.append({"nodes": nodes, "parent": parent_branch, "attach": 0.0, "order": order})
	for node in nodes:
		if fork >= 0 and node == fork:
			continue
		node_branch[node] = index
	for l in leaving:
		_chain(int(l[0]), int(l[1]), index, order + 1, children)


## Relaxes each branch's inner points toward their neighbours (its first and last stay).
func _smooth(passes: int) -> void:
	for p in passes:
		var next: PackedVector4Array = positions.duplicate()
		for b in branches:
			var nodes: PackedInt32Array = b["nodes"]
			for k in range(1, nodes.size() - 1):
				var i: int = nodes[k]
				if i == 0:
					continue
				var a: Vector4 = positions[nodes[k - 1]]
				var c: Vector4 = positions[nodes[k + 1]]
				next[i] = positions[i].lerp((a + c) * 0.5, 0.5)
		positions = next


## Lengths, how far along its branch each node is, where each branch joins its parent, and the wind's
## numbers per branch.
func _measure() -> void:
	var trunk_r: float = radii[0] if radii.size() > 0 else 0.1
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for bi in branches.size():
		var b: Dictionary = branches[bi]
		var nodes: PackedInt32Array = b["nodes"]
		var total: float = 0.0
		var cum := PackedFloat32Array([0.0])
		for k in range(1, nodes.size()):
			total += positions[nodes[k]].distance_to(positions[nodes[k - 1]])
			cum.append(total)
		b["length"] = total
		for k in nodes.size():
			var i: int = nodes[k]
			if node_branch[i] == bi:
				node_along[i] = cum[k] / maxf(total, 0.0001)
		var r0: float = radii[nodes[mini(1, nodes.size() - 1)]]
		# Thin and long bends more: a cantilever's tip moves as length^2 / radius^2 under a load
		# spread along it, kept in a range the eye reads as wood.
		var flex: float = clampf(pow(total / 2.0, 1.2) * pow(trunk_r / maxf(r0, 0.004), 0.6) * 0.12, 0.05, 1.6)
		if int(b["parent"]) < 0:
			flex = 0.35
		b["flex"] = flex
		# The trunk sways slowest; each order above it faster.
		b["freq"] = 0.32 * pow(1.55, float(int(b["order"])))
		b["phase"] = rng.randf() * 10.0
		branches[bi] = b
	for bi in branches.size():
		var b: Dictionary = branches[bi]
		var nodes: PackedInt32Array = b["nodes"]
		var pb: int = int(b["parent"])
		if pb >= 0 and nodes.size() > 0:
			b["attach"] = node_along[nodes[0]] if node_branch[nodes[0]] == pb else 0.0
		branches[bi] = b


## A copy with every W divided by `k`: grid builders (the voxels, the engine's voxel world) can build
## the tree in this squeezed space and stretch the mesh's W back by `k`, so every branch comes out
## `k` times deeper in W than across.
func squeezed(k: float) -> Resource:
	var out: Resource = duplicate(true)
	if k == 1.0:
		return out
	var pos: PackedVector4Array = out.get("positions")
	for i in pos.size():
		var p: Vector4 = pos[i]
		p.w /= k
		pos[i] = p
	out.set("positions", pos)
	return out


## Stretches a mesh's W by `k` in place (after building it squeezed).
static func stretch_w(m: ArrayTetraMesh4D, k: float) -> void:
	if k == 1.0 or m == null:
		return
	var b := Projection.IDENTITY
	b.w = Vector4(0, 0, 0, k)
	m.transform_mesh(Vector4.ZERO, b)


# -- reading ------------------------------------------------------------------------------------------

## Branch `bi`'s points, root to tip, and their radii.
func branch_points(bi: int) -> PackedVector4Array:
	var out := PackedVector4Array()
	for i in (branches[bi]["nodes"] as PackedInt32Array):
		out.append(positions[i])
	return out


func branch_radii(bi: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var nodes: PackedInt32Array = branches[bi]["nodes"]
	for k in nodes.size():
		# A branch's first point is its fork on the parent: the branch itself is only as thick as its
		# own second point there.
		var i: int = nodes[k]
		out.append(radii[nodes[mini(k + 1, nodes.size() - 1)]] if k == 0 and int(branches[bi]["parent"]) >= 0 else radii[i])
	return out


## The tips: nodes with no children (the twig ends), and the nodes within `depth` of one.
func tips() -> PackedInt32Array:
	var has_child: Dictionary = {}
	for i in parents.size():
		if parents[i] >= 0:
			has_child[parents[i]] = true
	var out := PackedInt32Array()
	for i in parents.size():
		if not has_child.has(i):
			out.append(i)
	return out


## Bounds of the nodes: {"min", "max"}.
func bounds() -> Dictionary:
	var lo := Vector4(INF, INF, INF, INF)
	var hi := Vector4(-INF, -INF, -INF, -INF)
	for p in positions:
		lo = lo.min(p)
		hi = hi.max(p)
	return {"min": lo, "max": hi}


## The highest order of any branch.
func max_order() -> int:
	var m: int = 0
	for b in branches:
		m = maxi(m, int(b["order"]))
	return m


## For the cards.
func summary() -> Dictionary:
	var bb: Dictionary = bounds()
	var ext: Vector4 = bb["max"] - bb["min"]
	return {"nodes": positions.size(), "branches": branches.size(), "tips": tips().size(), "orders": max_order() + 1,
		"height": ext.y, "width": maxf(ext.x, ext.z), "w_depth": ext.w, "trunk_r": radii[0] if radii.size() > 0 else 0.0}


## The nearest point of any branch to `p`: [branch, along]. Brute force over every segment; callers
## with many points use a SegmentIndex (tree_pivots.gd).
func nearest_branch(p: Vector4) -> Array:
	var best: float = INF
	var out: Array = [0, 0.0]
	for bi in branches.size():
		var nodes: PackedInt32Array = branches[bi]["nodes"]
		for k in range(1, nodes.size()):
			var a: Vector4 = positions[nodes[k - 1]]
			var c: Vector4 = positions[nodes[k]]
			var ab: Vector4 = c - a
			var l2: float = ab.length_squared()
			var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
			var d: float = p.distance_squared_to(a + ab * t)
			if d < best:
				best = d
				var ta: float = node_along[nodes[k - 1]] if k - 1 > 0 or int(branches[bi]["parent"]) < 0 else 0.0
				var tb: float = node_along[nodes[k]]
				out = [bi, lerpf(ta, tb, t)]
	return out
