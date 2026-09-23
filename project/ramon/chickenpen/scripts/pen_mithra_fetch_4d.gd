extends Node

## Mithra's errand: you give her the coin back, she goes and finds you a chicken.
##
## THE ERRAND IS THE THANK-YOU. She spends the whole game failing to find one small thing
## in one small field, and the joke only pays off if she turns out to be good at finding
## something - so the reward for the coin is not an item, it is ninety seconds of her
## being competent at the exact job she has been bad at, in front of you.
##
## SHE REALLY WALKS THERE AND REALLY CARRIES IT BACK. Nothing here teleports and nothing
## fades out: she picks a bird that is genuinely loose, crosses the field to it, the bird
## genuinely enters CARRIED, and she brings it to where you are actually standing. If you
## wander off she follows, because the alternative is a woman delivering a chicken to a
## patch of grass you left a minute ago.
##
## AND THE HANDOVER IS A REAL CATCH. `chicken_catcher_4d.give()` runs the same code the F
## key runs, so the bird counts, the arms come up, and the cluck plays. The version of
## this that parented the chicken to the carry anchor by hand looked identical for about
## a day and then disagreed with the catcher about everything.
##
## FIVE STATES AND NO TIMERS BETWEEN THEM. Each one ends because something arrived, not
## because a clock ran out - a fetch that is half on a stopwatch goes wrong the first time
## the player walks in an unexpected direction.

enum Step { IDLE, GOING, PICKING_UP, RETURNING, TALKING, LEAVING }

@export var mithra_path: NodePath = NodePath("../../Mithra")
@export var manager_path: NodePath = NodePath("../../Chickens")
@export var player_path: NodePath = NodePath("../../Player")
@export var catcher_path: NodePath = NodePath("../../Player/Catcher")
@export var dialogue_path: NodePath = NodePath("../MithraTalk")
@export var driver_path: NodePath = NodePath("../MithraDriver")

@export_group("The errand")
## She hurries. This is the one time in the game she is not ambling.
@export_range(0.5, 8.0, 0.1) var run_speed: float = 3.4
## How close she has to get to the bird before she has "found" it, and to the player
## before she starts talking.
@export_range(0.3, 4.0, 0.1) var reach: float = 1.1
@export_range(0.5, 6.0, 0.1) var talk_distance: float = 1.8
## A beat spent stooping over the bird, so it does not leap into her arms mid-stride.
@export_range(0.0, 3.0, 0.1) var pickup_seconds: float = 0.9
## Where she goes once she has handed it over: back to her patch, at a jog, delighted.
@export_range(0.0, 20.0, 0.5) var leave_distance: float = 7.0
## Held at about the height a person carries a chicken, slightly out in front.
@export var carry_offset := Vector4(0.0, 1.05, 0.35, 0.0)

var step: Step = Step.IDLE
var _mithra: CharacterBody4D
var _manager: Node
var _player: Node4D
var _catcher: Node
var _talk: Node
var _driver: Node
var _bird: Node
var _wait: float = 0.0
var _home := Vector4.ZERO
var _given: bool = false


func _ready() -> void:
	_mithra = get_node_or_null(mithra_path) as CharacterBody4D
	_manager = get_node_or_null(manager_path)
	_player = get_node_or_null(player_path) as Node4D
	_catcher = get_node_or_null(catcher_path)
	_talk = get_node_or_null(dialogue_path)
	_driver = get_node_or_null(driver_path)
	for missing in _missing():
		push_warning("MithraFetch: no %s, so her errand will not run." % missing)
	if _talk != null and _talk.has_signal("effect"):
		_talk.connect("effect", _on_effect)
	if _mithra != null:
		_home = _mithra.global_position


func _missing() -> Array:
	var out: Array = []
	if _mithra == null: out.append("Mithra")
	if _manager == null: out.append("chicken manager")
	if _player == null: out.append("player")
	if _catcher == null: out.append("catcher")
	if _talk == null: out.append("dialogue")
	return out


func _on_effect(name: String) -> void:
	match name:
		"fetch_chicken":
			_begin()
		"hand_over_chicken":
			_hand_over()
		"mithra_leaves":
			step = Step.LEAVING
			_wait = 0.0


## Off she goes. Started on the EFFECT rather than on the conversation ending, because the
## line that sends her is "stay there" - and a character who says that and then stands
## about waiting for a text box to close has said nothing.
func _begin() -> void:
	if not _missing().is_empty() or _given:
		return
	_bird = _nearest_loose()
	if _bird == null:
		# Every chicken is already penned or in your arms. Nothing to fetch, and she
		# should not set off across a field after a bird that does not exist.
		return
	_home = _mithra.global_position
	step = Step.GOING
	_mithra.set("halted", true)


## The loose bird nearest HER, not nearest the player - she is the one doing the walking,
## and sending her past three chickens to reach a fourth reads as a bug.
func _nearest_loose() -> Node:
	var best: Node = null
	var closest: float = INF
	for agent in _manager.call("locator_candidates"):
		var body: Node4D = (agent as Node).get_parent() as Node4D
		if body == null:
			continue
		var gap: float = body.global_position.distance_to(_mithra.global_position)
		if gap < closest:
			closest = gap
			best = agent
	return best


func _physics_process(delta: float) -> void:
	match step:
		Step.GOING:
			_going(delta)
		Step.PICKING_UP:
			_picking_up(delta)
		Step.RETURNING:
			_returning(delta)
		Step.LEAVING:
			_leaving(delta)


func _going(delta: float) -> void:
	if not is_instance_valid(_bird):
		_stand_down()
		return
	var body: Node4D = (_bird as Node).get_parent() as Node4D
	if body == null:
		_stand_down()
		return
	if _walk_towards(body.global_position, delta) > reach:
		return
	# Found. The bird stops being catchable by anyone else the moment she has it, which
	# is what on_caught is for - without it the player can take it out of her hands.
	_bird.call("on_caught")
	step = Step.PICKING_UP
	_wait = pickup_seconds


func _picking_up(delta: float) -> void:
	_mithra.linear_velocity.x = 0.0
	_mithra.linear_velocity.z = 0.0
	_carry()
	_wait -= delta
	if _wait <= 0.0:
		step = Step.RETURNING


func _returning(delta: float) -> void:
	_carry()
	if _walk_towards(_player.global_position, delta) > talk_distance:
		return
	_mithra.linear_velocity.x = 0.0
	_mithra.linear_velocity.z = 0.0
	if _mithra.has_method("face_towards"):
		_mithra.call("face_towards", _player.global_position)
	step = Step.TALKING
	# SHE OPENS HER OWN MOUTH. Everywhere else in this scene a conversation starts because
	# the player walked up and pressed a key; this one starts because she arrived, so it
	# is started from here rather than waiting to be talked to.
	if _driver != null and _driver.has_method("begin_delivery"):
		_driver.call("begin_delivery")


## Her arms are full while she walks back, and the bird has to be somewhere. Written as a
## LOCAL position: assigning global_position on a Node4D goes through the parent's
## transform and silently does nothing, which this project has now been caught by three
## times.
func _carry() -> void:
	if not is_instance_valid(_bird):
		return
	var body: Node4D = (_bird as Node).get_parent() as Node4D
	if body == null:
		return
	var host: Node4D = body.get_parent() as Node4D
	var origin: Vector4 = host.global_position if host != null else Vector4.ZERO
	body.position = _mithra.global_position + carry_offset - origin


## Into the player's hands, through the real catch.
func _hand_over() -> void:
	if not is_instance_valid(_bird) or _catcher == null:
		return
	# Out of hers first, or two things believe they are holding it.
	_bird.call("on_released")
	if not bool(_catcher.call("give", _bird)):
		# The player already has a chicken. Put it on the grass at their feet rather than
		# vanishing it - a gift that disappears because of an inventory rule is worse than
		# no gift.
		var body: Node4D = (_bird as Node).get_parent() as Node4D
		var host: Node4D = body.get_parent() as Node4D if body != null else null
		if body != null:
			body.position = _player.global_position \
				- (host.global_position if host != null else Vector4.ZERO)
	_given = true
	_bird = null
	if _driver != null and _driver.has_method("gave_a_chicken"):
		_driver.call("gave_a_chicken")


func _leaving(delta: float) -> void:
	if _mithra.global_position.distance_to(_home) < 1.2:
		_stand_down()
		return
	_walk_towards(_home, delta)


## Back to her own life: the searcher takes the wheel again and this node goes quiet.
func _stand_down() -> void:
	step = Step.IDLE
	if _mithra != null:
		_mithra.linear_velocity.x = 0.0
		_mithra.linear_velocity.z = 0.0
		_mithra.set("halted", false)


## Drives her towards a point at a run and returns how far away she still is.
##
## THROUGH move_and_slide, NOT BY SETTING POSITION. She has a collider and so does the
## fence; a fetch that teleports her along a straight line walks her through the pen.
func _walk_towards(point: Vector4, delta: float) -> float:
	var gap: Vector4 = point - _mithra.global_position
	var flat := Vector4(gap.x, 0.0, gap.z, 0.0)
	var distance: float = flat.length()
	if distance > 0.001:
		var step_dir: Vector4 = flat / distance
		_mithra.linear_velocity.x = step_dir.x * run_speed
		_mithra.linear_velocity.z = step_dir.z * run_speed
		if _mithra.has_method("face_towards"):
			_mithra.call("face_towards", point)
	if not _mithra.is_on_floor():
		_mithra.linear_velocity += _mithra.get_gravity() * delta
	_mithra.move_and_slide()
	# Through W as well, so she does not hand you a chicken from another slice. Slower
	# than the walk, the same way the player's ana/kata is.
	var through: float = point.w - _mithra.global_position.w
	if absf(through) > 0.01:
		_mithra.global_position.w += clampf(through, -1.0, 1.0) * run_speed * 0.3 * delta
	return distance


func reset() -> void:
	_stand_down()
	_bird = null
	_given = false
	_wait = 0.0
