extends Node4D

## The Arboretum: a tree's leaves, the "smart fakery" the pen's grass uses (chickenpen/grass/,
## follow_up/grass_study.md) turned to foliage. Not one leaf is a tetrahedron: each is an ordinary
## 3D leaf card in the cross-section renderer's own World3D, placed every frame by its shader
## (shaders/botany_leaf.gdshader) from where it is in 4D, so tens of thousands cost a fraction of a
## millisecond. This node makes the leaves from a skeleton, keeps them in float textures, and hands
## the shader the camera's frame every render (RenderingServer4D.pre_render, as the grass does).
##
## WHERE LEAVES GROW (grow_leaves()): round every node that carries few twigs (the outer branches),
## more of them the nearer a twig's end, scattered in a 4D ball round it and a little beyond it along
## its branch, as an oak's leaves crowd the ends of its shoots. Each leaf's 4D normal leans up and out
## of the crown (Runions et al. turn their leaves toward the horizontal) with a random part, W
## included, so the crown is full from every slice. Each leaf knows its twig, for the wind, and a
## birth (its twig's place in the growth order), for growing in.
##
## The tree node this hangs under is the leaves' frame: move or turn the tree and they follow.
##
## NO class_name (engine_gotchas.md).

const Pivots := preload("res://ramon/Arboretum/botany/tree_pivots.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const LeafShader := preload("res://ramon/Arboretum/shaders/botany_leaf.gdshader")

## Leaves round each outer node, and how far round it (m).
@export var per_node: int = 26
@export var spread: float = 0.42
## Which nodes carry leaves: those carrying at most this many twigs.
@export var leafy_twigs: int = 3
## A leaf's length (m) and how deep it is in W either side (m).
@export var leaf_size: float = 0.16
@export var leaf_w: float = 0.12
@export var crown_normals: float = 0.65
@export var enabled: bool = true:
	set(v):
		enabled = v
		_set_visible()

var material: ShaderMaterial
var count: int = 0
var build_ms: float = 0.0
var _mesh: ArrayMesh
var _mm := RID()
var _inst := RID()
var _scenario := RID()
var _height: float = 7.0
var _was_shown: bool = true


## The oak leaf, one unit long from its stalk (y -0.5) to its tip (y +0.5): lobed edges, widest past
## the middle (an oak's leaf is obovate), a short stalk; UV.x is -1 at the left edge, 0 on the
## midrib, +1 at the right, for the vein. Three vertices per station along the midrib, and every
## vertex runs the whole wind chain in the shader: 15 stations (45 vertices) made 77,000 leaves cost
## about 1.4 ms of GPU; 8 keep the lobes (the lobe wave lands on alternate stations) at half that.
static func leaf_mesh(stations: int = 8) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in stations:
		var t: float = float(i) / float(stations - 1)
		var y: float = lerpf(-0.5, 0.5, t)
		var env: float = pow(sin(PI * clampf((t - 0.06) / 0.94, 0.0, 1.0)), 0.75) * (0.55 + 0.45 * t)
		var lobes: float = 0.72 + 0.28 * cos(TAU * 3.5 * t)
		var w: float = 0.36 * env * lobes
		verts.append(Vector3(0.0, y, 0.0))
		uvs.append(Vector2(0.0, t))
		verts.append(Vector3(-w, y + 0.04 * w, 0.0))
		uvs.append(Vector2(-1.0, t))
		verts.append(Vector3(w, y + 0.04 * w, 0.0))
		uvs.append(Vector2(1.0, t))
	for i in stations - 1:
		var a: int = i * 3
		var b: int = (i + 1) * 3
		idx.append_array([a, a + 1, b + 1, a, b + 1, b])
		idx.append_array([a, b, b + 2, a, b + 2, a + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var normals := PackedVector3Array()
	for v in verts:
		normals.append(Vector3(0, 0, 1))
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Makes the leaves of skeleton `sk`; `seed` varies them.
func grow_leaves(sk: Resource, seed: int = 3) -> void:
	var t0: int = Time.get_ticks_usec()
	var positions: PackedVector4Array = sk.get("positions")
	var twigs: PackedInt32Array = sk.get("twigs")
	var node_branch: PackedInt32Array = sk.get("node_branch")
	var node_along: PackedFloat32Array = sk.get("node_along")
	var parents: PackedInt32Array = sk.get("parents")
	var bb: Dictionary = sk.call("bounds")
	var lo: Vector4 = bb["min"]
	var hi: Vector4 = bb["max"]
	_height = hi.y
	# The crown's middle: the middle of the outer nodes.
	var centre := Vector4.ZERO
	var outer: int = 0
	for i in positions.size():
		if twigs[i] <= leafy_twigs:
			centre += positions[i]
			outer += 1
	centre = centre / maxf(float(outer), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pos := PackedVector4Array()
	var nrm := PackedVector4Array()
	var mid := PackedVector4Array()
	var info := PackedVector4Array()
	var n_nodes: float = maxf(float(positions.size()), 1.0)
	for i in positions.size():
		if twigs[i] > leafy_twigs:
			continue
		var p: Vector4 = positions[i]
		var along_dir := Vector4(0, 1, 0, 0)
		if parents[i] >= 0:
			var d: Vector4 = p - positions[parents[i]]
			if d.length() > 0.0001:
				along_dir = d.normalized()
		var tipness: float = 1.0 if twigs[i] == 1 else 0.6
		var k: int = int(round(float(per_node) * tipness))
		for j in k:
			var off := Vector4(rng.randfn(), rng.randfn(), rng.randfn(), rng.randfn()).normalized() * spread * pow(rng.randf(), 0.6)
			var c: Vector4 = p + off + along_dir * spread * rng.randf_range(0.0, 0.5)
			var outward: Vector4 = c - centre
			outward = outward.normalized() if outward.length() > 0.0001 else Vector4(0, 1, 0, 0)
			var n: Vector4 = (Vector4(0, 1, 0, 0) * 0.7 + outward * 0.6 + Vector4(rng.randfn(), rng.randfn(), rng.randfn(), rng.randfn()) * 0.55).normalized()
			# The midrib: square to the normal, leaning out along the shoot.
			var m: Vector4 = along_dir + Vector4(rng.randfn(), rng.randfn(), rng.randfn(), rng.randfn()) * 0.6
			m = m - n * m.dot(n)
			if m.length() < 0.0001:
				m = Vector4(1, 0, 0, 0) - n * n.x
			m = m.normalized()
			pos.append(c)
			nrm.append(n)
			mid.append(m)
			info.append(Vector4(float(node_branch[i]), node_along[i], rng.randf(), clampf(float(i) / n_nodes * 0.85 + rng.randf() * 0.12, 0.0, 1.0)))
	count = pos.size()
	_upload(pos, nrm, mid, info, sk, centre)
	build_ms = (Time.get_ticks_usec() - t0) / 1000.0


## A row of 1024 leaves a texel each, from one float array (a texel per set_pixel was the slow part
## at a hundred thousand leaves).
func _texture(data: PackedVector4Array) -> ImageTexture:
	var rows: int = maxi(1, int(ceil(float(data.size()) / 1024.0)))
	var f := PackedFloat32Array()
	f.resize(1024 * rows * 4)
	for i in data.size():
		var v: Vector4 = data[i]
		var o: int = i * 4
		f[o] = v.x
		f[o + 1] = v.y
		f[o + 2] = v.z
		f[o + 3] = v.w
	var img := Image.create_from_data(1024, rows, false, Image.FORMAT_RGBAF, f.to_byte_array())
	return ImageTexture.create_from_image(img)


func _upload(pos: PackedVector4Array, nrm: PackedVector4Array, mid: PackedVector4Array, info: PackedVector4Array, sk: Resource, centre: Vector4) -> void:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = LeafShader
	material.set_shader_parameter("leaf_pos", _texture(pos))
	material.set_shader_parameter("leaf_nrm", _texture(nrm))
	material.set_shader_parameter("leaf_mid", _texture(mid))
	material.set_shader_parameter("leaf_info", _texture(info))
	material.set_shader_parameter("leaf_count", pos.size())
	material.set_shader_parameter("leaf_size", leaf_size)
	material.set_shader_parameter("leaf_w", leaf_w)
	material.set_shader_parameter("crown_centre", centre)
	material.set_shader_parameter("crown_normals", crown_normals)
	material.set_shader_parameter("tree_height", _height)
	material.set_shader_parameter("leaf_color", Style.LEAF)
	material.set_shader_parameter("leaf_alt", Style.LEAF_ALT)
	material.set_shader_parameter("pivot_tex", Pivots.texture(sk))
	material.set_shader_parameter("pivot_count", (sk.get("branches") as Array).size())
	if _mesh == null:
		_mesh = leaf_mesh()
	if not _mm.is_valid():
		_mm = RenderingServer.multimesh_create()
		RenderingServer.multimesh_set_mesh(_mm, _mesh.get_rid())
	RenderingServer.multimesh_allocate_data(_mm, maxi(pos.size(), 1), RenderingServer.MULTIMESH_TRANSFORM_3D, false, false)
	RenderingServer.multimesh_set_visible_instances(_mm, pos.size())
	if not _inst.is_valid():
		_inst = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_inst, _mm)
		RenderingServer.instance_geometry_set_cast_shadows_setting(_inst, RenderingServer.SHADOW_CASTING_SETTING_OFF)
		RenderingServer.instance_set_ignore_culling(_inst, true)
		RenderingServer.instance_set_custom_aabb(_inst, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_geometry_set_material_override(_inst, material.get_rid())
	_scenario = RID()
	_set_visible()
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)
	var wind: Node = load("res://ramon/Arboretum/botany/wind_4d.gd").call("of", get_tree()) if is_inside_tree() else null
	if wind != null:
		wind.call("register", material, self)


## The same leaves as `other` (its textures, its skeleton's branches), in a material of this node's
## own: the grove's oaks share one set of leaves per shape.
func share_from(other: Node) -> void:
	var src: ShaderMaterial = other.get("material")
	if src == null:
		return
	material = src.duplicate() as ShaderMaterial
	count = int(other.get("count"))
	_height = float(other.get("_height"))
	if _mesh == null:
		_mesh = leaf_mesh(6)
	if not _mm.is_valid():
		_mm = RenderingServer.multimesh_create()
		RenderingServer.multimesh_set_mesh(_mm, _mesh.get_rid())
	RenderingServer.multimesh_allocate_data(_mm, maxi(count, 1), RenderingServer.MULTIMESH_TRANSFORM_3D, false, false)
	RenderingServer.multimesh_set_visible_instances(_mm, count)
	if not _inst.is_valid():
		_inst = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_inst, _mm)
		RenderingServer.instance_geometry_set_cast_shadows_setting(_inst, RenderingServer.SHADOW_CASTING_SETTING_OFF)
		RenderingServer.instance_set_ignore_culling(_inst, true)
		RenderingServer.instance_set_custom_aabb(_inst, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_geometry_set_material_override(_inst, material.get_rid())
	_scenario = RID()
	_set_visible()
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)
	var wind: Node = load("res://ramon/Arboretum/botany/wind_4d.gd").call("of", get_tree()) if is_inside_tree() else null
	if wind != null:
		wind.call("register", material, self)


## Growth (0 to 1) and the season (0 summer, 1 autumn, 2 bare).
func set_grow(g: float) -> void:
	if material != null:
		material.set_shader_parameter("grow", g)


func set_season(s: float) -> void:
	if material != null:
		material.set_shader_parameter("season", s)


func _set_visible() -> void:
	if _inst.is_valid():
		RenderingServer.instance_set_visible(_inst, enabled and _scenario.is_valid() and is_visible_in_tree() and count > 0)


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)
	if _inst.is_valid():
		RenderingServer.instance_set_visible(_inst, false)


func _enter_tree() -> void:
	if _mm.is_valid() and not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)
		_scenario = RID()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _inst.is_valid():
			RenderingServer.free_rid(_inst)
		if _mm.is_valid():
			RenderingServer.free_rid(_mm)


## The camera's frame for the shader, every render, and the leaves into whichever World3D the cut is
## drawn in (the Combined renderer's is a SubViewport two deep).
func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	var shown: bool = is_visible_in_tree()
	if shown != _was_shown:
		_was_shown = shown
		_set_visible()
	if not shown or not _inst.is_valid() or viewport != get_viewport():
		return
	var world: World3D = viewport.find_world_3d()
	if engine != null and engine.get_friendly_name() == "Combined":
		var inner := viewport.get_node_or_null(^"CombinedProjectedSubViewport4D/CombinedCrossSectionSubViewport4D") as Viewport
		if inner != null:
			world = inner.find_world_3d()
	var scenario: RID = world.scenario if world != null else RID()
	if scenario != _scenario:
		_scenario = scenario
		RenderingServer.instance_set_scenario(_inst, scenario)
		_set_visible()
	var inverse: Projection = camera.global_basis.inverse()
	var basis: Projection = inverse * global_basis
	var origin: Vector4 = inverse * (global_position - camera.global_position)
	material.set_shader_parameter("frame_x", basis.x)
	material.set_shader_parameter("frame_y", basis.y)
	material.set_shader_parameter("frame_z", basis.z)
	material.set_shader_parameter("frame_w", basis.w)
	material.set_shader_parameter("frame_o", origin)
	material.set_shader_parameter("frame_scale", (global_basis.x as Vector4).length())
