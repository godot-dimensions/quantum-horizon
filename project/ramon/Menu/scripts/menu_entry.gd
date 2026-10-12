@tool
extends Resource
class_name MenuEntry

## One prototype in the menu: everything shown about it, and nothing about how
## it is shown. Sizes, colours and spacing live in [MenuStyle]; this is content
## only, so text can be rewritten without touching layout and vice versa.
##
## Edited in the inspector as part of `catalogue.tres`. Reordering the array
## there reorders the menu, and array order IS the tour order - see
## [MenuCatalogue].

@export_group("Identity")
@export var title: String = "":
	set(value):
		title = value
		emit_changed()

## One line. The SURPRISE, not the technology - "Walls you pass by rotating, not
## by walking" rather than "4D collision detection demo". This is the line that
## decides whether anyone clicks, and it is the register the gate catalogue in
## Demo/gates/ already got right.
@export_multiline var blurb: String = "":
	set(value):
		blurb = value
		emit_changed()

## Sets expectations before launch, which is most of what stops a greybox
## reading as a bug. Shown as a small badge next to the title.
@export_enum("Greybox", "Prototype", "Playable", "Polished") var maturity: String = "Prototype":
	set(value):
		maturity = value
		emit_changed()

## Which half of the list this sits in. The TOUR is the running order a first-time visitor
## is walked through; the LAB holds the earlier and rougher experiments, still one click
## away, listed below the tour so a greybox never sets the tone of a first impression.
##
## Only menu_final.gd reads this. Menu2 and the Frontier Map ignore it, so it cannot
## change either of them.
##
## CINEMATIC (Ramon, 1 Oct: "a 'cinematics' menu ... press 1 ... press 2") is a film played
## in a place rather than a prototype played by hand: kept in the catalogue's own
## `cinematics` list, shown under its own heading between the tour and the lab, and started
## by the number keys in the order listed. See [member cinematic].
@export_enum("Tour", "Lab", "Cinematic") var section: String = "Tour":
	set(value):
		section = value
		emit_changed()

## Which system this prototype shows, as menu_final groups them: the Frontier Map's four
## kinds of proof (Ramon, 8 Oct). It replaces the tour / lab split in menu_final, which
## lists the groups in this order, the order a first-time visitor learns them in. None
## lists the entry after the four groups. Menu2 and the Frontier Map ignore it.
@export_enum("None", "Orientation", "Spatial interaction", "World systems", "Living systems") var category: String = "None":
	set(value):
		category = value
		emit_changed()

## Which of menu_final's two families this prototype belongs to (Ramon's 9 Oct brief): the labs
## (interactive R&D exhibitions, walked around and experimented with) or the experiments (playable).
## menu_final groups by this; `category` and `thrust` stay as metadata. The names match
## MenuCatalogue.family_names (first called "Explore the systems" and "Experience 4D"; one noun per
## family since the 9 Oct review). Menu2 and the map ignore it.
@export_enum("None", "The labs", "The experiments") var family: String = "None":
	set(value):
		family = value
		emit_changed()

## Which of the programme's three questions this prototype answers: the RFP's thrusts (Build
## it: can a 4D world run in real time at game density; Fill it: can small teams make enough 4D
## content; Live it: can ordinary players understand and control 4D). menu_final can group by
## these instead of `category` (G in its design HUD, 8 Oct). Menu2 and the map ignore it.
@export_enum("None", "Live it", "Fill it", "Build it") var thrust: String = "None":
	set(value):
		thrust = value
		emit_changed()

## Where this prototype's system turns up in the playable world, in a few plain words ("the
## range, north of the gate"); empty when it does not (yet). The second round of menu_final's
## design review draws the relation from it (8 Oct). Menu2 and the map ignore it.
@export var world_link: String = "":
	set(value):
		world_link = value
		emit_changed()

## Where only the prototype's IDEA turns up in the world, built separately for it (no shared
## code), e.g. Phase Maze's stepping through W at the camp. Kept apart from `world_link` so the
## menu never claims the prototype itself runs there; drawn fainter, or dashed.
@export var world_idea: String = "":
	set(value):
		world_idea = value
		emit_changed()

## The other RFP questions this prototype also gives evidence for, besides its own `thrust`
## (for instance a measured frame cost is evidence for Build it). Drawn as rings in the
## evidence matrix design.
@export var also_answers: PackedStringArray = PackedStringArray():
	set(value):
		also_answers = value
		emit_changed()

## Untick to take the entry off the menu without deleting it: its words, scene and clip stay
## in the catalogue, ready to come back with one click (Ramon, 8 Oct: "when i say 'remove',
## i do not mean delete, i just mean, remove the visability or linkage from the menu").
##
## Only menu_final.gd reads this. Menu2 and the Frontier Map ignore it.
@export var show_in_menu: bool = true:
	set(value):
		show_in_menu = value
		emit_changed()

## Roughly how long this takes to see, e.g. "90 sec". Shown next to the maturity
## badge and in the row.
##
## Exists because eight unknowns feel longer than eight ninety-second things -
## someone deciding whether to click wants to know what they are committing to,
## and not knowing is itself a reason not to click.
@export var duration: String = "":
	set(value):
		duration = value
		emit_changed()

## A second sentence for the detail pane.
##
## The blurb is shown in the ROW; repeating it verbatim in the pane beside it
## wastes the most valuable line on the screen. Left empty, the pane falls back
## to the blurb, so this is an upgrade rather than a requirement.
@export_multiline var detail: String = "":
	set(value):
		detail = value
		emit_changed()

@export_group("Media")
## Basename in `thumbs/`. The menu looks for `<clip>.ogv` first, then
## `<clip>_loop.png`, then falls back to the icon.
@export var clip: String = "":
	set(value):
		clip = value
		emit_changed()

@export var icon: Texture2D = null:
	set(value):
		icon = value
		emit_changed()

## Where the clip is cropped vertically. 0 shows the top of the recorded frame,
## 1 the bottom, 0.5 the middle. -1 means "use the style's default".
##
## The pane is wider than 16:9, so a clip is scaled to COVER it and the overflow
## above and below is cropped. Which band survives is a judgement call per
## prototype - Sky Box Clouds wants the horizon, Voxel Mining wants the rock -
## so it is authored here rather than guessed globally. Drag it with the scene
## open and the preview follows live.
@export_range(-1.0, 1.0, 0.01) var preview_focus: float = -1.0:
	set(value):
		preview_focus = value
		emit_changed()

@export_file("*.tscn") var scene_path: String = "":
	set(value):
		scene_path = value
		emit_changed()

@export_group("Launch")
## Overrides [MenuCatalogue]'s launch label for this entry only. Empty means
## "use the catalogue's", which is what every single-scene entry wants.
##
## Exists for entries that launch more than one scene, where a button reading
## LAUNCH next to another button reading LAUNCH says nothing.
@export var launch_label: String = "":
	set(value):
		launch_label = value
		emit_changed()

## Starts the scene IN PLACE OF the menu instead of on top of it.
##
## A prototype normally runs as a child of the root with the menu kept alive underneath,
## so Esc and H can unwind it losslessly. That breaks a scene that is a place rather than
## a test: the chicken pen treats itself as the current scene everywhere (its cinema, cave,
## laptops and range all hang off `current_scene`), and it uses Esc and H itself. So an
## entry like that is changed to, and it comes back to the menu its own way - the pen
## through its laptops.
@export var opens_as_scene: bool = false:
	set(value):
		opens_as_scene = value
		emit_changed()

## A cinematic by name in the scene this entry opens - the chicken pen's list is in
## pen_cinematics_4d.gd. Set, launching opens the scene and plays the cinematic instead of
## handing over control; when it ends, or Escape skips it, it comes back to this menu. Use it
## with [member opens_as_scene]. Empty for anything that is played rather than watched; and
## a Cinematic entry left empty is a placeholder that launches nothing.
@export var cinematic: String = "":
	set(value):
		cinematic = value
		emit_changed()

## Further scenes this entry can start, each getting its own button beside the
## primary one. Parallel arrays, same reasoning as the control strip above.
##
## One prototype is not always one scene. Portal is two: a wall you shoot holes
## through and a chamber of linked openings. They share a question, a folder and
## a set of findings, so splitting them into two rows would say they are two
## unrelated things - but landing on one when you wanted the other is worse.
## Both live in one row, and the pane offers both.
@export var extra_launch_labels: PackedStringArray = PackedStringArray():
	set(value):
		extra_launch_labels = value
		emit_changed()

## Paths, aligned with `extra_launch_labels`. Not `@export_file` because Godot
## has no per-element file picker for a PackedStringArray.
@export var extra_launch_scenes: PackedStringArray = PackedStringArray():
	set(value):
		extra_launch_scenes = value
		emit_changed()

@export_group("Controls")
## Drawn as key caps, deliberately, rather than as a sentence. A cap is read in
## under a second and needs no reading; a sentence has to be parsed. Same visual
## language as the Phase Maze billboard, so the menu and the prototypes agree.
##
## Two parallel arrays rather than nested resources, so the whole control strip
## is editable inline in the inspector without opening sub-resources.
@export var control_keys: PackedStringArray = PackedStringArray():
	set(value):
		control_keys = value
		emit_changed()

@export var control_actions: PackedStringArray = PackedStringArray():
	set(value):
		control_actions = value
		emit_changed()

@export_group("Info cells")
## The fixed three-question schema, identical for every prototype.
##
## Fixed labels are what make eight prototypes COMPARABLE, and comparability is
## what makes a package read as designed rather than assembled. It also presents
## the work as a series of answered questions, which is the shape an academic
## reader already thinks in.
##
## KEEP THESE SHORT - roughly twelve words. The whole layout depends on these
## being scannable at low visual weight; one of them growing into a paragraph
## unbalances the pane and costs the skim-reader the thing they came for.
@export_multiline var question: String = "":
	set(value):
		question = value
		emit_changed()

@export_multiline var approach: String = "":
	set(value):
		approach = value
		emit_changed()

@export_multiline var finding: String = "":
	set(value):
		finding = value
		emit_changed()

## How sure the finding is, in the stakeholder deck's own tier words, printed small under
## the finding so the menu never claims more than the deck does. Nearly every finding here
## was observed by the person who built it, once, with no naive player involved - the
## default says exactly that. (A middle dot rather than the deck's comma, because an enum
## hint splits on commas.)
@export_enum("Observed while building · n = 1", "Measured", "Not yet tested") var finding_tier: String = "Observed while building · n = 1":
	set(value):
		finding_tier = value
		emit_changed()

## Measured numbers, as a single line - "130 ms per carve · ~58 fps · 10,752
## tetrahedra". Rendered as its own strip below the three cells rather than as a
## fourth cell.
##
## Kept SEPARATE from `finding` on purpose: a finding is a claim and a benchmark
## is a measurement, and mixing them makes both weaker. It is also the block an
## R&D or academic reader goes to first, so it wants its own place on the page
## rather than being buried inside prose.
@export_multiline var benchmark: String = "":
	set(value):
		benchmark = value
		emit_changed()


## Pairs the two control arrays, tolerating a mismatched length rather than
## erroring - a half-filled row in the inspector should render what it has.
func control_pairs() -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for i in control_keys.size():
		var action: String = control_actions[i] if i < control_actions.size() else ""
		pairs.append({"key": control_keys[i], "action": action})
	return pairs


## Every scene this entry can start, as {label, path}, primary first.
##
## `default_label` is the catalogue's, used whenever this entry has not named
## its own. An extra target with no label falls back to its file's basename
## rather than rendering a blank button.
func launch_targets(default_label: String) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if scene_path != "":
		targets.append({
			"label": launch_label if launch_label != "" else default_label,
			"path": scene_path,
		})
	for i in extra_launch_scenes.size():
		var path: String = extra_launch_scenes[i]
		if path == "":
			continue
		var label: String = extra_launch_labels[i] if i < extra_launch_labels.size() else ""
		if label == "":
			label = path.get_file().get_basename().replace("_", " ").to_upper()
		targets.append({"label": label, "path": path})
	return targets


func has_info() -> bool:
	return question != "" or approach != "" or finding != ""
