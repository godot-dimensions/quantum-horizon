extends RefCounted
## Port of shrubbery's (github.com/TanTanDev/shrubbery) branch-graph growth
## + space-colonization + voxelize pipeline, generalized to 4D per the
## approved port plan. Pure logic, no Node/scene dependency by design -
## fully headless-testable (see _verify_shrubbery_phase1_runner.gd).
##
## v1 scope: one trunk, Attractor-driven growth (space colonization) with
## a separate gravity-lean and w-lean bias, one sphere/glome leaf shape at
## every branch tip. No ShrubberyStep pipeline abstraction, no
## ConiferWhorl/StarLeaf, no Gradient/RandomSolid decoration yet - all
## deliberately deferred per the port plan.
##
## Attractor search and reached-consumption are both brute-force O(n*m)
## scans, matching shrubbery's OWN implementation (confirmed directly: no
## spatial acceleration structure in the source project either) - not an
## oversight, just not yet a bottleneck at v1's scale (hundreds of
## attractors, tens of iterations).

## CARRIED (Arboretum, 5 Oct 2026): a copy of res://sandbox/shrubbery/shrub_generator.gd, its class_name taken out
## and its references preloaded (Arboretum/carried/README.md).
const ShrubBranch := preload("res://ramon/Arboretum/carried/shrubbery/shrub_branch.gd")
const ShrubSpecies := preload("res://ramon/Arboretum/carried/shrubbery/shrub_species.gd")
const AttractorShape := preload("res://ramon/Arboretum/carried/shrubbery/attractor_shape_4d.gd")


const VOXEL_ID_WOOD := 1
const VOXEL_ID_LEAF := 2

var branches: Array[ShrubBranch] = []
var attractors: Array[Dictionary] = [] # {position: Vector4, reached: bool}

var _rng: RandomNumberGenerator


func _init(seed_value: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value


func build_trunk(species: ShrubSpecies) -> void:
	branches.clear()
	var root := ShrubBranch.new(Vector4.ZERO, species.trunk_direction, species.trunk_thickness, -1, 0, 0)
	branches.append(root)


## Samples up to `count` attractor points from an arbitrary AttractorShape
## via rejection sampling: draw a uniform random point inside
## shape.get_bounds(), keep it if shape.contains() accepts it, repeat.
## Works identically for a plain BoxAttractorShape (the default/maximum
## shape - see ShrubSpecies.build_default_attractor_shape()) or a
## composite VoronoiAttractorShape4D (the forest scene's crown-shyness
## shape) - the generator itself never needs to know which.
##
## max_attempts is a safety cap, not a correctness requirement: a heavily
## eroded shape (many nearby Voronoi neighbors, aggressive crown shyness)
## can legitimately have only a small fraction of its bounding box
## actually accepted, in which case fewer than `count` attractors are
## returned - a real, desired consequence (a tightly-hemmed-in tree
## should grow SMALLER in the crowded direction, not spin forever trying
## to force a fixed attractor count into a shrinking space).
func spawn_attractors_from_shape(shape: AttractorShape, count: int) -> void:
	attractors.clear()
	var bounds: Dictionary = shape.get_bounds()
	var max_attempts: int = count * 50
	var attempts := 0
	while attractors.size() < count and attempts < max_attempts:
		attempts += 1
		var candidate := Vector4(
			_rng.randf_range(bounds.min.x, bounds.max.x),
			_rng.randf_range(bounds.min.y, bounds.max.y),
			_rng.randf_range(bounds.min.z, bounds.max.z),
			_rng.randf_range(bounds.min.w, bounds.max.w)
		)
		if shape.contains(candidate):
			attractors.append({"position": candidate, "reached": false})


## Convenience wrapper matching the single-tree lab's own usage - builds
## the species' own default box shape (centered at attractor_center_offset,
## no Voronoi/crown-shyness composition) and spawns from it. The forest
## scene calls spawn_attractors_from_shape() directly with a
## VoronoiAttractorShape4D instead.
func spawn_attractors_from_tesseract(species: ShrubSpecies) -> void:
	spawn_attractors_from_shape(species.build_default_attractor_shape(), species.attractor_count)


func clear_attractors() -> void:
	attractors.clear()


func grow(species: ShrubSpecies) -> void:
	for _iteration in range(species.iterations):
		_grow_step(species)


## Every current tip (a branch with no child yet) advances by one OR TWO
## segments - two exactly when its own in-range attractors cluster into
## two sufficiently divergent groups (see _growth_directions) - a real
## fork, not just noise within one general direction. Tips are recomputed
## fresh each iteration rather than tracked incrementally - O(n) per
## iteration, O(n^2) total across the whole grow() call, acceptable at
## v1 scale and simpler than maintaining a live tip set across appends.
##
## This forking step is not a refinement - without it, EVERY tip grows
## exactly one child forever, meaning the entire structure is a single
## continuous unbranching chain (confirmed directly: an earlier version
## without this produced exactly that, which reads as an aimless
## wandering/spiraling path once deep inside a confined attractor cloud,
## not a tree at all).
##
## Hard safety ceiling (species.max_branches): forking is, by nature,
## potentially EXPONENTIAL - every fork doubles its own two children's
## chance of independently forking again next step, and early in growth
## (before attractors are meaningfully depleted) most tips entering the
## attractor cloud can satisfy the geometric fork condition at once.
## Confirmed directly, not guessed: an earlier version gating only NEW
## forks (never the ALREADY-forked population's own continued linear
## growth) still measured 5502 branches and a 9.8s voxelize() against a
## 500 cap - once explosive forking produces hundreds of tips within the
## first several iterations, even zero further forking still means
## hundreds of tips each growing by 1 segment for every REMAINING
## iteration, which alone blows well past the cap. Fixed here by making
## the cap a hard FREEZE on all growth (not just new forks) the moment
## it's reached, and by making forking itself probabilistic (see
## _growth_directions' own fork_probability comment) so branch count
## grows at a tamed rate rather than doubling whenever geometrically
## eligible - the same class of risk this project has hit before with
## uncapped procedural generation (see subdivided_box_tetra_mesh_4d.gd's
## own MAX_SUBDIVISIONS_PER_AXIS).
func _grow_step(species: ShrubSpecies) -> void:
	if branches.size() >= species.max_branches:
		return

	var has_child: Dictionary = {}
	for branch in branches:
		if branch.parent_index >= 0:
			has_child[branch.parent_index] = true

	var new_branches: Array[ShrubBranch] = []
	for tip_index in range(branches.size()):
		if has_child.has(tip_index):
			continue
		if branches.size() + new_branches.size() >= species.max_branches:
			break
		var tip: ShrubBranch = branches[tip_index]
		var allow_fork: bool = branches.size() + new_branches.size() + 1 < species.max_branches
		var directions: Array[Vector4] = _growth_directions(species, tip, allow_fork)
		for direction in directions:
			var new_position: Vector4 = tip.position + direction * species.segment_length
			var new_thickness: float = tip.thickness * species.branch_thickness_falloff
			var branch_id := branches.size() + new_branches.size()
			new_branches.append(ShrubBranch.new(new_position, direction, new_thickness, tip_index, tip.generation + 1, branch_id))

	var first_new: int = branches.size()
	for branch in new_branches:
		branches.append(branch)

	_consume_reached_attractors(species, first_new)


## Returns 1 growth direction normally, or 2 when a real fork is
## detected (see _try_split), allow_fork is true (see _grow_step's own
## max_branches safety ceiling), AND a fork_probability roll succeeds.
## The probability roll matters, not just the safety cap: with
## min_attractors_to_fork/fork_angle_threshold_deg loose enough to be
## geometrically satisfied often (typical once a tip is inside a dense-
## enough attractor cloud), forking on EVERY eligible step alone produced
## near-exponential branch-count growth (5502 branches measured against
## a 500 cap, entirely from tips that had already forked before the cap
## engaged) - fork_probability tames the RATE of forking directly,
## independent of and in addition to the hard cap, rather than relying
## on the cap alone to survive an inherently explosive process.
## Gravity/w-lean bias is applied to EACH resulting direction
## independently (after any split), not before - a fork should split
## around the attractor-driven direction, with gravity/w-lean then
## shaping each new branch on its own.
func _growth_directions(species: ShrubSpecies, tip: ShrubBranch, allow_fork: bool) -> Array[Vector4]:
	var attractor_dirs: Array[Vector4] = []
	for attractor in attractors:
		if attractor.reached:
			continue
		var to_attractor: Vector4 = attractor.position - tip.position
		var dist: float = to_attractor.length()
		if dist <= species.attract_distance and dist > 0.0001:
			attractor_dirs.append(to_attractor / dist)

	if allow_fork and attractor_dirs.size() >= species.min_attractors_to_fork and _rng.randf() < species.fork_probability:
		var split: Variant = _try_split(attractor_dirs, species.fork_angle_threshold_deg)
		if split != null:
			var pair: Array = split
			return [
				_apply_bias(species, (tip.direction + pair[0]).normalized()),
				_apply_bias(species, (tip.direction + pair[1]).normalized()),
			]

	var pull := Vector4.ZERO
	for d in attractor_dirs:
		pull += d
	if pull.length() > 0.0001:
		pull = pull.normalized()
	return [_apply_bias(species, (tip.direction + pull).normalized())]


func _apply_bias(species: ShrubSpecies, direction: Vector4) -> Vector4:
	var biased: Vector4 = direction
	# Gravity is real and stays on -Y - see shrub_species.gd's own comment
	# on why this is never generalized to an arbitrary lean axis.
	if species.gravity_lean_strength > 0.0:
		biased = (biased + Vector4(0, -1, 0, 0) * species.gravity_lean_strength).normalized()
	# w_lean is a deliberately separate knob - see shrub_species.gd.
	if species.w_lean_strength != 0.0:
		biased = (biased + Vector4(0, 0, 0, 1) * species.w_lean_strength).normalized()
	return biased


## Simple, fast 2-cluster split: picks the two attractor directions that
## are FARTHEST apart (by angle) as seeds, assigns every other direction
## to whichever seed it's closer to, and returns [cluster_a_average,
## cluster_b_average] if BOTH clusters end up non-empty AND the seeds'
## own angle exceeds fork_angle_threshold_deg - null otherwise (spread
## within one general direction isn't a real fork). O(n^2) in
## attractor_dirs.size() - fine at this scale (a handful to a few dozen
## per tip, not the whole attractor set).
func _try_split(attractor_dirs: Array[Vector4], threshold_deg: float) -> Variant:
	var best_dot := 2.0
	var seed_a := 0
	var seed_b := 0
	for i in range(attractor_dirs.size()):
		for j in range(i + 1, attractor_dirs.size()):
			var d: float = attractor_dirs[i].dot(attractor_dirs[j])
			if d < best_dot:
				best_dot = d
				seed_a = i
				seed_b = j
	var threshold_dot: float = cos(deg_to_rad(threshold_deg))
	if best_dot > threshold_dot:
		return null

	var sum_a := Vector4.ZERO
	var sum_b := Vector4.ZERO
	var count_a := 0
	var count_b := 0
	var dir_seed_a: Vector4 = attractor_dirs[seed_a]
	var dir_seed_b: Vector4 = attractor_dirs[seed_b]
	for d in attractor_dirs:
		if d.dot(dir_seed_a) >= d.dot(dir_seed_b):
			sum_a += d
			count_a += 1
		else:
			sum_b += d
			count_b += 1
	if count_a == 0 or count_b == 0:
		return null
	return [sum_a.normalized(), sum_b.normalized()]


## ARBORETUM (carried copy): only the branches added this step are checked. Every attraction point
## is placed before growth starts, so a point within the kill distance of an older branch was already
## removed in the step that branch was added; checking the new ones gives the same tree at a
## fraction of the cost (the oak's 950 nodes and 1,100 points made the full check minutes long).
func _consume_reached_attractors(species: ShrubSpecies, first_new: int = 0) -> void:
	for attractor in attractors:
		if attractor.reached:
			continue
		for bi in range(first_new, branches.size()):
			if branches[bi].position.distance_to(attractor.position) <= species.kill_distance:
				attractor.reached = true
				break


## Rasterizes the whole branch graph (thickness-aware capsule-like
## segments) plus glome (4D hypersphere) leaf clusters across the outer
## branches into a sparse voxel set. Returns packed-int64 key (see
## pack_voxel_key) -> VOXEL_ID_* Dictionary, matching voxel_world_4d.gd's
## own brick_key convention exactly so this storage scheme composes with
## the rest of the terrain/voxel code without a translation layer.
func voxelize(species: ShrubSpecies) -> Dictionary:
	var voxels: Dictionary = {}
	for branch in branches:
		if branch.parent_index < 0:
			continue
		var parent: ShrubBranch = branches[branch.parent_index]
		# branch.thickness (the CHILD's own, already-tapered value) is the
		# thickness of the segment being drawn from parent to this branch -
		# consistent with branch_thickness_falloff being applied once per
		# grown segment, not per node independent of its segment.
		_rasterize_segment(voxels, parent.position, branch.position, branch.thickness, species.voxel_size)

	var has_child: Dictionary = {}
	for i in range(branches.size()):
		if branches[i].parent_index >= 0:
			has_child[branches[i].parent_index] = true

	# Leaves cover the OUTER branches broadly (every node within the last
	# leafy_generation_depth generations of growth, not just literal
	# endpoints) - per explicit request for "leaf coverage on most of the
	# outer edges of branches," not one lump at a single point. Endpoints
	# are always included even if leafy_generation_depth is 0.
	var max_generation := 0
	for branch in branches:
		max_generation = maxi(max_generation, branch.generation)
	var leafy_generation_threshold: int = maxi(0, max_generation - species.leafy_generation_depth)
	for i in range(branches.size()):
		var branch: ShrubBranch = branches[i]
		var is_tip: bool = not has_child.has(i)
		if is_tip or branch.generation >= leafy_generation_threshold:
			_rasterize_glome(voxels, branch.position, species.leaf_radius, species.voxel_size)

	return voxels


## Masks each coordinate to 16 bits (two's complement) before packing -
## identical scheme to voxel_world_4d.gd's own brick_key(), reused
## verbatim rather than reinvented, since it's proven, gives plenty of
## range, and keeps the two systems' packed keys mutually unambiguous if
## they're ever compared or stored together.
static func pack_voxel_key(coord: Vector4i) -> int:
	return ((coord.x & 0xFFFF) << 48) | ((coord.y & 0xFFFF) << 32) | ((coord.z & 0xFFFF) << 16) | (coord.w & 0xFFFF)


## Inverse of pack_voxel_key - sign-extends each 16-bit field back to a
## signed int (two's complement). Shared here (not duplicated per mesh
## builder) since more than one now needs it.
static func unpack_voxel_key(key: int) -> Vector4i:
	var x := (key >> 48) & 0xFFFF
	var y := (key >> 32) & 0xFFFF
	var z := (key >> 16) & 0xFFFF
	var w := key & 0xFFFF
	if x >= 0x8000: x -= 0x10000
	if y >= 0x8000: y -= 0x10000
	if z >= 0x8000: z -= 0x10000
	if w >= 0x8000: w -= 0x10000
	return Vector4i(x, y, z, w)


static func world_to_cell(position: Vector4, voxel_size: float) -> Vector4i:
	return Vector4i(
		int(floor(position.x / voxel_size)),
		int(floor(position.y / voxel_size)),
		int(floor(position.z / voxel_size)),
		int(floor(position.w / voxel_size))
	)


static func cell_center(cell: Vector4i, voxel_size: float) -> Vector4:
	return Vector4(
		(cell.x + 0.5) * voxel_size,
		(cell.y + 0.5) * voxel_size,
		(cell.z + 0.5) * voxel_size,
		(cell.w + 0.5) * voxel_size
	)


## Rasterizes a thickness-aware capsule around the segment via ONE
## bounding-box pass with a real point-to-segment distance test per
## candidate cell - not the earlier approach of sampling many points
## along the segment and re-scanning a full ball of cells around EACH
## one. That earlier version was a real, measured performance bug, not
## just inelegant: consecutive sample points (spaced half a voxel apart)
## have heavily OVERLAPPING balls, so the same cells were redundantly
## re-checked ~10x over per segment. Confirmed as the dominant cost in a
## 30-tree forest scene measuring ~0.9s/tree (voxelize() alone was ~0.55s
## of that, per shrubbery_lab.gd's own per-stage timing) - unacceptable
## for a "regenerate on demand, like a terrain chunk" use case. A single
## bounding-box pass visits each candidate cell once.
##
## `thickness` is treated as a diameter (radius = thickness*0.5), matching
## the export's own doc comment.
func _rasterize_segment(voxels: Dictionary, from_position: Vector4, to_position: Vector4, thickness: float, voxel_size: float) -> void:
	var radius: float = maxf(thickness * 0.5, voxel_size * 0.5) # Never thinner than one voxel across.
	var seg_dir: Vector4 = to_position - from_position
	var seg_length_sq: float = seg_dir.length_squared()

	var box_min := Vector4(
		minf(from_position.x, to_position.x) - radius,
		minf(from_position.y, to_position.y) - radius,
		minf(from_position.z, to_position.z) - radius,
		minf(from_position.w, to_position.w) - radius
	)
	var box_max := Vector4(
		maxf(from_position.x, to_position.x) + radius,
		maxf(from_position.y, to_position.y) + radius,
		maxf(from_position.z, to_position.z) + radius,
		maxf(from_position.w, to_position.w) + radius
	)
	var cell_min: Vector4i = world_to_cell(box_min, voxel_size)
	var cell_max: Vector4i = world_to_cell(box_max, voxel_size)

	for x in range(cell_min.x, cell_max.x + 1):
		for y in range(cell_min.y, cell_max.y + 1):
			for z in range(cell_min.z, cell_max.z + 1):
				for w in range(cell_min.w, cell_max.w + 1):
					var cell := Vector4i(x, y, z, w)
					var p: Vector4 = cell_center(cell, voxel_size)
					if _point_segment_distance(p, from_position, seg_dir, seg_length_sq) <= radius:
						voxels[pack_voxel_key(cell)] = VOXEL_ID_WOOD


## Distance from `p` to the closest point on segment [a, a+ab] - `ab` and
## its squared length are passed in precomputed since a caller rasterizing
## one segment calls this once per candidate cell (easily thousands of
## calls) against the SAME segment.
static func _point_segment_distance(p: Vector4, a: Vector4, ab: Vector4, ab_length_sq: float) -> float:
	if ab_length_sq < 0.0000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / ab_length_sq, 0.0, 1.0)
	var closest: Vector4 = a + ab * t
	return p.distance_to(closest)


func _rasterize_glome(voxels: Dictionary, center: Vector4, radius: float, voxel_size: float) -> void:
	var cell_radius: int = int(ceil(radius / voxel_size))
	var center_cell: Vector4i = world_to_cell(center, voxel_size)
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			for dz in range(-cell_radius, cell_radius + 1):
				for dw in range(-cell_radius, cell_radius + 1):
					var cell: Vector4i = center_cell + Vector4i(dx, dy, dz, dw)
					if cell_center(cell, voxel_size).distance_to(center) <= radius:
						voxels[pack_voxel_key(cell)] = VOXEL_ID_LEAF


## Bounds of the branch graph ALONE (not voxelized geometry) - cheap,
## used by the Phase 1 verify runner to report W extent as a fraction of
## X/Y/Z extent, per the port plan's own sharpened done-criterion (a
## technically-nonzero-but-negligible W sliver must be caught here, not
## three phases later).
func branch_bounds() -> Dictionary:
	var min_pos := Vector4(INF, INF, INF, INF)
	var max_pos := Vector4(-INF, -INF, -INF, -INF)
	for branch in branches:
		min_pos = min_pos.min(branch.position)
		max_pos = max_pos.max(branch.position)
	return {"min": min_pos, "max": max_pos, "extent": max_pos - min_pos}
