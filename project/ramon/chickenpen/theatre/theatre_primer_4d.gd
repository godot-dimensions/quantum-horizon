extends Node

## Four of the talk's slides: how to look at 4D, before the talk shows what was built in it.
##
##   I    WHAT YOU SEE IS A SLICE       a flat chicken on a sheet; a ball and a cone pass
##                                      through its world, and all it ever sees is the cut
##   II   THINGS ARRIVE FROM NOWHERE    the same, one dimension up: a 4D ball and a
##                                      tesseract travel through your slice along W
##   IV   SHAPES WITH NO 3D TWIN        the tiger, spheritorus, ditorus, duocylinder and a
##                                      Klein bottle, each rising and turning through W
##   V    NOW YOU TURN IT               you hold the shapes yourself and turn them
##   VI   A LEFT GLOVE, TURNED, IS A    you turn a left glove into a right one, which no
##        RIGHT GLOVE                   rotation in 3D can do
##
## (III is the mined rock, which theatre_show_4d keeps; VII to IX are part two's.)
##
## THE GLOVE WAS THE BACK HALF OF V, and Ramon did not notice it (30 Sept). Nineteen
## seconds into an open-ended toy is where a thing gets skipped, so it is its own slide
## now, with its own title, its own stop for the arrow keys, and the camera moving in.
##
## WHY A CHICKEN AND NOT FLATLAND'S SQUARE. The audience has just spent the afternoon
## catching these, and the device is the old one - a two-dimensional being on a slice of a
## three-dimensional world, the way 4D Miner and Flatland both explain it - done as a
## shortcut, knowingly (Trym, 30 Sept: take the shortcut for now). What it buys is the next
## slide: once you have watched the chicken see a circle come from nowhere, a sphere doing
## the same thing in front of you is not a glitch, it is the same thing one dimension up.
## And you are the one who can see the chicken's whole world - the clever one, not the
## lost one (the spatial-language notes' framing principle).
##
## THE SLICE AND ITS SHADOW. Everything on the drum is a cross-section: the only way this
## renderer draws anything. The screen over the stage (theatre_screen_4d) shows what the
## cut leaves out - the chicken's flat view on slide I, and from slide II the shadow of the
## whole 4D shape, coloured by W. Two ways of looking at one object, side by side.
##
## THE SHAPES ARE MADE ON A WORKER THREAD when the room opens (theatre_shapes_4d, about a
## tenth of a second of GDScript plus the proxy meshes), so nothing about them is paid on
## the frame you walk in. The pieces that hold them are built on the still beat in the
## chair, with the rest of part one's exhibits.
##
## THE TALK DOES NOT WAIT for you on slides V and VI: they keep their clock, like every
## slide, and the arrows still step back and forth. Somebody who does not touch anything
## sees the shapes turn by themselves, and the glove turned for them.
##
## A LEFT DRAG TURNS THINGS TOO, on those two slides, and only a clean left click moves the
## talk on (see is_hands_on and was_clean_click). A click is "forward" everywhere else, and
## on the one slide that asks you to use the mouse it was an easy way to lose the slide.

const Shapes := preload("res://ramon/chickenpen/theatre/theatre_shapes_4d.gd")
const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

## How fast a drag turns the thing you are holding: the field camera's own rate, so the
## same hand movement turns the same amount here as it turns your slice outside.
@export_range(0.0, 0.02, 0.0005) var turn_per_pixel: float = 0.005

var _table: Node4D
var _metrics: Node
var _screen: Node
var _seat: Node
var _pane: Node
var _material: TetraMaterial4D
var _unit: BoxTetraMesh4D
var _paints: Dictionary = {}
var _task: int = -1
var _made: Dictionary = {}
var _dressed: bool = false
var _current: String = ""
var _pieces: Dictionary = {}

# Slide I.
## A little larger than the ghosts need (Ramon, 1 Oct), so the world has room round them.
const SHEET_W := 5.2
const SHEET_H := 2.8
## How thick everything IN the sheet is - the chicken and the cuts alike, one depth for
## all of it. A slice has no thickness to speak of, and the first version's chicken (three
## centimetres) and cuts (six) read as cut-outs standing in front of the sheet rather than
## things living in it.
const SLICE := 0.012
## The chicken's ground, above the turntable, and how far below it the sheet runs.
const FLOOR_Y := 0.55
const SHEET_DROP := 0.3
const STRIPS := 26
const BALL_X := 0.55
const BALL_R := 0.72
const CONE_X := 0.55
const CONE_R := 0.82
const CONE_H := 1.75
var _chicken: Node4D
var _chicken_head: Node4D
var _ghost_ball: Node4D
var _ghost_cone: Node4D
var _ball_cut: Array[MeshInstance4D] = []
var _cone_cut: Array[MeshInstance4D] = []
var _hop: float = 0.0
var _saw_something: bool = false
var _flat_beat: String = ""

# Slide II.
var _ball: MeshInstance4D
var _cube_pivot: Node4D
var _cube: MeshInstance4D
var _visitor_beat: String = ""

# Slide IV.
var _zoo: Array[Node4D] = []
var _zoo_slot: int = -1
## The plane each shape turns in: the one that changes its slice, which is not always the
## obvious one - the spheritorus's big circle lies in x-w, so turning it in x-w would spin
## that circle in its own plane and change nothing at all.
const TURNS := {"tiger": "xw", "spheritorus": "zw", "ditorus": "zw", "duocylinder": "xw", "klein": "xw"}
const SHAPE_Y := 1.9
## A fifth bigger than they are built: the ditorus's two tori were a pair of bangles from
## the seat. On the mesh node, under the pivot that turns it, so the shadow - drawn from the
## pivot's turn - keeps the proportions it is drawn in.
const ZOO_SCALE := 1.2

# Slide V.
var _toy: Array[Node4D] = []
var _toy_index: int = 0
var _toy_xw: float = 0.0
var _toy_zw: float = 0.0
var _toy_idle: float = 99.0
var _toy_cycle: float = 0.0
var _left_glove: Node4D
var _right_glove: Node4D
var _glove_turn: float = 0.0
var _glove_done: bool = false
var _toy_stage: String = ""
var _touched: bool = false
var _glove_started: bool = false
# The left button on the hands-on slides: held, how far it has moved, and when anything
# last turned an exhibit - so a drag is never mistaken for a click.
var _left_down: bool = false
var _left_moved: float = 0.0
var _last_turn_msec: int = -100000


func setup(table: Node4D, metrics: Node, screen: Node, seat: Node, pane: Node = null) -> void:
	_table = table
	_metrics = metrics
	_screen = screen
	_seat = seat
	_pane = pane
	# On the main thread: the colour cube is a texture, and textures are the renderer's.
	_material = TerrainBake.material()
	_unit = BoxTetraMesh4D.new()
	_unit.size = Vector4.ONE
	_task = WorkerThreadPool.add_task(_make_shapes, false, "theatre shapes")


func _make_shapes() -> void:
	var made := {"hyperball": Shapes.hyperball(), "tesseract": Shapes.tesseract()}
	for entry in Shapes.ZOO:
		made[entry["id"]] = Shapes.zoo_mesh(String(entry["id"]))
	# The proxy is built the first time a mesh is drawn, and that first draw is the hitch;
	# the cave's far room moved it here for the same reason (141 ms down to 17).
	for id in made:
		var mesh: Mesh4D = made[id]
		if mesh != null and mesh.has_method("get_proxy_mesh_3d"):
			mesh.call("get_proxy_mesh_3d")
	_made = made


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## The shapes, waiting for the worker if it has not finished. By the still beat in the
## chair it always has - the room has been open for seconds by then.
func meshes() -> Dictionary:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if not _dressed:
		_dressed = true
		for id in _made:
			(_made[id] as ArrayTetraMesh4D).material = _material
	return _made


func tetra_count(ids: Array) -> int:
	var total := 0
	var all: Dictionary = meshes()
	for id in ids:
		if all.has(id):
			total += (all[id] as ArrayTetraMesh4D).simplex_cell_vertex_indices.size() / 4
	return total


## The caption's placeholders, filled from the exhibits themselves.
func fill(text: String) -> String:
	if not text.contains("{"):
		return text
	var zoo: Array = []
	for entry in Shapes.ZOO:
		zoo.append(entry["id"])
	return text.replace("{ball_tetra}", _grouped(tetra_count(["hyperball"]))) \
		.replace("{zoo_tetra}", _grouped(tetra_count(zoo)))


func _grouped(value: int) -> String:
	var digits: String = str(value)
	var out: String = ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out


# ---------------------------------------------------------------- building blocks

func _paint(colour: Color) -> TetraMaterial4D:
	var key: String = colour.to_html()
	if not _paints.has(key):
		var m := TetraMaterial4D.new()
		m.albedo_color = colour
		_paints[key] = m
	return _paints[key]


## A box of [param size] (all four axes), turned by [param turn], from one shared unit mesh:
## every box on these slides is the same mesh scaled, so none of them costs a proxy of its own.
func _box(parent: Node, part: String, at: Vector4, size: Vector4, colour: Color,
		turn: Projection = Projection.IDENTITY) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = _unit
	node.material_override = _paint(colour)
	parent.add_child(node)
	node.position = at
	node.basis = turn * Basis4D.from_scale(size)
	return node


## A bar from [param a] to [param b] in 3D, [param thick] across, [param w] through W.
func _bar(parent: Node, part: String, a: Vector3, b: Vector3, thick: float, colour: Color,
		w: float = 0.5) -> MeshInstance4D:
	var along: Vector3 = b - a
	var length: float = along.length()
	var x: Vector3 = along / maxf(length, 0.0001)
	var helper: Vector3 = Vector3.UP if absf(x.y) < 0.9 else Vector3.RIGHT
	var z: Vector3 = x.cross(helper).normalized()
	var y: Vector3 = z.cross(x)
	var frame := Projection(Vector4(x.x, x.y, x.z, 0.0), Vector4(y.x, y.y, y.z, 0.0),
		Vector4(z.x, z.y, z.z, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))
	var mid: Vector3 = (a + b) * 0.5
	return _box(parent, part, Vector4(mid.x, mid.y, mid.z, 0.0),
		Vector4(length + thick * 0.6, thick, thick, w), colour, frame)


## A ring of bars round [param centre], in the plane of [param u] and [param v].
func _ring(parent: Node, part: String, centre: Vector3, u: Vector3, v: Vector3, radius: float,
		thick: float, colour: Color, segments: int = 28) -> void:
	for i in segments:
		var t0: float = TAU * float(i) / float(segments)
		var t1: float = TAU * float(i + 1) / float(segments)
		_bar(parent, "%s%d" % [part, i], centre + (u * cos(t0) + v * sin(t0)) * radius,
			centre + (u * cos(t1) + v * sin(t1)) * radius, thick, colour)


func _mesh_node(parent: Node, part: String, mesh: Mesh4D) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = mesh
	parent.add_child(node)
	return node


func _piece(part: String) -> Node4D:
	var piece := Node4D.new()
	piece.name = part
	_table.add_child(piece)
	_pieces[part] = piece
	return piece


# ---------------------------------------------------------------- building the slides

func build(id: String) -> Node4D:
	match id:
		"chicken":
			return _build_sheet()
		"visitors":
			return _build_visitors()
		"zoo":
			return _build_zoo()
		"toy":
			return _build_toy()
		"glove":
			return _build_gloves()
	return null


## The chicken's world: a glowing sheet standing across the drum, facing the house, with
## its floor line, a flat chicken standing on it, and two ghosts - a ball and a cone drawn
## only as wire, so you can see through them to the part the sheet actually cuts.
##
## WIRE, BECAUSE A SOLID WOULD HIDE THE CUT. The cut is inside the solid by definition;
## drawn solid, the ball would cover the very circle the slide is about. As rings of bars,
## you see the ball AND the bright disc where it meets the sheet.
func _build_sheet() -> Node4D:
	var piece := _piece("FlatWorld")
	# THE SHEET ITSELF IS NOT BUILT HERE AT ALL - its glow, its edges, its floor line and
	# its grid are all drawn over the picture, translucent, by theatre_pane_4d (see that
	# file for why the renderer cannot do it). The mesh frame they replace read as a solid
	# object; Ramon, 1 Oct: brighter, and a bit transparent.

	_chicken = _flat_chicken(piece)
	_chicken.position = Vector4(-1.35, FLOOR_Y, 0.0, 0.0)

	var ghost := Color(0.72, 0.82, 1.0)
	_ghost_ball = Node4D.new()
	_ghost_ball.name = "GhostBall"
	piece.add_child(_ghost_ball)
	var o := Vector3.ZERO
	_ring(_ghost_ball, "Equator", o, Vector3.RIGHT, Vector3.BACK, BALL_R, 0.026, ghost)
	_ring(_ghost_ball, "MeridianA", o, Vector3.RIGHT, Vector3.UP, BALL_R, 0.026, ghost)
	_ring(_ghost_ball, "MeridianB", o, Vector3.BACK, Vector3.UP, BALL_R, 0.026, ghost)
	for k in [-1.0, 1.0]:
		_ring(_ghost_ball, "Latitude%d" % int(k), Vector3(0.0, k * BALL_R * 0.55, 0.0),
			Vector3.RIGHT, Vector3.BACK, BALL_R * sqrt(1.0 - 0.55 * 0.55), 0.022, ghost, 22)
	_ghost_ball.visible = false

	_ghost_cone = Node4D.new()
	_ghost_cone.name = "GhostCone"
	piece.add_child(_ghost_cone)
	_ring(_ghost_cone, "Base", o, Vector3.RIGHT, Vector3.BACK, CONE_R, 0.026, ghost)
	_ring(_ghost_cone, "Middle", Vector3(0.0, CONE_H * 0.5, 0.0), Vector3.RIGHT, Vector3.BACK,
		CONE_R * 0.5, 0.022, ghost, 20)
	for i in 10:
		var a: float = TAU * float(i) / 10.0
		_bar(_ghost_cone, "Slant%d" % i, Vector3(cos(a), 0.0, sin(a)) * CONE_R,
			Vector3(0.0, CONE_H, 0.0), 0.024, ghost)
	_ghost_cone.visible = false

	# The cuts: a stack of thin strips in the sheet, re-sized every frame to the chord the
	# sheet makes through the ghost at each height. Strips rather than a mesh because they
	# can be re-sized by their basis alone, with no mesh rebuilt.
	for i in STRIPS:
		_ball_cut.append(_box(piece, "BallCut%d" % i, Vector4.ZERO, Vector4(0.01, 0.01, SLICE, 0.5),
			Color(1.0, 0.62, 0.20)))
		_cone_cut.append(_box(piece, "ConeCut%d" % i, Vector4.ZERO, Vector4(0.01, 0.01, SLICE, 0.5),
			Color(0.45, 1.0, 0.55)))
	for strip in _ball_cut + _cone_cut:
		strip.visible = false
	return piece


## The chicken, flat: a paper cut-out of boxes standing in the sheet, side on, facing the
## middle of its world. Its head is its own node so it can peck.
func _flat_chicken(parent: Node) -> Node4D:
	var bird := Node4D.new()
	bird.name = "FlatChicken"
	parent.add_child(bird)
	var body := Node4D.new()
	body.name = "Body"
	bird.add_child(body)
	body.basis = Basis4D.from_scale_uniform(1.55)
	var white := Color(0.97, 0.95, 0.90)
	var shade := Color(0.86, 0.84, 0.80)
	var red := Color(0.92, 0.18, 0.16)
	var yellow := Color(1.0, 0.76, 0.18)
	# The slice's depth in the bird's own (scaled) frame, and how far the wing and the eye
	# sit proud of the body - just enough to be drawn over it, no more.
	var thin: float = SLICE / 1.55
	var proud: float = thin * 0.6
	var w: float = 0.5
	_box(body, "Belly", Vector4(0.0, 0.30, 0.0, 0.0), Vector4(0.46, 0.20, thin, w), white)
	_box(body, "Back", Vector4(-0.01, 0.32, 0.0, 0.0), Vector4(0.34, 0.30, thin, w), white)
	_box(body, "Tail", Vector4(-0.25, 0.42, 0.0, 0.0), Vector4(0.12, 0.20, thin, w), white,
		Basis4D.from_xy(-0.45))
	_box(body, "Wing", Vector4(-0.03, 0.31, proud, 0.0), Vector4(0.24, 0.11, thin, w), shade)
	for dx in [-0.05, 0.05]:
		_box(body, "Leg%d" % int(signf(dx)), Vector4(dx, 0.10, 0.0, 0.0), Vector4(0.03, 0.20, thin, w), yellow)
		_box(body, "Foot%d" % int(signf(dx)), Vector4(dx + 0.035, 0.012, 0.0, 0.0),
			Vector4(0.10, 0.024, thin, w), yellow)
	_chicken_head = Node4D.new()
	_chicken_head.name = "Head"
	body.add_child(_chicken_head)
	_chicken_head.position = Vector4(0.14, 0.40, 0.0, 0.0)
	_box(_chicken_head, "Neck", Vector4(0.02, 0.05, 0.0, 0.0), Vector4(0.12, 0.16, thin, w), white)
	_box(_chicken_head, "Skull", Vector4(0.06, 0.16, 0.0, 0.0), Vector4(0.16, 0.14, thin, w), white)
	_box(_chicken_head, "Comb", Vector4(0.06, 0.255, 0.0, 0.0), Vector4(0.13, 0.05, thin, w), red)
	_box(_chicken_head, "Beak", Vector4(0.165, 0.15, 0.0, 0.0), Vector4(0.07, 0.045, thin, w), yellow)
	_box(_chicken_head, "Wattle", Vector4(0.115, 0.09, 0.0, 0.0), Vector4(0.04, 0.06, thin, w), red)
	_box(_chicken_head, "Eye", Vector4(0.095, 0.175, proud, 0.0), Vector4(0.03, 0.03, thin, w),
		Color(0.05, 0.05, 0.08))
	return bird


## The visitors: a 4D ball and a tesseract, both off along W until their beat.
func _build_visitors() -> Node4D:
	var piece := _piece("Visitors")
	var all: Dictionary = meshes()
	_ball = _mesh_node(piece, "Ball", all["hyperball"])
	_ball.visible = false
	_cube_pivot = Node4D.new()
	_cube_pivot.name = "TesseractPivot"
	piece.add_child(_cube_pivot)
	_cube = _mesh_node(_cube_pivot, "Tesseract", all["tesseract"])
	_cube_pivot.visible = false
	return piece


func _build_zoo() -> Node4D:
	var piece := _piece("Zoo")
	var all: Dictionary = meshes()
	for entry in Shapes.ZOO:
		var pivot := Node4D.new()
		pivot.name = String(entry["name"]).capitalize().replace(" ", "")
		piece.add_child(pivot)
		_mesh_node(pivot, "Shape", all[entry["id"]]).basis = Basis4D.from_scale_uniform(ZOO_SCALE)
		pivot.visible = false
		_zoo.append(pivot)
	return piece


func _build_toy() -> Node4D:
	var piece := _piece("Toy")
	var all: Dictionary = meshes()
	for entry in Shapes.ZOO:
		var pivot := Node4D.new()
		pivot.name = String(entry["name"]).capitalize().replace(" ", "")
		piece.add_child(pivot)
		_mesh_node(pivot, "Shape", all[entry["id"]]).basis = Basis4D.from_scale_uniform(ZOO_SCALE)
		pivot.position = Vector4(0.0, SHAPE_Y, 0.0, 0.0)
		pivot.visible = false
		_toy.append(pivot)
	return piece


## Two gloves on the drum, a left and a right.
func _build_gloves() -> Node4D:
	var piece := _piece("Gloves")
	_left_glove = _glove(piece, "LeftGlove", 1.0)
	_left_glove.position = Vector4(-1.15, 1.0, 0.0, 0.0)
	_right_glove = _glove(piece, "RightGlove", -1.0)
	_right_glove.position = Vector4(1.15, 1.0, 0.0, 0.0)
	return piece


## A glove, palm towards the house. [param thumb] is which side its thumb is on: that is
## the whole of its handedness, so the thumb is gold and nothing else is.
func _glove(parent: Node, part: String, thumb: float) -> Node4D:
	var glove := Node4D.new()
	glove.name = part
	parent.add_child(glove)
	var hand := Node4D.new()
	hand.name = "Hand"
	glove.add_child(hand)
	hand.basis = Basis4D.from_scale_uniform(2.4)
	var cloth := Color(0.82, 0.88, 1.0)
	var cuff := Color(0.30, 0.55, 0.95)
	var gold := Color(1.0, 0.78, 0.25)
	var w: float = 0.3
	_box(hand, "Cuff", Vector4(0.0, -0.06, 0.0, 0.0), Vector4(0.36, 0.14, 0.12, w), cuff)
	_box(hand, "Palm", Vector4(0.0, 0.18, 0.0, 0.0), Vector4(0.34, 0.36, 0.11, w), cloth)
	for i in 4:
		var x: float = -0.12 + 0.08 * float(i)
		var tall: float = [0.20, 0.26, 0.28, 0.24][i] if thumb > 0.0 else [0.24, 0.28, 0.26, 0.20][i]
		_box(hand, "Finger%d" % i, Vector4(x, 0.36 + tall * 0.5, 0.0, 0.0), Vector4(0.065, tall, 0.09, w), cloth)
	_box(hand, "Thumb", Vector4(thumb * 0.215, 0.19, 0.0, 0.0), Vector4(0.08, 0.20, 0.09, w), gold,
		Basis4D.from_xy(thumb * -0.55))
	return glove


# ---------------------------------------------------------------- running the slides

## Called by the show as a slide of ours starts. Everything is put back where the slide
## starts from, whichever way it was reached - forwards, or back from the next one.
func enter(id: String) -> void:
	_current = id
	_clear_metrics()
	_hop = 0.0
	_saw_something = false
	_flat_beat = ""
	_visitor_beat = ""
	_zoo_slot = -1
	_toy_stage = ""
	_glove_started = false
	_left_down = false
	_left_moved = 0.0
	if _pane != null and id != "chicken":
		_pane.call("hide_pane")
	match id:
		"chicken":
			if _screen != null:
				_screen.call("show_flat", "THE CHICKEN'S WHOLE WORLD",
					Rect2(-SHEET_W * 0.5, -SHEET_DROP, SHEET_W, SHEET_H))
			if _pane != null and _pieces.has("FlatWorld"):
				_pane.call("show_pane", _pieces["FlatWorld"],
					Rect2(-SHEET_W * 0.5, FLOOR_Y - SHEET_DROP, SHEET_W, SHEET_H), FLOOR_Y)
		"visitors", "zoo":
			if _screen != null:
				_screen.call("hide_screen")
		"toy":
			_toy_index = 0
			_toy_xw = 0.0
			_toy_zw = 0.0
			_toy_idle = 99.0
			_toy_cycle = 0.0
			_touched = false
			if _screen != null:
				_screen.call("hide_screen")
		"glove":
			_glove_turn = 0.0
			_glove_done = false
			_touched = false
			if _left_glove != null:
				_left_glove.basis = Projection.IDENTITY
			if _screen != null:
				_screen.call("hide_screen")


## And as the talk moves off our slides - onto the rock, or on to part two.
func leave() -> void:
	_current = ""
	if _screen != null:
		_screen.call("hide_screen")
	if _pane != null:
		_pane.call("hide_pane")
	_clear_metrics()


func current() -> String:
	return _current


func _clear_metrics() -> void:
	if _metrics != null and _metrics.has_method("clear"):
		_metrics.call("clear")


func _say_figures(figures: Array, keep: bool = false) -> void:
	if _metrics != null and _metrics.has_method("show_metrics"):
		_metrics.call("show_metrics", figures, keep)


func demonstrate(id: String, t: float, span: float, delta: float) -> void:
	var tau: float = clampf(t / maxf(span, 0.01), 0.0, 1.0)
	match id:
		"chicken":
			_run_sheet(tau, delta)
		"visitors":
			_run_visitors(tau)
		"zoo":
			_run_zoo(tau, span)
		"toy":
			_run_toy(tau, delta)
		"glove":
			_run_gloves(tau, delta)


## Where [param at] above the turntable is in the room, for anchoring a figure to it. Not
## turned with the table: a label that swung round with the spin would walk off its subject.
func _world(at: Vector4) -> Vector4:
	return _table.global_position + at


# ---- I

func _run_sheet(tau: float, delta: float) -> void:
	var ball_at: float = clampf((tau - 0.08) / 0.38, 0.0, 1.0)
	var cone_at: float = clampf((tau - 0.52) / 0.38, 0.0, 1.0)
	var ball_z: float = lerpf(-2.3, 2.3, ball_at)
	var cone_z: float = lerpf(-2.2, 2.2, cone_at)
	_ghost_ball.visible = tau > 0.06 and tau < 0.48
	_ghost_cone.visible = tau > 0.50 and tau < 0.94
	_ghost_ball.position = Vector4(BALL_X, FLOOR_Y + BALL_R, ball_z, 0.0)
	_ghost_cone.position = Vector4(CONE_X, FLOOR_Y, cone_z, 0.0)
	var shapes: Array = []
	var ball_outline: PackedVector2Array = _cut_ball(ball_z if _ghost_ball.visible else 99.0)
	var cone_outline: PackedVector2Array = _cut_cone(cone_z if _ghost_cone.visible else 99.0)
	if ball_outline.size() > 2:
		shapes.append([ball_outline, Color(1.0, 0.62, 0.20)])
	if cone_outline.size() > 2:
		shapes.append([cone_outline, Color(0.45, 1.0, 0.55)])

	# The chicken: pecks, and jumps when something appears in its world out of nowhere.
	var something: bool = not shapes.is_empty()
	if something and not _saw_something:
		_hop = 0.55
	_saw_something = something
	var lift: float = 0.0
	if _hop > 0.0:
		_hop = maxf(0.0, _hop - delta)
		lift = sin((1.0 - _hop / 0.55) * PI) * 0.32
	_chicken.position = Vector4(-1.35, FLOOR_Y + lift, 0.0, 0.0)
	var peck: float = 0.0 if something else maxf(0.0, sin(Time.get_ticks_msec() * 0.004)) * 0.6
	_chicken_head.basis = Basis4D.from_xy(-peck)
	if _screen != null:
		_screen.call("set_flat", shapes, Vector3(-1.35, lift, 1.0))

	# The two figures that say it: the ball as it is, and all of it the chicken gets.
	var beat: String = "ball" if _ghost_ball.visible else ("cone" if _ghost_cone.visible else "")
	if beat != "":
		var ghost: Node4D = _ghost_ball if beat == "ball" else _ghost_cone
		var top: Vector4 = ghost.position + Vector4(0.0, BALL_R + 0.15 if beat == "ball" else CONE_H - 0.1, 0.0, 0.0)
		var figures: Array = [{"at": _world(top), "value": "3D", "side": 1.0,
			"label": "the %s, as it really is" % beat, "colour": Color(0.72, 0.82, 1.0)}]
		if something:
			figures.append({"at": _world(Vector4(-SHEET_W * 0.5 + 0.2, FLOOR_Y + 1.6, 0.0, 0.0)),
				"value": "2D", "side": -1.0, "label": "all the chicken ever sees of it",
				"colour": Color(1.0, 0.70, 0.30)})
		_say_figures(figures, beat == _flat_beat)
	elif _flat_beat != "":
		_clear_metrics()
	_flat_beat = beat


## Sizes the ball's strips to the sheet's cut through it, [param z] from the sheet, and
## returns the cut's outline in sheet coordinates. Nothing when the ball is clear of it.
func _cut_ball(z: float) -> PackedVector2Array:
	var r: float = sqrt(maxf(0.0, BALL_R * BALL_R - z * z))
	var centre_y: float = FLOOR_Y + BALL_R
	return _size_strips(_ball_cut, BALL_X, centre_y - r, centre_y + r,
		func(y: float) -> float: return sqrt(maxf(0.0, r * r - (y - centre_y) * (y - centre_y))), r > 0.02)


## The same for the cone, standing on the floor with its point up: a triangle when the sheet
## runs through its axis, a curve with a flat foot when it does not.
func _cut_cone(z: float) -> PackedVector2Array:
	var d: float = absf(z)
	var top: float = FLOOR_Y + CONE_H * (1.0 - d / CONE_R)
	return _size_strips(_cone_cut, CONE_X, FLOOR_Y, top, func(y: float) -> float:
		var rho: float = CONE_R * (1.0 - (y - FLOOR_Y) / CONE_H)
		return sqrt(maxf(0.0, rho * rho - d * d)), d < CONE_R - 0.02)


func _size_strips(strips: Array[MeshInstance4D], x: float, y0: float, y1: float, half: Callable,
		on: bool) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var step: float = (y1 - y0) / float(strips.size())
	for i in strips.size():
		var y: float = y0 + step * (float(i) + 0.5)
		var h: float = float(half.call(y)) if on else 0.0
		var strip: MeshInstance4D = strips[i]
		strip.visible = on and h > 0.004
		if strip.visible:
			strip.position = Vector4(x, y, 0.0, 0.0)
			strip.basis = Basis4D.from_scale(Vector4(h * 2.0, step * 1.08, SLICE, 0.5))
			left.append(Vector2(x - h, y))
			right.append(Vector2(x + h, y))
	if left.size() < 2:
		return PackedVector2Array()
	# The ends of the outline, so the flat picture is not cut short by half a strip.
	var outline := PackedVector2Array([Vector2(x, y0)])
	outline.append_array(left)
	outline.append(Vector2(x, y1))
	right.reverse()
	outline.append_array(right)
	return outline


# ---- II

## The corner-first turn: the rotation that stands the tesseract on one corner along W,
## so its long diagonal (1, 1, 1, 1) points straight through your slice. A Householder
## reflection does that in one step, and flipping x afterwards makes it a rotation again -
## a reflected basis would wind every tetrahedron backwards and the renderer would cull
## the lot.
static func _corner_first() -> Projection:
	var d := Vector4(0.5, 0.5, 0.5, 0.5)
	var v: Vector4 = d - Vector4(0.0, 0.0, 0.0, 1.0)
	var k: float = 2.0 / v.length_squared()
	var cols: Array[Vector4] = []
	for i in 4:
		var e := Vector4.ZERO
		e[i] = 1.0
		var c: Vector4 = e - v * (v[i] * k)
		c.x = -c.x
		cols.append(c)
	return Projection(cols[0], cols[1], cols[2], cols[3])


func _run_visitors(tau: float) -> void:
	var ball_at: float = clampf((tau - 0.05) / 0.33, 0.0, 1.0)
	var face_at: float = clampf((tau - 0.42) / 0.20, 0.0, 1.0)
	var corner_at: float = clampf((tau - 0.66) / 0.30, 0.0, 1.0)
	var beat: String = ""
	if tau > 0.03 and tau < 0.40:
		beat = "ball"
	elif tau > 0.40 and tau < 0.64:
		beat = "face"
	elif tau > 0.64:
		beat = "corner"
	_ball.visible = beat == "ball"
	_cube_pivot.visible = beat == "face" or beat == "corner"
	var ball_w: float = lerpf(1.2, -1.2, _smooth(ball_at))
	_ball.position = Vector4(0.0, 1.75, 0.0, ball_w)
	var cube_w: float = lerpf(1.05, -1.05, _smooth(face_at)) if beat == "face" \
		else lerpf(1.45, -1.45, _smooth(corner_at))
	_cube_pivot.position = Vector4(0.0, 1.75, 0.0, cube_w)
	_cube_pivot.basis = _corner_first() if beat == "corner" else Projection.IDENTITY

	if beat != _visitor_beat and _screen != null:
		if beat == "ball":
			_screen.call("show_shadow", "ITS SHADOW: ALL OF IT, AT ONCE", Shapes.shadow_lines("hyperball"))
		elif beat == "face":
			_screen.call("show_shadow", "ITS SHADOW: A CUBE INSIDE A CUBE", Shapes.shadow_lines("tesseract"))
		figures_for_visitor(beat)
	_visitor_beat = beat
	if _screen != null and beat != "":
		var pivot: Node4D = _ball if beat == "ball" else _cube_pivot
		var w: float = ball_w if beat == "ball" else cube_w
		_screen.call("set_shadow", _table.basis * pivot.basis, Vector4(0.0, 0.0, 0.0, w))


func figures_for_visitor(beat: String) -> void:
	# On the left of the exhibit: the screen over the stage has the right.
	var at: Vector4 = _world(Vector4(-1.5, 2.9, 0.0, 0.0))
	match beat:
		"ball":
			_say_figures([{"at": at, "value": "4D BALL", "side": -1.0,
				"label": "every sphere you see is one slice of it", "colour": Color(0.95, 0.75, 1.0)}])
		"face":
			_say_figures([{"at": at, "value": "TESSERACT", "side": -1.0,
				"label": "face first: a cube, whole, then gone", "colour": Color(1.0, 0.82, 0.40)}])
		"corner":
			_say_figures([{"at": at, "value": "TESSERACT", "side": -1.0,
				"label": "corner first: a point, a pyramid, an octahedron", "colour": Color(1.0, 0.82, 0.40)}])
		_:
			_clear_metrics()


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# ---- IV

func _turn(id: String, angle: float) -> Projection:
	match String(TURNS.get(id, "xw")):
		"zw":
			return Basis4D.from_zw(angle)
		"yw":
			return Basis4D.from_wy(angle)
	return Basis4D.from_xw(angle)


func _run_zoo(tau: float, _span: float) -> void:
	var count: int = _zoo.size()
	var slot: int = mini(count - 1, int(floor(tau * float(count))))
	var local: float = tau * float(count) - float(slot)
	var id: String = String(Shapes.ZOO[slot]["id"])
	for i in count:
		_zoo[i].visible = i == slot
	var pivot: Node4D = _zoo[slot]
	# Up, then HELD on the slice its nameplate describes ("its slice: two balls") long
	# enough to read the plate against it, then turned a quarter of the way round through W
	# and back, then down. The hold is the claim; the turn is what makes it a 4D one.
	var rise: float = _smooth(clampf(local / 0.12, 0.0, 1.0))
	var sink: float = _smooth(clampf((local - 0.9) / 0.1, 0.0, 1.0))
	pivot.position = Vector4(0.0, lerpf(-2.4, SHAPE_Y, rise) - sink * 4.3, 0.0, 0.0)
	var turn: float = clampf((local - 0.34) / 0.54, 0.0, 1.0)
	pivot.basis = _turn(id, PI * 0.5 * pow(sin(PI * turn), 2.0))
	if slot != _zoo_slot:
		_zoo_slot = slot
		var entry: Dictionary = Shapes.ZOO[slot]
		_say_figures([{"at": _world(Vector4(-1.7, 3.1, 0.0, 0.0)), "value": String(entry["name"]),
			"side": -1.0, "label": String(entry["recipe"]), "colour": Color(0.80, 0.90, 1.0)}])
		if _screen != null:
			_screen.call("show_shadow", "ITS SHADOW", Shapes.shadow_lines(id))
	if _screen != null:
		_screen.call("set_shadow", _table.basis * pivot.basis)


# ---- V

func _run_toy(_tau: float, delta: float) -> void:
	if _toy_stage == "":
		_toy_stage = "shapes"
		_say_figures([{"at": _world(Vector4(-1.7, 3.1, 0.0, 0.0)), "value": "YOUR TURN",
			"side": -1.0, "label": "hold the right mouse button and drag. Scroll for the next shape",
			"colour": Color(0.80, 0.90, 1.0)}])
		if _screen != null:
			_screen.call("show_shadow", "ITS SHADOW", Shapes.shadow_lines(String(Shapes.ZOO[_toy_index]["id"])))
	_toy_idle += delta
	# Nobody at the controls: it turns itself and moves on every few seconds, so the slide
	# is never a still picture of a shape waiting to be touched.
	if _toy_idle > 2.5:
		_toy_xw += delta * 0.55
		_toy_zw = 0.35 * sin(_toy_xw * 0.7)
		_toy_cycle += delta
		if _toy_cycle > 6.0:
			_toy_cycle = 0.0
			_next_toy(1)
	for i in _toy.size():
		_toy[i].visible = i == _toy_index
	var pivot: Node4D = _toy[_toy_index]
	pivot.basis = Basis4D.from_xw(_toy_xw) * Basis4D.from_zw(_toy_zw)
	if _screen != null:
		_screen.call("set_shadow", _table.basis * pivot.basis)


# ---- VI

## Two gloves; turn the left one half way round through W. Turned for you if you have not
## done it by just past half way, so a player who only watches still sees it happen - and
## then it holds, matched, for the rest of the slide.
func _run_gloves(tau: float, delta: float) -> void:
	if not _glove_started:
		_glove_started = true
		_glove_figures()
	if not _glove_done and tau > 0.58:
		_glove_turn = move_toward(_glove_turn, PI, delta * 1.1)
	_check_glove()
	_left_glove.basis = Basis4D.from_xw(_glove_turn)


## Half a turn round, either way, and it is a right glove: snapped the rest of the way, and
## said so. Checked as you drag, not only once a frame, so the answer comes on the movement
## that earned it.
func _check_glove() -> void:
	if _glove_done:
		return
	if absf(fposmod(_glove_turn, TAU) - PI) < 0.12:
		_glove_done = true
		_glove_turn = PI
		_glove_figures()


func _glove_figures() -> void:
	var left: Vector4 = _world(_left_glove.position + Vector4(0.0, 1.95, 0.0, 0.0))
	var right: Vector4 = _world(_right_glove.position + Vector4(0.0, 1.95, 0.0, 0.0))
	if _glove_done:
		_say_figures([{"at": left, "value": "RIGHT", "side": -1.0,
			"label": "turned, not mirrored", "colour": Color(1.0, 0.82, 0.30)},
			{"at": right, "value": "RIGHT", "side": 1.0, "label": "the real one",
			"colour": Color(0.80, 0.90, 1.0)}])
	else:
		_say_figures([{"at": left, "value": "LEFT", "side": -1.0,
			"label": "drag sideways to turn it through W", "colour": Color(1.0, 0.82, 0.30)},
			{"at": right, "value": "RIGHT", "side": 1.0, "label": "make the left one match",
			"colour": Color(0.80, 0.90, 1.0)}])


func _next_toy(step: int) -> void:
	_toy_index = posmod(_toy_index + step, _toy.size())
	if _screen != null and _current == "toy":
		_screen.call("show_shadow", "ITS SHADOW", Shapes.shadow_lines(String(Shapes.ZOO[_toy_index]["id"])))


## Whether the slide on now is one you drive with the mouse (V and VI).
func is_hands_on() -> bool:
	return _current == "toy" or _current == "glove"


## Whether the left button just went up as a CLICK rather than the end of a drag: it barely
## moved while it was down, and nothing was being turned a moment ago. The show asks this
## on the release, and only moves on if it is.
func was_clean_click() -> bool:
	return _left_moved < 8.0 and Time.get_ticks_msec() - _last_turn_msec > 600


## Right mouse held and dragged turns whatever you are holding - and so does the left,
## here, because it is the drag people reach for first; the wheel changes shape. Turning
## only while you are seated: on your feet the same drag already turns your own slice
## (pen_orbit_rig_4d), and doing both at once would be two hands on one wheel. The left
## button is followed either way, so the show can tell a click from a drag.
func _unhandled_input(event: InputEvent) -> void:
	if not is_hands_on():
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_left_down = true
			_left_moved = 0.0
		else:
			_left_down = false
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _left_down:
		_left_moved += motion.relative.length()
	if _seat != null and _seat.has_method("is_seated") and not bool(_seat.call("is_seated")):
		return
	if motion != null and (Input.is_action_pressed(&"rotate_4d") or _left_down):
		_toy_idle = 0.0
		_touched = true
		_last_turn_msec = Time.get_ticks_msec()
		if _current == "toy":
			_toy_xw -= motion.relative.x * turn_per_pixel
			_toy_zw += motion.relative.y * turn_per_pixel
		elif not _glove_done:
			_glove_turn -= motion.relative.x * turn_per_pixel
			_check_glove()
		get_viewport().set_input_as_handled()
		return
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed and _current == "toy" \
			and (wheel.button_index == MOUSE_BUTTON_WHEEL_UP or wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_toy_idle = 0.0
		_toy_cycle = 0.0
		_touched = true
		_next_toy(1 if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		get_viewport().set_input_as_handled()


## For the tests: whether somebody has taken hold of it this visit.
func was_touched() -> bool:
	return _touched


func glove_done() -> bool:
	return _glove_done
