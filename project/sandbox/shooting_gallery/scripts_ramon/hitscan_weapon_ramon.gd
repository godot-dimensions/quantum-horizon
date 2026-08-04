extends Node
## Ramon-only fork of hitscan_weapon.gd - replaces the original's one-shot-
## per-click fire with a hold-to-charge burst: hold "fire" to charge over
## CHARGE_MAX_SEC seconds, release to unleash a burst of 1-MAX_BURST_SHOTS
## shots scaled to how charged you were. Overshoot past full charge without
## releasing and the charge "expires" - releasing after that point fires
## nothing at all, the same commit-to-a-release-window risk/reward most
## charge-shot mechanics use, rather than just rewarding holding forever.
##
## _charge_fraction and _is_expired are read directly every frame by
## charge_bar_ramon.gd - same "read a sibling's own live state" convention
## slice_radar.gd already uses for the spawners it displays, not a formal
## getter API.
##
## Audio: charge_buildup_ramon.wav is pitch-shifted live (via AudioStream
## Player.pitch_scale) from low to high as charge builds. It's re-triggered
## with .play() whenever it isn't already playing, rather than relying on
## AudioStreamWAV.loop_mode - looping that way also needs loop_end set to
## the stream's actual sample count, or the loop region defaults to [0, 0]
## and it effectively loops over nothing; re-triggering on ended sidesteps
## that entirely and just restarts the ~1s clip as needed (slightly
## audible restarts rather than a perfectly seamless loop, but guaranteed
## to actually keep sounding). A distinct charge_release_ramon.wav plays
## once on release (pitched down slightly for a bigger-feeling release the
## more charged the shot was, muted/lower for the expired "fizzle" case).
##
## Also spawns a visible ray_beam_ramon.gd (thicker/brighter the more
## charged the release was) and a poof_effect_ramon.gd burst per hit, and
## brightens gun_core_rotator_ramon.gd's core color while charging (on top
## of its existing fire-pulse glow).

const PoofEffect := preload("res://sandbox/shooting_gallery/scripts_ramon/poof_effect_ramon.gd")
const RayBeam := preload("res://sandbox/shooting_gallery/scripts_ramon/ray_beam_ramon.gd")
const ChargeBuildupSound := preload("res://sandbox/shooting_gallery/audio/charge_buildup_ramon.wav")
const ChargeReleaseSound := preload("res://sandbox/shooting_gallery/audio/charge_release_ramon.wav")

const CHARGE_MAX_SEC := 3.0
const MAX_BURST_SHOTS := 6
const BURST_SHOT_INTERVAL_SEC := 0.12
const MAX_RAY_DISTANCE := 40.0 # Only used for the beam's visual endpoint on a miss - the raycast itself has no fixed range.

const CHARGE_PITCH_LOW := 0.7
const CHARGE_PITCH_HIGH := 2.0
const CHARGE_VOLUME_DB := 4.0
const RELEASE_PITCH_FULL := 0.8 # Lower pitch at full charge - reads as "bigger."
const RELEASE_PITCH_TAP := 1.3
const EXPIRED_RELEASE_PITCH := 0.5
const EXPIRED_RELEASE_VOLUME_DB := -10.0
## A quick tap's charge-buildup sound already covers the "you fired" cue -
## the release "laser" sound is reserved for an actually-charged shot, not
## every single click.
const MIN_FRACTION_FOR_RELEASE_SOUND := 0.15

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var player_head: Node4D = $"../FlatPlane/Player/PlayerHead"
@onready var flat_plane: Node4D = $"../FlatPlane"
@onready var spawner: Node4D = $"../FlatPlane/GalleryTargetSpawner"
@onready var duck_spawner: Node4D = $"../FlatPlane/DuckRowSpawner"
@onready var blocker_spawner: Node4D = $"../FlatPlane/ShapeBlockerSpawner"
@onready var stalker_spawner: Node4D = $"../FlatPlane/BlackStalkerSpawner"
@onready var green_sphere_spawner: Node4D = $"../FlatPlane/GreenSphereSpawner"
@onready var gun_core: Node4D = $"../FlatPlane/Player/PlayerHead/FirstPersonCamera/GunViewmodel/Core"

var _charge_fraction: float = 0.0
var _is_expired: bool = false
var _is_charging: bool = false
var _charge_time_sec: float = 0.0
var _burst_in_progress: bool = false

var _charge_sound_player: AudioStreamPlayer
var _release_sound_player: AudioStreamPlayer


func _ready() -> void:
	_charge_sound_player = AudioStreamPlayer.new()
	_charge_sound_player.stream = ChargeBuildupSound
	_charge_sound_player.volume_db = CHARGE_VOLUME_DB
	add_child(_charge_sound_player)

	_release_sound_player = AudioStreamPlayer.new()
	_release_sound_player.stream = ChargeReleaseSound
	add_child(_release_sound_player)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_start_charge()
	elif event.is_action_released(&"fire"):
		_release_charge()


func _process(delta: float) -> void:
	if _is_charging:
		_charge_time_sec += delta
		if _charge_time_sec >= CHARGE_MAX_SEC:
			_charge_time_sec = CHARGE_MAX_SEC
			_is_expired = true
		_charge_fraction = _charge_time_sec / CHARGE_MAX_SEC
		_charge_sound_player.pitch_scale = lerpf(CHARGE_PITCH_LOW, CHARGE_PITCH_HIGH, _charge_fraction)
		if not _charge_sound_player.playing:
			_charge_sound_player.play()
	gun_core.charge_glow = _charge_fraction if (_is_charging and not _is_expired) else 0.0


func _start_charge() -> void:
	if _is_charging or _burst_in_progress:
		return
	_is_charging = true
	_charge_time_sec = 0.0
	_charge_fraction = 0.0
	_is_expired = false
	_charge_sound_player.pitch_scale = CHARGE_PITCH_LOW
	_charge_sound_player.play()


func _release_charge() -> void:
	if not _is_charging:
		return
	_is_charging = false
	_charge_sound_player.stop()
	var fraction: float = _charge_fraction
	var expired: bool = _is_expired
	_charge_fraction = 0.0
	_is_expired = false
	gun_core.charge_glow = 0.0

	if expired:
		_release_sound_player.pitch_scale = EXPIRED_RELEASE_PITCH
		_release_sound_player.volume_db = EXPIRED_RELEASE_VOLUME_DB
		_release_sound_player.play()
		return # Overcharged and not released in time - the shot is wasted.

	if fraction >= MIN_FRACTION_FOR_RELEASE_SOUND:
		_release_sound_player.pitch_scale = lerpf(RELEASE_PITCH_TAP, RELEASE_PITCH_FULL, fraction)
		_release_sound_player.volume_db = 0.0
		_release_sound_player.play()

	var shots: int = clampi(roundi(MAX_BURST_SHOTS * fraction), 1, MAX_BURST_SHOTS)
	_fire_burst(shots, fraction)


func _fire_burst(shots: int, intensity: float) -> void:
	_burst_in_progress = true
	for i in shots:
		_fire_single_shot(intensity)
		if i < shots - 1:
			await get_tree().create_timer(BURST_SHOT_INTERVAL_SEC).timeout
	_burst_in_progress = false


func _fire_single_shot(intensity: float) -> void:
	gun_core.pulse()
	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = player_head.global_position
	ray_params.global_ray_direction = -player_head.global_basis.z
	# Targets/blockers are Area4D (non-solid, detection-only) - raycasts don't
	# collide with areas by default, so this must be opted into explicitly.
	ray_params.collide_with_areas = true
	ray_params.set_exclude_nodes([player])
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)

	var beam_end: Vector4 = player_head.global_position - player_head.global_basis.z * MAX_RAY_DISTANCE
	if result.get("hit", false):
		beam_end = result.get("global_point", beam_end)
	_spawn_beam(player_head.global_position, beam_end, player_head.global_basis, intensity)

	if not result.get("hit", false):
		return
	var hit_body: Object = result["body"]
	var caught: bool = spawner.try_catch_target(hit_body)
	if not caught:
		caught = duck_spawner.try_hit_duck(hit_body)
	if not caught:
		caught = blocker_spawner.try_hit_blocker(hit_body)
	if not caught:
		caught = stalker_spawner.try_hit_stalker(hit_body)
	if not caught:
		caught = green_sphere_spawner.try_hit_sphere(hit_body)
	if caught:
		_spawn_poof(result.get("global_point", hit_body.global_position))


func _spawn_beam(from: Vector4, to: Vector4, orientation: Projection, intensity: float) -> void:
	var beam := Node4D.new()
	beam.set_script(RayBeam)
	flat_plane.add_child(beam)
	beam.setup(from, to, orientation, intensity)


func _spawn_poof(at_position: Vector4) -> void:
	var poof := Node4D.new()
	poof.set_script(PoofEffect)
	spawner.add_child(poof)
	poof.global_position = at_position
