extends SceneTree

## Probe: the pen enclosure's path-builder frame in the dev look (look/pen_look_4d.gd _frame_pen): is it
## there, what symbol, size and place did it get, and the fence's bounds.

func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _run() -> void:
	var room: Node = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(room)
	for k in 30:
		await process_frame
	var look: Node = room.get_node("Systems/Look")
	var net: Node = room.get_node("World/Paths")
	var fence := room.get_node_or_null("Pen/Fence") as MeshInstance4D
	print("FRAME: look applied %s, sym H %d, sym I %d" % [str(look.get("_applied")), int(net.call("sym", "H")), int(net.call("sym", "I"))])
	if fence != null:
		var r: PackedVector4Array = fence.get_rect_bounds_global()
		print("FRAME: fence %s, bounds at %s size %s, mesh %s" % [fence.get_class(), str(r[0]), str(r[1]), str(fence.mesh)])
	var f: Node = look.get_node_or_null("PenFrame")
	if f == null:
		print("FRAME: no PenFrame node")
	else:
		var mi := f as MeshInstance4D
		print("FRAME: PenFrame at %s, visible %s, mesh %s" % [str(mi.global_position), str(mi.is_visible_in_tree()), str(mi.mesh)])
	var Spec := load("res://ramon/CreationLab/PathCreator/path_spec.gd")
	print("FRAME: spec BOX_H_M %s PROUD_M %s UNIT_M %s W_SOFT %s, net p_scale %s _u %s" % [str(Spec.get("BOX_H_M")), str(Spec.get("PROUD_M")),
		str(Spec.get("UNIT_M")), str(Spec.get("W_SOFT")), str(net.get("p_scale")), str(net.call("_u"))])
	var dump := func(mi: MeshInstance4D, label: String) -> void:
		var cs: ShaderMaterial = (mi.material_override as TetraMaterial4D).get_cross_section_material_3d()
		var vals: Array = []
		for k in ["mode", "frame_sym", "frame_grow", "frame_round", "approach", "box_size", "w_half", "walk", "unit_m", "reveal_on", "found", "w_soft", "node_sym", "sym_tex"]:
			vals.append("%s=%s" % [k, str(cs.get_shader_parameter(k)).left(40)])
		print("FRAME %s %s at %s size %s: %s" % [label, mi.name, str(mi.global_position), str((mi.mesh as BoxTetraMesh4D).size if mi.mesh is BoxTetraMesh4D else null), ", ".join(PackedStringArray(vals))])
	if f != null:
		dump.call(f as MeshInstance4D, "ours")
	var shown: int = 0
	for item in net.get_children():
		if item is MeshInstance4D and shown < 3 and int(item.get_meta("mode", -1)) in [1, 3]:
			dump.call(item as MeshInstance4D, "net")
			shown += 1
	quit(0)
