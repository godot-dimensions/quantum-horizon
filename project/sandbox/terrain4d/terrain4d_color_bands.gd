class_name TerrainColorBands
extends RefCounted
## Discrete height/normal-based terrain coloring - NOT a smooth per-
## fragment gradient. TetraMaterial4D only supports a single flat
## albedo_color per material (confirmed earlier this session: no per-
## fragment/vertex-interpolated shading in this engine's Cross-section
## renderer), so discrete bands assigned at mesh-build time are the actual
## right approach here, not a compromise standing in for something better.
##
## Classification per tet: a steep surface reads as rock regardless of
## height (a cliff face or overhang shouldn't grow grass); a shallow
## surface is grass if high enough, dirt otherwise. First-pass thresholds
## and colors - tune by feel once actually visible.
##
## Single source of truth for both sides of the split this requires:
## VoxelWorld4D._build_brick_mesh() (classification, at mesh-build time,
## per the design here) and TerrainChunkPool4D (the fixed per-band
## TetraMaterial4D colors, reused across every pooled node rather than
## reinstantiated per node - the actual "flat albedo_color pattern" already
## used everywhere else in this codebase, just one material per band
## instead of one per brick).

const ROCK := 0
const GRASS := 1
const DIRT := 2
const BAND_COUNT := 3

const UP := Vector4(0.0, 1.0, 0.0, 0.0)
## normal.dot(UP) below this = steep enough to be rock regardless of
## height - roughly cos(45deg) ~= 0.7, so anything steeper than a 45
## degree slope reads as rock.
const STEEP_DOT_THRESHOLD := 0.7
## World-space Y above which a shallow-enough surface is grass rather
## than dirt - matches terrain4d_voxel_showcase.gd's own ground_level=0.0
## convention (the showcase's only live density field right now).
const HIGH_HEIGHT_THRESHOLD := 0.0

const BAND_COLORS := [
	Color(0.45, 0.45, 0.47, 1.0),  # ROCK - gray
	Color(0.25, 0.55, 0.2, 1.0),   # GRASS - green
	Color(0.4, 0.28, 0.15, 1.0),   # DIRT - brown
]

## `normal` is expected already-normalized (the meshing backends' own
## per-cell gradient normal, e.g. TerrainMeshBackendMT's `n` - see its
## generate_brick_mesh()) - not re-normalized here, so a zero/degenerate
## normal would read as "steep" (dot near 0) rather than crash; that's an
## acceptable fallback for a first pass, not a correctness requirement.
static func classify(centroid: Vector4, normal: Vector4) -> int:
	if normal.dot(UP) < STEEP_DOT_THRESHOLD:
		return ROCK
	return GRASS if centroid.y > HIGH_HEIGHT_THRESHOLD else DIRT
