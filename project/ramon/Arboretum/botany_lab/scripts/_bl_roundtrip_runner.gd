extends SceneTree

## BOTANY LAB, round 8: the way through and back by real scene changes, as in the game (the other runners add a
## room under the root): the hall in dark mode, to the second room (it opens bright), B there, back to the hall
## (dark again, its spots 40% up). Windowed and unfocusable, input off. Frames in smoke_test_output/botany_lab/
## round8/. Saves nothing.

const HALL := "res://ramon/Arboretum/botany_lab.tscn"
const OUT := "res://smoke_test_output/botany_lab/round8/"
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")

var _deadline: int = 0
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_deadline = Time.get_ticks_msec() + 180000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	(func() -> void: _run()).call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("TRIP TIMEOUT")
		quit(2)
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("TRIP PASS " + what)
	else:
		_failed += 1
		print("TRIP FAIL " + what)


func _quiet() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p: Node = current_scene.get("player") if current_scene != null else null
	if p != null:
		p.set("input_enabled", false)


## Waits (bounded) for the current scene to be the one named.
func _arrive(scene_name: String) -> bool:
	for i in 900:
		if current_scene != null and current_scene.name == scene_name and current_scene.is_node_ready():
			return true
		await process_frame
	return false


func _run() -> void:
	change_scene_to_file(HALL)
	_check(await _arrive("BotanyLab"), "the hall opens")
	await _frames(120)
	_quiet()
	current_scene.call("toggle_palette")
	await _frames(5)
	_check(Style.palette == "black", "the hall is in dark mode")
	current_scene.call("to_compare")
	_check(await _arrive("BotanyCompare"), "the second room opens by a scene change")
	for i in 2400:
		if bool(current_scene.call("ready_to_visit")) and current_scene.get("_board") == null:
			break
		await process_frame
	await _frames(30)
	_quiet()
	_check(Style.palette == "grey", "it opens bright")
	root.get_texture().get_image().save_png(OUT + "t01_second_room_from_a_dark_hall.png")
	current_scene.call("toggle_palette")
	await _frames(10)
	_check(Style.palette == "black", "B there makes it dark")
	current_scene.call("toggle_palette")
	await _frames(10)
	current_scene.call("back_to_hall")
	_check(await _arrive("BotanyLab"), "the way back opens the hall")
	await _frames(120)
	_quiet()
	_check(Style.palette == "black", "the hall is dark again, as it was left")
	var lt: Node = current_scene.get_node_or_null("Light04Oak")
	var sl: Node = lt.get("_light") if lt != null else null
	var e: float = float(sl.get("light_energy")) if sl != null else -1.0
	var base: float = float((lt.get("energy") as Dictionary).get(Style.mood, 1.0)) * float(Style.gain.get("spot", 1.0)) if lt != null else -1.0
	_check(absf(e / maxf(base, 0.0001) - 1.4) < 0.01, "its spots are the dark mode's again (x%.3f)" % (e / maxf(base, 0.0001)))
	root.get_texture().get_image().save_png(OUT + "t02_hall_again_dark.png")
	print("TRIP %s: %d passed, %d failed" % ["PASS" if _failed == 0 else "FAIL", _passed, _failed])
	quit(0 if _failed == 0 else 1)
