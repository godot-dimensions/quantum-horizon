extends SceneTree

## What the black cat's bent joints cost (strider_walker.gd blend_joints, 3 Oct): the cat kept
## walking near the player, its joint skin posed for a block and frozen for the next, ABBA, eight
## times over, the first half second of each block thrown away. Per block: the physics step (where
## the posing runs), the scripts, and the frame's render time on the CPU and the GPU (where the
## renderer rebuilds what was handed back). Vsync off.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/scripts/_measure_cat_joints_runner.gd

const BLOCK := 2.7
const CYCLES := 8
const ORDER := [true, false, false, true]

var _room: Node
var _cat: Node4D
var _walker: Node
var _player: Node4D
var _t: float = 0.0
var _started: bool = false
var _block: int = 0
var _rows: Dictionary = {true: [], false: []}


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _process(d: float) -> bool:
	_t += d
	if not _started:
		var grass: Node = _room.get_node_or_null("World/Grass")
		if (grass != null and not bool(grass.get("mask_ready"))) or _t < 8.0:
			return false
		_cat = _room.get_node("World/Cat") as Node4D
		_walker = _cat.get_node("Walker")
		_player = _room.get_node("Player") as Node4D
		_started = true
		_t = 0.0
		return false
	# Kept walking, a few metres in front of the player.
	_cat.set("_mood", 0)
	_cat.set("_mood_left", 100.0)
	_player.global_position = _cat.global_position + Vector4(0.0, 0.05, -3.0, 0.0)
	var on: bool = ORDER[_block % ORDER.size()]
	_walker.set("blend_joints", on)
	if _t > 0.5:
		var vp: RID = root.get_viewport_rid()
		(_rows[on] as Array).append([Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp)])
	if _t >= BLOCK:
		_t = 0.0
		_block += 1
		if _block >= CYCLES * ORDER.size():
			_report()
			return true
	return false


func _mean(rows: Array, column: int) -> float:
	var sum: float = 0.0
	for r in rows:
		sum += float(r[column])
	return sum / maxf(float(rows.size()), 1.0)


func _report() -> void:
	var names := ["physics", "scripts", "render cpu", "render gpu"]
	print("      %-11s %8s %8s %8s" % ["ms", "posed", "frozen", "cost"])
	for c in 4:
		var a: float = _mean(_rows[true], c)
		var b: float = _mean(_rows[false], c)
		print("      %-11s %8.3f %8.3f %+8.3f" % [names[c], a, b, a - b])
	var cells: Array = []
	for j in _walker.get("_joints"):
		cells.append(0 if j == null else (j["mesh"] as ArrayTetraMesh4D).simplex_cell_vertex_indices.size() / 4)
	print("      joint meshes, cells each: %s" % str(cells))
	print("CAT JOINTS DONE (%d and %d frames)" % [(_rows[true] as Array).size(), (_rows[false] as Array).size()])
