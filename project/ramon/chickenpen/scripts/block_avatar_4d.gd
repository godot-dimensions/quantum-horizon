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

## Hair, and whether a cap is worn over it. Defaults are the player's, so adding these
## changes nothing that already exists - a second chibi becomes a different person by
## turning the cap off and giving it another hair colour, rather than by a second build.
@export var hair: Color = Color(0.86, 0.72, 0.32)
@export var wear_cap: bool = true
## A ponytail hanging behind the head. Three tapering blocks rather than one, so it reads
## as hanging hair instead of a handle - and so it can be given a slight kick outward at
## the end, which is most of what makes it look like hair at all.
@export var ponytail: bool = false

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
	torso = _blob(self, "Torso", Vector4(0.0, 1.06, 0.0, 0.0), Vector3(1.10, 1.30, 0.95), skin)
	head = _limb(torso, "Face", Vector4(0.0, 0.20, 0.34, 0.0), Vector3(0.44, 0.26, 0.10), accent)
	# Stubby: hips at 0.536 and shoulders at +-0.520, straight off the GLB.
	_pair(0.520, 1.30, 0.26, 0.26, 0.20, 0.24, skin, skin, true)
	_pair(0.186, 0.536, 0.27, 0.27, 0.22, 0.26, skin, accent, false)


## The real-controller's bone layout at ordinary human proportions.
func _build_human() -> void:
	torso = _limb(self, "Torso", Vector4(0.0, 1.25, 0.0, 0.0), Vector3(0.46, 0.62, 0.26), skin)
	_limb(torso, "Chest", Vector4(0.0, 0.34, 0.0, 0.0), Vector3(0.52, 0.30, 0.28), skin)
	head = _limb(torso, "Head", Vector4(0.0, 0.62, 0.0, 0.0), Vector3(0.26, 0.28, 0.26), accent)
	_pair(0.280, 1.72, 0.32, 0.32, 0.14, 0.16, skin, skin, true)
	_pair(0.130, 0.94, 0.46, 0.46, 0.17, 0.19, skin, accent, false)


## Builds a left/right pair of TWO-SEGMENT limbs and records their joints.
##
## Two segments is the point. A limb that is one block can only swing from its root,
## which reads as a stilt; a knee or an elbow is what makes the lower half trail and
## catch up. The second pivot hangs off the first, so bending it moves the shin or the
## forearm and leaves the thigh or upper arm where it is.
func _pair(offset_x: float, joint_y: float, upper_len: float, lower_len: float,
		thickness: float, depth: float, upper_colour: Color, lower_colour: Color,
		is_arm: bool) -> void:
	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		var root_name: String = ("Shoulder" if is_arm else "Hip") + tag
		var joint_name: String = ("Elbow" if is_arm else "Knee") + tag
		var root := _pivot(self, root_name, Vector4(offset_x * side, joint_y, 0.0, 0.0))
		_limb(root, ("UpperArm" if is_arm else "Thigh") + tag,
			Vector4(0.0, -upper_len * 0.5, 0.0, 0.0),
			Vector3(thickness, upper_len, depth), upper_colour)
		var joint := _pivot(root, joint_name, Vector4(0.0, -upper_len, 0.0, 0.0))
		_limb(joint, ("Forearm" if is_arm else "Shin") + tag,
			Vector4(0.0, -lower_len * 0.5, 0.0, 0.0),
			Vector3(thickness * 0.92, lower_len, depth * 0.92), lower_colour)
		var ankle: Node4D = null
		if not is_arm:
			ankle = _pivot(joint, "Ankle" + tag, Vector4(0.0, -lower_len, 0.0, 0.0))
			_limb(ankle, "Foot" + tag, Vector4(0.0, -0.05, depth * 0.5, 0.0),
				Vector3(thickness * 1.15, 0.11, depth * 1.5), lower_colour)
		if side > 0.0:
			if is_arm: shoulder_left = root; elbow_left = joint
			else: hip_left = root; knee_left = joint; ankle_left = ankle
		else:
			if is_arm: shoulder_right = root; elbow_right = joint
			else: hip_right = root; knee_right = joint; ankle_right = ankle


func _build_chibi() -> void:
	# Proportions from the Ocarina-of-Time child reference: the head is about a QUARTER
	# of total height, which is the number that decides whether a figure reads as a child
	# or a short adult. Tunic to mid-thigh, bare legs below it, chunky boots.
	torso = _limb(self, "Tunic", Vector4(0.0, 0.84, 0.0, 0.0), Vector3(0.38, 0.46, 0.24), skin)
	_limb(torso, "Belt", Vector4(0.0, -0.20, 0.0, 0.0), Vector3(0.40, 0.07, 0.26), Color(0.35, 0.22, 0.14))
	head = _limb(torso, "Head", Vector4(0.0, 0.42, 0.0, 0.0), Vector3(0.30, 0.32, 0.29), accent)
	if wear_cap:
		_limb(head, "Cap", Vector4(0.0, 0.21, -0.02, 0.0), Vector3(0.33, 0.14, 0.31), skin)
		_limb(head, "CapTail", Vector4(0.0, 0.16, -0.24, 0.0), Vector3(0.12, 0.10, 0.28), skin)
	else:
		# No cap means the crown shows, so it needs hair on top as well as at the back.
		_limb(head, "Crown", Vector4(0.0, 0.15, 0.0, 0.0), Vector3(0.32, 0.10, 0.31), hair)
	_limb(head, "Hair", Vector4(0.0, 0.06, -0.15, 0.0), Vector3(0.31, 0.22, 0.06), hair)
	if ponytail:
		_limb(head, "Tie", Vector4(0.0, 0.10, -0.19, 0.0), Vector3(0.12, 0.09, 0.08), hair)
		_limb(head, "Tail1", Vector4(0.0, -0.02, -0.24, 0.0), Vector3(0.15, 0.20, 0.13), hair)
		_limb(head, "Tail2", Vector4(0.0, -0.19, -0.27, 0.0), Vector3(0.12, 0.16, 0.11), hair)
		_limb(head, "Tail3", Vector4(0.0, -0.32, -0.31, 0.0), Vector3(0.08, 0.12, 0.08), hair)
	_limb(head, "EarL", Vector4(0.18, 0.02, -0.02, 0.0), Vector3(0.09, 0.05, 0.05), accent)
	_limb(head, "EarR", Vector4(-0.18, 0.02, -0.02, 0.0), Vector3(0.09, 0.05, 0.05), accent)

	# TWO SEGMENTS PER LIMB. The knee is its own pivot hanging off the thigh, so bending
	# it swings the shin without moving the thigh - which is the whole difference between
	# a walk and a pair of stilts.
	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		# THE LEG MUST BE LONGER THAN THE HIP IS HIGH, BUT ONLY JUST.
		#
		# Too short and it cannot reach the floor, sits permanently straight, and every
		# planted foot gets dragged. Too long and the difference has to go somewhere, and
		# the only place it can go is the knee: at 0.36 + 0.36 against a hip 0.62 up and a
		# 0.08 sole, a straight leg reached 0.18 BELOW the ground, so the character stood
		# in a 83-degree squat before it had taken a step. Measured walking, its knee never
		# came straighter than 29 degrees and averaged 66.
		#
		# The hip sits at 0.70, so the stance is 0.62 against a 0.64 leg - 97%, standing
		# straight. The stride is bought by DIPPING from there rather than by crouching
		# permanently and hopping up; see body_bob in block_gait_4d.gd.
		#
		# 0.32 + 0.32 = 0.64 against a 0.62 stance. At the top of the pelvis rise the hip
		# is 0.635 up, which is 99% of the leg - straight, near enough to read as straight -
		# and at the ends of the stride it still has 0.10 of slack to bend into. The slack
		# is also what the stride is made of: sweep is sqrt(leg^2 - stance^2), so a leg
		# sized flush to the stance would stand up beautifully and be unable to step.
		var hip := _pivot(self, "Hip" + tag, Vector4(0.10 * side, 0.70, 0.0, 0.0))
		_limb(hip, "Thigh" + tag, Vector4(0.0, -0.16, 0.0, 0.0), Vector3(0.13, 0.32, 0.14), accent)
		var knee := _pivot(hip, "Knee" + tag, Vector4(0.0, -0.32, 0.0, 0.0))
		_limb(knee, "Shin" + tag, Vector4(0.0, -0.16, 0.0, 0.0), Vector3(0.12, 0.32, 0.13), accent)
		# THE BOOT HANGS OFF AN ANKLE, not off the shin. Rigid to the shin it tips with
		# the leg, which is the single most obviously wrong thing about the walk. Given
		# its own joint the gait can hold it flat, and later roll it for toe-off.
		var ankle := _pivot(knee, "Ankle" + tag, Vector4(0.0, -0.32, 0.0, 0.0))
		_limb(ankle, "Boot" + tag, Vector4(0.0, -0.03, 0.04, 0.0), Vector3(0.15, 0.10, 0.24), Color(0.40, 0.26, 0.16))
		var shoulder := _pivot(self, "Shoulder" + tag, Vector4(0.22 * side, 1.02, 0.0, 0.0))
		_limb(shoulder, "UpperArm" + tag, Vector4(0.0, -0.09, 0.0, 0.0), Vector3(0.10, 0.18, 0.11), skin)
		var elbow := _pivot(shoulder, "Elbow" + tag, Vector4(0.0, -0.18, 0.0, 0.0))
		_limb(elbow, "Forearm" + tag, Vector4(0.0, -0.09, 0.0, 0.0), Vector3(0.09, 0.18, 0.10), accent)
		_limb(elbow, "Hand" + tag, Vector4(0.0, -0.20, 0.0, 0.0), Vector3(0.09, 0.08, 0.10), accent)
		if side > 0.0:
			hip_left = hip; knee_left = knee; ankle_left = ankle
			shoulder_left = shoulder; elbow_left = elbow
		else:
			hip_right = hip; knee_right = knee; ankle_right = ankle
			shoulder_right = shoulder; elbow_right = elbow


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
