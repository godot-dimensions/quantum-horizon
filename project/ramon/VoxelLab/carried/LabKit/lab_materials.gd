@tool
extends RefCounted

## Every material the lab kit puts on a surface, built in one place.
##
## SURFACES wear Ramon's dev textures (res://textures/dev_finals/ramdev_*.png) tiled at true
## metres through LabKit/shaders/lab_surface.gdshader, lit by the real 4D lights.
##
## THE TEXTURES GET MIPMAPS HERE. The PNGs import as single-slice 3D textures without mipmaps
## (mipmaps/generate=false in their .import files), so a tiled floor seen from a distance
## samples a 1024 px grid into a few pixels and shimmers into moire. Changing their import
## settings would change them for every scene in the project, so instead this file reads the
## image once and builds a mipmapped ImageTexture3D copy for the kit. The sampler in the shader
## is anisotropic as well, for floors seen at a grazing angle.
##
## GLOWS (light strips, rims, rings) go through lab_glow.gdshader: unshaded, so they read as
## emitting light, which is the only way to do that in the cross-section renderer.
##
## Everything is cached by its arguments, so a hundred drums share a handful of materials.

const SurfaceShader := preload("res://ramon/VoxelLab/carried/LabKit/shaders/lab_surface.gdshader")
const GlowShader := preload("res://ramon/VoxelLab/carried/LabKit/shaders/lab_glow.gdshader")
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
		# Most of the set imports as a single-slice 3D texture, but ramdev_dark_grey.png imports
		# as a plain 2D texture (its .import says importer="texture", found 3 Oct), so a straight
		# `load() as Texture3D` gives null for it. Read the picture from either kind.
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


## A lit surface in a dev texture, tiled so one texture covers `metres` on every face of a box
## of `size`. Put it on a BoxTetraMesh4D whose cell_texture_map is FILL_EACH_SIDE.
## `tint` multiplies the texture (a mood can warm or cool a surface without another texture).
static func surface(tex_name: String, size: Vector4, metres: float = 2.0, tint: Color = Color.WHITE, offset: Vector3 = Vector3.ZERO) -> TetraMaterial4D:
	var key: String = "s|%s|%s|%.3f|%s|%s" % [tex_name, size, metres, tint, offset]
	if _materials.has(key):
		return _materials[key]
	var tex: Texture3D = texture(tex_name)
	var material := TetraMaterial4D.new()
	if tex == null:
		material.albedo_color = Color(0.6, 0.6, 0.6) * tint
		_materials[key] = material
		return material
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	# The shader goes in BEFORE the texture: Material4D only assigns its built-in shader while the
	# slot is empty, and setting the texture re-runs the update that binds it (hub_material_4d.gd).
	var cs: ShaderMaterial = material.get_cross_section_material_3d()
	cs.shader = SurfaceShader
	material.albedo_texture_3d = tex
	cs.set_shader_parameter("surface_size", size)
	cs.set_shader_parameter("texture_metres", maxf(metres, 0.001))
	cs.set_shader_parameter("texture_offset", offset)
	cs.set_shader_parameter("tint", tint)
	_materials[key] = material
	return material


## An unshaded glow in one colour at an energy (1.0 = the colour itself; above 1 is not
## brighter on screen past white, so keep the colour itself bright for a strong glow).
static func glow(color: Color, energy: float = 1.0) -> TetraMaterial4D:
	var key: String = "g|%s|%.3f" % [color, energy]
	if _materials.has(key):
		return _materials[key]
	var material := TetraMaterial4D.new()
	var cs: ShaderMaterial = material.get_cross_section_material_3d()
	cs.shader = GlowShader
	material.albedo_color = Color.WHITE
	cs.set_shader_parameter("glow_color", color)
	cs.set_shader_parameter("glow_energy", energy)
	_materials[key] = material
	return material


## A plain lit colour on the engine's own shader (creature blocks, markers).
static func flat(color: Color) -> TetraMaterial4D:
	var key: String = "f|%s" % [color]
	if _materials.has(key):
		return _materials[key]
	var material := TetraMaterial4D.new()
	material.albedo_color = color
	_materials[key] = material
	return material


## A box mesh whose sides each get a full 0..1 of texture, ready for `surface()`.
static func box_mesh(size: Vector4) -> BoxTetraMesh4D:
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	return mesh
