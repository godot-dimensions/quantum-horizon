extends SceneTree
## Is the chicken actually stepping, and do its two legs alternate?
var _root: Node
var _f := 0
var _track := {"LegL": [], "LegR": []}
var _body: Array = []
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 30: return false
	for side in ["LegL", "LegR"]:
		var rig: Node = _root.get_node_or_null("Chicken/%s" % side)
		if rig == null: continue
		var lowest: Node = null
		for c in rig.get_children():
			if c.has_method("get_loft_section") and (lowest == null or c.position.y < lowest.position.y):
				lowest = c
		if lowest: _track[side].append(lowest.position.y)
	var b: Node = _root.get_node_or_null("Chicken/Body")
	if b: _body.append(b.position.y)
	if _f < 190: return false
	for side in _track:
		var a: Array = _track[side]
		if a.is_empty(): print("%s: no samples" % side); continue
		var lo: float = a[0]; var hi: float = a[0]
		for v in a: lo = minf(lo, v); hi = maxf(hi, v)
		print("%s foot height: %.4f .. %.4f  (lift %.4f)  %s" % [side, lo, hi, hi - lo,
			"STEPPING" if hi - lo > 0.005 else "static"])
	var l: Array = _track["LegL"]; var r: Array = _track["LegR"]
	var diff := 0.0
	for i in range(mini(l.size(), r.size())): diff = maxf(diff, absf(l[i] - r[i]))
	print("biggest left/right difference: %.4f  %s" % [diff,
		"alternating" if diff > 0.005 else "LOCKSTEP"])
	var blo: float = _body[0]; var bhi: float = _body[0]
	for v in _body: blo = minf(blo, v); bhi = maxf(bhi, v)
	print("body rock: %.4f" % (bhi - blo))
	return true
