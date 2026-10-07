extends SceneTree

## THE STRAY BOXES (Ramon, 7 Oct, two screenshots with the slice turned: "weird boxes are scattered here and
## there", "clearly not trunks, but boxes"): a tall plain box standing alone in the grass, one by the camp and
## one in front of the town wall's gate. This lists every visible mesh in the pen that is box-shaped, upright
## and narrow (a few metres tall, about a metre across), with where it stands in W, so the stray ones can be
## named. Shapes off the farm's W show only when the slice is turned, as in both screenshots.
##
##   lab_run.sh windowed wt_boxes res://ramon/WTools/tests/_probe_stray_boxes_runner.gd

const PEN := "res://ramon/chickenpen/playable_world.tscn"


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _albedo(mi: MeshInstance4D) -> Color:
	var m: Material4D = mi.material_override as Material4D
	if m == null and mi.mesh != null:
		m = mi.mesh.get("material") as Material4D
	return m.albedo_color if m != null and "albedo_color" in m else Color(0, 0, 0, 0)


func _run() -> void:
	var pen: Node = (load(PEN) as PackedScene).instantiate()
	root.add_child(pen)
	current_scene = pen
	await _frames(240)
	var player := pen.get_node("Player") as Node4D
	player.set("input_enabled", false)
	var found: Array = []
	for n in pen.find_children("*", "MeshInstance4D", true, false):
		var mi := n as MeshInstance4D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var r: PackedVector4Array = mi.get_rect_bounds_local()
		var lo := Vector4(INF, INF, INF, INF)
		var hi := -lo
		for i in 16:
			var c: Vector4 = r[0] + Vector4(r[1].x * (i & 1), r[1].y * ((i >> 1) & 1), r[1].z * ((i >> 2) & 1), r[1].w * ((i >> 3) & 1))
			var p: Vector4 = mi.global_position + mi.global_basis * c
			lo = lo.min(p)
			hi = hi.max(p)
		var size: Vector4 = hi - lo
		var tall: bool = size.y > 1.2 and size.y < 6.0 and size.x < 2.0 and size.z < 2.0
		if not tall:
			continue
		var cells: int = int(mi.mesh.call("get_cell_count")) if mi.mesh.has_method("get_cell_count") else -1
		found.append([str(pen.get_path_to(mi)), mi.mesh.get_class(), cells, lo, hi, _albedo(mi)])
	found.sort_custom(func(a: Array, b: Array) -> bool: return (a[3] as Vector4).w < (b[3] as Vector4).w)
	print("STRAY BOXES: %d tall narrow meshes" % found.size())
	for f in found:
		var lo: Vector4 = f[3]
		var hi: Vector4 = f[4]
		var c: Color = f[5]
		var mid := (lo + hi) * 0.5
		print("  %-70s %-22s cells %4d  at x %6.1f z %6.1f  w %6.2f..%6.2f  size %.1f x %.1f x %.1f  albedo %s" % [
			String(f[0]).right(70), String(f[1]), int(f[2]), mid.x, mid.z, lo.w, hi.w, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z,
			c.to_html(false)])
	quit(0)
