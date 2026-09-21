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

@export_group("Catching")
## How close is close enough (item 26).
@export var catch_distance: float = 1.6
## How far off straight-ahead a chicken may be and still be catchable, in degrees.
@export var catch_angle_degrees: float = 110.0

@export_group("Throwing")
## Forward speed of a throw. Enough to clear a low fence, not enough to be a weapon
## (item 32).
@export var throw_speed: float = 5.5
## Upward part of the throw, which is what makes it an arc rather than a shove.
@export var throw_rise: float = 3.4
## A plain drop, for placing rather than throwing.
@export var drop_speed: float = 0.6

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
		_show_prompt("")
		return
	_candidate = _best_candidate()
	# Item 27: the prompt appears only when a catch would actually work, and goes the
	# instant it would not.
	_show_prompt("" if _candidate == null else "Catch  [%s]" % _action_hint(&"catch_target"))


## Scores every catchable chicken and returns the best, or null.
func _best_candidate() -> Node:
	if _manager == null:
		return null
	var forward: Vector4 = global_basis * Vector4(0.0, 0.0, 1.0, 0.0)
	var best: Node = null
	var best_score: float = -INF
	for agent in _manager.call("locator_candidates"):
		var body: Node4D = agent.get_parent() as Node4D
		if body == null:
			continue
		var to_bird: Vector4 = body.global_position - global_position
		var gap: float = to_bird.length()
		if gap > catch_distance:
			continue
		var facing: float = 1.0
		if gap > 0.001:
			facing = forward.dot(to_bird / gap)
		if facing < cos(deg_to_rad(catch_angle_degrees)):
			continue
		# Nearer is better, straighter ahead is better, and being ahead breaks ties
		# between two chickens at the same range.
		var score: float = (1.0 - gap / catch_distance) + facing * 0.6
		if score > best_score:
			best_score = score
			best = agent
	return best


func _catch(agent: Node) -> void:
	carried = agent
	agent.call("on_caught")
	var body: Node4D = agent.get_parent() as Node4D
	if body != null:
		# Freeze any leftover flight so a caught chicken does not keep travelling.
		_flying = _flying.filter(func(f): return f["agent"] != agent)
	emit_signal("caught", agent)


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
	body.position = _anchor.global_position - origin


func _release(thrown: bool) -> void:
	var agent: Node = carried
	carried = null
	if agent == null:
		return
	agent.call("on_released")
	var body: Node4D = agent.get_parent() as Node4D
	if body != null:
		var forward: Vector4 = (global_basis * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
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
