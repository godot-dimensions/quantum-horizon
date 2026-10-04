@tool
extends Node4D

## Kit: the gallery's player body, a grown-up block figure after Ramon's reference (4 Oct: "make
## the player character for the room more like this body but keep the face ... a bit more
## mature"; "make sure the characters for the pen stay the same, nothing I want inherited").
## Its own script: it does not extend or change the pen's block avatar
## (LabKit/carried/chickenpen/scripts/block_avatar_4d.gd), so the pen, its people and the other
## labs keep theirs. kit_player.gd puts it on the lab player for the goat room only.
##
## THE FACE is the lab player's head as it was: the chibi block head with a charcoal crown and
## back hair, the ears, no eyes, in the same colours.
## THE BODY: a white shirt as one big block over a darker waistband, grey trousers in two blocks a
## leg (a knee between), white sleeves in two blocks an arm, hands in the head's colour, white
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
@export var trousers: Color = Color(0.52, 0.53, 0.56):
	set(v):
		trousers = v
		_later()
@export var waistband: Color = Color(0.40, 0.41, 0.44):
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

## Measurements, in metres from the floor at the avatar's origin.
const HIP_Y := 0.94
const HIP_X := 0.12
const THIGH := 0.42
const SHIN := 0.42
## The trainer reaches this far below the ankle: the sole the gait stands the leg on.
const SOLE := 0.10
const SHIRT_Y := 1.30
const SHIRT := Vector3(0.52, 0.50, 0.30)
const SHOULDER_Y := 1.52
const UPPER_ARM := 0.30
const FOREARM := 0.25

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
	# The shirt is the torso: the gait leans it, and the waistband and the head go with it.
	torso = _block(self, "Shirt", Vector4(0.0, SHIRT_Y, 0.0, 0.0), SHIRT, shirt)
	_block(torso, "Waistband", Vector4(0.0, -SHIRT.y * 0.5 - 0.07, 0.0, 0.0), Vector3(0.46, 0.14, 0.27), waistband)
	# THE FACE, as the lab player had it: the chibi's head without its cap.
	head = _block(torso, "Head", Vector4(0.0, SHIRT.y * 0.5 + 0.18, 0.0, 0.0), Vector3(0.30, 0.32, 0.29), skin)
	_block(head, "Crown", Vector4(0.0, 0.15, 0.0, 0.0), Vector3(0.32, 0.10, 0.31), hair)
	_block(head, "Hair", Vector4(0.0, 0.06, -0.15, 0.0), Vector3(0.31, 0.22, 0.06), hair)
	_block(head, "EarL", Vector4(0.18, 0.02, -0.02, 0.0), Vector3(0.09, 0.05, 0.05), skin)
	_block(head, "EarR", Vector4(-0.18, 0.02, -0.02, 0.0), Vector3(0.09, 0.05, 0.05), skin)
	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		# Legs: thigh and shin in the trousers, a trainer on its own ankle so the gait can keep
		# it flat.
		var hip := _pivot(self, "Hip" + tag, Vector4(HIP_X * side, HIP_Y, 0.0, 0.0))
		_block(hip, "Thigh" + tag, Vector4(0.0, -THIGH * 0.5, 0.0, 0.0), Vector3(0.20, THIGH, 0.21), trousers)
		var knee := _pivot(hip, "Knee" + tag, Vector4(0.0, -THIGH, 0.0, 0.0))
		_block(knee, "Shin" + tag, Vector4(0.0, -SHIN * 0.5, 0.0, 0.0), Vector3(0.19, SHIN, 0.20), trousers)
		var ankle := _pivot(knee, "Ankle" + tag, Vector4(0.0, -SHIN, 0.0, 0.0))
		_block(ankle, "Boot" + tag, Vector4(0.0, -SOLE * 0.5, 0.05, 0.0), Vector3(0.20, SOLE, 0.32), shoes)
		_block(ankle, "Sole" + tag, Vector4(0.0, -SOLE + 0.012, 0.05, 0.0), Vector3(0.21, 0.026, 0.33), soles)
		# Arms: two sleeve blocks and a hand.
		var shoulder := _pivot(self, "Shoulder" + tag, Vector4((SHIRT.x * 0.5 + 0.095) * side, SHOULDER_Y, 0.0, 0.0))
		_block(shoulder, "UpperArm" + tag, Vector4(0.0, -UPPER_ARM * 0.5, 0.0, 0.0), Vector3(0.18, UPPER_ARM, 0.19), shirt)
		var elbow := _pivot(shoulder, "Elbow" + tag, Vector4(0.0, -UPPER_ARM, 0.0, 0.0))
		_block(elbow, "Forearm" + tag, Vector4(0.0, -FOREARM * 0.5, 0.0, 0.0), Vector3(0.17, FOREARM, 0.18), shirt)
		_block(elbow, "Hand" + tag, Vector4(0.0, -FOREARM - 0.065, 0.0, 0.0), Vector3(0.15, 0.14, 0.15), skin)
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
