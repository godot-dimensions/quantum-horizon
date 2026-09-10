extends Node4D
## Walks a lofted creature by driving its balls, reusing Motion Lab's gait clock.
##
## WHAT THIS BORROWS, and what it does not. The timing is Trym's: gait_controller.gd
## supplies the phase clock, the duty factor (what fraction of a cycle a foot is on the
## ground) and the per-limb phase offsets that make a walk a walk rather than four legs
## hopping together. The swing trajectory is his shape too - a Bezier from lift-off to
## landing with a raised apex, which he took from quadruped-robotics literature.
##
## What it does NOT borrow is FABRIK. Motion Lab's ik_chain_controller.gd orients each
## joint by writing its BASIS, and the loft now applies a ball's basis to its own
## cross-section - so letting FABRIK drive the balls directly would rotate every
## section twice, once by the spine frame and again by the bone. A two-bone leg has a
## closed-form solution anyway, so this writes POSITIONS only and leaves every basis at
## identity. Pointing FABRIK at a shadow skeleton that the balls merely follow is the
## better long-term answer, and is the obvious next step; it is not needed to find out
## whether a lofted surface can be animated at all, which is what this is for.
##
## MIRRORED LEGS HAVE TO BE DETACHED FIRST. The rig generates a limb's twin from the
## authored one, so while mirroring is on both sides are the same limb and cannot hold
## different phases - every gait would collapse into a pronk. detach_mirror() writes
## the twin out as real balls, which is precisely the case it was built for.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")
const _GaitController = preload("res://scripts/gait_controller.gd")

## Which rig to walk. Its leg branches are found by name.
@export var rig_path: NodePath = NodePath("..")

## Cross-section resolution used while animating. Deliberately low: a rebuild costs
## about 106 ms at 10 sides x 5 rings, which is six frames' worth. Cost falls roughly
## with sides x rings, so this trades roundness for a moving creature. The real fix is
## to skin the mesh instead of rebuilding it - see the note in _physics_process.
@export var animation_sides: int = 6
@export var animation_rings: int = 3

## Metres per second the ground appears to move under the creature. It walks in place,
## treadmill-style, exactly as Motion Lab does - the alternative is chasing it around.
@export var belt_speed: float = 1.6

## How far forward of its rest position a foot reaches at the top of its swing.
@export var stride_length: float = 1.1

## How high a foot lifts at the apex of its swing.
@export var step_height: float = 0.42

## How far the body dips and rises over a stride. Small, and at twice gait frequency:
## a quadruped's trunk falls and rises once per DIAGONAL pair, not once per cycle.
@export var body_bob: float = 0.09

## The gait clock reads its cadence off a "body" with these two fields (it scales
## stride frequency with actual speed rather than running at a fixed period). This
## walker IS that body - it is a Node4D for exactly that reason - so there is no
## separate mover to keep in sync with the legs.
var halted: bool = false
var speed: float = 0.0

var _rig: Node
var _gait: Node
var _legs: Array = []
var _body_rest_y: float = 0.0
var _body_ball: Node = null


func _ready() -> void:
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
	# Set BEFORE add_child: the gait clock resolves its body in an @onready, which runs
	# the moment it enters the tree, so assigning the path afterwards is too late.
	_gait.body_path = NodePath("..")
	add_child(_gait)
	if _gait.has_method("apply_preset"):
		_gait.apply_preset("walk")


## Turns each generated twin into real balls, so the four legs can hold four different
## phases. Without this every gait is a pronk - all four legs in lockstep.
## Detaches only the branches that are ACTUALLY mirrored - the legs.
##
## Detaching everything gave the horse two heads. A branch on the midline, like the
## neck, is never mirrored in the first place, so "detaching" it does not free a twin
## to move independently; it manufactures a duplicate that was not there. The rig
## already knows which branches earn a twin, so ask it rather than detaching blind:
## a branch is mirrored only if it sits clear of the mirror plane.
func _detach_mirrors() -> void:
	var axis: int = _rig.mirror_axis_index() if _rig.has_method("mirror_axis_index") else 0
	for ball in _rig.get_children():
		if not ball.has_method("get_loft_section"):
			continue
		var plane: float = _axis_of(_rig._position_in_rig(ball), axis)
		for child in ball.get_children():
			if not child.has_method("detach_mirror") or not bool(child.get("mirror_branch")):
				continue
			if absf(_axis_of(_rig._position_in_rig(child), axis) - plane) < 0.001:
				continue # On the midline: single by design, and must stay single.
			child.detach_mirror()


func _axis_of(point: Vector4, axis: int) -> float:
	match axis:
		1: return point.z
		2: return point.w
	return point.x


## A leg is any chain of three balls hanging off a body ball. Recorded with its rest
## pose so the gait can be expressed as an offset from where the creature stands.
func _collect_legs() -> void:
	for ball in _rig.get_children():
		if not ball.has_method("get_loft_section"):
			continue
		for hip in ball.get_children():
			if not hip.has_method("get_loft_section"):
				continue
			var knee: Node = _only_ball_child(hip)
			if knee == null:
				continue
			var foot: Node = _only_ball_child(knee)
			if foot == null:
				continue
			var hip_world: Vector4 = _rig._position_in_rig(hip)
			# A LEG DESCENDS. The neck is also a chain of balls hanging off a body ball,
			# so without this it qualified as a leg and got driven at a foot target on
			# the floor - the horse nodding its head at every step.
			if _rig._position_in_rig(foot).y > hip_world.y - 1.0:
				continue
			var foot_world: Vector4 = _rig._position_in_rig(foot)
			_legs.append({
				"hip": hip, "knee": knee, "foot": foot,
				"hip_world": hip_world,
				"rest_foot": foot_world,
				"upper": hip_world.distance_to(_rig._position_in_rig(knee)),
				"lower": _rig._position_in_rig(knee).distance_to(foot_world),
			})
	# Phase offsets follow the gait's own list, assigned by how far forward and which
	# side each leg sits - the diagonal pairing that makes a walk read as a walk.
	_legs.sort_custom(func(a, b):
		var pa: Vector4 = a["hip_world"]
		var pb: Vector4 = b["hip_world"]
		if not is_equal_approx(pa.z, pb.z):
			return pa.z > pb.z
		return pa.x > pb.x)
	for index in range(_legs.size()):
		_legs[index]["order"] = index
	var body: Node = _rig.get_children()[0] if _rig.get_child_count() > 0 else null
	if body != null and body.has_method("get_loft_section"):
		_body_ball = body
		_body_rest_y = body.position.y


func _only_ball_child(node: Node) -> Node:
	for child in node.get_children():
		if child.has_method("get_loft_section"):
			return child
	return null


func _physics_process(_delta: float) -> void:
	# Rebuilding the whole mesh every frame is the honest bottleneck here, and is why
	# the resolution is turned down. Skinning - binding each vertex to its section once
	# and only moving vertices afterwards - would remove it entirely: moving all of a
	# creature's vertices measured 0.06 ms, against 106 ms to rebuild. That is the next
	# piece of work, not a subtlety.
	var phase: float = float(_gait.phase_progress)
	var duty: float = float(_gait.duty_factor)
	var offsets: Array = _gait.phase_offsets

	for leg in _legs:
		var order: int = int(leg["order"]) % offsets.size()
		var local_phase: float = fposmod(phase + float(offsets[order]), 1.0)
		leg["foot_goal"] = _foot_position(leg, local_phase, duty)

	# The trunk rises and falls at twice the gait frequency - once per diagonal pair.
	if _body_ball != null:
		_body_ball.position.y = _body_rest_y + sin(phase * TAU * 2.0) * body_bob

	for leg in _legs:
		_place_leg(leg, leg["foot_goal"])


## Where a foot should be at this point in its own cycle.
##
## STANCE (local_phase < duty): the foot is planted, so in a treadmill it slides
## backward at belt speed - the ground moving under a creature that stays put.
## SWING: a quadratic Bezier from where it left the ground to where it will land, with
## a raised apex. Trym's shape, and the reason a leg arcs over rather than dragging.
func _foot_position(leg: Dictionary, local_phase: float, duty: float) -> Vector4:
	var rest: Vector4 = leg["rest_foot"]
	var forward := Vector4(0.0, 0.0, 1.0, 0.0)
	var lift_off: Vector4 = rest - forward * (stride_length * 0.5)
	var landing: Vector4 = rest + forward * (stride_length * 0.5)
	if local_phase < duty:
		var t: float = local_phase / maxf(duty, 0.0001)
		return landing.lerp(lift_off, t)
	var swing_t: float = (local_phase - duty) / maxf(1.0 - duty, 0.0001)
	# Ease so the foot leaves and arrives slowly and crosses quickly.
	var eased: float = swing_t * swing_t * (3.0 - 2.0 * swing_t)
	var apex: Vector4 = (lift_off + landing) * 0.5 + Vector4(0.0, step_height * 2.0, 0.0, 0.0)
	var one: Vector4 = lift_off.lerp(apex, eased)
	var two: Vector4 = apex.lerp(landing, eased)
	return one.lerp(two, eased)


## Closed-form two-bone IK. The knee lands on the circle where the two segment spheres
## intersect, pushed out along a bend direction so it flexes the right way rather than
## snapping to whichever side the maths happened to pick.
func _place_leg(leg: Dictionary, goal: Vector4) -> void:
	var hip: Vector4 = leg["hip_world"]
	var upper: float = float(leg["upper"])
	var lower: float = float(leg["lower"])
	var to_goal: Vector4 = goal - hip
	var reach: float = to_goal.length()
	if reach < 0.0001:
		return
	# A leg cannot be longer than it is, nor fold through itself.
	reach = clampf(reach, absf(upper - lower) + 0.02, upper + lower - 0.02)
	var direction: Vector4 = to_goal.normalized()
	var along: float = (reach * reach + upper * upper - lower * lower) / (2.0 * reach)
	var out: float = sqrt(maxf(upper * upper - along * along, 0.0))

	# Bend backwards, in the plane of travel: take -Z, remove the part along the leg.
	var bend := Vector4(0.0, 0.0, -1.0, 0.0)
	bend -= direction * bend.dot(direction)
	if bend.length() < 0.001:
		bend = Vector4(0.0, 0.0, 0.0, 1.0)
		bend -= direction * bend.dot(direction)
	bend = bend.normalized()

	var knee_world: Vector4 = hip + direction * along + bend * out
	var foot_world: Vector4 = hip + direction * reach
	# Balls are nested, so a child's position is its offset from its parent.
	(leg["knee"] as Node4D).position = knee_world - hip
	(leg["foot"] as Node4D).position = foot_world - knee_world
