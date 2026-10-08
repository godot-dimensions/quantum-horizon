# CARRIED OVER from res://ramon/chickenpen/scripts/block_walker_character_4d.gd on 8 Oct 2026 (the pen's walk and camera as they are
# since Andrew's 4 and 7 Oct changes), so the lab owns this copy: the original can change without breaking the
# lab, and the other way round (LabKit/carried/README.md). GroundBasis4D is the carried copy, preloaded as Ground.
extends CharacterBody4D

const Ground := preload("res://ramon/VoxelLab/carried/LabKit/carried/chickenpen/scripts/ground_basis_4d.gd")

## A third-person character whose walk is PROCEDURAL, not ported and not recorded.
##
## The other two scenes in this folder port a 3D controller and give it a static body.
## This one is the opposite experiment: the rig is built here out of 4D blocks, and the
## walk comes from the same machinery the creatures in project/ramon/Model use - Motion
## Lab's gait clock driving limbs that are moved RIGIDLY, as whole nodes.
##
## RIGID IS THE WHOLE POINT. Measured on those creatures, the three ways to move
## geometry are about an order of magnitude apart per tetrahedron per frame: drawing it
## ~0.15 us, deforming it ~2.5 us, re-lofting it ~11 us. Moving a whole NODE costs
## nothing measurable - Trym's rigged creature runs six solvers and does not register
## above the noise floor. A character built as separate limb nodes can therefore be
## animated for free, which is why this is the version worth trying on a player
## character rather than the skinned one.
##
## The walk itself lives in block_gait_4d.gd, a sibling node, so all three scenes in this
## folder share one cycle rather than three copies of it. This script only moves the body
## and turns it; the gait node reads the velocity that results and works the legs.

@export_group("Movement")
## RUNNING IS THE DEFAULT. A character this size covering ground at a stroll is dull to
## play, so no modifier means a run; hold ALT to walk and SHIFT to sprint.
##
## The numbers are chosen against the BODY, not picked for feel. Cadence is
## stride / (speed * duty), so at a 0.78 stride these give roughly 1.1 steps a second
## walking, 2.3 running and 3.2 sprinting. The previous 6.0 "run" needed 4.6 steps a
## second on 0.36-unit legs, which is why it looked frantic: it was a sprint being
## called a run.
@export var run_speed: float = 3.0
@export var walk_speed: float = 1.4
@export var sprint_speed: float = 4.2
@export var jump_velocity: float = 4.6
@export_range(0.1, 50.0, 0.1) var acceleration: float = 12.0
@export_range(0.1, 50.0, 0.1) var turn_speed: float = 11.0

## Starts facing AWAY from the camera, which is PI, not zero.
##
## _turn_avatar sets this to atan2(wish.x, wish.z), so walking forward - which is -Z, the
## way the camera looks - gives PI. Starting at 0 therefore started the character facing
## the exact opposite of the way the first press of W would take it: it stood looking down
## the camera until you moved.
## Cleared while a conversation is open. Gravity and the floor keep working - only the
## player's own intent is switched off - so standing still mid-sentence cannot leave the
## body hovering or half through the ground.
var input_enabled: bool = true

## The avatar's frame, upright, +Z the way it faces. Changed only when the character moves or is
## told to face something (as a 3D character's facing is), so a standing model stays put in the
## world while the view turns round it; _target_stance says which frame. Starts at PI, facing
## away from the camera.
var _stance: Projection = Basis4D.from_zx(PI)
## The facing as a world x-z angle, atan2(forward.x, forward.z): the convention the scripts that
## pose the player use (pen_dream_wake_4d.gd, watchstone_4d.gd, lab_sequence_4d.gd). Set, the model
## faces that way along the world's floor at once, its W as near the view's as that allows.
var _facing: float:
	get:
		return atan2(_stance.z.x, _stance.z.z)
	set(value):
		var forward := Vector4(sin(value), 0.0, cos(value), 0.0)
		_stance = _target_stance(forward) if _rig != null else Basis4D.from_zx(value)
## While a conversation is open, the avatar turns to whoever is speaking instead of
## keeping whatever heading it was walking on. The NPCs already do this; without the
## player doing it too, they turn politely to face somebody staring at a fence.
var _face_point: Vector4 = Vector4.ZERO
var _facing_point: bool = false

## How much slower the ana/kata axis is than ordinary movement.
@export_range(0.05, 1.0, 0.05) var w_speed_scale: float = 0.3

@onready var _rig: Node4D = $CameraRig
@onready var _avatar: Node4D = $Avatar
@onready var _label: Label = get_node_or_null("StateLabel")


## Seconds left on the floor. Nothing else in the scene knocks the player down yet; the
## cat is the first thing that fights back.
var _down: float = 0.0


## The avatar starts facing the way the camera looks (Ramon, 7 Oct: "when the player starts, turn him 180
## degrees. right now hes facing me and the wall"): the pen's camera starts looking down the path, along +Z,
## and the fixed PI above faced the avatar back at it. The rig is a child, so its own _ready has set its yaw
## (yaw 0 looks along -Z).
func _ready() -> void:
	if _rig != null and "yaw" in _rig:
		var y: float = float(_rig.get("yaw"))
		_facing = atan2(-sin(y), -cos(y))
		if _avatar != null:
			_avatar.basis = _stance


## Put on the ground for a moment. Movement stops, the avatar tips over, and it gets back
## up on its own - there is no state to clear and nothing to forget to undo.
func knock_down(seconds: float) -> void:
	_down = maxf(_down, seconds)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		linear_velocity += get_gravity() * delta
	if _down > 0.0:
		_down -= delta
		linear_velocity.x = move_toward(linear_velocity.x, 0.0, 20.0 * delta)
		linear_velocity.z = move_toward(linear_velocity.z, 0.0, 20.0 * delta)
		linear_velocity.w = move_toward(linear_velocity.w, 0.0, 20.0 * delta)
		move_and_slide()
		# Tipped over, and levelling out again over the last half second rather than
		# snapping upright.
		var tip: float = clampf(_down / 0.5, 0.0, 1.0) * PI * 0.42
		_avatar.basis = _stance * Basis4D.from_yz(tip)
		return
	if input_enabled and Input.is_action_just_pressed(&"move_jump") and is_on_floor():
		linear_velocity.y = jump_velocity
	var parts: Array = _wish_parts()
	var wish: Vector4 = parts[0]
	var ana: float = parts[1]
	var top: float = run_speed
	if input_enabled and Input.is_key_pressed(KEY_SHIFT):
		top = sprint_speed
	elif input_enabled and Input.is_key_pressed(KEY_ALT):
		top = walk_speed
	var rate: float = acceleration * top * delta
	# The fourth axis moves DELIBERATELY, at a fraction of walking pace, AND ALONG THE VIEW'S
	# OWN W - the slice normal, the rig's w axis - not the world's: stepping out of the world
	# you can see means leaving your slice square on, and only with the slice level are the
	# two the same.
	#
	# At full speed a short press of the ana key crossed w 0 to 5.9, and the twelve
	# chickens live between w -2.5 and 2.5 - so every one of them was behind a control
	# that shot past all of them at once, and landing on one was luck. It is also truer to
	# what the action is: stepping out of the world you can see is not a stride.
	# ONLY THE KEY IS THROTTLED, NOT THE WALK.
	#
	# Walking inside a tilted slice has a w component - your own forward axis leans
	# through W - and it has to move at the same pace as x and z or you slide out of the
	# slice you are standing in. It used to share this throttle with the ana key, at 30%,
	# so every step drifted you off your own slice: line up on a chicken, walk at it, and
	# it is gone again by the time you arrive. That is the whole "everything goes
	# lopsided when I walk".
	var w_top: float = top * w_speed_scale
	var target: Vector4 = wish * top + _rig.basis.w * (ana * w_top)
	# Eased as one horizontal vector: the step through W has x and z in it once the slice is
	# tilted, and the walk has w, so the axes are not separately anybody's.
	var horizontal := Vector3(linear_velocity.x, linear_velocity.z, linear_velocity.w).move_toward(Vector3(target.x, target.z, target.w), rate)
	linear_velocity.x = horizontal.x
	linear_velocity.z = horizontal.y
	linear_velocity.w = horizontal.z
	move_and_slide()
	_step_up(wish)
	_turn_avatar(target, delta)
	if _label != null:
		_label.text = "%s   %.1f units/s   w %.2f" % [
			_gait_name(),
			_horizontal_speed(), position.w]


## CLIMBING A STEP, because nothing else here can.
##
## The 4D physics engine is axis-aligned - `axis_aligned_box_physics_engine_4d` is the
## only one there is - so a sloped collider does not exist: a ramp has to be built as a
## staircase of little boxes. And CharacterBody4D has no step-up of its own, so every one
## of those risers is a vertical face, and a vertical face is a WALL however low it is.
## The result is geometry you can walk down and cannot walk back up, which is what this
## fixes.
##
## IT PROBES RATHER THAN SHOVING. Lifting whenever the body is blocked would let you climb
## anything by leaning on it. This asks what the floor is doing a pace ahead - a ray down
## from above head-of-step height - and only lifts if there IS floor there and it is
## within one step. A wall has no floor a pace in front of it at knee height, so a wall
## stays a wall. A gap in a fence has floor beyond it, but the floor is at the SAME height,
## so there is nothing to climb and nothing happens.
@export_group("Stepping up")
## The tallest thing that counts as a step rather than an obstacle.
@export_range(0.0, 1.0, 0.01) var step_height: float = 0.32
## How far ahead to look for the surface being stepped onto.
@export_range(0.1, 1.5, 0.05) var step_reach: float = 0.45


func _step_up(wish: Vector4) -> void:
	if step_height <= 0.0 or not is_on_wall() or not is_on_floor():
		return
	var flat := Vector4(wish.x, 0.0, wish.z, 0.0)
	if flat.length() < 0.2:
		return
	flat = flat.normalized()
	# Down from above the highest step we would take, a pace ahead.
	var params := RaycastParameters4D.new()
	var probe: Vector4 = global_position + flat * step_reach
	params.global_ray_origin = probe + Vector4(0.0, step_height + 0.25, 0.0, 0.0)
	params.global_ray_direction = Vector4(0.0, -1.0, 0.0, 0.0)
	params.max_distance = step_height + 0.30
	var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
	if Engine.get_physics_frames() % 40 == 0:
		print("[step] from %v dir %v hit %s" % [params.global_ray_origin, flat,
			str(hit.get("position", "nothing"))])
	if hit.is_empty() or not hit.has("global_point"):
		return
	var top: float = (hit["global_point"] as Vector4).y
	var climb: float = top - global_position.y
	if climb <= 0.02 or climb > step_height:
		return
	# Onto it, plus a hair so the next frame starts above the lip rather than inside it.
	global_position = Vector4(global_position.x, top + 0.02,
		global_position.z, global_position.w)


## Walking and stepping through W are two different actions that happened to share one
## vector, and sharing it is what made them share a speed limit too. Split: the walk is a
## unit direction lying IN your slice, tilt and all; the step is the raw key, scaled
## separately by whoever uses it.
func _wish_parts() -> Array:
	if not input_enabled:
		return [Vector4.ZERO, 0.0]
	var side: float = Input.get_axis(&"move_left", &"move_right")
	var fore: float = Input.get_axis(&"move_forward", &"move_back")
	var ana: float = Input.get_axis(&"move_kata", &"move_ana")
	var walk: Vector4 = Vector4.ZERO
	if side * side + fore * fore > 0.0001:
		walk = (_rig.movement_basis() * Vector4(side, 0.0, fore, 0.0)).normalized()
	return [walk, ana]


## Kept for anything that only wants the direction, and for the searcher, which drives
## this character without a rig of its own.
func _wish_direction() -> Vector4:
	return _wish_parts()[0]


func _turn_avatar(move: Vector4, delta: float) -> void:
	# Eased at the same rate a walking turn uses, rather than snapped: a head that jumps
	# round the instant a key is pressed reads as a glitch, and this is the one moment the
	# player is looking straight at their own avatar. Eased along the one rotation that takes
	# the stance to where it is going, whichever way that is - across the floor you see or
	# through W - so a step ana turns the model the way a step forward does.
	var want: Vector4 = _face_point - global_position if _facing_point else move
	want.y = 0.0
	if want.length_squared() > 1e-6:
		_stance = Ground.rotated_toward(_stance, _target_stance(want.normalized()), turn_speed * delta)
	_avatar.basis = _stance


## The frame the avatar turns to in order to face [param forward]: a horizontal unit, any way on
## the 4D floor.
##
## WHICH WAY A PERSON FACES IS AMBIGUOUS IN 4D: a whole circle of frames share one forward, turned
## about it through W. Walking across the floor you see, this is the one whose W is the slice's
## own +W (the rig's), so the cross-section you see of the model is the one you would see of a
## person standing in your world; with the slice level it is exactly from_zx(facing). Walking
## through W the model's W cannot be yours - it is facing that way - so it takes the nearest it
## can: the view's W with the forward's part taken out; or, facing straight along the view's W,
## wherever the least turn from its stance puts its W. +Z is the forward, Y up, X completes a
## right-handed frame.
func _target_stance(forward: Vector4) -> Projection:
	var n: Vector4 = _rig.basis.w
	var w: Vector4 = n - forward * forward.dot(n)
	if w.length_squared() < 1e-6:
		w = _least_turned(_stance.w, _stance.z, forward)
	w = w.normalized()
	return Projection(_right_of(forward, w), Vector4(0.0, 1.0, 0.0, 0.0), forward, w)


## [param v] carried by the least rotation of the floor's (x, z, w) that takes [param from] to
## [param to]: in the plane of the two, by the angle between them. Opposite directions have no
## such plane; then it is an about-face on the floor, about the stance's own W.
func _least_turned(v: Vector4, from: Vector4, to: Vector4) -> Vector4:
	var a := Vector3(from.x, from.z, from.w)
	var b := Vector3(to.x, to.z, to.w)
	var axis: Vector3 = a.cross(b)
	var q: Quaternion
	if axis.length_squared() < 1e-12:
		if a.dot(b) > 0.0:
			return v
		q = Quaternion(Vector3(_stance.w.x, _stance.w.z, _stance.w.w).normalized(), PI)
	else:
		q = Quaternion(axis.normalized(), acos(clampf(a.dot(b), -1.0, 1.0)))
	var r: Vector3 = q * Vector3(v.x, v.z, v.w)
	return Vector4(r.x, 0.0, r.y, r.z)


## The right-hand side of [param forward] on the floor of a slice with normal [param n]: the
## horizontal unit perpendicular to both that makes (right, up, forward, n) right-handed. Level,
## it is from_zx's own x column.
func _right_of(forward: Vector4, n: Vector4) -> Vector4:
	var c: Vector3 = Vector3(forward.x, forward.z, forward.w).cross(Vector3(n.x, n.z, n.w))
	return Vector4(c.x, 0.0, c.y, c.z).normalized()


## Turn to face a point without moving toward it. Same name and convention as the NPCs'.
func face_towards(point: Vector4) -> void:
	_face_point = point
	_facing_point = true


## Back to facing wherever you walk.
func stop_facing() -> void:
	_facing_point = false


func _horizontal_speed() -> float:
	return Vector3(linear_velocity.x, linear_velocity.z, linear_velocity.w).length()


func _gait_name() -> String:
	if not is_on_floor():
		return "AIRBORNE"
	var moving: float = _horizontal_speed()
	if moving < 0.05:
		return "IDLE"
	if moving > (run_speed + sprint_speed) * 0.5:
		return "SPRINT"
	if moving < (walk_speed + run_speed) * 0.5:
		return "WALK"
	return "RUN"
