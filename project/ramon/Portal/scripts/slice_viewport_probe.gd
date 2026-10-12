extends Control
## The one experiment that decides the Portal prototype's architecture: can two
## viewports show two DIFFERENT 4D cross-sections in the same frame?
##
## The strategy paper assumes yes - its portal view is a SubViewport whose
## camera sits in the destination slice. Reading engine/modules/4d/render/, the
## prediction is NO: exactly one RenderingEngine4D instance exists per engine
## name and is shared by every viewport (rendering_server_4d.cpp:328), it hands
## them all the same World3D and the same camera RID
## (cross_section_rendering_engine_4d.cpp:226-238), and the slice itself is
## pushed as per-INSTANCE shader parameters (modelview_origin,
## modelview_basis_*) which the frame loop overwrites as it walks viewports.
## The maintainer's own TODO sits on that exact line, :185 - "Need to split out
## view matrix to support multiple viewports, currently the same for all
## viewports."
##
## Run this scene (F6) and read the inset against the main view:
##
##   main RED, inset BLUE  -> prediction WRONG. Per-viewport slicing already
##                            works; build the portal view as the paper says.
##   both show the same    -> prediction CONFIRMED. One slice per frame; the
##                            portal view needs either that engine change or
##                            the geometry-diorama approach instead.
##   inset flickers        -> the viewports are racing for one set of uniforms.
##                            Same conclusion as above, and worth reporting
##                            upstream with a capture.
##
## Deliberately has no player body and no physics: a CharacterBody4D would only
## add ways for the test to fail for reasons unrelated to the question being
## asked. The main camera flies instead, and the inset camera is slaved to it at
## a fixed w offset - which is exactly the portal-view mapping this prototype
## would use anyway (identity rotation, pure w translation), so moving around
## also shows whether the inset tracks with correct parallax.

const FLOOR_TEXTURE: Texture3D = preload("res://textures/dev_finals/ramdev_grey.png")
const REFERENCE_TEXTURE: Texture3D = preload("res://textures/dev_finals/ramdev_white.png")
const HOME_TEXTURE: Texture3D = preload("res://textures/dev_finals/ramdev_red.png")
const DESTINATION_TEXTURE: Texture3D = preload("res://textures/dev_finals/ramdev_blue.png")

## How far apart in w the two markers sit. Each marker is only WNarrow thick, so
## a camera at w = 0 cannot see the far marker at all and vice versa - that
## mutual invisibility is the whole measurement.
const DESTINATION_W: float = 8.0
const MARKER_W_THICKNESS: float = 1.5

const W_STEP: float = 0.5 # Per key press, for sweeping w.
const FLY_SPEED: float = 6.0 # Metres per second.
const SPRINT_MULTIPLIER: float = 2.5
const MOUSE_SENSITIVITY: float = 0.002
const PITCH_LIMIT: float = 1.57 # Radians, just under straight up/down.

const SPAWN_POSITION := Vector4(0.0, 2.0, 12.0, 0.0)

@onready var _world: Node4D = $World
@onready var _main_camera: Camera4D = $World/MainCamera
@onready var _destination_camera: Camera4D = $DestinationViewportContainer/DestinationViewport/DestinationCamera
@onready var _readout: Label = $Readout

## Yaw and pitch are held as floats and the basis rebuilt from them each time,
## rather than composed incrementally onto the existing basis - the same reason
## player.gd sets pitch absolutely: repeated multiplication drifts, and this
## probe must not introduce a wobble that could be mistaken for a slicing bug.
var _yaw: float = 0.0
var _pitch: float = 0.0

## How far the inset camera sits along w from the main one. This is the whole
## measurement: at 0 both views must agree, at DESTINATION_W they must not.
var _w_offset: float = DESTINATION_W


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.07, 1.0))
	_build_markers()
	_main_camera.position = SPAWN_POSITION
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## No Light4D/WorldEnvironment4D here, so cross-sections need the flat-shaded
## swap or every surface renders black - same reason PhaseMaze, ImpossibleBypass
## and the shooting gallery use it. Keeping lights out of the probe also keeps
## one more per-viewport engine subsystem out of the measurement.
func _make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	FlatShadingRamon.apply(material)
	material.albedo_texture_3d = texture
	return material


func _add_box(position: Vector4, size: Vector4, texture: Texture3D) -> void:
	var mesh_instance := MeshInstance4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = size
	box.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	mesh_instance.mesh = box
	mesh_instance.material_override = _make_material(texture)
	mesh_instance.position = position
	_world.add_child(mesh_instance)


## Three markers, chosen so a single glance answers the question:
## white is w-invariant and must appear in BOTH views (it proves the inset is
## rendering the 4D world at all, rather than showing nothing); red exists only
## near w = 0 and blue only near w = DESTINATION_W, so exactly one of them
## should be visible per view IF the two viewports really do slice separately.
func _build_markers() -> void:
	var w_invariant_extent: float = DESTINATION_W * 4.0
	_add_box(Vector4(0.0, -0.25, 0.0, 0.0), Vector4(24.0, 0.5, 24.0, w_invariant_extent), FLOOR_TEXTURE)
	_add_box(Vector4(0.0, 1.5, 0.0, 0.0), Vector4(0.6, 3.0, 0.6, w_invariant_extent), REFERENCE_TEXTURE)
	_add_box(Vector4(-3.0, 1.5, 0.0, 0.0), Vector4(1.6, 3.0, 1.6, MARKER_W_THICKNESS), HOME_TEXTURE)
	_add_box(Vector4(3.0, 1.5, 0.0, DESTINATION_W), Vector4(1.6, 3.0, 1.6, MARKER_W_THICKNESS), DESTINATION_TEXTURE)


func _input(input_event: InputEvent) -> void:
	if input_event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var relative: Vector2 = input_event.relative * MOUSE_SENSITIVITY
		_yaw -= relative.x
		_pitch = clampf(_pitch - relative.y, -PITCH_LIMIT, PITCH_LIMIT)
		return
	if input_event is InputEventMouseButton and input_event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if not (input_event is InputEventKey and input_event.pressed and not input_event.echo):
		return
	match input_event.keycode:
		KEY_ESCAPE:
			# Release the mouse rather than quitting - running from the editor,
			# quitting on the reflex key makes the probe hard to re-examine.
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		KEY_RIGHT:
			_w_offset += W_STEP
		KEY_LEFT:
			_w_offset -= W_STEP
		KEY_R:
			_main_camera.position = SPAWN_POSITION
			_w_offset = DESTINATION_W
			_yaw = 0.0
			_pitch = 0.0


func _process(delta_time: float) -> void:
	_move_main_camera(delta_time)
	# The portal-view mapping in its simplest form: same orientation, same 3D
	# position, translated along w only. Anything the inset shows differently is
	# therefore a difference of SLICE, not of viewpoint.
	_destination_camera.basis = _main_camera.basis
	_destination_camera.position = _main_camera.position + Vector4(0.0, 0.0, 0.0, _w_offset)
	_update_readout()


func _move_main_camera(delta_time: float) -> void:
	_main_camera.basis = Basis4D.from_zx(_yaw) * Basis4D.from_yz(_pitch)
	var input_direction := Vector4(
		Input.get_axis(&"move_left", &"move_right"),
		0.0,
		Input.get_axis(&"move_forward", &"move_back"),
		Input.get_axis(&"move_kata", &"move_ana"),
	)
	var speed: float = FLY_SPEED * (SPRINT_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	# Flying, not walking: y comes from the look direction, so W flies where the
	# camera points. There is no floor to stand on and nothing here needs one.
	var motion: Vector4 = _main_camera.basis * input_direction
	if motion.length() > 0.0:
		_main_camera.position += motion.normalized() * speed * delta_time


func _update_readout() -> void:
	_readout.text = "\n".join([
		"SLICE / VIEWPORT PROBE",
		"",
		"WASD fly, mouse look, Q / E move through w, SHIFT sprint",
		"LEFT / RIGHT change the inset's w offset, R resets, ESC frees the mouse",
		"",
		"main camera w   %+.1f" % _main_camera.position.w,
		"inset offset    %+.1f   (inset camera w %+.1f)" % [_w_offset, _destination_camera.position.w],
		"",
		"white post = every w, must show in BOTH views",
		"red = only near w 0     blue = only near w %+.1f" % DESTINATION_W,
		"",
		"main RED + inset BLUE -> per-viewport slicing works",
		"both views identical   -> one slice per frame (predicted)",
	])
