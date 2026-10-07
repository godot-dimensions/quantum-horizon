extends SceneTree

## COVERAGE (WTools/PLAN.md steps 16-22): in the exploder lab, for each setup of the W Exploder, the plants
## the slice cuts within 45 m and in view, as the slice turns 0 to 60 degrees in xw, from three headings off
## the start (north, and 25 degrees either side); split into plants whose trunk is in the slice and crowns
## alone. Also the copies made, the time to make them and the time to cull them.
##
##   lab_run.sh windowed wt_coverage res://ramon/WTools/tests/_coverage_trees_runner.gd [setup names...]

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const LAB := "res://ramon/WTools/tests/exploder_lab.tscn"
const TURNS := [0.0, 5.0, 10.0, 15.0, 20.0, 30.0, 40.0, 50.0, 60.0]
const HEADINGS := [-25.0, 0.0, 25.0]
## name: [w_stretch, enabled, mode, w_reach, layer_spacing, auto_share, share, w_jitter, poisson_radius, trunk_w_taper]
const SETUPS := {
	"as_it_was": [1.0, false, "layers", 9.0, 4.5, false, 0.75, 0.0, 7.0],
	"round": [1.8, false, "layers", 9.0, 4.5, false, 0.75, 0.0, 7.0],
	"pen_now": [1.8, true, "layers", 9.0, 4.5, false, 0.75, 0.0, 7.0],
	"reach18": [1.8, true, "layers", 18.0, 4.5, true, 0.62, 0.0, 7.0],
	"reach18_jitter": [1.8, true, "layers", 18.0, 4.5, true, 0.62, 0.8, 7.0],
	"reach36": [1.8, true, "layers", 36.0, 4.5, true, 0.62, 0.8, 7.0],
	"poisson7": [1.8, true, "poisson", 18.0, 4.5, false, 0.62, 0.0, 7.0],
	"poisson5": [1.8, true, "poisson", 18.0, 4.5, false, 0.62, 0.0, 5.0],
	"reach18_taper4": [1.8, true, "layers", 18.0, 4.5, true, 0.62, 0.8, 7.0, 4.0],
	"reach18_taper8": [1.8, true, "layers", 18.0, 4.5, true, 0.62, 0.8, 7.0, 8.0],
	"reach18_taper14": [1.8, true, "layers", 18.0, 4.5, true, 0.62, 0.8, 7.0, 14.0],
	"reach18_slab70": [1.8, true, "layers", 18.0, 4.5, true, 0.62, 0.8, 7.0, 1.0, 0.7],
	"reach18_slab90": [1.8, true, "layers", 18.0, 4.5, true, 0.62, 0.8, 7.0, 1.0, 0.9],
	"reach36_slab90": [1.8, true, "layers", 36.0, 4.5, true, 0.62, 0.8, 7.0, 1.0, 0.9],
	"reach54_slab90": [1.8, true, "layers", 54.0, 4.5, true, 0.62, 0.8, 7.0, 1.0, 0.9],
}
const OUT := "res://smoke_test_output/wtools/coverage/"
## Frames of each setup at these turns, looking north.
const SHOT_TURNS := [0.0, 15.0, 30.0]

## Per wood mesh: [the trunk's half-width in x, its half-depth in W, the base's height], in the tree's frame.
var _trunks: Dictionary = {}

var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 840000:
		print("COVERAGE: gave up")
		return true
	return false


## The slice turned on either rig: the lab kit's older one keeps its turn in _slice_xw and yaw and builds
## its basis from them (so a basis set from outside is undone); the pen's takes the basis.
static func _tilt(rig: Node4D, xw: float, yaw: float) -> void:
	if "_slice_xw" in rig:
		rig.set("_slice_xw", xw)
		rig.set("_slice_zw", 0.0)
		rig.set("yaw", yaw)
		rig.call("_apply")
	else:
		SliceAngles.tilt(rig, xw, 0.0, yaw)


## VOLUME VIEW (step 23): reach 18 with the trunk slab, the copies drawn in the projection and not, from the
## start, in the projected and combined views; frames volume_<projected|combined>_<copies|none>.png.
func _volume() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for copies in [true, false]:
		var s: Array = SETUPS["reach18_slab90"]
		var lab: Node = (load(LAB) as PackedScene).instantiate()
		lab.set("readout", false)
		var trees: Node = lab.get_node("Trees")
		for k in [["mode", s[2]], ["w_reach", s[3]], ["layer_spacing", s[4]], ["auto_share", s[5]], ["w_jitter", s[7]], ["trunk_w_slab", s[10]], ["copies_projected", copies]]:
			trees.set(k[0], k[1])
		root.add_child(lab)
		current_scene = lab
		await _frames(40)
		var player := lab.get("player") as CharacterBody4D
		player.set("input_enabled", false)
		var cam := player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
		_tilt(lab.get("rig"), 0.0, 0.0)
		for engine in ["Projected", "Combined"]:
			var other := Camera4D.new()
			lab.add_child(other)
			other.make_current()
			await _frames(2)
			cam.rendering_engine_name = engine
			cam.make_current()
			await _frames(20)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "volume_%s_%s.png" % [engine.to_lower(), "copies" if copies else "none"]))
			other.queue_free()
		print("COVERAGE volume frames, copies projected %s" % str(copies))
		root.remove_child(lab)
		lab.free()
		await _frames(5)


## The trunk of a wood mesh: its half-width in x and half-depth in W over the lowest tenth of its height,
## and the height of that tenth's middle; in the mesh's own frame.
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var want: PackedStringArray = OS.get_cmdline_user_args()
	if want.size() > 0 and want[0] == "volume":
		await _volume()
		quit(0)
		return
	var names: Array = SETUPS.keys() if want.is_empty() else Array(want)
	for setup in names:
		var s: Array = SETUPS[setup]
		var lab: Node = (load(LAB) as PackedScene).instantiate()
		lab.set("readout", false)
		var trees: Node = lab.get_node("Trees")
		trees.set("enabled", s[1])
		trees.set("mode", s[2])
		trees.set("w_reach", s[3])
		trees.set("layer_spacing", s[4])
		trees.set("auto_share", s[5])
		trees.set("share", s[6])
		trees.set("w_jitter", s[7])
		trees.set("poisson_radius", s[8])
		trees.set("trunk_w_taper", float(s[9]) if s.size() > 9 else 1.0)
		trees.set("trunk_w_slab", float(s[10]) if s.size() > 10 else 0.0)
		for oak in trees.get_children():
			oak.set("w_stretch", s[0])
		root.add_child(lab)
		current_scene = lab
		await _frames(40)
		var player := lab.get("player") as CharacterBody4D
		player.set("input_enabled", false)
		var rig := lab.get("rig") as Node4D
		var cam := player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
		print("COVERAGE %s: %d placed, %d copies, %d refused, made in %d ms" % [setup, int(trees.get("placed")), int(trees.get("echo_count")),
			int(trees.get("refused")), int(trees.get("build_msec"))])
		var cut_rows := PackedStringArray()
		var trunk_rows := PackedStringArray()
		var float_rows := PackedStringArray()
		var cull_max: int = 0
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		for turn in TURNS:
			var crowns: int = 0
			var trunked: int = 0
			for h in HEADINGS:
				player.global_position = Vector4(0.0, 1.0, 14.0, 0.0)
				player.linear_velocity = Vector4.ZERO
				_tilt(rig, deg_to_rad(turn), deg_to_rad(h))
				rig.set("pitch", deg_to_rad(-4.0))
				await _frames(3)
				cull_max = maxi(cull_max, int(trees.get("cull_usec")))
				if h == 0.0 and SHOT_TURNS.has(turn):
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%02d.png" % [setup, int(turn)]))
				var n: Vector4 = cam.global_basis.w.normalized()
				for oak in trees.get_children():
					var o := oak as Node4D
					var d: Vector4 = o.global_position - cam.global_position
					if Vector2(d.x, d.z).length() > 45.0 or not bool(o.call("is_in_view", cam, root)):
						continue
					var crown: Array = o.call("crown_box")
					if crown.size() != 2:
						continue
					# The crown: well cut when the slice passes within 70% of its middle along its normal.
					var b: Projection = o.global_basis
					var cl: Vector4 = ((crown[0] as Vector4) + (crown[1] as Vector4)) * 0.5
					var hl: Vector4 = ((crown[1] as Vector4) - (crown[0] as Vector4)) * 0.5
					var c: Vector4 = o.global_position + b * cl
					var hn: float = sqrt(pow(hl.x * (b.x.dot(n)), 2) + pow(hl.y * (b.y.dot(n)), 2) + pow(hl.z * (b.z.dot(n)), 2) + pow(hl.w * (b.w.dot(n)), 2))
					if absf((c - cam.global_position).dot(n)) > 0.7 * hn:
						continue
					crowns += 1
					# The trunk: cut when the slice crosses its section a metre up.
					var wood := o.get_node_or_null("Tree/Wood") as MeshInstance4D
					if wood == null:
						continue
					var tk: Array = _trunk(wood.mesh as ArrayTetraMesh4D)
					var bw: Projection = wood.global_basis
					var at: Vector4 = wood.global_position + bw * Vector4(0.0, float(tk[2]), 0.0, 0.0)
					var ht: float = sqrt(pow(float(tk[0]) * bw.x.dot(n), 2) + pow(float(tk[0]) * bw.z.dot(n), 2) + pow(float(tk[1]) * bw.w.dot(n), 2))
					if absf((at - cam.global_position).dot(n)) <= ht:
						trunked += 1
			cut_rows.append("%3d" % roundi(crowns / 3.0))
			trunk_rows.append("%3d" % roundi(trunked / 3.0))
			float_rows.append("%3d" % roundi((crowns - trunked) / 3.0))
		print("COVERAGE %s crowns   %s" % [setup, " ".join(cut_rows)])
		print("COVERAGE %s trunked  %s" % [setup, " ".join(trunk_rows)])
		print("COVERAGE %s floating %s" % [setup, " ".join(float_rows)])
		print("COVERAGE %s cull at most %d us" % [setup, cull_max])
		root.remove_child(lab)
		lab.free()
		await _frames(5)
	print("COVERAGE: turns %s; plants cut within 45 m and in view, the mean of three headings" % str(TURNS))
	quit(0)
