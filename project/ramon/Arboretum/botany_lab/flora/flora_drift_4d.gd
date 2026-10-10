extends Node4D

## BOTANY LAB, round 3 (follow_up/arboretum.md section 9, step 14): petals, pollen and leaves on the air,
## drawn by flora_drift.gdshader (carried from the pen's wind bits; the pen untouched). One 3D MultiMesh
## in the Cross-section engine's World3D, moved into the camera's frame each render (as the pen's grass
## does, pen_grass_4d.gd _on_pre_render), so it costs a few hundredths of a millisecond.
##
## The room's wind (wind_4d.gd, `wind`) drives it: its direction in x and z, its speed (how far the air
## has moved is added up here, so a change of wind changes their speed, not where they are), and a
## gust, which puts more of them up and carries them faster.
##
##   stream false   a box of air (`box_size` round `box_centre`, `floor_y` to `top_y`): the flower room
##   stream true    from `source` downwind `reach` metres, falling (the hall's oak)
##
## In this node's own space. NO class_name (engine_gotchas.md).

const DriftShader := preload("res://ramon/Arboretum/botany_lab/flora/flora_drift.gdshader")
const MAX := 6000

@export var stream: bool = false
@export var amount: int = 700
## How many more are up at a gust's height, as a share of `amount`.
@export var gust_extra: float = 1.2
@export var box_centre := Vector2.ZERO
@export var box_size := Vector2(18.0, 18.0)
@export var floor_y: float = 0.2
@export var top_y: float = 7.0
@export var source := Vector3(0.0, 4.0, 0.0)
@export var source_radius: float = 2.5
@export var reach: float = 14.0
@export var leaf_share: float = 0.55
@export var leaf_size: float = 0.05
@export var bit_size: float = 0.014
@export var colours: PackedColorArray = PackedColorArray([Color(0.96, 0.72, 0.82), Color(0.98, 0.96, 0.94), Color(0.78, 0.66, 0.92), Color(1.0, 0.86, 0.42)])
## The wind's speed this drift feels, m/s, when there is no wind node.
@export var calm: float = 1.2

var wind: Node = null
var prerender_usec: int = 0
var _instance := RID()
var _multimesh := RID()
var _mesh: ArrayMesh
var _material: ShaderMaterial
var _scenario := RID()
var _travel: float = 0.0
var _wind_now: float = -1.0
var _msec: int = 0
var _was_shown: bool = true


func _ready() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var tex := ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(-0.02, 0.02, 0), Vector3(0.02, 0.02, 0), Vector3(0, 0.04, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(-1.0, 0.45), Vector2(1.0, 0.45), Vector2(0.0, 1.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 3, 0, 3, 2])
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_material = ShaderMaterial.new()
	_material.shader = DriftShader
	_material.set_shader_parameter("wind_noise", tex)
	_apply_settings()
	_multimesh = RenderingServer.multimesh_create()
	RenderingServer.multimesh_set_mesh(_multimesh, _mesh.get_rid())
	RenderingServer.multimesh_allocate_data(_multimesh, MAX, RenderingServer.MULTIMESH_TRANSFORM_3D, false, false)
	RenderingServer.multimesh_set_visible_instances(_multimesh, 0)
	_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_instance, _multimesh)
	RenderingServer.instance_geometry_set_material_override(_instance, _material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_ignore_culling(_instance, true)
	RenderingServer.instance_set_custom_aabb(_instance, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(_instance, false)
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


func _apply_settings() -> void:
	_material.set_shader_parameter("stream", 1 if stream else 0)
	_material.set_shader_parameter("box_centre", box_centre)
	_material.set_shader_parameter("box_size", box_size)
	_material.set_shader_parameter("floor_y", floor_y)
	_material.set_shader_parameter("top_y", top_y)
	_material.set_shader_parameter("source", source)
	_material.set_shader_parameter("source_radius", source_radius)
	_material.set_shader_parameter("reach", reach)
	_material.set_shader_parameter("leaf_share", leaf_share)
	_material.set_shader_parameter("leaf_size", leaf_size)
	_material.set_shader_parameter("bit_size", bit_size)
	if colours.size() >= 4:
		_material.set_shader_parameter("leaf_a", Vector3(colours[0].r, colours[0].g, colours[0].b))
		_material.set_shader_parameter("leaf_b", Vector3(colours[1].r, colours[1].g, colours[1].b))
		_material.set_shader_parameter("leaf_c", Vector3(colours[2].r, colours[2].g, colours[2].b))
		_material.set_shader_parameter("bit_colour", Vector3(colours[3].r, colours[3].g, colours[3].b))


## How many are up now (for runners).
func up_count() -> int:
	return RenderingServer.multimesh_get_visible_instances(_multimesh) if _multimesh.is_valid() else 0


func _set_visible(on: bool) -> void:
	if _instance.is_valid():
		RenderingServer.instance_set_visible(_instance, on and _scenario.is_valid())


func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	var shown: bool = is_visible_in_tree()
	if shown != _was_shown:
		_was_shown = shown
		_set_visible(shown)
	if not shown or viewport != get_viewport() or camera == null:
		return
	var started: int = Time.get_ticks_usec()
	var world: World3D = viewport.find_world_3d()
	if engine != null and engine.get_friendly_name() == "Combined":
		var inner := viewport.get_node_or_null(^"CombinedProjectedSubViewport4D/CombinedCrossSectionSubViewport4D") as Viewport
		if inner != null:
			world = inner.find_world_3d()
	var scenario: RID = world.scenario if world != null else RID()
	if scenario != _scenario:
		_scenario = scenario
		RenderingServer.instance_set_scenario(_instance, scenario)
		_set_visible(true)
	var inverse: Projection = camera.global_basis.inverse()
	var basis: Projection = inverse * global_basis
	var origin: Vector4 = inverse * (global_position - camera.global_position)
	var here: Vector4 = global_basis.inverse() * (camera.global_position - global_position)
	var normal: Vector4 = (global_basis.inverse() * camera.global_basis.w).normalized()
	# The air: how far it has moved, how hard it blows, a gust's extra.
	var now: int = Time.get_ticks_msec()
	var delta: float = clampf(float(now - _msec) / 1000.0, 0.0, 0.1) if _msec > 0 else 0.0
	_msec = now
	var speed: float = calm
	var dir := Vector2(0.82, 0.57)
	var g: float = 0.0
	if wind != null and is_instance_valid(wind):
		var d: Vector4 = wind.call("world_direction")
		var local_d: Vector4 = global_basis.inverse() * d
		if Vector2(local_d.x, local_d.z).length() > 0.01:
			dir = Vector2(local_d.x, local_d.z).normalized()
		speed = float(wind.get("speed")) * 0.35
		if float(wind.get("gust_front")) > -999.0:
			g = float(wind.call("_strength"))
	var target: float = speed * (1.0 + g * 3.0)
	_wind_now = target if _wind_now < 0.0 else lerpf(_wind_now, target, clampf(delta * 1.5, 0.0, 1.0))
	_travel += _wind_now * delta
	var up: int = clampi(roundi(float(amount) * (1.0 + gust_extra * clampf(g * 2.0, 0.0, 1.0))), 0, MAX)
	RenderingServer.multimesh_set_visible_instances(_multimesh, up)
	_material.set_shader_parameter("frame", PackedVector4Array([basis.x, basis.y, basis.z, basis.w, origin, here, normal]))
	_material.set_shader_parameter("wind_dir", dir)
	_material.set_shader_parameter("wind_now", _wind_now)
	_material.set_shader_parameter("travel", _travel)
	prerender_usec = Time.get_ticks_usec() - started


func _exit_tree() -> void:
	if _instance.is_valid():
		RenderingServer.instance_set_visible(_instance, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if RenderingServer4D.pre_render.is_connected(_on_pre_render):
			RenderingServer4D.pre_render.disconnect(_on_pre_render)
		if _instance.is_valid():
			RenderingServer.free_rid(_instance)
		if _multimesh.is_valid():
			RenderingServer.free_rid(_multimesh)
