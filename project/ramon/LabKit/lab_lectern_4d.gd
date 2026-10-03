@tool
extends Node4D

## The lectern in front of every rig, and its card.
##
## THE LECTERN is real 4D geometry, chamfered black metal with a slanted top and a strip of light
## along its edge in the part's colour, with real thickness through W, so it is there in your
## slice like anything else in the bay.
##
## THE CARD is drawn over it in 2D, through the live camera (LabKit/lab_overlay_4d.gd), so the
## text is crisp and always readable, the way the cinema draws its see-through pane (Ramon chose
## this over printing cards on 4D slabs, 3 Oct). It sits just above the lectern on screen, grows
## and shrinks a little with distance, and fades when the lectern leaves your slice or when you
## are far off. Before the step's task is done it shows a summary (the code, the title, the one
## idea); after, the full card: METHOD, SHOWS, LIMITS and MEASURED with its evidence tier, and
## a LIVE section the bay fills with its own numbers.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/LabKit/lab_style.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Overlay := preload("res://ramon/LabKit/lab_overlay_4d.gd")
const GENERATED := "lab_generated"

@export_enum("neutral", "build", "motion", "w") var part: String = "neutral":
	set(v):
		part = v
		_later()
## Beyond this distance the card is gone; within `full_within` it is at full size.
@export_range(2.0, 40.0, 0.5) var visible_within: float = 16.0
@export_range(1.0, 20.0, 0.5) var full_within: float = 6.0

var step: Resource
var done: bool = false
var metrics: Array = []
var mood: String = "bright"
var _strip: MeshInstance4D
var _parts: Array = []


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")
	add_to_group(Overlay.GROUP_DRAWER)


func _ready() -> void:
	mood = Style.mood_of(get_tree())
	_build()
	if not Engine.is_editor_hint():
		Overlay.ensure.call_deferred(get_tree())


func _later() -> void:
	if is_node_ready():
		_build()


func _build() -> void:
	for c in get_children():
		if c.has_meta(GENERATED):
			remove_child(c)
			c.free()
	_parts.clear()
	var w: float = 2.2
	# A column, a slanted top leaning towards whoever reads it (+Z), a foot.
	_box("Foot", Vector4(0.62, 0.06, 0.46, w), Vector4(0.0, 0.03, 0.0, 0.0))
	_box("Column", Vector4(0.34, 0.9, 0.26, w * 0.9), Vector4(0.0, 0.51, -0.02, 0.0))
	var top := _box("Top", Vector4(0.7, 0.05, 0.46, w * 0.95), Vector4(0.0, 1.0, 0.02, 0.0))
	top.basis = Basis4D.from_yz(deg_to_rad(-24.0))
	_strip = MeshInstance4D.new()
	_strip.name = "Strip"
	_strip.mesh = Mats.box_mesh(Vector4(0.66, 0.018, 0.02, w * 0.9))
	_strip.position = Vector4(0.0, 0.93, 0.235, 0.0)
	_strip.basis = Basis4D.from_yz(deg_to_rad(-24.0))
	_strip.set_meta(GENERATED, true)
	add_child(_strip)
	var body := StaticBody4D.new()
	body.name = "Body"
	body.set_meta(GENERATED, true)
	var shape := CollisionShape4D.new()
	var b := BoxShape4D.new()
	b.size = Vector4(0.62, 1.0, 0.46, w)
	shape.shape = b
	shape.position = Vector4(0.0, 0.5, 0.0, 0.0)
	body.add_child(shape)
	add_child(body)
	apply_mood(mood)


func _box(nm: String, sz: Vector4, at: Vector4) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(sz)
	m.position = at
	m.set_meta(GENERATED, true)
	add_child(m)
	_parts.append([m, sz])
	return m


func apply_mood(m: String, _instant: bool = false) -> void:
	mood = m
	for p in _parts:
		(p[0] as MeshInstance4D).material_override = Mats.surface(Style.surface("lectern", mood), p[1], 1.0)
	if _strip != null:
		var c: Color = Style.code(part + "_fill", mood) if part != "neutral" else Color(0.85, 0.88, 0.92)
		_strip.material_override = Mats.glow(c, 1.0)


func set_step(s: Resource, is_done: bool) -> void:
	step = s
	done = is_done


# -- the card ------------------------------------------------------------------------------------

func draw_overlay(canvas: Control, overlay: Node) -> void:
	if step == null or not is_visible_in_tree():
		return
	var anchor: Vector4 = global_position + Vector4(0.0, 1.35, 0.0, 0.0)
	var s = overlay.to_screen(anchor)
	if s == null:
		return
	var cam: Camera4D = overlay.get("camera")
	var dist: float = (cam.global_position - anchor).length() if cam != null else 5.0
	if dist > visible_within:
		return
	var fade: float = float(overlay.slice_fade(global_position + Vector4(0.0, 1.0, 0.0, 0.0)))
	fade *= clampf((visible_within - dist) / 3.0, 0.0, 1.0)
	if fade <= 0.01:
		return
	var vp: Vector2 = canvas.get_viewport_rect().size
	var ui: float = clampf(vp.y / 1080.0, 0.7, 2.2)
	var k: float = clampf(full_within / maxf(dist, 0.5), 0.62, 1.0) * ui
	var width: float = 380.0 * k
	var pad: float = 16.0 * k
	var inner: float = width - pad * 2.0
	var f_title: Font = Style.font("SemiBold")
	var f_body: Font = Style.font("Regular")
	var f_label: Font = Style.font("Bold")
	var fs_kick: int = int(Style.size(Style.MICRO) * k)
	var fs_title: int = int(Style.size(Style.SUBTITLE) * k)
	var fs_body: int = int(Style.size(Style.CAPTION) * k)
	var text: Color = Color(Style.ui("text", mood), fade)
	var dim: Color = Color(Style.ui("text_dim", mood), fade)
	var faint: Color = Color(Style.ui("text_faint", mood), fade)
	var accent: Color = Style.code(String(step.get("part")), mood) if String(step.get("part")) in ["build", "motion"] else Style.ui("text_dim", mood)
	accent.a = fade
	# Lay the card out first, to know its height.
	var rows: Array = []
	rows.append(["kick", String(step.get("code")) + "   " + String(step.get("part")).to_upper()])
	rows.append(["title", String(step.get("title"))])
	if not done:
		# Compact until the task is done: the guide panel already says the idea, and a big card
		# here would sit over the exhibit's neighbours.
		rows.append(["hint", "The full card opens when the task is done."])
	else:
		var any: bool = false
		for pair in [["METHOD", "method"], ["SHOWS", "shows"], ["LIMITS", "limits"], ["MEASURED", "measured"]]:
			var t: String = String(step.get(pair[1]))
			if not t.is_empty():
				rows.append(["label", pair[0]])
				rows.append(["body", t])
				any = true
		# The evidence tier qualifies MEASURED, so it only shows beside a measurement.
		if not String(step.get("measured")).is_empty():
			rows.append(["tier", String(step.get("tier"))])
		elif not any:
			rows.append(["body", String(step.get("idea"))])
	if not metrics.is_empty():
		rows.append(["label", "LIVE"])
		for m in metrics:
			rows.append(["metric", "%s   %s" % [String(m[0]), String(m[1])]])
	var h: float = pad
	var heights: Array = []
	for r in rows:
		var rh: float = 0.0
		match r[0]:
			"kick": rh = fs_kick * 1.5
			"title": rh = f_title.get_multiline_string_size(r[1], HORIZONTAL_ALIGNMENT_LEFT, inner, fs_title).y + 4.0 * k
			"label": rh = fs_kick * 1.7
			"body", "hint": rh = f_body.get_multiline_string_size(r[1], HORIZONTAL_ALIGNMENT_LEFT, inner, fs_body).y + 2.0 * k
			"tier", "metric": rh = fs_kick * 1.6
		heights.append(rh)
		h += rh
	h += pad
	var pos: Vector2 = (s as Vector2) - Vector2(width * 0.5, h + 10.0 * k)
	pos.x = clampf(pos.x, 8.0, vp.x - width - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - h - 8.0)
	var box: StyleBoxFlat = Style.panel_box(mood, k)
	box.bg_color.a *= fade
	box.border_color.a *= fade
	box.shadow_color.a *= fade
	canvas.draw_style_box(box, Rect2(pos, Vector2(width, h)))
	canvas.draw_rect(Rect2(pos + Vector2(pad, -3.0 * k), Vector2(34.0 * k, 3.0 * k)), accent)
	var y: float = pos.y + pad
	for i in rows.size():
		var r: Array = rows[i]
		var x: float = pos.x + pad
		match r[0]:
			"kick":
				canvas.draw_string(f_label, Vector2(x, y + fs_kick), r[1], HORIZONTAL_ALIGNMENT_LEFT, inner, fs_kick, accent)
			"title":
				canvas.draw_multiline_string(f_title, Vector2(x, y + fs_title), r[1], HORIZONTAL_ALIGNMENT_LEFT, inner, fs_title, -1, text)
			"label":
				canvas.draw_string(f_label, Vector2(x, y + fs_kick * 1.3), r[1], HORIZONTAL_ALIGNMENT_LEFT, inner, fs_kick, faint)
			"body":
				canvas.draw_multiline_string(f_body, Vector2(x, y + fs_body), r[1], HORIZONTAL_ALIGNMENT_LEFT, inner, fs_body, -1, dim)
			"hint":
				canvas.draw_multiline_string(f_body, Vector2(x, y + fs_body), r[1], HORIZONTAL_ALIGNMENT_LEFT, inner, fs_body, -1, faint)
			"tier":
				canvas.draw_string(f_body, Vector2(x, y + fs_kick * 1.2), r[1], HORIZONTAL_ALIGNMENT_LEFT, inner, fs_kick, faint)
			"metric":
				canvas.draw_string(f_title, Vector2(x, y + fs_kick * 1.2), r[1], HORIZONTAL_ALIGNMENT_LEFT, inner, fs_kick, dim)
		y += float(heights[i])
	# A thin leader from the card down to the lectern.
	canvas.draw_line(Vector2((s as Vector2).x, pos.y + h), s as Vector2, Color(accent, 0.6 * fade), 1.2 * k, true)
