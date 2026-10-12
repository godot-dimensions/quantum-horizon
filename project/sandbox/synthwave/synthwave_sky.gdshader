// Synthwave skybox shell - vertical gradient (dark near-black zenith through
// purple to a warm pink/orange horizon band) plus a sparse procedural
// starfield in the upper sky.
//
// Same copy-of-the-cross-section-vertex-shader approach as
// ramon/SkyBoxClouds/shaders/skybox_sky.gdshader, and for the identical two
// reasons stated in that file's own header: cull_disabled (viewed from
// inside a closed shell, winding can't be derived, so draw both faces) and
// no lighting term (the stock fragment stage's dot(normal,up) term would
// black out the zenith on an inward-facing shell). See that file for the
// full reasoning.
//
// local_pos carries each tetrahedron corner's own untransformed position,
// interpolated with the same mix_weight as the sliced vertex - since this
// shell is camera-parented and pinned at local (0,0,0,0) (see
// synthwave_sky.gd), local_pos IS the direction from the camera, with no
// extra transform needed.
shader_type spatial;
render_mode skip_vertex_transform, unshaded, cull_disabled;

instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform vec4 zenith_color : source_color = vec4(0.04, 0.02, 0.09, 1.0);
uniform vec4 upper_color : source_color = vec4(0.25, 0.06, 0.35, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.95, 0.25, 0.45, 1.0);
uniform vec4 lower_color : source_color = vec4(0.15, 0.03, 0.18, 1.0);
uniform float star_density = 300.0;
uniform float star_threshold = 0.9975;
// True world-up, re-expressed in this (camera-parented) shell's own native
// mesh frame - pushed fresh every frame by synthwave_sky.gd, since the
// shader has no other way to tell world orientation apart from the
// camera's current one. Using local_pos.y directly (an earlier version's
// bug, caught by an actual screenshot at two different camera pitches) is
// wrong for exactly that reason: this shell is a rigid child of the
// camera, so its own native Y axis rotates WITH the camera's pitch, making
// the horizon band appear to climb/drop as the player just looks up or
// down, with no actual world rotation involved. Defaults to plain world-up
// so the shader still behaves sanely before the script's first _process().
//
// Dotted against NORMALIZED local_pos (not raw local_pos - a second,
// separate bug an isolated-rotation diagnostic caught after the first fix:
// this shell is a BOX, not a sphere, so raw local_pos's magnitude and
// axis balance vary wildly by which face/edge/corner a fragment sits on,
// making the raw dot product swing non-monotonically as pitch changes even
// though the world-anchoring itself was already correct. Normalizing first
// makes this a true angular cosine, uniform across the whole shell).
uniform vec3 local_up_dir = vec3(0.0, 1.0, 0.0);
// The camera's own basis columns (where each of its local x/y/z axes
// currently points in world space) - lets the fragment shader reconstruct
// each fragment's TRUE WORLD direction (not just its elevation) for the
// starfield hash below. Without this, star_hash's input never left the
// camera's own rotating local frame, so the whole star pattern stayed
// glued to the same screen position no matter how the player looked around
// - confirmed directly (a live playtest report: "stars don't move at all"
// under both yaw and pitch, which a bare local_pos-based hash exactly
// predicts, since local_pos IS camera-local by construction).
uniform vec3 basis_x_dir = vec3(1.0, 0.0, 0.0);
uniform vec3 basis_y_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 basis_z_dir = vec3(0.0, 0.0, 1.0);

varying vec3 local_pos;

const int TETRAHEDRON_EDGE_TO_VERTEX_MAP[] = {
	0, 1,
	0, 2,
	0, 3,
	1, 2,
	1, 3,
	2, 3
};
const int CROSS_SECTION_LOOKUP[] = {
	-1, -1, -1, -1, -1, -1, // 0000
	0, 1, 2, -1, -1, -1, // 0001
	0, 4, 3, -1, -1, -1, // 0010
	2, 4, 1, 3, 1, 4, // 0011
	1, 3, 5, -1, -1, -1, // 0100
	0, 3, 2, 5, 2, 3, // 0101
	1, 0, 5, 4, 5, 0, // 0110
	2, 4, 5, -1, -1, -1, // 0111
	2, 5, 4, -1, -1, -1, // 1000
	1, 5, 0, 4, 0, 5, // 1001
	0, 2, 3, 3, 2, 5, // 1010
	1, 5, 3, -1, -1, -1, // 1011
	2, 1, 4, 4, 1, 3, // 1100
	0, 3, 4, -1, -1, -1, // 1101
	0, 2, 1, -1, -1, -1, // 1110
	-1, -1, -1, -1, -1, -1 // 1111
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

	vec4 local_verts[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	vec4 verts[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	verts[0] = (modelview_basis * verts[0]) + modelview_origin;
	verts[1] = (modelview_basis * verts[1]) + modelview_origin;
	verts[2] = (modelview_basis * verts[2]) + modelview_origin;
	verts[3] = (modelview_basis * verts[3]) + modelview_origin;

	int vertex_id = int(VERTEX.x);
	int face = get_face_lookup_index(verts[0].w, verts[1].w, verts[2].w, verts[3].w, vertex_id);
	if (CROSS_SECTION_LOOKUP[face] == -1) {
		POSITION = vec4(0.0, 0.0, CLIP_SPACE_FAR, 1.0);
	} else {
		int position_edge = CROSS_SECTION_LOOKUP[face + (vertex_id % 3)];
		int edge_vert1 = TETRAHEDRON_EDGE_TO_VERTEX_MAP[position_edge * 2];
		int edge_vert2 = TETRAHEDRON_EDGE_TO_VERTEX_MAP[(position_edge * 2) + 1];
		vec4 position1 = verts[edge_vert1];
		vec4 position2 = verts[edge_vert2];
		float mix_weight = position1.w / (position1.w - position2.w);
		vec4 position = mix(position1, position2, mix_weight);
		VERTEX = position.xyz;
		POSITION = PROJECTION_MATRIX * vec4(position.xyz, 1.0);

		local_pos = mix(local_verts[edge_vert1].xyz, local_verts[edge_vert2].xyz, mix_weight);
	}
}

float star_hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec3 dir = normalize(local_pos); // Camera-local direction of this fragment - stable across the whole shell regardless of box face/corner.
	float t = clamp(dot(dir, local_up_dir), -1.0, 1.0) * 0.5 + 0.5; // 0 = straight down, 0.5 = horizon, 1 = straight up.

	vec3 sky_color;
	if (t > 0.5) {
		sky_color = mix(horizon_color.rgb, mix(upper_color.rgb, zenith_color.rgb, smoothstep(0.35, 1.0, (t - 0.5) / 0.5)), smoothstep(0.0, 0.35, (t - 0.5) / 0.5));
	} else {
		sky_color = mix(lower_color.rgb, horizon_color.rgb, smoothstep(0.0, 1.0, t / 0.5));
	}

	// Sparse stars, only above the horizon, fading in just above it. Hashed
	// on the fragment's TRUE WORLD direction (reconstructed from the
	// camera's current basis), not the camera-local `dir` above - see
	// basis_x_dir's own comment on why that distinction is exactly what
	// makes the star pattern pan as the player looks around instead of
	// staying glued to the screen.
	vec3 world_dir = normalize(local_pos.x * basis_x_dir + local_pos.y * basis_y_dir + local_pos.z * basis_z_dir);
	float star_noise = star_hash(floor(world_dir * star_density));
	float star = step(star_threshold, star_noise) * smoothstep(0.52, 0.75, t);
	sky_color += vec3(star);

	ALBEDO = sky_color;
}
