extends SceneTree

## Hunts the "split" seen when dragging a body ball.
##
## Sweeps the brachiosaurus's middle spine ball through a range of heights and
## reports three things per position:
##
## - CHAIN ORDER. The root chain is sorted by HEIGHT, so dragging a ball past its
##   neighbour silently reorders the chain and the surface rewires itself. That
##   would read as a tear appearing out of nowhere.
## - BUILT. If two consecutive balls land near enough to coincide, _build_chain
##   bails out and returns null - and a skipped chain means that whole piece
##   VANISHES while the rest of the animal stays, which looks exactly like a split.
## - INVERTED. DO NOT TRUST THIS COLUMN. It was an attempt to detect a loft folding
##   through itself, which neither existing check can see - watertightness is
##   topological, so a self-intersecting surface is still "watertight" and still
##   passes the winding check. But it reports ~40% of tetrahedra as inverted on a
##   model that renders perfectly, so it is measuring surface curvature rather than
##   inversion. Left here only because the problem it aimed at is real and still
##   unsolved; a working detector needs a different approach.

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

	var spine: Node = _instance.get_node("Models/Brachio/Spine")
	spine.verbose = false
	var ball: Node = spine.get_node("Ball2")
	var original: Vector4 = ball.position

	print("Ball2 rest height is %.1f; Ball1 sits at 17.5 and Ball3 at 20.5." % original.y)
	print("%8s  %-7s %-9s %s" % ["Ball2 y", "built", "inverted", "chain order"])
	for height in [19.5, 18.5, 17.6, 17.5, 17.4, 16.0, 14.0, 21.0, 22.0]:
		ball.position = Vector4(original.x, height, original.z, original.w)
		spine.build(false)
		var chain: Array = spine._collect_chains()[0]
		var names: Array[String] = []
		for entry in chain:
			names.append(entry.name.replace("Ball", ""))
		var mesh: ArrayTetraMesh4D = spine.mesh
		print("%8.1f  %-7s %-9s %s" % [
			height, "yes" if mesh != null else "NO",
			str(_inverted_count(mesh, chain)) if mesh != null else "-",
			"-".join(names)])
	ball.position = original
	return true


static func _nearest_on_polyline(centers: PackedVector4Array, point: Vector4) -> Vector4:
	var best: Vector4 = centers[0]
	var best_distance: float = point.distance_to(best)
	for index in range(centers.size() - 1):
		var a: Vector4 = centers[index]
		var b: Vector4 = centers[index + 1]
		var span: Vector4 = b - a
		var length_squared: float = span.dot(span)
		if length_squared < 1e-9:
			continue
		var t: float = clampf((point - a).dot(span) / length_squared, 0.0, 1.0)
		var candidate: Vector4 = a + span * t
		var distance: float = point.distance_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


## Tetrahedra whose outward normal points back toward the chain it was built
## around. On a tube that cannot happen unless the surface has folded through
## itself, which is what a bend tighter than the section radius produces.
func _inverted_count(mesh: ArrayTetraMesh4D, chain: Array) -> int:
	var centers := PackedVector4Array()
	for ball in chain:
		centers.append(ball.get_loft_section()["center"])
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	var inverted: int = 0
	for cell in range(cells.size() / 4):
		var a: Vector4 = positions[cells[cell * 4]]
		var b: Vector4 = positions[cells[cell * 4 + 1]]
		var c: Vector4 = positions[cells[cell * 4 + 2]]
		var d: Vector4 = positions[cells[cell * 4 + 3]]
		var centroid: Vector4 = (a + b + c + d) / 4.0
		# Nearest point on the SPINE POLYLINE, not the nearest ball. Sections here are
		# ~8 units apart on a body 5 units thick, so snapping to the nearest ball
		# leaves a large axial component in "outward" and the test flips at random.
		var outward: Vector4 = centroid - _nearest_on_polyline(centers, centroid)
		if outward.length() < 0.0001:
			continue
		if Vector4D.perpendicular(b - a, c - a, d - a).dot(outward) < 0.0:
			inverted += 1
	return inverted
