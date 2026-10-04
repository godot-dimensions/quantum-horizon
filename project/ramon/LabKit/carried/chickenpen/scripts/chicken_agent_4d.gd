# CARRIED OVER from res://ramon/chickenpen/scripts/chicken_agent_4d.gd on 4 Oct 2026, so the lab owns this copy: the original can change without breaking the lab, and the other way round (LabKit/carried/README.md).
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

enum State { IDLE, WANDER, ALERT, EVADE, CARRIED, THROWN, PENNED, RECOVERING,
	TO_COOP, NESTING, ROOSTING }

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
## And how it behaves once the last bird is in and the pen is celebrating. Higher and
## much faster than a startle, which is the difference between alarm and delight.
@export_range(0.0, 3.0, 0.05) var party_hop: float = 0.42
@export_range(0.5, 20.0, 0.1) var party_rate: float = 7.5
@export_range(0.0, 1.5, 0.05) var party_wing_lift: float = 1.05
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

## Which slice a delivered chicken belongs on. Zero is the slice the player starts on, so
## a full pen is visible from where the objective is read. Adopted the instant it lands
## rather than eased into over a second and a half - see on_landed.
@export var pen_slice_w: float = 0.0

@export_group("The coop")
## The henhouse itself. A penned bird uses it: it walks up the ramp and settles inside, or
## flies up and sits on the roof, and after a while it comes back out and carries on.
##
## INSIDE IS HIDDEN, NOT WALKED AROUND. The coop is a shell with a doorway and no interior
## worth pathing through, and a chicken clipping through a wall to get in looks far worse
## than one that has simply gone in. It is set by the manager rather than per bird, so
## twelve chickens do not need twelve paths typing out.
## RESOLVED ON ASSIGNMENT, not in _ready. The manager sets this after the chicken is in
## the tree, so _ready has already run and looked the path up while it was still empty -
## the same late-property trap that once left the cat's walker unconfigured. Every bird
## simply never found its coop and stayed in the yard.
@export var coop_path: NodePath: set = _set_coop_path
## How often a penned bird bothers, as a fraction of the times it finishes a stroll.
@export_range(0.0, 1.0, 0.05) var coop_chance: float = 0.35
## Above the coop's OWN ORIGIN, not above the floor - the same measurement the cat's perch
## needed correcting for.
@export_range(0.1, 6.0, 0.05) var roof_top: float = 2.29
@export_range(1.0, 60.0, 0.5) var coop_min: float = 6.0
@export_range(1.0, 90.0, 0.5) var coop_max: float = 16.0
@export_range(0.2, 3.0, 0.05) var hop_seconds: float = 0.6
## How close to the coop's middle counts as being at it. The building is 1.8 deep, so
## anything under about 1.2 is inside the wall.
@export_range(0.5, 4.0, 0.05) var arrive_within: float = 1.7

var _last_seen: Vector4 = Vector4.ZERO
var _wing_node: Node4D
var _flutter: float = 0.0
var _path: float = 0.0
var _stuck_elapsed: float = 0.0
## Whether the penned bird is mid-stroll or stopped to peck. It lands walking.
var _penned_walking: bool = true
var _coop: Node4D
var _hop_from := Vector4.ZERO
var _hop_to := Vector4.ZERO
var _hop_t: float = 0.0
## Set when the twelfth bird lands. It is not a STATE, deliberately - see celebrate().
var _partying: bool = false
var _party_phase: float = 0.0
var _roosting: bool = false

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
	_set_coop_path(coop_path)
	_walker = _creature.get_node_or_null("Walker")
	if _walker == null:
		push_warning("ChickenAgent %d: no Walker under %s, so it will not move." % [chicken_id, _creature.name])
	if home_position == Vector4.ZERO:
		home_position = _creature.position
	_enter(State.IDLE)


func _set_coop_path(to: NodePath) -> void:
	coop_path = to
	if is_node_ready():
		_coop = get_node_or_null(coop_path) as Node4D


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
		State.TO_COOP:
			_tick_to_coop()
		State.NESTING, State.ROOSTING:
			_tick_indoors()
		_:
			pass
	_contain()



## The twelfth chicken is in. Everybody in the pen goes up and down and does not stop.
##
## A FLAG, NOT A STATE, and that is the whole design of it. A CELEBRATING state would
## have to answer every question the state machine answers - is it catchable, does it
## wander, does it count, what does it go back to - and the honest answer to all of them
## is "exactly what PENNED says", because the bird is still penned. It is just also
## delighted. So the flag rides on top and touches nothing but the pose.
##
## AND IT NEVER ENDS, which is the ask. There is no timer to expire and nothing that
## clears it but a restart, so the pen is still going when you walk away and still going
## when you come back from the theatre.
func celebrate(on: bool = true) -> void:
	_partying = on
	# Out of phase with every other bird, off the id it already has, so twelve chickens
	# do not hop as one animal. A random offset would do the same until you restarted and
	# got a different pen; this way the party looks the same every run.
	_party_phase = float(chicken_id) * 0.7391


func is_partying() -> bool:
	return _partying

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
			# NEARLY FULL PACE. At half, a penned bird covered a quarter of a unit in
			# seven seconds - technically walking and not visibly so. Calm is the long
			# pauses between strolls, not a slow stroll.
			_set_walker(not _penned_walking, walk_speed * 0.9, false, 0.0)
			_set_pecking(penned_peck_every_min, penned_peck_every_max)
			_timer = _rng.randf_range(wander_seconds_min, wander_seconds_max) 				* (1.0 if _penned_walking else 1.6)
		State.CARRIED, State.THROWN:
			_set_walker(true, 0.0, false, 0.0)
		State.RECOVERING:
			_set_walker(true, 0.0, false, 0.0)
			_timer = 0.2
		State.TO_COOP:
			# A PURPOSEFUL PACE. At 0.7 of the stroll it covered 0.05 units a second and
			# spent fourteen seconds crossing a metre and a half - a bird ambling to the
			# henhouse over a quarter of a minute reads as stuck, not as unhurried.
			_set_walker(false, walk_speed * 1.6, true, 0.0)
			_set_pecking(penned_peck_every_min * 3.0, penned_peck_every_max * 3.0)
			_timer = 12.0
		State.NESTING:
			_set_walker(true, 0.0, false, 0.0)
			_timer = _rng.randf_range(coop_min, coop_max)
		State.ROOSTING:
			# Settled high up: it stands and pecks, and does not try to walk off a roof.
			_set_walker(true, 0.0, false, 0.0)
			_set_pecking(penned_peck_every_min, penned_peck_every_max)
			_timer = _rng.randf_range(coop_min, coop_max)


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
	if _timer > 0.0:
		return
	# Every so often, at the end of a stroll, it goes and uses the henhouse.
	if _coop != null and _penned_walking and _rng.randf() < coop_chance:
		_roosting = _rng.randf() < 0.5
		_enter(State.TO_COOP)
		return
	_penned_walking = not _penned_walking
	_enter(State.PENNED)


func _tick_recovering() -> void:
	if _timer <= 0.0:
		_creature.position = home_position
		_enter(State.IDLE)


## Walking to the henhouse, then either in at the door or up onto the roof.
##
## The timer is a WAY OUT, not a plan: a bird that cannot reach the door - shoved off
## course, or hemmed in by eleven others - gives up and goes back to strolling rather
## than pushing at the wall for the rest of the run.
func _tick_to_coop() -> void:
	if _coop == null:
		_enter(State.PENNED)
		return
	var to: Vector4 = _coop.global_position - _creature.global_position
	var flat: float = Vector2(to.x, to.z).length()
	if _walker != null:
		_walker.set("steer_override", true)
		_walker.set("steer_heading", atan2(to.x, to.z))
	if _timer <= 0.0:
		_enter(State.PENNED)
		return
	# ARRIVED AT THE RAMP, not at the middle of the building. The coop's origin is inside
	# its own walls, so a threshold tight enough to call "at the door" is one the bird can
	# only meet by standing in the wall.
	if flat > arrive_within:
		return
	# Arrived. Home becomes the coop, so _contain stops pulling it back to the spot it
	# landed on - it is allowed to be here.
	#
	# IN THE BIRD'S OWN PARENT FRAME. _coop.position is local to the PEN and the chicken's
	# position is local to the flock, and mixing the two sent the bird to the coop's
	# offset measured from the wrong origin - out of the fence entirely and two and a half
	# units up. The pen then clamped it back in x and z while keeping the height, wrote
	# that height into its home, and the animator pinned it there: a chicken hovering over
	# the yard for good.
	var here: Vector4 = _coop_in_my_frame()
	home_position = here
	if _roosting:
		_hop_from = _creature.position
		_hop_to = here + Vector4(0.0, roof_top, 0.0, 0.0)
		_hop_to.w = _creature.position.w
		_hop_t = 0.0
		_enter(State.ROOSTING)
	else:
		_creature.visible = false
		_enter(State.NESTING)


## Where the coop is, expressed in the same frame the chicken's own position is in.
## Everything else here works in that frame, and the coop lives under the pen rather than
## under the flock - so its `position` is measured from a different origin entirely.
func _coop_in_my_frame() -> Vector4:
	var host: Node4D = _creature.get_parent() as Node4D
	return _coop.global_position - (host.global_position if host != null else Vector4.ZERO)


## Settled - inside out of sight, or up on the roof - until its time is up, and then back
## down to the floor of the pen.
func _tick_indoors() -> void:
	if state == State.ROOSTING and _hop_t < 1.0:
		_hop_t = minf(_hop_t + get_physics_process_delta_time() / maxf(hop_seconds, 0.05), 1.0)
		var along: Vector4 = _hop_from.lerp(_hop_to, _hop_t)
		# A flap up rather than a lift: chickens do get onto things, badly.
		_creature.position = Vector4(along.x, along.y + sin(_hop_t * PI) * 0.35,
			along.z, along.w)
		return
	if _timer > 0.0:
		return
	# Back down and out, at the foot of the ramp.
	var door: Vector4 = _coop_in_my_frame() + Vector4(0.0, 0.0, 1.4, 0.0)
	door.y = 0.0
	door.w = _creature.position.w
	_creature.position = door
	_creature.visible = true
	home_position = door
	_penned_walking = true
	_enter(State.PENNED)


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
	if _partying:
		# Frantic rather than pleased: fast, and the bird leaves the ground on every beat
		# instead of bobbing. abs() of a sine gives the bounce its bottom - a plain sine
		# would spend half of each cycle underground, and the ground is where it started.
		_party_phase += delta * party_rate
		var up: float = absf(sin(_party_phase))
		_creature.position.y = home_position.y + party_hop * up
		# Wings out of step with the legs, because a bird flaps on the way up and again
		# on the way down, and matching them made it read as one stiff mechanism.
		wing.basis = Basis4D.from_xy(-party_wing_lift * absf(sin(_party_phase * 1.7)))
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
		State.NESTING, State.ROOSTING:
			# It owns its own height up there; writing home's y drops it through the roof.
			wing.basis = Projection.IDENTITY
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
	# A nesting or roosting bird is meant to be still, and one walking to the coop is
	# under orders. None of them is stuck, and recovering them teleports a chicken out of
	# the henhouse for the crime of using it.
	if state == State.NESTING or state == State.ROOSTING or state == State.TO_COOP:
		_path = 0.0
		_stuck_elapsed = 0.0
		_last_seen = at
		return ""
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
	# Hands off a bird that is on its way to the coop, in it, or on top of it - the leash
	# would drag it off the roof and the W clamp would pull it back through the wall.
	if state == State.TO_COOP or state == State.NESTING or state == State.ROOSTING:
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


## Whether the bird is on its way to the henhouse, in it, or on top of it. The pen's
## return volume asks before it does anything, because every correction it makes assumes
## a bird standing on the floor of the pen - and one halfway through a hop onto the roof
## is not that. Caught mid-hop it had its raised height written into its own home, and an
## animator that pins y to home then left it hovering there for good.
func using_coop() -> bool:
	return state == State.TO_COOP or state == State.NESTING or state == State.ROOSTING


func can_be_caught() -> bool:
	return not returned and state != State.CARRIED and state != State.PENNED \
		and state != State.NESTING and state != State.ROOSTING and state != State.TO_COOP


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
		# WHEREVER IT LANDS IS HOME, and it is home the moment it touches down.
		#
		# NOTHING SLIDES ANY MORE. The slice it belongs on used to be eased onto over a
		# second and a half, which moved the bird while it stood there - the skate. Easing
		# it only while the legs moved just traded one fault for a worse pair: it marched
		# off along the throw line and then the leash hauled it back. The slice is simply
		# adopted on the frame it lands, inside the impact, and after that nothing moves
		# the bird but its own legs.
		home_position = _creature.position
		home_position.w = pen_slice_w
		_creature.position.w = pen_slice_w
		# AND IT LANDS STANDING. Walking out of the touchdown is what sent it skating off
		# in whatever direction it happened to be flying.
		_penned_walking = false
		_enter(State.PENNED)
	else:
		_enter(State.IDLE)


func describe() -> String:
	var mark: String = " RETURNED" if returned else ""
	return "#%d %s%s w%.2f" % [chicken_id, State.keys()[state], mark, _creature.position.w]
