extends SceneTree

## The wolf up close, for judging how it moves (6 Oct: "improve the wolf's animations and test how it
## jumps; when it catches a chicken make it feel believable"): in the range, at a fixed 30 fps, a camera
## following it: the gallop from the side and from three-quarters ahead, the trot, a leap over a bar, and
## a chase that ends in the catch, the shake and the carry. Frames in
## smoke_test_output/quantum_range/wolf/<take>_NN.png; the runner prints where the feet were while
## planted, so skating shows as a number.
##
##   range_run.sh clip wolf res://ramon/QuantumRange/scripts/_wolf_lab_runner.gd [only=gallop,leap,...]

const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const WOLF := "res://ramon/QuantumRange/scripts/targets/target_wolf.gd"
const CHICKEN := "res://ramon/QuantumRange/scripts/targets/target_chicken.gd"
const Build := preload("res://ramon/QuantumRange/carried/scripts/chamber_build.gd")
const OUT := "res://smoke_test_output/quantum_range/wolf/"

var _r: Node
var _d: Node
var _cam: Camera4D
var _t0: int = 0
var _only: PackedStringArray = []


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			_only = a.substr(5).split(",")
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 400000:
		print("WOLF: gave up after 400 s")
		return true
	return false


func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _look(from: Vector4, at: Vector4) -> void:
	var d: Vector4 = at - from
	_cam.global_position = from
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))


func _want(take: String) -> bool:
	return _only.is_empty() or _only.has(take)


## Films `frames` frames of `w`, the camera at `offset` from it (or fixed at `fixed` if given).
func _film(take: String, w: Node4D, offset: Vector4, frames: int, fixed: Vector4 = Vector4.INF, extra: Node4D = null, on_head: bool = false) -> void:
	var slid: float = 0.0
	var seen: Dictionary = {}
	for i in frames:
		if is_instance_valid(w):
			var at: Vector4 = w.global_position + Vector4(0, 0.7, 0, 0)
			if on_head:
				at = (w.get("_neck") as Node4D).global_position
			elif extra != null and is_instance_valid(extra):
				at = at.lerp(extra.global_position, 0.3)
			_look(fixed if fixed != Vector4.INF else at + offset, at)
			# Skating: how far each planted foot moves while it stays planted.
			for l in w.get("_legs"):
				var nm: String = l["name"]
				var foot: Vector4 = (l["knee"] as Node4D).local_to_global(Vector4.ZERO)
				if bool(l["planted"]):
					var fp: Vector4 = (l["knee"] as Node4D).global_basis * Vector4.ZERO
					var p: Vector4 = l["plant"]
					if seen.has(nm):
						slid = maxf(slid, (p - (seen[nm] as Vector4)).length())
					seen[nm] = p
				else:
					seen.erase(nm)
		await _frame()
		_save("%s_%02d" % [take, i])
	print("WOLF: filmed %s (plants moved at most %.3f m while planted)" % [take, slid])


func _wolf(at: Vector4, route: Array, props: Dictionary = {}) -> Node4D:
	var p: Dictionary = {"route": route, "size": 1.25}
	p.merge(props, true)
	return _d.call("spawn", WOLF, at, p)


func _run() -> void:
	var dir: String = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	if _only.is_empty():
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
	_r = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_r)
	current_scene = _r
	for i in 30:
		await _frame()
	_d = _r.get("director")
	_d.set("keep_bests", false)
	_d.set_process_unhandled_key_input(false)
	_r.set_process_unhandled_input(false)
	(_r.get("player") as Node).set("input_enabled", false)
	(_r.get("sfx") as Node).set("muted", true)
	(_r.get("hud") as Node).set("clean", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_cam.set("view_angle_type", 1)
	_cam.set("field_of_view_4d", deg_to_rad(45.0))
	_r.add_child(_cam)
	_cam.make_current()
	var t0: int = Time.get_ticks_usec()
	var probe: Node4D = _wolf(Vector4(0, 0, -30, 0), [{"wait": 0.1}])
	await _frame()
	print("WOLF: first wolf built in %.0f ms (pieces %.0f ms)" % [(Time.get_ticks_usec() - t0) / 1000.0, float(load("res://ramon/QuantumRange/scripts/range_wolf.gd").build_ms)])
	probe.call("leave")

	if _want("gallop"):
		var w: Node4D = _wolf(Vector4(-9, 0, -14, 0), [{"run": Vector4(10, 0, -14, 0), "speed": 6.5}])
		for i in 8:
			await _frame()
		await _film("gallop_side", w, Vector4(0, 0.1, 5.5, 0), 30)
		var w2: Node4D = _wolf(Vector4(-9, 0, -14, 0), [{"run": Vector4(10, 0, -14, 0), "speed": 6.5}])
		for i in 8:
			await _frame()
		await _film("gallop_front", w2, Vector4(4.0, 0.3, 3.0, 0), 24)
	if _want("trot"):
		var w3: Node4D = _wolf(Vector4(-6, 0, -14, 0), [{"run": Vector4(10, 0, -14, 0), "speed": 2.8}])
		for i in 8:
			await _frame()
		await _film("trot_side", w3, Vector4(0, 0.1, 5.0, 0), 24)
	if _want("leap"):
		# A holodeck bar to clear, at x = 0.
		var props: Node4D = _d.get("props")
		Build.box(props, "Bar", Vector3(0.0, 0.75, -14.0), Vector3(0.1, 0.08, 3.0), "range_counter", false)
		Build.box(props, "BarPostA", Vector3(0.0, 0.375, -15.5), Vector3(0.08, 0.75, 0.08), "range_counter", false)
		Build.box(props, "BarPostB", Vector3(0.0, 0.375, -12.5), Vector3(0.08, 0.75, 0.08), "range_counter", false)
		var w4: Node4D = _wolf(Vector4(-10, 0, -14, 0), [{"run": Vector4(-2.2, 0, -14, 0), "speed": 6.5}, {"leap": Vector4(2.4, 0, -14, 0), "height": 1.0},
			{"run": Vector4(10, 0, -14, 0), "speed": 6.5}])
		for i in 14:
			await _frame()
		await _film("leap", w4, Vector4.ZERO, 36, Vector4(0.5, 1.0, -9.6, 0))
	if _want("catch"):
		# The chase: a small chicken legging it, the wolf after it.
		var start := Vector4(-2.0, 0.315, -16.0, 0)
		var bird: Node4D = _d.call("spawn", CHICKEN, start, {"size": 0.3, "friendly": true, "running": true})
		bird.set("path", func(_tt: Node4D, a: float) -> Vector4:
			return start + Vector4(3.0 * a, 0.0, 0.6 * sin(a * 2.5), 0.0))
		var w5: Node4D = _wolf(Vector4(-9, 0, -16.5, 0), [{"pounce": bird}, {"run": Vector4(-8, 0, -24, 0), "speed": 5.0}])
		for i in 60:
			await _frame()
		await _film("catch", w5, Vector4(0.6, 0.25, 3.6, 0), 120, Vector4.INF, bird, true)
		print("WOLF: caught = %s" % str(w5.get("caught")) if is_instance_valid(w5) else "WOLF: the wolf is gone")
	if _want("aim"):
		# The hitbox against what you see: one shot each at red wolves at a random moment in their run,
		# from the firing position, aimed at the middle of the body.
		var p: CharacterBody4D = _r.get("player")
		p.call("place", Vector4(0, 0.05, 1.5, 0), 0.0)
		(p.get("camera") as Camera4D).make_current()
		var weapon: Node = _r.get("weapon")
		var outcomes: Dictionary = {}
		for k in 10:
			var z: float = -8.0 - 1.5 * float(k % 5)
			var w6: Node4D = _wolf(Vector4(-9, 0, z, 0), [{"run": Vector4(9, 0, z + (2.0 if k % 2 == 0 else -2.0), 0), "speed": 6.5}], {"size": 1.6})
			for i in 8 + (k * 7) % 30:
				await _frame()
			var core: Node4D = (w6.call("part", "Wolf") as Dictionary)["node"]
			p.call("aim_at", core.global_position)
			var r: Dictionary = weapon.call("fire", false)
			var o: String = String(r.get("outcome", ""))
			outcomes[o] = int(outcomes.get(o, 0)) + 1
			if o != "pop":
				print("WOLF: missed: aimed at %s, the shot ended at %s" % [str(core.global_position), str(r.get("at"))])
			if is_instance_valid(w6) and bool(w6.get("alive")):
				w6.call("leave")
			await _frame()
		print("WOLF: one shot each at ten running wolves: %s" % str(outcomes))
	print("WOLF: done")
	quit()
