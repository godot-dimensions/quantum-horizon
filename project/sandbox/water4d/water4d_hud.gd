extends Label
## The readout: which preset is live, the dominant wave's numbers, and how far the slice has
## been turned.
##
## `off W` is the one worth watching. It is how much of the dominant wave's direction points
## along the axis your slice cannot see: near 0 and the sea behaves like ordinary 3D water,
## near 1 and the crests are arriving from a direction that does not exist on screen, which
## is preset 4's whole point.

@export var surface_path: NodePath = ^"../../Water"
@export var camera_path: NodePath = ^"../../FlyCamera"

var _surface: Node4D = null
var _camera: Camera4D = null


func _ready() -> void:
	_surface = get_node_or_null(surface_path) as Node4D
	_camera = get_node_or_null(camera_path) as Camera4D


func _process(_delta: float) -> void:
	if _surface == null:
		return
	var d: Dictionary = _surface.call(&"dominant")
	var index: int = int(_surface.get(&"preset_index"))
	var preset: String = _surface.call(&"preset_name", index)
	var iterations: int = int(_surface.get(&"solve_iterations"))
	var solve: String = ("%d iterations" % iterations) if iterations > 0 else "off (plain sines)"
	var turn := Vector2.ZERO
	if _camera != null and _camera.has_method(&"slice_turn_degrees"):
		turn = _camera.call(&"slice_turn_degrees")

	# THE BRACKETS MATTER. `+` binds tighter than `%`, so formatting a chain of joined
	# literals without them feeds the arguments to the last piece alone and Godot prints
	# "String formatting error: a number is required" once a frame.
	var layout := ("WASD fly   Space/Ctrl up-down   E/Q through W   RMB-drag turn the slice   R level it\n"
			+ "1-8 presets   F Jacobian view   G Gerstner on/off   N detail noise   Esc free the cursor\n"
			+ "%d. %s    amplitude %.2f m   wavelength %.1f m   steepness %.2f   off W %.2f\n"
			+ "solve %s    slice turned %.0f / %.0f deg    %d fps")
	text = layout % [index + 1, preset,
			float(d["amplitude"]), float(d["wavelength"]), float(d["steepness"]),
			float(d["off_slice"]), solve,
			turn.x, turn.y, Engine.get_frames_per_second()]
