@tool
extends Resource
class_name HubSignStyle4D

## Typography for the hub's signs, in one asset the gates and the preview board
## both point at.
##
## WHY A RESOURCE rather than exports on each node: the sign is authored in
## _sign_board.tscn and rendered by hub_gate_4d.gd, and those are different scenes.
## Duplicating a dozen typographic controls across both guarantees they drift, and
## a preview that drifts from the thing it previews is worse than no preview. One
## `.tres` assigned in both places means editing tracking once changes what you see
## AND what ships.
##
## Everything here maps to something [Label3D] can actually do - `uppercase`,
## `line_spacing`, `outline_size`, `outline_modulate` are its own properties, and
## tracking/weight go through a [FontVariation] wrapping the base font. Nothing is
## exposed that the real sign cannot honour, because the board's whole job is to
## not lie.

@export var font: Font:
	set(value):
		font = value
		emit_changed()

@export_group("Panel")
## Sign panel size in metres, width by height.
##
## Lives here rather than on each node because it was the one setting the preview
## and the hub could disagree about, and they did: the board was authored at
## 3.0 x 0.7 while the ring still had the 2.0 x 1.0 default. That changes the
## aspect AND the blurb's wrap width, so no amount of correct typography could make
## the game match what was designed. Everything else was already shared; this was
## the hole in it.
@export var panel_size: Vector2 = Vector2(2.0, 1.0):
	set(value):
		panel_size = value
		# Mask aspect is derived from this, so it has to be rebuilt.
		_mask = null
		emit_changed()

## Corner rounding on the panel, in metres.
##
## Delivered as an ALPHA MASK rather than as geometry, because the sign is a
## [QuadMesh] and a quad has four corners by definition. The mask is generated
## here so the 2D preview and the in-game panel round by the same number.
@export_range(0.0, 0.5, 0.01, "suffix:m") var corner_radius: float = 0.0:
	set(value):
		corner_radius = value
		_mask = null
		emit_changed()

## Panel fill. Defaults to the palette's signage blue, so leaving it alone matches
## what the hub shipped with; overriding it takes the sign off the palette, which
## is fine for signage since the legend only reserves colour meanings for geometry.
@export var panel_color: Color = Color(0.235, 0.510, 0.808, 1.0):
	set(value):
		panel_color = value
		emit_changed()

## Title, blurb and icon colour. They share one, deliberately - a sign whose title
## and body differ in hue reads as two signs.
@export var text_color: Color = Color(0.902, 0.902, 0.902, 1.0):
	set(value):
		text_color = value
		emit_changed()

@export_group("Title")
@export var title_uppercase: bool = false:
	set(value):
		title_uppercase = value
		emit_changed()

@export_range(8, 256, 1) var title_font_size: int = 64:
	set(value):
		title_font_size = value
		emit_changed()

## Metres per font pixel. Glyph height in metres is `font_size * pixel_size`, so
## these two together - not either alone - decide whether a sign reads.
@export_range(0.0005, 0.02, 0.0001, "suffix:m") var title_pixel_size: float = 0.003:
	set(value):
		title_pixel_size = value
		emit_changed()

@export_group("Blurb")
@export var blurb_uppercase: bool = false:
	set(value):
		blurb_uppercase = value
		emit_changed()

@export_range(8, 256, 1) var blurb_font_size: int = 32:
	set(value):
		blurb_font_size = value
		emit_changed()

@export_range(0.0005, 0.02, 0.0001, "suffix:m") var blurb_pixel_size: float = 0.0025:
	set(value):
		blurb_pixel_size = value
		emit_changed()

## How much of the available text column the blurb may fill before it wraps, as a
## fraction of it.
##
## A ratio rather than a width in metres so it survives [member panel_size]
## changing - a fixed 1.4 m cap silently becomes "the whole column" the moment the
## panel narrows, which is the bug this is meant to prevent. Pull it down to force
## an earlier wrap and keep the blurb as a tight block under the title instead of a
## single line running the full width of the sign.
@export_range(0.1, 1.0, 0.01) var blurb_width_ratio: float = 1.0:
	set(value):
		blurb_width_ratio = value
		emit_changed()

@export_group("Typography")
## Tracking on the TITLE, in font pixels at its own font size.
##
## Separate from the blurb's on purpose, because they want opposite treatment: a
## title set in caps needs opening out, since caps at body tracking look cramped,
## while a small blurb at the same tracking falls apart into loose letters. One
## shared value cannot be right for both.
@export_range(-20, 40, 1, "suffix:px") var title_letter_spacing: int = 0:
	set(value):
		title_letter_spacing = value
		emit_changed()

@export_range(-20, 60, 1, "suffix:px") var title_word_spacing: int = 0:
	set(value):
		title_word_spacing = value
		emit_changed()

## Tracking on the BLURB. Usually 0 or slightly negative - it is set small, and
## small text needs tighter fitting than a display line does.
@export_range(-20, 40, 1, "suffix:px") var blurb_letter_spacing: int = 0:
	set(value):
		blurb_letter_spacing = value
		emit_changed()

@export_range(-20, 60, 1, "suffix:px") var blurb_word_spacing: int = 0:
	set(value):
		blurb_word_spacing = value
		emit_changed()

## Weight along a VARIABLE font's `wght` axis. 0 leaves the axis alone.
##
## DOES NOT WORK in this engine build, and the failure is silent - measured, not
## assumed. Montserrat's variable file reports its axis correctly
## (`get_supported_variation_list()` returns tag 2003265652 spanning 100 to 900),
## and [FontVariation] stores the value back faithfully, but the rendered glyphs do
## not change: "QUANTUM RANGE" measures exactly 931.00 px at 100, 400, 700 and 900,
## with String and StringName keys alike. Tracking through the same [FontVariation]
## does work, so the object is live - only this axis is inert.
##
## The trap on top of that: the variable file's DEFAULT instance is weight 100, so
## assigning it gets you Thin, not Regular, and it looks like a styling mistake
## rather than an engine one.
##
## Use the static files in fonts/Montserrat/static/ instead - Medium, SemiBold,
## Bold, Black are all there as separate faces, with letterforms the designer
## actually drew. Left exposed because it costs nothing and may start working on an
## engine bump.
@export_range(0, 900, 25) var font_weight: int = 0:
	set(value):
		font_weight = value
		emit_changed()

## Synthetic weight, for fonts with no `wght` axis. Thickens outlines rather than
## using designed letterforms, so it is the fallback rather than the first choice.
@export_range(-0.5, 1.0, 0.01) var embolden: float = 0.0:
	set(value):
		embolden = value
		emit_changed()

@export_range(-20.0, 40.0, 0.5, "suffix:px") var line_spacing: float = 0.0:
	set(value):
		line_spacing = value
		emit_changed()

@export_group("Outline")
## Outline is the cheapest way to keep a sign readable against a busy or
## differently-lit background, which matters here because slice rotation swings
## what is behind a sign without the sign moving at all.
@export_range(0, 64, 1, "suffix:px") var outline_size: int = 0:
	set(value):
		outline_size = value
		emit_changed()

@export var outline_color: Color = Color(0.0, 0.0, 0.0, 1.0):
	set(value):
		outline_color = value
		emit_changed()


## The font to actually draw with, wrapped in a [FontVariation] when any of the
## variation controls are non-default.
##
## [param size_scale] rescales the spacing values. Tracking is specified in font
## pixels, so it only stays proportional if it scales with the font size - and the
## 2D preview draws at `font_size * pixel_size * pixels_per_metre` rather than at
## [member title_font_size]. Without this the board would show correct letterforms
## at the wrong tracking, which is exactly the kind of quiet lie to avoid.
func make_title_font(size_scale: float = 1.0) -> Font:
	return _make_font(title_letter_spacing, title_word_spacing, size_scale)


func make_blurb_font(size_scale: float = 1.0) -> Font:
	return _make_font(blurb_letter_spacing, blurb_word_spacing, size_scale)


func _make_font(letter: int, word: int, size_scale: float) -> Font:
	var plain: bool = letter == 0 and word == 0 and is_zero_approx(embolden) and font_weight <= 0
	if plain:
		return font
	var variation := FontVariation.new()
	if font != null:
		variation.base_font = font
	variation.variation_embolden = embolden
	if font_weight > 0:
		variation.variation_opentype = {&"wght": font_weight}
	variation.set_spacing(TextServer.SPACING_GLYPH, roundi(letter * size_scale))
	variation.set_spacing(TextServer.SPACING_SPACE, roundi(word * size_scale))
	return variation


## Defaults for the two colours, kept as constants so the Nil-tolerant accessors
## below have something to fall back to without reaching for the palette.
const DEFAULT_PANEL_COLOR := Color(0.235, 0.510, 0.808, 1.0)
const DEFAULT_TEXT_COLOR := Color(0.902, 0.902, 0.902, 1.0)


## Nil-tolerant reads, because a Resource has the same stale-property-table problem
## a node does: a `.tres` already loaded when its script gains a property returns
## Nil for it until something reloads it.
##
## For most types that degrades quietly, but assigning Nil to a Color property is a
## hard error - it took down the whole board with a thousand identical
## "Invalid assignment of property 'modulate'" messages rather than one readable
## one. Falling back to the default costs nothing and cannot fail.
func get_panel_color() -> Color:
	return panel_color if typeof(panel_color) == TYPE_COLOR else DEFAULT_PANEL_COLOR


func get_text_color() -> Color:
	return text_color if typeof(text_color) == TYPE_COLOR else DEFAULT_TEXT_COLOR


## Height of the generated corner mask. The only detail it carries is four arcs,
## so this needs to be big enough that they do not stair-step - not big enough to
## resolve the panel.
const MASK_HEIGHT_PX := 256

var _mask: Texture2D = null


## Rounded-rectangle alpha mask for the panel, or null when rounding is off.
##
## Only the four CORNER squares are actually computed - roughly 4 * r^2 pixels
## rather than the whole image - because everything else is opaque by definition.
## At a typical radius that is a few thousand pixels instead of a hundred thousand,
## which matters because this runs in a @tool script on every rebuild.
##
## Edges are antialiased by coverage (`radius - distance`, clamped) rather than
## thresholded, since a hard cut would alias badly on a sign the player walks
## toward. Cached until something invalidates it.
func make_corner_mask() -> Texture2D:
	if corner_radius <= 0.0 or panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return null
	if _mask != null:
		return _mask

	var height := MASK_HEIGHT_PX
	var width: int = clampi(roundi(height * panel_size.x / panel_size.y), 4, 2048)
	# Metres to mask pixels. Clamped to half the short side, since a radius past
	# that is not a rounded rectangle any more and the arcs would cross.
	var radius: float = minf(corner_radius / panel_size.y * float(height), minf(width, height) * 0.5)

	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))

	var span := int(ceil(radius))
	for cy in span:
		for cx in span:
			# Distance from the corner's arc centre, which sits `radius` in from
			# both edges. +0.5 samples pixel centres.
			var dx := radius - (float(cx) + 0.5)
			var dy := radius - (float(cy) + 0.5)
			if dx < 0.0 or dy < 0.0:
				continue
			var alpha: float = clampf(radius - sqrt(dx * dx + dy * dy) + 0.5, 0.0, 1.0)
			if alpha >= 1.0:
				continue
			var colour := Color(1.0, 1.0, 1.0, alpha)
			image.set_pixel(cx, cy, colour)
			image.set_pixel(width - 1 - cx, cy, colour)
			image.set_pixel(cx, height - 1 - cy, colour)
			image.set_pixel(width - 1 - cx, height - 1 - cy, colour)

	_mask = ImageTexture.create_from_image(image)
	return _mask


## Case-folded text, so callers never have to remember which flag applies where.
func apply_title_case(text: String) -> String:
	return text.to_upper() if title_uppercase else text


func apply_blurb_case(text: String) -> String:
	return text.to_upper() if blurb_uppercase else text
