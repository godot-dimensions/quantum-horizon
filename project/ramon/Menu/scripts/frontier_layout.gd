@tool
extends Resource
class_name FrontierLayout

## Everything the Frontier Map places on screen, and every fixed string on it.
##
## Companion to `entries/catalogue.tres`, not a replacement for it. The catalogue
## owns what a prototype IS - title, blurb, controls, findings, benchmark, scene
## path - and stays the single source of truth shared with Menu2. This owns only
## what the MAP adds on top: where each node sits, which category it proves, what
## state it is in, and the planning gateways that are not prototypes at all.
##
## Adding a prototype is therefore two edits, and they mean different things: an
## entry in the catalogue says it exists, a placement here says where it belongs
## in the argument. A node placed here with no matching catalogue title is
## reported rather than silently skipped - see `frontier_map.gd`.

## The ten node placements. ORDER HERE IS IRRELEVANT - the route follows the
## catalogue's array order, which is the project's one running order.
@export var placements: Array[FrontierEntry] = []

@export var categories: Array[FrontierCategory] = []

## Explicit connections, used by SUB-MAPS.
##
## The overview leaves this empty and derives its route from catalogue order
## instead - see `route_from_catalogue`. On a sub-map a line means "this work
## plausibly enables that work", which no ordering can express, so those maps
## name every edge.
@export var edges: Array[FrontierEdge] = []

## True only for the overview. When set, the route is the catalogue's array
## order and `edges` is ignored; the line means "next in the tour".
@export var route_from_catalogue: bool = false:
	set(value):
		route_from_catalogue = value
		emit_changed()

## "FRONTIER MAP  /  OCTOBER GATE". Empty on the overview, which is the root.
@export var breadcrumb: String = "":
	set(value):
		breadcrumb = value
		emit_changed()

## Gold pill under the breadcrumb - the October Gate's "ESTIMATED · ENGINEER
## VALIDATION REQUIRED". Empty draws nothing.
@export var caveat: String = "":
	set(value):
		caveat = value
		emit_changed()

## Teal pill at the top right of the field - "NEXT-CYCLE SIGNAL OPEN". Clicking
## it opens the drawer straight onto its signal tab.
@export var signal_pill: String = "":
	set(value):
		signal_pill = value
		emit_changed()

## Which node's activity the signal pill opens.
@export var signal_node: String = "":
	set(value):
		signal_node = value
		emit_changed()

## The detail panel's box. Sub-maps run it full width under a taller field; the
## overview keeps it to the left half.
@export var panel_rect: Rect2 = Rect2(70, 670, 890, 300):
	set(value):
		panel_rect = value
		emit_changed()

## Vertical span of the lane separators, and where the caption sits.
@export var field_span: Vector2 = Vector2(220, 566):
	set(value):
		field_span = value
		emit_changed()

@export var caption_position: Vector2 = Vector2(70, 566):
	set(value):
		caption_position = value
		emit_changed()

## Default action-button label for nodes that do not name their own.
@export var action_label: String = "LAUNCH":
	set(value):
		action_label = value
		emit_changed()

@export var gateways: Array[FrontierGateway] = []

## Centre of the decorative haze past the last gateway, or ZERO for none.
##
## DECORATION, and it must stay decoration. The brief is explicit that these
## shapes "imply unknown future work and must not read as committed features",
## so they carry no title, no count, no focus and no click - which is also the
## Gravity paper's own fog rule: near work shows as silhouettes, far work as
## undifferentiated atmosphere. The moment a shape out here acquires a label it
## has become a promise.
@export var fog_teaser_position: Vector2 = Vector2.ZERO:
	set(value):
		fog_teaser_position = value
		emit_changed()

@export_group("Screen text")
@export var eyebrow: String = "QUANTUM HORIZON":
	set(value):
		eyebrow = value
		emit_changed()

@export var title: String = "FRONTIER MAP":
	set(value):
		title = value
		emit_changed()

## The mode-switch labels are NOT here - they live on [MenuCatalogue], which
## both screens already load, so the switch cannot be named differently on each
## side. See `guided_tab` / `explore_tab` there.

## `{count}` is replaced with the number of placed prototypes, so the button
## cannot go on claiming ten after someone adds an eleventh.
@export var start_tour_label: String = "START THE TOUR · {count} PROTOTYPES":
	set(value):
		start_tour_label = value
		emit_changed()

@export var route_caption: String = "ONE GUIDED EXPERIENCE STRING · CURVES ADD RHYTHM, NOT BRANCHING LOGIC · CATEGORY ANCHORS SHOW THE TYPE OF PROOF":
	set(value):
		route_caption = value
		emit_changed()

@export var gateways_heading: String = "PLANNING GATEWAYS":
	set(value):
		gateways_heading = value
		emit_changed()

@export var gateways_note: String = "SEPARATE SUB-MAPS · NOT PART OF THE TOUR ORDER":
	set(value):
		gateways_note = value
		emit_changed()

@export var launch_label: String = "LAUNCH":
	set(value):
		launch_label = value
		emit_changed()

@export_group("Legend")
## Parallel arrays, same reasoning as [MenuEntry]'s control strip: the whole
## legend stays editable inline in the inspector without opening sub-resources.
@export var legend_labels: PackedStringArray = PackedStringArray():
	set(value):
		legend_labels = value
		emit_changed()

@export var gate_legend_label: String = "GATE ESSENTIAL":
	set(value):
		gate_legend_label = value
		emit_changed()


func placement_for(entry_title: String) -> FrontierEntry:
	for placement in placements:
		if placement != null and placement.entry_title == entry_title:
			return placement
	return null


func category_for(category_index: int) -> FrontierCategory:
	for category in categories:
		if category != null and category.category == category_index:
			return category
	return null


func start_tour_text(count: int) -> String:
	return start_tour_label.replace("{count}", str(count))
