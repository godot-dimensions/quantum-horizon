extends SceneTree

## What the creature hall's frame costs, and who costs it: the script time (Performance TIME_PROCESS +
## TIME_PHYSICS_PROCESS, follow_up: the monitors, never wall clock in a headless run), then each kind of
## station switched off in turn (process_mode DISABLED) and what that saves.
##
##   CreationLab/scripts/lab_run.sh headless hall_perf res://ramon/CreationLab/hall/_perf_hall_runner.gd

const HALL := "res://ramon/CreationLab/hall/creature_hall.tscn"

var _g: Node


func _initialize() -> void:
	# Timings with vsync on are noise (follow_up/lofting_gotchas.md): a frame is a 60 Hz beat or a missed one.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


## (whole frame ms by the wall clock, vsync off; script process ms by the monitor) over `n` frames.
func _frames(n: int) -> Vector2:
	var p: float = 0.0
	await process_frame
	var t0: int = Time.get_ticks_usec()
	for i in n:
		await process_frame
		p += Performance.get_monitor(Performance.TIME_PROCESS)
	return Vector2(float(Time.get_ticks_usec() - t0) / 1000.0 / float(n), p / float(n) * 1000.0)


func _run() -> void:
	change_scene_to_file(HALL)
	var until: int = Time.get_ticks_msec() + 75000
	while Time.get_ticks_msec() < until and (current_scene == null or current_scene.scene_file_path != HALL or bool(current_scene.get("loading"))):
		await process_frame
	_g = current_scene
	if _g == null or bool(_g.get("loading")):
		print("FAIL the hall never finished loading")
		quit(1)
		return
	root.unfocusable = true
	var p: Node = _g.get("player")
	if p != null:
		p.set("input_enabled", false)
		# Where the frames are watched from: the middle, looking at the centre (most of the hall in view).
		p.global_position = Vector4(0.0, 0.05, 3.5, 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Settling: the first seconds after the board are the walkers' bindings and the leaves growing.
	for k in 6:
		var s: Vector2 = await _frames(120)
		print("settle %d  frame %6.2f ms  process %6.2f ms" % [k, s.x, s.y])
	var base: Vector2 = await _frames(120)
	print("ALL      frame %6.2f ms  process %6.2f ms" % [base.x, base.y])
	var kinds: Dictionary = {}
	for st in _g.get("stations"):
		kinds[String(st["data"]["kind"])] = true
	for kind in kinds:
		var nodes: Array = []
		for st in _g.get("stations"):
			if String(st["data"]["kind"]) == kind:
				nodes.append(st["node"])
		for n in nodes:
			n.process_mode = Node.PROCESS_MODE_DISABLED
		for i in 20:
			await process_frame
		var off: Vector2 = await _frames(60)
		print("%-8s saves frame %6.2f ms  process %6.2f ms  (%d station%s)" % [kind, base.x - off.x, base.y - off.y, nodes.size(), "" if nodes.size() == 1 else "s"])
		for n in nodes:
			n.process_mode = Node.PROCESS_MODE_INHERIT
		for i in 20:
			await process_frame
	# Everything but the stations: the room, the paths, the player, the HUD.
	for st in _g.get("stations"):
		st["node"].process_mode = Node.PROCESS_MODE_DISABLED
	for i in 20:
		await process_frame
	var rest: Vector2 = await _frames(60)
	print("NO STATIONS frame %6.2f ms  process %6.2f ms" % [rest.x, rest.y])
	quit(0)
