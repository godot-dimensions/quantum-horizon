extends Control
## Slice-alignment glow: a full-screen vignette-style border that glows
## green as the current target comes into angular alignment with the
## player's current slice. Entirely separate from the radar widget/POI
## arrow - reads BearingUtility4D directly, doesn't depend on their math.
##
## Opacity curve, per frame:
##   |angle_off_slice| >= OUTER_ANGLE_THRESHOLD_DEG (30 deg): 0 - far off
##     slice, no feedback.
##   |angle_off_slice| <= in-slice threshold: 1, flat - genuinely
##     intersecting the current slice already.
##   between: t = (30 - |angle|) / (30 - inner), opacity = t*t - stays low
##     longer, then rises quickly near full alignment (tune the exponent by
##     feel; this is a starting point, not a fixed spec).
##
## The in-slice threshold is NOT a new invented number: it's
## target_spawner.gd's existing MIDDLE_HALF_W_MARGIN (0.25) - the "genuinely
## intersecting" epsilon already used elsewhere (the middle half of the
## target's own 1-unit box - note this constant lives in target_spawner.gd,
## used by main.tscn; gallery_target_spawner.gd no longer has it, it was
## deliberately dropped earlier this session as a now-redundant visual cue).
## That epsilon is a raw world-unit distance (the target's own physical
## thickness, which doesn't change with range) - converted to an
## instantaneous angle each frame at the target's CURRENT distance purely so
## it and the fixed 30-degree outer gate share the same unit space for the
## ease formula above; the underlying "genuinely intersecting" criterion
## itself stays anchored to that real physical margin, not a made-up angle.

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

const OUTER_ANGLE_THRESHOLD_DEG := 30.0
const IN_SLICE_DISTANCE_EPSILON := 0.25

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var spawner: Node4D = $"../FlatPlane/GalleryTargetSpawner"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	material.set_shader_parameter("intensity", _compute_intensity())


func _compute_intensity() -> float:
	if spawner._current_target == null:
		return 0.0
	var bearing: Dictionary = BearingUtility4D.compute(player, spawner._current_target.global_position)
	var rel_length: float = bearing.rel.length()
	var angle_deg: float = absf(rad_to_deg(bearing.angle_off_slice))
	var inner_threshold_deg: float = (
		rad_to_deg(asin(clampf(IN_SLICE_DISTANCE_EPSILON / rel_length, -1.0, 1.0))) if rel_length > 0.0001 else 0.0
	)
	if angle_deg <= inner_threshold_deg:
		return 1.0
	if angle_deg >= OUTER_ANGLE_THRESHOLD_DEG:
		return 0.0
	var t: float = clampf((OUTER_ANGLE_THRESHOLD_DEG - angle_deg) / (OUTER_ANGLE_THRESHOLD_DEG - inner_threshold_deg), 0.0, 1.0)
	return t * t
