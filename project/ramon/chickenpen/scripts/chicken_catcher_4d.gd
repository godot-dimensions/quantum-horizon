extends Node4D

## Catching, carrying, dropping and throwing a chicken. Lives on the player.
##
## FORGIVING BY DESIGN (item 26). The brief asks for the best valid candidate rather than
## pixel-perfect aiming, so this scores every catchable chicken on distance AND on how
## far off your facing it is, and takes the best one. A chicken slightly behind your
## shoulder loses to one straight ahead at the same range, but a chicken dead ahead and
## slightly further away still wins - which is what "forgiving" means in practice.
##
## W COUNTS AS DISTANCE. A chicken in another slice is not catchable however close it
## looks on the floor plan, because the whole point of the locator is that you have to
## bring yourself into its slice first. That falls out of measuring the gap through all
## four axes rather than only through XZ.
##
## THE CARRY IS A FOLLOW, NOT A REPARENT. Reparenting would drag the chicken into the
## player's scaled space and fight the manager that owns it. Instead the carried chicken
## is moved to the anchor every frame, which also means it keeps its own W and survives
## the player moving through slices (item 64).

signal caught(agent: Node)
signal released(agent: Node, thrown: bool)

@export var manager_path: NodePath
@export var carry_anchor_path: NodePath
@export var prompt_path: NodePath
## Which node's facing decides what is "in front of you".
##
## THE AVATAR, NOT THIS NODE. The catcher hangs off the player body, and the body never
## turns - only the avatar does, because turning the body would feed yaw into the movement
## maths. So reading the body's basis asked "what is north of you", not "what are you
## looking at", and the answer never changed however the player span on the spot.
@export var facing_path: NodePath
## The gait, told when a chicken is picked up so it can stoop and then hold its arms up.
@export var gait_path: NodePath
## Whose basis defines the slice you are standing in - the camera rig. Same node the
## locator and the radar read; see the note on catch_w_tolerance for why it matters here.
@export var slice_frame_path: NodePath

@export_group("Catching")
## How close is close enough (item 26).
@export var catch_distance: float = 1.6
## How far off straight-ahead a chicken may be and still be catchable, in degrees.
@export var catch_angle_degrees: float = 110.0
## How far off your own slice a chicken may be and still be catchable.
##
## MUCH TIGHTER THAN THE REACH, and separate from it on purpose. Measuring catch range as a
## plain 4D distance let the player grab a bird 0.9 out through W - one they could not see,
## standing in front of empty grass - because 0.9 through W and 1.2 across the ground came
## to less than the 1.6 reach. That quietly made the whole phase step optional, and made a
## liar of the locator, which was still saying "turn toward ana" to make it catchable. You
## have to be in the chicken's slice to pick it up; that is the mechanic.
##
## MEASURED ALONG THE SLICE YOU ARE IN, not along the world's W axis. Those are the same
## thing only until you slice-rotate, and then they are badly different: rotating brings a
## chicken into view by turning the slice, which leaves its WORLD w offset as large as it
## ever was. Testing the world axis meant a bird you were looking straight at refused to be
## picked up, so rotating was useless for catching and the only way in was to walk through
## W. This is the same quantity the locator calls ana_offset, so "the locator says
## catchable" and "the catch works" are now the same statement.
@export_range(0.05, 1.0, 0.05) var catch_w_tolerance: float = 0.35
## How far below (or above) you a chicken can be and still be picked up. Generous: the
## character stoops for it, and a bird at your feet is the normal case, not the edge one.
@export_range(0.2, 4.0, 0.1) var catch_height: float = 2.0

@export_group("Throwing")
## A LOB, NOT A PITCH. Held overhead in two hands and tossed about three metres, which is
## far enough to clear the fence from just outside it and short enough that you have to
## walk up to the pen rather than lining up a shot from across the field. The old numbers
## threw it 5.9 m flat - a baseball, not a chicken being put somewhere.
##
## The two together set the shape: rise decides how high the arch goes and therefore how
## long it is in the air, speed decides how far it gets in that time.
@export var throw_speed: float = 1.90
## Upward part of the throw, which is what makes it an arc rather than a shove.
@export var throw_rise: float = 3.0
## A plain drop, for placing rather than throwing.
@export var drop_speed: float = 0.6

## How far a carried chicken bobs in your hands (item 30).
@export_range(0.0, 0.3, 0.01) var carry_bob: float = 0.05

@export_group("Flight")
@export var gravity: float = 9.0
## Below this height a thrown chicken has landed.
@export var ground_y: float = 0.0

var carried: Node = null

var _manager: Node
var _anchor: Node4D
var _prompt: Label
var _candidate: Node = null
var _flying: Array = []
var _bob: float = 0.0


func _ready() -> void:
	_manager = get_node_or_null(manager_path)
	_anchor = get_node_or_null(carry_anchor_path) as Node4D
	_prompt = get_node_or_null(prompt_path) as Label
	if _manager == null:
		push_warning("ChickenCatcher: manager_path resolves to nothing, so nothing can be caught.")
	if _anchor == null:
		push_warning("ChickenCatcher: carry_anchor_path resolves to nothing - a caught chicken would have nowhere to sit (item 29).")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"catch_target"):
		if carried != null:
			_release(true)
		elif _candidate != null:
			_catch(_candidate)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"fire") and carried != null:
		# A gentle drop, for placing a chicken rather than lobbing it.
		_release(false)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_advance_flights(delta)
	if carried != null:
		_carry_tick()
		# Item 68: the throw and the drop are taught HERE, at the only moment they mean
		# anything. Before you are holding a chicken there is nothing to throw, and a
		# tutorial panel that explained it up front would be explaining a verb the player
		# cannot perform yet. Both are shown because they are genuinely different acts -
		# one lobs the bird over the fence, the other sets it down where you stand.
		_show_prompt("Throw  [%s]      Put down  [%s]" % [
			_action_hint(&"catch_target"), _action_hint(&"fire")])
		return
	_candidate = _best_candidate()
	# Item 27: the prompt appears only when a catch would actually work, and goes the
	# instant it would not.
	_show_prompt("" if _candidate == null else "Catch  [%s]" % _action_hint(&"catch_target"))


## Scores every catchable chicken and returns the best, or null.
func _best_candidate() -> Node:
	if _manager == null:
		return null
	# PLUS Z, because that is the direction this character walks.
	#
	# Basis4D.looking_at treats -Z as forward, and following that convention here was
	# wrong: the avatar is not posed with looking_at, it is posed by the walker's _pose,
	# which puts the basis' +Z column along the movement direction. Using -Z aimed the
	# catch, and the throw, at whatever was directly behind the character as it walked.
	var facing: Node4D = get_node_or_null(facing_path) as Node4D
	var frame: Projection = facing.global_basis if facing != null else global_basis
	var forward: Vector4 = frame * Vector4(0.0, 0.0, 1.0, 0.0)
	var slice: Projection = _slice_basis()
	var best: Node = null
	var best_score: float = -INF
	for agent in _manager.call("locator_candidates"):
		var body: Node4D = agent.get_parent() as Node4D
		if body == null:
			continue
		var to_bird: Vector4 = body.global_position - global_position
		if absf(to_bird.dot(slice.w)) > catch_w_tolerance:
			continue
		# HORIZONTAL distance within that slice, with height handled separately.
		#
		# Measuring all three together spent most of the reach going DOWN: this node rides
		# at the player's origin, about 1.3 above the ground, and a chicken stands at zero.
		# That left sqrt(1.6^2 - 1.3^2) = 0.93 of actual grabbing room, so a bird plainly
		# in front of you was out of range for reasons nothing on screen could explain.
		# How far away it is and whether you can bend down to it are two questions.
		var drop: float = absf(to_bird.dot(slice.y))
		if drop > catch_height:
			continue
		var gap: float = Vector2(to_bird.dot(slice.x), to_bird.dot(slice.z)).length()
		if gap > catch_distance:
			continue
		var ahead: float = 1.0
		if gap > 0.001:
			# Measured flat too, so looking slightly down at a bird at your feet does not
			# count against how squarely you are facing it.
			var flat := Vector2(to_bird.dot(slice.x), to_bird.dot(slice.z)) / gap
			ahead = Vector2(forward.dot(slice.x), forward.dot(slice.z)).normalized().dot(flat)
		if ahead < cos(deg_to_rad(catch_angle_degrees)):
			continue
		# Nearer is better, straighter ahead is better, and being ahead breaks ties
		# between two chickens at the same range.
		var score: float = (1.0 - gap / catch_distance) + ahead * 0.6
		if score > best_score:
			best_score = score
			best = agent
	return best


## The frame the visible slice is defined in. Falls back to this node's own basis, which
## is what it used to use implicitly by reading the world axes.
func _slice_basis() -> Projection:
	var frame: Node4D = get_node_or_null(slice_frame_path) as Node4D
	return frame.global_basis if frame != null else global_basis


## Put a chicken in the player's hands without them having reached for it - Mithra hands
## one over at the end of her errand.
##
## A REAL CATCH, not a lookalike. It goes through the same _catch the F key does, so the
## bird enters CARRIED, the gait raises its arms, the `caught` signal fires and the cluck
## plays. A second path that merely parented the chicken to the anchor would drift from
## this one the first time either changed.
func give(agent: Node) -> bool:
	if agent == null or carried != null:
		return false
	_catch(agent)
	return true


func _catch(agent: Node) -> void:
	carried = agent
	_tell_gait(true)
	agent.call("on_caught")
	var body: Node4D = agent.get_parent() as Node4D
	if body != null:
		# Freeze any leftover flight so a caught chicken does not keep travelling.
		_flying = _flying.filter(func(f): return f["agent"] != agent)
	emit_signal("caught", agent)


func _tell_gait(carrying: bool) -> void:
	var gait: Node = get_node_or_null(gait_path)
	if gait != null:
		gait.call("set_carrying", carrying)


func _carry_tick() -> void:
	var body: Node4D = carried.get_parent() as Node4D
	if body == null or _anchor == null:
		return
	# Item 29 and 64: sits on the anchor, keeps its orientation cue readable, and follows
	# the player through W because the anchor is read in world space.
	#
	# Written as a LOCAL position deliberately. Assigning global_position on a Node4D is
	# a known trap in this engine - the setter goes through the parent's local transform
	# - and it silently did nothing here: the chicken stayed exactly where it was while
	# every other part of the carry looked correct.
	var host: Node4D = body.get_parent() as Node4D
	var origin: Vector4 = host.global_position if host != null else Vector4.ZERO
	# Item 30: a small bob on top of the anchor, so a held chicken is never perfectly
	# still. It belongs here rather than on the chicken because this line runs after the
	# chicken's own processing and would overwrite anything it wrote to its height.
	_bob += get_physics_process_delta_time()
	var lift: float = sin(_bob * 5.4) * carry_bob + sin(_bob * 2.1) * carry_bob * 0.4
	body.position = _anchor.global_position - origin + Vector4(0.0, lift, 0.0, 0.0)


func _release(thrown: bool) -> void:
	var agent: Node = carried
	carried = null
	_tell_gait(false)
	if agent == null:
		return
	agent.call("on_released")
	var body: Node4D = agent.get_parent() as Node4D
	if body != null:
		# Thrown the way the character is facing, which is the way it walks - see the note
		# on +Z in _best_candidate.
		var facing: Node4D = get_node_or_null(facing_path) as Node4D
		var frame: Projection = facing.global_basis if facing != null else global_basis
		var forward: Vector4 = (frame * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
		var speed: float = throw_speed if thrown else drop_speed
		var rise: float = throw_rise if thrown else 0.0
		_flying.append({
			"agent": agent,
			"body": body,
			"velocity": forward * speed + Vector4(0.0, rise, 0.0, 0.0),
		})
	emit_signal("released", agent, thrown)


## Thrown chickens, until they land.
##
## Deliberately NOT the physics engine. A thrown chicken needs to land predictably on
## valid ground and become a chicken again (item 33); a rigid body would bounce, roll,
## wedge under the fence or tunnel through it, which is the failure the brief names.
func _advance_flights(delta: float) -> void:
	if _flying.is_empty():
		return
	var still_flying: Array = []
	for flight in _flying:
		var body: Node4D = flight["body"]
		if not is_instance_valid(body):
			continue
		var velocity: Vector4 = flight["velocity"]
		velocity.y -= gravity * delta
		body.position += velocity * delta
		flight["velocity"] = velocity
		if body.position.y <= ground_y and velocity.y < 0.0:
			body.position.y = ground_y
			_land(flight["agent"], body)
		else:
			still_flying.append(flight)
	_flying = still_flying


func _land(agent: Node, _body: Node4D) -> void:
	# Whether it landed in the pen is the pen's business, not the catcher's; the pen
	# watches its own volume and calls on_landed itself. Here it simply stops flying.
	agent.call("on_landed", false)


func _show_prompt(text: String) -> void:
	if _prompt == null:
		return
	_prompt.text = text
	_prompt.visible = text != ""


func _action_hint(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string((event as InputEventKey).physical_keycode)
		if event is InputEventMouseButton:
			return "Mouse %d" % (event as InputEventMouseButton).button_index
	return "?"
