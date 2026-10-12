extends SceneTree

## How heavy the Dream Shifter is: tetrahedra per part (the 4D renderer slices every tetrahedron every frame, so this is
## the cost that matters), and with "pen" the whole pen's total for scale.
##
##   lab_run.sh headless ds_budget res://ramon/chickenpen/discovery/dream_shifter/_budget_runner.gd [pen]

const Shifter := preload("res://ramon/chickenpen/discovery/dream_shifter/pen_dream_shifter_4d.gd")


func _initialize() -> void:
	_run.call_deferred()


static func _tetras(m: Mesh4D) -> int:
	if m != null and m.has_method("get_simplex_cell_vertex_indices"):
		return (m.call("get_simplex_cell_vertex_indices") as PackedInt32Array).size() / 4
	return 0


func _run() -> void:
	var node := Node4D.new()
	node.set_script(Shifter)
	node.set("orb_height", 1.95)
	root.add_child(node)
	await process_frame
	var total: int = 0
	for mi in node.find_children("*", "MeshInstance4D", true, false):
		var n: int = _tetras((mi as MeshInstance4D).mesh)
		total += n
		print("BUDGET part %-12s %6d tetrahedra" % [mi.name, n])
	print("BUDGET shifter total %d tetrahedra (style %s)" % [total, node.get("style")])
	for path in ["res://models/primitives/platonic/24_cell/24_cell.g4b"]:
		var m: Mesh4D = load(path) as Mesh4D
		var far: float = 0.0
		if m != null and m.has_method("get_vertex_positions"):
			for v in (m.call("get_vertex_positions") as PackedVector4Array):
				far = maxf(far, v.length())
		print("BUDGET model %s class %s radius %.3f" % [path.get_file(), m.get_class() if m != null else "none", far])
	var o := OrthoplexTetraMesh4D.new()
	var far2: float = 0.0
	for v in (o.call("get_vertex_positions") as PackedVector4Array):
		far2 = maxf(far2, v.length())
	print("BUDGET model orthoplex radius %.3f tetrahedra %d" % [far2, _tetras(o)])
	node.queue_free()
	if "pen" in OS.get_cmdline_user_args():
		var pen: Node = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
		root.add_child(pen)
		for i in 30:
			await process_frame
		var all: int = 0
		var count: int = 0
		var biggest: Array = []
		for mi in pen.find_children("*", "MeshInstance4D", true, false):
			var n2: int = _tetras((mi as MeshInstance4D).mesh)
			all += n2
			count += 1
			biggest.append([n2, String(pen.get_path_to(mi))])
		biggest.sort_custom(func(a, b): return a[0] > b[0])
		print("BUDGET pen total %d tetrahedra in %d mesh instances" % [all, count])
		for i in mini(8, biggest.size()):
			print("BUDGET pen big %6d %s" % biggest[i])
	print("BUDGET DONE")
	quit(0)
