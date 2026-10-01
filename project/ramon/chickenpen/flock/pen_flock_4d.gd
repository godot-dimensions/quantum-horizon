extends Node4D

## A murmuration: starlings gathering over the field at dusk, in four dimensions.
##
## THE MODEL IS BOIDS WITH THE FOUR THINGS FIELD STUDIES ADDED. Reynolds' three rules -
## keep apart, match heading, move towards the others - are plain vector sums, so they run
## unchanged on Vector4 and the flock is a 4D flock for free. On top of them:
##   1. Seven neighbours, not a radius. Starlings track about seven birds whatever the
##      distance (Ballerini et al. 2008). Each bird grows or shrinks its own search radius
##      until about [member neighbours] birds fall inside it, as Hemelrijk's StarDisplay
##      does, which is that rule without a sort.
##   2. Turning inertia. The turn rate follows what the neighbours ask for with a lag of
##      [member turn_inertia] seconds instead of snapping to it. With it a turn crosses the
##      flock as a wave that keeps its size; without it the turn blurs out and fades
##      (Attanasi et al. 2014, the inertial spin model).
##   3. Cohesion scaled by how far out a bird is. A bird whose neighbours all sit to one
##      side is on the border and is pulled in hard; one in the middle hardly at all. That
##      is what makes the border denser than the middle, as measured.
##   4. A roost, a height band and a band in W. Birds that stray past [member roost_radius]
##      are called back, which is where the sweeping turns come from.
##
## A HAWK COMES THROUGH EVERY HALF MINUTE OR SO, and the flock's answer is the dark band
## that runs across a murmuration (Hemelrijk et al. 2015, "Agitation waves"). Birds close to
## it flee - which opens a hole around it - and roll hard to one side. A bird that sees a
## neighbour roll copies it after [member reaction_delay], and that copying is the wave: it
## is a wave of ORIENTATION, not of crowding. The rolled birds show the viewer their wings
## edge-on or flat instead of the usual, so the band is a change in how dark the flock looks,
## travelling at hop distance / reaction time.
##
## IT IS DRAWN AS ONE 3D MULTIMESH, NOT A NODE PER BIRD. The Cross-section engine renders in
## camera space into its own World3D (godot_3d_rendering_engine_4d.cpp: the 3D camera sits
## at the origin with no transform), so an instance added to that world is in the same
## picture. flock_bird.gdshader does the 4D part: it moves each bird into the camera's frame
## and cuts it at the slice, the way the engine cuts a tetrahedral mesh. One draw call for
## the whole flock, and the CPU writes twenty floats a bird.
##
## THE SIMULATION RUNS ON THE GPU WHEN THERE IS ONE, on the CPU when there is not. The
## GDScript step is the reference: headless runners (which have no GPU) step it and measure
## it. Measured in the pen, 300 birds cost 1.65 ms a frame of which 1.55 ms was that step
## (3.4 us a bird), so it stops at a few hundred birds. flock_step.glsl is the same model as
## a compute shader, for thousands: the rules, the flight and the drawing data all stay on
## the GPU, written straight into the multimesh's own buffer, and nothing comes back.

const METRICS := preload("res://ramon/chickenpen/flock/flock_metrics_4d.gd")
const SHADER := preload("res://ramon/chickenpen/flock/flock_bird.gdshader")
const COMPUTE := "res://ramon/chickenpen/flock/flock_step.glsl"
const G := 9.81
const FLOATS := 20
## Hash buckets for the GPU grid - a power of two, and a multiple of the 256-thread
## workgroup the scan runs in.
const BUCKETS := 16384
const GROUP := 256
## vec4 rows of settings the compute shader reads.
const PARAM_ROWS := 15
## For the sound: a bird this far from the camera counts half, and then it falls with the
## square of distance, as sound power does.
const SOUND_NEAR := 6.0

@export_group("Flock")
## 300 is about all the CPU step manages (1.65 ms); on the GPU, measured in the pen on an
## RTX 5080 at 1280x720: 2,000 birds 0.42 ms a frame, 5,000 0.67 ms, 10,000 0.84 ms.
@export_range(0, 20000) var count: int = 5000
## Where the flock is stepped. Auto is the GPU when the renderer has a RenderingDevice
## (Forward+ and Mobile do; Compatibility and --headless do not), the CPU otherwise.
@export_enum("Auto", "CPU", "GPU") var backend: int = 0
## On Auto without a GPU, the flock is cut to this many birds: the CPU step costs 4 us a
## bird, so the GPU's 5,000 would be a 20 ms frame.
@export_range(0, 2000) var cpu_count: int = 300
@export var flock_seed: int = 5213
## Metres the drawn bird is scaled by. A starling is 0.22 m long with a 0.38 m span; at
## the distances the field is seen from, true size is a few pixels.
@export_range(0.5, 4.0, 0.05) var bird_scale: float = 1.6
@export_range(1.0, 30.0, 0.1, "suffix:m/s") var cruise_speed: float = 10.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var min_speed: float = 6.5
@export_range(1.0, 40.0, 0.1, "suffix:m/s") var max_speed: float = 15.0

@export_group("Neighbours")
## Birds each one pays attention to. 6.5 in StarDisplay, "about seven" in the field.
@export_range(1.0, 20.0, 0.5) var neighbours: float = 6.5
## The largest search radius, which is also the grid cell. Birds out on their own look
## this far and no further. Every bird tests the 27 cells around its own, so this is the
## GPU cost: 5,000 birds took 2.85 ms at 5 m and 1.6 ms at 3 m once a hawk had squeezed the
## flock (11.5 birds within reach, 0.74 m apart), 0.4 ms at 3 m spread out. Birds inside
## the flock settle at 1.2-2.4 m anyway.
@export_range(1.0, 20.0, 0.1, "suffix:m") var radius_max: float = 2.2
@export_range(0.1, 5.0, 0.1, "suffix:m") var separation_radius: float = 1.1
## Social rules are re-evaluated for 1 bird in this many each frame, round-robin. A bird
## reacting at 20 Hz is still faster than a starling's ~75 ms reaction time allows.
@export_range(1, 8) var social_every: int = 3
## Birds cannot see straight behind them. Cosine of the edge of the blind cone.
@export_range(-1.0, 0.0, 0.05) var blind_cos: float = -0.8

@export_group("Rules", "rule_")
@export_range(0.0, 80.0, 0.5, "suffix:m/s²") var rule_separation: float = 10.0
## Turn rate asked for per radian of heading difference, 1/s. With [member turn_inertia]
## this sets how fast a turn crosses the flock - roughly spacing x sqrt(alignment / inertia).
## Measured with _measure_flock_runner.gd (wave), 300 birds: 3.5 and 0.3 s crawled at 4 m/s
## and reached 15% of the flock; 14 and 0.05 s crossed 61% of it at 8.5 m/s and turned the
## far side as hard as the near one. Plain boids (no inertia) reached 5% and faded.
@export_range(0.0, 40.0, 0.05) var rule_alignment: float = 14.0
@export_range(0.0, 40.0, 0.5, "suffix:m/s²") var rule_cohesion: float = 7.0
@export_range(0.0, 10.0, 0.05, "suffix:m/s²") var rule_noise: float = 5.0
## A weak pull towards the whole flock's middle, felt only beyond [member rule_gather_from]
## metres of it - scaled by the cube root of the flock's size against 300 birds, or a big
## flock is squeezed into a ball (5,000 birds are ~30 m across; 8 m pulled them all in). Seven-neighbour cohesion on its own lets a flock of hundreds come apart
## into clumps of twenty within seconds (measured: the biggest group held 13-30% of the
## birds). In a real murmuration the roost and the sight of the mass hold it together;
## this is that, stated plainly.
@export_range(0.0, 10.0, 0.05, "suffix:m/s²") var rule_gather: float = 3.0
@export_range(0.0, 100.0, 0.5, "suffix:m") var rule_gather_from: float = 8.0

@export_group("Turning")
## How long the turn rate takes to follow a request. 0 is plain boids. See rule_alignment.
@export_range(0.0, 2.0, 0.01, "suffix:s") var turn_inertia: float = 0.05
@export_range(0.1, 8.0, 0.1, "suffix:rad/s") var max_turn_rate: float = 3.0
@export_range(0.0, 5.0, 0.05, "suffix:1/s") var speed_spring: float = 0.6
@export_range(0.0, 20.0, 0.1, "suffix:1/s") var bank_rate: float = 7.0

@export_group("Place")
## Where the murmuration gathers, in this node's space. y is ignored: the band is below.
## Beyond the pen from the spawn point, so the flock is seen against the sunset glow as
## soon as the game starts, and short of the rim hills at 115 m (27 m tall).
@export var roost: Vector4 = Vector4(0, 0, -68, 0)
@export_range(5.0, 200.0, 1.0, "suffix:m") var roost_radius: float = 22.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s²") var roost_pull: float = 6.0
## How much of the roost's pull is worked out from the flock's middle (1) rather than from
## each bird (0). See _integrate.
@export_range(0.0, 1.0, 0.05) var roost_as_one: float = 0.85
## Low enough to sit inside the spawn camera's view (its top edge is about 16 degrees up),
## high enough to clear the foothills where the flock swings out furthest.
@export_range(0.0, 200.0, 0.5, "suffix:m") var height_low: float = 12.0
@export_range(0.0, 300.0, 0.5, "suffix:m") var height_high: float = 26.0
@export_range(0.0, 5.0, 0.05, "suffix:1/s²") var height_pull: float = 0.8
## Every bird is drawn towards the same altitude, which wanders slowly through the band.
## That shared spring squeezes the flock vertically while separation spreads it sideways,
## and is what makes it a flat sheet rather than a ball (StarDisplay does the same).
@export_range(0.0, 3.0, 0.01, "suffix:1/s²") var altitude_pull: float = 0.25
@export_range(5.0, 300.0, 1.0, "suffix:s") var altitude_period: float = 47.0
## Half the flock's depth along W. Thin, and it reads as a 3D flock you can walk out of;
## deep, and the slice you stand in shows a different flock every step through W.
@export_range(0.0, 50.0, 0.05, "suffix:m") var w_half_depth: float = 0.25
@export_range(0.0, 10.0, 0.05, "suffix:1/s²") var w_pull: float = 3.0
## Birds fly level: climbing or sinking is damped, and so is drifting along W. Without it
## the height and W bands are springs with a lagging turn on them, and they ring - each
## overshoot larger than the last, until the flock is 40 m tall and 8 m deep in W.
@export_range(0.0, 10.0, 0.05, "suffix:1/s") var level_flight: float = 0.5
@export_range(0.0, 10.0, 0.05, "suffix:1/s") var w_level: float = 2.5
## Half a bird's own depth along W at bird_scale 1. The slice shows it whole at its w and
## shrinking to nothing this far off it.
@export_range(0.05, 5.0, 0.01, "suffix:m") var bird_w_radius: float = 0.35
## One bird drawn white, by index, or none (-1). Off in the pen; the Lookout turns it on for
## its white starling (lookout/photo_judge_4d.gd finds it by this index at the shutter).
@export var white_bird: int = -1

@export_group("Hawk")
@export var hawk_enabled: bool = true
## Seconds between hawks, drawn between these two.
@export_range(5.0, 300.0, 1.0, "suffix:s") var hawk_every_min: float = 25.0
@export_range(5.0, 300.0, 1.0, "suffix:s") var hawk_every_max: float = 45.0
## Faster than the flock: a sparrowhawk cruises at about 12 m/s and stoops at 20-25,
## against the starlings' 10.
@export_range(5.0, 40.0, 0.5, "suffix:m/s") var hawk_speed: float = 14.0
@export_range(5.0, 60.0, 0.5, "suffix:m/s") var hawk_stoop_speed: float = 24.0
## Its size against a starling's at bird_scale, far from the camera. Ramon, 1 Oct: the first
## hawk, a starling scaled up, "I thought it was some stray starlings". At 1.5 (a 1.6 m
## span) the new shape was a few pixels from the spawn point, 100 m off; 2.4 (2.5 m) reads
## there - and was a pterodactyl when it flew past the camera. So it grows with distance,
## from [member hawk_near_scale] within 20 m to this beyond 90 m.
@export_range(0.5, 4.0, 0.05) var hawk_scale: float = 2.4
@export_range(0.5, 4.0, 0.05) var hawk_near_scale: float = 1.0
## The share of hawks that dive in over the far side of the flock from wherever the camera
## is, at a random angle of up to [member hawk_spread_degrees] either side, so the attack is
## seen; the rest come from anywhere. Ramon: "slightly offset the randomizer so it feels
## less staged".
@export_range(0.0, 1.0, 0.05) var hawk_seen_share: float = 0.75
@export_range(0.0, 180.0, 1.0, "suffix:°") var hawk_spread_degrees: float = 55.0
## Birds this close to the hawk flee and roll without waiting for a neighbour.
@export_range(1.0, 30.0, 0.5, "suffix:m") var scare_radius: float = 9.0
@export_range(0.0, 80.0, 0.5, "suffix:m/s²") var flee: float = 22.0
## How long a bird takes to copy a rolling neighbour - with the distance between them,
## this is the agitation wave's speed. Measured in real murmurations: about 13 m/s. Measured
## here (_measure_flock_runner.gd agitate, CPU, 300 birds): 0.08 s ran at 9.2 m/s, 0.12 s at
## 6.8 m/s, both across the whole flock - about a metre a hop. The CPU path adds ~25 ms a
## hop by only looking at neighbours every third frame; the GPU path looks every frame, so
## 0.07 s is about 14 m/s there, 10 on the CPU.
@export_range(0.01, 1.0, 0.005, "suffix:s") var reaction_delay: float = 0.07
@export_range(0.1, 3.0, 0.05, "suffix:s") var agitation_time: float = 0.7
## How far over a startled bird rolls, radians. The band is made of this.
@export_range(0.0, 1.6, 0.05) var agitation_roll: float = 1.3
## After a roll, how long before a bird will copy another one. Without it the wave bounces
## back and forth through the flock for ever.
@export_range(0.0, 5.0, 0.05, "suffix:s") var agitation_rest: float = 1.4
## The sideways jink that goes with the roll.
@export_range(0.0, 40.0, 0.5, "suffix:m/s²") var jink: float = 9.0

## Set while a runner drives step() itself.
var manual: bool = false
## Set by runners: time the GPU step with RenderingDevice timestamps into [member gpu_usec].
var profile_gpu: bool = false
var gpu_usec: float = 0.0
## Microseconds the last step() plus upload took, and a running mean.
var last_step_usec: float = 0.0
var mean_step_usec: float = 0.0

var _pos := PackedVector4Array()
var _head := PackedVector4Array()
var _turn := PackedVector4Array()
var _social := PackedVector4Array()
var _speed := PackedFloat32Array()
var _bank := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _centrality := PackedFloat32Array()
var _seen := PackedInt32Array()
var _phase := PackedFloat32Array()
var _tint := PackedFloat32Array()
var _wander := PackedVector4Array()
## A heading a bird has been told to take (zero when none) and for how much longer.
var _lead := PackedVector4Array()
var _lead_left := PackedFloat32Array()
## Agitation: how far through its roll a bird is (1 fresh, 0 calm), the reaction time left
## before it starts one, the rest left before it will copy again, and which way it rolls.
var _agit := PackedFloat32Array()
var _agit_wait := PackedFloat32Array()
var _agit_rest := PackedFloat32Array()
var _agit_sign := PackedFloat32Array()

enum HawkState { AWAY, HUNTING, LEAVING }
var _hawk_state: int = HawkState.AWAY
var _hawk_timer: float = 12.0
var _hawk_pos := Vector4(0.0, -1000.0, 0.0, 0.0)
var _hawk_head := Vector4(1.0, 0.0, 0.0, 0.0)
var _hawk_speed_now: float = 14.0
var _hawk_bank: float = 0.0
## Where in the flock it is going: an offset from the middle, so it does not always hit
## the dead centre.
var _hawk_aim := Vector4.ZERO
## The hawk has its own shape, so its own one-bird multimesh, drawn by the same material.
var _hawk_mesh: ArrayMesh
var _hawk_multimesh := RID()
var _hawk_instance := RID()
## Where the camera was at the last draw - the hawk comes in where it can be seen - and
## its W axis, both in the flock's space, for counting the birds in the camera's slice.
var _viewer := Vector4.ZERO
var _viewer_ana := Vector4(0.0, 0.0, 0.0, 1.0)
var _viewer_right := Vector4(1.0, 0.0, 0.0, 0.0)
var _viewer_known: bool = false
## The numbers the stats panel shows, refreshed as they come in: from the GPU's reduce pass
## a frame or so late, or summed by the CPU step. See stats().
var _sums := PackedFloat32Array()
var _nearest := PackedFloat32Array()
var _middle_pending: bool = false
var _buffer := PackedFloat32Array()

var _keys := PackedInt64Array()
var _cell_start := PackedInt32Array()
var _cell_end := PackedInt32Array()
var _sorted := PackedInt32Array()
var _grid_lo := Vector4.ZERO
var _grid_cell: float = 5.0
var _dim_x: int = 1
var _dim_y: int = 1
var _dim_z: int = 1

var _frame: int = 0
var _time: float = 0.0
## The flock's middle and mean heading, from the frame before.
var _middle := Vector4.ZERO
var _mean_heading := Vector4.ZERO
var _rng := RandomNumberGenerator.new()

var _mesh: ArrayMesh
var _material: ShaderMaterial
var _multimesh := RID()
var _instance := RID()
var _scenario := RID()

var _rd: RenderingDevice
var _gpu: bool = false
var _gpu_shader := RID()
var _gpu_pipeline := RID()
var _gpu_buffers: Dictionary = {}
## Two uniform sets, positions and headings swapped between them: set 0 reads A and writes
## B, set 1 the other way. _parity is the one the next step reads with.
var _gpu_sets: Array[RID] = []
var _parity: int = 0


func _ready() -> void:
	_mesh = _bird_mesh()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_multimesh = RenderingServer.multimesh_create()
	RenderingServer.multimesh_set_mesh(_multimesh, _mesh.get_rid())
	_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_instance, _multimesh)
	RenderingServer.instance_geometry_set_material_override(_instance, _material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	# Its transforms are 4D data, not 3D placements, so the AABB Godot would work out from
	# them is meaningless. The shader puts every bird where it belongs.
	RenderingServer.instance_set_ignore_culling(_instance, true)
	# And it still needs one: an instance whose AABB has no surface is never indexed into
	# its scenario, so ignore_culling never gets a say (renderer_scene_cull.cpp,
	# _update_instance). On the CPU every set_buffer happens to give it one; the GPU path
	# never calls set_buffer, and its flock stepped perfectly and drew nothing.
	RenderingServer.instance_set_custom_aabb(_instance, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(_instance, false)
	_hawk_mesh = _hawk_shape()
	_hawk_multimesh = RenderingServer.multimesh_create()
	RenderingServer.multimesh_set_mesh(_hawk_multimesh, _hawk_mesh.get_rid())
	RenderingServer.multimesh_allocate_data(_hawk_multimesh, 1, RenderingServer.MULTIMESH_TRANSFORM_3D, true, true)
	_hawk_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_hawk_instance, _hawk_multimesh)
	RenderingServer.instance_geometry_set_material_override(_hawk_instance, _material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(_hawk_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_ignore_culling(_hawk_instance, true)
	RenderingServer.instance_set_custom_aabb(_hawk_instance, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(_hawk_instance, false)
	_rd = RenderingServer.get_rendering_device()
	_gpu = backend != 1 and _rd != null
	if backend == 2 and _rd == null:
		push_warning("Flock: no RenderingDevice here (Compatibility or headless), stepping on the CPU.")
	if not _gpu and backend == 0:
		count = mini(count, cpu_count)
	respawn()
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


func _exit_tree() -> void:
	if _instance.is_valid():
		RenderingServer.instance_set_visible(_instance, false)
	if _hawk_instance.is_valid():
		RenderingServer.instance_set_visible(_hawk_instance, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if RenderingServer4D.pre_render.is_connected(_on_pre_render):
			RenderingServer4D.pre_render.disconnect(_on_pre_render)
		_gpu_free()
		if _instance.is_valid():
			RenderingServer.free_rid(_instance)
		if _multimesh.is_valid():
			RenderingServer.free_rid(_multimesh)
		if _hawk_instance.is_valid():
			RenderingServer.free_rid(_hawk_instance)
		if _hawk_multimesh.is_valid():
			RenderingServer.free_rid(_hawk_multimesh)


## Start over: [member count] birds in a loose cloud over the roost, heading roughly the
## same way.
func respawn() -> void:
	_rng.seed = flock_seed
	var n: int = count
	# One by one: packed arrays are values, so resizing them through a list resizes copies.
	_pos.resize(n)
	_head.resize(n)
	_turn.resize(n)
	_social.resize(n)
	_wander.resize(n)
	_lead.resize(n)
	_lead_left.resize(n)
	_agit.resize(n)
	_agit_wait.resize(n)
	_agit_rest.resize(n)
	_agit_sign.resize(n)
	_speed.resize(n)
	_bank.resize(n)
	_radius.resize(n)
	_centrality.resize(n)
	_phase.resize(n)
	_tint.resize(n)
	_seen.resize(n)
	_nearest.resize(n)
	_nearest.fill(0.0)
	_keys.resize(n)
	_sorted.resize(n)
	_buffer.resize(n * FLOATS)
	var mid: float = (height_low + height_high) * 0.5
	# About a metre between birds from the start: sparser, and the flock begins as clumps.
	var spread: float = pow(float(maxi(n, 1)), 1.0 / 3.0) * 0.55
	var yaw: float = _rng.randf() * TAU
	var along := Vector4(cos(yaw), 0.0, sin(yaw), 0.0)
	for i in n:
		_pos[i] = Vector4(roost.x + _rng.randfn(0.0, spread * 2.0), mid + _rng.randfn(0.0, spread * 0.4),
			roost.z + _rng.randfn(0.0, spread), roost.w + _rng.randfn(0.0, w_half_depth * 0.5))
		_head[i] = (along + Vector4(_rng.randfn(0.0, 0.25), _rng.randfn(0.0, 0.05), _rng.randfn(0.0, 0.25), 0.0)).normalized()
		_turn[i] = Vector4.ZERO
		_social[i] = Vector4.ZERO
		_wander[i] = Vector4.ZERO
		_lead[i] = Vector4.ZERO
		_lead_left[i] = 0.0
		_agit[i] = 0.0
		_agit_wait[i] = 0.0
		_agit_rest[i] = 0.0
		_agit_sign[i] = 1.0
		_speed[i] = cruise_speed * _rng.randf_range(0.9, 1.1)
		_bank[i] = 0.0
		_radius[i] = radius_max * 0.5
		_centrality[i] = 0.0
		_seen[i] = 0
		_phase[i] = _rng.randf()
		_tint[i] = _rng.randf_range(0.75, 1.3)
	_frame = 0
	_time = 0.0
	_middle = METRICS.centre(_pos)
	_mean_heading = METRICS.centre(_head)
	_hawk_state = HawkState.AWAY
	_hawk_timer = _rng.randf_range(10.0, 16.0)
	_hawk_pos = Vector4(0.0, -1000.0, 0.0, 0.0)
	RenderingServer.multimesh_allocate_data(_multimesh, n, RenderingServer.MULTIMESH_TRANSFORM_3D, true, true)
	_upload()
	if _gpu:
		_gpu_free()
		_gpu_init()


func _process(delta: float) -> void:
	if manual or count == 0:
		return
	if _gpu:
		gpu_step(minf(delta, 1.0 / 30.0))
	else:
		step(minf(delta, 1.0 / 30.0))


## True when the flock is being stepped by flock_step.glsl.
func on_gpu() -> bool:
	return _gpu


## One tick of the flock and the upload of what it looks like.
func step(dt: float) -> void:
	var started: int = Time.get_ticks_usec()
	if _pos.size() != count:
		respawn()
	if count > 0:
		_hawk_step(dt)
		_build_grid()
		for i in range(_frame % social_every, count, social_every):
			_social_rules(i)
		_integrate(dt)
		_draw_hawk()
		_upload()
	_frame += 1
	_time += dt
	last_step_usec = float(Time.get_ticks_usec() - started)
	mean_step_usec = last_step_usec if _frame <= 1 else lerpf(mean_step_usec, last_step_usec, 0.05)


## The birds sorted by grid cell: a key per bird of cell and index, one native sort, and
## a pass marking where each cell's run starts and ends. The grid covers the flock's own
## bounds and only (x, y, z); a flock deep in W just puts more birds in each cell.
func _build_grid() -> void:
	var lo: Vector4 = _pos[0]
	var hi: Vector4 = lo
	for p in _pos:
		lo = lo.min(p)
		hi = hi.max(p)
	var cell: float = radius_max
	var size := Vector3(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
	var total: float = (floorf(size.x / cell) + 1.0) * (floorf(size.y / cell) + 1.0) * (floorf(size.z / cell) + 1.0)
	if total > 65536.0:
		# A flock torn across the sky: coarser cells rather than a huge grid.
		cell *= pow(total / 65536.0, 1.0 / 3.0) * 1.05
	_grid_cell = cell
	_grid_lo = lo
	_dim_x = int(size.x / cell) + 1
	_dim_y = int(size.y / cell) + 1
	_dim_z = int(size.z / cell) + 1
	var cells: int = _dim_x * _dim_y * _dim_z
	if _cell_start.size() != cells:
		_cell_start.resize(cells)
		_cell_end.resize(cells)
	_cell_start.fill(0)
	_cell_end.fill(0)
	var inv: float = 1.0 / cell
	var n: int = count
	for i in n:
		var p: Vector4 = _pos[i]
		var c: int = (int((p.z - lo.z) * inv) * _dim_y + int((p.y - lo.y) * inv)) * _dim_x + int((p.x - lo.x) * inv)
		_keys[i] = (c << 16) | i
	_keys.sort()
	var previous: int = -1
	for k in n:
		var key: int = _keys[k]
		var c: int = key >> 16
		_sorted[k] = key & 0xFFFF
		if c != previous:
			if previous >= 0:
				_cell_end[previous] = k
			_cell_start[c] = k
			previous = c
	_cell_end[previous] = n


## The three rules for bird [param i], kept until its next turn comes round.
func _social_rules(i: int) -> void:
	var p: Vector4 = _pos[i]
	var h: Vector4 = _head[i]
	var r: float = _radius[i]
	var r2: float = r * r
	var sep_r: float = separation_radius
	var sep2: float = sep_r * sep_r
	var inv: float = 1.0 / _grid_cell
	var cx: int = int((p.x - _grid_lo.x) * inv)
	var cy: int = int((p.y - _grid_lo.y) * inv)
	var cz: int = int((p.z - _grid_lo.z) * inv)
	var x0: int = maxi(cx - 1, 0)
	var x1: int = mini(cx + 2, _dim_x)
	var y0: int = maxi(cy - 1, 0)
	var y1: int = mini(cy + 2, _dim_y)
	var z0: int = maxi(cz - 1, 0)
	var z1: int = mini(cz + 2, _dim_z)
	var sep := Vector4.ZERO
	var align := Vector4.ZERO
	var toward := Vector4.ZERO
	var lean := Vector4.ZERO
	var seen: int = 0
	var alarm: float = 0.0
	var closest: float = INF
	for gz in range(z0, z1):
		for gy in range(y0, y1):
			var row: int = (gz * _dim_y + gy) * _dim_x
			for gx in range(x0, x1):
				var c: int = row + gx
				for k in range(_cell_start[c], _cell_end[c]):
					var j: int = _sorted[k]
					if j == i:
						continue
					var d: Vector4 = _pos[j] - p
					var dd: float = d.length_squared()
					if dd < closest:
						closest = dd
					if dd > r2 or dd < 1e-8:
						continue
					var dl: float = sqrt(dd)
					if d.dot(h) < blind_cos * dl:
						continue
					var u: Vector4 = d / dl
					seen += 1
					lean += u
					toward += d
					align += _head[j]
					if dd < sep2:
						sep -= u * (1.0 - dl / sep_r)
					# A neighbour just starting its roll: copy it, same way over.
					if _agit[j] > 0.5:
						alarm = _agit_sign[j]
	if alarm != 0.0 and _agit[i] <= 0.0 and _agit_wait[i] <= 0.0 and _agit_rest[i] <= 0.0:
		_agit_wait[i] = reaction_delay * _rng.randf_range(0.7, 1.3)
		_agit_sign[i] = alarm
	# Grow or shrink the search until about `neighbours` birds are in it.
	_radius[i] = clampf(r * (1.0 + 0.12 * (neighbours - float(seen)) / neighbours), separation_radius, radius_max)
	_seen[i] = seen
	_nearest[i] = sqrt(closest) if closest < INF else radius_max
	var acc: Vector4 = sep * rule_separation
	if seen > 0:
		var n: float = float(seen)
		var centrality: float = lean.length() / n
		_centrality[i] = centrality
		var heading: Vector4 = align / n
		acc += (heading - h) * (rule_alignment * _speed[i])
		var to_middle: Vector4 = toward / n
		var tl: float = to_middle.length()
		if tl > 1e-5:
			acc += to_middle * (rule_cohesion * centrality / tl)
	else:
		_centrality[i] = 1.0
	# A slow private drift, so no two birds are exactly alike. Changed here, at the social
	# rate, rather than every frame: four random numbers a bird a frame are not free.
	var wander: Vector4 = _wander[i].lerp(Vector4(_rng.randfn(), _rng.randfn() * 0.3, _rng.randfn(), _rng.randfn() * 0.3), 0.08)
	_wander[i] = wander
	_social[i] = acc + wander * rule_noise


## Everything that is not a neighbour - roost, height, W, noise - and the flight itself,
## then the twenty floats the shader reads.
func _integrate(dt: float) -> void:
	var n: int = count
	var inertia: float = turn_inertia
	var follow: float = 1.0 if inertia <= dt else dt / inertia
	var bank_follow: float = minf(dt * bank_rate, 1.0)
	var rx: float = roost.x
	var rz: float = roost.z
	var rw: float = roost.w
	var far: float = roost_radius
	var w_half: float = w_half_depth
	var level: float = level_flight
	var w_level_gain: float = w_level
	var band: float = (height_high - height_low) * 0.5
	var altitude: float = height_low + band + sin(_time * TAU / altitude_period) * band * 0.45
	var altitude_gain: float = altitude_pull
	var scale: float = bird_scale
	var lead_gain: float = rule_alignment * 3.0 + 4.0
	var middle: Vector4 = _middle
	var as_one: float = roost_as_one
	# Heading straight away from home, the pull home points straight behind a bird and asks
	# for almost no turn at all, so tiny differences decide left or right - and half the flock
	# goes each way. The side is chosen once, for the whole flock, from its mean heading, and
	# every bird is asked to turn that way as hard as the flock is pointing away.
	var home := Vector2(roost.x - middle.x, roost.z - middle.z)
	var home_d: float = home.length()
	var mean := Vector2(_mean_heading.x, _mean_heading.z)
	var side_push := Vector4.ZERO
	if home_d > roost_radius * 0.6 and mean.length() > 0.05:
		home /= home_d
		mean = mean.normalized()
		var away: float = -home.dot(mean)
		if away > -0.2:
			var turn_sign: float = 1.0 if mean.cross(home) >= 0.0 else -1.0
			var ramp: float = smoothstep(roost_radius * 0.6, roost_radius * 1.4, home_d)
			side_push = Vector4(-mean.y, 0.0, mean.x, 0.0) * (turn_sign * roost_pull * ramp * as_one * clampf(away + 0.2, 0.0, 1.0))
	var gather: float = rule_gather
	var gather_from: float = _gather_from()
	var hawk_here: bool = _hawk_state != HawkState.AWAY
	var hawk: Vector4 = _hawk_pos
	var scare: float = scare_radius
	var sum := Vector4.ZERO
	var heading_sum := Vector4.ZERO
	var squares := Vector4.ZERO
	var crosses := Vector3.ZERO
	var nearest_sum: float = 0.0
	var seen_sum: int = 0
	var rolling: int = 0
	var in_slice: int = 0
	var slice_depth: float = bird_w_radius * bird_scale
	var viewer: Vector4 = _viewer
	var ana: Vector4 = _viewer_ana
	var heard: float = 0.0
	var heard_rolling: float = 0.0
	var heard_from := Vector4.ZERO
	var near2: float = SOUND_NEAR * SOUND_NEAR
	for i in n:
		var p: Vector4 = _pos[i]
		var h: Vector4 = _head[i]
		var s: float = _speed[i]
		var acc: Vector4 = _social[i]
		var side := Vector4(h.z, 0.0, -h.x, 0.0)
		var side_l: float = side.length()
		side = side / side_l if side_l > 0.05 else Vector4(1.0, 0.0, 0.0, 0.0)
		if hawk_here:
			var from_hawk: Vector4 = p - hawk
			var fh: float = from_hawk.length()
			if fh < scare and fh > 0.001:
				acc += from_hawk * (flee * (1.0 - fh / scare) / fh)
				if _agit[i] <= 0.0 and _agit_wait[i] <= 0.0 and _agit_rest[i] <= 0.0:
					_agit_wait[i] = reaction_delay * 0.5
					_agit_sign[i] = 1.0 if from_hawk.dot(side) >= 0.0 else -1.0
		if _agit_wait[i] > 0.0:
			_agit_wait[i] -= dt
			if _agit_wait[i] <= 0.0:
				_agit[i] = 1.0
				_agit_rest[i] = agitation_time + agitation_rest
		if _agit_rest[i] > 0.0:
			_agit_rest[i] -= dt
		var ag: float = _agit[i]
		var roll: float = 0.0
		if ag > 0.0:
			var envelope: float = sin(ag * PI)
			roll = _agit_sign[i] * agitation_roll * envelope
			acc += side * (_agit_sign[i] * jink * envelope)
			_agit[i] = maxf(ag - dt / agitation_time, 0.0)
		if _lead_left[i] > 0.0:
			# Told to go somewhere - startled, or fleeing - and meaning it: this outweighs the
			# neighbours, so the others have to follow rather than the bird giving in.
			_lead_left[i] -= dt
			acc += (_lead[i] - h) * (s * lead_gain)
		var to_middle: Vector4 = middle - p
		var md: float = to_middle.length()
		if md > gather_from:
			acc += to_middle * (gather * minf((md - gather_from) / gather_from, 1.0) / md)
		# Home: pulled back horizontally, from nothing at 0.6 of the roost radius to the full
		# pull at 1.4 of it, measured mostly from the flock's middle rather than the bird.
		# Measured from each bird, the front of the flock turned while the back flew on and
		# every U-turn tore it into pieces (biggest group 20-40% after each one). Measured
		# from the middle, every bird is asked for nearly the same turn and the flock turns
		# as one - equal-radius paths, which is what filmed flocks do.
		var hx: float = lerpf(p.x, middle.x, as_one)
		var hz: float = lerpf(p.z, middle.z, as_one)
		var dx: float = rx - hx
		var dz: float = rz - hz
		var dist: float = sqrt(dx * dx + dz * dz)
		if dist > far * 0.6:
			var pull: float = smoothstep(far * 0.6, far * 1.4, dist) * roost_pull / dist
			acc.x += dx * pull
			acc.z += dz * pull
		acc += side_push
		acc.y += (altitude - p.y) * altitude_gain
		if p.y < height_low:
			acc.y += minf((height_low - p.y) * height_pull, 8.0)
		elif p.y > height_high:
			acc.y -= minf((p.y - height_high) * height_pull, 8.0)
		acc.y -= h.y * s * level
		acc.w -= h.w * s * w_level_gain
		var dw: float = p.w - rw
		if dw > w_half:
			acc.w -= (dw - w_half) * w_pull
		elif dw < -w_half:
			acc.w -= (dw + w_half) * w_pull
		# Split the pull into along (speed) and across (turning).
		var along: float = acc.dot(h)
		var across: Vector4 = acc - h * along
		var want: Vector4 = across / maxf(s, 1.0)
		var turn: Vector4 = _turn[i].lerp(want, follow)
		var rate: float = turn.length()
		if rate > max_turn_rate:
			turn *= max_turn_rate / rate
		h = (h + turn * dt).normalized()
		turn -= h * turn.dot(h)
		s = clampf(s + ((cruise_speed - s) * speed_spring + along * 0.35) * dt, min_speed, max_speed)
		p += h * (s * dt)
		# Bank into the turn: tan(bank) = sideways acceleration / g.
		var right := Vector4(h.z, 0.0, -h.x, 0.0)
		var rl: float = right.length()
		right = right / rl if rl > 0.05 else Vector4(1.0, 0.0, 0.0, 0.0)
		var up := Vector4(-h.x * h.y, 1.0 - h.y * h.y, -h.z * h.y, -h.w * h.y)
		var ul: float = up.length()
		up = up / ul if ul > 0.05 else Vector4(0.0, 0.0, 1.0, 0.0)
		var bank: float = lerpf(_bank[i], -atan(turn.dot(right) * s / G), bank_follow)
		var cb: float = cos(bank + roll)
		var sb: float = sin(bank + roll)
		var wing: Vector4 = right * cb + up * sb
		_pos[i] = p
		sum += p
		heading_sum += h
		squares += p * p
		crosses += Vector3(p.x * p.y, p.x * p.z, p.y * p.z)
		nearest_sum += _nearest[i]
		seen_sum += _seen[i]
		if ag > 0.0:
			rolling += 1
		var off: Vector4 = p - viewer
		if absf(off.dot(ana)) < slice_depth:
			in_slice += 1
		# What the camera hears of this bird: power falling with the square of distance.
		var d2: float = off.length_squared()
		var loud: float = 1.0 / (1.0 + d2 / near2)
		heard += loud
		if ag > 0.0:
			heard_rolling += loud
		heard_from += off * (loud / sqrt(d2 + 0.01))
		_head[i] = h
		_turn[i] = turn
		_speed[i] = s
		_bank[i] = bank
		# Beating hard when climbing or slow, gliding in stretches otherwise.
		var glide: float = sin(_time * 0.9 + _phase[i] * TAU)
		var beat: float = clampf(0.55 + h.y * 3.0 + (cruise_speed - s) * 0.15 + (0.35 if glide > 0.2 else -0.45), 0.0, 1.0)
		if ag > 0.0:
			beat = 1.0
		var o: int = i * FLOATS
		_buffer[o] = p.x
		_buffer[o + 1] = p.y
		_buffer[o + 2] = p.z
		_buffer[o + 3] = p.w
		_buffer[o + 4] = h.x
		_buffer[o + 5] = h.y
		_buffer[o + 6] = h.z
		_buffer[o + 7] = h.w
		_buffer[o + 8] = wing.x
		_buffer[o + 9] = wing.y
		_buffer[o + 10] = wing.z
		_buffer[o + 11] = wing.w
		var t: float = _tint[i]
		_buffer[o + 12] = t
		_buffer[o + 13] = t
		_buffer[o + 14] = t
		_buffer[o + 15] = 1.0
		_buffer[o + 16] = _phase[i]
		_buffer[o + 17] = beat
		_buffer[o + 18] = scale
		_buffer[o + 19] = 0.0
	var inv_n: float = 1.0 / float(maxi(n, 1))
	_middle = sum * inv_n
	_mean_heading = heading_sum * inv_n
	var sq: Vector4 = squares * inv_n
	var cr: Vector3 = crosses * inv_n
	_sums = PackedFloat32Array([_middle.x, _middle.y, _middle.z, _middle.w, _mean_heading.x, _mean_heading.y, _mean_heading.z, _mean_heading.w,
		sq.x, sq.y, sq.z, sq.w, cr.x, cr.y, cr.z, 0.0, nearest_sum * inv_n, float(seen_sum) * inv_n, float(rolling), float(in_slice),
		heard, heard_rolling, 0.0, 0.0, heard_from.x, heard_from.y, heard_from.z, heard_from.w])


## Never on the GPU: the compute shader writes the buffer itself. It also must not: a
## multimesh_set_buffer made while any viewport wants motion vectors (TAA, FSR2) doubles
## the buffer and points drawing at its second half (mesh_storage.cpp, _multimesh_set_buffer),
## where the compute shader never writes.
func _upload() -> void:
	if _gpu:
		return
	if _multimesh.is_valid() and _buffer.size() == count * FLOATS and count > 0:
		RenderingServer.multimesh_set_buffer(_multimesh, _buffer)


## Just before the 4D engine draws: the flock into this camera's frame, in this viewport's
## world. The engine replaces the viewport's World3D on every engine switch and after a
## trip, so the scenario is checked each time rather than once.
func _on_pre_render(camera: Camera4D, viewport: Viewport, _engine: RenderingEngine4D) -> void:
	if viewport != get_viewport() or not _instance.is_valid():
		return
	var world: World3D = viewport.find_world_3d()
	var scenario: RID = world.scenario if world != null else RID()
	if scenario != _scenario:
		_scenario = scenario
		RenderingServer.instance_set_scenario(_instance, scenario)
		RenderingServer.instance_set_scenario(_hawk_instance, scenario)
	var shown: bool = is_visible_in_tree() and count > 0 and scenario.is_valid()
	RenderingServer.instance_set_visible(_instance, shown)
	RenderingServer.instance_set_visible(_hawk_instance, shown and _hawk_state != HawkState.AWAY)
	if not shown:
		return
	# In the flock's own space, which is where the hawk flies.
	_viewer = global_basis.inverse() * (camera.global_position - global_position)
	_viewer_ana = (global_basis.inverse() * (camera.global_basis * Vector4(0.0, 0.0, 0.0, 1.0))).normalized()
	_viewer_right = (global_basis.inverse() * (camera.global_basis * Vector4(1.0, 0.0, 0.0, 0.0))).normalized()
	_viewer_known = true
	var inverse: Projection = camera.global_basis.inverse()
	var basis: Projection = inverse * global_basis
	var origin: Vector4 = inverse * (global_position - camera.global_position)
	_material.set_shader_parameter("view_basis_x", basis.x)
	_material.set_shader_parameter("view_basis_y", basis.y)
	_material.set_shader_parameter("view_basis_z", basis.z)
	_material.set_shader_parameter("view_basis_w", basis.w)
	_material.set_shader_parameter("view_origin", origin)
	_material.set_shader_parameter("w_radius", bird_w_radius)
	_material.set_shader_parameter("white_index", white_bird if white_bird < count else -1)


## A starling at size 1, modelled +Z ahead: a pointed body, a short square tail and two
## swept, pointed wings. UV.x marks the wings for the shader - 0 on the body, rising to 1
## at each tip.
func _bird_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colours := PackedColorArray()
	var centre := Vector3(0.0, 0.002, 0.02)
	var nose := Vector3(0.0, 0.004, 0.115)
	var tail := Vector3(0.0, 0.004, -0.06)
	var left := Vector3(-0.024, 0.0, 0.02)
	var right := Vector3(0.024, 0.0, 0.02)
	var top := Vector3(0.0, 0.024, 0.025)
	var bottom := Vector3(0.0, -0.02, 0.02)
	var body: Array = [[nose, top, right], [nose, right, bottom], [nose, bottom, left], [nose, left, top],
		[tail, right, top], [tail, bottom, right], [tail, left, bottom], [tail, top, left]]
	for tri in body:
		_face(verts, normals, uvs, colours, tri, [0.0, 0.0, 0.0], centre)
	var tail_quad: Array = [Vector3(-0.013, 0.004, -0.055), Vector3(0.013, 0.004, -0.055), Vector3(0.03, 0.004, -0.105), Vector3(-0.03, 0.004, -0.105)]
	_face(verts, normals, uvs, colours, [tail_quad[0], tail_quad[1], tail_quad[2]], [0.0, 0.0, 0.0], centre + Vector3(0, -1, 0))
	_face(verts, normals, uvs, colours, [tail_quad[0], tail_quad[2], tail_quad[3]], [0.0, 0.0, 0.0], centre + Vector3(0, -1, 0))
	for side in [1.0, -1.0]:
		var a := Vector3(0.02 * side, 0.008, 0.05)
		var b := Vector3(0.02 * side, 0.008, -0.015)
		var c := Vector3(0.10 * side, 0.008, 0.035)
		var d := Vector3(0.10 * side, 0.008, -0.03)
		var e := Vector3(0.19 * side, 0.008, -0.045)
		var below := Vector3(0.0, -1.0, 0.0)
		_face(verts, normals, uvs, colours, [a, c, b], [0.01, 0.5, 0.01], below)
		_face(verts, normals, uvs, colours, [b, c, d], [0.01, 0.5, 0.5], below)
		_face(verts, normals, uvs, colours, [c, e, d], [0.5, 1.0, 0.5], below)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A sparrowhawk at size 1, +Z ahead: about 0.36 m long and 0.66 m across - a heavier body,
## broad wings with rounded, fingered tips, and a long tail. The silhouette is what tells it
## from the starlings at a distance: theirs are short-tailed little crosses with pointed,
## swept wings.
func _hawk_shape() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colours := PackedColorArray()
	var centre := Vector3(0.0, 0.004, 0.02)
	var nose := Vector3(0.0, 0.004, 0.12)
	var tail := Vector3(0.0, 0.006, -0.08)
	var left := Vector3(-0.042, 0.0, 0.02)
	var right := Vector3(0.042, 0.0, 0.02)
	var top := Vector3(0.0, 0.036, 0.03)
	var bottom := Vector3(0.0, -0.032, 0.02)
	var body: Array = [[nose, top, right], [nose, right, bottom], [nose, bottom, left], [nose, left, top],
		[tail, right, top], [tail, bottom, right], [tail, left, bottom], [tail, top, left]]
	for tri in body:
		_face(verts, normals, uvs, colours, tri, [0.0, 0.0, 0.0], centre)
	# The long tail, a little fanned and squared off.
	var below := centre + Vector3(0.0, -1.0, 0.0)
	var t0 := Vector3(-0.026, 0.006, -0.07)
	var t1 := Vector3(0.026, 0.006, -0.07)
	var t2 := Vector3(0.042, 0.006, -0.235)
	var t3 := Vector3(0.0, 0.006, -0.25)
	var t4 := Vector3(-0.042, 0.006, -0.235)
	_face(verts, normals, uvs, colours, [t0, t1, t2], [0.0, 0.0, 0.0], below)
	_face(verts, normals, uvs, colours, [t0, t2, t3], [0.0, 0.0, 0.0], below)
	_face(verts, normals, uvs, colours, [t0, t3, t4], [0.0, 0.0, 0.0], below)
	# Each wing a convex outline from the shoulder round the rounded tip, fanned from the
	# leading root. UV.x rises from the shoulder to the tip for the shader's flap.
	for side in [1.0, -1.0]:
		var outline: Array = [Vector2(0.035, 0.07), Vector2(0.16, 0.078), Vector2(0.26, 0.058), Vector2(0.33, 0.012),
			Vector2(0.325, -0.03), Vector2(0.29, -0.06), Vector2(0.2, -0.078), Vector2(0.12, -0.08), Vector2(0.035, -0.06)]
		var points: Array = []
		var flex: Array = []
		for o in outline:
			points.append(Vector3(o.x * side, 0.01, o.y))
			flex.append(clampf((o.x - 0.035) / 0.29, 0.01, 1.0))
		for k in range(1, points.size() - 1):
			_face(verts, normals, uvs, colours, [points[0], points[k], points[k + 1]], [flex[0], flex[k], flex[k + 1]], below)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## One flat triangle, its normal turned away from [param inside].
func _face(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colours: PackedColorArray,
		tri: Array, wing: Array, inside: Vector3) -> void:
	var a: Vector3 = tri[0]
	var b: Vector3 = tri[1]
	var c: Vector3 = tri[2]
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c) / 3.0 - inside) < 0.0:
		normal = -normal
	for k in 3:
		verts.append(tri[k])
		normals.append(normal)
		uvs.append(Vector2(float(wing[k]), 0.0))
		colours.append(Color.WHITE)


func _gather_from() -> float:
	return rule_gather_from * pow(maxf(float(count), 1.0) / 300.0, 1.0 / 3.0)


## The hawk. Away for a while; then, most times, out beyond the far side of the flock from
## the camera at a random angle either side, a little above it, so it comes in across the
## view and stoops into the flock - and otherwise in from anywhere, so it is not always the same show. It dives at
## a point near the middle, not on it, goes through, and climbs away.
func _hawk_step(dt: float) -> void:
	if not hawk_enabled:
		_hawk_state = HawkState.AWAY
		_hawk_pos = Vector4(0.0, -1000.0, 0.0, 0.0)
		return
	_hawk_timer -= dt
	var before: Vector4 = _hawk_head
	match _hawk_state:
		HawkState.AWAY:
			if _hawk_timer <= 0.0:
				_hawk_start()
		HawkState.HUNTING:
			var target: Vector4 = _middle + _mean_heading * 4.0 + _hawk_aim
			var to_target: Vector4 = target - _hawk_pos
			var want: Vector4 = to_target.normalized()
			_hawk_head = _hawk_head.lerp(want, minf(dt * 2.2, 1.0)).normalized()
			# Faster the steeper it dives.
			var stoop: float = clampf(-_hawk_head.y * 1.6, 0.0, 1.0)
			_hawk_speed_now = move_toward(_hawk_speed_now, lerpf(hawk_speed, hawk_stoop_speed, stoop), dt * 12.0)
			_hawk_pos += _hawk_head * (_hawk_speed_now * dt)
			# Through: close to the aim, or past it - a stoop that misses does not turn back.
			var past: bool = to_target.dot(_hawk_head) < 0.0 and to_target.length() < 15.0
			if to_target.length() < 2.5 or past or _hawk_timer <= 0.0:
				_hawk_state = HawkState.LEAVING
				_hawk_timer = 5.0
		HawkState.LEAVING:
			# Out the other side, levelling off and then climbing away.
			_hawk_head = (_hawk_head + Vector4(0.0, 0.5 * dt, 0.0, 0.0)).normalized()
			_hawk_speed_now = move_toward(_hawk_speed_now, hawk_speed, dt * 4.0)
			_hawk_pos += _hawk_head * (_hawk_speed_now * dt)
			if _hawk_timer <= 0.0:
				_hawk_state = HawkState.AWAY
				_hawk_timer = _rng.randf_range(hawk_every_min, hawk_every_max)
				_hawk_pos = Vector4(0.0, -1000.0, 0.0, 0.0)
	# Bank into its turns like the starlings do, a little slower.
	var turned: Vector4 = (_hawk_head - before) / maxf(dt, 0.0001)
	var side := Vector4(_hawk_head.z, 0.0, -_hawk_head.x, 0.0)
	side = side.normalized() if side.length() > 0.05 else Vector4(1.0, 0.0, 0.0, 0.0)
	_hawk_bank = lerpf(_hawk_bank, clampf(-atan(turned.dot(side) * _hawk_speed_now / G), -1.1, 1.1), minf(dt * 4.0, 1.0))


func _hawk_start() -> void:
	var flock_middle := Vector2(_middle.x, _middle.z)
	var from_viewer := Vector2(1.0, 0.0)
	var seen: bool = _viewer_known and _rng.randf() < hawk_seen_share
	if seen:
		var d := flock_middle - Vector2(_viewer.x, _viewer.z)
		if d.length() > 1.0:
			from_viewer = d.normalized()
		from_viewer = from_viewer.rotated(deg_to_rad(_rng.randf_range(-hawk_spread_degrees, hawk_spread_degrees)))
	else:
		from_viewer = Vector2.RIGHT.rotated(_rng.randf() * TAU)
	# Seen: far out beyond the flock and only a little above it, so whoever is watching the
	# flock has the hawk in view the whole way in - from high above it stayed off the top of
	# the spawn camera until it was already in the flock.
	var out: float = _rng.randf_range(60.0, 80.0) if seen else _rng.randf_range(35.0, 55.0)
	var up: float = _rng.randf_range(5.0, 12.0) if seen else _rng.randf_range(2.0, 14.0)
	# In the camera's slice along W when it can be seen, so a deep flock is still hit where
	# the player is looking; the flock's own W otherwise.
	var w: float = _viewer.w if seen else _middle.w
	_hawk_pos = Vector4(_middle.x + from_viewer.x * out, _middle.y + up, _middle.z + from_viewer.y * out, w)
	_hawk_head = (Vector4(_middle.x, _middle.y, _middle.z, w) - _hawk_pos).normalized()
	_hawk_aim = Vector4(_rng.randfn(0.0, 4.0), _rng.randfn(0.0, 1.5), _rng.randfn(0.0, 4.0), w - _middle.w)
	_hawk_speed_now = hawk_speed
	_hawk_bank = 0.0
	_hawk_state = HawkState.HUNTING
	_hawk_timer = 12.0


## The hawk's twenty floats and its draw. Slow deep beats in short bursts with glides
## between while it closes; wings held still in the stoop; flapping hard on the way out.
func _draw_hawk() -> void:
	if not _hawk_multimesh.is_valid():
		return
	var h: Vector4 = _hawk_head
	var right := Vector4(h.z, 0.0, -h.x, 0.0)
	right = right.normalized() if right.length() > 0.05 else Vector4(1.0, 0.0, 0.0, 0.0)
	var up := Vector4(-h.x * h.y, 1.0 - h.y * h.y, -h.z * h.y, -h.w * h.y)
	up = up.normalized() if up.length() > 0.05 else Vector4(0.0, 0.0, 1.0, 0.0)
	var wing: Vector4 = right * cos(_hawk_bank) + up * sin(_hawk_bank)
	var beat: float = 0.0
	if _hawk_state == HawkState.LEAVING:
		beat = 1.1
	elif _hawk_state == HawkState.HUNTING and h.y > -0.3:
		beat = 1.1 if fmod(_time, 2.4) < 1.0 else 0.0
	var p: Vector4 = _hawk_pos
	var away: float = (p - _viewer).length() if _viewer_known else 100.0
	var grow: float = lerpf(hawk_near_scale, hawk_scale, smoothstep(20.0, 90.0, away))
	# Custom w is the beat rate against a starling's: about 4 a second, not 11.
	var row := PackedFloat32Array([p.x, p.y, p.z, p.w, h.x, h.y, h.z, h.w, wing.x, wing.y, wing.z, wing.w,
		2.6, 2.2, 1.9, 1.0, 0.37, beat, bird_scale * grow, 0.36])
	RenderingServer.multimesh_set_buffer(_hawk_multimesh, row)


## The flock in numbers, for the stats panel: how many and where they are stepped, what a
## step costs, how ordered and how spaced they are, the shape, how many birds each one
## follows, how many the camera's slice cuts through, how many are rolling, and the hawk.
## Built from moments summed over every bird, on whichever side steps it - nothing here
## walks the flock.
func stats() -> Dictionary:
	var out: Dictionary = {
		"birds": count, "backend": "GPU" if _gpu else "CPU",
		"cpu_ms": last_step_usec / 1000.0, "gpu_ms": gpu_usec / 1000.0 if _gpu else -1.0,
		"hawk": ["away", "diving", "leaving"][_hawk_state] if hawk_enabled else "off",
		"hawk_next": _hawk_timer if _hawk_state == HawkState.AWAY and hawk_enabled else -1.0,
		"wave_ms": reaction_delay * 1000.0,
	}
	if _sums.size() < 20 or count == 0:
		return out
	var f: PackedFloat32Array = _sums
	var m := Vector4(f[0], f[1], f[2], f[3])
	var heading := Vector4(f[4], f[5], f[6], f[7])
	var cov := Basis(
		Vector3(f[8] - m.x * m.x, f[12] - m.x * m.y, f[13] - m.x * m.z),
		Vector3(f[12] - m.x * m.y, f[9] - m.y * m.y, f[14] - m.y * m.z),
		Vector3(f[13] - m.x * m.z, f[14] - m.y * m.z, f[10] - m.z * m.z))
	var axes: Array = METRICS._symmetric_eigen(cov)
	var thin: float = sqrt(maxf(float(axes[0][0]), 0.0001))
	out["order"] = heading.length()
	out["shape"] = Vector2(sqrt(maxf(float(axes[1][0]), 0.0)) / thin, sqrt(maxf(float(axes[2][0]), 0.0)) / thin)
	out["thickness"] = thin * 2.0
	out["w_depth"] = sqrt(maxf(f[11] - m.w * m.w, 0.0)) * 2.0
	out["nearest"] = f[16]
	out["neighbours"] = f[17]
	out["rolling"] = int(f[18])
	out["in_slice"] = f[19] / float(count)
	return out


## What the camera hears, for flock_sound_4d.gd: [code]loud[/code], every bird's sound power
## at the camera summed (1 for a bird SOUND_NEAR metres away) - so near birds and a big clump
## both make it louder, as they would; [code]rolling[/code], the share of that coming from
## birds mid-roll; [code]from[/code], the way it comes from, as a unit vector in the flock's
## space, shorter the more it surrounds you; [code]right[/code], the camera's right, the
## same space. Empty until the first sums are in.
func sound() -> Dictionary:
	if _sums.size() < 28 or count == 0:
		return {}
	var loud: float = _sums[20]
	var from := Vector4(_sums[24], _sums[25], _sums[26], _sums[27]) / maxf(loud, 0.0001)
	return {"loud": loud, "rolling": _sums[21] / maxf(loud, 0.0001), "from": from, "right": _viewer_right}


## Where the hawk is, or null while it is away - for runners.
func hawk_position() -> Variant:
	return null if _hawk_state == HawkState.AWAY else _hawk_pos


## Sends the hawk in now rather than when its time comes.
func call_hawk() -> void:
	_hawk_state = HawkState.AWAY
	_hawk_timer = 0.0


## Starts a roll on bird [param i], as if it had seen the hawk - for runners measuring the
## agitation wave without one.
func startle(i: int, way: float = 1.0) -> void:
	_agit[i] = 1.0
	_agit_rest[i] = agitation_time + agitation_rest
	_agit_sign[i] = way
	if _gpu and _gpu_buffers.has("agit_a"):
		var row := PackedFloat32Array([1.0, 0.0, agitation_time + agitation_rest, way]).to_byte_array()
		var key: String = "agit_a" if _parity == 0 else "agit_b"
		RenderingServer.call_on_render_thread(func() -> void: _rd.buffer_update(_gpu_buffers[key], i * 16, 16, row))


## How far through its roll each bird is, 0 calm.
func agitation() -> PackedFloat32Array:
	if not _gpu:
		return _agit
	var out := PackedFloat32Array()
	for v in _gpu_read_vec4("agit_a" if _parity == 0 else "agit_b"):
		out.append(v.x)
	return out


## For runners and the metrics. On the GPU these read the buffers back, which waits for the
## GPU to finish - fine for a test, not for every frame.
func positions() -> PackedVector4Array:
	return _gpu_read_vec4("pos_a" if _parity == 0 else "pos_b") if _gpu else _pos


func headings() -> PackedVector4Array:
	return _gpu_read_vec4("head_a" if _parity == 0 else "head_b") if _gpu else _head


func centralities() -> PackedFloat32Array:
	if not _gpu:
		return _centrality
	var out := PackedFloat32Array()
	for v in _gpu_read_vec4("misc"):
		out.append(v.w)
	return out


func neighbour_counts() -> PackedInt32Array:
	if not _gpu:
		return _seen
	var out := PackedInt32Array()
	for v in _gpu_read_vec4("misc2"):
		out.append(int(v.w))
	return out


## Puts bird [param i] exactly here, wings level, and redraws - for calibration frames,
## with [member manual] set so nothing moves it.
func place(i: int, at: Vector4, heading: Vector4) -> void:
	var h: Vector4 = heading.normalized()
	_pos[i] = at
	_head[i] = h
	var right := Vector4(h.z, 0.0, -h.x, 0.0).normalized()
	var row: Array = [at, h, right]
	var o: int = i * FLOATS
	for r in 3:
		var v: Vector4 = row[r]
		_buffer[o + r * 4] = v.x
		_buffer[o + r * 4 + 1] = v.y
		_buffer[o + r * 4 + 2] = v.z
		_buffer[o + r * 4 + 3] = v.w
	for k in 4:
		_buffer[o + 12 + k] = 1.0
	_buffer[o + 16] = 0.0
	_buffer[o + 17] = 0.0
	_buffer[o + 18] = bird_scale
	_buffer[o + 19] = 0.0
	_upload()


## Sends bird [param i] off along [param heading] for [param seconds], whatever its
## neighbours are doing - a bird that has seen a hawk.
func lead(i: int, heading: Vector4, seconds: float) -> void:
	_lead[i] = heading.normalized()
	_lead_left[i] = seconds
	if _gpu and _gpu_buffers.has("lead"):
		var h: Vector4 = _lead[i]
		var lead_row := PackedFloat32Array([h.x, h.y, h.z, h.w]).to_byte_array()
		var misc_row := PackedFloat32Array([seconds, _phase[i], _tint[i], 0.0]).to_byte_array()
		RenderingServer.call_on_render_thread(func() -> void:
			_rd.buffer_update(_gpu_buffers["lead"], i * 16, 16, lead_row)
			_rd.buffer_update(_gpu_buffers["misc2"], i * 16, 16, misc_row))


## Turns bird [param i] by [param angle] radians about the vertical, as if it had seen
## something - the push the wave-speed test starts a turn with.
func nudge(i: int, angle: float) -> void:
	var h: Vector4 = _head[i]
	var c: float = cos(angle)
	var s: float = sin(angle)
	_head[i] = Vector4(h.x * c - h.z * s, h.y, h.x * s + h.z * c, h.w).normalized()
	_turn[i] = Vector4.ZERO


# --- The GPU backend -------------------------------------------------------------------

## Vector4 is four doubles in this double-precision build, so packed arrays of them cannot
## go to the GPU as they are: every buffer is written out as 32-bit floats here.
static func _floats(values: PackedVector4Array) -> PackedByteArray:
	var out := PackedFloat32Array()
	out.resize(values.size() * 4)
	for i in values.size():
		var v: Vector4 = values[i]
		out[i * 4] = v.x
		out[i * 4 + 1] = v.y
		out[i * 4 + 2] = v.z
		out[i * 4 + 3] = v.w
	return out.to_byte_array()


func _gpu_init() -> void:
	var n: int = count
	if n == 0:
		return
	var spirv: RDShaderSPIRV = _compute_spirv()
	if spirv == null:
		_gpu = false
		return
	_gpu_shader = _rd.shader_create_from_spirv(spirv, "Flock step")
	_gpu_pipeline = _rd.compute_pipeline_create(_gpu_shader)
	var misc := PackedVector4Array()
	var misc2 := PackedVector4Array()
	misc.resize(n)
	misc2.resize(n)
	for i in n:
		misc[i] = Vector4(_speed[i], 0.0, _radius[i], 0.0)
		misc2[i] = Vector4(0.0, _phase[i], _tint[i], 0.0)
	var empty := PackedVector4Array()
	empty.resize(n)
	var uints := PackedInt32Array()
	uints.resize(n)
	var buckets := PackedInt32Array()
	buckets.resize(BUCKETS)
	var flock_state := PackedVector4Array([_middle, _mean_heading, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])
	_gpu_buffers = {
		"params": _rd.storage_buffer_create(16 * PARAM_ROWS, _gpu_params()),
		"pos_a": _rd.storage_buffer_create(n * 16, _floats(_pos)),
		"head_a": _rd.storage_buffer_create(n * 16, _floats(_head)),
		"pos_b": _rd.storage_buffer_create(n * 16, _floats(_pos)),
		"head_b": _rd.storage_buffer_create(n * 16, _floats(_head)),
		"turn": _rd.storage_buffer_create(n * 16, _floats(empty)),
		"misc": _rd.storage_buffer_create(n * 16, _floats(misc)),
		"wander": _rd.storage_buffer_create(n * 16, _floats(empty)),
		"lead": _rd.storage_buffer_create(n * 16, _floats(empty)),
		"misc2": _rd.storage_buffer_create(n * 16, _floats(misc2)),
		"cell_of": _rd.storage_buffer_create(n * 4, uints.to_byte_array()),
		"counts": _rd.storage_buffer_create(BUCKETS * 4, buckets.to_byte_array()),
		"starts": _rd.storage_buffer_create(BUCKETS * 4, buckets.to_byte_array()),
		"cursor": _rd.storage_buffer_create(BUCKETS * 4, buckets.to_byte_array()),
		"sorted": _rd.storage_buffer_create(n * 4, uints.to_byte_array()),
		"flock": _rd.storage_buffer_create(16 * 8, _floats(flock_state)),
		"stats": _rd.storage_buffer_create(n * 16, _floats(empty)),
		"agit_a": _rd.storage_buffer_create(n * 16, _floats(empty)),
		"agit_b": _rd.storage_buffer_create(n * 16, _floats(empty)),
	}
	var draw: RID = RenderingServer.multimesh_get_buffer_rd_rid(_multimesh)
	var order_a: Array = ["params", "pos_a", "head_a", "pos_b", "head_b", "turn", "misc", "wander", "lead", "misc2",
		"cell_of", "counts", "starts", "cursor", "sorted", "flock"]
	var order_b: Array = order_a.duplicate()
	order_b[1] = "pos_b"
	order_b[2] = "head_b"
	order_b[3] = "pos_a"
	order_b[4] = "head_a"
	_gpu_sets.clear()
	for order in [order_a, order_b]:
		var uniforms: Array[RDUniform] = []
		for k in order.size():
			uniforms.append(_storage_uniform(k, _gpu_buffers[order[k]]))
		uniforms.append(_storage_uniform(16, draw))
		# Agitation is read from neighbours, so it is double-buffered like positions.
		var reading_a: bool = order[1] == "pos_a"
		uniforms.append(_storage_uniform(17, _gpu_buffers["agit_a" if reading_a else "agit_b"]))
		uniforms.append(_storage_uniform(18, _gpu_buffers["agit_b" if reading_a else "agit_a"]))
		uniforms.append(_storage_uniform(19, _gpu_buffers["stats"]))
		_gpu_sets.append(_rd.uniform_set_create(uniforms, _gpu_shader, 0))
	_parity = 0


static func _storage_uniform(binding: int, rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(rid)
	return u


## Compiled here from the text whenever the text can be read, and the editor's import only
## when it cannot (an exported build). Not the other way round: the import is refreshed only
## when the editor next scans, so a game or runner launched from the command line loaded a
## stale shader - the stats panel read zeros for every sum the new one added (1 Oct).
func _compute_spirv() -> RDShaderSPIRV:
	var spirv: RDShaderSPIRV = null
	var text: String = FileAccess.get_file_as_string(COMPUTE)
	if text != "":
		var source := RDShaderSource.new()
		source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		source.source_compute = text.replace("#[compute]", "")
		spirv = _rd.shader_compile_spirv_from_source(source)
	elif ResourceLoader.exists(COMPUTE):
		var file: RDShaderFile = load(COMPUTE) as RDShaderFile
		if file != null:
			spirv = file.get_spirv()
	if spirv == null or spirv.compile_error_compute != "":
		push_error("Flock: the compute shader did not compile: %s" % (spirv.compile_error_compute if spirv != null else "no SPIR-V"))
		return null
	return spirv


## Every setting the shader reads, as ten vec4s in the order flock_step.glsl unpacks them.
func _gpu_params() -> PackedByteArray:
	var band: float = (height_high - height_low) * 0.5
	var altitude: float = height_low + band + sin(_time * TAU / altitude_period) * band * 0.45
	var lead_gain: float = rule_alignment * 3.0 + 4.0
	return PackedFloat32Array([
		roost.x, roost.y, roost.z, roost.w,
		cruise_speed, min_speed, max_speed, neighbours,
		radius_max, separation_radius, blind_cos, radius_max,
		rule_separation, rule_alignment, rule_cohesion, rule_noise,
		rule_gather, _gather_from(), turn_inertia, max_turn_rate,
		speed_spring, bank_rate, roost_radius, roost_pull,
		roost_as_one, height_low, height_high, height_pull,
		altitude_pull, altitude, w_half_depth, w_pull,
		level_flight, w_level, bird_scale, lead_gain,
		_hawk_pos.x, _hawk_pos.y, _hawk_pos.z, _hawk_pos.w,
		1.0 if _hawk_state != HawkState.AWAY else 0.0, scare_radius, flee, reaction_delay,
		agitation_time, agitation_roll, agitation_rest, jink,
		_viewer.x, _viewer.y, _viewer.z, _viewer.w,
		_viewer_ana.x, _viewer_ana.y, _viewer_ana.z, _viewer_ana.w,
		bird_w_radius * bird_scale, SOUND_NEAR, 0.0, 0.0,
	]).to_byte_array()


## One tick on the GPU: settings up, then COUNT, SCAN, SCATTER, UPDATE, REDUCE in one
## compute list, recorded on the render thread.
func gpu_step(dt: float) -> void:
	if _gpu_sets.size() != 2:
		return
	var started: int = Time.get_ticks_usec()
	_hawk_step(dt)
	_ask_for_middle()
	if profile_gpu:
		# The timestamps read back are a frame or two old, which is fine for a mean.
		var begin: int = -1
		for k in _rd.get_captured_timestamps_count():
			var stamp: String = _rd.get_captured_timestamp_name(k)
			if stamp == "Flock begin":
				begin = _rd.get_captured_timestamp_gpu_time(k)
			elif stamp == "Flock end" and begin >= 0:
				# The GPU times come back in nanoseconds, whatever the name says.
				gpu_usec = float(_rd.get_captured_timestamp_gpu_time(k) - begin) / 1000.0
	var params: PackedByteArray = _gpu_params()
	_draw_hawk()
	RenderingServer.call_on_render_thread(_gpu_dispatch.bind(params, dt, _time, _frame, _parity))
	_parity = 1 - _parity
	_frame += 1
	_time += dt
	last_step_usec = float(Time.get_ticks_usec() - started)
	mean_step_usec = last_step_usec if _frame <= 1 else lerpf(mean_step_usec, last_step_usec, 0.05)


func _gpu_dispatch(params: PackedByteArray, dt: float, now: float, frame: int, parity: int) -> void:
	if _gpu_sets.size() != 2:
		return
	var n: int = count
	var groups: int = (n + GROUP - 1) / GROUP
	_rd.buffer_update(_gpu_buffers["params"], 0, params.size(), params)
	_rd.buffer_clear(_gpu_buffers["counts"], 0, BUCKETS * 4)
	var here: RID = _gpu_sets[parity]
	var there: RID = _gpu_sets[1 - parity]
	if profile_gpu:
		_rd.capture_timestamp("Flock begin")
	var list: int = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _gpu_pipeline)
	var passes: Array = [[0, here, groups], [1, here, 1], [2, here, groups], [3, here, groups], [4, there, 1]]
	for k in passes.size():
		var step_pass: Array = passes[k]
		_rd.compute_list_bind_uniform_set(list, step_pass[1], 0)
		var push := PackedByteArray()
		push.resize(32)
		push.encode_u32(0, step_pass[0])
		push.encode_u32(4, n)
		push.encode_u32(8, BUCKETS - 1)
		push.encode_u32(12, frame)
		push.encode_float(16, dt)
		push.encode_float(20, now)
		_rd.compute_list_set_push_constant(list, push, push.size())
		_rd.compute_list_dispatch(list, step_pass[2], 1, 1)
		if k < passes.size() - 1:
			_rd.compute_list_add_barrier(list)
	_rd.compute_list_end()
	if profile_gpu:
		_rd.capture_timestamp("Flock end")


## The flock's middle and mean heading come back from the GPU a frame or so late, without
## waiting for it - the hawk needs somewhere to aim, and the roost pull is worked out on
## the GPU already.
func _ask_for_middle() -> void:
	if _middle_pending or not _gpu_buffers.has("flock"):
		return
	_middle_pending = true
	RenderingServer.call_on_render_thread(func() -> void:
		_rd.buffer_get_data_async(_gpu_buffers["flock"], _got_middle, 0, 112))


func _got_middle(data: PackedByteArray) -> void:
	_middle_pending = false
	var f: PackedFloat32Array = data.to_float32_array()
	if f.size() >= 8:
		_middle = Vector4(f[0], f[1], f[2], f[3])
		_mean_heading = Vector4(f[4], f[5], f[6], f[7])
	if f.size() >= 20:
		_sums = f


func _gpu_read_vec4(key: String) -> PackedVector4Array:
	var out := PackedVector4Array()
	if not _gpu_buffers.has(key):
		return out
	var raw: PackedFloat32Array = _rd.buffer_get_data(_gpu_buffers[key]).to_float32_array()
	out.resize(raw.size() / 4)
	for i in out.size():
		out[i] = Vector4(raw[i * 4], raw[i * 4 + 1], raw[i * 4 + 2], raw[i * 4 + 3])
	return out


func _gpu_free() -> void:
	if _rd == null:
		return
	for s in _gpu_sets:
		if s.is_valid():
			_rd.free_rid(s)
	_gpu_sets.clear()
	for key in _gpu_buffers:
		var rid: RID = _gpu_buffers[key]
		if rid.is_valid():
			_rd.free_rid(rid)
	_gpu_buffers.clear()
	if _gpu_pipeline.is_valid():
		_rd.free_rid(_gpu_pipeline)
	if _gpu_shader.is_valid():
		_rd.free_rid(_gpu_shader)
	_gpu_pipeline = RID()
	_gpu_shader = RID()
