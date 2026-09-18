extends SceneTree
## Where do the limbs actually sit? Measures the built mesh's extent on each axis, and
## the distinct positions limb tips occupy, for both of Trym's creatures.
var _i: Node
var _f := 0
func _initialize() -> void:
	_i = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_i)
func _process(_d) -> bool:
	_f += 1
	if _f < 6: return false
	for path in ["Creature"]:
		var rig: Node = _i.get_node_or_null(path)
		if rig == null or rig.mesh == null:
			print("%s: no mesh" % path); continue
		var lo: Array[float] = [1e9, 1e9, 1e9, 1e9]
		var hi: Array[float] = [-1e9, -1e9, -1e9, -1e9]
		for p in rig.mesh.get_vertex_positions():
			var c: Array[float] = [p.x, p.y, p.z, p.w]
			for i in range(4):
				lo[i] = minf(lo[i], c[i]); hi[i] = maxf(hi[i], c[i])
		print("%s: %d cells" % [path, rig.mesh.get_simplex_cell_vertex_indices().size() / 4])
		for i in range(4):
			print("   %s extent %7.2f .. %7.2f   span %6.2f" % ["XYZW"[i], lo[i], hi[i], hi[i]-lo[i]])
		# What symmetry is actually set on the limb roots?
		for b in _all(rig):
			if b.get("symmetry_type") != null and int(b.symmetry_type) >= 2:
				print("   %s: symmetry_type=%d count=%d mirror_axis(rig)=%d" % [
					b.name, int(b.symmetry_type), int(b.symmetry_count), int(rig.mirror_axis)])
	return true
func _all(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c.has_method("get_loft_section"): out.append(c); out.append_array(_all(c))
	return out
