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
## The repeating cluck, SEPARATE from the one-shot sounds and off by default.
##
## Item 54 asked for faint clucking that strengthens as you align, and it does work as a
## cue - but it fires every few seconds for the whole session, and in practice that reads
## as a loop you want to get away from rather than as guidance. The return chirp and the
## completion chorus are unaffected: those fire once each, when something actually
## happened, which is the difference between feedback and background.
@export var clucking_enabled: bool = false
## Seconds between clucks when the player is nowhere near the chicken's slice, and when
## they are on it. Rate is the coarse half of the cue; loudness is the fine half.
@export_range(0.5, 12.0, 0.1) var cluck_interval_far: float = 4.5
@export_range(0.2, 4.0, 0.1) var cluck_interval_near: float = 0.9
## Quiet even at its loudest. This fires continuously while the player hunts, and a cue
## that plays every second has to sit under everything else or it becomes the thing the
## player is trying to get away from.
@export_range(-60.0, 0.0, 1.0) var cluck_db_far: float = -36.0
@export_range(-60.0, 0.0, 1.0) var cluck_db_near: float = -22.0

## RE-LEVELLED AGAINST THE RECORDINGS, and they were measured rather than judged: these
## three streams are synthesised here and peak at -4.3, -5.4 and -8.0 dBFS, which is
## hotter than most of the library files beside them. They were tuned when this scene had
## no other sound in it, and by the time it did, the return chirp was the second loudest
## thing in the game - louder than a pickaxe hitting rock. The numbers below put them on
## the same table as pen_sfx_4d.gd: a confirmation lands at about -22 dBFS effective and
## the completion chorus at -20.
## Louder than the clucking, because it fires twelve times in a session rather than
## continuously, and because it is the one sound that confirms an action succeeded.
@export_range(-40.0, 0.0, 1.0) var confirm_db: float = -17.0
@export_range(-40.0, 0.0, 1.0) var chorus_db: float = -12.0

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
## Chickens closer than this through W are already in plain sight, so they get no marker.
##
## Without it the markers hovered over birds standing in front of the player, which is
## clutter at best and a map marker at worst - the thing item 58 is against. Tied to the
## slice you are on rather than to a distance, it also gives the arrival its own signal:
## the marker vanishes at the moment the chicken itself appears.
@export_range(0.0, 0.5, 0.01) var present_band: float = 0.12

var _locator: Node
var _manager: Node
var _player: Node4D
var _player_node: Node
var _cluck: AudioStreamPlayer
var _confirm: AudioStreamPlayer
var _chorus: AudioStreamPlayer
var _since_cluck: float = 0.0
var _silenced: bool = false
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
		_cluck.name = "Cluck"
		_cluck.bus = &"SFX"
		_cluck.stream = _make_cluck()
		_cluck.volume_db = cluck_db_far
		add_child(_cluck)
		_confirm = AudioStreamPlayer.new()
		_confirm.name = "Confirm"
		_confirm.bus = &"SFX"
		_confirm.stream = _make_confirm()
		_confirm.volume_db = confirm_db
		add_child(_confirm)
		_chorus = AudioStreamPlayer.new()
		_chorus.name = "Chorus"
		_chorus.bus = &"SFX"
		_chorus.stream = _make_chorus()
		_chorus.volume_db = chorus_db
		add_child(_chorus)


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
	# Through the locator's own frame, so the clucking and the words agree about what
	# "aligned" means even while the player is rotating their slice.
	var bearing: Dictionary = BearingUtility4D.compute_raw(
		_player.global_position, _locator.call("_slice_basis"), body.global_position)
	var wide: float = float(_locator.get("wide_angle"))
	# Absolute, for the same reason the locator takes the absolute: the angle is signed.
	return clampf(1.0 - absf(float(bearing["angle_off_slice"])) / maxf(wide, 0.01), 0.0, 1.0)


func _tick_audio(delta: float, target: Node, strength: float) -> void:
	if _cluck == null or not clucking_enabled or _silenced:
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
			var through_w: float = absf(here.w - at.w)
			wanted = flat <= reveal_distance and through_w > present_band
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


## The hunt is over: stop guiding (item 72).
##
## The markers are hidden explicitly rather than left to the next tick, because switching
## the glimpse off also stops the tick that would have hidden them - they would have
## frozen mid-bob wherever they were.
func quiet() -> void:
	# A flag rather than clearing the exports, so switching the guidance off at the end of
	# a run cannot quietly turn the clucking back ON when the next run resumes it.
	_silenced = true
	glimpse_enabled = false
	for marker in _markers.values():
		(marker as MeshInstance4D).visible = false


## And back on, for a restart (item 73).
func resume() -> void:
	_silenced = false
	glimpse_enabled = true
	_since_cluck = 0.0


## Item 70: a chicken is home. Played the instant the count changes, not on a timer.
func confirm() -> void:
	if _confirm != null:
		_confirm.play()


## Item 72: all twelve are in. A short collective answer from the flock rather than a
## fanfare - the brief asks for a small response, and the pen answering in its own voice
## is a better fit than a reward jingle.
func celebrate() -> void:
	if _chorus != null:
		_chorus.play()


## A cluck, built from numbers rather than shipped as a file.
##
## The falling pitch is what makes it a cluck instead of a beep - a chicken's call drops
## roughly an octave over its short length - and the noise term gives it the breathy edge
## that a pure tone lacks. Generated rather than sourced because there is no chicken audio
## in ramon/sounds/ and this prototype should not depend on one being added.

func _make_cluck() -> AudioStreamWAV:
	return _render(0.13, func(u: float, rng: RandomNumberGenerator, phase: float) -> Array:
		var hz: float = 880.0 * exp(-3.4 * u) + 300.0
		var next: float = phase + TAU * hz / float(RATE)
		var sample: float = sin(next) * 0.6 + sin(next * 2.0) * 0.25 			+ rng.randf_range(-1.0, 1.0) * 0.12
		# Fast attack, slower decay: the click at the front is what identifies it.
		return [sample * clampf(u / 0.06, 0.0, 1.0) * exp(-4.2 * u), next])


## Item 70: a rising two-note chirp.
##
## It goes UP where the cluck goes down, and that contrast is the whole reason it reads as
## "that worked" in a field full of falling clucks. Pitch direction carries the meaning;
## nothing else has to.
func _make_confirm() -> AudioStreamWAV:
	return _render(0.26, func(u: float, _rng: RandomNumberGenerator, phase: float) -> Array:
		var hz: float = 520.0 if u < 0.42 else 780.0
		var next: float = phase + TAU * hz / float(RATE)
		var sample: float = sin(next) * 0.7 + sin(next * 3.0) * 0.12
		# Re-struck at the note change, so it is two notes rather than one bent one.
		var step: float = u if u < 0.42 else u - 0.42
		return [sample * clampf(step / 0.01, 0.0, 1.0) * exp(-9.0 * step), next])


## Item 72: the flock answering at once.
##
## Eight clucks at scattered pitches and start times, summed into ONE stream rather than
## played on eight players - one sound has one level, and a chorus assembled at playback
## would have to be mixed every time it fired.
func _make_chorus() -> AudioStreamWAV:
	return _render(1.1, func(u: float, rng: RandomNumberGenerator, phase: float) -> Array:
		var total: float = 0.0
		for bird in 8:
			var start: float = float(bird) * 0.085 + sin(float(bird) * 2.7) * 0.02
			var step: float = u * 1.1 - start
			if step < 0.0 or step > 0.2:
				continue
			var hz: float = (760.0 + float(bird) * 55.0) * exp(-3.4 * step / 0.13) + 300.0
			total += sin(TAU * hz * step) * exp(-4.2 * step / 0.13) * 0.34
		return [total + rng.randf_range(-1.0, 1.0) * 0.03 * exp(-2.0 * u), phase])


const RATE: int = 22050


## Shared renderer. The three sounds differ only in how one sample is computed, so the
## buffer arithmetic lives here instead of three times over. The voice is handed the
## running oscillator phase and returns the next one, because a cluck sweeps its pitch and
## a phase recomputed from scratch each sample would click.
func _render(seconds: float, voice: Callable) -> AudioStreamWAV:
	var count: int = int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260921
	var phase: float = 0.0
	for i in count:
		var result: Array = voice.call(float(i) / float(count), rng, phase)
		phase = float(result[1])
		data.encode_s16(i * 2, int(clampf(float(result[0]), -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
