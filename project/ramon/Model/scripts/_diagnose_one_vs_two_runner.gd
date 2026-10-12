extends SceneTree
## Same tetrahedra, drawn as ONE mesh or as TWO. Everything else in the scene is hidden,
## so the only thing left in the frame is the body (and, in the working scene, the neck).
var _root: Node
var _f := 0
var _last := 0
var _ms := 0.0
var _n := 0
var _nm := ""
func _hide_all(n: Node, v: bool) -> void:
	if n is MeshInstance4D: (n as MeshInstance4D).visible = v
	for c in n.get_children(): _hide_all(c, v)
func _initialize() -> void:
	_nm = "rigged_creature_merged" if OS.get_cmdline_user_args().has("merged") else "rigged_creature_ramon"
	_root = load("res://ramon/Model/%s.tscn" % _nm).instantiate()
	root.add_child(_root); current_scene = _root
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
func _process(_d) -> bool:
	_f += 1
	if _f == 30:
		_hide_all(_root, false)
		var cells := 0
		var shown: Array = []
		for path in ["Chicken/Body", "Chicken/NeckHead"]:
			var n := _root.get_node_or_null(path) as MeshInstance4D
			if n == null: continue
			n.visible = true
			shown.append(path)
			cells += (n.mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
		print("%s: showing %s = %d tets in %d mesh(es)" % [_nm, str(shown), cells, shown.size()])
		_last = Time.get_ticks_usec()
		return false
	if _f < 30: return false
	var now := Time.get_ticks_usec()
	_ms += (now - _last) / 1000.0
	_last = now
	_n += 1
	if _n < 400: return false
	print("%s: %.2f ms/frame" % [_nm, _ms / _n])
	return true
