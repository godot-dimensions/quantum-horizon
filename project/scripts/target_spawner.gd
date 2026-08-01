extends Node4D
## Milestone 4 (simplified): spawn-spot-step loop, using a plain distance
## check + keypress instead of Area4D/InteractionTrigger4D. That approach is
## parked, not abandoned - interaction_trigger_4d.gd is untouched and worth
## reverting to (true step-on, no keypress) once Aaron's fix for the
## body_entered_self non-firing issue lands. This is a stand-in, not a final
## design call.
##
## One target at a time, random position with a wide W spread (not
## clustered near w=0 - forces genuine w-axis movement via move_kata/
## move_ana, Q/E). Press F within reach to catch it: despawns the current
## target, spawns a fresh one, prints elapsed time + running average.
## T toggles a live on-screen stopwatch label (off by default, for an
## unobtrusive default and a "watching the clock" vs. "just playing"
## comparison) - the last-result summary stays visible regardless of that
## toggle, so results aren't lost just because the ticking display is hidden.

const TargetScene := preload("res://target.tscn")

## Ground (sandbox/flat_plane.tscn) is a 50x1x50x50 BoxShape4D centered at
## the origin - half-extent 25 in x/z/w (5x the original 10x1x10x10). Keeping
## spawns within +-20 preserves the original ~20% safety margin to the edge
## while being "wide" relative to the default visible slice (effectively
## just w=0).
const XZ_RANGE := 20.0
const W_RANGE := 20.0
## Ground top is at y=0 (Ground position.y=-0.5, half-extent 0.5). A 1-unit
## target box centered at y=0.5 sits with its bottom flush on the ground.
const SPAWN_Y := 0.5
## Plain Euclidean reach radius, standing in for the old trigger's generous
## box half-extent (0.75/axis) - a sphere this size is at least as forgiving
## for a "step near it" feel, without requiring a per-axis box overlap.
const REACH_RADIUS := 1.5

## The target box (target.tscn) is a 1-unit BoxTetraMesh4D, so its w-extent
## is target.w +- 0.5. "Middle half, at least a quarter in from any edge"
## excludes the outer 0.25 on each end, leaving target.w +- 0.25.
const MIDDLE_HALF_W_MARGIN := 0.25
const CUBE_DEFAULT_COLOR := Color(1, 0.6, 0.1, 1) # matches target.tscn's own albedo_color.
const CUBE_SLICE_HIGHLIGHT_COLOR := Color(0.2, 0.9, 0.2, 1)

@onready var player: CharacterBody4D = $"../Player"
@onready var time_label: Label = $TimeLabel
@onready var result_label: Label = $ResultLabel

var _catch_count: int = 0
var _total_elapsed_sec: float = 0.0
var _spawn_time_msec: int = 0
var _current_target: Node4D = null
var _current_target_material: Resource = null
var _stopwatch_visible: bool = false

func _ready() -> void:
	time_label.visible = false
	result_label.visible = false
	_spawn_new_target()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("catch_target"):
		_try_catch()
	elif event.is_action_pressed("toggle_stopwatch_display"):
		_stopwatch_visible = not _stopwatch_visible
		time_label.visible = _stopwatch_visible

func _process(_delta: float) -> void:
	if _stopwatch_visible and _current_target != null:
		var elapsed: float = (Time.get_ticks_msec() - _spawn_time_msec) / 1000.0
		var average: float = (_total_elapsed_sec / _catch_count) if _catch_count > 0 else 0.0
		time_label.text = "Elapsed: %.1fs | Avg: %.1fs (%d catches)" % [elapsed, average, _catch_count]
	if _current_target != null:
		# Cross-section rendering slices at the camera's local w=0, and the
		# camera carries no w-offset from Player (PlayerHead/FirstPersonCamera
		# are both w=0 in local space) - so the player's own global w IS the
		# world-space w of the currently-visible slice.
		var slice_w: float = player.global_position.w
		var w_offset: float = absf(slice_w - _current_target.global_position.w)
		_current_target_material.albedo_color = (
			CUBE_SLICE_HIGHLIGHT_COLOR if w_offset <= MIDDLE_HALF_W_MARGIN else CUBE_DEFAULT_COLOR
		)

func _try_catch() -> void:
	if _current_target == null:
		return
	var distance: float = player.global_position.distance_to(_current_target.global_position)
	if distance <= REACH_RADIUS:
		_on_catch()

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
	# The material is a shared scene sub-resource - duplicate it so recoloring
	# this target doesn't bleed into every other Target instance.
	var mesh: MeshInstance4D = target.get_node("Mesh")
	_current_target_material = mesh.material_override.duplicate()
	mesh.material_override = _current_target_material

func _random_spawn_position() -> Vector4:
	return Vector4(
		randf_range(-XZ_RANGE, XZ_RANGE),
		SPAWN_Y,
		randf_range(-XZ_RANGE, XZ_RANGE),
		randf_range(-W_RANGE, W_RANGE),
	)
