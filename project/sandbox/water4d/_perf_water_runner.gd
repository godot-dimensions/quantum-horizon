extends SceneTree

## Frame time and GPU time, per preset.
##
##   godot --path project --rendering-method forward_plus --resolution 1280x720 \
##       --script res://sandbox/water4d/_perf_water_runner.gd
##
## MEDIANS, NOT MEANS. A mean over a few hundred frames sits above its own p95 whenever a
## couple of frames hitch, which has caught us out before; the median is what the frame
## actually costs.
##
## EACH PRESET IS GIVEN TIME TO SETTLE, in seconds rather than frames - the blend between
## presets takes half a second of wall clock, and with vsync off a frame count is not a
## duration.
##
## The GPU figure comes from Godot's own viewport measurement, which has to be switched on
## and then lags by a couple of frames, so the first samples after a switch are dropped with
## the settle.

const SCENE := "res://sandbox/water4d/water4d_test.tscn"
const Presets := preload("res://sandbox/water4d/water4d_presets.gd")
const SETTLE := 1.5
const SAMPLE := 2.5

var _root: Node = null
var _water: Node4D = null
var _preset: int = 0
var _held: float = 0.0
var _settling: bool = true
var _frames: int = 0
var _cpu: Array[float] = []
var _gpu: Array[float] = []
var _rows: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load(SCENE) as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		_water = _root.get_node("Water") as Node4D
		var camera := _root.get_node("FlyCamera") as Camera4D
		camera.position = Vector4(0.0, 12.0, 30.0, 0.0)
		camera.basis = Basis4D.orthonormalized(Basis4D.from_yz(-0.42))
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		return false

	_held += delta
	if _settling:
		if _held < SETTLE:
			return false
		_held = 0.0
		_settling = false
		_cpu.clear()
		_gpu.clear()
		return false

	_cpu.append(delta * 1000.0)
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	if _held < SAMPLE:
		return false

	_record()
	_preset += 1
	if _preset >= Presets.count():
		print("\n  preset             frame ms   fps     GPU ms   samples")
		for row in _rows:
			print(row)
		print("")
		quit(0)
		return true
	_water.call(&"set_preset", _preset)
	_held = 0.0
	_settling = true
	return false


func _record() -> void:
	var name: String = _water.call(&"preset_name", _preset)
	_rows.append("  %d %-16s %8.3f  %6.0f  %7.3f   %d"
			% [_preset + 1, name, _median(_cpu), 1000.0 / maxf(_median(_cpu), 0.0001),
			_median(_gpu), _cpu.size()])


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
