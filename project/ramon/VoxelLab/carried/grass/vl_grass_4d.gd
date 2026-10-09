extends Node4D

## VOXEL LAB (carried from ramon/chickenpen/grass/pen_grass_4d.gd, 9 Oct, round 5 #49): the pen's grass on a few
## patches of the open world's island. Ramon: "reuse the grass system from the Chicken Pen prototype ...
## distribute a few small grass patches across the island terrain ... individual grass blades somewhat thicker
## ... keep the patches sparse ... allow the grass to be toggled ... visible from normal viewing distances,
## including from the Open World platform".
##
## WHAT IS THE PEN'S, AS IT IS. Andrew's 4D lattice field (vl_grass_lattice.gdshader, his shader with the pen's
## later work): no blade is stored; the shader makes each from its tile and its cell. The bands round you, each
## with simpler blades than the one inside it; the tiles of each band listed in the plane the slice meets the
## ground in, the axis it is steepest along (d) left as columns; every render, the tiles in view and the
## camera's frame handed over (pre_render), the instances drawn by RenderingServer into the Cross-section
## engine's own World3D (the flock's way). The look is the pen's Hay meadow II over its 2 Oct meadow (LOOK).
##
## WHAT IS NEW. Patches: the share `coverage` of the grass ground where the field's own 4D noise is highest
## (round 5, Ramon: "the amount being covered by grass in percentage"), `patch_m` how big; the gap between blades
## `spacing_m` ("with density i mean grass blade to grass blade distance"). Only the island's square is tiled. The ground under them comes from the island's own chunk meshes (bake_heights, the pen's
## grass_heights_4d.gd way: every upward tetrahedron of grass, its y laid over a grid of (x, z, W) points),
## grass ground only, on a worker thread once the island is built. The blades are `width_scale` times the pen's
## width, and the frustum test allows for the island's height.
##
## Out: the pen's mask, clearings, paths, ground paint, trails, leaves on the wind and its panel.
##
## The grass's own space is the world's (this node sits at the field's origin, unturned).
##
## NO class_name (engine_gotchas.md).

const SHADER := preload("res://ramon/VoxelLab/carried/grass/vl_grass_lattice.gdshader")
const MAX_TILES := 384
## The height grid: metres a cell in x and z, a layer every DW metres along W.
const CELL := 0.5
const DW := 1.0
## No grass here (rock, sand, under the sea, nothing): far over height_max, so the shader lets no blade stand.
const NONE := 10000.0

## The pen's 2 Oct meadow with its Hay meadow II over it (pen_grass_looks.gd BASE and 3), then ours: sparser
## (spacing), wider (width_scale), the field reaching further (radius) and no fade to a ground colour at its
## edge (the patches have their own edges).
const LOOK := {
	"spacing": 0.07, "spacing_far": 0.3, "spacing_from": 4.0, "blade_height": 0.7, "blade_width": 0.007, "taper": 0.6,
	"min_pixels": 0.9, "clump_size": 1.6, "colour_root": Color(0.11, 0.17, 0.07), "colour_base": Color(0.31, 0.49, 0.16),
	"colour_lush": Color(0.27, 0.47, 0.18), "colour_dry": Color(0.47, 0.44, 0.22), "colour_tip": Color(0.48, 0.62, 0.26),
	"region_deep": Color(0.21, 0.40, 0.19), "region_bright": Color(0.40, 0.56, 0.17), "region_size": 13.0, "region_share": 0.25,
	"region_strength": 1.0, "hue_jitter": 0.05, "shade": 0.46, "toward_ground": 0.18, "saturation": 1.45, "root_dark": 0.0,
	"wind_speed": 3.4, "gustiness": 0.3, "gust_length": 7.0, "gust_width": 18.0, "bend_max": 0.55, "stiffness": 26.0, "sheen": 0.45,
	"wave_strength": 1.0, "wave_length": 8.0, "wave_speed": 3.2, "wave_width": 22.0, "big_gust_strength": 6.0, "big_gust_every": 16.0,
	"big_gust_chance": 0.7, "big_gust_width": 14.0, "big_gust_speed": 14.0, "big_gust_lean": 0.32, "splay": 0.08, "tuft_share": 0.0,
	"tuft_height": 1.9, "flower_height": 1.3, "flower_share": 0.007, "flower_patch_size": 0.0, "flower_dot": 0.0, "flower_white": 0.5,
	"ground_colour": Color(0.16, 0.22, 0.11),
}

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
	var tiles := PackedVector2Array()
	var middles := PackedVector2Array()
	var shown := PackedVector2Array()
	var multimesh := RID()

	func tile_size() -> float:
		return float(cells) * spacing


var enabled: bool = true:
	set(v):
		enabled = v
		_set_visible()
## The blades' width against the pen's.
var width_scale: float = 2.2:
	set(v):
		width_scale = v
		for band in _bands:
			(band as Band).material.set_shader_parameter("blade_width", float(LOOK["blade_width"]) * width_scale)
## The blades' height, m (Ramon, 9 Oct: "a grass size slider under tab").
var height_m: float = 0.7:
	set(v):
		height_m = v
		for band in _bands:
			(band as Band).material.set_shader_parameter("blade_height", height_m)
## The grass's colour ("a color coder for the grass color"): the pen's sap green (LOOK colour_base) moved to it,
## and every other colour of the look moved the same way (its hue turned by as much, its saturation and
## brightness scaled by as much), so the roots, tips, lush and dry clumps and the broad regions keep their spread
## round it. Alpha 0: the pen's own colours.
var colour: Color = Color(0, 0, 0, 0):
	set(v):
		colour = v
		for band in _bands:
			_colours_to((band as Band).material)
## The gap between neighbouring blades near you, m (LOOK's 7 cm; the far gap scales with it). Set with
## rebuild() after: the bands' tile meshes are made for their gap.
var spacing_m: float = 0.07
## The share of the grass ground that is grass, 0 to 1: the shader cuts its 4D noise at this share's quantile.
var coverage: float = 0.35:
	set(v):
		coverage = clampf(v, 0.0, 1.0)
		for band in _bands:
			_cover_to((band as Band).material)
## How big a patch is, m (the noise's period is three times it).
var patch_m: float = 6.0:
	set(v):
		patch_m = maxf(v, 0.5)
		for band in _bands:
			_cover_to((band as Band).material)
## How far through W either side of W 0 there is grass (the ground is baked that far and a metre more).
var w_reach: float = 6.0
## The rings round you: how far the grass is drawn, and where the bands change.
var radius: float = 80.0
var band_radii: Array = [12.0, 32.0]
var band_vertices: Array = [9, 5, 3]
## The rings' middle when it is your own camera that looks (the player's): the field, else the camera.
var player: Node4D

var _bands: Array = []
var _instances: Array = []
var _multimeshes: Array = []
var _meshes: Array = []
var _scenario := RID()
var _noise_image: Image
## noise3's values over many random points, sorted: the coverage's cut is read off them.
var _noise_values := PackedFloat32Array()
var _wind_texture: Texture2D
var _height_texture: ImageTexture3D
## x0, z0 of the height grid's corner, its cell, its cells a side; its first W layer, the step, how many.
var _height_rect := Vector4.ZERO
var _height_w := Vector3.ZERO
## About the island's ground height, for the frustum test.
var _ground_y: float = 0.0
var _lattice_layers: int = 8
var _tiles_axis: int = -1
var _tiles_centre := Vector2(1e9, 1e9)
var _tiles_stretch: float = 1.0
var _drawn: int = 0
## The last render's layout on the CPU, microseconds (the runners read it).
var prerender_usec: int = 0
var _ready_to_draw: bool = false


## Starts the grass on `heights` (bake_heights' result, as `rect` and `wl` say).
func start(heights: PackedFloat32Array, rect: Vector4, wl: Vector3, ground_y: float) -> void:
	_height_rect = rect
	_height_w = wl
	_ground_y = ground_y
	var cells: int = int(rect.w)
	var layers: Array[Image] = []
	var per: int = cells * cells
	for l in int(wl.z):
		var bytes: PackedByteArray = heights.slice(l * per, (l + 1) * per).to_byte_array()
		layers.append(Image.create_from_data(cells, cells, false, Image.FORMAT_RF, bytes))
	_height_texture = ImageTexture3D.new()
	_height_texture.create(Image.FORMAT_RF, cells, cells, int(wl.z), false, layers)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	_noise_image = noise.get_seamless_image(256, 256)
	_wind_texture = ImageTexture.create_from_image(_noise_image)
	_noise_values = _noise3_values(_noise_image)
	_build_bands()
	_ready_to_draw = true
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


## Blades handed to the GPU last render (the tiles in view, whole), for runners.
func blade_count() -> int:
	return _drawn


## The bands made again (after `spacing_m` changes): the same ground, new tiles.
func rebuild() -> void:
	if not _ready_to_draw:
		return
	_free_bands()
	_build_bands()
	_tiles_axis = -1
	_tiles_centre = Vector2(1e9, 1e9)
	_scenario = RID()


func _free_bands() -> void:
	for inst in _instances:
		RenderingServer.free_rid(inst)
	for mm in _multimeshes:
		RenderingServer.free_rid(mm)
	_instances.clear()
	_multimeshes.clear()
	_meshes.clear()
	_bands.clear()


## The near gap and the far one.
func _sp() -> float:
	return maxf(spacing_m, 0.02)


func _sp_far() -> float:
	return float(LOOK["spacing_far"]) * _sp() / float(LOOK["spacing"])


## The coverage's cut and the patches' size onto `m`.
func _cover_to(m: ShaderMaterial) -> void:
	var cut: float = 2.0
	if coverage >= 0.999:
		cut = -1.0
	elif coverage > 0.001 and not _noise_values.is_empty():
		cut = _noise_values[clampi(int((1.0 - coverage) * float(_noise_values.size())), 0, _noise_values.size() - 1)]
	m.set_shader_parameter("coverage_cut", cut)
	m.set_shader_parameter("patch_scale", patch_m * 3.0)
	m.set_shader_parameter("patch_w_reach", w_reach)


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)
	for inst in _instances:
		RenderingServer.free_rid(inst)
	for mm in _multimeshes:
		RenderingServer.free_rid(mm)
	_instances.clear()
	_multimeshes.clear()
	_bands.clear()


# -- the bands (the pen's, as they are) ----------------------------------------------------------------

func _build_bands() -> void:
	var cuts: Vector4 = _cuts_andrew()
	_lattice_layers = ceili(2.0 * sqrt(3.0) * 1.0 + 4.0)
	var bounds: Array[float] = [0.0]
	for r in band_radii:
		if float(r) > bounds.back() + 0.5 and float(r) < radius - 0.5:
			bounds.append(float(r))
	bounds.append(radius)
	for i in bounds.size() - 1:
		var band := Band.new()
		band.inner = bounds[i]
		band.outer = bounds[i + 1]
		band.last = i == bounds.size() - 2
		band.inner_fade = _fade(band.inner) if i > 0 else 0.0
		band.outer_fade = band.outer * 0.35 if band.last else _fade(band.outer)
		band.spacing = _wanted(maxf(band.inner - band.inner_fade, 0.0))
		var reach: float = band.outer + (0.0 if band.last else band.outer_fade)
		band.cells = clampi(roundi((1.5 + 0.12 * reach) / band.spacing), 6, 40)
		band.vertices = int(band_vertices[mini(i, band_vertices.size() - 1)])
		band.material = _material(band, float(i) * 37.1, cuts)
		_add_band(band)
		_bands.append(band)


## noise3's distribution (the shader's: the mean of three texels, spread back), sorted (the pen's _cuts_andrew).
static func _noise3_values(image: Image) -> PackedFloat32Array:
	var grey: Image = image.duplicate()
	grey.convert(Image.FORMAT_L8)
	var texels: PackedByteArray = grey.get_data()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var values := PackedFloat32Array()
	values.resize(1 << 16)
	for i in values.size():
		var sum: int = texels[rng.randi() % texels.size()] + texels[rng.randi() % texels.size()] + texels[rng.randi() % texels.size()]
		values[i] = 0.5 + (float(sum) / (3.0 * 255.0) - 0.5) * sqrt(3.0)
	values.sort()
	return values


## The pen's regions' quantiles of the same distribution.
func _cuts_andrew() -> Vector4:
	var values: PackedFloat32Array = _noise_values
	var n: int = values.size()
	var share: float = float(LOOK["region_share"])
	var at := func(f: float) -> float: return values[clampi(int(f * float(n)), 0, n - 1)]
	var soft: float = 0.06
	return Vector4(at.call(share - soft), at.call(share + soft), at.call(1.0 - share - soft), at.call(1.0 - share + soft))


func _fade(r: float) -> float:
	return 0.75 + 0.03 * r


func _power() -> float:
	var sp: float = _sp()
	return maxf(log(maxf(_sp_far(), sp) / sp) / log(radius / float(LOOK["spacing_from"])), 0.0)


func _wanted(d: float) -> float:
	var sp: float = _sp()
	return sp if d <= float(LOOK["spacing_from"]) else sp * pow(d / float(LOOK["spacing_from"]), _power())


func _material(band: Band, hash_seed: float, cuts: Vector4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("spacing", band.spacing)
	m.set_shader_parameter("tile_cells", band.cells)
	m.set_shader_parameter("seed", hash_seed)
	m.set_shader_parameter("layers", _lattice_layers)
	m.set_shader_parameter("w_radius_cells", 1.0)
	m.set_shader_parameter("band_in", band.inner)
	m.set_shader_parameter("band_in_fade", band.inner_fade)
	m.set_shader_parameter("band_out", band.outer)
	m.set_shader_parameter("band_out_fade", band.outer_fade)
	m.set_shader_parameter("last_band", band.last)
	m.set_shader_parameter("far_from", radius * 0.6)
	m.set_shader_parameter("far_to", radius)
	m.set_shader_parameter("far_amount", 0.0)
	m.set_shader_parameter("spacing_near", _sp())
	m.set_shader_parameter("spacing_from", float(LOOK["spacing_from"]))
	m.set_shader_parameter("spacing_power", _power())
	m.set_shader_parameter("blade_width", float(LOOK["blade_width"]) * width_scale)
	m.set_shader_parameter("ground_extent", 100000.0)
	m.set_shader_parameter("height_on", 1.0)
	m.set_shader_parameter("height_tex", _height_texture)
	m.set_shader_parameter("height_w", _height_w)
	m.set_shader_parameter("mask_rect", _height_rect)
	m.set_shader_parameter("height_max", NONE * 0.5)
	m.set_shader_parameter("slope_max", 1.4)
	_cover_to(m)
	m.set_shader_parameter("wind_noise", _wind_texture)
	m.set_shader_parameter("wind_dir", Vector2(0.82, 0.57).normalized())
	m.set_shader_parameter("region_cuts", cuts)
	m.set_shader_parameter("blade_levels", maxi((band.vertices - 1) >> 1, 1))
	m.set_shader_parameter("edge_colour", Vector3(0.16, 0.22, 0.11))
	for key in LOOK:
		if key in ["spacing", "spacing_far", "spacing_from", "blade_width", "region_share", "min_pixels"]:
			continue
		var v: Variant = LOOK[key]
		m.set_shader_parameter(key, Vector3(v.r, v.g, v.b) if v is Color else v)
	m.set_shader_parameter("min_pixels", float(LOOK["min_pixels"]))
	m.set_shader_parameter("blade_height", height_m)
	_colours_to(m)
	return m


const COLOUR_KEYS := ["colour_root", "colour_base", "colour_lush", "colour_dry", "colour_tip", "region_deep", "region_bright"]


## The look's colours onto `m`, moved to `colour` (see `colour`).
func _colours_to(m: ShaderMaterial) -> void:
	var base: Color = LOOK["colour_base"]
	var dh: float = colour.h - base.h
	var ks: float = colour.s / maxf(base.s, 0.01)
	var kv: float = colour.v / maxf(base.v, 0.01)
	for key in COLOUR_KEYS:
		var c: Color = LOOK[key]
		if colour.a > 0.0:
			c = Color.from_hsv(fposmod(c.h + dh, 1.0), clampf(c.s * ks, 0.0, 1.0), clampf(c.v * kv, 0.0, 1.0))
		m.set_shader_parameter(key, Vector3(c.r, c.g, c.b))


## The pen's _tile_mesh: one tile's blades, cells^2 x layers, each pairs of vertices up its length.
func _tile_mesh(vertices: int, cells: int) -> ArrayMesh:
	var levels: int = maxi((vertices - 1) >> 1, 1)
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
	var stack: int = _lattice_layers
	var count: int = cells * cells * stack
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var pos := PackedVector3Array()
	var index := PackedInt32Array()
	uv.resize(count * per)
	uv2.resize(count * per)
	pos.resize(count * per)
	index.resize(count * blade_index.size())
	var b: int = 0
	for k in stack:
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
	# Its transforms are unused (the shader places every blade), so its bounds are anywhere; a custom AABB as
	# well, or it is never indexed into the scenario at all.
	RenderingServer.instance_set_ignore_culling(inst, true)
	RenderingServer.instance_set_custom_aabb(inst, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(inst, false)
	band.multimesh = mm
	_meshes.append(mesh)
	_multimeshes.append(mm)
	_instances.append(inst)


func _set_visible() -> void:
	for inst in _instances:
		RenderingServer.instance_set_visible(inst, enabled and _ready_to_draw and _scenario.is_valid() and is_visible_in_tree())


# -- the tiles: only over the island's square ------------------------------------------------------------

## The tiles each band covers round `centre` in the plane's (u, v) that touch a patch there: the pen's list,
## then kept only where a patch's shadow on (u, v) is (its radius in x and z, its reach along W).
func _list_tiles(centre: Vector2, stretch: float, d: int) -> void:
	_tiles_centre = centre
	_tiles_stretch = stretch
	var uv: Array = [[1, 2], [0, 2], [0, 1]][d]
	var boxes: Array = []
	var side: float = _height_rect.z * _height_rect.w
	var blo := Vector3(_height_rect.x, _height_rect.y, -w_reach)
	var bhi := Vector3(_height_rect.x + side, _height_rect.y + side, w_reach)
	boxes.append(Rect2(Vector2(blo[uv[0]], blo[uv[1]]), Vector2(bhi[uv[0]] - blo[uv[0]], bhi[uv[1]] - blo[uv[1]])).grow(1.0))
	for band in _bands:
		var t: float = band.tile_size()
		var lo: float = maxf((band.inner - band.inner_fade - 0.6) / stretch, 0.0)
		var hi: float = band.outer + (0.0 if band.last else band.outer_fade) + 0.6
		var found: Array = []
		for box in boxes:
			# Only where the box meets the band's square round you.
			var r: Rect2 = (box as Rect2).intersection(Rect2(centre - Vector2(hi, hi), Vector2(hi, hi) * 2.0))
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				continue
			for tz in range(floori(r.position.y / t), floori(r.end.y / t) + 1):
				for tx in range(floori(r.position.x / t), floori(r.end.x / t) + 1):
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
		var seen: Dictionary = {}
		for f in found:
			if seen.has(f[1]):
				continue
			seen[f[1]] = true
			band.tiles.append(f[1])
			band.middles.append((f[1] + Vector2(0.5, 0.5)) * t)


## The camera's frame and the tiles in view, every render (the pen's _on_pre_render and _draw_andrew).
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
	if not enabled or not is_visible_in_tree():
		for band in _bands:
			RenderingServer.multimesh_set_visible_instances(band.multimesh, 0)
		_drawn = 0
		prerender_usec = 0
		return
	var started: int = Time.get_ticks_usec()
	var inverse: Projection = camera.global_basis.inverse()
	var basis: Projection = inverse * global_basis
	var origin: Vector4 = inverse * (global_position - camera.global_position)
	var here: Vector4 = global_basis.inverse() * (camera.global_position - global_position)
	var normal: Vector4 = (global_basis.inverse() * camera.global_basis.w).normalized()
	var m := Vector3(normal.x, normal.z, normal.w)
	if m.length() < 0.5:
		for band in _bands:
			RenderingServer.multimesh_set_visible_instances(band.multimesh, 0)
		return
	var d: int = m.abs().max_axis_index()
	var uv: Array = [[1, 2], [0, 2], [0, 1]][d]
	var c: float = normal.dot(here)
	var gu: float = -m[uv[0]] / m[d]
	var gv: float = -m[uv[1]] / m[d]
	var stretch_max: float = sqrt(1.0 + gu * gu + gv * gv)
	var centre3 := Vector3(here.x, here.z, here.w)
	if player != null and is_instance_valid(player) and player.is_ancestor_of(camera):
		var at_player: Vector4 = global_basis.inverse() * (player.global_position - global_position)
		centre3 = Vector3(at_player.x, at_player.z, at_player.w)
	var centre := Vector2(centre3[uv[0]], centre3[uv[1]])
	if d != _tiles_axis or centre.distance_to(_tiles_centre) > 0.5 or absf(stretch_max - _tiles_stretch) > 0.1:
		_tiles_axis = d
		_list_tiles(centre, stretch_max, d)
	var view: Vector2 = viewport.get_visible_rect().size
	var fov: float = float(camera.get("field_of_view_4d")) if int(camera.get("projection_type")) == 1 else float(camera.get("field_of_view_3d"))
	var fy: float = tan(fov * 0.5) * 1.15
	var fx: float = fy * view.x / maxf(view.y, 1.0)
	var kx: float = sqrt(1.0 + fx * fx)
	var ky: float = sqrt(1.0 + fy * fy)
	var pixel_angle: float = 2.0 * tan(fov * 0.5) / maxf(view.y, 1.0)
	var columns: Array = [basis.x, basis.z, basis.w]
	var cu: Vector4 = columns[uv[0]] + columns[d] * gu
	var cv: Vector4 = columns[uv[1]] + columns[d] * gv
	# The tiles' middles at about the island's ground height (the pen's stood at 0.3 m; the island's are metres up).
	var c4: Vector4 = basis.y * (_ground_y + 0.3) + columns[d] * (c / m[d]) + origin
	var au := Vector3(cu.x, cu.y, cu.z)
	var av := Vector3(cv.x, cv.y, cv.z)
	var c0 := Vector3(c4.x, c4.y, c4.z)
	var stretch: float = 0.5 * (sqrt(1.0 + gu * gu) + sqrt(1.0 + gv * gv))
	var frame := PackedVector4Array([basis.x, basis.y, basis.z, basis.w, origin, here, normal,
		Vector4(centre3.x, centre3.y, fx, pixel_angle), Vector4(centre3.z, float(d), c, 0.0)])
	var none := PackedVector4Array()
	none.resize(32)
	_drawn = 0
	for band in _bands:
		# A little more room up and down than the pen's: the ground under a patch is not all at its mean.
		var r: float = band.tile_size() * stretch + 0.7
		var rx: float = r * kx
		var ry: float = r * ky + 6.0
		band.shown.clear()
		var middles: PackedVector2Array = band.middles
		for i in middles.size():
			var mid: Vector2 = middles[i]
			var rel: Vector3 = au * mid.x + av * mid.y + c0
			var ahead: float = -rel.z
			if ahead > -r and absf(rel.x) - ahead * fx < rx and absf(rel.y) - ahead * fy < ry:
				band.shown.append(band.tiles[i])
		if band.shown.size() > MAX_TILES:
			band.shown.resize(MAX_TILES)
		var n: int = band.shown.size()
		_drawn += n * band.cells * band.cells * _lattice_layers
		var upload: PackedVector2Array = band.shown.duplicate()
		upload.resize(MAX_TILES)
		var mat: ShaderMaterial = band.material
		mat.set_shader_parameter("tiles", upload)
		mat.set_shader_parameter("frame", frame)
		mat.set_shader_parameter("pushers", none)
		mat.set_shader_parameter("pusher_motion", none)
		mat.set_shader_parameter("pusher_count", 0)
		RenderingServer.multimesh_set_visible_instances(band.multimesh, n)
	prerender_usec = Time.get_ticks_usec() - started


# -- the ground under the grass ----------------------------------------------------------------------------

## The ground's height over the grid, every W layer (layer l's rows from l * cells), on a worker thread: for
## every tetrahedron in `jobs` ([[global position, global basis, vertex positions, the cells' vertex indices,
## texture map values, the cells' texture map indices]], copied from the chunk meshes on the main thread) that
## lies in one of `boxes` (x, z, w lows and highs), its y over the (x, z, W) points under it, the highest kept:
## the top skin. NONE where that top is not grass (material 0) or there is none (the pen's grass_heights_4d.gd
## bake, grass only; the material read as vl_tet_ray.gd reads it).
static func bake_heights(jobs: Array, rect: Vector4, wl: Vector3, boxes: Array, sea_y: float) -> PackedFloat32Array:
	var cells_n: int = int(rect.w)
	var layers: int = int(wl.z)
	var top := PackedFloat32Array()
	top.resize(cells_n * cells_n * layers)
	top.fill(-NONE)
	var grass := PackedByteArray()
	grass.resize(top.size())
	for job in jobs:
		var o: Vector4 = job[0]
		var b: Projection = job[1]
		var pos: PackedVector4Array = job[2]
		var idx: PackedInt32Array = job[3]
		var tv: PackedVector3Array = job[4]
		var ti: PackedInt32Array = job[5]
		for cell in idx.size() >> 2:
			var a: Vector4 = b * pos[idx[cell * 4]] + o
			var bb: Vector4 = b * pos[idx[cell * 4 + 1]] + o
			var c: Vector4 = b * pos[idx[cell * 4 + 2]] + o
			var d: Vector4 = b * pos[idx[cell * 4 + 3]] + o
			if maxf(maxf(a.y, bb.y), maxf(c.y, d.y)) < sea_y:
				continue
			var lo := Vector3(minf(minf(a.x, bb.x), minf(c.x, d.x)), minf(minf(a.z, bb.z), minf(c.z, d.z)), minf(minf(a.w, bb.w), minf(c.w, d.w)))
			var hi := Vector3(maxf(maxf(a.x, bb.x), maxf(c.x, d.x)), maxf(maxf(a.z, bb.z), maxf(c.z, d.z)), maxf(maxf(a.w, bb.w), maxf(c.w, d.w)))
			var inside: bool = false
			for box in boxes:
				var bl: Vector3 = box[0]
				var bh: Vector3 = box[1]
				if hi.x >= bl.x and lo.x <= bh.x and hi.y >= bl.y and lo.y <= bh.y and hi.z >= bl.z and lo.z <= bh.z:
					inside = true
					break
			if not inside:
				continue
			var p0 := Vector3(a.x, a.z, a.w)
			var m := Basis(Vector3(bb.x, bb.z, bb.w) - p0, Vector3(c.x, c.z, c.w) - p0, Vector3(d.x, d.z, d.w) - p0)
			if absf(m.determinant()) < 1e-7:
				continue
			var inv: Basis = m.inverse()
			var is_grass: int = 1
			if ti.size() > cell * 4 and ti[cell * 4] < tv.size():
				is_grass = 1 if int(round(tv[ti[cell * 4]].x * 255.0)) == 0 else 0
			var i0: int = maxi(int(ceil((lo.x - rect.x) / CELL - 0.5)), 0)
			var i1: int = mini(int(floor((hi.x - rect.x) / CELL - 0.5)), cells_n - 1)
			var j0: int = maxi(int(ceil((lo.y - rect.y) / CELL - 0.5)), 0)
			var j1: int = mini(int(floor((hi.y - rect.y) / CELL - 0.5)), cells_n - 1)
			var l0: int = maxi(int(ceil((lo.z - wl.x) / wl.y)), 0)
			var l1: int = mini(int(floor((hi.z - wl.x) / wl.y)), layers - 1)
			for l in range(l0, l1 + 1):
				var w: float = wl.x + float(l) * wl.y
				for j in range(j0, j1 + 1):
					var z: float = rect.y + (float(j) + 0.5) * CELL
					for i in range(i0, i1 + 1):
						var x: float = rect.x + (float(i) + 0.5) * CELL
						var bary: Vector3 = inv * (Vector3(x, z, w) - p0)
						var first: float = 1.0 - bary.x - bary.y - bary.z
						if bary.x < -1e-4 or bary.y < -1e-4 or bary.z < -1e-4 or first < -1e-4:
							continue
						var y: float = a.y * first + bb.y * bary.x + c.y * bary.y + d.y * bary.z
						var at: int = (l * cells_n + j) * cells_n + i
						if y > top[at]:
							top[at] = y
							grass[at] = is_grass
	for at in top.size():
		if grass[at] == 0 or top[at] <= -NONE * 0.5:
			top[at] = NONE
	return top
