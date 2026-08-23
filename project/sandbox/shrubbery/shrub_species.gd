class_name ShrubSpecies4D
extends Resource
## Config for one shrub "species" - a native Resource (`.tres`) rather than
## porting shrubbery's own RON asset format, per the port plan's own
## reasoning (avoids a new parser dependency for no real benefit here).
## v1 scope only: a single trunk + space-colonization branching + one
## sphere/glome leaf shape at every tip. ConiferWhorl/StarLeaf and
## Gradient/RandomSolid decoration are deliberately deferred (see the
## port plan's "ConiferWhorl / StarLeaf stay 3D-shaped, deferred" note).

@export_group("Trunk")
@export var seed: int = 0
@export var trunk_direction: Vector4 = Vector4(0, 1, 0, 0)
## Bumped up from an initial 0.3 guess for a visibly thicker trunk - see
## _rasterize_segment's own comment: thickness now actually widens the
## rasterized geometry (an earlier version tracked a per-branch thickness
## value but never used it for anything, so every branch rendered at the
## same single-voxel-wide centerline regardless of this value).
@export var trunk_thickness: float = 0.5
@export var segment_length: float = 0.5
@export var iterations: int = 40
@export var branch_thickness_falloff: float = 0.97

@export_group("Space colonization (attractors)")
## Sampling volume is a tesseract (4D generalization of shrubbery's own
## AttractorShape::Cube) centered at attractor_center_offset - the
## highest-payoff 4D generalization per the port plan, since attractors
## (not the primitive growth rules) drive most of a shrub's emergent
## branching detail.
@export var attractor_count: int = 200
@export var attractor_center_offset: Vector4 = Vector4(0, 3, 0, 0)
## Revised from an initial (3,4,3,3) guess: that box spanned Y from -1 to
## +7, meaning the trunk (starting at Y=0) was already INSIDE the bottom
## of the attractor cloud from its very first growth step - attractors
## below and to the sides pulled it sideways/down before it ever got a
## chance to establish a clean vertical trunk, and once inside the cloud
## there's no directional preference at all (attractors surround the tip
## on every side). Narrowed to (2,1.5,2,1.5): the cloud's lower face now
## sits at attractor_center_offset.y - 1.5 = 1.5, well above the trunk's
## start, so growth has to climb ~1.5 units on its own (with nothing but
## gravity_lean_strength and its own straight-up trunk_direction acting
## on it) before any attractor comes into range - confirmed via direct
## measurement this was the actual cause of a shrub that rendered
## hugging the ground/spread sideways rather than reaching upward, not a
## rendering bug (the per-voxel box rendering fix was separate and real,
## but this shape problem persisted after that fix and needed its own
## diagnosis).
@export var attractor_half_extents: Vector4 = Vector4(2.0, 1.5, 2.0, 1.5)
## Revised down from an initial 2.0 guess: at that reach, a hypersphere
## of radius 2.0 (hypervolume ~79 units^4) covers more than half the
## ENTIRE attractor cloud's own volume (~144 units^4 at the half-extents
## above) - meaning from almost anywhere inside the cloud, most of the
## remaining attractors are already in range at once, so growth direction
## was dominated by whichever attractors happened to still be unreached
## (a depletion-order effect) rather than genuine local structure. That
## measured as the actual cause of a "logarithmic spiral curling inward"
## shape, not a rendering bug: a single greedy tip chasing a shifting,
## nearly-global average direction has no reason to commit to spreading
## outward. 1.0 keeps each step's influence genuinely LOCAL.
@export var attract_distance: float = 1.0
@export var kill_distance: float = 0.4

@export_group("Branching")
## A tip only considers forking into two branches when at least this
## many unreached attractors are currently in range - guards against
## forking on noise from just 1-2 stray attractors, which would read as
## random twigginess rather than real structural branch points.
@export var min_attractors_to_fork: int = 3
## Minimum angular separation (degrees) between a tip's two most
## divergent in-range attractor directions before it's treated as a real
## fork rather than one spread-out-but-still-single direction. Lower
## values fork more eagerly (bushier, more twigs); higher values fork
## more rarely (sparser, more dominant leaders).
@export var fork_angle_threshold_deg: float = 50.0
## Per-step chance a geometrically-eligible tip actually forks, rolled
## independently of (in addition to) min_attractors_to_fork/
## fork_angle_threshold_deg - tames the RATE of forking directly. Without
## this, forking on every eligible step measured near-exponential branch
## growth (5502 branches against a 500 cap - see shrub_generator.gd's own
## _grow_step comment), since the geometric condition alone is often
## satisfied for many consecutive steps once a tip is inside a dense-
## enough attractor cloud.
@export_range(0.0, 1.0) var fork_probability: float = 0.35
## Hard safety ceiling on total branch count, checked EVERY step (not
## just against new forks) - forking is potentially exponential even
## with fork_probability < 1 (see shrub_generator.gd's own _grow_step
## comment). Once reached, ALL growth freezes for the rest of grow()
## rather than the whole call failing - a safety ceiling, not a
## recommended target to actually reach in normal use.
@export var max_branches: int = 200

@export_group("Growth bias")
## Gravity is real, physical, and stays on the engine's actual -Y axis -
## never generalized to an arbitrary "lean axis." w_lean_strength is a
## deliberately SEPARATE knob for growth bias toward +/-W, independent of
## gravity - see the port plan's "GravityLean vs. w-lean" section for why
## these are not the same parameter. Revised down from an initial 0.15
## guess: applied unconditionally every growth iteration with no
## restoring force, 0.15 compounded over many iterations into a strong
## net downward drift once attractor pull stopped reliably pointing up
## (which it doesn't, once the tip is inside a cloud surrounding it on
## every side) - a real contributor to the ground-hugging shape above,
## alongside the attractor-cloud placement fix. Kept nonzero (not 0.0)
## since a subtle droop is part of what should read as organic, but
## small enough not to fight a healthy trunk on its own.
@export var gravity_lean_strength: float = 0.05
@export var w_lean_strength: float = 0.0

@export_group("Leaves")
## Revised down from an initial 0.6 guess after Phase 1's own measured
## branch extents (~1.2-2.6 units across) showed a 1.2-diameter leaf
## cluster was wildly oversized relative to the actual tree - both a
## visual proportion problem and (via shrub_mesh_builder.gd's meshed-
## volume cost) a real performance one.
@export var leaf_radius: float = 0.2
## How many of the most-recent growth generations get a leaf cluster,
## not just literal branch-chain endpoints - per explicit request for
## "leaf coverage on most of the outer edges of branches" rather than one
## lump only at each terminal tip. 0 reverts to endpoints-only.
@export var leafy_generation_depth: int = 4

@export_group("Voxelization")
## ~10cm/side, per direct user instruction - this project reads as 1 unit
## = 1 meter elsewhere (e.g. limb_prototype's own BASE_ANCHOR_FORWARD/
## BASE_TOTAL_REACH constants sit in the same 1-10 unit range as a
## creature's actual body size), so 0.1 is the literal 10cm.
@export var voxel_size: float = 0.1

@export_group("Mesh smoothing (see shrub_mesh_builder.gd)")
## Metaball-style falloff radius around each occupied voxel, as a
## multiple of voxel_size - the actual mechanism that turns blocky voxel
## occupancy into a continuously-varying implicit surface (see the port
## plan's "Mesh-building backend (revised)" section for why this is
## required, not optional polish). A lone voxel's own rendered radius
## works out to roughly smoothing_radius_in_voxels * voxel_size *
## (1 - density_iso_threshold) - see density_iso_threshold's own comment.
@export var smoothing_radius_in_voxels: float = 2.5
## Best-guess default: a standard metaball/blobby-surface iso-value. With
## this and the smoothing_radius_in_voxels default above, a single
## isolated voxel's blob alone renders as roughly a half-smoothing-radius
## rounded lump - already big enough for a thin branch to read as
## cylindrical rather than as a chain of separate balls, without being so
## large that nearby-but-unconnected branches visually fuse together.
@export var density_iso_threshold: float = 0.5
## MT's own evaluation grid must sample FINER than the raw voxel grid for
## the smoothing to resolve into visible curvature rather than aliasing
## back toward the blocky look (see the port plan) - this is the
## supersampling factor applied to voxel_size to get MT's world_step.
## Revised down from an initial 3.0 guess: total density-sample count
## scales as this factor to the 4th power (one 4D grid axis each), so
## 3.0 measured as computationally infeasible (>10 minutes for one small
## shrub, killed before completion) - 2.0 cuts sample count by roughly
## 5x for a real, measured, still-tractable trade against smoothness.
@export var mt_supersample_factor: float = 2.0
