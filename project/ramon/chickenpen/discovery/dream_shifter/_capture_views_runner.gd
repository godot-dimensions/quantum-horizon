extends SceneTree

## The explainer's pictures (discovery/dream_shifter/pen_look_explainer.gd): places of the valley, each caught in the
## dev look and in the art from the same camera, saved as views/<stem>_dev.jpg and views/<stem>_art.jpg. The HUD is
## hidden for the shots and the talk camera (World/TalkCam) is borrowed, so the player is not in them. Run it again
## when the valley changes; frames for checking go to smoke_test_output/dream_shifter/views/.
##
##   lab_run.sh windowed ds_views res://ramon/chickenpen/discovery/dream_shifter/_capture_views_runner.gd

const VIEWS_DIR := "res://ramon/chickenpen/discovery/dream_shifter/views/"
## [stem, camera position, the point it looks at]. W is the place's own (the cave's door is at W 3, the camp at -2.5).
const SHOTS := [
	["start", Vector4(27.5, 3.2, 15.0, 0.0), Vector4(24.0, 1.6, 40.0, 0.0)],
	["watchstone", Vector4(-4.0, 5.0, -6.0, 0.0), Vector4(-18.7, 7.5, -28.0, 0.0)],
	["cave", Vector4(9.5, 2.8, 41.5, 3.0), Vector4(7.4, 2.2, 29.6, 3.0)],
	["camp", Vector4(3.0, 3.6, 7.0, -2.5), Vector4(7.0, 0.8, -5.0, -2.5)],
]

var _room: Node
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 240000:
		print("VIEWS: gave up after 240 s")
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _hide_hud() -> void:
	for node in _room.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	for node in _room.find_children("*", "CanvasItem", true, false):
		var item := node as CanvasItem
		if not (item.get_parent() is CanvasItem):
			item.visible = false


static func _look_basis(gap: Vector4) -> Projection:
	var forward: Vector3 = Vector3(gap.x, gap.y, gap.z).normalized()
	var zc: Vector3 = -forward
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc).normalized()
	var yc: Vector3 = zc.cross(xc)
	return Projection(Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0), Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


func _grab(path_png: String, path_jpg: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path_png))
	if path_jpg != "":
		var small: Image = img.duplicate()
		small.resize(1600, int(1600.0 * float(img.get_height()) / float(img.get_width())), Image.INTERPOLATE_LANCZOS)
		small.save_jpg(ProjectSettings.globalize_path(path_jpg), 0.86)


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var check_dir: String = "res://smoke_test_output/dream_shifter/views/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(check_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VIEWS_DIR))
	OS.set_environment("PEN_LOOK", "art")
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	await _frames(90)
	var player: Node = _room.get_node("Player")
	player.set("input_enabled", false)
	var look: Node = _room.get_node("Systems/Look")
	var cam := _room.get_node("World/TalkCam") as Node4D
	print("VIEWS: window %s" % str(root.get_texture().get_size()))
	for shot in SHOTS:
		var stem: String = String(shot[0])
		cam.global_position = shot[1]
		cam.global_basis = _look_basis((shot[2] as Vector4) - (shot[1] as Vector4))
		cam.set("current", true)
		_hide_hud()
		for dev in [false, true]:
			look.call("set_dev", dev)
			await _frames(30)
			_hide_hud()
			var tag: String = "dev" if dev else "art"
			await _grab(check_dir + stem + "_" + tag + ".png", VIEWS_DIR + stem + "_" + tag + ".jpg")
			print("VIEW %s %s" % [stem, tag])
	print("VIEWS: DONE")
	quit(0)
