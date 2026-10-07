extends SceneTree

## THE CAVE, TWICE (Ramon, 7 Oct: "when spawning to the cave i think its better the slice is reset again ... insdie
## the cave its very bright, it was dark. like the environment settings from the pen scene carried over"). The pen
## in the look it opens in (dev, or look=art), the slice turned 20 degrees, Shift+C into the cave (the cave
## crossing's own key, go_for_testing): which environment is current, how tilted the slice is, a frame; home again;
## and the same a second time (the kept cave, put back in the tree, is where its sky used to be lost).
##
##   lab_run.sh windowed probe_cave res://ramon/chickenpen/scripts/_probe_cave_visits_runner.gd [look=art]

const OUT := "res://smoke_test_output/cave_probe/"

var _room: Node
var _tag: String = "dev"


func _initialize() -> void:
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		if a == "look=art":
			_tag = "art"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://probe_cave_journal.cfg")
	root.add_child(_room)
	current_scene = _room
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [_tag, nm]))


func _report(when: String, crossing: Node) -> void:
	var cave: Node = crossing.get("_theatre")
	var envs: PackedStringArray = []
	for env in _room.find_children("*", "WorldEnvironment4D", true, false):
		envs.append("%s current %s" % [str(_room.get_path_to(env)), str(env.get("current"))])
	var rig := _room.get_node("Player/CameraRig") as Node4D
	print("CAVE %s %s: away %s, slice tilt %.1f deg, player at %s | %s" % [_tag, when, str(crossing.call("is_away")),
		rad_to_deg(GroundBasis4D.tilt(rig.basis)), str((_room.get_node("Player") as Node4D).global_position.snapped(Vector4.ONE * 0.01)),
		", ".join(envs)])


func _run() -> void:
	await _wait(6.0)
	(_room.get_node("Player") as Node).set("input_enabled", false)
	var crossing: Node = _room.get_node("CaveCrossing")
	var rig: Node = _room.get_node("Player/CameraRig")
	for visit in [1, 2]:
		rig.call("drag_slice", Vector2(0.35, 0.0))
		await _wait(0.4)
		_report("visit %d, before" % visit, crossing)
		crossing.call("go_for_testing")
		await _wait(2.5)
		_report("visit %d, inside" % visit, crossing)
		await _shot("visit%d_inside" % visit)
		crossing.call("come_back")
		await _wait(2.0)
		_report("visit %d, home" % visit, crossing)
		await _shot("visit%d_home" % visit)
	print("CAVE %s: done" % _tag)
	quit(0)
