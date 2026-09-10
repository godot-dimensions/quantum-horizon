extends SceneTree

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

## Finds how far the brachiosaurus's shoulder ball can actually be grown before the
## surface folds, and reports the spacing to its neighbours so the limit makes
## sense rather than just being a number.

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var spine: Node = _instance.get_node("Models/Brachio/Spine")
	spine.verbose = false
	var shoulders: Node = spine.get_node("Ball3")
	var back: Vector4 = spine.get_node("Ball2").position
	var neck: Vector4 = spine.get_node("Ball4").position
	var gap_back: float = shoulders.position.distance_to(back)
	var gap_neck: float = shoulders.position.distance_to(neck)
	print("Ball3 (shoulders) sits %.1f from Ball2 behind it and %.1f from Ball4 ahead." % [gap_back, gap_neck])
	print("Its neighbours' radii are %.2f and %.2f." % [
		spine.get_node("Ball2").radius, spine.get_node("Ball4").radius])
	print("")
	print("%8s %8s %10s %14s" % ["radius", "vs gap", "spine folded", "front leg top"])

	var original: float = shoulders.radius
	for radius in [4.9, 6.0, 7.0, 8.0, 9.0, 10.0, 12.0, 14.0]:
		shoulders.radius = radius
		# The SPINE CHAIN ONLY. Measuring the rig's merged mesh counts leg
		# tetrahedra against the body's centreline, where they legitimately face
		# "inwards" because they belong to a different chain entirely.
		var sections: Array = []
		for ball in spine._collect_chains()[0]:
			sections.append(ball.get_loft_section())
		var mesh: ArrayTetraMesh4D = _Builder.build(sections, 5, 10, true, false, true)
		# How thick the front leg actually comes out where it meets the body: this is
		# what used to track the shoulder's radius instead of the leg's own.
		spine.build(false)
		var leg: ArrayTetraMesh4D = _Builder.build(_leg_sections(spine), 5, 10, true, false, true)
		var hip: Vector4 = spine.get_node("Ball3").position
		var thickest: float = 0.0
		for v in leg.get_vertex_positions():
			if absf(v.y - hip.y) < 1.0:
				thickest = maxf(thickest, absf(v.x - hip.x))
		print("%8.1f %8.2f %9.1f%% %13.2f" % [
			radius, radius / minf(gap_back, gap_neck), _folded_percent(mesh, sections), thickest])
	shoulders.radius = original
	return true


## Shares the builder's own test so this reports exactly what the warning reports.
func _folded_percent(mesh: ArrayTetraMesh4D, sections: Array) -> float:
	if mesh == null:
		return -1.0
	var centers := PackedVector4Array()
	for section in sections:
		centers.append(section["center"])
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	# Only the spine chain's own tetrahedra; the merged legs would dilute the number.
	var spine_cells: int = 0
	var folded: int = 0
	for cell in range(cells.size() / 4):
		var a: Vector4 = positions[cells[cell * 4]]
		var b: Vector4 = positions[cells[cell * 4 + 1]]
		var c: Vector4 = positions[cells[cell * 4 + 2]]
		var d: Vector4 = positions[cells[cell * 4 + 3]]
		var centroid: Vector4 = (a + b + c + d) * 0.25
		var nearest: Vector4 = _nearest(centers, centroid)
		spine_cells += 1
		var outward: Vector4 = centroid - nearest
		if outward.length() > 0.0001 and Vector4D.perpendicular(b - a, c - a, d - a).dot(outward) < 0.0:
			folded += 1
	return 100.0 * float(folded) / maxf(float(spine_cells), 1.0)


func _leg_sections(spine: Node) -> Array:
	for chain in spine._collect_chains():
		if chain.size() > 1 and String(chain[1].name).begins_with("FrontLeg"):
			var out: Array = []
			for ball in chain:
				out.append(ball.get_loft_section())
			var anchor: Dictionary = out[0].duplicate()
			anchor["radius"] = out[1]["radius"]
			anchor["v_scale"] = out[1].get("v_scale", 1.0)
			anchor["w_scale"] = out[1]["w_scale"]
			out[0] = anchor
			return out
	return []


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
