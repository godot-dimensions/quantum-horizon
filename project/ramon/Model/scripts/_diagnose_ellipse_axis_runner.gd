extends SceneTree

## Which world axis does v_scale stretch, for a chain running along Z?
##
## Worth measuring rather than reading off the property names. Those describe the
## UNALIGNED frame (u = X, v = Z, n = W); with align_to_spine on, the frame is built
## perpendicular to the local spine direction, so a body laid out along Z gets a
## different assignment and the names no longer say what they mean.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")
var _done := false

func _process(_d) -> bool:
	if _done: return true
	_done = true
	for probe in [["round", 1.0, 1.0], ["v_scale = 2", 2.0, 1.0], ["w_scale = 2", 1.0, 2.0]]:
		var sections: Array = []
		for i in range(3):
			sections.append({"center": Vector4(0, 0, float(i), 0), "radius": 1.0,
				"v_scale": probe[1], "w_scale": probe[2]})
		var mesh: ArrayTetraMesh4D = _Builder.build(sections, 5, 10, false, false, true, 1)
		var hi := Vector4(-1e9, -1e9, -1e9, -1e9)
		for p in mesh.get_vertex_positions():
			hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
		print("%-12s -> half-extent X %.2f, Y %.2f, W %.2f" % [probe[0], hi.x, hi.y, hi.w])
	return true
