extends Control

## Kit: a key prompt that pops up over something in the room when you walk up to it, and goes when
## you walk away (Ramon, 4 Oct: "just you get a button that pops up when you get near, with the
## engage key stroke"). A dark pill with the key cap and what it does, held over the thing's place
## on screen (Camera4D.world_to_viewport), springing in and out.
##
##   target   the Node4D it stands over; offset, how far above (and beside) its origin, in metres
##   key      the key cap's letter; text, what the key does now
##   shown    whether it is up
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")
const RD := preload("res://ramon/PhaseMazeRemake/carried/scripts/rd_build.gd")

var camera: Camera4D
var target: Node4D
var offset: Vector4 = Vector4(0.0, 1.7, 0.0, 0.0)
var key: String = "E"
var text: String = "Check data"
var shown: bool = false
var _a: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size
	if size != want or position != Vector2.ZERO:
		position = Vector2.ZERO
		size = want
	var was: float = _a
	_a = move_toward(_a, 1.0 if shown and target != null else 0.0, delta / 0.16)
	if _a > 0.0 or was > 0.0:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.001 or camera == null or not is_instance_valid(target) or not camera.is_inside_tree():
		return
	var at: Vector4 = target.global_position + offset
	# Not when it is behind the camera.
	var ahead: Vector4 = camera.global_basis * Vector4(0, 0, -1, 0)
	if (at - camera.global_position).dot(ahead) <= 0.1:
		return
	var p: Vector2 = camera.world_to_viewport(at)
	var u: float = size.y / 720.0
	# A little spring: up past full size and back.
	var t: float = _a
	var k: float = (1.0 + 0.18 * sin(t * PI)) * ease(t, 0.5)
	var f: Font = LabPrint.font("bold")
	var px: int = Style.type_px("body", u)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var cap: float = 28.0 * u
	var pad: float = 10.0 * u
	var w: float = pad + cap + 10.0 * u + tw + pad * 1.4
	var h: float = cap + pad * 1.2
	draw_set_transform(p, 0.0, Vector2(k, k))
	var r := Rect2(Vector2(-w * 0.5, -h), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Style.UI_GLASS, Style.UI_GLASS_ALPHA * _a)
	sb.set_corner_radius_all(int(h * 0.5))
	sb.border_color = Color(Style.UI_ACCENT, 0.9 * _a)
	sb.set_border_width_all(int(maxf(1.0, 1.5 * u)))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	# A small point under it, towards the thing.
	draw_colored_polygon(PackedVector2Array([Vector2(-6.0 * u, 0.0), Vector2(6.0 * u, 0.0), Vector2(0.0, 7.0 * u)]), Color(Style.UI_GLASS, Style.UI_GLASS_ALPHA * _a))
	# The key cap.
	var kr := Rect2(Vector2(r.position.x + pad, r.position.y + (h - cap) * 0.5), Vector2(cap, cap))
	var kb := StyleBoxFlat.new()
	kb.bg_color = Color(1, 1, 1, _a)
	kb.set_corner_radius_all(int(6 * u))
	kb.anti_aliasing = true
	draw_style_box(kb, kr)
	var kf: Font = LabPrint.font("black")
	var kpx: int = Style.type_px("lead", u)
	draw_string(kf, Vector2(kr.position.x, kr.get_center().y + kf.get_ascent(kpx) * 0.36), key, HORIZONTAL_ALIGNMENT_CENTER, cap, kpx, Color(Style.UI_GLASS, _a))
	draw_string(f, Vector2(kr.end.x + 10.0 * u, r.get_center().y + f.get_ascent(px) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, _a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
