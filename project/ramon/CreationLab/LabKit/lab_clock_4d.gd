extends Node

## The lab clock: exact pause, slow motion and frame stepping for any creature, whatever drives
## it, without touching its scripts.
##
## THE PROBLEM. The creatures run on six different drivers (the strider and its gait clock, the
## chicken walker, Trym's six solvers and eight IK chains, the birds' own _process loops, the
## dreamer, the people's gait), each stepping on the delta it is handed. None has a time scale of
## its own, and Engine.time_scale would slow the camera, the HUD's easing and the player too.
##
## THE APPROACH. `adopt(root)` takes over the processing of root's whole subtree: every node that
## was physics-processing or processing is switched off, remembered in the order Godot would
## have run it (process priority first, then tree order), and stepped from here instead, with
## its own delta times this root's `scale` times the clock's `time_scale`. Pausing is not
## stepping; a frame step is one step of 1/60 s. Because the nodes are stepped in Godot's own
## order, a gait clock still runs before its walker, and Trym's head attention still runs before
## his gait driver before his IK chains (their priorities are -3 ... 2).
##
## LIMITS, written down rather than discovered later:
## - Engine-side integration does not slow: CharacterBody4D.move_and_slide() reads the engine's
##   own physics delta. Rigs keep creatures in place, so nothing here relies on it.
## - A node that turns its own processing back on later escapes until the next re-scan
##   (`rescan_seconds`), which switches it off again and adopts it.
## - Anything animated from wall-clock time (Time.get_ticks_msec) is not slowed. None of the
##   current creatures does that.
##
## IT ALSO MEASURES. Every root's stepping is timed (microseconds of script work, physics and
## process together), so the lab can print what each animal costs to animate, one animal at a
## time, in a single run: `cost_ms(root)`.
##
## Rigs find the clock through the group "lab_clock". NO class_name (engine_gotchas.md).

const GROUP := "lab_clock"
const FRAME := 1.0 / 60.0

## Multiplies every adopted root's own scale: the whole lab in slow motion.
@export_range(0.0, 2.0, 0.01) var time_scale: float = 1.0
## Stops every adopted root.
@export var paused: bool = false
## How often each root's subtree is scanned again for nodes that started processing.
@export_range(0.25, 10.0, 0.25) var rescan_seconds: float = 2.0

## root instance id -> {root, scale, paused, physics: Array[Node], process: Array[Node], pstep: int, fstep: int}
var _roots: Dictionary = {}
var _rescan_t: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


## The clock in the tree, or null.
static func find(from: Node) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group(GROUP)


## Takes over `root`'s subtree. Call it once the creature has finished building (a frame after
## it entered the tree is safe: strider pieces, cat walkers and bird parts all exist by then).
func adopt(root: Node, scale: float = 1.0) -> void:
	if root == null:
		return
	var id: int = root.get_instance_id()
	var entry: Dictionary = _roots.get(id, {"root": root, "scale": scale, "paused": false, "physics": [], "process": [], "pstep": 0, "fstep": 0, "pusec": 0, "pticks": 0, "fusec": 0, "fticks": 0})
	entry["scale"] = scale
	_roots[id] = entry
	_scan(entry)


## Gives the subtree its own processing back.
func release(root: Node) -> void:
	var id: int = root.get_instance_id()
	if not _roots.has(id):
		return
	var entry: Dictionary = _roots[id]
	for n in entry["physics"]:
		if is_instance_valid(n):
			n.set_physics_process(true)
	for n in entry["process"]:
		if is_instance_valid(n):
			n.set_process(true)
	_roots.erase(id)


func set_root_scale(root: Node, scale: float) -> void:
	var id: int = root.get_instance_id()
	if _roots.has(id):
		_roots[id]["scale"] = scale


func get_root_scale(root: Node) -> float:
	var id: int = root.get_instance_id()
	return float(_roots[id]["scale"]) if _roots.has(id) else 1.0


func set_root_paused(root: Node, on: bool) -> void:
	var id: int = root.get_instance_id()
	if _roots.has(id):
		_roots[id]["paused"] = on


func is_root_paused(root: Node) -> bool:
	var id: int = root.get_instance_id()
	return bool(_roots[id]["paused"]) if _roots.has(id) else false


## Advances one root by one frame (1/60 s of its own time), whatever its pause state: the frame
## step for a paused creature. The step runs on the next physics and process ticks.
func step_root(root: Node, frames: int = 1) -> void:
	var id: int = root.get_instance_id()
	if _roots.has(id):
		_roots[id]["pstep"] = int(_roots[id]["pstep"]) + frames
		_roots[id]["fstep"] = int(_roots[id]["fstep"]) + frames


func is_adopted(root: Node) -> bool:
	return _roots.has(root.get_instance_id())


## Milliseconds of script work this root's animal costs: its physics step per physics tick plus
## its process step per frame (a frame at 60 fps carries one of each), or -1 if not adopted.
## Physics and frames are counted apart: with vsync off a frame is far shorter than a tick.
func cost_ms(root: Node) -> float:
	var id: int = root.get_instance_id()
	if not _roots.has(id):
		return -1.0
	var e: Dictionary = _roots[id]
	return float(e["pusec"]) / 1000.0 / maxf(float(e["pticks"]), 1.0) + float(e["fusec"]) / 1000.0 / maxf(float(e["fticks"]), 1.0)


func reset_costs() -> void:
	for id in _roots:
		for k in ["pusec", "pticks", "fusec", "fticks"]:
			_roots[id][k] = 0


func _scan(entry: Dictionary) -> void:
	var root: Node = entry["root"]
	if not is_instance_valid(root):
		return
	var phys: Array = entry["physics"]
	var proc: Array = entry["process"]
	var found_phys: Array = []
	var found_proc: Array = []
	_collect(root, found_phys, found_proc)
	for n in found_phys:
		n.set_physics_process(false)
		if not phys.has(n):
			phys.append(n)
	for n in found_proc:
		n.set_process(false)
		if not proc.has(n):
			proc.append(n)
	# Godot's own order: priority, then tree order.
	var order: Dictionary = {}
	var k: int = 0
	for n in _flatten(root):
		order[n] = k
		k += 1
	phys.sort_custom(func(a: Node, b: Node) -> bool:
		if a.process_physics_priority != b.process_physics_priority:
			return a.process_physics_priority < b.process_physics_priority
		return int(order.get(a, 0)) < int(order.get(b, 0)))
	proc.sort_custom(func(a: Node, b: Node) -> bool:
		if a.process_priority != b.process_priority:
			return a.process_priority < b.process_priority
		return int(order.get(a, 0)) < int(order.get(b, 0)))


func _collect(n: Node, phys: Array, proc: Array) -> void:
	if n.get_script() != null:
		if n.is_physics_processing() and n.has_method("_physics_process"):
			phys.append(n)
		if n.is_processing() and n.has_method("_process"):
			proc.append(n)
	for c in n.get_children():
		_collect(c, phys, proc)


func _flatten(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_flatten(c))
	return out


func _dt_for(entry: Dictionary, delta: float, stepping: bool) -> float:
	if stepping:
		return FRAME
	if paused or bool(entry["paused"]):
		return 0.0
	return delta * time_scale * float(entry["scale"])


func _physics_process(delta: float) -> void:
	for id in _roots.keys():
		var entry: Dictionary = _roots[id]
		if not is_instance_valid(entry["root"]):
			_roots.erase(id)
			continue
		# A root in a disabled branch (a bay you are not in) sleeps with it.
		if not (entry["root"] as Node).can_process():
			continue
		var stepping: bool = int(entry["pstep"]) > 0
		var dt: float = _dt_for(entry, delta, stepping)
		if stepping:
			entry["pstep"] = int(entry["pstep"]) - 1
		if dt <= 0.0:
			continue
		var t0: int = Time.get_ticks_usec()
		for n in entry["physics"]:
			if is_instance_valid(n) and n.is_inside_tree():
				n._physics_process(dt)
		entry["pusec"] = int(entry["pusec"]) + Time.get_ticks_usec() - t0
		entry["pticks"] = int(entry["pticks"]) + 1


func _process(delta: float) -> void:
	_rescan_t += delta
	var rescan: bool = _rescan_t >= rescan_seconds
	if rescan:
		_rescan_t = 0.0
	for id in _roots.keys():
		var entry: Dictionary = _roots[id]
		if not is_instance_valid(entry["root"]):
			_roots.erase(id)
			continue
		if rescan:
			_scan(entry)
		if not (entry["root"] as Node).can_process():
			continue
		var stepping: bool = int(entry["fstep"]) > 0
		var dt: float = _dt_for(entry, delta, stepping)
		if stepping:
			entry["fstep"] = int(entry["fstep"]) - 1
		if dt <= 0.0:
			continue
		var t1: int = Time.get_ticks_usec()
		for n in entry["process"]:
			if is_instance_valid(n) and n.is_inside_tree():
				n._process(dt)
		entry["fusec"] = int(entry["fusec"]) + Time.get_ticks_usec() - t1
		entry["fticks"] = int(entry["fticks"]) + 1
