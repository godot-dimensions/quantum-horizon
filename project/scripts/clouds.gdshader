shader_type spatial;
render_mode skip_vertex_transform, unshaded, depth_draw_never, blend_mix, shadows_disabled;
// cull_disabled deliberately NOT set, unlike the earlier flat-plane version:
// this is now a real enclosed box with correctly-wound outward-facing
// faces (see this shader's own header), so normal backface culling hides
// the far/inner faces properly. With it disabled, both faces drew with no
// reliable ordering between them (transparent/no-depth-write rendering
// doesn't sort triangles within a single mesh) - the far face visibly
// bled through on top of the near one, caught directly in an early test
// screenshot.

// A REAL 4D object (a BoxTetraMesh4D child of Terrain, see clouds_layer.gd)
// rendered through the engine's own Cross-Section pipeline - the same
// pipeline that slices the terrain itself, not a 3D-only mock outside it.
// This was a deliberate architecture change from an earlier version that
// used an ordinary flat MeshInstance3D plane to fake 4D-reactivity via
// pushed rotation uniforms: that plane was cheap, but a zero-thickness
// flat plane viewed at any oblique angle has vanishing on-screen area and
// severe perspective compression at its far edge (confirmed directly this
// session: with depth-testing disabled, its true silhouette was a massive
// wedge smeared toward the horizon, normally hidden behind the terrain
// except for a sliver that read as "a band glued to the screen"). No
// amount of alpha-fade tuning fixes that - it's the wrong SHAPE, not a
// tuning problem. A real 4D box, sliced by the same pipeline as terrain,
// gets a genuine 3D volume (visible side walls, not just a flat cap) and
// the same "shape changes correctly with slice angle" behavior terrain
// itself has - both problems solved by construction, not by fading.
//
// The performance concern that originally pushed this outside the 4D
// pipeline was "dozens of individual 4D cloud objects," not 4D-ness
// itself - a SINGLE 4D slab sized to the terrain's footprint costs about
// as much as one more terrain brick, nothing like per-cloud objects would.
//
// vertex() below is COPIED VERBATIM from the engine's own
// engine/modules/4d/render/cross_section/tetra_cross_section_shader.glsl -
// this is not stylistic, it's load-bearing: TetraMaterial4D's cross-section
// ShaderMaterial only auto-assigns the engine's default shader if the slot
// is still null (see Material4D::get_cross_section_material() /
// TetraMaterial4D::update_cross_section_material() in that same module),
// so clouds_layer.gd hands this shader in directly and it sticks - but the
// tetrahedron-slicing math (CUSTOM0-3 tet corners, the edge-crossing
// lookup tables, the modelview instance uniforms the rendering engine
// pushes per-instance) has to be reproduced exactly or the mesh doesn't
// slice at all. Only fragment() below is genuinely ours.
//
// noise_volume_atlas/sample_slice/sample_volume: a real 3-axis FBM noise
// volume - DEPTH separate 2D slices (see _bake_clouds_volume_runner.gd,
// deleted after running) packed into one flipbook atlas image (manual
// 3D-texture-via-2D-atlas trick, since FastNoiseLite/NoiseTexture3D don't
// give a genuinely seamless 4-axis volume here). Each tile is a seamless
// bake (NoiseTexture2D seamless=true, then wrapped-translated per slice).
// This part is unchanged from the earlier plane-based version and was
// already confirmed working well - only where/how it's sampled changed.
//
// The noise sampling coordinate comes from interpolating the tetrahedron's
// RAW, UNTRANSFORMED corners (CUSTOM0-3, in the box's own local space)
// using the exact same edge/mix_weight the slicing math below already
// computes - NOT from reconstructing a "world position" out of the sliced
// view-space VERTEX via INV_VIEW_MATRIX (an earlier version of this shader
// did that, and it was wrong: confirmed directly this session that pure
// camera zoom/orbit, with no 4D rig rotation at all, visibly resampled the
// noise pattern instead of just changing its apparent size/angle - the
// reconstruction was silently camera-dependent in a way it should never
// have been). CUSTOM0-3 never involve the camera at all, so local_pos
// below is provably stable under camera movement, and changes only when
// the tetrahedron's OWN w-values (which the modelview transform - the
// rig's rotation baked into this mesh's global transform - do affect)
// cross zero differently, i.e. only when the 4D slice actually rotates.
//
// That alone gives "a different fixed patch of the box's own texture gets
// exposed as the rig rotates" (since the box's SHAPE already responds
// correctly to rotation, via the same slicing math terrain uses) - but not
// "the pattern itself visibly warps/tilts as the angle changes," which is
// what the previous (camera-broken) version had, since it multiplied its
// sampling coordinate by the rig's own basis before the noise lookup.
// Restored here the same way, but applied to local_pos (camera-independent)
// instead of the old world-position reconstruction (camera-dependent) -
// basis_x/basis_z are still pushed every frame by clouds_layer.gd from
// rig.basis, same projection this project uses to rotate the real terrain
// (voxel_hover_camera_4d.gd's right-drag handler) and for ana_offset
// elsewhere (bearing_utility_4d.gd), just sourced from a value that has no
// camera dependency this time.

instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform sampler2D noise_volume_atlas : source_color, hint_default_white;
// Ours: ONE-OFF isolation test (debug_mode 8) - an ordinary, single-tile,
// properly-mipmapped 2D texture, sampled with normal automatic LOD
// selection (texture(), NOT textureLod(...,0.0)) - to separate how much of
// the visual severity at extreme rotation comes from the noise ATLAS's own
// known-corrupted mip chain (blends unrelated neighboring tiles above LOD
// 0, see sample_slice's own comment) versus the geometric mix_weight
// singularity itself, which is present regardless of what's sampled.
uniform sampler2D debug_single_tile_noise : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform float atlas_cols = 8.0;
uniform float atlas_rows = 6.0;
uniform float depth = 48.0; // Must match the atlas bake's DEPTH (ATLAS_COLS * ATLAS_ROWS).
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float coverage = 0.45; // Higher = more of the surface covered by cloud.
uniform float softness = 0.35; // Higher = softer, more feathered edges.
uniform vec2 drift_speed_a = vec2(0.03, 0.01); // Slow idle motion, independent of rotation.
uniform vec2 drift_speed_b = vec2(-0.015, 0.022);
uniform float uv_scale = 0.06; // World-space UV tiling - smaller = bigger cloud blobs.

uniform float leak_scale = 0.06; // Depth (rotated.w) local-units -> volume depth-slices.

// Pushed every frame by clouds_layer.gd - see this shader's own header.
uniform vec4 basis_x = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 basis_z = vec4(0.0, 0.0, 1.0, 0.0);

// Debugging only. 0 = normal rendering. 1 = raw local_pos.xz as color.
// 2 = rotated.xz (after the basis transform) as color. 3 = final wrapped
// tile UV as color. 4 = raw single-layer noise sample as grayscale.
uniform int debug_mode = 0;

// Alpha-suppression attempt at the near-degenerate-crossing banding - see
// this shader's own git history for the full root-cause investigation.
// Unlike the earlier color/position-regularization attempt (which blended
// the SAMPLED coordinate toward a fixed local weight and just traded one
// visible artifact for another, since 0.5 in one tetrahedron's own
// parametrization isn't the same physical point as 0.5 in a neighbor's),
// this leaves local_pos completely untouched and instead fades the
// material's own ALPHA toward 0 as the same degeneracy measure increases -
// sidesteps the "what's a valid shared reference point" problem entirely,
// since making something transparent doesn't require agreement with a
// neighbor about WHERE it should have sampled from. Confirmed this keeps
// the "smooth fade, no new pattern SHAPE" property the color/position
// attempt lacked, at every threshold and rotation angle tested.
//
// SUPERSEDED metric, see w_gap's own computation in vertex() for the
// CURRENT one - kept this paragraph for the record since the number this
// threshold is compared against changed meaning mid-investigation.
// Originally this compared directly against the raw crossing-edge gap
// |w1-w2|, and calibration render tests found NO single such threshold
// was both "fixes the worst case" and "zero cost elsewhere": a headless
// numeric sweep found the fraction of crossing edges below any given gap
// threshold did NOT correlate with visible severity (more small-gap edges
// existed at a visually CLEAN 45-degree rotation than at the visibly
// banded 80-degree one), because raw local-space gap size alone doesn't
// account for a triangle's actual screen-space prominence.
//
// Now compares against `sensitivity = edge_length / |w1-w2|` instead (see
// vertex()) - a genuinely better-separated signal, confirmed via a
// headless sweep across 0-88 degrees: max sensitivity across the whole
// mesh stayed at 1.4-6.8 at identity/45 degrees (both confirmed visually
// clean throughout this investigation), versus 37-821 at 80-88 degrees
// (both confirmed visually banded) - unlike the old metric, this one
// actually separates the known-clean and known-banded cases.
//
// 12.0 is a render-calibrated value, not just a numerically-derived one:
// direct crop-level renders found the 45-degree case stays completely
// clean up to ~10-11 (a mild version of the old mesh-grid cost starts
// appearing by 8), while 12-18 all gave similar, real improvement at the
// 88-degree worst case (noticeably softer/fainter banding than the
// previous gap-based metric ever achieved at any threshold) - 12.0 sits
// with comfortable margin below the clean-case cost onset while still in
// the useful range for the worst case. See
// CLOUDS_BANDING_TECHNICAL_SUMMARY.md for the full sweep data.
//
// Confirmed safe at identity rotation regardless of threshold: the +-W
// cells this whole bug traces back to provably cannot cross at all there
// (see technical summary), so there is nothing for this measure to ever
// flag in the most common viewing state.
uniform float degeneracy_threshold = 12.0;

// A/B testing only, see this shader's git history: true = old naive
// (position1.w - position2.w) denominator, false = the numerically-stable
// reformulation below. Confirmed via crop-level before/after renders that
// this reformulation changes NOTHING visible - the banding is byte-for-byte
// as severe either way. That's a real, useful negative result: it rules out
// GPU float32 catastrophic cancellation in the (w1-w2) computation as the
// cause, confirming the sensitivity is a genuine property of the true
// mathematical mix_weight formula (see its own derivative,
// d(mix_weight)/dw1 = -w2/(w1-w2)^2, which diverges as (w1-w2)->0
// regardless of how precisely w1/w2 themselves are computed) rather than a
// numerical-precision implementation bug. Kept in for the record, not
// because it does anything - see CLOUDS_BANDING_TECHNICAL_SUMMARY.md.
uniform bool debug_use_naive_mix_weight = false;

// Ours: the engine-level fix proposed in CLOUDS_BANDING_ENGINE_FIX_PROPOSAL.md,
// applied here too since this shader reimplements the crossing-point vertex()
// logic itself rather than using the engine's default cross-section shader
// (needed for the raw local_pos varying used in texture sampling - see this
// shader's own header). Regularizes the mix_weight denominator relative to
// the crossing edge's own local-space length instead of a fixed absolute
// constant - see tetra_cross_section_shader.glsl's own copy of this same
// fix for the full derivation/rationale. Testing this directly on clouds
// (the confirmed reproducer of the banding bug) validates the fix before/
// alongside the engine's own default-shader copy.
//
// Defaults to OFF: rendered testing (see CLOUDS_BANDING_ENGINE_FIX_PROPOSAL.md's
// "Testing plan results" section) found this clamp does not reduce the
// grazing-angle banding it targets, and introduces a new, worse, sawtooth-
// shaped visual defect at every RELATIVE_EPSILON value tried - confirmed via
// direct same-crop labeled renders at 45/80/88 degrees, not just the numeric
// metric. Kept in the shader (toggle-able) as tested infrastructure for a
// future, better-behaved version of this idea, not as an active fix.
uniform bool enable_relative_epsilon_fix = false;
uniform float relative_epsilon = 0.03;

// Blur-based de-aliasing (see sample_slice_blurred's own comment) - the
// SHIPPED primary mitigation. Of the three mechanisms tried (alpha
// suppression, this, and cell_center_fallback below), this had the
// gentlest moderate-rotation cost curve at a threshold strong enough to
// meaningfully soften the worst case - see CLOUDS_BANDING_TECHNICAL_SUMMARY.md
// for the full comparative calibration. 0.12 is the calibrated value: real,
// visible softening of the 80-88 degree banding's sharpness/contrast
// confirmed via crop-level before/after renders, with only a mild,
// easy-to-miss softening at moderate (~45 degree) rotations that were
// previously clean - the best trade-off found, not a free fix.
uniform bool enable_blur = true;
uniform float max_blur_radius = 0.12;
// Alpha suppression (the FIRST attempt - see w_degeneracy's own comment)
// kept available for A/B comparison, but OFF by default: confirmed via
// direct crop-level testing that COMBINING it with blur made the
// moderate-rotation cost WORSE, not better (both mechanisms reveal the
// same underlying mesh sub-cube grid, and stacking them compounds it
// rather than each covering the other's gap) - a real, useful negative
// result, not an oversight.
uniform bool enable_alpha_suppression = false;

varying vec4 local_pos;
varying float w_degeneracy;
varying float w_gap;

// --- Everything below to the end of vertex() is copied verbatim from
// tetra_cross_section_shader.glsl - see this shader's own header. ---

const int TETRAHEDRON_EDGE_TO_VERTEX_MAP[] = {
	0, 1,
	0, 2,
	0, 3,
	1, 2,
	1, 3,
	2, 3
};
const int CROSS_SECTION_LOOKUP[] = {
	-1, -1, -1, -1, -1, -1,
	0, 1, 2, -1, -1, -1,
	0, 4, 3, -1, -1, -1,
	2, 4, 1, 3, 1, 4,
	1, 3, 5, -1, -1, -1,
	0, 3, 2, 5, 2, 3,
	1, 0, 5, 4, 5, 0,
	2, 4, 5, -1, -1, -1,
	2, 5, 4, -1, -1, -1,
	1, 5, 0, 4, 0, 5,
	0, 2, 3, 3, 2, 5,
	1, 5, 3, -1, -1, -1,
	2, 1, 4, 4, 1, 3,
	0, 3, 4, -1, -1, -1,
	0, 2, 1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1
};

int get_face_lookup_index(float w1, float w2, float w3, float w4, int vertex_id) {
	int negative1 = w1 < 0.0 ? 1 : 0;
	int negative2 = w2 < 0.0 ? 2 : 0;
	int negative3 = w3 < 0.0 ? 4 : 0;
	int negative4 = w4 < 0.0 ? 8 : 0;
	int lookup_index = negative1 + negative2 + negative3 + negative4;
	return (lookup_index * 6) + vertex_id - (vertex_id % 3);
}

// Ours: identical to tetra_cross_section_shader.glsl's own copy - see
// enable_relative_epsilon_fix's own comment above and that file for the full
// derivation. Not using sign() deliberately: sign(0.0) is 0.0, which would
// zero out the clamp in exactly the case (an exactly-degenerate edge) where
// clamping matters most.
float regularized_diff(float raw_diff, float edge_length) {
	if (!enable_relative_epsilon_fix) {
		return raw_diff;
	}
	float min_denominator = edge_length * relative_epsilon;
	if (abs(raw_diff) < min_denominator) {
		return (raw_diff < 0.0 ? -1.0 : 1.0) * min_denominator;
	}
	return raw_diff;
}

void vertex() {
	mat4 modelview_basis = mat4(modelview_basis_x, modelview_basis_y, modelview_basis_z, modelview_basis_w);

	// Ours: kept as a separate array (not just CUSTOM0-3 inline) so it can
	// be reused below for the numerically-stable mix_weight denominator,
	// not just for local_pos sampling.
	vec4 local_verts[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };

	vec4 verts[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	verts[0] = (modelview_basis * verts[0]) + modelview_origin;
	verts[1] = (modelview_basis * verts[1]) + modelview_origin;
	verts[2] = (modelview_basis * verts[2]) + modelview_origin;
	verts[3] = (modelview_basis * verts[3]) + modelview_origin;

	int vertex_id = int(VERTEX.x);
	int face = get_face_lookup_index(verts[0].w, verts[1].w, verts[2].w, verts[3].w, vertex_id);
	if (CROSS_SECTION_LOOKUP[face] == -1) {
		// This vertex is unused, cull.
		POSITION = vec4(0.0, 0.0, CLIP_SPACE_FAR, 1.0);
	} else {
		int position_edge = CROSS_SECTION_LOOKUP[face + (vertex_id % 3)];
		int edge_vert1 = TETRAHEDRON_EDGE_TO_VERTEX_MAP[position_edge * 2];
		int edge_vert2 = TETRAHEDRON_EDGE_TO_VERTEX_MAP[(position_edge * 2) + 1];
		vec4 position1 = verts[edge_vert1];
		vec4 position2 = verts[edge_vert2];

		// Ours: the naive denominator (position1.w - position2.w) subtracts
		// two INDEPENDENTLY modelview-transformed w-values, each a sum of
		// terms up to half-extent magnitude (tens of units) - computed in
		// GPU float32 regardless of this (double-precision-real_t) engine
		// build, since instance uniforms and vertex attributes are plain
		// vec4/float on the GPU. When a cell has JUST started crossing w=0
		// (this shader's whole banding investigation - see git history),
		// both w-values are independently near zero, so this subtraction is
		// a textbook catastrophic-cancellation setup: two large-ish,
		// independently-rounded sums, whose true difference is tiny.
		// Reformulated to transform the LOCAL-space corner difference
		// directly instead: (local_vert1 - local_vert2) is small (bounded by
		// one tetrahedron's own edge length, not half-extent), so summing
		// modelview_basis's contribution to its w-component is well-
		// conditioned throughout - mathematically identical result
		// (modelview is linear, so basis*(a-b) == basis*a - basis*b exactly
		// in infinite precision), just computed via a path that avoids
		// forcing the GPU to represent-then-cancel two much larger
		// intermediate values first.
		float naive_diff_w = position1.w - position2.w;
		float stable_diff_w = (modelview_basis * (local_verts[edge_vert1] - local_verts[edge_vert2])).w;
		float diff_w = debug_use_naive_mix_weight ? naive_diff_w : stable_diff_w;

		// Ours: the engine-fix proposal's regularization, applied here - see
		// enable_relative_epsilon_fix's own comment above. edge_length is
		// computed once here and reused below for the sensitivity metric
		// (previously computed twice).
		float edge_length = length(local_verts[edge_vert1] - local_verts[edge_vert2]);
		float safe_diff_w = regularized_diff(diff_w, edge_length);

		float mix_weight = position1.w / safe_diff_w;
		vec4 position = mix(position1, position2, mix_weight);
		// Vertex is view space and used for lighting, position is clip space and used for rasterizing.
		VERTEX = position.xyz;
		POSITION = PROJECTION_MATRIX * vec4(position.xyz, 1.0);

		// Ours: interpolate the RAW local corners (not modelview-transformed)
		// with the same mix_weight - see this shader's own header for why.
		// UNCHANGED from the engine's own approach - no regularization of
		// the sampled coordinate itself, see the degeneracy_threshold
		// uniform's own comment for why.
		local_pos = mix(local_verts[edge_vert1], local_verts[edge_vert2], mix_weight);

		// Ours: the degeneracy TRIGGER signal - see degeneracy_threshold's own
		// comment for the full history of why the earlier version of this
		// (the raw crossing-edge gap |w1-w2| alone) was confirmed, via a
		// headless numeric sweep, to NOT predict visual severity: more
		// small-gap edges existed at a visually CLEAN 45-degree rotation
		// than at the visibly-banded 80-degree one, because a small gap
		// alone doesn't say how far local_pos would actually swing if that
		// gap shrinks further - a short edge with a small gap barely moves
		// local_pos at all when its mix_weight shifts; a long edge with the
		// same small gap swings by a lot (local_pos = mix(v1, v2,
		// mix_weight), so d(local_pos)/d(mix_weight) = v2-v1, the edge's own
		// vector - a small mix_weight perturbation on a LONG edge produces a
		// LARGE local_pos change, regardless of how small the w-gap that
		// caused it was).
		//
		// This reformulation multiplies the edge's own local-space LENGTH
		// into the signal: sensitivity = edge_length / |w1-w2| directly
		// estimates the magnitude local_pos could swing by per unit of
		// w-perturbation (since d(mix_weight)/dw ~ 1/(w1-w2), chain-ruled
		// through d(local_pos)/d(mix_weight) = edge vector). Confirmed via a
		// headless numeric sweep (angles 0-88 degrees) that this is a much
		// cleaner discriminator than the raw gap: max sensitivity across
		// the whole mesh stayed near 1-7 at identity/45 degrees (both
		// confirmed visually clean throughout this whole investigation),
		// climbing to 37 at 80 degrees and 821 at 88 degrees (both
		// confirmed visually banded) - a monotonic-at-the-verified-points
		// separation the old metric never had.
		float sensitivity = edge_length / max(abs(diff_w), 0.0001);
		w_degeneracy = smoothstep(0.0, degeneracy_threshold, sensitivity);
		w_gap = sensitivity;
	}
}

// --- Ours from here on. ---

// Samples one atlas tile (slice index, wrapped) at a local tile-space UV
// (also wrapped manually via fract - the atlas has no hardware wrap, since
// that would wrap the whole atlas image rather than each tile).
float sample_slice(vec2 local_uv, float slice) {
	float wrapped_slice = mod(slice, depth);
	float col = mod(wrapped_slice, atlas_cols);
	float row = floor(wrapped_slice / atlas_cols);
	vec2 tile_origin = vec2(col, row) / vec2(atlas_cols, atlas_rows);
	vec2 wrapped_uv = fract(local_uv) / vec2(atlas_cols, atlas_rows);
	// Forced to LOD 0 deliberately: mipmaps are enabled on this texture
	// resource by default, but they were generated by downsampling the
	// WHOLE packed atlas image uniformly, with no idea it's 48 independent
	// tiles - every mip above 0 already has neighboring, unrelated noise
	// tiles permanently blended across their shared boundaries. Confirmed
	// this session (via a forced-LOD-0 test) that this specific texture's
	// mip corruption was NOT the cause of the grazing-angle banding
	// artifact - but the corruption is still real and would eventually
	// bite under genuine heavy minification (e.g. viewing clouds from very
	// far away), so LOD 0 stays forced as a real, if partial, safeguard.
	return textureLod(noise_volume_atlas, tile_origin + wrapped_uv, 0.0).r;
}

// Ours: manual ring-tap box blur of a single slice, radius in the SAME
// pre-wrap tile-UV units as local_uv (0..1 spans one tile). Used to
// deliberately de-alias the near-degenerate-crossing region (see
// w_degeneracy's own comment) as a genuine anti-aliasing response instead
// of a transparency fade - see this shader's git history for why alpha
// suppression alone was a real but incomplete fix (it dims the pattern
// without removing its high-frequency structure, since a whole banded
// region tends to share a similarly-small w-gap, so a uniform per-edge
// alpha fade scales the WHOLE region down together rather than smoothing
// it out). This exists specifically BECAUSE the standard hardware fix for
// exactly this situation - let dFdx/dFdy-driven mipmap LOD selection blur
// undersampled detail automatically - was confirmed not to engage here
// (derivatives measured low despite real banding), and separately this
// atlas's own mip chain is known-corrupted across tile boundaries (see
// sample_slice's LOD-0 comment), so we can't just raise textureLod's lod
// argument either - taps must stay within ONE tile, which fract-wrapping a
// manual offset (rather than relying on hardware LOD/mip) gives us.
float sample_slice_blurred(vec2 local_uv, float slice, float radius) {
	float base = sample_slice(local_uv, slice);
	if (radius <= 0.0005) {
		return base;
	}
	const int TAPS = 8;
	float total = base;
	for (int i = 0; i < TAPS; i++) {
		float angle = (float(i) / float(TAPS)) * 6.28318530718;
		vec2 offset = vec2(cos(angle), sin(angle)) * radius;
		total += sample_slice(local_uv + offset, slice);
	}
	return total / float(TAPS + 1);
}

// Blends the two slices nearest w (the volume's "w" axis is only baked at
// integer slice steps - this is what makes the visible pattern morph
// smoothly through non-integer w instead of popping between slices).
float sample_volume(vec2 local_uv, float w, float blur_radius) {
	float w_wrapped = mod(w, depth);
	float slice0 = floor(w_wrapped);
	float slice1 = mod(slice0 + 1.0, depth);
	float blend = fract(w_wrapped);
	return mix(sample_slice_blurred(local_uv, slice0, blur_radius), sample_slice_blurred(local_uv, slice1, blur_radius), blend);
}

// Ours: as w_degeneracy rises, blend the sampling coordinate toward this
// tetrahedron's own sub-cube CENTER (box-local X/Z, packed into the mesh's
// UV attribute by SubdividedBoxTetraMesh4D.build() - see that function's
// own comment) instead of its unstable mix_weight-interpolated corner.
// Unlike the EARLIER, failed color/position regularization attempt (fading
// toward a fixed local parametric weight of 0.5 - see this shader's git
// history), a cell center is a genuinely SHARED, continuous reference: all
// 5 tetrahedra in one sub-cube, and by extension every crossing edge
// inside it, agree on the exact same point, so a whole near-degenerate
// region converges toward one coherent value instead of each tetrahedron
// independently computing its own (wildly different, since that's the
// whole mechanism behind the banding) unstable answer. The trade-off:
// pushed all the way to w_degeneracy=1, a badly-behaved region reads as a
// coarse, blocky mosaic (one flat-ish patch per sub-cube) rather than a
// smooth gradient - a real cost, but a stable and non-repeating one,
// unlike the mesh-grid moire the blur-radius approach produces once its
// radius exceeds one tile.
// OFF by default - confirmed via calibration sweep (see
// CLOUDS_BANDING_TECHNICAL_SUMMARY.md) that this mechanism has the WORST
// cost curve of the three tried: its moderate-rotation cost (a sharp,
// prominent mesh-grid diamond pattern) ramps up to full severity by
// roughly the SAME threshold where it barely starts helping the worst
// case, unlike blur's much more gradual ramp - there is no usable
// threshold where this helps 80-88 degrees meaningfully without already
// showing the full 45-degree cost. Kept in (not deleted) because the
// underlying idea - a genuinely shared, continuous per-cell reference
// point instead of an arbitrary local one - is real infrastructure (the
// simplex_cell_texture_map plumbing in SubdividedBoxTetraMesh4D.build())
// that a future, better-targeted trigger signal could still use.
uniform bool enable_cell_center_fallback = false;
// Separately tunable from degeneracy_threshold (used for alpha/blur): the
// cell-center blend is a much stronger visual change per unit of
// degeneracy than dimming or blurring, so calibration found it needs its
// own, much stricter threshold - see this shader's git history for the
// calibration sweep - or it visibly reveals the mesh's own sub-cube grid
// at moderate rotations that were previously clean. NOT recalibrated
// against the newer sensitivity-based w_gap (see vertex()) since this
// mechanism is disabled by default anyway - if re-enabling this, recheck
// this value against fresh render tests rather than trusting it as-is.
uniform float cell_center_threshold = 20.0;

void fragment() {
	vec4 rotated = local_pos.x * basis_x + local_pos.z * basis_z;
	float cell_center_blend = smoothstep(0.0, cell_center_threshold, w_gap);
	if (enable_cell_center_fallback && cell_center_blend > 0.0005) {
		vec4 stable_local = vec4(UV.x, local_pos.y, UV.y, local_pos.w);
		vec4 rotated_stable = stable_local.x * basis_x + stable_local.z * basis_z;
		rotated = mix(rotated, rotated_stable, cell_center_blend);
	}
	vec2 local_uv = rotated.xz * uv_scale;

	if (debug_mode == 1) {
		ALBEDO = vec3(local_pos.x * 0.01 + 0.5, local_pos.z * 0.01 + 0.5, 0.0);
		ALPHA = 1.0;
	} else if (debug_mode == 2) {
		ALBEDO = vec3(rotated.x * 0.01 + 0.5, rotated.z * 0.01 + 0.5, 0.0);
		ALPHA = 1.0;
	} else if (debug_mode == 3) {
		ALBEDO = vec3(fract(local_uv), 0.0);
		ALPHA = 1.0;
	} else if (debug_mode == 4) {
		ALBEDO = vec3(sample_slice(local_uv, 0.0));
		ALPHA = 1.0;
	} else if (debug_mode == 5) {
		// Direct view of the degeneracy factor itself (white = fully
		// degenerate, black = untouched) - confirms it targets the same
		// region the color-fade attempt did before judging the visual
		// result.
		ALBEDO = vec3(w_degeneracy);
		ALPHA = 1.0;
	} else if (debug_mode == 6) {
		// Ours: a fine-scale checkerboard of local_pos ALONE, with NO noise
		// texture involved at all - tests whether the raw sampling
		// coordinate (and therefore, by the exact identity position =
		// modelview_basis*local_pos + modelview_origin, the TRUE rendered
		// geometry itself) is unstable at this rotation, independent of
		// anything about the clouds noise field. A fine checkerboard is
		// sensitive to small local_pos jumps in a way the coarse (0.01
		// scale) debug_mode 1 gradient is not.
		vec2 checker_uv = local_pos.xz * 0.125;
		float checker = mod(floor(checker_uv.x) + floor(checker_uv.y), 2.0);
		ALBEDO = vec3(checker);
		ALPHA = 1.0;
	} else if (debug_mode == 7) {
		// Ours: RE-TEST of the fwidth/derivative claim, with fresh eyes -
		// visualizes fwidth(local_uv) (the ACTUAL noise-sampling UV, same
		// one sample_volume uses) directly as brightness, log-scaled so
		// both small and large values are visible in one image. An earlier
		// pass claimed this reads "sub-1-texel-per-pixel" everywhere
		// despite visible banding, but a later direct check of the raw
		// local_pos coordinate (debug_mode 6) showed smooth, textbook
		// grazing-angle COMPRESSION at this same rotation - which SHOULD
		// produce a large fwidth, not a small one. Re-verifying directly
		// rather than trusting the earlier claim.
		vec2 duv = fwidth(local_uv);
		float mag = length(duv);
		ALBEDO = vec3(log2(1.0 + mag * 100.0) * 0.2);
		ALPHA = 1.0;
	} else if (debug_mode == 8) {
		// Ours: isolation test - see debug_single_tile_noise's own comment.
		// Deliberately uses texture() (automatic mipmap/anisotropic LOD
		// selection), not textureLod(...,0.0), and a single ordinary tile
		// (no atlas indexing, no flipbook depth blending) - isolates
		// whether PROPER texture filtering, on its own, meaningfully
		// reduces the severity at this same extreme rotation, independent
		// of the atlas's own known mip corruption and independent of any
        // of this shader's geometric mitigations (all bypassed here).
		ALBEDO = vec3(texture(debug_single_tile_noise, fract(local_uv)).r);
		ALPHA = 1.0;
	} else {
		float w_local = rotated.w * leak_scale;
		float blur_radius = enable_blur ? (w_degeneracy * max_blur_radius) : 0.0;
		// Layer B uses a steeper tilt (w_local * 1.3, not a fresh leak
		// term) so the two layers drift apart under rotation, not just
		// under time - reinforces the "volumetric" read.
		float sample_a = sample_volume(local_uv + TIME * drift_speed_a, w_local, blur_radius);
		float sample_b = sample_volume(local_uv * 1.7 + TIME * drift_speed_b, w_local * 1.3, blur_radius);
		float density = sample_a * 0.65 + sample_b * 0.35;

		float alpha = smoothstep(1.0 - coverage - softness, 1.0 - coverage + softness, density);
		if (enable_alpha_suppression) {
			alpha *= (1.0 - w_degeneracy);
		}
		ALBEDO = cloud_color.rgb;
		ALPHA = alpha * cloud_color.a;
	}
}
