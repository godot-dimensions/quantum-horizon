extends SceneTree
## Where does the frame actually go? Hide one creature at a time and watch what changes.
var _root: Node
var _f := 0
var _last := 0
var _ms := [0.0, 0.0, 0.0]
var _n := [0, 0, 0]
var _chick: Node4D
var _trym: Node4D
const _PHASE := 300
func _initialize() -> void:
	var nm := "rigged_creature_merged" if OS.get_cmdline_user_args().has("merged") else "rigged_creature_ramon"
	_root = load("res://ramon/Model/%s.tscn" % nm).instantiate()
	root.add_child(_root); current_scene = _root
	# Vsync quantises the frame to 60 Hz and hides or exaggerates every cost here.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
func _hide(n: Node, v: bool) -> void:
	if n is MeshInstance4D: (n as MeshInstance4D).visible = v
	for c in n.get_children(): _hide(c, v)
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		_chick = _root.get_node("Chicken")
		for c in _root.get_children():
			if c.name != "Chicken" and c is Node4D and c.get_child_count() > 8: _trym = c
		print("other creature found: %s" % (_trym.name if _trym else "none"))
		_last = Time.get_ticks_usec()
		return false
	if _f < 20: return false
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	var slot: int = (_f - 20) / _PHASE
	if slot > 2:
		print("everything visible:   %.2f ms/frame" % (_ms[0] / _n[0]))
		print("chicken hidden:       %.2f ms/frame  -> chicken costs %.2f" % [_ms[1] / _n[1], _ms[0]/_n[0] - _ms[1]/_n[1]])
		print("other creature hidden: %.2f ms/frame -> it costs %.2f" % [_ms[2] / _n[2], _ms[0]/_n[0] - _ms[2]/_n[2]])
		return true
	if (_f - 20) % _PHASE == 0:
		_hide(_chick, slot != 1)
		if _trym: _hide(_trym, slot != 2)
	if (_f - 20) % _PHASE > 30:
		_ms[slot] += dt; _n[slot] += 1
	return false
