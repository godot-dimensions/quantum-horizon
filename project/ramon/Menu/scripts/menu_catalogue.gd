@tool
extends Resource
class_name MenuCatalogue

## The menu's content: the ordered list of prototypes, plus every fixed string
## on the screen. Nothing user-visible is hardcoded in `menu_mockup.gd`.
##
## ORDER IS THE CURRICULUM. The array is both the list order and the tour order,
## so dragging an entry in the inspector re-sequences the demo - legibility
## first, then interaction, then spectacle. That is a two-second experiment
## rather than a code change, which is the whole reason it lives here.
##
## One catalogue holding sub-resources rather than one .tres per entry (the
## pattern Demo/gates/ uses) specifically so reordering is a drag. The gates
## needed separate files because the hub ring picked them individually; nothing
## here does.

## No custom setter here, deliberately. A setter that assigns an untyped Array
## into a TYPED array property re-enters itself on the converted value and hangs
## - ResourceSaver.save() sat in that loop until the process was killed. Every
## other property in these resources can afford its emit_changed(); this one
## cannot, and does not need it.
@export var entries: Array[MenuEntry] = []

@export_group("Screen text")
@export var header: String = "QUANTUM HORIZON":
	set(value):
		header = value
		emit_changed()

@export var tour_title: String = "START THE TOUR":
	set(value):
		tour_title = value
		emit_changed()

## `{count}` is replaced with the number of entries, so adding a prototype
## cannot leave this sentence lying about how many there are.
@export var tour_subtitle: String = "All {count} in order, about ten minutes":
	set(value):
		tour_subtitle = value
		emit_changed()

@export var list_heading: String = "OR JUMP TO ONE":
	set(value):
		list_heading = value
		emit_changed()

## The two halves of the mode switch, shown identically on BOTH screens - same
## labels, same order, only the active index differs.
##
## They live on the CATALOGUE rather than on either screen's own resource
## because they are the one piece of text that must read identically in two
## places. Held in two resources they would drift, and a switch whose halves are
## named differently on each side stops looking like a switch and starts looking
## like two unrelated buttons.
## Named for the SCREEN it switches to, not for what that screen does. "Guided
## tour" described an intention; the toggle's two halves have to name the two
## destinations, or the switch stops being readable as a switch.
@export var guided_tab: String = "FRONTIER MAP":
	set(value):
		guided_tab = value
		emit_changed()

@export var explore_tab: String = "EXPLORE FREELY":
	set(value):
		explore_tab = value
		emit_changed()

@export var hint: String = "click to select  ·  again or ENTER to launch  ·  ESC returns  ·  ● played":
	set(value):
		hint = value
		emit_changed()

@export var launch_label: String = "LAUNCH":
	set(value):
		launch_label = value
		emit_changed()

@export_group("Tour notice")
## Shown when the hero banner is pressed, because the guided run-through is not
## built yet. Better than the button silently launching the first entry, which
## is what it did before and reads as a misfire rather than as "not done".
@export var notice_title: String = "COMING SOON":
	set(value):
		notice_title = value
		emit_changed()

## `{count}` is replaced with the number of entries.
@export_multiline var notice_body: String = "The guided run-through of all {count} in order isn't built yet.\nPick one from the list on the left in the meantime.":
	set(value):
		notice_body = value
		emit_changed()

@export var notice_hint: String = "ESC OR CLICK TO GO BACK":
	set(value):
		notice_hint = value
		emit_changed()


func notice_text() -> String:
	return notice_body.replace("{count}", str(entries.size()))

@export_group("Info cell labels")
## The three fixed questions. Editable because the framing may want to change
## for a different audience - but they should change for ALL entries at once,
## which is exactly why they live on the catalogue and not on each entry.
@export var question_label: String = "THE QUESTION":
	set(value):
		question_label = value
		emit_changed()

@export var approach_label: String = "THE APPROACH":
	set(value):
		approach_label = value
		emit_changed()

@export var finding_label: String = "THE FINDING":
	set(value):
		finding_label = value
		emit_changed()

## Heading for the measurements strip under the three cells.
@export var benchmark_label: String = "MEASURED":
	set(value):
		benchmark_label = value
		emit_changed()

@export_group("Hero and sections")
## What the big banner at the top of the list opens (menu_final only). Kept OUT of
## `entries` on purpose: it is not one of the prototypes in the running order, it is the
## place they live in, and Menu2 and the Frontier Map - which read only `entries` - never
## see it. Left empty, the banner falls back to START THE TOUR and its notice.
@export var hero: MenuEntry = null:
	set(value):
		hero = value
		emit_changed()

## The banner's call to action. The entry's own blurb and duration go underneath it.
@export var hero_heading: String = "PLAY THE WORLD":
	set(value):
		hero_heading = value
		emit_changed()

## What the banner says instead when the menu was opened from a laptop inside that world,
## where it takes you back rather than starting a second copy.
@export var hero_return_heading: String = "BACK TO THE PEN":
	set(value):
		hero_return_heading = value
		emit_changed()

@export var hero_return_subtitle: String = "Carry on where you left off":
	set(value):
		hero_return_subtitle = value
		emit_changed()

## Heading over the entries whose `section` is Lab.
@export var lab_heading: String = "THE LAB  ·  EARLIER, ROUGHER EXPERIMENTS":
	set(value):
		lab_heading = value
		emit_changed()


func subtitle_text() -> String:
	return tour_subtitle.replace("{count}", str(entries.size()))
