shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, depth_draw_always;

// Gerstner ocean in four dimensions, drawn as one ordinary 3D grid inside the Cross-section
// engine's own World3D.
//
// WHY A 3D GRID AND NOT A MeshInstance4D. A 4D water mesh would have to be rebuilt and
// re-sliced every frame, and per-frame mesh regeneration was the dominant cost in the pen
// (perf/README.md). The Cross-section engine draws in CAMERA SPACE - its 3D camera sits at
// the origin with no transform and every 4D mesh is moved into the camera's frame and cut at
// local w = 0 there - so a plain 3D mesh added to the same World3D lands in the same
// picture, lit by the same suns, as long as it does that move itself. Same trick as
// flock_bird.gdshader. One instance total, which also keeps it inside the GLES3
// instance-uniform budget if this is ever wanted on web.
//
// HORIZONTAL SPACE IS THREE-DIMENSIONAL. Gravity is along y, so the water is a height field
// over (x, z, w), and a wave vector k is a 3-vector in that space. Deep-water dispersion
// w = sqrt(g |k|) is a statement about |k| alone and so is unchanged by the extra dimension.
// Throughout this shader a `vec3` named h, k or dir is (x, z, w) - NOT (x, y, z).
//
// THE SLICE PROBLEM, which is the whole reason this is interesting. Gerstner motion is
// Lagrangian: a water particle moves horizontally as well as vertically, bunching toward
// crests. In 3D that horizontal shuffle stays in the ground plane. In 4D it has a component
// along the off-slice horizontal axis, so a particle at rest inside your slice is displaced
// OUT of it, and the particle you actually see at a given spot started somewhere off-slice.
// Drawing the displaced position of an in-slice rest point would be wrong. Instead, for each
// grid vertex we solve the inverse problem - which rest point lands here - by fixed-point
// iteration, which converges quickly because the displacement is small next to the
// wavelength whenever the steepness constraint holds.

#include "res://ramon/WaterLab/carried/shaders/foam_4d.gdshaderinc"

const float GRAVITY = 9.81;
const int MAX_WAVES = 8;

// The camera's 4D frame. The basis is orthonormal, so the inverse is the transpose and
// taking a world point into camera space is four dot products.
uniform vec4 cam_position;
uniform vec4 cam_basis_x;
uniform vec4 cam_basis_y;
uniform vec4 cam_basis_z;
uniform vec4 cam_basis_w;
// An orthonormal pair spanning the slice's horizontal directions, in (x, z, w). The grid is
// laid out along these, so it is anchored in the WORLD rather than in camera space and stays
// flat however far the camera pitches.
uniform vec3 slice_axis_a;
uniform vec3 slice_axis_b;
// The off-slice horizontal direction, in (x, z, w). Only used by the debug view.
uniform vec3 slice_axis_off;
uniform float water_level = 0.0;
// WATER LAB: past the near grid (its half width), the far ring's waves fade toward a flat sea by five
// times that, so its coarse grid does not shimmer: the sea reaches the horizon (Ramon, 9 Oct: "make the
// sea larger, so you can look out into the distance").
uniform float near_extent = 60.0;

uniform int wave_count = 4;
uniform vec3 wave_dir[MAX_WAVES];   // unit, in (x, z, w)
uniform float wave_amp[MAX_WAVES];
uniform float wave_number[MAX_WAVES]; // |k| = 2 pi / wavelength
uniform float wave_steep[MAX_WAVES];  // Q, already clamped on the CPU
uniform float wave_phase[MAX_WAVES];  // omega * t, advanced on the CPU so time never grows
                                      // large enough to lose float precision in the shader

// 0 means plain sine heights with no horizontal displacement at all, for comparison. 2 is
// plenty for the steepnesses the presets use.
uniform int solve_iterations = 2;
// WATER LAB: which Gerstner look (Ramon, 9 Oct: "there's this sort of texture clipping with the sea
// underneath ... patches on top that are darker ... make the Gerstner 2 and 3"). The patches were
// lighting, not geometry: with the faces of this grid away from the camera, the engine flips the
// normal of every ordinary pixel, but the foam branch wrote its own normal unflipped, so wherever the
// crest foam began (foam > 0.002, a hard edge) the sky's reflection switched to a weaker one.
//   1  as it was (Trym's).
//   2  the foam branch's normal flipped as the engine flips the rest, and the foam's relief and its
//      matt finish faded in over the foam's first quarter: the same sea, no patches.
//   3  the way of the shader Trym's came from (github.com/emilje/godot-water-shader, g_wave.gdshader):
//      the surface's own normal everywhere, nothing flipped, and the foam only a colour mixed in, never
//      tilting the normal; the crests' breaking also faded out with distance, so the coarse far ring
//      does not foam in big straight-edged sheets.
uniform int gerstner_style = 2;

// SURFACE DETAIL. The wave sum alone is smooth at every scale the grid can carry, which
// reads as oil rather than water. This is a band of value noise over (x, z, w) added to the
// height after the solve, with its gradient folded into the normal: it is texture on the
// surface, not part of the wave dynamics, so it deliberately takes no part in the
// displacement or the Jacobian.
uniform float detail_strength = 0.085;  // metres, coarse octave
uniform float detail_scale = 4.5;       // metres per noise cell, coarse octave
uniform float detail_time = 0.0;        // advanced on the CPU, same reason as wave_phase

// DEPTH FADING AND LIGHT ATTENUATION. Water does not have a colour so much as it eats one:
// light travelling through it is absorbed per metre, and unevenly - red goes first, blue
// last, which is why a deep pool reads blue-green and a shallow one reads like whatever is
// under it. Beer-Lambert, `exp(-absorption * metres)`, per channel.
//
// This is what makes a pool look deep, and it only shows when there is something to see
// THROUGH the water. In open ocean the path length is the far plane, the transmitted term
// goes to zero and all that is left is `scatter_color` - which is why that doubles as the
// deep-sea colour and there is no separate one.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Per metre, per channel. Red about four times blue, roughly clear-water ocean.
uniform vec3 absorption = vec3(0.42, 0.11, 0.07);
// What the water scatters back toward you, and how fast that saturates with depth.
uniform vec3 scatter_color : source_color = vec3(0.035, 0.175, 0.205);
uniform float scatter_strength = 0.21;
// Beyond this the exponentials have long since flattened; the clamp is to keep a sky-depth
// path length (effectively infinite) out of the arithmetic.
uniform float max_path_metres = 40.0;
// DEBUG ONLY. Paints `behind` - how far the view ray travels through water before it meets
// anything - instead of lighting the sea, so the value can be read off a screenshot rather
// than inferred from what the lit picture happens to look like. Black is zero, green ramps
// to max_path_metres, magenta is beyond it or negative.
uniform bool debug_path = false;
uniform vec3 deep_color : source_color = vec3(0.016, 0.055, 0.094);
uniform vec3 shallow_color : source_color = vec3(0.07, 0.22, 0.26);
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.96);
// WHERE FOAM STARTS, as a value of the Jacobian determinant. Measured rather than guessed:
// _probe_jacobian_runner.gd computes the determinant over a patch of horizontal space for
// every preset and reports, at 0.62, roughly 3% of the storm foaming, 5% of the chop and
// none at all of the calm - which is about what a sea looks like. The determinant's real
// range is wider than it seems from a screenshot: the storm reaches 0.16. An earlier guess
// of 0.88 painted a third of the sea white.
uniform float foam_threshold = 0.62;
uniform float foam_softness = 0.18;
// How hard the noise pushes the foam threshold about, and how opaque foam gets at its
// densest. Both exist because the first version foamed in a thin dithered line that read as
// an artefact rather than as water.
uniform float foam_break = 1.4;
// The procedural foam, from shaders/foam_4d.gdshaderinc.
// PERSISTENCE. The reference implementation this scene was modelled on has "persisting
// Jacobian foam" - foam that stays after the crest has stopped breaking and fades out over
// a second or two - and the usual way to get it is a foam buffer you write to and decay.
// That is exactly what does not work here: the buffer would have to be a 3D texture over
// (x, z, w), which is why the brief scoped persistence out.
//
// It does not need one. The wave field is analytic, so the Jacobian at an earlier moment is
// just the same sum with each phase wound back by its own omega. Sample a few moments back,
// decay each by its age, keep the strongest. No state, no buffer, and it costs a handful of
// extra wave loops in the VERTEX stage where they are cheap.
uniform int foam_history_samples = 4;
uniform float foam_history_step = 0.28;   // seconds between lookbacks
uniform float foam_decay = 1.15;          // e-folding time of the fade
uniform float foam_cell_size = 0.85;   // metres across one cell of the foam network
uniform float foam_relief = 0.055;     // how much the crust tilts the normal
uniform bool foam_textured = true;     // off falls back to the flat white it used to be
// Where the bubble detail gives up and fades back to the plain mask. Past this the cells are
// smaller than a pixel and sampling them point-by-point sparkles; there is no mip chain to
// fall back on because nothing here is a texture.
uniform float foam_detail_near = 22.0;
uniform float foam_detail_far = 65.0;
uniform float foam_opacity = 1.0;
uniform float intersection_foam_depth = 0.55;
uniform float specular_strength = 0.35;
uniform float roughness_value = 0.08;
// Artistic trim on the sea's answer to direct light. 1.0 is physically matched to the rest
// of the scene after the fix below; lower it only if a particular sea is still too hot.
uniform float light_response = 1.0;
// 1 renders the Jacobian determinant as a colour ramp instead of water.
uniform bool debug_jacobian = false;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec4 normal_4d_camera;
varying float jacobian_det;
varying float off_slice_rest;
varying float crest_height;
varying float surface_detail;
// The solved horizontal rest point, in WORLD (x, z, w). Foam is a function of this and
// nothing slice-relative, which is what welds the pattern to the water as the slice turns.
varying vec3 rest_world;
// Foam left over from crests that have already broken - see foam_history_samples.
varying float foam_history;
// The normal light() actually uses. A SEPARATE varying from normal_4d_camera because Godot
// forbids reassigning in fragment() anything the vertex stage assigned - and the foam crust
// has to tilt the normal, which only the fragment stage knows about. Written in fragment,
// read in light().
varying vec4 lit_normal_4d;


// Displacement of the horizontal rest point h, and the surface height there. Both come from
// the same loop because they share every cosine and sine.
vec3 wave_displacement(vec3 h, float steep_scale, out float height) {
	vec3 disp = vec3(0.0);
	height = 0.0;
	for (int i = 0; i < wave_count; i++) {
		float phase = dot(wave_dir[i] * wave_number[i], h) - wave_phase[i];
		disp += wave_steep[i] * steep_scale * wave_amp[i] * wave_dir[i] * cos(phase);
		height += wave_amp[i] * sin(phase);
	}
	return disp;
}


// Two octaves, and the gradient with them. The gradient is what actually shows - it tilts
// the normal, and a tilted normal catches the sun where a height change of 8 cm would not.
float detail_field(vec3 h, out vec3 gradient) {
	gradient = vec3(0.0);
	if (detail_strength <= 0.0) {
		return 0.0;
	}
	float total = 0.0;
	float amplitude = detail_strength;
	float scale = detail_scale;
	for (int octave = 0; octave < 2; octave++) {
		vec3 q = h / scale + vec3(detail_time * (0.6 + 0.4 * float(octave)));
		float e = 0.5;
		float n0 = foam4d_value(q);
		float nx = foam4d_value(q + vec3(e, 0.0, 0.0));
		float nz = foam4d_value(q + vec3(0.0, e, 0.0));
		float nw = foam4d_value(q + vec3(0.0, 0.0, e));
		total += (n0 - 0.5) * 2.0 * amplitude;
		gradient += vec3(nx - n0, nz - n0, nw - n0) * (2.0 * amplitude / (e * scale));
		amplitude *= 0.45;
		scale *= 0.34;
	}
	return total;
}


// The 4D equivalent of a 3D cross product: perpendicular to all three inputs. Same expansion
// as the engine's own render/shaders/perpendicular_4d.glsl, written out here rather than
// included so this scene stays independent of the module.
vec4 perpendicular_4d(vec4 a, vec4 b, vec4 c) {
	return vec4(
			-a.y * (b.z * c.w - b.w * c.z) + a.z * (b.y * c.w - b.w * c.y) - a.w * (b.y * c.z - b.z * c.y),
			+a.x * (b.z * c.w - b.w * c.z) - a.z * (b.x * c.w - b.w * c.x) + a.w * (b.x * c.z - b.z * c.x),
			-a.x * (b.y * c.w - b.w * c.y) + a.y * (b.x * c.w - b.w * c.x) - a.w * (b.x * c.y - b.y * c.x),
			+a.x * (b.y * c.z - b.z * c.y) - a.y * (b.x * c.z - b.z * c.x) + a.z * (b.x * c.y - b.y * c.x));
}


// The Jacobian determinant of the horizontal displacement, `seconds_ago` in the past.
//
// APPROXIMATE IN ONE WAY WORTH KNOWING: it winds the phases back but evaluates at the
// CURRENT rest point, so the foam it leaves trails in the wave's own frame rather than being
// carried along by the surface flow. Over a fraction of a second that is close; over many
// seconds it would drift away from the truth, which is the practical ceiling on foam_decay.
float jacobian_determinant_at(vec3 rest, float seconds_ago, float steep_scale) {
	mat3 jac = mat3(1.0);
	for (int i = 0; i < wave_count; i++) {
		// Deep water, so each wave's own angular frequency follows from its wavenumber.
		float omega = sqrt(GRAVITY * wave_number[i]);
		float phase = dot(wave_dir[i] * wave_number[i], rest)
				- (wave_phase[i] - omega * seconds_ago);
		float s = -wave_steep[i] * steep_scale * wave_amp[i] * wave_number[i] * sin(phase);
		vec3 d = wave_dir[i];
		jac[0] += s * d * d.x;
		jac[1] += s * d * d.y;
		jac[2] += s * d * d.z;
	}
	return determinant(jac);
}


void vertex() {
	float steep_scale = solve_iterations > 0 ? 1.0 : 0.0;

	// Where this grid vertex sits in the slice's own horizontal 2-plane, in world (x, z, w).
	// The grid is centred on the camera, so the ocean follows you and never runs out.
	vec3 cam_h = vec3(cam_position.x, cam_position.z, cam_position.w);
	vec3 target = cam_h + VERTEX.x * slice_axis_a + VERTEX.z * slice_axis_b;

	// Solve for the rest point whose displaced position lands back on this spot. The fixed
	// point is h = target - displacement(h); each pass is one more order of the horizontal
	// shuffle, and at 0 passes the displacement is switched off entirely and this is an
	// ordinary sum of sines.
	vec3 rest = target;
	float height = 0.0;
	for (int it = 0; it < solve_iterations; it++) {
		rest = target - wave_displacement(rest, steep_scale, height);
	}
	vec3 disp = wave_displacement(rest, steep_scale, height);
	vec3 surface_h = rest + disp;

	// How far off the slice the rest point had to sit for its displacement to bring it back.
	// Zero in 3D; nonzero exactly when a wave is travelling through W.
	off_slice_rest = dot(rest - target, slice_axis_off);
	crest_height = height;

	// The tangents of the displaced surface in all three horizontal directions, as 4D world
	// vectors, and the 3x3 Jacobian of the horizontal displacement that rides along with them.
	// d(disp)/dh_a = sum( -Q A K sin(phase) * dir * dir[a] ), so the Jacobian is the identity
	// plus a sum of rank-one terms and the tangents cost nothing extra to collect here.
	mat3 jac = mat3(1.0);
	vec3 dheight = vec3(0.0);
	for (int i = 0; i < wave_count; i++) {
		float phase = dot(wave_dir[i] * wave_number[i], rest) - wave_phase[i];
		float s = -wave_steep[i] * steep_scale * wave_amp[i] * wave_number[i] * sin(phase);
		vec3 d = wave_dir[i];
		jac[0] += s * d * d.x;
		jac[1] += s * d * d.y;
		jac[2] += s * d * d.z;
		dheight += wave_amp[i] * wave_number[i] * cos(phase) * d;
	}
	jacobian_det = determinant(jac);

	// What this spot was doing a moment ago, decayed by how long ago that was. Taken as a
	// max rather than a sum: foam does not get whiter for having broken twice.
	float history = 0.0;
	for (int h = 1; h <= foam_history_samples; h++) {
		float back = float(h) * foam_history_step;
		float was = jacobian_determinant_at(rest, back, steep_scale);
		float pinched = smoothstep(foam_threshold + foam_softness,
				foam_threshold - foam_softness, was);
		history = max(history, pinched * exp(-back / max(foam_decay, 0.01)));
	}
	foam_history = history;

	// Detail last, so it rides on top of the solved surface without disturbing the solve.
	vec3 detail_gradient;
	float detail = detail_field(rest, detail_gradient);
	height += detail;
	dheight += detail_gradient;
	surface_detail = detail;
	rest_world = rest;

	// Tangent a is (d(surface_h)/dh_a with y = d(height)/dh_a), written back into world axis
	// order (x, y, z, w).
	vec4 t0 = vec4(jac[0].x, dheight.x, jac[0].y, jac[0].z);
	vec4 t1 = vec4(jac[1].x, dheight.y, jac[1].y, jac[1].z);
	vec4 t2 = vec4(jac[2].x, dheight.z, jac[2].y, jac[2].z);
	vec4 n4 = normalize(perpendicular_4d(t0, t1, t2));
	// Keep it pointing up out of the water rather than down into it.
	if (n4.y < 0.0) {
		n4 = -n4;
	}

	// WATER LAB: far out, the waves fade (see near_extent).
	float lod = 1.0 - 0.75 * smoothstep(near_extent, near_extent * 5.0, length(VERTEX.xz));
	surface_h = target + (surface_h - target) * lod;
	height *= lod;
	n4 = normalize(mix(vec4(0.0, 1.0, 0.0, 0.0), n4, lod));
	foam_history *= lod;
	if (gerstner_style >= 3) {
		float near_k = 1.0 - smoothstep(near_extent, near_extent * 5.0, length(VERTEX.xz));
		jacobian_det = mix(1.0, jacobian_det, near_k);
		foam_history *= near_k;
	}
	vec4 world = vec4(surface_h.x, water_level + height + VERTEX.y, surface_h.y, surface_h.z);
	vec4 rel = world - cam_position;
	// Orthonormal basis, so the inverse is four dot products. The w component comes out at
	// ~0 by construction: that is what the solve above was for.
	VERTEX = vec3(dot(rel, cam_basis_x), dot(rel, cam_basis_y), dot(rel, cam_basis_z));
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);

	normal_4d_camera = vec4(dot(n4, cam_basis_x), dot(n4, cam_basis_y),
			dot(n4, cam_basis_z), dot(n4, cam_basis_w));
	// The in-slice part is what Godot's own specular and fog want.
	NORMAL = normalize(normal_4d_camera.xyz);
}


void fragment() {
	// Intersection foam: a bright line where the water meets something solid. Unrolled here
	// rather than put in a helper on purpose - Godot exposes a stage's builtins only inside
	// that stage's own function, so INV_PROJECTION_MATRIX is not visible to anything
	// fragment() calls.
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 depth_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	depth_view.xyz /= depth_view.w;
	float behind = -depth_view.z - (-VERTEX.z);
	// A NEGATIVE READING MEANS THE DEPTH SAMPLE IS THE WATER'S OWN SURFACE, not that the sea
	// is infinitely shallow here. The shader declares `depth_draw_always`, so the water is in
	// the depth prepass it then reads back; wherever a nearer crest wrote that pixel, a
	// farther fragment subtracts a smaller distance from a larger one and gets less than
	// zero. `debug_path` showed this as magenta across nearly the whole open sea.
	//
	// It was not a harmless sign error. `path` clamped to 0, so `transmitted` kept the full
	// background, and `edge` - the intersection foam that is meant to ring the pillar and the
	// walkway - went to 1 and painted foam_color over the entire surface. That is the white
	// that made the water blinding and hid everything swimming under it.
	//
	// No geometry behind means the ray leaves through open water, so the honest path is the
	// longest one, not the shortest.
	bool found_bottom = behind > 0.0;
	if (!found_bottom) {
		behind = max_path_metres;
	}

	// Default for both branches; the foam branch below tilts it.
	lit_normal_4d = normal_4d_camera;
	// Style 3: the surface's own normal, never flipped (see gerstner_style).
	if (gerstner_style >= 3) {
		NORMAL = normalize(normal_4d_camera.xyz);
	}

	if (debug_jacobian) {
		// Blue where the surface is stretched, white at rest, red where it is pinching.
		// No early return: `return` is rejected inside fragment().
		//
		// CENTRED TIGHTLY ON 1. The steepness clamp holds sum(Q k A) at or under 1, which is
		// exactly the condition that keeps the determinant positive, so it lives in a narrow
		// band around 1 and a 0..2 ramp renders the whole sea flat white - which is what the
		// first version of this did, and it hid the fact that the foam term was doing
		// nothing. Below the foam threshold it goes hard red, so a probe can count foam off
		// this view directly instead of guessing at it from the lit picture, where crest
		// specular looks exactly like foam.
		float d = jacobian_det;
		vec3 ramp;
		if (d < foam_threshold) {
			ramp = vec3(1.0, 0.13, 0.10);
		} else if (d < 1.0) {
			ramp = mix(vec3(0.97, 0.62, 0.55), vec3(0.95, 0.95, 0.95),
					clamp((d - foam_threshold) / max(1.0 - foam_threshold, 0.001), 0.0, 1.0));
		} else {
			ramp = mix(vec3(0.95, 0.95, 0.95), vec3(0.10, 0.35, 0.90),
					clamp((d - 1.0) / 0.5, 0.0, 1.0));
		}
		// FOR THE EYE, NOT FOR MEASURING. Lighting and the tonemap shift these colours, so
		// reading a foam fraction off this view is unreliable - two attempts to do it were
		// both wrong, once washed white by the tonemapper and once because an unlit version
		// of this branch drew nothing at all. The numbers come from
		// _probe_jacobian_runner.gd, which computes the determinant directly; this is here
		// so you can see WHERE on the sea it is dipping.
		ALBEDO = ramp;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		METALLIC = 0.0;
		EMISSION = ramp * 0.75;
	} else {
		// Jacobian foam: where the horizontal map stops being injective the surface is
		// pinching, which is a breaking crest. Stateless on purpose - persistent foam would
		// need a 3D texture over (x, z, w), which is out of scope for this test.
		// The noise shifts the threshold rather than being mixed into the colour after the
		// fact, so foam gains a ragged edge instead of the dithered lattice line a plain
		// smoothstep leaves where the determinant crosses over at grid resolution.
		float ragged = foam_threshold + surface_detail * foam_break;
		float pinch = smoothstep(ragged + foam_softness, ragged - foam_softness, jacobian_det);
		// Whatever is breaking now, or whatever was breaking recently and has not faded yet.
		pinch = max(pinch, foam_history);
		// Only where something really is just behind the surface. Guarded as well as the
		// clamp above, so that a future change to `behind` cannot quietly turn the whole sea
		// into foam again.
		float edge = found_bottom
				? 1.0 - smoothstep(0.0, intersection_foam_depth, behind)
				: 0.0;
		float foam = clamp(max(pinch * foam_opacity, edge * 0.9), 0.0, 1.0);
		// How far this view ray travels through water before it hits anything: the pool
		// floor, a pillar, the sea bed, or nothing at all.
		float path = clamp(behind, 0.0, max_path_metres);
		vec3 transmitted = texture(screen_texture, SCREEN_UV).rgb * exp(-absorption * path);
		vec3 scattered = scatter_color * (1.0 - exp(-scatter_strength * path));
		vec3 water = transmitted + scattered;

		// TEXTURE THE FOAM RATHER THAN PAINTING IT WHITE. `foam` above says how much foam
		// belongs here; foam_4d says what it looks like. Evaluated at the WORLD point, so
		// the pattern belongs to the water and not to the screen - pass anything
		// slice-relative and it swims as you turn.
		float cover = foam;
		vec3 crust = vec3(0.0);
		if (foam_textured && foam > 0.002) {
			vec3 gradient;
			cover = foam_4d_shaded(rest_world, foam, foam_cell_size, detail_time * 12.0,
					gradient);
			// A height field's normal is (-dh/dx, 1, -dh/dz, -dh/dw); here only the
			// horizontal derivatives exist, so the relief is that, taken into the camera's
			// frame to meet the normal the vertex stage left behind.
			vec4 relief_world = vec4(-gradient.x, 0.0, -gradient.y, -gradient.z) * foam_relief;
			// Style 2: the relief comes in over the foam's first quarter, not at once. Style 3: none, the
			// foam is a colour only (the original's way).
			if (gerstner_style == 2) {
				relief_world *= smoothstep(0.002, 0.25, foam);
			} else if (gerstner_style >= 3) {
				relief_world = vec4(0.0);
			}
			vec4 relief = vec4(dot(relief_world, cam_basis_x), dot(relief_world, cam_basis_y),
					dot(relief_world, cam_basis_z), dot(relief_world, cam_basis_w));
			lit_normal_4d = normalize(normal_4d_camera + relief);
			if (gerstner_style == 2) {
				// Flipped as the engine flips every other pixel of this sea.
				vec3 nl = normalize(lit_normal_4d.xyz);
				NORMAL = FRONT_FACING ? nl : -nl;
			} else if (gerstner_style <= 1) {
				NORMAL = normalize(lit_normal_4d.xyz);
			}
			// Fade the bubbles out with distance, back to the smooth mask. Procedural
			// detail has no mip chain, so beyond the point where a cell is sub-pixel it
			// aliases into sparkle - which reads as fireflies on the horizon.
			float detail_fade = 1.0 - smoothstep(foam_detail_near, foam_detail_far,
					length(VERTEX));
			// A MILKY FLOOR UNDER THE NETWORK. foam_4d returns the filaments alone, and on
			// their own they leave the holes as bare dark water, which reads as a net
			// thrown over the sea. Real foam leaves a film between its strands, so where
			// the density is high the holes keep a fraction of the foam colour and the
			// bright network sits on top of that. Scene-level, deliberately not in the
			// module: how milky foam is belongs to the water it is on.
			cover = foam * mix(0.32, 1.0, cover);
			cover = mix(foam, cover, detail_fade);
			crust = vec3(cover * 0.12 * detail_fade);
		}

		if (debug_path) {
			if (!found_bottom) {
				// Blue: nothing opaque behind the surface, so the ray leaves through open
				// water and the path is the longest one, not the shortest.
				ALBEDO = vec3(0.1, 0.3, 1.0);
			} else if (behind < 0.0) {
				ALBEDO = vec3(1.0, 0.0, 1.0);
			} else if (behind > max_path_metres) {
				ALBEDO = vec3(0.4, 0.0, 0.4);
			} else {
				ALBEDO = vec3(0.0, clamp(behind / max_path_metres, 0.0, 1.0), 0.0);
			}
			cover = 0.0;
			crust = vec3(0.0);
		}
		ALBEDO = debug_path ? ALBEDO : mix(water, foam_color, cover) + crust;
		ALPHA = 1.0;
		ROUGHNESS = mix(roughness_value, 0.88, cover);
		SPECULAR = mix(specular_strength, 0.04, cover);
		METALLIC = 0.0;
		EMISSION = vec3(0.0);
	}
}


// Lit as the rest of the 4D world is lit. LIGHT_SLICE_COMPONENT is how much of this light
// points along the camera's own W axis; the remainder is its in-slice direction. Same shape
// as the module's render/3d/shaders/tetra_light_shader.glsl, with our 4D surface normal in
// place of the tetrahedron's cell normal, so the water dims and brightens in step with the
// 4D geometry around it as the slice turns.
//
// This builtin is registered for every `spatial` shader's light() function
// (servers/rendering/shader_types.cpp), not only for the module's own shaders, so a plain
// shader like this one can use it - checked rather than assumed.
void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	float normal_dot_light = max(dot(normalize(lit_normal_4d), light_direction_4d), 0.0);
	// NO ALBEDO, AND A 1/PI. Both are what Godot's own diffuse does, checked in this fork
	// rather than assumed: scene_forward_lights_inc.glsl:203 computes
	// `diffuse_brdf_NL = cNdotL * (1.0 / M_PI)` and line 206 adds `light_color *
	// diffuse_brdf_NL * attenuation` with no albedo, because
	// scene_forward_clustered.glsl:2806 applies `diffuse_light *= albedo;` at the end - its
	// comment says so outright.
	//
	// This shader used to do neither. Multiplying by ALBEDO applied it TWICE, and omitting
	// the 1/PI made every direct-lit pixel about 3.14x too bright. Together that is albedo x
	// pi: foam at 0.95 albedo came out roughly three times too bright while open water at
	// 0.1 came out at a third - blinding white highlights sitting on near-black water, which
	// is exactly how the sea looked and why it could not be fixed by turning any one feature
	// off. The sky's ambient, the Blinn highlight, the foam and the scatter were each
	// measured and each moved the glare by under half a percent; this is the whole of it.
	//
	// `ramon/chickenpen` models are unaffected - they use the module's own tetra light
	// shader, which gets the albedo right. It does omit the same 1/PI, so 4D meshes are
	// uniformly brighter than Godot's standard shading, but that is consistent across the
	// 4D world and is not this shader's call to change.
	// TODO(flag-for-andrew): engine/modules/4d/render/3d/shaders/tetra_light_shader.glsl:7
	// adds `LIGHT_COLOR * ATTENUATION * normal_dot_light` with no `1.0 / PI`, where Godot's
	// built-in Lambert has one. Deliberate or not, it makes every tetra mesh pi times
	// brighter under direct light than an equivalent 3D mesh.
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * normal_dot_light * (1.0 / PI) * light_response;

	// A cheap Blinn term so crests catch the sun; the half vector only makes sense in the
	// slice, so this uses the in-slice part of the normal. SPECULAR_AMOUNT, not SPECULAR -
	// light() sees a different set of builtins from fragment() and SPECULAR is not among
	// them (servers/rendering/shader_types.cpp).
	vec3 half_vector = normalize(LIGHT * light_xyz_component + VIEW);
	float spec = pow(max(dot(normalize(lit_normal_4d.xyz), half_vector), 0.0),
			1.0 + 64.0 * (1.0 - ROUGHNESS));
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * SPECULAR_AMOUNT * light_response;
}
