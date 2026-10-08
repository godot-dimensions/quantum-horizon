extends SceneTree

## Second research probe for the remake's plan (8 Oct evening). The same three cells as
## _probe_walker_maze_runner.gd, at 6 m and with 5 m walls 0.4 m thick, testing what the plan relies on:
##
##   settle   a drag that stops part way (70 deg ahead into W plus 12 sideways) eased to the nearest
##            quarter turn with Andrew's rotated_toward; prints the angle left, frames every few ticks
##   swap     the F key's turn: the heading snapped, then forward swapped with W over 0.35 s; frames
##   tall     the chase camera in the turned view: do 5 m walls hide the maze beyond?
##   thick    a half-turned frame with 0.4 m walls, against the 0.2 m slivers of the first probe
##   fpwall   first person pressed against a wall: does the near plane cut into it?
##   ghosts   4D sight with the camera's hue-shift fade: ana ghosts and kata ghosts, and is the slice
##            itself left untinted?
##
## Nothing of the pen is changed: its procedural-walker scene is loaded as it is.
##   run.sh windowed turns res://ramon/PhaseMazeRemake/scripts/_probe_turns_runner.gd

const SCENE := "res://ramon/chickenpen/chickenpen_proceduralwalker.tscn"
const GB := preload("res://ramon/chickenpen/scripts/ground_basis_4d.gd")
const OUT := "res://smoke_test_output/phase_maze_remake/turns/"
const C := 6.0
const H := 5.0
const T := 0.4

var _t0: int = 0
var _scene: Node4D
var _player: CharacterBody4D
var _rig: Node4D
var _avatar: Node4D
var _cam: Camera4D
var _mats: Dictionary = {}
var _layer: Dictionary = {0: [], 1: []}


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 150000:
		print("TURNS: gave up after 150 s")
		return true
	return false


func _shot(name: String, frames: int = 6) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("TURNS: ", name)


func _mat(c: Color) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_color = c
	return m


## Sizes and centres in cells (1 = one 6 m cell); a size of 0 is a wall's thickness.
func _box(size: Vector4, centre: Vector4, mat: String, layer: int = -1) -> void:
	var s := Vector4(T if size.x == 0.0 else size.x * C, size.y, T if size.z == 0.0 else size.z * C, T if size.w == 0.0 else size.w * C)
	var body := StaticBody4D.new()
	body.position = Vector4(centre.x * C, centre.y, centre.z * C, centre.w * C)
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = s
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = s
	mi.mesh = mesh
	mi.material_override = _mats[mat]
	body.add_child(mi)
	_scene.add_child(body)
	if layer >= 0:
		(_layer[layer] as Array).append(mi)


func _build() -> void:
	_mats = {"white": _mat(Color(0.86, 0.87, 0.88)), "cyan": _mat(Color(0.25, 0.78, 0.88)),
		"yellow": _mat(Color(0.95, 0.80, 0.25)), "green": _mat(Color(0.35, 0.80, 0.45))}
	var y := H * 0.5
	# Cells A (z 0), B (z -1), C (z -2); layer 0 at w 0, layer 1 at w 1. Units of cells.
	_box(Vector4(0, H, 3, 2), Vector4(-0.5, y, -1, 0.5), "white")
	_box(Vector4(0, H, 3, 2), Vector4(0.5, y, -1, 0.5), "white")
	_box(Vector4(1, H, 0, 2), Vector4(0, y, 0.5, 0.5), "white")
	_box(Vector4(1, H, 0, 2), Vector4(0, y, -2.5, 0.5), "white")
	_box(Vector4(1, H, 0, 1), Vector4(0, y, -1.5, 0), "white", 0)
	_box(Vector4(1, H, 0, 1), Vector4(0, y, -0.5, 1), "white", 1)
	_box(Vector4(1, H, 3, 0), Vector4(0, y, -1, -0.5), "cyan")
	_box(Vector4(1, H, 3, 0), Vector4(0, y, -1, 1.5), "cyan")
	_box(Vector4(1, H, 1, 0), Vector4(0, y, 0, 0.5), "cyan")
	_box(Vector4(1, H, 1, 0), Vector4(0, y, -2, 0.5), "cyan")
	_box(Vector4(0.27, 0.04, 0.27, 0.6), Vector4(0, 0.02, -1, 0), "yellow", 0)
	_box(Vector4(0.27, 0.04, 0.27, 0.6), Vector4(0, 0.02, -2, 1), "green", 1)


func _place(cell: Vector4, settle: int = 20) -> void:
	_player.global_position = Vector4(cell.x * C, 0.1, cell.z * C, cell.w * C)
	_player.linear_velocity = Vector4.ZERO
	for i in settle:
		await physics_frame


func _chase() -> void:
	_rig.set("collide_with_world", true)
	_rig.set("pivot_height", 2.1)
	_rig.set("_home_pivot", 2.1)
	_rig.set("distance", 3.6)
	_rig.set("_zoom_target", 3.6)
	_avatar.visible = true


func _first() -> void:
	_rig.set("collide_with_world", false)
	_rig.set("min_distance", 0.0)
	_rig.set("distance", 0.01)
	_rig.set("_zoom_target", 0.01)
	_rig.set("pivot_height", 1.15)
	_rig.set("_home_pivot", 1.15)
	_avatar.visible = false


func _frame(b: Projection, pitch_deg: float) -> void:
	_rig.basis = b
	_rig.set("pitch", deg_to_rad(pitch_deg))
	_rig.call("_apply")


## The nearest quarter-turn frame to a level frame: of the 24 rotations of a cube in the floor's
## (x, z, w), the one whose columns best match this frame's (largest trace of R^T B).
func _nearest_quarter(ground: Projection) -> Projection:
	var b: Basis = GB._to_3d(ground)
	var best := Basis()
	var best_score: float = -INF
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for i in 3:
		for j in 3:
			if j == i:
				continue
			for si in [-1.0, 1.0]:
				for sj in [-1.0, 1.0]:
					var a: Vector3 = axes[i] * si
					var c: Vector3 = axes[j] * sj
					var r := Basis(a, c, a.cross(c))
					var score: float = r.x.dot(b.x) + r.y.dot(b.y) + r.z.dot(b.z)
					if score > best_score:
						best_score = score
						best = r
	return GB._from_3d(best)


func _angle_between(a: Projection, b: Projection) -> float:
	var q: Quaternion = GB._to_3d(Basis4D.transposed(a) * b).get_rotation_quaternion()
	return rad_to_deg(2.0 * acos(clampf(absf(q.w), 0.0, 1.0)))


func _run() -> void:
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

	# settle: stop a drag part way, then ease to the nearest quarter at 4 rad/s.
	_chase()
	await _place(Vector4(0, 0, -1, 0))
	var b: Projection = GB.sliced(Basis4D.from_zx(0.0), Vector2(deg_to_rad(12.0), deg_to_rad(70.0)))
	_frame(b, -24.0)
	var goal: Projection = _nearest_quarter(b)
	print("TURNS: settle from %.1f deg off the nearest quarter; goal w column %s" % [_angle_between(b, goal), str(goal.w)])
	await _shot("settle_0_released")
	var ticks: int = 0
	while _angle_between(_rig.basis, goal) > 0.01 and ticks < 120:
		_frame(GB.rotated_toward(_rig.basis, goal, 4.0 / 60.0), -24.0)
		ticks += 1
		if ticks == 4:
			await _shot("settle_1_quarter_way", 1)
		await physics_frame
	print("TURNS: settled in %d ticks (%.2f s at 60), %.3f deg left" % [ticks, ticks / 60.0, _angle_between(_rig.basis, goal)])
	await _shot("settle_2_done")

	# swap: from level, facing 20 deg off the corridor; snap the heading, then forward <-> W over 0.35 s.
	_frame(Basis4D.from_zx(deg_to_rad(20.0)), -24.0)
	await _shot("swap_0_start")
	var level: Projection = Basis4D.from_zx(0.0)
	var swapped: Projection = level * Basis4D.from_zw(PI * 0.5)
	var t: float = 0.0
	var n: int = 0
	while t < 0.35:
		var dt: float = 1.0 / 60.0
		t += dt
		var target: Projection = level if _angle_between(_rig.basis, level) > 0.5 and t < 0.12 else swapped
		_frame(GB.rotated_toward(_rig.basis, target, deg_to_rad(110.0) / 0.35 * dt * 1.6), -24.0)
		n += 1
		if n == 12:
			await _shot("swap_1_mid", 1)
		await physics_frame
	_frame(swapped, -24.0)
	print("TURNS: swap ends with w column %s, forward %s" % [str(_rig.basis.w), str(-_rig.basis.z)])
	await _shot("swap_2_done")
	await _shot("tall_chase_turned", 4)

	# thick: half turned with 0.4 m walls.
	_frame(GB.sliced(Basis4D.from_zx(0.0), Vector2(0.0, deg_to_rad(45.0))), -24.0)
	await _shot("thick_half_turned")

	# fpwall: first person nose to the end wall of layer 0 (z -1.5 cells).
	_first()
	_frame(Basis4D.from_zx(0.0), 0.0)
	await _place(Vector4(0, 0, -1.2, 0), 40)
	print("TURNS: first person pressed to the wall, body at z %.2f (wall face at %.2f)" % [_player.global_position.z, -1.5 * C + T * 0.5])
	await _shot("fpwall")

	# ghosts: back to chase, in A at layer 0, looking down the corridor. Ana (layer 1) allowed to project.
	_chase()
	_frame(Basis4D.from_zx(0.0), -24.0)
	await _place(Vector4(0, 0, 0.1, 0))
	for mi in _scene.find_children("*", "MeshInstance4D", true, false):
		(mi as MeshInstance4D).set("allow_projection", (_layer[1] as Array).has(mi))
	root.world_3d = World3D.new()
	_cam.set("rendering_engine_name", "Combined")
	_cam.set("projection_opacity_base", 0.1)
	for mode in [1, 2]:
		_cam.set("w_fade_mode", mode)
		_cam.set("w_fade_distance", 6.0)
		_cam.set("w_fade_color_negative", Color(0.2, 0.75, 0.95))
		_cam.set("w_fade_color_positive", Color(1.0, 0.6, 0.2))
		await _shot("ghosts_ana_fade%d" % mode, 10)
	# And the other way: stand in layer 1, layer 0 (kata) projecting.
	for mi in _scene.find_children("*", "MeshInstance4D", true, false):
		(mi as MeshInstance4D).set("allow_projection", (_layer[0] as Array).has(mi))
	await _place(Vector4(0, 0, -1.1, 1))
	_frame(Basis4D.from_zx(PI), -24.0)
	await _shot("ghosts_kata_fade2", 10)
	print("TURNS: done")
	quit()
