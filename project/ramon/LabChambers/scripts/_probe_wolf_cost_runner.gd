extends SceneTree

## What the lab's wolf (LabKit/carried/Model/wolf.tscn) costs to animate, before and after: its own
## walker as carried (strider_walker.gd, blend_joints on: rigid pieces plus a band of skin round
## every joint re-posed vertex by vertex each frame), the same walker with blend_joints off, and the
## rigid walk the goat uses (goat_walk_4d.gd: pieces lofted once, transforms only). Vsync off, one
## wolf filling the frame; prints frame time, script time and the walk's own cost, and saves a frame
## of each to res://smoke_test_output/goat_room/wolf_probe/. Its rigid pieces are baked on the way.
##
##   CreationLab/scripts/lab_run.sh windowed wolf_probe res://ramon/LabChambers/scripts/_probe_wolf_cost_runner.gd

const WOLF := "res://ramon/LabKit/carried/Model/wolf.tscn"
const WALK := preload("res://ramon/LabChambers/scripts/goat_walk_4d.gd")
const Mark := preload("res://ramon/LabKit/lab_mark_4d.gd")
const OUT := "res://smoke_test_output/goat_room/wolf_probe/"

var _world: Node4D


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## Averages over `seconds`: whole frame, script process, script physics, and `each` (a Callable run
## every frame, timed) if given.
func _measure(seconds: float, each: Callable = Callable()) -> Dictionary:
	var n: int = 0
	var t0: int = Time.get_ticks_usec()
	var proc: float = 0.0
	var phys: float = 0.0
	var own: float = 0.0
	while Time.get_ticks_usec() - t0 < int(seconds * 1000000.0):
		await process_frame
		if each.is_valid():
			var e0: int = Time.get_ticks_usec()
			each.call()
			own += float(Time.get_ticks_usec() - e0) / 1000.0
		n += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var total: float = float(Time.get_ticks_usec() - t0) / 1000.0
	return {"frame": total / maxf(float(n), 1.0), "process": proc / maxf(float(n), 1.0), "physics": phys / maxf(float(n), 1.0), "own": own / maxf(float(n), 1.0), "frames": n}


func _report(what: String, r: Dictionary) -> void:
	print("%-34s frame %.3f ms (%d frames)   script process %.3f ms   script physics %.3f ms   walk's own %.4f ms" % [what, float(r["frame"]), int(r["frames"]), float(r["process"]), float(r["physics"]), float(r["own"])])


func _shot(nm: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + nm + ".png")


func _wolf(blend: bool, keep_walker: bool) -> Node4D:
	var w: Node4D = (load(WOLF) as PackedScene).instantiate() as Node4D
	var walker: Node = w.get_node_or_null("Walker")
	if walker != null:
		if keep_walker:
			walker.set("blend_joints", blend)
		else:
			w.remove_child(walker)
			walker.free()
	_world.add_child(w)
	return w


func _run() -> void:
	_world = Node4D.new()
	root.add_child(_world)
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	_world.add_child(cam)
	cam.global_position = Vector4(-1.3, 0.75, 1.5, 0.0)
	cam.global_basis = Mark.basis_looking(cam.global_position, Vector4(0.0, 0.45, 0.0, 0.0))
	cam.current = true
	await _wait(1.0)
	_report("empty scene", await _measure(2.0))

	# As carried: its own walker, blend_joints on.
	var a: Node4D = _wolf(true, true)
	var walker: Node = a.get_node("Walker")
	walker.set_physics_process(false)
	await _wait(1.5)
	_report("wolf standing", await _measure(3.0))
	walker.set_physics_process(true)
	await _wait(1.5)
	_report("its walker, blend_joints on", await _measure(4.0))
	await _shot("walker_blend")
	a.free()
	await _wait(0.5)

	# The same walker, the joints hinged instead of blended.
	var b: Node4D = _wolf(false, true)
	await _wait(2.0)
	_report("its walker, blend_joints off", await _measure(4.0))
	await _shot("walker_hinged")
	b.free()
	await _wait(0.5)

	# The rigid walk: pieces lofted once (baked here), transforms only.
	var c: Node4D = _wolf(false, false)
	var rig: MeshInstance4D = c.get_node("Hide")
	rig.set("live_rebuild", false)
	await _wait(0.5)
	var walk := Node4D.new()
	walk.name = "Walk"
	walk.set_script(WALK)
	walk.set("leg_tops", PackedStringArray(["Hip"]))
	walk.set("bake_tag", "wolf_walk")
	walk.set("period", 1.0)
	walk.set("stride", 0.3)
	walk.set("lift", 0.12)
	walk.set("bob", 0.025)
	walk.set("roll", 0.02)
	c.add_child(walk)
	var t_attach: int = Time.get_ticks_usec()
	var ok: bool = bool(walk.call("attach", rig))
	print("rigid pieces ready: %s in %.1f ms" % [str(ok), float(Time.get_ticks_usec() - t_attach) / 1000.0])
	walk.call("set_walking", true)
	var clock := {"t": 0.0, "last": Time.get_ticks_usec()}
	var step := func() -> void:
		var now: int = Time.get_ticks_usec()
		clock["t"] = float(clock["t"]) + float(now - int(clock["last"])) / 1000000.0
		clock["last"] = now
		walk.call("pose", float(clock["t"]))
	await _wait(0.5)
	_report("rigid walk (goat_walk_4d)", await _measure(4.0, step))
	await _shot("rigid")
	walk.call("set_xray", true)
	for i in 30:
		step.call()
		await process_frame
	await _shot("rigid_xray")
	quit(0)
