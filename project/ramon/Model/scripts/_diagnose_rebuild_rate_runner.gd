extends SceneTree
## How OFTEN does a bone's geometry change? "Differs between two samples" cannot tell a
## rebuild every frame from a single settle early on - so count transitions instead.
var _root: Node
var _f := 0
var _last := {}
var _changes := {}
var _samples := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 20: return false
	_samples += 1
	for r in _rigs(_root):
		var key: String = str(r.get_path())
		var h: int = _hash(r)
		if _last.has(key) and _last[key] != h:
			_changes[key] = int(_changes.get(key, 0)) + 1
		_last[key] = h
	if _samples < 200: return false
	var per_frame := 0
	var once := 0
	var never := 0
	for key in _last:
		var c: int = int(_changes.get(key, 0))
		if c == 0: never += 1
		elif c <= 3: once += 1
		else: per_frame += 1
	print("over %d sampled frames, of %d rigs:" % [_samples, _last.size()])
	print("   geometry never changed:            %d" % never)
	print("   changed 1-3 times (a settle):      %d" % once)
	print("   changed on most frames (a re-loft):%d" % per_frame)
	for key in _changes:
		if int(_changes[key]) > 3:
			print("      %s: %d changes" % [key.get_file(), _changes[key]])
	return true
func _hash(r) -> int:
	var m = r.mesh
	if m == null: return 0
	var h := 0
	for p in m.get_vertex_positions():
		h = hash([h, snappedf(p.x, 1e-6), snappedf(p.y, 1e-6), snappedf(p.z, 1e-6), snappedf(p.w, 1e-6)])
	return h
func _rigs(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is MeshInstance4D and c.get_script() != null and c.has_method("build"): out.append(c)
		out.append_array(_rigs(c))
	return out
