extends Node
# COPIED INTO chickenpen SO THE SCENE OWNS EVERYTHING IT NEEDS. The original lives at
# res://ramon/Model/scripts/nike_antics.gd and is what animation_test still uses. The two
# are now separate files: a change to the pig in one scene does NOT reach the other.
## Nike's idle life: ambles for a while, stops to root the ground with his snout, and now
## and then flops onto his side for a bit before getting up again.
##
## WHY THE POSES GO ON THE RIG NODE AND NOT ON NIKE. The walker translates its own parent
## to travel, reading `mover.basis` to decide which way forward is - so tipping or rolling
## that node would steer the walk into the ground. The rig is a child of it, and the
## walker's leg solving is all done in RIG-LOCAL space (it reads _position_in_rig), so
## rotating the rig moves the whole animal without disturbing a single foot target. Travel
## on the parent, posture on the child, and the two never argue.
##
## IT ALSO COSTS NOTHING. A loft rig only rebuilds when a BALL moves - its change
## signature is built from the balls' own positions and bases - so moving the rig node is
## a pure transform. Same for the ears and the two skin rolls, which are separate rigs
## nested under a ball and come along for free.
##
## THE LIFT GOES THROUGH THE WALKER, NOT ROUND IT. The walker owns the rig node's Y - it
## writes `position.y = _rig_rest_y + bob` every physics tick for the trunk bob, and it
## runs after this node, so anything written to that property here is simply overwritten.
## Measured as exactly that: the roll took effect and the lift never did, and the rig's Y
## sat at plus or minus one body_bob whatever state he was in. So a posture's height is
## added to the walker's REST height instead, and the bob rides on top of it, which is
## also what you want - he still breathes while walking.
##
## HE TURNS ONLY WHILE HE IS STOPPED, and that is not a shortcut. The walker's own header
## says turning was tried and removed: yawing a creature swings its planted feet around
## its centre, so a turn has to be steered into the foot TARGETS rather than applied as a
## transform. But a pig with his nose in the dirt or lying on his side has no foot carrying
## him, so during those states the transform is free - and he gets a pause between every
## leg of the walk anyway. Roaming therefore costs nothing and needs no gait work at all.
##
## HALTING IS THE WALKER'S OWN SWITCH. Setting `halted` freezes the gait clock's phase
## rather than resetting it, so he picks the walk back up mid-stride instead of snapping to
## the start of a cycle, and it gates travel in the same breath. The chicken uses the same
## flag to stop its legs while its beak is down.

enum State { WALK, ROOT, GOING_DOWN, LYING, GETTING_UP, HOP }

@export var walker_path: NodePath = NodePath("../Walker")
@export var rig_path: NodePath = NodePath("../Hide")

@export_group("Timing")
## How long he keeps walking before he finds something more interesting to do.
@export var walk_seconds := Vector2(5.0, 11.0)
## How long the snout stays down.
@export var root_seconds := Vector2(2.5, 4.5)
## How long he stays down once he is down.
@export var lie_seconds := Vector2(7.0, 14.0)
## Chance that a walk ends in a lie-down rather than a root. Rooting is the common one;
## lying down is the event.
@export_range(0.0, 1.0, 0.05) var lie_chance: float = 0.3
## Getting down is quicker than getting up, because it is mostly gravity.
@export var down_seconds: float = 1.1
@export var up_seconds: float = 1.6

@export_group("Rooting")
## How far the nose goes down. Small: the feet come with it, so anything steep lifts the
## hind trotters off the ground.
@export_range(0.0, 25.0, 0.5, "suffix:°") var root_pitch_degrees: float = 7.0
## Lifted as he tips, so the front trotters stay on the floor instead of sinking through.
@export_range(0.0, 0.5, 0.01) var root_lift: float = 0.13
## The ruffle: a quick side-to-side sweep of the snout through the dirt.
@export_range(0.0, 20.0, 0.5, "suffix:°") var ruffle_degrees: float = 5.0
@export_range(0.5, 6.0, 0.1) var ruffle_hertz: float = 2.4

@export_group("Lying")
## Not a full 90: propped over rather than flat on his back-side, which is how he is in
## the reference photograph.
@export_range(30.0, 90.0, 1.0, "suffix:°") var lie_roll_degrees: float = 75.0
## Rolled over, this animal is TALLER than it is upright - it is wider than it is deep -
## so it has to rise slightly to rest on the ground rather than sink into it.
@export_range(-0.3, 0.4, 0.01) var lie_rise: float = 0.1
## Slow breathing while he is down, so he is asleep rather than switched off.
@export_range(0.0, 0.1, 0.005) var breath: float = 0.025
@export_range(0.05, 1.0, 0.05) var breath_hertz: float = 0.28

@export_group("Roaming")
## How far he will get from where he started before he is steered back. He only walks in
## straight lines, so without this he leaves.
@export_range(0.0, 40.0, 0.5) var roam_radius: float = 7.0
## How fast he comes round to a new heading, in radians a second. Slow: he is turning on
## the spot with his nose down, and a pig does not pivot.
@export_range(0.2, 6.0, 0.1) var turn_rate: float = 1.3
## Set by whoever picks him up. Everything stops and no posture is written, so he keeps
## whatever the carrier does with him.
@export var suspended: bool = false
## How far he may get while somebody is TALKING to him. He carries on walking, which is
## half of what makes him him, but a conversation must not end with him out of reach of the
## hands that were about to pick him up - which is exactly what happened: the grab found
## nothing there afterwards. Unlike the roam radius, this one is checked every frame and
## cuts his current walk short, because a walk leg can run eleven seconds and the roam
## check only fires when he next stops.
@export_range(0.5, 10.0, 0.1) var leash_radius: float = 1.8

@export_group("Dinner")
## The troughs. When one goes up he walks over and eats at it.
##
## HE DOES IT THE SAME WAY THE CHICKENS DO, which is why there is no steering code here
## either: pen_upgrades_4d moves a bird's idea of HOME to the trough and lets it drift in
## at its own pace. Nike already walks in straight lines back toward `_home` whenever he
## has strayed too far from it, so moving his home to the trough is the whole behaviour.
## What is added is a radius he will settle at, and a long root once he is there - a pig
## with his nose in a trough is already the animation for eating.
@export var feeder_path: NodePath = NodePath("../../../Pen/Upgrades")
## How close he gets before he stops walking and puts his head down. Roughly a snout's
## reach from the rim: closer and he stands in it.
@export_range(0.3, 4.0, 0.1) var feed_radius: float = 1.1
## How long dinner lasts before he goes back to being a pig about the field.
@export var feed_seconds := Vector2(9.0, 16.0)
## HE DOES NOT HURRY, and that was a deliberate reversal. He was given a trot on the way
## to dinner - twice the gait, because a trough goes up ten metres off and his amble covers
## 0.17 metres a second, so at his own pace it is a two-minute walk. Ramon's call was that
## Nike walks at one speed, always. He is right: a pig who moves faster when something good
## happens is a pig with a game system attached to him, and the whole point of him is that
## he is indifferent to yours. He gets there when he gets there.
##
## EXCEPT FOR THE FENCE, WHICH HE JUMPS. Throw him in the pen and then put food down
## outside it and he used to walk straight through the rails, because he is kinematic - the
## walker writes his position and never asks the physics server anything, so the fence's
## collision bodies are not there as far as he is concerned. That was already true before
## any of this; feeding him just made it something you would watch happen.
##
## A hop is the honest fix and the funny one. He is three tenths scale and the rails are
## most of a metre, so it is a real jump for him, and it is the only moment in the level
## where the pig does something athletic.
##
## THE FEET STOP FOR IT. `halted` freezes the gait's phase rather than resetting it, so he
## takes off mid-stride and picks the same stride back up on landing, and while halted the
## walker stops writing travel - which is what makes it safe to drive his position by hand
## for the length of the arc.
@export var fence_path: NodePath = NodePath("../../../Pen/Fence")
## How far from the rails he takes off. Roughly his own length.
@export_range(0.2, 3.0, 0.05) var hop_launch: float = 0.8
## How far the jump carries him. Comfortably more than the launch distance, so he lands
## clear of the rails rather than astride them.
@export_range(0.5, 6.0, 0.1) var hop_distance: float = 2.2
@export_range(0.2, 2.0, 0.05) var hop_seconds: float = 0.85
## Over the posts, the fence's tallest part. Their height is read off the fence, so raising
## it in the inspector raises the jump.
@export_range(0.0, 1.5, 0.05) var hop_clearance: float = 0.35
## Nose up off the ground, level at the top, nose down into the landing.
@export_range(0.0, 40.0, 1.0, "suffix:°") var hop_pitch_degrees: float = 14.0
## The size the launch, the distance and feed_radius were tuned at. They are lengths in metres,
## and a pig three times the size needs three times the run-up - taking off 0.8 m out, a
## big Nike would still have his snout through the rails. So they are scaled by his actual
## size over this one, and resizing him in the scene just works. Trym, 25 Sept: "Nike
## should be bigger, he's actually pretty huge IRL, like make him easily 3 times as tall
## and proportionally fat."
@export_range(0.05, 3.0, 0.05) var designed_at_scale: float = 0.3

var state: State = State.WALK

var _walker: Node
var _rig: Node4D
var _timer: float = 0.0
var _limit: float = 0.0
var _blend: float = 0.0
var _clock: float = 0.0
## The walker's own rest height, read on the first frame rather than in _ready - both
## nodes' _ready run in the same batch and nothing orders them, so reading it there got
## whatever was in the field before the walker had filled it in.
var _rest_y: float = 0.0
var _have_rest: bool = false
## The node the walker translates, which is this node's own parent, and where he started.
var _mover: Node4D
var _home: Vector4 = Vector4.ZERO
var _yaw: float = 0.0
var _heading: float = 0.0
## The uniform scale on the authored basis, kept so turning can put it back. He is
## authored at the size of the horse scene and instanced a third of that in the pen, and
## writing a pure rotation over that basis silently threw the scale away - he grew to
## full size the first time he turned round.
var _scale: float = 1.0
var _leashed: bool = false
## Where dinner is, in WORLD coordinates rather than his parent's. The troughs are built
## under the pen and he lives under the world, and converting between the two frames every
## frame to save one variable would be the kind of saving that goes wrong once.
var _feed_at: Vector4 = Vector4.ZERO
var _going_to_eat: bool = false
var _fence: FenceGenerator4D
var _hop_from: Vector4 = Vector4.ZERO
var _hop_to: Vector4 = Vector4.ZERO
var _hop_peak: float = 0.0


func _ready() -> void:
	_walker = get_node_or_null(walker_path)
	_rig = get_node_or_null(rig_path) as Node4D
	if _walker == null or _rig == null:
		push_warning("%s: walker or rig missing - Nike will just walk." % name)
		return
	_mover = get_parent() as Node4D
	if _mover != null:
		_home = _mover.position
		# Read out of the authored basis rather than assumed to be zero, so he sets off
		# facing wherever the scene pointed him.
		_yaw = atan2(_mover.basis.z.x, _mover.basis.z.z)
		_heading = _yaw
		_scale = maxf(_mover.basis.x.length(), 0.0001)
	_limit = randf_range(walk_seconds.x, walk_seconds.y)
	_fence = get_node_or_null(fence_path) as FenceGenerator4D
	var feeders: Node = get_node_or_null(feeder_path)
	if feeders != null and feeders.has_signal("feeder_raised"):
		feeders.connect("feeder_raised", go_and_eat)


func _physics_process(delta: float) -> void:
	if _walker == null or _rig == null:
		return
	if suspended:
		# Picked up on the way to dinner. Wherever he is put down it will not be here, and
		# a pig who resumed a walk to a trough he can no longer see would look possessed.
		_going_to_eat = false
		_set_halted(true)
		return
	if not _have_rest:
		_have_rest = true
		_rest_y = float(_walker.get("_rig_rest_y"))
	_timer += delta
	_clock += delta
	match state:
		State.WALK:
			_blend = 0.0
			_set_halted(false)
			if _fence != null and _crossing_rails():
				# THE FENCE STOPS HIM NOW, WHICHEVER WAY HE IS GOING. The hop used to be
				# checked only while he was on his way to a trough, which left the rails
				# solid for exactly one errand and made of paper the rest of the time -
				# and being thrown into the pen is when he is actually up against them.
				# He is kinematic, so the fence's collision bodies do not exist as far as
				# he is concerned; something here has to notice them or nothing does.
				var side: bool = _inside_pen(_mover.global_position)
				if _going_to_eat and side != _inside_pen(_feed_at):
					_take_off()
				else:
					_turn_away()
			elif _going_to_eat and _at_the_trough():
				# Checked every frame, not at the end of the leg. A walk leg runs up to
				# eleven seconds and he covers the length of the pen in that - so a pig
				# who only noticed dinner when he next stopped would walk straight past it
				# and eat somewhere out in the grass.
				_going_to_eat = false
				_enter(State.ROOT, randf_range(feed_seconds.x, feed_seconds.y))
			elif _leashed and _strayed():
				# Stopped short and turned back, rather than waiting for the walk leg to
				# run out. Stopping is also what makes the turn free - see the header.
				_choose_heading()
				_enter(State.ROOT, randf_range(0.8, 1.4))
			elif _timer >= _limit:
				_choose_heading()
				if _going_to_eat:
					# No lie-downs between here and the trough, and a brief stop rather
					# than a proper root: he is going somewhere.
					_enter(State.ROOT, randf_range(0.4, 0.8))
				elif randf() < lie_chance:
					_enter(State.GOING_DOWN, down_seconds)
				else:
					_enter(State.ROOT, randf_range(root_seconds.x, root_seconds.y))
		State.ROOT:
			_set_halted(true)
			# Eased in and out over the first and last third of a second, so the nose goes
			# down rather than snapping down.
			_blend = minf(_timer / 0.35, 1.0) * minf((_limit - _timer) / 0.35, 1.0)
			_blend = clampf(_blend, 0.0, 1.0)
			# ON HIS WAY TO DINNER HE DOES NOT SET OFF UNTIL HE IS FACING IT. He can only
			# turn while stopped, and this stop was a fixed half second or so - about forty
			# degrees of turn. With the trough behind him he set off still facing away and
			# walked a full leg the wrong way before stopping to turn another forty. Watched
			# tick by tick: 139 degrees off, then 102, then 131 as he walked on. A small pig
			# covered so little ground doing that it never showed; three times the size, he
			# walks three times as far, and he ended up further from his dinner than he
			# started three runs in five. So the stop simply lasts until he has come round,
			# with a ceiling so that nothing can hold him here for ever.
			var facing_it: bool = not _going_to_eat \
				or absf(angle_difference(_yaw, _heading)) <= deg_to_rad(12.0) \
				or _timer >= _limit + 4.0
			if _timer >= _limit and facing_it:
				_enter(State.WALK, randf_range(walk_seconds.x, walk_seconds.y))
		State.HOP:
			_set_halted(true)
			var u: float = clampf(_timer / maxf(hop_seconds, 0.01), 0.0, 1.0)
			_blend = u
			# Driven here rather than left to the walker, which is not travelling while
			# halted. A plain parabola: four-u-one-minus-u peaks at exactly 1 halfway,
			# so the clearance number is the height he actually reaches.
			_mover.position = _hop_from.lerp(_hop_to, u)
			_mover.position.y = _hop_peak * 4.0 * u * (1.0 - u)
			if _timer >= hop_seconds:
				_mover.position.y = 0.0
				_enter(State.WALK, randf_range(walk_seconds.x, walk_seconds.y))
		State.GOING_DOWN:
			_set_halted(true)
			_blend = _ease(_timer / maxf(down_seconds, 0.01))
			if _timer >= down_seconds:
				_enter(State.LYING, randf_range(lie_seconds.x, lie_seconds.y))
		State.LYING:
			_set_halted(true)
			_blend = 1.0
			if _timer >= _limit:
				_enter(State.GETTING_UP, up_seconds)
		State.GETTING_UP:
			_set_halted(true)
			_blend = 1.0 - _ease(_timer / maxf(up_seconds, 0.01))
			if _timer >= up_seconds:
				_enter(State.WALK, randf_range(walk_seconds.x, walk_seconds.y))
	_turn(delta)
	_pose()


## Dinner is served. Called by pen_upgrades_4d when a trough goes up.
##
## The CURRENT leg is cut short rather than left to run out, for the same reason the leash
## cuts one short: the trough appears the moment you pay for it, and a pig who carried on
## ambling for another nine seconds before noticing would look like he had not noticed.
## Being carried at the time is the one case where nothing happens - he is not walking
## anywhere, and he will be put down somewhere else.
func go_and_eat(at: Vector4) -> void:
	if _mover == null or suspended:
		return
	_feed_at = at
	_going_to_eat = true
	# His patch moves with him, so once dinner is over he goes on being a pig around the
	# trough instead of walking all the way back to where the scene first put him.
	_home = _mover.position + (at - _mover.global_position)
	if _at_the_trough():
		_going_to_eat = false
		_enter(State.ROOT, randf_range(feed_seconds.x, feed_seconds.y))
		return
	_choose_heading()
	# STOPPED, so that he can turn. He only turns while halted - the walker's feet are
	# planted otherwise - so setting a heading and sending him straight back out to walk
	# had him carry the OLD direction for the rest of the leg. Measured: eleven seconds and
	# a metre further from his dinner before he came round. A short root instead, which is
	# the same move the leash makes and reads as a pig looking up.
	_enter(State.ROOT, randf_range(0.5, 0.9))


func _inside_pen(at: Vector4) -> bool:
	if _fence == null:
		return false
	# The fence knows its own footprint, whatever shape it was given, and ignores height.
	return _fence.is_global_point_inside(at)


## Is the next stride going to put him through the rails?
##
## SAMPLED AHEAD RATHER THAN MEASURED TO THE NEAREST RAIL, and that is what makes it work
## at the corners and in both directions at once. Asking "am I inside here, and would I
## still be inside a stride from now" answers the question for a pig walking out, a pig
## walking in, and a pig cutting diagonally across a corner, with the same two calls. The
## measured version only handled one of the three and had to know which side he started on.
func _crossing_rails() -> bool:
	if _mover == null:
		return false
	var dir := Vector4(sin(_yaw), 0.0, cos(_yaw), 0.0)
	var ahead: Vector4 = _mover.global_position + dir * hop_launch * _size_ratio()
	return _inside_pen(_mover.global_position) != _inside_pen(ahead)


## Not every meeting with a fence is a jump. With nothing on the other side he wants, he
## does what an animal in a field does: stops, turns round and goes back the other way.
## Roughly back the other way - a pig who reversed to the exact opposite bearing every
## time would trace the same line across the pen for ever.
func _turn_away() -> void:
	_heading = _yaw + PI + randf_range(-0.7, 0.7)
	_enter(State.ROOT, randf_range(0.6, 1.2))


func _take_off() -> void:
	var dir := Vector4(sin(_yaw), 0.0, cos(_yaw), 0.0)
	_hop_from = _mover.position
	_hop_to = _mover.position + dir * hop_distance * _size_ratio()
	_hop_peak = _fence.post_height_meters + hop_clearance
	_enter(State.HOP, hop_seconds)


func _at_the_trough() -> bool:
	if _mover == null:
		return false
	var gap: Vector4 = _feed_at - _mover.global_position
	# Scaled like the hop: it is measured from his middle, and it is his SNOUT that has to
	# reach the trough. Unscaled, a big Nike had to push his middle to within a metre of it,
	# which put his snout through the fence the trough stands against - so he turned away,
	# came back, turned away, and walked off from his dinner three runs in five.
	return Vector2(gap.x, gap.z).length() <= feed_radius * _size_ratio()


## Called when a conversation with him opens and closes. Turning it on re-centres his
## patch on where he is standing, so he circles the player rather than the field.
func leash(on: bool) -> void:
	if on and not _leashed and _mover != null:
		_home = _mover.position
	_leashed = on


func _strayed() -> bool:
	if _mover == null:
		return false
	var away: Vector4 = _mover.position - _home
	return Vector2(away.x, away.z).length() > leash_radius


## A new direction, picked at the moment he stops rather than while walking. Straight back
## towards where he started once he has wandered too far, and otherwise a real change of
## direction - at least 50 degrees, or the turn is invisible and he appears to be stuck.
func _choose_heading() -> void:
	if _mover == null:
		return
	if _going_to_eat:
		var to_food: Vector4 = _feed_at - _mover.global_position
		_heading = atan2(to_food.x, to_food.z)
		return
	var away: Vector4 = _mover.position - _home
	var flat := Vector2(away.x, away.z)
	if flat.length() > (leash_radius if _leashed else roam_radius):
		_heading = atan2(-flat.x, -flat.y)
		return
	_heading = _yaw + (1.0 if randf() < 0.5 else -1.0) * randf_range(0.9, 2.3)


## Only while stopped, for the reason in the header.
func _turn(delta: float) -> void:
	if _mover == null or state == State.WALK:
		return
	_yaw = _rotate_toward(_yaw, _heading, turn_rate * delta)
	# Scale re-applied rather than assumed to be 1. A uniform scale commutes with a
	# rotation, so the order of these two does not matter.
	_mover.basis = Basis4D.from_zx(_yaw) * Projection(
		Vector4(_scale, 0.0, 0.0, 0.0), Vector4(0.0, _scale, 0.0, 0.0),
		Vector4(0.0, 0.0, _scale, 0.0), Vector4(0.0, 0.0, 0.0, _scale))


## Shortest way round, so a heading just past pi does not send him the long way about.
func _rotate_toward(from: float, to: float, step: float) -> float:
	var diff: float = wrapf(to - from, -PI, PI)
	if absf(diff) <= step:
		return to
	return from + signf(diff) * step


func _enter(next: State, limit: float) -> void:
	state = next
	_timer = 0.0
	_limit = limit


## Smoothstep. Getting up and going down both want to start and finish gently; a linear
## roll reads as a hinge rather than as weight shifting.
func _ease(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _set_halted(on: bool) -> void:
	if bool(_walker.get("halted")) != on:
		_walker.set("halted", on)


func _pose() -> void:
	var pitch: float = 0.0
	var roll: float = 0.0
	var yaw: float = 0.0
	var lift: float = 0.0
	match state:
		State.ROOT:
			pitch = deg_to_rad(root_pitch_degrees) * _blend
			lift = root_lift * _blend
			# The ruffle only happens once the nose is actually down.
			yaw = deg_to_rad(ruffle_degrees) * _blend * sin(_clock * TAU * ruffle_hertz)
		State.HOP:
			# Negative is nose UP - root_pitch is positive for a snout in the dirt - so
			# this runs from up at the launch, through level at the top, to down on the
			# way in, which is the shape of every jump.
			pitch = deg_to_rad(-hop_pitch_degrees) * (1.0 - 2.0 * _blend)
		State.GOING_DOWN, State.LYING, State.GETTING_UP:
			roll = deg_to_rad(lie_roll_degrees) * _blend
			lift = lie_rise * _blend
			if state == State.LYING:
				lift += breath * sin(_clock * TAU * breath_hertz)
	# Composed rather than accumulated: each state sets an absolute posture every frame, so
	# nothing can drift over a session's worth of lying down and getting up again.
	var basis: Projection = Projection.IDENTITY
	if not is_zero_approx(yaw):
		basis = Basis4D.from_zx(yaw) * basis
	if not is_zero_approx(pitch):
		basis = Basis4D.from_yz(pitch) * basis
	if not is_zero_approx(roll):
		basis = Basis4D.from_xy(roll) * basis
	_rig.basis = basis
	# Height handed to the walker to apply, for the reason in the header.
	_walker.set("_rig_rest_y", _rest_y + lift)


## How much bigger than his tuning he is - see designed_at_scale.
func _size_ratio() -> float:
	return _scale / maxf(designed_at_scale, 0.0001)
