extends SceneTree

## The one number that decides whether a lofted creature can be animated at all.
##
## Rebuilding a rig per frame is out - the goat measures 168 ms. The alternative is
## SKINNING: build the topology once, and each frame only move the vertices, which is
## cheap in principle. But moving them means handing new positions to the engine, and
## the engine rebuilds its whole 3D proxy mesh from scratch when it does - 12 proxy
## vertices per tetrahedron, through SurfaceTool. If THAT alone exceeds a frame, no
## amount of cleverness on the GDScript side rescues the plan, and the design has to
## change rather than be optimised.
##
## Measured here against a 16.7 ms frame at 60 Hz and a 33.3 ms frame at 30 Hz.

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	for path in ["Models/Goat/Hide", "Models/Chicken/Body", "Models/Brachio/Spine"]:
		var rig: Node = _instance.get_node_or_null(path)
		if rig == null or rig.mesh == null:
			continue
		_measure(path, rig.mesh)
	return true


func _measure(label: String, mesh: ArrayTetraMesh4D) -> void:
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var cells: int = mesh.get_simplex_cell_vertex_indices().size() / 4

	# Repeated, and reported as the BEST of several runs. A single sample put a
	# 2400-cell mesh above a 14240-cell one, which cannot be true of the work itself -
	# that is one-off setup and scheduling noise, and a design decision this size
	# should not rest on it. The minimum is the closest thing to the real cost.
	var runs: int = 5
	var skin_us: int = 1 << 30
	var upload_us: int = 1 << 30
	var proxy_us: int = 1 << 30
	for run in range(runs):
		var start: int = Time.get_ticks_usec()
		var moved := PackedVector4Array()
		moved.resize(positions.size())
		for index in range(positions.size()):
			moved[index] = positions[index] + Vector4(0.0, 0.001, 0.0, 0.0)
		skin_us = mini(skin_us, Time.get_ticks_usec() - start)

		start = Time.get_ticks_usec()
		mesh.set_vertex_positions(moved)
		upload_us = mini(upload_us, Time.get_ticks_usec() - start)

		# Timed in a BATCH and divided, not one call at a time. Timing single calls
		# returned a flat ~15 ms for meshes of 2400, 9600 and 14240 cells alike, which
		# cannot be the work - 15.6 ms is the Windows scheduler tick, so that was the
		# clock's resolution, not the engine's cost.
		start = Time.get_ticks_usec()
		for batch in range(20):
			mesh.update_proxy_mesh_3d()
		proxy_us = mini(proxy_us, (Time.get_ticks_usec() - start) / 20)

	var total: float = float(skin_us + upload_us + proxy_us) / 1000.0
	print("%s: %d cells, %d vertices" % [label, cells, positions.size()])
	print("   move vertices in GDScript %6.2f ms" % (float(skin_us) / 1000.0))
	print("   hand them to the mesh     %6.2f ms" % (float(upload_us) / 1000.0))
	print("   rebuild the 3D proxy      %6.2f ms" % (float(proxy_us) / 1000.0))
	print("   TOTAL %6.2f ms  ->  %s at 60Hz, %s at 30Hz" % [
		total,
		"fits" if total < 16.7 else "TOO SLOW",
		"fits" if total < 33.3 else "TOO SLOW"])
