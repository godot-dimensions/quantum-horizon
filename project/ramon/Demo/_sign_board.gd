@tool
extends Control

## Editing surface for the hub's signage: every gate's sign, laid out in arc order,
## at the size it will actually occupy on screen.
##
## WHY THIS IS A 2D SCENE. The real signs are [Label3D]/[Sprite3D] nodes rewritten
## into camera-relative space every `pre_render` (see
## hub_gate_ring_4d.gd's _on_pre_render), so the editor's 4D viewport cannot draw
## them at all - which is the only reason `_build_sign_proxy` exists, and it shows a
## blank slab rather than the sign. Nothing about the 4D machinery affects whether
## a blurb fits or reads, so this takes the typography out of the 4D scene entirely
## and iterates on it where it is directly visible.
##
## WHAT IT IS ACTUALLY FOR, which is not layout. The signs are legible or not at ONE
## distance - the spawn point - and that is a question about angular size, not about
## panel proportions. A [Label3D] glyph is `font_size * pixel_size` metres tall, so
## the hub's title is 0.192 m and its blurb 0.08 m; seen from 11.3 m on a 1080-line
## viewport those are roughly 15 px and 6 px of cap height. The title reads and the
## blurb does not. Previewing at an arbitrary zoom would hide that completely, so
## the default here reproduces the on-screen pixel size instead, and [member
## magnify] exists for when you want to inspect the layout rather than judge it.
##
## The `.tres` files in gates/ stay the single source of truth - editing text is
## still typing in the inspector. This is the other half: seeing the result.

const Palette := preload("res://ramon/Demo/scripts/hub_palette.gd")

## Every [HubSignStyle4D] control, mirrored flat into THIS node's inspector.
##
## Assigning a style resource otherwise buries the typography one level down, so
## changing tracking means expanding a sub-resource inside a collapsed group -
## which is not an editing surface, it is a scavenger hunt. These proxies appear as
## ordinary properties on the board and write straight through to the resource.
##
## They are declared PROPERTY_USAGE_EDITOR and never STORAGE, so nothing is
## serialised into the scene and there is still exactly one copy of every value:
## the `.tres`. A stored copy would silently diverge the moment the resource was
## edited from anywhere else.
const STYLE_PROXIES: Array[Dictionary] = [
	{"name": "font", "type": TYPE_OBJECT, "hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Font"},
	{"name": "panel_size", "type": TYPE_VECTOR2},
	{"name": "corner_radius", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,0.5,0.01,suffix:m"},
	{"name": "panel_color", "type": TYPE_COLOR},
	{"name": "text_color", "type": TYPE_COLOR},
	{"name": "title_uppercase", "type": TYPE_BOOL},
	{"name": "title_font_size", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "8,256,1"},
	{"name": "title_pixel_size", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0005,0.02,0.0001,suffix:m"},
	{"name": "blurb_uppercase", "type": TYPE_BOOL},
	{"name": "blurb_font_size", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "8,256,1"},
	{"name": "blurb_pixel_size", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0005,0.02,0.0001,suffix:m"},
	{"name": "blurb_width_ratio", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,1.0,0.01"},
	{"name": "title_letter_spacing", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-20,40,1,suffix:px"},
	{"name": "title_word_spacing", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-20,60,1,suffix:px"},
	{"name": "blurb_letter_spacing", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-20,40,1,suffix:px"},
	{"name": "blurb_word_spacing", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-20,60,1,suffix:px"},
	{"name": "font_weight", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,900,25"},
	{"name": "embolden", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-0.5,1.0,0.01"},
	{"name": "line_spacing", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-20,40,0.5,suffix:px"},
	{"name": "outline_size", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,64,1,suffix:px"},
	{"name": "outline_color", "type": TYPE_COLOR},
]

## Prefix keeping the proxies from colliding with this node's own fallback exports
## of the same name. Godot strips it in the inspector, so they read normally.
const STYLE_PREFIX := "style_"

@export_tool_button("Rebuild board") var _rebuild_action: Callable = rebuild

## The same catalogue the ring holds. Point it at gates/*.tres in arc order.
@export var gates: Array[HubGateDef4D] = []:
	set(value):
		gates = value
		rebuild()

@export_group("Sign geometry")
## Must match [member HubGateRing4D.panel_size], or this previews a sign that does
## not exist. The ring's own default is 2.0 x 1.0 and overrides the gate's 2.4.
@export var panel_size: Vector2 = Vector2(2.0, 1.0):
	set(value):
		panel_size = value
		rebuild()

@export var title_font_size: int = 64:
	set(value):
		title_font_size = value
		rebuild()

@export var title_pixel_size: float = 0.003:
	set(value):
		title_pixel_size = value
		rebuild()

@export var blurb_font_size: int = 32:
	set(value):
		blurb_font_size = value
		rebuild()

@export var blurb_pixel_size: float = 0.0025:
	set(value):
		blurb_pixel_size = value
		rebuild()

@export var font: Font:
	set(value):
		font = value
		rebuild()

## Shared typography asset. Assign the SAME `.tres` here and on the hub's
## GateRing and this stops being an approximation of the sign - both are drawing
## from one set of numbers. Leave it empty and the exports above are used instead.
@export var sign_style: HubSignStyle4D:
	set(value):
		if sign_style != null and sign_style.changed.is_connected(_on_definition_changed):
			sign_style.changed.disconnect(_on_definition_changed)
		sign_style = value
		if sign_style != null:
			sign_style.changed.connect(_on_definition_changed)
		# The proxy controls only exist while a style is assigned, so the whole
		# property list changes shape here and the inspector has to be told.
		notify_property_list_changed()
		rebuild()

@export_group("Viewing conditions")
## Distance the sign is judged from. The hub's is the arc radius, which
## [member HubGateRing4D.auto_radius] now solves for rather than fixing - 11.35 m
## at five gates over a 60 degree arc.
@export_range(1.0, 60.0, 0.05, "suffix:m") var viewing_distance: float = 11.35:
	set(value):
		viewing_distance = value
		rebuild()

## Vertical resolution the hub is played at. Angular size alone does not say
## whether text resolves - pixels do.
@export_range(240, 4320, 1, "suffix:px") var viewport_height: int = 1080:
	set(value):
		viewport_height = value
		rebuild()

## Must match the scene's [Camera4D]. Together with the two above this fixes the
## metres-to-pixels conversion, and therefore whether this preview is honest.
@export_range(20.0, 130.0, 0.5, "suffix:°") var vertical_fov: float = 70.0:
	set(value):
		vertical_fov = value
		rebuild()

## Scales the whole board up for designing on.
##
## Defaults to 4x because at 1x this is a legibility METER, not a design surface:
## true on-screen size from the spawn is roughly 15 px of title and 6 px of blurb,
## and a 6 px dynamic font rasterises to mush. That mush is an honest answer to
## "will players read this" and a useless one for laying a sign out.
##
## Drop it to 1.0 for the honest check. The caption says which mode you are in, so
## a magnified board can never be mistaken for a legible one.
@export_range(1.0, 12.0, 0.1, "suffix:x") var magnify: float = 4.0:
	set(value):
		magnify = value
		rebuild()

@export_group("Board")
## Signs per row. One row runs off a 1920-wide viewport as soon as [member
## magnify] is above about 1.5, and the whole point of magnifying is to read them,
## so they wrap instead. Arc order still runs left to right, then down.
@export_range(1, 8, 1) var columns: int = 2:
	set(value):
		columns = value
		rebuild()

@export_range(0, 120, 1, "suffix:px") var gap: int = 24:
	set(value):
		gap = value
		rebuild()

## Corner rounding, in METRES of sign rather than pixels, so it survives
## [member magnify] and describes the sign rather than this preview's zoom.
##
## PREVIEW ONLY until the real panel can carry it. In game the sign is a
## [QuadMesh] with a flat [StandardMaterial3D] - a hard-edged rectangle with no
## way to round it, because rounding needs alpha and the panel has no texture to
## carry one. Anything above 0 here is therefore a proposal, not a preview.
@export_range(0.0, 0.5, 0.01, "suffix:m") var corner_radius: float = 0.08:
	set(value):
		corner_radius = value
		rebuild()

## Draws each sign's cap heights and the wrap box, so a blurb that overflows is
## visible as overflow rather than as slightly odd spacing.
@export var show_metrics: bool = true:
	set(value):
		show_metrics = value
		rebuild()


func _ready() -> void:
	rebuild()


## Adds the flat typography controls, but only once a style is actually assigned -
## editing fields that write nowhere would be worse than not showing them.
func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if sign_style == null:
		return list
	list.append({
		"name": "Typography (edits sign_style)",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
		"hint_string": STYLE_PREFIX,
	})
	for proxy in STYLE_PROXIES:
		var entry: Dictionary = proxy.duplicate()
		entry["name"] = STYLE_PREFIX + String(proxy["name"])
		# EDITOR without STORAGE: shown, never written into the .tscn.
		entry["usage"] = PROPERTY_USAGE_EDITOR
		list.append(entry)
	return list


func _get(property: StringName):
	var name := String(property)
	if sign_style != null and name.begins_with(STYLE_PREFIX):
		return sign_style.get(name.substr(STYLE_PREFIX.length()))
	return null


func _set(property: StringName, value) -> bool:
	var name := String(property)
	if sign_style != null and name.begins_with(STYLE_PREFIX):
		sign_style.set(name.substr(STYLE_PREFIX.length()), value)
		# The resource emits `changed`, which _on_definition_changed already
		# listens for - so the board redraws without rebuilding here as well.
		return true
	return false


## Hides this node's own font exports once a style is assigned, since from that
## point they are dead values that look editable. Two sets of the same controls,
## one of which silently does nothing, is exactly the confusion to avoid.
func _validate_property(property: Dictionary) -> void:
	if sign_style == null:
		return
	if property.name in [
		&"font", &"panel_size", &"corner_radius", &"title_font_size", &"title_pixel_size", &"blurb_font_size", &"blurb_pixel_size"
	]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Redraw when any gate definition is edited. Separate from [method rebuild] so the
## connection can be tested for with `is_connected` and never doubled up.
func _on_definition_changed() -> void:
	rebuild()


## Mirrors HubGate4D._effective_style exactly: the assigned asset, or one built
## from this board's own exports. If these two ever disagree the preview is lying,
## so they are deliberately the same three lines.
func _effective_style() -> HubSignStyle4D:
	if sign_style != null:
		return sign_style
	var fallback := HubSignStyle4D.new()
	fallback.font = font
	fallback.panel_size = panel_size
	fallback.corner_radius = corner_radius
	fallback.title_font_size = title_font_size
	fallback.title_pixel_size = title_pixel_size
	fallback.blurb_font_size = blurb_font_size
	fallback.blurb_pixel_size = blurb_pixel_size
	return fallback


## Pixels one metre of sign occupies on screen at the configured viewing distance.
##
## Small-angle is NOT assumed: a 2.4 m panel at 11 m is wide enough that
## `2*atan(h/2d)` and `h/d` differ, and this is the number the whole scene's honesty
## rests on. Vertical is used because a viewport's FOV is specified vertically.
func pixels_per_metre() -> float:
	var fov := deg_to_rad(vertical_fov)
	if fov <= 0.0 or viewing_distance <= 0.0:
		return 100.0
	var subtended := 2.0 * atan(1.0 / (2.0 * viewing_distance))
	return float(viewport_height) * (subtended / fov) * magnify


func rebuild() -> void:
	if not is_inside_tree():
		return
	# A @tool script that gains exports while its scene is open keeps the node's
	# OLD property table until the scene is reloaded, so the new ones read as Nil -
	# see project/ramon/follow_up/engine_gotchas.md. Reading them blind emitted 128
	# identical GridContainer errors and left the board blank with no clue why.
	# One actionable warning is worth more than a wall of symptoms.
	if typeof(gates) != TYPE_ARRAY or typeof(columns) != TYPE_INT or typeof(gap) != TYPE_INT:
		push_warning("SignBoard: exports are not initialised - reload the scene (Scene > Reload Saved Scene).")
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if gates.is_empty():
		return

	# Live editing: a [Resource] emits `changed` whenever one of its properties is
	# set, so typing a new blurb into a gate .tres in the Inspector redraws the
	# board as you type. Without this the strings live in files the board only ever
	# reads, and every edit costs a trip to the Rebuild button.
	for definition in gates:
		if definition != null and not definition.changed.is_connected(_on_definition_changed):
			definition.changed.connect(_on_definition_changed)

	var ppm := pixels_per_metre()

	# Whole board scrolls, so nothing is ever unreachable at high magnification.
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var column := VBoxContainer.new()
	column.name = "Board"
	column.add_theme_constant_override("separation", gap)
	scroll.add_child(column)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = (
		"%d signs at %.2f m, %d-line viewport, %.0f° FOV%s\n%.1f px per metre  |  title cap %.1f px  |  blurb cap %.1f px"
		% [
			gates.size(), viewing_distance, viewport_height, vertical_fov,
			"" if is_equal_approx(magnify, 1.0) else "  (MAGNIFIED %.1fx - not legibility-honest)" % magnify,
			ppm,
			_effective_style().title_font_size * _effective_style().title_pixel_size * ppm,
			_effective_style().blurb_font_size * _effective_style().blurb_pixel_size * ppm,
		]
	)
	column.add_child(caption)

	var grid := GridContainer.new()
	grid.name = "Signs"
	# GridContainer hard-errors below 1, and a scrambled property table can hand us
	# a zero as easily as a Nil.
	grid.columns = maxi(1, columns)
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	column.add_child(grid)

	for definition in gates:
		if definition == null:
			continue
		grid.add_child(_build_sign(definition, ppm))


## Reproduces one billboard's layout from hub_gate_4d.gd's _build_billboard, in 2D.
##
## The offsets are that function's, converted from panel-centre metres to top-left
## pixels: icon cell is 55% of panel height, inset 0.12 m; text starts one cell plus
## 0.24 m in when there is an icon and 0.14 m in when there is not; title and blurb
## sit +/-19% of panel height either side of centre. Kept numerically identical on
## purpose - a preview that lays out its own way is worse than none.
func _build_sign(definition: HubGateDef4D, ppm: float) -> Control:
	var style := _effective_style()
	var width := style.panel_size.x * ppm
	var height := style.panel_size.y * ppm

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = style.get_panel_color()
	var radius_px: int = roundi(style.corner_radius * ppm)
	panel_style.corner_radius_top_left = radius_px
	panel_style.corner_radius_top_right = radius_px
	panel_style.corner_radius_bottom_left = radius_px
	panel_style.corner_radius_bottom_right = radius_px
	# Enough segments that the curve does not visibly facet when magnified.
	panel_style.corner_detail = 12

	var panel := Panel.new()
	panel.name = definition.gate_name.validate_node_name()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.custom_minimum_size = Vector2(width, height)
	panel.size = Vector2(width, height)

	var text_colour := style.get_text_color()
	var icon_cell := style.panel_size.y * 0.55
	var text_left := 0.14

	if definition.icon != null:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = definition.icon
		icon.modulate = text_colour
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(icon_cell * ppm, icon_cell * ppm)
		icon.position = Vector2(0.12 * ppm, (style.panel_size.y - icon_cell) * 0.5 * ppm)
		panel.add_child(icon)
		text_left = icon_cell + 0.24

	# Font pixels to screen pixels. Tracking, outline and line spacing are all
	# specified in font pixels, so they only stay proportional if they scale by the
	# same factor the glyphs do.
	var title_scale: float = style.title_pixel_size * ppm

	var title := Label.new()
	title.name = "Title"
	title.text = style.apply_title_case(definition.gate_name)
	title.add_theme_color_override("font_color", text_colour)
	title.add_theme_font_size_override("font_size", maxi(1, roundi(style.title_font_size * title_scale)))
	var title_font := style.make_title_font(title_scale)
	if title_font != null:
		title.add_theme_font_override("font", title_font)
	if style.outline_size > 0:
		title.add_theme_constant_override("outline_size", maxi(1, roundi(style.outline_size * title_scale)))
		title.add_theme_color_override("font_outline_color", style.outline_color)
	title.add_theme_constant_override("line_spacing", roundi(style.line_spacing * title_scale))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Label3D places its ORIGIN at the offset and centres the glyphs on it, so the
	# 2D box is half a line higher to put the baseline in the same place.
	var title_cap: float = style.title_font_size * title_scale
	title.position = Vector2(text_left * ppm, (style.panel_size.y * 0.5 - style.panel_size.y * 0.19) * ppm - title_cap * 0.5)
	title.size = Vector2(width - text_left * ppm, title_cap * 1.4)
	panel.add_child(title)

	if not definition.blurb.is_empty():
		var wrap_metres: float = maxf(0.1, (style.panel_size.x - text_left) * style.blurb_width_ratio)
		var blurb_scale: float = style.blurb_pixel_size * ppm
		var blurb := Label.new()
		blurb.name = "Blurb"
		blurb.text = style.apply_blurb_case(definition.blurb)
		blurb.add_theme_color_override("font_color", text_colour)
		blurb.add_theme_font_size_override("font_size", maxi(1, roundi(style.blurb_font_size * blurb_scale)))
		var blurb_font := style.make_blurb_font(blurb_scale)
		if blurb_font != null:
			blurb.add_theme_font_override("font", blurb_font)
		if style.outline_size > 0:
			blurb.add_theme_constant_override("outline_size", maxi(1, roundi(style.outline_size * blurb_scale)))
			blurb.add_theme_color_override("font_outline_color", style.outline_color)
		blurb.add_theme_constant_override("line_spacing", roundi(style.line_spacing * blurb_scale))
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var blurb_cap: float = style.blurb_font_size * blurb_scale
		blurb.position = Vector2(text_left * ppm, (style.panel_size.y * 0.5 + style.panel_size.y * 0.19) * ppm - blurb_cap * 0.5)
		blurb.size = Vector2(wrap_metres * ppm, blurb_cap * 3.0)
		panel.add_child(blurb)

		if show_metrics:
			var box := ReferenceRect.new()
			box.name = "WrapBox"
			box.border_color = Color(1.0, 1.0, 1.0, 0.35)
			box.editor_only = false
			box.position = blurb.position
			box.size = blurb.size
			panel.add_child(box)

	return panel
