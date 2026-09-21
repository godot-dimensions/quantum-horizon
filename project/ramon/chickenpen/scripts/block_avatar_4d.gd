@tool
extends Node4D

## A blocky 4D stand-in for a 3D character model.
##
## WHY A STAND-IN. The two controllers being ported here come with real models - a
## rigged GLB plush and a rigged FBX human. Neither can be shown: the 4D renderer swaps
## the viewport onto its own World3D, so a MeshInstance3D is not merely unsliceable, it
## is never drawn at all (tested: 342 lit pixels for a 4D box beside 0 for a 3D one). A
## 3D mesh also has no W, so even forced into the scenario it would look identical in
## every slice - an object smeared through the whole fourth axis.
##
## So the models are REPLACED rather than imported, and the point of this script is that
## the replacement keeps their proportions instead of inventing some.
##
## PLUSH is measured, not guessed. The numbers come from the GLB's own inverse bind
## matrices: hips 0.536 off the floor, the body-and-head blob centred at 0.796 and
## reaching 1.62, shoulders at +-0.520, hips at +-0.186, and a foot whose toe sits 0.175
## forward of the ankle. It is two thirds body, one third leg, which is what makes it
## read as a plush toy rather than a person.
##
## HUMAN is the real-controller's skeleton - root, hips, spine, chest, neck, head,
## shoulders, arms with fingers, thighs, shins, feet, toes - at ORDINARY human
## proportions. Its bone names were read out of the FBX; its measurements were not, so
## unlike PLUSH these are a sensible human and not that specific human.
##
## Every limb is its own node, so a gait can rotate them rigidly. That is the cheapest
## animation there is - moving whole nodes costs nothing measurable, against ~2.5 us per
## tetrahedron per frame to deform a mesh.

enum Build { PLUSH, HUMAN, CHIBI }

@export var build: Build = Build.PLUSH:
	set(value):
		build = value
		if is_node_ready():
			rebuild()

@export var skin: Color = Color(0.55, 0.72, 0.9):
	set(value):
		skin = value
		if is_node_ready():
			rebuild()

@export var accent: Color = Color(0.95, 0.85, 0.35):
	set(value):
		accent = value
		if is_node_ready():
			rebuild()

## Thickness through W. A 4D creature needs a real extent along the fourth axis or it
## vanishes the moment the viewer slices away from it.
@export var w_thickness: float = 0.45:
	set(value):
		w_thickness = value
		if is_node_ready():
			rebuild()

## Parts that a walk cycle drives, filled in by rebuild(). Each is a Node4D pivot with
## the block parented underneath, so rotating the pivot swings the limb from its top
## rather than about its middle.
var hip_left: Node4D
var hip_right: Node4D
var shoulder_left: Node4D
var shoulder_right: Node4D
var torso: Node4D
var head: Node4D


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	match build:
		Build.PLUSH:
			_build_plush()
		Build.CHIBI:
			_build_chibi()
		_:
			_build_human()


## Measured from godot_plush_model.glb. See the note at the top.
func _build_plush() -> void:
	# ROUND, not boxy. The plush is a Kirby-ish blob and a cube reads nothing like it.
	# There is no sphere among the 4D primitives, but an orthoplex - the 4D
	# cross-polytope - is the faceted ball of the set, and at this size it passes.
	torso = _blob(self, "Torso", Vector4(0.0, 1.06, 0.0, 0.0), Vector3(0.95, 1.15, 0.80), skin)
	head = _limb(torso, "Face", Vector4(0.0, 0.26, 0.34, 0.0), Vector3(0.44, 0.26, 0.10), accent)
	shoulder_left = _pivot(self, "ShoulderL", Vector4(0.52, 1.30, 0.0, 0.0))
	_limb(shoulder_left, "ArmL", Vector4(0.10, -0.24, 0.0, 0.0), Vector3(0.20, 0.50, 0.24), skin)
	shoulder_right = _pivot(self, "ShoulderR", Vector4(-0.52, 1.30, 0.0, 0.0))
	_limb(shoulder_right, "ArmR", Vector4(-0.10, -0.24, 0.0, 0.0), Vector3(0.20, 0.50, 0.24), skin)
	hip_left = _pivot(self, "HipL", Vector4(0.186, 0.536, 0.0, 0.0))
	_limb(hip_left, "LegL", Vector4(0.0, -0.27, 0.0, 0.0), Vector3(0.22, 0.54, 0.26), skin)
	_limb(hip_left, "FootL", Vector4(0.0, -0.52, 0.175, 0.0), Vector3(0.24, 0.12, 0.40), accent)
	hip_right = _pivot(self, "HipR", Vector4(-0.186, 0.536, 0.0, 0.0))
	_limb(hip_right, "LegR", Vector4(0.0, -0.27, 0.0, 0.0), Vector3(0.22, 0.54, 0.26), skin)
	_limb(hip_right, "FootR", Vector4(0.0, -0.52, 0.175, 0.0), Vector3(0.24, 0.12, 0.40), accent)


## The real-controller's bone layout at ordinary human proportions.
func _build_human() -> void:
	torso = _limb(self, "Torso", Vector4(0.0, 1.25, 0.0, 0.0), Vector3(0.46, 0.62, 0.26), skin)
	_limb(torso, "Chest", Vector4(0.0, 0.34, 0.0, 0.0), Vector3(0.52, 0.30, 0.28), skin)
	head = _limb(torso, "Head", Vector4(0.0, 0.62, 0.0, 0.0), Vector3(0.26, 0.28, 0.26), accent)
	shoulder_left = _pivot(self, "ShoulderL", Vector4(0.28, 1.72, 0.0, 0.0))
	_limb(shoulder_left, "ArmL", Vector4(0.0, -0.32, 0.0, 0.0), Vector3(0.14, 0.64, 0.16), skin)
	shoulder_right = _pivot(self, "ShoulderR", Vector4(-0.28, 1.72, 0.0, 0.0))
	_limb(shoulder_right, "ArmR", Vector4(0.0, -0.32, 0.0, 0.0), Vector3(0.14, 0.64, 0.16), skin)
	hip_left = _pivot(self, "HipL", Vector4(0.13, 0.94, 0.0, 0.0))
	_limb(hip_left, "LegL", Vector4(0.0, -0.46, 0.0, 0.0), Vector3(0.17, 0.92, 0.19), skin)
	_limb(hip_left, "FootL", Vector4(0.0, -0.90, 0.09, 0.0), Vector3(0.18, 0.09, 0.32), accent)
	hip_right = _pivot(self, "HipR", Vector4(-0.13, 0.94, 0.0, 0.0))
	_limb(hip_right, "LegR", Vector4(0.0, -0.46, 0.0, 0.0), Vector3(0.17, 0.92, 0.19), skin)
	_limb(hip_right, "FootR", Vector4(0.0, -0.90, 0.09, 0.0), Vector3(0.18, 0.09, 0.32), accent)


## Chibi: the Ocarina-of-Time-ish build, which is where this folder is heading - a small
## character who can run about a pen and pick up chickens.
##
## The trick of a chibi is the head. It is about a third of total height, where a real
## human's is an eighth, and everything else shortens to match: 1.35 tall with legs of
## barely half a metre. Those proportions are also kind to a block figure, because a big
## head and stubby limbs is a silhouette that survives being made of cubes.
func _build_chibi() -> void:
	torso = _limb(self, "Torso", Vector4(0.0, 0.80, 0.0, 0.0), Vector3(0.40, 0.42, 0.26), skin)
	head = _limb(torso, "Head", Vector4(0.0, 0.46, 0.0, 0.0), Vector3(0.50, 0.48, 0.46), accent)
	_limb(head, "Cap", Vector4(0.0, 0.28, -0.03, 0.0), Vector3(0.52, 0.16, 0.48), skin)
	_limb(head, "HairL", Vector4(0.30, 0.02, -0.02, 0.0), Vector3(0.10, 0.34, 0.40), skin)
	_limb(head, "HairR", Vector4(-0.30, 0.02, -0.02, 0.0), Vector3(0.10, 0.34, 0.40), skin)
	_limb(head, "Nose", Vector4(0.0, -0.06, 0.26, 0.0), Vector3(0.07, 0.07, 0.08), accent)
	shoulder_left = _pivot(self, "ShoulderL", Vector4(0.25, 0.96, 0.0, 0.0))
	_limb(shoulder_left, "ArmL", Vector4(0.0, -0.17, 0.0, 0.0), Vector3(0.12, 0.34, 0.13), skin)
	shoulder_right = _pivot(self, "ShoulderR", Vector4(-0.25, 0.96, 0.0, 0.0))
	_limb(shoulder_right, "ArmR", Vector4(0.0, -0.17, 0.0, 0.0), Vector3(0.12, 0.34, 0.13), skin)
	hip_left = _pivot(self, "HipL", Vector4(0.12, 0.56, 0.0, 0.0))
	_limb(hip_left, "LegL", Vector4(0.0, -0.25, 0.0, 0.0), Vector3(0.14, 0.50, 0.15), skin)
	_limb(hip_left, "BootL", Vector4(0.0, -0.50, 0.06, 0.0), Vector3(0.16, 0.14, 0.26), accent)
	hip_right = _pivot(self, "HipR", Vector4(-0.12, 0.56, 0.0, 0.0))
	_limb(hip_right, "LegR", Vector4(0.0, -0.25, 0.0, 0.0), Vector3(0.14, 0.50, 0.15), skin)
	_limb(hip_right, "BootR", Vector4(0.0, -0.50, 0.06, 0.0), Vector3(0.16, 0.14, 0.26), accent)


## A bare node to rotate a limb about. The block hangs below it, so the limb swings from
## the joint rather than pivoting around its own middle.
func _pivot(parent: Node, part_name: String, at: Vector4) -> Node4D:
	var node := Node4D.new()
	node.name = part_name
	parent.add_child(node)
	node.position = at
	if Engine.is_editor_hint():
		node.owner = get_tree().edited_scene_root
	return node


## A rounded body part. Same as _limb but built on the orthoplex instead of the box.
func _blob(parent: Node, part_name: String, at: Vector4, size: Vector3, colour: Color) -> Node4D:
	var node := MeshInstance4D.new()
	node.name = part_name
	var ball := OrthoplexTetraMesh4D.new()
	ball.size = Vector4(size.x, size.y, size.z, w_thickness * 1.6)
	node.mesh = ball
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	if Engine.is_editor_hint():
		node.owner = get_tree().edited_scene_root
	return node


func _limb(parent: Node, part_name: String, at: Vector4, size: Vector3, colour: Color) -> Node4D:
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
	if Engine.is_editor_hint():
		node.owner = get_tree().edited_scene_root
	return node
