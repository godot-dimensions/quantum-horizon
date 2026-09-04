@tool
extends Resource
class_name FrontierGateway

## A planning gateway in the lower right - October Gate, Open-Source Path, 2027
## Frontier. Entrances to sub-maps that do not exist yet.
##
## A SEPARATE TYPE from [FrontierEntry] on purpose. These are not prototypes, not
## stages of the tour, and not launchable, and the single most important thing
## this screen must not do is let a stakeholder mistake a planning artifact for
## something they can play. Giving them their own resource means they cannot
## accidentally acquire a scene path, inherit a launch button, or be swept up by
## code that walks the prototype list.

@export var title: String = "":
	set(value):
		title = value
		emit_changed()

## Small caps line under the title - "ESSENTIALS SUB-MAP".
@export var subtitle: String = "":
	set(value):
		subtitle = value
		emit_changed()

@export var glyph: String = "":
	set(value):
		glyph = value
		emit_changed()

@export var reference_position: Vector2 = Vector2.ZERO:
	set(value):
		reference_position = value
		emit_changed()

## Count badge - how many items the sub-map behind this holds. 0 hides it.
@export_range(0, 99, 1) var item_count: int = 0:
	set(value):
		item_count = value
		emit_changed()

## Live gateways draw solid and take focus; deferred ones draw dashed and dim.
##
## Both are inert in this first pass - no sub-map exists behind either - so
## `is_focusable()` below returns false for everything. The distinction is kept
## because the two states are visually different in the reference art and the
## code should not have to be rewritten when the first sub-map lands.
@export var deferred: bool = false:
	set(value):
		deferred = value
		emit_changed()


## Always false for now. The brief is explicit: "Planning nodes should visually
## accept focus only if they do something... present them as disabled/read-only
## and avoid dead clickable buttons." No sub-map exists yet, so nothing here is
## focusable, and the map draws them as read-only.
##
## When a sub-map ships, this becomes `return not deferred`.
func is_focusable() -> bool:
	return false
