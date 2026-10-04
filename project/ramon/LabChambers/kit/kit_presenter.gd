extends Control

## Kit: the presentation on screen. As each part of the exhibit's story begins, a title card comes
## down at the top (the part, its name, its one line, the hint that a click moves on) and stays the
## same for the whole part, its progress filling along its foot (Ramon, 4 Oct: "its annoying how the
## info label disappears half way and turns into a smaller one ... keep consistent"); through the
## part, short callouts rise above the control strip at their times, carrying the animal's own
## measured numbers ("when something is playing ... a title card should appear with that
## explainer"; "think of what explainer callouts can appear to educate"). The parts, their lines and
## their callouts are kit_presentation.gd's, so every animal tells the same story.
##
## It stays out of the way: nothing over the exhibit's middle, the card at the top, the callouts
## low and narrow enough to clear the slice view; hidden while the watched cinematic has its own
## captions.
##
## NO class_name (engine_gotchas.md).

const Presentation := preload("res://ramon/LabChambers/kit/kit_presentation.gd")
const LabPrint := preload("res://ramon/LabKit/lab_print.gd")

const CALLOUT_SECONDS := 3.6

var showcase: Node
var room: Node
var _clock: float = 0.0
var _part: int = -1
var _part_at: float = -10.0
var _serial: int = -1
var _next: int = 0
var _callout: String = ""
var _callout_at: float = -10.0
var _callout_until: float = -10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size
	if size != want or position != Vector2.ZERO:
		position = Vector2.ZERO
		size = want
	_clock += delta
	if showcase == null:
		return
	var i: int = int(showcase.get("seq_index"))
	var cine = room.get("_cine") if room != null else null
	if cine != null and not cine.is_empty():
		i = -1
	var ser: int = int(showcase.get("serial"))
	if i != _part or ser != _serial:
		_part = i
		_serial = ser
		_part_at = _clock
		_next = 0
		_callout_until = minf(_callout_until, _clock + 0.2)
	if _part >= 0:
		var t: float = float(showcase.get("seq_t"))
		var calls: Array = Presentation.chapters()[_part]["callouts"]
		while _next < calls.size() and t >= float(calls[_next][0]):
			var text: String = Presentation.fill(String(calls[_next][1]), Presentation.numbers(showcase.call("data"), showcase.call("bench")))
			_next += 1
			if not text.is_empty():
				_callout = text
				_callout_at = _clock
				_callout_until = _clock + CALLOUT_SECONDS
	queue_redraw()


static func _ease(x: float) -> float:
	var u: float = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _draw() -> void:
	var u: float = size.y / 720.0
	if u <= 0.0 or showcase == null:
		return
	if _part >= 0:
		var parts: Array = Presentation.chapters()
		var ch: Dictionary = parts[_part]
		var age: float = _clock - _part_at
		var progress: float = clampf(float(showcase.get("seq_t")) / maxf(float(showcase.get("seq_len")), 0.01), 0.0, 1.0)
		_draw_card(u, ch, parts.size(), _ease(age / 0.35), progress, age)
	var ca: float = _ease((_clock - _callout_at) / 0.3) * (1.0 - _ease((_clock - _callout_until + 0.35) / 0.35))
	if ca > 0.01 and not _callout.is_empty():
		_draw_callout(u, ca)


func _draw_card(u: float, ch: Dictionary, count: int, a: float, progress: float, age: float) -> void:
	var w: float = 560.0 * u
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var line: String = String(ch["line"])
	var lines: int = 1 if fl.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * u)).x < w - 60.0 * u else 2
	var h: float = (104.0 + 20.0 * float(lines)) * u
	var r := Rect2(Vector2((size.x - w) * 0.5, (30.0 - 14.0 * (1.0 - _ease(age / 0.45))) * u), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.085, 0.86 * a)
	sb.set_corner_radius_all(int(14 * u))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	draw_rect(Rect2(r.position + Vector2(0.0, 18.0 * u), Vector2(4.0 * u, h - 36.0 * u)), Color(0.36, 0.62, 1.0, a))
	var name: String = String((showcase.call("data") as Dictionary).get("name", "")).to_upper()
	var x: float = r.position.x + 28.0 * u
	draw_string(fs, Vector2(x, r.position.y + 32.0 * u), "PART %d OF %d   ·   %s" % [_part + 1, count, name], HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(0.55, 0.76, 1.0, a))
	draw_string(fl, Vector2(r.position.x, r.position.y + 32.0 * u), "CLICK FOR THE NEXT PART", HORIZONTAL_ALIGNMENT_RIGHT, w - 28.0 * u, int(10 * u), Color(1, 1, 1, 0.5 * a))
	draw_string(fb, Vector2(x, r.position.y + 68.0 * u), String(ch["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * u), Color(1, 1, 1, a))
	draw_multiline_string(fl, Vector2(x, r.position.y + 96.0 * u), line, HORIZONTAL_ALIGNMENT_LEFT, w - 56.0 * u, int(15 * u), 2, Color(1, 1, 1, 0.88 * a))
	var bar := Rect2(Vector2(x, r.end.y - 14.0 * u), Vector2(w - 56.0 * u, 2.0 * u))
	draw_rect(bar, Color(1, 1, 1, 0.12 * a))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color(0.36, 0.62, 1.0, a))


func _draw_callout(u: float, a: float) -> void:
	var fl: Font = LabPrint.font("body")
	var px: int = int(15 * u)
	var max_w: float = 540.0 * u
	var tw: float = fl.get_string_size(_callout, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var lines: int = 1 if tw <= max_w - 52.0 * u else 2
	var w: float = minf(tw + 52.0 * u, max_w)
	var h: float = (24.0 + 21.0 * float(lines)) * u
	var rise: float = 10.0 * u * (1.0 - _ease((_clock - _callout_at) / 0.35))
	var r := Rect2(Vector2((size.x - w) * 0.5, size.y - 96.0 * u - h + rise), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.965, 0.955, 0.93, 0.95 * a)
	sb.set_corner_radius_all(int(12 * u))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	draw_rect(Rect2(r.position + Vector2(14.0 * u, 12.0 * u), Vector2(3.0 * u, h - 24.0 * u)), Color(0.13, 0.40, 0.86, a))
	draw_multiline_string(fl, Vector2(r.position.x + 28.0 * u, r.position.y + 28.0 * u), _callout, HORIZONTAL_ALIGNMENT_LEFT, w - 46.0 * u, px, 2, Color(0.10, 0.10, 0.12, a))
