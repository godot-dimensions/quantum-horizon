extends Node4D

## BOTANY LAB, round 3 (follow_up/arboretum.md section 9, steps 19-22): the flower room's small foliage,
## the pen's trick (flora_sprigs.gdshader: one 3D MultiMesh in the Cross-section engine's World3D, moved
## into the camera's frame each render, every piece drawn where your slice crosses its spot and shrunk
## by how far that is from its home in W). Ivy leaves, grass blades, wisteria florets and little
## wildflowers, tens of thousands for a few hundredths of a millisecond.
##
## Add pieces with add() (in this node's x, y, z: where its stalk is, which way it runs, which way it
## faces, how long it is), then commit() once. The room's wind (`wind`, wind_4d.gd) makes them flutter,
## more in a gust.
##
## NO class_name (engine_gotchas.md).

const SprigShader := preload("res://ramon/Arboretum/botany_lab/flora/flora_sprigs.gdshader")
const MAX := 160000

enum {LEAF, BLADE, FLORET, PETAL, STEM}

## How far either side of its home in W a piece shows, metres.
@export var w_radius: float = 0.7
## Colours: [a, b] a kind.
@export var colours: Dictionary = {}

var wind: Node = null
var prerender_usec: int = 0
var _xf := PackedFloat32Array()
var _n: int = 0
var _instance := RID()
var _multimesh := RID()
var _mesh: ArrayMesh
var _material: ShaderMaterial
var _scenario := RID()
var _was_shown: bool = true
var _gust: float = 0.0


func _ready() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(-0.02, 0.02, 0), Vector3(0.02, 0.02, 0), Vector3(0, 0.04, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(-1.0, 0.45), Vector2(1.0, 0.45), Vector2(0.0, 1.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 3, 0, 3, 2])
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_material = ShaderMaterial.new()
	_material.shader = SprigShader
	_material.set_shader_parameter("w_radius", w_radius)
	for k in colours:
		var pair: Array = colours[k]
		_material.set_shader_parameter(String(k) + "_a", _v3(pair[0]))
		_material.set_shader_parameter(String(k) + "_b", _v3(pair[1]))
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


static func _v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## One piece: its stalk at `at`, running along `along`, its face toward `facing` (made square to
## along), `length` long; `pick` its colour between the kind's two, `flutter` 0..1, `home_w` its home
## in W.
func add(kind: int, at: Vector3, along: Vector3, facing: Vector3, length: float, pick: float, flutter: float, home_w: float) -> void:
	if _n >= MAX:
		return
	var y: Vector3 = along.normalized()
	var z: Vector3 = facing - y * facing.dot(y)
	if z.length() < 0.001:
		z = y.cross(Vector3.RIGHT) if absf(y.x) < 0.9 else y.cross(Vector3.UP)
	z = z.normalized()
	var x: Vector3 = y.cross(z).normalized()
	var b := Basis(x * length, y * length, z * length)
	# A Transform3D as the multimesh buffer keeps it: three rows of basis and origin, then the custom data.
	_xf.append_array([b.x.x, b.y.x, b.z.x, at.x, b.x.y, b.y.y, b.z.y, at.y, b.x.z, b.y.z, b.z.z, at.z,
		float(kind), pick, flutter, home_w])
	_n += 1


func count() -> int:
	return _n


## Uploads every piece added.
func commit() -> void:
	if _multimesh.is_valid():
		RenderingServer.free_rid(_multimesh)
	if _instance.is_valid():
		RenderingServer.free_rid(_instance)
	_multimesh = RenderingServer.multimesh_create()
	RenderingServer.multimesh_set_mesh(_multimesh, _mesh.get_rid())
	RenderingServer.multimesh_allocate_data(_multimesh, maxi(_n, 1), RenderingServer.MULTIMESH_TRANSFORM_3D, false, true)
	if _n > 0:
		RenderingServer.multimesh_set_buffer(_multimesh, _xf)
	RenderingServer.multimesh_set_visible_instances(_multimesh, _n)
	_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_instance, _multimesh)
	RenderingServer.instance_geometry_set_material_override(_instance, _material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_ignore_culling(_instance, true)
	RenderingServer.instance_set_custom_aabb(_instance, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	if _scenario.is_valid():
		RenderingServer.instance_set_scenario(_instance, _scenario)
	RenderingServer.instance_set_visible(_instance, _scenario.is_valid() and is_visible_in_tree())


func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	if not _instance.is_valid():
		return
	var shown: bool = is_visible_in_tree()
	if shown != _was_shown:
		_was_shown = shown
		RenderingServer.instance_set_visible(_instance, shown and _scenario.is_valid())
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
		RenderingServer.instance_set_visible(_instance, true)
	var inverse: Projection = camera.global_basis.inverse()
	var basis: Projection = inverse * global_basis
	var origin: Vector4 = inverse * (global_position - camera.global_position)
	var here: Vector4 = global_basis.inverse() * (camera.global_position - global_position)
	var normal: Vector4 = (global_basis.inverse() * camera.global_basis.w).normalized()
	_material.set_shader_parameter("frame", PackedVector4Array([basis.x, basis.y, basis.z, basis.w, origin, here, normal]))
	var speed: float = 1.0
	var g: float = 0.0
	if wind != null and is_instance_valid(wind):
		speed = float(wind.get("speed"))
		if float(wind.get("gust_front")) > -999.0:
			g = float(wind.call("_strength"))
	_gust = lerpf(_gust, g, 0.08)
	_material.set_shader_parameter("wind_now", speed)
	_material.set_shader_parameter("gust", _gust)
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
