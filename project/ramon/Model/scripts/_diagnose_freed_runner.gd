extends SceneTree
## Something frees the brachiosaurus at runtime. When, and what survives?
var _root: Node
var _f := 0
var _brachio: Node
var _walker: Node
var _spine: Node
var _reported := false
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 5:
		_brachio = _root.get_node_or_null("Brachio")
		_walker = _root.get_node_or_null("Brachio/Walker")
		_spine = _root.get_node_or_null("Brachio/Spine")
		print("frame 5: brachio=%s walker=%s spine=%s" % [_brachio != null, _walker != null, _spine != null])
		return false
	if _f < 5: return false
	if not _reported:
		var b := is_instance_valid(_brachio)
		var w := is_instance_valid(_walker)
		var s := is_instance_valid(_spine)
		var r := is_instance_valid(_root)
		if not (b and w and s and r):
			print("frame %d: root=%s brachio=%s walker=%s spine=%s" % [_f, r, b, w, s])
			_reported = true
			return true
	if _f < 400: return false
	print("all still alive at frame %d" % _f)
	return true
