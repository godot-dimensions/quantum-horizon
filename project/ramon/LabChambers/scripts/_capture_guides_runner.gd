extends SceneTree

## The guides batch: the goat room's guide paths from above and from the entrance, the pivot by
## the research wall, the desk on the left wall with its spot, the picker tucked at the pedestal,
## the hologram's finer grain close up, the Creation Lab wall, and Room 2's path lab from above and
## from the door, at our W and moved 0.9 m through W (cases 4 and 5 change). To
## res://smoke_test_output/goat_room/guides/.
##
##   CreationLab/scripts/lab_run.sh windowed guides res://ramon/LabChambers/scripts/_capture_guides_runner.gd

const SCENE := "res://ramon/LabChambers/goat_room.tscn"
const OUT := "res://smoke_test_output/goat_room/guides/"
const Mark := preload("res://ramon/LabKit/lab_mark_4d.gd")

var _g: Node
var _cam: Camera4D


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
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


func _look(from: Vector4, to: Vector4) -> void:
	_cam.global_position = from
	_cam.global_basis = Mark.basis_looking(from, to)


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.5)
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	_g.get_node("Room").call("set_mood", "dark", true, false)
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(0.0, 0.05, 12.0, 0.0)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(_cam)
	_cam.current = true
	_look(Vector4(0.5, 9.4, 4.5, 0), Vector4(0.5, 0.0, -1.0, 0))
	await _wait(0.6)
	await _shot("goat_room_above")
	_look(Vector4(0.0, 1.9, 9.6, 0), Vector4(0.0, 0.4, 2.0, 0))
	await _wait(0.4)
	await _shot("from_entrance")
	_look(Vector4(4.4, 1.7, 6.4, 0), Vector4(7.5, 1.2, 2.4, 0))
	await _wait(0.4)
	await _shot("wall_pivot")
	# The curved arrows close, from above: each should stay a chevron, turned to the curve.
	_look(Vector4(3.2, 4.2, 6.6, 0), Vector4(3.4, 0.0, 3.9, 0))
	await _wait(0.4)
	await _shot("curve_arrows_close")
	await _wait(0.5)
	await _shot("curve_arrows_close_later")
	# The pad, and where the entrance arrows end in their line.
	_look(Vector4(6.6, 3.0, 6.2, 0), Vector4(6.6, 0.0, 3.0, 0))
	await _wait(0.4)
	await _shot("wall_pad")
	_look(Vector4(1.6, 2.2, 6.8, 0), Vector4(0.0, 0.0, 3.6, 0))
	await _wait(0.4)
	await _shot("entrance_end_line")
	_look(Vector4(-4.2, 1.9, 5.6, 0), Vector4(-8.6, 0.9, 2.8, 0))
	await _wait(0.4)
	await _shot("desk_on_left_wall")
	_look(Vector4(1.6, 1.0, 5.4, 0), Vector4(0.0, 0.4, 1.6, 0))
	await _wait(0.4)
	await _shot("picker_at_pedestal")
	_look(Vector4(1.2, 1.9, 3.2, 0), Vector4(0.0, 1.9, -1.5, 0))
	await _wait(0.4)
	await _shot("hologram_close")
	_look(Vector4(-1.8, 4.2, 4.0, 0), Vector4(-8.5, 4.2, -5.0, 0))
	await _wait(0.6)
	await _shot("creation_lab_wall")
	# Room 2's path lab.
	_look(Vector4(0.0, 9.6, -14.5, 0), Vector4(0.0, 0.0, -27.5, 0))
	await _wait(0.6)
	await _shot("room2_above")
	_look(Vector4(0.0, 9.6, -14.5, 0.9), Vector4(0.0, 0.0, -27.5, 0.9))
	await _wait(0.4)
	await _shot("room2_above_w09")
	# The slice turned through W (as the playable world's player turns it): the marks are sliced with
	# their strips, so they thin and go further off, the way the slice leaves them.
	for deg in [15.0, 35.0]:
		_look(Vector4(0.0, 9.6, -14.5, 0), Vector4(0.0, 0.0, -27.5, 0))
		_cam.global_basis = _cam.global_basis * Basis4D.from_xw(deg_to_rad(deg))
		await _wait(0.4)
		await _shot("room2_slice_turned_%d" % int(deg))
	_look(Vector4(0.5, 9.4, 4.5, 0), Vector4(0.5, 0.0, -1.0, 0))
	_cam.global_basis = _cam.global_basis * Basis4D.from_xw(deg_to_rad(25.0))
	await _wait(0.4)
	await _shot("goat_room_slice_turned_25")
	_look(Vector4(-3.0, 2.0, -13.0, 0), Vector4(0.0, 0.0, -24.0, 0))
	await _wait(0.4)
	await _shot("room2_from_door")
	_look(Vector4(0.0, 4.5, -19.0, 0), Vector4(0.0, 4.5, -42.0, 0))
	await _wait(0.4)
	await _shot("room2_sign")
	quit(0)
