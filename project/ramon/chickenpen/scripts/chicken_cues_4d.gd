extends Node

## Sound and near-slice glimpse: the two cues that support the locator without repeating it
## (items 54 and 55).
##
## ONE NODE FOR BOTH, because they are one feature. Both answer "am I getting warmer
## through W", both read the same alignment number, and splitting them would mean two
## copies of that calculation drifting apart. The locator already computes it, so this
## asks the locator rather than recomputing from the bearing utility a third time.
##
## SOUND IS COARSE ON PURPOSE (item 54). The clucking carries rate and loudness and
## nothing else - no direction, no distance, no which-way-through-W. It tells you that you
## are warmer, and then you read the locator to find out why. A sound that encoded
## direction would replace the visual explanation, which item 54 explicitly says it must
## not do.
##
## THE GLIMPSE IS REAL GEOMETRY, NOT AN EFFECT (item 55). Item 55 allows a partial reveal
## only if it matches the engine's slice presentation and stays visually stable, which
## rules out a faked shimmer - and TetraMaterial4D has no transparency to fade with
## anyway. So the marker is a 4D orthoplex, and the engine does the work: a cross-section
## taken at distance d from the centre of an orthoplex of W half-extent h is the same
## shape scaled by (1 - |d| / h), so the marker GROWS OUT OF NOTHING as the player moves
## into the chicken's slice and vanishes to a point on the way out. It is the same maths
## that makes the chicken itself appear, so it can never disagree with the chicken about
## where the slice boundary is.
##
## NOT A MAP MARKER (item 58). It exists only within a narrow band of W and only within
## sight, so it cannot lead the player anywhere - by the time you can see it, you had
## already found the right slice and the right place. It confirms; it does not guide.

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

@export var locator_path: NodePath
@export var manager_path: NodePath
@export var player_path: NodePath

@export_group("Clucking")
@export var audio_enabled: bool = true
## Seconds between clucks when the player is nowhere near the chicken's slice, and when
## they are on it. Rate is the coarse half of the cue; loudness is the fine half.
@export_range(0.5, 12.0, 0.1) var cluck_interval_far: float = 4.5
@export_range(0.2, 4.0, 0.1) var cluck_interval_near: float = 0.9
## Quiet even at its loudest. This fires continuously while the player hunts, and a cue
## that plays every second has to sit under everything else or it becomes the thing the
## player is trying to get away from.
@export_range(-60.0, 0.0, 1.0) var cluck_db_far: float = -32.0
@export_range(-60.0, 0.0, 1.0) var cluck_db_near: float = -14.0

@export_group("Glimpse")
@export var glimpse_enabled: bool = true
## How far through W the marker reaches. Outside this band its cross-section is empty, so
## this is literally the distance at which the glimpse begins.
@export_range(0.1, 2.0, 0.05) var reveal_band: float = 0.55
## And how far away in ordinary space it can be seen, so it stays a confirmation rather
## than a beacon.
@export_range(2.0, 40.0, 0.5) var reveal_distance: float = 11.0
@export var glimpse_color: Color = Color(1.0, 0.92, 0.45)
@export_range(0.0, 3.0, 0.05) var glimpse_height: float = 1.65

var _locator: Node
var _manager: Node
var _player: Node4D
var _player_node: Node
var _cluck: AudioStreamPlayer
var _since_cluck: float = 0.0
var _markers: Dictionary = {}
var _bob: float = 0.0


func _ready() -> void:
	_locator = get_node_or_null(locator_path)
	_manager = get_node_or_null(manager_path)
	_player = get_node_or_null(player_path) as Node4D
	if _locator == null or _manager == null or _player == null:
		push_warning("ChickenCues: locator, manager or player missing - the supporting cues are off (item 82).")
		return
	if audio_enabled:
		_cluck = AudioStreamPlayer.new()
		_cluck.stream = _make_cluck()
		_cluck.volume_db = cluck_db_far
		add_child(_cluck)


func _process(delta: float) -> void:
	if _locator == null or _player == null:
		return
	var target: Node = _locator.get("target")
	var strength: float = _strength(target)
	if audio_enabled:
		_tick_audio(delta, target, strength)
	if glimpse_enabled:
		_tick_glimpse(delta)


## How close the player is to the target's slice, 0 to 1. Taken from the locator's own
## thresholds so the sound, the marker and the words can never disagree about "warm".
func _strength(target: Node) -> float:
	if target == null:
		return 0.0
	var body: Node4D = target.get_parent() as Node4D
	if body == null:
		return 0.0
	var bearing: Dictionary = BearingUtility4D.compute(_player, body.global_position)
	var wide: float = float(_locator.get("wide_angle"))
	return clampf(1.0 - float(bearing["angle_off_slice"]) / maxf(wide, 0.01), 0.0, 1.0)


func _tick_audio(delta: float, target: Node, strength: float) -> void:
	if _cluck == null:
		return
	if target == null:
		return
	_since_cluck += delta
	var interval: float = lerpf(cluck_interval_far, cluck_interval_near, strength)
	if _since_cluck < interval:
		return
	_since_cluck = 0.0
	_cluck.volume_db = lerpf(cluck_db_far, cluck_db_near, strength)
	# A little pitch scatter, so twelve identical clucks do not read as one machine.
	_cluck.pitch_scale = randf_range(0.88, 1.14)
	_cluck.play()


func _tick_glimpse(delta: float) -> void:
	_bob += delta
	var at: Vector4 = _player.global_position
	for agent in (_manager.get("agents") as Array):
		var body: Node4D = agent.get_parent() as Node4D
		if body == null:
			continue
		var marker: MeshInstance4D = _markers.get(agent) as MeshInstance4D
		if marker == null:
			marker = _make_marker()
			_markers[agent] = marker
		# A returned or carried bird is not something to find.
		var wanted: bool = bool(agent.call("can_be_caught"))
		var here: Vector4 = body.global_position
		if wanted:
			var flat: float = Vector2(here.x - at.x, here.z - at.z).length()
			wanted = flat <= reveal_distance
		marker.visible = wanted
		if not wanted:
			continue
		# Bobbing, so it reads as a cue rather than as part of the chicken. Moving a node
		# is free; resizing the mesh would rebuild it twelve times a frame.
		var lift: float = glimpse_height + sin(_bob * 2.4 + float(agent.get("chicken_id"))) * 0.12
		marker.position = Vector4(here.x, here.y + lift, here.z, here.w)


func _make_marker() -> MeshInstance4D:
	var node := MeshInstance4D.new()
	var mesh := OrthoplexTetraMesh4D.new()
	# Small in space, wide in W: the W half-extent IS the reveal band, because that is the
	# offset at which the cross-section shrinks to a point.
	mesh.half_extents = Vector4(0.17, 0.17, 0.17, reveal_band)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = glimpse_color
	node.material_override = material
	# Parented to the manager, not to the chicken: the chickens are scaled to a quarter,
	# and a marker inherited that scale would shrink its reveal band with it.
	_manager.add_child(node)
	return node


## A cluck, built from numbers rather than shipped as a file.
##
## The falling pitch is what makes it a cluck instead of a beep - a chicken's call drops
## roughly an octave over its short length - and the noise term gives it the breathy edge
## that a pure tone lacks. Generated rather than sourced because there is no chicken audio
## in ramon/sounds/ and this prototype should not depend on one being added.
func _make_cluck() -> AudioStreamWAV:
	var rate: int = 22050
	var seconds: float = 0.13
	var count: int = int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260921
	var phase: float = 0.0
	for i in count:
		var u: float = float(i) / float(count)
		var hz: float = 880.0 * exp(-3.4 * u) + 300.0
		phase += TAU * hz / float(rate)
		var sample: float = sin(phase) * 0.6 + sin(phase * 2.0) * 0.25 \
			+ rng.randf_range(-1.0, 1.0) * 0.12
		# Fast attack, slower decay: the click at the front is most of what identifies it.
		var envelope: float = clampf(u / 0.06, 0.0, 1.0) * exp(-4.2 * u)
		data.encode_s16(i * 2, int(clampf(sample * envelope, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
