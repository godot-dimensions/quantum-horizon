@tool
extends Node4D

## A bay: the test cell every step of a lab explanation happens in. Every bay in a lab is the same
## shell at the same place, stacked along W (LabKit/lab_sequence_4d.gd), so moving between steps
## works like turning a page, and camera marks set on the shell frame every bay the same way.
##
## THE SHELL, all generated (nothing is saved into the scene file), sized from `size`:
##   floor     Ramon's dev grid at 2 m a tile; white in the bright mood, dark grey in the dark
##   walls     the back and both sides, open at the front where you arrive; chamfered corners
##   numeral   the step's number in large segmented digits on the back wall, glowing in the part's
##             colour, built from bars like a seven-segment display (no texture, no font)
##   ring      a light-strip ring and four crossbars overhead: lab rigging that frames the shots,
##             barely there in the bright mood and carrying the room in the dark one
##   pad       the W-lift's pad where you arrive (the lift's logic is the sequence's)
##   spots     where the rig, the lectern and the learning zone go (`spot("rig")` and so on)
##
## THE DISSOLVE. Boxes do not fade through W, they end: a 4D box's cross-section stays the same
## size until the slice leaves it, then it is gone. So each piece has its own W thickness, the
## walls thinnest and the floor thickest. Riding the lift out of a bay, the walls leave the slice
## first, then the rigging, then the centre; arriving, the floor is already there and the walls
## come last. Outside in, then inside out.
##
## NO class_name (engine_gotchas.md): preload this file.

const Style := preload("res://ramon/LabKit/lab_style.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const GENERATED := "lab_generated"
const GROUP := "lab_bay"

## The square footprint in metres (x and z).
@export_range(8.0, 60.0, 0.5) var size: float = 14.0:
	set(v):
		size = v
		_later()
@export_range(2.0, 10.0, 0.1) var wall_height: float = 4.4:
	set(v):
		wall_height = v
		_later()
## The step's number on the back wall; -1 shows none.
@export_range(-1, 99, 1) var numeral: int = 1:
	set(v):
		numeral = v
		_later()
@export_enum("neutral", "build", "motion", "w") var part: String = "neutral":
	set(v):
		part = v
		_later()
## How far through W the floor reaches either way, in metres. Bays 12 m apart with a floor 11.6
## thick leave you standing on floor the whole way through a lift ride.
@export_range(1.0, 40.0, 0.1) var floor_w: float = 11.6:
	set(v):
		floor_w = v
		_later()
## The lift's pad lights in the W colour once you may ride on, and stays a dim grey until then.
var lift_lit: bool = true
@export var show_pad: bool = true:
	set(v):
		show_pad = v
		_later()

var _mood: String = "bright"
var _parts: Array = []     # [MeshInstance4D, size, role]
var _exhibit_light: OmniLight4D
var _glows: Array = []     # [MeshInstance4D, kind] kind: "part" or "strip" or "pad"
var _built: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group("lab_mood_listener")


func _ready() -> void:
	_mood = Style.mood_of(get_tree())
	_build()


func _later() -> void:
	if is_node_ready():
		_build()


## Where things stand in a bay, in its own space, on one line from where you arrive to the
## exhibit: the pad, the learning zone, the lectern, then the rig a few metres beyond it, close
## enough to read from the zone (the first layout put the rig nine metres from the pad and the
## wolf read small). The back wall, with the step's number, stands well behind the rig.
func spot(which: String) -> Vector4:
	var h: float = size * 0.5
	match which:
		# Found by eye from the player's camera (4 Oct): with the lectern straight in front, its
		# card and your own avatar both sat on the exhibit. Now the lectern stands beside the rig
		# like a museum label, and the pad is near enough that the exhibit fills the view.
		"rig": return Vector4(0.0, 0.0, -h * 0.22, 0.0)
		"lectern": return Vector4(h * 0.33, 0.0, h * 0.03, 0.0)
		"zone": return Vector4(0.0, 0.0, h * 0.14, 0.0)
		"pad": return Vector4(0.0, 0.0, h * 0.38, 0.0)
		"numeral": return Vector4(0.0, wall_height * 0.55, -h + 0.25, 0.0)
	return Vector4.ZERO


func _build() -> void:
	for c in get_children():
		if c.has_meta(GENERATED):
			remove_child(c)
			c.free()
	_parts.clear()
	_glows.clear()
	var h: float = size * 0.5
	var t: float = 0.24          # wall thickness
	var chamfer: float = 1.6     # how far a corner is cut back
	var wall_w: float = floor_w * 0.42
	# The floor, top at y 0, and solid.
	_box("Floor", Vector4(size, 0.2, size, floor_w), Vector4(0.0, -0.1, 0.0, 0.0), "floor", true)
	# The back wall and the two sides, stopping short of the corners, which are cut at 45 degrees.
	_box("WallBack", Vector4(size - chamfer * 2.0, wall_height, t, wall_w), Vector4(0.0, wall_height * 0.5, -h, 0.0), "wall", true)
	_box("WallLeft", Vector4(t, wall_height, size * 0.82 - chamfer, wall_w), Vector4(-h, wall_height * 0.5, -size * 0.09 + chamfer * 0.5, 0.0), "wall", true)
	_box("WallRight", Vector4(t, wall_height, size * 0.82 - chamfer, wall_w), Vector4(h, wall_height * 0.5, -size * 0.09 + chamfer * 0.5, 0.0), "wall", true)
	var diag: float = chamfer * sqrt(2.0)
	for sx in [-1.0, 1.0]:
		var corner := _box("Corner%s" % ("L" if sx < 0.0 else "R"), Vector4(diag + t, wall_height, t, wall_w),
			Vector4(sx * (h - chamfer * 0.5), wall_height * 0.5, -h + chamfer * 0.5, 0.0), "wall", true)
		corner.basis = Basis4D.from_zx(sx * PI * 0.25)
	# A skirting strip of light along the foot of the walls, and a cap along their tops.
	_glow_box("SkirtBack", Vector4(size - chamfer * 2.0, 0.03, 0.03, wall_w * 0.98), Vector4(0.0, 0.06, -h + t * 0.5 + 0.02, 0.0), "strip")
	_glow_box("CapBack", Vector4(size - chamfer * 2.0, 0.025, 0.06, wall_w * 0.98), Vector4(0.0, wall_height + 0.012, -h, 0.0), "part")
	for sx in [-1.0, 1.0]:
		_glow_box("Skirt%s" % ("L" if sx < 0.0 else "R"), Vector4(0.03, 0.03, size * 0.82 - chamfer, wall_w * 0.98),
			Vector4(sx * (h - t * 0.5 - 0.02), 0.06, -size * 0.09 + chamfer * 0.5, 0.0), "strip")
	# The rigging: a light ring and four crossbars, thinner through W than the walls are.
	var ring_y: float = wall_height + 0.9
	var ring_r: float = h * 0.62
	var segs: int = 36
	for i in segs:
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0 := Vector4(cos(a0) * ring_r, ring_y, sin(a0) * ring_r - h * 0.1, 0.0)
		var p1 := Vector4(cos(a1) * ring_r, ring_y, sin(a1) * ring_r - h * 0.1, 0.0)
		var g := _glow_box("Ring%d" % i, Vector4((p1 - p0).length() * 1.03, 0.05, 0.05, floor_w * 0.3), (p0 + p1) * 0.5, "strip")
		g.basis = Basis4D.from_zx(atan2(p1.x - p0.x, p1.z - p0.z) - PI * 0.5)
	for k in 4:
		var ang: float = PI * 0.25 + float(k) * PI * 0.5
		var dir := Vector4(cos(ang), 0.0, sin(ang), 0.0)
		var bar_len: float = h * 0.62
		var mid: Vector4 = dir * (ring_r * 0.5) + Vector4(0.0, ring_y + 0.08, -h * 0.1, 0.0)
		var bar := _box("Truss%d" % k, Vector4(bar_len, 0.05, 0.05, floor_w * 0.28), mid, "trim", false)
		bar.basis = Basis4D.from_zx(atan2(dir.x, dir.z) - PI * 0.5)
	# The step's number.
	if numeral >= 0:
		_numeral(numeral)
	# The W-lift's pad.
	if show_pad:
		var pad_at: Vector4 = spot("pad")
		_cubinder_part("Pad", 1.5, 0.05, floor_w * 0.995, pad_at + Vector4(0.0, 0.025, 0.0, 0.0), "pad")
		_ring_glow("PadRing", 1.55, pad_at + Vector4(0.0, 0.055, 0.0, 0.0), "pad")
	# A soft light over the exhibit, for the dark mood: a rig without a boom brings no pool of its own.
	_exhibit_light = OmniLight4D.new()
	_exhibit_light.name = "ExhibitLight"
	_exhibit_light.set_meta(GENERATED, true)
	_exhibit_light.position = spot("rig") + Vector4(0.0, wall_height * 0.8, 1.2, 0.0)
	_exhibit_light.light_color = Color(0.92, 0.94, 1.0)
	_exhibit_light.set("omni_range_meters", size * 0.55)
	add_child(_exhibit_light)
	_built = true
	apply_mood(_mood, true)


# -- pieces ------------------------------------------------------------------------------------

func _box(nm: String, sz: Vector4, at: Vector4, role: String, solid: bool) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(sz)
	m.position = at
	m.set_meta(GENERATED, true)
	add_child(m)
	_parts.append([m, sz, role])
	if solid:
		var body := StaticBody4D.new()
		body.name = nm + "Body"
		body.set_meta(GENERATED, true)
		var shape := CollisionShape4D.new()
		var box := BoxShape4D.new()
		box.size = sz
		shape.shape = box
		body.add_child(shape)
		body.position = at
		add_child(body)
	return m


func _glow_box(nm: String, sz: Vector4, at: Vector4, kind: String) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(sz)
	m.position = at
	m.set_meta(GENERATED, true)
	add_child(m)
	_glows.append([m, kind])
	return m


func _cubinder_part(nm: String, r: float, hgt: float, thick: float, at: Vector4, role: String) -> void:
	var c := CubinderShape4D.new()
	c.radius = r
	c.height = hgt
	c.thickness = thick
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = c.to_tetra_mesh({"segments": 40})
	m.position = at
	m.set_meta(GENERATED, true)
	add_child(m)
	_parts.append([m, Vector4(r * 2.0, hgt, r * 2.0, thick), role])


func _ring_glow(nm: String, r: float, at: Vector4, kind: String) -> void:
	var n: int = 40
	for i in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var p0 := Vector4(cos(a0) * r, 0.0, sin(a0) * r, 0.0)
		var p1 := Vector4(cos(a1) * r, 0.0, sin(a1) * r, 0.0)
		var g := _glow_box("%s%d" % [nm, i], Vector4((p1 - p0).length() * 1.05, 0.02, 0.05, floor_w * 0.99), at + (p0 + p1) * 0.5, kind)
		g.basis = Basis4D.from_zx(atan2(p1.x - p0.x, p1.z - p0.z) - PI * 0.5)


## Large segmented digits on the back wall, as on a seven-segment display.
const SEGMENTS := {
	0: "abcdef", 1: "bc", 2: "abdeg", 3: "abcdg", 4: "bcfg", 5: "acdfg", 6: "acdefg", 7: "abc", 8: "abcdefg", 9: "abcdfg",
}


func _numeral(n: int) -> void:
	var text: String = "%02d" % n
	var digit_h: float = wall_height * 0.42
	var digit_w: float = digit_h * 0.52
	var bar: float = digit_h * 0.085
	var gap: float = digit_w * 0.42
	var centre: Vector4 = spot("numeral")
	var total_w: float = digit_w * text.length() + gap * (text.length() - 1)
	for i in text.length():
		var on: String = SEGMENTS[int(text[i])]
		var cx: float = -total_w * 0.5 + digit_w * 0.5 + float(i) * (digit_w + gap)
		var half_h: float = digit_h * 0.5
		var half_w: float = digit_w * 0.5
		var spec := {
			"a": [Vector2(cx, half_h), true], "g": [Vector2(cx, 0.0), true], "d": [Vector2(cx, -half_h), true],
			"f": [Vector2(cx - half_w, half_h * 0.5), false], "b": [Vector2(cx + half_w, half_h * 0.5), false],
			"e": [Vector2(cx - half_w, -half_h * 0.5), false], "c": [Vector2(cx + half_w, -half_h * 0.5), false],
		}
		for sname in spec:
			var at2: Vector2 = spec[sname][0]
			var horizontal: bool = spec[sname][1]
			var sz: Vector4 = Vector4(digit_w - bar * 0.4, bar, 0.04, floor_w * 0.36) if horizontal else Vector4(bar, half_h - bar * 0.4, 0.04, floor_w * 0.36)
			var g := _glow_box("Digit%d%s" % [i, sname], sz, centre + Vector4(at2.x, at2.y, 0.0, 0.0), "digit_on" if on.contains(sname) else "digit_off")


# -- the mood ----------------------------------------------------------------------------------

func apply_mood(mood: String, _instant: bool = false) -> void:
	_mood = mood
	if not _built:
		return
	if _exhibit_light != null:
		_exhibit_light.visible = mood == Style.DARK
		_exhibit_light.light_energy = 1.6
	for p in _parts:
		var mi: MeshInstance4D = p[0]
		var role: String = p[2]
		if role == "pad":
			mi.material_override = Mats.surface(Style.surface("pad", mood), p[1], 1.0)
		else:
			mi.material_override = Mats.surface(Style.surface(role, mood), p[1], 2.0, Style.tint(part, role, mood))
	var part_col: Color = Style.code(part + "_fill", mood) if part != "neutral" else Color(0.72, 0.76, 0.82)
	var strip_col: Color = Color(0.86, 0.90, 0.96) if mood == Style.DARK else Color(0.78, 0.80, 0.84)
	var off_col: Color = Color(0.90, 0.90, 0.90) if mood == Style.BRIGHT else Color(0.10, 0.11, 0.14)
	for g in _glows:
		var mi2: MeshInstance4D = g[0]
		match g[1]:
			"part", "digit_on":
				mi2.material_override = Mats.glow(part_col if mood == Style.DARK else part_col.darkened(0.08), 1.0)
			"digit_off":
				mi2.material_override = Mats.glow(off_col, 1.0)
			"pad":
				var dim: Color = Color(0.62, 0.64, 0.68) if mood == Style.BRIGHT else Color(0.22, 0.24, 0.28)
				mi2.material_override = Mats.glow(Style.code("w_fill", mood) if lift_lit else dim, 1.0)
			_:
				mi2.material_override = Mats.glow(strip_col, 1.0)


func set_lift_lit(on: bool) -> void:
	if lift_lit == on:
		return
	lift_lit = on
	apply_mood(_mood, true)
