extends SceneTree

## What the projection (P) costs (Ramon, 3 Oct: "when using projection, the scene gets laggier,
## why is that"): from the spawn, the projection on for a block and off for the next, ABBA, eight
## times over, vsync off, the first half second of each block thrown away. Per block: frames, the
## scripts, and the render time on the CPU and the GPU. Then the same with the grass hidden, and
## with the ground hidden, to see what the projection pass spends its time on.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_measure_projection_runner.gd

const BLOCK := 2.2
const CYCLES := 3
const ORDER := [true, false, false, true]
const CASES := ["as it is", "grass hidden", "ground hidden"]
## Gives up after this, printing what it has.
const LIMIT := 170.0

var _room: Node
var _lookout: Node
var _t: float = 0.0
var _started: bool = false
var _case: int = 0
var _block: int = 0
var _rows: Dictionary = {}


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _set_case() -> void:
	(_room.get_node("World/Grass") as Node4D).visible = _case != 1
	var ground := _room.get_node_or_null("World/Ground/GroundMesh") as Node4D
	if ground != null:
		ground.visible = _case != 2
	_rows = {true: [], false: []}


var _all: float = 0.0
var _frames: int = 0


func _process(d: float) -> bool:
	_t += d
	_all += d
	_frames += 1
	if _all > LIMIT:
		print("PROJECTION FAIL: timed out at case %d block %d (%d frames in all)" % [_case, _block, _frames])
		if _started:
			_report()
		return true
	if not _started:
		var grass: Node = _room.get_node_or_null("World/Grass")
		if (grass != null and not bool(grass.get("mask_ready"))) or _t < 8.0:
			return false
		_lookout = _room.get_node("Systems/Lookout")
		for c in _room.get_node("UI").get_children():
			if c is CanvasItem:
				(c as CanvasItem).visible = false
		_started = true
		_set_case()
		_t = 0.0
		return false
	var on: bool = ORDER[_block % ORDER.size()]
	if bool(_lookout.get("projection")) != on:
		_lookout.call("set_projection", on)
	if _t > 0.5:
		var vp: RID = root.get_viewport_rid()
		(_rows[on] as Array).append([d * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp)])
	if _t >= BLOCK:
		print("      block %d (%s) done: %d frames so far, projection %s" % [_block, CASES[_case], _frames, "on" if on else "off"])
		_t = 0.0
		_block += 1
		if _block >= CYCLES * ORDER.size():
			_report()
			_block = 0
			_case += 1
			if _case >= CASES.size():
				_lookout.call("set_projection", false)
				print("PROJECTION DONE")
				return true
			_set_case()
	return false


func _mean(rows: Array, column: int) -> float:
	var sum: float = 0.0
	for r in rows:
		sum += float(r[column])
	return sum / maxf(float(rows.size()), 1.0)


func _report() -> void:
	print("   --- %s ---" % CASES[_case])
	var names := ["frame", "scripts", "render cpu", "render gpu"]
	print("      %-11s %8s %8s %8s" % ["ms", "P on", "P off", "cost"])
	for c in 4:
		var a: float = _mean(_rows[true], c)
		var b: float = _mean(_rows[false], c)
		print("      %-11s %8.2f %8.2f %+8.2f" % [names[c], a, b, a - b])
