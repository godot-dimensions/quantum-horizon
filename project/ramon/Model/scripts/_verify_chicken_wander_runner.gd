extends SceneTree
## Is the wander genuinely unpredictable, still a walk, and still on the platform?
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
	var cx := 0.0; var cz := 0.0
	for p in _pts: cx += p.x; cz += p.z
	cx /= _pts.size(); cz /= _pts.size()
	var rlo := 1e9; var rhi := -1e9
	var stray := 0.0
	for p in _pts:
		var r := sqrt((p.x-cx)*(p.x-cx) + (p.z-cz)*(p.z-cz))
		rlo = minf(rlo, r); rhi = maxf(rhi, r)
		stray = maxf(stray, sqrt((p.x-_pts[0].x)*(p.x-_pts[0].x) + (p.z-_pts[0].z)*(p.z-_pts[0].z)))
	# Heading changes: a circle turns at a constant rate, a wander does not.
	var turns: Array[float] = []
	for i in range(2, _pts.size()):
		var a := atan2(_pts[i].x-_pts[i-1].x, _pts[i].z-_pts[i-1].z)
		var b := atan2(_pts[i-1].x-_pts[i-2].x, _pts[i-1].z-_pts[i-2].z)
		turns.append(wrapf(a-b, -PI, PI))
	var tmin := 1e9; var tmax := -1e9; var tsum := 0.0
	for t in turns: tmin = minf(tmin, t); tmax = maxf(tmax, t); tsum += t
	var mean := tsum / turns.size()
	var varsum := 0.0
	for t in turns: varsum += (t-mean)*(t-mean)
	print("travelled %.2f units in %.1f s -> %.2f units/s" % [travelled, _pts.size()/60.0, travelled/(_pts.size()/60.0)])
	print("radius from path centroid: %.2f .. %.2f (a circle would be near-constant)" % [rlo, rhi])
	print("turn rate: mean %.4f rad/frame, spread %.4f  -> %s" % [mean, sqrt(varsum/turns.size()),
		"varying, not a fixed arc" if sqrt(varsum/turns.size()) > absf(mean) * 0.5 else "constant arc"])
	print("furthest from start: %.2f units (roam limit 5.0)" % stray)
	return true
