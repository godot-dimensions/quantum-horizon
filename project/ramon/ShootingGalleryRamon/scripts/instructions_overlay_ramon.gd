extends Control
## Ramon-only: a static HUD legend in the top-left - controls, plus a short
## "what does this thing do" line per object type. Static text, not reading
## any other node's live state (unlike charge_bar_ramon.gd) - this is pure
## reference info, always the same regardless of what's happening in the
## scene.
##
## Key bindings quoted here match this branch's project.godot input map
## specifically - rotate_4d is remapped to right-click and fire to
## left-click here (see player/CONTROLLER_NOTES.md's note on the
## shooting-gallery-branch-only swap), not left-click-to-rotate like main.

const LINES := [
	"MOVE: WASD   ANA/KATA: Q/E   LOOK: MOUSE",
	"HOLD RIGHT-CLICK + MOUSE: ROTATE SLICE",
	"HOLD LEFT-CLICK: CHARGE SHOT   RELEASE: FIRE",
	"",
	"WHITE/GREY BLOCKS: SHOOT TO CLEAR SIGHTLINES (GREY = TOUGHER)",
	"YELLOW BLOCKS: TARGETS, 1 HIT",
	"GREEN SPHERES: FAST AND EVASIVE, APPEAR BRIEFLY",
	"BLACK MONOLITH: SHOOT IT (8 HITS) OR CHANGE SLICE - IT WILL",
	"  EVENTUALLY CATCH YOU IF YOU JUST RUN",
]

const FONT_SIZE := 15
const LINE_SPACING := 20.0
const TEXT_COLOR := Color(1, 1, 1, 0.8)
const TOP_MARGIN := 24.0
const LEFT_MARGIN := 24.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for i in LINES.size():
		var pos := Vector2(LEFT_MARGIN, TOP_MARGIN + i * LINE_SPACING)
		draw_string(font, pos, LINES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
