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

const SHADER := preload("res://ramon/WaterLab/carried/water4d/water4d.gdshader")
const Presets := preload("res://ramon/WaterLab/carried/water4d/water4d_presets.gd")
const Wave := Presets.Wave

const MAX_WAVES := 8
const GRAVITY := 9.81
## Half-width of the grid, in metres, centred on the camera. The shader anchors it to the
## world, so this is "how far you can see water", not a position.
## Half-width of the water patch, in metres. 60 (a 120 m sea) is what the open-water test
## scene wants and stays the default, but a patch dropped into another scene has to STOP
## somewhere: in the Arboretum a 120 m sea centred on the annex reached back under the hall
## and the spawn point, so the floor had a sea running through it everywhere you stood.
##
## Set it before the node enters the tree; the mesh is built once in _ready.
var extent: float = EXTENT
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
## WATER LAB: the Gerstner look, 1 to 3 (water4d.gdshader gerstner_style); with solve_iterations 0 the
## Gerstner motion is off whichever it is.
var gerstner_style: int = 2
var water_level: float = 0.0
## Shrinks or grows the whole wave field. The presets are written for open sea - a 70 m swell
## in a 40 m room is one wave and reads as the floor tilting - so a pool wants about a fifth
## of that.
##
## AMPLITUDE AND WAVELENGTH SCALE TOGETHER, which keeps the steepness budget exactly where it
## was: the constraint is sum(Q k A), k goes as 1/scale while A goes as scale, so their
## product does not move. A scaled-down sea is the same sea seen smaller, not a flatter one.
var wave_scale: float = 1.0

## HOW CLEAR THE WATER IS, per metre and per channel. Beer-Lambert: what reaches you through
## `d` metres is `exp(-absorption * d)`. Red goes first, which is why anything deep reads
## blue-green and a pale floor turns the colour of the water rather than its own.
##
## The defaults are open-sea: murky enough that a few metres down is already gone, which is
## right for an ocean with nothing under it to see. A POOL WANTS CLEARER WATER AND LESS
## SCATTER, or the floor never shows and the depth cannot be read at all - see
## pool_room_4d.gd, which sets its own.
var absorption := Vector3(0.42, 0.11, 0.07)
## What the water sends back toward you, and how quickly that saturates with depth. Also the
## deep-sea colour, since at an infinite path length it is all that is left.
var scatter_color := Color(0.035, 0.175, 0.205)
var scatter_strength: float = 0.21
## HOW HARD THE SUN GLINTS OFF THE SURFACE, and how tight that glint is.
##
## Neither was reachable from outside before, which mattered: the shader's own 0.35 and 0.08
## put a white blow-out across the middle of any view that looks toward the sun at a shallow
## angle, and anything under the surface there - the pool's plesiosaur, in the case that
## found this - is simply lost in it. The specular is also summed over thousands of wavelets,
## so it piles up far beyond what the number suggests.
##
## Roughness is raised as the strength comes down. Dropping the strength alone leaves the
## same needle-sharp glints, only dimmer, which reads as the sun going behind a cloud; a
## broader, weaker highlight still says "water" while letting you see into it.
var specular_strength: float = 0.35
var roughness: float = 0.08
## Artistic trim on how hard the sea answers direct light. 1.0 is physically matched to the
## rest of the scene; see the note in water4d.gdshader, which had been double-applying albedo
## and skipping the 1/PI that Godot's own diffuse applies.
var light_response: float = 1.0

var _instance := RID()
## WATER LAB: the far ring, out to `far_extent` metres (0: none), drawn with the same material.
var far_extent: float = 0.0
var _far_instance := RID()
var _far_mesh: ArrayMesh = null
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

## THE PROFILER IS OPTIONAL, and has to be looked up rather than named.
##
## QHProfiler is an autoload, and it is declared only on branches that carry the perf tooling
## - res://perf/qh_profiler.gd is not on origin/RamonPrototypes at all. Naming it directly
## made this whole script fail to PARSE there, which takes the water surface with it: the sea
## simply never appears, with the real reason seven lines up the log under a pile of
## "Identifier not declared".
##
## A sandbox module has no business depending on another branch's tooling, so the profiler is
## resolved at runtime and the scopes are no-ops when it is absent.
var _profiler: Node = null


func _begin_scope(tag: StringName) -> void:
	if _profiler != null:
		_profiler.call(&"begin", tag)


func _end_scope(tag: StringName) -> void:
	if _profiler != null:
		_profiler.call(&"end", tag)


func _ready() -> void:
	_profiler = get_node_or_null(^"/root/QHProfiler")
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
	# Built a moment later: the scene's root sets far_extent in its own _ready, after this one's.
	_make_far.call_deferred()
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


func _make_far() -> void:
	if far_extent > extent and not _far_instance.is_valid():
		_far_mesh = _build_far_ring()
		_far_instance = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_far_instance, _far_mesh.get_rid())
		RenderingServer.instance_geometry_set_material_override(_far_instance, _material.get_rid())
		RenderingServer.instance_geometry_set_cast_shadows_setting(_far_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
		RenderingServer.instance_set_ignore_culling(_far_instance, true)
		RenderingServer.instance_set_custom_aabb(_far_instance, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
		RenderingServer.instance_set_visible(_far_instance, false)
		_scenario = RID()


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)
	if _instance.is_valid():
		RenderingServer.free_rid(_instance)
		_instance = RID()
	if _far_instance.is_valid():
		RenderingServer.free_rid(_far_instance)
		_far_instance = RID()


func _process(delta: float) -> void:
	_begin_scope(&"qh_custom/water4d/blend")
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
	_end_scope(&"qh_custom/water4d/blend")

	_begin_scope(&"qh_custom/water4d/phase")
	for i in range(MAX_WAVES):
		var k: float = TAU / maxf(_live[i].wavelength * maxf(wave_scale, 0.01), 0.1)
		# Deep water. The dispersion relation only involves |k|, so it is the same statement
		# in four dimensions as in three.
		_phase[i] = fposmod(_phase[i] + sqrt(GRAVITY * k) * delta, TAU)
	_detail_time = fposmod(_detail_time + delta * 0.06, 1024.0)
	_end_scope(&"qh_custom/water4d/phase")


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
	var step: float = (extent * 2.0) / float(GRID_RESOLUTION)
	for z in range(side):
		for x in range(side):
			verts[z * side + x] = Vector3(-extent + float(x) * step, 0.0,
					-extent + float(z) * step)
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


## WATER LAB: the far ring: a square annulus from just inside the near grid's edge out to `far_extent`,
## its lines spaced wider the further out (each about 13% beyond the last), a few centimetres lower so
## that where the two overlap the near grid's finer surface wins. The squares inside the near grid are
## left out. The shader places it the same way (round the camera) and fades its waves (near_extent).
func _build_far_ring() -> ArrayMesh:
	var inner: float = extent - 0.5
	var steps: int = 26
	var outer: Array = []
	for k in steps + 1:
		outer.append(inner * pow(far_extent / inner, float(k) / float(steps)))
	var coords: Array = []
	for k in range(steps, -1, -1):
		coords.append(-float(outer[k]))
	for k in range(1, 8):
		coords.append(lerpf(-inner, inner, float(k) / 8.0))
	for k in steps + 1:
		coords.append(float(outer[k]))
	var n: int = coords.size()
	var verts := PackedVector3Array()
	for j in n:
		for i in n:
			verts.append(Vector3(coords[i], -0.04, coords[j]))
	var indices := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var cx: float = (float(coords[i]) + float(coords[i + 1])) * 0.5
			var cz: float = (float(coords[j]) + float(coords[j + 1])) * 0.5
			if absf(cx) < inner and absf(cz) < inner:
				continue
			var a: int = j * n + i
			indices.append_array([a, a + n, a + 1, a + 1, a + n, a + n + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	return mesh


# --- per frame, just before the 4D engine draws ---------------------------------------------

func _on_pre_render(camera: Camera4D, viewport: Viewport, _engine: RenderingEngine4D) -> void:
	if viewport != get_viewport() or not _instance.is_valid():
		return
	_begin_scope(&"qh_custom/water4d/uniforms")
	var world: World3D = viewport.find_world_3d()
	var scenario: RID = world.scenario if world != null else RID()
	if scenario != _scenario:
		_scenario = scenario
		RenderingServer.instance_set_scenario(_instance, scenario)
		if _far_instance.is_valid():
			RenderingServer.instance_set_scenario(_far_instance, scenario)
	var shown: bool = is_visible_in_tree() and scenario.is_valid()
	RenderingServer.instance_set_visible(_instance, shown)
	if _far_instance.is_valid():
		RenderingServer.instance_set_visible(_far_instance, shown)
	_material.set_shader_parameter(&"near_extent", extent)
	if not shown:
		_end_scope(&"qh_custom/water4d/uniforms")
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
	_material.set_shader_parameter(&"gerstner_style", gerstner_style)
	_material.set_shader_parameter(&"debug_jacobian", debug_jacobian)
	_material.set_shader_parameter(&"detail_strength", detail_strength)
	_material.set_shader_parameter(&"detail_time", _detail_time)
	_material.set_shader_parameter(&"absorption", absorption)
	_material.set_shader_parameter(&"scatter_color", scatter_color)
	_material.set_shader_parameter(&"scatter_strength", scatter_strength)
	_material.set_shader_parameter(&"specular_strength", specular_strength)
	_material.set_shader_parameter(&"roughness_value", roughness)
	_material.set_shader_parameter(&"light_response", light_response)
	_push_waves()
	_end_scope(&"qh_custom/water4d/uniforms")


## The live wave set as flat arrays, with the Gerstner steepness constraint applied.
##
## THE CLAMP IS NOT OPTIONAL. Gerstner displacement with sum(Q k A) > 1 folds the surface
## through itself - the horizontal map stops being injective and the mesh ties knots. The
## presets are written to sit under it, but a blend passes through intermediate states that
## no preset describes, so it is enforced here every frame rather than trusted to the data.
## WATER LAB: the sea's height at a world point (x, z, w), as the shader draws it there (no detail
## noise, no far fade), for things that float: the fishing boat. Mirrors water4d.gdshader's
## wave_displacement and the fixed-point solve: which rest point lands on (x, z, w), then the summed
## heights at that rest point. Reads the live (blended) waves, so a preset change rocks it too.
func height_at(p: Vector3) -> float:
	if _live.is_empty():
		return water_level
	var size: float = maxf(wave_scale, 0.01)
	var steep_scale: float = 1.0 if solve_iterations > 0 else 0.0
	# The steepness clamp, as _push_waves applies it.
	var total: float = 0.0
	for i in range(MAX_WAVES):
		var w: Wave = _live[i]
		total += w.steepness * TAU / maxf(w.wavelength * size, 0.1) * w.amplitude * size
	var clamp_k: float = 1.0 / total if total > 1.0 else 1.0
	var rest: Vector3 = p
	var h: float = 0.0
	for it in maxi(solve_iterations, 0) + 1:
		var disp := Vector3.ZERO
		h = 0.0
		for i in range(MAX_WAVES):
			var w: Wave = _live[i]
			var k: float = TAU / maxf(w.wavelength * size, 0.1)
			var amp: float = w.amplitude * size
			var phase: float = k * w.dir.dot(rest) - _phase[i]
			disp += w.dir * (w.steepness * clamp_k * steep_scale * amp * cos(phase))
			h += amp * sin(phase)
		if it < maxi(solve_iterations, 0):
			rest = p - disp
	return water_level + h


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
	var size: float = maxf(wave_scale, 0.01)
	for i in range(MAX_WAVES):
		var w: Wave = _live[i]
		var k: float = TAU / maxf(w.wavelength * size, 0.1)
		dirs[i] = w.dir
		amps[i] = w.amplitude * size
		numbers[i] = k
		steeps[i] = w.steepness
		total += w.steepness * k * w.amplitude * size
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
