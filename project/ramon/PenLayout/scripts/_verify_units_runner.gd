extends SceneTree

## Pen layout, Phase A (6 Oct 2026): what a scene IS, written down so two versions can be compared.
## The scene is instantiated but not run (no _ready, nothing moves). For every saved node:
##   - its identity: its path, with the units' roots taken out (so a node keeps its identity when it
##     moves into a unit)
##   - its place in the world: position and basis, composed down from the root
##   - where each of its node links points (every NodePath property, the scripts' defaults
##     included), by the target's identity
## Compare the old pen's dump with the new one's (tools/compare_units.py).
##
##   CreationLab/scripts/lab_run.sh headless pl_units res://ramon/PenLayout/scripts/_verify_units_runner.gd <scene> <tag>

const OUT := "res://smoke_test_output/pen_layout/units/"
## The units' roots (the Lookout's site keeps its own name and place, so it is not one of them).
const UNIT_ROOTS := ["TrymCabin", "KeeperPost", "Range", "ProfessorPost", "RockPileSpot", "Cave"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://ramon/chickenpen/playable_world.tscn"
	var tag: String = args[1] if args.size() > 1 else "now"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var root: Node = (load(scene_path) as PackedScene).instantiate()
	var lines: PackedStringArray = PackedStringArray()
	var n_nodes: int = 0
	var n_links: int = 0
	var stack: Array = [[root, Vector4.ZERO, Projection.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var gp: Vector4 = item[1]
		var gb: Projection = item[2]
		if node is Node4D:
			var n4 := node as Node4D
			gp = gp + gb * n4.position
			gb = gb * n4.basis
		var ident: String = _ident(root, node)
		if ident != "<unit root>":
			n_nodes += 1
			lines.append("N\t%s\t%s\t%s" % [ident, _v(gp), _b(gb)])
			for prop in node.get_property_list():
				var nm: String = String(prop["name"])
				var t: int = int(prop["type"])
				var v: Variant = node.get(nm)
				if t == TYPE_NODE_PATH:
					lines.append("L\t%s\t%s\t%s" % [ident, nm, _target(root, node, v)])
					n_links += 1
				elif t == TYPE_ARRAY and v is Array and String(prop.get("hint_string", "")).contains("NodePath"):
					var k: int = 0
					for e in v:
						lines.append("L\t%s\t%s[%d]\t%s" % [ident, nm, k, _target(root, node, e)])
						k += 1
						n_links += 1
		for c in node.get_children():
			if c.owner != null or c == root:
				stack.append([c, gp, gb])
	lines.sort()
	var f := FileAccess.open(OUT + tag + ".txt", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("UNITS DUMP %s: %d nodes, %d links -> %s%s.txt" % [tag, n_nodes, n_links, OUT, tag])
	root.free()
	quit(0)


func _ident(root: Node, node: Node) -> String:
	var p: String = String(root.get_path_to(node))
	if p == ".":
		return "."
	var parts: PackedStringArray = p.split("/")
	if parts.size() == 2 and parts[0] == "World" and parts[1] in UNIT_ROOTS:
		return "<unit root>"
	if parts.size() > 2 and parts[0] == "World" and parts[1] in UNIT_ROOTS:
		parts.remove_at(1)
	return "/".join(parts)


func _target(root: Node, holder: Node, v: Variant) -> String:
	if v == null:
		return "<null>"
	var np: NodePath = v
	if np.is_empty():
		return "<unset>"
	var t: Node = holder.get_node_or_null(np)
	if t == null:
		return "<missing: %s>" % String(np)
	return _ident(root, t) + ((":" + String(np.get_concatenated_subnames())) if np.get_subname_count() > 0 else "")


func _v(p: Vector4) -> String:
	return "%.4f,%.4f,%.4f,%.4f" % [p.x, p.y, p.z, p.w]


func _b(b: Projection) -> String:
	return "%s|%s|%s|%s" % [_v(b.x), _v(b.y), _v(b.z), _v(b.w)]
