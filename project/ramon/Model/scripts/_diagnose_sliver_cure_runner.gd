extends SceneTree

## Measures which knob actually removes slivers, on the two spans that have them.
##
## Three candidates, and guessing between them is exactly the mistake to avoid:
## resolution (fewer rings puts the first ring further from the pole, so the pole
## triangles are less pinched), smoothing (more sections along the span, so each prism
## is less stretched), and neither.
##
## Reports the engine's shape number for the worst cell, where anything at or below
## CMP_EPSILON (0.00001) is what makes it throw the closest-point cache away.
##
## FOLDING IS REPORTED ALONGSIDE, because the two failures pull on the same lever from
## opposite ends: slivers come from spans too LONG for how wide the sections are, and
## folding from spans too SHORT. Smoothing shortens spans, so a cure for one is a
## plausible cause of the other, and a fix that only counted slivers would hide it.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	# The beak branch as it is now: anchor on the head, then base, mid and a fine tip.
	var beak: Array = [
		_section(Vector4(0.0, 1.68, 0.53, 0.0), 0.165),
		_section(Vector4(0.0, 1.71, 0.64, 0.0), 0.075),
		_section(Vector4(0.0, 1.67, 0.78, 0.0), 0.048),
		_section(Vector4(0.0, 1.62, 0.92, 0.0), 0.02),
	]
	# A brachio spine span: wide sections, metres apart.
	var spine: Array = [
		_section(Vector4(0.0, 13.0, -29.0, 0.0), 1.7),
		_section(Vector4(0.0, 11.0, -37.0, 0.0), 0.55),
		_section(Vector4(0.0, 9.0, -43.0, 0.0), 0.4),
	]
	_sweep("beak branch (as built: 10 sides, 6 rings)", beak, 10, 6)
	_sweep("brachio spine span (12 sides, 6 rings)", spine, 12, 6)
	return true


func _sweep(label: String, sections: Array, sides: int, rings: int) -> void:
	print("--- %s ---" % label)
	print("  as built:")
	_measure(sections, rings, sides, 1)
	print("  fewer rings:")
	for fewer in [5, 4, 3]:
		_measure(sections, fewer, sides, 1, "rings %d" % fewer)
	print("  more smoothing (sections inserted along each span):")
	for smoothing in [2, 3, 4]:
		_measure(sections, rings, sides, smoothing, "smoothing %d" % smoothing)


func _measure(sections: Array, rings: int, sides: int, smoothing: int, note: String = "as built") -> void:
	var mesh: ArrayTetraMesh4D = _Builder.build(sections, rings, sides, true, false, true, smoothing)
	if mesh == null:
		print("     %s -> failed to build" % note)
		return
	var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var count: int = cells.size() / 4
	var slivers: int = 0
	var worst: float = INF
	for cell in range(count):
		var shape: float = _Builder._cell_shape(
			positions[cells[cell * 4]], positions[cells[cell * 4 + 1]],
			positions[cells[cell * 4 + 2]], positions[cells[cell * 4 + 3]])
		worst = minf(worst, shape)
		if shape <= 0.00001:
			slivers += 1
	var folded: int = 0
	var centers := PackedVector4Array()
	for section in _sections_of(sections, smoothing):
		centers.append(section["center"])
	for cell in range(count):
		var a: Vector4 = positions[cells[cell * 4]]
		var b: Vector4 = positions[cells[cell * 4 + 1]]
		var c: Vector4 = positions[cells[cell * 4 + 2]]
		var d: Vector4 = positions[cells[cell * 4 + 3]]
		var centroid: Vector4 = (a + b + c + d) * 0.25
		var outward: Vector4 = centroid - _Builder._nearest_on_spine(centers, centroid)
		if outward.length() > 0.0001 and Vector4D.perpendicular(b - a, c - a, d - a).dot(outward) < 0.0:
			folded += 1
	print("     %s -> %d tets, %d slivers, %d folded, worst shape %.7f  %s" % [
		note, count, slivers, folded, worst,
		"OK" if slivers == 0 and folded == 0 else "still broken"])


func _sections_of(sections: Array, smoothing: int) -> Array:
	return _Builder.smooth_sections(sections, smoothing)


func _section(center: Vector4, radius: float) -> Dictionary:
	return {"center": center, "radius": radius, "v_scale": 1.0, "w_scale": 1.0}
