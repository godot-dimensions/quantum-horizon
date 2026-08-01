extends Control
## Shooting gallery experiment: static crosshair, fixed at screen center.
## Just a reference point for aiming this pass - doesn't react to hits or
## aiming state.

const SIZE := 16.0
const THICKNESS := 2.0
const GAP := 3.0 # Small gap at the center so the lines don't overlap into a solid blob.
const COLOR := Color(1, 1, 1, 0.85)

func _ready() -> void:
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size / 2.0
	# Horizontal arm, split by the center gap.
	draw_rect(Rect2(center.x - SIZE / 2.0, center.y - THICKNESS / 2.0, SIZE / 2.0 - GAP, THICKNESS), COLOR)
	draw_rect(Rect2(center.x + GAP, center.y - THICKNESS / 2.0, SIZE / 2.0 - GAP, THICKNESS), COLOR)
	# Vertical arm, split by the center gap.
	draw_rect(Rect2(center.x - THICKNESS / 2.0, center.y - SIZE / 2.0, THICKNESS, SIZE / 2.0 - GAP), COLOR)
	draw_rect(Rect2(center.x - THICKNESS / 2.0, center.y + GAP, THICKNESS, SIZE / 2.0 - GAP), COLOR)
