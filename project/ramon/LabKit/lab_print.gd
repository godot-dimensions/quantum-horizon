@tool
extends RefCounted

## Prints: text, key caps, numbers and floor marks drawn once into a texture, for
## LabKit/lab_grid.gd to paint onto a wall or a floor (`LabGrid.set_print`). This is the case
## study's "text is paint" (follow_up/lab_case_study/): Unreal's intro level prints its lessons
## straight onto its grid walls at a fixed size, and that is what reads, where a card that grows
## as you come near jitters and reflows (Ramon's review of the gallery, 4 Oct).
##
##   var tex: Texture2D = await LabPrint.render(get_tree(), Vector2i(1280, 720), func(c: Control) -> void:
##       LabPrint.block(c, Vector2(40, 40), 1200.0, [["01/02", "bold", 60], ["BUILD", "black", 180]]))
##
## RENDERED ONCE through a SubViewport, read back, mipmapped, and freed: a sign seen across a
## room is sampled small, and without mipmaps its letters shimmer.
##
## THE PICTURE IS PREMULTIPLIED: text drawn over a clear background carries its colour already
## multiplied by its coverage, so the grid shader paints it as `surface * (1 - a) + ink`. Painting
## it the straight way would put a dark fringe round every letter.
##
## NO class_name (engine_gotchas.md): preload it.

const FONTS := {
	"black": "res://ramon/Demo/fonts/Montserrat/static/Montserrat-ExtraBold.ttf",
	"bold": "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Bold.ttf",
	"body": "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf",
	"light": "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Medium.ttf",
}

static var _fonts: Dictionary = {}


class Canvas extends Control:
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = FONTS.get(kind, FONTS["body"])
	var f: Font = load(path) as Font
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f


## Renders `paint(canvas)` into a picture `size` pixels big and returns it as a mipmapped
## texture. Await it: the picture is drawn on the next frames.
static func render(tree: SceneTree, size: Vector2i, paint: Callable) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var c := Canvas.new()
	c.size = Vector2(size)
	c.paint = paint
	vp.add_child(c)
	tree.root.add_child.call_deferred(vp)
	await tree.process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Draws text items top to bottom from `origin`, wrapped at `width` pixels, and returns the height
## used. Each item is [text, font kind, size in px] with optional [3] colour, [4] gap after in px,
## [5] alignment (HORIZONTAL_ALIGNMENT_*).
static func block(c: Control, origin: Vector2, width: float, items: Array) -> float:
	var y: float = origin.y
	for item in items:
		var text: String = String(item[0])
		var f: Font = font(String(item[1]))
		var px: int = int(item[2])
		var col: Color = item[3] if item.size() > 3 else Color.WHITE
		var gap: float = float(item[4]) if item.size() > 4 else px * 0.45
		var align: int = int(item[5]) if item.size() > 5 else HORIZONTAL_ALIGNMENT_LEFT
		if text.is_empty():
			y += gap
			continue
		var sz: Vector2 = f.get_multiline_string_size(text, align, width, px)
		c.draw_multiline_string(f, Vector2(origin.x, y + f.get_ascent(px)), text, align, width, px, -1, col)
		y += sz.y + gap
	return y - origin.y


## The height `block()` would use for `items` at `width`, without drawing.
static func measure(width: float, items: Array) -> float:
	var y: float = 0.0
	for item in items:
		var text: String = String(item[0])
		var f: Font = font(String(item[1]))
		var px: int = int(item[2])
		var gap: float = float(item[4]) if item.size() > 4 else px * 0.45
		var align: int = int(item[5]) if item.size() > 5 else HORIZONTAL_ALIGNMENT_LEFT
		if text.is_empty():
			y += gap
			continue
		y += f.get_multiline_string_size(text, align, width, px).y + gap
	return y


## `block()`, scaled down as a whole (sizes and gaps together) until it fits `height`.
static func block_fit(c: Control, origin: Vector2, width: float, height: float, items: Array) -> float:
	var scaled: Array = items
	for attempt in 12:
		if measure(width, scaled) <= height:
			break
		var shrunk: Array = []
		for item in scaled:
			var it: Array = (item as Array).duplicate()
			it[2] = maxi(4, int(float(it[2]) * 0.92))
			if it.size() > 4:
				it[4] = float(it[4]) * 0.92
			shrunk.append(it)
		scaled = shrunk
	return block(c, origin, width, scaled)


## A key cap like the ones standing on Unreal's first wall: a light rounded block with a dark
## edge below, the key's letter in it.
static func keycap(c: Control, rect: Rect2, label: String, px: int, face: Color = Color(0.96, 0.96, 0.95), ink: Color = Color(0.12, 0.12, 0.13)) -> void:
	var r: float = rect.size.y * 0.14
	var lip := Rect2(rect.position + Vector2(0.0, rect.size.y * 0.09), rect.size)
	_round_rect(c, lip, r, Color(0.20, 0.21, 0.23))
	_round_rect(c, rect, r, face)
	var f: Font = font("bold")
	var sz: Vector2 = f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, px)
	c.draw_string(f, Vector2(rect.position.x, rect.get_center().y + f.get_ascent(px) * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, px, ink)
	if sz.x <= 0.0:
		pass


## A filled rounded rectangle.
static func _round_rect(c: Control, rect: Rect2, r: float, col: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = col
	box.set_corner_radius_all(int(r))
	box.anti_aliasing = true
	c.draw_style_box(box, rect)


## A ring (outline circle) `thick` pixels wide.
static func ring(c: Control, centre: Vector2, radius: float, thick: float, col: Color) -> void:
	c.draw_arc(centre, radius - thick * 0.5, 0.0, TAU, 128, col, thick, true)
