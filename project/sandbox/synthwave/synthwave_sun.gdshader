// Synthwave sun disc - simple vertical gradient (bright yellow top fading to
// warm orange-pink bottom), same copy-the-cross-section-vertex-shader
// approach as synthwave_grid.gdshader/synthwave_sky.gdshader - see those
// files' own header comments for why reimplementing the vertex stage isn't
// an option.
shader_type spatial;
render_mode skip_vertex_transform, unshaded;

instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform vec4 top_color : source_color = vec4(1.0, 0.95, 0.4, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);
// local_pos is in the CylinderIcoMesh's own native (unscaled) space, not
// world units - the node's basis reorients native Z onto the rendered
// disc's local y (see synthwave_sky.gd's own comment, same reorientation
// sky.gd's sun disc uses), so this is that mesh's native round radius
// (matching sky.gd's own CYLINDER_NATIVE_ROUND_RADIUS), not a world-space size.
uniform float native_round_radius = 0.85065081;
// True world-up, re-expressed in this disc's own native x/z plane - same
// camera-rotation problem and same per-frame fix as synthwave_sky.gdshader's
// own local_up_dir (see that file's comment for the full reasoning); this
// disc is a rigid child of the camera too, so without this its gradient
// would visibly rotate as the player just looks up or down. Defaults to
// (0,1) so the shader still behaves sanely (matching the original
// local_pos.z-only behavior) before the script's first _process().
uniform vec2 native_up_dir = vec2(0.0, 1.0);

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

void fragment() {
	// native_up_dir's components already correspond to (native X, native Z)
	// - see synthwave_sky.gd's own comment on why no further basis-inversion
	// is needed (the shared round_scale factor cancels out of the direction).
	float t = clamp(dot(vec2(local_pos.x, local_pos.z), native_up_dir) / native_round_radius, -1.0, 1.0) * 0.5 + 0.5;
	ALBEDO = mix(bottom_color.rgb, top_color.rgb, t);
}
