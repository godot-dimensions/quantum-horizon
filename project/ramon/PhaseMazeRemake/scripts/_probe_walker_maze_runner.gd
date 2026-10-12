extends SceneTree

## Research probe for the remake's plan (8 Oct): the pen's walker (Andrew's stepping and facing,
## the orbit rig) in three maze cells laid out in x, z AND w, photographed from behind and from the
## eyes, with the slice level, half turned and turned all the way into W. Nothing of the pen is
## changed: its procedural-walker scene is loaded as it is and walls are added to the instance.
##
##   Cells are 4 m in x, z and w. Layer 0 is w -2..2, layer 1 is w 2..6.
##   A (z 2..-2) and B (z -2..-6) are open to each other in layer 0; layer 0 ends in a wall at z -6.
##   Between the layers (w 2) a wall closes A and C, but B is open: the way on is ana, then on to C.
##   White walls stand across x or z; cyan walls stand across w and are seen only when the slice turns.
##
## Frames in smoke_test_output/phase_maze_remake/probe/.
##   run.sh windowed probe res://ramon/PhaseMazeRemake/scripts/_probe_walker_maze_runner.gd [cell=6]
##
## With cell=6 every cell is 6 m instead of 4 (heights unchanged), and the frames are prefixed c6_; two
## more framings are added for third person: over the shoulder (the rig's aiming framing) and high.

const SCENE := "res://ramon/chickenpen/chickenpen_proceduralwalker.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/probe/"
const H := 3.0
const T := 0.2

var _t0: int = 0
var _scene: Node4D
var _player: CharacterBody4D
var _rig: Node4D
var _avatar: Node4D
var _cam: Camera4D
var _white := TetraMaterial4D.new()
var _cyan := TetraMaterial4D.new()
var _yellow := TetraMaterial4D.new()
var _green := TetraMaterial4D.new()
var _layer1_only: Array[MeshInstance4D] = []
## Cell size over 4: every x, z and w below is written for 4 m cells and multiplied by this.
var _k: float = 1.0
var _pre: String = ""


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 120000:
		print("PROBE: gave up after 120 s")
		return true
	return false


func _shot(name: String, frames: int = 8) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	name = _pre + name
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("PROBE: ", name, "  camera distance %.2f" % float(_rig.get("distance")))


func _box(size: Vector4, centre: Vector4, mat: TetraMaterial4D, layer1: bool = false) -> void:
	size = Vector4(maxf(size.x * _k, T) if size.x > T else T, size.y, maxf(size.z * _k, T) if size.z > T else T, maxf(size.w * _k, T) if size.w > T else T)
	centre = Vector4(centre.x * _k, centre.y, centre.z * _k, centre.w * _k)
	var body := StaticBody4D.new()
	body.position = centre
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	_scene.add_child(body)
	if layer1:
		_layer1_only.append(mi)


func _build() -> void:
	_white.albedo_color = Color(0.86, 0.87, 0.88)
	_cyan.albedo_color = Color(0.25, 0.78, 0.88)
	_yellow.albedo_color = Color(0.95, 0.80, 0.25)
	_green.albedo_color = Color(0.35, 0.80, 0.45)
	var y := H * 0.5
	# Side walls, both layers, the whole run A..C.
	_box(Vector4(T, H, 12.0, 8.0), Vector4(-2.0, y, -4.0, 2.0), _white)
	_box(Vector4(T, H, 12.0, 8.0), Vector4(2.0, y, -4.0, 2.0), _white)
	# Ends.
	_box(Vector4(4.0, H, T, 8.0), Vector4(0.0, y, 2.0, 2.0), _white)
	_box(Vector4(4.0, H, T, 8.0), Vector4(0.0, y, -10.0, 2.0), _white)
	# Layer 0 stops at z -6; layer 1 is closed between A and B.
	_box(Vector4(4.0, H, T, 4.0), Vector4(0.0, y, -6.0, 0.0), _white)
	_box(Vector4(4.0, H, T, 4.0), Vector4(0.0, y, -2.0, 4.0), _white, true)
	# The walls across W: the two outer ones, and between the layers at A and C (B is the way through).
	_box(Vector4(4.0, H, 12.0, T), Vector4(0.0, y, -4.0, -2.0), _cyan)
	_box(Vector4(4.0, H, 12.0, T), Vector4(0.0, y, -4.0, 6.0), _cyan)
	_box(Vector4(4.0, H, 4.0, T), Vector4(0.0, y, 0.0, 2.0), _cyan)
	_box(Vector4(4.0, H, 4.0, T), Vector4(0.0, y, -8.0, 2.0), _cyan)
	# A painted cue in B (layer 0 only) and the exit pad in C (layer 1 only).
	_box(Vector4(1.6, 0.04, 1.6, 3.6), Vector4(0.0, 0.02, -4.0, 0.0), _yellow)
	_box(Vector4(1.6, 0.04, 1.6, 3.6), Vector4(0.0, 0.02, -8.0, 4.0), _green, true)


func _place(at: Vector4, settle: int = 20) -> void:
	_player.global_position = Vector4(at.x * _k, at.y, at.z * _k, at.w * _k)
	_player.linear_velocity = Vector4.ZERO
	for i in settle:
		await physics_frame


func _first_person(on: bool) -> void:
	_rig.set("collide_with_world", not on)
	_rig.set("min_distance", 0.0 if on else 1.5)
	_rig.set("distance", 0.01 if on else 5.0)
	_rig.set("_zoom_target", 0.01 if on else 5.0)
	_rig.set("pivot_height", 1.15 if on else 1.1)
	_rig.set("_home_pivot", 1.15 if on else 1.1)
	_avatar.visible = not on


func _level(yaw: float) -> void:
	_rig.basis = Basis4D.from_zx(yaw)
	_rig.set("pitch", deg_to_rad(-8.6))
	_rig.call("_apply")


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cell="):
			_k = float(a.substr(5)) / 4.0
			_pre = "c%d_" % int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_scene = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	for i in 10:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_scene.get_node("Posts") as Node4D).visible = false
	_player = _scene.get_node("Player")
	_rig = _scene.get_node("Player/CameraRig")
	_avatar = _scene.get_node("Player/Avatar")
	_cam = _scene.get_node("Player/CameraRig/Pitch/Camera4D")
	_player.set("input_enabled", false)
	_rig.set_process_unhandled_input(false)
	_player.set_process_unhandled_input(false)
	_build()
	for i in 4:
		await process_frame

	for fp in [false, true]:
		var tag: String = "fp" if fp else "tp"
		_first_person(fp)
		# A, looking down the corridor to layer 0's dead end.
		_level(0.0)
		await _place(Vector4(0.0, 0.1, 0.6, 0.0))
		await _shot(tag + "_1_flat_A")
		# B, the slice turned into W in steps: forward leans from -z toward w.
		await _place(Vector4(0.0, 0.1, -4.0, 0.0))
		for deg in [45.0, 90.0]:
			_level(0.0)
			_rig.call("drag_slice", Vector2(0.0, deg_to_rad(deg)))
			await _shot("%s_2_B_turned_%d" % [tag, int(deg)])
		# B in layer 1, level again: the way on to C is open.
		_level(0.0)
		await _place(Vector4(0.0, 0.1, -3.4, 4.0))
		await _shot(tag + "_3_flat_B_layer1")

	# Two more third-person framings: over the shoulder (the rig's aiming framing, which the pen uses at
	# its range counter) and a high chase camera looking down past the head.
	_first_person(false)
	for framing in ["os", "hi"]:
		_rig.call("set_aiming", framing == "os")
		if framing == "hi":
			_rig.set("pivot_height", 2.1)
			_rig.set("_home_pivot", 2.1)
			_rig.set("_zoom_target", 3.6)
		_level(0.0)
		if framing == "hi":
			_rig.set("pitch", deg_to_rad(-24.0))
			_rig.call("_apply")
		await _place(Vector4(0.0, 0.1, 0.6, 0.0), 40)
		await _shot(framing + "_1_flat_A")
		await _place(Vector4(0.0, 0.1, -4.0, 0.0))
		_level(0.0)
		if framing == "hi":
			_rig.set("pitch", deg_to_rad(-24.0))
		_rig.call("drag_slice", Vector2(0.0, deg_to_rad(90.0)))
		await _shot(framing + "_2_B_turned_90")
	_rig.call("set_aiming", false)

	# 4D sight: back in A, third person, the Combined pass ghosting only what is in layer 1.
	_first_person(false)
	_level(0.0)
	await _place(Vector4(0.0, 0.1, 0.6, 0.0))
	for child in _scene.find_children("*", "MeshInstance4D", true, false):
		(child as MeshInstance4D).set("allow_projection", _layer1_only.has(child))
	root.world_3d = World3D.new()
	_cam.set("rendering_engine_name", "Combined")
	_cam.set("projection_opacity_base", 0.08)
	await _shot("tp_4_combined_A", 12)
	print("PROBE: done")
	quit()
