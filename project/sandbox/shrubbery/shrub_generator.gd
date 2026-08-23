class_name ShrubGenerator4D
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

const VOXEL_ID_WOOD := 1
const VOXEL_ID_LEAF := 2

var branches: Array[ShrubBranch4D] = []
var attractors: Array[Dictionary] = [] # {position: Vector4, reached: bool}

var _rng: RandomNumberGenerator


func _init(seed_value: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value


func build_trunk(species: ShrubSpecies4D) -> void:
	branches.clear()
	var root := ShrubBranch4D.new(Vector4.ZERO, species.trunk_direction, species.trunk_thickness, -1, 0, 0)
	branches.append(root)


func spawn_attractors_from_tesseract(species: ShrubSpecies4D) -> void:
	attractors.clear()
	var center: Vector4 = species.attractor_center_offset
	var half: Vector4 = species.attractor_half_extents
	for i in range(species.attractor_count):
		var offset := Vector4(
			_rng.randf_range(-half.x, half.x),
			_rng.randf_range(-half.y, half.y),
			_rng.randf_range(-half.z, half.z),
			_rng.randf_range(-half.w, half.w)
		)
		attractors.append({"position": center + offset, "reached": false})


func clear_attractors() -> void:
	attractors.clear()


func grow(species: ShrubSpecies4D) -> void:
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
func _grow_step(species: ShrubSpecies4D) -> void:
	if branches.size() >= species.max_branches:
		return

	var has_child: Dictionary = {}
	for branch in branches:
		if branch.parent_index >= 0:
			has_child[branch.parent_index] = true

	var new_branches: Array[ShrubBranch4D] = []
	for tip_index in range(branches.size()):
		if has_child.has(tip_index):
			continue
		if branches.size() + new_branches.size() >= species.max_branches:
			break
		var tip: ShrubBranch4D = branches[tip_index]
		var allow_fork: bool = branches.size() + new_branches.size() + 1 < species.max_branches
		var directions: Array[Vector4] = _growth_directions(species, tip, allow_fork)
		for direction in directions:
			var new_position: Vector4 = tip.position + direction * species.segment_length
			var new_thickness: float = tip.thickness * species.branch_thickness_falloff
			var branch_id := branches.size() + new_branches.size()
			new_branches.append(ShrubBranch4D.new(new_position, direction, new_thickness, tip_index, tip.generation + 1, branch_id))

	for branch in new_branches:
		branches.append(branch)

	_consume_reached_attractors(species)


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
func _growth_directions(species: ShrubSpecies4D, tip: ShrubBranch4D, allow_fork: bool) -> Array[Vector4]:
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


func _apply_bias(species: ShrubSpecies4D, direction: Vector4) -> Vector4:
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


func _consume_reached_attractors(species: ShrubSpecies4D) -> void:
	for attractor in attractors:
		if attractor.reached:
			continue
		for branch in branches:
			if branch.position.distance_to(attractor.position) <= species.kill_distance:
				attractor.reached = true
				break


## Rasterizes the whole branch graph (thickness-aware capsule-like
## segments) plus glome (4D hypersphere) leaf clusters across the outer
## branches into a sparse voxel set. Returns packed-int64 key (see
## pack_voxel_key) -> VOXEL_ID_* Dictionary, matching voxel_world_4d.gd's
## own brick_key convention exactly so this storage scheme composes with
## the rest of the terrain/voxel code without a translation layer.
func voxelize(species: ShrubSpecies4D) -> Dictionary:
	var voxels: Dictionary = {}
	for branch in branches:
		if branch.parent_index < 0:
			continue
		var parent: ShrubBranch4D = branches[branch.parent_index]
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
		var branch: ShrubBranch4D = branches[i]
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


## Samples points along the segment at roughly half a voxel apart and
## marks every cell within `thickness*0.5` of each sample point solid - a
## simple, correct-enough thickness-aware capsule rasterization for v1
## (no distance-competition between overlapping branches yet, unlike
## shrubbery's own closest-distance rule - every branch just claims its
## own cells outright, acceptable since branches rarely overlap at v1's
## segment_length/thickness scale). `thickness` is treated as a diameter
## (radius = thickness*0.5), matching the export's own doc comment.
## Previously ignored entirely (every segment rasterized as a single-
## voxel-wide centerline regardless of its own thickness value) - a real
## gap, not a simplification, since a "thicker trunk" request has nothing
## to actually widen without this.
func _rasterize_segment(voxels: Dictionary, from_position: Vector4, to_position: Vector4, thickness: float, voxel_size: float) -> void:
	var length: float = from_position.distance_to(to_position)
	var steps: int = maxi(1, int(ceil(length / (voxel_size * 0.5))))
	var radius: float = maxf(thickness * 0.5, voxel_size * 0.5) # Never thinner than one voxel across.
	var cell_radius: int = int(ceil(radius / voxel_size))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var point: Vector4 = from_position.lerp(to_position, t)
		if cell_radius <= 0:
			voxels[pack_voxel_key(world_to_cell(point, voxel_size))] = VOXEL_ID_WOOD
			continue
		var center_cell: Vector4i = world_to_cell(point, voxel_size)
		for dx in range(-cell_radius, cell_radius + 1):
			for dy in range(-cell_radius, cell_radius + 1):
				for dz in range(-cell_radius, cell_radius + 1):
					for dw in range(-cell_radius, cell_radius + 1):
						var cell: Vector4i = center_cell + Vector4i(dx, dy, dz, dw)
						if cell_center(cell, voxel_size).distance_to(point) <= radius:
							voxels[pack_voxel_key(cell)] = VOXEL_ID_WOOD


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
