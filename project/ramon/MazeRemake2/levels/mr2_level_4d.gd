extends Node4D
## A LEVEL OF THE ANNEX: what every level shares. A level script extends this, describes its rooms
## in build_level() with the builder (world/mr2_build.gd), and adds what happens in tick().
##
## THE LEVEL IS BUILT IN CODE when it enters the tree, so nothing generated is ever saved into its
## .tscn (a MeshInstance4D saves whatever mesh it holds, engine_capabilities.md), and every collider is
## made from the same morph boxes as the meshes it stands for.
##
## WHAT THE GAME READS FROM A LEVEL: the title, the W range the gizmo draws (w_min, w_max) and the band
## colours (bands), the spawn, the checkpoints (each room's way in: Backspace brings you back), the
## doors (the builder's records), the relics, and the lift out (a box: stand in it and the level is done).

const Build := preload("res://ramon/MazeRemake2/world/mr2_build.gd")
const Morph := preload("res://ramon/MazeRemake2/world/mr2_morph.gd")
const LabGrid := preload("res://ramon/MazeRemake2/carried/lab_grid.gd")
const LabPrint := preload("res://ramon/MazeRemake2/carried/lab_print.gd")
const KitStyle := preload("res://ramon/MazeRemake2/carried/kit_style.gd")

signal relic_taken(relic: Dictionary)

@export var number: int = 1
@export var title: String = "THE THRESHOLD"
## The W the gizmo's scale runs over.
@export var w_min: float = -4.0
@export var w_max: float = 4.0

## The bands: [[w, colour, name], ...] ascending. The floors are tinted along them and the gizmo
## draws them.
var bands: Array = []
var build
var spawn := Vector4.ZERO
var spawn_yaw: float = 0.0
## [{name, lo: Vector4, hi: Vector4, at: Vector4 (feet), yaw}]: the first whose box holds you is
## where Backspace takes you.
var checkpoints: Array = []
## [{name, at: Vector4, r: float, node: Node4D, taken: bool, line: String}]
var relics: Array = []
## The lift out: {lo: Vector4, hi: Vector4} in world space (x, y, z, w).
var lift_out: Dictionary = {}
var lift_in: Dictionary = {}
var game: Node = null
## How much a level lifts the ambient light in DARK (the Heart's atrium is bigger than the torch reaches).
var dark_lift: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	build = Build.new(self)
	var stops := PackedFloat32Array()
	var colors := PackedColorArray()
	for b in bands:
		stops.append(float(b[0]))
		colors.append(b[1])
	build.tint = {"stops": stops, "colors": colors}
	build_level()
	build.finish()
	after_build()


## Override: the rooms.
func build_level() -> void:
	pass


## Override: anything made after the meshes (signs, props).
func after_build() -> void:
	pass


## Override: per frame, with the player.
func tick(_player: Node4D, delta: float) -> void:
	_time += delta


func doors() -> Array:
	return build.doors if build != null else []


## The band colour at W `w` (the same scale the floor uses).
func band_color(w: float) -> Color:
	if bands.is_empty():
		return Build.HOME
	if w <= float(bands[0][0]):
		return bands[0][1]
	for i in range(1, bands.size()):
		var a: float = float(bands[i - 1][0])
		var b: float = float(bands[i][0])
		if w <= b:
			return (bands[i - 1][1] as Color).lerp(bands[i][1], clampf((w - a) / maxf(b - a, 0.0001), 0.0, 1.0))
	return bands[bands.size() - 1][1]


## The band's name nearest W `w` ("KATA", "HOME", "ANA" ...).
func band_name(w: float) -> String:
	var best: String = ""
	var bd: float = INF
	for b in bands:
		var d: float = absf(float(b[0]) - w)
		if d < bd:
			bd = d
			best = String(b[2]) if b.size() > 2 else ""
	return best


## The checkpoint whose box holds `p` (feet), or the spawn.
func checkpoint_for(p: Vector4) -> Dictionary:
	for c in checkpoints:
		var lo: Vector4 = c["lo"]
		var hi: Vector4 = c["hi"]
		if p.x >= lo.x and p.x <= hi.x and p.z >= lo.z and p.z <= hi.z and p.w >= lo.w and p.w <= hi.w:
			return c
	return {"name": "start", "at": spawn, "yaw": spawn_yaw}


static func in_box(p: Vector4, box: Dictionary) -> bool:
	if box.is_empty():
		return false
	var lo: Vector4 = box["lo"]
	var hi: Vector4 = box["hi"]
	return p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y and p.z >= lo.z and p.z <= hi.z and p.w >= lo.w and p.w <= hi.w


## A sign: a box from `lo` to `hi` (thin along the axis of `normal`), standing from W `w0` to `w1`,
## printed on its `normal` face with `paint(canvas)` over `px` pixels. `slot` "blue" teaches (white type
## on the code blue), "glass" is a screen.
func sign_painted(lo: Vector3, hi: Vector3, w0: float, w1: float, normal: Vector4, px: Vector2i, paint: Callable, slot: String = "blue", glow: float = 0.35) -> MeshInstance4D:
	var mi: MeshInstance4D = build.sign(lo, hi, w0, w1, slot)
	var face := Vector2(hi.x - lo.x, hi.y - lo.y) if (absf(normal.z) > 0.5 or absf(normal.w) > 0.5) else Vector2(hi.z - lo.z, hi.y - lo.y)
	_paint_sign.call_deferred(mi, normal, face, px, paint, glow)
	return mi


func _paint_sign(mi: MeshInstance4D, normal: Vector4, face: Vector2, px: Vector2i, paint: Callable, glow: float) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var tex: Texture2D = await LabPrint.render(get_tree(), px, paint)
	if tex == null or not is_instance_valid(mi):
		return
	LabGrid.set_print(mi.material_override, tex, normal, Rect2(Vector2.ZERO, face), Color.WHITE, glow)


## The usual teaching sign: a kicker, a title and a line, white on blue, laid out on the kit's type
## ladder for the face, every line shrunk to fit the sign's width if it would run over.
func lesson_paint(kicker: String, heading: String, line: String, accent: Color = Color(0.62, 0.86, 1.0)) -> Callable:
	return func(c: Control) -> void:
		var w: float = c.size.x
		var h: float = c.size.y
		var m: float = w * 0.07
		var avail: float = w - m * 2.0
		var kf: Font = LabPrint.font("bold")
		var tf: Font = LabPrint.font("black")
		var bf: Font = LabPrint.font("body")
		var heads: PackedStringArray = heading.split("\n")
		var bodies: PackedStringArray = line.split("\n")
		var ks: int = _fit(kf, [kicker], int(h * 0.07), avail)
		var ts: int = _fit(tf, heads, int(h * 0.15), avail)
		var bs: int = _fit(bf, bodies, int(h * 0.075), avail)
		var y: float = h * 0.14
		c.draw_string(kf, Vector2(m, y + ks), kicker, HORIZONTAL_ALIGNMENT_LEFT, -1, ks, accent)
		y += ks * 2.2
		c.draw_rect(Rect2(m, y - ks * 0.6, w * 0.08, maxf(2.0, h * 0.008)), accent)
		y += ts * 0.5
		for t in heads:
			y += ts
			c.draw_string(tf, Vector2(m, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color.WHITE)
			y += ts * 0.12
		y += bs * 1.4
		for t in bodies:
			c.draw_string(bf, Vector2(m, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(0.86, 0.92, 1.0))
			y += bs * 1.45


## The largest size up to `size` at which every line of `lines` fits `width`.
static func _fit(f: Font, lines: Array, size: int, width: float) -> int:
	var s: int = size
	for t in lines:
		var tw: float = f.get_string_size(String(t), HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		if tw > width:
			s = int(floor(s * width / tw))
	return maxi(8, s)


## A relic: a 16-cell (the 4D octahedron) floating at `at` with W half-extent `r`: its slice grows from a
## point as you come to its W and shrinks away after, so it is only there near its own W. Walk into it to
## take it.
func add_relic(name: String, at: Vector4, r: float, color: Color, line: String) -> Dictionary:
	var mi := MeshInstance4D.new()
	mi.name = "Relic_" + name
	var m := OrthoplexTetraMesh4D.new()
	m.size = Vector4(0.7, 0.9, 0.7, r * 2.0)
	mi.mesh = m
	mi.material_override = Build.glow_material(color, 1.0)
	mi.position = at
	add_child(mi)
	var rec := {"name": name, "at": at, "r": r, "node": mi, "taken": false, "line": line, "color": color}
	relics.append(rec)
	return rec


## How much of a relic shows in a level slice at W `w`: 0 outside its W half-extent, 1 at its own W.
static func relic_share(rec: Dictionary, w: float) -> float:
	var d: float = absf(w - (rec["at"] as Vector4).w)
	return clampf(1.0 - d / float(rec["r"]), 0.0, 1.0)


## Turns the relics, and takes one when you walk into it at its W.
func tick_relics(player: Node4D, delta: float) -> void:
	var f: Vector4 = player.global_position
	for rec in relics:
		var node: Node4D = rec["node"]
		if not is_instance_valid(node):
			continue
		if bool(rec["taken"]):
			continue
		var at: Vector4 = rec["at"]
		node.basis = Basis4D.from_zx(_time * 0.9) * Basis4D.from_xw(_time * 0.35)
		node.position = at + Vector4(0, sin(_time * 1.6) * 0.08, 0, 0)
		var d := Vector2(f.x - at.x, f.z - at.z).length()
		if d < 0.9 and absf(f.y - at.y) < 1.6 and relic_share(rec, f.w) > 0.5:
			rec["taken"] = true
			node.visible = false
			relic_taken.emit(rec)
