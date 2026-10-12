extends SceneTree

## WHAT THE OUTFIT COSTS (outfit/PLAN_OUTFIT.md steps 27, 31 and 68), measured, vsync off
## (lofting_gotchas.md: vsync makes every frame timing meaningless), windowed (headless renders nothing):
##   - the wearer's and the circle's own work per frame, timed by calling them directly a few thousand
##     times (one frame's noise is bigger than either);
##   - a hat change that takes the cap off: the figure rebuilt, repainted and the hat hung, in one go;
##   - whole frames and GPU time with the circle drawn and hidden, alternated in blocks so drift
##     cancels, at the circle, standing ready and while dressing.
##
##   lab_run.sh windowed outfit_perf res://ramon/chickenpen/outfit/_perf_outfit_runner.gd

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")
const Keeper := preload("res://ramon/chickenpen/outfit/outfit_keeper_4d.gd")
const TEST_SAVE := "user://outfit_test_perf.cfg"
const BLOCK := 40
const BLOCKS := 6

var _room: Node
var _t0: int = 0


class Guard extends Node:
	func _input(event: InputEvent) -> void:
		if event is InputEventKey or event is InputEventMouse:
			get_viewport().set_input_as_handled()


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 180000:
		print("PERF FAIL: gave up after 180 s")
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Outfit.use_save_path(TEST_SAVE)
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout != null:
		lookout.set("journal_path", "user://outfit_test_journal.cfg")
	root.add_child(_room)
	current_scene = _room
	root.add_child(Guard.new())
	await _frames(150)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var player := _room.get_node("Player") as CharacterBody4D
	player.set("input_enabled", false)
	var circle := _room.get_node("World/OutfitCircle") as Node4D
	var keeper: Node = root.get_node(NodePath(String(Keeper.NAME)))
	var avatar: Node = player.get_node("Avatar")
	var wearer: Node = keeper.call("wearer_for", avatar)

	print("\n--- per frame, called directly ---")
	var n: int = 5000
	var t: int = Time.get_ticks_usec()
	for i in n:
		wearer.call("_process", 0.016)
	print("PERF wearer, nothing changed: %.2f us a frame" % (float(Time.get_ticks_usec() - t) / n))
	player.global_position = Vector4(60.0, player.global_position.y, 0.0, 0.0)
	await _frames(10)
	t = Time.get_ticks_usec()
	for i in n:
		circle.call("_process", 0.0)
	print("PERF circle, you far away: %.2f us a frame" % (float(Time.get_ticks_usec() - t) / n))
	player.global_position = circle.global_position + Vector4(-2.5, 0.0, 0.0, 0.0)
	await _frames(120)
	t = Time.get_ticks_usec()
	for i in n:
		circle.call("_process", 0.0)
	print("PERF circle, up and ready: %.2f us a frame" % (float(Time.get_ticks_usec() - t) / n))

	print("\n--- a hat that takes the cap off ---")
	var costs: Array[float] = []
	for hat in [Outfit.HAT_TOP, Outfit.HAT_CAP, Outfit.HAT_CHICKEN, Outfit.HAT_CAP, Outfit.HAT_HYPERCUBE, Outfit.HAT_CAP]:
		Outfit.set_value("hat", hat)
		t = Time.get_ticks_usec()
		wearer.call("_dress")
		costs.append(float(Time.get_ticks_usec() - t) / 1000.0)
		await _frames(5)
	print("PERF rebuild, repaint and hang the hat: %s ms" % ", ".join(costs.map(func(c: float) -> String: return "%.2f" % c)))
	Outfit.set_value("shirt", 4)
	t = Time.get_ticks_usec()
	wearer.call("_dress")
	print("PERF a colour change (repaint only): %.3f ms" % (float(Time.get_ticks_usec() - t) / 1000.0))

	print("\n--- whole frames: the circle drawn and hidden, alternated ---")
	await _blocks("ready", circle)
	player.set("input_enabled", true)
	player.global_position = circle.global_position
	await _frames(30)
	circle.call("begin")
	await _frames(210)
	print("PERF state now %d (3 = dressing)" % int(circle.get("state")))
	await _blocks("dressing", circle)
	circle.call("done")
	await _frames(60)
	player.set("input_enabled", false)
	player.global_position = Vector4(60.0, player.global_position.y, 0.0, 0.0)
	await _frames(120)
	await _blocks("far", circle)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://outfit_test_journal.cfg"))
	print("PERF DONE")
	quit(0)


## Frame and GPU medians with the circle shown and hidden, in alternating blocks.
func _blocks(label: String, circle: Node4D) -> void:
	var shown: Array[float] = []
	var hidden: Array[float] = []
	var gpu_shown: Array[float] = []
	var gpu_hidden: Array[float] = []
	var strips: Node4D = circle.get_node_or_null("Strips") as Node4D
	for b in BLOCKS:
		var on: bool = b % 2 == 0
		circle.visible = on
		await _frames(6)
		var last: int = Time.get_ticks_usec()
		for f in BLOCK:
			await process_frame
			var now: int = Time.get_ticks_usec()
			var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			(shown if on else hidden).append(float(now - last) / 1000.0)
			(gpu_shown if on else gpu_hidden).append(gpu)
			last = now
	circle.visible = true
	print("PERF %-9s frame %.2f ms shown, %.2f hidden;  GPU %.2f ms shown, %.2f hidden%s" % [label, _median(shown), _median(hidden),
		_median(gpu_shown), _median(gpu_hidden), "  (strips up)" if strips != null else ""])


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var v: Array[float] = values.duplicate()
	v.sort()
	return v[v.size() / 2]
