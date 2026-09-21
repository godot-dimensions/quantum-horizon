extends Node4D
## Walks a two-legged lofted creature - a chicken - on Motion Lab's gait clock.
##
## WHY NOT ik_gait_driver.gd, which already does this for Trym's creature: that driver
## does not discover legs, it enumerates eight hard-coded names -
##
##     for station in ["Fore", "Hind"]: for side in ["L", "R"]: for w_half in ["A", "K"]
##
## - and reads the body plan straight out of the resulting string ("tag[4] == L",
## "tag[5] == K") to index a four-element offsets table. A biped has no fore/hind, no
## ana/kata half and two legs, so every one of those assumptions fails. Generalising it
## is the right long-term move and is a contained job; this is the narrow version that
## proves a biped works at all.
##
## A CHICKEN IS NOT A SMALL QUADRUPED. Two differences drive everything here:
##
##   * Two legs alternate at exactly half a cycle. There is no diagonal pair to keep in
##     step, so the gait table's four offsets have nothing to say.
##   * The body pitches and the head counter-rotates. A quadruped's trunk bobs twice per
##     stride, once per diagonal pair; a biped's rocks ONCE, over whichever foot is
##     planted, and a bird holds its head still against that rocking - the "chicken
##     head" effect Trym's own design doc names in section 4.4 as a thing to build.
##
## The legs are driven as loft balls rather than as rigid bones, because the chicken was
## authored as a model and not as a bone rig. That costs a re-loft of the two small leg
## rigs each frame; see _physics_process for what that actually measures.

const _GaitController = preload("res://scripts/gait_controller.gd")

## The two leg rigs. Each must be its OWN rig with mirroring off - while they are a
## single mirrored rig they are the same limb, and cannot hold different phases.
@export var left_leg_path: NodePath = NodePath("../LegL")
@export var right_leg_path: NodePath = NodePath("../LegR")
@export var body_path: NodePath = NodePath("../Body")
@export var neck_path: NodePath = NodePath("../NeckHead")

## Small numbers: a chicken's stride is a fraction of its leg, and its leg is already
## nearly straight standing still (hip 0.70, foot 0.03, segments totalling 0.67), so
## there is very little slack for a solver to bend into.
## Cadence comes from the gait clock, which scales its period against its own
## reference_speed of 2.0 - so `speed` below 2.0 makes the bird slower than the preset,
## not faster. It was 1.2, i.e. running at two thirds cadence.
@export var stride_length: float = 0.17
@export var step_height: float = 0.07
@export var body_bob: float = 0.018
@export var body_pitch: float = 0.035
@export var head_stabilise: float = 0.9

## PECKING. Trym's design doc calls for exactly this in section 4.8 - a library of
## parametric idle behaviours, described there as "lower a limb toward a body-relative
## target, hold, repeat N times", solved through the same machinery as locomotion rather
## than played back as a clip.
##
## The neck is SWUNG ABOUT ITS BASE rather than dragged downward. Moving the whole neck
## rig down would post the head through the bird's own chest; rotating about the first
## neck ball keeps the shoulder joint where it belongs and the head describes the arc it
## should. The bird also stops walking while its beak is on the floor, which is what
## makes it read as feeding rather than as a head wobble.
@export var peck_enabled: bool = true
@export_range(1.0, 20.0, 0.5) var peck_interval_min: float = 3.0
@export_range(1.0, 20.0, 0.5) var peck_interval_max: float = 8.0
@export var peck_duration: float = 1.9
## How far down to reach, as a fraction of the gap between the beak at rest and the
## ground. The ANGLE is not authored - it is solved for at startup from where the head
## actually sits relative to the neck's hinge, so re-proportioning the bird's neck does
## not silently turn the peck into a nod.
@export_range(0.0, 1.0, 0.05) var peck_reach: float = 0.92
@export_range(1, 6, 1) var peck_jabs: int = 3

## Rigs that hang off the head but are authored as SIBLINGS of the neck rather than
## children of it. Nothing carries those when the neck swings, so their part of the head
## stays in the air while the beak goes to the floor.
##
## Empty by default, because PARENTING is the better fix and the wattle now uses it: a
## rig nested under a ball is skipped by the parent rig's branch detection, which only
## descends through balls, so it keeps its own mesh and colour while inheriting the
## transform - and it follows in the EDITOR too, which this runtime carrying never did.
## Kept for anything that genuinely cannot be reparented.
@export var head_attachment_paths: Array[NodePath] = []

## WHICH part of the head is aimed at the floor. This has to be the beak: aiming the
## last ball of the neck chain instead puts the COMB on the ground and swings the head
## a full 147 degrees, which turns it upside down and leaves the beak pointing back at
## the bird's own feet. The beak sits forward of the neck's axis, so aiming it needs a
## far smaller swing and lands the head the right way up.
@export var peck_target_path: NodePath = NodePath("../NeckHead/Ball4/BeakBase/BeakMid/BeakTip")

var halted: bool = false
## Fed to the gait clock, which derives its period as reference_period * reference_speed
## / speed - so this is a cadence dial, not a distance. At 24 the period is 0.33 s, and
## with a 0.17 stride that carries the bird about 1.0 units/s: roughly one leg-length
## per second, which is a chicken's walk. It was 0.25 units/s before.
var speed: float = 24.0

## Radius of the circle it walks. The forward speed is DERIVED from the gait rather
## than set independently: a stride carries the body a fixed distance, so travelling
## any faster than the feet is skating, and any slower is moonwalking.
## How it chooses where to go.
##
## A circle is legible but it is also the most predictable path there is - one glance
## and you have seen the whole thing. WANDER steers by fractal Brownian noise instead:
## several octaves of value noise summed, each half the amplitude and double the
## frequency of the last, sampled along time to drive the TURN RATE rather than the
## position. Steering rather than teleporting is what keeps it a walk - the bird always
## moves forward at exactly the speed its own legs are pedalling, it just changes its
## mind about where forward is.
##
## Turning is what fBm is good for here: one octave alone gives lazy sweeping arcs, and
## the higher octaves add the small corrections that read as an animal paying attention
## rather than a vehicle on rails.
@export_enum("Wander", "Circle") var path_mode: int = 0
@export var circle_radius: float = 1.6

## Sharpest turn it can make, in degrees per second. Too high and it spins on the spot.
@export var turn_rate_degrees: float = 95.0

## How far it may stray before it is steered gently back. Without this a random walk
## eventually leaves the ground entirely.
@export var roam_radius: float = 5.0

## Seconds of noise per second of walking. Lower is lazier.
@export var wander_scale: float = 0.35

## How close another bird has to be before this one steers away, in units. Without it
## five birds in close proximity walk straight through each other - measured closest
## approach 0.02 units, which is two birds occupying the same space. This is steering,
## not collision: they lean away from a crowd rather than being pushed apart, so the
## flock stays loose instead of jostling. 0 disables it.
@export var separation: float = 1.7

var _angle: float = 0.0
var _centre: Vector4
var _heading: float = 0.0
var _elapsed: float = 0.0
var _noise: FastNoiseLite
var _wander_centre: Vector4

## Where the neck hinges: the first neck ball, so the swing pivots at the shoulder.
const _NECK_PIVOT := Vector4(0.0, 1.02, 0.42, 0.0)
var _peck_countdown: float = 0.0
var _peck_elapsed: float = -1.0
var _peck_angle: float = 0.0
var _carried: Array = []
var _bound: bool = false
const _FLOCK_GROUP := "chicken_flock"
var _crowding: float = 0.0

## ADDITIVE HOOK for the chicken-pen minigame, and deliberately inert otherwise.
##
## When something else needs to decide where this bird goes - fleeing a player, heading
## for a pen - it sets these instead of the walker inventing a heading from its noise.
## Everything else about the walk is unchanged, so the five birds in
## rigged_creature_ramon.tscn that use this script are untouched: steer_override starts
## false and nothing reads steer_heading until it is true.
##
## Extending rather than forking, which is what item 6 of the brief asks for and what the
## strider walker had to be rescued from earlier in this project.
var steer_override: bool = false
var steer_heading: float = 0.0
var _scale: float = 1.0
var _neck_pivot: Vector4 = _NECK_PIVOT

## The bird itself. This node is a CHILD of it, so writing our own position would slide
## the controller around inside a stationary chicken.
var _creature: Node4D

var _gait: Node
var _legs: Array = []
var _body: Node
var _neck: Node
var _body_rest: Vector4
var _neck_rest: Vector4


func _ready() -> void:
	for path in [left_leg_path, right_leg_path]:
		var rig: Node = get_node_or_null(path)
		if rig == null or not rig.has_method("build"):
			continue
		var balls: Array = []
		for child in rig.get_children():
			if child.has_method("get_loft_section"):
				balls.append(child)
		if balls.size() < 3:
			continue
		# Authored bottom-up: Ball1 is the foot, Ball3 the hip. Sort by height so the
		# code does not depend on the order they happen to sit in the scene tree.
		balls.sort_custom(func(a, b): return a.position.y < b.position.y)
		_legs.append({
			"rig": rig, "foot": balls[0], "knee": balls[1], "hip": balls[2],
			"hip_pos": balls[balls.size() - 1].position,
			"rest_foot": balls[0].position,
			"upper": balls[2].position.distance_to(balls[1].position),
			"lower": balls[1].position.distance_to(balls[0].position),
		})
	if _legs.size() < 2:
		push_warning("ChickenWalker: needs two independent leg rigs, found %d." % _legs.size())
		set_physics_process(false)
		return

	_body = get_node_or_null(body_path)
	_neck = get_node_or_null(neck_path)
	if _body != null:
		_body_rest = _body.position
	if _neck != null:
		_neck_rest = _neck.position
		for path in head_attachment_paths:
			var node: Node = get_node_or_null(path)
			if node is Node4D:
				_carried.append({"node": node, "rest": (node as Node4D).position})

	# Orbit about a point one radius away, so the bird starts where it was placed
	# rather than jumping to the rim of a circle centred on itself.
	_creature = get_parent() as Node4D
	if _creature == null:
		push_warning("ChickenWalker: expected to hang off the creature it drives.")
		set_physics_process(false)
		return
	_centre = _creature.position - Vector4(circle_radius, 0.0, 0.0, 0.0)
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_VALUE
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.frequency = 1.0
	_noise.seed = randi()
	# Everything the gait measures - stride, step height, reach - is in the bird's OWN
	# units. Its travel is in the parent's. Shrinking the bird has to shrink the distance
	# it covers per step by the same factor or it skates across the ground.
	_scale = maxf(_creature.basis.x.length(), 0.0001)
	_wander_centre = _creature.position
	_creature.add_to_group(_FLOCK_GROUP)
	_peck_countdown = randf_range(peck_interval_min, peck_interval_max)

	_gait = Node.new()
	_gait.set_script(_GaitController)
	_gait.name = "GaitController"
	_gait.standalone_input = false
	_gait.body_path = NodePath("..")
	add_child(_gait)
	if _gait.has_method("apply_preset"):
		_gait.apply_preset("walk")


func _physics_process(_delta: float) -> void:
	# NOTHING on this bird re-lofts. The body, neck, wings and wattle are moved as whole
	# nodes - the rigid approach Trym's creature uses throughout - and the two legs, which
	# do have to bend, are skinned.
	#
	# They used to re-loft, and an earlier version of this comment called them "the
	# cheapest rigs on the bird". Measured, they were the opposite: 7.8 ms per leg per
	# frame, so five birds spent 77 ms of a 79 ms frame in there while DRAWING all five
	# cost 0.86 ms. Moving a single ball is what triggers it.
	if not _bound:
		_bound = true
		for leg in _legs:
			_bind_leg(leg)
	var phase: float = float(_gait.phase_progress)
	var duty: float = float(_gait.duty_factor)

	for index in range(_legs.size()):
		# Two legs, half a cycle apart. That is the whole of a biped gait.
		var local_phase: float = fposmod(phase + (0.0 if index == 0 else 0.5), 1.0)
		_place_leg(_legs[index], _foot_position(_legs[index], local_phase, duty))

	var pecking: float = _update_peck(_delta)
	# Legs stop while the beak is down. halted freezes the gait clock's phase, so the
	# bird resumes mid-stride rather than snapping back to the start of its cycle.
	halted = pecking > 0.0
	if not halted:
		if path_mode == 1:
			_travel(_delta)
		else:
			_wander(_delta)

	# ONE rock per stride, not two: a biped leans over whichever foot is planted.
	if _body != null:
		var rock: float = sin(phase * TAU)
		_body.position = _body_rest + Vector4(0.0, absf(rock) * body_bob, rock * body_pitch, 0.0)
	# And the head holds still against it - a bird's gaze stabilisation.
	if _neck != null and _body != null:
		var drift: Vector4 = _body.position - _body_rest
		_neck.position = _neck_rest - drift * head_stabilise
		_apply_peck(pecking)
		_carry_attachments()


## Advances the peck clock and returns how far down the neck should be, 0 to 1.
##
## The shape is a dip, several quick jabs at the bottom, then a rise - not a single
## smooth bob, because a feeding bird strikes repeatedly once it is down there.
func _update_peck(delta: float) -> float:
	if not peck_enabled or _neck == null:
		return 0.0
	# Solved on the first simulated frame, not in _ready: global transforms are not
	# settled yet at _ready, so the feet read as sitting at the origin and the bird
	# would aim its beak at a floor well below the one it stands on.
	if _peck_angle == 0.0:
		_solve_peck_angle()
	if _peck_elapsed < 0.0:
		_peck_countdown -= delta
		if _peck_countdown > 0.0:
			return 0.0
		_peck_elapsed = 0.0
	_peck_elapsed += delta
	var t: float = _peck_elapsed / maxf(peck_duration, 0.001)
	if t >= 1.0:
		_peck_elapsed = -1.0
		_peck_countdown = randf_range(peck_interval_min, peck_interval_max)
		return 0.0
	if t < 0.25:
		return smoothstep(0.0, 1.0, t / 0.25)
	if t > 0.75:
		return smoothstep(0.0, 1.0, (1.0 - t) / 0.25)
	# At the bottom: quick jabs between 82% and full depth.
	return 0.91 + 0.09 * cos((t - 0.25) / 0.5 * TAU * float(peck_jabs))


## Swings the neck down about its base by the given amount.
##
## Rotating a node also moves everything hanging off it, so the pivot is held in place
## explicitly: position += pivot - R * pivot. Without that the neck would rotate about
## the creature's origin, which is on the ground, and the head would scythe through the
## floor instead of dipping to it.
func _apply_peck(amount: float) -> void:
	if amount <= 0.0:
		_neck.basis = Projection.IDENTITY
		return
	var a: float = amount * _peck_angle
	var rotated := Projection(
		Vector4(1.0, 0.0, 0.0, 0.0),
		Vector4(0.0, cos(a), sin(a), 0.0),
		Vector4(0.0, -sin(a), cos(a), 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0))
	_neck.basis = rotated
	_neck.position += _neck_pivot - rotated * _neck_pivot


## Carries the bird around its circle at exactly the speed its own legs are pedalling.
##
## A biped covers two strides per gait cycle - one per leg - so the ground speed that
## keeps the feet from sliding is 2 * stride_length / period. Deriving it means the walk
## stays honest if the cadence or the stride is retuned later.
func _travel(delta: float) -> void:
	var period: float = maxf(float(_gait.period_sec), 0.0001)
	var ground_speed: float = 2.0 * stride_length / period
	# circle_radius is a distance in the WORLD, so the speed around it has to be too.
	_angle += (ground_speed * _scale / maxf(circle_radius, 0.0001)) * delta
	_creature.position = _centre + Vector4(cos(_angle) * circle_radius,
		_creature.position.y - _centre.y, sin(_angle) * circle_radius, 0.0)
	# Face along the tangent. The bird is modelled facing +Z, so its local Z column has
	# to become the direction of travel, and X follows from it.
	var tz: float = cos(_angle) * _scale
	var tx: float = -sin(_angle) * _scale
	_creature.basis = Projection(Vector4(tz, 0.0, -tx, 0.0), Vector4(0.0, _scale, 0.0, 0.0),
		Vector4(tx, 0.0, tz, 0.0), Vector4(0.0, 0.0, 0.0, _scale))


## Steers by fractal noise, moving forward at whatever speed the gait is producing.
func _wander(delta: float) -> void:
	_elapsed += delta
	var turn: float = _noise.get_noise_1d(_elapsed * wander_scale)

	# A gentle pull back toward home, strongest when furthest out, so the bird roams
	# freely in the middle and turns away rather than walking off the platform. Blended
	# into the noise instead of overriding it, or the return reads as a sudden decision.
	var offset: Vector4 = _creature.position - _wander_centre
	var strayed: float = Vector2(offset.x, offset.z).length() / maxf(roam_radius * _scale, 0.001)
	if strayed > 1.0:
		var home: float = atan2(-offset.x, -offset.z)
		var toward: float = wrapf(home - _heading, -PI, PI)
		# Committing over the first third past the limit rather than the first whole
		# radius: blending in linearly let it reach 7.69 units against a stated 5.0,
		# because a bird can only turn so fast and the noise kept pulling the other way.
		turn = lerpf(turn, signf(toward), clampf((strayed - 1.0) * 3.0, 0.0, 1.0))

	turn = _avoid_crowding(turn)
	if steer_override:
		# Turn toward the heading we were handed, at the bird's own turn rate, so an
		# externally steered bird still banks like a bird instead of snapping round.
		var toward: float = wrapf(steer_heading - _heading, -PI, PI)
		_heading += clampf(toward, -1.0, 1.0) * deg_to_rad(turn_rate_degrees) * delta
	else:
		_heading += turn * deg_to_rad(turn_rate_degrees) * delta
	var period: float = maxf(float(_gait.period_sec), 0.0001)
	var ground_speed: float = 2.0 * stride_length / period
	var step: float = ground_speed * delta * _scale * (1.0 - 0.85 * _crowding)
	_creature.position += Vector4(sin(_heading) * step, 0.0, cos(_heading) * step, 0.0)
	_face(_heading)


## Points the bird along a heading. It is modelled facing +Z, so its local Z column has
## to become the direction of travel and X follows from it.
## Points the bird along its heading, KEEPING whatever scale it was placed at.
##
## This writes the whole basis every frame, so a scale set in the scene would be wiped
## on the first step. The models are authored at 1 unit = 0.25 m while the player is
## 1 unit = 1 m, so the birds are scaled down to share a world with him, and that scale
## has to survive being re-aimed.
func _face(heading: float) -> void:
	var tz: float = cos(heading) * _scale
	var tx: float = sin(heading) * _scale
	_creature.basis = Projection(Vector4(tz, 0.0, -tx, 0.0), Vector4(0.0, _scale, 0.0, 0.0),
		Vector4(tx, 0.0, tz, 0.0), Vector4(0.0, 0.0, 0.0, _scale))


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


## Closed-form two-bone IK, joint folding BACKWARD.
##
## This was forward, and it was the reason the bird read as a man in a chicken suit: a
## forward-bulging mid-leg joint is a human KNEE. A bird's knee is short and hidden up
## inside the body; the visible joint halfway down the leg is its ANKLE, and an ankle
## folds the other way. One sign, and the whole silhouette changes species.
func _place_leg(leg: Dictionary, goal: Vector4) -> void:
	var hip: Vector4 = leg["hip_pos"]
	var upper: float = float(leg["upper"])
	var lower: float = float(leg["lower"])
	var to_goal: Vector4 = goal - hip
	var reach: float = to_goal.length()
	if reach < 0.0001:
		return
	reach = clampf(reach, absf(upper - lower) + 0.005, upper + lower - 0.005)
	var direction: Vector4 = to_goal.normalized()
	var along: float = (reach * reach + upper * upper - lower * lower) / (2.0 * reach)
	var out: float = sqrt(maxf(upper * upper - along * along, 0.0))

	var bend := Vector4(0.0, 0.0, -1.0, 0.0)
	bend -= direction * bend.dot(direction)
	if bend.length() < 0.001:
		bend = Vector4(1.0, 0.0, 0.0, 0.0)
		bend -= direction * bend.dot(direction)
	bend = bend.normalized()

	# NOT written back to the ball nodes. Moving a ball makes its rig re-loft the whole
	# leg, which measured at 7.8 ms per leg per frame - five birds spent 77 of their
	# 79 ms/frame there. The same pose is applied by skinning the mesh instead.
	_skin_leg(leg, hip + direction * along + bend * out, hip + direction * reach)


## Works out the swing angle that actually puts the beak on the floor.
##
## Swinging the neck by angle a moves the head, which sits at (py, pz) from the hinge,
## to height R*cos(a + phi) where R is the head's distance from the hinge and phi its
## rest bearing. So the angle for a wanted height is a plain inversion of that - and it
## also tells us when a height is out of reach (|ty| > R), rather than winding the neck
## round and posting the head through the bird's back.
func _solve_peck_angle() -> void:
	if _neck == null:
		return
	var head: Node = get_node_or_null(peck_target_path)
	if head == null:
		head = _neck
		while head.get_child_count() > 0:
			head = head.get_child(head.get_child_count() - 1)
	var first: Node = _neck
	if first.get_child_count() > 0:
		first = first.get_child(0)
	_neck_pivot = _sum_up(first, _neck)
	var head_off: Vector4 = _sum_up(head, _neck) - _neck_pivot
	var r: float = Vector2(head_off.y, head_off.z).length()
	if r < 0.001:
		return
	var phi: float = atan2(head_off.z, head_off.y)
	# The floor, as the bird stands on it: the lowest point any foot reaches.
	var ground: float = _lowest_foot()
	var want: float = lerpf(_neck_pivot.y + head_off.y, ground, peck_reach) - _neck_pivot.y
	_peck_angle = acos(clampf(want / r, -1.0, 1.0)) - phi
	if true:
		print("[walker] peck: aiming %s, %.3f from hinge, reaching y %.3f -> %.2f rad" % [head.name, r, want + _neck_pivot.y, _peck_angle])


## Local offset of a descendant, summed up the chain. Valid at rest, where every basis
## on the way is still identity.
func _sum_up(node: Node, ancestor: Node) -> Vector4:
	var total := Vector4.ZERO
	var walk: Node = node
	while walk != null and walk != ancestor:
		if walk is Node4D:
			total += (walk as Node4D).position
		walk = walk.get_parent()
	return total


func _lowest_foot() -> float:
	var lowest: float = INF
	for leg in _legs:
		var foot: Node = leg["foot"]
		if foot is Node4D:
			lowest = minf(lowest, _sum_up(foot, _creature).y)
	return 0.0 if is_inf(lowest) else lowest


## Glues the head attachments to the neck, whatever the neck is doing.
##
## Each one is placed as though it were a child of the neck rig: its offset from the
## neck at rest, carried through the neck's current rotation. That covers the peck and
## the gaze-stabilising counter-bob in one expression, so the wattle cannot drift a
## frame behind the beak it hangs from.
func _carry_attachments() -> void:
	if _carried.is_empty() or _neck == null:
		return
	var neck_basis: Projection = _neck.basis
	for entry in _carried:
		var node: Node4D = entry["node"]
		node.basis = neck_basis
		node.position = _neck.position + neck_basis * (entry["rest"] - _neck_rest)


## Binds a leg's mesh to its two bones, once.
##
## Each vertex is placed along the leg by height - 0 at the hip, 1 at the foot - and
## handed to the thigh or the shank according to which side of the knee it falls on,
## with a soft band across the joint so the surface bends instead of shearing. Cheap,
## and good enough for a leg this low-poly.
func _bind_leg(leg: Dictionary) -> void:
	var rig: Node = leg["rig"]
	var mesh := (rig as MeshInstance4D).mesh as ArrayTetraMesh4D
	if mesh == null:
		return
	# Stops the rig re-lofting when anything moves: from here the mesh is driven directly.
	rig.set("live_rebuild", false)
	var rest: PackedVector4Array = mesh.get_vertex_positions()
	var hip: Vector4 = leg["hip_pos"]
	var knee: Vector4 = (leg["knee"] as Node4D).position
	var foot: Vector4 = (leg["foot"] as Node4D).position
	var span: float = maxf(hip.y - foot.y, 0.0001)
	var at_knee: float = (hip.y - knee.y) / span
	var weights := PackedFloat32Array()
	weights.resize(rest.size())
	for i in rest.size():
		var s: float = (hip.y - rest[i].y) / span
		weights[i] = smoothstep(at_knee - 0.14, at_knee + 0.14, s)
	leg["mesh"] = mesh
	leg["rest"] = rest
	leg["weights"] = weights
	leg["rest_knee"] = knee
	leg["rest_foot"] = foot
	leg["out"] = PackedVector4Array()
	leg["out"].resize(rest.size())


## Poses a bound leg: thigh rotates about the hip, shank about the knee, and each vertex
## is a blend of the two.
func _skin_leg(leg: Dictionary, knee: Vector4, foot: Vector4) -> void:
	if not leg.has("mesh"):
		return
	var hip: Vector4 = leg["hip_pos"]
	var rest: PackedVector4Array = leg["rest"]
	var weights: PackedFloat32Array = leg["weights"]
	var out: PackedVector4Array = leg["out"]
	var thigh: Array = _plane_rotation((leg["rest_knee"] as Vector4) - hip, knee - hip)
	var shank: Array = _plane_rotation((leg["rest_foot"] as Vector4) - (leg["rest_knee"] as Vector4), foot - knee)
	var rest_knee: Vector4 = leg["rest_knee"]
	for i in rest.size():
		var v: Vector4 = rest[i]
		var a: Vector4 = hip + _apply_plane_rotation(v - hip, thigh)
		var b: Vector4 = knee + _apply_plane_rotation(v - rest_knee, shank)
		out[i] = a.lerp(b, weights[i])
	(leg["mesh"] as ArrayTetraMesh4D).set_vertex_positions(out)


## The rotation carrying one direction onto another, as the plane they span plus the
## angle within it. In 4D there is no rotation axis to name - a rotation lives in a
## PLANE - so it is stored as two orthonormal vectors and the sine and cosine.
func _plane_rotation(from: Vector4, to: Vector4) -> Array:
	var u: Vector4 = from.normalized()
	var t: Vector4 = to.normalized()
	var c: float = clampf(u.dot(t), -1.0, 1.0)
	var v: Vector4 = t - u * c
	if v.length() < 0.00001:
		return [u, u, 1.0, 0.0]   # already aligned, or exactly reversed
	v = v.normalized()
	return [u, v, c, sqrt(maxf(1.0 - c * c, 0.0))]


func _apply_plane_rotation(x: Vector4, r: Array) -> Vector4:
	var u: Vector4 = r[0]
	var v: Vector4 = r[1]
	var c: float = r[2]
	var s: float = r[3]
	var xu: float = u.dot(x)
	var xv: float = v.dot(x)
	return x + ((c - 1.0) * xu - s * xv) * u + (s * xu + (c - 1.0) * xv) * v


## Bends a turn away from any bird standing too close.
##
## Each neighbour inside the separation radius pushes, harder the closer it is, and the
## bird turns toward the sum. Blended with the wander rather than replacing it, so a
## crowded bird still wanders - it just wanders outward.
func _avoid_crowding(turn: float) -> float:
	_crowding = 0.0
	if separation <= 0.0:
		return turn
	var reach: float = separation * _scale
	var push := Vector2.ZERO
	for other in _creature.get_tree().get_nodes_in_group(_FLOCK_GROUP):
		if other == _creature or not (other is Node4D):
			continue
		var away := Vector2(_creature.position.x - (other as Node4D).position.x,
			_creature.position.z - (other as Node4D).position.z)
		var gap: float = away.length()
		if gap > 0.001 and gap < reach:
			push += away / gap * (1.0 - gap / reach)
	var urgency: float = clampf(push.length(), 0.0, 1.0)
	_crowding = urgency
	if urgency < 0.001:
		return turn
	var toward: float = wrapf(atan2(push.x, push.y) - _heading, -PI, PI)
	return lerpf(turn, signf(toward), urgency)
