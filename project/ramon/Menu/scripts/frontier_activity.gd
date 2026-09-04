@tool
extends Resource
class_name FrontierActivity

## The contents of the contextual drawer for one node: aggregate contribution,
## player signal, and an optional bounded next-cycle choice.
##
## THIS IS THE ANTI-SPRAWL MECHANISM. The proposal is blunt that there must not
## be one map node per contributor, pull request or jam entry, because that
## becomes unreadable and confuses people with product dependencies. So a node
## carries a COUNT and this resource; names, PRs, credits and artefacts live one
## level deeper than the drawer, not on the map.
##
## SHAPED FOR A BACKEND IT DOES NOT HAVE YET. Every field here is a plain value
## or a parallel array - no scene references, no node paths, nothing that only
## makes sense in the editor. A later service can fill the same fields from a
## real contribution feed without the drawer changing, and `illustrative` marks
## whether the numbers on screen are real. Right now they are not, and the
## drawer says so on its face rather than quietly implying measurement.

## Drives the gold "ILLUSTRATIVE FUTURE DATA" pill. Turn this off only when the
## numbers actually come from somewhere.
@export var illustrative: bool = true:
	set(value):
		illustrative = value
		emit_changed()

@export_group("Contribution")
@export var contributors: int = 0:
	set(value):
		contributors = value
		emit_changed()

@export var merged: int = 0:
	set(value):
		merged = value
		emit_changed()

@export var open_briefs: int = 0:
	set(value):
		open_briefs = value
		emit_changed()

## Initials only, and only as a stand-in for avatars.
##
## Deliberately NOT names, handles or images: the proposal keeps individuals one
## level deeper, and initials are enough to show that a count is made of people
## without turning the drawer into a directory. A backend would fill these from
## whatever identity it has; nothing here assumes an account system exists.
@export var member_initials: PackedStringArray = PackedStringArray():
	set(value):
		member_initials = value
		emit_changed()

## How many more people the "+N" chip stands for. 0 hides it.
@export var member_overflow: int = 0:
	set(value):
		member_overflow = value
		emit_changed()

@export_group("Lanes")
## Parallel arrays - same reasoning as [MenuEntry]'s control strip, so the whole
## strip stays editable inline without opening sub-resources.
@export var lane_names: PackedStringArray = PackedStringArray():
	set(value):
		lane_names = value
		emit_changed()

@export var lane_counts: PackedInt32Array = PackedInt32Array():
	set(value):
		lane_counts = value
		emit_changed()

## 0..1 fill of each lane's bar. Authored rather than derived from the counts,
## because a bar showing 3 of an unstated maximum is a bar that means nothing.
@export var lane_fills: PackedFloat32Array = PackedFloat32Array():
	set(value):
		lane_fills = value
		emit_changed()

@export_group("Player signal")
@export var played: int = 0:
	set(value):
		played = value
		emit_changed()

@export var completed: int = 0:
	set(value):
		completed = value
		emit_changed()

@export var shared: int = 0:
	set(value):
		shared = value
		emit_changed()

@export_group("Next-cycle signal")
## Whether the second drawer tab has anything in it. When false the tab is
## disabled rather than hidden, so the interaction stays discoverable.
@export var signal_open: bool = false:
	set(value):
		signal_open = value
		emit_changed()

## Exactly three, by design. The proposal's bound is "three feasible,
## dependency-aware options" - more is a survey, fewer is not a choice.
@export var option_titles: PackedStringArray = PackedStringArray():
	set(value):
		option_titles = value
		emit_changed()

@export var option_subtitles: PackedStringArray = PackedStringArray():
	set(value):
		option_subtitles = value
		emit_changed()

@export var option_counts: PackedInt32Array = PackedInt32Array():
	set(value):
		option_counts = value
		emit_changed()

## Live totals are shown here because this is a concept. The proposal notes a
## production version should hide them until a person has submitted or the
## signal closes, to avoid bandwagon effects - flip this off to preview that.
@export var show_option_counts: bool = true:
	set(value):
		show_option_counts = value
		emit_changed()


func lane_count() -> int:
	return mini(lane_names.size(), mini(lane_counts.size(), lane_fills.size()))


func option_count() -> int:
	return mini(option_titles.size(), option_subtitles.size())


func has_contribution() -> bool:
	return contributors > 0 or merged > 0 or open_briefs > 0
