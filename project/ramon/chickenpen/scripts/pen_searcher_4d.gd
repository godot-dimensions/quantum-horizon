extends CharacterBody4D

## The girl looking for her pocket watch: the player's own rig, driven by a wander instead of input.
##
## SAME RIG, DIFFERENT DRIVER. She is a CharacterBody4D with a block_avatar_4d and a
## block_gait_4d under her, exactly as the player is - so she inherits the planted feet, the
## pelvis drop, the arm swing and the stoop for free, and any fix to the walk reaches her
## without being ported. The only thing block_walker_character_4d does that this does not is
## read the keyboard. Everything below replaces that one function: choose somewhere to be,
## walk there, stop and look about, choose again.
##
## THE FACING CONVENTION IS THE PLAYER'S. `_facing = atan2(wish.x, wish.z)` and the avatar's
## basis is from_zx of it, which makes +Z the direction she walks - the same convention the
## catch and the throw use. Getting this backwards is a mistake this project has already
## made twice, so it is copied rather than re-derived.
##
## SHE IS SEARCHING, WHICH IS WHY SHE STOPS. A character that walks continuously reads as
## patrolling. The pauses are the characterisation: she gets somewhere, looks around, does
## not find it, and tries somewhere else.

@export var avatar_path: NodePath = NodePath("Avatar")
@export var player_path: NodePath
@export var inventory_path: NodePath
@export var readout_path: NodePath

@export_group("Wandering")
## Where she searches, and how far she strays from it. Set from her starting position.
@export_range(1.0, 30.0, 0.5) var roam_radius: float = 7.0
@export_range(0.2, 4.0, 0.1) var walk_speed: float = 1.3
@export_range(0.5, 20.0, 0.5) var turn_speed: float = 4.0
@export_range(0.5, 8.0, 0.1) var pause_min: float = 1.2
@export_range(0.5, 12.0, 0.1) var pause_max: float = 3.0
## How close counts as arrived. Loose, or she creeps the last few centimetres.
@export_range(0.1, 2.0, 0.05) var arrive_within: float = 0.6
## Room she keeps from anything solid when she picks a spot (her body plus a hand).
@export_range(0.2, 2.0, 0.05, "suffix:m") var clearance: float = 0.7
## How long she may walk without getting closer before she gives that spot up.
@export_range(0.3, 4.0, 0.1, "suffix:s") var give_up_after: float = 0.9

@export_group("Talking")
@export_range(1.0, 12.0, 0.5) var speak_within: float = 4.0
@export_range(0.5, 8.0, 0.5) var speak_within_w: float = 2.5

var _avatar: Node4D
var _player: Node4D
var _inventory: Node
var _readout: Label
var _home := Vector4.ZERO
var _target := Vector4.ZERO
var _facing: float = PI
var _pause: float = 0.0
var _rng := RandomNumberGenerator.new()
var _said: String = ""
## The closest she has been to the spot she is walking to, and how long since she got closer.
var _best: float = INF
var _no_progress: float = 0.0
## The way back from the last spot she could not reach; she looks that way next.
var _away := Vector2.ZERO


## Set while she is being talked to. Gravity and the floor keep working; only her
## searching stops, so she cannot walk out of her own conversation.
var halted: bool = false


func _ready() -> void:
	_avatar = get_node_or_null(avatar_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	_inventory = get_node_or_null(inventory_path)
	_readout = get_node_or_null(readout_path) as Label
	_rng.seed = 90210
	_home = position
	_target = position
	_pause = _rng.randf_range(pause_min, pause_max)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		linear_velocity += get_gravity() * delta
	if halted:
		linear_velocity.x = 0.0
		linear_velocity.z = 0.0
		linear_velocity.w = 0.0
		move_and_slide()
		return
	_think(delta)
	move_and_slide()
	_talk()


## Turn to whoever is speaking to her, so she is not delivering her lines to a fence post.
## Uses the player's own facing convention: atan2(x, z) into Basis4D.from_zx.
func face_towards(point: Vector4) -> void:
	if _avatar == null:
		return
	var gap: Vector4 = point - global_position
	if absf(gap.x) > 0.001 or absf(gap.z) > 0.001:
		_facing = atan2(gap.x, gap.z)
		_avatar.basis = Basis4D.from_zx(_facing)


func _think(delta: float) -> void:
	if _pause > 0.0:
		# Standing still and looking about. Turning while stopped is what sells searching -
		# a character that freezes between walks reads as switched off.
		_pause -= delta
		_facing = wrapf(_facing + delta * 0.9, -PI, PI)
		_apply_facing()
		linear_velocity.x = move_toward(linear_velocity.x, 0.0, walk_speed * 6.0 * delta)
		linear_velocity.z = move_toward(linear_velocity.z, 0.0, walk_speed * 6.0 * delta)
		if _pause <= 0.0:
			_choose(_away)
			_away = Vector2.ZERO
		return

	var to: Vector4 = _target - position
	var left: float = Vector2(to.x, to.z).length()
	if left <= arrive_within:
		_pause = _rng.randf_range(pause_min, pause_max)
		return
	# STUCK AGAINST SOMETHING (Ramon, 7 Oct: "mirtha is crying against the wall ... and not walking").
	# A spot behind the town wall, a bush or the cat's rocks can never be reached, and with nothing
	# to notice it she pressed into it for good. Not getting closer for a moment is how she notices:
	# she stops, looks about, and then tries somewhere the other way.
	if left < _best - 0.05:
		_best = left
		_no_progress = 0.0
	else:
		_no_progress += delta
		if _no_progress >= give_up_after:
			_away = -Vector2(to.x, to.z).normalized()
			_pause = _rng.randf_range(pause_min, pause_max) * 0.5
			return

	var wish: Vector4 = Vector4(to.x, 0.0, to.z, 0.0).normalized()
	linear_velocity.x = move_toward(linear_velocity.x, wish.x * walk_speed, walk_speed * 4.0 * delta)
	linear_velocity.z = move_toward(linear_velocity.z, wish.z * walk_speed, walk_speed * 4.0 * delta)
	_facing = rotate_toward(_facing, atan2(wish.x, wish.z), turn_speed * delta)
	_apply_facing()


## Somewhere else within her patch. Never her own W - she is looking on this slice, which
## is the joke: the watch is not on it.
##
## ONLY WHERE SHE CAN WALK STRAIGHT TO (7 Oct). Her patch takes in the town wall, two bushes, two
## oaks and the cat's rock pile, so a spot is tried with a ray at knee height from her to it, and
## kept only if nothing solid lies before it and [member clearance] past it. Given [param away]
## (the way back from a spot she could not reach), she looks only in that half. If twelve tries
## all fail she stays put and looks about again.
func _choose(away: Vector2 = Vector2.ZERO) -> void:
	_best = INF
	_no_progress = 0.0
	for i in 12:
		var angle: float = _rng.randf_range(0.0, TAU)
		var span: float = _rng.randf_range(roam_radius * 0.3, roam_radius)
		var spot: Vector4 = _home + Vector4(cos(angle) * span, 0.0, sin(angle) * span, 0.0)
		var step := Vector2(spot.x - position.x, spot.z - position.z)
		if step.length() < arrive_within * 2.0:
			continue
		if away != Vector2.ZERO and step.normalized().dot(away) < 0.2:
			continue
		if _blocked(step):
			continue
		_target = Vector4(spot.x, position.y, spot.z, position.w)
		return
	_target = position
	_pause = _rng.randf_range(pause_min, pause_max)


## Whether something solid stands between her and [param step] away (x, z), or within
## [member clearance] past it.
func _blocked(step: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var dir := Vector4(step.x, 0.0, step.y, 0.0).normalized()
	var params := RaycastParameters4D.new()
	params.global_ray_origin = global_position + Vector4(0.0, 0.5, 0.0, 0.0)
	params.global_ray_direction = dir
	params.max_distance = step.length() + clearance
	var skip: Array[Node4D] = [self]
	if _player != null:
		skip.append(_player)
	params.set_exclude_nodes(skip)
	var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
	return bool(hit.get("hit", false))


func _apply_facing() -> void:
	if _avatar != null:
		_avatar.basis = Basis4D.from_zx(_facing)


## One line, when you are near enough, and a different one once you are carrying the thing
## she has lost. She does not take it - there is no trade here yet - but she notices.
func _talk() -> void:
	if _player == null or _readout == null:
		return
	var gap: Vector4 = _player.global_position - global_position
	var near: bool = Vector2(gap.x, gap.z).length() <= speak_within \
		and absf(gap.w) <= speak_within_w
	var line: String = ""
	if near:
		var has_watch: bool = _inventory != null and bool(_inventory.call("has_item", "found_watch"))
		line = "Mithra: \"Is that my watch? I've been up and down this field twice.\"" if has_watch \
			else "Mithra: \"I dropped my watch somewhere here. I can hear it. It's not where I dropped it.\""
	if line != _said:
		_said = line
		_readout.text = line
