extends SceneTree
## Which chain folds, and is the gizmo scaling to blame?
##
## Two balls carry a basis with a Y scale (Barrel 1.23, Poll 1.62). The builder applies
## a ball's basis to its whole cross-section, so a scale along an axis that is NOT
## perpendicular to the local spine stretches the section ALONG the chain - and a
## section stretched along the chain runs into its neighbours. Baking the same scale
## into radius/w_scale instead keeps the section perpendicular, so comparing the two is
## the test.
const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")
var _i: Node
var _f := 0
func _initialize() -> void:
	_i = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(_i)
func _process(_d) -> bool:
	_f += 1
	if _f < 5: return false
	var rig: Node = _i.get_node("Creature/Strider/Hide")
	print("--- as authored (gizmo scale live on the balls) ---")
	_report(rig)
	print("--- after baking those scales into radius/w_scale ---")
	for ball in _all(rig):
		if ball.has_method("bake_basis_scale"):
			ball.bake_basis_scale()
	rig.build(false)
	_report(rig)
	return true
func _all(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c.has_method("get_loft_section"):
			out.append(c); out.append_array(_all(c))
	return out
func _report(rig: Node) -> void:
	for chain in rig._collect_chains():
		if chain.size() < 2: continue
		var sections: Array = []
		var names: Array = []
		for b in chain:
			var s: Dictionary = b.get_loft_section()
			s["center"] = rig._position_in_rig(b)
			sections.append(s); names.append(b.name)
		var mesh: ArrayTetraMesh4D = _Builder.build(sections, rig.profile_rings, rig.profile_sides,
			rig.taper_ends, false, rig.align_to_spine, rig.smoothing)
		if mesh == null: continue
		var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
		var pos: PackedVector4Array = mesh.get_vertex_positions()
		var centers := PackedVector4Array()
		for s in _Builder.subdivide_long_spans(sections): centers.append(s["center"])
		var folded := 0
		for c in range(cells.size() / 4):
			var a: Vector4 = pos[cells[c*4]]; var b: Vector4 = pos[cells[c*4+1]]
			var cc: Vector4 = pos[cells[c*4+2]]; var d: Vector4 = pos[cells[c*4+3]]
			var mid: Vector4 = (a+b+cc+d) * 0.25
			var outward: Vector4 = mid - _Builder._nearest_on_spine(centers, mid)
			if outward.length() > 0.0001 and Vector4D.perpendicular(b-a, cc-a, d-a).dot(outward) < 0.0:
				folded += 1
		if folded > 0:
			print("   %s: %d of %d folded" % [" -> ".join(names), folded, cells.size() / 4])
