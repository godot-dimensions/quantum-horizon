@tool
extends Resource
class_name FrontierEntry

## Where one prototype sits on the Frontier Map, and what kind of proof it is.
##
## Deliberately NOT a copy of [MenuEntry]. Titles, blurbs, controls, findings and
## benchmarks stay in `entries/catalogue.tres` and are looked up by `entry_title`,
## so the two menus can never disagree about what a prototype IS. This resource
## carries only what the MAP adds: a position, a category, a state, and the gate
## cross-reference.
##
## THE ORDER IS NOT HERE. The running order is the catalogue's array order, the
## same single source of truth [MenuCatalogue] already documents. The brief's
## `tour_index` was dropped on purpose: a second ordering that the catalogue's
## own Move up / Move down buttons cannot see is a drift waiting to happen, and
## the curve on this screen is explicitly rhythm rather than dependency logic.

## Which prototype in `catalogue.tres` this places, matched on its `title`.
##
## Matched by title rather than array index so reordering the catalogue - the one
## supported way to re-sequence the tour - cannot silently re-point every node on
## the map at the wrong prototype.
##
## A placement whose title matches NOTHING in the catalogue is not an error: it
## is a node for work that does not exist yet, and showing those is most of why
## this screen exists. Such a node draws from this resource alone and needs
## `route_after` to know where it sits in the line. See `standalone` below.
@export var entry_title: String = "":
	set(value):
		entry_title = value
		emit_changed()

## What the node LABEL says, when that differs from the id. Sub-map nodes carry
## two-line names - "MATERIALS +" then "SCATTER" - which would make terrible
## identifiers, so the id stays a clean single line and this holds the drawn
## text, newline included.
@export var display_title: String = "":
	set(value):
		display_title = value
		emit_changed()


func label_text() -> String:
	return display_title if display_title != "" else entry_title


## For a node with no catalogue entry: which entry it follows in the route.
##
## The running order is the catalogue's array order, and something absent from
## the catalogue has no place in that order by definition. Rather than inventing
## a parallel index - the `tour_index` this design deliberately avoids - a
## standalone node names the one prototype it comes after, and is spliced in
## there. Empty means it goes last.
##
## Ignored entirely when the title DOES match a catalogue entry, so it can never
## fight the catalogue for control of the order.
@export var route_after: String = "":
	set(value):
		route_after = value
		emit_changed()

## Subtitle for a standalone node, which has no [MenuEntry] maturity to read.
## Ignored when a catalogue entry backs this placement.
@export var standalone_subtitle: String = "UPCOMING":
	set(value):
		standalone_subtitle = value
		emit_changed()

## The kind of proof this prototype contributes. Drives the node's colour and
## which category anchor it sits under.
enum Category { ORIENTATION, SPATIAL_INTERACTION, WORLD_SYSTEMS, LIVING_SYSTEMS }

@export var category: Category = Category.ORIENTATION:
	set(value):
		category = value
		emit_changed()

## How the node is drawn and whether it can be entered.
##
## Distinct from [MenuEntry]'s `maturity`, which describes how finished a
## prototype is. This describes the VIEWER's relationship to it - seen it, can
## enter it, cannot enter it yet - which is what the map is actually about.
##
##   PLAYED    - entered this session; gets the tick
##   AVAILABLE - built and launchable, not yet entered
##   RESEARCH  - a live research strand rather than a finished demo
##   UPCOMING  - named and placed, but not built. NOT launchable.
##   FOG       - decorative or deferred. Never focusable, never clickable.
enum State { PLAYED, AVAILABLE, RESEARCH, UPCOMING, FOG }

@export var state: State = State.AVAILABLE:
	set(value):
		state = value
		emit_changed()

## Centre of the node in the 1920x1080 reference space the mock-up is drawn in.
## `frontier_map.gd` scales that whole space uniformly, so these stay authorable
## against the reference art at any window size.
@export var reference_position: Vector2 = Vector2.ZERO:
	set(value):
		reference_position = value
		emit_changed()

## The glyph drawn inside the circle.
##
## A character rather than a Texture2D because the reference art uses geometric
## symbols that a font already carries, and nine PNGs would be nine more import
## steps for something a string does exactly as well. Swap to an icon field if
## the art ever stops being typographic.
@export var glyph: String = "":
	set(value):
		glyph = value
		emit_changed()

## The gold G. Marks a prototype that contributes evidence to the October Gate.
##
## A CROSS-REFERENCE, not a route change: it must not alter the tour order, and
## it must not read as a collectible. One badge, one meaning.
@export var gate_essential: bool = false:
	set(value):
		gate_essential = value
		emit_changed()

## A second kind of flag, for nodes that belong to a workstream without
## supplying gate evidence.
##
## The gold G is reserved: it means "this contributes to the October decision"
## and nothing else. A node like Voxel Mining is part of the voxel core without
## being gate evidence, so it flies its own letter in the workstream's colour -
## same bookmark shape, different claim.
@export var flag_letter: String = "":
	set(value):
		flag_letter = value
		emit_changed()

## Revealed beside the badge when it is pressed. The whole content of the
## cross-reference, so the badge is never an inert decoration.
@export var flag_caption: String = "":
	set(value):
		flag_caption = value
		emit_changed()


## Gate-essential nodes fly a gold G by default; anything else needs its own
## letter before it gets a badge at all.
func has_flag() -> bool:
	return gate_essential or flag_letter != ""


func flag_text() -> String:
	if flag_letter != "":
		return flag_letter
	return "G" if gate_essential else ""


func flag_caption_text() -> String:
	if flag_caption != "":
		return flag_caption
	return "OCTOBER GATE" if gate_essential else ""


## Small pills under the detail copy - "GATE ESSENTIAL", "VOXEL CORE". Free text
## so a new kind of claim does not need a code change.
@export var tags: PackedStringArray = PackedStringArray():
	set(value):
		tags = value
		emit_changed()

## Overrides the catalogue's `blurb` in the map's detail panel.
##
## The map's panel is wider and colder than Menu2's row, and a line written to
## make someone click ("Walls you pass by rotating") is not always the line that
## explains what a proof demonstrates. Left empty, the catalogue's text is used.
@export_multiline var map_detail: String = "":
	set(value):
		map_detail = value
		emit_changed()

## Shown instead of the launch button when `state` is UPCOMING, so a node that
## cannot be entered says why rather than offering a button that does nothing.
@export var upcoming_note: String = "":
	set(value):
		upcoming_note = value
		emit_changed()


@export_group("Node kind")
## What CONFIRMING this node does. Selection and the information panel work the
## same for all three; only activation differs.
##
##   PROTOTYPE - launches a scene from the catalogue.
##   GATEWAY   - opens the sub-map named in `opens_map`.
##   PLANNING  - inspect only. Sub-map work with nothing behind it yet.
##
## Gateways stopped being a separate resource here on purpose. The proposal's
## interaction contract gives every node the same three intentions - selected,
## activated, activity_requested - and two node classes meant two places for
## focus, hover and badge handling to drift apart.
enum Kind { PROTOTYPE, GATEWAY, PLANNING }

@export var kind: Kind = Kind.PROTOTYPE:
	set(value):
		kind = value
		emit_changed()

## For a GATEWAY: the [FrontierLayout] to open. Empty means the sub-map does not
## exist yet, and the node says so instead of opening nothing.
@export_file("*.tres") var opens_map: String = "":
	set(value):
		opens_map = value
		emit_changed()

## Small caps line under the title in the detail panel - "GATE-ESSENTIAL
## PROCEDURAL PROOF". Falls back to the node's category name.
@export var detail_head: String = "":
	set(value):
		detail_head = value
		emit_changed()

## Second sentence of panel copy, for the sub-map nodes that need to qualify
## what they claim.
@export_multiline var map_detail_2: String = "":
	set(value):
		map_detail_2 = value
		emit_changed()

## Label on the panel's action button. Empty falls back to the layout's default.
@export var action_label: String = "":
	set(value):
		action_label = value
		emit_changed()

## Multiplies the node's radius. Gateways and decision nodes draw larger,
## because on a planning map "this is a destination" and "this is a step" are
## different weights of thing and size is the cheapest way to say so.
@export_range(0.6, 2.0, 0.05) var radius_scale: float = 1.0:
	set(value):
		radius_scale = value
		emit_changed()

## Draws a second ring outside the node. Marks the map's terminal or hero node
## without borrowing the selection ring's meaning.
@export var haloed: bool = false:
	set(value):
		haloed = value
		emit_changed()

@export_group("Activity")
## The blue numbered badge. 0 hides it.
##
## A SEPARATE INTERACTIVE TARGET from the node body, per the badge language: the
## body means "inspect or enter this", the badge means "show me what is
## happening here". Mixing them is how someone opens a contribution drawer when
## they only wanted to launch a prototype.
@export var activity_count: int = 0:
	set(value):
		activity_count = value
		emit_changed()

## Shown when the count is not a number - the October Gate's own badge is "?",
## because the thing it is counting is a decision nobody has taken yet.
@export var activity_glyph: String = "":
	set(value):
		activity_glyph = value
		emit_changed()

@export var activity: FrontierActivity = null:
	set(value):
		activity = value
		emit_changed()


func has_activity() -> bool:
	return activity != null and (activity_count > 0 or activity_glyph != "")


func is_enterable() -> bool:
	match kind:
		Kind.GATEWAY:
			return opens_map != ""
		Kind.PLANNING:
			return false
	return state != State.UPCOMING and state != State.FOG


## FOG nodes are atmosphere. The brief is explicit that they must not take focus
## or clicks, so this is checked before a node is even given a focus mode.
func is_focusable() -> bool:
	return state != State.FOG
