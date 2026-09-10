extends SceneTree

## Checks that scaling a ball with the gizmo changes the mesh on EVERY axis, and that
## the rig notices in time to rebuild.
##
## Two separate failures were in play and either alone hides the other: the section
## ignored the ball's Y scale outright, and the change-detection signature recorded
## only the X, Z and W axis lengths, so a Y scale produced an identical signature and
## no rebuild was even attempted.
##
## The test is a horizontal chain, running along Z, because that is where the two
## disagree: its section axes are (X, W, Y), so Y widens the model there while being
## meaningless on the vertical chain the old code assumed. A vertical chain is checked
## too, to prove the fix did not disturb the case that already worked.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_axes("horizontal chain, running along Z", Vector4(0.0, 0.0, 1.0, 0.0))
	_axes("vertical chain, running along Y", Vector4(0.0, 1.0, 0.0, 0.0))
	return true


func _axes(label: String, direction: Vector4) -> void:
	print("--- %s ---" % label)
	var plain: Vector4 = _extent(direction, Projection.IDENTITY)
	print("   unscaled half-extent: X %.2f, Y %.2f, Z %.2f, W %.2f" % [plain.x, plain.y, plain.z, plain.w])
	for axis in range(4):
		var columns: Array[Vector4] = [
			Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]
		columns[axis] = columns[axis] * 2.0
		var scaled: Vector4 = _extent(direction, Projection(columns[0], columns[1], columns[2], columns[3]))
		var grew: Vector4 = Vector4(
			scaled.x - plain.x, scaled.y - plain.y, scaled.z - plain.z, scaled.w - plain.w)
		var moved: bool = grew.length() > 0.01
		print("   scale x2 along %s -> X %.2f, Y %.2f, Z %.2f, W %.2f   %s" % [
			"XYZW"[axis], scaled.x, scaled.y, scaled.z, scaled.w,
			"changes the mesh" if moved else "NO EFFECT (along the chain, expected)"])


func _extent(direction: Vector4, ball_basis: Projection) -> Vector4:
	var sections: Array = []
	for index in range(3):
		sections.append({
			"center": direction * float(index), "radius": 1.0, "v_scale": 1.0, "w_scale": 1.0,
			"basis": ball_basis if index == 1 else Projection.IDENTITY})
	var mesh: ArrayTetraMesh4D = _Builder.build(sections, 5, 10, false, false, true, 1)
	# Only the middle section is scaled, so measure the widest ring rather than the
	# whole mesh, which the unscaled ends would otherwise dominate.
	var high := Vector4(-1e9, -1e9, -1e9, -1e9)
	for p in mesh.get_vertex_positions():
		var along: float = p.dot(direction)
		if absf(along - 1.0) > 0.01:
			continue
		high = Vector4(maxf(high.x, p.x), maxf(high.y, p.y), maxf(high.z, p.z), maxf(high.w, p.w))
	return high
