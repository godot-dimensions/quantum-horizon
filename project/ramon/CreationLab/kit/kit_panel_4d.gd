@tool
extends Node4D

## Kit: a screen, mounted on a wall or floating, facing the node's +Z (turn the node to aim it).
##
##   kind "wslice"    W-SLICE: a track of nine stops and a marker that follows the showcase's slice
##   kind "sections"  CROSS-SECTIONS: nine cells, one per slice, sketching how big the exhibit's
##                    cross-section is at each (round in the middle of its W reach, small at the
##                    ends), the current one framed
##
## `showcase` points at the KitShowcase it reads (kit_showcase_4d.gd).
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/CreationLab/scripts/chamber_build.gd")
const RD := preload("res://ramon/CreationLab/scripts/rd_build.gd")
const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Batch := preload("res://ramon/LabKit/lab_batch.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const SLICES := 9
const PPM := 160.0

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export_enum("wslice", "sections") var kind: String = "wslice":
	set(v):
		kind = v
		_later()
@export var size: Vector2 = Vector2(3.2, 1.3):
	set(v):
		size = v
		_later()
@export var showcase: NodePath
## The way its face looks, in the world (x, z): the node turns itself to it.
@export var face: Vector3 = Vector3(0, 0, 1):
	set(v):
		face = v
		_turn()

var _box: MeshInstance4D
var _marker: MeshInstance4D
var _prints: Array = []
var _shown: int = -1
var _queued: bool = false


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func _turn() -> void:
	var f := Vector2(face.x, face.z)
	if f.length() < 0.001:
		return
	# A basis whose +Z is `face`, upright: a turn about Y.
	basis = Basis4D.from_zx(atan2(f.x, f.y))


func rebuild() -> void:
	_turn()
	Build.clear(self)
	_prints = []
	_shown = -1
	_box = Build.box(self, "Screen", Vector3.ZERO, Vector3(size.x, size.y, 0.06), "kit_screen" if kind == "wslice" else "kit_screen2", false)
	_marker = MeshInstance4D.new()
	_marker.name = "Marker"
	if kind == "wslice":
		_marker.mesh = Mats.box_mesh(Vector4(0.1, 0.24, 0.04, 0.4))
	else:
		var cell: Vector2 = _cell_size()
		var b := Batch.new()
		var t: float = 0.025
		b.box("m", Vector4(cell.x, t, t, 0.4), Vector4(0, cell.y * 0.5, 0, 0))
		b.box("m", Vector4(cell.x, t, t, 0.4), Vector4(0, -cell.y * 0.5, 0, 0))
		b.box("m", Vector4(t, cell.y, t, 0.4), Vector4(cell.x * 0.5, 0, 0, 0))
		b.box("m", Vector4(t, cell.y, t, 0.4), Vector4(-cell.x * 0.5, 0, 0, 0))
		var mi: MeshInstance4D = b.instance("m")
		_marker.mesh = mi.mesh
		mi.free()
	_marker.set_meta(Build.GENERATED, true)
	add_child(_marker)
	_apply_mood_now()
	var tree: SceneTree = get_tree()
	if tree != null:
		_prints.append(await RD.print_box(tree, _box, Vector4(0, 0, 1, 0), size, _paint, {"bright": 0.7, "dark": 0.85}))
		_apply_mood_now()


func _px(m: float) -> int:
	return int(round(m * PPM))


## The cells' grid for "sections": three by three under the title.
func _cell_size() -> Vector2:
	var area := Vector2(size.x - 0.4, size.y - 0.75)
	return Vector2(area.x / 3.0 - 0.08, area.y / 3.0 - 0.08)


func _cell_centre(i: int) -> Vector2:
	var cell: Vector2 = _cell_size()
	var col: int = i % 3
	var row: int = i / 3
	var x: float = -size.x * 0.5 + 0.2 + (cell.x + 0.08) * (float(col) + 0.5)
	var y: float = size.y * 0.5 - 0.62 - (cell.y + 0.08) * (float(row) + 0.5)
	return Vector2(x, y)


func _paint(c: Control, ink: Dictionary) -> void:
	var on: Color = ink["on_accent"]
	var f: Font = LabPrint.font("black")
	var fl: Font = LabPrint.font("body")
	if kind == "wslice":
		c.draw_string(f, Vector2(_px(0.2), _px(0.38)), "W-SLICE", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(0.26), on)
		c.draw_string(fl, Vector2(_px(0.2), _px(0.62)), "Mouse wheel moves the slice. Right drag turns it.", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(0.12), Color(on, 0.78))
		var y: float = c.size.y * 0.76
		var x0: float = c.size.x * 0.12
		var x1: float = c.size.x * 0.88
		c.draw_line(Vector2(x0, y), Vector2(x1, y), Color(on, 0.55), _px(0.02), true)
		for i in SLICES:
			var x: float = lerpf(x0, x1, float(i) / float(SLICES - 1))
			c.draw_circle(Vector2(x, y), _px(0.035), Color(on, 0.8), true, -1.0, true)
		RD.icon(c, "arrow_left", Rect2(Vector2(c.size.x * 0.02, y - _px(0.15)), Vector2(_px(0.3), _px(0.3))), on)
		RD.icon(c, "arrow_right", Rect2(Vector2(c.size.x * 0.98 - _px(0.3), y - _px(0.15)), Vector2(_px(0.3), _px(0.3))), on)
		return
	c.draw_string(f, Vector2(_px(0.2), _px(0.36)), "Cross-sections", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(0.24), on)
	c.draw_string(fl, Vector2(_px(0.2), _px(0.56)), "Each slice cuts a different 3D shape from the same 4D goat.", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(0.11), Color(on, 0.78))
	var cell: Vector2 = _cell_size()
	for i in SLICES:
		var cc: Vector2 = _cell_centre(i)
		var centre := Vector2((cc.x + size.x * 0.5) * PPM, (size.y * 0.5 - cc.y) * PPM)
		c.draw_rect(Rect2(centre - cell * PPM * 0.5, cell * PPM), Color(on, 0.08))
		# How big the cut is at this slice: the goat is widest in the middle of its reach through W.
		var w: float = (float(i) - 4.0) / 4.0
		var k: float = sqrt(maxf(0.0, 1.0 - w * w * 0.92))
		var body := Vector2(cell.x * 0.62, cell.y * 0.30) * PPM * k
		c.draw_set_transform(centre, 0.0, Vector2(1.0, body.y / maxf(body.x, 1.0)))
		c.draw_circle(Vector2.ZERO, body.x * 0.5, Color(on, 0.85), true, -1.0, true)
		c.draw_set_transform(Vector2.ZERO)
		for leg in [-0.32, -0.12, 0.12, 0.32]:
			var lx: float = centre.x + body.x * leg
			c.draw_line(Vector2(lx, centre.y), Vector2(lx, centre.y + cell.y * PPM * 0.32 * k), Color(on, 0.85), maxf(1.0, _px(0.02) * k), true)
		c.draw_string(fl, centre + Vector2(-cell.x * PPM * 0.45, cell.y * PPM * 0.45), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, _px(0.08), Color(on, 0.6))


func apply_mood(_m: String, _instant: bool = false) -> void:
	_apply_mood_now()


func _apply_mood_now() -> void:
	for rec in _prints:
		RD.apply(rec, Style.mood)
	if is_instance_valid(_marker):
		_marker.material_override = Mats.glow(Color(1, 1, 1) if kind == "wslice" else Style.pick(Style.FRAME_LIT).lightened(0.3), 1.0)
	_shown = -1


func _process(_delta: float) -> void:
	var sc: Node = get_node_or_null(showcase) if not showcase.is_empty() else null
	var i: int = int(sc.get("slice_index")) if sc != null else 4
	if i == _shown or not is_instance_valid(_marker):
		return
	_shown = i
	if kind == "wslice":
		var k: float = float(i) / float(SLICES - 1)
		_marker.position = Vector4(lerpf(-size.x * 0.38, size.x * 0.38, k), size.y * (0.5 - 0.76), 0.05, 0.0)
	else:
		var cc: Vector2 = _cell_centre(i)
		_marker.position = Vector4(cc.x, cc.y, 0.05, 0.0)
