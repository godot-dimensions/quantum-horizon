@tool
extends Node4D
class_name WGapBuilder4D

## ONE ROOM. ONE GAP. ONE IDEA.
##
## The smallest thing that can prove the 4D verb is worth building a course
## around: a gap too wide to jump, and a bridge that exists only somewhere else
## along w. Walk to the edge, slide along w, the bridge is there, cross, slide
## back. If that does not feel good, no amount of tower scaffolding will save it.
##
## Everything the earlier greybox spent its effort on - tiers, spine, bays,
## checkpoints, stair catalogues - is deliberately absent. That course had no 4D
## content at all: it was a staircase tower with w as decoration, which is why
## slicing felt like nothing was happening. Nothing here exists except the verb.
##
## THE READABILITY TRICK, taken from Miegakure: the ground is not one w-invariant
## slab, it is a STACK of slabs along w, each a different colour. A 4D world is
## otherwise invisible - a box either exists in your slice or it does not, with
## no partial reveal to hint at what is next door - so without this, moving along
## w changes nothing on screen until something abruptly pops in. With it, the
## floor under your feet changes colour the moment you leave a band, and "I am
## somewhere else now" needs no HUD to say it.

const Palette := preload("res://ramon/Demo/scripts/hub_palette.gd")
const SurfaceMaterial := preload("res://ramon/Demo/scripts/hub_material_4d.gd")

const GENERATED_META := &"w_gap_generated"

## Measured in `_audit_probe.gd`: walk-jump reach at SPEED 5.0 with no sprint.
## The gap must beat this or the puzzle has a boring solution.
const MEASURED_WALK_JUMP_REACH := 4.592

## Measured jump apex: JUMP_VELOCITY 4.5 against gravity 9.8.
const MEASURED_JUMP_APEX := 1.033


@export_group("The gap")

## Width of the unjumpable gap. Must exceed [constant MEASURED_WALK_JUMP_REACH];
## [method rebuild] warns if it does not, because a jumpable gap quietly deletes
## the entire point of the room.
@export var gap_width: float = 7.0:
	set(value):
		gap_width = value
		rebuild()

## Length of the standing ledge on each side of the gap.
@export var ledge_length: float = 22.0:
	set(value):
		ledge_length = value
		rebuild()

@export var walkway_width: float = 6.0:
	set(value):
		walkway_width = value
		rebuild()

@export_group("W bands")

## Centre of each w band, and its colour. The player starts in band 1 (w = 0);
## the bridge lives in band 2.
@export var band_centres: PackedFloat32Array = PackedFloat32Array([-5.0, 0.0, 5.0]):
	set(value):
		band_centres = value
		rebuild()

@export var band_colours: Array[String] = ["yellow", "grey", "blue"]:
	set(value):
		band_colours = value
		rebuild()

## Bands are DERIVED to tile exactly, edge to edge, with no gap between them.
##
## Authoring the thickness by hand is a trap: at 4.4 thick on 5.0 spacing there
## is 0.6 m of pure nothing between each pair of bands, and since the player is
## only 0.5 m wide in w, sliding across that boundary drops you into the void
## with no floor under you at all. Bands that exactly abut share a plane, which
## is not an overlap - so no interpenetration either.
func _band_thickness() -> float:
	if band_centres.size() < 2:
		return 6.0
	return absf(band_centres[1] - band_centres[0])

## Which band the bridge spans the gap in. The whole puzzle is that this is not
## the band you start in.
@export var bridge_band: int = 2:
	set(value):
		bridge_band = value
		rebuild()

@export_group("Jump boxes")

## A row of boxes on the near ledge, each taller than the last, purely to find
## out by feel what is jumpable.
##
## They are w-invariant - present in every band - so they test the JUMP and
## nothing else. The measured numbers to compare against: step-up walks over
## anything up to 0.70 m, and the jump apex is 1.033 m, so 0.8 must be jumped,
## 1.0 should just go, and 1.2 should be impossible.
@export var show_jump_boxes: bool = true:
	set(value):
		show_jump_boxes = value
		rebuild()

@export var jump_box_heights: PackedFloat32Array = PackedFloat32Array([0.8, 1.0, 1.2]):
	set(value):
		jump_box_heights = value
		rebuild()

## Offset to one side of the walkway, so the main route stays clear.
##
## On the centre line they became a wall across the road: the 0.8 m box is above
## the step-up allowance, so anything walking the room without jumping simply
## stops at it. Off to the side they are there when you want them and out of the
## way when you do not.
@export var jump_box_z: float = 2.0:
	set(value):
		jump_box_z = value
		rebuild()

@export var jump_box_size: float = 1.8:
	set(value):
		jump_box_size = value
		rebuild()

@export_group("Ramp")

## A ramp you WALK up, at the far end of the room.
##
## It is a rotated box, but only VISUALLY. A rotated `BoxShape4D` collides as its
## enclosing axis-aligned box - measured at x5.11 taller at 15 degrees and x12.02
## at 45 - so a tilted collider is a huge invisible wall, nothing like the slope
## it draws. The tilt therefore lives on the MESH alone, and the real collision is
## a flight of small axis-aligned steps hidden inside the slab.
##
## That only works because `ascent_player_4d.gd` has step-up: with a 0.7 m
## allowance the steps are walked straight over and the ramp feels continuous.
## Without it, even a 1 cm step stops you dead.
@export var show_ramp: bool = true:
	set(value):
		show_ramp = value
		rebuild()

@export var ramp_rise: float = 3.0:
	set(value):
		ramp_rise = value
		rebuild()

@export var ramp_run: float = 8.0:
	set(value):
		ramp_run = value
		rebuild()

## Tread depth of the hidden collision steps.
##
## Matching this to the per-frame travel distance (0.083 m at 5 m/s and 60 fps)
## would make the rise continuous, and does - but it takes ~100 colliders per ramp
## per w band, which measured out at roughly 7 fps. Collider count is the wrong
## lever. The body still steps at this tread; `ascent_player_4d.gd` smooths the
## CAMERA over it instead, which is what the player actually sees.
@export var ramp_tread: float = 0.2:
	set(value):
		ramp_tread = value
		rebuild()

@export_group("W step")

## The ascent primitive: a ledge you cannot reach, and a step in another w band
## that gets you onto it.
##
## Every height here is picked against measured limits, not by feel:
##   high ledge  1.5 m above the landing - jump apex is 1.033 m and the step-up
##               allowance is 0.7 m, so from the landing it is flatly impossible
##   helper step 0.9 m - inside the jump apex, so it CAN be jumped onto
##   the gap between them is 0.6 m - inside the step-up allowance, so from the
##               helper you WALK onto the high ledge
##
## The high ledge exists in every band, so once you are up you can shift home.
## Only the helper is conditional.
@export var show_w_step: bool = true:
	set(value):
		show_w_step = value
		rebuild()

## Height of the unreachable ledge above the landing it stands on.
@export var w_step_high: float = 1.5:
	set(value):
		w_step_high = value
		rebuild()

## Height of the helper step. Must be under the 1.033 m jump apex, and within the
## 0.7 m step-up allowance of [member w_step_high].
@export var w_step_helper: float = 0.9:
	set(value):
		w_step_helper = value
		rebuild()

## Which band the helper lives in. Deliberately NOT the bridge's band, so the
## room teaches both directions along w rather than only ana.
@export var w_step_band: int = 0:
	set(value):
		w_step_band = value
		rebuild()

@export_group("W lift")

## A cubinder disc that ferries you ACROSS a stretch of w with no floor in it.
##
## The lift has to earn its place: you can already walk along w whenever you
## like, so a lift that merely moves you along w is a slower version of pressing
## a key. What makes it necessary is the VOID - a run of w between the two pads
## where there is simply nothing to stand on. Walk into it and you fall; ride
## across and you do not.
##
## The platform is a plain box. A cubinder was the interesting option - the only
## curved 4D shape that both draws itself and has a flat top, so its bounding box
## matches the surface you see - but it carries zero uvw entries, cannot be
## textured, and its flat-shaded cross-section looks like a scribble. A spherinder
## (`CylinderShape4D` here) is worse on both counts: `to_tetra_mesh()` returns
## null so it cannot be drawn at all, and its dome would leave you standing on an
## invisible box above the visible surface.
@export var show_w_lift: bool = true:
	set(value):
		show_w_lift = value
		rebuild()

## How far along w the lift travels. The void spans almost all of it.
@export var lift_travel_w: float = 14.0:
	set(value):
		lift_travel_w = value
		rebuild()

## Half the platform's width. Named for the disc it used to be; it is a box now.
@export var lift_radius: float = 2.2:
	set(value):
		lift_radius = value
		rebuild()

## How far the lift's top sits above the pad it launches from.
##
## Needs to be a clear STEP, not a flush join. Flush made the boundary ambiguous:
## the lift could not tell whether you were on it or merely beside it, and chose
## wrongly. Comfortably inside the 0.7 m step-up allowance, so you still walk on.
@export var lift_step_up: float = 0.4:
	set(value):
		lift_step_up = value
		rebuild()

## Thickness of the lift platform, and how far its underside clears the pad.
##
## The lift used to be a full slab_thickness tall sitting AT the pad's height,
## which put its box in exactly the same y range as the pad's - same x, same z,
## overlapping w - so the two interpenetrated whenever it was home. A nudge
## upward alone does not fix that: at 0.5 m thick it still overlaps unless lifted
## a whole slab. Thin, and resting on top, clears it outright and leaves a lip
## small enough to walk over without noticing.
@export var lift_thickness: float = 0.15:
	set(value):
		lift_thickness = value
		rebuild()

@export var lift_speed: float = 3.0:
	set(value):
		lift_speed = value
		rebuild()

@export_group("Braided corridor")

## Two walkways that share one stretch of the room but live in different w bands,
## drifting across each other in plan so they cross without ever touching.
##
## This is the half of the 4D vocabulary the room was missing. Everything else
## here APPEARS - the bridge, the helper step, the lift arrives. Nothing shared
## space with anything. Here two complete paths occupy the same corridor, and
## which one is under your feet depends only on where you are along w.
##
## Each path has a gap the other covers, placed near the crossing point where the
## two are closest in z - so switching costs one w shift and barely any sideways
## movement, rather than a blind leap.
@export var show_braid: bool = true:
	set(value):
		show_braid = value
		rebuild()

## The two bands the paths live in. The first is the band the lift delivers you
## to, so the corridor begins where the lift ends.
@export var braid_w_a: float = 14.0:
	set(value):
		braid_w_a = value
		rebuild()

@export var braid_w_b: float = 9.0:
	set(value):
		braid_w_b = value
		rebuild()

@export var braid_length: float = 26.0:
	set(value):
		braid_length = value
		rebuild()

## How far each path drifts sideways across the run. They drift opposite ways, so
## this is what makes them cross rather than run parallel.
@export var braid_drift: float = 1.8:
	set(value):
		braid_drift = value
		rebuild()

@export var braid_width: float = 2.6:
	set(value):
		braid_width = value
		rebuild()

@export_group("Look")

@export var slab_thickness: float = 0.5:
	set(value):
		slab_thickness = value
		rebuild()

@export var use_dev_textures: bool = true:
	set(value):
		use_dev_textures = value
		rebuild()

@export var texture_metres: float = 2.0:
	set(value):
		texture_metres = value
		rebuild()

@export_tool_button("Rebuild room") var _rebuild_action: Callable = rebuild


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	# Nil-tolerant guard: a @tool script that gained exports while its scene was
	# open reads them back as Nil until reload, and a Nil bool is silently false.
	if typeof(use_dev_textures) != TYPE_BOOL:
		push_warning("WGapBuilder4D: stale @tool properties. Reload the scene.")
		return
	if not is_inside_tree():
		return
	_clear_generated()

	if show_w_step:
		if w_step_high <= MEASURED_JUMP_APEX:
			push_warning("WGapBuilder4D: the high ledge at %.2f m is inside the %.2f m jump apex, so it can be jumped without using w at all." % [w_step_high, MEASURED_JUMP_APEX])
		if w_step_helper >= MEASURED_JUMP_APEX:
			push_warning("WGapBuilder4D: the helper step at %.2f m is at or above the %.2f m jump apex, so it cannot be jumped onto either." % [w_step_helper, MEASURED_JUMP_APEX])
		if w_step_high - w_step_helper > 0.7:
			push_warning("WGapBuilder4D: %.2f m from helper to high ledge exceeds the 0.70 m step-up allowance, so the last move is impossible." % (w_step_high - w_step_helper))

	if gap_width <= MEASURED_WALK_JUMP_REACH:
		push_warning("WGapBuilder4D: a %.1f m gap is inside the %.2f m walk-jump reach, so it can be jumped and the 4D route is pointless. Widen it." % [gap_width, MEASURED_WALK_JUMP_REACH])

	var band_thickness: float = _band_thickness()
	var half_gap: float = gap_width * 0.5
	var near_centre: float = -half_gap - ledge_length * 0.5
	var far_centre: float = half_gap + ledge_length * 0.5

	if show_jump_boxes:
		_build_jump_boxes(near_centre, band_thickness)
	if show_ramp and show_w_step and show_w_lift:
		# Past the high ledge, continuing the same line, at its height.
		var ramp_start: float = far_centre + ledge_length * 0.5 + ramp_run
		var lift_x: float = ramp_start + ledge_length + 1.0
		_build_w_lift(lift_x, ramp_rise + w_step_high)
		if show_braid:
			# Starts where the lift drops you off, so the far pad is no longer a
			# dead end.
			_build_braid(lift_x + 7.0, ramp_rise + w_step_high)

	for index in band_centres.size():
		var w: float = band_centres[index]
		var colour: String = band_colours[index] if index < band_colours.size() else "grey"
		# Both ledges exist in EVERY band, so the room itself is continuous
		# however far along w you slide. Only the bridge is conditional - if the
		# ground vanished too, sliding would read as falling out of the world
		# rather than as stepping sideways into a different version of it.
		_slab("Ledge%d_Near" % index, Vector4(ledge_length, slab_thickness, walkway_width, band_thickness),
				Vector4(near_centre, -slab_thickness * 0.5, 0.0, w), colour)
		_slab("Ledge%d_Far" % index, Vector4(ledge_length, slab_thickness, walkway_width, band_thickness),
				Vector4(far_centre, -slab_thickness * 0.5, 0.0, w), colour)
		if index == bridge_band:
			_slab("Bridge", Vector4(gap_width, slab_thickness, walkway_width, band_thickness),
					Vector4(0.0, -slab_thickness * 0.5, 0.0, w), colour)
		if show_ramp:
			_build_ramp(index, far_centre + ledge_length * 0.5, w, band_thickness, colour)
			if show_w_step:
				_build_w_step(index, far_centre + ledge_length * 0.5 + ramp_run, w, band_thickness, colour)


## Two interleaved paths across the same corridor, one per band.
##
## Built from short segments so a gap is just a segment that was never made. The
## gaps sit either side of the middle, where the two paths are closest in z.
func _build_braid(start_x: float, deck_top: float) -> void:
	const SEGMENTS := 13
	var seg_length: float = braid_length / float(SEGMENTS)
	# Each gap must be WIDER THAN THE JUMP, or the whole obstacle is optional: at
	# one segment (2 m) both gaps sat inside the 4.59 m walk-jump reach, so the
	# corridor could be run straight down one lane without ever changing band.
	# Three segments is 6 m, comfortably past it.
	var gap_segments: int = maxi(1, int(ceil((MEASURED_WALK_JUMP_REACH + 1.0) / seg_length)))
	# Gaps STRADDLE THE CROSSING, where the two lanes are nearest in z.
	#
	# Placed further out they force a switch at a point where the lanes are 2.2 m
	# apart sideways, so changing band drops you into the void between them - the
	# switch would demand a simultaneous w shift and strafe onto a path you cannot
	# see. Around the crossing the lanes overlap heavily, so a switch is one key.
	var crossing: int = SEGMENTS / 2
	var gap_a_start: int = crossing + 1
	var gap_b_start: int = maxi(0, crossing - gap_segments)

	for lane in 2:
		var w: float = braid_w_a if lane == 0 else braid_w_b
		var colour: String = "red" if lane == 0 else "blue"
		var gap_start: int = gap_a_start if lane == 0 else gap_b_start
		# Opposite drift directions: this is the braid.
		var from_z: float = -braid_drift if lane == 0 else braid_drift
		var to_z: float = braid_drift if lane == 0 else -braid_drift
		for index in SEGMENTS:
			if index >= gap_start and index < gap_start + gap_segments:
				continue
			var t: float = (float(index) + 0.5) / float(SEGMENTS)
			_slab("Braid%d_%02d" % [lane, index],
					Vector4(seg_length, slab_thickness, braid_width, 5.0),
					Vector4(start_x + braid_length * t, deck_top - slab_thickness * 0.5,
							lerpf(from_z, to_z, t), w),
					colour)

	# Somewhere to arrive, spanning both bands so either lane can finish.
	var end_x: float = start_x + braid_length + 3.0
	var end_w: float = (braid_w_a + braid_w_b) * 0.5
	var end_span_z: float = braid_width * 3.0
	var end_span_w: float = absf(braid_w_a - braid_w_b) + 10.0
	_slab("BraidEnd", Vector4(6.0, slab_thickness, end_span_z, end_span_w),
			Vector4(end_x, deck_top - slab_thickness * 0.5, 0.0, end_w), "white")

	# The finish. Tall and as w-broad as the pad, so arriving in either lane
	# counts and nobody can stand on the end pad without triggering it.
	var goal := Area4D.new()
	goal.name = "CourseGoal"
	goal.position = Vector4(end_x, deck_top + 1.5, 0.0, end_w)
	goal.set_meta(GENERATED_META, true)
	goal.set_script(load("res://ramon/ObstacleCourse/scripts/course_goal_4d.gd"))
	var goal_collider := CollisionShape4D.new()
	var goal_shape := BoxShape4D.new()
	goal_shape.size = Vector4(6.0, 3.0, end_span_z, end_span_w)
	goal_collider.shape = goal_shape
	goal.add_child(goal_collider)
	add_child(goal)


## The W lift: two pads separated by a stretch of w with no floor, and a disc
## that crosses it.
##
## Built once, outside the per-band loop, because its pads are placed at explicit
## w values rather than in the room's bands - the whole point is the empty w
## between them, which a banded floor would fill in.
func _build_w_lift(start_x: float, deck_top: float) -> void:
	var pad_depth: float = 6.0
	var pad_w_thickness: float = 5.0
	var centre_x: float = start_x + pad_depth * 0.5

	# Board here, in the home band.
	_slab("LiftPadNear", Vector4(pad_depth, slab_thickness, walkway_width, pad_w_thickness),
			Vector4(centre_x, deck_top - slab_thickness * 0.5, 0.0, 0.0), "grey")
	# Arrive here, a long way along w. Red so the destination reads as somewhere
	# else rather than as more of the same floor.
	_slab("LiftPadFar", Vector4(pad_depth, slab_thickness, walkway_width, pad_w_thickness),
			Vector4(centre_x, deck_top - slab_thickness * 0.5, 0.0, lift_travel_w), "red")

	# Resting ON the pads, not inside them: underside a hair above the pad top.
	var lift_bottom: float = deck_top + lift_step_up
	var lift := Node4D.new()
	lift.name = "WLift"
	lift.position = Vector4(centre_x, lift_bottom + lift_thickness * 0.5, 0.0, 0.0)
	lift.set_meta(GENERATED_META, true)
	var script: Script = load("res://ramon/ObstacleCourse/scripts/w_lift_4d.gd")
	lift.set_script(script)
	lift.set("w_from", 0.0)
	lift.set("w_to", lift_travel_w)
	lift.set("speed", lift_speed)
	lift.set("half_extent", lift_radius)
	lift.set("top_y", lift_bottom + lift_thickness)

	# A BOX, not the cubinder this started as. The cubinder is the only curved 4D
	# shape that both draws itself and has a flat top, so mechanically it was
	# fine - but it carries zero uvw entries, so it cannot be textured, and its
	# flat-shaded cross-section reads as a scribble rather than a platform. A box
	# textures at the room's own scale and collides exactly as it looks.
	var size := Vector4(lift_radius * 2.0, lift_thickness, lift_radius * 2.0, 4.0)
	var shape := BoxShape4D.new()
	shape.size = size

	var collider := CollisionShape4D.new()
	collider.shape = shape
	lift.add_child(collider)

	var mesh_instance := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = SurfaceMaterial.surface("yellow", size, texture_metres, use_dev_textures)
	lift.add_child(mesh_instance)
	add_child(lift)


## The unreachable ledge, and the helper step that reaches it.
##
## Both sit on top of the ramp's landing, at its far end. The two are flush in x
## on purpose: step-up only fires when the horizontal move is actually blocked, so
## the helper has to be up against the high ledge for walking off it to work.
func _build_w_step(index: int, ramp_start: float, w: float, band_thickness: float, colour: String) -> void:
	var landing_top: float = ramp_rise
	var landing_end: float = ramp_start + ledge_length
	var high_depth: float = 6.0
	var helper_depth: float = 2.5

	var high_far: float = landing_end - 0.5
	var high_near: float = high_far - high_depth

	# Present in EVERY band: it is the destination, and a destination that came
	# and went with the slice would be a trap rather than a goal.
	_slab("HighLedge%d" % index,
			Vector4(high_depth, w_step_high, walkway_width, band_thickness),
			Vector4((high_near + high_far) * 0.5, landing_top + w_step_high * 0.5, 0.0, w), colour)

	if index != w_step_band:
		return
	# The one conditional piece. Flush against the high ledge so that stepping off
	# it is a blocked horizontal move, which is what step-up needs to trigger.
	_slab("HelperStep",
			Vector4(helper_depth, w_step_helper, walkway_width, band_thickness),
			Vector4(high_near - helper_depth * 0.5, landing_top + w_step_helper * 0.5, 0.0, w), colour)


## Boxes to jump onto, spaced along the near ledge in front of the spawn.
##
## Deliberately isolated - you jump ON one, then off it - rather than a staircase.
## The question they answer is "how high can I get", which a flight of steps
## hides behind step-up.
func _build_jump_boxes(near_centre: float, band_thickness: float) -> void:
	var count: int = jump_box_heights.size()
	if count == 0:
		return
	var span: float = ledge_length - jump_box_size * 2.0
	for index in count:
		var height: float = jump_box_heights[index]
		var t: float = (float(index) + 1.0) / float(count + 1)
		var x: float = near_centre - span * 0.5 + span * t
		# One box across every band, so it is a jump test and not a w puzzle.
		var w_span: float = band_thickness * float(maxi(band_centres.size(), 1))
		var body := _make_box("JumpBox_%d" % index,
				Vector4(jump_box_size, height, jump_box_size, w_span),
				Vector4(x, height * 0.5, jump_box_z, 0.0), "white")
		add_child(body)


## One walkable ramp: a tilted mesh with a stepped collider inside it, plus a
## landing at the top so there is somewhere to arrive.
func _build_ramp(index: int, start_x: float, w: float, band_thickness: float, colour: String) -> void:
	var angle: float = atan2(ramp_rise, ramp_run)
	var steps: int = maxi(1, int(ceil(ramp_run / ramp_tread)))
	var rise_per_step: float = ramp_rise / float(steps)
	if index == 0 and rise_per_step > 0.7:
		push_warning("WGapBuilder4D: ramp steps rise %.2f m, above the player's 0.7 m step-up allowance - the ramp will not be walkable. Reduce ramp_tread or ramp_rise." % rise_per_step)

	# The drawn slab: rotated in the x/y plane so its length rises along +x.
	# Mesh only - no collider anywhere on this node.
	var visual := Node4D.new()
	visual.name = "Ramp%d_Visual" % index
	var slope_length: float = sqrt(ramp_run * ramp_run + ramp_rise * ramp_rise)
	visual.basis = Basis4D.from_xy(angle)
	# Offset by half the slab thickness along the slab's OWN normal, so its TOP
	# SURFACE runs from (start_x, 0) to (start_x + run, rise) - flush with the
	# ledge it leaves and the landing it meets. Placing the slab centre on that
	# line instead, which is the obvious thing to do, floats the walking surface
	# half a thickness above the ledge and leaves the visible lip at the joint.
	var normal := Vector2(-sin(angle), cos(angle))
	visual.position = Vector4(
			start_x + ramp_run * 0.5 - normal.x * slab_thickness * 0.5,
			ramp_rise * 0.5 - normal.y * slab_thickness * 0.5,
			0.0, w)
	visual.set_meta(GENERATED_META, true)
	var mesh_instance := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	var ramp_size := Vector4(slope_length, slab_thickness, walkway_width, band_thickness)
	mesh.size = ramp_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = SurfaceMaterial.surface(colour, ramp_size, texture_metres, use_dev_textures)
	visual.add_child(mesh_instance)
	add_child(visual)

	# The real thing you stand on. Each step's top is centred on the drawn slope,
	# so the player's feet never sit more than half a rise from the visible
	# surface - at these numbers about 9 cm, which reads as a smooth ramp.
	var collision := Node4D.new()
	collision.name = "Ramp%d_Steps" % index
	collision.set_meta(GENERATED_META, true)
	add_child(collision)
	for step_index in range(steps):
		var t: float = (float(step_index) + 0.5) / float(steps)
		var top: float = ramp_rise * t
		collision.add_child(_make_collider("Step_%03d" % step_index,
				Vector4(ramp_tread, slab_thickness, walkway_width, band_thickness),
				Vector4(start_x + ramp_run * t, top - slab_thickness * 0.5, 0.0, w)))

	_slab("Landing%d" % index, Vector4(ledge_length, slab_thickness, walkway_width, band_thickness),
			Vector4(start_x + ramp_run + ledge_length * 0.5, ramp_rise - slab_thickness * 0.5, 0.0, w), colour)


func _slab(node_name: String, size: Vector4, position: Vector4, palette_name: String) -> void:
	add_child(_make_box(node_name, size, position, palette_name))


## Collision with no mesh. The drawn ramp is the thing you see, and at a 0.08 m
## tread there are hundreds of these - building a tetrahedral mesh for each one
## purely to hide it is waste.
func _make_collider(node_name: String, size: Vector4, position: Vector4) -> StaticBody4D:
	var body := StaticBody4D.new()
	body.name = node_name
	body.position = position
	body.set_meta(GENERATED_META, true)
	var collider := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body


func _make_box(node_name: String, size: Vector4, position: Vector4, palette_name: String) -> StaticBody4D:
	var body := StaticBody4D.new()
	body.name = node_name
	body.position = position
	body.set_meta(GENERATED_META, true)

	var collider := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

	var mesh_instance := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = SurfaceMaterial.surface(palette_name, size, texture_metres, use_dev_textures)
	body.add_child(mesh_instance)
	return body


func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			remove_child(child)
			child.queue_free()
