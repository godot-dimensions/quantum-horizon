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
## Cadence, not distance - see chicken_walker.gd's `speed`. Scaled down with the stride
## going up, so the birds keep their old pace with longer steps.
@export var walk_speed: float = 6.0
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
## Item 25: print this chicken's state changes. Per bird rather than global, because the
## interesting question is almost always "what is number 7 doing", and twelve chickens all
## logging at once is not a readout, it is a wall.
@export var debug_state: bool = false

@export_group("Temperament")
## Docile birds do not flee. They notice nothing, bolt from nothing, and spend their time
## standing about pecking the ground.
##
## This deliberately switches off items 21-23 - the startle, the evade and its cooldown -
## which the brief asked for and which are still here and still work. A chicken that runs
## when you approach turns catching into a chase, and the hunt in this prototype is meant
## to be through W, not around the field. The skittish version is one flag away.
@export var docile: bool = true
## How often a docile bird pecks, and how often a penned one does. Penned birds peck more:
## they have arrived, they are at home, and a pen of chickens all pecking reads as settled
## in a way a pen of chickens all walking does not.
@export_range(0.5, 20.0, 0.5) var peck_every_min: float = 2.0
@export_range(0.5, 20.0, 0.5) var peck_every_max: float = 5.0
@export_range(0.5, 20.0, 0.5) var penned_peck_every_min: float = 1.2
@export_range(0.5, 20.0, 0.5) var penned_peck_every_max: float = 3.2

@export_group("Liveliness")
## How far a startled chicken hops, and how far its wings come up (item 21).
@export_range(0.0, 2.0, 0.05) var startle_hop: float = 0.55
@export_range(0.0, 1.5, 0.05) var startle_wing_lift: float = 0.8
## And how much it fidgets while being carried (item 30).
@export_range(0.0, 1.5, 0.05) var carried_flutter: float = 0.5

@export_group("Recovery")
## Below this the chicken has left the world rather than wandered (item 76).
@export var lost_below_y: float = -4.0
## And beyond this from its own home it is lost rather than exploring. Generous: a good
## throw covers a lot of ground, and recovering a bird mid-flight would undo the throw.
@export var lost_distance: float = 60.0
@export_range(1.0, 30.0, 0.5) var stuck_seconds: float = 8.0
## Total ground a chicken must cover within that window. A healthy bird idles and wanders
## its way to several units; one held against a post covers essentially nothing.
@export_range(0.05, 4.0, 0.05) var stuck_travel: float = 0.6

var state: State = State.IDLE
var returned: bool = false

## Has the player ever had hold of this bird? A chicken counts as delivered because
## someone carried it in, never because it wandered in on its own - see pen_return_4d.gd.
var ever_carried: bool = false

## How long a delivered chicken takes to walk onto the pen's slice, and which slice that
## is. Zero is the slice the player starts on, so a full pen is visible from where the
## objective is read.
const SETTLE_SECONDS: float = 1.6
@export var pen_slice_w: float = 0.0

var _last_seen: Vector4 = Vector4.ZERO
var _wing_node: Node4D
var _flutter: float = 0.0
var _path: float = 0.0
var _stuck_elapsed: float = 0.0
var _settle_from: float = 0.0
var _settle_time: float = SETTLE_SECONDS
## Whether the penned bird is mid-stroll or stopped to peck. It lands walking.
var _penned_walking: bool = true

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
	_guard(delta)
	_animate(delta)
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
	if debug_state and next != state:
		print("[chicken %d] %s -> %s at %.1v" % [
			chicken_id, State.keys()[state], State.keys()[next], _creature.position])
	state = next
	match state:
		State.IDLE:
			_set_walker(true, walk_speed, false, 0.0)
			_set_pecking(peck_every_min, peck_every_max)
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
			# Home, and STILL A BIRD. This used to halt the walker outright - a penned
			# chicken stood on one spot pecking for ever, and because the state re-entered
			# itself it never walked again in the whole run. It now does what a loose one
			# does, a few steps and then a stop to peck, only slower, calmer and on a
			# shorter leash; _contain already holds it to 60% of its wander radius around
			# wherever it landed.
			_set_walker(not _penned_walking, walk_speed * 0.5, false, 0.0)
			_set_pecking(penned_peck_every_min, penned_peck_every_max)
			_timer = _rng.randf_range(wander_seconds_min, wander_seconds_max) 				* (1.0 if _penned_walking else 1.6)
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
	#
	# THE DRIFT ONTO THE PEN'S SLICE ONLY HAPPENS WHILE IT IS WALKING. Run against a
	# halted walker it slid the body through W with both feet planted, which is the skate
	# it was reported as - the legs were doing nothing while the bird travelled. Moving
	# it only while the legs are moving costs nothing, because it starts off walking the
	# moment it lands.
	if _settle_time < SETTLE_SECONDS and _penned_walking:
		_settle_time += get_physics_process_delta_time()
		var t: float = clampf(_settle_time / SETTLE_SECONDS, 0.0, 1.0)
		# Eased, so it slows into place instead of stopping dead.
		var w: float = lerpf(_settle_from, pen_slice_w, t * t * (3.0 - 2.0 * t))
		_creature.position.w = w
		home_position.w = w
	if _timer <= 0.0:
		_penned_walking = not _penned_walking
		_enter(State.PENNED)


func _tick_recovering() -> void:
	if _timer <= 0.0:
		_creature.position = home_position
		_enter(State.IDLE)


## How often this bird pecks. Set per state, because a settled chicken pecks more than a
## wandering one and the difference is most of what makes the pen look like a pen.
func _set_pecking(every_min: float, every_max: float) -> void:
	if _walker == null:
		return
	_walker.set("peck_enabled", true)
	_walker.set("peck_interval_min", every_min)
	_walker.set("peck_interval_max", every_max)


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


## Is the player close enough to startle this bird right now?
##
## THE COOLDOWN COUNTS HERE TOO, not only at the moment it decides to run. It used to gate
## the EVADE and not the ALERT, so a player simply standing next to a chicken made it
## flicker IDLE - ALERT - IDLE many times a second: it noticed, found it was still resting,
## went back to idle, and noticed again on the very next frame. The startle hop replayed
## every time, so the bird vibrated instead of settling. A chicken that has just run is
## allowed to be unimpressed by you for a few seconds.
func _threatened() -> bool:
	if docile or state == State.PENNED or returned or _cooldown > 0.0:
		return false
	return _distance_to_player() < alert_distance


func _away_from_player() -> float:
	if _player == null:
		return 0.0
	var away: Vector4 = _creature.global_position - _player.global_position
	return atan2(away.x, away.z)


## Keeps a loose chicken in its authored region (item 19) and its assigned slice (20).
##
## Applied as a pull rather than a wall: it is steered home when it strays, instead of
## being stopped at a boundary, which would look like it had walked into glass.
## Item 76: notice when a chicken has ended up somewhere it cannot come back from.
##
## FOUR WAYS TO BE LOST, and they need different tests because they fail differently. A
## bird that falls through the floor keeps falling and never trips a distance check in XZ.
## One that is thrown over the horizon is at a perfectly sensible height. One wedged
## against a fence post is at a legal position and simply never leaves it, so only time
## reveals it. And a NaN is none of the above - it compares false against every threshold,
## so it has to be tested for first or it slips through all of them.
##
## The recovery is deliberately dull: go home. There is nowhere better to put a chicken
## that has gone wrong, and anywhere cleverer would be a second placement system disagreeing
## with the authored one.
## Items 21 and 30: the two moments the chicken has to look alive without walking.
##
## A startled bird HOPS AND THROWS ITS WINGS UP, and a carried one keeps fidgeting. Both
## are the same small amount of work - a wing angle and a height - and both exist because
## a chicken that merely stops, or merely hangs in your hands, reads as a prop. The walker
## drives the legs and never touches the wing or the height, so these can be written
## directly without fighting it.
func _animate(delta: float) -> void:
	_flutter += delta
	var wing: Node4D = _wing()
	if wing == null:
		return
	match state:
		State.ALERT:
			# Wings up and a hop, over the beat of noticing. Sine over the whole beat, so
			# it lands as the bird decides whether to bolt.
			var beat: float = clampf(1.0 - _timer / 0.35, 0.0, 1.0)
			var arc: float = sin(beat * PI)
			wing.basis = Basis4D.from_xy(-startle_wing_lift * arc)
			_creature.position.y = home_position.y + startle_hop * arc
		State.EVADE:
			# Still half-raised while running, the way a panicking bird holds them.
			wing.basis = Basis4D.from_xy(-startle_wing_lift * 0.45)
			_creature.position.y = home_position.y
		State.CARRIED, State.THROWN:
			# Item 30: a slow flutter with an occasional harder flap, so it never settles
			# into a loop the eye can predict. It keeps flapping through the throw, which
			# is both funnier and the honest thing for a bird in the air to do.
			#
			# NEITHER OF THESE TOUCHES THE HEIGHT. The catcher owns where a held or flying
			# chicken is, and writing y here flattened every throw into a slide along the
			# ground - the arc was there in the catcher and overwritten a frame later.
			var slow: float = sin(_flutter * 4.2) * 0.35
			var kick: float = maxf(sin(_flutter * 0.9), 0.0)
			wing.basis = Basis4D.from_xy(-carried_flutter * (slow + kick * 0.8))
		_:
			wing.basis = Projection.IDENTITY
			_creature.position.y = home_position.y


func _wing() -> Node4D:
	if _wing_node == null:
		_wing_node = _creature.get_node_or_null("Wing") as Node4D
	return _wing_node


func _guard(delta: float) -> void:
	if state == State.CARRIED or state == State.RECOVERING:
		_path = 0.0
		_stuck_elapsed = 0.0
		_last_seen = _creature.position
		return
	var at: Vector4 = _creature.position
	var reason: String = ""
	if not _finite(at):
		reason = "its position stopped being a number"
	elif at.y < lost_below_y:
		reason = "it fell through the world (y %.1f)" % at.y
	elif Vector2(at.x - home_position.x, at.z - home_position.z).length() > lost_distance:
		reason = "it is %.0f units from home" % Vector2(at.x - home_position.x, at.z - home_position.z).length()
	else:
		reason = _check_stuck(delta, at)
	if reason != "":
		recover(reason)


## Has this chicken got anywhere in the last few seconds?
##
## PATH LENGTH, NOT DISPLACEMENT, and over a long window rather than between frames. Both
## of those are lessons from getting it wrong:
##
##   - Per-frame stillness teleported seven healthy chickens on its first run. A bird walks
##     about 0.02 units per frame, which is the same order as any threshold small enough to
##     mean "not moving", so walking and being wedged were indistinguishable.
##   - Net displacement would flag a bird that wandered in a circle and came back, which is
##     ordinary chicken behaviour and not a fault. Summing the path cannot make that
##     mistake: a circling bird has travelled, even though it is back where it started.
##
## WORST CASE IT TAKES TWICE stuck_seconds to notice. The window that was already running
## when the bird got wedged still holds the walking it did beforehand, so that one passes
## and only the next clean window trips. Eight to sixteen seconds is the right order for
## this: long enough never to fire on a bird that is merely dithering, short enough that a
## player hunting the last chicken is not left staring at a fence post.
##
## It also does not care which state the bird is in. An earlier version only counted while
## WANDERing, so a chicken pinned against a fence post cycled idle - wander - idle as usual,
## reset the count every time it went idle, and stayed pinned forever.
func _check_stuck(delta: float, at: Vector4) -> String:
	if state == State.PENNED:
		_path = 0.0
		_stuck_elapsed = 0.0
		_last_seen = at
		return ""
	_path += Vector2(at.x - _last_seen.x, at.z - _last_seen.z).length()
	_last_seen = at
	_stuck_elapsed += delta
	if _stuck_elapsed < stuck_seconds:
		return ""
	var walked: float = _path
	_path = 0.0
	_stuck_elapsed = 0.0
	if walked < stuck_travel:
		return "it walked %.2f units in %.0f s, so it is wedged against something" % [
			walked, stuck_seconds]
	return ""


func _finite(v: Vector4) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z) and is_finite(v.w)


## Send a chicken home. Public because the debug tools (item 81) need exactly this.
func recover(reason: String) -> void:
	# Always announced. A chicken recovering is by definition something going wrong, and
	# item 82 would rather that be noisy during development than quietly corrected.
	push_warning("ChickenAgent %d recovered: %s (item 76)." % [chicken_id, reason])
	_path = 0.0
	_stuck_elapsed = 0.0
	_creature.position = home_position
	_last_seen = home_position
	_enter(State.RECOVERING)


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


## Item 77: the state transitions refuse the impossible rather than trusting the caller.
##
## Rapid presses, a repeated area signal and a frame that ran twice all arrive here as the
## same thing - a second call that should do nothing - and guarding at the state machine
## means every caller is idempotent, not just the careful ones.
func on_caught() -> void:
	if state == State.CARRIED or returned:
		return
	ever_carried = true
	_enter(State.CARRIED)


func on_released() -> void:
	if state != State.CARRIED:
		return
	_enter(State.THROWN)


## Item 64: a delivered chicken has to still be THERE afterwards.
##
## It keeps the W it landed at for a moment and then walks onto the pen's own slice,
## rather than snapping there the instant it touches down. The distinction matters: the
## player threw it while standing at some W of their own, and a bird that teleported on
## landing would look like it had been rejected. Drifting reads as the chicken settling.
## The alternative - leaving it at the thrown W forever - is worse than a snap, because a
## pen full of chickens nobody can see from the home slice looks like a pen full of
## nothing.
func on_landed(in_pen: bool) -> void:
	if returned:
		return
	if in_pen:
		returned = true
		# WHEREVER IT LANDS IS HOME. It does not walk back to where it was thrown from or
		# to the middle of the pen - it picks up its life at the spot it came down on.
		home_position = _creature.position
		_settle_from = _creature.position.w
		_settle_time = 0.0
		_penned_walking = true
		_enter(State.PENNED)
	else:
		_enter(State.IDLE)


func describe() -> String:
	var mark: String = " RETURNED" if returned else ""
	return "#%d %s%s w%.2f" % [chicken_id, State.keys()[state], mark, _creature.position.w]
