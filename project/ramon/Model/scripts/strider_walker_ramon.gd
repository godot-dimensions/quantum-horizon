## A fork of strider_walker.gd, for the brachiosaurus in rigged_creature_ramon.tscn.
##
## The original drives the horse in animation_test.tscn and is left exactly as it was on
## 10 Sep. Everything here that differs from it is because a forty-unit sauropod is not a
## horse: it SKINS its mesh instead of re-lofting it every frame, it TRAVELS instead of
## walking on a treadmill, and it has to be told which branches are legs because its TAIL
## passes the "a leg descends" test and would otherwise be walked on.
##
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
## Only branches whose first ball's name starts with one of these count as legs. Empty
## means "any descending chain of three balls", which is how the horse was collected.
## The brachiosaurus needs it: its TAIL drops five units from the body ball it hangs
## off, so it passes the descent test and the creature tries to walk on it.
@export var leg_name_prefixes: PackedStringArray = PackedStringArray()

## How far from a leg's own line a vertex can sit and still be carried by it. Wide
## enough to take the whole limb, narrow enough to leave the belly behind.
## How often the mesh is re-posed, in frames. Handing vertices back makes the engine
## rebuild the whole proxy mesh, which measured 18.97 ms on the brachiosaurus - 6.6 us
## per cell, far worse per cell than a chicken's leg because this animal is forty units
## tall and covers most of the screen. Drawing it without touching it costs 0.40 ms.
## A sauropod at a slow walk does not need a fresh pose sixty times a second, so this
## divides the cost directly. The IK still runs every frame; only the mesh lags.
@export_range(1, 6, 1) var skin_every: int = 3

@export var leg_influence: float = 4.5

## Prints how many vertices ended up bound, which is the quick way to see a binding that
## has caught the whole body or none of it.
@export var verbose_skin: bool = false

@export var animation_sides: int = 6
@export var animation_rings: int = 3

## Metres per second the ground appears to move under the creature. On its own this is
## a treadmill - it walks in place, exactly as Motion Lab does.
@export var belt_speed: float = 1.6

## Whether it actually goes anywhere. Off by default: Motion Lab and the horse were
## built to be watched from one spot.
##
## The travel speed is NOT a separate number to tune. A planted foot slides backward
## through rig space at stride_length per stance, so the creature has to move forward at
## exactly that rate or the feet will skate. It is derived from the gait every frame.
@export var travel: bool = false

## NOTE: it walks in a straight line. Turning was tried and removed. Yawing the whole
## creature swings its planted feet around its centre - a foot fifteen units out drags
## half a unit a second at only 1.5 deg/s - so a turn has to be steered into the foot
## TARGETS, which is a gait change rather than a transform. Until then, straight.

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

# Preloaded rather than reached by its class_name: a global class is only registered
# once the editor has scanned the project, so a class_name reference fails outright in
# a headless run. The other scripts here preload for the same reason.
const _Plane = preload("res://ramon/Model/scripts/plane_rotation_4d.gd")

var _rig: Node
var _bound: bool = false
var _skin_maths := 0.0
var _skin_upload := 0.0
var _skin_frames := 0
var _since_skin := 0
var _rig_rest_y: float = 0.0
var _rest_verts := PackedVector4Array()
var _posed := PackedVector4Array()
var _skin_index := PackedInt32Array()
var _skin_leg := PackedInt32Array()
var _skin_weight := PackedFloat32Array()
var _skin_shank := PackedFloat32Array()
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
	if _rig is Node4D:
		_rig_rest_y = (_rig as Node4D).position.y
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
			if not leg_name_prefixes.is_empty():
				var named := false
				for prefix in leg_name_prefixes:
					if hip.name.begins_with(prefix):
						named = true
						break
				if not named:
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
	# It used to rebuild the whole mesh every frame, which is why the resolution is
	# turned down. Measured on the brachiosaurus that cost 26.87 ms/frame on its own.
	# It is skinned now: each vertex is bound once to the leg bone nearest it, and only
	# vertices move afterwards. Nothing here re-lofts.
	if not _bound:
		_bound = true
		_bind_mesh()
	var phase: float = float(_gait.phase_progress)
	var duty: float = float(_gait.duty_factor)
	var offsets: Array = _gait.phase_offsets

	for leg in _legs:
		var order: int = int(leg["order"]) % offsets.size()
		var local_phase: float = fposmod(phase + float(offsets[order]), 1.0)
		leg["was_stance"] = bool(leg.get("in_stance", false))
		leg["in_stance"] = local_phase < duty
		leg["prev_goal"] = leg.get("foot_goal", Vector4.ZERO)
		leg["foot_goal"] = _foot_position(leg, local_phase, duty)

	# The trunk rises and falls at twice the gait frequency - once per diagonal pair.
	# Applied to the rig NODE rather than to the body ball: moving a ball re-lofts.
	var bob: float = sin(phase * TAU * 2.0) * body_bob
	if _rig is Node4D:
		(_rig as Node4D).position.y = _rig_rest_y + bob

	for leg in _legs:
		# In rig space, so the bob the rig node just applied has to come back off the
		# goal or the feet would ride up and down with the trunk.
		var goal: Vector4 = leg["foot_goal"]
		_place_leg(leg, Vector4(goal.x, goal.y - bob, goal.z, goal.w))
	if travel and not halted:
		_travel()
	_since_skin += 1
	if _since_skin >= skin_every:
		_since_skin = 0
		_skin()


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

	# Recorded rather than written to the balls: writing a ball makes the rig re-loft
	# the entire creature. The pose reaches the mesh through _skin() instead.
	leg["knee_now"] = hip + direction * along + bend * out
	leg["foot_now"] = hip + direction * reach


## Binds every vertex near a leg to that leg, once.
##
## A vertex is judged by two things: how far DOWN the leg it sits, measured from the hip
## to the foot, and how far it is from the leg's own line. Both have to be satisfied, and
## that is what keeps the belly still - it is low enough to pass the first test but far
## enough from any leg to fail the second. Everything unbound never moves again, so the
## body, neck and tail cost nothing per frame.
func _bind_mesh() -> void:
	# Rebuild FIRST. _ready lowers the rig to animation resolution, but that rebuild has
	# not necessarily happened by the first physics frame - binding straight away caught
	# the full-resolution mesh (9600 cells rather than 2880) and bound to stale vertices.
	_rig.call("build")
	var mesh := (_rig as MeshInstance4D).mesh as ArrayTetraMesh4D
	if mesh == null or _legs.is_empty():
		return
	# From here the mesh is driven directly, so the rig must stop watching its balls.
	_rig.set("live_rebuild", false)
	_rest_verts = mesh.get_vertex_positions()
	_posed = _rest_verts.duplicate()
	for leg in _legs:
		leg["rest_knee"] = _rig._position_in_rig(leg["knee"])
		leg["rest_foot"] = _rig._position_in_rig(leg["foot"])
		leg["knee_now"] = leg["rest_knee"]
		leg["foot_now"] = leg["rest_foot"]
	for i in _rest_verts.size():
		var v: Vector4 = _rest_verts[i]
		var best: int = -1
		var best_weight: float = 0.0
		var best_shank: float = 0.0
		for index in _legs.size():
			var leg: Dictionary = _legs[index]
			var hip: Vector4 = leg["hip_world"]
			var knee: Vector4 = leg["rest_knee"]
			var foot: Vector4 = leg["rest_foot"]
			var drop: float = maxf(hip.y - foot.y, 0.0001)
			var down: float = clampf((hip.y - v.y) / drop, 0.0, 1.0)
			var reach: float = minf(_distance_to_segment(v, hip, knee), _distance_to_segment(v, knee, foot))
			var near: float = 1.0 - smoothstep(leg_influence * 0.55, leg_influence, reach)
			var weight: float = smoothstep(0.02, 0.4, down) * near
			if weight > best_weight:
				best_weight = weight
				best = index
				var at_knee: float = (hip.y - knee.y) / drop
				best_shank = smoothstep(at_knee - 0.18, at_knee + 0.18, down)
		if best >= 0 and best_weight > 0.001:
			_skin_index.append(i)
			_skin_leg.append(best)
			_skin_weight.append(best_weight)
			_skin_shank.append(best_shank)
	if verbose_skin:
		print("[strider] bound %d of %d vertices to %d legs" % [_skin_index.size(), _rest_verts.size(), _legs.size()])


## Applies the current pose to the bound vertices. Two rotations per leg, then a blend.
func _skin() -> void:
	if _skin_index.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var thigh: Array = []
	var shank: Array = []
	for leg in _legs:
		var hip: Vector4 = leg["hip_world"]
		thigh.append(_Plane.between((leg["rest_knee"] as Vector4) - hip, (leg["knee_now"] as Vector4) - hip))
		shank.append(_Plane.between((leg["rest_foot"] as Vector4) - (leg["rest_knee"] as Vector4),
			(leg["foot_now"] as Vector4) - (leg["knee_now"] as Vector4)))
	for k in _skin_index.size():
		var i: int = _skin_index[k]
		var leg: Dictionary = _legs[_skin_leg[k]]
		var v: Vector4 = _rest_verts[i]
		var hip: Vector4 = leg["hip_world"]
		var a: Vector4 = hip + _Plane.apply(v - hip, thigh[_skin_leg[k]])
		var b: Vector4 = (leg["knee_now"] as Vector4) + _Plane.apply(v - (leg["rest_knee"] as Vector4), shank[_skin_leg[k]])
		_posed[i] = v.lerp(a.lerp(b, _skin_shank[k]), _skin_weight[k])
	var t1 := Time.get_ticks_usec()
	((_rig as MeshInstance4D).mesh as ArrayTetraMesh4D).set_vertex_positions(_posed)
	if verbose_skin:
		_skin_maths += t1 - t0
		_skin_upload += Time.get_ticks_usec() - t1
		_skin_frames += 1
		if _skin_frames == 200:
			var mesh := (_rig as MeshInstance4D).mesh as ArrayTetraMesh4D
			print("[strider] %d cells, %d of %d verts bound, maths %.3f ms, upload %.3f ms" % [
				mesh.get_simplex_cell_vertex_indices().size() / 4, _skin_index.size(),
				_rest_verts.size(), _skin_maths / 200.0 / 1000.0, _skin_upload / 200.0 / 1000.0])


func _distance_to_segment(point: Vector4, a: Vector4, b: Vector4) -> float:
	var ab: Vector4 = b - a
	var length_squared: float = ab.length_squared()
	if length_squared < 0.000001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)


## Carries the creature along at exactly the rate its planted feet slide backward.
##
## MEASURED from the feet rather than derived from the gait. The derivation - stride
## length over the stance fraction of the period - looks right and is not: it produced a
## foot drift equal to the body speed, meaning the feet moved with the body instead of
## staying put. Taking the actual per-frame slide of the feet that are ON THE GROUND and
## moving the creature by its opposite cannot be out of step with the gait, whatever the
## cadence, duty factor or stride is set to.
##
## Only legs that were in stance LAST frame as well count: a leg landing this frame jumps
## from its swing arc to the ground, and that jump is not ground slide.
func _travel() -> void:
	var mover := get_parent() as Node4D
	if mover == null:
		return
	var slide := Vector4.ZERO
	var planted: int = 0
	for leg in _legs:
		if bool(leg.get("in_stance", false)) and bool(leg.get("was_stance", false)):
			slide += (leg["foot_goal"] as Vector4) - (leg["prev_goal"] as Vector4)
			planted += 1
	if planted == 0:
		return
	mover.position -= mover.basis * (slide / float(planted))
