extends SceneTree
## Does the bird actually travel, on a circle, at the speed its legs imply?
var _root: Node
var _f := 0
var _pts: Array[Vector4] = []
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 20: return false
	var c: Node4D = _root.get_node_or_null("Chicken")
	if c: _pts.append(c.position)
	if _f < 950: return false
	var travelled := 0.0
	for i in range(1, _pts.size()): travelled += _pts[i].distance_to(_pts[i-1])
	# Centre of the traced arc, and how constant the radius is.
	var cx := 0.0; var cz := 0.0
	for p in _pts: cx += p.x; cz += p.z
	cx /= _pts.size(); cz /= _pts.size()
	var rlo := 1e9; var rhi := -1e9
	for p in _pts:
		var r := sqrt((p.x-cx)*(p.x-cx) + (p.z-cz)*(p.z-cz))
		rlo = minf(rlo, r); rhi = maxf(rhi, r)
	print("samples %d, distance travelled %.2f units over %.1f s" % [
		_pts.size(), travelled, _pts.size() / 60.0])
	print("radius from traced centre: %.2f .. %.2f  -> %s" % [rlo, rhi,
		"circular" if rhi - rlo < 0.35 else "not a circle"])
	return true
