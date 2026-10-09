extends Node4D

## WATER LAB: the tank's water (tank/tank_water.gdshader), a full-screen pass in the Cross-section
## engine's own World3D, added through RenderingServer as the pen's flock and Trym's sea are. This
## node sits at the middle of the water; every frame, just before the 4D engine draws, it hands the
## shader the camera's frame in its own (the shader meets every view ray with the water as a 4D box
## there), and the clock its ripples, caustics and shafts run on.
##
## A QUAD THAT COVERS THE SCREEN, NOT A BOX: the cut of a 4D box by a turned slice is not a box, and
## the shader works it out per pixel instead. Pixels whose ray misses the water, or meets something
## in front of it (you, walking past the glass), are discarded.
##
## NO class_name (engine_gotchas.md).

const SHADER := preload("res://ramon/WaterLab/tank/tank_water.gdshader")

## The water's half extents (x, y, z, W) about this node; y's top is the surface.
var half_extents: Vector4 = Vector4(6.0, 2.1, 1.6, 1.6)
## Toward the light, in this node's frame (the shafts lean away from it; the glints use it).
var light_dir: Vector3 = Vector3(0.25, 1.0, 0.15)
var clarity: float = 1.0
var caustics: float = 0.85
var shafts: float = 0.35
var ripples: float = 1.0

var _mesh: QuadMesh
var _material: ShaderMaterial
var _instance := RID()
var _scenario := RID()
var _time: float = 0.0


func _ready() -> void:
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(2.0, 2.0)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_instance, _mesh.get_rid())
	RenderingServer.instance_geometry_set_material_override(_instance, _material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_ignore_culling(_instance, true)
	RenderingServer.instance_set_custom_aabb(_instance, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(_instance, false)
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _instance.is_valid():
		RenderingServer.free_rid(_instance)


func _process(delta: float) -> void:
	# Accumulated and wrapped, not a clock: a large time loses precision in the shader's noise.
	_time = fposmod(_time + delta, 4096.0)


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
	var shown: bool = is_visible_in_tree() and scenario.is_valid()
	RenderingServer.instance_set_visible(_instance, shown)
	if not shown:
		return
	var inv: Projection = global_basis.inverse()
	var to_tank: Projection = inv * camera.global_basis
	var origin: Vector4 = inv * (camera.global_position - global_position)
	_material.set_shader_parameter(&"to_tank_x", to_tank.x)
	_material.set_shader_parameter(&"to_tank_y", to_tank.y)
	_material.set_shader_parameter(&"to_tank_z", to_tank.z)
	_material.set_shader_parameter(&"to_tank_w", to_tank.w)
	_material.set_shader_parameter(&"cam_in_tank", origin)
	_material.set_shader_parameter(&"half_ext", half_extents)
	_material.set_shader_parameter(&"water_time", _time)
	_material.set_shader_parameter(&"light_dir", light_dir.normalized())
	_material.set_shader_parameter(&"absorption", Vector3(0.26, 0.065, 0.045) / maxf(clarity, 0.05))
	_material.set_shader_parameter(&"caustic_strength", caustics)
	_material.set_shader_parameter(&"shaft_strength", shafts)
	_material.set_shader_parameter(&"ripple_strength", ripples)


## Where the camera is in the water's frame (the koi come to the glass in front of you).
func to_local_point(world_point: Vector4) -> Vector4:
	return global_basis.inverse() * (world_point - global_position)
