extends SceneTree

## Compares the brachiosaurus spine chain at each smoothing level, reporting the
## three things that could explain visible tears: whether it is still watertight,
## how much of it folds through itself, and how thick the sections have become
## RELATIVE TO THEIR SPACING - because inserting sections shortens the spacing while
## leaving the radius alone, which is exactly the ratio that drives folding.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var rig: Node = _instance.get_node("Models/Brachio/Spine")
	rig.verbose = false

	var authored: Array = []
	for ball in rig._collect_chains()[0]:
		var section: Dictionary = ball.get_loft_section()
		section["center"] = rig._position_in_rig(ball)
		authored.append(section)

	print("%9s %9s %11s %10s %12s" % ["smoothing", "sections", "tetrahedra", "worst r/gap", "folded"])
	for segments in [1, 2, 3, 4]:
		var smoothed: Array = _Builder.smooth_sections(authored, segments)
		var worst: float = 0.0
		for index in range(smoothed.size() - 1):
			var gap: float = (smoothed[index]["center"] as Vector4).distance_to(smoothed[index + 1]["center"])
			if gap > 0.0001:
				worst = maxf(worst, float(smoothed[index]["radius"]) / gap)
		var mesh: ArrayTetraMesh4D = _Builder.build(authored, 6, 12, true, false, true, segments)
		var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
		print("%9d %9d %11d %10.2f %11.1f%%" % [
			segments, smoothed.size(), cells.size() / 4, worst,
			100.0 * float(_folded(mesh, smoothed)) / float(cells.size() / 4)])
	return true


func _folded(mesh: ArrayTetraMesh4D, sections: Array) -> int:
	var centers := PackedVector4Array()
	for section in sections:
		centers.append(section["center"])
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	var count: int = 0
	for cell in range(cells.size() / 4):
		var a: Vector4 = positions[cells[cell * 4]]
		var b: Vector4 = positions[cells[cell * 4 + 1]]
		var c: Vector4 = positions[cells[cell * 4 + 2]]
		var d: Vector4 = positions[cells[cell * 4 + 3]]
		var centroid: Vector4 = (a + b + c + d) * 0.25
		var outward: Vector4 = centroid - _nearest(centers, centroid)
		if outward.length() > 0.0001 and Vector4D.perpendicular(b - a, c - a, d - a).dot(outward) < 0.0:
			count += 1
	return count


static func _nearest(centers: PackedVector4Array, point: Vector4) -> Vector4:
	var best: Vector4 = centers[0]
	var best_distance: float = point.distance_to(best)
	for index in range(centers.size() - 1):
		var start: Vector4 = centers[index]
		var span: Vector4 = centers[index + 1] - start
		var length_squared: float = span.dot(span)
		if length_squared < 1e-9:
			continue
		var candidate: Vector4 = start + span * clampf((point - start).dot(span) / length_squared, 0.0, 1.0)
		var distance: float = point.distance_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
