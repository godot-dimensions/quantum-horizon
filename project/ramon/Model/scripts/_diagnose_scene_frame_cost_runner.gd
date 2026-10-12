extends SceneTree
## Frame cost of a whole scene, and how many tetrahedra the chicken is made of.
## Pass -- merged to load the merged scene instead of the working one.
var _root: Node
var _f := 0
var _last := 0
var _ms := 0.0
var _n := 0
var _name := ""
func _initialize() -> void:
	_name = "rigged_creature_merged" if OS.get_cmdline_user_args().has("merged") else "rigged_creature_ramon"
	_root = load("res://ramon/Model/%s.tscn" % _name).instantiate()
	root.add_child(_root); current_scene = _root
	# Vsync quantises the frame to 60 Hz and hides or exaggerates every cost here.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
func _process(_d) -> bool:
	_f += 1
	if _f == 30:
		var cells := 0
		for c in _root.get_node("Chicken").get_children():
			if c is MeshInstance4D and c.mesh is TetraMesh4D:
				cells += (c.mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
		print("%s: chicken is %d tetrahedra across %d rigs" % [_name, cells,
			_root.get_node("Chicken").get_children().size()])
		_last = Time.get_ticks_usec()
		return false
	if _f < 30: return false
	var now := Time.get_ticks_usec()
	_ms += (now - _last) / 1000.0
	_last = now
	_n += 1
	if _n < 400: return false
	print("%s: %.2f ms/frame average over %d frames" % [_name, _ms / _n, _n])
	return true
