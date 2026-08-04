extends Node4D
## Ramon-only "creepy stalker" experiment: a lone black slab, shaped like
## the 2001: A Space Odyssey monolith (a tall, narrow, thin rectangular
## slab - not an exact 1:4:9 replica, just close enough to read as "that
## thing"), that spawns rarely and far away (well behind the blue floor,
## further back than any other activity in this scene) on a w-slice with a
## guaranteed minimum offset from the player's default w=0 (see
## MIN_SPAWN_W_OFFSET) - so it's never already sitting in your starting
## slice at spawn, and slice-rotating to go looking for it is meaningful
## rather than a coin flip.
##
## Its speed ramps up the longer it's been actively chasing (from SPEED_MIN
## up to SPEED_MAX over CHASE_RAMP_SEC), rather than staying fixed - outright
## running from it in a straight line at a constant speed would let the
## player evade it forever, which isn't the intent ("in any case it will
## touch you... when you dont shoot it"). SPEED_MAX is set above the
## player's own sprint speed (see player.gd's SPEED * SPRINT_MULTIPLIER), so
## given enough uninterrupted time it always eventually catches up in x/z.
##
## It ALSO slowly drifts its own w toward the player's current w (at
## W_DRIFT_FRACTION of the main speed) - changing slice is still a real,
## strong escape early on since this drift starts very slow, but it isn't
## a permanent hiding spot either. This also fixes a real bug: without any
## w tracking at all, the stalker would close the x/z distance to under the
## 0.05m stop threshold and then just sit there forever if it happened to
## be on a different w than the player, since nothing was left to move it -
## reported as "stuck on the black floor." Slowly drifting w means it always
## keeps moving until it's genuinely caught up in every axis.
##
## Uses Area4D.move_area() rather than a plain position assignment, unlike
## every other moving thing in this scene (ducks, targets, blockers) -
## Area4D's own docs warn that bypassing the physics system this way means
## body_entered_self never fires, and this script's entire "hits you"
## detection depends on that signal actually firing. The others get away
## with a plain position set because they only ever need to be found by
## hitscan_weapon_ramon.gd's raycast query, which doesn't care how a body's
## transform was last set.
##
## Humming while it approaches: a single looping AudioStreamPlayer whose
## volume_db is manually recomputed from player distance every frame - not
## real positional 3D audio. The cross-section renderer builds its own
## internal RenderingServer instances directly rather than real Node3D
## scene-tree members (confirmed while building the earlier ray beam/poof
## effects), so there's no clean hook for AudioStreamPlayer3D to piggyback
## on; faking distance-based volume by hand gets the same "creepier as it
## gets closer" effect without needing that integration.

const HIT_POINTS := 8

const SPAWN_Z := -28.0 # "Further in the back" - pushed further than before so it's clearly visible approaching from a distance.
const SPAWN_X_RANGE := 8.0
const SPAWN_W_RANGE := 5.0
const MIN_SPAWN_W_OFFSET := 2.5 # Guarantees it never spawns already inside the player's starting w=0 slice.
const SPAWN_Y := 2.0 # Raised vs. the old cube's spawn height - a slab this tall would clip into the floor at y=1.
const SPEED_MIN := 0.6 # Meters per second - "slowly," at first.
const SPEED_MAX := 13.0 # Above the player's sprint speed (5.0 * 2.5) - see class comment.
const CHASE_RAMP_SEC := 35.0
const W_DRIFT_FRACTION := 0.15 # Fraction of the current x/z speed used for w drift - see class comment.
const MIN_SPAWN_DELAY_SEC := 5.0
const MAX_SPAWN_DELAY_SEC := 12.0
## Slow "breathing" scale pulse - purely cosmetic unease, no gameplay effect.
const BREATH_SPEED := 1.3
const BREATH_AMOUNT := 0.04

## Monolith proportions - tall and narrow, thin in depth/ana-kata, not a cube.
const SLAB_SIZE := Vector4(1.0, 4.0, 0.3, 0.3)
const SLAB_SCALE := 1.1

const HUM_MAX_DISTANCE := 20.0
const HUM_MIN_VOLUME_DB := -40.0
const HUM_MAX_VOLUME_DB := 4.0

const HumSound := preload("res://sandbox/shooting_gallery/audio/hum_ramon.wav")

@onready var player: CharacterBody4D = $"../Player"
@onready var game_over_overlay: Control = $"../../GameOverOverlay"

var _stalker: Area4D = null
var _stalker_mesh: MeshInstance4D = null
var _hp: int = HIT_POINTS
var _spawn_timer_sec: float = 0.0
var _elapsed_sec: float = 0.0
var _chase_time_sec: float = 0.0
var _hum_player: AudioStreamPlayer


func _ready() -> void:
	_spawn_timer_sec = randf_range(MIN_SPAWN_DELAY_SEC, MAX_SPAWN_DELAY_SEC)
	_hum_player = AudioStreamPlayer.new()
	_hum_player.stream = HumSound
	if _hum_player.stream is AudioStreamWAV:
		_hum_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_hum_player.volume_db = HUM_MIN_VOLUME_DB
	add_child(_hum_player)


func _process(delta: float) -> void:
	_elapsed_sec += delta
	if _stalker == null:
		_spawn_timer_sec -= delta
		if _spawn_timer_sec <= 0.0:
			_spawn_stalker()
		return

	var breath: float = SLAB_SCALE * (1.0 + sin(_elapsed_sec * BREATH_SPEED) * BREATH_AMOUNT)
	_stalker_mesh.basis = Projection(
		Vector4(breath, 0, 0, 0),
		Vector4(0, breath, 0, 0),
		Vector4(0, 0, breath, 0),
		Vector4(0, 0, 0, breath),
	)

	_chase_time_sec += delta
	var speed: float = lerpf(SPEED_MIN, SPEED_MAX, clampf(_chase_time_sec / CHASE_RAMP_SEC, 0.0, 1.0))

	var to_player: Vector4 = player.global_position - _stalker.global_position
	var motion := Vector4.ZERO
	var flat_dir := Vector2(to_player.x, to_player.z)
	if flat_dir.length() > 0.05:
		flat_dir = flat_dir.normalized()
		motion.x = flat_dir.x * speed
		motion.z = flat_dir.y * speed
	if absf(to_player.w) > 0.05:
		motion.w = signf(to_player.w) * speed * W_DRIFT_FRACTION
	if motion != Vector4.ZERO:
		_stalker.move_area(motion * delta)

	var distance: float = to_player.length()
	var proximity: float = clampf(1.0 - distance / HUM_MAX_DISTANCE, 0.0, 1.0)
	_hum_player.volume_db = lerpf(HUM_MIN_VOLUME_DB, HUM_MAX_VOLUME_DB, proximity)


## Called by hitscan_weapon_ramon.gd. Returns whether the hit body was the
## active stalker; despawns it (scheduling the next sporadic appearance) once
## HIT_POINTS is reached.
func try_hit_stalker(hit_body: Object) -> bool:
	if _stalker == null or hit_body != _stalker:
		return false
	_hp -= 1
	if _hp <= 0:
		_despawn_stalker()
	return true


func _spawn_stalker() -> void:
	_hp = HIT_POINTS
	_chase_time_sec = 0.0
	_stalker = Area4D.new()
	add_child(_stalker)
	_stalker.position = Vector4(
		randf_range(-SPAWN_X_RANGE, SPAWN_X_RANGE),
		SPAWN_Y,
		SPAWN_Z,
		_random_offset_w(),
	)

	var collision_shape := CollisionShape4D.new()
	var box_shape := BoxShape4D.new()
	box_shape.size = SLAB_SIZE * SLAB_SCALE
	collision_shape.shape = box_shape
	_stalker.add_child(collision_shape)

	_stalker_mesh = MeshInstance4D.new()
	var box_mesh := BoxTetraMesh4D.new()
	box_mesh.size = SLAB_SIZE
	_stalker_mesh.mesh = box_mesh
	var material := TetraMaterial4D.new()
	# Deliberately not pure/near-zero black: the cross-section void background
	# reads as very dark too, and at albedo ~0.02 the monolith was blending
	# into it almost completely except where its per-face shading gradient
	# happened to catch some light - effectively invisible most of the time.
	# Nudged another +0.03 per channel on top of that same fix - still dark
	# enough to read as "black", just distinguishable.
	material.albedo_color = Color(0.14, 0.14, 0.15, 1.0)
	_stalker_mesh.material_override = material
	_stalker.add_child(_stalker_mesh)

	_stalker.body_entered_self.connect(_on_stalker_body_entered)

	_hum_player.volume_db = HUM_MIN_VOLUME_DB
	_hum_player.play()


## A w with a guaranteed minimum distance from 0 (the player's default,
## unrotated slice) - never all the way out at SPAWN_W_RANGE necessarily,
## but never near-zero either.
func _random_offset_w() -> float:
	var magnitude: float = randf_range(MIN_SPAWN_W_OFFSET, SPAWN_W_RANGE)
	return magnitude if randf() < 0.5 else -magnitude


func _on_stalker_body_entered(body: PhysicsBody4D) -> void:
	if body != player:
		return
	game_over_overlay.trigger()
	_despawn_stalker()


func _despawn_stalker() -> void:
	if _stalker == null:
		return
	_stalker.queue_free()
	_stalker = null
	_stalker_mesh = null
	_hum_player.stop()
	_spawn_timer_sec = randf_range(MIN_SPAWN_DELAY_SEC, MAX_SPAWN_DELAY_SEC)
