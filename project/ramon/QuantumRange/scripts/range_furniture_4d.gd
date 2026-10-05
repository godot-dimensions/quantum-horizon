@tool
extends Node4D

## The range's built-in furniture: the counter on the firing line, and the holodeck's thin cyan light
## lines (one along the counter's front edge, one along the foot of every wall), merged into one mesh
## per colour (carried/LabKit/lab_batch.gd: every 4D instance costs shader instance variables, and a
## line of light is one draw instead of dozens).
##
## It stands at the world origin (the grid shader continues its lines from where each box stands).
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/QuantumRange/carried/scripts/chamber_build.gd")
const Mats := preload("res://ramon/QuantumRange/carried/LabKit/lab_materials.gd")
const Batch := preload("res://ramon/QuantumRange/carried/LabKit/lab_batch.gd")
const Layout := preload("res://ramon/QuantumRange/scripts/range_layout.gd")
const Style := preload("res://ramon/QuantumRange/scripts/range_style.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
## The light lines at the foot of the walls.
@export var skirting: bool = true:
	set(v):
		skirting = v
		_later()

var _queued: bool = false


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func rebuild() -> void:
	Build.clear(self)
	var c: Vector3 = Layout.COUNTER
	Build.box(self, "Counter", Vector3(0.0, c.y * 0.5, Layout.LINE_Z), c, "range_counter", true)
	# A grey top so the counter reads as a ledge against the white floor beyond it.
	Build.box(self, "CounterTop", Vector3(0.0, c.y + 0.02, Layout.LINE_Z), Vector3(c.x + 0.04, 0.04, c.z + 0.06), "range_top", false)
	var b := Batch.new()
	var w: float = Build.W_DEPTH * 0.5
	# The firing line: along the counter's downrange edge, just under its top.
	b.box("line", Vector4(c.x, 0.035, 0.035, w), Vector4(0.0, c.y - 0.05, Layout.LINE_Z - c.z * 0.5 - 0.02, 0.0))
	if skirting:
		var ol: PackedVector2Array = Layout.outline()
		for e in ol.size():
			var a: Vector2 = ol[e]
			var d2: Vector2 = ol[(e + 1) % ol.size()]
			var len: float = a.distance_to(d2)
			var dir: Vector2 = (d2 - a) / len
			var inward := Vector2(-dir.y, dir.x)
			var mid: Vector2 = (a + d2) * 0.5 + inward * 0.04
			var span: float = len
			# The door leaves its gap in the line.
			if e == 3:
				var left: float = Layout.entrance_along(Layout.DOOR.y)
				var right: float = Layout.entrance_along(Layout.DOOR.x)
				for piece in [Vector2(0.0, left), Vector2(right, len)]:
					var pm: Vector2 = a + dir * ((piece.x + piece.y) * 0.5) + inward * 0.04
					b.box("line", Vector4(piece.y - piece.x, 0.05, 0.03, w), Vector4(pm.x, 0.025, pm.y, 0.0), Basis4D.from_zx(atan2(dir.x, dir.y) - PI * 0.5))
				continue
			b.box("line", Vector4(span, 0.05, 0.03, w), Vector4(mid.x, 0.025, mid.y, 0.0), Basis4D.from_zx(atan2(dir.x, dir.y) - PI * 0.5))
	var lines: MeshInstance4D = b.instance("line")
	lines.material_override = Mats.glow(Style.glow("w"), 1.0)
	lines.set_meta(Build.GENERATED, true)
	add_child(lines)
