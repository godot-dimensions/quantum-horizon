extends Node4D
## Slice Garden: a sign painted on the floor: key caps and a few words, in the lab's code blue on its
## grid (white ink vanished in the spotlight's pool on the pale floor, 6 Oct)
## (PLAN.md step 50; Ramon: "or just use some icons on the playing field"). Unreal's intro level
## stands its keys beside the thing they work (RESEARCH.md, and follow_up/lab_case_study); here they
## lie on the ground where you need them, so nothing floats and nothing scales with distance.
##
## `lines` is a list of lines, each a list of pieces:
##   ["key", "E"]        a key cap
##   ["mouse", "right"]  a mouse with its right (or "left") button lit
##   ["text", "lift"]    words
##   ["dots", 2, "warm"] W-cue dots: how many lanes to go, warm for ana, cool for kata
##   ["title", "..."], ["lead", "..."], ["body", "..."], ["small", "..."]
##                       panel type, after the lab's wall panels (a line's height follows its
##                       largest piece, so a title line is taller than a body line)
## `align` "center" or "left" (a panel, as the lab's walls are set). `ink` is the paint: the lab's code
## blue on the grey floors, white on the blue platform (Ramon, 6 Oct: "a blue platform with the white
## icons and explainer").
## It is drawn once into a picture (a SubViewport, then a mipmapped copy, so it stays sharp and does
## not shimmer at a distance) and painted on a thin box with shaders/mk_decal.gdshader.
##
## `size` is the sign's extent on the floor (x, z) in metres; `depth_w` how deep in W it is (one lane:
## it belongs to that world).
##
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/MiegakureLook/Remake/world/mk_materials.gd")
const DecalShader := preload("res://ramon/MiegakureLook/Remake/shaders/mk_decal.gdshader")
const FONT_BOLD := "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Bold.ttf"
const FONT_BLACK := "res://ramon/Demo/fonts/Montserrat/static/Montserrat-ExtraBold.ttf"
const PX_PER_M := 220.0
## The lab kit's code blue (CreationLab/kit/kit_style.gd CODE_BLUE, a shade deeper for the floor).
const INK := Color(0.09, 0.31, 0.80)
const WHITE_INK := Color(1, 1, 1)
## Each piece's size, relative to a key cap.
const SCALE := {"key": 1.0, "mouse": 1.0, "dots": 1.0, "text": 1.0, "title": 1.9, "lead": 0.95, "body": 0.72, "small": 0.62}
const WARM := Color(1.0, 0.64, 0.25)
const COOL := Color(0.45, 0.62, 1.0)

var lines: Array = []
var size: Vector2 = Vector2(3.0, 1.0)
var depth_w: float = 1.6
var ink: Color = Color(0.09, 0.31, 0.80)
var align: String = "center"
## Set by the sign itself to the paint colour while drawing.
var _paint_ink: Color = Color.WHITE

var _mesh: MeshInstance4D
var _material: TetraMaterial4D


func _ready() -> void:
	_mesh = MeshInstance4D.new()
	_mesh.name = "Paint"
	var box_size := Vector4(size.x, 0.02, size.y, depth_w)
	_mesh.mesh = Mats.box_mesh(box_size)
	_material = TetraMaterial4D.new()
	var cs: ShaderMaterial = _material.get_cross_section_material_3d()
	cs.shader = DecalShader
	_material.albedo_color = Color.WHITE
	cs.set_shader_parameter("surface_size", box_size)
	cs.set_shader_parameter("ink", Color.WHITE)
	_paint_ink = ink
	_mesh.material_override = _material
	_mesh.position = Vector4(0, 0.012, 0, 0)
	_mesh.visible = false
	add_child(_mesh)
	_paint()


func _paint() -> void:
	var px := Vector2i(int(size.x * PX_PER_M), int(size.y * PX_PER_M))
	var vp := SubViewport.new()
	vp.size = px
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var canvas := Control.new()
	canvas.size = Vector2(px)
	vp.add_child(canvas)
	var bold: Font = load(FONT_BOLD)
	var black: Font = load(FONT_BLACK)
	canvas.draw.connect(func() -> void: _draw_sign(canvas, Vector2(px), bold, black))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = vp.get_texture().get_image()
	if image != null and not image.is_empty():
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		_material.get_cross_section_material_3d().set_shader_parameter("sign_texture", ImageTexture.create_from_image(image))
		_mesh.visible = true
	vp.queue_free()


## Lays the lines out, each as tall as its largest piece, centred or left-aligned.
func _draw_sign(c: Control, px: Vector2, bold: Font, black: Font) -> void:
	if lines.is_empty():
		return
	var weights: Array = []
	var total_weight: float = 0.0
	for line in lines:
		var w: float = 0.4
		for p in line:
			w = maxf(w, float(SCALE.get(String(p[0]), 1.0)))
		weights.append(w)
		total_weight += w
	var base: float = px.y / maxf(total_weight, 0.01)
	var unit: float = minf(base * 0.78, 120.0)
	# Shrink to fit the widest line in 92% of the width (a sign never spills off its own floor).
	for li in lines.size():
		var total_w: float = 0.0
		for p in lines[li]:
			total_w += _piece_width(p, unit, bold) + unit * 0.3
		if total_w > px.x * 0.92:
			unit *= px.x * 0.92 / total_w
	var y: float = 0.0
	for li in lines.size():
		var pieces: Array = lines[li]
		var line_h: float = base * float(weights[li])
		var widths: Array = []
		var total: float = 0.0
		for p in pieces:
			var w: float = _piece_width(p, unit, bold)
			widths.append(w)
			total += w
		total += unit * 0.3 * float(pieces.size() - 1)
		var x: float = (px.x - total) * 0.5 if align == "center" else px.x * 0.04
		var cy: float = y + line_h * 0.5
		for i in pieces.size():
			_draw_piece(c, pieces[i], Vector2(x, cy), unit, bold, black)
			x += float(widths[i]) + unit * 0.3
		y += line_h


func _piece_width(p: Array, unit: float, bold: Font) -> float:
	var kind: String = String(p[0])
	if kind in ["title", "lead", "body", "small"]:
		var f: Font = load(FONT_BLACK) if kind == "title" else bold
		return f.get_string_size(String(p[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(unit * 0.62 * float(SCALE[kind]))).x
	match kind:
		"key":
			return maxf(unit * 0.95, bold.get_string_size(String(p[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(unit * 0.5)).x + unit * 0.45)
		"mouse":
			return unit * 0.7
		"dots":
			return unit * 0.42 * float(int(p[1]))
		_:
			return bold.get_string_size(String(p[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(unit * 0.62)).x


func _draw_piece(c: Control, p: Array, at: Vector2, unit: float, bold: Font, black: Font) -> void:
	var ink_c: Color = _paint_ink
	var kind: String = String(p[0])
	if kind in ["title", "lead", "body", "small"]:
		var size: int = int(unit * 0.62 * float(SCALE[kind]))
		var col: Color = ink_c
		if kind == "small" or kind == "body":
			col = ink_c.lerp(Color(0.85, 0.9, 1.0) if ink_c.get_luminance() > 0.5 else ink_c, 0.15)
		c.draw_string(black if kind == "title" else bold, Vector2(at.x, at.y + size * 0.36), String(p[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		return
	match kind:
		"key":
			var label: String = String(p[1])
			var w: float = _piece_width(p, unit, bold)
			var r := Rect2(Vector2(at.x, at.y - unit * 0.48), Vector2(w, unit * 0.96))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = ink_c
			sb.set_border_width_all(int(maxf(unit * 0.07, 3.0)))
			sb.set_corner_radius_all(int(unit * 0.16))
			sb.draw(c.get_canvas_item(), r)
			c.draw_string(black, Vector2(at.x, at.y + unit * 0.19), label, HORIZONTAL_ALIGNMENT_CENTER, w, int(unit * 0.5), ink_c)
		"mouse":
			var w2: float = unit * 0.7
			var body := Rect2(Vector2(at.x, at.y - unit * 0.5), Vector2(w2, unit))
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = Color(0, 0, 0, 0)
			sb2.border_color = ink_c
			sb2.set_border_width_all(int(maxf(unit * 0.07, 3.0)))
			sb2.set_corner_radius_all(int(w2 * 0.5))
			sb2.draw(c.get_canvas_item(), body)
			var right: bool = String(p[1]) == "right"
			var half := Rect2(Vector2(at.x + (w2 * 0.5 if right else 0.0) + unit * 0.07, at.y - unit * 0.43), Vector2(w2 * 0.5 - unit * 0.14, unit * 0.36))
			c.draw_rect(half, WARM if right else ink_c)
			c.draw_line(Vector2(at.x + w2 * 0.5, at.y - unit * 0.5), Vector2(at.x + w2 * 0.5, at.y - unit * 0.07), ink_c, maxf(unit * 0.05, 2.0))
		"dots":
			var n: int = int(p[1])
			var col: Color = WARM if String(p[2]) == "warm" else COOL
			for i in n:
				c.draw_circle(Vector2(at.x + unit * 0.21 + unit * 0.42 * float(i), at.y), unit * 0.14, col)
		_:
			c.draw_string(bold, Vector2(at.x, at.y + unit * 0.22), String(p[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(unit * 0.62), ink_c)
