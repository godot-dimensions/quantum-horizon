extends Control

## Measurements, set in small type beside the thing they measure.
##
## THEY ARE NOT THE EXHIBIT. An earlier version of this put the headline number up in
## two-metre-high seven-segment digits hanging over the drum, which made every moment about
## its own statistic - the number stole the stage from the goat. A figure is a footnote on
## an object. It goes next to the object, in the smallest type that can still be read from
## the back, and the object stays the thing you are looking at.
##
## AND IT IS TYPE, NOT GEOMETRY. Montserrat, the same face the stakeholder deck is set in,
## drawn in screen space and anchored to a point in the world. Building letters out of
## boxes was the wrong instinct twice over: it reads as instrumentation rather than as a
## caption, and letterforms made of cubes are the one thing in this room that would look
## worse the closer you got to them.
##
## THE ANCHOR IS A POINT IN 4D, so a metric hides when its subject leaves your slice, the
## same as the subject does. A label still floating over an object that is no longer there
## would be the exact mistake the first finding is about.

@export var camera_path: NodePath
## AND THE RIG THAT TAKES THE CAMERA WHEN YOU SIT DOWN. A figure is anchored to a point in
## the world and drawn in screen space, so it has to be projected through the camera that
## is actually rendering. Pointed at the player's camera alone, every number slid off its
## subject the moment the shot camera became current: the subject moved on screen and its
## label stayed where the seated view would have put it.
@export var shot_rig_path: NodePath
@export_file("*.ttf") var font_file: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf"
@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.5
## How far through W the subject can be before its figure goes with it.
@export_range(0.5, 20.0, 0.5) var w_range: float = 6.0
@export_range(8, 60, 1) var value_size: int = 30
@export_range(6, 40, 1) var label_size: int = 15
## How far to one side of the anchor the figure sits, in pixels.
@export_range(0.0, 300.0, 5.0) var offset_x: float = 86.0
@export_range(-300.0, 300.0, 5.0) var offset_y: float = -18.0
@export var label_color: Color = Color(0.72, 0.80, 0.90)
@export var rule_color: Color = Color(0.45, 0.72, 0.95, 0.65)

var _camera: Camera4D
var _shot_rig: Node
var _font: Font
var _metrics: Array = []
var _fade: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_camera = get_node_or_null(camera_path) as Camera4D
	_shot_rig = get_node_or_null(shot_rig_path)
	if font_file != "" and ResourceLoader.exists(font_file):
		_font = load(font_file)
	if _font == null:
		_font = ThemeDB.fallback_font


## Each entry: {"at": Vector4 world point, "value": String, "label": String,
## "colour": Color, "side": -1.0 or 1.0}.
## `keep` leaves the fade alone, for a figure that is being updated rather than replaced.
## Without it the counter that climbs while the animal assembles restarted its fade on
## every step and spent the whole moment flickering at a tenth of its brightness.
func show_metrics(metrics: Array, keep: bool = false) -> void:
	_metrics = metrics
	if not keep:
		_fade = 0.0


func clear() -> void:
	_metrics = []


func count() -> int:
	return _metrics.size()


func _process(delta: float) -> void:
	var want: float = 1.0 if not _metrics.is_empty() else 0.0
	_fade = move_toward(_fade, want, delta / maxf(fade_seconds, 0.01))
	if _camera == null:
		_camera = get_node_or_null(camera_path) as Camera4D
	if _shot_rig == null:
		_shot_rig = get_node_or_null(shot_rig_path)
	queue_redraw()


## Whichever camera is rendering this frame - the player's while they are on their feet,
## the shot camera once they have sat down and it has taken over.
func _live() -> Camera4D:
	if _shot_rig != null and _shot_rig.has_method("live_camera"):
		var shot: Camera4D = _shot_rig.call("live_camera") as Camera4D
		if shot != null and shot.is_current():
			return shot
	return _camera


func _draw() -> void:
	var eye: Camera4D = _live()
	if _fade <= 0.01 or eye == null or _metrics.is_empty():
		return
	var screen: Vector2 = get_viewport_rect().size
	for metric in _metrics:
		var at: Vector4 = metric.get("at", Vector4.ZERO)
		var gap: Vector4 = at - eye.global_position
		# Behind the camera projects to nonsense, and off the slice is not there at all.
		if (-eye.global_basis.z).dot(gap) <= 0.05 or absf(gap.w) > w_range:
			continue
		var point: Vector2 = eye.world_to_viewport(at)
		if point.x < -200.0 or point.x > screen.x + 200.0:
			continue
		var side: float = float(metric.get("side", 1.0))
		var colour: Color = metric.get("colour", Color(0.85, 0.92, 1.0))
		var value: String = String(metric.get("value", ""))
		var label: String = String(metric.get("label", ""))

		var wide: float = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1,
			value_size).x
		var anchor := Vector2(point.x + side * offset_x, point.y + offset_y)
		# A leader, so it is unambiguous which object the figure belongs to. Without it a
		# number floating near two exhibits belongs to neither.
		var reach := Vector2(point.x + side * 14.0, point.y)
		draw_line(reach, Vector2(anchor.x - side * 8.0, anchor.y + 4.0),
			Color(rule_color, rule_color.a * _fade), 1.0, true)

		var x: float = anchor.x if side > 0.0 else anchor.x - wide
		draw_string(_font, Vector2(x, anchor.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1,
			value_size, Color(colour, _fade))
		if label != "":
			draw_string(_font, Vector2(x, anchor.y + float(label_size) * 1.35), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label_size,
				Color(label_color, _fade * 0.85))
