extends SceneTree
## What does it cost to DEFORM a lofted mesh every frame instead of moving it rigidly?
##
## Windowed on purpose: headless uses the dummy renderer, where the proxy mesh the cost
## lives in is never built, so a headless number would be a fiction. And deform/rigid
## are INTERLEAVED frame by frame rather than run as two blocks - run-to-run drift here
## is 1-2 ms, which swamped the signal when the two were timed as separate phases and
## once produced a negative cost.
##
## The frame time read at the top of _process covers the PREVIOUS frame's draw, which is
## where the proxy rebuild happens, so each sample is attributed to the frame before it.
var _root: Node
var _f := 0
var _targets: Array = []
var _last := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
	# Vsync quantises the frame to 60 Hz and hides or exaggerates every cost here.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		for path in ["Chicken/NeckHead", "Chicken/Body", "Chicken/LegL"]:
			var n: MeshInstance4D = _root.get_node(path)
			var m := n.mesh as ArrayTetraMesh4D
			if m == null: continue
			_targets.append({"name": path, "mesh": m, "rest": m.get_vertex_positions(),
				"cells": m.get_simplex_cell_vertex_indices().size() / 4,
				"on": 0.0, "off": 0.0, "n": 0, "loop": 0.0})
		_last = Time.get_ticks_usec()
		return false
	if _f < 20: return false
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	# 400 frames per mesh: even frames deform it, odd frames leave it alone.
	var slot: int = (_f - 20) / 400
	if slot >= _targets.size():
		for t in _targets:
			var on: float = t["on"] / maxf(t["n"], 1)
			var off: float = t["off"] / maxf(t["n"], 1)
			print("%s: %d cells, %d verts -> deform costs %.2f ms/frame (%.2f on vs %.2f off), maths %.3f ms" % [
				t["name"], t["cells"], t["rest"].size(), on - off, on, off, t["loop"] / maxf(t["n"], 1) / 1000.0])
		return true
	var t: Dictionary = _targets[slot]
	var prev_deformed: bool = ((_f - 1) % 2) == 0
	if _f - 20 > slot * 400 + 20:
		if prev_deformed: t["on"] += dt
		else: t["off"] += dt; t["n"] += 1
	if _f % 2 == 0:
		var t0 := Time.get_ticks_usec()
		var rest: PackedVector4Array = t["rest"]
		var out := PackedVector4Array(); out.resize(rest.size())
		var a: float = 0.05 * sin(_f * 0.2)
		for i in rest.size():
			var v: Vector4 = rest[i]
			out[i] = Vector4(v.x, v.y + a * sin(v.z * 4.0), v.z + a, v.w)
		t["loop"] += Time.get_ticks_usec() - t0
		(t["mesh"] as ArrayTetraMesh4D).set_vertex_positions(out)
	return false
