extends Node4D

## The gameplay brain for one chicken. Locomotion stays in chicken_walker.gd.
##
## COMPOSITION, NOT REPLACEMENT. Item 18 of the brief says to expand the existing wander
## rather than replace it, and item 6 says to prefer extension over forking. So this owns
## the STATE - loose, alert, fleeing, carried, penned - and hands the walker a heading and
## a speed when it wants one. The walker keeps doing what it is good at: gait timing,
## planted feet, pecking, keeping its distance from other birds.
##
## The walker is only steered when this says so. Its steer_override defaults to false, so
## a chicken with no agent behaves exactly as it always did.
##
## TWELVE INSTANCES FROM ONE SCENE (item 15). Everything that should differ between birds
## comes from variation_seed rather than from twelve hand-edited copies: idle timing,
## wander radius, how skittish it is. One scene, twelve personalities.

enum State { IDLE, WANDER, ALERT, EVADE, CARRIED, THROWN, PENNED, RECOVERING }

## Stable identity (item 75). Progress, locator exclusion and recovery all key off this
## rather than on scene-tree order or a display name, either of which can change.
@export var chicken_id: int = 0

## Seeds every per-bird variation below. Two chickens with different seeds behave
## differently; the same seed always reproduces the same bird.
@export var variation_seed: int = 0

@export_group("Home and bounds")
## Where this chicken belongs. Set from the placement rather than authored per instance.
@export var home_position: Vector4 = Vector4.ZERO
## How far it may stray from home while loose (item 19).
@export var wander_radius: float = 3.0
## How far it may drift through W from its assigned slice (item 20). Small on purpose: a
## chicken that wanders through W turns an authored hiding puzzle into an unrelated chase.
@export var w_drift: float = 0.15

@export_group("Speeds")
@export var walk_speed: float = 18.0
@export var evade_speed: float = 34.0

@export_group("Idle and wander")
@export var idle_seconds_min: float = 1.2
@export var idle_seconds_max: float = 3.5
@export var wander_seconds_min: float = 2.0
@export var wander_seconds_max: float = 5.0

@export_group("Reacting to the player")
## Inside this the chicken notices and reacts (item 21).
@export var alert_distance: float = 2.2
## Inside this it actually runs (item 22).
@export var evade_distance: float = 1.3
## How far one flight may carry it, so it cannot be chased out of its region.
@export var evade_max_distance: float = 2.2
## Enforced rest between flights, so it cannot chain-escape forever (item 22).
@export var evade_cooldown: float = 2.5
## How close the player must be to catch it.
@export var catch_distance: float = 0.9

@export_group("Debug")
@export var debug_state: bool = false

var state: State = State.IDLE
var returned: bool = false

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _cooldown: float = 0.0
var _evade_from: Vector4 = Vector4.ZERO
var _walker: Node
var _player: Node4D

@onready var _creature: Node4D = get_parent() as Node4D


func _ready() -> void:
	_rng.seed = variation_seed if variation_seed != 0 else chicken_id * 7919 + 13
	# Seeded personality: each bird gets its own patience, range and nerve.
	idle_seconds_max *= _rng.randf_range(0.75, 1.35)
	wander_seconds_max *= _rng.randf_range(0.8, 1.3)
	wander_radius *= _rng.randf_range(0.85, 1.2)
	alert_distance *= _rng.randf_range(0.85, 1.15)
	_walker = _creature.get_node_or_null("Walker")
	if _walker == null:
		push_warning("ChickenAgent %d: no Walker under %s, so it will not move." % [chicken_id, _creature.name])
	if home_position == Vector4.ZERO:
		home_position = _creature.position
	_enter(State.IDLE)


func bind_player(player: Node4D) -> void:
	_player = player


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_timer -= delta
	match state:
		State.IDLE:
			_tick_idle()
		State.WANDER:
			_tick_wander()
		State.ALERT:
			_tick_alert()
		State.EVADE:
			_tick_evade()
		State.PENNED:
			_tick_penned()
		State.RECOVERING:
			_tick_recovering()
		_:
			pass
	_contain()


func _enter(next: State) -> void:
	state = next
	match state:
		State.IDLE:
			_set_walker(true, walk_speed, false, 0.0)
			_timer = _rng.randf_range(idle_seconds_min, idle_seconds_max)
		State.WANDER:
			_set_walker(false, walk_speed, false, 0.0)
			_timer = _rng.randf_range(wander_seconds_min, wander_seconds_max)
		State.ALERT:
			# A beat of noticing before bolting, which is what makes it read as a
			# creature reacting rather than a trigger volume firing.
			_set_walker(true, walk_speed, false, 0.0)
			_timer = _rng.randf_range(0.15, 0.35)
		State.EVADE:
			_set_walker(false, evade_speed, true, _away_from_player())
			_evade_from = _creature.position
			_timer = 1.4
		State.PENNED:
			_set_walker(false, walk_speed * 0.6, false, 0.0)
			_timer = _rng.randf_range(wander_seconds_min, wander_seconds_max)
		State.CARRIED, State.THROWN:
			_set_walker(true, 0.0, false, 0.0)
		State.RECOVERING:
			_set_walker(true, 0.0, false, 0.0)
			_timer = 0.2


func _tick_idle() -> void:
	if _threatened():
		_enter(State.ALERT)
	elif _timer <= 0.0:
		_enter(State.WANDER)


func _tick_wander() -> void:
	if _threatened():
		_enter(State.ALERT)
	elif _timer <= 0.0:
		_enter(State.IDLE)


func _tick_alert() -> void:
	if _timer > 0.0:
		return
	# It only actually runs if the player is close enough AND it has had its rest.
	# Otherwise it goes back to what it was doing, which is what stops an endless chase.
	if _distance_to_player() < evade_distance and _cooldown <= 0.0:
		_enter(State.EVADE)
	else:
		_enter(State.IDLE)


func _tick_evade() -> void:
	var run: float = _creature.position.distance_to(_evade_from)
	if _timer <= 0.0 or run >= evade_max_distance:
		_cooldown = evade_cooldown
		_enter(State.IDLE)
		return
	if _walker != null:
		_walker.set("steer_heading", _away_from_player())


func _tick_penned() -> void:
	# Penned birds are calm: no alert, no evade, a shorter leash (item 24).
	if _timer <= 0.0:
		_enter(State.PENNED)


func _tick_recovering() -> void:
	if _timer <= 0.0:
		_creature.position = home_position
		_enter(State.IDLE)


func _set_walker(halted: bool, speed: float, steer: bool, heading: float) -> void:
	if _walker == null:
		return
	_walker.set("halted", halted)
	if speed > 0.0:
		_walker.set("speed", speed)
	_walker.set("steer_override", steer)
	_walker.set("steer_heading", heading)


func _distance_to_player() -> float:
	if _player == null:
		return INF
	# Through all four axes: a player in another slice is genuinely far away, and a
	# chicken should not panic about one it cannot see.
	return _creature.global_position.distance_to(_player.global_position)


func _threatened() -> bool:
	return state != State.PENNED and not returned and _distance_to_player() < alert_distance


func _away_from_player() -> float:
	if _player == null:
		return 0.0
	var away: Vector4 = _creature.global_position - _player.global_position
	return atan2(away.x, away.z)


## Keeps a loose chicken in its authored region (item 19) and its assigned slice (20).
##
## Applied as a pull rather than a wall: it is steered home when it strays, instead of
## being stopped at a boundary, which would look like it had walked into glass.
func _contain() -> void:
	if state == State.CARRIED or state == State.THROWN or _walker == null:
		return
	var offset: Vector4 = _creature.position - home_position
	var flat: float = Vector2(offset.x, offset.z).length()
	var limit: float = wander_radius if state != State.PENNED else wander_radius * 0.6
	if flat > limit:
		_walker.set("steer_override", true)
		_walker.set("steer_heading", atan2(-offset.x, -offset.z))
	elif state != State.EVADE:
		_walker.set("steer_override", false)
	# W is held far tighter than XYZ. The whole point of an authored placement is that
	# the chicken stays findable where it was put.
	if absf(offset.w) > w_drift:
		_creature.position.w = home_position.w + clampf(offset.w, -w_drift, w_drift)


func can_be_caught() -> bool:
	return not returned and state != State.CARRIED and state != State.PENNED


func on_caught() -> void:
	_enter(State.CARRIED)


func on_released() -> void:
	_enter(State.THROWN)


func on_landed(in_pen: bool) -> void:
	if in_pen:
		returned = true
		home_position = _creature.position
		_enter(State.PENNED)
	else:
		_enter(State.IDLE)


func describe() -> String:
	var mark: String = " RETURNED" if returned else ""
	return "#%d %s%s w%.2f" % [chicken_id, State.keys()[state], mark, _creature.position.w]
