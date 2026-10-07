extends SceneTree

## THE PROJECTION IN THE ART LOOK, A AGAINST B (Ramon, 7 Oct: "turning projection on gives some really weird artifacts
## that obscure my whole screen, see ref shot. oddly it doesnt happen in dev mode", at 7 fps). The pen in the art look,
## from the spawn and from beside the camp a little kata (where his shot was), the projection on and off in turn, vsync
## off, for each of:
##   terrain in       as it was: the ground and the hills projected too (lookout_4d.gd terrain_in_projection)
##   terrain out      as it is now
##   plants out too   the placed trees and bushes out of the projection as well, to see what they cost
## Per case: the frame time and the GPU's render time with it on and with it off, and a frame with it on, to
## res://smoke_test_output/projection_ab/. A test journal, never Ramon's.
##
##   lab_run.sh windowed proj_ab res://ramon/chickenpen/lookout/_projection_ab_runner.gd look=art

const OUT := "res://smoke_test_output/projection_ab/"
const BLOCK := 2.0
const CASES := ["terrain in", "terrain out", "plants out too"]
const SPOTS := [[Vector4(24.9, 0.0, 19.1, 0.0), "spawn"], [Vector4(8.0, 0.0, -2.0, -1.66), "camp"]]

var _room: Node
var _lookout: Node
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	_lookout = _room.get_node("Systems/Lookout")
	_lookout.set("journal_path", "user://projection_ab_journal.cfg")
	root.add_child(_room)
	current_scene = _room
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 170000:
		print("PROJECTION AB: gave up after 170 s")
		return true
	return false


func _wait(s: float) -> void:
	await create_timer(s).timeout


## Frames for [param s] seconds: [mean frame ms, mean GPU ms], the first quarter second thrown away.
func _measure(s: float) -> Array:
	await _wait(0.25)
	var frames: int = 0
	var gpu: float = 0.0
	var start: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(s * 1000000.0):
		await process_frame
		frames += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	var ms: float = float(Time.get_ticks_usec() - start) / 1000.0 / maxf(float(frames), 1.0)
	return [ms, gpu / maxf(float(frames), 1.0)]


func _plants(on: bool) -> void:
	for path in ["World/Trees", "World/LookoutSite/Oak"]:
		var n: Node = _room.get_node_or_null(path)
		if n == null:
			continue
		for mi in n.find_children("*", "MeshInstance4D", true, false):
			if not (mi as Node).has_meta(&"w_copy_mesh"):
				(mi as MeshInstance4D).allow_projection = on


func _run() -> void:
	await _wait(8.0)
	var player := _room.get_node("Player") as CharacterBody4D
	player.set("input_enabled", false)
	# No HUD in the frames: the picture is what is being judged.
	for c in _room.get_node("UI").get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	for spot in SPOTS:
		player.global_position = spot[0]
		player.set("linear_velocity", Vector4.ZERO)
		await _wait(1.0)
		for c in CASES.size():
			_lookout.set("terrain_in_projection", c == 0)
			_plants(c != 2)
			_lookout.call("set_projection", true)
			var on: Array = await _measure(BLOCK)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%d_%s.png" % [spot[1], c, String(CASES[c]).replace(" ", "_")]))
			_lookout.call("set_projection", false)
			var off: Array = await _measure(BLOCK)
			print("PROJECTION AB %-6s %-15s on %6.1f ms (GPU %5.1f)   off %6.1f ms (GPU %5.1f)" % [spot[1], CASES[c], on[0], on[1], off[0], off[1]])
	_lookout.set("terrain_in_projection", false)
	_plants(true)
	print("PROJECTION AB: done")
	quit(0)
