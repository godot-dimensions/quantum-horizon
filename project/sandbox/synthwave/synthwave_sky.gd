extends Node4D
## Synthwave skybox: same camera-parented shell + sun-disc structure as
## sky.gd (see that script's own header for the full derivation of why the
## shell is huge/camera-pinned and how the sun disc's local position doubles
## as its own off-slice-visibility signal) - this fork swaps sky.gd's flat
## TetraMaterial4D colors for the gradient/starfield ShaderMaterials in
## synthwave_sky.gdshader/synthwave_sun.gdshader, and drops the day/night
## elevation lerp entirely (a synthwave sky is one fixed look, not a cycle).

const SUN_DIRECTION := Vector4(0.37206, 0.90359, -0.21261, 0.0)
const WORLD_UP := Vector4(0.0, 1.0, 0.0, 0.0)

const SHELL_HALF_EXTENT := 200.0
const SUN_DISTANCE := 150.0

const SUN_RADIUS := 10.0
const SUN_DEPTH := 2.0
const SUN_W_THICKNESS := 6.0

const CYLINDER_NATIVE_ROUND_RADIUS := 0.85065081
const CYLINDER_NATIVE_THIN_LENGTH := 1.0
const CylinderIcoMesh := preload("res://models/primitives/cylinder/ico/cylinder_smooth_ico2.g4b")

const SkyShader := preload("res://sandbox/synthwave/synthwave_sky.gdshader")
const SunShader := preload("res://sandbox/synthwave/synthwave_sun.gdshader")

@onready var camera: Node4D = $".."
@onready var shell: MeshInstance4D = $Shell
@onready var sun_disc: Node4D = $SunDisc
@onready var sun_visual: MeshInstance4D = $SunDisc/Visual

var _shell_shader_material: ShaderMaterial
var _sun_shader_material: ShaderMaterial
var _debug_local_up: Vector4 = Vector4.ZERO # Inspectable from a verify runner without needing GPU readback.


func _ready() -> void:
	position = Vector4(0, 0, 0, 0)

	var shell_mesh := BoxTetraMesh4D.new()
	shell_mesh.size = Vector4.ONE * (SHELL_HALF_EXTENT * 2.0)
	shell.mesh = shell_mesh
	# Same winding fix as sky.gd's own shell - see that script's comment.
	shell.basis = Basis4D.from_scale(Vector4(1, 1, -1, 1))
	# material_override is typed Material4D, not Material - a plain
	# ShaderMaterial can't go there directly (confirmed the hard way: a
	# parse-time type error). The working pattern, from
	# ramon/SkyBoxClouds/scripts/skydome_4d.gd: keep a real TetraMaterial4D
	# in the slot, then swap the SHADER on its own internal
	# cross_section_material - extra custom uniforms (below) can still be
	# set directly on that inner ShaderMaterial; TetraMaterial4D's own
	# per-frame updates only ever touch its two known uniforms (albedo,
	# albedo_texture), so they don't disturb these.
	var shell_material := TetraMaterial4D.new()
	_shell_shader_material = shell_material.get_cross_section_material()
	_shell_shader_material.shader = SkyShader
	shell.material_override = shell_material

	sun_visual.mesh = CylinderIcoMesh
	var round_scale: float = SUN_RADIUS / CYLINDER_NATIVE_ROUND_RADIUS
	var depth_scale: float = SUN_DEPTH / (2.0 * CYLINDER_NATIVE_ROUND_RADIUS)
	var w_scale: float = SUN_W_THICKNESS / CYLINDER_NATIVE_THIN_LENGTH
	sun_visual.basis = Projection(
		Vector4(round_scale, 0, 0, 0),
		Vector4(0, 0, 0, w_scale),
		Vector4(0, round_scale, 0, 0),
		Vector4(0, 0, depth_scale, 0),
	)
	sun_visual.position = Vector4(0, 0, 0, -w_scale * 0.5)
	var sun_material := TetraMaterial4D.new()
	_sun_shader_material = sun_material.get_cross_section_material()
	_sun_shader_material.shader = SunShader
	_sun_shader_material.set_shader_parameter("native_round_radius", CYLINDER_NATIVE_ROUND_RADIUS)
	sun_visual.material_override = sun_material


func _process(_delta: float) -> void:
	var camera_basis: Projection = camera.global_basis
	var sun_world_offset: Vector4 = SUN_DIRECTION * SUN_DISTANCE
	sun_disc.position = Vector4(
		sun_world_offset.dot(camera_basis.x),
		sun_world_offset.dot(camera_basis.y),
		sun_world_offset.dot(camera_basis.z),
		sun_world_offset.dot(camera_basis.w),
	)

	# True world-up, re-expressed in the camera's CURRENT local frame (same
	# dot-against-each-basis-column trick as sun_disc.position above) - both
	# the shell and the sun disc are rigid children of the camera, so this is
	# recomputed fresh every frame rather than once, exactly tracking
	# whichever way the camera is currently looking. See both shaders' own
	# local_up_dir/native_up_dir comments for why this is needed at all.
	var local_up: Vector4 = Vector4(
		WORLD_UP.dot(camera_basis.x),
		WORLD_UP.dot(camera_basis.y),
		WORLD_UP.dot(camera_basis.z),
		WORLD_UP.dot(camera_basis.w),
	)
	_debug_local_up = local_up
	_shell_shader_material.set_shader_parameter("local_up_dir", Vector3(local_up.x, local_up.y, local_up.z))
	# The camera's own basis columns, passed through as-is (each "where does
	# this local axis point in world space") - lets the shell shader
	# reconstruct any fragment's true world direction for the starfield hash.
	# See basis_x_dir's own comment in the shader for why this is a separate,
	# genuinely necessary uniform rather than something derivable from
	# local_up_dir alone (that one only ever extracts a single "how much is
	# world-up" component, not a full direction).
	_shell_shader_material.set_shader_parameter("basis_x_dir", Vector3(camera_basis.x.x, camera_basis.x.y, camera_basis.x.z))
	_shell_shader_material.set_shader_parameter("basis_y_dir", Vector3(camera_basis.y.x, camera_basis.y.y, camera_basis.y.z))
	_shell_shader_material.set_shader_parameter("basis_z_dir", Vector3(camera_basis.z.x, camera_basis.z.y, camera_basis.z.z))
	# The sun disc's own native X/Z plane maps to local X/Y respectively (see
	# sun_visual.basis above: native X -> local x, native Z -> local y) - the
	# shared round_scale factor on both cancels out of a direction, so no
	# further basis-inversion is needed beyond picking these two components.
	_sun_shader_material.set_shader_parameter("native_up_dir", Vector2(local_up.x, local_up.y))
