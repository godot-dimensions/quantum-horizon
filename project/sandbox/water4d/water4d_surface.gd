extends Node4D
## The ocean: one 3D grid drawn inside the Cross-section engine's own World3D, with the wave
## field evaluated entirely in the shader.
##
## NOTHING ABOUT A WAVE IS EVALUATED HERE. This script owns the presets, the blend between
## them, the dispersion relation and the steepness clamp - all per wave, so at most eight
## numbers a frame - and hands them to water4d.gdshader as uniforms. The surface itself is
## the shader's business. Per-vertex work in GDScript is what the pen's perf pass found to
## be the expensive mistake.
##
## THE INSTANCE IS NOT A SCENE NODE. The Cross-section engine draws in camera space, so the
## water is added straight to the viewport's World3D through RenderingServer, the same way
## `ramon/chickenpen/flock/pen_flock_4d.gd` adds its murmuration. Two things from there are
## carried over because they are not obvious:
##
##   - `instance_set_ignore_culling(true)`, because the shader puts the vertices somewhere
##     Godot's own bounds cannot predict; and
##   - a custom AABB anyway, because an instance with no bounds is never indexed into its
##     scenario at all, and then ignore_culling never gets a say. The flock stepped perfectly
##     and drew nothing until that was added.
##
## The scenario is re-checked every frame rather than cached once, because the engine
## replaces the viewport's World3D on an engine switch or a scene trip.

const SHADER := preload("res://sandbox/water4d/water4d.gdshader")
const Presets := preload("res://sandbox/water4d/water4d_presets.gd")
const Wave := Presets.Wave

const MAX_WAVES := 8
const GRAVITY := 9.81
## Half-width of the grid, in metres, centred on the camera. The shader anchors it to the
## world, so this is "how far you can see water", not a position.
const EXTENT := 60.0
## Vertices per side. 193 across 120 m is a 0.63 m step, which carries the 2 m chop of
## preset 5 at about three samples a wave - coarse but legible. Raise for stills.
const GRID_RESOLUTION := 192
const BLEND_SECONDS := 0.5

var preset_index: int = 0
var debug_jacobian: bool = false
## Metres of value-noise detail riding on the wave sum. Zero is the old smooth surface.
var detail_strength: float = 0.085
var solve_iterations: int = 2
var water_level: float = 0.0

var _instance := RID()
var _mesh: ArrayMesh = null
var _material: ShaderMaterial = null
var _scenario := RID()
## The live wave set, which chases `_target` rather than snapping to it.
var _live: Array[Wave] = []
var _target: Array[Wave] = []
var _blend_left: float = 0.0
## Phase is accumulated rather than recomputed as omega * t: omega changes while a blend is
## running, and a large t loses float precision in the shader.
var _phase: PackedFloat32Array = PackedFloat32Array()
var _last_axis_a := Vector3(1.0, 0.0, 0.0)
## Accumulated rather than taken from a clock, for the same reason as the wave phases: a
## large time loses float precision inside the shader's noise lookup.
var _detail_time: float = 0.0


# --- lifecycle ----------------------------------------------------------------------------

func _ready() -> void:
	_live = Presets._preset(0)
	_target = Presets._preset(0)
	_phase.resize(MAX_WAVES)
	_mesh = _build_grid()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_instance, _mesh.get_rid())
	RenderingServer.instance_geometry_set_material_override(_instance, _material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(
			_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_ignore_culling(_instance, true)
	# Needed even with ignore_culling - see the note at the top of this file.
	RenderingServer.instance_set_custom_aabb(
			_instance, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(_instance, false)
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)
	if _instance.is_valid():
		RenderingServer.free_rid(_instance)
		_instance = RID()


func _process(delta: float) -> void:
	QHProfiler.begin(&"qh_custom/water4d/blend")
	if _blend_left > 0.0:
		var step: float = clampf(delta / maxf(_blend_left, 0.0001), 0.0, 1.0)
		for i in range(MAX_WAVES):
			var a: Wave = _live[i]
			var b: Wave = _target[i]
			a.amplitude = lerpf(a.amplitude, b.amplitude, step)
			a.wavelength = lerpf(a.wavelength, b.wavelength, step)
			a.steepness = lerpf(a.steepness, b.steepness, step)
			var d: Vector3 = a.dir.lerp(b.dir, step)
			a.dir = d.normalized() if d.length() > 0.0001 else b.dir
		_blend_left = maxf(_blend_left - delta, 0.0)
	QHProfiler.end(&"qh_custom/water4d/blend")

	QHProfiler.begin(&"qh_custom/water4d/phase")
	for i in range(MAX_WAVES):
		var k: float = TAU / maxf(_live[i].wavelength, 0.1)
		# Deep water. The dispersion relation only involves |k|, so it is the same statement
		# in four dimensions as in three.
		_phase[i] = fposmod(_phase[i] + sqrt(GRAVITY * k) * delta, TAU)
	_detail_time = fposmod(_detail_time + delta * 0.06, 1024.0)
	QHProfiler.end(&"qh_custom/water4d/phase")


## Forwarded so the HUD and the probes can ask the node, without each of them having to
## know the presets live in their own file.
static func preset_name(index: int) -> String:
	return Presets.preset_name(index)


func set_preset(index: int) -> void:
	preset_index = clampi(index, 0, Presets.count() - 1)
	_target = Presets._preset(preset_index)
	_blend_left = BLEND_SECONDS


## What the HUD prints: the dominant wave of the live set.
func dominant() -> Dictionary:
	var best: Wave = _live[0]
	for w in _live:
		if w.amplitude > best.amplitude:
			best = w
	return {
		"amplitude": best.amplitude,
		"wavelength": best.wavelength,
		"steepness": best.steepness,
		"off_slice": absf(best.dir.z),
	}


# --- the grid -------------------------------------------------------------------------------

## A flat lattice. Its x and z carry grid coordinates only; the shader decides where every
## vertex actually goes, so there are no normals or UVs to supply.
func _build_grid() -> ArrayMesh:
	var side: int = GRID_RESOLUTION + 1
	var verts := PackedVector3Array()
	verts.resize(side * side)
	var step: float = (EXTENT * 2.0) / float(GRID_RESOLUTION)
	for z in range(side):
		for x in range(side):
			verts[z * side + x] = Vector3(-EXTENT + float(x) * step, 0.0,
					-EXTENT + float(z) * step)
	var indices := PackedInt32Array()
	indices.resize(GRID_RESOLUTION * GRID_RESOLUTION * 6)
	var at: int = 0
	for z in range(GRID_RESOLUTION):
		for x in range(GRID_RESOLUTION):
			var i: int = z * side + x
			indices[at] = i
			indices[at + 1] = i + side
			indices[at + 2] = i + 1
			indices[at + 3] = i + 1
			indices[at + 4] = i + side
			indices[at + 5] = i + side + 1
			at += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Godot would work this out from the flat lattice, which is not where the shader puts
	# anything; a generous one keeps it from being thrown away before ignore_culling applies.
	mesh.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	return mesh


# --- per frame, just before the 4D engine draws ---------------------------------------------

func _on_pre_render(camera: Camera4D, viewport: Viewport, _engine: RenderingEngine4D) -> void:
	if viewport != get_viewport() or not _instance.is_valid():
		return
	QHProfiler.begin(&"qh_custom/water4d/uniforms")
	var world: World3D = viewport.find_world_3d()
	var scenario: RID = world.scenario if world != null else RID()
	if scenario != _scenario:
		_scenario = scenario
		RenderingServer.instance_set_scenario(_instance, scenario)
	var shown: bool = is_visible_in_tree() and scenario.is_valid()
	RenderingServer.instance_set_visible(_instance, shown)
	if not shown:
		QHProfiler.end(&"qh_custom/water4d/uniforms")
		return

	var b: Projection = camera.global_basis
	_material.set_shader_parameter(&"cam_position", camera.global_position)
	_material.set_shader_parameter(&"cam_basis_x", b.x)
	_material.set_shader_parameter(&"cam_basis_y", b.y)
	_material.set_shader_parameter(&"cam_basis_z", b.z)
	_material.set_shader_parameter(&"cam_basis_w", b.w)

	# The slice's horizontal frame, all in (x, z, w). The camera script keeps world up inside
	# the slice, which makes the w column purely horizontal, so it is exactly the direction
	# the slice cannot see along.
	var off := Vector3(b.w.x, b.w.z, b.w.w)
	off = off.normalized() if off.length() > 0.0001 else Vector3(0.0, 0.0, 1.0)
	# Line the grid up with where you are looking, so it follows the view smoothly instead of
	# snapping when some world axis stops being the best choice.
	var fwd := Vector3(-b.z.x, -b.z.z, -b.z.w)
	fwd -= off * fwd.dot(off)
	var axis_a: Vector3 = fwd.normalized() if fwd.length() > 0.0001 else _last_axis_a
	# Looking straight up or down leaves nothing to line up with; hold the last good one.
	if axis_a.length() < 0.0001:
		axis_a = _last_axis_a
	_last_axis_a = axis_a
	var axis_b: Vector3 = off.cross(axis_a).normalized()

	_material.set_shader_parameter(&"slice_axis_a", axis_a)
	_material.set_shader_parameter(&"slice_axis_b", axis_b)
	_material.set_shader_parameter(&"slice_axis_off", off)
	_material.set_shader_parameter(&"water_level", water_level)
	_material.set_shader_parameter(&"solve_iterations", solve_iterations)
	_material.set_shader_parameter(&"debug_jacobian", debug_jacobian)
	_material.set_shader_parameter(&"detail_strength", detail_strength)
	_material.set_shader_parameter(&"detail_time", _detail_time)
	_push_waves()
	QHProfiler.end(&"qh_custom/water4d/uniforms")


## The live wave set as flat arrays, with the Gerstner steepness constraint applied.
##
## THE CLAMP IS NOT OPTIONAL. Gerstner displacement with sum(Q k A) > 1 folds the surface
## through itself - the horizontal map stops being injective and the mesh ties knots. The
## presets are written to sit under it, but a blend passes through intermediate states that
## no preset describes, so it is enforced here every frame rather than trusted to the data.
func _push_waves() -> void:
	var dirs := PackedVector3Array()
	var amps := PackedFloat32Array()
	var numbers := PackedFloat32Array()
	var steeps := PackedFloat32Array()
	dirs.resize(MAX_WAVES)
	amps.resize(MAX_WAVES)
	numbers.resize(MAX_WAVES)
	steeps.resize(MAX_WAVES)
	var total: float = 0.0
	for i in range(MAX_WAVES):
		var w: Wave = _live[i]
		var k: float = TAU / maxf(w.wavelength, 0.1)
		dirs[i] = w.dir
		amps[i] = w.amplitude
		numbers[i] = k
		steeps[i] = w.steepness
		total += w.steepness * k * w.amplitude
	if total > 1.0:
		var scale: float = 1.0 / total
		for i in range(MAX_WAVES):
			steeps[i] *= scale
	_material.set_shader_parameter(&"wave_count", MAX_WAVES)
	_material.set_shader_parameter(&"wave_dir", dirs)
	_material.set_shader_parameter(&"wave_amp", amps)
	_material.set_shader_parameter(&"wave_number", numbers)
	_material.set_shader_parameter(&"wave_steep", steeps)
	_material.set_shader_parameter(&"wave_phase", _phase)
