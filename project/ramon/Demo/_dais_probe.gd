extends SceneTree

## Confirms the dais actually has geometry, and records how the cubinder's
## cross-section behaves under slice rotation.
##
## `to_tetra_mesh` returning a non-null mesh is not proof of anything - an empty
## mesh is also non-null, and an unlit or invisible dais would look identical to a
## missing one from the structural verifier's point of view. This counts cells and
## measures the bounds directly.


func _init() -> void:
	var shape := CubinderShape4D.new()
	shape.radius = 13.845
	shape.height = 0.2
	shape.thickness = 60.0

	for segments in [8, 16, 48]:
		var mesh: TetraMesh4D = shape.to_tetra_mesh({"segments": segments})
		if mesh == null:
			print("segments=%d -> NULL" % segments)
			continue
		var verts: PackedVector4Array = mesh.get_vertices()
		var cells: PackedInt32Array = mesh.get_simplex_cell_indices()
		# How far the faceted rim bows INSIDE the true circle, midway between two
		# vertices. Measuring vertex radii instead would report zero error at every
		# segment count, because an inscribed polygon puts every vertex exactly on
		# the radius - it is the flats between them that fall short.
		var max_r := 0.0
		for v in verts:
			max_r = maxf(max_r, sqrt(v.x * v.x + v.z * v.z))
		var sagitta := max_r * (1.0 - cos(PI / float(segments)))
		print(
			"segments=%2d  verts=%4d  cell_indices=%5d  tets=%4d  rim %.3f m, flats bow in %.1f cm"
			% [segments, verts.size(), cells.size(), cells.size() / 4, max_r, sagitta * 100.0]
		)

	# The stretch the doc comment claims: a disc in XZ extruded along w presents a
	# cross-section scaled by 1/cos(theta) after theta of zw rotation.
	print("--- zw rotation stretch of the visible disc ---")
	for degrees in [15.0, 30.0, 45.0]:
		var theta := deg_to_rad(degrees)
		print("  %4.0f deg -> %.1f%% wider in z, clipped beyond |z| = %.0f m"
			% [degrees, (1.0 / cos(theta) - 1.0) * 100.0, 30.0 / sin(theta)])

	quit()
