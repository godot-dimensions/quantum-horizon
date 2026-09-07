extends SceneTree

## Throwaway diagnostic. Re-runs the manifold check on the dual-contoured
## surface TWO ways, to separate a real topological hole from a bookkeeping
## artifact:
##
##   by index    - a face is identified by its three vertex INDICES. This is
##                 what the earlier check did, and it reported 11,664
##                 single-use faces. It cannot tell a genuine gap from two
##                 tetrahedra that meet perfectly in space but happen to name
##                 the same corner with different vertex ids - which the
##                 contour deliberately produces, since it emits one vertex
##                 per material pair (see MultiVertexDualContour4D._emit_component_vertex).
##
##   by position - a face is identified by its three vertex POSITIONS, so
##                 coincident-but-distinct vertices collapse together. This is
##                 the honest test of whether the surface is closed.
##
## If the by-position count collapses toward zero, the mesh is closed and the
## visible holes come from somewhere else (winding, backface culling, or the
## MIN_NORMALIZED_VOLUME sliver rejection). If it stays high, neighbouring
## cells genuinely disagree and the bug is in component detection.
##
## Delete this file once the question is answered.
##
## Run headless from the repo root:
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
##     --headless --path project --script res://ramon/voxel_port/manifold_check.gd

const GRID_SIZE := 12
## globewater | globe | cutoff - the baseline documented in follow_up/voxel_port.md.
const MODEL_LAYERS := (1 << 0) | (1 << 2) | (1 << 7)

## Positions are compared after scaling by this and rounding to an integer.
## Coincident vertices are written from the same solved Vector4, so they are
## bit-identical and any sane scale works; this only guards against a future
## change that recomputes rather than reuses.
const POSITION_SCALE := 10000.0

## Radii the baseline model uses, as fractions of grid size. The shoreline is
## the band where these two surfaces meet.
const WATER_RADIUS_FRACTION := 0.37
const GROUND_RADIUS_FRACTION := 0.35

## Faces whose centroid is within this many grid units of the water radius are
## counted as "at the shoreline". The two surfaces sit ~0.24 grid units apart
## at GRID_SIZE 12, so this is a little wider than the gap between them.
const SHORELINE_BAND := 0.5

## Reserved dictionary key used to tally faces that collapsed to a repeated
## corner, so they never masquerade as real triangles.
const DEGENERATE_KEY := "__degenerate__"


func _init() -> void:
	var terrain_script: GDScript = load("res://ramon/voxel_port/scripts/voxel_terrain_4d.gd")
	var terrain: Node = terrain_script.new()
	terrain.grid_size = GRID_SIZE
	terrain.model_layers = MODEL_LAYERS
	terrain._setup_noise()

	var field := VoxelField4D.new(GRID_SIZE)
	for model_name in terrain.selected_model_names():
		if not terrain._add_model_layer(field, model_name, GRID_SIZE):
			push_error("unknown model layer '%s'" % model_name)
	var contour := MultiVertexDualContour4D.new(field)
	contour.generate()
	terrain.free()

	_report(contour)
	quit()


func _report(contour: MultiVertexDualContour4D) -> void:
	var vertices: PackedVector4Array = contour.vertices
	var ground: PackedInt32Array = contour.ground_cells
	var water: PackedInt32Array = contour.water_cells

	print("=".repeat(64))
	print("grid_size            %d" % GRID_SIZE)
	print("vertices             %d" % vertices.size())
	print("ground tetrahedra    %d" % (ground.size() / 4))
	print("water tetrahedra     %d" % (water.size() / 4))
	print("total tetrahedra     %d" % ((ground.size() + water.size()) / 4))

	# Collapse coincident vertices to a canonical id, so "by position" is just
	# "by index" over the remapped ids. Cheaper than building string keys per
	# face, and it also tells us how much duplication exists at all.
	var canonical := PackedInt32Array()
	canonical.resize(vertices.size())
	var position_to_id: Dictionary = {}
	for i in range(vertices.size()):
		var v: Vector4 = vertices[i]
		var key := "%d,%d,%d,%d" % [
			roundi(v.x * POSITION_SCALE),
			roundi(v.y * POSITION_SCALE),
			roundi(v.z * POSITION_SCALE),
			roundi(v.w * POSITION_SCALE),
		]
		if position_to_id.has(key):
			canonical[i] = position_to_id[key]
		else:
			position_to_id[key] = i
			canonical[i] = i
	var distinct_positions: int = position_to_id.size()
	print("distinct positions   %d  (%d vertices collapse onto an existing position)"
			% [distinct_positions, vertices.size() - distinct_positions])
	print("=".repeat(64))

	print("")
	print("CONTOUR STATS")
	var stat_keys: Array = contour.stats.keys()
	stat_keys.sort()
	for key in stat_keys:
		print("  %-32s %s" % [key, contour.stats[key]])

	var by_index: Dictionary = _count_faces(ground, water, PackedInt32Array(), false)
	var by_position: Dictionary = _count_faces(ground, water, canonical, true)

	_print_counts("BY INDEX    (what the old check measured)", by_index)
	_print_counts("BY POSITION (the honest test)", by_position)

	_print_shoreline_breakdown(by_position, vertices, canonical)


## Returns {face_key: [use_count, is_water_face]}. When p_remap is non-empty,
## vertex indices are mapped through it first, collapsing coincident vertices.
func _count_faces(ground: PackedInt32Array, water: PackedInt32Array, p_remap: PackedInt32Array, use_remap: bool) -> Dictionary:
	var counts: Dictionary = {}
	_accumulate(counts, ground, p_remap, use_remap, false)
	_accumulate(counts, water, p_remap, use_remap, true)
	return counts


func _accumulate(counts: Dictionary, cells: PackedInt32Array, p_remap: PackedInt32Array, use_remap: bool, is_water: bool) -> void:
	var tetrahedron_count: int = cells.size() / 4
	for t in range(tetrahedron_count):
		var a: int = cells[t * 4 + 0]
		var b: int = cells[t * 4 + 1]
		var c: int = cells[t * 4 + 2]
		var d: int = cells[t * 4 + 3]
		if use_remap:
			a = p_remap[a]
			b = p_remap[b]
			c = p_remap[c]
			d = p_remap[d]
		# The 4 triangular faces of a tetrahedron, each the tet minus one vertex.
		_bump(counts, a, b, c, is_water)
		_bump(counts, a, b, d, is_water)
		_bump(counts, a, c, d, is_water)
		_bump(counts, b, c, d, is_water)


## Sorted triple as the key, so the two tetrahedra sharing a face agree on it
## regardless of the winding each saw it from.
func _bump(counts: Dictionary, i: int, j: int, k: int, is_water: bool) -> void:
	# After collapsing coincident vertices a "face" can have a repeated corner.
	# That is not a triangle and must not be counted as one - a sliver whose
	# corners coincide would otherwise manufacture matched pairs out of nothing
	# and hide a genuine boundary.
	if i == j or j == k or i == k:
		counts[DEGENERATE_KEY] = counts.get(DEGENERATE_KEY, 0) + 1
		return
	var tri := [i, j, k]
	tri.sort()
	var key := "%d/%d/%d" % tri
	if counts.has(key):
		var entry: Array = counts[key]
		entry[0] += 1
		if is_water:
			entry[1] = true
	else:
		counts[key] = [1, is_water]


func _print_counts(title: String, counts: Dictionary) -> void:
	var once := 0
	var twice := 0
	var more := 0
	for key in counts:
		if key == DEGENERATE_KEY:
			continue
		var used: int = counts[key][0]
		if used == 1:
			once += 1
		elif used == 2:
			twice += 1
		else:
			more += 1
	var total: int = once + twice + more
	print("")
	print(title)
	print("  distinct faces     %d" % total)
	print("  degenerate (skip)  %d  (corner repeated after collapsing)" % counts.get(DEGENERATE_KEY, 0))
	print("  used twice (good)  %d  (%.1f%%)" % [twice, 100.0 * float(twice) / maxf(1.0, float(total))])
	print("  used ONCE  (hole)  %d  (%.1f%%)" % [once, 100.0 * float(once) / maxf(1.0, float(total))])
	if more > 0:
		print("  used 3+   (bad!)   %d" % more)


## Splits the surviving single-use faces by where they sit. Clustering at the
## shoreline would mean the topology is arguably correct and component
## assignment legitimately shifts where ground meets water; an even spread
## across open terrain means neighbouring cells disagree and that is the bug.
func _print_shoreline_breakdown(counts: Dictionary, vertices: PackedVector4Array, canonical: PackedInt32Array) -> void:
	# One representative position per canonical id.
	var position_of: Dictionary = {}
	for i in range(vertices.size()):
		var id: int = canonical[i]
		if not position_of.has(id):
			position_of[id] = vertices[i]

	var center := Vector4(1, 1, 1, 1) * (float(GRID_SIZE) * 0.5)
	var water_radius: float = WATER_RADIUS_FRACTION * float(GRID_SIZE)
	var ground_radius: float = GROUND_RADIUS_FRACTION * float(GRID_SIZE)

	var at_shoreline := 0
	var elsewhere := 0
	var water_faces := 0
	var ground_faces := 0
	var histogram: Dictionary = {}

	for key in counts:
		if key == DEGENERATE_KEY:
			continue
		var entry: Array = counts[key]
		if entry[0] != 1:
			continue
		if entry[1]:
			water_faces += 1
		else:
			ground_faces += 1

		var parts: PackedStringArray = key.split("/")
		var centroid := Vector4.ZERO
		for p in parts:
			centroid += position_of[int(p)]
		centroid /= float(parts.size())

		var radius: float = (centroid - center).length()
		if absf(radius - water_radius) <= SHORELINE_BAND:
			at_shoreline += 1
		else:
			elsewhere += 1

		var bucket: int = int(floor(radius - ground_radius))
		histogram[bucket] = histogram.get(bucket, 0) + 1

	var total: int = at_shoreline + elsewhere
	print("")
	print("SURVIVING SINGLE-USE FACES, BY LOCATION")
	if total == 0:
		print("  none - the surface is closed. The visible holes are NOT a")
		print("  topology problem; look at winding, backface culling, or the")
		print("  MIN_NORMALIZED_VOLUME sliver rejection instead.")
		return
	print("  total              %d" % total)
	print("  on ground surface  %d" % ground_faces)
	print("  on water surface   %d" % water_faces)
	print("  at shoreline       %d  (%.1f%%)  [within %.2f of r=%.2f]"
			% [at_shoreline, 100.0 * float(at_shoreline) / float(total), SHORELINE_BAND, water_radius])
	print("  elsewhere          %d  (%.1f%%)" % [elsewhere, 100.0 * float(elsewhere) / float(total)])
	print("")
	print("  radial histogram (grid units from ground radius r=%.2f):" % ground_radius)
	var buckets: Array = histogram.keys()
	buckets.sort()
	for b in buckets:
		var count: int = histogram[b]
		var bar := "#".repeat(clampi(count * 60 / maxi(1, total), 0, 60))
		print("   %+3d..%+3d  %6d  %s" % [b, b + 1, count, bar])
	print("")
	if float(at_shoreline) / float(total) > 0.6:
		print("  VERDICT: clustered at the shoreline. Topology is arguably")
		print("  correct; the visible holes likely have another cause.")
	else:
		print("  VERDICT: spread across open terrain. Component detection is")
		print("  inconsistent between neighbouring cells - that is the bug.")
