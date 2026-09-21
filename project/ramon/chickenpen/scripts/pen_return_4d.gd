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
## COUNTED EXACTLY ONCE (item 43). The count is a property of the chicken, not a tally
## kept here: a bird that is already returned is skipped, so re-entry, a rapid double
## throw or a chicken wandering back over the line can never increment anything twice.

@export var fence_path: NodePath
@export var manager_path: NodePath

## How often to test, in frames. Item 79 asks for staggered low-priority work; a chicken
## crossing a fence does not need checking sixty times a second.
@export_range(1, 20, 1) var check_every: int = 3

var _fence: Node
var _manager: Node
var _rng := RandomNumberGenerator.new()
var _tick: int = 0


func _ready() -> void:
	_fence = get_node_or_null(fence_path)
	_manager = get_node_or_null(manager_path)
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
		# It is in the pen and has not been counted. Count it once, and only once.
		agent.call("on_landed", true)
		_manager.call("note_returned", agent)


## Item 44: a returned chicken that somehow leaves is put back, WITHOUT changing the
## score. Escaping should be an inconvenience, not a way to lose progress.
func _keep_in(agent: Node, body: Node4D, inside: bool) -> void:
	if inside:
		return
	var home: Vector4 = _fence.call("random_interior_point", _rng)
	body.position = home - _pen_origin()
	agent.set("home_position", body.position)


func _pen_origin() -> Vector4:
	var host: Node4D = null
	var body_parent: Node = _manager
	if body_parent != null:
		host = body_parent as Node4D
	return host.global_position if host != null else Vector4.ZERO
