extends SceneTree

## The dev panel's room diagram (kit_plan_view.gd, F1 ROOM SHAPE) as the Creation Lab wall is
## lengthened, and what the dev tools and the wall panels cost a frame: the whole frame's time,
## vsync off, with the story playing (the engine's TIME_PROCESS monitor read more than a whole frame
## here, so it is not used), for
## (a) the dev panel shut, (b) open, (c) the first walls instead of the panels, (d) no walls at all.
## To res://smoke_test_output/creation_lab/dev_panel/.
##
##   CreationLab/scripts/lab_run.sh windowed dev_panel res://ramon/CreationLab/scripts/_capture_dev_panel_runner.gd

const SCENE := "res://ramon/CreationLab/creation_lab.tscn"
const OUT := "res://smoke_test_output/creation_lab/dev_panel/"

var _g: Node
var _fails: Array = []


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


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _shot(what: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


## Average frame time over `secs`, ms.
func _measure(what: String, secs: float) -> float:
	await _wait(1.0)
	var n: int = 0
	var t0: int = Time.get_ticks_usec()
	var until: int = Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		n += 1
	var frame_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(maxi(n, 1))
	print("%-28s frame %.3f ms, %.0f fps (%d frames)" % [what, frame_ms, 1000.0 / frame_ms, n])
	return frame_ms


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(5.0)
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(0.0, 0.05, 5.5, 0.0)
	var sc: Node = _g.get_node("Showcase")
	sc.call("replay")
	var tuner: Control = _g.get("tuner")
	tuner.visible = false
	var a: float = await _measure("(a) panels, dev panel shut", 6.0)
	tuner.visible = true
	var b: float = await _measure("(b) panels, dev panel open", 6.0)
	tuner.visible = false
	_g.set("walls", "first")
	var c: float = await _measure("(c) the first walls", 6.0)
	_g.set("walls", "panels")
	await _wait(1.0)
	for nm in ["IntroPanel", "ResearchBoard", "IntroPanelCopy", "ResearchBoardCopy"]:
		_g.get_node(nm).set("enabled", false)
	var d: float = await _measure("(d) no walls at all", 6.0)
	print("the panels cost %.3f ms a frame, the first walls %.3f ms, the open dev panel %.3f ms" % [a - d, c - d, b - a])
	for nm in ["IntroPanel", "ResearchBoard", "IntroPanelCopy", "ResearchBoardCopy"]:
		_g.get_node(nm).set("enabled", true)
	await _wait(1.5)
	# The diagram: the dev panel open, scrolled to ROOM SHAPE.
	tuner.visible = true
	var scroll: ScrollContainer = tuner.get("_scroll")
	await _wait(0.5)
	scroll.scroll_vertical = 100000
	await _wait(0.5)
	await _shot("dev_panel_plan_saved")
	_g.set("creation_wall_length", float(_g.get("creation_wall_length")) + 2.0)
	await _wait(1.5)
	scroll.scroll_vertical = 100000
	await _wait(0.3)
	await _shot("dev_panel_plan_longer")
	var pv: Control = null
	for ch in tuner.find_children("*", "Control", true, false):
		if ch.get_script() != null and String((ch.get_script() as Script).resource_path).ends_with("kit_plan_view.gd"):
			pv = ch
	_check(pv != null and pv.size.x > 100.0, "the room diagram is in the dev panel")
	print("DEV PANEL %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
