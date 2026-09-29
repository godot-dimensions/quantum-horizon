@tool
extends Node4D

## The shooting range beside Trym's shed: a covered firing line in near-black timber, a
## rack of rifles, sandbags, and painted boards down the range. Stand at the counter and
## shoot the boards (pen_range_shooting_4d.gd). The range master behind it has somewhere
## better to send you as well (pen_range_talk_4d.gd, pen_range_trip_4d.gd).
##
## ONE MESH, BUILT FROM BOXES, COLOURED PER VERTEX. Everything is a box, so it is drawn
## from a list of boxes through terrain_bake_4d's box front end and merged into a single
## mesh - one draw instead of sixty (Experiment B) - and the boxes that should stop you are
## made into colliders from the same list, so what you see and what you bump into agree.
## It is small enough (about 2,500 tetrahedra) to build when the scene opens rather than
## bake to disk.
##
## EXCEPT THE BOARDS, which fall when shot and so cannot be part of a mesh that never moves.
## Each is its own node, hinged at the foot of its face, all five sharing one small mesh;
## the posts they stand on stay in the booth's mesh.
##
## FOUR-DIMENSIONAL LIKE A ROOM, OPEN LIKE A STALL. The enclosure rule
## (follow_up/4d_enclosure_rule.md): corner posts with the booth's full W depth, half-height
## walls on both z sides AND both w sides, so a turned slice sees a booth and not a roof on
## sticks. The +x side, toward the field, is the way in; the -x side is the firing line.
## The target boards are spread through w as well as z, so turning the slice down the
## range brings other boards onto it.
##
## Its own frame: +x faces the field, -x is down the range.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var wood: Color = Color(0.105, 0.088, 0.072): set = _set_colour
@export var wood_edge: Color = Color(0.17, 0.14, 0.11): set = _set_colour
@export var steel: Color = Color(0.20, 0.21, 0.23): set = _set_colour
@export var stock: Color = Color(0.36, 0.22, 0.12): set = _set_colour
@export var sandbag: Color = Color(0.46, 0.41, 0.31): set = _set_colour
@export var board: Color = Color(0.90, 0.88, 0.80): set = _set_colour
@export var ring: Color = Color(0.72, 0.14, 0.10): set = _set_colour

const HALF := Vector3(2.0, 2.5, 1.75)
const ROOF_Y := 2.85
## Down the range, in the booth's frame: (x, z, w) of each board's post. Spread through z
## and w, so turning the slice down the range brings other boards onto it.
const BOARDS := [Vector3(-9.0, -1.2, 0.0), Vector3(-12.0, 0.8, 0.9), Vector3(-15.0, -0.2, -1.1), Vector3(-18.0, 1.4, 0.4), Vector3(-13.5, -1.9, -0.3)]
## How high the hinge at the foot of a board's face is: the top of its post.
const HINGE_Y := 1.1
## A board's face as a box, from its hinge: [centre, size]. The rings are cubes in (y, z, w)
## - a 4D board's face is a solid, not a square - so how far out a shot landed is the
## largest of its three offsets from the middle, and the bull is the black cube there.
const FACE := [Vector4(0.02, 0.45, 0.0, 0.0), Vector4(0.06, 0.9, 0.9, 0.9)]
const RING_HALF := 0.28
const INNER_HALF := 0.18
const BULL_HALF := 0.07

## SIGNS THROUGH W (Ramon, 29 Sept: "maybe you can find different signs in 4d when you
## rotate"). A board's face is a solid 0.9 deep in W, and the rings fill only its middle;
## either side of them, a painted layer a hand's depth thick: on one side a letter, on the
## other a red glyph. The home slice cuts every board through its rings, so neither shows
## until you step or turn the slice through a board - and then it is a different sign on
## each board, and a different one again the other way. Read across the range from the
## left, the letters spell what the white suits dig out of the hill.
const SIGN_W := 0.37
const SIGN_CELL := 0.13
## By board, in the order of BOARDS: its letter, and its glyph. The boards' order across
## the range from the counter, left to right, is 3, 1, 2, 0, 4.
const LETTERS := ["T", "Z", "O", "A", "H"]
const GLYPHS := ["diamond", "cross", "eye", "plus", "triangle"]
const BITMAPS := {
	"A": [".###.", "#...#", "#####", "#...#", "#...#"],
	"Z": ["#####", "...#.", "..#..", ".#...", "#####"],
	"O": [".###.", "#...#", "#...#", "#...#", ".###."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#.."],
	"H": ["#...#", "#...#", "#####", "#...#", "#...#"],
	"diamond": ["..#..", ".#.#.", "#...#", ".#.#.", "..#.."],
	"cross": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	"eye": [".###.", "#...#", "#.#.#", "#...#", ".###."],
	"plus": ["..#..", "..#..", "#####", "..#..", "..#.."],
	"triangle": ["..#..", ".#.#.", ".#.#.", "#...#", "#####"],
}
@export var letter_ink: Color = Color(0.06, 0.06, 0.07): set = _set_colour
@export var glyph_ink: Color = Color(0.70, 0.12, 0.10): set = _set_colour
## The rifle on the counter you pick up to shoot, where one of the pair used to lie, and
## the other still painted into the booth beside it (pen_range_shooting_4d.gd).
const RIFLE_ON_COUNTER := Vector4(-HALF.x + 0.15, 1.15, -0.9, 0.0)
var counter_rifle: Node4D

## The board nodes, in the order of BOARDS.
var board_nodes: Array[Node4D] = []


func _set_colour(_v: Color) -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()


## [centre, size, colour, solid] for every box.
func boxes() -> Array:
	var out := []
	# Deck, counter and its top. The deck is drawn, not collided with: a body here has no
	# step-up (snap distance 0.1 m), so even a plank's height of deck would stop you at
	# its edge. It is thin enough that standing "in" it does not show.
	out.append([Vector4(0.0, 0.025, 0.0, 0.0), Vector4(HALF.x * 2.0, 0.05, HALF.y * 2.0, HALF.z * 2.0), wood_edge, false])
	out.append([Vector4(-HALF.x + 0.3, 0.55, 0.0, 0.0), Vector4(0.45, 1.0, HALF.y * 2.0 - 0.3, HALF.z * 2.0 - 0.2), wood, true])
	out.append([Vector4(-HALF.x + 0.3, 1.08, 0.0, 0.0), Vector4(0.62, 0.06, HALF.y * 2.0 - 0.1, HALF.z * 2.0), wood_edge, false])
	# Posts at the four corners in (x, z), each running the booth's whole W depth. Posts at
	# the eight corners in (x, z, w) with a post's own thin W depth looked right on paper
	# and left the roof floating: every one of them sat off the home slice.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			out.append([Vector4(sx * (HALF.x - 0.1), ROOF_Y * 0.5, sz * (HALF.y - 0.1), 0.0), Vector4(0.16, ROOF_Y, 0.16, HALF.z * 2.0), wood, true])
	# And the same four again for the w walls: at the corners in (w, z), running the whole X
	# depth. A slice turned a quarter into W sees these as its corner posts, the way the
	# home slice sees the ones above; in between it cuts parts of both.
	for sw in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			out.append([Vector4(0.0, ROOF_Y * 0.5, sz * (HALF.y - 0.1), sw * (HALF.z - 0.1)), Vector4(HALF.x * 2.0, ROOF_Y, 0.16, 0.16), wood, false])
	# Roof, and a ridge along it.
	out.append([Vector4(0.0, ROOF_Y + 0.07, 0.0, 0.0), Vector4(HALF.x * 2.0 + 0.5, 0.14, HALF.y * 2.0 + 0.5, HALF.z * 2.0 + 0.5), wood, false])
	out.append([Vector4(0.0, ROOF_Y + 0.22, 0.0, 0.0), Vector4(0.26, 0.18, HALF.y * 2.0 + 0.5, HALF.z * 2.0 + 0.5), wood_edge, false])
	# Half walls on both z sides and both w sides - the eight-wall rule, cut to waist height.
	for s in [-1.0, 1.0]:
		out.append([Vector4(0.0, 0.62, s * (HALF.y - 0.06), 0.0), Vector4(HALF.x * 2.0, 1.0, 0.1, HALF.z * 2.0), wood, true])
		out.append([Vector4(0.0, 0.62, 0.0, s * (HALF.z - 0.06)), Vector4(HALF.x * 2.0, 1.0, HALF.y * 2.0, 0.1), wood, true])
		# Plank lines on them, a shade lighter.
		for y in [0.3, 0.62, 0.94]:
			out.append([Vector4(0.0, y, s * (HALF.y - 0.005), 0.0), Vector4(HALF.x * 2.0 - 0.1, 0.03, 0.02, HALF.z * 2.0 - 0.2), wood_edge, false])
	# The rifle rack against the +z wall, and four rifles standing in it.
	var rack_z: float = HALF.y - 0.28
	out.append([Vector4(0.4, 1.25, rack_z, 0.0), Vector4(1.8, 0.08, 0.14, 0.5), wood_edge, false])
	out.append([Vector4(0.4, 0.2, rack_z, 0.0), Vector4(1.8, 0.1, 0.24, 0.5), wood_edge, false])
	for i in 4:
		var x: float = -0.3 + 0.45 * float(i)
		out.append([Vector4(x, 0.36, rack_z, 0.0), Vector4(0.07, 0.36, 0.05, 0.07), stock, false])
		out.append([Vector4(x, 0.95, rack_z, 0.0), Vector4(0.035, 0.85, 0.035, 0.05), steel, false])
	# A rifle lying on the counter, pointing down the range; the other of the pair is its own
	# node (counter_rifle), since you pick it up.
	for z in [0.7]:
		out.append([Vector4(-HALF.x + 0.15, 1.15, z, 0.0), Vector4(0.95, 0.035, 0.035, 0.05), steel, false])
		out.append([Vector4(-HALF.x + 0.62, 1.15, z, 0.0), Vector4(0.36, 0.08, 0.06, 0.07), stock, false])
	# Ammunition tins.
	for z in [-0.1, 1.5]:
		out.append([Vector4(-HALF.x + 0.4, 1.17, z, 0.3), Vector4(0.24, 0.12, 0.14, 0.14), Color(0.22, 0.28, 0.16), false])
	# Down the range: the boards' posts (the boards themselves are board_boxes()), and a
	# berm of sandbags.
	for b in BOARDS:
		out.append([Vector4(b.x, HINGE_Y * 0.5, b.y, b.z), Vector4(0.08, HINGE_Y, 0.08, 0.08), wood, false])
	for row in 3:
		var y: float = 0.16 + 0.3 * float(row)
		out.append([Vector4(-21.0, y, 0.0, 0.0), Vector4(0.6, 0.28, 6.0 - row * 0.8, 4.0 - row * 0.6), sandbag.darkened(0.06 * row), true])
	# A few loose sandbags by the counter.
	out.append([Vector4(-HALF.x - 0.45, 0.16, -1.8, 0.8), Vector4(0.55, 0.3, 0.4, 0.4), sandbag, true])
	out.append([Vector4(-HALF.x - 0.45, 0.16, 1.9, -0.9), Vector4(0.55, 0.3, 0.4, 0.4), sandbag, true])
	return out


## A board's signs, from its hinge: [centre, size, colour] for each painted cell.
func sign_boxes(index: int) -> Array:
	var out := []
	for layer in [[String(LETTERS[index]), SIGN_W, letter_ink], [String(GLYPHS[index]), -SIGN_W, glyph_ink]]:
		var rows: Array = BITMAPS[layer[0]]
		for r in rows.size():
			var row: String = rows[r]
			for c in row.length():
				if row[c] != "#":
					continue
				# Seen from the counter, looking down -x, the board's left is +z.
				var at := Vector4(0.07, FACE[0].y + (2 - r) * SIGN_CELL, (2 - c) * SIGN_CELL, float(layer[1]))
				out.append([at, Vector4(0.02, SIGN_CELL * 0.92, SIGN_CELL * 0.92, 0.14), layer[2]])
	return out


## One board's face, from its hinge: [centre, size, colour] for each box.
func board_boxes() -> Array:
	return [
		[FACE[0], FACE[1], board],
		[Vector4(0.06, 0.45, 0.0, 0.0), Vector4(0.03, RING_HALF * 2.0, RING_HALF * 2.0, RING_HALF * 2.0), ring],
		[Vector4(0.08, 0.45, 0.0, 0.0), Vector4(0.02, INNER_HALF * 2.0, INNER_HALF * 2.0, INNER_HALF * 2.0), board],
		[Vector4(0.10, 0.45, 0.0, 0.0), Vector4(0.02, BULL_HALF * 2.0, BULL_HALF * 2.0, BULL_HALF * 2.0), Color(0.08, 0.08, 0.08)],
	]


## The shading every box here gets: tops catch the light, sides less so, and the foot of
## anything standing darker. [param base_y] is how high the box's own frame starts.
static func _shade(colour: Color, base_y: float = 0.0) -> Callable:
	return func(p: Vector4, outward: Vector4) -> Color:
		var c: Color = colour if outward.y > 0.5 else colour.darkened(0.2)
		return c.lerp(Color.BLACK, 0.3 * (1.0 - smoothstep(0.0, 0.35, p.y + base_y)) * float(outward.y < 0.5))


func rebuild() -> void:
	for child in get_children():
		if child.has_meta("range_booth_built"):
			child.free()
	var all := TerrainBake.Builder.new()
	var body := StaticBody4D.new()
	body.name = "Solid"
	body.set_meta("range_booth_built", true)
	for b in boxes():
		all.append(TerrainBake.bake_box(b[0], b[1], _shade(b[2])))
		if b[3] and not Engine.is_editor_hint():
			var shape := BoxShape4D.new()
			shape.size = b[1]
			var holder := CollisionShape4D.new()
			holder.shape = shape
			holder.position = b[0]
			body.add_child(holder)
	var mesh := MeshInstance4D.new()
	mesh.name = "Booth"
	mesh.set_meta("range_booth_built", true)
	mesh.mesh = TerrainBake.mesh_of(all)
	add_child(mesh)
	add_child(body)
	# The boards, each on its own hinge, each with its own signs - so each its own mesh now,
	# five small ones rather than one shared.
	board_nodes.clear()
	for i in BOARDS.size():
		var face := TerrainBake.Builder.new()
		for b in board_boxes() + sign_boxes(i):
			face.append(TerrainBake.bake_box(b[0], b[1], _shade(b[2], HINGE_Y)))
		var bp: Vector3 = BOARDS[i]
		var hinge := MeshInstance4D.new()
		hinge.name = "Board%d" % i
		hinge.set_meta("range_booth_built", true)
		hinge.mesh = TerrainBake.mesh_of(face)
		hinge.position = Vector4(bp.x, HINGE_Y, bp.y, bp.z)
		add_child(hinge)
		board_nodes.append(hinge)
	# The rifle you pick up: barrel and stock, the same boxes the painted one is made of.
	var rifle := TerrainBake.Builder.new()
	rifle.append(TerrainBake.bake_box(Vector4.ZERO, Vector4(0.95, 0.035, 0.035, 0.05), _shade(steel, 1.15)))
	rifle.append(TerrainBake.bake_box(Vector4(0.47, 0.0, 0.0, 0.0), Vector4(0.36, 0.08, 0.06, 0.07), _shade(stock, 1.15)))
	var on_counter := MeshInstance4D.new()
	on_counter.name = "CounterRifle"
	on_counter.set_meta("range_booth_built", true)
	on_counter.mesh = TerrainBake.mesh_of(rifle)
	on_counter.position = RIFLE_ON_COUNTER
	add_child(on_counter)
	counter_rifle = on_counter
