extends SceneTree

## A few frames of the Dream Shifter's pedestal (whatever its style is; "laputa" since 10 Oct night), art and dev, and
## one with the camera's slice turned into W (the cradle's ana and kata arms come in), for a look.
##
##   lab_run.sh windowed ds_pedestal res://ramon/chickenpen/discovery/dream_shifter/_shot_pedestal_runner.gd

const OUT := "res://smoke_test_output/dream_shifter/laputa/"

var _room: Node


class RunnerGuard extends Node:
	func _input(event: InputEvent) -> void:
		if event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


static func _look_basis(gap: Vector4) -> Projection:
	var forward: Vector3 = Vector3(gap.x, gap.y, gap.z).normalized()
	var zc: Vector3 = -forward
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc).normalized()
	var yc: Vector3 = zc.cross(xc)
	return Projection(Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0), Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0, 0, 0, 1))


func _shot(name: String, from: Vector4, at: Vector4, into_w: float = 0.0) -> void:
	var cam := _room.get_node("World/TalkCam") as Node4D
	cam.global_position = from
	cam.global_basis = _look_basis(at - from) * Basis4D.from_xw(into_w)
	cam.set("current", true)
	await _frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("FRAME %s" % name)


func _hide_hud() -> void:
	for node in _room.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	for node in _room.find_children("*", "CanvasItem", true, false):
		var item := node as CanvasItem
		if not (item.get_parent() is CanvasItem):
			item.visible = false


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	OS.set_environment("PEN_LOOK", "art")
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	var guard := RunnerGuard.new()
	root.add_child(guard)
	await _frames(100)
	var crossing: Node = _room.get_node_or_null("Crossing")
	print("PEDESTAL: away at start %s" % str(crossing != null and bool(crossing.call("is_away"))))
	var player := _room.get_node("Player") as Node4D
	player.set("input_enabled", false)
	# The HUD's DEV / ART switch first, from the player's own camera on the road, in both looks.
	player.global_position = Vector4(24.9, 1.2, 21.0, 0.0)
	var rig := player.get_node("CameraRig") as Node4D
	rig.call("face_toward", Vector4(0.0, 0.0, 1.0, 0.0))
	rig.call("_apply")
	await _frames(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "00_hud_art.png"))
	print("FRAME 00_hud_art")
	_room.get_node("Systems/Look").call("set_dev", true)
	await _frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "00_hud_switching.png"))
	await _frames(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "00_hud_dev.png"))
	print("FRAME 00_hud_dev")
	_room.get_node("Systems/Look").call("set_dev", false)
	await _frames(20)
	player.global_position = Vector4(30.0, 1.2, 22.0, 0.0)
	var shifter := _room.get_node("World/DreamShifter") as Node4D
	var c: Vector4 = shifter.global_position
	_hide_hud()
	# From the road, three-quarter; square on; close; at a walker's eye coming up the spur; and the slice turned into W.
	await _shot("01_three_quarter", c + Vector4(4.2, 1.9, 3.0, 0.0), c + Vector4(0.0, 1.25, 0.0, 0.0))
	await _shot("02_front", c + Vector4(4.6, 1.5, 0.0, 0.0), c + Vector4(0.0, 1.3, 0.0, 0.0))
	await _shot("03_close", c + Vector4(2.0, 1.5, 0.9, 0.0), c + Vector4(0.0, 1.5, 0.0, 0.0))
	await _shot("05_eye", c + Vector4(3.4, 1.62, 0.7, 0.0), c + Vector4(0.0, 1.55, 0.0, 0.0))
	await _shot("06_slice_turned", c + Vector4(4.0, 1.7, 1.2, 0.0), c + Vector4(0.0, 1.4, 0.0, 0.0), 0.6)
	_room.get_node("Systems/Look").call("set_dev", true)
	await _frames(20)
	_hide_hud()
	await _shot("04_dev", c + Vector4(4.2, 1.9, 3.0, 0.0), c + Vector4(0.0, 1.1, 0.0, 0.0))
	print("PEDESTAL: away at end %s" % str(crossing != null and bool(crossing.call("is_away"))))
	print("PEDESTAL: DONE")
	quit(0)
