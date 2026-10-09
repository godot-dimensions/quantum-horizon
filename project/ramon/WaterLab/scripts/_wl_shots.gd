extends SceneTree

## WATER LAB: what every Water Lab runner shares. A queue of steps, each [frames to wait, what to
## do, the frame's name], run one after another; a frame is saved under OUT when a step names one.
## Windowed runs are unfocusable (they must not steal Ramon's keyboard). A runner extends this,
## sets `out`, and fills the queue in `setup()`; `perf_start(name)` and `perf_end()` time the frames
## between them (median and 95th percentile, milliseconds).

var out: String = "res://smoke_test_output/water_lab/"
var deadline_ms: int = 180000
var tag: String = "WL"

var _queue: Array = []
var _wait: int = 0
var _deadline: int = 0
var _measuring: String = ""
var _perf: Array = []
var _last_us: int = 0
var _script_us: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(func() -> void:
		_deadline = Time.get_ticks_msec() + deadline_ms
		setup()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))).call_deferred()


## Fill the queue here.
func setup() -> void:
	pass


func step(wait: int, f: Callable, shot: String = "") -> void:
	_queue.append([wait, f, shot])


func shot(name: String, wait: int = 2) -> void:
	step(wait, func() -> void: pass, name)


func nop() -> void:
	pass


func perf_start(name: String) -> void:
	_measuring = name
	_perf = []
	_last_us = Time.get_ticks_usec()
	_script_us = 0.0


func perf_end() -> void:
	if _perf.is_empty():
		_measuring = ""
		return
	var sorted: Array = _perf.duplicate()
	sorted.sort()
	var med: float = sorted[sorted.size() / 2]
	var p95: float = sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)]
	var proc: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	print("%s PERF %s: %d frames, median %.2f ms, 95th %.2f ms, process %.2f ms, physics %.2f ms" % [tag, _measuring, sorted.size(), med, p95, proc, phys])
	_measuring = ""


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline and _deadline > 0:
		print(tag + " TIMEOUT")
		quit(2)
		return true
	if not _measuring.is_empty():
		var now: int = Time.get_ticks_usec()
		_perf.append((now - _last_us) / 1000.0)
		_last_us = now
	if _wait > 0:
		_wait -= 1
		return false
	if _queue.is_empty():
		if _deadline > 0:
			print(tag + " done")
			quit()
			return true
		return false
	var s: Array = _queue[0]
	if s.size() < 4:
		s.append(true)
		(s[1] as Callable).call()
		return false
	if int(s[0]) > 0:
		s[0] = int(s[0]) - 1
		return false
	_queue.pop_front()
	if not String(s[2]).is_empty():
		root.get_texture().get_image().save_png(out + String(s[2]) + ".png")
		print(tag + " shot ", s[2])
	return false


## A test world in code: a sky, a sun, a grey floor, a camera at `eye` looking at `look`.
func test_world(eye: Vector4, look: Vector4) -> Node4D:
	var w := Node4D.new()
	w.name = "TestWorld"
	var env := WorldEnvironment4D.new()
	var sky := GradientSkyMaterial4D.new()
	sky.set("horizon_color", Color(0.62, 0.69, 0.76))
	sky.set("top_color", Color(0.17, 0.35, 0.62))
	sky.set("bottom_color", Color(0.08, 0.12, 0.18))
	env.set("sky_material", sky)
	env.set("ambient_light_sky_contribution", 0.25)
	env.set("ambient_light_color", Color(0.42, 0.48, 0.56))
	env.set("tonemap_mode", 2)
	env.set("current", true)
	w.add_child(env)
	var sun := DirectionalLight4D.new()
	sun.basis = Projection(Vector4(0.8192, 0, -0.5736, 0), Vector4(-0.3214, 0.8192, -0.4589, 0), Vector4(0.4698, 0.5736, 0.671, 0), Vector4(0, 0, 0, 1))
	sun.set("light_energy", 1.1)
	w.add_child(sun)
	var floor := MeshInstance4D.new()
	var bm := BoxTetraMesh4D.new()
	bm.size = Vector4(60, 1, 60, 60)
	floor.mesh = bm
	floor.position = Vector4(0, -0.5, 0, 0)
	var fm := TetraMaterial4D.new()
	fm.albedo_color = Color(0.45, 0.46, 0.47)
	floor.material_override = fm
	w.add_child(floor)
	var cam := Camera4D.new()
	cam.name = "Camera"
	cam.set("rendering_engine_name", "Cross-section")
	w.add_child(cam)
	root.add_child(w)
	aim(cam, eye, look)
	cam.make_current()
	return w


## Points `cam` from `eye` at `look` (the look's W ignored: the slice stays level).
func aim(cam: Camera4D, eye: Vector4, look: Vector4) -> void:
	var d: Vector4 = look - eye
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001))
	cam.global_position = eye
	cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)
