extends SceneTree

## What the pen costs per frame, and what the cloud deck adds.
##
## DECIDED ONCE AT STARTUP, NOT INTERLEAVED. Interleaving is the right method when the two
## states are cheap to switch between - it defeats run-to-run drift. Here it was wrong:
## reassigning cloud_material every frame rebuilds the sky, so both samples came back at
## 100 ms and the difference between them meant nothing. Two runs and a 1-2 ms drift is the
## honest measurement for a change that cannot be toggled cheaply.
##
## Flip CLOUDS to compare. Vsync off, or the numbers are quantised to the 60 Hz beat.

const CLOUDS: bool = true
## Also clear the sky, to find out whether the scattering model is what costs.
const SKY: bool = true

var _f: int = 0
var _total: float = 0.0
var _n: int = 0
var _worst: float = 0.0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var env: Node = scene.get_node("World/Environment")
	if not CLOUDS:
		env.set("cloud_material", null)
	if not SKY:
		env.set("sky_material", null)
	print("clouds: %s   sky: %s" % [
		str(env.get("cloud_material") != null), str(env.get("sky_material") != null)])


func _process(delta: float) -> bool:
	_f += 1
	if _f > 40:
		_total += delta
		_n += 1
		_worst = maxf(_worst, delta)
	if _f < 200:
		return false
	print("FRAME mean %.2f ms  worst %.2f ms  over %d samples" % [
		_total / maxf(float(_n), 1.0) * 1000.0, _worst * 1000.0, _n])
	return true
