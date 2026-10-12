extends SceneTree
## The horse skins now but does not move. Did the binding find anything?
var _root: Node
var _f := 0
var _walker: Node
var _rig: MeshInstance4D
func _initialize() -> void:
	_root = load("res://ramon/Model/animation_test.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f > 40:
		if _f % 40 == 0:
			var live := _rig.mesh as ArrayTetraMesh4D
			var lo := 1e9
			for v in live.get_vertex_positions(): lo = minf(lo, v.y)
			var leg0: Dictionary = (_walker.get("_legs") as Array)[0]
			print("frame %3d: gait phase %.3f, foot goal y %.3f, lowest vertex %.4f, halted %s" % [
				_f, float(_walker.get("_gait").phase_progress), (leg0.get("foot_goal", Vector4.ZERO) as Vector4).y,
				lo, str(_walker.get("halted"))])
		if _f > 260: return true
		return false
	if _f < 40: return false
	var walker: Node = null
	var stack: Array = [_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get_script() != null and n.name.findn("walk") >= 0: walker = n
		for c in n.get_children(): stack.append(c)
	if walker == null:
		print("no walker"); return true
	var legs: Array = walker.get("_legs")
	print("legs collected: %d" % legs.size())
	for leg in legs:
		var hip: Vector4 = leg["hip_world"]
		var foot: Vector4 = leg.get("rest_foot", Vector4.ZERO)
		print("  hip y %.3f -> foot y %.3f, drop %.3f, influence %.3f" % [
			hip.y, foot.y, hip.y - foot.y, (hip.y - foot.y) * float(walker.get("leg_influence_ratio"))])
	print("mesh vertices: %d, bound: %d" % [
		(walker.get("_rest_verts") as PackedVector4Array).size(),
		(walker.get("_skin_index") as PackedInt32Array).size()])
	_walker = walker
	_rig = walker.get("_rig") as MeshInstance4D
	return false
