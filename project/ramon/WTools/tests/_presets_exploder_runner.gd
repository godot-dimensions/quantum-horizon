extends SceneTree

## THE EXPLODER'S PRESETS IN THE LAB (WTools/PLAN.md steps 51-54): for no copies and each preset in
## exploder/presets, in the exploder lab, the plants within 45 m and in view whose crown the slice cuts near
## its middle (70%), whether their trunk is cut too, and the floating crowns, as the slice turns 0-60 degrees
## in xw and in zw (three headings each); frames at 0, 15, 30, 45 (xw), 30 (zw) and in the volume view; the time to
## make the copies, the cull's time, and the GPU's time flat and turned 30.
##
##   lab_run.sh windowed wt_presets res://ramon/WTools/tests/_presets_exploder_runner.gd [preset names]

const LAB := "res://ramon/WTools/tests/exploder_lab.tscn"
const PRESETS := "res://ramon/WTools/exploder/presets/"
const OUT := "res://smoke_test_output/wtools/presets/"
const TURNS := [0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
const HEADINGS := [-25.0, 0.0, 25.0]
const SHOTS := [0.0, 15.0, 30.0, 45.0]

var _trunks: Dictionary = {}
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 1500000:
		print("PRESETS: gave up")
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var names: Array = ["off"]
	for f in DirAccess.get_files_at(PRESETS):
		if f.ends_with(".tres"):
			names.append(f.get_basename())
	var want: PackedStringArray = OS.get_cmdline_user_args()
	if not want.is_empty():
		names = Array(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for name in names:
		var lab: Node = (load(LAB) as PackedScene).instantiate()
		lab.set("readout", false)
		var trees: Node = lab.get_node("Trees")
		if name == "off":
			trees.set("enabled", false)
			trees.set("trunk_w_slab", 0.0)
		else:
			trees.set("preset", load(PRESETS + name + ".tres"))
		root.add_child(lab)
		current_scene = lab
		await _frames(45)
		var player := lab.get("player") as CharacterBody4D
		player.set("input_enabled", false)
		var rig := lab.get("rig") as Node4D
		var cam := player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
		print("PRESET %s: %d placed, %d copies, %d refused, made in %d ms" % [name, int(trees.get("placed")), int(trees.get("echo_count")),
			int(trees.get("refused")), int(trees.get("build_msec"))])
		for plane in ["xw", "zw"]:
			var rows := [PackedStringArray(), PackedStringArray(), PackedStringArray()]
			var cull_max: int = 0
			for turn in TURNS:
				var counts := [0, 0]
				for h in HEADINGS:
					_set_view(player, rig, turn, h, plane)
					await _frames(3)
					cull_max = maxi(cull_max, int(trees.get("cull_usec")))
					var c: Array = _count(trees, cam)
					counts[0] += c[0]
					counts[1] += c[1]
				rows[0].append("%3d" % roundi(counts[0] / 3.0))
				rows[1].append("%3d" % roundi(counts[1] / 3.0))
				rows[2].append("%3d" % roundi((counts[0] - counts[1]) / 3.0))
			print("PRESET %s %s crowns   %s" % [name, plane, " ".join(rows[0])])
			print("PRESET %s %s trunked  %s" % [name, plane, " ".join(rows[1])])
			print("PRESET %s %s floating %s   (cull at most %d us)" % [name, plane, " ".join(rows[2]), cull_max])
		# Frames: xw at SHOTS and zw at 30 (straight ahead), heading 0.
		var shots: Array = SHOTS.map(func(t: float) -> Array: return ["xw", t]) + [["zw", 30.0]]
		for shot in shots:
			_set_view(player, rig, shot[1], 0.0, shot[0])
			await _frames(4)
			await RenderingServer.frame_post_draw
			var tag: String = ("%02d" % int(shot[1])) if shot[0] == "xw" else ("zw%02d" % int(shot[1]))
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [name, tag]))
		# The GPU, flat and turned 30 (medians of 90 frames).
		for turn in [0.0, 30.0]:
			_set_view(player, rig, turn, 0.0, "xw")
			await _frames(20)
			var gpu: Array = []
			for i in 90:
				await process_frame
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			gpu.sort()
			print("PRESET %s GPU %.2f ms at %d degrees" % [name, gpu[45], int(turn)])
		# The volume view, from the start.
		_set_view(player, rig, 0.0, 0.0, "xw")
		for engine in ["Projected", "Combined"]:
			var other := Camera4D.new()
			lab.add_child(other)
			other.make_current()
			await _frames(2)
			cam.rendering_engine_name = engine
			cam.make_current()
			await _frames(20)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_volume_%s.png" % [name, engine.to_lower()]))
			other.queue_free()
		root.remove_child(lab)
		lab.free()
		await _frames(5)
	print("PRESETS DONE: turns %s" % str(TURNS))
	quit(0)


func _set_view(player: CharacterBody4D, rig: Node4D, turn: float, heading: float, plane: String) -> void:
	player.global_position = Vector4(0.0, 1.0, 14.0, 0.0)
	player.linear_velocity = Vector4.ZERO
	if "_slice_xw" in rig:
		rig.set("_slice_xw", deg_to_rad(turn) if plane == "xw" else 0.0)
		rig.set("_slice_zw", deg_to_rad(turn) if plane == "zw" else 0.0)
		rig.set("yaw", deg_to_rad(heading))
		rig.call("_apply")
	rig.set("pitch", deg_to_rad(-4.0))


## [crowns well cut, of them with the trunk cut too], within 45 m and in view.
func _count(trees: Node, cam: Camera4D) -> Array:
	var n: Vector4 = cam.global_basis.w.normalized()
	var crowns: int = 0
	var trunked: int = 0
	for oak in trees.get_children():
		var o := oak as Node4D
		var d: Vector4 = o.global_position - cam.global_position
		if Vector2(d.x, d.z).length() > 45.0 or not bool(o.call("is_in_view", cam, root)):
			continue
		var crown: Array = o.call("crown_box")
		if crown.size() != 2:
			continue
		var b: Projection = o.global_basis
		var cl: Vector4 = ((crown[0] as Vector4) + (crown[1] as Vector4)) * 0.5
		var hl: Vector4 = ((crown[1] as Vector4) - (crown[0] as Vector4)) * 0.5
		var c: Vector4 = o.global_position + b * cl
		var hn: float = sqrt(pow(hl.x * (b.x.dot(n)), 2) + pow(hl.y * (b.y.dot(n)), 2) + pow(hl.z * (b.z.dot(n)), 2) + pow(hl.w * (b.w.dot(n)), 2))
		if absf((c - cam.global_position).dot(n)) > 0.7 * hn:
			continue
		crowns += 1
		var wood := o.get_node_or_null("Tree/Wood") as MeshInstance4D
		if wood == null:
			continue
		var tk: Array = _trunk(wood.mesh as ArrayTetraMesh4D)
		var bw: Projection = wood.global_basis
		var at: Vector4 = wood.global_position + bw * Vector4(0.0, float(tk[2]), 0.0, 0.0)
		var ht: float = sqrt(pow(float(tk[0]) * bw.x.dot(n), 2) + pow(float(tk[0]) * bw.z.dot(n), 2) + pow(float(tk[1]) * bw.w.dot(n), 2))
		if absf((at - cam.global_position).dot(n)) <= ht:
			trunked += 1
	return [crowns, trunked]


func _trunk(m: ArrayTetraMesh4D) -> Array:
	if m == null:
		return [0.1, 0.1, 0.5]
	var key: int = m.get_instance_id()
	if _trunks.has(key):
		return _trunks[key]
	var verts: PackedVector4Array = m.get_vertex_positions()
	var lo: float = INF
	var hi: float = -INF
	for v in verts:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	var top: float = lo + (hi - lo) * 0.1
	var rx: float = 0.0
	var rw: float = 0.0
	for v in verts:
		if v.y <= top:
			rx = maxf(rx, maxf(absf(v.x), absf(v.z)))
			rw = maxf(rw, absf(v.w))
	_trunks[key] = [rx, rw, (lo + top) * 0.5]
	return _trunks[key]
