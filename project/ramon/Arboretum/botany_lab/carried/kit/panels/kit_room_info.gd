@tool
extends Resource

## Kit: what one room says on its two wall panels (rule 6 of the handoff: "number, title, lead,
## description, interactions and right-layout variant. Keep layout positions and typography in the
## shared template rather than per-room content"). One of these per prototype, saved as a .tres
## next to its scene; the panels (kit_wall_panel_4d.gd) read it, the template (kit_panel_spec.gd)
## decides where and how big.
##
## The introduction is a stable room introduction (rule 2): one title line, a one-line lead, up
## to five body lines and two to four shortcuts. Write to fit; the panel never shrinks essential
## text, it reports what runs over.
##
## LIVE WORDS: {tokens} in the description and in a shortcut's label are filled in by the room's
## panel source (kit_panel_source_showcase.gd fills {name}, {balls} and {action} from the animal on
## the plinth); a token it does not know is left as written.
##
## NO class_name (engine_gotchas.md).

## The room's number in its programme: "01".
@export var number: int = 1
## The title: one line in the hero role.
@export var title: String = "Creation Lab"
## The running header's right-hand words on the introduction.
@export var status: String = "BUILD  /  ANIMATE  /  EXPLORE"
## One line under the title.
@export var lead: String = "Build a 4D animal, then bring it to life."
## Up to five lines.
@export_multiline var description: String = ""
## Two to four shortcuts: [icon, label]. Icons (kit_panel_icons.gd): "wheel", "rdrag", "click",
## "drag", "arrows", "key:E" (any key's letter or word after the colon).
@export var interactions: Array = [["wheel", "Slice through W"], ["rdrag", "Rotate in 4D"], ["key:E", "Add a ball"]]
## The heading over the shortcuts.
@export var controls_heading: String = "CONTROLS"

@export_group("Research panel")
## Its running header: "<title> / <this>" on the left.
@export var research_title: String = "RESEARCH WALL"
## Its running header's right-hand words.
@export var research_status: String = "●  MEASURED LIVE ON THIS MACHINE"
## The research panel's layout family (rule 3): an animal and its evidence, two equal comparison
## columns, or three steps in sequence. All keep the same header, bounds, type and lower band.
## ARBORETUM (carried copy): "methods", four equal columns, one a method (kit_panel_research.gd).
@export_enum("specimen", "compare", "steps", "methods", "algorithm") var research_layout: String = "specimen"


## The introduction's running header, left: "01  /  CREATION LAB".
func intro_header() -> String:
	return "%02d  /  %s" % [number, title.to_upper()]


## The research panel's running header, left: "CREATION LAB  /  RESEARCH WALL".
func research_header() -> String:
	return "%s  /  %s" % [title.to_upper(), research_title.to_upper()]
