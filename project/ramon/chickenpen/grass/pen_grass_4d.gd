extends Node4D

## Grass over the pen's field: a few hundred thousand blades round you, built and blown about
## entirely on the GPU (pen_grass.gdshader), cut by the slice like everything else.
## follow_up/grass_study.md is the case study it comes from.
##
## WHAT THIS NODE DOES, AND ALL IT DOES. The blades have no stored positions: the shader makes
## each from its tile and its cell. So this script only
##   - builds the BANDS round you (band_radii): each a mesh of one tile's blades, simpler than
##     the band inside it (band_vertices), and a MultiMesh of tiles, drawn by RenderingServer
##     into the Cross-section engine's own World3D, as the flock is;
##   - lists, when you have moved half a metre, the world-snapped tiles each band covers, and
##     every render keeps only those in the camera's view and hands them to the shader with the
##     camera's frame (pre_render, as the flock does) and the people and animals that push the
##     grass aside;
##   - once, after the scene is up, builds the MASK: for each half metre of the field, up to two
##     stretches of W where something stands on the ground - a floor, a pond, a hill - so no
##     blade grows inside it. From the real geometry: every tetrahedron of every still thing that
##     touches the ground marks the cells under it with its W reach; the hills come from the
##     Lookout's height map (lookout_ground_4d.gd). It runs a few thousand cells at a time, and
##     the grass grows in when it is done.
##
## COST, by design: a few hundred tile tests and a dozen uniforms a frame on the CPU; the GPU
## does the tiles in view x cells^2 x layers x the band's vertices (see _measure_grass_runner.gd).

const SHADER := preload("res://ramon/chickenpen/grass/pen_grass.gdshader")
const GROUND := preload("res://ramon/chickenpen/lookout/lookout_ground_4d.gd")
## Tiles a band can draw at once (the shader's tiles[] array is this long).
const MAX_TILES := 384

@export var enabled: bool = true:
	set(v):
		enabled = v
		_set_visible()

@export_group("Field")
## The gap between blades at your feet and at the field's edge. It starts widening this far
## out and grows smoothly (as a power of the distance) out to the edge.
@export_range(0.04, 0.5, 0.005, "suffix:m") var spacing: float = 0.085
@export_range(0.04, 1.0, 0.01, "suffix:m") var spacing_far: float = 0.30
@export_range(0.5, 20.0, 0.5, "suffix:m") var spacing_from: float = 3.0
## How far round you the grass reaches.
@export_range(10.0, 80.0, 1.0, "suffix:m") var radius: float = 44.0
## The bands of simpler blades: where each ends (the last one ends at the radius), and the
## vertices a blade has in each, from your feet out. Same blade, fewer bends.
@export var band_radii: PackedFloat32Array = PackedFloat32Array([5.0, 10.0, 18.0, 28.0])
@export var band_vertices: PackedInt32Array = PackedInt32Array([11, 9, 7, 5, 3])
## Blades stacked along W at each spot, and how far apart.
@export_range(1, 5) var layers: int = 3
@export_range(0.05, 1.0, 0.01, "suffix:m") var layer_spacing: float = 0.22
## How thick in W a blade is: within this of the slice, some of it shows.
@export_range(0.05, 1.0, 0.01, "suffix:m") var w_radius: float = 0.3

@export_group("Blades")
@export_range(0.05, 2.0, 0.01, "suffix:m") var blade_height: float = 0.4
## A blade's width at its root; where that would be under min_pixels on screen, it is
## min_pixels wide instead (thinner, and a far field flickers and goes bare).
@export_range(0.002, 0.2, 0.001, "suffix:m") var blade_width: float = 0.009
@export_range(0.0, 3.0, 0.05) var min_pixels: float = 0.8
@export_range(0.3, 5.0, 0.05, "suffix:m") var clump_size: float = 1.3
@export var colour_root: Color = Color(0.11, 0.17, 0.07)
## The field's main colour: sap green.
@export var colour_base: Color = Color(0.31, 0.49, 0.16)
@export var colour_lush: Color = Color(0.27, 0.47, 0.18)
@export var colour_dry: Color = Color(0.47, 0.44, 0.22)
@export var colour_tip: Color = Color(0.48, 0.62, 0.26)
## The field's own colour (the pen's ground material): what the field's edge turns into.
@export var ground_colour: Color = Color(0.16, 0.22, 0.11)
## The painted look: broad regions over the field, about region_size across - sap green
## (colour_base) the most of it, and two offsets of it, deeper and cooler, lighter and warmer,
## each over region_share of the field - the field going region_strength of the way to them;
## and each blade's hue nudged by up to hue_jitter towards yellow or blue.
@export var region_deep: Color = Color(0.21, 0.40, 0.19)
@export var region_bright: Color = Color(0.40, 0.56, 0.17)
@export_range(2.0, 40.0, 0.5, "suffix:m") var region_size: float = 13.0
@export_range(0.0, 0.45, 0.01) var region_share: float = 0.25
@export_range(0.0, 1.0, 0.01) var region_strength: float = 1.0
@export_range(0.0, 0.2, 0.005) var hue_jitter: float = 0.05

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
## The script's own time in the last pre_render, microseconds, for runners.
var prerender_usec: int = 0


## One band of the field: a ring round you with its own grid gap and its own blade.
class Band:
	var inner: float
	var outer: float
	var inner_fade: float
	var outer_fade: float
	var last: bool
	var spacing: float
	var cells: int
	var vertices: int
	var material: ShaderMaterial
	## The tiles (world-snapped indices) that reach this band round the centre, nearest first,
	## their middles, and the ones in view this frame.
	var tiles := PackedVector2Array()
	var middles := PackedVector2Array()
	var shown := PackedVector2Array()
	var multimesh := RID()

	func tile_size() -> float:
		return float(cells) * spacing


var _bands: Array[Band] = []
var _meshes: Array = []
var _multimeshes: Array = []
var _instances: Array = []
var _scenario := RID()
var _tiles_centre := Vector2(INF, INF)
var _drawn: int = 0
var _region_cuts := Vector4(0.36, 0.46, 0.55, 0.65)
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
	# Made here, not by a NoiseTexture2D (which makes it on a thread, later), so the regions'
	# cuts can be read off it now.
	var noise_image: Image = noise.get_seamless_image(256, 256)
	var wind := ImageTexture.create_from_image(noise_image)
	_region_cuts = _cuts(noise_image)
	_mask_image = Image.create_empty(MASK_CELLS, MASK_CELLS, false, Image.FORMAT_RGBAF)
	_mask_image.fill(Color(1e4, -1e4, 1e4, -1e4))
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	var bounds: Array[float] = [0.0]
	for r in band_radii:
		if r > bounds.back() + 0.5 and r < radius - 0.5:
			bounds.append(r)
	bounds.append(radius)
	for i in bounds.size() - 1:
		var band := Band.new()
		band.inner = bounds[i]
		band.outer = bounds[i + 1]
		band.last = i == bounds.size() - 2
		band.inner_fade = _fade(band.inner) if i > 0 else 0.0
		band.outer_fade = band.outer * 0.35 if band.last else _fade(band.outer)
		# As fine as the gap wanted where its cross-fade starts, so it is never too coarse.
		band.spacing = _wanted(maxf(band.inner - band.inner_fade, 0.0))
		var reach: float = band.outer + (0.0 if band.last else band.outer_fade)
		# Tiles of about 2 m near you to about 7 m at the edge: fine enough to cull well, few
		# enough to test every frame.
		band.cells = clampi(roundi((1.5 + 0.12 * reach) / band.spacing), 6, 40)
		band.vertices = band_vertices[mini(i, band_vertices.size() - 1)] if not band_vertices.is_empty() else 7
		band.material = _material(wind, band, float(i) * 37.1)
		_add_band(band)
		_bands.append(band)
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)
	_set_visible()
	_find_pushers.call_deferred()
	_build_mask.call_deferred()


## Where the regions' noise turns deep and bright: its quantiles, so each offset covers
## region_share of the field (half-way into its soft edge), sap green the rest.
func _cuts(image: Image) -> Vector4:
	var grey: Image = image.duplicate()
	grey.convert(Image.FORMAT_L8)
	var values: PackedByteArray = grey.get_data()
	values.sort()
	var n: int = values.size()
	var at := func(f: float) -> float: return float(values[clampi(int(f * float(n)), 0, n - 1)]) / 255.0
	var soft: float = 0.06
	return Vector4(at.call(region_share - soft), at.call(region_share + soft), at.call(1.0 - region_share - soft), at.call(1.0 - region_share + soft))


## How wide the cross-fade between two bands is, where they meet at [param r].
func _fade(r: float) -> float:
	return 0.75 + 0.03 * r


## The power the gap grows by: spacing at spacing_from, spacing_far at the radius.
func _power() -> float:
	return maxf(log(maxf(spacing_far, spacing) / spacing) / log(radius / spacing_from), 0.0)


## The gap wanted between blades [param d] from you (the shader's own curve).
func _wanted(d: float) -> float:
	return spacing if d <= spacing_from else spacing * pow(d / spacing_from, _power())


func _material(wind: Texture2D, band: Band, hash_seed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("spacing", band.spacing)
	m.set_shader_parameter("tile_cells", band.cells)
	m.set_shader_parameter("seed", hash_seed)
	m.set_shader_parameter("layers", layers)
	m.set_shader_parameter("layer_spacing", layer_spacing)
	m.set_shader_parameter("w_radius", w_radius)
	m.set_shader_parameter("band_in", band.inner)
	m.set_shader_parameter("band_in_fade", band.inner_fade)
	m.set_shader_parameter("band_out", band.outer)
	m.set_shader_parameter("band_out_fade", band.outer_fade)
	m.set_shader_parameter("last_band", band.last)
	m.set_shader_parameter("spacing_near", spacing)
	m.set_shader_parameter("spacing_from", spacing_from)
	m.set_shader_parameter("spacing_power", _power())
	m.set_shader_parameter("blade_height", blade_height)
	m.set_shader_parameter("blade_width", blade_width)
	m.set_shader_parameter("min_pixels", min_pixels)
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
	m.set_shader_parameter("region_size", region_size)
	m.set_shader_parameter("region_cuts", _region_cuts)
	m.set_shader_parameter("region_strength", region_strength)
	m.set_shader_parameter("hue_jitter", hue_jitter)
	for key in ["colour_root", "colour_base", "colour_lush", "colour_dry", "colour_tip", "ground_colour", "region_deep", "region_bright"]:
		var c: Color = get(key)
		m.set_shader_parameter(key, Vector3(c.r, c.g, c.b))
	return m


## One tile's blades: [param cells]^2 x layers of them, each pairs of vertices up its length,
## closer together towards the tip where it bends, and the tip. UV is (side -1 / +1 / 0, t from
## root to tip); UV2 is the blade's cell in the tile, (i + layer x cells, j). The shader does the
## rest.
func _tile_mesh(vertices: int, cells: int) -> ArrayMesh:
	var levels: int = maxi((vertices - 1) / 2, 1)
	var per: int = levels * 2 + 1
	var blade_uv := PackedVector2Array()
	for i in levels:
		var t: float = 1.0 - pow(1.0 - float(i) / float(levels), 1.25)
		blade_uv.append(Vector2(-1.0, t))
		blade_uv.append(Vector2(1.0, t))
	blade_uv.append(Vector2(0.0, 1.0))
	var blade_index := PackedInt32Array()
	for i in levels - 1:
		var a: int = i * 2
		blade_index.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var last: int = (levels - 1) * 2
	blade_index.append_array([last, last + 1, per - 1])
	var count: int = cells * cells * layers
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var pos := PackedVector3Array()
	var index := PackedInt32Array()
	uv.resize(count * per)
	uv2.resize(count * per)
	pos.resize(count * per)
	index.resize(count * blade_index.size())
	var b: int = 0
	for k in layers:
		for j in cells:
			for i in cells:
				var cell := Vector2(float(i + k * cells), float(j))
				var v0: int = b * per
				for v in per:
					uv[v0 + v] = blade_uv[v]
					uv2[v0 + v] = cell
					pos[v0 + v] = Vector3(blade_uv[v].x * 0.02, blade_uv[v].y * 0.4, 0.0)
				var i0: int = b * blade_index.size()
				for n in blade_index.size():
					index[i0 + n] = v0 + blade_index[n]
				b += 1
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_band(band: Band) -> void:
	var mesh := _tile_mesh(band.vertices, band.cells)
	var mm := RenderingServer.multimesh_create()
	RenderingServer.multimesh_set_mesh(mm, mesh.get_rid())
	RenderingServer.multimesh_allocate_data(mm, MAX_TILES, RenderingServer.MULTIMESH_TRANSFORM_3D, false, false)
	RenderingServer.multimesh_set_visible_instances(mm, 0)
	var inst := RenderingServer.instance_create()
	RenderingServer.instance_set_base(inst, mm)
	RenderingServer.instance_geometry_set_material_override(inst, band.material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(inst, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	# Its transforms are unused - the shader places every blade - so its bounds are anywhere.
	RenderingServer.instance_set_ignore_culling(inst, true)
	RenderingServer.instance_set_custom_aabb(inst, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(inst, false)
	band.multimesh = mm
	_meshes.append(mesh)
	_multimeshes.append(mm)
	_instances.append(inst)


## The blades handed to the GPU last frame (the tiles in view, whole), for runners.
func blade_count() -> int:
	return _drawn


## Per band: [inner, outer, gap, cells per tile side, tile size, vertices, tiles in view].
func band_report() -> Array:
	var out: Array = []
	for band in _bands:
		out.append([band.inner, band.outer, band.spacing, band.cells, band.tile_size(), band.vertices, band.shown.size()])
	return out


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


## The tiles each band covers round [param centre], nearest first: every world-snapped tile
## that reaches the band (with its cross-fades, and half a metre to spare, so this need only run
## again when you have moved that far).
func _list_tiles(centre: Vector2) -> void:
	_tiles_centre = centre
	for band in _bands:
		var t: float = band.tile_size()
		var lo: float = maxf(band.inner - band.inner_fade - 0.6, 0.0)
		var hi: float = band.outer + (0.0 if band.last else band.outer_fade) + 0.6
		var found: Array = []
		for tz in range(floori((centre.y - hi) / t), floori((centre.y + hi) / t) + 1):
			for tx in range(floori((centre.x - hi) / t), floori((centre.x + hi) / t) + 1):
				var x0: float = float(tx) * t
				var z0: float = float(tz) * t
				var nearest: float = Vector2(clampf(centre.x, x0, x0 + t), clampf(centre.y, z0, z0 + t)).distance_to(centre)
				var fx: float = maxf(absf(centre.x - x0), absf(centre.x - x0 - t))
				var fz: float = maxf(absf(centre.y - z0), absf(centre.y - z0 - t))
				if nearest <= hi and fx * fx + fz * fz >= lo * lo:
					found.append([nearest, Vector2(tx, tz)])
		found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		band.tiles.clear()
		band.middles.clear()
		for f in found:
			band.tiles.append(f[1])
			band.middles.append((f[1] + Vector2(0.5, 0.5)) * t)


## The camera's frame for the shader, every render, and the tiles in its view; the instances
## into whichever World3D the cut is drawn in (the Combined renderer's is a SubViewport two deep).
func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	if viewport != get_viewport() or _instances.is_empty():
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
		for inst in _instances:
			RenderingServer.instance_set_scenario(inst, scenario)
		_set_visible()
	var inverse: Projection = camera.global_basis.inverse()
	var basis: Projection = inverse * global_basis
	var origin: Vector4 = inverse * (global_position - camera.global_position)
	var here: Vector4 = global_basis.inverse() * (camera.global_position - global_position)
	var normal: Vector4 = (global_basis.inverse() * camera.global_basis.w).normalized()
	# The rings' middle is you: the player, when this is their own camera (the orbit rig, a few
	# metres behind them), so the field spreads out round them and not ahead of the view; else
	# (the hawk, the Lookout's camera, a cutscene) the camera.
	var centre := Vector2(here.x, here.z)
	var player := _room.get_node_or_null("Player") as Node4D
	if player != null and player.is_ancestor_of(camera):
		var at_player: Vector4 = global_basis.inverse() * (player.global_position - global_position)
		centre = Vector2(at_player.x, at_player.z)
	if centre.distance_to(_tiles_centre) > 0.5:
		_list_tiles(centre)
	var pushers := PackedVector4Array()
	for p in _pushers:
		if is_instance_valid(p) and p.is_visible_in_tree() and pushers.size() < 16:
			var at: Vector4 = global_basis.inverse() * (p.global_position - global_position)
			if Vector2(at.x - centre.x, at.z - centre.y).length() < 14.0:
				pushers.append(at)
	# The view's half-width and half-height, as tangents, with a margin; a pixel's angle.
	var view: Vector2 = viewport.get_visible_rect().size
	var fov: float = float(camera.get("field_of_view_4d")) if int(camera.get("projection_type")) == 1 else float(camera.get("field_of_view_3d"))
	var fy: float = tan(fov * 0.5) * 1.15
	var fx: float = fy * view.x / maxf(view.y, 1.0)
	var kx: float = sqrt(1.0 + fx * fx)
	var ky: float = sqrt(1.0 + fy * fy)
	var pixel_angle: float = 2.0 * tan(fov * 0.5) / maxf(view.y, 1.0)
	# Only the tiles in view, tested as balls round their middles at the slice's w there. The
	# slice's w over the ground is linear in x and z, so a middle's place in the camera's frame
	# is too: ax * x + az * z + c0.
	var gx: float = 0.0
	var gz: float = 0.0
	var w0: float = here.w
	if absf(normal.w) > 0.25:
		gx = -normal.x / normal.w
		gz = -normal.z / normal.w
		w0 = here.w + (normal.x * here.x + normal.y * here.y + normal.z * here.z) / normal.w
	var cx: Vector4 = basis.x + basis.w * gx
	var cz: Vector4 = basis.z + basis.w * gz
	var c4: Vector4 = basis.y * 0.3 + basis.w * w0 + origin
	var ax := Vector3(cx.x, cx.y, cx.z)
	var az := Vector3(cz.x, cz.y, cz.z)
	var c0 := Vector3(c4.x, c4.y, c4.z)
	var frame := PackedVector4Array([basis.x, basis.y, basis.z, basis.w, origin, here, normal,
		Vector4(centre.x, centre.y, fx, pixel_angle)])
	_drawn = 0
	for band in _bands:
		var r: float = band.tile_size() * 0.7072 + 0.7
		var rx: float = r * kx
		var ry: float = r * ky
		band.shown.clear()
		var middles: PackedVector2Array = band.middles
		for i in middles.size():
			var m: Vector2 = middles[i]
			var rel: Vector3 = ax * m.x + az * m.y + c0
			var ahead: float = -rel.z
			if ahead > -r and absf(rel.x) - ahead * fx < rx and absf(rel.y) - ahead * fy < ry:
				band.shown.append(band.tiles[i])
		if band.shown.size() > MAX_TILES:
			band.shown.resize(MAX_TILES)
		var n: int = band.shown.size()
		_drawn += n * band.cells * band.cells * layers
		var upload: PackedVector2Array = band.shown.duplicate()
		upload.resize(MAX_TILES)
		var mat: ShaderMaterial = band.material
		mat.set_shader_parameter("tiles", upload)
		mat.set_shader_parameter("frame", frame)
		mat.set_shader_parameter("pushers", pushers)
		mat.set_shader_parameter("pusher_count", pushers.size())
		RenderingServer.multimesh_set_visible_instances(band.multimesh, n)
	prerender_usec = Time.get_ticks_usec() - started


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
