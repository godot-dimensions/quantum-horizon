extends Node4D

## The Arboretum: a grove plot's sign, a black glass screen on a stand at the plot's corner (the kit's
## screens are black glass with white type) carrying the plot's own numbers, measured as the plot is
## placed: how many trees, how many shapes they share, how many tetrahedra are drawn and how many are
## held in video memory (a shared shape is held once), and how long the grove took to load.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/Arboretum/carried/scripts/chamber_build.gd")
const RD := preload("res://ramon/Arboretum/carried/scripts/rd_build.gd")
const LabPrint := preload("res://ramon/Arboretum/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/Arboretum/carried/kit/kit_style.gd")
const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")

const SIZE := Vector2(2.0, 1.1)

var _info: Dictionary = {}
var _load_ms: float = 0.0
var _screen: MeshInstance4D
var _rec: Dictionary = {}


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func show_info(info: Dictionary, load_ms: float) -> void:
	_info = info
	_load_ms = load_ms
	_build()


func _build() -> void:
	Build.clear(self)
	Build.box(self, "Stand", Vector3(0, 0.55, -0.06), Vector3(0.4, 1.1, 0.3), "kit_metal", true)
	_screen = Build.box(self, "Screen", Vector3(0, 1.45, 0), Vector3(SIZE.x, SIZE.y, 0.05), "kit_glass", false)
	_screen.basis = Basis4D.from_yz(deg_to_rad(30.0))
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	_rec = await RD.print_box(tree, _screen, Vector4(0, 0, 1, 0), SIZE, _paint, {"bright": 0.95, "dark": 0.95}, 360.0)
	apply_mood(Style.mood)


func apply_mood(m: String, _instant: bool = false) -> void:
	if not _rec.is_empty():
		RD.apply(_rec, m if m in ["bright", "dark"] else "bright")


func _paint(c: Control, _ink: Dictionary) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	var white := Color(1, 1, 1)
	var dim := Color(0.80, 0.86, 0.96, 0.75)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var lw: float = maxf(2.0, h * 0.012)
	c.draw_rect(Rect2(Vector2(lw, lw), Vector2(w - lw * 2.0, h - lw * 2.0)), Color(1, 1, 1, 0.85), false, lw)
	var pad: float = h * 0.09
	c.draw_string(fs, Vector2(pad, pad + h * 0.07), "THE GROVE   ·   " + String(_info.get("cell", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, int(h * 0.055), Style.UI_ACCENT)
	c.draw_string(fb, Vector2(pad, pad + h * 0.25), String(_info.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, int(h * 0.15), white)
	var rows: Array = [
		["Trees", "%d, sharing %d shapes" % [int(_info.get("trees", 0)), int(_info.get("shapes", 0))]],
		["Drawn", "%s tetrahedra" % Bake.thousands(int(_info.get("drawn", 0)))],
		["Held in memory", "%s tetrahedra, about %.0f MB" % [Bake.thousands(int(_info.get("held", 0))), Bake.mb(int(_info.get("held", 0)))]],
	]
	if int(_info.get("leaves", 0)) > 0:
		rows.append(["Leaves", "%s, on the graphics card" % Bake.thousands(int(_info.get("leaves", 0)))])
	rows.append(["Loaded", "from disk as you came near, %s" % Bake.ms(_load_ms)])
	var y: float = pad + h * 0.38
	for r in rows:
		c.draw_line(Vector2(pad, y), Vector2(w - pad, y), Color(1, 1, 1, 0.12), maxf(1.0, lw * 0.5))
		y += h * 0.1
		c.draw_string(fl, Vector2(pad, y), String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, int(h * 0.055), dim)
		c.draw_string(fs, Vector2(pad + w * 0.32, y), String(r[1]), HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0 - w * 0.32, int(h * 0.055), white)
		y += h * 0.03
	c.draw_string(fl, Vector2(pad, h - pad), "PRE-BAKED SHAPES  ·  MEASURED WHEN PLACED", HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, int(h * 0.04), dim)
