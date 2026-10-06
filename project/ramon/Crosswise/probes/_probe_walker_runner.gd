extends SceneTree
## Probes 6, 7 and 9 (PLAN.md): the copied walker on a lane-banded slab under the islands' light,
## driven through the real walker code (scripted keys) in the normal view, through a turn, and in the
## turned view. Measures what each key does to his 4D position (axis purity), checks the slice stays
## on him, and saves frames to smoke_test_output/crosswise/probe_walker/.
##
## Run: Crosswise/run.sh windowed probe_walker res://ramon/Crosswise/probes/_probe_walker_runner.gd

const Mats := preload("res://ramon/Crosswise/world/mk_materials.gd")
const Env := preload("res://ramon/Crosswise/world/mk_env_4d.gd")
const Cam := preload("res://ramon/Crosswise/scripts/mk_camera_4d.gd")
const WalkerBuild := preload("res://ramon/Crosswise/character/mk_walker_build.gd")

const OUT := "res://smoke_test_output/crosswise/probe_walker/"
const LANES := {
	"width": 1.6, "zero_w": 0.0,
	"tints": [Color(0.80, 0.88, 1.0), Color(0.90, 0.94, 1.0), Color(1, 1, 1), Color(1.0, 0.96, 0.88), Color(1.0, 0.90, 0.76)],
	"seam": Color(0.55, 0.62, 0.78, 0.9), "mark_lane": 2, "mark_color": Color(0.35, 0.82, 0.88), "mark_mix": 0.35,
}

var _stage: Node4D
var _walker: CharacterBody4D
var _cam: Camera4D
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _mark: Vector4
var _checks: int = 0
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage = Node4D.new()
	_stage.name = "Stage"
	var env := Node4D.new()
	env.name = "Env"
	env.set_script(Env)
	_stage.add_child(env)
	_slab(Vector4(0, -0.5, 0, 0), Vector4(16, 1, 16, 8), "white", {"lanes": LANES, "side_tint": Color(0.55, 0.58, 0.66), "wface": Color(0.36, 0.33, 0.78, 0.7)})
	# A pillar in lane 0 only, a cube in lane +2, a slab across W (a W-wall) at w 2.4.
	_slab(Vector4(3, 0.9, -3, 0), Vector4(1.2, 1.8, 1.2, 1.6), "grey", {"wface": Color(0.36, 0.33, 0.78, 0.8), "wedge": Color(0.55, 0.45, 1.0, 0.6)})
	_slab(Vector4(-3, 0.5, -2, 3.2), Vector4(1, 1, 1, 1), "yellow", {"wface": Color(0.36, 0.33, 0.78, 0.8)})
	_slab(Vector4(0, 0.6, -5, 2.4), Vector4(10, 1.2, 4, 0.3), "grey", {"wface": Color(0.36, 0.33, 0.78, 0.8)})
	_walker = WalkerBuild.make()
	_walker.position = Vector4(0, 0.05, 2, 0)
	_stage.add_child(_walker)
	_cam = Camera4D.new()
	_cam.name = "Camera"
	_cam.set_script(Cam)
	_stage.add_child(_cam)
	_cam.set("target_path", NodePath("../Walker"))
	_cam.set("env_path", NodePath("../Env"))
	_walker.set("camera_path", NodePath("../Camera"))
	_walker.set("scripted", true)
	root.add_child.call_deferred(_stage)


func _slab(at: Vector4, size: Vector4, tex: String, opts: Dictionary) -> void:
	var body := StaticBody4D.new()
	body.position = at
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance4D.new()
	mesh.mesh = Mats.box_mesh(size)
	var o: Dictionary = opts.duplicate()
	o["origin"] = at
	mesh.material_override = Mats.surface(tex, size, 2.0, o)
	body.add_child(mesh)
	_stage.add_child(body)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 75.0:
		print("PROBE_WALKER FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _stage.is_inside_tree():
		return false
	_t += delta
	match _step:
		0:
			if _t > 1.5:
				_save("01_normal_idle")
				_mark = _walker.global_position
				_go(Vector2(0, -1))
		1:
			if _t > 0.6:
				_save("02_normal_walk_forward")
			if _t > 1.2:
				_axis("normal W key", Vector4(0, 0, -1, 0))
				_go(Vector2(1, 0))
		2:
			if _t > 1.0:
				_axis("normal D key", Vector4(1, 0, 0, 0))
				_go(Vector2.ZERO)
		3:
			if _t > 0.5:
				_cam.call("request_turn")
				_step += 1
				_t = 0.0
		4:
			if absf(_t - 0.3) < delta:
				_save("03_mid_turn")
			if _t > 1.2:
				_save("04_turned_idle")
				_slice_check("turned")
				_mark = _walker.global_position
				_go(Vector2(0, -1))
		5:
			if _t > 0.6:
				_save("05_turned_walk_forward")
			if _t > 1.2:
				_axis("turned W key", Vector4(0, 0, 0, 1))
				_go(Vector2(-1, 0))
		6:
			if _t > 1.0:
				_axis("turned A key", Vector4(-1, 0, 0, 0))
				_go(Vector2(0, 1))
		7:
			if _t > 0.5:
				_save("06_turned_walk_back")
			if _t > 0.9:
				_axis("turned S key", Vector4(0, 0, 0, -1))
				_go(Vector2.ZERO)
		8:
			if _t > 0.4:
				_cam.call("request_turn")
				_step += 1
				_t = 0.0
		9:
			if _t > 1.3:
				_save("07_back_to_normal")
				_slice_check("normal")
				print("PROBE_WALKER done: %d checks, %d failed" % [_checks, _fails])
				return true
	return false


func _go(move: Vector2) -> void:
	_walker.set("scripted_move", move)
	_mark = _walker.global_position
	_step += 1
	_t = 0.0


## How much of the move went along `axis`, against the rest.
func _axis(label: String, axis: Vector4) -> void:
	var d: Vector4 = _walker.global_position - _mark
	d.y = 0.0
	var along: float = d.dot(axis)
	var off: float = (d - axis * along).length()
	var ok: bool = along > 0.8 and off < 0.05 * along + 0.02
	_checks += 1
	if not ok:
		_fails += 1
	print("PROBE_WALKER %s %s: moved %s, along %.3f, off-axis %.3f" % ["PASS" if ok else "FAIL", label, d, along, off])


## Is the slice on him? His offset from the camera along the slice's normal must be ~0.
func _slice_check(label: String) -> void:
	var n: Vector4 = _cam.global_basis.w
	var off: float = n.dot(_walker.global_position - _cam.global_position)
	var ok: bool = absf(off) < 0.01
	_checks += 1
	if not ok:
		_fails += 1
	print("PROBE_WALKER %s slice on him (%s): normal %s, offset %.4f" % ["PASS" if ok else "FAIL", label, n, off])


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("PROBE_WALKER saved %s at %s" % [name, _walker.global_position])
