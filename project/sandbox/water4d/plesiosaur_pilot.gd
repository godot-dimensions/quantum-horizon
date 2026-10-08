extends Node4D

## Swims the plesiosaur around the pool: a wandering course through all four axes, held
## between two depths and inside the pool's own walls.
##
## WANDERING RATHER THAN A FIXED PATH. A laid-out path is easy to make look right once and
## then reads as a fairground ride on the second lap - and the pool is a showcase somebody
## walks around in for minutes at a time. What makes a creature look like it is going
## somewhere is not the route but the TURN RATE: a heading that can only bend so fast per
## second never produces the instant direction changes that give wandering away. So the
## course is random and the heading is rate-limited, which is the cheap half of steering
## behaviour and the half that does the work here.
##
## THE FOURTH AXIS IS A REAL PROBLEM, not a free extra. Swimming through W means the animal
## leaves the player's slice: it is about 2 m thick that way, so anywhere past w = 2 it simply
## is not drawn. That is correct - it is what a 4D creature DOES - but a creature that spends
## most of its time invisible is a bad showcase, so `bounds.z` (the W half-extent) defaults
## much smaller than the X and Z ones. It drifts in and out of view rather than disappearing
## for a minute at a time. Raise it for a demonstration of exactly that, and turn the slice to
## go looking.
##
## Heading is also capped away from pointing straight along W, for the same reason as the
## bend in `plesiosaur_swimmer.gd`: a long thin animal whose length lies along W has almost no
## cross-section in the slice and reads as a floating sliver.

const _Plane = preload("res://ramon/chickenpen/scripts/plane_rotation_4d.gd")

## What to steer. Left empty, the pilot's own parent is driven.
@export var body_path: NodePath = NodePath("..")
## The swimmer on that body, so the head can be told to look at something.
@export var swimmer_path: NodePath = NodePath("../Swimmer")
## Who the head turns to look at.
@export var player_path: NodePath = NodePath("")

@export_group("Where it may go")
## Half-extents in x, z and W. W is deliberately much smaller - see the note above.
@export var bounds := Vector3(46.0, 46.0, 8.0)
## Metres below the surface, nearest and deepest. The pool floor is at 35 m, so the deeper
## figure wants to stay clear of it by more than the animal is tall.
@export var depth_range := Vector2(10.0, 32.0)

@export_group("How it swims")
## Deliberately slow. At 4 m/s a 9 m animal crosses the pool in twenty seconds and is gone
## before you have turned round; the brief was something you can spot and then keep track of.
@export_range(0.2, 8.0, 0.1, "suffix:m/s") var speed: float = 1.5
@export_range(2.0, 60.0, 1.0, "suffix:°/s") var turn_rate_degrees: float = 14.0
## How close counts as arrived. Generous, because a rate-limited heading cannot hit a point
## exactly and a tight radius makes the animal circle a waypoint it can never reach.
@export_range(1.0, 20.0, 0.5, "suffix:m") var waypoint_radius: float = 6.0
## Steepest climb or dive, as a fraction of the heading. Keeps it swimming rather than
## porpoising, and keeps `Basis4D.looking_at` away from its degenerate straight-up case.
@export_range(0.05, 0.8, 0.01) var climb_limit: float = 0.3
## Largest share of the heading that may lie along W, for the reason in the note above.
@export_range(0.05, 1.0, 0.01) var w_heading_limit: float = 0.5

@export_group("Attention")
## Mean seconds between glances at the player.
@export_range(2.0, 60.0, 0.5, "suffix:s") var attention_gap: float = 11.0
@export_range(0.5, 20.0, 0.5, "suffix:s") var attention_hold: float = 4.0
## Only bothers to look when the player is at least this close, in the full 4D distance - so
## it does not solemnly track somebody standing fifty metres away through W.
@export_range(5.0, 120.0, 1.0, "suffix:m") var attention_range: float = 55.0

var _body: Node4D = null
var _swimmer: Node = null
var _player: Node4D = null
var _heading := Vector4(0.0, 0.0, 1.0, 0.0)
var _goal := Vector4()
var _until_glance: float = 6.0
var _glancing: float = 0.0


func _ready() -> void:
	_body = get_node_or_null(body_path) as Node4D
	_swimmer = get_node_or_null(swimmer_path)
	if not player_path.is_empty():
		_player = get_node_or_null(player_path) as Node4D
	if _body == null:
		push_warning("Plesiosaur pilot: nothing to steer at %s." % body_path)
		set_physics_process(false)
		return
	_body.position = _pick_goal()
	_goal = _pick_goal()
	_until_glance = randf_range(attention_gap * 0.3, attention_gap)


func _physics_process(delta: float) -> void:
	var here: Vector4 = _body.position
	if here.distance_to(_goal) < waypoint_radius:
		_goal = _pick_goal()

	var wanted: Vector4 = _steer(here)
	_turn_toward(wanted, deg_to_rad(turn_rate_degrees) * delta)
	_body.position = _inside(here + _heading * speed * delta)
	# `use_model_front` is TRUE: the default builds a CAMERA basis, which faces -Z, and the
	# plesiosaur's nose is +Z. Without it the animal swims backwards, tail first, which looks
	# almost plausible from a distance and is maddening to diagnose.
	_body.basis = Basis4D.looking_at(_heading, _perpendicular_for(_heading),
			Vector4(0.0, 1.0, 0.0, 0.0), true)

	_attend(delta)


## Direction to the goal, flattened to a swimmable climb and kept off the W axis.
func _steer(here: Vector4) -> Vector4:
	var toward: Vector4 = _goal - here
	if toward.length() < 0.001:
		return _heading
	toward = toward.normalized()
	# Both limits are applied to the DIRECTION, not to the heading after turning, so the
	# rate-limited turn still arrives somewhere legal rather than being clamped mid-bend and
	# jittering against the limit.
	toward.y = clampf(toward.y, -climb_limit, climb_limit)
	toward.w = clampf(toward.w, -w_heading_limit, w_heading_limit)
	if toward.length() < 0.001:
		return _heading
	return toward.normalized()


## Bends the heading toward [param wanted] by at most [param step] radians. A plain Givens
## rotation in the plane the two span, which is the 4D version of "turn a bit that way" -
## there is no axis to turn about.
func _turn_toward(wanted: Vector4, step: float) -> void:
	var along: float = clampf(_heading.dot(wanted), -1.0, 1.0)
	var angle: float = acos(along)
	if angle <= step or angle < 0.0001:
		_heading = wanted
		return
	var sideways: Vector4 = wanted - _heading * along
	if sideways.length() < 0.00001:
		return
	_heading = (_heading * cos(step) + sideways.normalized() * sin(step)).normalized()


func _pick_goal() -> Vector4:
	return Vector4(
			randf_range(-bounds.x, bounds.x),
			-randf_range(minf(depth_range.x, depth_range.y), maxf(depth_range.x, depth_range.y)),
			randf_range(-bounds.y, bounds.y),
			_pick_w())


## W is NOT picked evenly across its range, the way the other axes are.
##
## Measured: with even picking the animal spent 22% of ten minutes within 1.2 m of w = 0, and
## the animal is only about 2 m thick that way - so for over three quarters of the time a
## player standing at w = 0 saw an empty pool. "Swims through all four axes" and "easy to
## spot and keep track of" both have to be true, and even picking gives up the second.
##
## Cubing a 0..1 roll pulls the distribution hard toward zero while leaving the whole range
## reachable: the median goal sits around an eighth of the limit, and a far excursion still
## happens every so often. The animal therefore lives near the player's slice and wanders out
## of it now and then, rather than treating w = 0 as one value among many.
func _pick_w() -> float:
	var roll: float = randf()
	return bounds.z * roll * roll * roll * (1.0 if randf() < 0.5 else -1.0)


## A hard clamp as well as the waypoints, because a rate-limited turn can overshoot a wall
## while it is still bending away from it.
func _inside(at: Vector4) -> Vector4:
	return Vector4(
			clampf(at.x, -bounds.x, bounds.x),
			clampf(at.y, -maxf(depth_range.x, depth_range.y), -minf(depth_range.x, depth_range.y)),
			clampf(at.z, -bounds.y, bounds.y),
			clampf(at.w, -bounds.z, bounds.z))


## `looking_at` needs a fourth direction to resolve the basis, and the default is W. When the
## heading is itself mostly along W the two are colinear, which the engine warns about and
## then guesses at - so hand it X instead in that case.
func _perpendicular_for(direction: Vector4) -> Vector4:
	if absf(direction.w) > 0.85:
		return Vector4(1.0, 0.0, 0.0, 0.0)
	return Vector4(0.0, 0.0, 0.0, 1.0)


## Glances at the player now and then, by handing the swimmer a point to aim the head at.
## The pilot decides WHEN; the swimmer decides what the head can physically do about it.
func _attend(delta: float) -> void:
	if _swimmer == null or not _swimmer.has_method(&"look_at_point"):
		return
	if _glancing > 0.0:
		_glancing -= delta
		if _glancing <= 0.0:
			_swimmer.call(&"look_at_point", Vector4(), false)
			_until_glance = randf_range(attention_gap * 0.5, attention_gap * 1.5)
		elif _player != null:
			_swimmer.call(&"look_at_point", _player.get_global_position(), true)
		return
	_until_glance -= delta
	if _until_glance > 0.0 or _player == null:
		return
	if _body.position.distance_to(_player.get_global_position()) > attention_range:
		# Not close enough to be worth it; try again shortly rather than waiting out another
		# full gap, or the animal ignores a player who has just walked up to the rail.
		_until_glance = attention_gap * 0.25
		return
	_glancing = attention_hold
