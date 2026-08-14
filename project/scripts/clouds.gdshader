shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

// Ordinary 3D plane geometry, deliberately outside the 4D Cross-section
// pipeline (same "doesn't need to be 4D" convention as the HUD) - no
// Node4D/tet-mesh cost. A semi-transparent LAYER sized to the terrain's own
// footprint and positioned at a fixed height above it (see clouds_layer.gd),
// meant to be looked at mostly from above - like a real cloud deck seen from
// a plane window, not a full sky dome. An earlier version of this WAS a sky
// shader (shader_type sky, sampled from EYEDIR) - correct for "clouds fill
// the whole sky as seen from ground level," wrong for this project's actual
// RTS-style hover camera looking mostly downward at a bounded terrain patch.
// Reverted to a mesh plane, but keeping every fix already made to the
// UNDERLYING sampling (seamless atlas, correct tilt math) - only the
// coordinate SOURCE changes back from EYEDIR to this plane's own world
// position.
//
// Real 4D volumetric clouds were explicitly ruled out as too expensive;
// this is a cheap mock of that instead, see the conversation this was
// built in.
//
// noise_volume_atlas is a real 3-axis FBM noise volume - DEPTH separate 2D
// slices (see _bake_clouds_volume_runner.gd, now deleted after running)
// packed into one flipbook atlas image, ATLAS_COLS x ATLAS_ROWS tiles
// (manual 3D-texture-via-2D-atlas trick - there is no real sampler3D here).
// Each tile is a genuinely SEAMLESS bake (Godot's own NoiseTexture2D
// seamless=true, then wrapped-translated per slice) - an earlier version
// baked each slice independently without seamlessness, invisible on a flat
// texture but catastrophic once sampled through a radial coordinate; not an
// issue here (world-position sampling was never radial), but the atlas
// asset itself is shared and already fixed, so no change needed there.
//
// Sampled as a genuinely TILTED cross-section through the baked volume, not
// a single global depth. A world point at (world_xz.x, cloud_height,
// world_xz.y, 0), if it were a real 4D point, would have LOCAL coordinates
// (as seen through the CURRENT rotated 4D slice) equal to `rig.basis^T *
// world` - i.e. `local = world.x * rig_basis.x + world.z * rig_basis.z`
// (the world.y and world.w terms drop out: xw/zw rotations never touch y so
// rig_basis.y is exactly (0,1,0,0), and this plane's world.w is always 0).
// Both the IN-PLANE coordinates (local.xz, the spatial noise UV) and the
// DEPTH coordinate (local.w, which slice of the volume) come out of this
// same transform - rig_basis.x/rig_basis.z are pushed wholesale as
// basis_x/basis_z every frame by clouds_layer.gd. This is the same
// rig_basis this project already uses to rotate the real terrain (see
// voxel_hover_camera_4d.gd's right-drag handler) and to compute ana_offset
// for real 4D points elsewhere (see bearing_utility_4d.gd) - same
// projection, just applied to a point that was never really 4D to begin
// with.
//
// At zero rotation, basis_x=(1,0,0,0) and basis_z=(0,0,1,0) exactly, so
// local = (world.x, 0, world.z, 0) - identical to the untilted case.

uniform sampler2D noise_volume_atlas : source_color, hint_default_white;
uniform float atlas_cols = 8.0;
uniform float atlas_rows = 6.0;
uniform float depth = 48.0; // Must match the atlas bake's DEPTH (ATLAS_COLS * ATLAS_ROWS).
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float coverage = 0.45; // Higher = more of the surface covered by cloud.
uniform float softness = 0.35; // Higher = softer, more feathered edges.
uniform vec2 drift_speed_a = vec2(0.03, 0.01); // Slow idle motion, independent of rotation.
uniform vec2 drift_speed_b = vec2(-0.015, 0.022);
uniform float uv_scale = 0.06; // World-space UV tiling - smaller = bigger cloud blobs.

// Pushed every frame by clouds_layer.gd - see this shader's own header for
// the derivation.
uniform vec4 basis_x = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 basis_z = vec4(0.0, 0.0, 1.0, 0.0);
uniform float leak_scale = 0.06; // Depth (local.w) world-units -> volume depth-slices.

// Radial fade centered on the deck's own XZ origin (always the terrain's
// center - see clouds_layer.gd), pushed every frame as half the current
// footprint. Without this, a wide, thin, horizontal plane viewed from a
// normal hover-camera distance/angle visually recedes into a smeared band
// near the horizon - technically still anchored to the terrain in world
// space (confirmed directly: moving the plane's position hides it exactly
// where expected), but reading as if it were glued to the screen/camera
// instead, since that smeared band barely shifts for ordinary orbit/zoom
// changes. Fading the coverage out before it reaches that smeared region
// keeps the VISIBLE cloud mass concentrated directly over the terrain,
// where it genuinely does shift and scale with camera changes.
uniform float coverage_radius = 24.0;
uniform float edge_fade_fraction = 0.35; // Fraction of coverage_radius the fade ramps over.

// View-angle fade - separate problem from coverage_radius above. A flat
// horizontal plane viewed near edge-on (a shallow/grazing camera angle,
// the normal RTS-hover-camera case looking somewhat toward the horizon
// rather than straight down) visually smears its far portion out to fill
// a huge span of screen space - the classic "infinite floor" perspective
// illusion, true of ANY finite flat plane viewed edge-on regardless of its
// actual bounded size (confirmed directly via an annotated screenshot: the
// deck's rendered extent tracked the screen/horizon, not any world-space
// boundary). coverage_radius's world-space fade can't fix this - a point
// can be well within coverage_radius and still be viewed almost edge-on if
// it's far from the camera in the "away" direction. Fading by how face-on
// the camera is looking at the plane (NORMAL vs VIEW, both view-space
// built-ins Godot already provides) fixes it in a way that's genuinely a
// property of the plane's OWN geometry relative to the viewer, not a
// camera-position hack - steep/top-down views show it fully, shallow/
// grazing views fade it out before the smear can dominate the frame.
uniform float view_fade_start = 0.55; // abs(dot(NORMAL, VIEW)) below this = fully faded.
uniform float view_fade_end = 0.7; // abs(dot(NORMAL, VIEW)) above this = fully visible.

// Debugging only - see the conversation this was built in. 0 = normal
// rendering. 1 = raw world_xz as color. 2 = local.xz (after the basis
// transform, before *uv_scale or fract/texture) as color. 3 = final wrapped
// tile UV (fract(local_uv)) as color. 4 = raw single-layer noise sample (no
// 2-layer combine, no smoothstep) as grayscale.
uniform int debug_mode = 0;

// VERTEX is object-space in vertex() - MODEL_MATRIX * VERTEX gives world
// space; pass it through explicitly rather than relying on render_mode
// world_vertex_coords (which would also change how VERTEX behaves for
// anything else added to this shader later).
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

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

void fragment() {
	vec4 local = world_xz.x * basis_x + world_xz.y * basis_z;
	vec2 local_uv = local.xz * uv_scale;

	if (debug_mode == 1) {
		ALBEDO = vec3(world_xz.x * 0.01 + 0.5, world_xz.y * 0.01 + 0.5, 0.0);
		ALPHA = 1.0;
	} else if (debug_mode == 2) {
		ALBEDO = vec3(local.x * 0.01 + 0.5, local.z * 0.01 + 0.5, 0.0);
		ALPHA = 1.0;
	} else if (debug_mode == 3) {
		ALBEDO = vec3(fract(local_uv), 0.0);
		ALPHA = 1.0;
	} else if (debug_mode == 4) {
		ALBEDO = vec3(sample_slice(local_uv, 0.0));
		ALPHA = 1.0;
	} else {
		float w_local = local.w * leak_scale;
		// Layer B uses a steeper tilt (w_local * 1.3, not a fresh leak
		// term) so the two layers drift apart under rotation, not just
		// under time - reinforces the "volumetric" read.
		float sample_a = sample_volume(local_uv + TIME * drift_speed_a, w_local);
		float sample_b = sample_volume(local_uv * 1.7 + TIME * drift_speed_b, w_local * 1.3);
		float density = sample_a * 0.65 + sample_b * 0.35;

		float alpha = smoothstep(1.0 - coverage - softness, 1.0 - coverage + softness, density);

		// See coverage_radius's own comment above for why this exists.
		float dist_from_center = length(world_xz);
		float edge_fade = 1.0 - smoothstep(
			coverage_radius * (1.0 - edge_fade_fraction), coverage_radius, dist_from_center);
		alpha *= edge_fade;

		// See view_fade_start/end's own comment above for why this exists.
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		alpha *= smoothstep(view_fade_start, view_fade_end, facing);

		ALBEDO = cloud_color.rgb;
		ALPHA = alpha * cloud_color.a;
	}
}
