@tool
extends Resource
class_name FrontierStyle

## Every colour and dimension the Frontier Map draws with.
##
## Same contract as [MenuStyle]: nothing in `frontier_map.gd` hardcodes a colour
## or a size, it asks this. Kept SEPARATE from `menu2_style.tres` rather than
## extending it, because the two screens are deliberately different objects - a
## warm dark list versus a cold navy chart - and one shared palette would mean
## retuning either one drags the other with it.
##
## SIZES ARE IN REFERENCE PIXELS. Everything is authored against the 1920x1080
## mock-up and the whole map is scaled uniformly to the window by the map script,
## so these numbers can be read straight off the reference art. There is no
## modular scale here on purpose: this is a chart with measured positions, not a
## type hierarchy that has to stay in proportion as it grows.

@export_group("Type")
@export var font: Font = null:
	set(value):
		font = value
		emit_changed()

@export_range(6, 60, 1, "suffix:px") var title_size: int = 37:
	set(value):
		title_size = value
		emit_changed()

@export_range(6, 30, 1, "suffix:px") var eyebrow_size: int = 13:
	set(value):
		eyebrow_size = value
		emit_changed()

@export_range(6, 30, 1, "suffix:px") var section_size: int = 13:
	set(value):
		section_size = value
		emit_changed()

@export_range(6, 30, 1, "suffix:px") var node_label_size: int = 15:
	set(value):
		node_label_size = value
		emit_changed()

@export_range(6, 30, 1, "suffix:px") var node_sub_size: int = 11:
	set(value):
		node_sub_size = value
		emit_changed()

@export_range(6, 40, 1, "suffix:px") var panel_title_size: int = 24:
	set(value):
		panel_title_size = value
		emit_changed()

@export_range(6, 30, 1, "suffix:px") var body_size: int = 14:
	set(value):
		body_size = value
		emit_changed()

@export_range(6, 30, 1, "suffix:px") var small_caps_size: int = 11:
	set(value):
		small_caps_size = value
		emit_changed()

## Tracking for the all-caps labels. The reference art opens these out a long
## way - it is most of what makes the screen read as a chart rather than a menu.
@export_range(0, 12, 1, "suffix:px") var caps_tracking: int = 3:
	set(value):
		caps_tracking = value
		emit_changed()

@export_range(0, 12, 1, "suffix:px") var section_tracking: int = 3:
	set(value):
		section_tracking = value
		emit_changed()

@export_group("Ground")
@export var background: Color = Color("#08131f"):
	set(value):
		background = value
		emit_changed()
@export var background_far: Color = Color("#0b1825"):
	set(value):
		background_far = value
		emit_changed()
@export var header_fill: Color = Color("#060d15"):
	set(value):
		header_fill = value
		emit_changed()
@export var rule: Color = Color("#1b2b3c"):
	set(value):
		rule = value
		emit_changed()
@export var divider: Color = Color("#26384d"):
	set(value):
		divider = value
		emit_changed()
@export var separator: Color = Color("#1b2d41"):
	set(value):
		separator = value
		emit_changed()

@export_group("Text")
@export var text_bright: Color = Color("#eef4ff"):
	set(value):
		text_bright = value
		emit_changed()
@export var text: Color = Color("#e8eef8"):
	set(value):
		text = value
		emit_changed()
@export var text_dim: Color = Color("#afbbcd"):
	set(value):
		text_dim = value
		emit_changed()
@export var text_faint: Color = Color("#8291a8"):
	set(value):
		text_faint = value
		emit_changed()
@export var text_section: Color = Color("#73859d"):
	set(value):
		text_section = value
		emit_changed()
@export var text_legend: Color = Color("#8b99ad"):
	set(value):
		text_legend = value
		emit_changed()

@export_group("Node states")
@export_subgroup("Played")
@export var played_fill: Color = Color("#0d2236"):
	set(value):
		played_fill = value
		emit_changed()
@export var played_stroke: Color = Color("#5bb8ff"):
	set(value):
		played_stroke = value
		emit_changed()
@export var played_glyph: Color = Color("#b8c9de"):
	set(value):
		played_glyph = value
		emit_changed()
## Fill of the small tick disc on a played node.
@export var check_fill: Color = Color("#258ae8"):
	set(value):
		check_fill = value
		emit_changed()

@export_subgroup("Available")
@export var available_fill: Color = Color("#0b1622"):
	set(value):
		available_fill = value
		emit_changed()
@export var available_stroke: Color = Color("#8fa2b8"):
	set(value):
		available_stroke = value
		emit_changed()
@export var available_glyph: Color = Color("#b3c0d2"):
	set(value):
		available_glyph = value
		emit_changed()

@export_subgroup("Research")
@export var research_fill: Color = Color("#17152b"):
	set(value):
		research_fill = value
		emit_changed()
@export var research_stroke: Color = Color("#a77af4"):
	set(value):
		research_stroke = value
		emit_changed()

@export_subgroup("Upcoming")
## Named and placed, not built. Reads as live work rather than as a dead slot -
## teal, the World Systems hue, because that is the band it will land in.
@export var upcoming_fill: Color = Color("#102839"):
	set(value):
		upcoming_fill = value
		emit_changed()
@export var upcoming_stroke: Color = Color("#61d4e7"):
	set(value):
		upcoming_stroke = value
		emit_changed()

@export_subgroup("Fog")
@export var fog_fill: Color = Color("#09131e"):
	set(value):
		fog_fill = value
		emit_changed()
@export var fog_stroke: Color = Color("#536278"):
	set(value):
		fog_stroke = value
		emit_changed()

@export_subgroup("Selection")
## The ring drawn OUTSIDE the selected node. Selection is a ring rather than a
## fill change so it can sit on top of any state without destroying the state's
## own colour - a played node stays visibly played while selected.
@export var selection_ring: Color = Color("#5cc2ff"):
	set(value):
		selection_ring = value
		emit_changed()

## Keyboard/controller focus, drawn as a second dashed ring further out.
##
## Its own colour and its own ring because focus and selection are different
## things here: the brief requires visible focus INDEPENDENT of hover, and a
## controller user moving through nodes needs to see where they are before they
## commit to selecting it.
@export var focus_ring: Color = Color("#ffd9a0"):
	set(value):
		focus_ring = value
		emit_changed()

@export_group("Accents")
@export var gate_gold: Color = Color("#d5b56b"):
	set(value):
		gate_gold = value
		emit_changed()
@export var gate_gold_bright: Color = Color("#ffe29a"):
	set(value):
		gate_gold_bright = value
		emit_changed()
@export var gate_gold_ink: Color = Color("#17202a"):
	set(value):
		gate_gold_ink = value
		emit_changed()

## The blue numbered activity badge. Its own tokens rather than reusing the
## selection ring: a badge and a selection mean different things, and one colour
## serving two meanings is how a palette stops encoding anything.
@export var badge_fill: Color = Color("#1269a8"):
	set(value):
		badge_fill = value
		emit_changed()

@export var badge_stroke: Color = Color("#6fc9ff"):
	set(value):
		badge_stroke = value
		emit_changed()

@export var panel_fill: Color = Color("#102237"):
	set(value):
		panel_fill = value
		emit_changed()
@export var panel_fill_far: Color = Color("#09131f"):
	set(value):
		panel_fill_far = value
		emit_changed()
@export var panel_stroke: Color = Color("#294058"):
	set(value):
		panel_stroke = value
		emit_changed()
@export var panel_head: Color = Color("#5cb2ff"):
	set(value):
		panel_head = value
		emit_changed()

@export var button_fill: Color = Color("#0d569c"):
	set(value):
		button_fill = value
		emit_changed()
@export var button_stroke: Color = Color("#2d8ee4"):
	set(value):
		button_stroke = value
		emit_changed()
@export var button_fill_hover: Color = Color("#1268b8"):
	set(value):
		button_fill_hover = value
		emit_changed()
## Launch drawn when the selected node cannot be entered.
@export var button_fill_disabled: Color = Color("#16202c"):
	set(value):
		button_fill_disabled = value
		emit_changed()

@export var tab_active_fill: Color = Color("#0e2942"):
	set(value):
		tab_active_fill = value
		emit_changed()
@export var tab_active_stroke: Color = Color("#4ba9ff"):
	set(value):
		tab_active_stroke = value
		emit_changed()
@export var tab_idle_fill: Color = Color("#0b151f"):
	set(value):
		tab_idle_fill = value
		emit_changed()
@export var tab_idle_stroke: Color = Color("#2a394b"):
	set(value):
		tab_idle_stroke = value
		emit_changed()

@export_group("Geometry")
## The banner's height is NOT here - it is `MenuBanner.HEIGHT`, a constant, so
## the bar cannot end up a different size on the two screens that share it.
##
## Icon drawn inside a node, as a fraction of the node's radius.
##
## Small on purpose. The reference art sits its glyphs well inside the circle,
## and the ring - not the picture - is what carries the node's state. An icon
## that fills the circle turns a state indicator into a button.
@export_range(0.3, 1.4, 0.01) var node_icon_scale: float = 0.72:
	set(value):
		node_icon_scale = value
		emit_changed()

@export_range(10, 90, 1, "suffix:px") var node_radius: float = 38.0:
	set(value):
		node_radius = value
		emit_changed()

## Selected nodes grow slightly. Small on purpose - the reference art moves from
## 38 to 42, which reads as emphasis without shoving the neighbours' labels.
@export_range(0, 20, 1, "suffix:px") var node_radius_selected_bonus: float = 4.0:
	set(value):
		node_radius_selected_bonus = value
		emit_changed()

@export_range(0, 40, 1, "suffix:px") var selection_ring_gap: float = 10.0:
	set(value):
		selection_ring_gap = value
		emit_changed()

@export_range(0.5, 8.0, 0.1, "suffix:px") var node_stroke_width: float = 2.0:
	set(value):
		node_stroke_width = value
		emit_changed()

## Gap between a node's circle and where its route edge starts, so the curve
## does not appear to grow out of the outline.
@export_range(0, 30, 1, "suffix:px") var edge_gap: float = 6.0:
	set(value):
		edge_gap = value
		emit_changed()

@export_range(0.5, 8.0, 0.1, "suffix:px") var edge_width: float = 2.3:
	set(value):
		edge_width = value
		emit_changed()

## How far the bezier control points reach horizontally, as a fraction of the
## gap between two nodes. Higher is loopier. This is the only number that
## controls the character of the whole route.
@export_range(0.0, 1.0, 0.01) var edge_curvature: float = 0.45:
	set(value):
		edge_curvature = value
		emit_changed()

@export_range(2, 64, 1) var edge_segments: int = 24:
	set(value):
		edge_segments = value
		emit_changed()

@export_range(20, 90, 1, "suffix:px") var gateway_radius: float = 41.0:
	set(value):
		gateway_radius = value
		emit_changed()

## Minimum clickable square around a node, per the brief's 44x44 floor. Applied
## in REFERENCE pixels before scaling, so it holds at the design size.
@export_range(20, 120, 1, "suffix:px") var min_hit_size: float = 44.0:
	set(value):
		min_hit_size = value
		emit_changed()


## The font with caps tracking applied. Built per call rather than cached, the
## same trade [MenuStyle.label_font] makes and for the same reason.
func caps_font(tracking: int = -1) -> Font:
	var amount: int = caps_tracking if tracking < 0 else tracking
	if font == null or amount == 0:
		return font
	var variation := FontVariation.new()
	variation.base_font = font
	variation.set_spacing(TextServer.SPACING_GLYPH, amount)
	return variation
