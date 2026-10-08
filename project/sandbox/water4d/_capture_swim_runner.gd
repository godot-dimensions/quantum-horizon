extends SceneTree

## The plesiosaur through one stroke, from the side and from above.
##
##   godot --path project --rendering-method forward_plus --resolution 1100x620 \
##       --script res://sandbox/water4d/_capture_swim_runner.gd
##
## `_probe_swim_runner.gd` proves the cut loses no geometry and that the pieces move. Neither
## of those says whether the SEAMS hold: a patch that is posed with the wrong transform still
## conserves its cells perfectly while tearing a hole in the neck. That is what these are for.
##
## Four phases of the flipper beat from the side, and four from above where the neck's sway
## reads best. The camera is placed from the model's own bounds, for the reason written up in
## `_capture_plesiosaur_runner.gd`.

const SCENE := "res://sandbox/water4d/plesiosaur.tscn"
const PHASES: int = 4

var _root: Node = null
var _model: Node = null
var _swimmer: Node = null
var _camera: Camera4D = null
var _frames: int = 0
var _shot: int = 0
var _posed: bool = false
var _centre := Vector4()
var _reach: float = 10.0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_build()
		return false
	if _frames < 4:
		return false
	if _frames == 4:
		_measure()
		return false

	# POSE ON ONE CALL, PHOTOGRAPH ON THE NEXT. Stepping the clock and grabbing the texture
	# in the same frame photographs the PREVIOUS pose, so every shot comes out one phase stale.
	# An `await process_frame` here looked like the tidy fix and silently stopped the loop
	# after a single image - a SceneTree._process that awaits no longer returns the bool the
	# main loop reads. Two plain states do the same job and keep the contract.
	if not _posed:
		var phase: int = _shot % PHASES
		_aim(_shot >= PHASES)
		var period: float = _swimmer.get("stroke_period")
		_swimmer.set("_time", period * float(phase) / float(PHASES))
		_swimmer.call("_physics_process", 0.0)
		_posed = true
		return false

	var shot_phase: int = _shot % PHASES
	var from_above: bool = _shot >= PHASES
	root.get_texture().get_image().save_png(
			"user://swim_%s_%d.png" % ["close" if from_above else "side", shot_phase])
	print("  %s phase %d" % ["close" if from_above else "side", shot_phase])
	_posed = false
	_shot += 1
	if _shot >= PHASES * 2:
		quit(0)
		return true
	return false


func _build() -> void:
	_root = Node4D.new()
	root.add_child(_root)
	current_scene = _root
	var environment := WorldEnvironment4D.new()
	environment.current = true
	environment.sky_material = GradientSkyMaterial4D.new()
	environment.ambient_light_sky_contribution = 0.35
	environment.ambient_light_color = Color(0.5, 0.56, 0.62)
	environment.tonemap_mode = 2
	_root.add_child(environment)
	var sun := DirectionalLight4D.new()
	sun.basis = Basis4D.from_yz(-0.7) * Basis4D.from_zx(0.5)
	sun.light_color = Color(1.0, 0.97, 0.91)
	sun.light_energy = 1.15
	_root.add_child(sun)
	var fill := DirectionalLight4D.new()
	fill.basis = Basis4D.from_yz(-0.3) * Basis4D.from_zx(-2.2)
	fill.light_color = Color(0.72, 0.8, 0.88)
	fill.light_energy = 0.5
	_root.add_child(fill)
	_model = (load(SCENE) as PackedScene).instantiate()
	_root.add_child(_model)
	_swimmer = _model.get_node_or_null(^"Swimmer")
	_camera = Camera4D.new()
	_camera.rendering_engine_name = "Cross-section"
	_root.add_child(_camera)
	_camera.current = true


## The bounds have to come from the PIECES now: the rig hands its mesh to them and keeps none.
func _measure() -> void:
	var low := Vector4(INF, INF, INF, INF)
	var high := Vector4(-INF, -INF, -INF, -INF)
	for node in _walk(_model):
		if not (node is MeshInstance4D):
			continue
		var mesh := (node as MeshInstance4D).mesh as ArrayTetraMesh4D
		if mesh == null:
			continue
		for p in mesh.get_vertex_positions():
			low = Vector4(minf(low.x, p.x), minf(low.y, p.y), minf(low.z, p.z), minf(low.w, p.w))
			high = Vector4(maxf(high.x, p.x), maxf(high.y, p.y), maxf(high.z, p.z), maxf(high.w, p.w))
	_centre = (low + high) * 0.5
	var span: Vector4 = high - low
	_reach = maxf(maxf(span.x, span.y), span.z)


func _aim(from_above: bool) -> void:
	# The "above" slot is reused as a CLOSE side shot of the shoulder, which is where the
	# flipper seam is and the only place a tear would show. A whole-animal frame renders the
	# seam about three pixels wide, which is not enough to tell a tear from a shading edge.
	var offset := Vector4(-1.0, 0.12, 0.0, 0.0) if not from_above else Vector4(-1.0, 0.25, 0.35, 0.0)
	var distance: float = _reach * (0.85 if not from_above else 0.22)
	var at: Vector4 = _centre if not from_above else _centre + Vector4(0.0, 0.0, 0.6, 0.0)
	var from: Vector4 = at + offset.normalized() * distance
	_camera.position = from
	_camera.basis = Basis4D.looking_at(at - from)


func _walk(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_walk(child))
	return found
