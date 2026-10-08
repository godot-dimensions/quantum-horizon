extends Node4D

## Swims the plesiosaur by cutting its hide into rigid pieces and turning them.
##
## WHY NOT RE-LOFT. Driving a lofted creature by moving its balls means rebuilding the whole
## surface every frame. Measured on this model by `_probe_loft_cost_runner.gd`: 574 ms per
## rebuild at authoring resolution, and still 53 ms at a resolution ugly enough that the
## animal is barely round. A 16.67 ms frame has no room for any of that. Remeshing is not an
## animation technique here, whatever the cost in a tutorial says.
##
## SO THIS DOES WHAT THE WOLF DOES. `ramon/chickenpen/scripts/strider_walker.gd` solved the
## same problem for a walking sauropod, and the shape of its answer is:
##
##   1. build the loft ONCE, then set live_rebuild = false so the rig stops watching balls;
##   2. give every vertex an owner - which segment carries it;
##   3. bucket each tetrahedron by its corners' owners, and make each bucket its own
##      MeshInstance4D, all SHARING the rig's one vertex array and differing only in which
##      cells they index, so cutting costs no extra memory;
##   4. per frame write each piece's basis and position. No mesh is touched at all;
##   5. the cells whose corners DISAGREE cannot be carried rigidly by anybody, so they become
##      small joint patches that are posed per frame - a few hundred vertices, not 4460.
##
## Step 5 is the answer to the seam. Overlapping capsules would also work and would be less
## code, but it would mean abandoning the lofted surface the model is made of, and the joint
## patch keeps the skin continuous for about two hundred vertices of work per joint.
##
## WHAT THIS DOES DIFFERENTLY FROM THE WOLF: the pieces are PARENTED TO EACH OTHER rather than
## all hung off the rig. The wolf's legs are two bones off a rigid body, so it accumulates the
## two transforms by hand. A neck is nine joints deep, and composing nine transforms by hand
## each frame is nine chances to get the order wrong - so the neck pieces form a chain in the
## scene tree and Node4D composes them, which is free and cannot be got wrong. Each piece then
## only has to express its own local bend.

const _Plane = preload("res://ramon/chickenpen/scripts/plane_rotation_4d.gd")

@export var rig_path: NodePath = NodePath("../Hide")

@export_group("Build")
## Resolution the hide is built at before it is cut. Unlike the wolf's, this is NOT a
## per-frame cost - the mesh is built once - so it can afford to stay close to the authoring
## resolution. It is exposed because the cut itself scales with cell count.
@export_range(1, 4, 1) var animation_smoothing: int = 3
@export_range(4, 16, 1) var animation_sides: int = 12
@export_range(3, 8, 1) var animation_rings: int = 5
## Pose the joint patches. Off, the seams tear open as the neck bends; the pieces themselves
## still move. Worth turning off once to see what the patches are actually doing.
@export var blend_joints: bool = true

@export_group("Flipper stroke")
## Plesiosaurs did not row, they flew: the flippers beat up and down like wings. The stroke is
## therefore a rotation in the X-Y plane about the shoulder, not a backward sweep.
@export_range(0.4, 8.0, 0.05, "suffix:s") var stroke_period: float = 2.6
@export_range(0.0, 60.0, 1.0, "suffix:°") var stroke_degrees: float = 24.0
## How far the beat leans into the axis the player cannot see, a quarter cycle out of phase
## with the visible one. This is the trick `tail_sway_solver.gd` uses: without it the stroke
## looks identical from every W, which is the failure this whole project keeps running into.
## With it, a flipper's reach in the slice PULSES as it beats.
@export_range(0.0, 45.0, 1.0, "suffix:°") var stroke_w_degrees: float = 13.0
## Hind pair's phase offset, in cycles. At 0.5 the pairs beat in opposition, which is what
## keeps the body from pitching; at 0 all four beat together.
@export_range(0.0, 1.0, 0.05) var hind_phase: float = 0.5

@export_group("Neck and tail")
@export_range(0.5, 20.0, 0.1, "suffix:s") var wave_period: float = 5.5
## TOTALS AT THE TIP, not per joint - each joint takes a share. The joints compose, so a
## per-joint figure means the tip gets the sum and the number in the inspector describes
## nothing you can see. tail_sway_solver.gd states the same convention for the same reason.
##
## It matters more than bookkeeping here. At 3 degrees PER JOINT of W sway the head reached
## about 18 degrees off the slice, which on a 4 m neck is 1.2 m through W - and the neck is
## only about 0.25 m thick that way, so the whole thing left the slice and the animal was
## rendered with no neck at all. Shared along the chain, the same number stays visible.
@export_range(0.0, 90.0, 1.0, "suffix:°") var neck_sway_degrees: float = 26.0
@export_range(0.0, 45.0, 1.0, "suffix:°") var neck_w_degrees: float = 7.0
@export_range(0.0, 90.0, 1.0, "suffix:°") var tail_sway_degrees: float = 20.0
## How far behind each joint runs from the one before it, in cycles. Zero makes the neck a
## rigid plank that hinges at the shoulder; this is what makes the bend travel along it.
@export_range(0.0, 0.3, 0.005) var lag_per_joint: float = 0.055

@export_group("Head")
@export_range(0.0, 60.0, 1.0, "suffix:°") var head_turn_degrees: float = 12.0
@export_range(0.0, 30.0, 1.0, "suffix:°") var head_pitch_degrees: float = 5.0
## Deliberately not a multiple of the swim period: a head that scans in step with the
## flippers reads as clockwork.
@export_range(1.0, 30.0, 0.1, "suffix:s") var look_period: float = 9.3
## Furthest the head will turn off the neck to follow something. A real neck runs out of
## travel; without a cap the head swivels right round when the player walks behind it, which
## reads as a broken joint rather than as attention.
@export_range(5.0, 120.0, 1.0, "suffix:°") var head_follow_degrees: float = 60.0
## How quickly a glance fades in and out, in units of attention per second. Fast enough to
## look like noticing, slow enough not to snap.
@export_range(0.2, 8.0, 0.1) var attention_ease: float = 1.6

## The body, which does not move - everything else hangs off it.
const BODY_BALLS: PackedStringArray = ["TailBase", "Hips", "Belly", "Barrel", "Chest"]
## Forward from the body. Each entry is one rigid piece; the head is four balls in one piece
## because a skull does not bend.
const NECK_SEGMENTS: Array = [
	["NeckRoot"], ["Neck1"], ["Neck2"], ["Neck3"], ["Neck4"],
	["Nape", "Skull", "Jaw", "SnoutTip"],
]
## Backward from the body.
const TAIL_SEGMENTS: Array = [["TailMid"], ["TailFluke", "TailTip"]]
## Each flipper becomes TWO pieces, one per side of the body: the rig generates the left pair
## by mirroring and there are no ball nodes for them, so a vertex's side is decided by the
## sign of its X and the ball positions are mirrored to match when measuring distance.
const FLIPPERS: Array = [
	["ForeFlipperBase", "ForeFlipperMid", "ForeFlipperTip"],
	["HindFlipperBase", "HindFlipperMid", "HindFlipperTip"],
]

var _rig: MeshInstance4D = null
## One entry per piece: {node, pivot, kind, index, side}.
var _pieces: Array = []
## One entry per seam: {node, mesh, rest, weight, child}.
var _joints: Array = []
var _time: float = 0.0
var _ready_to_swim: bool = false
## Where the head is being asked to look, and how much notice it is currently taking. The
## pilot sets the first two; `_attention` eases between them so a glance begins and ends.
## Nose-to-tail length of the hide as authored, so a caller can scale the animal to a size it
## wants without hardcoding a number that stops being true the moment a ball is dragged.
var _rest_length: float = 0.0
var _look_target := Vector4()
var _look_active: bool = false
var _attention: float = 0.0


func _ready() -> void:
	_rig = get_node_or_null(rig_path) as MeshInstance4D
	if _rig == null:
		push_warning("Plesiosaur swimmer: no rig at %s." % rig_path)
		return
	_rig.smoothing = animation_smoothing
	_rig.profile_sides = animation_sides
	_rig.profile_rings = animation_rings
	# Build explicitly rather than waiting for the rig's own coalesced rebuild. The wolf hit
	# this: binding on the first physics frame caught the PREVIOUS resolution's mesh and bound
	# to vertices that were about to be thrown away.
	_rig.build(false)
	_rig.live_rebuild = false
	_ready_to_swim = _cut()


func _physics_process(delta: float) -> void:
	if not _ready_to_swim:
		return
	_time += delta
	_attention = clampf(_attention + (1.0 if _look_active else -1.0) * attention_ease * delta,
			0.0, 1.0)
	for piece in _pieces:
		var turn: Projection = _rotation_for(piece)
		var node: Node4D = piece["node"]
		var pivot: Vector4 = piece["pivot"]
		# v -> pivot + R(v - pivot), which as a node transform is basis R, origin pivot - R*pivot.
		node.basis = turn
		node.position = pivot - turn * pivot
	if blend_joints:
		for joint in _joints:
			_pose_joint(joint)


## The local bend for one piece, in its parent's frame.
func _rotation_for(piece: Dictionary) -> Projection:
	var kind: String = piece["kind"]
	var index: int = piece["index"]
	if kind == "body":
		return Projection.IDENTITY

	if kind == "flipper":
		var pair: int = piece["pair"]
		var side: float = piece["side"]
		var phase: float = TAU * (_time / maxf(stroke_period, 0.01)
				- (hind_phase if pair == 1 else 0.0))
		# Negated on the left: a rotation in X-Y that lifts a flipper reaching along +X pushes
		# the one reaching along -X down, so without this the pair scissors instead of beating.
		var flap: float = deg_to_rad(stroke_degrees) * sin(phase) * side
		var through_w: float = deg_to_rad(stroke_w_degrees) * sin(phase + PI * 0.5) * side
		return Basis4D.from_xy(flap) * Basis4D.from_xw(through_w)

	var lag: float = float(index) * lag_per_joint
	var wave: float = TAU * (_time / maxf(wave_period, 0.01) - lag)
	if kind == "tail":
		# The tail trails the body, so its wave runs on from where the body's would be rather
		# than starting fresh - otherwise the hips and the tail base argue with each other.
		var tail_share: float = 1.0 / float(maxi(TAIL_SEGMENTS.size(), 1))
		var sway: float = deg_to_rad(tail_sway_degrees * tail_share) * sin(wave + PI)
		var tail_w: float = deg_to_rad(tail_sway_degrees * tail_share * 0.5) * sin(wave + PI * 1.5)
		return Basis4D.from_zx(sway) * Basis4D.from_zw(tail_w)

	var share: float = 1.0 / float(maxi(NECK_SEGMENTS.size(), 1))
	var neck_sway: float = deg_to_rad(neck_sway_degrees * share) * sin(wave)
	var neck_w: float = deg_to_rad(neck_w_degrees * share) * sin(wave + PI * 0.5)
	var bend: Projection = Basis4D.from_zx(neck_sway) * Basis4D.from_zw(neck_w)
	if not piece["is_head"]:
		return bend
	# The head carries the neck's own share of the wave PLUS a slower scan of its own, so it
	# does not simply ride the neck like a knob on the end of it.
	var look: float = TAU * _time / maxf(look_period, 0.01)
	var idle: Projection = (Basis4D.from_zx(deg_to_rad(head_turn_degrees) * sin(look))
			* Basis4D.from_yz(deg_to_rad(head_pitch_degrees) * sin(look * 1.7)))
	if _attention <= 0.001:
		return bend * idle
	var attend: Projection = _attention_turn(piece, bend)
	# The glance REPLACES the idle scan rather than adding to it: two rotations about
	# different things, summed, give a head that drifts off the target while it is supposedly
	# staring at it.
	return bend * _blend_toward(idle, attend, _attention)


## The local rotation that would point the head's nose at `_look_target`.
##
## The head's rest forward is +Z IN RIG SPACE, and the rotation being built is local to the
## head's parent - so the world direction has to be carried back through the parent's global
## basis and through the neck's own bend before it means anything here. Getting that chain
## wrong gives a head that looks at the right thing only when the animal happens to be facing
## down +Z, which is most of the time near the start and none of it later.
func _attention_turn(piece: Dictionary, bend: Projection) -> Projection:
	var node: Node4D = piece["node"]
	var parent := node.get_parent() as Node4D
	if parent == null:
		return Projection.IDENTITY
	var toward: Vector4 = _look_target - node.get_global_position()
	if toward.length() < 0.001:
		return Projection.IDENTITY
	var local: Vector4 = parent.get_global_basis().inverse() * toward.normalized()
	local = (bend.inverse() * local).normalized()
	var turn: Array = _Plane.between(Vector4(0.0, 0.0, 1.0, 0.0), local)
	# Clamp the travel. _Plane.between hands back the plane and the sine and cosine, so the
	# angle can be re-made smaller in the same plane rather than abandoned.
	var angle: float = atan2(turn[3], turn[2])
	var limit: float = deg_to_rad(head_follow_degrees)
	if absf(angle) > limit:
		angle = limit * signf(angle)
		turn = [turn[0], turn[1], cos(angle), sin(angle)]
	return Projection(
			_Plane.apply(Vector4(1.0, 0.0, 0.0, 0.0), turn),
			_Plane.apply(Vector4(0.0, 1.0, 0.0, 0.0), turn),
			_Plane.apply(Vector4(0.0, 0.0, 1.0, 0.0), turn),
			_Plane.apply(Vector4(0.0, 0.0, 0.0, 1.0), turn))


## Eases between two rotations by moving each basis vector and re-squaring the result. Not a
## true interpolation of rotations, but over the small angles a glance covers the difference
## is invisible, and it needs no decomposition.
func _blend_toward(from: Projection, to: Projection, amount: float) -> Projection:
	var t: float = clampf(amount, 0.0, 1.0)
	return Basis4D.orthonormalized(Projection(
			(from * Vector4(1.0, 0.0, 0.0, 0.0)).lerp(to * Vector4(1.0, 0.0, 0.0, 0.0), t),
			(from * Vector4(0.0, 1.0, 0.0, 0.0)).lerp(to * Vector4(0.0, 1.0, 0.0, 0.0), t),
			(from * Vector4(0.0, 0.0, 1.0, 0.0)).lerp(to * Vector4(0.0, 0.0, 1.0, 0.0), t),
			(from * Vector4(0.0, 0.0, 0.0, 1.0)).lerp(to * Vector4(0.0, 0.0, 0.0, 1.0), t)))


## Nose to tail, as built, before any scaling. Zero until the hide has been cut.
func rest_length() -> float:
	return _rest_length


## Asked by the pilot. [param active] false lets the glance fade out rather than cutting it.
func look_at_point(point: Vector4, active: bool) -> void:
	_look_target = point
	_look_active = active


## Builds the pieces and the joint patches. False if the hide could not be cut, in which case
## nothing animates and the model simply stands still rather than falling apart.
func _cut() -> bool:
	var mesh := _rig.mesh as ArrayTetraMesh4D
	if mesh == null:
		push_warning("Plesiosaur swimmer: the rig built no mesh.")
		return false
	var rest: PackedVector4Array = mesh.get_vertex_positions()
	if rest.is_empty():
		return false
	var low_z: float = INF
	var high_z: float = -INF
	for point in rest:
		low_z = minf(low_z, point.z)
		high_z = maxf(high_z, point.z)
	_rest_length = high_z - low_z

	# --- which ball carries which piece ---------------------------------------------------
	var ball_owner: Dictionary = {}       # ball name -> piece index
	var plan: Array = []                  # piece index -> description
	var parent_of: PackedInt32Array = PackedInt32Array()

	var body_index: int = plan.size()
	plan.append({"name": "Body", "kind": "body", "index": 0, "balls": BODY_BALLS,
			"parent": -1, "is_head": false})
	parent_of.append(-1)
	for ball in BODY_BALLS:
		ball_owner[ball] = body_index

	var previous: int = body_index
	for i in NECK_SEGMENTS.size():
		var names: Array = NECK_SEGMENTS[i]
		var index: int = plan.size()
		plan.append({"name": "Neck%d" % i, "kind": "neck", "index": i, "balls": names,
				"parent": previous, "is_head": i == NECK_SEGMENTS.size() - 1})
		parent_of.append(previous)
		for ball in names:
			ball_owner[ball] = index
		previous = index

	previous = body_index
	for i in TAIL_SEGMENTS.size():
		var names: Array = TAIL_SEGMENTS[i]
		var index: int = plan.size()
		plan.append({"name": "Tail%d" % i, "kind": "tail", "index": i, "balls": names,
				"parent": previous, "is_head": false})
		parent_of.append(previous)
		for ball in names:
			ball_owner[ball] = index
		previous = index

	# A flipper's two sides share ball NAMES, so the owner table cannot hold them. They are
	# resolved by sign of X at assignment time instead, through `flipper_of`.
	var flipper_of: Dictionary = {}       # ball name -> [pair, right piece, left piece]
	for pair in FLIPPERS.size():
		var names: Array = FLIPPERS[pair]
		var right: int = plan.size()
		plan.append({"name": "Flipper%dR" % pair, "kind": "flipper", "index": pair,
				"balls": names, "parent": body_index, "is_head": false, "side": 1.0,
				"pair": pair})
		parent_of.append(body_index)
		var left: int = plan.size()
		plan.append({"name": "Flipper%dL" % pair, "kind": "flipper", "index": pair,
				"balls": names, "parent": body_index, "is_head": false, "side": -1.0,
				"pair": pair})
		parent_of.append(body_index)
		# THE BASE BALL OWNS NOTHING. It sits at x = 0.5, which is INSIDE a body 0.64 wide, so
		# nearest-ball handed it a wide patch of flank - 695 cells of it - and because that
		# patch straddles body and flipper it became a seam, which the stroke then stretched.
		# The animal swam with its sides torn open. Dropping the buried ball from the
		# ownership set puts the seam at the body's surface, where a shoulder belongs. It is
		# still the PIVOT: that is what it is for.
		#
		# This is the job the wolf does with `leg_influence_ratio`, arrived at the other way
		# round. I wrote above that nearest-ball "needs no influence radius to tune"; that was
		# wrong, and this is the tuning, just expressed as which balls count rather than as a
		# distance.
		for ball in (names as Array).slice(1):
			flipper_of[ball] = [pair, right, left]

	# --- where each ball actually sits ----------------------------------------------------
	var ball_at: Dictionary = {}
	for ball in _all_balls(_rig):
		ball_at[String(ball.name)] = _rig._position_in_rig(ball)
	for entry in ball_owner:
		if not ball_at.has(entry):
			push_warning("Plesiosaur swimmer: no ball named '%s'; the cut will be wrong." % entry)
			return false
	for pair in FLIPPERS:
		for entry in (pair as Array):
			if not ball_at.has(entry):
				push_warning("Plesiosaur swimmer: no ball named '%s'; the cut will be wrong." % entry)
				return false

	# --- every vertex to its piece --------------------------------------------------------
	# NEAREST BALL, not a distance to a centre line. The wolf measures distance to the leg's
	# line because a leg is a line; a neck is a chain of sections and the sections ARE the
	# balls, so the nearest ball is both simpler and exactly right - a vertex was generated
	# from the section nearest it. It also needs no influence radius to tune, which is the
	# parameter the wolf's comments spend the most words apologising for.
	var owner := PackedInt32Array()
	owner.resize(rest.size())
	for v in rest.size():
		var point: Vector4 = rest[v]
		var best: int = body_index
		var best_distance: float = INF
		for name in ball_at:
			var is_flipper: bool = flipper_of.has(name)
			# A ball that owns nothing is skipped entirely rather than being allowed to win
			# the nearest test and then fail the owner lookup - which is what a buried
			# shoulder ball did as soon as it was dropped from the ownership set.
			if not is_flipper and not ball_owner.has(name):
				continue
			var at: Vector4 = ball_at[name]
			if is_flipper and point.x < 0.0:
				at = Vector4(-at.x, at.y, at.z, at.w)
			var distance: float = point.distance_squared_to(at)
			if distance >= best_distance:
				continue
			best_distance = distance
			if is_flipper:
				var sides: Array = flipper_of[name]
				best = sides[1] if point.x >= 0.0 else sides[2]
			else:
				best = ball_owner[name]
		owner[v] = best

	# --- pivots: the seam, not the ball ---------------------------------------------------
	# A piece turns about the boundary it meets its parent at, which is halfway between the
	# last ball of the parent and the first of the child. Turning about the child's own first
	# ball instead would swing the piece's back end into the parent, because the cut sits
	# behind that ball, not on it.
	for index in plan.size():
		var entry: Dictionary = plan[index]
		var parent: int = entry["parent"]
		if parent < 0:
			entry["pivot"] = Vector4()
			continue
		var mine: Vector4 = ball_at[(entry["balls"] as Array)[0]]
		var theirs: Vector4 = _nearest_ball_of(plan[parent], ball_at, mine)
		var pivot: Vector4 = (mine + theirs) * 0.5
		if entry["kind"] == "flipper" and entry["side"] < 0.0:
			pivot = Vector4(-pivot.x, pivot.y, pivot.z, pivot.w)
		entry["pivot"] = pivot

	# --- cells into buckets, disagreements into bands -------------------------------------
	var cells: PackedInt32Array = mesh.simplex_cell_vertex_indices
	var textures: PackedInt32Array = mesh.simplex_cell_texture_map_indices
	var normals: PackedInt32Array = mesh.simplex_cell_normal_indices
	var boundary: PackedVector4Array = mesh.simplex_cell_boundary_normals
	var has_textures: bool = textures.size() == cells.size()
	var has_normals: bool = normals.size() == cells.size()
	var has_boundary: bool = boundary.size() == cells.size() / 4

	# Plain Arrays while they grow: a PackedInt32Array pulled out of an Array is a VALUE, so
	# appending to it grows a copy that is thrown away and every bucket stays empty. The wolf
	# records losing a whole hide to exactly this.
	var buckets: Array = []
	for _i in plan.size():
		buckets.append([[], [], [], []])
	var bands: Dictionary = {}            # child piece index -> array of cell indices

	for cell in cells.size() / 4:
		var k: int = cell * 4
		var first: int = owner[cells[k]]
		var agreed: bool = true
		for j in range(1, 4):
			if owner[cells[k + j]] != first:
				agreed = false
				break
		var target: int = first
		if not agreed:
			# Which seam does it straddle? The deeper of the two pieces involved names it,
			# because a seam is identified by its child. A cell touching three pieces is
			# counted for the deepest, which is rare and never more than one cell wide.
			var deepest: int = first
			for j in range(1, 4):
				var candidate: int = owner[cells[k + j]]
				if _depth_of(candidate, parent_of) > _depth_of(deepest, parent_of):
					deepest = candidate
			if blend_joints and deepest != body_index:
				if not bands.has(deepest):
					bands[deepest] = []
				(bands[deepest] as Array).append(cell)
				continue
			# Without joint patches the cell has to be carried rigidly by somebody; its
			# parent-most owner keeps the surface anchored to the body rather than flying off
			# with a limb.
			target = first
			for j in range(1, 4):
				var other: int = owner[cells[k + j]]
				if _depth_of(other, parent_of) < _depth_of(target, parent_of):
					target = other
		var bucket: Array = buckets[target]
		for j in 4:
			(bucket[0] as Array).append(cells[k + j])
			if has_textures:
				(bucket[1] as Array).append(textures[k + j])
			if has_normals:
				(bucket[2] as Array).append(normals[k + j])
		if has_boundary:
			(bucket[3] as Array).append(boundary[cell])

	# --- pieces as nodes, chained so Node4D composes them ---------------------------------
	var nodes: Array = []
	nodes.resize(plan.size())
	for index in plan.size():
		var entry: Dictionary = plan[index]
		var node := MeshInstance4D.new()
		node.name = entry["name"]
		var bucket: Array = buckets[index]
		if not (bucket[0] as Array).is_empty():
			var piece := ArrayTetraMesh4D.new()
			# SHARED, not copied: every piece indexes the same 4460 vertices and differs only
			# in which cells it names. Cutting therefore costs no vertex memory at all.
			piece.vertex_positions = mesh.vertex_positions
			piece.normal_values = mesh.normal_values
			piece.texture_map_values = mesh.texture_map_values
			piece.simplex_cell_vertex_indices = PackedInt32Array(bucket[0])
			piece.simplex_cell_texture_map_indices = PackedInt32Array(bucket[1])
			piece.simplex_cell_normal_indices = PackedInt32Array(bucket[2])
			piece.simplex_cell_boundary_normals = PackedVector4Array(bucket[3])
			node.mesh = piece
		node.material_override = _rig.material_override
		nodes[index] = node

	for index in plan.size():
		var parent: int = parent_of[index]
		if parent < 0:
			_rig.add_child(nodes[index])
		else:
			(nodes[parent] as Node).add_child(nodes[index])

	_pieces.clear()
	for index in plan.size():
		var entry: Dictionary = plan[index]
		_pieces.append({
			"node": nodes[index], "pivot": entry["pivot"], "kind": entry["kind"],
			"index": entry["index"], "is_head": entry["is_head"],
			"side": entry.get("side", 1.0), "pair": entry.get("pair", 0),
		})

	# --- joint patches --------------------------------------------------------------------
	_joints.clear()
	for child in bands:
		var patch: Variant = _joint_patch(mesh, bands[child], child, owner, plan,
				nodes[parent_of[child]])
		if patch != null:
			_joints.append(patch)

	# The rig itself now draws nothing: every cell it built belongs to a piece.
	_rig.mesh = null
	return true


## One seam's skin: the straddling cells, given a vertex array of their own so that posing it
## hands the renderer a few hundred vertices rather than the whole animal.
func _joint_patch(mesh: ArrayTetraMesh4D, band: Array, child: int, owner: PackedInt32Array,
		plan: Array, parent_node: Node) -> Variant:
	if band.is_empty():
		return null
	var cells: PackedInt32Array = mesh.simplex_cell_vertex_indices
	var textures: PackedInt32Array = mesh.simplex_cell_texture_map_indices
	var normals: PackedInt32Array = mesh.simplex_cell_normal_indices
	var boundary: PackedVector4Array = mesh.simplex_cell_boundary_normals
	var source: PackedVector4Array = mesh.get_vertex_positions()
	var has_textures: bool = textures.size() == cells.size()
	var has_normals: bool = normals.size() == cells.size()
	var has_boundary: bool = boundary.size() == cells.size() / 4

	var remap: Dictionary = {}
	var rest := PackedVector4Array()
	var weight := PackedFloat32Array()
	var out_cells: Array = []
	var out_textures: Array = []
	var out_normals: Array = []
	var out_boundary: Array = []
	for cell in band:
		var k: int = int(cell) * 4
		for j in 4:
			var v: int = cells[k + j]
			if not remap.has(v):
				remap[v] = rest.size()
				rest.append(source[v])
				# 1 where the vertex belongs to the moving side, 0 where it belongs to the
				# parent. A hard split rather than a falloff, which makes the patch STRETCH
				# across the seam instead of tearing - the same job the wolf's blend does.
				weight.append(1.0 if owner[v] == child else 0.0)
			out_cells.append(remap[v])
			if has_textures:
				out_textures.append(textures[k + j])
			if has_normals:
				out_normals.append(normals[k + j])
		if has_boundary:
			out_boundary.append(boundary[int(cell)])

	var patch := ArrayTetraMesh4D.new()
	patch.vertex_positions = rest
	patch.normal_values = mesh.normal_values
	patch.texture_map_values = mesh.texture_map_values
	patch.simplex_cell_vertex_indices = PackedInt32Array(out_cells)
	patch.simplex_cell_texture_map_indices = PackedInt32Array(out_textures)
	patch.simplex_cell_normal_indices = PackedInt32Array(out_normals)
	patch.simplex_cell_boundary_normals = PackedVector4Array(out_boundary)

	var node := MeshInstance4D.new()
	node.name = "%sSeam" % (plan[child] as Dictionary)["name"]
	node.mesh = patch
	node.material_override = _rig.material_override
	# Parented to the PARENT piece, so the patch sits in the frame its still half belongs to
	# and only its moving half has to be worked out each frame.
	parent_node.add_child(node)
	return {"mesh": patch, "rest": rest, "weight": weight, "child": child,
			"posed": rest.duplicate()}


## Poses one seam: each vertex where its own side would put it, blended by its weight.
func _pose_joint(joint: Dictionary) -> void:
	var child: int = joint["child"]
	var piece: Dictionary = _pieces[child]
	var node: Node4D = piece["node"]
	var turn: Projection = node.basis
	var shift: Vector4 = node.position
	var rest: PackedVector4Array = joint["rest"]
	var weight: PackedFloat32Array = joint["weight"]
	var posed: PackedVector4Array = joint["posed"]
	for i in rest.size():
		var v: Vector4 = rest[i]
		if weight[i] <= 0.0:
			posed[i] = v
			continue
		posed[i] = v.lerp(turn * v + shift, weight[i])
	(joint["mesh"] as ArrayTetraMesh4D).vertex_positions = posed


## The ball of [param entry] closest to [param toward], so a seam lands between the two balls
## that actually face each other rather than between arbitrary ends of two groups.
func _nearest_ball_of(entry: Dictionary, ball_at: Dictionary, toward: Vector4) -> Vector4:
	var best: Vector4 = toward
	var best_distance: float = INF
	for name in (entry["balls"] as Array):
		var at: Vector4 = ball_at[name]
		var distance: float = at.distance_squared_to(toward)
		if distance < best_distance:
			best_distance = distance
			best = at
	return best


func _depth_of(index: int, parent_of: PackedInt32Array) -> int:
	var depth: int = 0
	var at: int = index
	while at >= 0 and parent_of[at] >= 0 and depth < 32:
		at = parent_of[at]
		depth += 1
	return depth


func _all_balls(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		if child.has_method("get_loft_section"):
			found.append(child)
			found.append_array(_all_balls(child))
	return found
