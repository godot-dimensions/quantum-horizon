extends SceneTree

## Why pulling a mid-body ball sideways produces a fin.
##
## It is not a frame swap - the frames rotate smoothly. It is MITRE BLOW-UP, the
## standard failure of lofting round a sharp corner.
##
## A section sits square to the local direction, and at a corner "the local
## direction" is the bisector of the two segments meeting there. The section is
## therefore a plane cutting the corner diagonally, and the tube's surface has to
## stretch by 1 / cos(half the turn angle) to reach it. At a 90 degree turn that is
## 1.4x and looks fine; at 140 degrees it is 2.9x and the section is nearly edge-on
## to the tube, so the surface flares into a blade. One section simply cannot
## express a sharp corner - which is why Spore INSERTS more metaballs as you
## stretch a limb rather than stretching the ones you have.
##
## Measured as how far the surface strays from the spine, in multiples of the
## radius. A healthy tube stays at about 1.0.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

## A thin tube bends cleanly; the artifact only appears once sections are thick
## relative to how far apart they sit, which is exactly the brachiosaurus body.
## The chicken's body is radius 0.44 on ~0.28 spacing - sections WIDER than they
## are apart. Nothing tested before went past 0.75.
const _CASES: Array = [[1.5, 4.0], [5.4, 8.0], [1.0, 1.0], [1.5, 1.0], [0.44, 0.28]]

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	print("%7s %8s %6s %10s %14s %10s" % ["radius", "spacing", "ratio", "turn deg", "bulge", "inverted"])
	for case in _CASES:
		for pull in [0.0, 2.0, 4.0, 8.0]:
			_run(case[0], case[1], pull)
	return true


func _run(radius: float, spacing: float, pull: float) -> void:
	if true:
		var sections: Array = []
		for index in range(5):
			var offset: float = pull if index == 2 else 0.0
			sections.append({
				"center": Vector4(offset, float(index) * spacing, 0.0, 0.0),
				"radius": radius, "v_scale": 1.0, "w_scale": 1.0})

		var turn: float = 2.0 * atan2(pull, spacing)
		var mesh: ArrayTetraMesh4D = _Builder.build(sections, 6, 12, true, false, true)
		var centers := PackedVector4Array()
		for section in sections:
			centers.append(section["center"])
		var bulge: float = 0.0
		var positions: PackedVector4Array = mesh.get_vertex_positions()
		for p in positions:
			bulge = maxf(bulge, p.distance_to(_nearest_on_polyline(centers, p)))

		# On a straight tube every outward normal must point away from the spine, so
		# this MUST read 0% at pull 0. If it does not, the detector is broken and its
		# numbers mean nothing; if it does, then whatever it counts as the tube bends
		# is real folding of the surface through itself.
		var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
		var inverted: int = 0
		for cell in range(cells.size() / 4):
			var a: Vector4 = positions[cells[cell * 4]]
			var b: Vector4 = positions[cells[cell * 4 + 1]]
			var c: Vector4 = positions[cells[cell * 4 + 2]]
			var d: Vector4 = positions[cells[cell * 4 + 3]]
			var centroid: Vector4 = (a + b + c + d) * 0.25
			var outward: Vector4 = centroid - _nearest_on_polyline(centers, centroid)
			if outward.length() > 0.0001 and Vector4D.perpendicular(b - a, c - a, d - a).dot(outward) < 0.0:
				inverted += 1
		print("%7.1f %8.1f %6.2f %10.1f %13.2fx %8.1f%%" % [
			radius, spacing, radius / spacing, rad_to_deg(turn), bulge / radius,
			100.0 * float(inverted) / float(cells.size() / 4)])


static func _nearest_on_polyline(centers: PackedVector4Array, point: Vector4) -> Vector4:
	var best: Vector4 = centers[0]
	var best_distance: float = point.distance_to(best)
	for index in range(centers.size() - 1):
		var a: Vector4 = centers[index]
		var span: Vector4 = centers[index + 1] - a
		var length_squared: float = span.dot(span)
		if length_squared < 1e-9:
			continue
		var candidate: Vector4 = a + span * clampf((point - a).dot(span) / length_squared, 0.0, 1.0)
		var distance: float = point.distance_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
