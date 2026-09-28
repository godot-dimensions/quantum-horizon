@tool
extends Node4D

## A painted sign, in letters built from 4D blocks, so that turning your slice round shows
## you it is backwards.
##
## CHIRALITY, WHICH WAS ALREADY HAPPENING AND NOBODY COULD SEE IT. Turn your slice 180
## degrees through W and x goes to minus x: everything on your slice is mirror-reversed.
## The block people already switch hands when you do it - Trym: "I actually really like
## that the 4D camera applies to the character model as well, so if you rotate 180 degrees
## you actually switch hands on the things you're holding. Speaking of chirality we should
## add some modelled text in the scene so you can actually see the flip." A chicken looks
## much the same either way round. Writing does not. Nobody has to be told what they are
## looking at when the sign by the pen starts reading backwards.
##
## THE LETTERS HAVE REAL DEPTH IN W, deliberately more than anything else on the sign. A
## half turn sends w to minus w as well, so letters thin in W would leave the slice exactly
## as the flip arrived - the one moment the sign exists for is the one it would miss.
##
## A PIXEL FONT, MERGED INTO RUNS. Five by seven, capitals only, and each row's lit pixels
## are joined into one block per run rather than one per pixel - "CHICKENS" is about fifty
## blocks instead of about a hundred and fifty, and per-object cost is what the renderer
## pays for (Trym's measurements, 27 Sept). Letters are drawn in the node's own x-y plane,
## reading left to right towards +x, and face +z.

@export var text: String = "CHICKENS": set = _set_text
## Edge of one pixel of the font, in metres.
@export_range(0.01, 0.5, 0.005) var pixel: float = 0.075: set = _set_pixel
## How far the letters stand proud of the board.
@export_range(0.005, 0.5, 0.005) var relief: float = 0.05: set = _set_pixel
@export_range(0.05, 3.0, 0.05) var w_depth: float = 1.2: set = _set_pixel
@export var letter_colour: Color = Color(0.96, 0.94, 0.86): set = _set_colour
@export var board_colour: Color = Color(0.34, 0.20, 0.11): set = _set_colour
@export var post_colour: Color = Color(0.26, 0.16, 0.09): set = _set_colour
## Height of the board's bottom edge above the ground. Zero leaves the posts off.
@export_range(0.0, 4.0, 0.05) var mount_height: float = 1.1: set = _set_pixel

## Five columns by seven rows, top row first. Only what the signs in this field need, plus
## enough of the alphabet that a new sign is a string and not a font job.
const GLYPHS := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}


func _set_text(v: String) -> void: text = v; _later()
func _set_pixel(_v: float) -> void: _later()
func _set_colour(_v: Color) -> void: _later()


func _ready() -> void:
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	var ink := TetraMaterial4D.new()
	ink.albedo_color = letter_colour
	var wood := TetraMaterial4D.new()
	wood.albedo_color = board_colour
	var post := TetraMaterial4D.new()
	post.albedo_color = post_colour

	var letters: String = text.to_upper()
	var advance: float = pixel * 6.0
	var width: float = maxf(advance * float(letters.length()) - pixel, pixel)
	var height: float = pixel * 7.0
	var margin: float = pixel * 1.5
	var left: float = -width * 0.5
	var bottom: float = mount_height + margin
	# The board, a little bigger than the words, thinner in W than the letters on purpose.
	_block("Board", Vector4(0.0, bottom + height * 0.5, 0.0, 0.0),
		Vector3(width + margin * 2.0, height + margin * 2.0, pixel * 0.6), wood, w_depth * 0.8)
	if mount_height > 0.0:
		for side in [-1.0, 1.0]:
			_block("Post%d" % int(side), Vector4(side * (width * 0.5 + margin * 0.6), (bottom + height + margin) * 0.5, -pixel * 0.35, 0.0),
				Vector3(pixel * 1.2, bottom + height + margin, pixel * 1.2), post, w_depth * 0.8)
	for i in letters.length():
		var glyph: Array = GLYPHS.get(letters[i], GLYPHS[" "])
		var x0: float = left + advance * float(i)
		for row in 7:
			var line: String = glyph[row]
			var col: int = 0
			while col < 5:
				if line[col] != "1":
					col += 1
					continue
				var run: int = col
				while run < 5 and line[run] == "1":
					run += 1
				var cells: float = float(run - col)
				_block("L%d_%d_%d" % [i, row, col],
					Vector4(x0 + (float(col) + cells * 0.5) * pixel,
						bottom + (6.5 - float(row)) * pixel, pixel * 0.3 + relief * 0.5, 0.0),
					Vector3(cells * pixel, pixel, relief), ink, w_depth)
				col = run


func _block(part: String, at: Vector4, size: Vector3, material: TetraMaterial4D, depth: float) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(size.x, size.y, size.z, depth)
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	node.position = at
	return node
