extends SceneTree
## Is the walking creature re-lofting per frame, or moving rigid pieces?
##
## Decisive either way: a re-loft changes a rig's LOCAL vertex data, while a rigid
## transform leaves the vertices untouched and changes only the node's transform. So
## sample both, early and late, and see which one moved.
var _root: Node
var _f := 0
var _first_verts := {}
var _first_xform := {}
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 40:
		for r in _rigs(_root):
			_first_verts[r.name] = _hash(r)
			_first_xform[r.name] = r.global_position
		return false
	if _f < 160: return false
	var verts_changed := 0
	var xform_moved := 0
	var total := 0
	for r in _rigs(_root):
		if not _first_verts.has(r.name): continue
		total += 1
		if _hash(r) != _first_verts[r.name]:
			verts_changed += 1
			var cells: int = r.mesh.get_simplex_cell_vertex_indices().size() / 4 if r.mesh else 0
			print("   re-lofts: %-14s (%d cells)" % [r.name, cells])
		if r.global_position.distance_to(_first_xform[r.name]) > 0.001: xform_moved += 1
	print("across 120 frames, of %d rigs:" % total)
	print("   rigs whose LOCAL vertex data changed (a re-loft): %d" % verts_changed)
	print("   rigs whose TRANSFORM moved (a rigid placement):   %d" % xform_moved)
	print("   -> %s" % ("RIGID: geometry frozen, nodes moved" if verts_changed == 0 and xform_moved > 0
		else "re-meshing every frame" if verts_changed > 0 else "nothing moved at all"))
	return true
func _hash(r) -> int:
	var m = r.mesh
	if m == null: return 0
	var h := 0
	for p in m.get_vertex_positions():
		h = hash([h, snappedf(p.x, 1e-6), snappedf(p.y, 1e-6), snappedf(p.z, 1e-6), snappedf(p.w, 1e-6)])
	return h
func _rigs(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is MeshInstance4D and c.get_script() != null and c.has_method("build"): out.append(c)
		out.append_array(_rigs(c))
	return out
