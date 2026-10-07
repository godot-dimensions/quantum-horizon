extends RefCounted

## The pen's ground, painted: a broad glow of green in the middle of the farm falling off to the
## pen's own dark green far out, and sand round the chicken pen and the marsh with ragged edges.
## Ramon, 3 Oct: "the original, darker green still makes more sense in regards to the dusk or
## dawn mood we have. it would just be nice if we could get some kind of huge falloff, brighter
## green like the grass but a tiny bit darker for the center of the whole scene, and then make a
## radial gradient toward the farther dark background", "keep the surface of the pen inside,
## and a little beyond 'sandy'", and for the marsh "just water, sand ... place the sand from the
## pen also here surrounding it".
##
## ON THE REAL GROUND, NOT A LAYER OVER IT. A TetraMaterial4D can colour a mesh from a 3D texture
## through each cell corner's UVW (TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY, as the baked
## terrain does). The ground slab's top is a cube in x, z and w, so its UVW can simply be its own
## x, z and w: the texture is a map of the field, lit and cut by the slice like any 4D surface.
##
## W IS PIECEWISE. The texture has a layer at each of a few w's (the breaks): a handful for the
## glow, and a pair either side of every patch of sand (the pen at w 0, the marsh at w 8), so
## sand is sharp in W where it is and nowhere else. The slab is one box between each two breaks,
## stacked along W; inside one box the map is linear, as a cell's UVW has to be.
##
## CHEAP TO MAKE (Ramon: "0.3 seconds for what painted ground? seems like a lot"). The glow is
## smooth, so it is worked out on a coarse grid and scaled up, once per distinct strength along
## W; only the sand is painted texel by texel, and only round the sand. About 0.3 s became a
## few tens of milliseconds, once, at the start.
##
## Nothing is saved into the pen: build() returns a new mesh and material for the GroundMesh,
## and the Grass node keeps the old ones to put back.

const BASE_BREAKS := [-60.0, -24.0, -10.0, -4.0, -1.5, 1.5, 4.0, 10.0, 24.0, 60.0]
const TEXELS := 256
const GLOW_TEXELS := 48


## [mesh, material] for a ground slab of [param size] (centred, as the pen's BoxTetraMesh4D is),
## painted with [param p]: centre (Vector2), glow_in, glow_out, glow_w (m), own, glow, sand
## (sRGB Colors), sand_ragged, and sands: an Array of {field, w0, w1, box} - field is a
## grid's worth of "how far inside the sand" (m, > 0 inside) on the grid {grid_cell,
## grid_cells, grid_half}, box its [i0, i1, j0, j1] in grid cells.
static func build(size: Vector4, p: Dictionary) -> Array:
	var half := size * 0.5
	var breaks: Array[float] = _breaks(p["sands"], half.w)
	var mesh := ArrayTetraMesh4D.new()
	for k in breaks.size() - 1:
		var box := BoxTetraMesh4D.new()
		box.size = Vector4(size.x, size.y, size.z, breaks[k + 1] - breaks[k])
		var part: ArrayTetraMesh4D = box.to_array_tetra_mesh()
		part.material = null
		mesh.merge_with(part, Vector4(0.0, 0.0, 0.0, (breaks[k] + breaks[k + 1]) * 0.5))
	# Every vertex looks the field up at its own x, z and w; one map entry per vertex.
	var positions: PackedVector4Array = mesh.vertex_positions
	var uvws := PackedVector3Array()
	uvws.resize(positions.size())
	for i in positions.size():
		var v: Vector4 = positions[i]
		uvws[i] = Vector3((v.x + half.x) / size.x, (v.z + half.z) / size.z, _w_to_uvw(v.w, breaks))
	mesh.texture_map_values = uvws
	mesh.simplex_cell_texture_map_indices = mesh.simplex_cell_vertex_indices
	var glows: Dictionary = {}
	var layers: Array[Image] = []
	for w in breaks:
		var fade: float = snappedf(1.0 - smoothstep(2.0, float(p["glow_w"]), absf(w)), 0.001)
		if not glows.has(fade):
			glows[fade] = _glow(size, p, fade)
		var layer: Image = (glows[fade] as Image).duplicate()
		for sand in p["sands"]:
			_sand(layer, w, sand, size, p)
		layer.convert(Image.FORMAT_RGBAH)
		layers.append(layer)
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGBAH, TEXELS, TEXELS, breaks.size(), false, layers)
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	material.albedo_texture_3d = texture
	# For whatever else wants the ground's colour at a point (the paths' soft edges, 7 Oct): where the
	# layers lie along W (_w_to_uvw) and how big the slab is.
	material.set_meta(&"breaks", PackedFloat32Array(breaks))
	material.set_meta(&"size", Vector2(size.x, size.z))
	return [mesh, material]


## The w's with a layer: the glow's, and either side of each patch of sand and at its edges;
## none closer together than 0.4 m.
static func _breaks(sands: Array, half_w: float) -> Array[float]:
	var all: Array[float] = []
	for b in BASE_BREAKS:
		all.append(clampf(float(b), -half_w, half_w))
	for sand in sands:
		for b in [float(sand["w0"]) - 1.0, float(sand["w0"]), float(sand["w1"]), float(sand["w1"]) + 1.0]:
			all.append(clampf(b, -half_w, half_w))
	all.sort()
	var out: Array[float] = []
	for b in all:
		if out.is_empty() or b - out.back() >= 0.4:
			out.append(b)
	return out


## Where w lands in the texture's depth: break k at the middle of layer k, linear between.
static func _w_to_uvw(w: float, breaks: Array[float]) -> float:
	var n: int = breaks.size()
	for k in n - 1:
		if w <= breaks[k + 1] + 0.0001 or k == n - 2:
			var f: float = clampf((w - breaks[k]) / (breaks[k + 1] - breaks[k]), 0.0, 1.0)
			return (float(k) + 0.5 + f) / float(n)
	return 0.5 / float(n)


## The glow at strength [param fade] along W, in linear light: worked out coarse, scaled up.
static func _glow(size: Vector4, p: Dictionary, fade: float) -> Image:
	var own: Color = (p["own"] as Color).srgb_to_linear()
	var image: Image
	if fade <= 0.0:
		image = Image.create_empty(TEXELS, TEXELS, false, Image.FORMAT_RGBAF)
		image.fill(Color(own.r, own.g, own.b, 1.0))
		return image
	var glow: Color = (p["glow"] as Color).srgb_to_linear()
	var centre: Vector2 = p["centre"]
	var data := PackedFloat32Array()
	data.resize(GLOW_TEXELS * GLOW_TEXELS * 4)
	for j in GLOW_TEXELS:
		var z: float = -size.z * 0.5 + (float(j) + 0.5) * size.z / float(GLOW_TEXELS)
		for i in GLOW_TEXELS:
			var x: float = -size.x * 0.5 + (float(i) + 0.5) * size.x / float(GLOW_TEXELS)
			var g: float = (1.0 - smoothstep(float(p["glow_in"]), float(p["glow_out"]), Vector2(x, z).distance_to(centre))) * fade
			var c: Color = own.lerp(glow, g)
			var o: int = (j * GLOW_TEXELS + i) * 4
			data[o] = c.r
			data[o + 1] = c.g
			data[o + 2] = c.b
			data[o + 3] = 1.0
	image = Image.create_from_data(GLOW_TEXELS, GLOW_TEXELS, false, Image.FORMAT_RGBAF, data.to_byte_array())
	image.resize(TEXELS, TEXELS, Image.INTERPOLATE_BILINEAR)
	return image


## Paints one patch of sand into [param layer] (at [param w]): where its field says inside, the
## edge broken by noise, mottled, worn towards the green round it.
static func _sand(layer: Image, w: float, sand: Dictionary, size: Vector4, p: Dictionary) -> void:
	var w_in: float = 1.0 - smoothstep(0.0, 1.0, maxf(float(sand["w0"]) - w, w - float(sand["w1"])))
	if w_in <= 0.0:
		return
	var field: PackedFloat32Array = sand["field"]
	var grid_cell: float = p["grid_cell"]
	var grid_cells: int = p["grid_cells"]
	var grid_half: float = p["grid_half"]
	var box: Array = sand["box"]
	var sand_colour: Color = (p["sand"] as Color).srgb_to_linear()
	var ragged: float = p["sand_ragged"]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 4417
	noise.frequency = 0.35
	noise.fractal_octaves = 3
	var mottle := FastNoiseLite.new()
	mottle.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mottle.seed = 911
	mottle.frequency = 0.6
	var texel := Vector2(size.x / float(TEXELS), size.z / float(TEXELS))
	# The field's box, in texels.
	var x0: float = -grid_half + float(box[0]) * grid_cell
	var x1: float = -grid_half + float(box[1] + 1) * grid_cell
	var z0: float = -grid_half + float(box[2]) * grid_cell
	var z1: float = -grid_half + float(box[3] + 1) * grid_cell
	var i0: int = clampi(int(floor((x0 + size.x * 0.5) / texel.x)), 0, TEXELS - 1)
	var i1: int = clampi(int(ceil((x1 + size.x * 0.5) / texel.x)), 0, TEXELS - 1)
	var j0: int = clampi(int(floor((z0 + size.z * 0.5) / texel.y)), 0, TEXELS - 1)
	var j1: int = clampi(int(ceil((z1 + size.z * 0.5) / texel.y)), 0, TEXELS - 1)
	for j in range(j0, j1 + 1):
		var z: float = -size.z * 0.5 + (float(j) + 0.5) * texel.y
		for i in range(i0, i1 + 1):
			var x: float = -size.x * 0.5 + (float(i) + 0.5) * texel.x
			# The field, bilinear between its cells.
			var fx: float = clampf((x + grid_half) / grid_cell - 0.5, 0.0, float(grid_cells - 1))
			var fz: float = clampf((z + grid_half) / grid_cell - 0.5, 0.0, float(grid_cells - 1))
			var ci: int = mini(int(fx), grid_cells - 2)
			var cj: int = mini(int(fz), grid_cells - 2)
			var tx: float = fx - float(ci)
			var tz: float = fz - float(cj)
			var o: int = cj * grid_cells + ci
			var inside: float = lerpf(lerpf(field[o], field[o + 1], tx), lerpf(field[o + grid_cells], field[o + grid_cells + 1], tx), tz)
			var edge: float = -inside + noise.get_noise_2d(x, z) * ragged
			if edge > 0.4:
				continue
			var s: float = (1.0 - smoothstep(-0.35, 0.35, edge)) * w_in
			var under: Color = layer.get_pixel(i, j)
			var m: float = 0.86 + 0.16 * mottle.get_noise_2d(x, z)
			var worn: Color = sand_colour.lerp(under, 0.45 * smoothstep(-1.2, 0.0, edge))
			var out: Color = under.lerp(worn * m, s)
			out.a = 1.0
			layer.set_pixel(i, j, out)
