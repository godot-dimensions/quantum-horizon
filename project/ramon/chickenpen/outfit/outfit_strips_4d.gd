extends Node4D

## THE CHOICES, AS A BODY DIAGRAM. Six slim strips of colour tiles standing beside you in the fitting
## circle, one at the height of each thing they change: HAT over your head, then HAIR, SKIN, SHIRT,
## TROUSERS, and SHOES at your boots, each with a thin line back to the part it dresses. The circle's
## scan prints them: as its ring of light passes a part, that part's strip unfolds out of the ring
## (outfit_circle_4d.gd calls set_print). The way a callout diagram labels a figure, which is the
## research lab's own language, and the reason the choices read without a menu: each one sits next to
## what it changes.
##
## THEY ARE 4D THINGS, standing in the world: boxes with a real thickness through W, like the arch's
## field, so turning the slice while you dress does not make them blink out. The words are not: text
## is drawn flat over the screen where a strip's end projects, as the world tags are
## (dialogue/world_tag_4d.gd), so it stays readable at any angle and any UI size.
##
## A CAROUSEL, NOT THE WHOLE PALETTE. Five tiles show: the chosen one raised in the middle with a cyan
## rim (the research's rule: mark the choice by its shape, not by its colour alone), two either side.
## Left and right turn the carousel, so a palette of thirteen never makes a strip too long to read.
##
## Built facing the camera when the scan starts (+Z toward it, +X to its right), and then left where it
## is: the mouse can still orbit round you and the strips stay standing in the world.

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")

## Strip heights over the plate, top to bottom, the rows of Outfit.ROWS.
const HEIGHTS := [1.68, 1.42, 1.16, 0.90, 0.56, 0.24]
## Where each strip's line points: the part it dresses, as (x, height) on the figure facing the camera.
const ANCHORS := [Vector2(0.15, 1.52), Vector2(0.15, 1.33), Vector2(0.14, 1.22), Vector2(0.18, 0.88),
	Vector2(0.10, 0.50), Vector2(0.10, 0.06)]
## Where a strip starts, out past the frame's rim (0.8) so the front post never crosses it.
const INNER_X := 0.92
const LENGTH := 0.74
const TILE := 0.12
const SPACING := 0.14
const SHOWN := 5
const MAT := Color(0.78, 0.82, 0.88)

var frame_color: Color = Color(0.16, 0.19, 0.27)
var edge_color: Color = Color(0.32, 0.86, 1.0)
var w_depth: float = 0.5
var camera: Camera4D
## Where the labels go: a Control on the pen's UI layer (outfit_circle_4d.gd finds it).
var ui: Control
var text_color: Color = Color(1.0, 0.95, 0.74)
var font: Font
var text_size: int = 22

var active_row: int = 3

var _rows: Array[Dictionary] = []
var _seen_rev: int = -1
var _seen_row: int = -1


func _ready() -> void:
	for i in Outfit.ROWS.size():
		_rows.append(_build_row(i))
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


## Every strip at once, for folding them all away together.
func set_all(amount: float) -> void:
	for i in _rows.size():
		set_print(i, amount)


func _process(_delta: float) -> void:
	if _seen_rev != Outfit.changes() or _seen_row != active_row:
		_refresh()
	_place_labels()


func _exit_tree() -> void:
	for r in _rows:
		var label: Label = r.get("label")
		if label != null and is_instance_valid(label):
			label.queue_free()


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
		# A light mat behind every tile, so a dark colour (charcoal on the navy panel) is still a tile.
		mats.append(_box(root, "Mat%d" % t, MAT))
	r["tiles"] = tiles
	r["mats"] = mats
	if ui != null:
		var label := Label.new()
		label.name = "OutfitRow%d" % i
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
## the panel unrolls from the ring outward, then the tiles pop in one by one.
func _lay_out_into(r: Dictionary, row: int) -> void:
	var p: float = float(r["print"])
	var lift: float = 0.05 if row == active_row else 0.0
	var anchor: Vector2 = ANCHORS[row]
	var from := Vector2(anchor.x, anchor.y - HEIGHTS[row])
	var to := Vector2(INNER_X, 0.0)
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
		panel.position = Vector4(INNER_X + length * 0.5, 0.0, lift, 0.0)
		(edge.mesh as BoxTetraMesh4D).size = Vector4(length, 0.014, 0.03, w_depth)
		edge.position = Vector4(INNER_X + length * 0.5, -0.092, lift, 0.0)
	var centre_x: float = INNER_X + LENGTH * 0.5
	var tiles: Array = r["tiles"]
	for t in tiles.size():
		var tile := tiles[t] as MeshInstance4D
		var pop: float = clampf((p - 0.5 - absf(t - 2) * 0.08) / 0.2, 0.0, 1.0)
		tile.visible = pop > 0.01
		var chosen: bool = t == 2
		var side: float = (TILE * 1.25 if chosen else TILE) * pop
		(tile.mesh as BoxTetraMesh4D).size = Vector4(side, side, 0.03, w_depth * 0.8)
		tile.position = Vector4(centre_x + (t - 2) * SPACING, 0.0, lift + (0.05 if chosen else 0.022), 0.0)
	var mats: Array = r["mats"]
	for t in mats.size():
		var mat := mats[t] as MeshInstance4D
		var tile := tiles[t] as MeshInstance4D
		mat.visible = tile.visible and t != 2
		var side: float = (tile.mesh as BoxTetraMesh4D).size.x + 0.018
		(mat.mesh as BoxTetraMesh4D).size = Vector4(side, side, 0.02, w_depth * 0.8)
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
		# A hat with nothing to paint (none, or the chicken) shows its colours greyed: still there to
		# pick for the next hat, but plainly not doing anything now.
		var muted: bool = i == 0 and not Outfit.hat_takes_colour()
		var tiles: Array = r["tiles"]
		for t in tiles.size():
			var colour: Color = list[posmod(at + t - 2, list.size())]
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


## What row [param i]'s label says: the part, then the choice ("HAT  Top hat, Red").
func _words(i: int) -> String:
	var row: Array = Outfit.ROWS[i]
	var colour_name: String = Outfit.name_of(row[1], Outfit.get_value(row[1]))
	var said: String = colour_name
	if row[2] != "":
		var style: String = Outfit.name_of(row[2], Outfit.get_value(row[2]))
		said = style if (i == 0 and not Outfit.hat_takes_colour()) else "%s, %s" % [style, colour_name]
	return "%s   %s" % [row[0], said]


## Each label at its strip's outer end, where that projects on screen; hidden while its strip is
## still printing, or when the end is behind the camera.
func _place_labels() -> void:
	if camera == null or ui == null:
		return
	var screen: Vector2 = ui.get_viewport_rect().size
	var to_canvas: Vector2 = screen / Vector2(ui.get_viewport().get_size())
	var forward: Vector4 = -camera.global_basis.z
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var label: Label = r.get("label")
		if label == null:
			continue
		var p: float = float(r["print"])
		var end: Vector4 = global_position + global_basis * Vector4(INNER_X + LENGTH + 0.06, HEIGHTS[i], 0.0, 0.0)
		if p < 0.6 or forward.dot(end - camera.global_position) <= 0.05:
			label.visible = false
			continue
		label.visible = true
		label.self_modulate.a = clampf((p - 0.6) / 0.3, 0.0, 1.0)
		label.size = label.get_combined_minimum_size()
		var point: Vector2 = camera.world_to_viewport(end) * to_canvas
		# Kept on screen: in a small window the longest label would run off the right edge.
		label.position = Vector2(minf(point.x, screen.x - label.size.x - 12.0), point.y - label.size.y * 0.5)
