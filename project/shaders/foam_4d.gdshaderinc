// Procedural foam and noise over the 4D horizontal volume.
//
//   #include "res://shaders/foam_4d.gdshaderinc"
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
///   scale     metres across one clump cell. ~0.6 for sea foam, larger for a lazier raft.
///   time      seconds. Drifts and slowly reorganises, so foam does not look painted on.
///
/// Three layers, which is what stops it reading as a flat white smear:
///   clumps   where foam is at all, from the nearest-feature distance
///   bubbles  the cell walls of a much finer lattice, brightening the clump interior
///   lacing   value noise punching holes, so the sheet is torn rather than solid
float foam_4d(vec3 p, float density, float scale, float time) {
	if (density <= 0.002) {
		return 0.0;
	}
	// Drift is deliberately not axis-aligned, including through W: foam sliding along a world
	// axis is a pattern the eye picks out immediately.
	vec3 q = p / max(scale, 0.001) + vec3(0.11, -0.07, 0.05) * time;

	vec2 clump_cell = foam4d_worley(q, 0.9);
	// The clump radius grows with density; past about 0.8 the cells touch and the foam
	// becomes a sheet, which is what a breaking crest should look like.
	float radius = mix(0.16, 1.05, density);
	float clumps = 1.0 - smoothstep(radius * 0.55, radius, clump_cell.x);

	// Bubble walls: the gap between nearest and second nearest is near zero exactly on a cell
	// boundary, which draws the film between bubbles.
	vec2 bubble_cell = foam4d_worley(q * 4.7 + vec3(19.3, 7.1, 31.7), 0.95);
	float walls = smoothstep(0.0, 0.33, bubble_cell.y - bubble_cell.x);

	// Lacing. Biased by density so that heavy foam tears less.
	float lace = foam4d_value(q * 1.9 + vec3(5.2, 11.9, 2.7) + time * 0.08);
	float torn = smoothstep(0.18, 0.62, lace + density * 0.55);

	// Bubbles brighten the inside rather than cutting it away, so the clump keeps its shape.
	float mask = clumps * torn * mix(0.45, 1.0, walls);
	return clamp(mask, 0.0, 1.0);
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
