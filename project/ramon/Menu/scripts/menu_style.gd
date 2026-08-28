@tool
extends Resource
class_name MenuStyle

## Every visual decision the menu makes, in one editable resource.
##
## Same idea as `Demo/sign_style.tres` driving both the hub signs and the return
## prompt: one resource, edited in the inspector, and everything that reads it
## restyles at once. Nothing in `menu_mockup.gd` hardcodes a size, a colour or a
## gap any more - it asks this.
##
## THE ONE IDEA: type and spacing are DERIVED, not listed.
##
## A menu with eight independently-set font sizes drifts - someone nudges one,
## the ramp stops being a ramp, and nothing looks deliberate. So there are two
## numbers instead: a base size and a ratio. Every role is a STEP on that scale
## (`size_for(TITLE)` is `base * ratio^2`), which means changing `base_font_size`
## moves the whole hierarchy together and keeps its proportions exactly. That is
## a modular scale, and it is how a type system stays coherent while still being
## fully adjustable.
##
## `ui_scale` multiplies type AND spacing together, so it zooms the whole design
## for a projector or a 4K panel without re-laying anything out.
##
## Spacing works the same way: one `spacing_unit`, and every gap and margin is a
## multiple of it. Change 8 to 10 and the entire layout breathes.

# --------------------------------------------------------------------------
# Type
# --------------------------------------------------------------------------

## Steps on the modular scale. Negative steps are smaller than body text.
## Used as `style.size_for(MenuStyle.TITLE)` rather than a raw number anywhere.
const MICRO: int = -2
const CAPTION: int = -1
const BODY: int = 0
const SUBTITLE: int = 1
const TITLE: int = 2
const DISPLAY: int = 3

@export_group("Type")
@export var font: Font = null:
	set(value):
		font = value
		emit_changed()

## The size of BODY text. Every other size is derived from it, so this is the
## single control that moves the whole hierarchy.
@export_range(8, 40, 1, "suffix:px") var base_font_size: int = 15:
	set(value):
		base_font_size = value
		emit_changed()

## Ratio between adjacent steps. 1.0 collapses the hierarchy to one size; 1.618
## is the golden ratio and is dramatic; 1.25-1.33 is the usual readable range.
@export_range(1.0, 1.8, 0.01) var type_ratio: float = 1.28:
	set(value):
		type_ratio = value
		emit_changed()

## Multiplies type and spacing together - a whole-design zoom for a projector or
## a 4K panel. Layout proportions are unaffected.
@export_range(0.5, 2.5, 0.05) var ui_scale: float = 1.0:
	set(value):
		ui_scale = value
		emit_changed()

## Tracking on the small all-caps labels. Capitals set tight read as a block;
## opening them out is what makes a label read as a label. Matches the tracking
## `sign_style.tres` applies to the hub signage.
@export_range(-10, 20, 1, "suffix:px") var label_tracking: int = 2:
	set(value):
		label_tracking = value
		emit_changed()

# --------------------------------------------------------------------------
# Spacing and shape
# --------------------------------------------------------------------------

@export_group("Spacing and shape")
## The rhythm unit. Every gap, margin and pad in the menu is a multiple of this.
@export_range(2, 24, 1, "suffix:px") var spacing_unit: int = 8:
	set(value):
		spacing_unit = value
		emit_changed()

@export_range(0, 32, 1, "suffix:px") var corner_radius: int = 8:
	set(value):
		corner_radius = value
		emit_changed()

@export_subgroup("Preview corners")
## The preview pane's corners, in pixels, each independently adjustable.
## Rounded by a shader rather than a mask, so these are live at any pane size.
## Setting all four equal is the ordinary case; unequal corners are there for
## when the pane wants to point at something.
@export_range(0, 90, 1, "suffix:px") var preview_corner_top_left: float = 14.0:
	set(value):
		preview_corner_top_left = value
		emit_changed()
@export_range(0, 90, 1, "suffix:px") var preview_corner_top_right: float = 14.0:
	set(value):
		preview_corner_top_right = value
		emit_changed()
@export_range(0, 90, 1, "suffix:px") var preview_corner_bottom_right: float = 14.0:
	set(value):
		preview_corner_bottom_right = value
		emit_changed()
@export_range(0, 90, 1, "suffix:px") var preview_corner_bottom_left: float = 14.0:
	set(value):
		preview_corner_bottom_left = value
		emit_changed()

## Edge feathering in pixels. 0 is hard and aliased, ~1 is clean.
@export_range(0.0, 4.0, 0.1, "suffix:px") var preview_edge_softness: float = 1.0:
	set(value):
		preview_edge_softness = value
		emit_changed()

## Aspect ratio the clips were RECORDED at - 1280x720, so 16:9.
##
## Separate from `preview_aspect`, which is the shape of the pane. The two are
## usually different: the pane stretches to whatever width the detail column
## gives it, and a 16:9 clip is then scaled to COVER that shape and cropped,
## never squeezed to fit it. Getting this wrong is what squashed the first cut.
@export_range(0.5, 3.0, 0.001) var clip_aspect: float = 1.7778:
	set(value):
		clip_aspect = value
		emit_changed()

## Default vertical crop for clips that do not set their own. 0 shows the top of
## the frame, 1 the bottom, 0.5 the middle. Each entry can override it, because
## the interesting part of a shot is in a different place in every prototype -
## the horizon in Sky Box Clouds, the rock in Voxel Mining.
@export_range(0.0, 1.0, 0.01) var preview_focus_default: float = 0.5:
	set(value):
		preview_focus_default = value
		emit_changed()

## Width of the accent bar marking the selected row.
@export_range(0, 12, 1, "suffix:px") var selection_bar: int = 3:
	set(value):
		selection_bar = value
		emit_changed()

# --------------------------------------------------------------------------
# Palette
# --------------------------------------------------------------------------

@export_group("Palette")
@export var background: Color = Color(0.055, 0.062, 0.080):
	set(value):
		background = value
		emit_changed()
@export var surface: Color = Color(0.098, 0.110, 0.135):
	set(value):
		surface = value
		emit_changed()
@export var surface_raised: Color = Color(0.140, 0.156, 0.190):
	set(value):
		surface_raised = value
		emit_changed()
@export var accent: Color = Color(0.0667, 0.3345, 0.6810):
	set(value):
		accent = value
		emit_changed()
@export var text: Color = Color(0.90, 0.92, 0.95):
	set(value):
		text = value
		emit_changed()
@export var text_dim: Color = Color(0.58, 0.62, 0.70):
	set(value):
		text_dim = value
		emit_changed()
@export var text_faint: Color = Color(0.40, 0.44, 0.52):
	set(value):
		text_faint = value
		emit_changed()
@export var positive: Color = Color(0.42, 0.78, 0.50):
	set(value):
		positive = value
		emit_changed()

## Heading colour for the measurements strip.
##
## Its own token rather than reusing `positive`, which means "played" on the row
## dots. A measurement is not a success, and two meanings sharing one colour is
## how a palette stops encoding anything. Muted teal keeps it distinct from both
## the blue cell headings and the green dots.
@export var benchmark_accent: Color = Color(0.45, 0.72, 0.70):
	set(value):
		benchmark_accent = value
		emit_changed()

## Fill for the Launch bar.
##
## It previously used Godot's default Button theme, which on this ground sat at
## almost exactly the panel colour - the most important control on the screen
## was the hardest thing to see. A step lighter than the surface is enough: it
## reads as a control without competing with the accent, which is spoken for by
## the hero banner and the selection bar.
@export var launch_fill: Color = Color(0.185, 0.205, 0.245):
	set(value):
		launch_fill = value
		emit_changed()

@export var launch_fill_hover: Color = Color(0.245, 0.270, 0.320):
	set(value):
		launch_fill_hover = value
		emit_changed()

# --------------------------------------------------------------------------
# Layout
# --------------------------------------------------------------------------

@export_group("Layout")
## Width of the banner column, before ui_scale. The detail pane takes the rest.
@export_range(280, 900, 10, "suffix:px") var list_width: float = 520.0:
	set(value):
		list_width = value
		emit_changed()

## Preview pane aspect. 1.777 is 16:9 and matches what the clips are recorded
## at; anything else letterboxes or crops them.
@export_range(1.0, 2.6, 0.001) var preview_aspect: float = 1.7778:
	set(value):
		preview_aspect = value
		emit_changed()

@export_range(40, 200, 2, "suffix:px") var thumbnail_width: float = 132.0:
	set(value):
		thumbnail_width = value
		emit_changed()

## Tint for the banner icons. Pure white sits at the very top of the value range
## and out-shouts the titles beside it, which are the thing the row is actually
## for. Knocking the glyphs back to a light grey puts them below the type in the
## hierarchy without making them look faded.
@export var thumbnail_tint: Color = Color(0.74, 0.77, 0.82):
	set(value):
		thumbnail_tint = value
		emit_changed()

@export_subgroup("Info cells")
## Step on the type scale for the cell HEADINGS. One step above the body they
## introduce, so they lead into it instead of sitting level with it.
@export_range(-3, 3, 1) var info_label_step: int = 0:
	set(value):
		info_label_step = value
		emit_changed()

## Step for the cell BODY text.
@export_range(-3, 3, 1) var info_body_step: int = -1:
	set(value):
		info_body_step = value
		emit_changed()

## Fine adjustment in PIXELS, on top of the step above.
##
## The modular scale moves in whole steps, and a step is a ~28% jump - far more
## than "nudge it one point bigger" ever means. These two let the info text be
## tuned by single pixels without leaving the scale or dragging every other size
## along with it.
@export_range(-6, 6, 1, "suffix:px") var info_label_nudge: int = 0:
	set(value):
		info_label_nudge = value
		emit_changed()

@export_range(-6, 6, 1, "suffix:px") var info_body_nudge: int = 1:
	set(value):
		info_body_nudge = value
		emit_changed()

@export_subgroup("Detail pane spacing")
## Vertical gap between the blocks stacked down the detail pane - preview,
## title, blurb, controls, cells, measurements. In spacing units, fractional, so
## it can be dragged to taste rather than jumping in whole steps.
@export_range(0.5, 8.0, 0.1) var detail_paragraph_gap: float = 2.0:
	set(value):
		detail_paragraph_gap = value
		emit_changed()

## Horizontal gap between the three info cells.
@export_range(0.5, 8.0, 0.1) var info_cell_h_gap: float = 2.0:
	set(value):
		info_cell_h_gap = value
		emit_changed()

## Vertical gap between an info cell's heading and its body.
@export_range(0.0, 4.0, 0.1) var info_cell_label_gap: float = 0.5:
	set(value):
		info_cell_label_gap = value
		emit_changed()

## How many info cells sit side by side before wrapping. Three fits the
## question/approach/finding schema; two gives them more width on a narrow
## screen.
@export_range(1, 4, 1) var info_columns: int = 3:
	set(value):
		info_columns = value
		emit_changed()

## Turns the whole info block off, for a stakeholder-only build where the
## reading is a distraction rather than a feature.
@export var show_info_cells: bool = true:
	set(value):
		show_info_cells = value
		emit_changed()

@export var show_control_keys: bool = true:
	set(value):
		show_control_keys = value
		emit_changed()

# --------------------------------------------------------------------------
# Derived values - the whole point of the resource
# --------------------------------------------------------------------------

## Font size for a step on the modular scale. Never hardcode a size; ask for a
## role and let the ramp decide.
func size_for(step: int) -> int:
	return maxi(6, int(round(float(base_font_size) * pow(type_ratio, float(step)) * ui_scale)))


## A multiple of the spacing unit, scaled. `space(2)` is two units.
func space(multiplier: float) -> int:
	return maxi(0, int(round(float(spacing_unit) * multiplier * ui_scale)))


## Any authored pixel length, scaled the same way as everything else. Used for
## list width and thumbnail size so ui_scale zooms them too.
func scaled(pixels: float) -> float:
	return pixels * ui_scale


## The font with label tracking applied. A FontVariation is built per call
## rather than cached, because caching it would need invalidating every time the
## style changed and this is called a few dozen times on one screen build.
func label_font() -> Font:
	if font == null or label_tracking == 0:
		return font
	var variation := FontVariation.new()
	variation.base_font = font
	variation.set_spacing(TextServer.SPACING_GLYPH, label_tracking)
	return variation
