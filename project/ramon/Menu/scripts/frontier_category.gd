@tool
extends Resource
class_name FrontierCategory

## One of the four kinds of proof, as drawn along the top of the Frontier Map.
##
## The categories are the screen's actual argument. Nine prototypes in a list
## read as nine unrelated demos; the same nine sorted into Orientation, Spatial
## Interaction, World Systems and Living Systems read as a research programme
## with coverage. That is the thing Menu2 cannot say, and it is why these are
## authored content rather than a hardcoded header row.

@export var label: String = "":
	set(value):
		label = value
		emit_changed()

## Which [FrontierEntry.Category] this heads. Kept as a plain int so the resource
## does not have to import the enum, and checked by the map when it groups nodes.
@export_enum("Orientation", "Spatial interaction", "World systems", "Living systems")
var category: int = 0:
	set(value):
		category = value
		emit_changed()

## Colour for the heading and its icon. One hue per kind of proof is what makes
## the curve legible as a progression rather than as decoration.
@export var color: Color = Color(0.29, 0.66, 1.0):
	set(value):
		color = value
		emit_changed()

## Colour for route edges ARRIVING in this category.
##
## Separate from `color` because the reference art does not use one hue for both:
## Spatial Interaction's heading is blue like Orientation's, but its stretch of
## the route is a muted grey. Heading colour groups the nodes; edge colour paces
## the journey, and they are allowed to differ.
@export var edge_color: Color = Color(0.29, 0.66, 1.0):
	set(value):
		edge_color = value
		emit_changed()

## Sub-maps head their bands with the same component but at a different weight:
## the 2027 map's Q1-Q4 are large, quiet chapter markers rather than small caps
## labels. A style rather than a font size so the two stay distinguishable when
## the type scale is retuned.
enum TextStyle { SECTION, QUARTER }

@export var text_style: TextStyle = TextStyle.SECTION:
	set(value):
		text_style = value
		emit_changed()

## Draws the little mark before the heading. Off for sub-map lanes, which are
## organisational bands rather than the four kinds of proof.
@export var show_mark: bool = true:
	set(value):
		show_mark = value
		emit_changed()

@export_group("Reference layout")
## Top-left of the heading text, in the 1920x1080 reference space.
@export var label_position: Vector2 = Vector2.ZERO:
	set(value):
		label_position = value
		emit_changed()

## The dotted vertical tick under the heading - x, then start and end y. It
## points down into the band of nodes the heading covers without drawing a box
## around them, which would cut the one continuous route into four panels.
##
## ZERO draws none, which is what sub-map lane headings want: their bands are
## already fenced by separators on both sides.
@export var drop_line: Vector3 = Vector3.ZERO:
	set(value):
		drop_line = value
		emit_changed()

## x of the faint dashed separator BEFORE this category, or -1 for none (the
## first category has nothing to its left). Separators run the height of the
## node field.
@export var separator_x: float = -1.0:
	set(value):
		separator_x = value
		emit_changed()
