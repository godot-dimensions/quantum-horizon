extends SceneTree

## Do the grass and the leaves stay on the farm when you go through a door? The pen switches the
## farm off on a trip (pen_crossing_4d.gd hides and disables World and the rest), but the grass
## and the leaves are RenderingServer instances, not nodes under it. This goes into the theatre
## (Crossing) and then the cave (CaveCrossing) and prints whether either is still drawn there,
## with a frame of each. Gives up after 120 s. Saves res://smoke_test_output/crossing_<where>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/grass/_crossing_grass_runner.gd

var _room: Node
var _grass: Node
var _t: float = 0.0
var _step: int = -1
var _wait: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_crossing_test.cfg")
	_grass = _room.get_node("World/Grass")
	root.add_child(_room)
	current_scene = _room


func _drawn() -> String:
	# There is no getter for an instance's visibility, so this says what the node knows; the
	# frame says what is drawn.
	var panel := _room.get_node_or_null("UI/GrassPanel") as CanvasItem
	return "World visible %s, grass node visible in tree %s, leaves up %d, grass panel %s" % [
		(_room.get_node("World") as Node4D).visible, _grass.is_visible_in_tree(), int(_grass.call("bits_count")),
		"shown" if panel != null and panel.visible else "hidden"]


func _process(d: float) -> bool:
	_t += d
	if _t > 120.0:
		print("CROSSING FAIL: timed out at step %d" % _step)
		return true
	_wait -= d
	if _wait > 0.0:
		return false
	match _step:
		-1:
			if not bool(_grass.get("mask_ready")) or _t < 6.0:
				return false
			print("      on the farm:      ", _drawn())
			root.get_texture().get_image().save_png("res://smoke_test_output/crossing_0_farm.png")
			_room.get_node("Crossing").call("go_for_testing")
			_step = 0
			_wait = 4.0
		0:
			print("      in the theatre:   ", _drawn())
			root.get_texture().get_image().save_png("res://smoke_test_output/crossing_1_theatre.png")
			_room.get_node("Crossing").call("come_back")
			_step = 1
			_wait = 3.0
		1:
			print("      back on the farm: ", _drawn())
			var cave: Node = _room.get_node_or_null("CaveCrossing")
			if cave != null and cave.has_method("go_for_testing"):
				cave.call("go_for_testing")
			_step = 2
			_wait = 5.0
		2:
			print("      in the cave:      ", _drawn())
			root.get_texture().get_image().save_png("res://smoke_test_output/crossing_2_cave.png")
			print("CROSSING DONE")
			if FileAccess.file_exists("user://lookout_journal_crossing_test.cfg"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_crossing_test.cfg"))
			return true
	return false
