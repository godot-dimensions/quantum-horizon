extends SceneTree

## What the Lookout's own scripts cost, A/B: every node the Lookout adds (its systems, the owl
## and its tree, the heron and its marsh, the kata wood and the chipmunks, the balloon) asleep
## for a block, awake for the next, eight times over, at one spot - and the scripts' time
## averaged per block, the first second of each thrown away.
##
## INTERLEAVED, NOT TWO RUNS: the pen's own scripts drift by several milliseconds over a minute
## (its chickens, the hawk coming through), which swamps a difference measured as two
## separate runs. And in blocks of seconds rather than frame by frame, because
## Performance.TIME_PROCESS is a coarse monitor: 90 frames in a row can read the same.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_measure_ab_runner.gd -- spot=field|balloon

const TEST_BOOK := "user://lookout_journal_ab_test.cfg"
## Blocks of an odd length in an on, off, off, on order, repeated: an A/B in plain alternation
## picked up 1.7 ms from toggling an EMPTY node in the balloon, because something in the scene
## runs on a period that lined up with the blocks. ABBA cancels a drift and a period both.
const BLOCK := 2.7
const CYCLES := 8
const ORDER := [true, false, false, true]

var _room: Node
var _lookout: Node
var _spot: String = "field"
var _t: float = 0.0
var _phase: int = 0
var _block: int = 0
var _on: Array = []
var _off: Array = []
var _nodes: Array = []


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("spot="):
			_spot = arg.substr(5)
	if FileAccess.file_exists(TEST_BOOK):
		DirAccess.remove_absolute(TEST_BOOK)
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	_lookout = _room.get_node("Systems/Lookout")
	_lookout.set("journal_path", TEST_BOOK)
	root.add_child(_room)
	current_scene = _room


func _set_lookout(on: bool) -> void:
	for n in _nodes:
		if is_instance_valid(n):
			(n as Node).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _mean(values: Array) -> float:
	var total: float = 0.0
	for v in values:
		total += float(v)
	return total / maxf(float(values.size()), 1.0)


func _process(d: float) -> bool:
	_t += d
	match _phase:
		0:
			# Past the pen's warm-up.
			if _t < 25.0:
				return false
			for path in ["World/AnaOwl", "World/OwlTree", "World/AnaHeron", "World/AnaMarsh", "World/KataWood", "World/Balloon"]:
				if _room.get_node_or_null(path) != null:
					_nodes.append(_room.get_node(path))
			for c in _lookout.get("chipmunks"):
				_nodes.append(c)
			if _spot == "balloon":
				_lookout.get("journal").call("set_flag", "approached", true)
				_lookout.get("journal").call("set_flag", "met_wren", true)
				var balloon: Node = _lookout.get("balloon")
				balloon.call("set_ready", true, true)
				balloon.call("board")
				balloon.set("ride_speed", 0.0001)
				balloon.set("ride_time", 60.0)
			# The Lookout's systems last: asleep, the balloon's ride and the camera stop too, so
			# for the balloon spot only the world nodes are switched.
			if _spot != "balloon":
				_nodes.append(_lookout)
			else:
				# The viewfinder: what the camera draws over the picture, every frame.
				_nodes.append(_lookout.get("station").get("view"))
			# -- only=none: an empty node, for the method's own noise and bias.
			if OS.get_cmdline_user_args().has("only=none"):
				var empty := Node.new()
				_room.add_child(empty)
				_nodes = [empty]
			# -- only=view: the viewfinder alone.
			if OS.get_cmdline_user_args().has("only=view"):
				_nodes = [_lookout.get("station").get("view")]
			_phase = 2
			_t = 0.0
		2:
			# Settled before the first block: boarding, the camera's set-up and the first radio
			# lines all land in the first seconds, and put in the first block they were the
			# whole of a 1.8 ms "cost" measured on an empty node.
			if _t > 6.0:
				_phase = 1
				_t = 0.0
		1:
			var on: bool = ORDER[_block % 4]
			if _t > 1.0:
				(_on if on else _off).append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			if _t >= BLOCK:
				_block += 1
				_t = 0.0
				_set_lookout(ORDER[_block % 4])
				if _block >= CYCLES * 2:
					_set_lookout(true)
					print("      %-8s scripts with the Lookout %.3f ms, without %.3f ms: it costs %.3f ms" % [_spot, _mean(_on), _mean(_off), _mean(_on) - _mean(_off)])
					if _spot == "balloon":
						print("      the viewfinder's own draw: %.3f ms a frame" % (float(_lookout.get("station").get("view").get("draw_usec")) / 1000.0))
					if FileAccess.file_exists(TEST_BOOK):
						DirAccess.remove_absolute(TEST_BOOK)
					print("AB DONE")
					return true
	return false
