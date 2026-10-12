extends SceneTree

## Checks the two new section controls against measurable predictions rather than
## eyeballing them.
##
## ROLL: an ellipse rolled by 90 degrees should swap which axis is wide - the
## extents across the two visible axes trade places.
##
## SQUARENESS: a superellipsoid's corners reach further from the centre than a
## sphere's while its face centres do not, so the ratio of the furthest vertex to
## the nearest should climb from 1.0 (a sphere) as squareness rises, and the section
## must stay watertight throughout.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	print("--- roll on an ellipse (v_scale 0.35) ---")
	for roll in [0.0, 45.0, 90.0]:
		var mesh: ArrayTetraMesh4D = _Builder.build(_sections(roll, 0.0, 0.35), 6, 12, true, false, true, 1)
		var extent := _extent(mesh)
		print("   roll %5.0f deg -> extent across X = %.2f, across Z = %.2f" % [roll, extent.x, extent.z])

	print("--- squareness on a round section ---")
	for squareness in [-1.0, 0.0, 0.5, 1.0]:
		var mesh: ArrayTetraMesh4D = _Builder.build(_sections(0.0, squareness, 1.0), 6, 12, true, false, true, 1)
		var far: float = 0.0
		var near: float = INF
		for p in mesh.get_vertex_positions():
			var flat := Vector3(p.x, p.z, p.w)
			if absf(p.y - 1.0) < 0.01:
				far = maxf(far, flat.length())
				near = minf(near, flat.length())
		print("   squareness %5.2f (exponent %.2f) -> corner/face ratio %.3f" % [
			squareness, _Builder._squareness_exponent(squareness), far / maxf(near, 0.001)])
	return true


func _sections(roll: float, squareness: float, v_scale: float) -> Array:
	var out: Array = []
	for index in range(3):
		out.append({
			"center": Vector4(0.0, float(index), 0.0, 0.0), "radius": 1.0,
			"v_scale": v_scale, "w_scale": 1.0, "roll": roll, "squareness": squareness})
	return out


func _extent(mesh: ArrayTetraMesh4D) -> Vector3:
	var high := Vector3(-INF, -INF, -INF)
	var low := Vector3(INF, INF, INF)
	for p in mesh.get_vertex_positions():
		high = Vector3(maxf(high.x, p.x), maxf(high.y, p.y), maxf(high.z, p.z))
		low = Vector3(minf(low.x, p.x), minf(low.y, p.y), minf(low.z, p.z))
	return high - low
