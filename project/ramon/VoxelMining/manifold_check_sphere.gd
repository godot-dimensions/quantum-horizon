extends SceneTree
## Throwaway diagnostic, same method as project/ramon/voxel_port/
## manifold_check.gd: build the exact field VoxelMiningSphereBlock currently
## builds (grid_size 16, box_fill_fraction 0.65, the parameters live on
## RockBlock_Sphere in voxel_mining_shapes_test.tscn right now), dual-contour
## it, then count how many triangular faces are used by exactly one
## tetrahedron ("by position", so coincident-but-distinct vertex ids collapse
## together - the honest test of whether the surface is closed).
##
## Single material here (no water), so there is no shoreline case to split
## out the way the terrain version does - every single-use face is a genuine
## candidate hole, full stop.
##
## Delete this file once the question is answered.
##
## Run headless from the repo root:
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
##     --headless --path project --script res://ramon/VoxelMining/manifold_check_sphere.gd

const GRID_SIZE := 16
const BOX_FILL_FRACTION := 0.65
const CELL_SIZE := 0.4
const MINING_RADIUS_METERS := 0.48
const CARVE_COUNT := 20
const POSITION_SCALE := 10000.0
const DEGENERATE_KEY := "__degenerate__"


func _init() -> void:
	var center: Vector4 = Vector4.ONE * (float(GRID_SIZE) * 0.5)
	var radius: float = float(GRID_SIZE) * 0.5 * BOX_FILL_FRACTION

	var field := VoxelField4D.new(GRID_SIZE)
	field.add_layer(
		VoxelField4D.VoxelMaterial.GROUND,
		func(p: Vector4) -> float:
			return radius - (p - center).length(),
		func(p: Vector4) -> Vector4:
			var offset: Vector4 = center - p
			var length: float = offset.length()
			return Vector4.ZERO if is_zero_approx(length) else offset / length,
		1.0)

	print("--- base sphere ---")
	var base_contour := DualContour4D.new(field)
	base_contour.generate()
	_report(base_contour)

	_simulate_mining_session(field, center, radius)

	print("")
	print("--- after %d carves (a real mining session) ---" % CARVE_COUNT)
	var mined_contour := DualContour4D.new(field)
	mined_contour.generate()
	_report(mined_contour)

	quit()


## Carves CARVE_COUNT bites at actual surface points (GROUND with at least
## one AIR neighbor), the way a player mining inward from outside actually
## would - not at arbitrary interior points a player could never reach first.
func _simulate_mining_session(field: VoxelField4D, center: Vector4, sphere_radius: float) -> void:
	var radius_in_cells: float = MINING_RADIUS_METERS / CELL_SIZE
	var surface_points: Array[Vector4i] = []
	for x in range(field.size):
		for y in range(field.size):
			for z in range(field.size):
				for w in range(field.size):
					var p := Vector4i(x, y, z, w)
					if field.material_at(p) != VoxelField4D.VoxelMaterial.GROUND:
						continue
					if _touches_air(field, p):
						surface_points.append(p)

	print("surface points available: %d" % surface_points.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in range(CARVE_COUNT):
		if surface_points.is_empty():
			break
		var index: int = rng.randi_range(0, surface_points.size() - 1)
		var grid_point: Vector4i = surface_points[index]
		var origin := Vector4(grid_point.x, grid_point.y, grid_point.z, grid_point.w)
		field.add_layer(
			VoxelField4D.VoxelMaterial.AIR,
			func(p: Vector4) -> float:
				return radius_in_cells - (p - origin).length(),
			func(p: Vector4) -> Vector4:
				var offset: Vector4 = origin - p
				var length: float = offset.length()
				return Vector4.ZERO if is_zero_approx(length) else offset / length,
			1.0,
			1 << VoxelField4D.VoxelMaterial.GROUND)
		# Recompute surface points fresh each carve, same as the real game
		# does via _rebuild_colliders - a carve exposes new surface for the
		# next hit to land on.
		surface_points.clear()
		for x in range(field.size):
			for y in range(field.size):
				for z in range(field.size):
					for w in range(field.size):
						var p := Vector4i(x, y, z, w)
						if field.material_at(p) == VoxelField4D.VoxelMaterial.GROUND and _touches_air(field, p):
							surface_points.append(p)


func _touches_air(field: VoxelField4D, p: Vector4i) -> bool:
	for axis in range(4):
		for delta in [-1, 1]:
			var neighbor: Vector4i = p
			neighbor[axis] += delta
			if field.is_inside(neighbor) and field.material_at(neighbor) != VoxelField4D.VoxelMaterial.GROUND:
				return true
	return false


func _report(contour: DualContour4D) -> void:
	var vertices: PackedVector4Array = contour.vertices
	var ground: PackedInt32Array = contour.ground_cells

	print("=".repeat(64))
	print("grid_size            %d" % GRID_SIZE)
	print("box_fill_fraction    %.3f" % BOX_FILL_FRACTION)
	print("vertices             %d" % vertices.size())
	print("ground tetrahedra    %d" % (ground.size() / 4))
	print("=".repeat(64))

	print("")
	print("CONTOUR STATS")
	var stat_keys: Array = contour.stats.keys()
	stat_keys.sort()
	for key in stat_keys:
		print("  %-32s %s" % [key, contour.stats[key]])

	# Collapse coincident vertices to a canonical id.
	var canonical := PackedInt32Array()
	canonical.resize(vertices.size())
	var position_to_id: Dictionary = {}
	for i in range(vertices.size()):
		var v: Vector4 = vertices[i]
		var key := "%d,%d,%d,%d" % [
			roundi(v.x * POSITION_SCALE), roundi(v.y * POSITION_SCALE),
			roundi(v.z * POSITION_SCALE), roundi(v.w * POSITION_SCALE),
		]
		if position_to_id.has(key):
			canonical[i] = position_to_id[key]
		else:
			position_to_id[key] = i
			canonical[i] = i

	var counts: Dictionary = {}
	_accumulate(counts, ground, canonical)

	var once := 0
	var twice := 0
	var more := 0
	for key in counts:
		if key == DEGENERATE_KEY:
			continue
		var used: int = counts[key]
		if used == 1:
			once += 1
		elif used == 2:
			twice += 1
		else:
			more += 1
	var total: int = once + twice + more

	print("")
	print("BY POSITION (the honest test)")
	print("  distinct faces     %d" % total)
	print("  degenerate (skip)  %d" % counts.get(DEGENERATE_KEY, 0))
	print("  used twice (good)  %d  (%.2f%%)" % [twice, 100.0 * float(twice) / maxf(1.0, float(total))])
	print("  used ONCE  (hole)  %d  (%.2f%%)" % [once, 100.0 * float(once) / maxf(1.0, float(total))])
	if more > 0:
		print("  used 3+   (bad!)   %d" % more)
	print("")
	if once == 0:
		print("VERDICT: closed manifold, zero holes at this resolution.")
	else:
		print("VERDICT: %d open faces - a real gap, not just a rare one-off." % once)


func _accumulate(counts: Dictionary, cells: PackedInt32Array, remap: PackedInt32Array) -> void:
	var tetrahedron_count: int = cells.size() / 4
	for t in range(tetrahedron_count):
		var a: int = remap[cells[t * 4 + 0]]
		var b: int = remap[cells[t * 4 + 1]]
		var c: int = remap[cells[t * 4 + 2]]
		var d: int = remap[cells[t * 4 + 3]]
		_bump(counts, a, b, c)
		_bump(counts, a, b, d)
		_bump(counts, a, c, d)
		_bump(counts, b, c, d)


func _bump(counts: Dictionary, i: int, j: int, k: int) -> void:
	if i == j or j == k or i == k:
		counts[DEGENERATE_KEY] = counts.get(DEGENERATE_KEY, 0) + 1
		return
	var tri := [i, j, k]
	tri.sort()
	var key := "%d/%d/%d" % tri
	counts[key] = counts.get(key, 0) + 1
