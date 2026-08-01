extends Camera4D
## Shooting gallery minimap: the always-on "volume view" camera. In
## godot_boids_4d this was three pieces - VolumeRig (yaw) + VolumeCamera
## (pitch/tilt), a separate main-view camera the player could Tab into and
## fly around, plus MiniMapCamera, which mirrored whichever of {first-person,
## volume} camera WASN'T the current main view into the mini-map's
## SubViewport. There's no second main view or Tab toggle here - this is
## always-on and never becomes the primary camera - so all three collapse
## into one node: a fixed orientation set once (never touched again,
## regardless of the player's look direction) plus per-frame position
## tracking.
##
## Orientation: a single y-w rotor swap, applied once in _ready() and never
## reapplied. This makes local-w align with world-y and local-y align with
## world-w - the rendered 3D scene (local x/y/z) becomes world x/w/z (a
## normal 3D scene perpendicular to gravity), and world-y (actual height)
## becomes the sliced axis, exactly mirroring how w is sliced in first-person
## Cross-section. This is the boids source's actual (confirmed working)
## mechanism - a forward-facing camera with w as the vertical screen axis and
## y as the sliced axis, NOT a literal bird's-eye/top-down camera pitch, even
## though the net effect is "a view of the x/z/w space perpendicular to
## gravity."
##
## Position: tracks the player's x/z/w every frame (a real change from
## boids' fixed rig) - x and w directly, since those map to the rendered
## scene's horizontal and vertical screen axes, so the player lands exactly
## at screen-center by construction. z gets a fixed pullback added on top
## (can't just equal the player's z - that's zero distance, degenerate) so
## the player stays framed at a consistent depth/scale as they walk around.
## y is deliberately NOT tracked - it's the sliced axis here, and keeping it
## fixed gives a stable view of the gallery's floors/targets rather than the
## visible height band drifting every time the player jumps.
##
## Uses "Wireframe Canvas", not "Cross-section" - confirmed necessary, not
## stylistic (matches godot_boids_4d/minimap_camera.gd's own comment): the
## Cross-section engine's C++ implementation stores its World3D/camera/mesh
## RIDs in single, non-per-viewport-keyed members, so two simultaneous
## Cross-section cameras (this one + FirstPersonCamera) would fight over the
## same resources. Wireframe Canvas instead adds its own Control child to
## whichever viewport asks for it, so it's safe alongside the main view.

@export var pullback_z: float = 10.0
@export var fixed_height_y: float = 1.0

@onready var player: CharacterBody4D = $"../../../FlatPlane/Player"


func _ready() -> void:
	rendering_engine = "Wireframe Canvas"
	projection_type = Camera4D.PROJECTION4D_PERSPECTIVE_4D
	field_of_view_3d = deg_to_rad(65)
	field_of_view_4d = deg_to_rad(65)
	clip_far = 60.0
	w_fade_mode = Camera4D.W_FADE_TRANSPARENCY_HUE_SHIFT
	w_fade_distance = 4.0
	rotate_rotor_local(Rotor4D.from_yw(PI / 2.0))
	make_current()


func _process(_delta: float) -> void:
	var p: Vector4 = player.global_position
	global_position = Vector4(p.x, fixed_height_y, p.z + pullback_z, p.w)
