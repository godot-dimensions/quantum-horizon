extends SceneTree
## Voxel Lab, round 5 (9 Oct): what the open world's grass patches cost (Ramon: "how heavy is the grass
## currently"). Two views, each measured with the grass on, then off, then on again: close to a patch (9 m
## off it, 4.5 m up) and from the deck looking over the island toward the patches. Per view, the median over
## 150 frames of the GPU's render time and the CPU's (the root viewport's own measured times, vsync off), the
## grass's own layout on the CPU each render (prerender_usec), and the blades handed to the GPU.
##   VoxelLab/run.sh windowed grass_cost res://ramon/VoxelLab/field/_measure_grass_runner.gd

const FIELD := "res://ramon/VoxelLab/field/voxel_field.tscn"
const FRAMES := 150

var _f: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _cam: Camera4D
var _views: Array = []
var _view: int = 0
var _phase: int = 0
var _gpu: Array = []
var _cpu: Array = []
var _lay: Array = []
var _blades: int = 0
var _results: Array = []


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_open.call_deferred()


func _open() -> void:
	_f = (load(FIELD) as PackedScene).instantiate()
	root.add_child(_f)
	current_scene = _f


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b: Array = a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _process(delta: float) -> bool:
	_total += delta
	if _total > 150.0:
		print("GRASS FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _f == null or not _f.is_inside_tree() or _f.get("player") == null:
		return false
	_f.get("player").set("input_enabled", false)
	_t += delta
	match _step:
		0:
			if not bool(_f.get("loading")) and _f.get("grass") != null and _t > 3.0:
				RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
				var g: Node = _f.get("grass")
				var ps: Array = g.get("patches")
				var p: Vector4 = ps[0]
				var y: float = float(_f.call("ground_at", p.x, p.y, 0.0))
				var mid := Vector2.ZERO
				for q in ps:
					mid += Vector2((q as Vector4).x, (q as Vector4).y)
				mid /= float(ps.size())
				var deck: Vector4 = (_f.get("raft") as Node4D).global_position
				var to_mid := Vector2(mid.x - deck.x, mid.y - deck.z)
				_views = [
					["close to a patch", Vector4(p.x + 9.0, y + 4.5, p.y, 0.0), Basis4D.from_zx(atan2(9.0, 0.0)) * Basis4D.from_yz(deg_to_rad(-22.0))],
					["from the deck", Vector4(deck.x, deck.y + 3.5, deck.z, 0.0), Basis4D.from_zx(atan2(-to_mid.x, -to_mid.y)) * Basis4D.from_yz(deg_to_rad(-12.0))],
				]
				_cam = Camera4D.new()
				_cam.rendering_engine_name = "Cross-section"
				_f.add_child(_cam)
				print("GRASS %d patches, window %s" % [ps.size(), str(root.get_visible_rect().size)])
				_start_view()
				_step = 1
		1:
			# Each phase: a second to settle, then FRAMES frames sampled.
			if _t < 1.0:
				return false
			var vp: RID = root.get_viewport_rid()
			_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
			var g: Node = _f.get("grass")
			_lay.append(float(int(g.get("prerender_usec"))) / 1000.0)
			_blades = maxi(_blades, int(g.call("blade_count")))
			if _gpu.size() >= FRAMES:
				var on: bool = _phase != 1
				_results.append([String(_views[_view][0]), on, _median(_gpu), _median(_cpu), _median(_lay), _blades])
				print("GRASS %-18s grass %-3s  GPU %6.2f ms  CPU render %5.2f ms  grass layout %5.3f ms  blades %d" % [String(_views[_view][0]), "on" if on else "off",
					_median(_gpu), _median(_cpu), _median(_lay), _blades])
				_phase += 1
				if _phase > 2:
					_phase = 0
					_view += 1
					if _view >= _views.size():
						_report()
						return true
				_start_view()
	return false


func _start_view() -> void:
	var v: Array = _views[_view]
	_cam.global_position = v[1]
	_cam.global_basis = v[2]
	_cam.make_current()
	_f.call("set_grass", _phase != 1, 2.2)
	_gpu = []
	_cpu = []
	_lay = []
	_blades = 0
	_t = 0.0


func _report() -> void:
	for i in range(0, _results.size(), 3):
		var a: Array = _results[i]
		var off: Array = _results[i + 1]
		var b: Array = _results[i + 2]
		var on_gpu: float = (float(a[2]) + float(b[2])) * 0.5
		print("GRASS COST %-18s GPU +%.2f ms (%.2f on, %.2f off)  CPU layout %.3f ms  blades %d" % [String(a[0]), on_gpu - float(off[2]), on_gpu, float(off[2]),
			(float(a[4]) + float(b[4])) * 0.5, maxi(int(a[5]), int(b[5]))])
	print("GRASS done")
