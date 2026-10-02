extends Node4D

## Grass over the pen's field: a few hundred thousand blades round the camera, built and blown
## about entirely on the GPU (pen_grass.gdshader), cut by the slice like everything else.
## follow_up/grass_study.md is the case study it comes from.
##
## WHAT THIS NODE DOES, AND ALL IT DOES. The blades have no stored positions: the shader makes
## each from its instance number, round wherever the camera is. So this script only
##   - builds two blade meshes (15 vertices near, 7 far) and two MultiMeshes of N instances,
##     drawn by RenderingServer into the Cross-section engine's own World3D, as the flock is;
##   - every render, hands the shader the camera's frame (pre_render, as the flock does), and
##     the people and animals that push the grass aside;
##   - once, after the scene is up, builds the MASK: for each half metre of the field, up to two
##     stretches of W where something stands on the ground - a floor, a pond, a hill - so no
##     blade grows inside it. From the real geometry: every tetrahedron of every still thing that
##     touches the ground marks the cells under it with its W reach; the hills come from the
##     Lookout's height map (lookout_ground_4d.gd). It runs a few thousand cells at a time, and
##     the grass grows in when it is done.
##
## COST, by design: no script work per frame beyond a dozen uniforms; the GPU does
## near_cells^2 x layers x 15 + far_cells^2 x layers x 7 vertices (see _measure_grass_runner.gd).

const SHADER := preload("res://ramon/chickenpen/grass/pen_grass.gdshader")
const GROUND := preload("res://ramon/chickenpen/lookout/lookout_ground_4d.gd")

@export var enabled: bool = true:
	set(v):
		enabled = v
		_set_visible()

@export_group("Rings")
@export_range(0.04, 0.5, 0.005, "suffix:m") var near_spacing: float = 0.085
@export_range(3.0, 30.0, 0.5, "suffix:m") var near_radius: float = 12.0
@export_range(0.1, 1.0, 0.01, "suffix:m") var far_spacing: float = 0.32
@export_range(10.0, 80.0, 1.0, "suffix:m") var far_radius: float = 44.0
## Blades stacked along W at each spot, and how far apart.
@export_range(1, 5) var layers: int = 3
@export_range(0.05, 1.0, 0.01, "suffix:m") var layer_spacing: float = 0.22
## How thick in W a blade is: within this of the slice, some of it shows.
@export_range(0.05, 1.0, 0.01, "suffix:m") var w_radius: float = 0.3

@export_group("Blades")
@export_range(0.05, 2.0, 0.01, "suffix:m") var blade_height: float = 0.5
@export_range(0.005, 0.2, 0.001, "suffix:m") var blade_width: float = 0.016
@export_range(0.005, 0.3, 0.001, "suffix:m") var far_blade_width: float = 0.045
@export_range(0.3, 5.0, 0.05, "suffix:m") var clump_size: float = 1.3
@export var colour_root: Color = Color(0.07, 0.10, 0.05)
@export var colour_base: Color = Color(0.20, 0.31, 0.12)
@export var colour_lush: Color = Color(0.14, 0.30, 0.13)
@export var colour_dry: Color = Color(0.47, 0.44, 0.22)
@export var colour_tip: Color = Color(0.46, 0.55, 0.24)
## The field's own colour (the pen's ground material): what the ring's edge turns into.
@export var ground_colour: Color = Color(0.16, 0.22, 0.11)

@export_group("Wind")
@export var wind_direction: Vector2 = Vector2(0.82, 0.57)
## The mean wind, m/s (3 is a light breeze), and how gusty (0 steady, 1 squally).
@export_range(0.0, 15.0, 0.1, "suffix:m/s") var wind_speed: float = 3.0
@export_range(0.0, 1.0, 0.01) var gustiness: float = 0.55
## A gust band's length down the wind and across it.
@export_range(1.0, 40.0, 0.5, "suffix:m") var gust_length: float = 7.0
@export_range(1.0, 60.0, 0.5, "suffix:m") var gust_width: float = 18.0
## How far over the strongest gust lays a blade, and the wind pressure ((m/s)^2) that lays it
## half way.
@export_range(0.0, 0.95, 0.01) var bend_max: float = 0.42
@export_range(1.0, 200.0, 0.5) var stiffness: float = 30.0
@export_range(0.0, 1.0, 0.01) var sheen: float = 0.2
## The blade grid is centred this share of its radius ahead of the camera, so little is made
## behind it, where it is never seen; its half-size is (1 - this / 2) of the radius.
@export_range(0.0, 0.6, 0.01) var grid_ahead: float = 0.3

@export_group("Ground")
## The pen's ground slab reaches this far in x, z and w (chickenpen.tscn: 120 m a side).
@export var ground_extent: float = 59.0
## Things whose subtree is never part of the mask: they move, or they are the ground itself.
@export var mask_skip: PackedStringArray = PackedStringArray(["Ground", "Hills", "CaveHill", "Flock", "Chickens", "Player", "Mithra",
	"Nike", "Cat", "RedCat", "Crow", "Crow2", "Crow3", "Trym", "Professor", "Keeper", "RangeMaster", "Wren", "AnaOwl", "AnaHeron",
	"Chipmunk0", "Chipmunk1", "Chipmunk2", "Balloon", "Grass", "UI"])

var mask_ready: bool = false
## Mask cells marked, and how long the mask took, for runners.
var mask_cells: int = 0
var mask_msec: int = 0

var _material_near: ShaderMaterial
var _material_far: ShaderMaterial
var _meshes: Array = []
var _multimeshes: Array = []
var _instances: Array = []
var _scenario := RID()
var _mask_image: Image
var _mask_texture: ImageTexture
var _pushers: Array[Node4D] = []
var _room: Node

const MASK_CELL := 0.5
const MASK_CELLS := 240


func _ready() -> void:
	_room = owner if owner != null else get_parent().get_parent()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var wind := NoiseTexture2D.new()
	wind.width = 256
	wind.height = 256
	wind.seamless = true
	wind.noise = noise
	_mask_image = Image.create_empty(MASK_CELLS, MASK_CELLS, false, Image.FORMAT_RGBAF)
	_mask_image.fill(Color(1e4, -1e4, 1e4, -1e4))
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	_material_near = _material(wind, near_spacing, near_radius, 0.0, blade_width)
	_material_far = _material(wind, far_spacing, far_radius, near_radius - 5.0, far_blade_width)
	_add_ring(_material_near, near_spacing, near_radius, 11)
	_add_ring(_material_far, far_spacing, far_radius, 7)
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)
	_set_visible()
	_find_pushers.call_deferred()
	_build_mask.call_deferred()


func _material(wind: Texture2D, spacing: float, radius: float, inner: float, width: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("spacing", spacing)
	m.set_shader_parameter("cells", _cells(spacing, radius))
	m.set_shader_parameter("layers", layers)
	m.set_shader_parameter("layer_spacing", layer_spacing)
	m.set_shader_parameter("w_radius", w_radius)
	m.set_shader_parameter("radius_in", inner)
	# The near ring thins out over its last five metres while the far one thins in over the
	# same five; the far one thins out over its last third into the bare field.
	m.set_shader_parameter("radius_in_band", 5.0)
	m.set_shader_parameter("radius_out", radius)
	m.set_shader_parameter("radius_out_band", 5.0 if inner <= 0.0 else radius * 0.35)
	m.set_shader_parameter("blade_height", blade_height)
	m.set_shader_parameter("blade_width", width)
	m.set_shader_parameter("ground_extent", ground_extent)
	m.set_shader_parameter("clump_size", clump_size)
	m.set_shader_parameter("mask", _mask_texture)
	m.set_shader_parameter("mask_rect", Vector4(-MASK_CELL * MASK_CELLS * 0.5, -MASK_CELL * MASK_CELLS * 0.5, MASK_CELL, float(MASK_CELLS)))
	m.set_shader_parameter("wind_noise", wind)
	m.set_shader_parameter("wind_dir", wind_direction.normalized())
	m.set_shader_parameter("wind_speed", wind_speed)
	m.set_shader_parameter("gustiness", gustiness)
	m.set_shader_parameter("gust_length", gust_length)
	m.set_shader_parameter("gust_width", gust_width)
	m.set_shader_parameter("bend_max", bend_max)
	m.set_shader_parameter("stiffness", stiffness)
	m.set_shader_parameter("sheen", sheen)
	for key in ["colour_root", "colour_base", "colour_lush", "colour_dry", "colour_tip", "ground_colour"]:
		var c: Color = get(key)
		m.set_shader_parameter(key, Vector3(c.r, c.g, c.b))
	return m


func _cells(spacing: float, radius: float) -> int:
	return int(ceil(radius * 2.0 * (1.0 - grid_ahead * 0.5) / spacing))


## A blade: pairs of vertices up its length, closer together towards the tip where it bends,
## and the tip. UV is (side -1 / +1 / 0, t from root to tip); the shader does the rest.
func _blade_mesh(vertices: int) -> ArrayMesh:
	var levels: int = (vertices - 1) / 2
	var uv := PackedVector2Array()
	var pos := PackedVector3Array()
	for i in levels:
		var t: float = 1.0 - pow(1.0 - float(i) / float(levels), 1.25)
		for side in [-1.0, 1.0]:
			uv.append(Vector2(side, t))
			pos.append(Vector3(side * 0.02, t * 0.4, 0.0))
	uv.append(Vector2(0.0, 1.0))
	pos.append(Vector3(0.0, 0.4, 0.0))
	var index := PackedInt32Array()
	for i in levels - 1:
		var a: int = i * 2
		index.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var last: int = (levels - 1) * 2
	index.append_array([last, last + 1, vertices - 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_ring(material: ShaderMaterial, spacing: float, radius: float, vertices: int) -> void:
	var mesh := _blade_mesh(vertices)
	var count: int = _cells(spacing, radius) * _cells(spacing, radius) * layers
	var mm := RenderingServer.multimesh_create()
	RenderingServer.multimesh_set_mesh(mm, mesh.get_rid())
	RenderingServer.multimesh_allocate_data(mm, count, RenderingServer.MULTIMESH_TRANSFORM_3D, false, false)
	var inst := RenderingServer.instance_create()
	RenderingServer.instance_set_base(inst, mm)
	RenderingServer.instance_geometry_set_material_override(inst, material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(inst, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	# Its transforms are unused - the shader places every blade - so its bounds are anywhere.
	RenderingServer.instance_set_ignore_culling(inst, true)
	RenderingServer.instance_set_custom_aabb(inst, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(inst, false)
	_meshes.append(mesh)
	_multimeshes.append(mm)
	_instances.append(inst)


func blade_count() -> int:
	return (_cells(near_spacing, near_radius) * _cells(near_spacing, near_radius) + _cells(far_spacing, far_radius) * _cells(far_spacing, far_radius)) * layers


func _set_visible() -> void:
	for inst in _instances:
		RenderingServer.instance_set_visible(inst, enabled and mask_ready and _scenario.is_valid() and is_visible_in_tree())


func _exit_tree() -> void:
	for inst in _instances:
		RenderingServer.instance_set_visible(inst, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if RenderingServer4D.pre_render.is_connected(_on_pre_render):
			RenderingServer4D.pre_render.disconnect(_on_pre_render)
		for inst in _instances:
			RenderingServer.free_rid(inst)
		for mm in _multimeshes:
			RenderingServer.free_rid(mm)


## The camera's frame for the shader, every render; the instances into whichever World3D the
## cut is drawn in (the Combined renderer's is a SubViewport two deep).
func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	if viewport != get_viewport() or _instances.is_empty():
		return
	var world: World3D = viewport.find_world_3d()
	if engine != null and engine.get_friendly_name() == "Combined":
		var inner := viewport.get_node_or_null(^"CombinedProjectedSubViewport4D/CombinedCrossSectionSubViewport4D") as Viewport
		if inner != null:
			world = inner.find_world_3d()
	var scenario: RID = world.scenario if world != null else RID()
	if scenario != _scenario:
		_scenario = scenario
		for inst in _instances:
			RenderingServer.instance_set_scenario(inst, scenario)
		_set_visible()
	var inverse: Projection = camera.global_basis.inverse()
	var basis: Projection = inverse * global_basis
	var origin: Vector4 = inverse * (global_position - camera.global_position)
	var here: Vector4 = global_basis.inverse() * (camera.global_position - global_position)
	var normal: Vector4 = (global_basis.inverse() * camera.global_basis.w).normalized()
	var pushers := PackedVector4Array()
	for p in _pushers:
		if is_instance_valid(p) and p.is_visible_in_tree() and pushers.size() < 16:
			var at: Vector4 = global_basis.inverse() * (p.global_position - global_position)
			if Vector2(at.x - here.x, at.z - here.z).length() < near_radius + 2.0:
				pushers.append(at)
	var ahead: Vector4 = global_basis.inverse() * (camera.global_basis * Vector4(0.0, 0.0, -1.0, 0.0))
	var flat := Vector2(ahead.x, ahead.z)
	flat = flat.normalized() if flat.length() > 0.05 else Vector2.ZERO
	_material_near.set_shader_parameter("grid_shift", flat * near_radius * grid_ahead)
	_material_far.set_shader_parameter("grid_shift", flat * far_radius * grid_ahead)
	# The view's half-width, as a tangent, with a margin: blades off the sides are dropped early.
	var view: Vector2 = viewport.get_visible_rect().size
	var fov: float = float(camera.get("field_of_view_4d")) if int(camera.get("projection_type")) == 1 else float(camera.get("field_of_view_3d"))
	var frustum_x: float = tan(fov * 0.5) * view.x / maxf(view.y, 1.0) * 1.15
	_material_near.set_shader_parameter("frustum_x", frustum_x)
	_material_far.set_shader_parameter("frustum_x", frustum_x)
	for m in [_material_near, _material_far]:
		m.set_shader_parameter("view_basis_x", basis.x)
		m.set_shader_parameter("view_basis_y", basis.y)
		m.set_shader_parameter("view_basis_z", basis.z)
		m.set_shader_parameter("view_basis_w", basis.w)
		m.set_shader_parameter("view_origin", origin)
		m.set_shader_parameter("camera_world", here)
		m.set_shader_parameter("slice_normal", normal)
		m.set_shader_parameter("pushers", pushers)
		m.set_shader_parameter("pusher_count", pushers.size())


## The player, the chickens, Nike, the cats, the people: whoever walks through the grass.
func _find_pushers() -> void:
	_pushers.clear()
	for path in ["Player", "Mithra", "World/Nike", "World/Cat", "World/RedCat", "World/Trym", "World/Professor", "World/Keeper",
			"World/LookoutSite/Wren", "World/RangeMaster"]:
		var n := _room.get_node_or_null(path) as Node4D
		if n != null:
			_pushers.append(n)
	var chickens: Node = _room.get_node_or_null("Chickens")
	if chickens != null:
		for c in chickens.get_children():
			if c is Node4D:
				_pushers.append(c)


# --- The mask ----------------------------------------------------------------------------------

## Built once, a slice at a time, after everything is in the scene (the Lookout builds its
## marsh, wood and trees in its _ready). Then the grass grows in.
func _build_mask() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var started: int = Time.get_ticks_msec()
	var data := PackedFloat32Array()
	data.resize(MASK_CELLS * MASK_CELLS * 4)
	for i in MASK_CELLS * MASK_CELLS:
		data[i * 4] = 1e4
		data[i * 4 + 1] = -1e4
		data[i * 4 + 2] = 1e4
		data[i * 4 + 3] = -1e4
	var meshes: Array = []
	_collect(_room, meshes)
	var budget: int = 0
	for mi in meshes:
		budget += _mark_mesh(mi, data)
		if budget > 6000:
			budget = 0
			await get_tree().process_frame
	# The hills and the cave hill, from the Lookout's height map at the farm's w.
	var ground: RefCounted = GROUND.build(_room, 0.0, 3.0)
	var half: float = MASK_CELL * MASK_CELLS * 0.5
	for j in MASK_CELLS:
		for i in MASK_CELLS:
			var x: float = -half + (float(i) + 0.5) * MASK_CELL
			var z: float = -half + (float(j) + 0.5) * MASK_CELL
			if float(ground.call("height", x, z)) > 0.3:
				_mark(data, i, j, -3.5, 3.5)
	_mask_image = Image.create_from_data(MASK_CELLS, MASK_CELLS, false, Image.FORMAT_RGBAF, data.to_byte_array())
	_mask_texture.update(_mask_image)
	mask_cells = 0
	for i in MASK_CELLS * MASK_CELLS:
		if data[i * 4] < data[i * 4 + 1]:
			mask_cells += 1
	mask_msec = Time.get_ticks_msec() - started
	mask_ready = true
	_set_visible()


func _collect(node: Node, out: Array) -> void:
	if node != _room and (mask_skip.has(String(node.name)) or node is CharacterBody4D):
		return
	if node is MeshInstance4D and (node as MeshInstance4D).mesh is TetraMesh4D and (node as MeshInstance4D).is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


## Every tetrahedron of [param mi] that touches the ground and stays low (a floor, a pond, the
## foot of a wall - not a whole leg of the tower) marks the cells under it with its W reach.
## Returns how many tetrahedra it looked at.
func _mark_mesh(mi: MeshInstance4D, data: PackedFloat32Array) -> int:
	var mesh: TetraMesh4D = mi.mesh as TetraMesh4D
	var rb: PackedVector4Array = mesh.get_rect_bounds()
	var basis: Projection = mi.global_basis
	var origin: Vector4 = mi.global_position
	var lo_y: float = INF
	var hi_y: float = -INF
	for c in 16:
		var corner := rb[0] + Vector4(rb[1].x if c & 1 else 0.0, rb[1].y if c & 2 else 0.0, rb[1].z if c & 4 else 0.0, rb[1].w if c & 8 else 0.0)
		var p: Vector4 = basis * corner + origin
		lo_y = minf(lo_y, p.y)
		hi_y = maxf(hi_y, p.y)
	if lo_y > 0.45 or hi_y < 0.0:
		return 1
	var cells: PackedVector4Array = mesh.get_simplex_cell_positions()
	var half: float = MASK_CELL * MASK_CELLS * 0.5
	var k: int = 0
	while k + 3 < cells.size():
		var a: Vector4 = basis * cells[k] + origin
		var b: Vector4 = basis * cells[k + 1] + origin
		var c: Vector4 = basis * cells[k + 2] + origin
		var d: Vector4 = basis * cells[k + 3] + origin
		k += 4
		var lo: Vector4 = a.min(b).min(c.min(d))
		var hi: Vector4 = a.max(b).max(c.max(d))
		if lo.y > 0.45 or hi.y < 0.0 or hi.y > 1.3:
			continue
		var i0: int = clampi(int(floor((lo.x + half) / MASK_CELL)), 0, MASK_CELLS - 1)
		var i1: int = clampi(int(floor((hi.x + half) / MASK_CELL)), 0, MASK_CELLS - 1)
		var j0: int = clampi(int(floor((lo.z + half) / MASK_CELL)), 0, MASK_CELLS - 1)
		var j1: int = clampi(int(floor((hi.z + half) / MASK_CELL)), 0, MASK_CELLS - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				_mark(data, i, j, lo.w, hi.w)
	return cells.size() / 4


## Adds the W stretch [param a]..[param b] to cell (i, j): joined to a stretch it touches, or in
## the empty slot, or (both slots taken) to the nearer.
func _mark(data: PackedFloat32Array, i: int, j: int, a: float, b: float) -> void:
	var o: int = (j * MASK_CELLS + i) * 4
	for slot in [0, 2]:
		var lo: float = data[o + slot]
		var hi: float = data[o + slot + 1]
		if lo > hi:
			data[o + slot] = a
			data[o + slot + 1] = b
			return
		if a < hi + 1.0 and b > lo - 1.0:
			data[o + slot] = minf(lo, a)
			data[o + slot + 1] = maxf(hi, b)
			return
	var mid: float = (a + b) * 0.5
	var d0: float = absf(mid - (data[o] + data[o + 1]) * 0.5)
	var d1: float = absf(mid - (data[o + 2] + data[o + 3]) * 0.5)
	var s: int = 0 if d0 <= d1 else 2
	data[o + s] = minf(data[o + s], a)
	data[o + s + 1] = maxf(data[o + s + 1], b)
