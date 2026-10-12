extends Control

## F4: the developer overlay - what the 4D renderer and the photo judge are working with, drawn
## over whatever camera is up (the farm's, the raised one, the balloon's, the hawk's). The
## "accessibility for developers" pillar made visible: everything here was already being
## worked out every frame; this only draws it.
##
## For each creature in front of you, within reach in W:
##   - a dashed box: the creature's whole extent, as if it were all in your slice;
##   - a solid box inside it: the part your slice actually cuts - the section of a 4D body,
##     sqrt(1 - (dw / R)^2) of it, where dw is how far its middle is from your slice and R
##     how deep it is in W;
##   - a W gauge beside it: its depth along W as a bar, and a tick where your slice crosses;
##   - its numbers: its w from your slice, its depth, how much of it is cut.
## And a card: where the camera is in all four axes, which way its slice faces (the normal,
## and the two slice angles), the renderer, the frame.

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")

@export var key: Key = KEY_F4

var lookout: Node
var on: bool = false

var _font: Font
var _card: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_default_font()
	_card = StyleBoxFlat.new()
	_card.bg_color = Color(0.03, 0.04, 0.06, 0.62)
	_card.border_color = Color(1.0, 1.0, 1.0, 0.1)
	_card.set_border_width_all(1)
	_card.set_corner_radius_all(9)
	visible = false


func _input(event: InputEvent) -> void:
	var press := event as InputEventKey
	if press != null and press.pressed and not press.echo and press.keycode == key 			and (on or lookout == null or bool(lookout.call("_at_lookout"))):
		on = not on
		visible = on
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if on:
		queue_redraw()


func _draw() -> void:
	if lookout == null:
		return
	var cam: Camera4D = lookout.call("current_camera")
	if cam == null:
		return
	var s: Vector2 = get_viewport_rect().size
	var subjects: Node = lookout.get("subjects")
	var normal: Vector4 = cam.global_basis.w
	var t: float = tan(float(subjects.call("vertical_fov", cam)) * 0.5)
	var lit: Color = STYLE.accent.lightened(0.45)
	var listed: int = 0
	var cut_count: int = 0
	for v in subjects.call("in_view", cam, cam.global_position, normal, 4.0):
		var subject: Dictionary = v["subject"]
		var sc: Vector2 = v["screen"]
		var depth: float = float(v["depth"])
		var dw: float = float(v["w"])
		var wr: float = maxf(float(subject["w_radius"]), 0.01)
		var left: float = 1.0 - (dw / wr) * (dw / wr)
		var cut: float = sqrt(left) if left > 0.0 else 0.0
		if cut > 0.0:
			cut_count += 1
		var p := Vector2((sc.x + 1.0) * 0.5 * s.x, (1.0 - sc.y) * 0.5 * s.y)
		var half: float = float(subject["radius"]) / (depth * t) * s.y * 0.5
		half = clampf(half, 6.0, s.y * 0.4)
		var c: Color = lit if cut > 0.0 else Color(1, 1, 1, 0.75)
		_dashed_rect(Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0), c * Color(1, 1, 1, 0.7))
		if cut > 0.0:
			draw_rect(Rect2(p - Vector2(half, half) * cut, Vector2(half, half) * 2.0 * cut), c, false, 1.5)
		# The W gauge: the body's depth along W, and where the slice crosses it.
		var gx: float = p.x + half + 10.0
		var gh: float = clampf(half * 2.0, 40.0, 160.0)
		var g0: float = p.y - gh * 0.5
		var span: float = 4.0
		var wy := func(w: float) -> float: return g0 + gh * (1.0 - (w + span) / (2.0 * span))
		draw_line(Vector2(gx, g0), Vector2(gx, g0 + gh), Color(1, 1, 1, 0.3), 1.0)
		draw_rect(Rect2(Vector2(gx - 3.0, wy.call(dw + wr)), Vector2(6.0, wy.call(dw - wr) - wy.call(dw + wr))), c * Color(1, 1, 1, 0.55))
		draw_line(Vector2(gx - 8.0, wy.call(0.0)), Vector2(gx + 8.0, wy.call(0.0)), Color(1, 1, 1, 0.95), 2.0)
		var label: String = "%s  w %+.2f  R %.2f  cut %d%%" % [String(subject["id"]), dw, wr, int(round(cut * 100.0))]
		draw_string(_font, Vector2(p.x - half, p.y - half - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
		listed += 1
	# The camera's card.
	var b: Projection = cam.global_basis
	var pos: Vector4 = cam.global_position
	var xw: float = rad_to_deg(atan2(b.w.x, b.w.w))
	var zw: float = rad_to_deg(atan2(b.w.z, b.w.w))
	var flock: Node = lookout.get("room").get_node_or_null("World/Flock")
	var rows: Array = [
		["camera", "x %.1f  y %.1f  z %.1f  w %+.2f" % [pos.x, pos.y, pos.z, pos.w]],
		["slice", "normal (%.2f, %.2f, %.2f, %.2f)" % [b.w.x, b.w.y, b.w.z, b.w.w]],
		["angles", "xw %+.1f°  zw %+.1f°  (0, 0 is the farm's slice)" % [xw, zw]],
		["renderer", "%s%s" % [String(cam.get("rendering_engine_name")), "  ·  flock ghost on" if flock != null and bool(flock.get("ghost")) else ""]],
		["lens", "%.1f° vertical, field_of_view_4d" % rad_to_deg(float(cam.get("field_of_view_4d")))],
		["creatures", "%d in reach, %d cut by the slice" % [listed, cut_count]],
		["frame", "%.0f fps  ·  scripts %.2f ms" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]],
	]
	var ts: int = 12
	var step: float = float(ts) + 7.0
	var w: float = 400.0
	var at := Vector2((s.x - w) * 0.5, s.y - 40.0 - step * float(rows.size() + 1) - 12.0)
	draw_style_box(_card, Rect2(at, Vector2(w, 12.0 + step * float(rows.size() + 1))))
	draw_rect(Rect2(at + Vector2(14.0, -6.0), Vector2(34.0, 3.0)), STYLE.accent.lightened(0.3))
	var asc: float = _font.get_ascent(ts)
	var y: float = at.y + 12.0
	draw_string(_font, Vector2(at.x + 14.0, y + asc), "Developer overlay  ·  F4", HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 1, 1, 0.6))
	y += step
	for row in rows:
		draw_string(_font, Vector2(at.x + 14.0, y + asc), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 1, 1, 0.45))
		draw_string(_font, Vector2(at.x + 86.0, y + asc), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, w - 100.0, ts, Color(1, 1, 1, 0.9))
		y += step


func _dashed_rect(r: Rect2, c: Color) -> void:
	var corners: Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n: int = maxi(int(a.distance_to(b) / 8.0), 1)
		for k in n:
			if k % 2 == 0:
				draw_line(a.lerp(b, float(k) / float(n)), a.lerp(b, float(k + 1) / float(n)), c, 1.0)
