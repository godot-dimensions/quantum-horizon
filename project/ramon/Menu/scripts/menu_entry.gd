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
