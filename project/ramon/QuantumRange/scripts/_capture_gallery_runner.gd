extends SceneTree

## Plan step 40: every target family in a row in front of the firing line, photographed from the line,
## then each one close up from its own slice and from a few W offsets (to see the shell open through W,
## the cluster's two hidden satellites, the capsule's petals thinning away). Frames in
## smoke_test_output/quantum_range/gallery/.
##
##   range_run.sh windowed gallery res://ramon/QuantumRange/scripts/_capture_gallery_runner.gd

const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/quantum_range/gallery/"
const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")
const FAMILIES := [
	["pip", "res://ramon/QuantumRange/scripts/targets/target_pip.gd", {}],
	["block", "res://ramon/QuantumRange/scripts/targets/target_block.gd", {}],
	["armoured", "res://ramon/QuantumRange/scripts/targets/target_armoured.gd", {}],
	["shell", "res://ramon/QuantumRange/scripts/targets/target_shell.gd", {}],
	["cluster", "res://ramon/QuantumRange/scripts/targets/target_cluster.gd", {}],
	["capsule", "res://ramon/QuantumRange/scripts/targets/target_capsule.gd", {}],
	["sentinel", "res://ramon/QuantumRange/scripts/targets/target_sentinel.gd", {}],
	["ring", "res://ramon/QuantumRange/scripts/targets/target_ring.gd", {"ring_at": Vector4(0, 0, 0, 0)}],
	["drone", "res://ramon/QuantumRange/scripts/targets/target_drone.gd", {"kind": "red"}],
	["heavy", "res://ramon/QuantumRange/scripts/targets/target_drone.gd", {"kind": "heavy"}],
	["friendly", "res://ramon/QuantumRange/scripts/targets/target_drone.gd", {"kind": "friendly"}],
	["chicken", "res://ramon/QuantumRange/scripts/targets/target_chicken.gd", {}],
]

var _r: Node
var _cam: Camera4D
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 110000:
		print("GALLERY: gave up after 110 s")
		return true
	return false


func _look(eye: Vector4, at: Vector4) -> void:
	var d: Vector4 = at - eye
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001)))


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_r = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_r)
	current_scene = _r
	for i in 20:
		await process_frame
	(_r.get("hud") as CanvasItem).visible = false
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_cam.set("view_angle_type", 1)
	_cam.set("field_of_view_4d", 1.3962634)
	_r.add_child(_cam)
	_cam.make_current()
	var t_build: int = Time.get_ticks_usec()
	var spots: Array = []
	var only: PackedStringArray = PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5).split(",")
	var n: int = FAMILIES.size()
	for i in n:
		var f: Array = FAMILIES[i]
		if not only.is_empty() and not (String(f[0]) in only):
			continue
		var t := Node4D.new()
		t.set_script(load(String(f[1])))
		for k in (f[2] as Dictionary):
			t.set(String(k), (f[2] as Dictionary)[k])
		if String(f[0]) == "ring":
			t.set("camera", _cam)
		var x: float = -11.0 + 22.0 * float(i) / float(n - 1)
		var at := Vector4(x, 1.7, -9.0, 0.0)
		t.position = at
		(_r.get("targets") as Node).add_child(t)
		spots.append([String(f[0]), at, t])
	print("GALLERY: built every family in %.1f ms (meshes %.1f ms)" % [(Time.get_ticks_usec() - t_build) / 1000.0, Shapes.build_ms])
	await create_timer(1.0).timeout
	_look(Vector4(0, 1.9, 2.0, 0), Vector4(0, 1.7, -9.0, 0))
	if only.is_empty():
		await _shot("00_row")
	for s in spots:
		var nm: String = s[0]
		var at: Vector4 = s[1]
		for w in [0.0, 0.35, 0.8, 1.1]:
			_look(Vector4(at.x, at.y + 0.4, at.z + 3.2, w), Vector4(at.x, at.y, at.z, w))
			if nm == "capsule" and w == 0.0:
				# Closed, then open (its cycle: 2.4 s shut, 0.35 s opening, 1.1 s open).
				await _shot("%s_w%.2f_closed" % [nm, w])
				await create_timer(2.6).timeout
			await _shot("%s_w%.2f" % [nm, w])
	print("GALLERY: done")
	quit()
