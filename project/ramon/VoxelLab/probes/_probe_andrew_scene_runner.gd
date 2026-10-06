extends SceneTree
## Voxel Lab: Andrew's own test scenes (4Denthusiast, project/sandbox/, commit f291c49), opened as they
## are, to see what they show and whether they run: the landscape (fractal noise terrain, an ocean,
## caves) and the 24-cell fringe test. Their root script (res://scripts/voxel_edit_tester.gd) is not
## in the repo, so the scenes open without it; this checks what is left. Frames from his camera, then
## from a few places of our own, and the chunk and tetrahedron counts as they load.
## Frames to smoke_test_output/voxel_lab/andrew/.
##   VoxelLab/run.sh windowed andrew res://ramon/VoxelLab/probes/_probe_andrew_scene_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/andrew/"
const SCENES := ["res://sandbox/voxel_test.tscn", "res://sandbox/voxel_24cell_test.tscn"]

var _scene: Node
var _i: int = -1
var _t: float = 0.0
var _total: float = 0.0
var _shot: int = 0
var _last_us: int = 0
var _frames: Array = []
## Stand in for the missing script's load trigger (see _next).
var add_trigger: bool = true
var trigger_distance: float = 48.0


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2 and kv[0] == "trigger":
			add_trigger = kv[1] != "0"
			if add_trigger:
				trigger_distance = float(kv[1])
	_next.call_deferred()


func _next() -> void:
	if _scene != null:
		_scene.queue_free()
		_scene = null
	_i += 1
	if _i >= SCENES.size():
		print("ANDREW done")
		quit()
		return
	var packed: PackedScene = load(SCENES[_i])
	if packed == null:
		print("ANDREW FAIL: could not load %s" % SCENES[_i])
		return
	_scene = packed.instantiate()
	print("ANDREW opened %s: root script %s" % [SCENES[_i], "present" if _scene.get_script() != null else "MISSING (the scene opens without it)"])
	root.add_child(_scene)
	# The missing script must have told the engine where to load: the scenes hold no load trigger, so
	# without one no chunk ever loads (measured: 0 meshes after 15 s, a black frame). A trigger on his
	# camera stands in for it, here in the runner only; his files are not touched.
	var cams: Array = _scene.find_children("*", "Camera4D", true, false)
	if add_trigger and not cams.is_empty():
		var trig = ClassDB.instantiate("VoxelLoadTrigger4D")
		trig.name = "RunnerTrigger"
		trig.set("load_distance", trigger_distance)
		(cams[0] as Node).add_child(trig)
		print("ANDREW added a load trigger on the camera, %.0f voxels" % trigger_distance)
	_t = 0.0
	_shot = 0
	_frames = []


func _meshes() -> Array:
	var out: Array = []
	for w in _scene.find_children("*", "", true, false):
		if w.get_class() == "VoxelWorld4D":
			for c in w.get_children():
				if c is MeshInstance4D and (c as MeshInstance4D).mesh != null:
					out.append(c)
	return out


func _process(delta: float) -> bool:
	_total += delta
	var now: int = Time.get_ticks_usec()
	if _last_us > 0:
		_frames.append(float(now - _last_us) / 1000.0)
	_last_us = now
	if _total > 150.0:
		print("ANDREW FAIL: timed out")
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree():
		return false
	_t += delta
	var cam: Camera4D = _scene.find_children("*", "Camera4D", true, false)[0] if not _scene.find_children("*", "Camera4D", true, false).is_empty() else null
	var marks: Array = [3.0, 8.0, 12.0, 16.0, 20.0]
	if _shot < marks.size() and _t > float(marks[_shot]):
		var ms: Array = _meshes()
		var tets: int = 0
		for m in ms:
			tets += ((m as MeshInstance4D).mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
		var sorted: Array = _frames.duplicate()
		sorted.sort()
		print("ANDREW %s at %.0f s: %d chunk meshes, %d tetrahedra (~%.0f MB), frames median %.1f worst %.1f ms" % [
			SCENES[_i].get_file(), _t, ms.size(), tets, float(tets) * 1.25 / 1024.0,
			float(sorted[sorted.size() / 2]) if not sorted.is_empty() else 0.0, float(sorted[-1]) if not sorted.is_empty() else 0.0])
		_frames = []
		_save("%s_%d" % [SCENES[_i].get_file().get_basename(), _shot])
		if cam != null:
			# His camera first (as the scene has it), then a few of our own.
			match _shot:
				1:
					cam.position = Vector4(18, 14, 30, 0)
					cam.basis = Basis4D.from_zx(deg_to_rad(30.0)) * Basis4D.from_yz(deg_to_rad(-22.0))
				2:
					cam.position = Vector4(-6, 6, 12, 0)
					cam.basis = Basis4D.from_zx(deg_to_rad(-20.0)) * Basis4D.from_yz(deg_to_rad(-15.0))
				3:
					# Turned through W: the same place, the slice swung a quarter turn into W.
					cam.basis = Basis4D.from_zx(deg_to_rad(-20.0)) * Basis4D.from_yz(deg_to_rad(-15.0)) * Basis4D.from_zw(deg_to_rad(90.0))
		_shot += 1
	if _shot >= marks.size():
		_next()
	return false


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("ANDREW saved %s" % name)
