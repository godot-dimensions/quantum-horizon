extends Node4D
## Walks a lofted creature using Motion Lab's own solvers, unmodified.
##
## Both of Trym's pieces are used as they stand: gait_controller.gd supplies the phase
## clock, duty factor and per-limb phase offsets, and ik_chain_controller.gd solves each
## leg with FABRIK across ALL of its joints - no two-bone shortcut, so a three-segment
## leg articulates at every joint it has.
##
## FABRIK RUNS ON A SHADOW SKELETON, and the loft balls follow it. That is not
## squeamishness: ik_chain_controller orients a joint by writing its BASIS, and the loft
## applies a ball's basis to its own cross-section, so pointing the solver straight at
## the balls would rotate every section twice - once by the spine frame and again by the
## bone. A parallel chain of plain Node4Ds keeps the two concerns apart: the solver sees
## an ordinary skeleton, the balls only ever receive positions, and every ball's basis
## stays identity.
##
## Reading the solve one frame after it happens is deliberate, and is the same
## one-frame-delayed discipline hip_suspension_solver.gd uses: this node runs at a later
## physics priority than the solvers, takes the pose they just finished, and sets the
## targets they will chase next tick. Nothing in the tick depends on its own output.
##
## MIRRORED LEGS ARE DETACHED FIRST. A generated twin IS its original, so all four legs
## would share one phase and every gait would collapse into a pronk. detach_mirror()
## writes the twin out as real balls - exactly the case it was built for.

const _GaitController = preload("res://scripts/gait_controller.gd")
const _IKChainController = preload("res://scripts/ik_chain_controller.gd")

@export var rig_path: NodePath = NodePath("../Hide")

## Cross-section resolution while animating. Low on purpose: a rebuild of this creature
## costs far more than a frame at full resolution, so this trades roundness for motion.
## Skinning the mesh - binding vertices once and only moving them afterwards - removes
## the trade rather than balancing it, and is the next piece of work.
@export var animation_sides: int = 6
@export var animation_rings: int = 3

## Stride and lift are SMALL FRACTIONS OF LEG REACH, not absolute distances, and that
## matters more than it looks. FABRIK has no hinge limits here - Motion Lab does not set
## any either - so nothing stops it folding a chain back on itself when the target comes
## far inside the chain's own length. Measured: a 0.75 lift took hip-to-hoof from 5.06
## down to 3.34 against a 6.04 chain, and the solver answered with three collinear
## segments doubled back on each other - dead straight legs, off-line 0.00 at every
## joint. Keeping the foot beyond roughly three quarters of full reach keeps the solve
## in the well-behaved region where a knee actually bends.
@export var belt_speed: float = 2.0
@export var stride_length: float = 1.5
@export var step_height: float = 0.28
@export var body_bob: float = 0.10

## The gait clock scales cadence off a "body" carrying these two fields. This node is
## that body, which is why it is a Node4D.
var halted: bool = false
var speed: float = 0.0

var _rig: Node
var _gait: Node
var _legs: Array = []
var _body_ball: Node = null
var _body_rest_y: float = 0.0


func _ready() -> void:
	# After the solvers, never before - see the one-frame note above.
	process_physics_priority = 10
	_rig = get_node_or_null(rig_path)
	if _rig == null or not _rig.has_method("build"):
		push_warning("StriderWalker: rig_path does not point at a loft rig.")
		set_physics_process(false)
		return
	speed = belt_speed
	_rig.verbose = false
	_rig.profile_sides = animation_sides
	_rig.profile_rings = animation_rings
	_detach_mirrors()
	_collect_legs()
	if _legs.is_empty():
		push_warning("StriderWalker: found no legs to walk on.")
		set_physics_process(false)
		return

	_gait = Node.new()
	_gait.set_script(_GaitController)
	_gait.name = "GaitController"
	_gait.standalone_input = false
	# Set BEFORE add_child: the clock resolves its body in an @onready, which fires the
	# moment it enters the tree.
	_gait.body_path = NodePath("..")
	add_child(_gait)
	if _gait.has_method("apply_preset"):
		_gait.apply_preset("walk")


func _detach_mirrors() -> void:
	for ball in _rig.get_children():
		if not ball.has_method("get_loft_section"):
			continue
		for child in ball.get_children():
			if child.has_method("detach_mirror") and bool(child.get("mirror_branch")):
				child.detach_mirror()


## Finds every leg - a chain of balls under a body ball - and gives each its own shadow
## skeleton and FABRIK solver.
func _collect_legs() -> void:
	for ball in _rig.get_children():
		if not ball.has_method("get_loft_section"):
			continue
		for hip in ball.get_children():
			if not hip.has_method("get_loft_section"):
				continue
			var chain: Array = [hip]
			var node: Node = hip
			while true:
				var next: Node = _only_ball_child(node)
				if next == null:
					break
				chain.append(next)
				node = next
			# A LEG DESCENDS. Without this test the neck qualifies too - it is also a
			# chain of balls hanging off a body ball - and FABRIK duly dragged the
			# horse's head down to a foot target on the ground. Requiring the tip to
			# end well below its own anchor separates limbs that reach for the floor
			# from ones that reach for the sky, without hard-coding any names.
			if chain.size() < 3:
				continue
			var anchor_y: float = _rig._position_in_rig(chain[0]).y
			var tip_y: float = _rig._position_in_rig(chain[chain.size() - 1]).y
			if tip_y > anchor_y - 1.0:
				continue
			_legs.append(_build_shadow(chain))

	# Order fore-to-hind then side to side, so the gait's own phase offsets land on the
	# diagonal pairs that make a walk read as a walk.
	_legs.sort_custom(func(a, b):
		var pa: Vector4 = a["anchor"]
		var pb: Vector4 = b["anchor"]
		if not is_equal_approx(pa.z, pb.z):
			return pa.z > pb.z
		return pa.x > pb.x)
	for index in range(_legs.size()):
		_legs[index]["order"] = index

	var first: Node = _rig.get_children()[0] if _rig.get_child_count() > 0 else null
	if first != null and first.has_method("get_loft_section"):
		_body_ball = first
		_body_rest_y = first.position.y


## One shadow chain per leg: plain Node4Ds in the shape the solver expects, with the
## solver itself living on the anchor so its joint paths stay simple.
func _build_shadow(chain: Array) -> Dictionary:
	var anchor_pos: Vector4 = _rig._position_in_rig(chain[0])
	var lengths: Array[float] = []
	for index in range(chain.size() - 1):
		lengths.append(_rig._position_in_rig(chain[index]).distance_to(
			_rig._position_in_rig(chain[index + 1])))

	var anchor := Node4D.new()
	anchor.name = "Shadow_%s" % chain[0].name
	anchor.set_script(_IKChainController)
	anchor.position = anchor_pos

	var parent: Node = anchor
	var paths: Array[NodePath] = []
	var path_text: String = ""
	var joints: Array = []
	for index in range(lengths.size()):
		var joint := Node4D.new()
		joint.name = "J%d" % (index + 1)
		# Seeded down the leg so FABRIK starts from a plausible pose, not a heap.
		joint.position = Vector4() if index == 0 else Vector4(0.0, -float(lengths[index - 1]), 0.0, 0.0)
		parent.add_child(joint)
		path_text = joint.name if index == 0 else "%s/%s" % [path_text, joint.name]
		paths.append(NodePath(path_text))
		joints.append(joint)
		parent = joint

	var target := Node4D.new()
	target.name = "Target"
	target.position = _rig._position_in_rig(chain[chain.size() - 1]) - anchor_pos
	anchor.add_child(target)

	# CONFIGURED BEFORE IT ENTERS THE TREE. The solver resolves its joints and its
	# target in _ready, which fires the instant add_child is called, so anything set
	# afterwards is simply never seen - the chain solved against a target it had not
	# been told about, and answered with the same folded, dead-straight pose no matter
	# what stride or step height it was given. This is the second time in this file
	# that ordering has bitten; the gait clock's body_path was the first.
	anchor.joint_paths = paths
	anchor.link_lengths = lengths
	anchor.target_path = NodePath("Target")
	# KEEP THE BEND OUT OF W. FABRIK in 4D is free to fold a leg through the fourth
	# axis, which satisfies the target perfectly while being invisible in the player's
	# slice - the leg looks rigidly straight and the gait reads as a shuffle. This is
	# the solver's own plane-alignment pass, and it is not optional in 4D the way it
	# would be in 3D.
	anchor.enable_plane_alignment_twist = true
	add_child(anchor)

	return {
		"balls": chain, "joints": joints, "lengths": lengths,
		"anchor": anchor_pos, "target": target,
		"rest_foot": _rig._position_in_rig(chain[chain.size() - 1]),
	}


func _only_ball_child(node: Node) -> Node:
	for child in node.get_children():
		if child.has_method("get_loft_section"):
			return child
	return null


func _physics_process(_delta: float) -> void:
	var phase: float = float(_gait.phase_progress)
	var duty: float = float(_gait.duty_factor)
	var offsets: Array = _gait.phase_offsets

	for leg in _legs:
		_read_solved_pose(leg)
		var order: int = int(leg["order"]) % offsets.size()
		var local_phase: float = fposmod(phase + float(offsets[order]), 1.0)
		var goal: Vector4 = _foot_position(leg, local_phase, duty)
		(leg["target"] as Node4D).position = goal - (leg["anchor"] as Vector4)

	if _body_ball != null:
		# Twice per cycle: a quadruped's trunk falls and rises once per diagonal pair.
		_body_ball.position.y = _body_rest_y + sin(phase * TAU * 2.0) * body_bob


## Copies the pose FABRIK just solved onto the loft balls, as positions only.
##
## Balls are nested with identity bases throughout, so a child's local position is
## simply its offset from its parent - no transform composition needed, and none of the
## solver's joint ROTATIONS reach the sections.
func _read_solved_pose(leg: Dictionary) -> void:
	var joints: Array = leg["joints"]
	var balls: Array = leg["balls"]
	var lengths: Array = leg["lengths"]
	var previous: Vector4 = leg["anchor"]
	for index in range(joints.size()):
		var here: Vector4 = (joints[index] as Node4D).global_position
		if index > 0:
			(balls[index] as Node4D).position = here - previous
		previous = here
	# The last ball sits at the end effector - the final joint's own tip.
	var last: Node4D = joints[joints.size() - 1]
	var tip: Vector4 = last.global_position + last.global_basis.y * float(lengths[lengths.size() - 1])
	(balls[balls.size() - 1] as Node4D).position = tip - last.global_position


## STANCE: the foot is planted, so on a treadmill it tracks backward at belt speed.
## SWING: a quadratic Bezier from lift-off to landing over a raised apex - Trym's own
## swing shape, taken from quadruped-robotics literature.
func _foot_position(leg: Dictionary, local_phase: float, duty: float) -> Vector4:
	var rest: Vector4 = leg["rest_foot"]
	var forward := Vector4(0.0, 0.0, 1.0, 0.0)
	var lift_off: Vector4 = rest - forward * (stride_length * 0.5)
	var landing: Vector4 = rest + forward * (stride_length * 0.5)
	if local_phase < duty:
		return landing.lerp(lift_off, local_phase / maxf(duty, 0.0001))
	var swing: float = (local_phase - duty) / maxf(1.0 - duty, 0.0001)
	var eased: float = swing * swing * (3.0 - 2.0 * swing)
	var apex: Vector4 = (lift_off + landing) * 0.5 + Vector4(0.0, step_height * 2.0, 0.0, 0.0)
	return lift_off.lerp(apex, eased).lerp(apex.lerp(landing, eased), eased)
