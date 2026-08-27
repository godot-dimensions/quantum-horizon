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


## Pairs the two control arrays, tolerating a mismatched length rather than
## erroring - a half-filled row in the inspector should render what it has.
func control_pairs() -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for i in control_keys.size():
		var action: String = control_actions[i] if i < control_actions.size() else ""
		pairs.append({"key": control_keys[i], "action": action})
	return pairs


func has_info() -> bool:
	return question != "" or approach != "" or finding != ""
