@tool
extends RefCounted

## Shared colour legend for the Demo hub, sampled from the project's dev textures.
##
## The hub deliberately uses FEWER colours than any prototype it links to. It is
## the frame around the work, not a competitor to it, so `red` and `blue` are
## reserved: red already means "primary target" inside the shooting gallery, and
## blue is claimed here for signage only. Structural geometry is greyscale.
##
## Colours are sampled from `res://textures/dev_finals/ramdev_*.png` at runtime
## rather than hardcoded, so editing those PNGs re-tints the hub without touching
## code. [constant FALLBACKS] covers the case where the image cannot be read -
## imported textures are not guaranteed to hand back an uncompressed [Image], and
## a hub that renders in the wrong grey is far better than one that fails to load.
##
## The dev PNGs are imported with `importer="3d_texture"`, so they load as
## [CompressedTexture3D] rather than [Texture2D] - a single-slice volume. That is
## exactly the type [TetraMaterial4D] wants for `albedo_texture_3d`, so they can
## be mapped onto 4D geometry directly. [method get_texture] exposes them for
## that; the colours below are for cases where flat albedo is wanted instead.

const TEXTURE_DIR := "res://textures/dev_finals/"

## Sampled at this fraction across the image. The dev textures carry grid lines
## on their edges and at the halfway point, so both 0.5 and the corners would
## pick up a line rather than the base colour. 0.25 lands inside the first tile.
const SAMPLE_UV := 0.25

## Used when a texture is missing or its image cannot be decoded. Measured from
## the committed PNGs so the hub looks identical either way.
const FALLBACKS := {
	"grey": Color(0.447, 0.447, 0.447),
	"white": Color(0.902, 0.902, 0.902),
	"black": Color(0.106, 0.106, 0.106),
	"black_metal": Color(0.149, 0.153, 0.161),
	"dark_grey": Color(0.216, 0.216, 0.216),
	"yellow": Color(0.886, 0.949, 0.322),
	"blue": Color(0.235, 0.510, 0.808),
	"red": Color(0.831, 0.204, 0.196),
}

static var _cache: Dictionary = {}


## Every palette name available as `ramdev_<name>.png`, sorted.
##
## Scanned from disk rather than hard-coded, so dropping a new PNG into
## dev_finals/ adds it to every colour dropdown without anyone editing code - which
## is the same reason the colours themselves are sampled from the images rather
## than written down twice.
##
## Falls back to the [constant FALLBACKS] keys when the directory cannot be listed.
## That is not a theoretical branch: an exported build has no `res://` directory to
## walk, so without it the dropdowns would come up empty outside the editor.
static func get_names() -> PackedStringArray:
	var names := PackedStringArray()
	var dir := DirAccess.open(TEXTURE_DIR)
	if dir != null:
		for file in dir.get_files():
			# .import sidecars share the stem, so filter on extension rather than
			# on the prefix alone or every name would appear twice.
			if file.begins_with("ramdev_") and file.get_extension() == "png":
				names.append(file.get_basename().trim_prefix("ramdev_"))
	if names.is_empty():
		for key in FALLBACKS:
			names.append(key)
	names.sort()
	return names


## The same list as a PROPERTY_HINT_ENUM hint string, for inspector dropdowns.
static func get_names_hint() -> String:
	return ",".join(get_names())


## Returns the base colour of `ramdev_<name>.png`, cached after the first read.
static func get_color(name: String) -> Color:
	if _cache.has(name):
		return _cache[name]
	var result: Color = FALLBACKS.get(name, Color.MAGENTA)
	var image := _first_image(get_texture(name))
	if image != null and image.get_width() > 0:
		var x := int(image.get_width() * SAMPLE_UV)
		var y := int(image.get_height() * SAMPLE_UV)
		result = image.get_pixel(x, y)
	_cache[name] = result
	return result


## Returns the imported dev texture itself, ready to hand to
## [member TetraMaterial4D.albedo_texture_3d]. Null if the file is missing.
static func get_texture(name: String) -> Texture3D:
	var path := TEXTURE_DIR + "ramdev_" + name + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture3D


## Pulls the first slice out of a 3D texture as a readable [Image]. These import
## as a single-slice volume, so slice 0 is the whole picture.
static func _first_image(texture: Texture3D) -> Image:
	if texture == null:
		return null
	var layers := texture.get_data()
	if layers == null or layers.is_empty():
		return null
	var image: Image = layers[0]
	if image == null:
		return null
	# VRAM-compressed imports block get_pixel(). Decompressing is cheap and only
	# happens once per colour, behind the cache.
	if image.is_compressed() and image.decompress() != OK:
		return null
	return image


## Structure: floors, walls, gate frames. Everything w-invariant and inert.
static func structure() -> Color:
	return get_color("grey")


## Interaction and 4D relevance. Threshold pads, the parts you are meant to touch,
## and anything whose cross-section changes when you slice-rotate.
static func accent() -> Color:
	return get_color("yellow")


## Signage panels only. Saturated against a desaturated world, so it reads at any
## ambient brightness without relying on being lighter or darker than the wall.
static func signage() -> Color:
	return get_color("blue")


## Text and icons drawn on top of [method signage].
static func signage_text() -> Color:
	return get_color("white")


## Gate state indicator once a prototype has been visited. State is the only job
## colour does on a gate - identity is carried by the billboard icon instead.
static func visited() -> Color:
	return get_color("white")


static func clear_cache() -> void:
	_cache.clear()
