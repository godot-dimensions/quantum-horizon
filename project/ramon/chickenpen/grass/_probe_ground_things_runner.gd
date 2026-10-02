extends SceneTree

## Lists every mesh standing on the pen's ground (bottom below 0.3 m, top above it), with its
## footprint in x, z and its reach in W, so the grass mask can be checked against what is
## really there. Headless: geometry only.
##
##   godot... --headless --path project --script res://ramon/chickenpen/grass/_probe_ground_things_runner.gd

var _room: Node
var _t: float = 0.0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_probe_test.cfg")
	root.add_child(_room)


func _process(d: float) -> bool:
	_t += d
	if _t < 2.0:
		return false
	var rows: Array = []
	for m in _room.find_children("*", "MeshInstance4D", true, false):
		var mi := m as MeshInstance4D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var rb: PackedVector4Array = mi.mesh.call("get_rect_bounds")
		var lo := Vector4(INF, INF, INF, INF)
		var hi := -lo
		for c in 16:
			var corner := Vector4(rb[1].x if c & 1 else 0.0, rb[1].y if c & 2 else 0.0, rb[1].z if c & 4 else 0.0, rb[1].w if c & 8 else 0.0) + rb[0]
			var p: Vector4 = mi.global_basis * corner + mi.global_position
			lo = lo.min(p)
			hi = hi.max(p)
		if lo.y > 0.3 or hi.y < 0.02:
			continue
		var path: String = String(_room.get_path_to(mi))
		rows.append([(hi.x - lo.x) * (hi.z - lo.z), "%7.1f m2  x %6.1f..%6.1f  z %6.1f..%6.1f  w %6.1f..%6.1f  y %5.2f..%5.2f  %s" % [
			(hi.x - lo.x) * (hi.z - lo.z), lo.x, hi.x, lo.z, hi.z, lo.w, hi.w, lo.y, hi.y, path]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 70):
		print(r[1])
	print("PROBE: %d meshes on the ground" % rows.size())
	return true
