@tool
extends Node4D

## Kit: the gallery's player body, a grown-up block figure after Ramon's reference (4 Oct: "make
## the player character for the room more like this body but keep the face ... a bit more
## mature"; "make sure the characters for the pen stay the same, nothing I want inherited").
## Its own script: it does not extend or change the pen's block avatar
## (LabKit/carried/chickenpen/scripts/block_avatar_4d.gd), so the pen, its people and the other
## labs keep theirs. kit_player.gd puts it on the lab player for the goat room only.
##
## THE HEAD is smaller than the lab player's chibi head and has no ears: a block about a sixth of
## the height with a charcoal cap of hair over the top and down the back, the same colours.
## THE BODY, to the proportions of his turnaround sheet: a white shirt as one block over a
## waistband, a short neck, grey trousers in two blocks a leg (a knee between), slim white sleeves
## in two blocks an arm hanging relaxed at the sides, hands in the head's colour, white
## trainers with dark soles. The head is about a fifth of the height where the chibi's is a
## quarter, which is most of what reads as adult rather than child.
##
## THE RIG is the one block_gait_4d.gd drives, so the walk, the arm swing, carrying and settling
## all work unchanged: hip > knee > ankle and shoulder > elbow pivots with each block hanging below
## its pivot, `torso` (the waistband and head ride on it, so they lean with it) and `head`. The
## gait measures this body (hip height, the knee, the "Shin" block, the "Boot" block for the sole)
## and sizes its stride and its clock to it. STANDING STRAIGHT: the hip stands about 99.5% of the
## leg above the ankle, and kit_player.gd lets the gait use that much of it (its reach_fraction and
## knee_slack; the chibi's settings hold back 3% and 1 cm, which bends a standing knee 18 to 28
## degrees: a crouch on a grown-up figure). Measured standing: about 11 degrees. The stride's
## slack then comes from the walk's dip, as the chibi's does.
##
## NO class_name (engine_gotchas.md).

@export var shirt: Color = Color(0.88, 0.89, 0.91):
	set(v):
		shirt = v
		_later()
@export var trousers: Color = Color(0.45, 0.46, 0.49):
	set(v):
		trousers = v
		_later()
@export var waistband: Color = Color(0.41, 0.42, 0.45):
	set(v):
		waistband = v
		_later()
@export var shoes: Color = Color(0.93, 0.93, 0.94):
	set(v):
		shoes = v
		_later()
@export var soles: Color = Color(0.20, 0.20, 0.22):
	set(v):
		soles = v
		_later()
## The head and the hands.
@export var skin: Color = Color(0.38, 0.39, 0.42):
	set(v):
		skin = v
		_later()
@export var hair: Color = Color(0.20, 0.20, 0.22):
	set(v):
		hair = v
		_later()
## Thickness through W, as the pen's avatar has it.
@export var w_thickness: float = 0.45:
	set(v):
		w_thickness = v
		_later()

## Measurements, in metres from the floor at the avatar's origin, MEASURED off Ramon's turnaround
## sheet (4 Oct, "shoulders too broad, look at ref"): its front view, 430 px for its 180 cm, read
## in pixels by colour (shirt, neck, waistband, trousers, trainer, sole, hands); then his close crop
## of the body: arms hanging straight at the shirt's sides, trouser legs nearly touching, a low
## trainer as wide as the leg with a sole as thick as its white upper; then the concept frames for
## the head and slimmer arms.
const HIP_Y := 0.842
const HIP_X := 0.105
const THIGH := 0.39
const SHIN := 0.346
## The trainer, white upper and dark sole together, from the ankle to the floor: the sole the gait
## stands the leg on. Low, and no wider than the trousers (Ramon, 4 Oct: "the shoes look so dumb,
## make them less high and not extend on the sides beyond the pants").
const SOLE := 0.11
const SOLE_DARK := 0.05
const SHIRT_Y := 1.175
const SHIRT := Vector3(0.41, 0.43, 0.21)
const SHOULDER_Y := 1.39
const SHOULDER_X := 0.27
const NECK := 0.07
## The head block, without its hair.
const HEAD := Vector3(0.25, 0.27, 0.26)
## The arms hang relaxed at the sides (Ramon, 4 Oct), out from the body just enough that the hands
## clear the thighs.
const SPLAY := 2.0
const UPPER_ARM := 0.29
const FOREARM := 0.23

## The parts the gait drives, filled in by rebuild().
var hip_left: Node4D
var hip_right: Node4D
var knee_left: Node4D
var knee_right: Node4D
var ankle_left: Node4D
var ankle_right: Node4D
var shoulder_left: Node4D
var shoulder_right: Node4D
var elbow_left: Node4D
var elbow_right: Node4D
var torso: Node4D
var head: Node4D

var _queued: bool = false


func _ready() -> void:
	rebuild()


func _later() -> void:
	if _queued or not is_node_ready():
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func rebuild() -> void:
	for child in get_children():
		child.free()
	# The shirt is the torso: the gait leans it, and the waistband, neck and head go with it.
	torso = _block(self, "Shirt", Vector4(0.0, SHIRT_Y, 0.0, 0.0), SHIRT, shirt)
	_block(torso, "Waistband", Vector4(0.0, -SHIRT.y * 0.5 - 0.07, 0.0, 0.0), Vector3(0.39, 0.14, 0.20), waistband)
	_block(torso, "Neck", Vector4(0.0, SHIRT.y * 0.5 + NECK * 0.5, 0.0, 0.0), Vector3(0.14, NECK, 0.13), skin)
	# THE HEAD, after the gallery concept frames (Ramon, 4 Oct: "maybe something with the face is
	# off, the head too big ... he looks good here, different head shape"): a smaller block, about
	# a sixth of the height with its hair, the hair a cap over the top and down the back, no ears.
	head = _block(torso, "Head", Vector4(0.0, SHIRT.y * 0.5 + NECK + HEAD.y * 0.5, 0.0, 0.0), HEAD, skin)
	_block(head, "Crown", Vector4(0.0, HEAD.y * 0.5 - 0.01, -0.005, 0.0), Vector3(HEAD.x + 0.02, 0.07, HEAD.z + 0.02), hair)
	_block(head, "Hair", Vector4(0.0, 0.03, -HEAD.z * 0.5 - 0.005, 0.0), Vector3(HEAD.x + 0.02, HEAD.y * 0.72, 0.04), hair)
	_block(head, "Fringe", Vector4(0.0, HEAD.y * 0.5 - 0.055, HEAD.z * 0.5 + 0.004, 0.0), Vector3(HEAD.x + 0.02, 0.04, 0.03), hair)
	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		# Legs: thigh and shin in the trousers, the hip hidden in the waistband, a trainer on its
		# own ankle so the gait can keep it flat: a white upper on a dark sole, stacked, as wide as
		# the trouser leg. The sole is the "Boot" block, as it reaches the floor (the gait reads
		# the sole's height off that name).
		var hip := _pivot(self, "Hip" + tag, Vector4(HIP_X * side, HIP_Y, 0.0, 0.0))
		_block(hip, "Thigh" + tag, Vector4(0.0, -THIGH * 0.5, 0.0, 0.0), Vector3(0.18, THIGH, 0.18), trousers)
		var knee := _pivot(hip, "Knee" + tag, Vector4(0.0, -THIGH, 0.0, 0.0))
		_block(knee, "Shin" + tag, Vector4(0.0, -SHIN * 0.5, 0.0, 0.0), Vector3(0.18, SHIN, 0.18), trousers)
		var ankle := _pivot(knee, "Ankle" + tag, Vector4(0.0, -SHIN, 0.0, 0.0))
		var upper: float = SOLE - SOLE_DARK
		_block(ankle, "Shoe" + tag, Vector4(0.0, -upper * 0.5, 0.06, 0.0), Vector3(0.18, upper, 0.30), shoes)
		_block(ankle, "Boot" + tag, Vector4(0.0, -upper - SOLE_DARK * 0.5, 0.06, 0.0), Vector3(0.18, SOLE_DARK, 0.30), soles)
		# Arms: the shoulder is what the gait swings; under it a fixed splay, then two sleeve
		# blocks, the elbow (the gait bends it) and a hand.
		var shoulder := _pivot(self, "Shoulder" + tag, Vector4(SHOULDER_X * side, SHOULDER_Y, 0.0, 0.0))
		var splay := _pivot(shoulder, "Splay" + tag, Vector4.ZERO)
		splay.basis = Basis4D.from_xy(deg_to_rad(SPLAY) * side)
		_block(splay, "UpperArm" + tag, Vector4(0.0, -UPPER_ARM * 0.5, 0.0, 0.0), Vector3(0.13, UPPER_ARM, 0.14), shirt)
		var elbow := _pivot(splay, "Elbow" + tag, Vector4(0.0, -UPPER_ARM, 0.0, 0.0))
		_block(elbow, "Forearm" + tag, Vector4(0.0, -FOREARM * 0.5, 0.0, 0.0), Vector3(0.125, FOREARM, 0.135), shirt)
		_block(elbow, "Hand" + tag, Vector4(0.0, -FOREARM - 0.065, 0.0, 0.0), Vector3(0.115, 0.13, 0.12), skin)
		if side > 0.0:
			hip_left = hip; knee_left = knee; ankle_left = ankle
			shoulder_left = shoulder; elbow_left = elbow
		else:
			hip_right = hip; knee_right = knee; ankle_right = ankle
			shoulder_right = shoulder; elbow_right = elbow


## A bare node to turn a limb about; its block hangs below it.
func _pivot(parent: Node, part_name: String, at: Vector4) -> Node4D:
	var node := Node4D.new()
	node.name = part_name
	parent.add_child(node)
	node.position = at
	return node


func _block(parent: Node, part_name: String, at: Vector4, size: Vector3, colour: Color) -> Node4D:
	var node := MeshInstance4D.new()
	node.name = part_name
	var box := BoxTetraMesh4D.new()
	box.size = Vector4(size.x, size.y, size.z, w_thickness)
	node.mesh = box
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node
