extends Node
## Rail mode: the actual "ride" mechanic. Step on StartTrigger (a plain
## InteractionTrigger4D, reused exactly as built for the other modes) to
## begin - translation locks (see player.gd's rail_locked flag, which only
## skips its own WASD/Q-E movement and move_and_slide()), and position
## lerps along a fixed straight-line path over a fixed duration instead.
## Mouse-look and slice-rotation both stay fully live throughout - they
## live entirely in player.gd's _input(), untouched by rail_locked either
## way, so there's nothing extra to preserve here.
##
## The path itself is a straight line, fixed at w=0 the whole ride - the
## "4D navigation, not just aim" test comes entirely from the targets' own
## mixed w positions (see rail_target_spawner.gd), not from the ride's own
## path moving in w. Same principle every other mode in this project
## already uses (W-targeting, Contest mode's w=+-3 pairs): you rotate your
## slice to line up a shot, you don't need to physically move in w to do
## it - a stationary-in-w rider can still hit an off-w target by aiming
## through a slice-rotated forward direction (that direction vector itself
## gains a w-component from the rotation, even though the rider's own
## position.w never changes).
##
## Owns the current ride's score totals directly (rather than leaving that
## to the HUD, per combat_stats_hud.gd's usual "dumb readout" split) since
## starting/resetting a ride and zeroing its totals are the same event -
## splitting them across two scripts would just be two copies of "is a ride
## in progress" to keep in sync. The HUD only owns cross-ride session-best
## tracking, a genuinely separate, presentation-only concern.
##
## No scene reload on reset - the same teleport-and-rearm pattern already
## established by this project's other "always ready to go again" modes
## (e.g. gallery_target_spawner.gd's respawn-on-hit). InteractionTrigger4D
## already re-fires on any fresh entry after a genuine exit with no extra
## "rearm" call needed - RESET_POSITION just needs to sit outside the
## trigger's own bounds, which it does (see the trigger's placement in
## bullseye_range.tscn).

signal ride_started
## Emitted after every resolved hit during a ride, running totals so far.
signal score_updated(aim_total: int, slice_total: int)
signal ride_completed(aim_total: int, slice_total: int)
signal ride_reset

const PATH_START := Vector4(0, 1, 3, 0)
const PATH_END := Vector4(0, 1, -12, 0)
const RESET_POSITION := Vector4(0, 1, 6, 0) # Starting area, clear of the trigger's own bounds.
const RIDE_DURATION_SEC := 14.0 # Tune by feel - 5 targets over 15 units, roughly one every 3s.
const RESULTS_DISPLAY_SEC := 4.0 # How long the completed run's totals stay up before auto-reset.

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var start_trigger: Area4D = $"../FlatPlane/StartTrigger"
@onready var target_spawner: Node4D = $"../FlatPlane/RailTargetSpawner"
@onready var weapon: Node = $"../BullseyeWeapon"

var _riding: bool = false
var _elapsed_sec: float = 0.0
var _results_timer_sec: float = -1.0
var _run_aim_total: int = 0
var _run_slice_total: int = 0


func _ready() -> void:
	start_trigger.triggered.connect(_on_start_trigger)
	weapon.shot_resolved.connect(_on_shot_resolved)


func _on_start_trigger(_body: PhysicsBody4D) -> void:
	if _riding:
		return
	_riding = true
	_elapsed_sec = 0.0
	_run_aim_total = 0
	_run_slice_total = 0
	player.rail_locked = true
	# Snap onto the path's exact start rather than wherever the player
	# happened to be standing when they crossed the trigger - keeps the ride
	# itself simple and repeatable regardless of exact walk-in position.
	player.global_position = PATH_START
	ride_started.emit()


func _on_shot_resolved(hit: bool, ring_score: int, slice_score_percent: int) -> void:
	if not _riding or not hit:
		return
	_run_aim_total += ring_score
	_run_slice_total += slice_score_percent
	score_updated.emit(_run_aim_total, _run_slice_total)


func _physics_process(delta: float) -> void:
	if _riding:
		_elapsed_sec += delta
		var t: float = clampf(_elapsed_sec / RIDE_DURATION_SEC, 0.0, 1.0)
		player.global_position = PATH_START.lerp(PATH_END, t)
		if t >= 1.0:
			_complete_ride()
		return

	if _results_timer_sec >= 0.0:
		_results_timer_sec -= delta
		if _results_timer_sec <= 0.0:
			_results_timer_sec = -1.0
			_reset_course()


func _complete_ride() -> void:
	_riding = false
	_results_timer_sec = RESULTS_DISPLAY_SEC
	ride_completed.emit(_run_aim_total, _run_slice_total)


func _reset_course() -> void:
	player.global_position = RESET_POSITION
	player.rail_locked = false
	target_spawner.reset_all()
	ride_reset.emit()
