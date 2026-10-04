@tool
extends Node4D

## Kit: a data desk. A plain block with a screen on top leaning towards you, showing the exhibit's
## own measured numbers and a small chart (Ramon, 4 Oct: "a panel block you can look down at ...
## for tucking away research data in a non intrusive way"). Faces the node's +Z: stand on that side
## to read it. `showcase` points at the KitShowcase whose exhibit it measures.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/LabChambers/scripts/chamber_build.gd")
const RD := preload("res://ramon/LabChambers/scripts/rd_build.gd")
const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")
const PPM := 160.0

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var showcase: NodePath
## The way its face looks, in the world (x, z): the node turns itself to it.
@export var face: Vector3 = Vector3(0, 0, 1):
	set(v):
		face = v
		_turn()

var _top: MeshInstance4D
var _prints: Array = []
var _done: bool = false
var _t: float = 0.0


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")
	add_to_group("kit_desk")


func _ready() -> void:
	rebuild()


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
	_done = false
	Build.box(self, "Base", Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 1.0), "kit_desk")
	_top = MeshInstance4D.new()
	_top.name = "Top"
	var s := Vector4(2.7, 0.08, 1.35, 0.6)
	_top.mesh = Mats.box_mesh(s)
	_top.position = Vector4(0, 1.0, 0.05, 0)
	_top.basis = Basis4D.from_yz(0.36)
	_top.material_override = LabGrid.material("kit_screen", s, global_position if is_inside_tree() else Vector4.ZERO)
	_top.set_meta(Build.GENERATED, true)
	add_child(_top)


## Where you stand to read it, in the world.
func near(p: Vector4) -> bool:
	var l: Vector4 = p - global_position
	var front: Vector4 = global_basis * Vector4(0, 0, 1.3, 0)
	return Vector2(l.x - front.x, l.z - front.z).length() < 1.5


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _done:
		return
	_t += delta
	if _t < 0.5:
		return
	_done = true
	var tree: SceneTree = get_tree()
	var rec: Dictionary = await RD.print_box(tree, _top, Vector4(0, 1, 0, 0), Vector2(2.7, 1.35), _paint_label, {"bright": 0.75, "dark": 0.9})
	_prints.append(rec)
	RD.apply(rec, Style.mood)


func _paint_label(c: Control, ink: Dictionary) -> void:
	var on: Color = ink["on_accent"]
	c.draw_string(LabPrint.font("black"), Vector2(0.0, c.size.y * 0.5), "RESEARCH DATA", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, _px(0.2), on)
	c.draw_string(LabPrint.font("body"), Vector2(0.0, c.size.y * 0.5 + _px(0.2)), "Step up to read the goat's measurements", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, _px(0.085), Color(on, 0.8))
	for i in 8:
		var bh: float = _px(0.08 + 0.04 * float(i))
		c.draw_rect(Rect2(Vector2(c.size.x * 0.5 - _px(0.5) + _px(0.125) * float(i), c.size.y * 0.32 - bh), Vector2(_px(0.08), bh)), Color(on, 0.4 + 0.07 * float(i)))


func _px(m: float) -> int:
	return int(round(m * PPM))


func _paint(c: Control, ink: Dictionary, d: Dictionary) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	var on: Color = ink["on_accent"]
	c.draw_string(LabPrint.font("black"), Vector2(_px(0.12), _px(0.2)), String(d.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, _px(0.11), on)
	var rows: Array = d.get("rows", [])
	var bars: Array = d.get("bars", [])
	var col_w: float = w * (0.46 if not bars.is_empty() else 0.9)
	var y: float = _px(0.38)
	for r in rows:
		c.draw_string(LabPrint.font("body"), Vector2(_px(0.12), y), String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, _px(0.075), Color(on, 0.78))
		c.draw_string(LabPrint.font("bold"), Vector2(_px(0.12), y), String(r[1]), HORIZONTAL_ALIGNMENT_RIGHT, col_w - _px(0.12), _px(0.085), on)
		c.draw_line(Vector2(_px(0.12), y + _px(0.04)), Vector2(col_w, y + _px(0.04)), Color(on, 0.18), 1.0)
		y += _px(0.15)
	if not bars.is_empty():
		var x0: float = w * 0.54
		var x1: float = w - _px(0.12)
		var top: float = _px(0.36)
		var base: float = h - _px(0.22)
		var most: float = 1.0
		for b in bars:
			most = maxf(most, float(b))
		var bw: float = (x1 - x0) / float(bars.size())
		for i in bars.size():
			var bh: float = (base - top) * float(bars[i]) / most
			c.draw_rect(Rect2(Vector2(x0 + bw * float(i) + bw * 0.15, base - bh), Vector2(bw * 0.7, bh)), Color(on, 0.35 + 0.65 * float(i + 1) / float(bars.size())))
		c.draw_line(Vector2(x0, base), Vector2(x1, base), Color(on, 0.5), 1.5)
		c.draw_string(LabPrint.font("body"), Vector2(x0, h - _px(0.07)), String(d.get("bar_label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, _px(0.07), Color(on, 0.78))


func apply_mood(_m: String, _instant: bool = false) -> void:
	for rec in _prints:
		RD.apply(rec, Style.mood)
