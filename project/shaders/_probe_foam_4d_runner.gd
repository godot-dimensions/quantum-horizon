extends SceneTree

## Does foam_4d actually vary along W, or does it only look like it does?
##
##   godot --path project --rendering-method forward_plus --resolution 720x720 \
##       --script res://shaders/_probe_foam_4d_runner.gd
##
## THE CLAIM UNDER TEST. The module says its pattern is defined over all three horizontal
## axes, so that turning the slice shows a genuine cross-section of a 3D foam field rather
## than a 2D pattern dragged sideways. If that were false - if the field were really a
## function of (x, z) with w ignored - then at a slice turn of 90 degrees one of the two
## visible axes WOULD BE W, the pattern would be constant along it, and the screen would
## fill with stripes.
##
## So: paint a flat plane with the field at several slice angles and measure how stripy each
## frame is. Stripiness is the ratio of pixel transitions counted along rows to transitions
## counted along columns. Round cells give about 1. A field with no W variation, seen at 90
## degrees, gives a number far from 1 - and that is the failure this is here to catch.
##
## It is a measurement of the REAL SHADER through the real renderer, not of a GDScript port
## of the same maths, which would only ever prove that two copies of my arithmetic agree.

const DEMO_SHADER := preload("res://shaders/foam_4d_demo.gdshader")
const ANGLES: Array[float] = [0.0, 30.0, 60.0, 90.0]
const SETTLE := 0.45
const EXTENT := 14.0
const GRID := 2
## Round cells never give exactly 1 - the screen is not square in world terms once the plane
## is seen at an angle - but anything inside this band is isotropic to the eye.
const RATIO_LIMIT := 1.9

var _camera: Camera4D = null
var _material: ShaderMaterial = null
var _instance := RID()
var _mesh: ArrayMesh = null
var _frames: int = 0
var _held: float = 0.0
var _index: int = 0
var _rows: Array[String] = []
var _ratios: Array[float] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_build()
		return false
	_held += delta
	if _held < SETTLE:
		return false
	_held = 0.0

	_measure(ANGLES[_index])
	_index += 1
	if _index >= ANGLES.size():
		return _report()
	_aim(ANGLES[_index])
	return false


func _build() -> void:
	var root_node := Node4D.new()
	root.add_child(root_node)
	current_scene = root_node

	var environment := WorldEnvironment4D.new()
	environment.current = true
	root_node.add_child(environment)

	_camera = Camera4D.new()
	root_node.add_child(_camera)
	_camera.rendering_engine_name = "Cross-section"
	_camera.current = true
	_camera.position = Vector4(0.0, 6.0, 0.0, 0.0)

	# A flat lattice; the shader decides where every vertex goes.
	var side: int = GRID + 1
	var verts := PackedVector3Array()
	verts.resize(side * side)
	var step: float = (EXTENT * 2.0) / float(GRID)
	for z in range(side):
		for x in range(side):
			verts[z * side + x] = Vector3(-EXTENT + float(x) * step, 0.0,
					-EXTENT + float(z) * step)
	var indices := PackedInt32Array()
	for z in range(GRID):
		for x in range(GRID):
			var i: int = z * side + x
			indices.append_array([i, i + side, i + 1, i + 1, i + side, i + side + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))

	_material = ShaderMaterial.new()
	_material.shader = DEMO_SHADER
	_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_instance, _mesh.get_rid())
	RenderingServer.instance_geometry_set_material_override(_instance, _material.get_rid())
	RenderingServer.instance_set_ignore_culling(_instance, true)
	RenderingServer.instance_set_custom_aabb(_instance,
			AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer4D.pre_render.connect(_on_pre_render)
	_aim(ANGLES[0])


## Straight down at the plane, with the slice turned `degrees` in the xw plane. Looking down
## keeps the plane filling the frame at every angle, so the frames stay comparable.
func _aim(degrees: float) -> void:
	_camera.basis = Basis4D.orthonormalized(
			Basis4D.from_xw(deg_to_rad(degrees)) * Basis4D.from_yz(-1.5))


func _on_pre_render(camera: Camera4D, viewport: Viewport, _engine: RenderingEngine4D) -> void:
	if viewport != root or not _instance.is_valid():
		return
	var world: World3D = viewport.find_world_3d()
	RenderingServer.instance_set_scenario(_instance,
			world.scenario if world != null else RID())
	var b: Projection = camera.global_basis
	_material.set_shader_parameter(&"cam_position", camera.global_position)
	_material.set_shader_parameter(&"cam_basis_x", b.x)
	_material.set_shader_parameter(&"cam_basis_y", b.y)
	_material.set_shader_parameter(&"cam_basis_z", b.z)
	var off := Vector3(b.w.x, b.w.z, b.w.w).normalized()
	var fwd := Vector3(-b.z.x, -b.z.z, -b.z.w)
	fwd -= off * fwd.dot(off)
	var axis_a: Vector3 = fwd.normalized() if fwd.length() > 0.0001 else Vector3(1.0, 0.0, 0.0)
	_material.set_shader_parameter(&"slice_axis_a", axis_a)
	_material.set_shader_parameter(&"slice_axis_b", off.cross(axis_a).normalized())


func _measure(degrees: float) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png("user://foam4d_slice_%02d.png" % int(degrees))
	var w: int = image.get_width()
	var h: int = image.get_height()
	# Only the middle, where the plane is, away from any horizon.
	var x0: int = w / 5
	var x1: int = w - w / 5
	var y0: int = h / 5
	var y1: int = h - h / 5
	var across: int = 0
	var down: int = 0
	var lit: int = 0
	var total: int = 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			var on: bool = image.get_pixel(x, y).r > 0.5
			total += 1
			if on:
				lit += 1
			if x > x0 and (image.get_pixel(x - 1, y).r > 0.5) != on:
				across += 1
			if y > y0 and (image.get_pixel(x, y - 1).r > 0.5) != on:
				down += 1
	var ratio: float = float(maxi(across, down)) / maxf(float(mini(across, down)), 1.0)
	_ratios.append(ratio)
	_rows.append("  %3d deg   coverage %5.1f%%   transitions %5d across / %5d down   ratio %.2f"
			% [int(degrees), 100.0 * float(lit) / maxf(float(total), 1.0), across, down, ratio])


func _report() -> bool:
	print("\n  foam_4d seen through a slice turned by:")
	for row in _rows:
		print(row)
	var worst: float = 0.0
	for r in _ratios:
		worst = maxf(worst, r)
	print("")
	if _ratios[0] > RATIO_LIMIT:
		print("  FAIL - even at 0 degrees the pattern is stripy (ratio %.2f). The measurement"
				% _ratios[0])
		print("         is picking up something other than the foam - fix it before reading")
		print("         the turned rows, which it cannot tell apart from this.")
	elif worst > RATIO_LIMIT:
		print("  FAIL - worst ratio %.2f across the turns. The field is close to constant"
				% worst)
		print("         along one of the visible axes, which is what a pattern with no W")
		print("         variation looks like once the slice is turned into W.")
	else:
		print("  PASS - worst ratio %.2f over 0 to 90 degrees. The pattern stays isotropic as"
				% worst)
		print("         the slice turns into W, so the field genuinely varies along all three")
		print("         horizontal axes.")
	if _instance.is_valid():
		RenderingServer.free_rid(_instance)
		_instance = RID()
	quit(0)
	return true
