extends SceneTree
## Do the paired legs step together or alternate? Samples each foot's height over a
## stride and reports how far apart each pair's motion is. Identical heights every
## frame means lockstep.
var _scene: String = "res://ramon/Model/rigged_creature.tscn"
var _root: Node
var _f := 0
var _tracks := {}
func _initialize() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_scene = OS.get_cmdline_user_args()[0]
	_root = load(_scene).instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 30: return false
	for n in _feet(_root):
		var tag: String = n.name
		if not _tracks.has(tag): _tracks[tag] = []
		_tracks[tag].append(n.global_position.y)
	if _f < 150: return false
	print("scene: %s" % _scene.get_file())
	var pairs := {}
	for tag in _tracks:
		var base: String = tag.substr(0, 5)   # "ForeL" / "HindR"
		if not pairs.has(base): pairs[base] = []
		pairs[base].append(tag)
	for base in pairs:
		var t: Array = pairs[base]
		if t.size() != 2: continue
		var a: Array = _tracks[t[0]]
		var b: Array = _tracks[t[1]]
		var diff := 0.0
		for i in range(min(a.size(), b.size())):
			diff = maxf(diff, absf(a[i] - b[i]))
		print("   %-6s %s vs %s : biggest height difference %.4f  %s" % [
			base, t[0], t[1], diff,
			"LOCKSTEP - they move as one" if diff < 0.01 else "alternating"])
	return true
func _feet(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Node4D and str(c.name).ends_with("FootTarget"): out.append(c)
		out.append_array(_feet(c))
	return out
