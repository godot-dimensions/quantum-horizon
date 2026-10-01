extends Control

## A thought the player has on the way down the walkway, once.
##
## IT IS THE PLAYER'S LINE, NOT A CAPTION. The act titles are a documentary lower third
## across the bottom of the screen; this is somebody muttering to themselves half way down
## a ramp, so it sits up near them, in a small bubble, and goes away on its own. Putting
## it in the same band as the titles would have read as a fourth finding.
##
## AND IT FIRES ON WHERE YOU ARE, not on a timer. The point of it is that this spot is a
## good spot - which is only true if you are standing in it.

@export var player_path: NodePath
@export var stage_path: NodePath
@export var text: String = "Good view from here. I'll watch from this step."
## How far down the rake before it occurs to them - 0 is the top, 1 the bottom.
@export_range(0.0, 1.0, 0.05) var fires_at: float = 0.45
@export_range(0.5, 12.0, 0.5) var holds_seconds: float = 5.0
@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.5
@export var bubble_color: Color = Color(0.05, 0.07, 0.12, 0.88)
@export var edge_color: Color = Color(0.32, 0.82, 1.0, 0.9)
@export var text_color: Color = Color(0.93, 0.96, 1.0)

var _player: Node4D
var _stage: Node4D
var _said: bool = false
var _left: float = 0.0
var _fade: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player = get_node_or_null(player_path) as Node4D
	_stage = get_node_or_null(stage_path) as Node4D


func _process(delta: float) -> void:
	if not _said and _player != null and _stage != null and _on_the_spot():
		_said = true
		_left = holds_seconds
	var was: float = _fade
	if _left > 0.0:
		_left -= delta
		_fade = minf(_fade + delta / fade_seconds, 1.0)
	else:
		_fade = maxf(_fade - delta / fade_seconds, 0.0)
	# One more redraw on the frame it reaches nothing: a Control keeps its last drawing until
	# told to draw again, so stopping at the last faint frame left the line on screen, barely
	# visible, over every slide of the talk.
	if _fade > 0.0 or was > 0.0:
		queue_redraw()


## On the walkway, and far enough down the RAKE - not the landing, where there is nothing
## to have an opinion about yet.
func _on_the_spot() -> bool:
	var at: Vector4 = _player.global_position
	if float(_stage.call("aisle_gap", at)) > float(_stage.get("aisle_width")) * 0.6:
		return false
	var top: Vector4 = _stage.get("aisle_to")
	var foot: Vector4 = _stage.get("aisle_from")
	var span: float = Vector2(top.x - foot.x, top.z - foot.z).length()
	if span < 0.5:
		return false
	var down: float = Vector2(top.x - at.x, top.z - at.z).length() / span
	return down >= fires_at and down <= 1.0


func _draw() -> void:
	if _fade <= 0.01:
		return
	var screen: Vector2 = get_viewport_rect().size
	var font: Font = ThemeDB.fallback_font
	var size: int = int(screen.y * 0.026)
	var wide: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pad: float = screen.y * 0.022
	var box := Rect2(Vector2((screen.x - wide) * 0.5 - pad, screen.y * 0.62),
		Vector2(wide + pad * 2.0, size + pad * 2.0))
	draw_rect(box, Color(bubble_color, bubble_color.a * _fade), true)
	draw_rect(box, Color(edge_color, edge_color.a * _fade * 0.7), false, 1.5)
	# draw_string places a BASELINE, so the text sits a line-height down inside the box.
	draw_string(font, Vector2(box.position.x + pad, box.position.y + pad + size * 0.78),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(text_color, _fade))
