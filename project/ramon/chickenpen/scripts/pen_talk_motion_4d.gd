extends Node

## People move while they talk. Until now this cast delivered every line standing
## perfectly still, which reads as a vending machine with a name.
##
## ONE NODE FOR THE WHOLE CAST, not a script per character. Every figure here is a
## block_avatar_4d, so they all expose the same five handles - head, torso, two shoulders,
## two elbows - and a gesture written once fits all of them. A second copy of this on
## Trym would drift from the one on Mithra within a week.
##
## WHAT MAKES IT NOT LOOK LOOPED. Three things, because any one of them alone is a tell:
##
##   1. A CONTINUOUS IDLE of three sine waves whose periods are deliberately not simple
##      multiples of each other (1.9, 2.7 and 4.3 seconds). Their sum does not repeat for
##      minutes, where two waves at 2 and 4 seconds repeat every four and the eye catches
##      it almost immediately.
##   2. DISCRETE GESTURES on top - a nod, a tilt, a hand out, a shrug, a point - each
##      lasting under a second, fired at random intervals.
##   3. NO GESTURE TWICE IN A ROW. The last one is remembered and excluded from the next
##      draw, because a fair coin genuinely does repeat about half the time with two
##      choices and it is the repeat that gets noticed, not the randomness.
##
## AND EVERY SPEAKER IS OUT OF PHASE with every other, seeded off their node name, so two
## characters in one conversation never move as a pair.
##
## IT RUNS AFTER THE GAIT. block_gait_4d writes the arms and the torso every physics tick
## for the walk cycle, and a figure that talks while its gait is live would have all of
## this overwritten a moment after it was written. process_priority is set high so this
## node's _physics_process runs last, and it blends rather than replaces - a character who
## gestures mid-stride keeps their walk.##
## IT MUST NOT COMPOUND, AND THAT IS THE HARD PART. A gesture is applied by multiplying
## onto the joint's existing basis, which is what lets a wave ride over a walk instead of
## cancelling it - but multiplying onto your own last output every frame integrates, and
## the arm winds up like a clock spring. It only behaves when something else assigns the
## joint a fresh value each tick, which the gait does WHILE WALKING and nothing does when
## a figure is standing still or has no gait at all, like the keeper. Measured: an arm
## that should sweep 0.5 radians swept 1.48 and climbing.
##
## So each joint remembers the basis it was handed and the basis it wrote. If the joint
## still holds what we wrote, nobody else has touched it and we start again from the
## remembered input; if it holds something else, the gait has spoken this frame and that
## is the new input. Correct whether the figure is walking, standing, or has no gait.

## WHO IS IN AND WHO IS NOT. The four people on the farm - Mithra, the keeper, Trym and
## the professor - all of whom are block_avatar_4d and all of whom hold still to talk.
##
## Nike is out because he is a pig: no shoulders, no head node, nothing here to drive, and
## nike_antics already gives him a life of his own.
##
## THE THEATRE IS OUT DELIBERATELY. Its presenter is choreographed - theatre_show_4d walks
## him between two marks, swings his legs and poses him per act - and a second thing
## writing his arms would fight that frame by frame. A keynote is blocked; a conversation
## in a field is not, which is the whole reason this node exists for one and not the
## other.
##
## Each entry: the dialogue player to watch, and the figure to move while it is running.
## The figure is a block_avatar_4d - the node with the shoulders on it, not the body.
@export var speakers: Array[NodePath] = []
@export var figures: Array[NodePath] = []

@export_group("Idle")
## The constant small motion underneath everything.
##
## DELIBERATELY UNDER-PLAYED. The first pass at these numbers was roughly twice this and
## read as someone telling an anecdote rather than someone answering a question about
## chickens. The job is the difference between a person and a statue; anything past that
## is a performance, and a performance repeated on every line of dialogue in the game
## becomes a tic. Turn them up per character if one of them earns it.
@export_range(0.0, 0.5, 0.01) var head_sway: float = 0.038
@export_range(0.0, 0.5, 0.01) var torso_sway: float = 0.016
@export_range(0.0, 1.0, 0.01) var arm_idle: float = 0.028

@export_group("Gestures")
@export var gestures_enabled: bool = true
## Seconds between gestures, drawn fresh each time. Short enough that a four-line
## exchange gets two or three, long enough that they are punctuation rather than fidget.
@export_range(0.2, 12.0, 0.1) var gesture_gap_min: float = 2.8
@export_range(0.2, 12.0, 0.1) var gesture_gap_max: float = 6.5
## The whole arc, up and back down. SLOW: the arm should be seen to move rather than be
## noticed having moved. Under about a second and a half it reads as a twitch.
@export_range(0.2, 8.0, 0.05) var gesture_seconds: float = 2.4
@export_range(0.0, 2.0, 0.05) var gesture_size: float = 0.34
## How fast a figure settles back to its rest pose when it stops talking. Not instant: a
## hand that snaps to the side the moment the box closes is worse than never raising it.
@export_range(0.5, 12.0, 0.5) var relax_rate: float = 3.5

## ALMOST STRAIGHT ARMS, SLOWLY. The old set had a shrug that folded both elbows nearly a
## radian and a point that threw one arm up past the shoulder, all inside three quarters
## of a second. On a block figure with no hands to read, a fast bent arm does not look
## like emphasis, it looks like a fault.
##
## What is left is two arm shapes - one lifts gently and comes down, one opens out to the
## side and comes down - and three that barely touch the arms at all. The elbow never
## bends past a tenth of a radian, so the arm reads as an arm rather than a hinge.
enum G { NOD, TILT, LIFT, OPEN, BOTH_OPEN, LEAN_IN }

var _watched: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Last, so the gait has already written the walk by the time any of this lands.
	#
	# BOTH PRIORITIES, and the physics one is the one that matters. process_priority
	# orders _process only; _physics_process is ordered by process_physics_priority, and
	# setting just the first is a silent no-op that looks right. Measured: the head moved
	# and the arms did not, because the gait writes the shoulders every physics tick and
	# was still running after this node.
	process_priority = 500
	process_physics_priority = 500
	_rng.randomize()
	for i in speakers.size():
		var talk: Node = get_node_or_null(speakers[i])
		var figure: Node = get_node_or_null(figures[i]) if i < figures.size() else null
		if talk == null or figure == null:
			push_warning("TalkMotion: entry %d is missing its dialogue or its figure." % i)
			continue
		_watched.append({
			"talk": talk,
			"figure": figure,
			# Off the name, so it is stable across runs but different per character - two
			# people in one scene must not breathe in time with each other.
			"phase": float(hash(String(figure.get_path())) % 1000) * 0.01,
			"amount": 0.0,
			"next": 0.0,
			"gesture": -1,
			"left": 0.0,
			"last": -1,
			"hand": 1.0,
		})
	if _watched.is_empty():
		push_warning("TalkMotion: nobody to animate - `speakers` and `figures` are empty or unpaired.")


func _physics_process(delta: float) -> void:
	for who in _watched:
		var talking: bool = bool(who["talk"].call("is_running"))
		# Eased in and out, so starting and stopping a conversation is not a snap.
		who["amount"] = move_toward(who["amount"], 1.0 if talking else 0.0, delta * relax_rate)
		if who["amount"] <= 0.001:
			continue
		if talking and gestures_enabled:
			_tick_gesture(who, delta)
		elif not talking:
			who["gesture"] = -1
		_pose(who, delta)


func _tick_gesture(who: Dictionary, delta: float) -> void:
	if who["left"] > 0.0:
		who["left"] -= delta
		return
	who["next"] -= delta
	if who["next"] > 0.0:
		who["gesture"] = -1
		return
	# Never the same one twice running. With seven to choose from a repeat is not likely,
	# but "not likely" is exactly the kind of thing that happens on the line the player is
	# actually reading.
	var pick: int = _rng.randi() % G.size()
	if pick == int(who["last"]):
		pick = (pick + 1 + (_rng.randi() % (G.size() - 1))) % G.size()
	who["gesture"] = pick
	who["last"] = pick
	who["left"] = gesture_seconds
	who["hand"] = 1.0 if _rng.randf() < 0.5 else -1.0
	who["next"] = _rng.randf_range(gesture_gap_min, gesture_gap_max)


## The pose for one speaker this frame: idle underneath, gesture on top, both scaled by
## how much of a conversation they are currently in.
func _pose(who: Dictionary, _delta: float) -> void:
	var figure: Node = who["figure"]
	var amount: float = who["amount"]
	var t: float = float(Time.get_ticks_msec()) * 0.001 + float(who["phase"])
	# Three periods with no common multiple worth speaking of.
	var a: float = sin(t / 1.9 * TAU)
	var b: float = sin(t / 2.7 * TAU + 1.1)
	var c: float = sin(t / 4.3 * TAU + 2.3)

	var nod: float = 0.0
	var turn: float = 0.0
	var tilt: float = 0.0
	var lean: float = 0.0
	var arm_l: float = 0.0
	var arm_r: float = 0.0
	var elbow_l: float = 0.0
	var elbow_r: float = 0.0
	var out_l: float = 0.0
	var out_r: float = 0.0

	var g: int = int(who["gesture"])
	if g >= 0:
		# One arc per gesture: up and back down over its whole length, so nothing ever
		# ends mid-movement and there is no pose to snap out of.
		var arc: float = sin((1.0 - float(who["left"]) / maxf(gesture_seconds, 0.01)) * PI)
		var size: float = arc * gesture_size
		var hand: float = float(who["hand"])
		match g:
			G.NOD:
				nod += 0.26 * size
			G.TILT:
				tilt += 0.22 * size * hand
			G.LIFT:
				# One arm lifts, hangs for a moment at the top of the arc, and comes back
				# down. Nearly straight - the elbow is here to stop it reading as a plank,
				# not to make a shape.
				if hand > 0.0:
					arm_l += 0.52 * size; elbow_l += 0.09 * size
				else:
					arm_r += 0.52 * size; elbow_r += 0.09 * size
				turn += 0.06 * size * hand
			G.OPEN:
				# The same arc, out to the side instead of forward.
				if hand > 0.0:
					out_l += 0.46 * size; elbow_l += 0.07 * size
				else:
					out_r += 0.46 * size; elbow_r += 0.07 * size
			G.BOTH_OPEN:
				out_l += 0.26 * size; out_r += 0.26 * size
				elbow_l += 0.06 * size; elbow_r += 0.06 * size
			G.LEAN_IN:
				lean += 0.14 * size
				nod += 0.12 * size

	# EVERY CHANNEL IS A SUM, never a single wave. The first version handed one sine to
	# each axis - a to the nod, b to the turn, c to the tilt - and although the three of
	# them together never repeated, each axis on its own was a plain 1.9, 2.7 or 4.3
	# second loop. Measured against a deliberately looping control the nod came out MORE
	# self-similar than the control did. Pairs of incommensurable waves per channel fix
	# it, and cost nothing: the sines are already computed.
	nod += (a * 0.62 + c * 0.38) * head_sway
	turn += (b * 0.70 + a * 0.30) * head_sway
	tilt += (c * 0.60 + b * 0.40) * head_sway * 0.6
	lean += (b * 0.55 + c * 0.45) * torso_sway
	arm_l += (a * 0.6 + c * 0.4) * arm_idle
	arm_r += (b * 0.6 - a * 0.4) * arm_idle

	# Pitch, then yaw, then the tilt that makes a nod read as a person rather than a hinge.
	_apply(who, figure.get("head") as Node4D, "hd",
		Basis4D.from_yz(nod * amount) * Basis4D.from_zx(turn * amount)
			* Basis4D.from_xy(tilt * amount))
	_apply(who, figure.get("torso") as Node4D, "to", Basis4D.from_yz(lean * amount))
	_arm(who, figure.get("shoulder_left") as Node4D, figure.get("elbow_left") as Node4D,
		"L", 1.0, arm_l * amount, elbow_l * amount, out_l * amount)
	_arm(who, figure.get("shoulder_right") as Node4D, figure.get("elbow_right") as Node4D,
		"R", -1.0, arm_r * amount, elbow_r * amount, out_r * amount)


## An arm: swung from the shoulder, opened out to the side, and bent a little at the
## elbow.
##
## THE TAG MUST NAME THE SIDE. This took "sh" and "el" for both arms, and the two of them
## shared one slot in the memory that stops gestures compounding. That memory works by
## asking "is the joint still holding what I wrote last frame?" - if yes, nobody else has
## touched it and the frame before that is the true input. With one slot for two joints,
## the second arm each frame was compared against the FIRST arm's stored output, never
## matched, and so treated its own previous output as fresh input - which is the
## definition of integrating. It wound a little further every frame until the arm came up
## through the shoulder and bent backwards. Per-side keys, and it stays where it is put.
##
## SIDEWAYS IS A SECOND PLANE. The swing is in yz, the same plane the gait uses, which can
## only send a hand forward or back. Opening a palm out to the side is a rotation in xy,
## and `side` mirrors it so both arms open outward rather than both drifting the same way.
func _arm(who: Dictionary, shoulder: Node4D, elbow: Node4D, tag: String, side: float,
		raise: float, bend: float, out: float) -> void:
	_apply(who, shoulder, "sh" + tag,
		Basis4D.from_yz(-raise) * Basis4D.from_xy(out * side))
	_apply(who, elbow, "el" + tag, Basis4D.from_yz(-bend))


## Lays `turn` over whatever the joint was given this frame, without ever layering it over
## its own previous output. See the note at the top - this is the whole reason gestures do
## not wind up.
func _apply(who: Dictionary, joint: Node4D, tag: String, turn: Projection) -> void:
	if joint == null:
		return
	var in_key: String = tag + "_in"
	var out_key: String = tag + "_out"
	var base: Projection = joint.basis
	if who.has(out_key) and _same(base, who[out_key]):
		base = who[in_key]
	who[in_key] = base
	joint.basis = base * turn
	who[out_key] = joint.basis


## Projections compare exactly here rather than approximately: we are asking "is this the
## identical value we wrote", not "is it close to it", and a gait writing a nearly-equal
## basis is still a gait writing.
func _same(a: Projection, b: Projection) -> bool:
	return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w
