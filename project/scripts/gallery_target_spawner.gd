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
## 5 in x/z/w). Keeping spawns within +-4 preserves the same ~20% edge margin
## ratio target_spawner.gd used (20/25 there, 4/5 here).
const XZ_RANGE := 4.0
## W range intentionally NOT constrained to the orange floor's own w-extent -
## targets hover in space rather than resting on it, so there's nothing
## requiring them to sit within the floor's physical w bounds. Keeping this
## wide (unchanged from target_spawner.gd) is the whole point: slice-rotation
## is still required to spot most targets.
const W_RANGE := 20.0
## Orange floor top is at y=0 (Ground position.y=-0.5, half-extent 0.5).
## Targets hover 1-2 units above that, chosen at random per spawn.
const HOVER_Y_MIN := 1.0
const HOVER_Y_MAX := 2.0

## The target box (gallery_target.tscn) is a 1-unit BoxTetraMesh4D, so its
## w-extent is target.w +- 0.5. "Middle half, at least a quarter in from any
## edge" excludes the outer 0.25 on each end, leaving target.w +- 0.25.
const MIDDLE_HALF_W_MARGIN := 0.25
const TARGET_DEFAULT_COLOR := Color(0.9, 0.1, 0.1, 1) # matches gallery_target.tscn's own albedo_color.
const TARGET_SLICE_HIGHLIGHT_COLOR := Color(0.2, 0.9, 0.2, 1)

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
	if event.is_action_pressed("toggle_stopwatch_display"):
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
		# world-space w of the currently-visible slice. Doubles as an aiming
		# aid here: green means this target is actually in the visible slice.
		var slice_w: float = player.global_position.w
		var w_offset: float = absf(slice_w - _current_target.global_position.w)
		_current_target_material.albedo_color = (
			TARGET_SLICE_HIGHLIGHT_COLOR if w_offset <= MIDDLE_HALF_W_MARGIN else TARGET_DEFAULT_COLOR
		)

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
	# The material is a shared scene sub-resource - duplicate it so recoloring
	# this target doesn't bleed into every other GalleryTarget instance.
	var mesh: MeshInstance4D = target.get_node("Mesh")
	_current_target_material = mesh.material_override.duplicate()
	mesh.material_override = _current_target_material

func _random_spawn_position() -> Vector4:
	return Vector4(
		randf_range(-XZ_RANGE, XZ_RANGE),
		randf_range(HOVER_Y_MIN, HOVER_Y_MAX),
		randf_range(-XZ_RANGE, XZ_RANGE),
		randf_range(-W_RANGE, W_RANGE),
	)
