extends SceneTree
## Voxel Lab, plan steps 2 to 5 and 7: one hero specimen in the engine's own voxel world, then what a
## cut costs, the engine's way (the frame after pays for everything) against the swap (the chunks
## meshed hidden, their draw buffers built on a worker thread, shown all at once).
##
##   -- voxel=0.1        the voxel size, metres (the specimen is 2.4 x 1.8 x 1.6 x 1.8 m)
##   -- stress=60        cuts in a row at the end, in swap mode, every few frames (stability)
##
## Frames to smoke_test_output/voxel_lab/probe_cut/. Run windowed: costs need the real renderer.
##   VoxelLab/run.sh windowed probe_cut res://ramon/VoxelLab/probes/_probe_cut_runner.gd voxel=0.1

const Specimen := preload("res://ramon/VoxelLab/specimen/vl_specimen_4d.gd")
const Recipe := preload("res://ramon/VoxelLab/specimen/vl_recipe.gd")
const Cut := preload("res://ramon/VoxelLab/specimen/vl_cut.gd")

const OUT := "res://smoke_test_output/voxel_lab/probe_cut/"
const SIZE := Vector4(2.4, 1.8, 1.6, 1.8)

var voxel: float = 0.1
var stress: int = 60
var _stage: Node4D
var _cam: Camera4D
var _spec: Node4D
var _total: float = 0.0
var _t: float = 0.0
var _step: String = "build"
var _plan: Array = []
var _i: int = 0
var _results: Array = []
var _waiting: bool = false
var _base: Array = []
var _last_us: int = 0
var _tag: String = ""
var _stress_left: int = 0
var _stress_frames: Array = []


func _initialize() -> void:
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2 and kv[0] == "voxel":
			voxel = float(kv[1])
		if kv.size() == 2 and kv[0] == "stress":
			stress = int(kv[1])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage = Node4D.new()
	var env := WorldEnvironment4D.new()
	var sky := GradientSkyMaterial4D.new()
	sky.top_color = Color(0.06, 0.08, 0.13)
	sky.horizon_color = Color(0.12, 0.15, 0.22)
	sky.bottom_color = Color(0.05, 0.06, 0.08)
	env.sky_material = sky
	env.ambient_light_color = Color(0.30, 0.34, 0.42)
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = 2
	_stage.add_child(env)
	var sun := DirectionalLight4D.new()
	sun.basis = Basis4D.from_zx(deg_to_rad(25.0)) * Basis4D.from_yz(deg_to_rad(-55.0))
	sun.light_energy = 1.1
	_stage.add_child(sun)
	var floor_mesh := MeshInstance4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = Vector4(12, 0.2, 12, 6)
	floor_mesh.mesh = box
	floor_mesh.position = Vector4(0, -0.1, 0, 0)
	_stage.add_child(floor_mesh)
	_spec = Node4D.new()
	_spec.name = "Specimen"
	_spec.set_script(Specimen)
	_spec.position = Vector4(0, SIZE.y * 0.5 + 0.3, 0, 0)
	_stage.add_child(_spec)
	_cam = Camera4D.new()
	_cam.rendering_engine_name = "Cross-section"
	_cam.position = Vector4(1.6, 2.2, 4.6, 0)
	_cam.basis = Basis4D.from_zx(deg_to_rad(19.0)) * Basis4D.from_yz(deg_to_rad(-13.0))
	_stage.add_child(_cam)
	root.add_child.call_deferred(_stage)


## The cuts, in the specimen's voxel coordinates: the front face's middle, and a chunk's corner.
func _cuts(r: Dictionary) -> Array:
	var c: Vector4 = r["center"]
	var h: Vector4 = r["half"]
	var front: Vector4 = c + Vector4(0, 0, h.z, 0)
	var v: float = voxel
	# Chunk boundaries sit at multiples of 8; the middle is at 4 (+ jitter): the nearest corner on the
	# front face is (8, 8, -, 8).
	var corner := Vector4(8.0, 8.0, front.z, 8.0)
	var down := Vector4(0, 0, -1, 0)
	return [
		["ball S middle", Cut.ball(front + Vector4(-0.3, 0.1, 0, 0) / v, 0.10 / v)],
		["ball M middle", Cut.ball(front + Vector4(0.0, 0.0, 0, 0) / v, 0.20 / v)],
		["ball L middle", Cut.ball(front + Vector4(0.45, -0.2, 0, 0) / v, 0.35 / v)],
		["ball M corner", Cut.ball(corner, 0.20 / v)],
		["block M", Cut.block(front + Vector4(-0.7, 0.35, 0, 0) / v, Vector4.ONE * 0.2 / v)],
		["drill M", Cut.drill(front + Vector4(0.7, 0.45, 0.05, 0) / v, down, 0.12 / v, 0.9 / v)],
		["saw M", Cut.saw(front + Vector4(-0.9, -0.5, 0, 0) / v, front + Vector4(0.2, -0.55, 0, 0) / v, Vector4(0, 1, 0, 0), 0.13 / v,
			down, 0.4 / v, Vector4(0, 0, 0, 1), SIZE.w / v)],
	]


func _process(delta: float) -> bool:
	_total += delta
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if _total > 240.0:
		print("PROBE_CUT FAIL: timed out in step %s (%d/%d)" % [_step, _i, _plan.size()])
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _stage.is_inside_tree():
		return false
	_t += delta
	match _step:
		"build":
			if _spec.get("phase") == "idle":
				_spec.call("build", Recipe.block(SIZE, voxel))
				_spec.connect("cut_done", _on_cut)
			elif bool(_spec.call("is_ready")):
				var st: Dictionary = _spec.get("stats")
				print("PROBE_CUT built voxel %.2f m: load %.0f ms, recipe edits %.1f ms, meshed %.0f ms, %d chunk meshes, %d tetrahedra (~%.0f MB), %d solid voxels" % [
					voxel, float(st.get("load_ms", 0)), float(st.get("recipe_edit_ms", 0)), float(st.get("mesh_ms", 0)), int(st["chunks"]), int(st["tets"]),
					float(st["mb"]), Recipe.voxel_count(_spec.get("recipe"))])
				_step = "settle"
				_t = 0.0
		"settle":
			if _t > 1.0:
				_save("01_built_%s" % _vtag())
				_step = "base"
				_t = 0.0
				_base = []
		"base":
			_base.append(frame_ms)
			if _base.size() >= 60:
				_base.sort()
				print("PROBE_CUT baseline frame: median %.2f ms, worst %.2f ms" % [_base[_base.size() / 2], _base[-1]])
				_plan = _cuts(_spec.get("recipe"))
				_i = 0
				_tag = "sync"
				_spec.set("swap", false)
				_step = "cut"
				_t = 0.0
		"cut":
			if _waiting:
				return false
			if _i >= _plan.size():
				_save("02_after_%s_%s" % [_tag, _vtag()])
				if _tag == "sync":
					# Whole again, then the same cuts with the swap.
					_spec.call("build", Recipe.block(SIZE, voxel))
					_step = "rebuild"
				else:
					_step = "stress"
					_stress_left = stress
					_stress_frames = []
				_t = 0.0
				return false
			if _t < 0.4:
				return false
			var it: Array = _plan[_i]
			_waiting = true
			var rec: Dictionary = _spec.call("apply_cut", it[1])
			rec["name"] = "%s %s" % [_tag, it[0]]
		"rebuild":
			if bool(_spec.call("is_ready")) and _t > 0.5:
				_i = 0
				_tag = "swap"
				_spec.set("swap", true)
				_spec.set("flash_on", true)
				_step = "cut"
				_t = 0.0
		"stress":
			_stress_frames.append(frame_ms)
			if frame_ms > 40.0:
				var pend: Dictionary = _spec.get("_pending")
				print("PROBE_CUT spike %.1f ms in stress: cuts left %d, swap busy %s, keys %d, task %d, visible chunks %d of %d" % [frame_ms, _stress_left,
					str(bool(_spec.call("busy"))), (pend.get("keys", {}) as Dictionary).size(), int(pend.get("task", -1)),
					(_spec.call("chunk_nodes") as Array).filter(func(n): return (n as MeshInstance4D).visible).size(), (_spec.call("chunk_nodes") as Array).size()])
			if _stress_left > 0 and int(_total * 60.0) % 4 == 0:
				var r: Dictionary = _spec.get("recipe")
				var c: Vector4 = r["center"]
				var h: Vector4 = r["half"]
				var p := c + Vector4(randf_range(-h.x, h.x) * 0.7, randf_range(-h.y, h.y) * 0.7, h.z, randf_range(-h.w, h.w) * 0.5)
				_spec.call("apply_cut", Cut.ball(p, randf_range(0.08, 0.25) / voxel))
				_stress_left -= 1
			elif _stress_left <= 0 and not bool(_spec.call("busy")) and _t > 1.0:
				_stress_frames.sort()
				print("PROBE_CUT stress: %d cuts, median frame %.2f ms, worst %.2f ms, %d records" % [stress, _stress_frames[_stress_frames.size() / 2], _stress_frames[-1], (_spec.get("records") as Array).size()])
				_save("03_stress_%s" % _vtag())
				_report()
				return true
	return false


func _on_cut(rec: Dictionary) -> void:
	_waiting = false
	_i += 1
	_t = 0.0
	if _step == "stress":
		return
	_results.append(rec)
	print("PROBE_CUT %-22s voxels %5d  touched %2d chunks, remeshed %2d  call %6.2f ms  worst frame %7.2f ms  on screen after %7.1f ms  worker %6.1f ms  count %5.1f ms" % [
		String(rec.get("name", rec["label"])), int(rec["voxels"]), int(rec["chunks_touched"]), int(rec["chunks"]), float(rec["call_ms"]), float(rec["worst_ms"]),
		float(rec["latency_ms"]), float(rec.get("worker_ms", 0.0)), float(rec.get("count_ms", 0.0))])


func _report() -> void:
	var sync_worst: float = 0.0
	var swap_worst: float = 0.0
	for rec in _results:
		if bool(rec["swap"]):
			swap_worst = maxf(swap_worst, float(rec["worst_ms"]))
		else:
			sync_worst = maxf(sync_worst, float(rec["worst_ms"]))
	print("PROBE_CUT summary voxel %.2f: worst frame the engine's way %.1f ms, with the swap %.1f ms" % [voxel, sync_worst, swap_worst])
	print("PROBE_CUT done")


func _vtag() -> String:
	return "%03d" % int(round(voxel * 1000.0))


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("PROBE_CUT saved %s" % name)
