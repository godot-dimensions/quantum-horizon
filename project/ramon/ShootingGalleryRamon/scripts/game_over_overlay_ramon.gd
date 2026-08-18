extends Control
## Ramon-only "you got caught" feedback: a full-screen translucent red flash
## with "GAME OVER" text, triggered externally (by black_stalker_spawner_
## ramon.gd) when the black stalker reaches the player. Purely a visual
## flash, not a real pause/reset - "the game continues after 3 seconds
## anew" per spec means the overlay just fades back out and play resumes;
## nothing about player position/score/the stalker's own respawn timer is
## touched here, that's black_stalker_spawner_ramon.gd's job.
##
## Builds its own ColorRect/Label children in code rather than via the
## scene file - same reasoning as the shape blockers/stalker being built in
## code: this is one Control node with a script, not worth a dedicated
## dumb sub-scene for two children.

const DISPLAY_SEC := 3.0
const OVERLAY_COLOR := Color(0.6, 0.0, 0.0, 0.45)

var _timer_sec: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var color_rect := ColorRect.new()
	color_rect.color = OVERLAY_COLOR
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(color_rect)

	var label := Label.new()
	label.text = "GAME OVER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	visible = false


func _process(delta: float) -> void:
	if _timer_sec < 0.0:
		return
	_timer_sec -= delta
	if _timer_sec <= 0.0:
		visible = false
		_timer_sec = -1.0


func trigger() -> void:
	visible = true
	_timer_sec = DISPLAY_SEC
