extends SceneTree

## A lighting bench for the R&D gallery: a plain floor and wall, LabKit's room for the sky and
## sun, and one light at a time, to see what a SpotLight4D and an OmniLight4D actually do in the
## cross-section renderer before the gallery leans on them. Frames to
## res://smoke_test_output/light_test/<nn>_<what>.png.
##
##   CreationLab/scripts/lab_run.sh windowed light_test res://ramon/CreationLab/scripts/_light_test_runner.gd

const Build := preload("res://ramon/CreationLab/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")
const Room := preload("res://ramon/CreationLab/LabKit/lab_room_4d.gd")
const OUT := "res://smoke_test_output/light_test/"

var _g: Node4D
var _n: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(what: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s%02d_%s.png" % [OUT, _n, what])
	print("shot ", what)
	_n += 1


func _run() -> void:
	_g = Node4D.new()
	root.add_child(_g)
	var room := Node4D.new()
	room.set_script(Room)
	room.name = "Room"
	_g.add_child(room)
	LabGrid.set_swatch("lt_floor", Color(0.62, 0.62, 0.62), Color(0.5, 0.5, 0.5), Color(0.58, 0.58, 0.58), 0.4)
	Build.box(_g, "Floor", Vector3(0, -0.25, 0), Vector3(30, 0.5, 30), "lt_floor")
	Build.box(_g, "Wall", Vector3(0, 4, -8), Vector3(30, 8, 0.5), "lt_floor")
	Build.box(_g, "Block", Vector3(0, 1, -2), Vector3(2, 2, 2), "lt_floor")
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(cam)
	cam.global_position = Vector4(0, 5, 12, 0)
	cam.global_basis = Mark.basis_looking(cam.global_position, Vector4(0, 0.5, -2, 0))
	cam.make_current()
	await _wait(1.0)
	room.set("mood_overrides", {"bright": {"key_energy": 0.7, "fill_energy": 0.15, "ambient": Color(0.30, 0.31, 0.34), "ambient_sky": 0.1, "exposure": 0.9}})
	for mood in ["dark", "bright"]:
		room.call("set_mood", mood, true, false)
		await _wait(0.4)
		await _shot(mood + "_no_light")
		var spot := SpotLight4D.new()
		_g.add_child(spot)
		spot.position = Vector4(0, 7, 0, 0)
		spot.basis = Mark.basis_looking(spot.position, Vector4(0, 0, -1.5, 0))
		spot.set("spot_angle_degrees", 32.0)
		spot.set("spot_range_meters", 16.0)
		spot.set("spot_range_attenuation", 0.2)
		spot.set("light_energy", 5.0)
		for a in [[50.0, 1.0], [70.0, 1.0], [70.0, 4.0], [90.0, 6.0]]:
			spot.set("spot_angle_degrees", float(a[0]))
			spot.set("spot_angle_attenuation", float(a[1]))
			await _wait(0.3)
			await _shot("%s_spot_ang%d_soft%.0f" % [mood, int(a[0]), float(a[1])])
		spot.queue_free()
		var omni := OmniLight4D.new()
		_g.add_child(omni)
		omni.position = Vector4(-4, 5, 0, 0)
		omni.set("omni_range_meters", 14.0)
		for a in [[0.15, 1.2]]:
			omni.set("omni_range_attenuation", float(a[0]))
			omni.set("light_energy", float(a[1]))
			await _wait(0.3)
			await _shot("%s_omni_att%.1f_e%.1f" % [mood, float(a[0]), float(a[1])])
		omni.queue_free()
	print("LIGHT TEST DONE")
	quit(0)
