extends Node

## Decides when a chicken counts as returned, and keeps the penned ones in.
##
## NO SECOND BOX (item 40). This does not own a volume; it asks the fence whether a point
## is inside it. The brief warns specifically against a separately sized detection box
## that drifts out of sync with the geometry, and the way to guarantee that cannot happen
## is to have only one description of where the pen is.
##
## NOT AN Area4D. Area4D detects PhysicsBody4D, and the chickens are plain Node4D - giving
## each of twelve birds a physics body to trigger a volume would add collision the brief
## asks to SIMPLIFY (item 78). Twelve point-in-box tests a frame costs nothing.
##
## DELIVERED, NOT MERELY PRESENT (item 43). Being inside the pen is not enough - the
## player must have HELD the bird at some point. Without that clause a chicken standing in
## the pen scores, and two ways of scoring nothing arise: one that spawns inside the fence
## and is counted before the player has moved, and one that wanders in unattended. The
## first actually happened here: chicken 7 was authored at z = -5.4 while the pen interior
## reaches z = -5.1, so the first W-lesson bird - the one the locator exists to teach with -
## was collected on frame one and never appeared in the hunt. A loose chicken found inside
## is now walked back out instead.
##
## COUNTED EXACTLY ONCE (item 43). The count is a property of the chicken, not a tally
## kept here: a bird that is already returned is skipped, so re-entry, a rapid double
## throw or a chicken wandering back over the line can never increment anything twice.

@export var fence_path: NodePath
@export var manager_path: NodePath
@export var coop_path: NodePath

## Item 48: one penned chicken in this many is sent to loiter by the coop instead of
## wherever it landed. Not all of them - twelve birds converging on three spots is a queue,
## and a few birds near the ramp with the rest spread out is what a pen actually looks
## like.
@export_range(1, 6, 1) var coop_share: int = 3

## How often to test, in frames. Item 79 asks for staggered low-priority work; a chicken
## crossing a fence does not need checking sixty times a second.
@export_range(1, 20, 1) var check_every: int = 3

var _fence: Node
var _manager: Node
var _rng := RandomNumberGenerator.new()
var _tick: int = 0
var _warned: Dictionary = {}
var _coop: Node


func _ready() -> void:
	_fence = get_node_or_null(fence_path)
	_manager = get_node_or_null(manager_path)
	_coop = get_node_or_null(coop_path)
	_rng.seed = 20260921
	if _fence == null:
		push_warning("PenReturn: fence_path resolves to nothing - no chicken can ever be returned (item 82).")
	if _manager == null:
		push_warning("PenReturn: manager_path resolves to nothing - nothing to watch.")


func _physics_process(_delta: float) -> void:
	if _fence == null or _manager == null:
		return
	_tick += 1
	if _tick % check_every != 0:
		return
	for agent in (_manager.get("agents") as Array):
		var body: Node4D = agent.get_parent() as Node4D
		if body == null:
			continue
		var inside: bool = bool(_fence.call("contains_point", body.global_position))
		if bool(agent.get("returned")):
			_keep_in(agent, body, inside)
			continue
		if not inside:
			continue
		if not bool(agent.get("ever_carried")):
			_eject(agent, body)
			continue
		# It is in the pen and has not been counted. Count it once, and only once.
		agent.call("on_landed", true)
		_manager.call("note_returned", agent)


## ITEM 48 IS NOW THE BIRD'S OWN BUSINESS, and this is where it used to be done TO it.
##
## A third of the birds had their home_position rewritten to a spot by the coop the
## instant they were counted - "their HOME moves, not their position", the idea being they
## would walk over rather than appear there. What it actually does is hand containment a
## destination the bird is not at, and containment tows it: drop a chicken in the pen and
## it slides off towards the coop and springs about on the leash. Outside the fence none
## of this runs, which is exactly why the fault only ever showed up inside it.
##
## A penned chicken goes to the coop by itself now - in at the door or up onto the roof,
## and back out again - so the behaviour this was reaching for exists without anything
## moving the bird. Wherever it lands, it stays and gets on with it.

## Item 44: a returned chicken that somehow leaves is put back, WITHOUT changing the
## score. Escaping should be an inconvenience, not a way to lose progress.
func _keep_in(agent: Node, body: Node4D, inside: bool) -> void:
	if inside:
		return
	var home: Vector4 = _fence.call("random_interior_point", _rng)
	body.position = home - _pen_origin()
	agent.set("home_position", body.position)


## Walks a never-carried chicken back out of the pen, the short way.
##
## It leaves through whichever wall it is nearest, so a bird that strayed one step over the
## line steps one back rather than being flung across the field. Its home moves with it,
## otherwise containment would tow it straight back in and it would bounce on the boundary
## forever.
func _eject(agent: Node, body: Node4D) -> void:
	var b: Array = _fence.call("interior_bounds")
	var fence_origin: Vector4 = (_fence as Node4D).global_position
	var lo: Vector4 = fence_origin + b[0]
	var hi: Vector4 = fence_origin + b[1]
	var at: Vector4 = body.global_position
	var clearance: float = 1.2

	# Distance to each of the four walls, and where leaving by it would put the bird.
	var exits := [
		[at.x - lo.x, Vector4(lo.x - clearance, at.y, at.z, at.w)],
		[hi.x - at.x, Vector4(hi.x + clearance, at.y, at.z, at.w)],
		[at.z - lo.z, Vector4(at.x, at.y, lo.z - clearance, at.w)],
		[hi.z - at.z, Vector4(at.x, at.y, hi.z + clearance, at.w)],
	]
	var best: Array = exits[0]
	for e in exits:
		if e[0] < best[0]:
			best = e
	var out: Vector4 = best[1]
	if not _warned.has(agent):
		_warned[agent] = true
		push_warning("PenReturn: chicken %s was inside the pen without ever being carried, so it was walked out rather than counted (item 43). If this fires on the first frame, its authored placement overlaps the fence." % str(agent.get("chicken_id")))
	body.position = out - _pen_origin()
	agent.set("home_position", body.position)


func _pen_origin() -> Vector4:
	var host: Node4D = null
	var body_parent: Node = _manager
	if body_parent != null:
		host = body_parent as Node4D
	return host.global_position if host != null else Vector4.ZERO
