extends Control

## The Voxel Lab's loading board (Ramon, 9 Oct: "when you go through the door the bake loads, and then
## you can see maybe a diagram saying some benchmarks in our cool style of blue, but then white ... full
## frame full screen ... just data, allowing the scene to load ... preview info about whats to come,
## that the screen fades to white and then it fades to the field and you're there"). Full screen, the
## lab's teaching blue with its grid, everything on it white: what is coming, the numbers of it being
## built as they change, and a diagram (the chunks appearing on a map, or one bar per specimen). When
## the host calls finish(), the board goes white, and the white fades to the scene, built.
##
## Whatever loads behind it may take every frame it likes: the frame-time spikes of building a world
## are on nobody's screen.
##
##   kicker, title, subtitle, coming (lines)     the words
##   numbers   [[label, value], ...]             big white figures along the bottom
##   dots      [[Vector2 in -1..1, lit], ...]    the chunk map (the open world)
##   bars      [[label, 0..1, value], ...]       one per specimen (the lab)
##   progress  0..1                              the line along the foot
##   finish()  white, then the scene; finished when it is gone
##
## open(host) puts one up on a layer of its own. NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")

signal finished

var kicker: String = "VOXEL LAB"
var title: String = ""
var subtitle: String = ""
var coming: Array = []
var numbers: Array = []
var dots: Array = []
var bars: Array = []
var progress: float = 0.0
var diagram_title: String = ""
## A small line at the foot, for credit.
var credit: String = ""
var _phase: String = "board"
var _t: float = 0.0
var _white: float = 0.0


static func open(host: Node) -> Control:
	var layer := CanvasLayer.new()
	layer.name = "LoadBoard"
	layer.layer = 30
	host.add_child(layer)
	var b := Control.new()
	b.set_script(load("res://ramon/VoxelLab/room/vl_load_board.gd"))
	layer.add_child(b)
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func showing() -> bool:
	return _phase != "done"


func finish() -> void:
	if _phase == "board":
		_phase = "white"
		_t = 0.0


func close_now() -> void:
	_phase = "done"
	finished.emit()
	get_parent().queue_free()


func _process(delta: float) -> void:
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


func _draw() -> void:
	var u: float = size.y / 720.0
	if _phase != "out":
		_board(u)
	if _white > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _white))


func _board(u: float) -> void:
	var blue: Color = Style.pick(Style.CODE_BLUE)
	draw_rect(Rect2(Vector2.ZERO, size), blue)
	# The wall's grid, faint.
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
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var left: float = 72.0 * u
	var top: float = 84.0 * u
	draw_string(fs, Vector2(left, top), kicker, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("caption", u), dim)
	draw_string(fb, Vector2(left, top + 64.0 * u), title, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.52, int(58 * u), white)
	draw_string(fs, Vector2(left, top + 98.0 * u), subtitle, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.52, Style.type_px("lead", u), white)
	var cy: float = top + 156.0 * u
	if not coming.is_empty():
		draw_string(fs, Vector2(left, cy), "WHAT IS COMING", HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("caption", u), dim)
		cy += 10.0 * u
		for c in coming:
			cy += 30.0 * u
			draw_rect(Rect2(Vector2(left, cy - 9.0 * u), Vector2(6.0 * u, 6.0 * u)), white)
			draw_string(fl, Vector2(left + 18.0 * u, cy), String(c), HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.48, Style.type_px("lead", u), white)
	# The figures along the bottom.
	var fy: float = size.y - 96.0 * u
	var fx: float = left
	for n in numbers:
		var v: String = String(n[1])
		draw_string(fb, Vector2(fx, fy), v, HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * u), white)
		draw_string(fs, Vector2(fx, fy + 24.0 * u), String(n[0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("micro", u), dim)
		fx += maxf(fb.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * u)).x, 120.0 * u) + 48.0 * u
	if not credit.is_empty():
		draw_string(fl, Vector2(left, size.y - 14.0 * u), credit, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("micro", u), Color(1, 1, 1, 0.6))
	# The line along the foot.
	var pr := Rect2(Vector2(left, size.y - 40.0 * u), Vector2(size.x - left * 2.0, 3.0 * u))
	draw_rect(pr, Color(1, 1, 1, 0.22))
	draw_rect(Rect2(pr.position, Vector2(pr.size.x * clampf(progress, 0.0, 1.0), pr.size.y)), white)
	draw_string(fs, Vector2(pr.end.x - 200.0 * u, pr.position.y - 10.0 * u), "BUILDING  %d%%" % int(round(clampf(progress, 0.0, 1.0) * 100.0)),
		HORIZONTAL_ALIGNMENT_RIGHT, 200.0 * u, Style.type_px("caption", u), white)
	# The diagram, on the right.
	var side: float = minf(size.y * 0.5, size.x * 0.32)
	var box := Rect2(Vector2(size.x - left - side, top - 20.0 * u), Vector2(side, side))
	draw_rect(box, Color(1, 1, 1, 0.5), false, maxf(1.0, 1.5 * u))
	if not diagram_title.is_empty():
		draw_string(fs, Vector2(box.position.x, box.end.y + 22.0 * u), diagram_title, HORIZONTAL_ALIGNMENT_LEFT, side, Style.type_px("caption", u), dim)
	if not dots.is_empty():
		var cell: float = side / 26.0
		for d in dots:
			var p: Vector2 = d[0]
			if absf(p.x) > 1.0 or absf(p.y) > 1.0:
				continue
			var c: Vector2 = box.get_center() + p * side * 0.48
			if bool(d[1]):
				draw_rect(Rect2(c - Vector2(cell, cell) * 0.42, Vector2(cell, cell) * 0.84), white)
			else:
				draw_rect(Rect2(c - Vector2(cell, cell) * 0.42, Vector2(cell, cell) * 0.84), Color(1, 1, 1, 0.45), false, 1.0)
		# You, in the middle.
		draw_circle(box.get_center(), 5.0 * u, Color(1.0, 0.86, 0.5))
	elif not bars.is_empty():
		var bh: float = minf(28.0 * u, (side - 24.0 * u) / float(bars.size()))
		var by: float = box.position.y + 18.0 * u
		for b in bars:
			draw_string(fs, Vector2(box.position.x + 14.0 * u, by + bh * 0.42), String(b[0]), HORIZONTAL_ALIGNMENT_LEFT, side * 0.45, Style.type_px("micro", u), white)
			var bar := Rect2(Vector2(box.position.x + side * 0.48, by + bh * 0.2), Vector2(side * 0.36 * clampf(float(b[1]), 0.0, 1.0), bh * 0.36))
			draw_rect(Rect2(Vector2(box.position.x + side * 0.48, by + bh * 0.2), Vector2(side * 0.36, bh * 0.36)), Color(1, 1, 1, 0.18))
			draw_rect(bar, white)
			draw_string(fl, Vector2(box.end.x - 12.0 * u - 60.0 * u, by + bh * 0.42), String(b[2]), HORIZONTAL_ALIGNMENT_RIGHT, 60.0 * u, Style.type_px("micro", u), white)
			by += bh
