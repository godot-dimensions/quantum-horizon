extends SceneTree

## Items 79 and 80: where does the frame actually go?
##
## MEASURED BEFORE ANYTHING IS OPTIMISED, which is the whole of item 80. The costs worth
## addressing are the ones that show up here, not the ones that look expensive in source.
##
## Headless, so nothing is drawn: this is logic cost only - AI, containment, the locator's
## queries, the walkers' IK and skinning. That is exactly the list item 80 names, and
## leaving rendering out means a slow frame cannot be blamed on the renderer.
##
## NOT WALL-CLOCK FRAME TIME. The headless loop here is paced: an empty scene with no vsync
## and no max_fps still reports exactly 6.900 ms per frame, so timing the frame measures the
## pacer and every subsystem appears free. Performance.TIME_PROCESS and TIME_PHYSICS_PROCESS
## report time actually spent inside script callbacks, which is what these systems are.
##
## ROUND-ROBIN, AND THE MINIMUM OF EACH. The workload is not stationary - twelve chickens
## idle, wander and evade in turn, and IK costs more in some poses than others - so one pass
## through the configurations measures the chickens' mood as much as the code. A single-pass
## version of this reported that switching the locator OFF cost 2.4 ms, because that window
## happened to catch the flock mid-wander. Cycling through the configurations repeatedly and
## keeping each one's cheapest window removes the mood and leaves the code.
##
## A/B BY SWITCHING SYSTEMS OFF, not by hiding things. Hiding a mesh stops it drawing and
## leaves every calculation behind it running, which is how an earlier measurement in this
## project concluded the opposite of the truth.

const BASELINE := "res://ramon/chickenpen/chickenpen_proceduralwalker.tscn"
const PROTOTYPE := "res://ramon/chickenpen/chickenpen.tscn"

const WARMUP: int = 40
const WINDOW: int = 220
const ROUNDS: int = 5

## Cumulative: each configuration also has everything above it switched off.
const CONFIGS := [
	"everything on",
	"locator and cues off",
	"pen return checks off",
	"chicken agents off",
	"walkers off too",
]

var _scene: Node
var _f: int = 0
var _total: float = 0.0
var _taken: int = 0
var _baseline_ms: float = 0.0
var _config: int = 0
var _round: int = 0
var _best: Dictionary = {}
var _measuring_baseline: bool = true


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_load(BASELINE)


func _load(path: String) -> void:
	if _scene != null:
		_scene.free()
	_scene = load(path).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_restart()


func _restart() -> void:
	_f = 0
	_total = 0.0
	_taken = 0


func _process(_d) -> bool:
	_f += 1
	if _f > WARMUP:
		_total += Performance.get_monitor(Performance.TIME_PROCESS)
		_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		_taken += 1
	if _taken < WINDOW:
		return false

	var ms: float = _total / float(_taken) * 1000.0
	_restart()

	if _measuring_baseline:
		_baseline_ms = ms
		_measuring_baseline = false
		print("baseline (the scene this was copied from, no chickens): %.2f ms/frame" % ms)
		_load(PROTOTYPE)
		return false

	var config_name: String = CONFIGS[_config]
	_best[config_name] = minf(float(_best.get(config_name, INF)), ms)

	_config += 1
	if _config < CONFIGS.size():
		_apply(_config)
		return false

	# One full sweep done. Switch everything back on and go round again.
	_config = 0
	_round += 1
	if _round < ROUNDS:
		_enable_all()
		return false

	_report()
	return true


## Switch off everything up to and including this configuration.
func _apply(index: int) -> void:
	match index:
		1:
			_set_running(["Systems/Locator", "Systems/Cues"], false)
		2:
			_set_running(["Pen/Return"], false)
		3:
			_set_agents(true, false)
		4:
			_set_agents(false, false)


func _enable_all() -> void:
	_set_running(["Systems/Locator", "Systems/Cues", "Pen/Return"], true)
	_set_agents(true, true)
	_set_agents(false, true)


func _set_running(paths: Array, running: bool) -> void:
	for path in paths:
		var node: Node = _scene.get_node_or_null(path)
		if node != null:
			node.set_process(running)
			node.set_physics_process(running)


## agents_not_walkers picks which half of each chicken to switch.
func _set_agents(agents_not_walkers: bool, running: bool) -> void:
	for agent in (_scene.get_node("Chickens").get("agents") as Array):
		if agents_not_walkers:
			agent.set_physics_process(running)
			continue
		var walker: Node = (agent.get_parent() as Node).get_node_or_null("Walker")
		if walker != null:
			walker.set_process(running)
			walker.set_physics_process(running)


func _report() -> void:
	var full: float = _best[CONFIGS[0]]
	print("prototype, everything on: %.2f ms/frame  (+%.2f over baseline)" % [
		full, full - _baseline_ms])
	print("\nbest of %d windows per configuration, each system switched off in turn:" % ROUNDS)
	var previous: float = full
	for i in CONFIGS.size():
		var ms: float = _best[CONFIGS[i]]
		var line: String = "   %-24s %6.2f ms" % [CONFIGS[i], ms]
		if i > 0:
			var drop: float = previous - ms
			line += "   that system costs %5.2f ms" % drop
			if drop > 0.05:
				line += "  (%.3f ms per chicken)" % (drop / 12.0)
		print(line)
		previous = ms
	print("\n   left with all of it off: %.2f ms - the chicken bodies and the rest of" % _best[CONFIGS[4]])
	print("   the scene simply existing.")
	print("\nprototype script time: %.2f ms of the 16.7 ms available at 60 fps." % full)
	_report_frequency()


## Item 79: what runs every frame, and what does not.
func _report_frequency() -> void:
	print("\nwhat runs at what rate (item 79):")
	print("   agent state, containment, recovery   every physics frame, cheap arithmetic")
	print("   walker IK and skinning               every physics frame, the real cost")
	print("   locator target choice                every physics frame, 12 distance tests")
	print("   pen return point-in-box              every 3rd frame (check_every)")
	print("   glimpse markers                      every process frame, 12 position writes")
	print("   fence and coop rebuild               only when a parameter changes")
