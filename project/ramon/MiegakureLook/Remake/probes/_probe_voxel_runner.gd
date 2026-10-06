extends SceneTree
## Probe 5 (PLAN.md): one small native VoxelWorld4D as a breakable plug. A grey crust over a gold
## core (a layered generator: the core box is "undefined" outside itself, so the crust shows through
## there), bounded, loaded by a static trigger. Then one strike: a sphere of air carved into its
## front, timed, and the frames before and after in the normal view and turned into W.
## Frames to smoke_test_output/crosswise/probe_voxel/.
##
## The world is scaled to the voxel size, so voxel numbers are metres / VOXEL. Its type name is
## avoided in code (the sandbox's terrain4d script still claims the class name VoxelWorld4D in the
## global class cache, engine_gotchas): ClassDB.instantiate, untyped variables.
##
## Run: Remake/run.sh windowed probe_voxel res://ramon/MiegakureLook/Remake/probes/_probe_voxel_runner.gd

const Mats := preload("res://ramon/MiegakureLook/Remake/world/mk_materials.gd")
const Env := preload("res://ramon/MiegakureLook/Remake/world/mk_env_4d.gd")
const Cam := preload("res://ramon/MiegakureLook/Remake/scripts/mk_camera_4d.gd")

const OUT := "res://smoke_test_output/crosswise/probe_voxel/"
const VOXEL := 0.2
const AIR := 254
const UNDEFINED := 255
## The plug in metres (x, y, z, w).
const PLUG := Vector4(1.6, 2.0, 1.6, 1.2)

var _stage: Node4D
var _focus: Node4D
var _cam: Camera4D
var _world
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage = Node4D.new()
	var env := Node4D.new()
	env.name = "Env"
	env.set_script(Env)
	_stage.add_child(env)
	var floor_size := Vector4(10, 1, 10, 6)
	var slab := MeshInstance4D.new()
	slab.mesh = Mats.box_mesh(floor_size)
	slab.position = Vector4(0, -0.5, 0, 0)
	slab.material_override = Mats.surface("white", floor_size, 2.0, {"origin": slab.position})
	_stage.add_child(slab)
	_focus = Node4D.new()
	_focus.name = "Focus"
	_focus.position = Vector4(0, 0.5, 1.2, 0)
	_stage.add_child(_focus)
	_cam = Camera4D.new()
	_cam.name = "Camera"
	_cam.set_script(Cam)
	_cam.set("distance", 9.0)
	_cam.set("target_path", NodePath("../Focus"))
	_cam.set("env_path", NodePath("../Env"))
	_stage.add_child(_cam)
	_build_plug()
	root.add_child.call_deferred(_stage)


func _build_plug() -> void:
	_world = ClassDB.instantiate("VoxelWorld4D")
	_world.name = "Plug"
	var size_v: Vector4 = PLUG / VOXEL
	var crust = ClassDB.instantiate("BoxVoxelGenerator4D")
	crust.set("center", Vector4.ZERO)
	crust.set("size", size_v)
	crust.set("material_inner", 0)
	crust.set("material_outer", AIR)
	var core = ClassDB.instantiate("BoxVoxelGenerator4D")
	core.set("center", Vector4.ZERO)
	core.set("size", size_v - Vector4(3, 3, 3, 2))
	core.set("material_inner", 1)
	core.set("material_outer", UNDEFINED)
	var layered = ClassDB.instantiate("LayeredVoxelGenerator4D")
	layered.set("layers", [crust, core])
	_world.set("generator", layered)
	var pal = ClassDB.instantiate("VoxelMaterialPalette4D")
	pal.set("colors", PackedColorArray([Color(0.52, 0.50, 0.62), Color(1.0, 0.74, 0.22)]))
	_world.set("material_palette", pal)
	_world.set("world_bounds_enabled", true)
	var half: Vector4i = Vector4i(ceili(size_v.x * 0.5) + 2, ceili(size_v.y * 0.5) + 2, ceili(size_v.z * 0.5) + 2, ceili(size_v.w * 0.5) + 2)
	_world.set("world_bounds_position", -half)
	_world.set("world_bounds_size", half * 2)
	_world.set("scale", Vector4(VOXEL, VOXEL, VOXEL, VOXEL))
	_world.set("position", Vector4(0, PLUG.y * 0.5, -1.0, 0))
	_stage.add_child(_world)
	var trigger = ClassDB.instantiate("VoxelLoadTrigger4D")
	trigger.name = "Trigger"
	trigger.set("load_distance", 24.0)
	_world.add_child(trigger)
	trigger.set("voxel_world_path", NodePath(".."))


func _meshes() -> int:
	var n: int = 0
	for c in _world.find_children("*", "MeshInstance4D", true, false):
		if (c as MeshInstance4D).mesh != null:
			n += 1
	return n


func _process(delta: float) -> bool:
	_total += delta
	if _total > 70.0:
		print("PROBE_VOXEL FAIL: timed out at step %d (meshes %d)" % [_step, _meshes()])
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _stage.is_inside_tree():
		return false
	_t += delta
	match _step:
		0:
			if _meshes() > 0 and _t > 1.0:
				print("PROBE_VOXEL PASS meshes appeared: %d after %.2f s" % [_meshes(), _t])
				_save("01_plug_normal")
				_step = 1
				_t = 0.0
		1:
			if _t > 0.3:
				_cam.call("request_turn")
				_step = 2
				_t = 0.0
		2:
			if _t > 1.2:
				_save("02_plug_turned")
				_cam.call("request_turn")
				_step = 3
				_t = 0.0
		3:
			if _t > 1.2:
				var edit = ClassDB.instantiate("SphereVoxelEdit4D")
				# The front face (toward +Z, the camera), a little above the middle.
				edit.set("center", Vector4(0.1, 0.2, PLUG.z * 0.5, 0.0) / VOXEL)
				edit.set("radius", 0.55 / VOXEL)
				edit.set("fill_material", AIR)
				var start: int = Time.get_ticks_usec()
				_world.call("apply_edit", edit)
				print("PROBE_VOXEL apply_edit %.2f ms" % (float(Time.get_ticks_usec() - start) / 1000.0))
				_step = 4
				_t = 0.0
		4:
			if _t > 0.2:
				print("PROBE_VOXEL frame after the edit: %.2f ms (delta)" % (delta * 1000.0))
			if _t > 0.8:
				_save("03_struck_normal")
				_cam.call("request_turn")
				_step = 5
				_t = 0.0
		5:
			if _t > 1.2:
				_save("04_struck_turned")
				print("PROBE_VOXEL done")
				return true
	return false


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("PROBE_VOXEL saved %s" % name)
