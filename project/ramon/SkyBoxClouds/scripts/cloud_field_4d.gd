@tool
extends MeshInstance4D

# No `class_name` here either - see the note at the top of skydome_4d.gd.

## 4D cumulus built from clumped, stretched, hierarchically-detailed polytopes.
##
## [b]Three levels, because that is what makes a cloud[/b]
##
## 1. A [b]coverage field[/b] decides where cloud exists and how thick.
##    [FastNoiseLite] over [code](x, z, w)[/code] - the horizontal 3-space of
##    the deck, y being altitude. Coverage varies across the ground AND across
##    w, so slice-rotating moves you into different weather.
## 2. Each accepted site grows a [b]clump[/b] of a few LARGE primary puffs.
##    Few and big, not many and small: the reference implementations surveyed
##    for this used about six primitives per cumulus, because silhouette comes
##    from mass placement, not primitive count.
## 3. Every primary puff sprouts [b]detail puffs on its own surface[/b]. This is
##    the cauliflower edge, and it is the difference between "a blob" and "a
##    cloud". Hierarchical particle attachment is the standard trick for it.
##
## [b]Ellipsoids, not spheres[/b]
##
## Puffs are scaled non-uniformly - squashed vertically, stretched horizontally
## along a random axis. A sphere reads as a ball no matter how you arrange it;
## the literature on real-time cumulus is explicit that swapping spheres for
## ellipsoids is what makes formations read as cloud.
##
## Rotations are deliberately restricted to the zx, xw and zw planes - the
## three planes of the horizontal 3-space. All of them leave the y axis alone,
## which is what lets the vertical squash stay actually vertical: the basis is
## built rotation-first then scaled per column, so a rotation that tilted y
## would smear the flattening into a random direction.
##
## [b]Stretching through w[/b]
##
## The deck is a 3-volume in (x, z, w) but you only ever see one w-slice of it,
## so most generated cloud is invisible at any moment. Measured on the first
## version: 5% of tetrahedra crossed the viewing slice. The sky looked empty no
## matter how much was generated.
##
## Two things fix it, and only one of them is obvious:
##
## - Keep [member w_extent] TIGHT relative to [member field_extent]. Spreading
##   the deck through w just moves cloud out of view.
## - Stretch each PUFF along w ([member w_stretch]), not the clump envelope.
##   Stretching the envelope was the first attempt and measured strictly worse -
##   it scatters puffs away from your slice. Stretching the puff itself makes
##   one puff span many slices, so it stays on screen as you rotate.
##
## Together those took the yield from 5.1% to 24.6% of tetrahedra crossing the
## slice - roughly 5x the visible cloud for the same budget.
##
## Everything merges into ONE mesh via [method ArrayTetraMesh4D.merge_with].
## Clouds are OPAQUE - overlapping transparent hulls is the coincident-surface
## case suspected behind the voxel port's visible holes.

enum CoverageNoise {
	## Worley/Voronoi. Cell structure reads as patchy weather.
	CELLULAR,
	## Smooth fractal blobs - broader, softer coverage.
	SIMPLEX,
	PERLIN,
}

## Available puff primitives, cheapest first. Tetrahedron counts are measured,
## not nominal - see ramon/voxel_port/polytope_budget.gd.
enum PuffShape {
	## 5 tets. A 4-simplex. Extremely angular; only useful as tiny detail.
	CELL_5,
	## 16 tets. The built-in orthoplex. Cheap, angular alone, fine in bulk.
	ORTHOPLEX_16,
	## 40 tets. The built-in tesseract.
	TESSERACT,
	## 96 tets. Rounded enough to read as cloud - the sensible default.
	CELL_24,
	## 600 tets. Roundest affordable shape, 6x the 24-cell.
	CELL_600,
}

const _SHAPE_PATHS := {
	PuffShape.CELL_5: "res://models/primitives/platonic/5_cell/5_cell.g4b",
	PuffShape.CELL_24: "res://models/primitives/platonic/24_cell/24_cell.g4b",
	PuffShape.CELL_600: "res://models/primitives/platonic/600_cell/600_cell.g4b",
}

## Terrain at the documented baseline, printed as a yardstick. Cost scales with
## TOTAL 4D mesh size rather than visible geometry, because the renderer calls
## instance_set_ignore_culling(true).
const TERRAIN_TETRAHEDRA := 28140

## Where saved skies live. Created on first save.
const PRESET_DIRECTORY := "res://ramon/SkyBoxClouds/presets"

@export_tool_button("Generate") var _generate_action: Callable = generate
@export_tool_button("Randomize Seed and Generate") var _randomize_action: Callable = randomize_and_generate
@export_tool_button("Clear") var _clear_action: Callable = clear

@export_group("Presets")
## Each writes a complete, measured set of values and regenerates, so there is
## always a known-good starting point to return to after experimenting. They
## set every parameter they depend on rather than only the interesting ones -
## a preset that inherits half its state from whatever you last tried is not a
## preset.
@export_tool_button("Preset: Scattered") var _preset_scattered: Callable = apply_scattered
@export_tool_button("Preset: Fair weather") var _preset_fair: Callable = apply_fair_weather
@export_tool_button("Preset: Fair weather 2") var _preset_fair2: Callable = apply_fair_weather_2
@export_tool_button("Preset: Overcast") var _preset_overcast: Callable = apply_overcast

@export_subgroup("Your presets")
## File name for save/load, without extension. Change it to keep several skies
## side by side.
@export var preset_name: String = "my_sky"

@export_tool_button("Save Current As Preset") var _save_preset: Callable = save_preset
@export_tool_button("Load Saved Preset") var _load_preset: Callable = load_preset

@export_group("Layer")
## Half-width of the deck in x and z. Wants to be several times
## [member base_altitude] or the deck visibly ends before the horizon.
@export_range(100.0, 6000.0, 10.0, "or_greater", "suffix:m") var field_extent: float = 900.0

## Half-width in w, kept separate from x/z. The deck is a 3-VOLUME in
## (x, z, w), so its cost grows with the cube of extent - and w is the axis you
## cannot see all of at once. Keeping it tighter than field_extent spends the
## budget where it shows.
@export_range(50.0, 4000.0, 10.0, "or_greater", "suffix:m") var w_extent: float = 130.0

## Altitude of the flat cloud base - the condensation level.
@export_range(0.0, 2000.0, 1.0, "or_greater", "suffix:m") var base_altitude: float = 110.0

## How far the tallest clumps rise above the base.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:m") var layer_thickness: float = 90.0

@export_group("Coverage")
@export var coverage_noise: CoverageNoise = CoverageNoise.SIMPLEX

## Lower = larger weather systems. The strongest knob for "a few big masses"
## versus "small puffs everywhere".
@export_range(0.0002, 0.02, 0.0002) var coverage_frequency: float = 0.0022

## Fraction of sky left CLEAR, as a percentile of the coverage field rather
## than an absolute noise value - raw ranges differ wildly between noise types,
## so ranking makes this mean the same thing everywhere.
@export_range(0.0, 0.95, 0.01) var coverage_threshold: float = 0.30

## Power curve on coverage above the cutoff. Above 1 keeps the biggest masses
## rare, which is the natural size distribution.
@export_range(0.25, 4.0, 0.05) var coverage_contrast: float = 1.5

@export_group("Clumps")
## Candidate sites tested against coverage. Scale this with extent - the deck
## is a volume, so doubling field_extent needs roughly 8x the attempts to hold
## the same density.
@export_range(50, 4000, 10) var clump_attempts: int = 900

## Horizontal radius of a clump at minimum and maximum coverage.
@export_range(5.0, 600.0, 1.0, "or_greater", "suffix:m") var clump_radius_min: float = 70.0
@export_range(5.0, 600.0, 1.0, "or_greater", "suffix:m") var clump_radius_max: float = 240.0

## Vertical squash of the clump envelope. Cumulus are far wider than tall.
@export_range(0.05, 1.0, 0.01) var clump_vertical_ratio: float = 0.3

## How much a clump's SIZE is decided independently of how much cloud cover is
## there.
##
## At 0, size follows coverage directly - big clumps only occur in dense
## regions, which is tidy and wrong. Photographs of fair weather cumulus show
## the opposite: a lone large cloud sitting in open blue while a crowded band
## nearby holds only small ones. Size and cover are separate variables in the
## real thing.
##
## At 1, size comes entirely from an independent squared random draw - a power
## law giving many small clumps and a few large ones, which is the size
## distribution such skies actually have. Values in between blend the two.
@export_range(0.0, 1.0, 0.05) var size_variance: float = 0.0

## Elongation along w. Above 1 makes each clump span more slices, which is what
## fills the sky without generating more clouds - see the class notes.
@export_range(0.5, 6.0, 0.1) var w_stretch: float = 4.5

@export_group("Primary puffs")
## Few and large. Silhouette comes from where mass sits, not how many pieces.
@export_range(1, 40, 1) var primary_puffs_min: int = 3
@export_range(1, 60, 1) var primary_puffs_max: int = 9

@export_range(5.0, 300.0, 1.0, "or_greater", "suffix:m") var primary_size_min: float = 34.0
@export_range(5.0, 300.0, 1.0, "or_greater", "suffix:m") var primary_size_max: float = 92.0

## Random horizontal elongation per puff - 1.0 gives spheres. This is the
## single change that stops a puff reading as a ball.
@export_range(1.0, 4.0, 0.05) var horizontal_stretch: float = 1.8

## Puff height relative to its horizontal size.
@export_range(0.15, 1.0, 0.05) var puff_vertical_ratio: float = 0.55

## Puff size at the top of a clump relative to the base - the cumulus profile,
## wide flat bottom under a smaller crown.
@export_range(0.1, 1.5, 0.05) var top_taper: float = 0.5

@export_group("Detail puffs")
## Smaller puffs scattered on each primary puff's SURFACE. This is the
## cauliflower edge. Zero disables the second level entirely.
@export_range(0, 24, 1) var detail_puffs_per_primary: int = 5

## Detail puff size relative to its parent.
@export_range(0.1, 0.8, 0.02) var detail_size_ratio: float = 0.4

## How far out detail puffs sit, as a fraction of the parent radius. Near 1
## they ride the rim and break the silhouette, which is the point; lower values
## bury them and do nothing visible.
@export_range(0.3, 1.3, 0.05) var detail_surface_bias: float = 0.95

@export_group("Shape and smoothing")
## Primitive used for the big masses. The 600-cell is the roundest option and
## costs 6x the 24-cell, so try it with a lower clump count.
@export var primary_shape: PuffShape = PuffShape.CELL_24

## Primitive used for the surface detail. These are small and numerous, so a
## cheap shape is usually right - there are typically 5x as many of them as
## primaries, and at that size roundness barely registers.
@export var detail_shape: PuffShape = PuffShape.ORTHOPLEX_16

## Optional geometric smoothing: each tetrahedron is split into 8 and the new
## vertices pushed back out onto the sphere, so the silhouette rounds off.
##
## [b]Costs 8x the tetrahedra per level[/b], applied to every puff of that kind.
## A 16-cell at one level (128 tets) is rounder than a raw 24-cell (96) for
## about the same price, which makes it the interesting setting. Two levels is
## almost always the wrong trade - reach for a bigger polytope instead.
##
## This does NOT smooth the shading. The cross-section shader computes flat
## per-triangle normals in its vertex stage and discards the mesh's own smooth
## normals, so facet shading is fixed until that is solved in the engine. What
## this changes is how many facets there are, and the outline.
@export_range(0, 2, 1) var smooth_subdivisions: int = 0

@export_group("Animation")
## Drives the sky by slowly ROTATING the whole deck rather than regenerating or
## translating it.
##
## Rotation is the right primitive here for two reasons. It is free - one
## [Projection] assigned per frame, against a mesh that would take seconds to
## rebuild - and it is perfectly periodic, so the sky never drifts out of the
## field and never has to jump back, which a translating deck would.
##
## The w-plane rotation is the interesting half: it sweeps the deck THROUGH the
## viewing slice, so cross-sections change and clouds visibly billow, merge and
## dissolve. Nothing is regenerated - it is the same geometry being cut at a
## moving angle. That is an animation only a 4D renderer can give you for free.
@export var animate: bool = false

@export_tool_button("Toggle Animation") var _animate_action: Callable = toggle_animation

## Yaw about the vertical axis - clouds sweep across the sky. This is the
## "wind", and being angular it keeps a constant apparent rate at any distance.
@export_range(0.0, 10.0, 0.05, "suffix:deg/s") var wind_speed: float = 0.55

## How far the deck slides along w, in metres, as it evolves.
##
## A slide rather than a w-plane ROTATION, which is what this started as and
## measured badly: rotating in zw mixes the deck's huge z extent into w,
## destroying the thinness that makes a slice look full. Visible geometry fell
## 74% over four minutes. Translation changes the cross-section just as much
## while leaving the deck's shape untouched.
##
## Keep this inside the density plateau - the deck measures roughly flat across
## w = -80..+80 and falls away sharply past +/-200, so a larger amplitude makes
## the sky visibly thin out at the extremes of the cycle.
@export_range(0.0, 300.0, 1.0, "suffix:m") var evolve_amplitude: float = 55.0

## Seconds for one full there-and-back slide. Long, because the cross-section
## changes fast - clouds billow and dissolve from surprisingly little movement.
@export_range(5.0, 600.0, 1.0, "suffix:s") var evolve_period: float = 90.0

@export_group("Appearance")
@export var cloud_color: Color = Color(0.95, 0.96, 0.98)
@export var cloud_seed: int = 1

@export_group("Budget")
## Generation stops here, so a bad combination thins the sky rather than
## locking the editor.
@export_range(5000, 400000, 1000) var max_tetrahedra: int = 90000

var _ready_to_generate := false

## Seconds of animation. Kept rather than reading engine time so the motion
## always starts from zero when toggled on.
var _elapsed := 0.0


func _ready() -> void:
	_ready_to_generate = true
	# Explicit because the editor does not always enable processing for a @tool
	# node that gained a _process() during a hot reload, and the animation is
	# meant to preview live in the "4D" tab without entering Play.
	set_process(true)
	if mesh == null:
		generate()


## Keeps the generated mesh and the live animation pose OUT of the saved scene.
##
## Two separate problems, one hook.
##
## The mesh is the serious one. A MeshInstance4D serializes whatever mesh it
## holds, so saving with clouds generated embedded ~90,000 tetrahedra into
## skybox_clouds.tscn - measured at 24 MB, one line of it 17 million characters.
## Worse than the size: on load the mesh is no longer null, so [method _ready]
## skips generate(), and everything generate() does at runtime is skipped with
## it. For the skydome that means its custom shader never gets assigned and the
## dome renders with the stock one - back-face culled, invisible from inside.
## That is why the sky vanished in Play but looked fine in the editor.
##
## The pose is the minor one: previewing the animation writes position/basis
## every frame, which would otherwise bake whatever moment the save caught.
##
## Stripping here and rebuilding in POST_SAVE keeps the file tiny, keeps the
## editor view intact, and guarantees generate() runs on every load - which is
## what makes the runtime-only setup reliable. voxel_port.tscn does the same.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			basis = Projection.IDENTITY
			position = Vector4.ZERO
			mesh = null
		NOTIFICATION_EDITOR_POST_SAVE:
			if mesh == null:
				generate()


func clear() -> void:
	mesh = null


func toggle_animation() -> void:
	animate = not animate
	if not animate:
		# Return to the authored transform rather than freezing wherever the
		# toggle happened to catch it, so stopping is repeatable and the scene
		# saves in a known state.
		_elapsed = 0.0
		basis = Projection.IDENTITY
		position = Vector4.ZERO
	notify_property_list_changed()


## Rotates the whole deck. Runs in the editor too, so the look can be judged
## without entering Play - which matters because the w-plane component is the
## part that is hard to imagine from a still frame.
func _process(delta: float) -> void:
	# Nil-safe reads throughout: a @tool script that gains exports while a
	# scene is open comes back from the hot reload with them unset, and `if not
	# animate` silently treats Nil as false - which looks exactly like the
	# preview being broken. Reload the scene to pick up the real values.
	if animate == null or not animate:
		return
	_elapsed += delta
	# Composed fresh from elapsed time rather than multiplied incrementally.
	# Repeated multiplication of a Projection accumulates float drift and
	# eventually shears the deck - the same reason player.gd re-orthonormalizes
	# the body basis every frame.
	#
	# Yaw is a zx rotation, which mixes only x and z and therefore leaves the
	# deck's w profile completely untouched. That is why the wind can run
	# indefinitely without thinning the sky.
	var yaw_rate: float = float(wind_speed) if wind_speed != null else 0.0
	var amplitude: float = float(evolve_amplitude) if evolve_amplitude != null else 0.0
	var period: float = float(evolve_period) if evolve_period != null else 90.0
	basis = Basis4D.from_zx(deg_to_rad(yaw_rate) * _elapsed)
	# Sinusoidal so it returns to where it started - no drift to correct, and
	# the deck never wanders off the dense part of its own w profile.
	position = Vector4(0.0, 0.0, 0.0, amplitude * sin(TAU * _elapsed / maxf(0.001, period)))


func randomize_and_generate() -> void:
	cloud_seed = randi()
	generate()


## Sparse fair-weather sky: a handful of large, well-separated masses over a lot
## of open blue. Cheapest of the three.
func apply_scattered() -> void:
	_apply_common()
	coverage_frequency = 0.0016
	coverage_threshold = 0.55
	coverage_contrast = 1.7
	clump_attempts = 150
	clump_radius_min = 80.0
	clump_radius_max = 260.0
	primary_puffs_min = 3
	primary_puffs_max = 8
	primary_size_min = 42.0
	primary_size_max = 104.0
	detail_puffs_per_primary = 6
	max_tetrahedra = 55000
	_finish_preset()


## The reference-photo look: many distinct cumulus with clear sky between them.
## This is the default the file ships with.
func apply_fair_weather() -> void:
	_apply_common()
	coverage_frequency = 0.0022
	coverage_threshold = 0.30
	coverage_contrast = 1.5
	clump_attempts = 120
	clump_radius_min = 70.0
	clump_radius_max = 240.0
	primary_puffs_min = 3
	primary_puffs_max = 9
	primary_size_min = 34.0
	primary_size_max = 92.0
	detail_puffs_per_primary = 5
	max_tetrahedra = 95000
	_finish_preset()


## Second take on fair weather, built from a different premise.
##
## The first one derives everything from coverage: dense regions get big
## clumps, sparse regions get small ones. Tidy, but it produces a sky where
## size and crowding always agree, which photographs of real fair-weather
## cumulus do not show.
##
## This one changes three things:
##
## 1. [b]Size is mostly independent of cover[/b] ([member size_variance] 0.8),
##    drawn from a power law. Many small clouds, a few large, scattered without
##    regard to how crowded their neighbourhood is.
## 2. [b]A much wider deck[/b] - 1500 against 900 - so it reaches the horizon
##    and clouds crowd there by perspective alone. That banding is free; trying
##    to author it into the coverage field would only fight the projection.
## 3. [b]Flatter, smaller clouds[/b], more of them. Fair weather cumulus are
##    wide and shallow, and shrinking them is what pays for the extra count -
##    a tetrahedron costs the same at any size, so smaller clouds mean more
##    clouds rather than more tetrahedra.
func apply_fair_weather_2() -> void:
	_apply_common()
	field_extent = 1500.0
	base_altitude = 125.0
	layer_thickness = 70.0
	coverage_frequency = 0.0016
	coverage_threshold = 0.30
	coverage_contrast = 1.1
	clump_attempts = 230
	clump_radius_min = 45.0
	clump_radius_max = 200.0
	clump_vertical_ratio = 0.22
	size_variance = 0.8
	primary_puffs_min = 2
	primary_puffs_max = 7
	primary_size_min = 26.0
	primary_size_max = 74.0
	puff_vertical_ratio = 0.42
	top_taper = 0.42
	detail_puffs_per_primary = 4
	detail_size_ratio = 0.45
	max_tetrahedra = 120000
	_finish_preset()


## Heavy cover: masses merge into a broken ceiling with only gaps of blue.
## Costs roughly twice fair weather - watch the tet count.
func apply_overcast() -> void:
	_apply_common()
	coverage_frequency = 0.0030
	coverage_threshold = 0.05
	coverage_contrast = 1.2
	clump_attempts = 140
	clump_radius_min = 95.0
	clump_radius_max = 280.0
	primary_puffs_min = 4
	primary_puffs_max = 11
	primary_size_min = 44.0
	primary_size_max = 108.0
	detail_puffs_per_primary = 5
	max_tetrahedra = 160000
	_finish_preset()


## Shared between presets: the geometry that governs how much of the deck is
## ever on screen. These were measured rather than chosen - see the class notes
## on slice yield - so presets vary weather, not the things that decide whether
## the sky is visible at all.
func _apply_common() -> void:
	field_extent = 900.0
	w_extent = 130.0
	w_stretch = 4.5
	base_altitude = 110.0
	layer_thickness = 90.0
	coverage_noise = CoverageNoise.SIMPLEX
	clump_vertical_ratio = 0.3
	horizontal_stretch = 1.8
	puff_vertical_ratio = 0.55
	top_taper = 0.5
	detail_size_ratio = 0.4
	detail_surface_bias = 0.95
	primary_shape = PuffShape.CELL_24
	detail_shape = PuffShape.ORTHOPLEX_16
	smooth_subdivisions = 0
	size_variance = 0.0


func _finish_preset() -> void:
	notify_property_list_changed()
	generate()


## Writes every tunable to res://ramon/SkyBoxClouds/presets/<preset_name>.cfg.
##
## In the project rather than user:// deliberately - a sky you liked is worth
## keeping next to the scene that uses it, visible in the FileSystem dock and
## diffable in git, not buried in an OS data folder. The files are a couple of
## KB of plain text.
##
## The property list is read from the script itself rather than spelled out, so
## anything added later is saved without this function needing to know about
## it. Callables (the tool buttons) and underscore-prefixed internals are
## skipped, as is preset_name - loading a preset should not rename the slot you
## loaded it from.
func save_preset() -> void:
	if not Engine.is_editor_hint():
		push_error("CloudField4D: presets are an editor tool - res:// is read-only at runtime.")
		return
	var file_name: String = preset_name.strip_edges().validate_filename()
	if file_name.is_empty():
		push_error("CloudField4D: preset_name is empty.")
		return

	var config := ConfigFile.new()
	for property_name in _tunable_property_names():
		config.set_value("cloud_field", property_name, get(property_name))

	DirAccess.make_dir_recursive_absolute(PRESET_DIRECTORY)
	var path: String = "%s/%s.cfg" % [PRESET_DIRECTORY, file_name]
	var error: int = config.save(path)
	if error != OK:
		push_error("CloudField4D: could not write %s (error %d)" % [path, error])
		return
	print("CloudField4D: saved preset -> %s" % path)
	# Without this the file exists on disk but stays invisible in the
	# FileSystem dock until something else triggers a scan.
	if Engine.has_singleton("EditorInterface"):
		Engine.get_singleton("EditorInterface").get_resource_filesystem().scan()


## Restores a saved preset and regenerates.
func load_preset() -> void:
	var file_name: String = preset_name.strip_edges().validate_filename()
	var path: String = "%s/%s.cfg" % [PRESET_DIRECTORY, file_name]
	var config := ConfigFile.new()
	var error: int = config.load(path)
	if error != OK:
		push_error("CloudField4D: no preset at %s (error %d)" % [path, error])
		return
	for property_name in config.get_section_keys("cloud_field"):
		# Guard against presets written before a property existed, or after one
		# was removed - a stale key would otherwise be a hard error.
		if property_name in _tunable_property_names():
			set(property_name, config.get_value("cloud_field", property_name))
	print("CloudField4D: loaded preset <- %s" % path)
	_finish_preset()


## Every exported tunable, discovered from the script rather than listed by
## hand so it cannot drift out of date.
func _tunable_property_names() -> PackedStringArray:
	var names := PackedStringArray()
	for property in get_property_list():
		if not (property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		# Tool buttons are Callables, and internals are underscore-prefixed.
		if property["type"] == TYPE_CALLABLE:
			continue
		var property_name: String = property["name"]
		if property_name.begins_with("_") or property_name == "preset_name":
			continue
		names.append(property_name)
	return names


func generate() -> void:
	var primary_template: ArrayTetraMesh4D = _build_template(primary_shape)
	var detail_template: ArrayTetraMesh4D = _build_template(detail_shape)
	if primary_template == null or detail_template == null:
		return
	var primary_cost: int = primary_template.get_simplex_cell_vertex_indices().size() / 4
	var detail_cost: int = detail_template.get_simplex_cell_vertex_indices().size() / 4

	var rng := RandomNumberGenerator.new()
	rng.seed = cloud_seed
	var noise: FastNoiseLite = _build_coverage_noise()

	# Pass 1: score candidate sites. Coverage depends on horizontal position
	# only - x, z AND w, the fourth axis deliberately fed to the third noise
	# input so w carries weather rather than extruding one 2D map through it.
	var sites: Array[Vector4] = []
	var scores := PackedFloat32Array()
	for attempt in range(clump_attempts):
		var site := Vector4(
			rng.randf_range(-field_extent, field_extent),
			0.0,
			rng.randf_range(-field_extent, field_extent),
			rng.randf_range(-w_extent, w_extent))
		sites.append(site)
		scores.append(noise.get_noise_3d(site.x, site.z, site.w))

	var sorted := scores.duplicate()
	sorted.sort()
	var cutoff_index: int = clampi(int(float(sorted.size()) * coverage_threshold), 0, sorted.size() - 1)
	var cutoff: float = sorted[cutoff_index]
	var span: float = maxf(0.0001, sorted[sorted.size() - 1] - cutoff)

	var field := ArrayTetraMesh4D.new()
	var tetrahedra := 0
	var clumps := 0
	var primaries := 0
	var details := 0
	var budget_hit := false

	for index in range(sites.size()):
		if tetrahedra >= max_tetrahedra:
			budget_hit = true
			break
		if scores[index] < cutoff:
			continue

		var site: Vector4 = sites[index]
		var density: float = pow(clampf((scores[index] - cutoff) / span, 0.0, 1.0), coverage_contrast)
		site.y = base_altitude + density * layer_thickness * rng.randf_range(0.0, 0.3)

		# Squared draw is a cheap power law: many small clumps, few large. Blended
		# against coverage by size_variance, so size can be decoupled from cover
		# without giving up the tie entirely.
		var size_roll: float = pow(rng.randf(), 2.0)
		var size_factor: float = lerpf(density, size_roll, size_variance)
		var clump_radius: float = lerpf(clump_radius_min, clump_radius_max, size_factor)
		var primary_count: int = int(round(lerpf(float(primary_puffs_min), float(primary_puffs_max), size_factor)))

		for p in range(primary_count):
			if tetrahedra >= max_tetrahedra:
				budget_hit = true
				break

			var offset: Vector4 = _clump_offset(rng, clump_radius)
			# Radial falloff on the HORIZONTAL distance only - y is handled by
			# the taper below, and counting it twice pinches the base instead
			# of widening it.
			var horizontal: float = Vector3(offset.x, offset.z, offset.w / maxf(0.01, w_stretch)).length()
			var distance_fraction: float = clampf(horizontal / maxf(0.001, clump_radius), 0.0, 1.0)
			var size: float = lerpf(primary_size_max, primary_size_min, distance_fraction)
			var height_fraction: float = clampf(
				offset.y / maxf(0.001, clump_radius * clump_vertical_ratio), 0.0, 1.0)
			size *= lerpf(1.0, top_taper, height_fraction)

			var position: Vector4 = site + offset
			# Hold every puff's underside at or above the condensation level so
			# the deck reads as one flat base.
			position.y = maxf(position.y, base_altitude + size * puff_vertical_ratio * 0.5)

			var scale: Vector4 = _puff_scale(rng, size)
			field.merge_with(primary_template, position, _puff_basis(rng, scale))
			tetrahedra += primary_cost
			primaries += 1

			# Level 3: detail puffs riding this puff's own surface.
			for d in range(detail_puffs_per_primary):
				if tetrahedra >= max_tetrahedra:
					budget_hit = true
					break
				var surface_direction: Vector4 = _random_horizontal_direction(rng)
				# Bias upward: undersides of cumulus are smooth, tops are not.
				surface_direction.y = absf(surface_direction.y) * 0.8 - 0.15
				var detail_position := Vector4(
					position.x + surface_direction.x * scale.x * detail_surface_bias,
					position.y + surface_direction.y * scale.y * detail_surface_bias,
					position.z + surface_direction.z * scale.z * detail_surface_bias,
					position.w + surface_direction.w * scale.w * detail_surface_bias)
				var detail_size: float = size * detail_size_ratio * rng.randf_range(0.7, 1.3)
				var detail_scale: Vector4 = _puff_scale(rng, detail_size)
				field.merge_with(detail_template, detail_position, _puff_basis(rng, detail_scale))
				tetrahedra += detail_cost
				details += 1
		clumps += 1

	if primaries == 0:
		push_warning("CloudField4D: no puffs generated - lower coverage_threshold or raise clump_attempts.")
		mesh = null
		return

	var material := TetraMaterial4D.new()
	# Stock colour path on purpose. Clouds are seen from OUTSIDE, so the engine
	# shader's dot(normal, up) term is an asset - it is what stops a clump
	# reading as a flat silhouette.
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	material.albedo_color = cloud_color
	field.material = material
	mesh = field

	print("CloudField4D: %d clumps / %d primary + %d detail puffs / %d tets (%.0f%% of a baseline terrain)%s" % [
		clumps, primaries, details, tetrahedra,
		100.0 * float(tetrahedra) / float(TERRAIN_TETRAHEDRA),
		"  - BUDGET REACHED, sky thinner than configured" if budget_hit else ""])


## Offset of a primary puff within its clump. Hemisphere rather than ball, so
## puffs sit above the base and the underside stays flat. Stretched along w so
## the clump spans many slices.
func _clump_offset(rng: RandomNumberGenerator, clump_radius: float) -> Vector4:
	var direction: Vector4 = _random_horizontal_direction(rng)
	direction.y = absf(direction.y)
	# Cube-root keeps the distribution even by volume rather than piling
	# everything at the centre where it cannot affect the silhouette.
	var radial: float = pow(rng.randf(), 0.33)
	# The w spread of the ENVELOPE is deliberately tighter than x/z, not wider.
	# Measured: widening it scatters puffs away from the viewing slice and
	# lowers how much of the mesh is ever visible - the opposite of the intent.
	# Elongation through w belongs on the individual puff (see _puff_scale),
	# where it makes one puff span many slices instead of moving it out of
	# yours.
	return Vector4(
		direction.x * clump_radius * radial,
		direction.y * clump_radius * clump_vertical_ratio * radial,
		direction.z * clump_radius * radial,
		direction.w * clump_radius * clump_vertical_ratio * radial)


## A unit direction. Gaussian components give an even spread over the sphere,
## which the reference cumulus implementations also use for placement.
func _random_horizontal_direction(rng: RandomNumberGenerator) -> Vector4:
	var direction := Vector4(rng.randfn(), rng.randfn(), rng.randfn(), rng.randfn())
	var length: float = direction.length()
	return Vector4.ZERO if length < 0.0001 else direction / length


## Per-axis half-extents for one puff: squashed vertically, elongated along a
## random horizontal axis, and widened through w.
func _puff_scale(rng: RandomNumberGenerator, size: float) -> Vector4:
	var stretch: float = rng.randf_range(1.0, horizontal_stretch)
	var squeeze: float = 1.0 / sqrt(stretch)
	# Spend the elongation on one horizontal axis and compensate on the others,
	# so stretching changes shape rather than just inflating volume.
	var axis: int = rng.randi_range(0, 2)
	var sx: float = size * (stretch if axis == 0 else squeeze)
	var sz: float = size * (stretch if axis == 1 else squeeze)
	# w gets the full stretch on top of any random elongation. This is what
	# makes a single puff span a range of slices, so it stays visible as you
	# rotate through w instead of vanishing - and it raises the fraction of the
	# mesh that is ever on screen, which is the whole efficiency problem here.
	var sw: float = size * (stretch if axis == 2 else squeeze) * w_stretch
	return Vector4(sx, size * puff_vertical_ratio, sz, sw)


## Rotation limited to the three planes that FIX the y axis (zx, xw, zw), then
## per-column scaling. Column scaling applies in the rotated frame, so a
## rotation touching y would tilt the vertical squash off vertical.
func _puff_basis(rng: RandomNumberGenerator, scale: Vector4) -> Projection:
	var basis: Projection = Basis4D.from_zx(rng.randf_range(0.0, TAU))
	basis = Basis4D.from_xw(rng.randf_range(0.0, TAU)) * basis
	basis = Basis4D.from_zw(rng.randf_range(0.0, TAU)) * basis
	basis.x *= scale.x
	basis.y *= scale.y
	basis.z *= scale.z
	basis.w *= scale.w
	return basis


## Loads or constructs one primitive, subdivides it if asked, and normalizes it
## to unit radius.
##
## The parameter is untyped deliberately. A @tool script that gains exported
## properties while a scene is open comes back from the hot reload with those
## properties still Nil - Godot keeps the node's old property table until the
## scene is reloaded - and a typed parameter turns that into a hard failure of
## the Generate button. Coercing with a sane fallback keeps the tool usable
## mid-iteration; reloading the scene is what restores the real defaults.
func _build_template(shape_value) -> ArrayTetraMesh4D:
	var shape: int = int(shape_value) if shape_value != null else PuffShape.CELL_24
	var levels: int = int(smooth_subdivisions) if smooth_subdivisions != null else 0
	var source: TetraMesh4D
	match shape:
		PuffShape.ORTHOPLEX_16:
			source = OrthoplexTetraMesh4D.new()
		PuffShape.TESSERACT:
			source = BoxTetraMesh4D.new()
		_:
			var path: String = _SHAPE_PATHS[shape]
			source = load(path)
			if source == null:
				push_error("CloudField4D: could not load %s" % path)
				return null

	var mesh: ArrayTetraMesh4D = _normalize_template(source.to_array_tetra_mesh())
	if mesh == null:
		return null
	for level in range(levels):
		mesh = _subdivide_to_sphere(mesh)
		if mesh == null:
			return null
	return mesh


## Splits every tetrahedron into 8 and pushes the new vertices back onto the
## unit sphere, giving a rounder shell.
##
## Standard 1-to-8 split: four corner tetrahedra plus four filling the inner
## octahedron, cut along the ab-cd diagonal. The diagonal choice is safe here
## even though an equivalent choice tore the voxel port's surface, because that
## octahedron is strictly INTERIOR to one tetrahedron - neighbours never see
## it. What they do share are the edge midpoints, and those are deduplicated by
## originating edge so both sides land on the same vertex.
##
## Orientation is re-derived per sub-tetrahedron rather than inherited: the
## octahedral four do not reliably keep the parent's winding, and a backwards
## cell renders as a hole. Since these shells are convex about the origin, a
## cell's outward direction is just its own centroid.
func _subdivide_to_sphere(mesh: ArrayTetraMesh4D) -> ArrayTetraMesh4D:
	var vertices: PackedVector4Array = mesh.get_vertex_positions()
	var indices: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	var result := ArrayTetraMesh4D.new()
	var midpoints := {}

	for t in range(indices.size() / 4):
		var corner := PackedInt32Array()
		corner.resize(4)
		for k in range(4):
			corner[k] = indices[t * 4 + k]

		# Six edge midpoints, keyed by the originating edge so adjacent
		# tetrahedra reuse the same vertex and no crack can open.
		var mid := {}
		for a in range(4):
			for b in range(a + 1, 4):
				var lo: int = mini(corner[a], corner[b])
				var hi: int = maxi(corner[a], corner[b])
				var key: int = lo * 100000 + hi
				if not midpoints.has(key):
					var midpoint: Vector4 = (vertices[lo] + vertices[hi]) * 0.5
					var length: float = midpoint.length()
					if length > 0.0:
						midpoint = midpoint / length
					midpoints[key] = result.append_vertex(midpoint, true)
				mid[a * 4 + b] = midpoints[key]

		var v := PackedInt32Array()
		v.resize(4)
		for k in range(4):
			v[k] = result.append_vertex(vertices[corner[k]], true)

		var ab: int = mid[0 * 4 + 1]
		var ac: int = mid[0 * 4 + 2]
		var ad: int = mid[0 * 4 + 3]
		var bc: int = mid[1 * 4 + 2]
		var bd: int = mid[1 * 4 + 3]
		var cd: int = mid[2 * 4 + 3]

		var sub_cells := [
			[v[0], ab, ac, ad],
			[v[1], ab, bc, bd],
			[v[2], ac, bc, cd],
			[v[3], ad, bd, cd],
			[ab, cd, ac, ad],
			[ab, cd, ad, bd],
			[ab, cd, bd, bc],
			[ab, cd, bc, ac],
		]
		for cell in sub_cells:
			_append_outward(result, cell)

	return _normalize_template(result)


## Appends one tetrahedron, flipping its winding if it faces inward.
func _append_outward(mesh: ArrayTetraMesh4D, cell: Array) -> void:
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var a: Vector4 = positions[cell[0]]
	var b: Vector4 = positions[cell[1]]
	var c: Vector4 = positions[cell[2]]
	var d: Vector4 = positions[cell[3]]
	# Signed 4-volume of the cell against its own outward direction. On a
	# convex shell centred at the origin, "outward" is simply the centroid.
	var centroid: Vector4 = (a + b + c + d) * 0.25
	var determinant: float = Projection(b - a, c - a, d - a, centroid).determinant()
	if determinant < 0.0:
		mesh.append_tetra_cell_indices(cell[1], cell[0], cell[2], cell[3])
	else:
		mesh.append_tetra_cell_indices(cell[0], cell[1], cell[2], cell[3])


## Rescales to unit radius so puff sizes are metres, and drops the UVW map.
##
## The map has to go because ArrayTetraMesh4D::merge_with mis-sizes it: it
## resizes to end_cell_index_count / 4, but the map holds one entry per
## cell-VERTEX (TetraMesh4D asserts texture_map_count == cell_indices_count),
## so the write offset goes negative and every merge spams "Index p_index = -N
## is out of bounds". The block is skipped when both meshes have an empty map,
## which is the only clean way around it from outside the engine.
func _normalize_template(blob: ArrayTetraMesh4D) -> ArrayTetraMesh4D:
	var vertices: PackedVector4Array = blob.get_vertex_positions()
	var longest := 0.0
	for vertex in vertices:
		longest = maxf(longest, vertex.length())
	if longest <= 0.0:
		push_error("CloudField4D: degenerate template")
		return null
	for i in range(vertices.size()):
		vertices[i] = vertices[i] / longest
	blob.set_vertex_positions(vertices)
	blob.texture_map_values = PackedVector3Array()
	blob.simplex_cell_texture_map_indices = PackedInt32Array()
	return blob


func _build_coverage_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = cloud_seed
	noise.frequency = coverage_frequency
	match coverage_noise:
		CoverageNoise.CELLULAR:
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		CoverageNoise.SIMPLEX:
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		CoverageNoise.PERLIN:
			noise.noise_type = FastNoiseLite.TYPE_PERLIN
	return noise
