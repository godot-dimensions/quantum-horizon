extends Control

## The menu's loading screen: what shows from the click until the prototype is there. In the style of
## the Voxel Lab's loading board (VoxelLab/room/vl_load_board.gd), so every scene loads the same way
## (Ramon, 9 Oct: "let your menu loader be in the same style as the voxel labs start loader ... so
## your loader will be consistent across all scenes ... your design can be different of course, but
## the style should be the same"). The style, shared: full screen in the lab's code blue with its wall
## grid drifting faintly, everything on it white, Montserrat ExtraBold for the title, small tracked
## Bold for the labels, big figures along the bottom, a thin line along the foot that fills, and at
## the end a white flash that fades into the scene. The design, the menu's own: the prototype's name
## and line, its keys as white caps under HOW TO PLAY, its logo in the square on the right with the
## question it asks under it, and where it sits in the run.
##
## A copy of the lab board's tokens rather than a reference to its file: the menu must not depend on
## a prototype's folder. If the lab's board changes its look, change this one to match.
##
## On its own CanvasLayer at 29, one under the lab board's 30. One white fade, at the very end (Ramon,
## 9 Oct): a prototype that brings its own board (the Voxel Lab's, on a layer named LoadBoard) puts it
## over this one in the frame it arrives, blue hands over to blue, this one goes without a white
## (menu_final._hand_over_overlay), and the white is the scene's own once it is built. Any other
## prototype gets this board's white (finish()) the moment it is there.
##
##   kicker, title, subtitle          the words at the top left
##   keys       [[key, action], ...]  HOW TO PLAY
##   logo       Texture2D             in the square, drawn white (or painter, a Callable, draws it)
##   question   String                under the square
##   numbers    [[label, value], ...] big white figures along the bottom
##   progress   0..1, stage String    the line along the foot and what it is doing
##   begin(), finish(), close_now()   up, white then the scene, gone at once
##
## NO class_name (engine_gotchas.md): menu_final preloads it.

const CODE_BLUE := Color(0.13, 0.40, 0.86)
const FONTS := {
	"black": "res://ramon/Demo/fonts/Montserrat/static/Montserrat-ExtraBold.ttf",
	"bold": "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Bold.ttf",
	"body": "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf",
}
## The kit's type scale (kit_style.gd): 11 px at 720 high, steps of 1.25.
const TYPE_PX := 11.0
const TYPE_RATIO := 1.25
const TYPE_STEP := {"micro": -2, "caption": -1, "body": 0, "lead": 1}

var kicker: String = ""
var title: String = ""
var subtitle: String = ""
var keys: Array = []
var logo: Texture2D = null
## Draws into the square instead of a logo: func(canvas: CanvasItem, area: Rect2).
var painter: Callable = Callable()
var question: String = ""
var numbers: Array = []
var progress: float = 0.0
var stage: String = "LOADING"
var _phase: String = "idle"
var _t: float = 0.0
var _white: float = 0.0
var _fonts: Dictionary = {}


static func open(host: Node) -> Control:
	var layer := CanvasLayer.new()
	layer.name = "MenuLoadBoard"
	layer.layer = 29
	layer.visible = false
	host.add_child(layer)
	var b := Control.new()
	b.set_script(load("res://ramon/Menu/scripts/menu_load_board.gd"))
	layer.add_child(b)
	return b


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func showing() -> bool:
	return _phase != "idle"


## Up, at the start of a launch.
func begin() -> void:
	_phase = "board"
	_t = 0.0
	_white = 0.0
	progress = 0.0
	stage = "LOADING"
	mouse_filter = Control.MOUSE_FILTER_STOP
	(get_parent() as CanvasLayer).visible = true
	queue_redraw()


## The prototype is there: white, then the white fades to it. Lets the mouse through at once, so
## nothing in the scene waits on the fade.
func finish() -> void:
	if _phase == "board":
		_phase = "white"
		_t = 0.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE


## Gone at once (a failed launch, or the menu coming back).
func close_now() -> void:
	_phase = "idle"
	_white = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	(get_parent() as CanvasLayer).visible = false


func _process(delta: float) -> void:
	if _phase == "idle":
		return
	size = get_viewport_rect().size
	_t += delta
	match _phase:
		"white":
			_white = minf(1.0, _t / 0.35)
			if _white >= 1.0:
				_phase = "out"
				_t = 0.0
		"out":
			_white = 1.0 - minf(1.0, _t / 0.8)
			if _t >= 0.8:
				close_now()
				return
	queue_redraw()


func _font(kind: String) -> Font:
	if not _fonts.has(kind):
		var f: Font = load(FONTS.get(kind, FONTS["body"])) as Font
		_fonts[kind] = f if f != null else ThemeDB.fallback_font
	return _fonts[kind]


func _px(role: String, u: float) -> int:
	return maxi(7, int(round(TYPE_PX * pow(TYPE_RATIO, float(TYPE_STEP.get(role, 0))) * u)))


func _draw() -> void:
	# Its first frame comes before it knows the window: nothing to draw at no size (fonts at 0 px err).
	if size.y < 8.0 or _phase == "idle":
		return
	var u: float = size.y / 720.0
	if _phase != "out":
		_board(u)
	if _white > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _white))


func _board(u: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CODE_BLUE)
	# The wall's grid, faint, drifting: the one thing that moves while the engine is busy.
	var step: float = 48.0 * u
	var line := Color(1, 1, 1, 0.07)
	var x: float = fposmod(-_t * 6.0 * u, step)
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), line, 1.0)
		x += step
	var y: float = 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), line, 1.0)
		y += step
	var white := Color.WHITE
	var dim := Color(1, 1, 1, 0.68)
	var fb: Font = _font("black")
	var fs: Font = _font("bold")
	var fl: Font = _font("body")
	var left: float = 72.0 * u
	var top: float = 84.0 * u
	var text_w: float = size.x * 0.50
	# The words.
	draw_string(fs, Vector2(left, top), kicker, HORIZONTAL_ALIGNMENT_LEFT, text_w, _px("caption", u), dim)
	draw_string(fb, Vector2(left, top + 64.0 * u), title, HORIZONTAL_ALIGNMENT_LEFT, text_w, int(58 * u), white)
	draw_multiline_string(fs, Vector2(left, top + 98.0 * u), subtitle, HORIZONTAL_ALIGNMENT_LEFT, text_w, _px("lead", u), 2, white)
	# How to play: each key as a white outlined cap, its action beside it.
	# Where the lab board's WHAT IS COMING sits, so a hand-over to it does not jump.
	var cy: float = top + 156.0 * u
	if not keys.is_empty():
		draw_string(fs, Vector2(left, cy), "HOW TO PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, _px("caption", u), dim)
		cy += 14.0 * u
		var cap_px: int = _px("caption", u)
		var act_px: int = _px("lead", u)
		for k in keys:
			cy += 34.0 * u
			var key_text: String = String(k[0])
			var kw: float = maxf(fs.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_px).x + 18.0 * u, 34.0 * u)
			var cap := Rect2(Vector2(left, cy - 18.0 * u), Vector2(kw, 24.0 * u))
			draw_rect(cap, Color(1, 1, 1, 0.9), false, maxf(1.0, 1.2 * u))
			draw_string(fs, Vector2(cap.position.x, cy - 1.0 * u), key_text, HORIZONTAL_ALIGNMENT_CENTER, kw, cap_px, white)
			draw_string(fl, Vector2(left + 112.0 * u, cy), String(k[1]), HORIZONTAL_ALIGNMENT_LEFT, text_w - 112.0 * u, act_px, white)
	# The square on the right: the prototype's logo, drawn white; the question it asks under it.
	# The lab board's square, the same size and place.
	var side: float = minf(size.y * 0.5, size.x * 0.32)
	var box := Rect2(Vector2(size.x - left - side, top - 20.0 * u), Vector2(side, side))
	draw_rect(box, Color(1, 1, 1, 0.5), false, maxf(1.0, 1.5 * u))
	if logo != null:
		var s: float = side * 0.52
		var aspect: float = float(logo.get_width()) / maxf(1.0, float(logo.get_height()))
		var ls := Vector2(s, s / aspect) if aspect >= 1.0 else Vector2(s * aspect, s)
		draw_texture_rect(logo, Rect2(box.get_center() - ls * 0.5, ls), false, Color(1, 1, 1, 0.92))
	elif painter.is_valid():
		painter.call(self, box)
	if not question.is_empty():
		draw_string(fs, Vector2(box.position.x, box.end.y + 26.0 * u), "THE QUESTION", HORIZONTAL_ALIGNMENT_LEFT, side, _px("caption", u), dim)
		draw_multiline_string(fl, Vector2(box.position.x, box.end.y + 50.0 * u), question, HORIZONTAL_ALIGNMENT_LEFT, side, _px("body", u), 3, white)
	# The figures along the bottom.
	var fy: float = size.y - 96.0 * u
	var fx: float = left
	for n in numbers:
		var v: String = String(n[1])
		draw_string(fb, Vector2(fx, fy), v, HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * u), white)
		draw_string(fs, Vector2(fx, fy + 24.0 * u), String(n[0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, _px("micro", u), dim)
		fx += maxf(fb.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * u)).x, 120.0 * u) + 48.0 * u
	# The line along the foot, and what it is doing: the file loading (a real percentage), then the
	# scene being built (the engine's own work on the main thread, which cannot be measured).
	var pr := Rect2(Vector2(left, size.y - 40.0 * u), Vector2(size.x - left * 2.0, 3.0 * u))
	draw_rect(pr, Color(1, 1, 1, 0.22))
	draw_rect(Rect2(pr.position, Vector2(pr.size.x * clampf(progress, 0.0, 1.0), pr.size.y)), white)
	var label: String = stage
	if stage == "LOADING":
		label = "LOADING  %d%%" % int(round(clampf(progress, 0.0, 1.0) * 100.0))
	draw_string(fs, Vector2(pr.end.x - 320.0 * u, pr.position.y - 10.0 * u), label, HORIZONTAL_ALIGNMENT_RIGHT, 320.0 * u, _px("caption", u), white)
