extends RefCounted
## Slice Garden: every material, built in one place.
##
## SURFACES wear Ramon's dev textures (res://textures/dev_finals/ramdev_*.png) tiled at true metres
## through shaders/mk_surface.gdshader, which also draws the W lanes, the W-face tint, the W-edge
## warning and the hazard bands (see its header). GLOWS go through shaders/mk_glow.gdshader.
##
## THE TEXTURES GET MIPMAPS HERE, as the lab kit does (CreationLab/LabKit/lab_materials.gd, whose
## reader this copies): the PNGs import without mipmaps, so a tiled floor seen from the diorama
## camera would shimmer, and Miegakure's own art direction warns that fine texture shimmers during
## the turn. A copy rather than a preload, so the kit can change without changing this.
##
## Materials are cached by their arguments; anything that animates a uniform asks for its own
## (`unique`).
##
## NO class_name (engine_gotchas.md): preload this file.

const SurfaceShader := preload("res://ramon/MiegakureLook/Remake/shaders/mk_surface.gdshader")
## The Creation Lab's grid swatches (CreationLab/kit/kit_style.gd SWATCHES, "bright"), copied 6 Oct:
## [surface, line, subline, strength]. Ramon asked for the lab's look here.
const GRID := {
	"floor": [Color(0.64, 0.65, 0.66), Color(0.52, 0.53, 0.55), Color(0.60, 0.61, 0.62), 0.5],
	"wall": [Color(0.70, 0.71, 0.72), Color(0.58, 0.59, 0.61), Color(0.66, 0.67, 0.68), 0.6],
	"ceiling": [Color(0.82, 0.83, 0.84), Color(0.74, 0.75, 0.76), Color(0.79, 0.80, 0.81), 0.3],
	# The lab's code blue, the colour of its teaching walls (Ramon, 6 Oct: the first platform "blue ...
	# with the white icons and explainer ... check out the blue walls at creatorlab").
	"blue": [Color(0.13, 0.40, 0.86), Color(0.20, 0.48, 0.93), Color(0.16, 0.44, 0.90), 0.5],
}
const GlowShader := preload("res://ramon/MiegakureLook/Remake/shaders/mk_glow.gdshader")
const TEXTURE_DIR := "res://textures/dev_finals/"

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}


## A mipmapped copy of ramdev_<name>.png as a single-slice Texture3D, or null if missing.
static func texture(name: String) -> Texture3D:
	if _textures.has(name):
		return _textures[name]
	var path: String = TEXTURE_DIR + "ramdev_" + name + ".png"
	var result: Texture3D = null
	if ResourceLoader.exists(path):
		# ramdev_dark_grey.png imports as a 2D texture, the rest as 3D (found by the lab, 3 Oct).
		var res: Resource = load(path)
		var picture: Image = null
		if res is Texture3D:
			result = res as Texture3D
			var layers: Array = (res as Texture3D).get_data()
			if not layers.is_empty() and layers[0] is Image:
				picture = layers[0]
		elif res is Texture2D:
			picture = (res as Texture2D).get_image()
		if picture != null:
			var base: Image = picture.duplicate()
			if base.is_compressed():
				base.decompress()
			base.convert(Image.FORMAT_RGBA8)
			var levels: Array[Image] = [base]
			var w: int = base.get_width()
			var h: int = base.get_height()
			while w > 1 or h > 1:
				w = maxi(1, w / 2)
				h = maxi(1, h / 2)
				var level: Image = base.duplicate()
				level.resize(w, h, Image.INTERPOLATE_LANCZOS)
				levels.append(level)
			var tex := ImageTexture3D.new()
			if tex.create(Image.FORMAT_RGBA8, base.get_width(), base.get_height(), 1, true, levels) == OK:
				result = tex
	_textures[name] = result
	return result


## A lit surface in a dev texture on a box of `size`, one texture every `metres`.
## `opts` (all optional): tint, side_tint (Color), origin (Vector4, the mesh's world position, for
## lanes and hazard bands), lanes (Dictionary: width, zero_w, tints [5 Colors -2..+2], seam,
## mark_lane, mark_color, mark_mix), wface (Color, mix in .a), wedge (Color, mix in .a), hazard
## (Vector2 world z range), grid (a GRID swatch name: the lab grid instead of the texture),
## unique (bool: a material of its own, for animating).
static func surface(tex_name: String, size: Vector4, metres: float = 2.0, opts: Dictionary = {}) -> TetraMaterial4D:
	var unique: bool = bool(opts.get("unique", false))
	var key: String = "s|%s|%s|%.3f|%s" % [tex_name, size, metres, str(opts)]
	if not unique and _materials.has(key):
		return _materials[key]
	var tex: Texture3D = texture(tex_name)
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	# The shader goes in BEFORE the texture: Material4D only assigns its built-in shader while the
	# slot is empty, and setting the texture re-runs the update that binds it.
	var cs: ShaderMaterial = material.get_cross_section_material_3d()
	cs.shader = SurfaceShader
	if tex != null:
		material.albedo_texture_3d = tex
	else:
		material.albedo_color = Color(0.7, 0.7, 0.7)
	cs.set_shader_parameter("surface_size", size)
	cs.set_shader_parameter("texture_metres", maxf(metres, 0.001))
	cs.set_shader_parameter("tint", opts.get("tint", Color.WHITE))
	cs.set_shader_parameter("side_tint", opts.get("side_tint", Color.WHITE))
	cs.set_shader_parameter("origin_4d", opts.get("origin", Vector4.ZERO))
	if opts.has("lanes"):
		var lanes: Dictionary = opts["lanes"]
		cs.set_shader_parameter("lanes_on", true)
		cs.set_shader_parameter("lane_width", float(lanes.get("width", 1.6)))
		cs.set_shader_parameter("lane_zero_w", float(lanes.get("zero_w", 0.0)))
		var tints: Array = lanes.get("tints", [])
		var names := ["lane_m2", "lane_m1", "lane_0", "lane_p1", "lane_p2"]
		for i in names.size():
			cs.set_shader_parameter(names[i], tints[i] if i < tints.size() else Color.WHITE)
		cs.set_shader_parameter("lane_seam_color", lanes.get("seam", Color(1, 1, 1, 0.9)))
		cs.set_shader_parameter("mark_lane", int(lanes.get("mark_lane", 99)))
		cs.set_shader_parameter("mark_color", lanes.get("mark_color", Color(0.35, 0.85, 0.9)))
		cs.set_shader_parameter("mark_mix", float(lanes.get("mark_mix", 0.55)))
	if opts.has("wface"):
		var c: Color = opts["wface"]
		cs.set_shader_parameter("wface_color", Color(c.r, c.g, c.b))
		cs.set_shader_parameter("wface_mix", c.a)
	if opts.has("wedge"):
		var c2: Color = opts["wedge"]
		cs.set_shader_parameter("wedge_color", Color(c2.r, c2.g, c2.b))
		cs.set_shader_parameter("wedge_mix", c2.a)
	if opts.has("grid"):
		var g: Array = GRID.get(String(opts["grid"]), GRID["floor"])
		cs.set_shader_parameter("grid_on", true)
		cs.set_shader_parameter("grid_surface", g[0])
		cs.set_shader_parameter("grid_line", g[1])
		cs.set_shader_parameter("grid_subline", g[2])
		cs.set_shader_parameter("grid_strength", g[3])
	if opts.has("hazard"):
		cs.set_shader_parameter("hazard_on", true)
		cs.set_shader_parameter("hazard_z", opts["hazard"])
	if not unique:
		_materials[key] = material
	return material


## An unshaded glow in one colour; `pulse` 0..1 makes it breathe.
static func glow(color: Color, energy: float = 1.0, pulse: float = 0.0, unique: bool = false) -> TetraMaterial4D:
	var key: String = "g|%s|%.3f|%.2f" % [color, energy, pulse]
	if not unique and _materials.has(key):
		return _materials[key]
	var material := TetraMaterial4D.new()
	var cs: ShaderMaterial = material.get_cross_section_material_3d()
	cs.shader = GlowShader
	material.albedo_color = Color.WHITE
	cs.set_shader_parameter("glow_color", color)
	cs.set_shader_parameter("glow_energy", energy)
	cs.set_shader_parameter("pulse", pulse)
	if not unique:
		_materials[key] = material
	return material


## A plain lit colour on the engine's own shader (the walker's blocks, small markers).
static func flat(color: Color, unique: bool = false) -> TetraMaterial4D:
	var key: String = "f|%s" % [color]
	if not unique and _materials.has(key):
		return _materials[key]
	var material := TetraMaterial4D.new()
	material.albedo_color = color
	if not unique:
		_materials[key] = material
	return material


## A box mesh whose sides each carry a full texture unwrap (the surface shader maps by position, so
## this only matters for the engine's own shader).
static func box_mesh(size: Vector4) -> BoxTetraMesh4D:
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	return mesh
