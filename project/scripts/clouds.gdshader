shader_type sky;

// Real sky shader (see ramon/IsoclynicSun/shaders/isoclynic_sun_sky.gdshader
// for this project's existing, proven WorldEnvironment/Sky/shader_type sky
// wiring) - NOT a mesh plane.
//
// Sampled directly from EYEDIR (the per-pixel view direction Godot's sky
// pass provides - a normalized vec3, always well-defined) rather than by
// projecting onto a ground plane at a fixed height. An earlier version DID
// project onto a plane (`t = (cloud_height - camera_y) / EYEDIR.y`, then
// sample at the hit point) - that has a genuine singularity as EYEDIR.y ->
// 0 (looking toward the horizon), where t blows up and the sampled position
// swings wildly per pixel; fading clouds out before that singularity
// helped but didn't fix it, since the blow-up starts well before the fade
// threshold and dominates most of the visible sky at any normal, non-
// steeply-downward camera angle. EYEDIR itself has no such singularity
// anywhere - it is a unit vector, always smooth and bounded - so using its
// own components directly as the sampling coordinate is both simpler and
// correct.
//
// Real 4D volumetric clouds were explicitly ruled out as too expensive;
// this is a cheap mock of that instead, see the conversation this was
// built in.
//
// noise_volume_atlas is a real 3-axis FBM noise volume - DEPTH separate 2D
// slices (see _bake_clouds_volume_runner.gd, now deleted after running)
// packed into one flipbook atlas image, ATLAS_COLS x ATLAS_ROWS tiles
// (manual 3D-texture-via-2D-atlas trick - there is no real sampler3D here).
//
// Sampled as a genuinely TILTED cross-section through the baked volume, not
// a single global depth. Treating EYEDIR as if it were a real 4D
// direction (w=0), its LOCAL direction (as seen through the CURRENT rotated
// 4D slice) is `rig.basis^T * EYEDIR` - i.e. `local = EYEDIR.x * rig_basis.x
// + EYEDIR.z * rig_basis.z` (the EYEDIR.y and w=0 terms drop out: xw/zw
// rotations never touch y so rig_basis.y is exactly (0,1,0,0)). Both the
// IN-PLANE coordinates (local.xz, the spatial noise UV) and the DEPTH
// coordinate (local.w, which slice of the volume) come out of this same
// transform - rig_basis.x/rig_basis.z are pushed wholesale as basis_x/
// basis_z every frame by clouds_layer.gd. This is the same rig_basis this
// project already uses to rotate the real terrain (see
// voxel_hover_camera_4d.gd's right-drag handler) and to compute ana_offset
// for real 4D points elsewhere (see bearing_utility_4d.gd) - same
// projection, applied to a direction that was never really 4D to begin
// with, the same way it was previously applied to a position.
//
// At zero rotation, basis_x=(1,0,0,0) and basis_z=(0,0,1,0) exactly, so
// local = (EYEDIR.x, 0, EYEDIR.z, 0) - the plain, untilted case.

uniform sampler2D noise_volume_atlas : source_color, hint_default_white;
uniform float atlas_cols = 8.0;
uniform float atlas_rows = 6.0;
uniform float depth = 48.0; // Must match the atlas bake's DEPTH (ATLAS_COLS * ATLAS_ROWS).
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float coverage = 0.45; // Higher = more of the sky filled with cloud.
uniform float softness = 0.35; // Higher = softer, more feathered edges.
uniform vec2 drift_speed_a = vec2(0.03, 0.01); // Slow idle motion, independent of rotation.
uniform vec2 drift_speed_b = vec2(-0.015, 0.022);
uniform float direction_scale = 2.0; // EYEDIR.xz (range +-1) -> UV tiling - bigger = smaller cloud blobs.

// Sky base colors (no real atmosphere/scattering model - just a vertical
// gradient so clouds have something other than flat black behind them).
uniform vec3 zenith_color : source_color = vec3(0.25, 0.45, 0.75);
uniform vec3 horizon_color : source_color = vec3(0.65, 0.75, 0.85);
uniform vec3 ground_color : source_color = vec3(0.18, 0.18, 0.2);

// Pushed every frame by clouds_layer.gd.
uniform vec4 basis_x = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 basis_z = vec4(0.0, 0.0, 1.0, 0.0);
uniform float leak_scale = 24.0; // Depth (local.w, range roughly +-1.4) world-units -> volume depth-slices.

// Debugging only - see the conversation this was built in. 0 = normal
// rendering. 1 = raw EYEDIR.xz as color (no basis transform, no texture -
// isolates whether EYEDIR itself is smooth). 2 = local.xz (after the basis
// transform, before *direction_scale or fract/texture) as color - isolates
// whether the basis transform introduces anything non-smooth. 3 = final
// wrapped tile UV (fract(local_uv)) as color - isolates the tiling/fract
// step. 4 = raw single-layer noise sample (no 2-layer combine, no
// smoothstep) as grayscale.
uniform int debug_mode = 0;

// Samples one atlas tile (slice index, wrapped) at a local tile-space UV
// (also wrapped manually via fract - the atlas has no hardware wrap, since
// that would wrap the whole atlas image rather than each tile).
float sample_slice(vec2 local_uv, float slice) {
	float wrapped_slice = mod(slice, depth);
	float col = mod(wrapped_slice, atlas_cols);
	float row = floor(wrapped_slice / atlas_cols);
	vec2 tile_origin = vec2(col, row) / vec2(atlas_cols, atlas_rows);
	vec2 wrapped_uv = fract(local_uv) / vec2(atlas_cols, atlas_rows);
	return texture(noise_volume_atlas, tile_origin + wrapped_uv).r;
}

// Blends the two slices nearest w (the volume's "w" axis is only baked at
// integer slice steps - this is what makes the visible pattern morph
// smoothly through non-integer w instead of popping between slices).
float sample_volume(vec2 local_uv, float w) {
	float w_wrapped = mod(w, depth);
	float slice0 = floor(w_wrapped);
	float slice1 = mod(slice0 + 1.0, depth);
	float blend = fract(w_wrapped);
	return mix(sample_slice(local_uv, slice0), sample_slice(local_uv, slice1), blend);
}

void sky() {
	vec4 local = EYEDIR.x * basis_x + EYEDIR.z * basis_z;
	vec2 local_uv = local.xz * direction_scale;

	if (debug_mode == 1) {
		COLOR = vec3(EYEDIR.x * 0.5 + 0.5, EYEDIR.z * 0.5 + 0.5, 0.0);
	} else if (debug_mode == 2) {
		COLOR = vec3(local.x * 0.5 + 0.5, local.z * 0.5 + 0.5, 0.0);
	} else if (debug_mode == 3) {
		COLOR = vec3(fract(local_uv), 0.0);
	} else if (debug_mode == 4) {
		COLOR = vec3(sample_slice(local_uv, 0.0));
	} else {
		vec3 base = mix(horizon_color, zenith_color, smoothstep(0.0, 0.9, max(EYEDIR.y, 0.0)));
		base = mix(ground_color, base, smoothstep(-0.05, 0.05, EYEDIR.y));

		float w_local = local.w * leak_scale;
		// Layer B uses a steeper tilt (w_local * 1.3, not a fresh leak
		// term) so the two layers drift apart under rotation, not just
		// under time - reinforces the "volumetric" read.
		float sample_a = sample_volume(local_uv + TIME * drift_speed_a, w_local);
		float sample_b = sample_volume(local_uv * 1.7 + TIME * drift_speed_b, w_local * 1.3);
		float density = sample_a * 0.65 + sample_b * 0.35;

		float alpha = smoothstep(1.0 - coverage - softness, 1.0 - coverage + softness, density);
		// Fade into ground_color below the horizon (clouds are an upper-
		// hemisphere-only effect) - reuses the same horizon band as the
		// base sky gradient above.
		alpha *= smoothstep(-0.05, 0.05, EYEDIR.y);

		COLOR = mix(base, cloud_color.rgb, alpha * cloud_color.a);
	}
}
