// Procedural foam and noise over the 4D horizontal volume.
//
//   #include "res://ramon/Water/carried/shaders/foam_4d.gdshaderinc"
//
// Drop-in for any shader that can hand it a point in the 4D world. See shaders/README.md.
//
// EVERY FUNCTION HERE TAKES A `vec3` THAT IS (x, z, w), NOT (x, y, z). Gravity in this
// project is along y, so the horizontal space a sea surface or a ground plane lives over is
// three-dimensional: two axes you can see and one you turn the slice to reach.
//
// WHY THAT MATTERS, AND WHY A 2D TEXTURE WILL NOT DO. A 3D game can paint foam with a
// scrolling 2D texture over its ground plane. Here the pattern has to be defined over all
// three horizontal axes, because turning the slice re-cuts the world along W and a pattern
// with no W variation smears into stripes exactly when the camera starts moving through it.
//
// ROTATION-INVARIANCE IS BY CONSTRUCTION, AND IT IS THE CALLER'S JOB TO KEEP IT. These are
// pure functions of a WORLD point. Pass the world position of the surface and the pattern is
// welded to the water: turn the slice and the foam stays on the wave it belongs to. Pass
// anything slice-relative - a camera-space position, a screen UV, a grid index - and it will
// swim across the surface as you turn, which looks like the sea sliding under its own foam.
// If this ever starts shimmering, that is the first thing to check.

#ifndef FOAM_4D_INCLUDED
#define FOAM_4D_INCLUDED


vec3 foam4d_hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			dot(p, vec3(269.5, 183.3, 246.1)),
			dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}


float foam4d_hash13(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}


/// Trilinear value noise over (x, z, w). Generic - exposed because anything using this file
/// for foam usually wants a matching noise band for its surface detail, and two different
/// hashes in one surface read as two different materials.
float foam4d_value(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = foam4d_hash13(i + vec3(0.0, 0.0, 0.0));
	float n100 = foam4d_hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = foam4d_hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = foam4d_hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = foam4d_hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = foam4d_hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = foam4d_hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = foam4d_hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
			mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}


/// Cellular (Worley) noise over (x, z, w). Returns the distance to the nearest feature point
/// and to the second nearest, so `y - x` is the cell-boundary field that draws bubble walls.
///
/// Twenty-seven neighbours, because in three dimensions that is what it takes - the 3x3 of a
/// 2D implementation misses the diagonals in W and leaves seams that only show up once the
/// slice turns, which is a miserable thing to debug.
vec2 foam4d_worley(vec3 p, float jitter) {
	vec3 cell = floor(p);
	vec3 local = p - cell;
	float nearest = 8.0;
	float second = 8.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 offset = vec3(float(i), float(j), float(k));
				vec3 feature = foam4d_hash33(cell + offset) * jitter + (0.5 - 0.5 * jitter);
				float d = length(offset + feature - local);
				if (d < nearest) {
					second = nearest;
					nearest = d;
				} else if (d < second) {
					second = d;
				}
			}
		}
	}
	return vec2(nearest, second);
}


/// Foam coverage at a 4D horizontal world point, 0 to 1.
///
///   p         the point, in (x, z, w) metres
///   density   0 nothing, 1 a solid sheet. This is the dial to drive from whatever decides
///             where foam belongs - a Jacobian determinant, a shoreline distance, a splash.
///   scale     metres across one cell. ~0.4 for sea foam, larger for a lazier raft.
///   time      seconds. Drifts and slowly reorganises, so foam does not look painted on.
///
/// FOAM IS THE EDGES BETWEEN CELLS, NOT THE CELLS. This is the whole shape of the thing and
/// it is easy to get backwards. Look at a photograph of a breaking sea: the white is a
/// NETWORK of filaments with open water inside the holes, because foam collects where
/// surface flow converges, and convergence lines are the boundaries between patches that are
/// being pushed apart - not the middles of them.
///
/// So the field is `second nearest - nearest`, which goes to zero exactly where you are
/// equidistant from two feature points, i.e. ON a cell wall. Using the nearest distance
/// alone instead paints a disc around every feature point and gives white blobs with water
/// between them - the photographic negative of foam. (It is what the first version of this
/// did.)
///
/// Three layers:
///   network  the ropes themselves, thickening with density until the holes close over
///   wisps    a finer boundary field, texturing the ropes and leaving strands on open water
///   mottle   value noise, so a rope is not a uniformly bright line
float foam_4d(vec3 p, float density, float scale, float time) {
	if (density <= 0.002) {
		return 0.0;
	}
	// Drift is deliberately not axis-aligned, including through W: foam sliding along a world
	// axis is a pattern the eye picks out immediately.
	vec3 q = p / max(scale, 0.001) + vec3(0.11, -0.07, 0.05) * time;

	// DOMAIN WARP, and it is what separates foam from a crackle texture. A Worley lattice
	// has straight walls and sharp three-way vertices; real foam filaments wander, because
	// the surface carrying them is being stirred. Bending the lookup before it reaches the
	// lattice costs three value-noise samples and buys every bit of that irregularity.
	// Two octaves, and they do different jobs. The coarse one makes whole cells wander off
	// the lattice; the fine one bows the WALLS, which is what rounds a Voronoi cell. One
	// octave alone still leaves straight segments between vertices - recognisably a
	// polygon - however far it drags them about.
	vec3 warp_coarse = vec3(
			foam4d_value(q * 0.85 + vec3(13.1, 2.7, 41.3)),
			foam4d_value(q * 0.85 + vec3(5.9, 27.4, 8.2)),
			foam4d_value(q * 0.85 + vec3(33.7, 17.6, 23.9))) - 0.5;
	vec3 warp_fine = vec3(
			foam4d_value(q * 2.6 + vec3(7.7, 35.2, 12.8)),
			foam4d_value(q * 2.6 + vec3(21.4, 3.3, 29.1)),
			foam4d_value(q * 2.6 + vec3(2.9, 44.6, 18.5))) - 0.5;
	q += warp_coarse * 0.55 + warp_fine * 0.22;

	// The network. `boundary` is 0 on a cell wall and grows toward a cell interior, so a
	// small threshold draws thin ropes and a large one floods the cells.
	vec2 cell = foam4d_worley(q, 0.9);
	float boundary = cell.y - cell.x;
	// Thickness wanders along a rope rather than being constant, for the same reason as the
	// warp: a filament of even width reads as drawn rather than collected.
	float vary = foam4d_value(q * 1.3 + vec3(2.2, 9.8, 15.4));
	float width = mix(0.012, 1.00, density * density) * mix(0.55, 1.45, vary);
	// Feathered rather than hard: foam has no edge, it thins out.
	float profile = 1.0 - smoothstep(width * 0.15, width, boundary);
	// Round the rope's own cross-section. smoothstep alone gives a band with two parallel
	// sides; squaring the complement swells the middle and tapers the shoulders, which is
	// the difference between a filament and a stripe.
	float network = profile * profile * (3.0 - 2.0 * profile);

	// A finer network, three times over. Inside a rope it breaks the white up; outside, at
	// higher densities, it leaves the stray strands that keep open water from looking empty.
	vec2 fine = foam4d_worley(q * 3.1 + vec3(19.3, 7.1, 31.7), 0.95);
	float fine_width = mix(0.02, 0.22, density);
	float wisps = 1.0 - smoothstep(fine_width * 0.4, fine_width, fine.y - fine.x);

	// Mottling, so the ropes have grain rather than being painted on.
	float mottle = foam4d_value(q * 2.4 + vec3(5.2, 11.9, 2.7) + time * 0.08);

	float mask = max(network, wisps * network * mix(0.0, 0.85, density));
	return clamp(mask * mix(0.68, 1.0, mottle), 0.0, 1.0);
}


/// The same field plus its gradient, for shading. The gradient tilts the normal so foam
/// catches light as a crust rather than as a decal - which is most of what sells it, since a
/// flat white patch reads as a hole in the water however good its silhouette is.
///
/// Finite differences, three extra evaluations. If that is too much, use `foam_4d` and
/// perturb the roughness only.
float foam_4d_shaded(vec3 p, float density, float scale, float time, out vec3 gradient) {
	float centre = foam_4d(p, density, scale, time);
	float step_m = max(scale, 0.001) * 0.17;
	float dx = foam_4d(p + vec3(step_m, 0.0, 0.0), density, scale, time);
	float dz = foam_4d(p + vec3(0.0, step_m, 0.0), density, scale, time);
	float dw = foam_4d(p + vec3(0.0, 0.0, step_m), density, scale, time);
	gradient = vec3(dx - centre, dz - centre, dw - centre) / step_m;
	return centre;
}

#endif // FOAM_4D_INCLUDED
