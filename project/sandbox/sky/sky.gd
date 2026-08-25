extends Node4D
## Camera-parented sky: same rigid-parenting pattern as GunViewmodel, one
## level under FirstPersonCamera - rides along with the camera's full
## transform automatically, no sync code needed. Two pieces:
##
## Shell - a large enclosing box, pinned at local position (0,0,0,0) and
## sized far beyond any other scene geometry in every axis INCLUDING w (see
## SHELL_HALF_EXTENT) - "not a world-space shell, not something that should
## ever disappear." Being camera-relative and huge, the camera/player is
## always at its exact center, same standard technique any 3D engine's
## skybox cube uses - you're always "inside" it, so its own silhouette
## never actually matters (per spec: "doesn't need to be a true sphere at
## this scale"). Its ALWAYS-large w half-extent - unlike every gameplay
## target in this project, which is deliberately kept thin in w - is
## exactly what guarantees it's inside the visible w=0 cross-section for
## literally any slice-rotation the player can reach.
##
## Interior-facing box rendering (the camera sits INSIDE this box's volume,
## looking at its inner faces) is already proven working elsewhere in this
## project - Holodeck (holodeck_ramon.gd) is the exact same box-viewed-
## from-inside setup, just world-anchored instead of camera-relative.
##
## Sun disc - SunDisc itself is a plain (unscripted-mesh) Node4D whose LOCAL
## POSITION (recomputed every frame, including local w) is the sun's fixed
## true world direction transformed into the camera's CURRENT local axes -
## same transform family BearingUtility4D uses (a world-space offset,
## dotted against each basis column to read off its local components).
## This position is the clean, semantic "how aligned is the sun with the
## current slice" value - at perfect alignment it's exactly Vector4(...,
## w=0), nothing else added to it.
##
## Its own child, Visual (a MeshInstance4D), is where the actual round
## panel lives - same cylinder(ico) reorientation technique as
## bullseye_target.gd's ring panels (native round axes onto local x/y,
## squeezed thin in local z for a flat coin - see that script's own header
## comment for the full derivation). Visual's own FIXED local w offset only
## centers the cylinder mesh's native w-span (0..1, not centered like this
## project's usual +-half-size convention) around wherever SunDisc's own
## position places it - it must NOT be folded into SunDisc's own position
## directly (an earlier version of this script did exactly that, and it
## quietly shifted what "aligned" meant by a constant amount - the same
## split bullseye_target.gd already uses, keeping its own global_position
## clean while its child ring panels carry their own small cosmetic
## offsets, for exactly this reason).
##
## SunDisc's local w is NOT pinned to 0, unlike the shell - that's the
## entire point: when the player's current slice doesn't happen to include
## the sun's true direction, its local w drifts away from 0 and the whole
## thing (SunDisc plus its Visual child) simply isn't in the rendered
## cross-section, exactly like any other 4D object going off-slice. No
## special-case visibility logic anywhere - this is the existing cross-
## section rule already handling it for free.
##
## Motion (an actual moving orbit), toggles, and clouds are all explicitly
## deferred - SUN_DIRECTION is a fixed constant for this pass. Confirm the
## shell's non-occlusion, the elevation-driven tint, and the disc's
## transform/visibility all work together first.

## Fixed for now - a real orbit (animating this over time) is a later pass.
## Roughly a mid-morning sun: mostly up, a bit off to one side. Pre-
## normalized by hand (GDScript const initializers can't call .normalized()
## at parse time) - direction (0.35, 0.85, -0.2, 0.0) / its own length.
const SUN_DIRECTION := Vector4(0.37206, 0.90359, -0.21261, 0.0)

const SHELL_HALF_EXTENT := 200.0 # Far beyond any other geometry in this project, in every axis including w.
const SUN_DISTANCE := 150.0 # Comfortably inside the shell - a finite stand-in for "infinitely far," same as any skybox sun.

const NIGHT_COLOR := Color(0.05, 0.07, 0.15, 1.0)
const DAY_COLOR := Color(0.55, 0.75, 0.95, 1.0)

const SUN_RADIUS := 8.0
const SUN_DEPTH := 2.0 # Local z thickness of the flat disc, before the cylinder(ico) reorientation scale.
const SUN_W_THICKNESS := 6.0 # Deliberately generous, not razor-thin like a gameplay target - see class comment on why the disc's own visibility already comes for free from local w drifting off 0.
const SUN_COLOR := Color(1.0, 0.95, 0.6, 1.0)

## Same derivation as bullseye_target.gd's own constants - see that
## script's header comment.
const CYLINDER_NATIVE_ROUND_RADIUS := 0.85065081
const CYLINDER_NATIVE_THIN_LENGTH := 1.0
const CylinderIcoMesh := preload("res://models/primitives/cylinder/ico/cylinder_smooth_ico2.g4b")

@onready var camera: Node4D = $".."
@onready var shell: MeshInstance4D = $Shell
@onready var sun_disc: Node4D = $SunDisc
@onready var sun_visual: MeshInstance4D = $SunDisc/Visual

var _shell_material: TetraMaterial4D
var _sun_material: TetraMaterial4D


func _ready() -> void:
	position = Vector4(0, 0, 0, 0) # Pinned - see class comment.

	var shell_mesh := BoxTetraMesh4D.new()
	shell_mesh.size = Vector4.ONE * (SHELL_HALF_EXTENT * 2.0)
	shell.mesh = shell_mesh
	# BoxTetraMesh4D's faces are single-sided with outward-pointing normals
	# by design (confirmed in engine source: box_mesh_data.inc's boundary
	# normals + ArrayTetraMesh4D's own docs on "which side is the front").
	# The cross-section shader backface-culls by default (no cull_disabled
	# in its render_mode) - viewed from OUTSIDE a box that's normal, but the
	# camera sits at this shell's own center, i.e. permanently INSIDE it, so
	# every face's outward normal always points away from the camera and
	# would be culled entirely. A single negated spatial axis (not w - that
	# axis isn't part of the final rasterized triangle, it drives the
	# cross-section slice itself, a different computation) mirrors the
	# mesh, reversing final screen-space winding and therefore which side
	# reads as "front" - confirmed by direct pixel-sampling, not just
	# reasoned: without this, the rendered pixel was flat (0.298, 0.298,
	# 0.298), Godot's default clear color showing through an entirely
	# unrendered shell.
	shell.basis = Basis4D.from_scale(Vector4(1, 1, -1, 1))
	_shell_material = TetraMaterial4D.new()
	shell.material_override = _shell_material

	sun_visual.mesh = CylinderIcoMesh
	var round_scale: float = SUN_RADIUS / CYLINDER_NATIVE_ROUND_RADIUS
	var depth_scale: float = SUN_DEPTH / (2.0 * CYLINDER_NATIVE_ROUND_RADIUS)
	var w_scale: float = SUN_W_THICKNESS / CYLINDER_NATIVE_THIN_LENGTH
	# Columns are where each NATIVE axis ends up, scaled to its target
	# extent in the same motion: native X -> local x, native Z -> local y,
	# native W -> local z, native Y -> local w. Identical pattern to
	# bullseye_target.gd's _build_cylinder_panel().
	sun_visual.basis = Projection(
		Vector4(round_scale, 0, 0, 0),
		Vector4(0, 0, 0, w_scale),
		Vector4(0, round_scale, 0, 0),
		Vector4(0, 0, depth_scale, 0),
	)
	# Fixed, local to Visual only - centers the cylinder mesh's native w-span
	# around SunDisc's own (per-frame, semantic) position, never folded into
	# it - see class comment.
	sun_visual.position = Vector4(0, 0, 0, -w_scale * 0.5)
	_sun_material = TetraMaterial4D.new()
	_sun_material.albedo_color = SUN_COLOR
	sun_visual.material_override = _sun_material


func _process(_delta: float) -> void:
	_shell_material.albedo_color = NIGHT_COLOR.lerp(DAY_COLOR, get_elevation_t())

	var camera_basis: Projection = camera.global_basis
	var sun_world_offset: Vector4 = SUN_DIRECTION * SUN_DISTANCE
	sun_disc.position = Vector4(
		sun_world_offset.dot(camera_basis.x),
		sun_world_offset.dot(camera_basis.y),
		sun_world_offset.dot(camera_basis.z),
		sun_world_offset.dot(camera_basis.w),
	)


## 0-1: 0 at directly below the horizon (elevation -90 deg), 1 at directly
## overhead (elevation +90 deg), 0.5 exactly at the horizon - a plain sine
## mapping of the elevation angle. No asin needed: SUN_DIRECTION is
## normalized, so its own y-component already IS sin(elevation) by
## definition - same shortcut BearingUtility4D takes for angle_off_slice.
func get_elevation_t() -> float:
	return clampf(SUN_DIRECTION.y * 0.5 + 0.5, 0.0, 1.0)
