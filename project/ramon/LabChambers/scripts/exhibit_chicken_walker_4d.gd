extends "res://ramon/LabKit/carried/chickenpen/scripts/chicken_walker.gd"

## Lab: the pen chicken's own walker (LabKit/carried/chickenpen/scripts/chicken_walker.gd, the
## lab's copy, not edited: Ramon, 4 Oct, "never adjust anything from the playable world ... just
## copy stuff over"), kept on the spot for the goat room's pedestal. Everything it does in the pen
## stays: the two rigid leg halves hinged at the knee, the body rocking over the planted foot, the
## head holding still against it, and its peck (a dip and three jabs, swung about the base of the
## neck, its reach solved to the ground).
##
## WHAT CHANGES HERE, by overriding, not editing:
##   it does not roam   _wander and _travel do nothing, so it stays centred on the pedestal
##   its feet slide     in the pen a planted foot holds its place in the WORLD while the bird
##                      walks over it; a bird that does not travel would then never sweep its
##                      leg back, so here a planted foot slides back in its leg's own frame, the
##                      ground moving under it (a treadmill), and the turntable cannot twist it
##   it flutters        every `flutter_every` seconds a short hop, its wings spreading and
##                      beating while it is up (Ramon: "maybe fly up too")
##
## NO class_name (engine_gotchas.md).

@export var flutter_every: float = 5.0
@export var flutter_seconds: float = 1.3
## How high the hop goes, in the bird's own units.
@export var hop_height: float = 0.32

var _flutter_t: float = 0.0
var _rest_y: float = NAN
var _wing: Node4D


func _wander(_delta: float) -> void:
	pass


func _travel(_delta: float) -> void:
	pass


## The pen's foot path, but planted feet slide back in the leg's own frame instead of holding a
## point in the world.
func _foot_position(leg: Dictionary, local_phase: float, duty: float) -> Vector4:
	var rest: Vector4 = leg["rest_foot"]
	var forward := Vector4(0.0, 0.0, 1.0, 0.0)
	var sweep: float = stride_length * 2.0 * maxf(duty, 0.0001)
	var lift_off: Vector4 = rest - forward * (sweep * 0.5)
	var landing: Vector4 = rest + forward * (sweep * 0.5)
	if local_phase < duty:
		return landing.lerp(lift_off, local_phase / maxf(duty, 0.0001))
	var swing: float = (local_phase - duty) / maxf(1.0 - duty, 0.0001)
	var eased: float = swing * swing * (3.0 - 2.0 * swing)
	var apex: Vector4 = (lift_off + landing) * 0.5 + Vector4(0.0, step_height * 2.0, 0.0, 0.0)
	return lift_off.lerp(apex, eased).lerp(apex.lerp(landing, eased), eased)


func _physics_process(delta: float) -> void:
	super(delta)
	_flutter(delta)


## A hop now and then: up and down on a sine, the wings opening out and beating while it is up
## (the wing rig is one mirrored pair, so its width is what opens and closes). The legs hold their
## stride in the air (the gait clock is halted), no peck starts while it is up, and the hop waits
## for a peck to finish.
func _flutter(delta: float) -> void:
	var bird: Node4D = get_parent() as Node4D
	if bird == null:
		return
	if is_nan(_rest_y):
		_rest_y = bird.position.y
	if _wing == null:
		_wing = bird.get_node_or_null("Wing") as Node4D
	var start: float = flutter_every - flutter_seconds
	var before: float = fposmod(_flutter_t, flutter_every)
	if not (_peck_elapsed >= 0.0 and before > start - 0.1 and before <= start):
		_flutter_t += delta
	var c: float = fposmod(_flutter_t, flutter_every)
	if c > start - peck_duration - 0.2:
		_peck_countdown = maxf(_peck_countdown, flutter_every - c + 0.4)
	var f: float = 0.0
	if c > start:
		f = sin((c - start) / flutter_seconds * PI)
		halted = true
	var k: float = maxf(bird.basis.y.length(), 0.0001)
	bird.position.y = _rest_y + f * hop_height * k
	if _wing != null:
		var spread: float = 1.0 + f * (0.5 + 0.35 * sin(_flutter_t * TAU * 7.0))
		_wing.basis = Projection(Vector4(spread, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))


## Back to standing: no hop, wings folded, the legs straightened to their rest, the body and the
## head back where they were authored, no peck under way.
func settle() -> void:
	var bird: Node4D = get_parent() as Node4D
	if bird != null and not is_nan(_rest_y):
		bird.position.y = _rest_y
	if _wing != null:
		_wing.basis = Projection.IDENTITY
	for leg in _legs:
		for key in ["thigh_node", "shank_node"]:
			if leg.has(key):
				(leg[key] as Node4D).basis = Projection.IDENTITY
				(leg[key] as Node4D).position = Vector4.ZERO
		if leg.has("rest_knee"):
			(leg["knee"] as Node4D).position = leg["rest_knee"]
		(leg["foot"] as Node4D).position = leg["rest_foot"]
		leg["planted"] = false
	halted = false
	_peck_elapsed = -1.0
	if _body != null:
		_body.position = _body_rest
	if _neck != null:
		_neck.position = _neck_rest
		_neck.basis = Projection.IDENTITY
		_carry_attachments()
