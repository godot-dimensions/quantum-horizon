extends Control

## THE EXPLAINER after the Dream Shifter's shift (discovery/dream_shifter/pen_look_guide_4d.gd). Ramon's brief, 9 Oct:
## "Only after that real-time shift, show a short explainer ... images or graphics that slide from one state to the
## next, similar in spirit to what happens in the Devlog video ... Use the actual engine visuals ... not skippable for
## the first 5 seconds, then skippable."
##
## WHAT IT SHOWS: the Dev Logs' slider (Ramon's Dev Logs, The playable world: "Drag across the picture. Left of the line
## the dev look, right of it the art"), played rather than dragged. One frame in the middle of the screen, the dev look
## left of a glowing line and the art right of it, the line sweeping across. The first pictures are the player's own:
## the frame they were looking at just now, in both looks, caught while the world shifted. Then three more places of
## the valley (discovery/dream_shifter/views/, captured from the game by _capture_views_runner.gd).
##
## WHAT IT SAYS (in this order, a beat each, the line sweeping to the side being described):
##   ONE WORLD. TWO MODES.
##   DEV MODE  How we build. We block it out, test it, and find out what is possible in 4D.
##   ART MODE  Where it is going. The same world, dressed as the vision it can become.
##   Rough on purpose. This is a prototype, and every block in it is a question we are answering about 4D.
##   [I] switches between them, any time.
## Short sentences, full stops, no dashes; "we" and "our" (the team's voice).
##
## Not skippable for skip_after seconds (a filling bar says so); after that Space, Enter, F, Esc or a click close it;
## it closes by itself after hold_max seconds. Built in code; drawn in _draw. NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")

signal closed

@export var skip_after: float = 5.0
@export var hold_max: float = 32.0

## The pairs shown: each {"dev": Texture2D, "art": Texture2D, "label": String}.
var pairs: Array = []
var _t: float = 0.0
var _open: bool = false
var _closing: float = -1.0
var _a: float = 0.0
var _key: String = "I"

## The beats, in seconds from opening.
const T_FRAME := 0.5
const T_DEV := 1.2
const T_ART := 3.6
const T_ROUGH := 6.2
const T_KEY := 7.4
const T_CYCLE := 6.0
const PAIR_SECONDS := 4.2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


## Open with [param shown] pairs; [param key] is the look's key, for the keycap.
func open(shown: Array, key: String = "I") -> void:
	pairs = shown
	_key = key
	_t = 0.0
	_a = 0.0
	_closing = -1.0
	_open = true
	visible = true


func is_open() -> bool:
	return _open


func can_skip() -> bool:
	return _open and _t >= skip_after and _closing < 0.0


## Closes it (the guide calls this on a key or a click once can_skip is true).
func close() -> void:
	if _open and _closing < 0.0:
		_closing = 0.35


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and can_skip():
		close()
	accept_event()


func _process(delta: float) -> void:
	if not _open:
		return
	size = get_viewport_rect().size
	_t += delta
	if _closing >= 0.0:
		_closing -= delta
		_a = clampf(_closing / 0.35, 0.0, 1.0)
		if _closing <= 0.0:
			_open = false
			visible = false
			closed.emit()
			return
	else:
		_a = minf(_a + delta / 0.4, 1.0)
		if _t >= hold_max:
			close()
	queue_redraw()


## The wipe, 0 (all art) to 1 (all dev), over time: the middle, then all the dev while the dev words come, then all the
## art while the art words come, then slowly back and forth.
func _wipe() -> float:
	if _t < T_DEV:
		return 0.5
	if _t < T_ART:
		return lerpf(0.5, 1.0, _ease((_t - T_DEV) / 1.1))
	if _t < T_CYCLE:
		return lerpf(1.0, 0.0, _ease((_t - T_ART) / 1.4))
	return 0.5 + 0.38 * sin((_t - T_CYCLE) * TAU / 5.0 - PI * 0.5)


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The pair showing now, the one coming next, and how far into the crossfade to it (0..1): the first pair until the
## cycle starts, then each for PAIR_SECONDS, fading to the next over its last eighth.
func _pairs_now() -> Vector3:
	if pairs.size() <= 1 or _t < T_CYCLE:
		return Vector3(0.0, 0.0, 0.0)
	var s: float = (_t - T_CYCLE) / PAIR_SECONDS
	var k: int = int(floor(s))
	return Vector3(float(k % pairs.size()), float((k + 1) % pairs.size()), _ease((fmod(s, 1.0) - 0.88) / 0.12))


func _fade_in(at: float, over: float = 0.5) -> float:
	return _ease((_t - at) / over) * _a


func _draw() -> void:
	# Its first draw can come before _process has sized it (font sizes of 0).
	if not _open or size.y < 100.0:
		return
	var screen: Vector2 = size
	var u: float = screen.y / 1080.0
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.015, 0.02, 0.04, 0.93 * _a))
	var fb: Font = LabPrint.font("black")
	var fbo: Font = LabPrint.font("bold")
	var fs: Font = LabPrint.font("body")
	var accent := Style.UI_ACCENT
	# The frame: 16:9, as big as leaves room for the words.
	var fw: float = minf(screen.x * 0.60, screen.y * 0.46 * 16.0 / 9.0)
	var fh: float = fw * 9.0 / 16.0
	var frame := Rect2(Vector2((screen.x - fw) * 0.5, screen.y * 0.205), Vector2(fw, fh))
	# The title over it.
	var ta: float = _fade_in(0.0, 0.6)
	var rise: float = (1.0 - _ease(_t / 0.6)) * 16.0 * u
	draw_string(fbo, Vector2(0.0, frame.position.y - 74.0 * u + rise), "THE DREAM SHIFTER", HORIZONTAL_ALIGNMENT_CENTER, screen.x, int(14 * u), Color(accent, ta))
	draw_string(fb, Vector2(0.0, frame.position.y - 26.0 * u + rise), "One world. Two modes.", HORIZONTAL_ALIGNMENT_CENTER, screen.x, int(44 * u), Color(1, 1, 1, ta))
	# The pictures and the wipe.
	var fa: float = _fade_in(T_FRAME, 0.45)
	if fa > 0.0 and not pairs.is_empty():
		var pn: Vector3 = _pairs_now()
		var w: float = _wipe()
		_draw_pair(frame, int(pn.x), w, fa)
		if pn.z > 0.0:
			_draw_pair(frame, int(pn.y), w, fa * pn.z)
		var lx: float = frame.position.x + fw * w
		# The line: a soft glow and a bright core, full height of the frame.
		draw_rect(Rect2(Vector2(lx - 14.0 * u, frame.position.y), Vector2(28.0 * u, fh)), Color(accent, 0.10 * fa))
		draw_rect(Rect2(Vector2(lx - 5.0 * u, frame.position.y), Vector2(10.0 * u, fh)), Color(accent, 0.25 * fa))
		draw_rect(Rect2(Vector2(lx - 1.5 * u, frame.position.y), Vector2(3.0 * u, fh)), Color(1, 1, 1, 0.95 * fa))
		draw_circle(Vector2(lx, frame.get_center().y), 15.0 * u, Color(1, 1, 1, 0.95 * fa))
		draw_string(fbo, Vector2(lx - 15.0 * u, frame.get_center().y + 5.0 * u), "‹ ›", HORIZONTAL_ALIGNMENT_CENTER, 30.0 * u, int(14 * u), Color(0.1, 0.12, 0.16, fa))
		# The frame's edge, and the two tags in its top corners.
		draw_rect(frame, Color(1, 1, 1, 0.35 * fa), false, maxf(1.0, 2.0 * u))
		_tag(frame.position + Vector2(14.0, 14.0) * u, "DEV MODE", false, fa * (0.4 + 0.6 * clampf(w * 2.0, 0.0, 1.0)), u)
		_tag(Vector2(frame.end.x - 14.0 * u, frame.position.y + 14.0 * u), "ART MODE", true, fa * (0.4 + 0.6 * clampf((1.0 - w) * 2.0, 0.0, 1.0)), u)
		var label: String = String(pairs[int(pn.y) if pn.z > 0.5 else int(pn.x)].get("label", ""))
		if label != "":
			draw_string(fs, Vector2(frame.position.x, frame.end.y + 22.0 * u), label, HORIZONTAL_ALIGNMENT_LEFT, fw, int(13 * u), Color(1, 1, 1, 0.55 * fa))
	# The two modes, under the halves of the frame they belong to.
	var col_y: float = frame.end.y + 62.0 * u
	var col_w: float = fw * 0.5 - 24.0 * u
	var da: float = _fade_in(T_DEV, 0.5)
	if da > 0.0:
		var lit: float = 1.0 if _t < T_ART or _t >= T_CYCLE else 0.55
		draw_string(fb, Vector2(frame.position.x, col_y), "DEV MODE", HORIZONTAL_ALIGNMENT_LEFT, col_w, int(22 * u), Color(accent, da * lit))
		draw_string(fbo, Vector2(frame.position.x, col_y + 34.0 * u), "How we build.", HORIZONTAL_ALIGNMENT_LEFT, col_w, int(19 * u), Color(1, 1, 1, da * lit))
		draw_multiline_string(fs, Vector2(frame.position.x, col_y + 62.0 * u), "We block it out, test it, and find out what is possible in 4D.",
			HORIZONTAL_ALIGNMENT_LEFT, col_w, int(17 * u), 3, Color(1, 1, 1, 0.82 * da * lit))
	var aa: float = _fade_in(T_ART, 0.5)
	if aa > 0.0:
		var x2: float = frame.position.x + fw * 0.5 + 24.0 * u
		var lit2: float = 1.0 if _t >= T_ART else 0.55
		draw_string(fb, Vector2(x2, col_y), "ART MODE", HORIZONTAL_ALIGNMENT_LEFT, col_w, int(22 * u), Color(Style.UI_GOLD, aa * lit2))
		draw_string(fbo, Vector2(x2, col_y + 34.0 * u), "Where it is going.", HORIZONTAL_ALIGNMENT_LEFT, col_w, int(19 * u), Color(1, 1, 1, aa * lit2))
		draw_multiline_string(fs, Vector2(x2, col_y + 62.0 * u), "The same world, dressed as the vision it can become.",
			HORIZONTAL_ALIGNMENT_LEFT, col_w, int(17 * u), 3, Color(1, 1, 1, 0.82 * aa * lit2))
	# The message, and the key.
	var ra: float = _fade_in(T_ROUGH, 0.6)
	if ra > 0.0:
		draw_string(fbo, Vector2(0.0, col_y + 140.0 * u), "Rough on purpose. This is a prototype, and every block in it is a question we are answering about 4D.",
			HORIZONTAL_ALIGNMENT_CENTER, screen.x, int(18 * u), Color(1, 1, 1, ra))
	var ka: float = _fade_in(T_KEY, 0.5)
	if ka > 0.0:
		var words: String = "switches between them, any time."
		var px: int = int(19 * u)
		var tw: float = fbo.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var cap := Vector2(46.0, 46.0) * u
		var gap: float = 14.0 * u
		var x0: float = (screen.x - (cap.x + gap + tw)) * 0.5
		var ky: float = col_y + 172.0 * u
		_keycap(Rect2(Vector2(x0, ky), cap), _key, int(24 * u), ka)
		draw_string(fbo, Vector2(x0 + cap.x + gap, ky + cap.y * 0.66), words, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, ka))
	_draw_skip(screen, u)


func _draw_pair(frame: Rect2, index: int, wipe: float, alpha: float) -> void:
	if pairs.is_empty():
		return
	var pair: Dictionary = pairs[clampi(index, 0, pairs.size() - 1)]
	var art: Texture2D = pair.get("art") as Texture2D
	var dev: Texture2D = pair.get("dev") as Texture2D
	if art != null:
		draw_texture_rect_region(art, frame, _crop(art, 0.0, 1.0), Color(1, 1, 1, alpha))
	if dev != null and wipe > 0.001:
		var part := Rect2(frame.position, Vector2(frame.size.x * wipe, frame.size.y))
		draw_texture_rect_region(dev, part, _crop(dev, 0.0, wipe), Color(1, 1, 1, alpha))


## The middle 16:9 of [param tex], from [param from] to [param to] across its width (shares of the crop).
static func _crop(tex: Texture2D, from: float, to: float) -> Rect2:
	var s: Vector2 = tex.get_size()
	var w: float = minf(s.x, s.y * 16.0 / 9.0)
	var h: float = w * 9.0 / 16.0
	var o := Vector2((s.x - w) * 0.5, (s.y - h) * 0.5)
	return Rect2(o + Vector2(w * from, 0.0), Vector2(w * (to - from), h))


func _tag(at: Vector2, text: String, right: bool, alpha: float, u: float) -> void:
	var f: Font = LabPrint.font("black")
	var px: int = int(13 * u)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pad := Vector2(10.0, 6.0) * u
	var box := Rect2(Vector2(at.x - (tw + pad.x * 2.0) if right else at.x, at.y), Vector2(tw + pad.x * 2.0, px + pad.y * 2.0))
	var sb := Style.glass_box(6.0 * u, alpha, 0.75)
	draw_style_box(sb, box)
	draw_string(f, box.position + Vector2(pad.x, pad.y + px * 0.82), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, alpha))


## Bottom right: a bar filling while it cannot be skipped yet, then "Space  continue".
func _draw_skip(screen: Vector2, u: float) -> void:
	var fbo: Font = LabPrint.font("bold")
	var px: int = int(15 * u)
	var at := Vector2(screen.x - 48.0 * u, screen.y - 46.0 * u)
	if _t < skip_after:
		var bw: float = 160.0 * u
		var r := Rect2(Vector2(at.x - bw, at.y - 4.0 * u), Vector2(bw, 4.0 * u))
		draw_rect(r, Color(1, 1, 1, 0.15 * _a))
		draw_rect(Rect2(r.position, Vector2(bw * (_t / skip_after), r.size.y)), Color(1, 1, 1, 0.55 * _a))
		return
	var a: float = _ease((_t - skip_after) / 0.4) * _a
	var words: String = "continue"
	var tw: float = fbo.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var cap := Vector2(78.0, 34.0) * u
	var x0: float = at.x - tw - 12.0 * u - cap.x
	_keycap(Rect2(Vector2(x0, at.y - cap.y), cap), "Space", int(14 * u), a)
	draw_string(fbo, Vector2(at.x - tw, at.y - cap.y * 0.3), words, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, a))


## A key cap as the lab kit draws them (LabPrint.keycap), faded by [param alpha] lip and all.
func _keycap(rect: Rect2, label: String, px: int, alpha: float) -> void:
	var r: int = int(rect.size.y * 0.14)
	var lip := StyleBoxFlat.new()
	lip.bg_color = Color(0.20, 0.21, 0.23, alpha)
	lip.set_corner_radius_all(r)
	lip.anti_aliasing = true
	draw_style_box(lip, Rect2(rect.position + Vector2(0.0, rect.size.y * 0.09), rect.size))
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.96, 0.96, 0.95, alpha)
	face.set_corner_radius_all(r)
	face.anti_aliasing = true
	draw_style_box(face, rect)
	var f: Font = LabPrint.font("bold")
	draw_string(f, Vector2(rect.position.x, rect.get_center().y + f.get_ascent(px) * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, px, Color(0.12, 0.12, 0.13, alpha))
