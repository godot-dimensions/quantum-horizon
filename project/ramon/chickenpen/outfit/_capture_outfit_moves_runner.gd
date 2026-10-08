extends SceneTree

## THE OUTFIT IN MOTION (outfit/PLAN_OUTFIT.md step 33): each hat worn while walking, carrying a
## chicken and being knocked over, seen from the side, so a hat that clips or falls behind shows up in
## a frame rather than in Ramon's play. Frames to smoke_test_output/outfit/moves/. Never touches his
## saved outfit (a test file of its own), and the window takes no real input.
##
##   lab_run.sh windowed outfit_moves res://ramon/chickenpen/outfit/_capture_outfit_moves_runner.gd

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const OUT := "res://smoke_test_output/outfit/moves/"
const TEST_SAVE := "user://outfit_test_moves.cfg"
const SPOT := Vector4(10.0, 0.0, 26.0, 0.0)

var _room: Node
var _player: CharacterBody4D
var _rig: Node4D
var _t0: int = 0


class Guard extends Node:
	func _input(event: InputEvent) -> void:
		if event is InputEventKey or event is InputEventMouse:
			get_viewport().set_input_as_handled()


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 180000:
		print("MOVES FAIL: gave up after 180 s")
		return true
	return false


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	var path: String = OUT + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("FRAME %s" % path)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Outfit.use_save_path(TEST_SAVE)
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout != null:
		lookout.set("journal_path", "user://outfit_test_journal.cfg")
	root.add_child(_room)
	current_scene = _room
	root.add_child(Guard.new())
	await _wait(2.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var ui: Node = _room.get_node_or_null("UI")
	for c in ui.get_children():
		if String(c.name) in ["GrassPanel", "PathsPanel"]:
			c.process_mode = Node.PROCESS_MODE_DISABLED
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	_player = _room.get_node("Player") as CharacterBody4D
	_rig = _player.get_node("CameraRig") as Node4D
	var catcher: Node = _player.get_node("Catcher")
	var chickens: Node = _room.get_node("Chickens")
	var hats: Array = [[Outfit.HAT_TOP, "top_hat"], [Outfit.HAT_CHICKEN, "chicken"], [Outfit.HAT_HYPERCUBE, "hypercube"], [Outfit.HAT_BEANIE, "beanie"]]
	for h in hats:
		Outfit.restore({"hat": h[0], "hat_colour": 7, "hair": 4, "skin": 3, "shirt": 5, "legs": 1, "trousers": 8, "shoes": 10})
		_player.set("input_enabled", false)
		_player.global_position = Vector4(SPOT.x, _player.global_position.y, SPOT.z, 0.0)
		_player.linear_velocity = Vector4.ZERO
		# Side on: the camera looks east at a player facing north.
		_player.set("_facing", PI)
		SliceAngles.tilt(_rig, 0.0, 0.0, -PI / 2.0)
		_rig.set("pitch", deg_to_rad(-6.0))
		_rig.set("distance", 3.2)
		_rig.set("_zoom_target", 3.2)
		_rig.call("_apply")
		await _wait(0.8)
		await _shot("%s_1_stand" % h[1])
		# A chicken in your arms.
		var bird: Node4D = null
		for c in chickens.find_children("*", "Node4D", true, false):
			if c.has_method("on_caught"):
				bird = c
				break
		if bird != null and catcher.has_method("_catch"):
			bird.global_position = _player.global_position + Vector4(0.0, 0.0, -0.8, 0.0)
			await _wait(0.1)
			catcher.call("_catch", bird)
			await _wait(0.8)
			await _shot("%s_2_carry" % h[1])
			if catcher.has_method("_release"):
				catcher.call("_release", false)
			await _wait(0.5)
		# Walking, held on the key for a second.
		_player.set("input_enabled", true)
		Input.action_press(&"move_left")
		await _wait(0.55)
		await _shot("%s_3_walk" % h[1])
		Input.action_release(&"move_left")
		_player.set("input_enabled", false)
		await _wait(0.4)
		_player.call("knock_down", 1.2)
		await _wait(0.35)
		await _shot("%s_4_down" % h[1])
		await _wait(1.4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://outfit_test_journal.cfg"))
	print("MOVES DONE")
	quit(0)
