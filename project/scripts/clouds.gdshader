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

varying vec4 local_pos;

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

void vertex() {
	mat4 modelview_basis = mat4(modelview_basis_x, modelview_basis_y, modelview_basis_z, modelview_basis_w);

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
		float mix_weight = position1.w / (position1.w - position2.w);
		vec4 position = mix(position1, position2, mix_weight);
		// Vertex is view space and used for lighting, position is clip space and used for rasterizing.
		VERTEX = position.xyz;
		POSITION = PROJECTION_MATRIX * vec4(position.xyz, 1.0);

		// Ours: interpolate the RAW local corners (not modelview-transformed)
		// with the same mix_weight - see this shader's own header for why.
		vec4 local_verts[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
		local_pos = mix(local_verts[edge_vert1], local_verts[edge_vert2], mix_weight);
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
	vec4 rotated = local_pos.x * basis_x + local_pos.z * basis_z;
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
	} else {
		float w_local = rotated.w * leak_scale;
		// Layer B uses a steeper tilt (w_local * 1.3, not a fresh leak
		// term) so the two layers drift apart under rotation, not just
		// under time - reinforces the "volumetric" read.
		float sample_a = sample_volume(local_uv + TIME * drift_speed_a, w_local);
		float sample_b = sample_volume(local_uv * 1.7 + TIME * drift_speed_b, w_local * 1.3);
		float density = sample_a * 0.65 + sample_b * 0.35;

		float alpha = smoothstep(1.0 - coverage - softness, 1.0 - coverage + softness, density);
		ALBEDO = cloud_color.rgb;
		ALPHA = alpha * cloud_color.a;
	}
}
