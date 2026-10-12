extends Node
## Keeps each foot addressed to the GROUND rather than to the leg above it.
##
## THE GAP THIS BRIDGES: ik_chain_controller.gd solves the leg to put the ANKLE on the
## foot target, and it is free to arrive there from any angle. Nothing in that solve
## knows which way is down, so a foot rigidly parented to the lower leg inherits
## whatever tilt the shin happened to converge to and spends the stance phase pointing
## into or out of the ground.
##
## WHY THE FOOT IS NOT A FOURTH IK JOINT: FABRIK would then treat it as reach, swinging
## the foot to help the chain hit its target. A foot's job is the opposite - to stay put
## and flat while the leg above it moves. So the chain still ends at the ankle, and this
## runs afterwards as a separate pass.
##
## RUNS AT PRIORITY 2, after the chains solve at 1 and the gait places targets at -1.
## Reading a lower leg's orientation before FABRIK has set it would level every foot
## against last frame's pose.
##
## It does not raycast. Ground adaptation per foot is a later item in
## PROCEDURAL_CREATURE_ANIMATION_SYSTEM.md's stack (section 3, step 3); this assumes the
## flat plane the lab actually has, and takes the height as a parameter so a raycast can
## replace it without touching the rest.

@export var creature_path: NodePath = NodePath("../Creature")

## The height at which an ankle counts as PLANTED - not the ground surface itself.
##
## These differ, and the difference showed up as a measurement: the gait puts its foot
## targets at y = 0.05, so a resting ankle sits 0.05 up. Against a ground_y of 0 the
## flatten weight never reached 1 even with the foot down, and planted feet measured
## 18 degrees off flat. Matching this to the target height is what makes a planted foot
## actually flat.
@export var ground_y: float = 0.05

## Which way the foot bone points when flat. The creature faces -X, and a foot runs
## forward from the ankle to the toe.
@export var forward: Vector4 = Vector4(-1.0, 0.0, 0.0, 0.0)

## How far above the ground a foot has to lift before it stops being levelled and goes
## back to following the shin. Without this the foot stays rigidly flat at the top of a
## swing, which reads as a dangling plank rather than a relaxing ankle.
##
## MEASURED, not guessed: the swing lifts the ankle to about 0.26 (a quadratic Bezier
## peaks at half its apex control point, so step_height 0.42 gives 0.21, on top of the
## 0.05 rest height). At the 0.55 this started as, the fade never reached zero and the
## toe-lift below never engaged at all - the verify run recorded zero lifted samples.
@export_range(0.05, 2.0, 0.01) var flatten_fade_height: float = 0.2

## Toe lift at the top of the swing, once levelling has faded out. Small on purpose -
## it is the difference between a foot and a stick, not a dance move.
@export_range(0.0, 45.0, 1.0, "suffix:°") var swing_toe_lift: float = 14.0

var _feet: Array[Dictionary] = []


func _ready() -> void:
	# After ik_chain_controller.gd's own priority 1: a foot can only be levelled once
	# the shin it hangs off has been solved for this frame.
	process_physics_priority = 2
	var creature: Node4D = get_node_or_null(creature_path) as Node4D
	if creature == null:
		push_warning("FootGroundSolver: creature_path does not resolve.")
		set_physics_process(false)
		return
	_collect(creature)
	if _feet.is_empty():
		push_warning("FootGroundSolver: found no Foot rigs under any Lower segment.")
		set_physics_process(false)


func _collect(node: Node) -> void:
	if node.name == StringName("Foot"):
		var shin: Node4D = node.get_parent() as Node4D
		if shin != null:
			_feet.append({"foot": node as Node4D, "shin": shin})
	for child in node.get_children():
		_collect(child)


func _physics_process(_delta: float) -> void:
	for entry in _feet:
		var foot: Node4D = entry["foot"]
		var shin: Node4D = entry["shin"]
		# The shin's own bone direction, which is the convention the IK chain uses.
		var shin_dir: Vector4 = shin.global_basis.y
		var ankle_height: float = foot.global_position.y - ground_y
		# 1 when planted, easing to 0 as the foot lifts clear.
		var flatten: float = clampf(1.0 - ankle_height / maxf(flatten_fade_height, 0.0001), 0.0, 1.0)

		# Flat means: along travel, with no vertical component at all.
		var flat: Vector4 = Vector4(forward.x, 0.0, forward.z, forward.w)
		if flat.length() < 0.0001:
			flat = Vector4(-1.0, 0.0, 0.0, 0.0)
		flat = flat.normalized()
		# Lifted means: carry on out of the shin, with the toe picked up a little.
		var lifted: Vector4 = shin_dir.normalized()
		lifted = (lifted + Vector4(0.0, 1.0, 0.0, 0.0) * sin(deg_to_rad(swing_toe_lift))).normalized()

		var desired: Vector4 = lifted.lerp(flat, flatten)
		if desired.length() < 0.0001:
			continue
		desired = desired.normalized()
		# The foot is a child of the shin, so its own basis has to undo the shin's
		# rotation before applying the orientation we actually want in world space.
		foot.basis = _rotation_between(Vector4(0, 1, 0, 0), shin.global_basis.inverse() * desired)


## The rotation taking direction [param from] onto direction [param to].
##
## In 4D a rotation has no axis - it lives in a PLANE - so this builds the rotation in
## the plane the two directions span and leaves everything perpendicular untouched,
## which is the minimal rotation between them.
func _rotation_between(from: Vector4, to: Vector4) -> Projection:
	if from.length() < 0.000001 or to.length() < 0.000001:
		return Projection.IDENTITY
	var a: Vector4 = from.normalized()
	var target: Vector4 = to.normalized()
	var cos_t: float = clampf(a.dot(target), -1.0, 1.0)
	if cos_t > 0.999999:
		return Projection.IDENTITY
	var b: Vector4 = target - a * cos_t
	if b.length() < 0.000001:
		b = _any_perpendicular(a)
	b = b.normalized()
	var sin_t: float = sqrt(maxf(1.0 - cos_t * cos_t, 0.0))
	return Projection(
		_rotate_vector(Vector4(1, 0, 0, 0), a, b, cos_t, sin_t),
		_rotate_vector(Vector4(0, 1, 0, 0), a, b, cos_t, sin_t),
		_rotate_vector(Vector4(0, 0, 1, 0), a, b, cos_t, sin_t),
		_rotate_vector(Vector4(0, 0, 0, 1), a, b, cos_t, sin_t))


## R x = x + (cos-1)[(a.x)a + (b.x)b] + sin[(a.x)b - (b.x)a] for the orthonormal
## plane (a, b): sends a to cos*a + sin*b and fixes anything outside that plane.
func _rotate_vector(x: Vector4, a: Vector4, b: Vector4, cos_t: float, sin_t: float) -> Vector4:
	var ax: float = a.dot(x)
	var bx: float = b.dot(x)
	return x + a * ((cos_t - 1.0) * ax - sin_t * bx) + b * ((cos_t - 1.0) * bx + sin_t * ax)


func _any_perpendicular(a: Vector4) -> Vector4:
	for candidate in [Vector4(0, 1, 0, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]:
		var p: Vector4 = candidate - a * a.dot(candidate)
		if p.length() > 0.001:
			return p
	return Vector4(0, 1, 0, 0)
