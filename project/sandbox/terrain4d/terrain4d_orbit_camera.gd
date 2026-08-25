extends Camera4D
## Orbit camera for the strategy-style terrain viewer: stays pointed at a
## fixed pivot, panned by left-click-drag via azimuth (free, wraps around
## the vertical axis with no clamp) and elevation (clamped so the camera
## can never dip below the horizon or go past straight-down), and zoomed
## via the scroll wheel (radius, also clamped).
##
## This replaced an earlier design that spun the TERRAIN in ordinary 3D via
## a holonomy-free quaternion (absolute yaw/pitch, rebuilt fresh each time).
## That approach genuinely fixed the holonomy/roll-drift problem, but a
## free yaw+pitch orientation can still end up upside-down (yaw past a
## pitch of +/-90 degrees flips which way "up" reads) - not wanted here.
## An azimuth/elevation orbit is a different, simpler fix for a different
## part of the same complaint: it can't go upside-down BY CONSTRUCTION
## (elevation is clamped to a range that never crosses the pivot's own
## height, and azimuth alone - pure horizontal orbiting - can never flip
## anything), and it has zero holonomy risk for the same reason the
## quaternion approach did: azimuth and elevation are independent scalars
## with no rotation COMPOSITION happening at all, so there's nothing for
## drift to accumulate in.
##
## 4D (right-click) rotation stays on the terrain object itself, in
## terrain4d_orbit_controller.gd, unchanged.

const MOUSE_SENSITIVITY := 0.006

@export var look_at_target: Vector4 = Vector4(0, 1, 0, 0)
@export var radius: float = 13.6
@export var min_radius: float = 5.0
@export var max_radius: float = 30.0
@export var zoom_step: float = 1.2
## Elevation is measured from "straight down" (0 degrees, camera directly
## above the target) to "horizon" (90 degrees, camera level with the
## target) - clamping keeps it a bit short of both ends.
@export var min_elevation_deg: float = 10.0
@export var max_elevation_deg: float = 80.0
@export var initial_elevation_deg: float = 54.0
@export var initial_azimuth_deg: float = 0.0

var _azimuth := 0.0
var _elevation := 0.0

func _ready() -> void:
	_azimuth = deg_to_rad(initial_azimuth_deg)
	_elevation = deg_to_rad(initial_elevation_deg)
	_apply_orbit()

func _input(input_event: InputEvent) -> void:
	if input_event is InputEventMouseMotion:
		_handle_drag(input_event)
	elif input_event is InputEventMouseButton and input_event.pressed:
		_handle_zoom(input_event)

func _handle_drag(input_event: InputEventMouseMotion) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var rel: Vector2 = input_event.relative * MOUSE_SENSITIVITY
	# Increasing azimuth moves the CAMERA counter-clockwise (viewed from
	# above, given _apply_orbit()'s offset formula), which makes the OBJECT
	# appear to rotate CLOCKWISE from the camera's view - matching the
	# previously-confirmed "drag left = object turns clockwise from above"
	# feel from when 3D rotation still lived on the object itself. A left
	# drag is a negative rel.x, so it needs to INCREASE azimuth, meaning
	# rel.x must be subtracted, not added.
	_azimuth -= rel.x
	# Dragging up (rel.y negative) brings the camera up toward the
	# straight-down view, i.e. decreases elevation.
	_elevation = clampf(_elevation + rel.y, deg_to_rad(min_elevation_deg), deg_to_rad(max_elevation_deg))
	_apply_orbit()

func _handle_zoom(input_event: InputEventMouseButton) -> void:
	if input_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		radius = clampf(radius - zoom_step, min_radius, max_radius)
		_apply_orbit()
	elif input_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		radius = clampf(radius + zoom_step, min_radius, max_radius)
		_apply_orbit()

## Public entry point for external code that mutates look_at_target
## directly (e.g. a pan controller) - _apply_orbit() otherwise only runs
## in response to this script's own drag/zoom input handling, so a
## look_at_target change made from outside wouldn't move the camera until
## the next drag/zoom event without this.
func refresh() -> void:
	_apply_orbit()

func _apply_orbit() -> void:
	var sin_e := sin(_elevation)
	var cos_e := cos(_elevation)
	# azimuth=0 offsets along +Z (matching the original fixed camera's
	# (0, y, z, 0) placement), so the default view looks the same as before.
	var offset := Vector4(sin_e * sin(_azimuth), cos_e, sin_e * cos(_azimuth), 0.0) * radius
	position = look_at_target + offset
	var direction := look_at_target - position
	basis = Basis4D.looking_at(direction, Vector4(0, 0, 0, 1), Vector4(0, 1, 0, 0))
