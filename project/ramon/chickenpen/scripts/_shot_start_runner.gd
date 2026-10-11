extends SceneTree

## The very first view of the pen (Ramon, 11 Oct: the character starts 3 m forward so the camera clears the walls and
## the tree). Prints where the camera is and which way it looks, and saves the frame.
##
##   lab_run.sh windowed pen_start res://ramon/chickenpen/scripts/_shot_start_runner.gd [name]

const OUT := "res://smoke_test_output/pen_start/"


class RunnerGuard extends Node:
	func _input(event: InputEvent) -> void:
		if event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var room: Node = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	root.add_child(RunnerGuard.new())
	for i in 90:
		await process_frame
	var player := room.get_node("Player") as Node4D
	var cam: Node4D = null
	for c in room.find_children("*", "Camera4D", true, false):
		if bool(c.get("current")):
			cam = c as Node4D
	print("START player %s" % str(player.global_position))
	if cam != null:
		var fwd: Vector4 = -cam.global_basis.z
		print("START camera %s at %s looking %s" % [cam.name, str(cam.global_position), str(fwd)])
	await RenderingServer.frame_post_draw
	var name: String = "start"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		name = args[0]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("START DONE")
	quit(0)
