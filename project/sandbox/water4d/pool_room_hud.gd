extends Label
## The room's contextual prompt, and the keys that only work where the prompt says so.
##
## CONTEXTUAL MEANS THE KEYS ARE ALSO CONTEXTUAL, not just the text. Pressing 3 in a corner
## of the room does nothing; the wave modes belong to the walkway, because that is where you
## can see the water they change. The same for the rotation point: the slice turn is offered
## in one place, with a ring drawn on the deck, so it reads as a thing the room does rather
## than a key you were told about once.
##
## THE SLICE TURN WRITES THE PLAYER'S OWN BASIS, which is what the Cross-section engine reads
## through the camera under it. It does NOT fight `player.gd` - that script only touches the
## basis on mouse motion, so a key-driven turn and a drag can coexist, and right-drag still
## works here exactly as it does everywhere else in the project. This is a guided version of
## the same control, not a replacement for it.
##
## y IS FORCED BACK TO WORLD UP after every turn, for the same reason `player.gd` does it and
## `sandbox/water4d/water4d_camera.gd` explains at length: the water's surface is
## parameterised with world up inside the slice, which holds while the turn stays in the xw
## and zw planes. A yw turn would shear the sea.

const Presets := preload("res://sandbox/water4d/water4d_presets.gd")

@export var room_path: NodePath = ^"../../Room"
@export var water_path: NodePath = ^"../../Water"
@export var player_path: NodePath = ^"../../Player"

var _room: Node4D = null
var _water: Node4D = null
var _player: Node4D = null
var _turn: float = 0.0


func _ready() -> void:
	_room = get_node_or_null(room_path) as Node4D
	_water = get_node_or_null(water_path) as Node4D


## LATE, NOT IN _ready. Godot readies children before parents, so this label is ready before
## the room that builds the player is - looking it up in _ready would find nothing, once,
## and the prompts would never appear again.
func _resolve_player() -> Node4D:
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node4D
	return _player


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _room == null or _resolve_player() == null:
		return
	if not bool(_room.call(&"is_on_walkway", _player.global_position)):
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_8 and _water != null:
		_water.call(&"set_preset", key.keycode - KEY_1)


func _process(delta: float) -> void:
	if _room == null or _water == null or _resolve_player() == null:
		return
	var where: Vector4 = _player.global_position
	var on_walkway: bool = bool(_room.call(&"is_on_walkway", where))
	var on_point: bool = bool(_room.call(&"is_on_rotation_point", where))

	if on_point:
		var turning: float = 0.0
		if Input.is_key_pressed(KEY_Z):
			turning -= 1.0
		if Input.is_key_pressed(KEY_C):
			turning += 1.0
		if turning != 0.0:
			var step: float = deg_to_rad(float(_room.get(&"rotation_speed_degrees"))) * turning * delta
			_turn = fposmod(_turn + step, TAU)
			var basis: Projection = Basis4D.from_xw(step) * _player.global_basis
			# World up back inside the slice - see the note at the top of this file.
			basis.y = Vector4(0.0, 1.0, 0.0, 0.0)
			_player.global_basis = Basis4D.orthonormalized(basis)

	var preset: int = int(_water.get(&"preset_index"))
	var name: String = Presets.preset_name(preset)
	var depth: float = float(_room.get(&"pool_depth"))

	var lines := "WASD walk   mouse look (orbit)   wheel zoom   Tab camera preset   Q / E through W\n"
	if on_point:
		lines += "[ ROTATION POINT ]  Z and C turn the slice - watch the waves change, not just the view\n"
	elif on_walkway:
		lines += "[ WALKWAY ]  1-8 change the sea.   Stand on the ring mid-span to turn the slice\n"
	else:
		lines += "Step onto the walkway to change the sea\n"
	lines += ("%d. %s    pool %.0f m deep    slice turned %.0f deg    %d fps"
			% [preset + 1, name, depth, rad_to_deg(_turn), Engine.get_frames_per_second()])
	text = lines
