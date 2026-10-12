extends Node4D

## WATER LAB: a herd of animals (or plants, or bubbles) drawn the starlings' way: one 3D multimesh in
## the Cross-section engine's own World3D, each instance a 4D body placed and cut by its shader
## (shared/slice_draw.gdshaderinc). Whatever owns the herd (the koi's school, the eel, the weed beds)
## writes each member's row and calls upload(); this node does the drawing part, which is the pen's
## flock's (chickenpen/flock/pen_flock_4d.gd _ready and _on_pre_render) without the flock.
##
## A ROW IS 20 FLOATS: position, heading and side (three Vector4, the multimesh's 12 transform
## floats), a colour (4) and custom data (4). What colour and custom mean is the shader's business;
## the koi, for one, carry their variety and seed in the colour and their tail beat in the custom.
##
## TWO THINGS FROM THE FLOCK THAT ARE NOT OBVIOUS:
##   - ignore_culling, because the shader puts the vertices where Godot's bounds cannot predict, and
##   - a custom AABB anyway: an instance with no bounds is never indexed into its scenario at all,
##     and then ignore_culling never gets a say (renderer_scene_cull.cpp, _update_instance).
## The scenario is checked every draw rather than once: the engine replaces the viewport's World3D
## on an engine switch and after a scene trip.
##
## NO class_name (engine_gotchas.md).

const FLOATS := 20

## The shape every member is drawn with, and its shader (both set before the node enters the tree,
## or call rebuild()).
var mesh: Mesh
var shader: Shader
## Extra uniforms for the shader, set once and again whenever changed (set_param).
var params: Dictionary = {}
## Each member's half depth through W at size 1 (the shader reads it as `w_radius`).
var w_radius: float = 0.2
var count: int = 0
var buffer := PackedFloat32Array()

var _material: ShaderMaterial
var _multimesh := RID()
var _instance := RID()
var _scenario := RID()
var _allocated: int = -1


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = shader
	for k in params:
		_material.set_shader_parameter(k, params[k])
	_multimesh = RenderingServer.multimesh_create()
	if mesh != null:
		RenderingServer.multimesh_set_mesh(_multimesh, mesh.get_rid())
	_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_instance, _multimesh)
	RenderingServer.instance_geometry_set_material_override(_instance, _material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_ignore_culling(_instance, true)
	RenderingServer.instance_set_custom_aabb(_instance, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(_instance, false)
	set_count(count)
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _instance.is_valid():
			RenderingServer.free_rid(_instance)
		if _multimesh.is_valid():
			RenderingServer.free_rid(_multimesh)


## How many members, the buffer sized to match (new rows are zero: drawn nowhere, at size 0).
func set_count(n: int) -> void:
	count = maxi(n, 0)
	buffer.resize(count * FLOATS)
	if not _multimesh.is_valid() or count == _allocated:
		return
	_allocated = count
	RenderingServer.multimesh_allocate_data(_multimesh, count, RenderingServer.MULTIMESH_TRANSFORM_3D, true, true)


func set_param(key: StringName, value: Variant) -> void:
	params[key] = value
	if _material != null:
		_material.set_shader_parameter(key, value)


func material() -> ShaderMaterial:
	return _material


## Member `i`: where it is, which way it heads and which way is its right (unit Vector4s in the
## herd's space), its colour data and its custom data.
func write(i: int, p: Vector4, ahead: Vector4, right: Vector4, colour: Color, custom: Vector4) -> void:
	var o: int = i * FLOATS
	buffer[o] = p.x
	buffer[o + 1] = p.y
	buffer[o + 2] = p.z
	buffer[o + 3] = p.w
	buffer[o + 4] = ahead.x
	buffer[o + 5] = ahead.y
	buffer[o + 6] = ahead.z
	buffer[o + 7] = ahead.w
	buffer[o + 8] = right.x
	buffer[o + 9] = right.y
	buffer[o + 10] = right.z
	buffer[o + 11] = right.w
	buffer[o + 12] = colour.r
	buffer[o + 13] = colour.g
	buffer[o + 14] = colour.b
	buffer[o + 15] = colour.a
	buffer[o + 16] = custom.x
	buffer[o + 17] = custom.y
	buffer[o + 18] = custom.z
	buffer[o + 19] = custom.w


## The rows to the multimesh. Once a frame, after writing them.
func upload() -> void:
	if _multimesh.is_valid() and count > 0 and buffer.size() == count * FLOATS:
		RenderingServer.multimesh_set_buffer(_multimesh, buffer)


## Just before the 4D engine draws: the herd into this camera's frame, in this viewport's world (or
## the Combined renderer's inner one, as the flock does).
func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	if viewport != get_viewport() or not _instance.is_valid():
		return
	var world: World3D = viewport.find_world_3d()
	if engine != null and engine.get_friendly_name() == "Combined":
		var inner := viewport.get_node_or_null(^"CombinedProjectedSubViewport4D/CombinedCrossSectionSubViewport4D") as Viewport
		if inner != null:
			world = inner.find_world_3d()
	var scenario: RID = world.scenario if world != null else RID()
	if scenario != _scenario:
		_scenario = scenario
		RenderingServer.instance_set_scenario(_instance, scenario)
	var shown: bool = is_visible_in_tree() and count > 0 and scenario.is_valid()
	RenderingServer.instance_set_visible(_instance, shown)
	if not shown:
		return
	var inverse: Projection = camera.global_basis.inverse()
	var basis: Projection = inverse * global_basis
	var origin: Vector4 = inverse * (global_position - camera.global_position)
	_material.set_shader_parameter(&"view_basis_x", basis.x)
	_material.set_shader_parameter(&"view_basis_y", basis.y)
	_material.set_shader_parameter(&"view_basis_z", basis.z)
	_material.set_shader_parameter(&"view_basis_w", basis.w)
	_material.set_shader_parameter(&"view_origin", origin)
	_material.set_shader_parameter(&"w_radius", w_radius)


## Where the camera was at the last draw, in the herd's space: for anything that wants to look at
## you (a koi at the glass) or to know what is in your slice.
func viewer_in_herd(camera: Camera4D) -> Vector4:
	return global_basis.inverse() * (camera.global_position - global_position)
