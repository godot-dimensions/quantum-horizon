extends SceneTree
## What changes in a re-lofting bone? The rig rebuilds when its section signature moves,
## and that signature is built from each ball's position, radius, scales and basis - so
## comparing those two snapshots names the culprit exactly.
var _root: Node
var _f := 0
var _snap := {}
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 40:
		for r in _rigs(_root): _snap[r.get_path()] = _describe(r)
		return false
	if _f < 160: return false
	var reported := 0
	for r in _rigs(_root):
		var before: Array = _snap.get(r.get_path(), [])
		var after: Array = _describe(r)
		if before == after or reported >= 2: continue
		reported += 1
		print("--- %s ---" % str(r.get_path()).replace("/root/RiggedCreatureRamon/Creature/", ""))
		for i in range(mini(before.size(), after.size())):
			if before[i] != after[i]:
				print("   %s" % before[i])
				print("   %s" % after[i])
		# Is live_rebuild even on?
		print("   live_rebuild = %s" % r.live_rebuild)
	return true
func _describe(r) -> Array:
	var out: Array = []
	for b in r.get_children():
		if not b.has_method("get_loft_section"): continue
		out.append("%-3s pos=%s r=%.4f v=%.3f w=%.3f basis.x=%s basis.y=%s" % [
			b.name, b.position, b.radius, b.v_scale, b.w_scale, b.basis.x, b.basis.y])
	return out
func _rigs(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is MeshInstance4D and c.get_script() != null and c.has_method("build"): out.append(c)
		out.append_array(_rigs(c))
	return out
