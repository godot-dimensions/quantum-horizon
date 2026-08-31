@tool
extends RefCounted

## One place that builds every textured surface in the Demo hub.
##
## The point is a SHARED WORLD SCALE: one texture covers [param texture_metres]
## on every face of every box, whatever that box's proportions. A gate pillar, the
## floor and the back wall then read at the same grain, which is what makes the
## greybox usable as a scale reference rather than decoration.
##
## Getting that needs the forked shader. The project's normal route -
## `cell_texture_map = FILL_EACH_SIDE` plus
## `albedo_source = TEXTURE3D_CELL_UVW_ONLY`, as phase_maze_builder.gd and
## gallery_target_ramon.tscn do it - maps exactly one texture per side, so a 0.25 m
## frame segment and a 48 m floor each get one copy and the grain differs by two
## orders of magnitude between them. That is correct for PhaseMaze, where every
## wall is a separate panel sized to its texture; it cannot give a consistent
## scale across objects of different sizes.
##
## The fork takes the box's full size and picks the right three dimensions per
## cell from its 4D normal, so the scale is right on every face rather than only
## on the one it was tuned for.

const Palette := preload("res://ramon/Demo/scripts/hub_palette.gd")
const TiledShader := preload("res://ramon/Demo/shaders/hub_tiled_surface.gdshader")


## Textured surface at the shared world scale.
##
## [param size] must be the box's own size, since the shader derives tiling from
## it. Falls back to flat albedo if the texture is missing, so a mistyped palette
## name gives the wrong colour rather than an invisible surface.
## [param texture_offset] shifts the tiling within each tile, in texture widths.
## The dev textures put their grid lines through the middle of the image, so 0.5
## moves those onto the tile seams where neighbouring tiles join into one grid.
static func tiled(palette_name: String, size: Vector4, texture_metres: float, alpha: float = 1.0, texture_offset: float = 0.0) -> TetraMaterial4D:
	var texture := Palette.get_texture(palette_name)
	if texture == null:
		return flat(palette_name, alpha)

	var material := TetraMaterial4D.new()
	if alpha < 1.0:
		# ..._AND_SINGLE multiplies the texture by albedo_color, which is the only
		# way to get alpha through - the ..._ONLY source ignores albedo entirely.
		material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_AND_SINGLE
		material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	else:
		material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY

	# Swap the shader in BEFORE pushing the texture. Material4D only assigns its
	# built-in shader while the slot is empty, so ours survives; assigning the
	# texture afterwards re-runs update_cross_section_material() and binds
	# albedo_texture against the replacement rather than leaving it unbound. Same
	# ordering trick phase_maze_builder.gd documents.
	var cross_section: ShaderMaterial = material.get_cross_section_material_3d()
	cross_section.shader = TiledShader
	material.albedo_texture_3d = texture
	cross_section.set_shader_parameter("surface_size", size)
	cross_section.set_shader_parameter("texture_metres", maxf(texture_metres, 0.0001))
	cross_section.set_shader_parameter("texture_offset", texture_offset)
	return material


## Flat albedo sampled from the same dev PNG, on the stock shader. For surfaces
## where a texture would be noise, and as the fallback above.
static func flat(palette_name: String, alpha: float = 1.0) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	var color := Palette.get_color(palette_name)
	color.a = alpha
	material.albedo_color = color
	return material


## Picks tiled or flat from one switch, so callers do not each repeat the branch.
static func surface(palette_name: String, size: Vector4, texture_metres: float, textured: bool, alpha: float = 1.0) -> TetraMaterial4D:
	if textured:
		return tiled(palette_name, size, texture_metres, alpha)
	return flat(palette_name, alpha)
