extends Control

## WATER LAB, THE SEA: what everyone sees (Ramon, 9 Oct, round 2: "as the scene starts, you don't see
## any HUD ... what everybody else will see is a little overlay HUD ... sea variations, including this
## one as the basic one that you enter. An ability to turn the Gerstner on and off ... next to the
## navigational buttons with the keystrokes aligned to it ... a separate little area ... a panel that
## shows the metrics ... we need this movement icon for the mouse also here"). The dev HUD (Tab,
## seascape_hud.gd) stays as it was, closed until asked for.
##
## In the lab kit's family for overlays (kit_style.gd: black glass, white type, light blue for what is
## active; a numbered box is a button, and these answer their keys):
##   THE KEYS     a strip along the bottom, the tank room's (rd_hud.gd): walk, look, and on the
##                platform the right drag; R, G, Tab.
##   THE SEA      bottom left: the four seas as tiles 1 to 4, the one running lit; under them the
##                Gerstner, off and its three looks, G stepping through them.
##   THE NUMBERS  bottom right: the sea's dominant wave (amplitude, wavelength, steepness, how far it
##                runs off the slice), the slice's tilt, the solve, the frame rate.
##   THE MOUSE    on the platform, the shared mouse tutorial (shared/mouse_tutorial.gd) acting the
##                right drag.
##   A THOUGHT    thought(text): a line in the middle of the screen for a few seconds (the edge's
##                "look down").
##
## Sizes follow the window's height. NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/WaterLab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")
const Presets := preload("res://ramon/WaterLab/carried/water4d/water4d_presets.gd")
const MouseTutorial := preload("res://ramon/WaterLab/shared/mouse_tutorial.gd")

## The scene's root (seascape_4d.gd).
var room: Node
var _mouse: Control
var _thought: String = ""
var _thought_left: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_mouse = Control.new()
	_mouse.set_script(MouseTutorial)
	_mouse.set("gestures", [["drag_h", "TURN THE SLICE"], ["drag_v", "TURN IT THE OTHER WAY"]])
	_mouse.set("anchor", Vector2(0.03, 0.42))
	add_child(_mouse)


func thought(text: String) -> void:
	_thought = text
	_thought_left = 5.0


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	_t += delta
	_thought_left = maxf(_thought_left - delta, 0.0)
	if _mouse != null:
		_mouse.set("shown", room != null and String(room.get("_site")) == "platform")
	queue_redraw()


func _draw() -> void:
	if room == null or size.y < 100.0:
		return
	var u: float = size.y / 1080.0
	_draw_keys(u)
	_draw_seas(u)
	var dev: Node = room.get("hud")
	if dev == null or int(dev.get("mode")) != 1:
		_draw_numbers(u)
	if _thought_left > 0.0:
		_draw_thought(u)


func _glass(r: Rect2, u: float) -> void:
	draw_style_box(Style.glass_box(16.0 * u), r)


func _draw_keys(u: float) -> void:
	var on_platform: bool = String(room.get("_site")) == "platform"
	var strip: Array = [["WASD", "Walk"], ["Mouse", "Look"]]
	if on_platform:
		strip.append(["Right drag", "Turn the slice"])
		strip.append(["R", "Level it"])
	strip.append(["G", "Gerstner"])
	strip.append(["Tab", "Dev"])
	var fk: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var kpx: int = Style.type_px("caption", u)
	var lpx: int = Style.type_px("body", u)
	var gap: float = 22.0 * u
	var widths: Array = []
	var total: float = 0.0
	for it in strip:
		var kw: float = maxf(24.0 * u, fk.get_string_size(String(it[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, kpx).x + 14.0 * u)
		var lw: float = fl.get_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
		widths.append([kw, lw])
		total += kw + 8.0 * u + lw
	total += gap * float(strip.size() - 1) + 40.0 * u
	var h: float = 40.0 * u
	var r := Rect2(Vector2((size.x - total) * 0.5, size.y - h - 22.0 * u), Vector2(total, h))
	var sb := Style.glass_box(h * 0.5)
	draw_style_box(sb, r)
	var ink := Color(1, 1, 1, 0.96)
	var x: float = r.position.x + 20.0 * u
	for i in strip.size():
		var kw: float = widths[i][0]
		var lw: float = widths[i][1]
		var kr := Rect2(Vector2(x, r.get_center().y - 11.0 * u), Vector2(kw, 22.0 * u))
		var kb := StyleBoxFlat.new()
		kb.draw_center = false
		kb.border_color = Color(ink, 0.7)
		kb.set_border_width_all(int(maxf(1.0, 1.5 * u)))
		kb.set_corner_radius_all(int(5 * u))
		draw_style_box(kb, kr)
		draw_string(fk, Vector2(kr.position.x, kr.get_center().y + 4.0 * u), String(strip[i][0]), HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, kpx, ink)
		var lx: float = kr.end.x + 8.0 * u
		draw_string(fl, Vector2(lx, r.get_center().y + 4.5 * u), String(strip[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, ink)
		x = lx + lw + gap
		if i < strip.size() - 1:
			draw_line(Vector2(x - gap * 0.5, r.position.y + 11.0 * u), Vector2(x - gap * 0.5, r.end.y - 11.0 * u), Color(ink, 0.25), maxf(1.0, u))


## The four seas and the Gerstner, bottom left.
func _draw_seas(u: float) -> void:
	var seas: Array = room.call("seas")
	var on: int = int(room.call("sea_index"))
	var g: int = int(room.call("gerstner"))
	var w: float = 430.0 * u
	var h: float = 236.0 * u
	var r := Rect2(Vector2(24.0 * u, size.y - h - 84.0 * u), Vector2(w, h))
	_glass(r, u)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var pad: float = 18.0 * u
	draw_string(fb, r.position + Vector2(pad, pad + 14.0 * u), "THE SEA", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u), Color.WHITE)
	draw_string(fs, r.position + Vector2(pad, pad + 14.0 * u), "1 - 4", HORIZONTAL_ALIGNMENT_RIGHT, w - pad * 2.0, int(12 * u), Color(Style.UI_INK_DIM))
	# The tiles: two rows of two.
	var tw: float = (w - pad * 2.0 - 10.0 * u) * 0.5
	var th: float = 46.0 * u
	for i in seas.size():
		var col: int = i % 2
		var row: int = i / 2
		var tr := Rect2(r.position + Vector2(pad + float(col) * (tw + 10.0 * u), pad + 28.0 * u + float(row) * (th + 8.0 * u)), Vector2(tw, th))
		var lit: bool = i == on
		_tile(tr, u, lit)
		var ink: Color = Style.UI_ACCENT if lit else Color(1, 1, 1, 0.9)
		draw_string(fs, tr.position + Vector2(10.0 * u, 18.0 * u), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * u), ink)
		draw_string(fl, tr.position + Vector2(30.0 * u, 29.0 * u), Presets.preset_name(int(seas[i])), HORIZONTAL_ALIGNMENT_LEFT, tw - 36.0 * u, int(14 * u), ink)
	# The Gerstner: off and its three looks.
	var gy: float = r.position.y + pad + 28.0 * u + 2.0 * (th + 8.0 * u) + 10.0 * u
	draw_string(fb, Vector2(r.position.x + pad, gy + 14.0 * u), "GERSTNER", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * u), Color.WHITE)
	draw_string(fs, Vector2(r.position.x + pad, gy + 14.0 * u), "G", HORIZONTAL_ALIGNMENT_RIGHT, w - pad * 2.0, int(12 * u), Color(Style.UI_INK_DIM))
	var labels: Array = ["OFF", "1", "2", "3"]
	var gw: float = (w - pad * 2.0 - 3.0 * 8.0 * u) / 4.0
	for i in 4:
		var gr := Rect2(Vector2(r.position.x + pad + float(i) * (gw + 8.0 * u), gy + 24.0 * u), Vector2(gw, 30.0 * u))
		var lit2: bool = i == g
		_tile(gr, u, lit2)
		draw_string(fs, Vector2(gr.position.x, gr.get_center().y + 5.0 * u), labels[i], HORIZONTAL_ALIGNMENT_CENTER, gw, int(13 * u), Style.UI_ACCENT if lit2 else Color(1, 1, 1, 0.85))


func _tile(r: Rect2, u: float, lit: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Style.UI_ACCENT, 0.16) if lit else Color(1, 1, 1, 0.04)
	sb.border_color = Color(Style.UI_ACCENT, 0.9) if lit else Color(1, 1, 1, 0.22)
	sb.set_border_width_all(int(maxf(1.0, (2.5 if lit else 1.2) * u)))
	sb.set_corner_radius_all(int(8 * u))
	draw_style_box(sb, r)


## The numbers, bottom right.
func _draw_numbers(u: float) -> void:
	var water: Node = room.get_node_or_null("Water")
	if water == null:
		return
	var d: Dictionary = water.call(&"dominant")
	var turn: Vector2 = room.call("slice_degrees")
	var iterations: int = int(water.get(&"solve_iterations"))
	var rows: Array = [
		["Amplitude", "%.2f m" % float(d.get("amplitude", 0.0))],
		["Wavelength", "%.1f m" % float(d.get("wavelength", 0.0))],
		["Steepness", "%.2f" % float(d.get("steepness", 0.0))],
		["Off W", "%.2f" % float(d.get("off_slice", 0.0))],
		["Slice tilted", "%.0f°" % turn.x],
		["Solve", ("%d iterations" % iterations) if iterations > 0 else "off"],
		["Frame rate", "%d fps" % Engine.get_frames_per_second()],
	]
	var w: float = 330.0 * u
	var line: float = 24.0 * u
	var h: float = 62.0 * u + line * float(rows.size())
	var r := Rect2(Vector2(size.x - w - 24.0 * u, size.y - h - 84.0 * u), Vector2(w, h))
	_glass(r, u)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var pad: float = 18.0 * u
	var index: int = int(water.get(&"preset_index"))
	draw_string(fb, r.position + Vector2(pad, pad + 14.0 * u), Presets.preset_name(index).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, int(15 * u), Color.WHITE)
	draw_string(fs, r.position + Vector2(pad, pad + 34.0 * u), "THE DOMINANT WAVE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(Style.UI_INK_DIM))
	for i in rows.size():
		var y: float = r.position.y + pad + 60.0 * u + float(i) * line
		draw_string(fl, Vector2(r.position.x + pad, y), String(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), Color(1, 1, 1, 0.72))
		draw_string(fs, Vector2(r.position.x + pad, y), String(rows[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, w - pad * 2.0, int(14 * u), Color.WHITE)


func _draw_thought(u: float) -> void:
	var a: float = clampf(_thought_left / 0.6, 0.0, 1.0) * clampf((5.0 - _thought_left) / 0.4, 0.0, 1.0)
	var fb: Font = LabPrint.font("bold")
	var px: int = int(26 * u)
	var tw: float = fb.get_string_size(_thought, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var r := Rect2(Vector2((size.x - tw) * 0.5 - 28.0 * u, size.y * 0.30), Vector2(tw + 56.0 * u, 60.0 * u))
	var sb := Style.glass_box(30.0 * u)
	sb.bg_color.a *= a
	draw_style_box(sb, r)
	draw_string(fb, Vector2(r.position.x, r.get_center().y + 9.0 * u), _thought, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, Color(1, 1, 1, a))
