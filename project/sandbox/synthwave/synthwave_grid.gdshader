// Synthwave ground grid - neon lines over a dark fill, fading to the line
// color near the horizon for that classic "glowing floor" look.
//
// Near-verbatim copy of engine/modules/4d/render/cross_section/
// tetra_cross_section_shader.glsl, same reasoning as skybox_sky.gdshader's
// own header comment: the vertex stage slices each tetrahedron to the
// current 3D cross-section and reimplementing it is not an option, so this
// is a copy with the fragment stage (and one extra varying) replaced.
//
// The extra varying, local_pos, carries the tetrahedron corners' own
// UNTRANSFORMED (pre modelview) positions, interpolated with the exact same
// mix_weight as the sliced vertex position itself. Since the ground mesh
// never moves or rotates, local_pos.xz IS stable world-ground-plane
// position - exactly what a camera-independent grid pattern needs. This
// sidesteps relying on BoxTetraMesh4D's own UV parameterization (unknown
// scale/orientation) entirely.
shader_type spatial;
render_mode skip_vertex_transform, unshaded;

instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform vec4 line_color : source_color = vec4(1.0, 0.15, 0.85, 1.0);
uniform vec4 fill_color : source_color = vec4(0.05, 0.02, 0.12, 1.0);
uniform float cell_size = 4.0;
// World-space half-width of each line, in the same units as cell_size - NOT
// a pixel count. An earlier version anti-aliased lines via fwidth(), which
// is the standard technique but blows up at grazing/near-camera angles
// (fwidth explodes as a world-space coordinate change maps to a huge
// per-pixel derivative), saturating the whole calculation to solid
// line-color - confirmed directly: a screenshot showed the entire
// foreground as flat magenta, no lines at all, not a subtle artifact. A
// fixed world-space width sidesteps that failure mode entirely (worst case
// at extreme distance is ordinary shimmer/aliasing, not a solid wrong color).
uniform float line_thickness = 0.06;
// Lines brighten toward this world-space distance from the origin and hold
// at full brightness beyond it - the "glowing toward the horizon" look.
uniform float glow_distance = 60.0;

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

vec3 slice_edge(vec4 v1, vec4 v2) {
	float mix_weight = v1.w / (v1.w - v2.w);
	return mix(v1, v2, mix_weight).xyz;
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

		int face_v1_edge = CROSS_SECTION_LOOKUP[face];
		int face_v2_edge = CROSS_SECTION_LOOKUP[face + 1];
		int face_v3_edge = CROSS_SECTION_LOOKUP[face + 2];
		vec3 face_v1 = slice_edge(verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v1_edge * 2]], verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v1_edge * 2 + 1]]);
		vec3 face_v2 = slice_edge(verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v2_edge * 2]], verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v2_edge * 2 + 1]]);
		vec3 face_v3 = slice_edge(verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v3_edge * 2]], verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v3_edge * 2 + 1]]);
		vec3 normal = normalize(cross(face_v3 - face_v1, face_v2 - face_v1));
		vec3 tangent = normalize(face_v2 - face_v1);
		vec3 binormal = normalize(cross(normal, tangent));
		NORMAL = normal;
		TANGENT = tangent;
		BINORMAL = binormal;
	}
}

void fragment() {
	// World-space distance to the nearest grid line along each axis (the
	// +0.5 phase shift puts the zero-distance point at integer cell
	// boundaries, not cell centers - fract(coord) alone is 0 AT the
	// boundary and 0.5 at the center, the opposite of "distance to line").
	vec2 coord = local_pos.xz / cell_size;
	vec2 dist_to_line = abs(fract(coord + 0.5) - 0.5) * cell_size;
	float d = min(dist_to_line.x, dist_to_line.y);
	float line_amount = 1.0 - smoothstep(line_thickness * 0.5, line_thickness * 1.5, d);

	float dist_from_origin = length(local_pos.xz);
	float glow_t = clamp(dist_from_origin / glow_distance, 0.0, 1.0);
	vec3 glowing_line_color = mix(line_color.rgb, line_color.rgb * 1.6, glow_t);

	ALBEDO = mix(fill_color.rgb, glowing_line_color, line_amount);
}
