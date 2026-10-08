extends SceneTree

## Which fence parameter actually opens the railing up at w = 0?
##
##   godot --path project --rendering-method forward_plus --resolution 900x600 \
##       --script res://sandbox/water4d/_probe_rail_sweep_runner.gd
##
## `_probe_rail_openness_runner.gd` showed the starting slice covering 30% against 8%
## everywhere else: at w = 0 the cut passes through a bar that runs the whole length, and at
## any other angle it misses it. Which bar, and which number governs it, is not obvious from
## the generator's headers - `beam_coverage` has no comment and the ratios are ratios of
## ratios - so this builds one rail at a time and measures, instead of reading the source and
## hoping.
##
## One fence, nothing else in the scene, same camera every time. The only thing that changes
## between rows is the one parameter named in it.

const SETTLE := 0.35

## name, then the overrides applied on top of the walkway's own numbers.
const CASES := [
	["as built", {}],
	["beam_count 0", {"beam_count": 0}],
	["beam_coverage 0.04", {"beam_coverage": 0.04}],
	["beam_thickness 0.15", {"beam_thickness_ratio": 0.15}],
	["beam_max_height 0.35", {"beam_max_height_ratio": 0.35}],
	["rib_height 0.25", {"rib_height_ratio": 0.25}],
	["rib_thickness 0.08", {"rib_thickness_ratio": 0.08}],
	["spacing 5.0", {"desired_spacing_meters": 5.0}],
]

var _camera: Camera4D = null
var _holder: Node4D = null
var _fence: FenceGenerator4D = null
var _frames: int = 0
var _held: float = 0.0
var _index: int = 0
var _rows: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_holder = Node4D.new()
		root.add_child(_holder)
		current_scene = _holder
		var environment := WorldEnvironment4D.new()
		environment.current = true
		_holder.add_child(environment)
		var sun := DirectionalLight4D.new()
		_holder.add_child(sun)
		_camera = Camera4D.new()
		_camera.rendering_engine_name = "Cross-section"
		_holder.add_child(_camera)
		_camera.position = Vector4(0.0, 1.3, 7.0, 0.0)
		_camera.basis = Basis4D.orthonormalized(Basis4D.from_yz(-0.05))
		_camera.current = true
		_build(0)
		return false

	_held += delta
	if _held < SETTLE:
		return false
	_held = 0.0

	_measure(CASES[_index][0])
	_index += 1
	if _index >= CASES.size():
		return _report()
	_build(_index)
	return false


func _build(index: int) -> void:
	if _fence != null:
		_fence.queue_free()
	_fence = FenceGenerator4D.new()
	_fence.name = "Rail"
	_fence.update_automatically = false
	_fence.input_shape_type = FenceGenerator4D.INPUT_SHAPE_BOX
	# The walkway's own long rail: thin in z, the walkway's depth through W.
	_fence.box_size = Vector3(43.6, 0.16, 4.2)
	_fence.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	_fence.desired_spacing_meters = 2.8
	_fence.post_height_meters = 1.05
	_fence.post_thickness_meters = 0.075
	_fence.top_footprint_ratio = 1.0
	_fence.rib_height_ratio = 1.0
	_fence.rib_thickness_ratio = 0.26
	_fence.beam_count = 2
	_fence.beam_coverage = 0.16
	_fence.beam_max_height_ratio = 0.95
	var material := TetraMaterial4D.new()
	material.albedo_color = Color(0.62, 0.57, 0.48)
	_fence.post_material = material
	_fence.rib_material = material
	_fence.beam_material = material
	for key in (CASES[index][1] as Dictionary):
		_fence.set(key, (CASES[index][1] as Dictionary)[key])
	_fence.position = Vector4(0.0, 0.0, 1.7, 0.0)
	_holder.add_child(_fence)
	_fence.update_fence_mesh_now()


func _measure(label: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png("user://railsweep_%s.png" % label.replace(" ", "_").replace(".", "_"))
	var hits: int = 0
	var total: int = 0
	var y0: int = int(float(image.get_height()) * 0.30)
	var y1: int = int(float(image.get_height()) * 0.72)
	for y in range(y0, y1):
		for x in range(0, image.get_width(), 2):
			var c: Color = image.get_pixel(x, y)
			total += 1
			if c.r > c.b + 0.04:
				hits += 1
	_rows.append("  %-22s covers %5.1f%%" % [label, 100.0 * float(hits) / maxf(float(total), 1.0)])


func _report() -> bool:
	print("\n  one long rail, seen square on at w = 0:")
	for row in _rows:
		print(row)
	print("")
	quit(0)
	return true
