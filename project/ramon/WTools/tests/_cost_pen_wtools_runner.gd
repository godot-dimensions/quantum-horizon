extends SceneTree

## WHAT THE W TOOLS COST THE PEN'S CPU (WTools/PLAN.md step 95). Frame time is too noisy to tell a few
## tenths of a millisecond (follow_up: headless frame pacing), so this reads the engine's own process and
## physics time (medians of 240 frames) from the start, flat and with the slice turned 30 degrees, with the
## W tools as they are, the Exploder off, and the Optimisers off. The art look.
##
##   PEN_LOOK=art lab_run.sh windowed wt_pen_cost res://ramon/WTools/tests/_cost_pen_wtools_runner.gd

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const START := Vector4(24.9, 1.2, 19.1, 0.0)
const SETUPS := {
	"as is": [],
	"no exploder": ["World/Trees"],
	"no optimisers": ["World/WatchstoneW", "World/RangeW"],
	"copies hollow": ["World/Trees:copies_solid=false"],
}

var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 600000:
		print("COST: gave up")
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for setup in SETUPS:
		var room: Node = (load(PEN) as PackedScene).instantiate()
		for path in SETUPS[setup]:
			# "path" switches it off; "path:property=value" sets that.
			if String(path).contains(":"):
				var what: String = String(path).get_slice(":", 1)
				room.get_node(String(path).get_slice(":", 0)).set(what.get_slice("=", 0), str_to_var(what.get_slice("=", 1)))
			else:
				room.get_node(path).set("enabled", false)
		root.add_child(room)
		current_scene = room
		await _frames(240)
		var player := room.get_node("Player") as CharacterBody4D
		player.set("input_enabled", false)
		var rig := player.get_node("CameraRig") as Node4D
		for turn in [0.0, 30.0]:
			player.global_position = START
			if "_slice_zw" in rig:
				rig.set("_slice_zw", deg_to_rad(turn))
				rig.call("_apply")
			await _frames(30)
			var proc: Array = []
			var phys: Array = []
			for i in 240:
				await process_frame
				proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
				phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			proc.sort()
			phys.sort()
			print("COST %-14s turned %2d: process %.2f ms, physics %.2f ms" % [setup, int(turn), proc[120], phys[120]])
		root.remove_child(room)
		room.free()
		await _frames(10)
	print("COST DONE")
	quit(0)
