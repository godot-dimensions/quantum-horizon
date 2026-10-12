extends SceneTree

## Checks that smoothing does what it claims: bends the centreline through the balls
## rather than between them, without moving the balls themselves.
##
## The test shape is a right-angle corner - three balls forming an L. Unsmoothed,
## the midpoint of each span sits exactly on the straight line between two balls.
## Smoothed, it should bow away from that line, and the balls themselves must stay
## exactly where they were put.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var sections: Array = [
		{"center": Vector4(0.0, 0.0, 0.0, 0.0), "radius": 0.4, "v_scale": 1.0, "w_scale": 1.0},
		{"center": Vector4(0.0, 3.0, 0.0, 0.0), "radius": 0.8, "v_scale": 1.0, "w_scale": 1.0},
		{"center": Vector4(3.0, 3.0, 0.0, 0.0), "radius": 0.4, "v_scale": 1.0, "w_scale": 1.0},
	]

	print("%9s %9s %11s %s" % ["smoothing", "sections", "tetrahedra", "centreline"])
	for segments in [1, 2, 4, 8]:
		var smoothed: Array = _Builder.smooth_sections(sections, segments)
		var mesh: ArrayTetraMesh4D = _Builder.build(sections, 4, 8, true, false, true, segments)
		var trail: Array[String] = []
		for entry in smoothed:
			var c: Vector4 = entry["center"]
			trail.append("(%.2f,%.2f)" % [c.x, c.y])
		print("%9d %9d %11d %s" % [
			segments, smoothed.size(),
			mesh.get_simplex_cell_vertex_indices().size() / 4,
			" ".join(trail) if smoothed.size() <= 9 else "%d points" % smoothed.size()])

	# The authored balls must still be ON the curve, not merely near it.
	var smoothed: Array = _Builder.smooth_sections(sections, 4)
	for index in range(sections.size()):
		var authored: Vector4 = sections[index]["center"]
		var found: Vector4 = smoothed[index * 4]["center"]
		print("   ball %d authored at (%.2f, %.2f), curve passes through (%.2f, %.2f) - %s" % [
			index + 1, authored.x, authored.y, found.x, found.y,
			"exact" if authored.distance_to(found) < 0.0001 else "MOVED"])
	return true
