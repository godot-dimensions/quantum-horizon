extends "res://ramon/WaterLab/scripts/_wl_shots.gd"

## WATER LAB experiment: can a Camera4D inside a SubViewport render a 4D specimen (the hammerhead, a
## lofted 4D mesh) and a slice herd (a koi) into that viewport's texture, for the fish wall's turntables?
## The main view shows the texture on a TextureRect. Frames in smoke_test_output/water_lab/studio/.

const Shark := preload("res://ramon/WaterLab/life/shark_4d.gd")
const Herd := preload("res://ramon/WaterLab/shared/slice_herd_4d.gd")
const KoiMesh := preload("res://ramon/WaterLab/life/koi_mesh.gd")
const KOI := preload("res://ramon/WaterLab/life/koi.gdshader")

var _vp: SubViewport
var _shark: Node4D


func setup() -> void:
	out = "res://smoke_test_output/water_lab/studio/"
	tag = "STUDIO"
	var world: Node4D = test_world(Vector4(0.0, 1.6, 6.0, 0.0), Vector4(0.0, 1.0, 0.0, 0.0))
	_vp = SubViewport.new()
	_vp.size = Vector2i(640, 400)
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	_vp.add_child(cam)
	aim(cam, Vector4(0.0, -400.0, 3.4, 0.0), Vector4(0.0, -400.0, 0.0, 0.0))
	cam.make_current()
	_shark = Node4D.new()
	_shark.set_script(Shark)
	_shark.set("half_extents", Vector4(50, 50, 50, 50))
	_vp.add_child(_shark)
	var koi := Node4D.new()
	koi.set_script(Herd)
	koi.set("mesh", KoiMesh.build())
	koi.set("shader", KOI)
	koi.set("count", 1)
	_vp.add_child(koi)
	var tr := TextureRect.new()
	tr.texture = _vp.get_texture()
	tr.position = Vector2(20, 20)
	root.add_child(tr)
	step(10, func() -> void:
		_shark.set_process(false)
		_shark.set("p", Vector4(0.0, -400.0, 0.0, 0.0))
		_shark.set("frame", _shark.call("_frame_for", Vector4(1.0, 0.0, 0.0, 0.0)))
		_shark.call("_pose")
		koi.call("write", 0, Vector4(0.0, -400.7, 0.8, 0.0), Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Color(0.0, 0.4, 0.1, 0.0), Vector4(1.0, 0.05, 0.8, 0.0))
		koi.call("upload"))
	step(20, nop, "01_studio_in_corner")
