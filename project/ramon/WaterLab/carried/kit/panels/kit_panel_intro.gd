@tool
extends "res://ramon/WaterLab/carried/kit/panels/kit_panel_page.gd"

## Kit: the introduction panel, a stable room introduction (rule 2), laid out as frame 01's left
## panel: the running header ("01 / CREATION LAB", the status on the right), the title on one line,
## the lead on one line, the description in at most five lines no wider than 680, the lower rule,
## then CONTROLS (on the line where the research panel's benchmark starts) and two to four
## shortcuts, an icon over each label, the labels standing on the research panel's footnote line.
##
## refresh(d), d from the room's data (kit_room_info.gd) with its words filled in:
##   header_left, header_right, title, lead, body, heading, controls: [[icon, label], ...]
## flash(icon) lights that shortcut's icon for a moment: its control was just used.
##
## NO class_name (engine_gotchas.md).

const FLASH_S := 0.7

var title_t: E.Text
var lead_t: E.Text
var body_t: E.Text
var heading_t: E.Text
var _icons: Array = []
var _labels: Array = []
var _kinds: Array = []
var _flash: Dictionary = {}


func _build() -> void:
	var main := group("Introduction")
	title_t = text(main, "Title", "hero", "white", Vector2(0, Spec.MAIN_Y), Spec.PANEL.x)
	lead_t = text(main, "Lead", "lead", "white", Vector2(0, Spec.MAIN_Y + 78.0 + 24.0), Spec.PANEL.x)
	body_t = text(main, "Introduction copy", "body", "muted", Vector2(0, Spec.MAIN_Y + 162.0), Spec.BODY_MAX_W, Spec.BODY_MAX_LINES)
	var ctl := group("Controls")
	heading_t = text(ctl, "Controls heading", "label", "muted", Vector2(0, Spec.SUPPORT_Y), Spec.PANEL.x)
	_icons = []
	_labels = []
	for i in 4:
		var sc := group("Shortcut %d" % (i + 1), ctl)
		var ic := E.Icon.new("Icon", k)
		sc.add_child(ic)
		var label_y: float = Spec.shortcut_label_y()
		ic.place(Vector2(float(i) * Spec.SHORTCUT_PITCH, label_y - Spec.SHORTCUT_LABEL_DY), Spec.ICON_BOX)
		var lb := text(sc, "Shortcut label", "control", "white", Vector2(float(i) * Spec.SHORTCUT_PITCH, label_y), Spec.SHORTCUT_W)
		_icons.append(ic)
		_labels.append(lb)


func refresh(d: Dictionary) -> void:
	header_left.set_text(String(d.get("header_left", "")))
	header_right.set_text(String(d.get("header_right", "")))
	title_t.set_text(String(d.get("title", "")))
	lead_t.set_text(String(d.get("lead", "")))
	body_t.set_text(String(d.get("body", "")))
	heading_t.set_text(String(d.get("heading", "CONTROLS")))
	var controls: Array = d.get("controls", [])
	if controls.size() < 2 or controls.size() > 4:
		push_warning("Wall panel: the introduction wants two to four shortcuts, not %d." % controls.size())
	_kinds = []
	for i in _icons.size():
		var on: bool = i < controls.size()
		var ic: E.Icon = _icons[i]
		(ic.get_parent() as Control).visible = on
		if not on:
			_kinds.append("")
			continue
		var kind: String = String(controls[i][0])
		_kinds.append(kind)
		if ic.kind != kind:
			ic.kind = kind
			ic.queue_redraw()
		(_labels[i] as E.Text).set_text(String(controls[i][1]))


## Lights the shortcut whose icon is `kind` ("wheel", "rdrag", "key:E", ...).
func flash(kind: String) -> void:
	if kind in _kinds:
		_flash[kind] = FLASH_S


func tick(dt: float) -> bool:
	var busy: bool = false
	for i in _icons.size():
		var kind: String = String(_kinds[i]) if i < _kinds.size() else ""
		var left: float = float(_flash.get(kind, 0.0))
		if left > 0.0:
			left = maxf(0.0, left - dt)
			_flash[kind] = left
			busy = true
		(_icons[i] as E.Icon).lit = E.ease_out(left / FLASH_S) if left > 0.0 else 0.0
	return busy
