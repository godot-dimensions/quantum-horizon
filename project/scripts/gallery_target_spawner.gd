extends Node4D
## Shooting gallery experiment: same spawn-spot-step loop as target_spawner.gd,
## but the catch trigger is now an external hitscan raycast (hitscan_weapon.gd)
## instead of an F-key/proximity check - that mechanic is fully superseded
## here, not kept alongside. Position randomization otherwise follows the
## same pattern (wide W spread so slice-rotation is still required to spot
## most targets), just constrained to the orange floor's footprint and offset
## upward so targets hover instead of resting on the ground.

const TargetScene := preload("res://sandbox/shooting_gallery/gallery_target.tscn")

## Orange floor is a 10x1x10x10 BoxShape4D centered at the origin (half-extent
## 5 in x/z/w). Keeping spawns within +-4 on all three axes - x, z, AND w -
## preserves the same ~20% edge margin ratio target_spawner.gd used (20/25
## there, 4/5 here), and keeps every spawn genuinely "above the orange floor"
## rather than the original wide-W-range spotting/tracking design (that's a
## different exercise from a shooting gallery, where targets should be
## visible and reachable without extensive slice-rotation spelunking).
const XZ_RANGE := 4.0
const W_RANGE := 4.0
## Orange floor top is at y=0 (Ground position.y=-0.5, half-extent 0.5).
## Targets hover 1-2 units above that, chosen at random per spawn.
const HOVER_Y_MIN := 1.0
const HOVER_Y_MAX := 2.0

@onready var time_label: Label = $TimeLabel
@onready var result_label: Label = $ResultLabel

var _catch_count: int = 0
var _total_elapsed_sec: float = 0.0
var _spawn_time_msec: int = 0
var _current_target: Node4D = null
var _stopwatch_visible: bool = false

func _ready() -> void:
	# Free mode only - contest mode runs its own fixed sequence
	# (ContestSequencePlayer) instead of this random single-target loop.
	# _current_target staying null is already handled everywhere it's read
	# (try_catch_target, slice_radar.gd, w_targeting.gd).
	if GameMode.selected_mode == GameMode.Mode.CONTEST:
		set_process(false)
		time_label.visible = false
		result_label.visible = false
		return
	time_label.visible = false
	result_label.visible = false
	_spawn_new_target()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stopwatch_display"):
		_stopwatch_visible = not _stopwatch_visible
		time_label.visible = _stopwatch_visible

func _process(_delta: float) -> void:
	if _stopwatch_visible and _current_target != null:
		var elapsed: float = (Time.get_ticks_msec() - _spawn_time_msec) / 1000.0
		var average: float = (_total_elapsed_sec / _catch_count) if _catch_count > 0 else 0.0
		time_label.text = "Elapsed: %.1fs | Avg: %.1fs (%d catches)" % [elapsed, average, _catch_count]

## Called by hitscan_weapon.gd with the raycast hit's "body" result. Returns
## whether it was actually the current target (so the caller can tell a hit
## from a miss), and performs the despawn+respawn/timer bookkeeping if so.
func try_catch_target(hit_body: Object) -> bool:
	if _current_target == null or hit_body != _current_target:
		return false
	_on_catch()
	return true

func _on_catch() -> void:
	var elapsed: float = (Time.get_ticks_msec() - _spawn_time_msec) / 1000.0
	_catch_count += 1
	_total_elapsed_sec += elapsed
	var average: float = _total_elapsed_sec / _catch_count
	print("Catch #%d: %.2fs (running average: %.2fs)" % [_catch_count, elapsed, average])
	# Always-visible last-result summary, independent of the T toggle above -
	# stays on screen even with the live ticking display hidden.
	result_label.text = "Last catch: %.2fs | Avg: %.2fs (%d catches)" % [elapsed, average, _catch_count]
	result_label.visible = true
	_current_target.queue_free()
	_spawn_new_target()

func _spawn_new_target() -> void:
	var target: Node4D = TargetScene.instantiate()
	add_child(target)
	target.position = _random_spawn_position()
	_current_target = target
	_spawn_time_msec = Time.get_ticks_msec()

func _random_spawn_position() -> Vector4:
	return Vector4(
		randf_range(-XZ_RANGE, XZ_RANGE),
		randf_range(HOVER_Y_MIN, HOVER_Y_MAX),
		randf_range(-XZ_RANGE, XZ_RANGE),
		randf_range(-W_RANGE, W_RANGE),
	)
