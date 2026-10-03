extends RefCounted

## The pen's ground, painted: a broad glow of green in the middle of the farm falling off to the
## pen's own dark green far out, and a sandy yard round the chicken pen with a ragged edge.
## Ramon, 3 Oct: "the original, darker green still makes more sense in regards to the dusk or
## dawn mood we have. it would just be nice if we could get some kind of huge falloff, brighter
## green like the grass but a tiny bit darker for the center of the whole scene, and then make a
## radial gradient toward the farther dark background", and "keep the surface of the pen inside,
## and a little beyond 'sandy'".
##
## ON THE REAL GROUND, NOT A LAYER OVER IT. A TetraMaterial4D can colour a mesh from a 3D texture
## through each cell corner's UVW (TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY, as the baked
## terrain does). The ground slab's top is a cube in x, z and w, so its UVW can simply be its own
## x, z and w: the texture is a map of the field, lit and cut by the slice like any 4D surface.
##
## W IS PIECEWISE. The texture has only a few layers along W, and the things that matter (the
## pen, the glow's middle) sit at w 0. So the slab is several boxes stacked along W, at
## W_BREAKS, and layer k of the texture sits at break k: fine near w 0, coarse far out, where it
## is all the dark green anyway. Inside one box the map is linear, as a cell's UVW has to be.
##
## Nothing is saved into the pen: build() returns a new mesh and material for the GroundMesh,
## and the Grass node keeps the old ones to put back.

const W_BREAKS := [-60.0, -24.0, -10.0, -4.0, -1.5, 1.5, 4.0, 10.0, 24.0, 60.0]
const TEXELS := 256


## [mesh, material] for a ground slab of [param size] (centred, as the pen's BoxTetraMesh4D is),
## painted with [param p]: centre (Vector2), glow_in, glow_out, glow_w (m), own, glow, sand
## (sRGB Colors), sand_rects (Array of [x0, x1, z0, z1, w0, w1]), sand_beyond, sand_ragged.
## Spread over frames with [param tree]; await it.
static func build(size: Vector4, p: Dictionary, tree: SceneTree) -> Array:
	var half := size * 0.5
	var mesh := ArrayTetraMesh4D.new()
	for k in W_BREAKS.size() - 1:
		var w0: float = maxf(float(W_BREAKS[k]), -half.w)
		var w1: float = minf(float(W_BREAKS[k + 1]), half.w)
		if w1 <= w0:
			continue
		var box := BoxTetraMesh4D.new()
		box.size = Vector4(size.x, size.y, size.z, w1 - w0)
		var part: ArrayTetraMesh4D = box.to_array_tetra_mesh()
		part.material = null
		mesh.merge_with(part, Vector4(0.0, 0.0, 0.0, (w0 + w1) * 0.5))
	# Every vertex looks the field up at its own x, z and w; one map entry per vertex.
	var positions: PackedVector4Array = mesh.vertex_positions
	var uvws := PackedVector3Array()
	uvws.resize(positions.size())
	for i in positions.size():
		var v: Vector4 = positions[i]
		uvws[i] = Vector3((v.x + half.x) / size.x, (v.z + half.z) / size.z, _w_to_uvw(v.w))
	mesh.texture_map_values = uvws
	mesh.simplex_cell_texture_map_indices = mesh.simplex_cell_vertex_indices
	var layers: Array[Image] = []
	for k in W_BREAKS.size():
		layers.append(_layer(float(W_BREAKS[k]), size, p))
		await tree.process_frame
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGBAH, TEXELS, TEXELS, W_BREAKS.size(), false, layers)
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	material.albedo_texture_3d = texture
	return [mesh, material]


## Where w lands in the texture's depth: break k at the middle of layer k, linear between.
static func _w_to_uvw(w: float) -> float:
	var n: int = W_BREAKS.size()
	for k in n - 1:
		var a: float = W_BREAKS[k]
		var b: float = W_BREAKS[k + 1]
		if w <= b + 0.0001 or k == n - 2:
			var f: float = clampf((w - a) / (b - a), 0.0, 1.0)
			return (float(k) + 0.5 + f) / float(n)
	return 0.5 / float(n)


## One layer of the field at [param w], in linear light.
static func _layer(w: float, size: Vector4, p: Dictionary) -> Image:
	var own: Color = (p["own"] as Color).srgb_to_linear()
	var glow: Color = (p["glow"] as Color).srgb_to_linear()
	var sand: Color = (p["sand"] as Color).srgb_to_linear()
	var centre: Vector2 = p["centre"]
	var glow_in: float = p["glow_in"]
	var glow_out: float = p["glow_out"]
	# Along W the glow fades too, more gently: it is the farm's, at w 0.
	var w_fade: float = 1.0 - smoothstep(2.0, float(p["glow_w"]), absf(w))
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 4417
	noise.frequency = 0.35
	noise.fractal_octaves = 3
	var mottle := FastNoiseLite.new()
	mottle.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mottle.seed = 911
	mottle.frequency = 0.6
	var rects: Array = p["sand_rects"]
	var beyond: float = p["sand_beyond"]
	var ragged: float = p["sand_ragged"]
	var data := PackedFloat32Array()
	data.resize(TEXELS * TEXELS * 4)
	var cell := Vector2(size.x / float(TEXELS), size.z / float(TEXELS))
	for j in TEXELS:
		var z: float = -size.z * 0.5 + (float(j) + 0.5) * cell.y
		for i in TEXELS:
			var x: float = -size.x * 0.5 + (float(i) + 0.5) * cell.x
			var r: float = Vector2(x, z).distance_to(centre)
			# The glow: full in the middle, a long smooth fall to the pen's own green.
			var g: float = (1.0 - smoothstep(glow_in, glow_out, r)) * w_fade
			var c: Color = own.lerp(glow, g)
			# The yard: within sand_beyond of the pen's outline, at the pen's w, its edge broken.
			for rect in rects:
				var w_in: float = 1.0 - smoothstep(0.0, 1.5, maxf(float(rect[4]) - w, w - float(rect[5])))
				if w_in <= 0.0:
					continue
				var dx: float = maxf(float(rect[0]) - x, x - float(rect[1]))
				var dz: float = maxf(float(rect[2]) - z, z - float(rect[3]))
				var outside: float = Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length() + minf(maxf(dx, dz), 0.0)
				if outside > beyond + ragged * 1.5:
					continue
				var edge: float = outside - beyond + noise.get_noise_2d(x, z) * ragged
				var s: float = (1.0 - smoothstep(-0.35, 0.35, edge)) * w_in
				# Trodden sand, darker in patches and where it meets the grass.
				var m: float = 0.86 + 0.16 * mottle.get_noise_2d(x, z)
				var worn: Color = sand.lerp(c, 0.45 * smoothstep(-1.2, 0.0, edge))
				c = c.lerp(worn * m, s)
			var o: int = (j * TEXELS + i) * 4
			data[o] = c.r
			data[o + 1] = c.g
			data[o + 2] = c.b
			data[o + 3] = 1.0
	var image := Image.create_from_data(TEXELS, TEXELS, false, Image.FORMAT_RGBAF, data.to_byte_array())
	image.convert(Image.FORMAT_RGBAH)
	return image
