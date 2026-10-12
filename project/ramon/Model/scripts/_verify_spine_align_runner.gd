extends SceneTree

## Two objective checks on a stack that leans hard in both X and W.
##
## SKEW: if a cross-section sits square to the spine, none of its vertices should
## have any extent ALONG the spine - they all lie in the plane perpendicular to it.
## So measure each vertex's component along the TRUE spine direction (taken from
## the section centres, never from the frame, or the unaligned case trivially
## measures its own flat "up" and reports zero). Near zero means square; large
## means sheared, which is the squashed diagonal tube seen in the editor.
##
## ELLIPSE: with v_scale away from 1.0 the section's extent across its two visible
## axes should differ by exactly that factor.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var leaning: Array = [
		{"center": Vector4(0.0, 0.0, 0.0, 0.0), "radius": 1.0, "v_scale": 1.0, "w_scale": 1.0},
		{"center": Vector4(1.5, 1.5, 0.0, 1.0), "radius": 1.0, "v_scale": 1.0, "w_scale": 1.0},
		{"center": Vector4(3.0, 3.0, 0.0, 2.0), "radius": 1.0, "v_scale": 1.0, "w_scale": 1.0},
	]
	var spine: Vector4 = ((leaning[2]["center"] as Vector4) - (leaning[0]["center"] as Vector4)).normalized()

	print("--- skew, measured against the real spine direction ---")
	for aligned in [false, true]:
		var mesh: ArrayTetraMesh4D = _Builder.build(leaning, 6, 12, true, false, aligned)
		var spread: float = _middle_extent(mesh, leaning[1]["center"], spine)
		print("align_to_spine=%-5s  spread along spine = %.3f   (0.000 = square, so no shear)" % [aligned, spread])

	print("--- ellipse ---")
	var elliptical: Array = [
		{"center": Vector4(0.0, 0.0, 0.0, 0.0), "radius": 1.0, "v_scale": 0.4, "w_scale": 1.0},
		{"center": Vector4(0.0, 2.0, 0.0, 0.0), "radius": 1.0, "v_scale": 0.4, "w_scale": 1.0},
		{"center": Vector4(0.0, 4.0, 0.0, 0.0), "radius": 1.0, "v_scale": 1.0, "w_scale": 1.0},
	]
	var mesh_e: ArrayTetraMesh4D = _Builder.build(elliptical, 6, 12, true, false, true)
	var frames: Array = _Builder.build_frames(elliptical, true)
	var per_section: int = (_Builder.build_profile_surface(6, 12)["directions"] as PackedVector3Array).size()
	var positions: PackedVector4Array = mesh_e.get_vertex_positions()
	for index in [0, 2]:
		var center: Vector4 = elliptical[index]["center"]
		var extent_u: float = 0.0
		var extent_v: float = 0.0
		for vertex in range(per_section * index, per_section * (index + 1)):
			var offset: Vector4 = positions[vertex] - center
			extent_u = maxf(extent_u, absf(offset.dot(frames[index][0])))
			extent_v = maxf(extent_v, absf(offset.dot(frames[index][1])))
		print("section %d (v_scale=%.1f): extent across axis 1 = %.2f, across axis 2 = %.2f  -> ratio %.2f" % [
			index, elliptical[index]["v_scale"], extent_u, extent_v, extent_v / extent_u
		])
	return true


func _middle_extent(mesh: ArrayTetraMesh4D, center: Vector4, direction: Vector4) -> float:
	var per_section: int = (_Builder.build_profile_surface(6, 12)["directions"] as PackedVector3Array).size()
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var spread: float = 0.0
	for index in range(per_section, per_section * 2):
		spread = maxf(spread, absf((positions[index] - center).dot(direction)))
	return spread
