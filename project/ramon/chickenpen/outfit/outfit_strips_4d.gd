extends Node4D

## THE BASIC CHOICES, AS A BODY DIAGRAM. Six slim strips of colour tiles standing beside you in the
## fitting circle, one at the height of each thing they change: HAT over your head, then HAIR, SKIN,
## SHIRT, TROUSERS, and SHOES at your boots, each with a thin line back to the part it dresses. The
## circle's scan prints them: as its ring of light passes a part, that part's strip unfolds out of the
## ring (outfit_circle_4d.gd calls set_print). A callout diagram, the research lab's own language: each
## choice sits next to what it changes.
##
## ON YOUR LEFT AS YOU LOOK AT YOURSELF (Ramon, 8 Oct: "place the colors on the left side. its against
## hud overlap"): the pen's controls card and dial sit on the right of the screen.
##
## ARROW KEYS ONLY (Ramon: "arrows probably enough"): up and down pick the strip, left and right the
## colour. A floating card of the four keys hangs over the strips, and under the last strip there is one
## more stop, ADVANCED, which takes you to Trym's fitting room (the styles, the hats and the jokes, with
## room for all of it). Both are drawn flat over the screen where their spot in the room projects, by
## drawing calls at the screen's own size, as the lab kit's prompts are (kit/kit_prompt.gd), so they
## stay sharp at any size.
##
## THEY ARE 4D THINGS, standing in the world: boxes with a real thickness through W, like the arch's
## field, so turning the slice while you dress does not make them blink out.
##
## A CAROUSEL, NOT THE WHOLE PALETTE. Five tiles show: the chosen one raised in the middle with a cyan
## rim (marked by its shape, not by its colour alone), two either side, each on a light mat so a dark
## colour still reads as a tile.
##
## Built facing the mirror when the scan starts (+Z toward it, +X to its right), then left where it is.

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")
const KitStyle := preload("res://ramon/CreationLab/kit/kit_style.gd")

## Strip heights over the plate, top to bottom, the rows of Outfit.ROWS.
const HEIGHTS := [1.68, 1.42, 1.16, 0.90, 0.56, 0.24]
## Where each strip's line points: the part it dresses, as (x, height) on the figure facing the camera,
## on the figure's side the strips are on.
const ANCHORS := [Vector2(0.15, 1.52), Vector2(0.15, 1.33), Vector2(0.14, 1.22), Vector2(0.18, 0.88),
	Vector2(0.10, 0.50), Vector2(0.10, 0.06)]
## Where a strip starts, out past the frame's rim (0.8) so the front post never crosses it.
const INNER_X := 0.92
const LENGTH := 0.74
const TILE := 0.12
const SPACING := 0.14
const SHOWN := 5
const MAT := Color(0.78, 0.82, 0.88)
## The stop under the last strip: Trym's fitting room.
const ADVANCED := 6
## Which side of you the strips stand on: -1 the camera's left.
const SIDE := -1.0

var frame_color: Color = Color(0.16, 0.19, 0.27)
var edge_color: Color = Color(0.32, 0.86, 1.0)
var w_depth: float = 0.5
var camera: Camera4D
## Where the words go: a Control on the pen's UI layer (outfit_circle_4d.gd finds it).
var ui: Control
var text_color: Color = Color(1.0, 0.95, 0.74)
var font: Font
var text_size: int = 22

var active_row: int = 3

var _rows: Array[Dictionary] = []
var _seen_rev: int = -1
var _seen_row: int = -1
var _overlay: Control


## Draws the arrow keys and the ADVANCED stop for the strips that own it.
class Overlay extends Control:
	var strips: Node

	func _draw() -> void:
		if strips != null and is_instance_valid(strips):
			strips.call("draw_overlay", self)


func _ready() -> void:
	for i in Outfit.ROWS.size():
		_rows.append(_build_row(i))
	if ui != null:
		_overlay = Overlay.new()
		_overlay.name = "OutfitKeys"
		_overlay.strips = self
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(_overlay)
	_refresh()


## How far row [param row]'s strip has printed: 0 nothing, 1 whole.
func set_print(row: int, amount: float) -> void:
	if row < 0 or row >= _rows.size():
		return
	var r: Dictionary = _rows[row]
	if absf(float(r["print"]) - amount) < 0.0005:
		return
	r["print"] = clampf(amount, 0.0, 1.0)
	_lay_out(row)


func get_print(row: int) -> float:
	return float(_rows[row]["print"]) if row >= 0 and row < _rows.size() else 0.0


func set_all(amount: float) -> void:
	for i in _rows.size():
		set_print(i, amount)


func _process(_delta: float) -> void:
	if _seen_rev != Outfit.changes() or _seen_row != active_row:
		_refresh()
	_place_labels()
	if _overlay != null:
		_overlay.queue_redraw()


func _exit_tree() -> void:
	for r in _rows:
		var label: Label = r.get("label")
		if label != null and is_instance_valid(label):
			label.queue_free()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()


# --- Building --------------------------------------------------------------------------------------

func _build_row(i: int) -> Dictionary:
	var root := Node4D.new()
	root.name = "Row%d" % i
	add_child(root)
	root.position = Vector4(0.0, HEIGHTS[i], 0.0, 0.0)
	var r: Dictionary = {"root": root, "print": 0.0}
	r["panel"] = _box(root, "Panel", frame_color)
	r["edge"] = _box(root, "Edge", edge_color)
	r["leader"] = _box(root, "Leader", edge_color)
	r["rim"] = _box(root, "Rim", edge_color)
	var tiles: Array[MeshInstance4D] = []
	var mats: Array[MeshInstance4D] = []
	for t in SHOWN:
		tiles.append(_box(root, "Tile%d" % t, Color.WHITE))
		mats.append(_box(root, "Mat%d" % t, MAT))
	r["tiles"] = tiles
	r["mats"] = mats
	if ui != null:
		var label := Label.new()
		label.name = "OutfitRow%d" % i
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if font != null:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", text_size)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.visible = false
		ui.add_child(label)
		r["label"] = label
	_lay_out_into(r, i)
	return r


func _box(parent: Node, part: String, colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = BoxTetraMesh4D.new()
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	# The dev look leaves the circle's tech as it is, as it does Trym's arch (look/pen_look_4d.gd OWN).
	node.set_meta(&"_look_own", true)
	parent.add_child(node)
	node.visible = false
	return node


# --- Laying out ------------------------------------------------------------------------------------

func _lay_out(row: int) -> void:
	_lay_out_into(_rows[row], row)


## Where every piece of a strip is at its current print: the line draws out from the part first, then
## the panel unrolls from the ring outward, then the tiles pop in one by one. Everything is laid out on
## the +X side and mirrored by SIDE.
func _lay_out_into(r: Dictionary, row: int) -> void:
	var p: float = float(r["print"])
	var lift: float = 0.05 if row == active_row else 0.0
	var anchor: Vector2 = ANCHORS[row]
	var from := Vector2(anchor.x * SIDE, anchor.y - HEIGHTS[row])
	var to := Vector2(INNER_X * SIDE, 0.0)
	var line: float = clampf(p / 0.35, 0.0, 1.0)
	var leader := r["leader"] as MeshInstance4D
	var span: Vector2 = (to - from) * line
	leader.visible = line > 0.01
	if leader.visible:
		(leader.mesh as BoxTetraMesh4D).size = Vector4(span.length(), 0.012, 0.012, w_depth * 0.6)
		leader.basis = Basis4D.from_xy(span.angle())
		var mid: Vector2 = from + span * 0.5
		leader.position = Vector4(mid.x, mid.y, lift * 0.5, 0.0)
	var unroll: float = clampf((p - 0.2) / 0.5, 0.0, 1.0)
	var panel := r["panel"] as MeshInstance4D
	var edge := r["edge"] as MeshInstance4D
	panel.visible = unroll > 0.01
	edge.visible = panel.visible
	if panel.visible:
		var length: float = LENGTH * unroll
		(panel.mesh as BoxTetraMesh4D).size = Vector4(length, 0.17, 0.02, w_depth)
		panel.position = Vector4((INNER_X + length * 0.5) * SIDE, 0.0, lift, 0.0)
		(edge.mesh as BoxTetraMesh4D).size = Vector4(length, 0.014, 0.03, w_depth)
		edge.position = Vector4((INNER_X + length * 0.5) * SIDE, -0.092, lift, 0.0)
	var centre_x: float = (INNER_X + LENGTH * 0.5) * SIDE
	var tiles: Array = r["tiles"]
	for t in tiles.size():
		var tile := tiles[t] as MeshInstance4D
		var pop: float = clampf((p - 0.5 - absf(t - 2) * 0.08) / 0.2, 0.0, 1.0)
		tile.visible = pop > 0.01
		var chosen: bool = t == 2
		var side: float = (TILE * 1.25 if chosen else TILE) * pop
		(tile.mesh as BoxTetraMesh4D).size = Vector4(side, side, 0.03, w_depth * 0.8)
		# Left to right on screen, the palette in its order: the earlier colours to the left.
		tile.position = Vector4(centre_x + (t - 2) * SPACING, 0.0, lift + (0.05 if chosen else 0.022), 0.0)
	var mats: Array = r["mats"]
	for t in mats.size():
		var mat := mats[t] as MeshInstance4D
		var tile := tiles[t] as MeshInstance4D
		mat.visible = tile.visible and t != 2
		var size: float = (tile.mesh as BoxTetraMesh4D).size.x + 0.018
		(mat.mesh as BoxTetraMesh4D).size = Vector4(size, size, 0.02, w_depth * 0.8)
		mat.position = tile.position - Vector4(0.0, 0.0, 0.012, 0.0)
	var rim := r["rim"] as MeshInstance4D
	var rim_pop: float = clampf((p - 0.5) / 0.2, 0.0, 1.0)
	rim.visible = rim_pop > 0.01
	(rim.mesh as BoxTetraMesh4D).size = Vector4((TILE * 1.25 + 0.04) * rim_pop, (TILE * 1.25 + 0.04) * rim_pop, 0.02, w_depth * 0.8)
	rim.position = Vector4(centre_x, 0.0, lift + 0.025, 0.0)


## The tiles' colours and the labels' words, from the outfit; and the active row lifted toward you.
func _refresh() -> void:
	_seen_rev = Outfit.changes()
	_seen_row = active_row
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var key: String = Outfit.ROWS[i][1]
		var list: Array = Outfit.options(key)
		var at: int = Outfit.get_value(key)
		# A hat with nothing to paint (none, or the chicken) shows its colours greyed.
		var muted: bool = i == 0 and not Outfit.hat_takes_colour()
		var tiles: Array = r["tiles"]
		for t in tiles.size():
			var colour: Color = list[posmod(at + t - 2, list.size())]
			if at == Outfit.CUSTOM:
				# Your own colour (the fitting room's wheel) in the middle, the palette's ends either side
				# of it, where the arrows step to (outfit_4d.gd step).
				colour = Outfit.colour(key) if t == 2 else list[posmod(t - (2 if t < 2 else 3), list.size())]
			if muted:
				colour = colour.lerp(Color(0.45, 0.47, 0.5), 0.7)
			((tiles[t] as MeshInstance4D).material_override as TetraMaterial4D).albedo_color = colour
		var on: bool = i == active_row
		((r["panel"] as MeshInstance4D).material_override as TetraMaterial4D).albedo_color = \
			frame_color.lerp(edge_color, 0.22) if on else frame_color
		((r["edge"] as MeshInstance4D).material_override as TetraMaterial4D).albedo_color = \
			edge_color if on else edge_color.lerp(frame_color, 0.55)
		((r["leader"] as MeshInstance4D).material_override as TetraMaterial4D).albedo_color = \
			edge_color if on else edge_color.lerp(frame_color, 0.5)
		_lay_out_into(r, i)
		var label: Label = r.get("label")
		if label != null:
			label.text = _words(i)
			label.modulate = Color(1, 1, 1, 1.0) if on else Color(1, 1, 1, 0.62)
			label.add_theme_color_override("font_color", edge_color.lerp(Color.WHITE, 0.35) if on else text_color)


## What row [param i]'s label says: the part, then the colour ("SHIRT   Teal"). The basic choices
## are colours; the hat's style is shown, as it is what the colour goes on.
func _words(i: int) -> String:
	var row: Array = Outfit.ROWS[i]
	var colour_name: String = Outfit.name_of(row[1], Outfit.get_value(row[1]))
	if i == 0:
		var hat: String = Outfit.name_of("hat", Outfit.hat())
		return "%s   %s" % [row[0], hat if not Outfit.hat_takes_colour() else "%s, %s" % [hat, colour_name]]
	return "%s   %s" % [row[0], colour_name]


## A spot in the strips' frame, on screen in the UI's own units; and whether it is in front of the
## camera at all.
func _on_screen(local: Vector2) -> Array:
	var at: Vector4 = global_position + global_basis * Vector4(local.x, local.y, 0.0, 0.0)
	if camera == null or ui == null:
		return [false, Vector2.ZERO]
	var forward: Vector4 = -camera.global_basis.z
	if forward.dot(at - camera.global_position) <= 0.05:
		return [false, Vector2.ZERO]
	var to_canvas: Vector2 = ui.get_viewport_rect().size / Vector2(ui.get_viewport().get_size())
	return [true, camera.world_to_viewport(at) * to_canvas]


## Each label at its strip's outer end, its right edge there (the strips are on your left), where that
## projects on screen; hidden while its strip is still printing.
func _place_labels() -> void:
	if camera == null or ui == null:
		return
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var label: Label = r.get("label")
		if label == null:
			continue
		var p: float = float(r["print"])
		var spot: Array = _on_screen(Vector2((INNER_X + LENGTH + 0.06) * SIDE, HEIGHTS[i]))
		if p < 0.6 or not bool(spot[0]):
			label.visible = false
			continue
		label.visible = true
		label.self_modulate.a = clampf((p - 0.6) / 0.3, 0.0, 1.0)
		label.size = label.get_combined_minimum_size()
		var point: Vector2 = spot[1]
		label.position = Vector2(maxf(point.x - label.size.x, 12.0), point.y - label.size.y * 0.5)


# --- The keys card and the ADVANCED stop (drawn) ---------------------------------------------------

## The four arrow keys over the strips, and the ADVANCED stop under the last one: dark glass pills and
## light key caps, sized from the screen's height as the lab kit's prompts are (u is the height over
## 720), so they are drawn at the size they show and stay sharp.
func draw_overlay(c: Control) -> void:
	var u: float = c.size.y / 720.0
	var heading: Font = KitStyle.ui_font("heading")
	var text_font: Font = KitStyle.ui_font("text")
	var px: int = KitStyle.type_px("body", u) + int(2.0 * u)

	# THE KEYS, over the hat's strip, as soon as it has printed.
	var top: float = get_print(0)
	var spot: Array = _on_screen(Vector2((INNER_X + LENGTH * 0.5) * SIDE, HEIGHTS[0] + 0.30))
	if top > 0.6 and bool(spot[0]):
		var a: float = clampf((top - 0.6) / 0.3, 0.0, 1.0)
		var cap: float = 26.0 * u
		var gap: float = 5.0 * u
		var words := ["part", "colour"]
		var word_w: float = 0.0
		for w in words:
			word_w = maxf(word_w, text_font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
		var cluster := Vector2(cap * 3.0 + gap * 2.0, cap * 2.0 + gap)
		var pad: float = 10.0 * u
		var box_size := Vector2(cluster.x + 14.0 * u + word_w + pad * 2.0, cluster.y + pad * 2.0)
		var box := Rect2(spot[1] - Vector2(box_size.x * 0.5, box_size.y), box_size)
		var glass: StyleBoxFlat = KitStyle.glass_box(8.0 * u, a)
		c.draw_style_box(glass, box)
		var o: Vector2 = box.position + Vector2(pad, pad)
		_key(c, Rect2(o + Vector2(cap + gap, 0.0), Vector2(cap, cap)), Vector2(0, -1), a)
		_key(c, Rect2(o + Vector2(0.0, cap + gap), Vector2(cap, cap)), Vector2(-1, 0), a)
		_key(c, Rect2(o + Vector2(cap + gap, cap + gap), Vector2(cap, cap)), Vector2(0, 1), a)
		_key(c, Rect2(o + Vector2((cap + gap) * 2.0, cap + gap), Vector2(cap, cap)), Vector2(1, 0), a)
		var tx: float = o.x + cluster.x + 14.0 * u
		var ascent: float = text_font.get_ascent(px)
		c.draw_string(text_font, Vector2(tx, o.y + cap * 0.5 + ascent * 0.36), "part", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(KitStyle.UI_INK_SOFT, a))
		c.draw_string(text_font, Vector2(tx, o.y + cap + gap + cap * 0.5 + ascent * 0.36), "colour", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(KitStyle.UI_INK_SOFT, a))

	# ADVANCED, under the shoes' strip, as soon as that has printed: a stop the arrows reach like any
	# strip, lit in the lab's code blue when it is the one chosen.
	var last: float = get_print(Outfit.ROWS.size() - 1)
	var under: Array = _on_screen(Vector2((INNER_X + LENGTH * 0.5) * SIDE, HEIGHTS[5] - 0.2))
	if last > 0.6 and bool(under[0]):
		var a2: float = clampf((last - 0.6) / 0.3, 0.0, 1.0)
		var on: bool = active_row == ADVANCED
		var label: String = "ADVANCED"
		var hint: String = "Enter"
		var lpx: int = KitStyle.type_px("lead", u)
		var hpx: int = KitStyle.type_px("caption", u) + int(2.0 * u)
		var lw: float = heading.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
		var hw: float = heading.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hpx).x
		var pad_x: float = 16.0 * u
		var pill_size := Vector2(pad_x * 2.0 + lw + (12.0 * u + hw + 14.0 * u if on else 0.0), 40.0 * u)
		var pill := Rect2(under[1] - Vector2(pill_size.x * 0.5, 0.0), pill_size)
		var sb: StyleBoxFlat = KitStyle.glass_box(pill_size.y * 0.5, a2)
		if on:
			sb.bg_color = Color(KitStyle.CODE_BLUE["bright"], a2)
			sb.border_color = Color(1, 1, 1, 0.6 * a2)
			sb.set_border_width_all(maxi(1, int(2.0 * u)))
		c.draw_style_box(sb, pill)
		var base: float = pill.position.y + pill_size.y * 0.5 + heading.get_ascent(lpx) * 0.36
		c.draw_string(heading, Vector2(pill.position.x + pad_x, base), label, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx,
			Color(1, 1, 1, a2 * (1.0 if on else 0.7)))
		if on:
			var kx: float = pill.position.x + pad_x + lw + 12.0 * u
			var key_rect := Rect2(Vector2(kx, pill.position.y + 8.0 * u), Vector2(hw + 14.0 * u, pill_size.y - 16.0 * u))
			var kb := StyleBoxFlat.new()
			kb.bg_color = Color(1, 1, 1, 0.92 * a2)
			kb.set_corner_radius_all(int(4.0 * u))
			kb.anti_aliasing = true
			c.draw_style_box(kb, key_rect)
			c.draw_string(heading, Vector2(key_rect.position.x + 7.0 * u, key_rect.get_center().y + heading.get_ascent(hpx) * 0.36), hint,
				HORIZONTAL_ALIGNMENT_LEFT, -1, hpx, Color(KitStyle.UI_GLASS, a2))


## A light key cap with an arrow on it pointing [param dir].
func _key(c: Control, r: Rect2, dir: Vector2, a: float) -> void:
	var kb := StyleBoxFlat.new()
	kb.bg_color = Color(1, 1, 1, 0.92 * a)
	kb.set_corner_radius_all(int(r.size.y * 0.18))
	kb.anti_aliasing = true
	c.draw_style_box(kb, r)
	var centre: Vector2 = r.get_center()
	var s: float = r.size.y * 0.22
	var side := Vector2(-dir.y, dir.x)
	var tip: Vector2 = centre + dir * s
	var back: Vector2 = centre - dir * s * 0.8
	c.draw_colored_polygon(PackedVector2Array([tip, back + side * s, back - side * s]), Color(KitStyle.UI_GLASS, a))
