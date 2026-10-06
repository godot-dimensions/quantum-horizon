extends SceneTree

## What the range costs (plan steps 64 and 65), measured windowed with vsync off
## (follow_up/lofting_gotchas.md "Measuring anything"): how long the scene takes to open and its
## shapes to bake, then for the lobby, the target gallery and every stage of every experiment, two
## seconds of frames: the whole frame, the script time, the physics time, the GPU time, what is on
## screen. A stage over 8 ms of frame time is printed as OVER.
##
## "script" and "physics" are Performance's monitors, which hold the worst step of the last second (main.cpp
## process_max), not this frame's: read them as a ceiling. The frame time is measured here, frame by frame.
##
##   range_run.sh windowed perf res://ramon/QuantumRange/scripts/_perf_runner.gd

const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")
const BUDGET_MS := 8.0
const SAMPLE_S := 2.0

var _r: Node
var _d: Node
var _p: CharacterBody4D
var _t0: int = 0
var _rows: Array = []


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 240000:
		print("PERF: gave up after 240 s")
		return true
	return false


func _wait(s: float) -> void:
	await create_timer(s).timeout


## Two seconds of frames under the label `what`.
func _sample(what: String) -> void:
	var vp: RID = root.get_viewport_rid()
	var frames: Array = []
	var scripts: Array = []
	var physics: Array = []
	var gpu: Array = []
	var prims: int = 0
	var last: int = Time.get_ticks_usec()
	var end: int = last + int(SAMPLE_S * 1000000.0)
	while Time.get_ticks_usec() < end:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		scripts.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		prims = maxi(prims, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	frames.pop_front()
	var f: float = _median(frames)
	var row: String = "%-28s frame %5.2f ms (worst %5.2f)  script %5.2f  physics %4.2f  gpu %4.2f  triangles %6d  targets %2d  meshes %3d%s" % [
		what, f, _p95(frames), _median(scripts), _median(physics), _median(gpu), prims,
		int(_d.call("alive_count")), _meshes(_r), "  OVER" if f > BUDGET_MS else ""]
	print("PERF: ", row)
	_rows.append(row)


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: Array = a.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func _p95(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: Array = a.duplicate()
	s.sort()
	return float(s[mini(s.size() - 1, int(s.size() * 0.95))])


func _meshes(n: Node) -> int:
	var c: int = 1 if n is MeshInstance4D else 0
	for k in n.get_children():
		c += _meshes(k)
	return c


func _tetrahedra(n: Node, seen: Dictionary) -> int:
	var c: int = 0
	if n is MeshInstance4D:
		var m: Mesh4D = (n as MeshInstance4D).mesh
		if m is TetraMesh4D and not seen.has(m):
			seen[m] = true
			c += (m as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	for k in n.get_children():
		c += _tetrahedra(k, seen)
	return c


func _run() -> void:
	var t: int = Time.get_ticks_usec()
	_r = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_r)
	current_scene = _r
	await process_frame
	print("PERF: opened in %.0f ms (shapes baked so far %.0f ms)" % [(Time.get_ticks_usec() - t) / 1000.0, Shapes.build_ms])
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_d = _r.get("director")
	_d.set("keep_bests", false)
	_p = _r.get("player")
	(_r.get("sfx") as Node).set("muted", true)
	_p.call("place", Vector4(0, 0.05, 1.5, 0), 0.0)
	await _wait(1.0)
	_p.call("aim_at", Vector4(0, 1.6, -12.0, 0))
	await _sample("lobby")
	var b0: float = Shapes.build_ms
	_d.call("toggle_gallery")
	await _wait(1.0)
	print("PERF: gallery baked %.0f ms more (all shapes %.0f ms)" % [Shapes.build_ms - b0, Shapes.build_ms])
	await _sample("gallery")
	print("PERF: gallery tetrahedra %d (each shared mesh once)" % _tetrahedra(_r, {}))
	_d.call("toggle_gallery")
	var names: Array = ["locate", "charge", "reveal", "incoming", "skeet"]
	for i in 5:
		var e: RefCounted = (_d.get("experiments") as Array)[i]
		for k in (e.get("stages") as Array).size():
			_d.call("start", i)
			if k > 0:
				_d.call("_begin_stage", k)
			var waited: float = 0.0
			while String(_d.get("state")) != "stage" and waited < 6.0:
				await process_frame
				waited += 1.0 / 60.0
			if i == 4:
				e.call("action")
				e.call("action")
			await _wait(0.8)
			await _sample("%d %s %s" % [i + 1, names[i], "ABCD"[k]])
	print("PERF: all shapes baked %.0f ms" % Shapes.build_ms)
	print("PERF: done")
	quit()
