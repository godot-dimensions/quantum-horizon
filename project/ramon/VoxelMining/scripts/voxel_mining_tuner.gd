extends CanvasLayer
## In-game tuner for a voxel mining block: pick a parameter, nudge it with the
## arrow keys or type an exact number, and watch the rock rebuild.
##
## WHY THIS EXISTS RATHER THAN JUST USING THE INSPECTOR. Every one of these
## values is already an `@export`, so the editor can set them - but the thing
## being tuned is how the rock feels to *mine*, and mining only happens in Play.
## Alt-tabbing to the inspector between attempts loses the state you were judging
## and, for grid_size in particular, loses the sense of how much slower the last
## change made it. So this reads its starting values off whatever the scene
## authored (nothing is duplicated here) and edits the live node in place.
##
## The panel also earns its keep as a guard rail. Two things about this system
## are easy to get wrong and hard to diagnose from the result:
##
##   1. grid_size and box_fill_fraction can silently overshoot the grid, which
##      renders as ragged holes in the rock that look exactly like inverted
##      normals. [method _overshoot_warning] states the inequality and shows the
##      largest fill fraction the current grid can take.
##   2. Cut quality is not really "bite radius in metres", it is bite radius in
##      GRID CELLS - the same 0.48 m bite is a smooth bowl at cell_size 0.2 and a
##      single chipped voxel at 0.5. The panel shows the derived cell count next
##      to the metres so the number you are actually tuning is on screen.
##
## Raw keycodes rather than input actions throughout, following return_button.gd:
## project.godot is shared with everyone, and a debug panel has no business
## adding actions to it.

## The block to tune. Anything exposing the properties in [constant PARAMETERS]
## works - rows whose property the node does not have are simply skipped, so this
## also runs against a plain VoxelMiningBlock (it just loses the crust row).
@export var block_path: NodePath = ^"../RockBlock"

@export_group("Keys")
@export var toggle_key: Key = KEY_F1
@export var previous_key: Key = KEY_UP
@export var next_key: Key = KEY_DOWN
@export var decrease_key: Key = KEY_LEFT
@export var increase_key: Key = KEY_RIGHT
## Rebuilds the rock from scratch, discarding every cut made so far.
@export var reset_key: Key = KEY_G

@export_group("Style")
@export var font: Font = null
@export_range(8, 40, 1, "suffix:px") var font_size: int = 15
@export var panel_color: Color = Color(0.04, 0.05, 0.07, 0.82)
@export var text_color: Color = Color(0.86, 0.87, 0.9, 1.0)
@export var dim_color: Color = Color(0.55, 0.57, 0.62, 1.0)
@export var highlight_color: Color = Color(0.97, 0.72, 0.32, 1.0)
@export var warning_color: Color = Color(0.95, 0.45, 0.35, 1.0)
@export var margin: Vector2 = Vector2(24.0, 24.0)

## One row each. `rebuild` marks the values that change the FIELD rather than
## just how it is drawn or cut - those have to go through generate(), which
## starts the rock over. The rest apply live and keep whatever has been mined.
const PARAMETERS: Array[Dictionary] = [
	{"property": &"grid_size", "label": "Grid size", "min": 4.0, "max": 16.0, "step": 1.0, "integer": true, "rebuild": true},
	{"property": &"cell_size", "label": "Cell size", "min": 0.05, "max": 1.5, "step": 0.02, "rebuild": true, "suffix": " m"},
	{"property": &"box_fill_fraction", "label": "Fill fraction", "min": 0.1, "max": 0.9, "step": 0.01, "rebuild": true},
	{"property": &"mining_radius_meters", "label": "Bite radius", "min": 0.05, "max": 2.0, "step": 0.02, "rebuild": false, "suffix": " m"},
	{"property": &"bite_shape", "label": "Bite shape", "min": 0.0, "max": 1.0, "step": 1.0, "integer": true, "rebuild": false, "names": ["Round", "Boxy"]},
	{"property": &"crust_metres", "label": "Crust depth", "min": 0.05, "max": 2.0, "step": 0.05, "rebuild": false, "suffix": " m"},
]

## The margin dual contouring needs between the shape's outer surface and the
## grid boundary. Below it, cells past the edge cannot be built and the rock
## renders with open faces. Measured while building the first blocks; see
## project/ramon/follow_up/voxel_port.md.
const GRID_EDGE_MARGIN := 1.1

var _block: Node4D = null
var _rows: Array[Dictionary] = []
var _selected: int = 0
## Digits typed since the last Enter. Empty means "not typing".
var _typed: String = ""
var _last_rebuild_msec: float = 0.0

var _name_labels: Array[Label] = []
var _value_labels: Array[Label] = []
var _note_labels: Array[Label] = []
var _panel: PanelContainer = null
var _stats_label: Label = null
var _warning_label: Label = null


func _ready() -> void:
	_block = get_node_or_null(block_path) as Node4D
	if _block == null:
		push_warning("VoxelMiningTuner: no block at %s - the panel will not appear." % block_path)
		return
	_rows = _available_rows()
	_build_ui()
	_refresh()


## Skips any row whose property the target node does not actually declare, so
## pointing this at a different block subclass degrades to the rows that do
## apply instead of erroring on the first get().
func _available_rows() -> Array[Dictionary]:
	var present := {}
	for entry in _block.get_property_list():
		present[StringName(entry["name"])] = true
	var rows: Array[Dictionary] = []
	for parameter in PARAMETERS:
		if present.has(parameter["property"]):
			rows.append(parameter)
	return rows


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = margin
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	_panel.add_child(column)

	column.add_child(_make_label("VOXEL TUNER    %s hide" % OS.get_keycode_string(toggle_key), dim_color))

	# A GridContainer rather than padded text: the project has no monospace font,
	# so columns built out of spaces would not line up at any font size.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 2)
	column.add_child(grid)

	for row in _rows:
		var name_label := _make_label("", text_color)
		var value_label := _make_label("", text_color)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size = Vector2(90.0, 0.0)
		var note_label := _make_label("", dim_color)
		grid.add_child(name_label)
		grid.add_child(value_label)
		grid.add_child(note_label)
		_name_labels.append(name_label)
		_value_labels.append(value_label)
		_note_labels.append(note_label)

	column.add_child(HSeparator.new())
	_stats_label = _make_label("", dim_color)
	column.add_child(_stats_label)
	_warning_label = _make_label("", warning_color)
	column.add_child(_warning_label)
	column.add_child(_make_label(
		"%s/%s pick    %s/%s adjust (Shift x10)    type a number + Enter    %s reset rock" % [
			OS.get_keycode_string(previous_key), OS.get_keycode_string(next_key),
			OS.get_keycode_string(decrease_key), OS.get_keycode_string(increase_key),
			OS.get_keycode_string(reset_key)],
		dim_color))


func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", font_size)
	if font != null:
		label.add_theme_font_override(&"font", font)
	return label


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _block == null or _panel == null:
		return

	if key.keycode == toggle_key:
		_panel.visible = not _panel.visible
		_typed = ""
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if not _panel.visible or _rows.is_empty():
		return

	if key.keycode == previous_key:
		_selected = posmod(_selected - 1, _rows.size())
		_typed = ""
	elif key.keycode == next_key:
		_selected = posmod(_selected + 1, _rows.size())
		_typed = ""
	elif key.keycode == decrease_key:
		_nudge(-1.0, key.shift_pressed)
	elif key.keycode == increase_key:
		_nudge(1.0, key.shift_pressed)
	elif key.keycode == reset_key:
		_regenerate()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_commit_typed()
	elif key.keycode == KEY_BACKSPACE:
		_typed = _typed.substr(0, maxi(_typed.length() - 1, 0))
	elif _is_number_character(key.unicode):
		_typed += String.chr(key.unicode)
	else:
		return

	_refresh()
	get_viewport().set_input_as_handled()


func _is_number_character(unicode: int) -> bool:
	return (unicode >= 48 and unicode <= 57) or unicode == 46 # 0-9 and '.'


func _nudge(direction: float, coarse: bool) -> void:
	var row: Dictionary = _rows[_selected]
	var step: float = float(row["step"]) * (10.0 if coarse else 1.0)
	_apply(row, float(_block.get(row["property"])) + direction * step)


func _commit_typed() -> void:
	if _typed.is_empty():
		return
	if _typed.is_valid_float():
		_apply(_rows[_selected], _typed.to_float())
	_typed = ""


## Clamps into the row's range, writes it, and rebuilds only when the row says
## the change touches the field. Anything else is either picked up by the
## property's own setter (crust depth remeshes itself) or only matters at the
## next swing (bite radius), so forcing a generate() there would throw away the
## mining you are in the middle of judging.
func _apply(row: Dictionary, value: float) -> void:
	var clamped := clampf(value, float(row["min"]), float(row["max"]))
	if row.get("integer", false):
		_block.set(row["property"], int(roundf(clamped)))
	else:
		_block.set(row["property"], clamped)
	if row.get("rebuild", false):
		_regenerate()


func _regenerate() -> void:
	var started_usec := Time.get_ticks_usec()
	_block.generate()
	_last_rebuild_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0


func _refresh() -> void:
	if _panel == null or not _panel.visible:
		return
	for index in range(_rows.size()):
		var row: Dictionary = _rows[index]
		var selected := index == _selected
		_name_labels[index].text = ("> " if selected else "   ") + str(row["label"])
		_name_labels[index].add_theme_color_override(&"font_color", highlight_color if selected else text_color)
		if selected and not _typed.is_empty():
			_value_labels[index].text = _typed + "_"
		else:
			_value_labels[index].text = _format_value(row)
		_value_labels[index].add_theme_color_override(&"font_color", highlight_color if selected else text_color)
		_note_labels[index].text = _note_for(row)
	_stats_label.text = _stats_text()
	var warning := _overshoot_warning()
	_warning_label.text = warning
	_warning_label.visible = not warning.is_empty()


func _format_value(row: Dictionary) -> String:
	var value: float = float(_block.get(row["property"]))
	var suffix: String = str(row.get("suffix", ""))
	if row.has("names"):
		var names: Array = row["names"]
		return str(names[clampi(int(value), 0, names.size() - 1)])
	if row.get("integer", false):
		return "%d%s" % [int(value), suffix]
	return "%.2f%s" % [value, suffix]


## True when bites are round, tolerating a block that has no bite_shape at all
## (a plain VoxelMiningBlock is always round).
func _bite_is_round() -> bool:
	var shape: Variant = _block.get(&"bite_shape")
	return shape == null or int(shape) == 0


## The derived numbers that actually explain what a row does. Metres mean
## nothing here on their own - everything this system does is measured in grid
## cells, and the cell is itself one of the things being tuned.
func _note_for(row: Dictionary) -> String:
	var grid_size := int(_block.grid_size)
	var cell_size := float(_block.cell_size)
	match row["property"]:
		&"grid_size":
			# The cost multiplier is stated up front because it is the one value
			# here that can lock the game up for seconds on a single keypress:
			# every remesh sweeps the whole field, so it is O(grid_size^4).
			# Measured on this machine: 180 ms a swing at 8, 6.4 SECONDS at 16.
			return "%d^4 = %s field points, %.1fx the cost of grid 8" % [
				grid_size, _thousands(int(pow(grid_size, 4))), pow(float(grid_size) / 8.0, 4.0)]
		&"cell_size":
			return "one voxel, %.2f m across" % cell_size
		&"box_fill_fraction":
			return "rock %.2f m across" % (float(grid_size) * cell_size * float(_block.box_fill_fraction))
		&"mining_radius_meters":
			# The ridge warning is the whole reason this row shows cells at all.
			# A round bite only removes a diagonal neighbour once its radius
			# passes sqrt(2) cells; below that, two craters landing diagonally
			# leave a one-cell wall of rock standing between them.
			var radius_cells: float = float(_block.mining_radius_meters) / maxf(cell_size, 0.001)
			var text := "bite is %.1f cells wide" % (radius_cells * 2.0)
			if _bite_is_round() and radius_cells <= sqrt(2.0):
				text += "  - under root 2, leaves diagonal ridges"
			return text
		&"bite_shape":
			if _bite_is_round():
				return "sphere; needs radius over %.2f m here to clear diagonals" % (sqrt(2.0) * cell_size)
			return "cube; clears the whole 3^4 neighbourhood at any radius"
		&"crust_metres":
			return "%.1f voxels of grey shell" % (float(_block.crust_metres) / maxf(cell_size, 0.001))
	return ""


func _stats_text() -> String:
	var voxels: Node = _block.get_node_or_null("Voxels")
	var collider_count: int = voxels.get_child_count() if voxels != null else 0
	return "rebuild %.0f ms    last remesh %.0f ms    %s colliders" % [
		_last_rebuild_msec, float(_block.get(&"last_remesh_msec")), _thousands(collider_count)]


## Empty when the current grid_size/box_fill_fraction pair is safe.
##
## The shape's outer surface sits at grid_size * 0.5 * (1 + fill) and needs to
## stay [constant GRID_EDGE_MARGIN] inside the grid's last index. Cross that and
## dual contouring cannot build the cells past the boundary, leaving faces you
## can see straight through - which reads as a normals bug, not as a grid one,
## and has cost real time before.
func _overshoot_warning() -> String:
	var grid_size := float(_block.grid_size)
	var reach := grid_size * 0.5 * (1.0 + float(_block.box_fill_fraction))
	if reach <= grid_size - GRID_EDGE_MARGIN:
		return ""
	return "OVERSHOOT: rock reaches the grid edge, expect open faces. Max fill at grid %d is %.2f." % [
		int(grid_size), 1.0 - 2.0 * GRID_EDGE_MARGIN / grid_size]


func _thousands(value: int) -> String:
	var digits := str(value)
	var out := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			out += ","
		out += digits[index]
	return out
