@tool
extends Node4D
## Builds a volumetric 4D world by compositing signed-density layers, dual
## contouring the result, and handing the tetrahedra to two [MeshInstance4D]
## children (opaque ground and transparent water) plus optional collision.
##
## This is the port of the reference WebGL demo's pipeline onto Godot 4D. The
## demo's other half - slicing the 4D mesh down to a 3D cross-section in a
## vertex shader - is not ported because the engine already does exactly that
## in render/cross_section/tetra_cross_section_shader.glsl, by the same
## method. So the whole cost here is generation, paid once, and thereafter
## rotating through 4D is five uniform updates per frame.
##
## [b]Unlike[/b] the height-field generator in project/ramon/VoxelIsland/, this does
## not regenerate on every property change. A size^4 grid at size 14 is ~38k
## points and ~154k candidate edges, which is seconds of GDScript rather than
## milliseconds - auto-regenerating would make the inspector unusable. Set up
## the parameters, then press Generate.

const _SCRIPT_PATH_HINT := "res://ramon/voxel_port/scripts/"

## Hard ceiling on grid size. _generate_brick()/_process() now cull chunks by
## distance and 4D-slice membership instead of submitting every tetrahedron
## to the renderer every frame regardless of visibility - that WAS the
## reason for the old, much lower ceiling (see
## cross_section_rendering_engine_4d.cpp's own instance_set_ignore_culling
## call, which is why frustum culling can't just be turned back on instead),
## and it worked: a real scale-test run held a steady 60fps at every size
## tried, right up to the point generation itself became the blocker.
##
## That's the OTHER cost this raise does nothing about: VoxelField4D +
## MultiVertexDualContour4D scale as size^4 in memory and roughly size^3 in emitted
## geometry, paid once per Generate press, independent of how the result is
## later chunked for rendering, and it dominates. Measured on this machine:
## size 12 (the default below) took 8.4s to generate - already close to
## unusable for an interactive "press Generate and wait" workflow - and size
## 14 took 15.5s, so the ceiling actually worth exposing here is barely above
## the default. 16 leaves one small step of headroom for a slower generate
## while keeping the Inspector honest that pushing further into this range
## risks a real wait, not a free win the way the render-side fix was.
## Meaningfully bigger worlds need the generation cost itself addressed
## (e.g. threaded/incremental generation, the way VoxelWorld4D's
## process_regeneration_async() already does elsewhere in this project) -
## that's a bigger change than this one, not something to paper over by
## raising a constant.
const MAX_GRID_SIZE := 512

## Grid points per axis. 12-14 was the sweet spot before per-chunk culling
## existed (see MAX_GRID_SIZE's own comment for why) - kept as the default
## for a quick first look, but no longer close to the practical ceiling.
const BASELINE_GRID_SIZE := 12

## Model layer bits. The values matter: layers are composited in ascending bit
## order, so the bit order [b]is[/b] the layer order and no separate sort is
## needed. Water first so terrain can replace it where they overlap, solids
## next, and the carving layers last - a carve listed before a solid would just
## get filled back in.
##
## This is the one thing a checkbox list would otherwise lose compared to the
## reference demo's ordered comma-separated string, and encoding the order into
## the bits means it cannot be got wrong rather than merely being documented.
const MODEL_GLOBE_WATER := 1 << 0
const MODEL_PLANE_WATER := 1 << 1
const MODEL_GLOBE := 1 << 2
const MODEL_PLANE := 1 << 3
const MODEL_HYPERCUBE := 1 << 4
const MODEL_24CELL := 1 << 5
const MODEL_SPHERINDER := 1 << 6
const MODEL_CUTOFF := 1 << 7
## Carves away everything more than max_depth_below_water grid units on the
## far side of "down" from the water/ground reference level - see
## max_depth_below_water's own comment. Ordering relative to cutoff doesn't
## matter - both are pure AIR carves, and carving already-AIR space twice is
## a no-op (VoxelField4D._can_replace rejects same-material "replacement").
const MODEL_SEAFLOOR := 1 << 8
## A tube following a parametric arch through 4D - see arch_* exports and
## _add_model_layer's "arch" branch for the actual curve.
const MODEL_ARCH := 1 << 9

## Bit index -> the name [method _add_model_layer] dispatches on. Must stay in
## the same order as the bits above and as the @export_flags hint.
const _MODEL_LAYER_NAMES: Array[String] = [
	"globewater",
	"planewater",
	"globe",
	"plane",
	"hypercube",
	"24cell",
	"spherinder",
	"cutoff",
	"seafloor",
	"arch",
]

const BASELINE_MODEL_LAYERS := MODEL_GLOBE_WATER | MODEL_GLOBE | MODEL_CUTOFF
const BASELINE_CELL_SIZE := 4.0
const BASELINE_NOISE_FREQUENCY := 0.12
const BASELINE_FRACTAL_OCTAVES := 3
const BASELINE_TERRAIN_SEED := 1

## How far to step when differencing the noise field for its gradient, in grid
## cells. The analytic models below (spheres, planes, hypercubes) supply exact
## gradients; only the noise term needs differencing, so this error is confined
## to the one term that has it rather than contaminating the whole surface
## normal the way differencing the composite density would.
const NOISE_GRADIENT_EPSILON := 0.01

## Normals from the noisy terrain layers are scaled down relative to the
## analytic ones. [QEFSolver4D] weights each crossing by its normal's
## magnitude, so this says "trust the exact sphere/plane boundary more than
## the noisy one when they meet in the same cell" - which stops noise from
## dragging an otherwise crisp shoreline off the analytic surface.
const NOISY_LAYER_CONFIDENCE := 0.5
const ANALYTIC_LAYER_CONFIDENCE := 1.0

## Edge length of the generated (slope, altitude) colour palette. 32 is plenty
## - it is sampled with linear filtering and the underlying gradient is smooth,
## so a larger texture would only store interpolation the GPU does for free.
const PALETTE_RESOLUTION := 32

enum TerrainShape {
	## Up is +Y everywhere; altitude is height above the mid-plane.
	PLANAR,
	## Up is radially outward from the grid center; altitude is distance from
	## it. This is what makes a hypersphere world shade correctly - "up" is a
	## different direction at every point on it.
	RADIAL,
}

@export_tool_button("Generate") var _generate_action: Callable = generate
@export_tool_button("Randomize Seed and Generate") var _randomize_action: Callable = randomize_and_generate
@export_tool_button("Clear") var _clear_action: Callable = clear

@export_group("Grid")
## Grid points per axis. The field is grid_size^4 points.
@export_range(4, MAX_GRID_SIZE, 1) var grid_size: int = BASELINE_GRID_SIZE
## World size of one grid cell, in meters. Total world footprint is
## grid_size * cell_size across each axis.
@export_range(0.25, 32.0, 0.25, "or_greater", "suffix:m") var cell_size: float = BASELINE_CELL_SIZE

@export_group("Model")
## Which layers to composite, ticked in the inspector. They are applied top to
## bottom in the order listed, which is also the order that makes sense - so
## the ordering trap the reference demo's comma-separated string has (put
## [code]cutoff[/code] first and it gets filled straight back in) cannot happen
## here.
##
## Combinations worth trying:
## [br]- Globe Water + Globe + Cutoff: an ocean planet (the default)
## [br]- Plane Water + Plane + Spherinder + Cutoff: the column from the
##   reference demo's own screenshot - set Terrain Shape to Planar and raise
##   Noise Amplitude Fraction to 0.4 to match it
## [br]- Hypercube + Cutoff, or 24-Cell + Cutoff: sharp-edge preservation on
##   its own, with no noise to hide behind
@export_flags("Globe Water", "Plane Water", "Globe", "Plane", "Hypercube", "24-Cell", "Spherinder", "Cutoff", "Seafloor", "Arch")
var model_layers: int = BASELINE_MODEL_LAYERS:
	set(value):
		model_layers = value
		update_configuration_warnings()
@export var terrain_seed: int = BASELINE_TERRAIN_SEED
## Only used when Seafloor is ticked above. Grid units below the water/ground
## reference level (plane_height for a plane world, the ground radius for a
## globe) that stay solid rock/water before Seafloor carves the rest away to
## AIR. Small values mean a shallow world - all the interesting terrain sits
## close to the surface, with none of the deep "empty ocean floor" volume a
## plain cutoff box leaves in place below the waterline (that volume still
## costs real generation time and mesh memory even though it's rarely worth
## looking at - see MAX_GRID_SIZE's own comment on where that cost goes).
@export_range(1.0, 64.0, 0.5, "or_greater") var max_depth_below_water: float = 6.0

## Arch: a tube of ground following a parametric path that rises from the
## ground plane, sweeps through BOTH y and w on the way up, and comes back
## down to the ground plane somewhere else in the scene - a shape that
## cannot be flattened into an ordinary 3D arch without self-intersecting,
## which is the point of it: sliced through w=0 at different rig rotations,
## the arch appears to emerge from and vanish back into the ground as it
## sweeps through the fourth axis, instead of just sitting there like an
## ordinary bridge would.
@export_range(0.0, 1.0, 0.01) var arch_start_fraction := 0.2
@export_range(0.0, 1.0, 0.01) var arch_end_fraction := 0.8
@export_range(1.0, 64.0, 0.5, "or_greater") var arch_height: float = 10.0
@export_range(0.0, 64.0, 0.5, "or_greater") var arch_w_amplitude: float = 8.0
@export_range(0.5, 8.0, 0.1, "or_greater") var arch_radius: float = 1.5

@export_group("Noise")
@export_range(0.01, 1.0, 0.001, "or_greater") var noise_frequency: float = BASELINE_NOISE_FREQUENCY
@export_range(1, 8, 1) var fractal_octaves: int = BASELINE_FRACTAL_OCTAVES
@export_range(0.0, 1.0, 0.01) var fractal_gain: float = 0.5
## Noise height as a fraction of grid size. The reference demo uses 0.2 for
## the globe and 0.4 for the plane; this is applied to whichever is active.
##
## [b]Interacts with [code]cutoff[/code].[/b] The globe sits at radius
## 0.35 * grid_size and noise pushes peaks out to (0.35 + this) * grid_size,
## while [code]cutoff[/code] seals the world at an axis-aligned box whose
## nearest face is (grid_size / 2 - 1.1) from the globe's centre. Peaks past
## that get shaved flat against the boundary, which reads as suspiciously
## rectangular patches on the highest ground. Clipping is avoided when:
##
##     noise_amplitude_fraction <= 0.15 - 1.1 / grid_size
##
## which is ~0.058 at grid_size 12, ~0.095 at 20, ~0.104 at 24. The default of
## 0.2 is therefore over that line at every usable grid size - deliberately so,
## since the reference demo's own defaults clip the same way and the flat spots
## only appear where fBm actually approaches its extremes, which is rare. Lower
## it if you want a guaranteed-round planet; raise grid_size if you want tall
## peaks and no clipping, since the bound relaxes as the grid grows.
@export_range(0.0, 1.0, 0.01) var noise_amplitude_fraction: float = 0.2
## Reshapes the combined noise (base + optional detail/cellular layers below)
## through [code]sign(n) * abs(n)^power[/code] before it's used as density.
## Values above 1 flatten gentle mid-range variation into wide, smooth
## basins and domes while leaving sharp extremes alone - a "rolling hills"
## look. Values below 1 do the opposite: they exaggerate mid-range variation,
## which reads as more uniformly jagged/spiky terrain. 1.0 leaves the raw
## noise unchanged. This is the knob a single fractal-noise call has no way
## to express - raising fractal_octaves adds more detail at a FIXED
## frequency ratio between octaves, it can't independently flatten or
## sharpen the result the way a post-hoc power curve can.
@export_range(0.2, 4.0, 0.05) var noise_smoothing_power: float = 1.0
## Adds a second, independently-configured fractal noise layer at a
## different frequency on top of the base one. Two well-separated
## frequencies (a broad base shape plus a much finer detail pass) read as
## far more natural terrain than pushing one single fractal call's own
## octave count higher, which only adds more of the SAME frequency ratio
## rather than a genuinely different scale of feature.
@export var detail_noise_enabled: bool = false
@export_range(1.0, 32.0, 0.5, "or_greater") var detail_noise_frequency_multiplier: float = 6.0
@export_range(0.0, 1.0, 0.01) var detail_noise_amplitude_fraction: float = 0.25
## A cellular (Voronoi) noise layer, added on top of the fractal base(s).
## Cellular noise's sharp cell boundaries read as rocky/cracked detail,
## which plain fractal simplex noise - continuous and smooth by
## construction - has no way to produce on its own.
@export var cellular_noise_enabled: bool = false
@export_range(0.01, 1.0, 0.001, "or_greater") var cellular_noise_frequency: float = 0.3
@export_range(0.0, 1.0, 0.01) var cellular_noise_amplitude_fraction: float = 0.2

@export_group("Appearance")
## Which way is "up", for slope shading and altitude banding. Set this to
## match the model - RADIAL for globe worlds, PLANAR for plane worlds.
@export var terrain_shape: TerrainShape = TerrainShape.RADIAL:
	set(value):
		terrain_shape = value
		update_configuration_warnings()
## Optional. When set, colouring switches from per-cell to a 3D texture
## indexed by (slope, altitude, material) - the reference demo's trick, which
## gets cliff/grass/snow banding out of a single lookup. When null, the
## equivalent colours are computed per tetrahedron in GDScript instead.
@export var albedo_texture_3d: Texture3D = null
@export var water_color: Color = Color(0.1, 0.25, 0.6, 0.75)
## Flip if the terrain renders inside-out - see [member MultiVertexDualContour4D.flip_winding].
@export var flip_winding: bool = false

@export_group("Physics")
## Builds a [ConcaveMeshShape4D] from the ground tetrahedra.
##
## [b]This does not currently give you terrain-shaped collision.[/b] The only
## physics engine the module ships is [code]AxisAlignedBoxPhysicsEngine4D[/code],
## whose own header states: "Non-BoxShape4D shapes will work, but will be
## converted to boxes." Every collision shape is reduced to a single [Rect4]
## bounding box, so all ~20,000 tetrahedra collapse into one box spanning the
## whole world - you can stand on its lid and walk off its edges, and it lines
## up with the terrain nowhere except by accident.
##
## Off by default for that reason: the resulting box is not merely useless but
## actively misleading, an invisible crate around the whole world that stops
## you walking up to the terrain you can plainly see. The ObservationFloor in
## voxel_port.tscn is a real BoxShape4D, which the AABB engine handles exactly,
## and is what you actually stand on.
##
## The code is kept, and kept as a mesh shape rather than a hand-made box,
## because the shape itself is correct and costs under a second to build - so
## it starts working the day the module gains a non-AABB engine, with no
## changes needed here. Turning it on today only makes sense for measuring
## generation cost.
@export var generate_collision: bool = false

@export_group("Culling")
## Path to the Camera4D to cull against. Both cull tests below need to know
## where the viewer actually is - without this wired up, every chunk is
## treated as always-visible (see _process's own null guard), which is a
## silent no-op fallback rather than a hard error, so an unwired scene keeps
## working exactly as before this feature existed.
@export var camera_path: NodePath
## The node whose global_basis carries the 4D "rotate the object" gesture
## (this project's right-drag rig rotation convention) - defaults to this
## Terrain node itself, since here the terrain IS the object being oriented,
## not a large world the camera moves through.
@export var rig_path: NodePath
@export_range(10.0, 4000.0, 1.0, "or_greater", "suffix:m") var max_render_distance: float = 400.0

## Cells per brick, along each axis - a brick is both the streaming unit
## (generated independently, on demand) and the culling unit (one
## MeshInstance4D pair, exactly matching what CHUNK_SIZE_GRID_UNITS used to
## define by post-hoc bucketing a single monolithic contour). An @export
## rather than a constant because this is a genuine tuning knob, not a fixed
## property of the algorithm the way BRICK_PAD is: smaller bricks mean
## finer-grained streaming/culling but pay BRICK_PAD's overlap overhead more
## times per unit of real geometry (measured: at 8, an 80m streaming radius
## needed 176 bricks and ~2.58M total field points; at 16, the same radius
## needed far fewer, larger bricks and ~1.4M total field points - padding
## overhead falls off fast as bricks grow); bigger bricks amortize that
## overhead better but make the streaming radius coarser and each individual
## brick's own generate call heavier (worse for spreading work across
## frames/threads, and coarser for the volumetric-edit tool this will need
## to support later).
@export_range(2, 64, 1) var BRICK_CORE_CELLS := 8

## Extra points of margin generated on every side of a brick's own core, past
## which its geometry is discarded rather than emitted (see _generate_brick).
##
## Needed because MultiVertexDualContour4D deliberately leaves a cell's hexahedra
## incomplete - and therefore that cell's own vertices unemitted - whenever
## any of the 8 cells that would need to surround its crossings falls outside
## the field ("Edges missing part of their ring sit on the outermost layer of
## the grid" - dual_contour_4d.gd's own comment on _build_hexahedra). Without
## this margin, EVERY brick's own outermost ring of cells would be silently
## dropped as "incomplete", not just its true boundary - producing a visible
## gap between every pair of adjacent bricks, since neither one would have
## generated the cells nearest their shared face. One point of margin gives
## every core cell the full ring of neighbours - at most one cell away along
## any of the 3 non-edge axes for any of its own crossings - it could ever
## need, so nothing genuinely inside the core gets discarded as incomplete.
const BRICK_PAD := 1

## Set while [method _reset_defaults] reassigns exported values, so nothing
## tries to regenerate mid-reset.
var _suppress_regenerate := false

## Brick key (Vector4i, in brick-grid coordinates - world cell index /
## BRICK_CORE_CELLS) -> MeshInstance4D. A brick IS a culling chunk now: each
## one is generated from its own independent VoxelField4D/MultiVertexDualContour4D pass
## (see _generate_brick), so there is no separate post-hoc partitioning step
## the way CHUNK_SIZE_GRID_UNITS used to require.
var _ground_chunks: Dictionary = {}
var _water_chunks: Dictionary = {}
## Brick key -> {min: Vector4, max: Vector4}, world-space (post cell_size/
## center transform) - the AABB both cull tests below check against. Shared
## between a brick's ground and water meshes since they come from the same
## grid region.
var _chunk_bounds: Dictionary = {}
## Brick key -> true for every brick _generate_brick has already processed,
## including ones that produced no geometry at all (pure air, or pure
## padding overlap with a neighbour) - so streaming never re-attempts a
## brick that has already been decided, without needing every decided brick
## to also have a mesh.
var _generated_bricks: Dictionary = {}
## Set once per generate() call, then read by every later _generate_brick
## call - including the ones _stream_bricks_near_camera() triggers on demand,
## long after generate() itself has returned. selected_model_names() and
## grid_size could be re-read live instead, but that would mean a brick
## streamed in halfway through the player changing the inspector's model
## flags could disagree with every brick already generated under the old
## ones - freezing both for the duration of one generate() "session" is what
## keeps a world self-consistent while it streams.
var _active_model_names: PackedStringArray = []
var _nominal_size: int = 0
var _nominal_center: float = 0.0
## Bumped at the start of every generate() call and stamped onto every brick
## task requested under it (see _request_brick/_finish_brick). WorkerThreadPool
## has no cancel API, so a task requested by a generate() session that has
## since been superseded (Generate pressed again, Randomize Seed pressed
## mid-stream) cannot be stopped - it is instead left to finish and then
## silently discarded, rather than corrupting the new session by building a
## brick from the OLD parameters into what is now a different world.
var _generation_session_id := 0

## Standing volumetric edits, applied in order on top of the base model
## layers every time ANY brick (re)generates - see edit_sphere() and
## _add_edit_layer(). Each entry is {"is_add": bool, "center": Vector4 (grid
## coordinates), "radius": float (grid units)}. Grows for the lifetime of one
## generate() session; cleared by generate() along with everything else.
var _edit_operations: Array = []

## WorkerThreadPool task id -> brick key, for tasks currently running (or
## finished but not yet reaped) on a background thread. _compute_brick_geometry
## does the entire VoxelField4D/MultiVertexDualContour4D/QEF pass off-thread - none of it
## touches the scene tree, RenderingServer, or PhysicsServer, so it is safe to
## run concurrently with the main thread's own work; only _finish_brick (the
## MeshInstance4D/ArrayTetraMesh4D creation) needs the main thread, since that
## does touch the render server. This is the same split this project's own
## VoxelWorld4D.process_regeneration_async() already established: a worker
## touches only its own private data, and anything that creates an engine
## resource or touches a server happens back on the calling thread once the
## job is confirmed done.
var _pending_brick_tasks: Dictionary = {}
## Brick key -> Dictionary, the result_slot each in-flight task writes its
## output into once done (see _compute_brick_geometry). A Dictionary is a
## reference type in GDScript, so the worker thread mutating it and the main
## thread later reading it is safe PROVIDED the read only happens after
## WorkerThreadPool.is_task_completed() confirms the task is done - that call
## is what establishes the happens-before edge between the two threads.
var _bricks_in_flight: Dictionary = {}
## Caps concurrent in-flight brick tasks. WorkerThreadPool's own pool size
## already bounds true parallelism, but without this a big streaming radius
## could queue hundreds of tasks in a single frame, each one holding its own
## VoxelField4D/MultiVertexDualContour4D allocation alive until collected - this bounds
## peak memory from queued-but-not-yet-run work, not just peak CPU.
const MAX_CONCURRENT_BRICK_TASKS := 8

## How far past max_render_distance (as a multiple of it) a brick has to
## drift before _update_chunk_visibility evicts it outright - see that
## function's own comment for why this exists and why it isn't 1.0.
const EVICTION_MARGIN_MULTIPLIER := 3.0

## Set by a deliberate bake (see bake_to_file()'s own callers) to disable
## eviction entirely while a fixed region is being populated and held for
## serialization. Eviction exists for LIVE PLAY, where the camera actually
## moves and "far away" is a meaningful, permanent judgement - during a bake
## the camera is often just sitting wherever the scene file's own defaults
## left it, unrelated to the region actually being generated, which measured
## out as a genuine, serious bug: bricks near the eviction boundary cycled
## generate -> evict -> re-request -> generate forever, never converging,
## for 30+ minutes, until the sustained rate of creating and freeing
## MeshInstance4D/ArrayTetraMesh4D nodes crashed the renderer outright
## rather than merely running slowly. A bake calling generate() and then
## waiting for it to "settle" has no use for eviction anyway - it WANTS
## everything it just asked for to stick around long enough to serialize.
var suppress_eviction: bool = false

## Set by a demo/preview session that loaded a bake and wants EXACTLY the
## baked bricks, instantly, with no further generation - a wider camera view
## than the bake's own max_render_distance would otherwise trigger
## _stream_bricks_near_camera() to live-generate everything beyond the baked
## region on demand, which pays the full noise+layer cost per brick (seconds
## each, not milliseconds) and defeats the entire point of loading a bake:
## instant interaction. Purely a gate on requesting NEW bricks - editing,
## orbiting, and 4D-rotating the ones already loaded are untouched.
var freeze_streaming: bool = false

## Frame counter for _stream_bricks_near_camera()'s throttle - see
## STREAM_SCAN_INTERVAL_FRAMES.
var _stream_frame_counter := 0
## How often (in frames) _process() re-scans for not-yet-generated bricks
## near the camera. Every frame would mean re-walking the whole candidate
## brick range - itself proportional to (radius / BRICK_CORE_CELLS)^4 - just
## to find that almost all of it is already generated; a quarter-second
## response time to camera movement costs far less and is not something a
## player can perceive as lag on a streaming world.
const STREAM_SCAN_INTERVAL_FRAMES := 15
## One material per generate() call, shared across every chunk instead of
## _build_mesh's own default of building a fresh TetraMaterial4D (and, for
## ground, rebuilding the palette texture) every time it's called - with
## potentially hundreds of chunks now instead of one mesh, doing that per
## chunk would make regeneration far slower for no visual difference, since
## every chunk of the same type is visually identical material anyway.
var _ground_material: TetraMaterial4D
var _water_material: TetraMaterial4D

## Live culling stats, read by the perf HUD - see _process().
var _visible_chunk_count := 0
var _total_chunk_count := 0
var _visible_tet_count := 0
var _total_tet_count := 0

var _last_stats := {}
## Whether meshes existed when an editor save began, so the post-save rebuild
## only fires for scenes that actually had generated terrain.
var _had_meshes_before_save := false


## Builds the terrain as soon as the scene loads, in the editor as well as at
## runtime, so opening the scene shows the world rather than an empty node.
##
## Checks child count rather than `ground.mesh == null` - ground_instance's
## own .mesh is never assigned now (see _generate_brick), only its brick
## CHILDREN carry meshes, so a mesh==null check would be true even right
## after a real generate() and cause this to regenerate on every _ready().
func _ready() -> void:
	var ground: MeshInstance4D = _get_ground_instance()
	if ground != null and ground.get_child_count() == 0:
		generate()


## Per-frame chunk visibility cull - the only thing this adds beyond what
## generate() already built. Two independent tests, either one true means
## skip: distance from the viewer, and whether the chunk's world-space AABB
## can even geometrically cross the camera's current 4D slice at all (see
## _straddles_slice's own comment - a tet only emits cross-section geometry
## when its own corners straddle the slice, so a chunk whose entire extent
## sits on one side of it contributes zero geometry regardless of distance).
## Guarded to skip entirely in the editor - this is a live-camera concern,
## meaningless while just previewing Generate's output in the inspector.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_chunk_visibility()
	_poll_brick_tasks()

	_stream_frame_counter += 1
	if not freeze_streaming and _stream_frame_counter >= STREAM_SCAN_INTERVAL_FRAMES:
		_stream_frame_counter = 0
		_stream_bricks_near_camera()


## Reaps every background brick task that has finished since the last frame
## and hands its result to _finish_brick for the main-thread-only half of the
## work (building the actual MeshInstance4D/ArrayTetraMesh4D). Cheap even
## with many bricks in flight - is_task_completed() is a quick poll, not a
## wait, so a brick that's still computing costs nothing here until it's done.
func _poll_brick_tasks() -> void:
	if _pending_brick_tasks.is_empty():
		return
	var finished_task_ids: Array = []
	for task_id in _pending_brick_tasks:
		if WorkerThreadPool.is_task_completed(task_id):
			finished_task_ids.append(task_id)
	for task_id in finished_task_ids:
		var bk: Vector4i = _pending_brick_tasks[task_id]
		# Already completed (that's what the loop above just checked) - this
		# only reaps the task's internal bookkeeping, it does not block.
		WorkerThreadPool.wait_for_task_completion(task_id)
		_pending_brick_tasks.erase(task_id)
		var result_slot: Dictionary = _bricks_in_flight[bk]
		_bricks_in_flight.erase(bk)
		_finish_brick(bk, result_slot)

	# Print once whenever the queue fully drains, rather than once per
	# generate() call the way the old synchronous version did - streaming
	# means more batches can start (see _stream_bricks_near_camera) long
	# after the original generate() call already returned, each with its own
	# "caught up" moment worth reporting.
	if _pending_brick_tasks.is_empty():
		_print_stats()


## Returns [camera, rig, viewer_position (camera's position in the rig's own
## local space)], or an empty array if camera_path isn't wired up. Shared by
## _update_chunk_visibility (every frame) and _stream_bricks_near_camera
## (throttled) - both need the identical world-to-rig-local conversion this
## project's terrain4d_voxel_showcase.gd established, needed because the rig
## (here, this Terrain node itself by default) is what carries the 4D
## right-drag rotation, while the camera does not.
func _get_viewer_state() -> Array:
	var camera: Camera4D = get_node_or_null(camera_path) as Camera4D
	if camera == null:
		return []
	var rig: Node4D = (get_node_or_null(rig_path) as Node4D) if not rig_path.is_empty() else self
	var inverse_basis: Projection = rig.global_basis.inverse()
	var viewer_position: Vector4 = inverse_basis * (camera.global_position - rig.global_position)
	return [camera, rig, viewer_position]


## Generates any not-yet-streamed brick within max_render_distance of the
## camera's current position - the counterpart to _update_chunk_visibility's
## per-frame HIDE/SHOW decision, but for bricks that do not exist to hide or
## show yet. Together they are what makes grid_size a nominal world extent
## rather than something paid for in full on every generate() press: a
## world many times max_render_distance across costs the same to walk into
## as one exactly max_render_distance across, because only the bricks the
## camera has actually gotten close to are ever built.
func _stream_bricks_near_camera() -> void:
	if _active_model_names.is_empty():
		return # No generate() session active yet - nothing to stream against.
	var viewer_state: Array = _get_viewer_state()
	if viewer_state.is_empty():
		return
	var viewer_position: Vector4 = viewer_state[2]
	_stream_bricks_in_radius(viewer_position, max_render_distance, _nominal_center)


func _update_chunk_visibility() -> void:
	var viewer_state: Array = _get_viewer_state()
	if viewer_state.is_empty():
		# No camera wired up - fall back to "everything visible", the exact
		# behavior before this feature existed, rather than silently hiding
		# a scene that hasn't wired camera_path yet.
		for chunk in _ground_chunks.values():
			(chunk as MeshInstance4D).visible = true
		for chunk in _water_chunks.values():
			(chunk as MeshInstance4D).visible = true
		_visible_chunk_count = _total_chunk_count
		_visible_tet_count = _total_tet_count
		return

	var camera: Camera4D = viewer_state[0]
	var rig: Node4D = viewer_state[1]
	var viewer_position: Vector4 = viewer_state[2]
	var inverse_basis: Projection = rig.global_basis.inverse()
	var rig_pos: Vector4 = rig.global_position
	# ana_offset direction (bearing_utility_4d.gd's own formula,
	# ana_offset = rel.dot(observer_basis.w)) expressed in rig-local space -
	# see _straddles_slice for the projection this feeds.
	var slice_w_dir_local: Vector4 = inverse_basis * camera.global_basis.w
	var slice_base_offset: float = (rig_pos - camera.global_position).dot(camera.global_basis.w)

	var dist_sq: float = max_render_distance * max_render_distance
	# Bricks this far past max_render_distance get EVICTED (freed and
	# forgotten, see _discard_brick) rather than merely hidden - without
	# this, wandering a live-streamed world far enough in one direction
	# accumulates every brick ever generated forever, since nothing ever
	# frees them. That is not a hypothetical: a long exploration session hit
	# the engine's own out-of-memory error, not just a slowdown. The margin
	# above max_render_distance itself matters - evicting the instant
	# something crosses out of rendering range would mean constantly
	# regenerating a brick a player is hovering right at the visibility
	# boundary of, trading a memory problem for a CPU one.
	var eviction_dist_sq: float = pow(max_render_distance * EVICTION_MARGIN_MULTIPLIER, 2.0)
	_visible_chunk_count = 0
	_visible_tet_count = 0
	for key in _chunk_bounds.keys():
		var bounds: Dictionary = _chunk_bounds[key]
		var lo: Vector4 = bounds.min
		var hi: Vector4 = bounds.max
		var chunk_center: Vector4 = (lo + hi) * 0.5
		var chunk_dist_sq: float = chunk_center.distance_squared_to(viewer_position)
		if not suppress_eviction and chunk_dist_sq > eviction_dist_sq:
			_discard_brick(key)
			continue
		var in_range: bool = chunk_dist_sq <= dist_sq
		var visible: bool = in_range and _straddles_slice(lo, hi, slice_w_dir_local, slice_base_offset)
		if _ground_chunks.has(key):
			(_ground_chunks[key] as MeshInstance4D).visible = visible
		if _water_chunks.has(key):
			(_water_chunks[key] as MeshInstance4D).visible = visible
		if visible:
			_visible_chunk_count += 1
			# Both ground and water chunks at this key count toward the
			# visible tet estimate shown in the HUD - an approximation (uses
			# each chunk's ORIGINAL tet count, not a live recount), good
			# enough for a stats display.
			var ground_node: MeshInstance4D = _ground_chunks.get(key)
			if ground_node != null and ground_node.mesh != null:
				_visible_tet_count += (ground_node.mesh as ArrayTetraMesh4D).simplex_cell_indices.size() / 4
			var water_node: MeshInstance4D = _water_chunks.get(key)
			if water_node != null and water_node.mesh != null:
				_visible_tet_count += (water_node.mesh as ArrayTetraMesh4D).simplex_cell_indices.size() / 4


## Exact rotated-AABB support-point test: true if [lo, hi] (a chunk's
## world-space AABB) has at least one point on each side of the camera's 4D
## slice plane - i.e. this chunk's tets could genuinely produce cross-
## section geometry. False means every corner of this box projects to the
## same side, so submitting it to the renderer at all is provably wasted -
## ported directly from this project's own TerrainChunkPool4D
## (slice_w_dir_local/slice_base_offset), which measured this cutting
## submitted tets by ~66% on the height-field terrain it was built for.
func _straddles_slice(lo: Vector4, hi: Vector4, w_dir_local: Vector4, base_offset: float) -> bool:
	var min_proj := 0.0
	var max_proj := 0.0
	for axis in range(4):
		var d: float = w_dir_local[axis]
		var lo_a: float = lo[axis]
		var hi_a: float = hi[axis]
		if d >= 0.0:
			min_proj += d * lo_a
			max_proj += d * hi_a
		else:
			min_proj += d * hi_a
			max_proj += d * lo_a
	var min_ana: float = min_proj + base_offset
	var max_ana: float = max_proj + base_offset
	return min_ana <= 0.0 and max_ana >= 0.0


## Keeps the generated meshes out of the saved [code].tscn[/code].
##
## The meshes are ordinary resources assigned to an exported property, so Godot
## would happily serialize all ~28,000 tetrahedra into the scene file - the
## height-field test scene next door is 1.6 MB for exactly this reason, and
## this one would be far worse. Since everything here is reproducible from the
## exported parameters plus the seed, storing it is pure cost. Dropping the
## meshes immediately before a save and rebuilding right after keeps the scene
## file at a couple of hundred bytes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Background brick tasks (see _compute_brick_geometry) call instance
		# methods - _add_model_layer, _noise_value, etc. - on this very node.
		# If this node is freed while one is still running on its
		# WorkerThreadPool thread, that call lands on a freed object and
		# errors ("Nonexistent function ... in base 'previously freed'"),
		# reproduced by closing a running scene while streaming was still
		# in flight. Blocking here until every pending task has actually
		# finished is what makes freeing this node safe regardless of what
		# streaming was doing at the time.
		for task_id in _pending_brick_tasks.keys():
			WorkerThreadPool.wait_for_task_completion(task_id)
		return
	if not Engine.is_editor_hint():
		return
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			_had_meshes_before_save = _get_ground_instance() != null and _get_ground_instance().mesh != null
			clear()
		NOTIFICATION_EDITOR_POST_SAVE:
			if _had_meshes_before_save:
				generate()


func _get_ground_instance() -> MeshInstance4D:
	return get_node_or_null("Ground") as MeshInstance4D


func _get_water_instance() -> MeshInstance4D:
	return get_node_or_null("Water") as MeshInstance4D


func _get_collision_shape() -> CollisionShape4D:
	return get_node_or_null("StaticBody4D/CollisionShape4D") as CollisionShape4D


## The ticked layers, in composite order. Ascending bit order is the layer
## order by construction (see the MODEL_* constants), so this needs no sort.
func selected_model_names() -> PackedStringArray:
	var names := PackedStringArray()
	for bit in range(_MODEL_LAYER_NAMES.size()):
		if (model_layers & (1 << bit)) != 0:
			names.append(_MODEL_LAYER_NAMES[bit])
	return names


## Surfaces the configuration mistakes that are otherwise silent - they produce
## terrain that generates without error and simply looks wrong, which is far
## more expensive to notice than a failed build.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if model_layers == 0:
		warnings.append("No model layers selected - Generate will produce nothing.")
		return warnings

	var uses_plane: bool = (model_layers & (MODEL_PLANE | MODEL_PLANE_WATER)) != 0
	var uses_globe: bool = (model_layers & (MODEL_GLOBE | MODEL_GLOBE_WATER)) != 0
	if uses_plane and not uses_globe and terrain_shape == TerrainShape.RADIAL:
		warnings.append("Plane layers are selected but Terrain Shape is Radial, so \"up\" is treated as pointing away from the world centre. Slope and altitude colouring will be wrong. Set Terrain Shape to Planar.")
	if uses_globe and not uses_plane and terrain_shape == TerrainShape.PLANAR:
		warnings.append("Globe layers are selected but Terrain Shape is Planar, so \"up\" is treated as +Y everywhere instead of radially outward. Slope and altitude colouring will be wrong. Set Terrain Shape to Radial.")

	if (model_layers & MODEL_CUTOFF) == 0:
		warnings.append("Cutoff is not selected. Any surface reaching the edge of the grid ends in a ragged open hole, because cells on the boundary are skipped during contouring. Only safe for models that sit comfortably inside the grid.")

	var has_solid: bool = (model_layers & (MODEL_GLOBE | MODEL_PLANE | MODEL_HYPERCUBE | MODEL_24CELL)) != 0
	if not has_solid and (model_layers & (MODEL_GLOBE_WATER | MODEL_PLANE_WATER)) != 0:
		warnings.append("Water is selected with no solid layer, so there is nothing for it to form a shoreline against.")

	return warnings


func randomize_and_generate() -> void:
	terrain_seed = randi()
	generate()


func clear() -> void:
	_clear_chunks()
	var ground: MeshInstance4D = _get_ground_instance()
	if ground != null:
		ground.mesh = null
	var water: MeshInstance4D = _get_water_instance()
	if water != null:
		water.mesh = null
	var collision: CollisionShape4D = _get_collision_shape()
	if collision != null:
		collision.shape = null


## Frees every brick MeshInstance4D this script created and resets the
## tracking dictionaries/stats - called by both clear() and the start of
## generate() (a fresh generate() always streams bricks in from scratch,
## never patches the previous set), so a stale brick from a smaller previous
## grid_size can never linger.
func _clear_chunks() -> void:
	for chunk in _ground_chunks.values():
		(chunk as MeshInstance4D).queue_free()
	for chunk in _water_chunks.values():
		(chunk as MeshInstance4D).queue_free()
	_ground_chunks.clear()
	_water_chunks.clear()
	_chunk_bounds.clear()
	_generated_bricks.clear()
	_edit_operations.clear()
	_visible_chunk_count = 0
	_total_chunk_count = 0
	_visible_tet_count = 0
	_total_tet_count = 0


## Generates the world as independent bricks rather than one monolithic
## VoxelField4D/MultiVertexDualContour4D pass - see _stream_bricks_in_radius and
## _generate_brick. Only bricks within max_render_distance of world center
## (Vector4.ZERO - the same point every model is built around, and where the
## camera's default look_at_target sits) are generated here; more stream in
## later via _stream_bricks_near_camera as the camera actually moves near
## them. This is what decouples grid_size (how big the world is ALLOWED to
## be) from how much of it this call actually pays to build.
##
## Returns as soon as the initial batch of bricks has been QUEUED, not once
## they're built - each one runs on a WorkerThreadPool thread (see
## _request_brick/_compute_brick_geometry) and lands over the following
## frames as _process()'s _poll_brick_tasks reaps them. This is what makes
## even a very large initial view load without a multi-second stall: the
## caller (and every frame in between) keeps running while the terrain
## actually builds. _print_stats() fires once streaming drains rather than
## from here directly - see _poll_brick_tasks.
func generate() -> void:
	var ground_instance: MeshInstance4D = _get_ground_instance()
	if ground_instance == null:
		push_error("VoxelTerrain4D: expected a MeshInstance4D child named 'Ground'.")
		return

	var clamped_size: int = clampi(grid_size, 4, MAX_GRID_SIZE)
	if clamped_size != grid_size:
		push_warning("VoxelTerrain4D: grid_size clamped to %d." % clamped_size)

	_active_model_names = selected_model_names()
	if _active_model_names.is_empty():
		push_warning("VoxelTerrain4D: no model layers selected, nothing to generate.")
		return

	_generation_session_id += 1
	_clear_chunks()
	_nominal_size = clamped_size
	_nominal_center = float(clamped_size - 1) * 0.5
	_ground_material = _build_material(false)
	_water_material = _build_material(true)
	_last_stats = {}

	_stream_bricks_in_radius(Vector4.ZERO, max_render_distance, _nominal_center)

	if generate_collision:
		push_warning("VoxelTerrain4D: generate_collision is not supported in brick-streaming mode - collision would need aggregating across every generated brick, which streaming (more bricks arrive after this call returns) makes an ongoing job rather than a one-time one. No collision shape will be built; see the ObservationFloor box in voxel_port.tscn for what to stand on instead.")
	var collision_shape: CollisionShape4D = _get_collision_shape()
	if collision_shape != null:
		collision_shape.shape = null

	_update_chunk_visibility()
	print("[VoxelTerrain4D] queued %d bricks for background generation (nominal grid_size %d)..." % [_bricks_in_flight.size(), _nominal_size])


## Stamped when generate() (or a later streaming request) starts a batch of
## background work, and read by _print_stats to report elapsed wall time -
## the async counterpart to the old synchronous generate()'s local
## start_usec, since that timing now has to survive across many separate
## _process() frames instead of one function call.
var _generate_start_usec: int = 0


func _print_stats() -> void:
	var ground_tetrahedra: int = _last_stats.get("ground_tetrahedra", 0)
	var water_tetrahedra: int = _last_stats.get("water_tetrahedra", 0)
	var total_tetrahedra: int = ground_tetrahedra + water_tetrahedra
	# 6 cross-section vertices per tetrahedron, each carrying all four corner
	# positions plus texture data - see TetraMesh4D::update_cross_section_mesh.
	var approximate_megabytes: float = float(total_tetrahedra) * 6.0 * 120.0 / (1024.0 * 1024.0)
	print("[VoxelTerrain4D] %d bricks (nominal grid_size %d) -> %d grid points -> %d crossings -> %d vertices -> %d tets (%d ground / %d water)" % [
		_generated_bricks.size(),
		_nominal_size,
		_last_stats.get("grid_points", 0),
		_last_stats.get("crossing_edges", 0),
		_last_stats.get("vertices", 0),
		total_tetrahedra,
		ground_tetrahedra,
		water_tetrahedra,
	])
	print("[VoxelTerrain4D] %d broken tets dropped, ~%.1f MB of cross-section mesh" % [
		_last_stats.get("tetrahedra_degenerate", 0),
		approximate_megabytes,
	])
	print("[VoxelTerrain4D] field %.0f ms (summed across bricks, not wall time), %.0f ms wall time since this batch was queued" % [
		_last_stats.get("field_ms", 0.0),
		(Time.get_ticks_usec() - _generate_start_usec) / 1000.0,
	])


## Builds a fresh, thread-private set of noise generators from this node's
## exported noise parameters - called once per brick, from
## _compute_brick_geometry, on whichever WorkerThreadPool thread that brick
## landed on, and never shared with any other brick's task.
##
## This project never independently verified that FastNoiseLite's
## get_noise_*() is safe to call concurrently, from multiple threads, on ONE
## SHARED instance - and the artifact this was built to rule out (regular,
## brick-aligned wall-like structures reported after a long play session)
## is exactly the shape a subtle cross-thread read hazard would produce: the
## seam between two threads' work IS a brick boundary. A fresh instance per
## brick costs one small allocation and a handful of property writes -
## negligible next to a single brick's own field-evaluation cost - and
## removes any doubt about the cause regardless of whether shared
## FastNoiseLite access was ever actually the problem.
func _build_thread_local_noise_set() -> Dictionary:
	var base := FastNoiseLite.new()
	base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base.seed = terrain_seed
	base.frequency = noise_frequency
	base.fractal_type = FastNoiseLite.FRACTAL_FBM
	base.fractal_octaves = fractal_octaves
	base.fractal_gain = fractal_gain

	var detail: FastNoiseLite = null
	if detail_noise_enabled:
		detail = FastNoiseLite.new()
		detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		# Offset from the base seed rather than reusing it - an IDENTICAL
		# seed at a different frequency is still a strongly correlated
		# signal (the same underlying lattice, just resampled), which reads
		# as one noise field wobbling rather than two independent scales of
		# feature layered together.
		detail.seed = terrain_seed + 1
		detail.frequency = noise_frequency * detail_noise_frequency_multiplier
		detail.fractal_type = FastNoiseLite.FRACTAL_FBM
		detail.fractal_octaves = maxi(1, fractal_octaves - 1)
		detail.fractal_gain = fractal_gain

	var cellular: FastNoiseLite = null
	if cellular_noise_enabled:
		cellular = FastNoiseLite.new()
		cellular.noise_type = FastNoiseLite.TYPE_CELLULAR
		cellular.seed = terrain_seed + 2
		cellular.frequency = cellular_noise_frequency
		cellular.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
		cellular.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	return {"base": base, "detail": detail, "cellular": cellular}


## FastNoiseLite only samples up to 3D, so the fourth axis is folded in by
## offsetting the other three by it. That is a real approximation - the result
## is not isotropic in 4D the way genuine 4D noise would be - but it is
## continuous and seedless-of-artifacts at these frequencies, and it keeps the
## noise term to one cheap call. Swapping in a true 4D noise with an analytic
## gradient is the natural upgrade here, and would let _noise_gradient stop
## differencing entirely.
##
## Combines the base fractal layer with the optional detail/cellular layers
## from [param noise_set] (see _build_thread_local_noise_set), then reshapes
## the sum through noise_smoothing_power - see that export's own comment for
## why a post-hoc power curve is the thing a single fractal-noise call can't
## express on its own.
func _noise_value(noise_set: Dictionary, p: Vector4) -> float:
	var sx: float = p.x + p.w * 1.7
	var sy: float = p.y - p.w * 1.3
	var sz: float = p.z + p.w * 2.1
	var value: float = (noise_set["base"] as FastNoiseLite).get_noise_3d(sx, sy, sz)
	var detail: FastNoiseLite = noise_set["detail"]
	if detail != null:
		value += detail.get_noise_3d(sx, sy, sz) * detail_noise_amplitude_fraction
	var cellular: FastNoiseLite = noise_set["cellular"]
	if cellular != null:
		value += cellular.get_noise_3d(sx, sy, sz) * cellular_noise_amplitude_fraction
	if not is_equal_approx(noise_smoothing_power, 1.0):
		value = signf(value) * pow(absf(value), noise_smoothing_power)
	return value


func _noise_gradient(noise_set: Dictionary, p: Vector4) -> Vector4:
	var e: float = NOISE_GRADIENT_EPSILON
	var gradient := Vector4.ZERO
	for axis in range(4):
		var ahead: Vector4 = p
		var behind: Vector4 = p
		ahead[axis] += e
		behind[axis] -= e
		gradient[axis] = (_noise_value(noise_set, ahead) - _noise_value(noise_set, behind)) / (2.0 * e)
	return gradient


## Thin wrapper around [method VoxelField4D.add_layer] that translates every
## point the density/gradient closures see by [param offset] before calling
## them, so the SAME closures - defined once in _add_model_layer below in
## terms of a fixed [param size]/center, exactly as when this generated one
## monolithic field - can be evaluated against an individual brick's own
## small field instead. A brick's field-local point 0 is world-grid point
## [param offset], so this is exactly the translation needed to make
## density_fn/gradient_fn see world-grid coordinates regardless of which
## brick is asking. With offset == Vector4.ZERO (every call site not
## involved in streaming) this is a no-op pass-through.
func _wrapped_add_layer(field: VoxelField4D, offset: Vector4, material: int, density_fn: Callable, gradient_fn: Callable, confidence: float, replace_mask: int = VoxelField4D.REPLACE_ANY) -> int:
	return field.add_layer(
		material,
		func(p: Vector4) -> float: return density_fn.call(p + offset),
		func(p: Vector4) -> Vector4: return gradient_fn.call(p + offset),
		confidence, replace_mask)


func _add_model_layer(field: VoxelField4D, model_name: String, size: int, world_offset: Vector4, noise_set: Dictionary) -> bool:
	var center := Vector4(1, 1, 1, 1) * (float(size) * 0.5)
	var noise_amplitude: float = noise_amplitude_fraction * float(size)

	match model_name:
		"globe":
			var radius: float = float(size) * 0.35
			_wrapped_add_layer(field, world_offset,
				VoxelField4D.VoxelMaterial.GROUND,
				func(p: Vector4) -> float:
					return noise_amplitude * _noise_value(noise_set, p) + radius - (p - center).length(),
				func(p: Vector4) -> Vector4:
					var offset: Vector4 = center - p
					var length: float = offset.length()
					var radial: Vector4 = Vector4.ZERO if is_zero_approx(length) else offset / length
					return _noise_gradient(noise_set, p) * noise_amplitude + radial,
				NOISY_LAYER_CONFIDENCE)
			return true

		"globewater":
			var water_radius: float = float(size) * 0.37
			_wrapped_add_layer(field, world_offset,
				VoxelField4D.VoxelMaterial.WATER,
				func(p: Vector4) -> float:
					return water_radius - (p - center).length(),
				func(p: Vector4) -> Vector4:
					var offset: Vector4 = center - p
					var length: float = offset.length()
					return Vector4.ZERO if is_zero_approx(length) else offset / length,
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"plane":
			var plane_height: float = float(size) * 0.5
			_wrapped_add_layer(field, world_offset,
				VoxelField4D.VoxelMaterial.GROUND,
				func(p: Vector4) -> float:
					return noise_amplitude * _noise_value(noise_set, p) + plane_height - p.y,
				func(p: Vector4) -> Vector4:
					return _noise_gradient(noise_set, p) * noise_amplitude + Vector4(0, -1, 0, 0),
				NOISY_LAYER_CONFIDENCE)
			return true

		"planewater":
			var water_level: float = float(size) * 0.5
			_wrapped_add_layer(field, world_offset,
				VoxelField4D.VoxelMaterial.WATER,
				func(p: Vector4) -> float:
					return water_level - p.y,
				func(_p: Vector4) -> Vector4:
					return Vector4(0, -1, 0, 0),
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"spherinder":
			# Carves away everything outside a sphere in x/z/w, leaving the
			# vertical axis untouched - a cylinder one dimension up.
			var column_radius: float = float(size) * 0.5 - 1.0
			_wrapped_add_layer(field, world_offset,
				VoxelField4D.VoxelMaterial.AIR,
				func(p: Vector4) -> float:
					var radial := Vector3(p.x - center.x, p.z - center.z, p.w - center.w)
					return radial.length() - column_radius,
				func(p: Vector4) -> Vector4:
					var radial := Vector3(p.x - center.x, p.z - center.z, p.w - center.w)
					if is_zero_approx(radial.length()):
						return Vector4(1, 0, 0, 0)
					radial = radial.normalized()
					return Vector4(radial.x, 0.0, radial.y, radial.z),
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"cutoff":
			# Seals the outermost shell of the grid. Dual contouring skips
			# cells that would need out-of-bounds neighbors, so without this
			# any surface reaching the boundary ends in a ragged open edge.
			var high_limit: float = float(size) - 1.1
			var low_limit := 0.1
			_wrapped_add_layer(field, world_offset,
				VoxelField4D.VoxelMaterial.AIR,
				func(p: Vector4) -> float:
					var highest: float = maxf(maxf(p.x, p.y), maxf(p.z, p.w)) - high_limit
					var lowest: float = low_limit - minf(minf(p.x, p.y), minf(p.z, p.w))
					return maxf(highest, lowest),
				func(p: Vector4) -> Vector4:
					var best_axis := 0
					var best_value: float = -INF
					var best_sign := 1.0
					for axis in range(4):
						var above: float = p[axis] - high_limit
						if above > best_value:
							best_value = above
							best_axis = axis
							best_sign = 1.0
						var below: float = low_limit - p[axis]
						if below > best_value:
							best_value = below
							best_axis = axis
							best_sign = -1.0
					var gradient := Vector4.ZERO
					gradient[best_axis] = best_sign
					return gradient,
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"hypercube":
			var rotation: Projection = _random_rotation()
			# The rotation is orthonormal, so its inverse is its transpose -
			# which is what maps a face normal in the hypercube's own frame back
			# into world space. Projection exposes inverse() but not
			# transposed(), so take that route.
			var inverse_rotation: Projection = rotation.inverse()
			var half_extent: float = float(size) * 0.25
			_wrapped_add_layer(field, world_offset,
				VoxelField4D.VoxelMaterial.GROUND,
				func(p: Vector4) -> float:
					var local: Vector4 = rotation * (p - center)
					var largest: float = maxf(maxf(absf(local.x), absf(local.y)), maxf(absf(local.z), absf(local.w)))
					return half_extent - largest,
				func(p: Vector4) -> Vector4:
					var local: Vector4 = rotation * (p - center)
					var best_axis := 0
					var best_value: float = -1.0
					for axis in range(4):
						if absf(local[axis]) > best_value:
							best_value = absf(local[axis])
							best_axis = axis
					var face_normal := Vector4.ZERO
					face_normal[best_axis] = signf(local[best_axis])
					return inverse_rotation * face_normal,
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"24cell":
			# The 24-cell is the intersection of a hypercube and a
			# hyper-octahedron, so its density is the tighter of the two
			# constraints and its gradient is whichever one is currently
			# binding. It has no 3D analogue, which makes it a good check that
			# sharp features survive the QEF solve.
			var cell_radius: float = float(size) * 0.5 - 2.5
			_wrapped_add_layer(field, world_offset,
				VoxelField4D.VoxelMaterial.GROUND,
				func(p: Vector4) -> float:
					var d: Vector4 = p - center
					var absolute := Vector4(absf(d.x), absf(d.y), absf(d.z), absf(d.w))
					var octahedral: float = (absolute.x + absolute.y + absolute.z + absolute.w) * 0.5
					var cubic: float = maxf(maxf(absolute.x, absolute.y), maxf(absolute.z, absolute.w))
					return cell_radius - maxf(cubic, octahedral),
				func(p: Vector4) -> Vector4:
					var d: Vector4 = p - center
					var absolute := Vector4(absf(d.x), absf(d.y), absf(d.z), absf(d.w))
					var binding: float = (absolute.x + absolute.y + absolute.z + absolute.w) * 0.5
					var gradient := Vector4(-signf(d.x), -signf(d.y), -signf(d.z), -signf(d.w)) * 0.5
					for axis in range(4):
						if absolute[axis] > binding:
							binding = absolute[axis]
							gradient = Vector4.ZERO
							gradient[axis] = -signf(d[axis])
					return gradient,
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"seafloor":
			# Matches whichever reference level the corresponding water
			# layer already uses (globewater's water_radius, planewater's
			# water_level) so a shallow world's floor sits a fixed distance
			# below the SAME surface the water sits on, regardless of shape.
			var is_radial: bool = terrain_shape == TerrainShape.RADIAL
			var reference_level: float = float(size) * (0.37 if is_radial else 0.5)
			_wrapped_add_layer(field, world_offset,
				VoxelField4D.VoxelMaterial.AIR,
				func(p: Vector4) -> float:
					var depth: float = reference_level - (p - center).length() if is_radial else reference_level - p.y
					return depth - max_depth_below_water,
				func(p: Vector4) -> Vector4:
					if is_radial:
						var offset: Vector4 = center - p
						var length: float = offset.length()
						return Vector4.ZERO if is_zero_approx(length) else offset / length
					return Vector4(0, -1, 0, 0),
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"arch":
			var arch_base_y: float = float(size) * 0.5
			var start_x: float = float(size) * arch_start_fraction
			var end_x: float = float(size) * arch_end_fraction
			var curve_point_fn := func(t: float) -> Vector4:
				return Vector4(
					lerp(start_x, end_x, t),
					arch_base_y + arch_height * sin(t * PI),
					center.z,
					center.w + arch_w_amplitude * sin(t * TAU),
				)
			# Cheap bounding-sphere reject before the (relatively) expensive
			# closest-point search below - most grid points in a world that
			# combines Arch with a full plane/globe base are nowhere near
			# the arch at all, and this is a handful of subtractions against
			# one sample-and-search loop of ~30+ curve evaluations.
			var arch_bounds_center := Vector4(
				(start_x + end_x) * 0.5, arch_base_y + arch_height * 0.5, center.z, center.w)
			var arch_bounds_radius: float = maxf(absf(end_x - start_x), arch_height) * 0.5 + arch_w_amplitude + arch_radius + 2.0
			var arch_bounds_radius_sq: float = arch_bounds_radius * arch_bounds_radius
			# _closest_point_on_curve's coarse-sample-then-refine search is only
			# safe when the tube radius is much smaller than a sample's spacing
			# IN ARC LENGTH - a fixed sample count silently violates that near
			# the peak, where dy/dt drops to 0 while dx/dt and dw/dt (from
			# arch_w_amplitude * TAU * cos(t*TAU)) are both still large, so the
			# curve can cover several radii worth of distance between two
			# adjacent samples. Size the sample count off the curve's own worst-
			# case analytic speed instead of a magic constant, so the refinement
			# always starts from a coarse sample within one radius of the truth
			# no matter what arch_height/arch_w_amplitude/the x-span are set to.
			var arch_max_speed: float = sqrt(
				(end_x - start_x) * (end_x - start_x) +
				(arch_height * PI) * (arch_height * PI) +
				(arch_w_amplitude * TAU) * (arch_w_amplitude * TAU))
			# 4x safety margin below one radius per sample step.
			var curve_sample_count: int = clampi(ceili(arch_max_speed / maxf(arch_radius, 0.01) * 4.0), 24, 4000)
			_wrapped_add_layer(field, world_offset,
				VoxelField4D.VoxelMaterial.GROUND,
				func(p: Vector4) -> float:
					if p.distance_squared_to(arch_bounds_center) > arch_bounds_radius_sq:
						return -1000.0 # Provably nowhere near the arch - skip the search.
					var closest: Dictionary = _closest_point_on_curve(p, curve_point_fn, curve_sample_count)
					return arch_radius - (closest["distance"] as float),
				func(p: Vector4) -> Vector4:
					var closest: Dictionary = _closest_point_on_curve(p, curve_point_fn, curve_sample_count)
					# Density is (radius - distance), so its true gradient points
					# TOWARD the curve, same sign convention as globe/globewater's
					# (center - p) below - not away from it. The previous version
					# here returned the outward direction instead, flipping the
					# normal fed into the winding vote for the whole tube surface.
					var offset: Vector4 = (closest["point"] as Vector4) - p
					var length: float = offset.length()
					return Vector4.ZERO if is_zero_approx(length) else offset / length,
				ANALYTIC_LAYER_CONFIDENCE)
			return true

	return false


## Coarse-sample-then-refine closest-point search along a parametric curve -
## there is no general closed-form distance-to-an-arbitrary-curve formula,
## so this samples [param curve_point_fn] at [param sample_count] points,
## keeps the nearest, then narrows in on it with a few bisection-style
## halving steps. Good enough for a tube whose radius is much smaller than
## the curve's own radius of curvature (true for "arch" - arch_radius is a
## small fraction of arch_height/arch_w_amplitude), which is what keeps the
## coarse sampling from ever missing a closer point the refinement phase
## could not find on its own.
func _closest_point_on_curve(p: Vector4, curve_point_fn: Callable, sample_count: int) -> Dictionary:
	var best_t := 0.0
	var best_dist_sq := INF
	for i in range(sample_count + 1):
		var t: float = float(i) / float(sample_count)
		var d_sq: float = (curve_point_fn.call(t) as Vector4).distance_squared_to(p)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_t = t

	var step: float = 1.0 / float(sample_count)
	for refine_iteration in range(6):
		var t_low: float = maxf(0.0, best_t - step)
		var t_high: float = minf(1.0, best_t + step)
		var d_low: float = (curve_point_fn.call(t_low) as Vector4).distance_squared_to(p)
		var d_high: float = (curve_point_fn.call(t_high) as Vector4).distance_squared_to(p)
		if d_low < best_dist_sq:
			best_dist_sq = d_low
			best_t = t_low
		if d_high < best_dist_sq:
			best_dist_sq = d_high
			best_t = t_high
		step *= 0.5

	return {"point": curve_point_fn.call(best_t), "distance": sqrt(best_dist_sq)}


## A uniformly-ish random 4D rotation, by Gram-Schmidt on gaussian columns.
## Gaussian rather than uniform because a gaussian vector's direction is
## isotropic, so orthonormalizing four of them gives no preferred axis.
func _random_rotation() -> Projection:
	var generator := RandomNumberGenerator.new()
	generator.seed = terrain_seed
	var columns: Array[Vector4] = []
	while columns.size() < 4:
		var candidate := Vector4(
			generator.randfn(), generator.randfn(), generator.randfn(), generator.randfn())
		for existing in columns:
			candidate -= existing * candidate.dot(existing)
		var length: float = candidate.length()
		if length < 1e-4:
			continue # Landed nearly inside the span already covered; redraw.
		columns.append(candidate / length)
	return Projection(columns[0], columns[1], columns[2], columns[3])


## Generates every not-yet-streamed brick whose center (in world-grid
## coordinates) is within [param radius] world meters of [param origin_world],
## clamped to the nominal [0, _nominal_size) world the current generate()
## session declared. Shared by generate() itself (origin = world center) and
## _stream_bricks_near_camera (origin = the camera's live position) - the
## only difference between "generate the world" and "stream more of it in
## later" is which point this radius is measured from.
func _stream_bricks_in_radius(origin_world: Vector4, radius: float, center: float) -> void:
	# Only reset the "batch start" timestamp when nothing is already in
	# flight - otherwise a streaming scan that lands while an earlier batch
	# is still finishing (see STREAM_SCAN_INTERVAL_FRAMES) would push the
	# reference point forward and understate _print_stats's reported wall
	# time for work that was already queued before this call.
	if _bricks_in_flight.is_empty():
		_generate_start_usec = Time.get_ticks_usec()
	var offset := Vector4(center, center, center, center)
	var origin_grid: Vector4 = origin_world / cell_size + offset
	var radius_grid: float = radius / cell_size
	var brick_span: float = float(BRICK_CORE_CELLS)
	# Bricks covering grid cells [0, _nominal_size) - a brick index past this
	# would only ever contain padding, never a core cell inside the nominal
	# world, so there is nothing for it to generate.
	var max_brick_index: int = maxi(0, ceili(float(_nominal_size) / brick_span) - 1)

	var bk_min := Vector4i.ZERO
	var bk_max := Vector4i.ZERO
	for axis in range(4):
		bk_min[axis] = clampi(floori((origin_grid[axis] - radius_grid) / brick_span), 0, max_brick_index)
		bk_max[axis] = clampi(ceili((origin_grid[axis] + radius_grid) / brick_span), 0, max_brick_index)

	var radius_grid_sq: float = radius_grid * radius_grid
	for bx in range(bk_min.x, bk_max.x + 1):
		for by in range(bk_min.y, bk_max.y + 1):
			for bz in range(bk_min.z, bk_max.z + 1):
				for bw in range(bk_min.w, bk_max.w + 1):
					var bk := Vector4i(bx, by, bz, bw)
					if _generated_bricks.has(bk):
						continue
					var brick_center_grid: Vector4 = Vector4(bk) * brick_span + Vector4.ONE * (brick_span * 0.5)
					if brick_center_grid.distance_squared_to(origin_grid) > radius_grid_sq:
						continue
					_request_brick(bk)


## Queues one brick's generation on a WorkerThreadPool thread if it isn't
## Adds (is_add = true) or carves (is_add = false) a hyperspherical volume
## centered at [param world_position] (this Terrain's own local space, same
## convention as camera.look_at_target and every other world-space point in
## this script) with radius [param world_radius] meters. Every brick whose
## core or padding could see this edit is dropped and re-requested
## immediately, so the change is visible within one streaming pass rather
## than waiting for the next scheduled scan.
func edit_sphere(world_position: Vector4, world_radius: float, is_add: bool) -> void:
	if _active_model_names.is_empty():
		return # No generate() session active yet - nothing to edit.
	var offset := Vector4(_nominal_center, _nominal_center, _nominal_center, _nominal_center)
	var center_grid: Vector4 = world_position / cell_size + offset
	var radius_grid: float = world_radius / cell_size
	_edit_operations.append({"is_add": is_add, "center": center_grid, "radius": radius_grid})

	# WorkerThreadPool has no cancel API (see _generation_session_id's own
	# comment) - bumping the session id here means any brick task already in
	# flight anywhere, not just near this edit, gets discarded as stale by
	# _finish_brick once it completes rather than risking it overwriting a
	# brick this edit just invalidated with pre-edit geometry. Bricks far
	# from the edit that get discarded this way simply aren't marked
	# generated, and pick themselves back up on the next streaming scan
	# (see STREAM_SCAN_INTERVAL_FRAMES) - a small, one-off delay, not a
	# correctness problem, and simpler than tracking per-brick edit epochs.
	_generation_session_id += 1

	var brick_span: float = float(BRICK_CORE_CELLS)
	# Reach past the edit's own radius by one brick span plus BRICK_PAD: a
	# brick whose CORE doesn't touch the edit at all can still have its
	## PADDING margin overlap it, and that padding needs to see the edit too
	# or it would disagree with whichever brick owns those cells as ITS
	# core - the same cross-brick consistency requirement BRICK_PAD exists
	# for in the first place, just triggered by an edit instead of a
	# generate() pass.
	var reach: float = radius_grid + float(BRICK_PAD) + brick_span
	var bk_min := Vector4i.ZERO
	var bk_max := Vector4i.ZERO
	for axis in range(4):
		bk_min[axis] = floori((center_grid[axis] - reach) / brick_span)
		bk_max[axis] = ceili((center_grid[axis] + reach) / brick_span)
	for bx in range(bk_min.x, bk_max.x + 1):
		for by in range(bk_min.y, bk_max.y + 1):
			for bz in range(bk_min.z, bk_max.z + 1):
				for bw in range(bk_min.w, bk_max.w + 1):
					var bk := Vector4i(bx, by, bz, bw)
					_discard_brick(bk)
					_request_brick(bk)


## Frees an existing brick's mesh children (if any) and forgets it was ever
## generated, so a later _request_brick for the same key builds it fresh
## rather than treating it as already done.
func _discard_brick(bk: Vector4i) -> void:
	if _generated_bricks.has(bk):
		_generated_bricks.erase(bk)
		_total_chunk_count -= 1
	if _ground_chunks.has(bk):
		var ground_mesh: ArrayTetraMesh4D = (_ground_chunks[bk] as MeshInstance4D).mesh
		if ground_mesh != null:
			_total_tet_count -= ground_mesh.simplex_cell_indices.size() / 4
		(_ground_chunks[bk] as MeshInstance4D).queue_free()
		_ground_chunks.erase(bk)
	if _water_chunks.has(bk):
		var water_mesh: ArrayTetraMesh4D = (_water_chunks[bk] as MeshInstance4D).mesh
		if water_mesh != null:
			_total_tet_count -= water_mesh.simplex_cell_indices.size() / 4
		(_water_chunks[bk] as MeshInstance4D).queue_free()
		_water_chunks.erase(bk)
	_chunk_bounds.erase(bk)


## Applies one edit_sphere() entry as an extra VoxelField4D layer, exactly
## like a "spherinder"/"cutoff" carve in _add_model_layer - the same
## density/gradient shape either places GROUND (is_add) or carves back to
## AIR, letting VoxelField4D's own layer-compositing (material comparison,
## crossing refinement, everything) do the actual work unchanged.
func _add_edit_layer(field: VoxelField4D, op: Dictionary, brick_origin: Vector4) -> void:
	var center: Vector4 = op["center"]
	var radius: float = op["radius"]
	var material: int = VoxelField4D.VoxelMaterial.GROUND if op["is_add"] else VoxelField4D.VoxelMaterial.AIR
	_wrapped_add_layer(field, brick_origin,
		material,
		func(p: Vector4) -> float:
			return radius - (p - center).length(),
		func(p: Vector4) -> Vector4:
			var offset: Vector4 = center - p
			var length: float = offset.length()
			return Vector4.ZERO if is_zero_approx(length) else offset / length,
		ANALYTIC_LAYER_CONFIDENCE)


## Queues one brick's generation on a WorkerThreadPool thread if it isn't
## already generated or already in flight, up to MAX_CONCURRENT_BRICK_TASKS
## at once - callers past that cap simply retry on the next streaming scan,
## since nothing here is lost, only delayed.
func _request_brick(bk: Vector4i) -> void:
	if _generated_bricks.has(bk) or _bricks_in_flight.has(bk):
		return
	if _bricks_in_flight.size() >= MAX_CONCURRENT_BRICK_TASKS:
		return
	var result_slot := {"session_id": _generation_session_id}
	_bricks_in_flight[bk] = result_slot
	# Snapshotted here (main thread, at request time) rather than read live
	# from _compute_brick_geometry on the worker thread - _edit_operations
	# can grow at any time from a live edit (see edit_sphere), and Array is
	# not documented safe for one thread to append to while another iterates
	# it. Duplicating it once per brick means every brick sees a fixed,
	# consistent edit history for its own generation, the same freezing
	# principle _active_model_names already applies to the model layer list.
	var edit_ops_snapshot: Array = _edit_operations.duplicate()
	var task_id: int = WorkerThreadPool.add_task(_compute_brick_geometry.bind(bk, result_slot, edit_ops_snapshot))
	_pending_brick_tasks[task_id] = bk


## Runs entirely on a background thread - the whole VoxelField4D +
## MultiVertexDualContour4D + QEF pass for one brick, exactly what the old synchronous
## _generate_brick did, but writing its output into [param result_slot]
## instead of building any MeshInstance4D/ArrayTetraMesh4D (those touch the
## render server and must happen back on the main thread - see _finish_brick).
## Reads _active_model_names/_nominal_size/flip_winding/_noise and the
## various @export generation parameters, all of which this generate()
## "session" already treats as frozen for its duration (see
## _active_model_names's own comment) - nothing here writes to shared state,
## so many of these can run concurrently across different bricks safely.
func _compute_brick_geometry(bk: Vector4i, result_slot: Dictionary, edit_ops_snapshot: Array) -> void:
	var brick_field_size: int = BRICK_CORE_CELLS + 1 + 2 * BRICK_PAD
	var brick_origin: Vector4 = Vector4(bk) * float(BRICK_CORE_CELLS) - Vector4.ONE * float(BRICK_PAD)

	var field_start_usec: int = Time.get_ticks_usec()
	var field := VoxelField4D.new(brick_field_size)
	var noise_set: Dictionary = _build_thread_local_noise_set()
	for model_name in _active_model_names:
		_add_model_layer(field, model_name, _nominal_size, brick_origin, noise_set)
	# Edits are just more density layers, applied in the order they were
	# made, exactly like the "cutoff"/"spherinder" carve layers already are -
	# a later edit legitimately overwrites an earlier one that overlaps it,
	# the same as any other layer composition in this field.
	for op in edit_ops_snapshot:
		_add_edit_layer(field, op, brick_origin)
	var field_ms: float = (Time.get_ticks_usec() - field_start_usec) / 1000.0

	var contour := MultiVertexDualContour4D.new(field)
	contour.flip_winding = flip_winding
	contour.generate()

	# contour.vertices comes out in this brick's OWN local coordinates
	# (0 .. brick_field_size - 1) - shift once, in place, so every downstream
	# consumer (_build_mesh, _slope_at, _altitude_at, the core-cell filter
	# right below) can keep treating vertex positions as world-grid
	# coordinates exactly like the old monolithic contour's always were.
	for i in range(contour.vertices.size()):
		contour.vertices[i] += brick_origin

	var core_min: Vector4 = Vector4(bk) * float(BRICK_CORE_CELLS)
	var core_max: Vector4 = core_min + Vector4.ONE * float(BRICK_CORE_CELLS)

	result_slot["contour"] = contour
	result_slot["ground_core"] = _filter_core_cells(contour, contour.ground_cells, core_min, core_max)
	result_slot["water_core"] = _filter_core_cells(contour, contour.water_cells, core_min, core_max)
	result_slot["core_min"] = core_min
	result_slot["core_max"] = core_max
	result_slot["field_ms"] = field_ms
	result_slot["grid_points"] = field.point_count()
	result_slot["crossing_edges"] = contour.stats.get("crossing_edges", 0)
	result_slot["vertices"] = contour.stats.get("vertices", 0)
	result_slot["tetrahedra_degenerate"] = contour.stats.get("tetrahedra_degenerate", 0)


## Main-thread-only second half of brick generation: takes a finished
## background task's result_slot and builds the actual MeshInstance4D/
## ArrayTetraMesh4D children from it - the direct counterpart to the old
## _rebuild_chunks/_partition_cells_by_chunk pair, except a brick's geometry
## was never part of a larger contour to begin with, so there is nothing to
## partition.
func _finish_brick(bk: Vector4i, result_slot: Dictionary) -> void:
	if result_slot["session_id"] != _generation_session_id:
		return # Superseded by a later generate()/randomize_and_generate() call - discard.
	_generated_bricks[bk] = true
	_last_stats["field_ms"] = _last_stats.get("field_ms", 0.0) + result_slot["field_ms"]
	_last_stats["grid_points"] = _last_stats.get("grid_points", 0) + result_slot["grid_points"]
	_last_stats["crossing_edges"] = _last_stats.get("crossing_edges", 0) + result_slot["crossing_edges"]
	_last_stats["vertices"] = _last_stats.get("vertices", 0) + result_slot["vertices"]
	_last_stats["tetrahedra_degenerate"] = _last_stats.get("tetrahedra_degenerate", 0) + result_slot["tetrahedra_degenerate"]

	var contour: MultiVertexDualContour4D = result_slot["contour"]
	var ground_core: PackedInt32Array = result_slot["ground_core"]
	var water_core: PackedInt32Array = result_slot["water_core"]
	if ground_core.is_empty() and water_core.is_empty():
		# Pure air, or every crossing here belonged to padding a neighbouring
		# brick already owns. _generated_bricks[bk] above still counts this
		# brick (it IS done, just meshless) - resync here too, or a later
		# _discard_brick for this key decrements _total_chunk_count without
		# it ever having been incremented for this brick, eventually driving
		# the count negative.
		_total_chunk_count = _generated_bricks.size()
		return

	var core_min: Vector4 = result_slot["core_min"]
	var core_max: Vector4 = result_slot["core_max"]
	var center: float = _nominal_center
	var offset := Vector4(center, center, center, center)
	_chunk_bounds[bk] = {
		"min": (core_min - offset) * cell_size,
		"max": (core_max - offset) * cell_size,
	}

	if not ground_core.is_empty():
		var ground_instance: MeshInstance4D = _get_ground_instance()
		if ground_instance != null:
			var node := MeshInstance4D.new()
			node.name = "GroundBrick_%d_%d_%d_%d" % [bk.x, bk.y, bk.z, bk.w]
			node.mesh = _build_mesh(contour, ground_core, center, false, _ground_material)
			ground_instance.add_child(node)
			_ground_chunks[bk] = node
			_total_tet_count += ground_core.size() / 4
			_last_stats["ground_tetrahedra"] = _last_stats.get("ground_tetrahedra", 0) + ground_core.size() / 4

	if not water_core.is_empty():
		var water_instance: MeshInstance4D = _get_water_instance()
		if water_instance != null:
			var node := MeshInstance4D.new()
			node.name = "WaterBrick_%d_%d_%d_%d" % [bk.x, bk.y, bk.z, bk.w]
			node.mesh = _build_mesh(contour, water_core, center, true, _water_material)
			water_instance.add_child(node)
			_water_chunks[bk] = node
			_total_tet_count += water_core.size() / 4
			_last_stats["water_tetrahedra"] = _last_stats.get("water_tetrahedra", 0) + water_core.size() / 4

	_total_chunk_count = _generated_bricks.size()


## Writes every currently-generated brick's raw mesh arrays
## (vertex positions, simplex indices, texture values and indices - everything
## needed to rebuild an ArrayTetraMesh4D without touching VoxelField4D/
## MultiVertexDualContour4D/QEFSolver4D again) plus its bounds to a single file,
## alongside the generation parameters that produced it. This is the
## "pre-processing step, done once" half of baking: run generate() (and let
## it fully stream in - see _wait_until_caught_up if scripting this), then
## call this once to capture the result. load_from_file() is the other half.
##
## Deliberately does not cache _edit_operations - a bake captures a
## generated WORLD, not an edit history, and reloading it always starts from
## that clean baseline, the same as pressing Generate itself does.
func bake_to_file(path: String) -> void:
	var bricks_data := {}
	for bk in _generated_bricks.keys():
		var entry := {}
		if _chunk_bounds.has(bk):
			var bounds: Dictionary = _chunk_bounds[bk]
			entry["min"] = bounds["min"]
			entry["max"] = bounds["max"]
		var ground_node: MeshInstance4D = _ground_chunks.get(bk)
		if ground_node != null and ground_node.mesh != null:
			var mesh: ArrayTetraMesh4D = ground_node.mesh
			entry["ground_vertices"] = mesh.vertices
			entry["ground_indices"] = mesh.simplex_cell_indices
			entry["ground_texture_map_values"] = mesh.texture_map_values
			entry["ground_texture_map_indices"] = mesh.simplex_cell_texture_map_indices
		var water_node: MeshInstance4D = _water_chunks.get(bk)
		if water_node != null and water_node.mesh != null:
			var mesh: ArrayTetraMesh4D = water_node.mesh
			entry["water_vertices"] = mesh.vertices
			entry["water_indices"] = mesh.simplex_cell_indices
			entry["water_texture_map_values"] = mesh.texture_map_values
			entry["water_texture_map_indices"] = mesh.simplex_cell_texture_map_indices
		bricks_data[bk] = entry

	var data := {
		"format_version": 2,
		"nominal_size": _nominal_size,
		"cell_size": cell_size,
		"brick_core_cells": BRICK_CORE_CELLS,
		"brick_pad": BRICK_PAD,
		"model_layers": model_layers,
		"terrain_seed": terrain_seed,
		"noise_frequency": noise_frequency,
		"fractal_octaves": fractal_octaves,
		"fractal_gain": fractal_gain,
		"noise_amplitude_fraction": noise_amplitude_fraction,
		"flip_winding": flip_winding,
		"terrain_shape": terrain_shape,
		"bricks": bricks_data,
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("VoxelTerrain4D: could not open '%s' for writing (error %s)." % [path, FileAccess.get_open_error()])
		return
	file.store_var(data)
	file.close()
	print("[VoxelTerrain4D] baked %d bricks to %s" % [bricks_data.size(), path])


## Loads a file written by bake_to_file(), skipping VoxelField4D/
## MultiVertexDualContour4D/QEFSolver4D entirely - every brick's mesh is rebuilt
## directly from its stored arrays. Refuses to load (returns false, logs
## why) if the cache's generation parameters don't match this node's current
## settings, since a mismatched cache's geometry would quietly disagree with
## whatever live streaming would generate for the same brick keys - visible
## as seams at best, an outright wrong world at worst.
##
## Real-time systems - _update_chunk_visibility's culling,
## _stream_bricks_near_camera's live streaming for anything past the baked
## region, edit_sphere - all keep working unchanged afterwards, exactly as
## if generate() itself had populated these same dictionaries; loading is
## just a much faster way to arrive at the same _generated_bricks/
## _ground_chunks/_water_chunks/_chunk_bounds state.
func load_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("VoxelTerrain4D: cache file '%s' does not exist." % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("VoxelTerrain4D: could not open '%s' for reading (error %s)." % [path, FileAccess.get_open_error()])
		return false
	var data: Dictionary = file.get_var()
	file.close()

	var mismatch := PackedStringArray()
	if int(data.get("nominal_size", -1)) != grid_size:
		mismatch.append("grid_size")
	if not is_equal_approx(float(data.get("cell_size", -1.0)), cell_size):
		mismatch.append("cell_size")
	if int(data.get("brick_core_cells", -1)) != BRICK_CORE_CELLS:
		mismatch.append("BRICK_CORE_CELLS")
	if int(data.get("model_layers", -1)) != model_layers:
		mismatch.append("model_layers")
	if int(data.get("terrain_seed", -1)) != terrain_seed:
		mismatch.append("terrain_seed")
	if not mismatch.is_empty():
		push_error("VoxelTerrain4D: cache '%s' does not match current settings (%s) - refusing to load stale geometry." % [path, ", ".join(mismatch)])
		return false

	_active_model_names = selected_model_names()
	_generation_session_id += 1
	_clear_chunks()
	_nominal_size = int(data["nominal_size"])
	_nominal_center = float(_nominal_size - 1) * 0.5
	_ground_material = _build_material(false)
	_water_material = _build_material(true)
	_last_stats = {}
	_generate_start_usec = Time.get_ticks_usec()

	var ground_instance: MeshInstance4D = _get_ground_instance()
	var water_instance: MeshInstance4D = _get_water_instance()
	var bricks_data: Dictionary = data["bricks"]
	for bk in bricks_data.keys():
		var entry: Dictionary = bricks_data[bk]
		_generated_bricks[bk] = true
		if entry.has("min"):
			_chunk_bounds[bk] = {"min": entry["min"], "max": entry["max"]}

		if entry.has("ground_vertices") and ground_instance != null:
			var ground_mesh := ArrayTetraMesh4D.new()
			ground_mesh.vertices = entry["ground_vertices"]
			ground_mesh.simplex_cell_indices = entry["ground_indices"]
			ground_mesh.texture_map_values = entry.get("ground_texture_map_values", entry.get("ground_uvw", PackedVector3Array()))
			if entry.has("ground_texture_map_indices"):
				ground_mesh.simplex_cell_texture_map_indices = entry["ground_texture_map_indices"]
			else:
				ground_mesh.simplex_cell_texture_map_indices = PackedInt32Array(range(ground_mesh.texture_map_values.size()))
			ground_mesh.material = _ground_material
			var ground_node := MeshInstance4D.new()
			ground_node.name = "GroundBrick_%d_%d_%d_%d" % [bk.x, bk.y, bk.z, bk.w]
			ground_node.mesh = ground_mesh
			ground_instance.add_child(ground_node)
			_ground_chunks[bk] = ground_node
			_total_tet_count += ground_mesh.simplex_cell_indices.size() / 4

		if entry.has("water_vertices") and water_instance != null:
			var water_mesh := ArrayTetraMesh4D.new()
			water_mesh.vertices = entry["water_vertices"]
			water_mesh.simplex_cell_indices = entry["water_indices"]
			water_mesh.texture_map_values = entry.get("water_texture_map_values", entry.get("water_uvw", PackedVector3Array()))
			if entry.has("water_texture_map_indices"):
				water_mesh.simplex_cell_texture_map_indices = entry["water_texture_map_indices"]
			else:
				water_mesh.simplex_cell_texture_map_indices = PackedInt32Array(range(water_mesh.texture_map_values.size()))
			water_mesh.material = _water_material
			var water_node := MeshInstance4D.new()
			water_node.name = "WaterBrick_%d_%d_%d_%d" % [bk.x, bk.y, bk.z, bk.w]
			water_node.mesh = water_mesh
			water_instance.add_child(water_node)
			_water_chunks[bk] = water_node
			_total_tet_count += water_mesh.simplex_cell_indices.size() / 4

	_total_chunk_count = _generated_bricks.size()
	_update_chunk_visibility()
	var total_ms: float = (Time.get_ticks_usec() - _generate_start_usec) / 1000.0
	print("[VoxelTerrain4D] loaded %d bricks (%d tets) from %s in %.0f ms" % [_generated_bricks.size(), _total_tet_count, path, total_ms])
	return true


## Keeps only the tets (4 indices each, into contour.vertices - already
## shifted to world-grid coordinates by the time this runs) whose centroid
## falls strictly within [core_min, core_max): the cells this brick actually
## OWNS, as opposed to the BRICK_PAD margin around them that exists purely so
## MultiVertexDualContour4D's own hexahedron completeness check (see BRICK_PAD) doesn't
## discard geometry that belongs to the core. A tet belonging to the padding
## is not lost - the neighbouring brick that owns those cells as ITS core
## will independently regenerate the identical geometry there, from the
## identical world-grid density samples, since every brick's density/gradient
## closures are pure functions of world-grid position regardless of which
## brick asked.
func _filter_core_cells(contour: MultiVertexDualContour4D, cells: PackedInt32Array, core_min: Vector4, core_max: Vector4) -> PackedInt32Array:
	var kept := PackedInt32Array()
	for i in range(0, cells.size(), 4):
		var centroid := Vector4.ZERO
		for corner in range(4):
			centroid += contour.vertices[cells[i + corner]]
		centroid *= 0.25
		var inside := true
		for axis in range(4):
			if centroid[axis] < core_min[axis] or centroid[axis] >= core_max[axis]:
				inside = false
				break
		if inside:
			kept.append(cells[i])
			kept.append(cells[i + 1])
			kept.append(cells[i + 2])
			kept.append(cells[i + 3])
	return kept


## Builds one [ArrayTetraMesh4D] from a subset of the contoured tetrahedra.
##
## Note this appends tetrahedra directly rather than going through the
## polytope hierarchy (edges -> faces -> cells) that the height-field
## generator uses. These are already simplices, so the polytope form buys
## nothing and costs ~11 deduplicating appends per tetrahedron instead of one -
## and PolyMesh4D would only decompose them straight back into simplices to
## render anyway.
func _build_mesh(contour: MultiVertexDualContour4D, cells: PackedInt32Array, center: float, is_water: bool, shared_material: TetraMaterial4D = null) -> ArrayTetraMesh4D:
	if cells.is_empty():
		return null

	var mesh := ArrayTetraMesh4D.new()
	var remap := {}
	var texture_map := PackedVector3Array()

	for i in range(0, cells.size(), 4):
		var indices := PackedInt32Array()
		indices.resize(4)
		for corner in range(4):
			var source_index: int = cells[i + corner]
			var mapped_index: int
			if remap.has(source_index):
				mapped_index = remap[source_index]
			else:
				var grid_position: Vector4 = contour.vertices[source_index]
				var world_position: Vector4 = (grid_position - Vector4(center, center, center, center)) * cell_size
				mapped_index = mesh.append_vertex(world_position, false)
				remap[source_index] = mapped_index
			indices[corner] = mapped_index

		mesh.append_tetra_cell_indices(indices[0], indices[1], indices[2], indices[3])

		# One UVW per tetrahedron corner, in the same order the corners were
		# appended - TetraMesh4D requires the texture map to be exactly as long
		# as the cell position list, which is 4 entries per cell.
		for corner in range(4):
			var source_index: int = cells[i + corner]
			var grid_position: Vector4 = contour.vertices[source_index]
			texture_map.append(Vector3(
				_slope_at(grid_position, contour.vertex_normals[source_index], center),
				_altitude_at(grid_position, center),
				0.5))

	if not is_water:
		mesh.texture_map_values = texture_map
		mesh.simplex_cell_texture_map_indices = PackedInt32Array(range(texture_map.size()))

	# Only two colour sources actually reach the cross-section shader:
	# TetraMaterial4D::update_cross_section_material sets exactly two uniforms,
	# `albedo` (from albedo_color, and only when the SINGLE_COLOR flag is set)
	# and `albedo_texture` (only when the TEXTURE3D_CELL_UVW flag is set).
	# albedo_color_array is never consulted for tetrahedral meshes at all, so
	# PER_CELL and PER_VERT both silently render pure white - the shader simply
	# has no per-cell colour attribute to read.
	#
	# shared_material lets a caller building many chunk meshes from the same
	# generate() pass reuse ONE material (and, for ground, one already-baked
	# palette texture) instead of rebuilding it per chunk - every chunk of the
	# same type is visually identical material anyway, so per-chunk materials
	# would just be redundant allocation, not a visual difference.
	if shared_material != null:
		mesh.material = shared_material
	else:
		mesh.material = _build_material(is_water)
	return mesh


func _build_material(is_water: bool) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	if is_water:
		material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
		material.albedo_color = water_color
	else:
		material.albedo_texture_3d = albedo_texture_3d if albedo_texture_3d != null else _build_palette_texture()
		material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	return material


## Bakes [method _ground_color] into a 3D texture indexed by (slope, altitude).
##
## This is the reference demo's trick, and on this renderer it is not merely
## the nicer option but the only one available for varying colour across a
## surface - see the note in [method _build_mesh]. Depth is 1 because both
## inputs fit in the first two axes; the third UVW component is unused and the
## sampler clamps it.
func _build_palette_texture() -> ImageTexture3D:
	var image: Image = Image.create_empty(PALETTE_RESOLUTION, PALETTE_RESOLUTION, false, Image.FORMAT_RGB8)
	for y in range(PALETTE_RESOLUTION):
		var altitude: float = float(y) / float(PALETTE_RESOLUTION - 1)
		for x in range(PALETTE_RESOLUTION):
			var slope: float = float(x) / float(PALETTE_RESOLUTION - 1)
			image.set_pixel(x, y, _ground_color(slope, altitude))
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGB8, PALETTE_RESOLUTION, PALETTE_RESOLUTION, 1, false, [image])
	return texture


## Slope as 0 (facing straight up) to 1 (vertical wall or overhang), from the
## angle between the surface normal and local "up".
func _slope_at(grid_position: Vector4, normal: Vector4, center: float) -> float:
	if normal.length_squared() < 1e-8:
		return 0.0
	var up: Vector4 = _up_at(grid_position, center)
	return clampf(1.0 - absf(normal.dot(up)), 0.0, 1.0)


func _up_at(grid_position: Vector4, center: float) -> Vector4:
	if terrain_shape == TerrainShape.PLANAR:
		return Vector4(0, 1, 0, 0)
	var outward: Vector4 = grid_position - Vector4(center, center, center, center)
	var length: float = outward.length()
	return Vector4(0, 1, 0, 0) if is_zero_approx(length) else outward / length


## Normalized height in [0, 1] across the world, for altitude banding.
func _altitude_at(grid_position: Vector4, center: float) -> float:
	var span: float = maxf(center, 0.001)
	if terrain_shape == TerrainShape.PLANAR:
		return clampf(grid_position.y / (span * 2.0), 0.0, 1.0)
	var radius: float = (grid_position - Vector4(center, center, center, center)).length()
	return clampf(radius / span, 0.0, 1.0)


## Mud at the flat, low-lying shoreline, sand on the steeper parts of the
## same low band, grass above that, rock higher still, snow at the top - and
## regardless of altitude, anything steep enough reads as bare stone. The
## reference demo gets this from a single 2D texture lookup indexed by
## exactly these two values; assigning an [member albedo_texture_3d] switches
## to that path.
func _ground_color(slope: float, altitude: float) -> Color:
	const MUD := Color(0.35, 0.27, 0.19)
	const SAND := Color(0.76, 0.70, 0.50)
	const GRASS := Color(0.28, 0.52, 0.24)
	const ROCK := Color(0.42, 0.40, 0.38)
	## Deliberately a distinct, cooler grey from ROCK above - ROCK is an
	## ALTITUDE band (the "mid-height" colour on a gentle slope), while this
	## is a SLOPE override applied regardless of altitude. Using the same
	## colour for both would mean a steep cliff just looks like "more of
	## whatever altitude band it happens to sit in" instead of reading as
	## actual bare exposed stone.
	const STONE_GREY := Color(0.56, 0.57, 0.59)
	const SNOW := Color(0.92, 0.94, 0.96)

	var base: Color
	if altitude < 0.45:
		# Mud wants to be low AND flat - a flood-plain/lakebed, not just
		# "anything near the water". A steep bank at the same altitude (the
		# waterline meeting an actual slope, not a flat shore) reads as
		# ordinary sand instead, which is what slope blends toward here.
		var shore: Color = MUD.lerp(SAND, clampf(slope / 0.3, 0.0, 1.0))
		base = shore.lerp(GRASS, clampf(altitude / 0.45, 0.0, 1.0))
	elif altitude < 0.8:
		base = GRASS.lerp(ROCK, clampf((altitude - 0.45) / 0.35, 0.0, 1.0))
	else:
		base = ROCK.lerp(SNOW, clampf((altitude - 0.8) / 0.2, 0.0, 1.0))
	return base.lerp(STONE_GREY, clampf((slope - 0.35) / 0.4, 0.0, 1.0))


## Builds collision from the well-conditioned subset of the ground tetrahedra
## rather than from the finished mesh.
##
## [method ConcaveMeshShape4D.create_from_mesh] would take the mesh whole, and
## a single sliver in it fails the entire shape - which on flat-faceted models
## is close to guaranteed. Feeding [method ConcaveMeshShape4D.set_simplex_cells]
## the filtered subset directly keeps the visible mesh complete while giving
## the physics side only what it can actually invert. The excluded tetrahedra
## are too thin to have meaningfully contributed a collision surface anyway.
func _update_collision(contour: MultiVertexDualContour4D, center: float) -> void:
	var collision_shape: CollisionShape4D = _get_collision_shape()
	if collision_shape == null:
		return
	if not generate_collision or contour.ground_collision_cells.is_empty():
		collision_shape.shape = null
		return

	var offset := Vector4(center, center, center, center)
	var simplex_cells := PackedVector4Array()
	simplex_cells.resize(contour.ground_collision_cells.size())
	for i in range(contour.ground_collision_cells.size()):
		var vertex_index: int = contour.ground_collision_cells[i]
		simplex_cells[i] = (contour.vertices[vertex_index] - offset) * cell_size

	var shape := ConcaveMeshShape4D.new()
	shape.set_simplex_cells(simplex_cells)
	collision_shape.shape = shape
