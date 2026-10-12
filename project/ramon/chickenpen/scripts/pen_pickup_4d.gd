@tool
extends Node4D

## Something to find: Mithra's 4D pocket watch, a golden egg, or a bag of azoth.
##
## IT WAS AN ADA COIN, with the Cardano mark built from dots. Trym asked on 25 Sept for every
## mention of money to come out of the scene, and it became the watch Mithra lost.
##
## A WATCH THAT KEEPS FOUR-DIMENSIONAL TIME, LITERALLY. The case and the face have depth
## through W like everything else, so the watch is solid from any slice. The HANDS do not:
## three pairs of them stand at three different depths along W, each set to a different
## time, each thin enough in W to belong to one slice. Step through W or turn your slice
## while it spins and the watch tells you a different time. The back says it keeps
## four-dimensional time; Mithra took that for a boast. It is the one object in the scene
## that shows the fourth axis doing something to its own geometry rather than hiding it.
##
## ROUND WITHOUT A ROUND PRIMITIVE. The module has boxes and orthoplexes, so the case is
## six rectangles turned thirty degrees apart - a rough twelve-sided plate that reads as
## round at the size it is seen, the same trick the coin used.
##
## FOUND, NOT GIVEN. These sit off the starting slice on purpose. The gauntlet is handed
## over in conversation; these are what the gauntlet is FOR, so they are only reachable by
## doing the thing it teaches.

## THE BAG OF AZOTH (6 Oct 2026, layout A's easter eggs): somebody's stash, hidden off the
## farm's slice at the end of a faint path. A sack tied at the neck with violet crystals
## standing out of it, each at its own depth in W, because azoth is "never wholly in the slice
## you are looking at" (professor_script.gd): step through W and the crystals change. Worth
## [member bag_worth] azoth, which the keeper takes for troughs.
const CELL24 := "res://models/primitives/platonic/24_cell/24_cell.g4b"

## WHITE_EGG (10 Oct 2026, Ramon's walkthrough item 14: "Place three collectible eggs inside the chicken house or pen
## area: Two regular white eggs. One golden egg. Distribute them across W"): the golden egg's shape in an off-white
## shell. Appended last, so the kinds already saved in the scene keep their numbers.
## CLOCK (10 Oct, Ramon's walkthrough item 27: "a second mysterious clock or clock-like artifact" out at the meadow's
## edge, for Mithra): the watch's build in bronze and teal, larger. Appended last, like WHITE_EGG.
enum Kind { POCKET_WATCH, GOLDEN_EGG, AZOTH_BAG, WHITE_EGG, CLOCK }

@export var kind: Kind = Kind.POCKET_WATCH: set = _set_kind
@export_range(0.05, 2.0, 0.01) var size: float = 0.34: set = _set_size
@export_range(0.05, 3.0, 0.05) var w_depth: float = 0.5: set = _set_w
## Turns on the spot, because a collectible that is not moving reads as scenery.
@export_range(0.0, 6.0, 0.1) var spin_speed: float = 1.3
@export_range(0.0, 0.5, 0.01) var bob_height: float = 0.08

@export_group("Colours")
@export var watch_case: Color = Color(0.80, 0.62, 0.30): set = _set_a
@export var watch_face: Color = Color(0.96, 0.93, 0.84): set = _set_b
@export var watch_hands: Color = Color(0.10, 0.09, 0.12): set = _set_e
@export var egg_shell: Color = Color(0.98, 0.80, 0.24): set = _set_c
@export var egg_shine: Color = Color(1.0, 0.94, 0.62): set = _set_d
@export var sack: Color = Color(0.56, 0.44, 0.29): set = _set_f
@export var sack_tie: Color = Color(0.33, 0.24, 0.15): set = _set_g
@export var azoth: Color = Color(0.62, 0.36, 0.95): set = _set_h

@export_group("Bag")
## How many pieces of azoth a bag is worth.
@export_range(1, 6) var bag_worth: int = 2

var _rest_y: float = 0.0
var _clock: float = 0.0


func _set_kind(v: Kind) -> void: kind = v; _later()
func _set_size(v: float) -> void: size = v; _later()
func _set_w(v: float) -> void: w_depth = v; _later()
func _set_a(v: Color) -> void: watch_case = v; _later()
func _set_b(v: Color) -> void: watch_face = v; _later()
func _set_e(v: Color) -> void: watch_hands = v; _later()
func _set_c(v: Color) -> void: egg_shell = v; _later()
func _set_d(v: Color) -> void: egg_shine = v; _later()
func _set_f(v: Color) -> void: sack = v; _later()
func _set_g(v: Color) -> void: sack_tie = v; _later()
func _set_h(v: Color) -> void: azoth = v; _later()


func _ready() -> void:
	_rest_y = position.y
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_clock += delta
	basis = Basis4D.from_zx(_clock * spin_speed)
	position.y = _rest_y + sin(_clock * 2.0) * bob_height


func rebuild() -> void:
	for child in get_children():
		child.free()
	if kind == Kind.POCKET_WATCH or kind == Kind.CLOCK:
		_build_watch()
	elif kind == Kind.AZOTH_BAG:
		_build_bag()
	else:
		_build_egg()


## Where along W each set of hands stands, and the time it shows - hours and minutes. The
## middle set is on the slice you normally see; the others are a short step either way.
const HANDS := [[-0.16, 10, 10], [0.0, 3, 45], [0.16, 7, 25]]


## The case on edge, a cream face each side, the bow and crown on top, twelve ticks, and
## three pairs of hands at three depths along W.
func _build_watch() -> void:
	var clock: bool = kind == Kind.CLOCK
	var brass := TetraMaterial4D.new()
	brass.albedo_color = Color(0.46, 0.36, 0.26) if clock else watch_case
	var cream := TetraMaterial4D.new()
	cream.albedo_color = Color(0.56, 0.74, 0.70) if clock else watch_face
	var ink := TetraMaterial4D.new()
	ink.albedo_color = watch_hands

	var thickness: float = size * 0.22
	for i in 6:
		var plate := _box("Case%d" % i, Vector4.ZERO,
			Vector3(size * 2.0, size * 0.54, thickness), brass)
		plate.basis = Basis4D.from_xy(PI * float(i) / 6.0)
	# The face, a little smaller than the case and standing proud of it on both sides.
	for i in 6:
		for side in [1.0, -1.0]:
			var face := _box("Face%d%s" % [i, "F" if side > 0.0 else "B"],
				Vector4(0.0, 0.0, side * thickness * 0.52, 0.0),
				Vector3(size * 1.72, size * 0.46, thickness * 0.08), cream)
			face.basis = Basis4D.from_xy(PI * float(i) / 6.0)
	# The crown and the bow the chain would hang from.
	_box("Crown", Vector4(0.0, size * 1.06, 0.0, 0.0), Vector3(size * 0.20, size * 0.18, size * 0.20), brass)
	for i in 4:
		var a: float = TAU * float(i) / 4.0
		var bar := _box("Bow%d" % i, Vector4(sin(a) * size * 0.15, size * 1.30 + cos(a) * size * 0.15, 0.0, 0.0),
			Vector3(size * 0.20, size * 0.06, size * 0.06), brass)
		bar.basis = Basis4D.from_xy(a)
	# Twelve ticks, longer at the quarters.
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		var quarter: bool = i % 3 == 0
		for side in [1.0, -1.0]:
			var tick := _box("Tick%d%s" % [i, "F" if side > 0.0 else "B"],
				Vector4(sin(a) * size * 0.72, cos(a) * size * 0.72, side * thickness * 0.58, 0.0),
				Vector3(size * 0.05, size * (0.16 if quarter else 0.09), thickness * 0.06), ink)
			tick.basis = Basis4D.from_xy(-a)
	# THE HANDS, a set per slice. Each is thin in W so it belongs to one depth only, which is
	# what makes the time change as you move through W - see the header.
	for layer in HANDS.size():
		var at_w: float = float(HANDS[layer][0])
		var hour: float = float(HANDS[layer][1]) + float(HANDS[layer][2]) / 60.0
		var minute: float = float(HANDS[layer][2])
		for side in [1.0, -1.0]:
			_hand("Hour%d%s" % [layer, "F" if side > 0.0 else "B"], TAU * hour / 12.0, size * 0.42, size * 0.075,
				side * thickness * 0.62, at_w, ink)
			_hand("Minute%d%s" % [layer, "F" if side > 0.0 else "B"], TAU * minute / 60.0, size * 0.62, size * 0.05,
				side * thickness * 0.64, at_w, ink)


## One hand, pivoted at the centre and pointing at `angle` (clockwise from twelve), sitting
## at depth `at_w` along W with only a thin slice of W to itself.
func _hand(part: String, angle: float, length: float, width: float, z: float, at_w: float,
		material: TetraMaterial4D) -> void:
	var node := _box(part, Vector4(sin(angle) * length * 0.5, cos(angle) * length * 0.5, z, at_w),
		Vector3(width, length, size * 0.03), material)
	var mesh := node.mesh as BoxTetraMesh4D
	var extent: Vector4 = mesh.size
	extent.w = w_depth * 0.24
	mesh.size = extent
	node.basis = Basis4D.from_xy(-angle)


## A blocky egg: stacked slabs, widest below the middle, the way an egg actually is.
func _build_egg() -> void:
	# ONE 24-CELL, NOT EIGHT SLABS (10 Oct, Ramon's walkthrough item 37: "replacing the current stacked-cube egg
	# construction with a simpler form. A single appropriately shaped 24-cell might work well"): the project's own
	# 24-cell, stretched taller than it is wide and as round through W as across, in the egg's colour. One mesh.
	var white: bool = kind == Kind.WHITE_EGG
	var shell := TetraMaterial4D.new()
	shell.albedo_color = Color(0.90, 0.88, 0.84) if white else egg_shell
	var node := MeshInstance4D.new()
	node.name = "Egg"
	node.mesh = load(CELL24) as Mesh4D
	node.material_override = shell
	node.set("allow_projection", false)
	add_child(node)
	node.basis = Basis4D.from_scale(Vector4(0.80, 1.05, 0.80, 0.80) * size)
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root


## A sack: stacked slabs, fat at the bottom and pinched at the neck, a tie round the neck,
## and four crystals standing out of the mouth at four depths in W.
func _build_bag() -> void:
	var cloth := TetraMaterial4D.new()
	cloth.albedo_color = sack
	var tie := TetraMaterial4D.new()
	tie.albedo_color = sack_tie
	var glass := TetraMaterial4D.new()
	glass.albedo_color = azoth
	# height fraction, half-width fraction, from the floor up.
	var slabs := [[-1.0, 0.50], [-0.70, 0.66], [-0.30, 0.70], [0.10, 0.62], [0.40, 0.42], [0.56, 0.22]]
	for i in slabs.size() - 1:
		var low: Array = slabs[i]
		var high: Array = slabs[i + 1]
		var mid: float = (float(low[0]) + float(high[0])) * 0.5
		var span: float = (float(high[0]) - float(low[0])) * size
		var half: float = maxf(float(low[1]), float(high[1])) * size
		_box("Sack%d" % i, Vector4(0.0, mid * size, 0.0, 0.0), Vector3(half * 2.0, span, half * 2.0), cloth)
	_box("Tie", Vector4(0.0, 0.52 * size, 0.0, 0.0), Vector3(size * 0.52, size * 0.08, size * 0.52), tie)
	# [x, z, w, height, tilt]: thin in W, each where a different slice catches it.
	var crystals := [[0.0, 0.0, 0.0, 0.62, 0.0], [0.10, 0.04, 0.14, 0.46, 0.35],
		[-0.08, -0.05, -0.12, 0.50, -0.30], [0.02, -0.09, 0.24, 0.36, 0.2]]
	for i in crystals.size():
		var c: Array = crystals[i]
		var h: float = float(c[3]) * size
		var node: MeshInstance4D = _box("Azoth%d" % i, Vector4(float(c[0]) * size, 0.56 * size + h * 0.5, float(c[1]) * size, float(c[2]) * size),
			Vector3(size * 0.12, h, size * 0.12), glass)
		(node.mesh as BoxTetraMesh4D).size.w = w_depth * 0.22
		node.basis = Basis4D.from_xy(float(c[4]))


func _box(part: String, at: Vector4, box: Vector3, material: TetraMaterial4D) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(box.x, box.y, box.z, w_depth)
	node.mesh = mesh
	node.material_override = material
	# Out of the projection (P): small, and a watch alone is some thirty meshes, which the projection counts twice
	# against the engine's instance limit (10 Oct: the pen's eggs and the clock took the dev look over it).
	node.set("allow_projection", false)
	add_child(node)
	node.position = at
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
	return node
