// The Voxel Lab's grid view (G): a specimen's own colours, with every voxel's edges drawn on its
// faces, so the resolution of the engine's voxel world is visible on screen (and a cut's facets can be
// counted against it).
//
// A fork of engine/modules/4d/render/3d/cross_section/tetra_cross_section_shader.glsl AS OF
// godot-4d 5dd394c (4 Oct 2026; the vertex stage last changed in b288c8d, 30 Sept). The vertex stage
// is the lab kit's copy (CreationLab/LabKit/shaders/lab_surface.gdshader, carried), identical to the
// engine's; re-copy it if the engine's changes.
//
// The deltas:
//   1. ALBEDO is the engine's own (the palette texture at the cell's UVW, the material's colour),
//      then darkened along the lines where the fragment's position in the mesh crosses a whole voxel
//      on an axis lying along the surface (an axis the surface faces along draws no line). A chunk
//      mesh's positions are in voxels (its world is scaled to the voxel size), so whole numbers are
//      voxel edges.
//   2. `perpendicular_4d` inlined and `light()` carried across, as in the kit's fork.

shader_type spatial;
render_mode skip_vertex_transform;

instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler3D albedo_texture : hint_default_white, source_color;
uniform vec3 albedo_texture_map_offset = vec3(0.0);
uniform vec3 albedo_texture_map_scale = vec3(1.0);

// The lines: how dark, how wide (in voxels), and every how many voxels a stronger one.
uniform float line_strength = 0.55;
uniform float line_width = 0.06;
uniform float major_every = 8.0;
uniform float major_strength = 0.85;

varying vec3 uvw;
varying vec4 normal_4d;
varying flat vec4 local_normal_4d;
varying vec4 local_pos;

vec4 perpendicular_4d(vec4 a, vec4 b, vec4 c) {
	return vec4(
			-a.y * (b.z * c.w - b.w * c.z) + a.z * (b.y * c.w - b.w * c.y) - a.w * (b.y * c.z - b.z * c.y),
			+a.x * (b.z * c.w - b.w * c.z) - a.z * (b.x * c.w - b.w * c.x) + a.w * (b.x * c.z - b.z * c.x),
			-a.x * (b.y * c.w - b.w * c.y) + a.y * (b.x * c.w - b.w * c.x) - a.w * (b.x * c.y - b.y * c.x),
			+a.x * (b.y * c.z - b.z * c.y) - a.y * (b.x * c.z - b.z * c.x) + a.z * (b.x * c.y - b.y * c.x));
}

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
	mat4 modelview_basis_4d = mat4(modelview_basis_x, modelview_basis_y, modelview_basis_z, modelview_basis_w);

	vec4 local_4d[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	vec4 verts_4d[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	verts_4d[0] = (modelview_basis_4d * verts_4d[0]) + modelview_origin;
	verts_4d[1] = (modelview_basis_4d * verts_4d[1]) + modelview_origin;
	verts_4d[2] = (modelview_basis_4d * verts_4d[2]) + modelview_origin;
	verts_4d[3] = (modelview_basis_4d * verts_4d[3]) + modelview_origin;

	vec3 uvw2 = vec3(UV2, VERTEX.y);
	vec4 uvw_offsets = (BONE_WEIGHTS * 2.0 - 1.0) * exp2(float(BONE_INDICES.x) - 64.0);
	vec3 uvws[] = { vec3(UV, uvw2.z + uvw_offsets.x), uvw2, vec3(NORMAL.xy / NORMAL.z, VERTEX.z), uvw2 + uvw_offsets.yzw };

	vec4 ln = perpendicular_4d(local_4d[1] - local_4d[0], local_4d[2] - local_4d[0], local_4d[3] - local_4d[0]);
	local_normal_4d = length(ln) > 0.0 ? normalize(ln) : vec4(0.0, 1.0, 0.0, 0.0);

	int vertex_id = int(VERTEX.x);
	int face = get_face_lookup_index(verts_4d[0].w, verts_4d[1].w, verts_4d[2].w, verts_4d[3].w, vertex_id);
	normal_4d = vec4(0.0, 0.0, 1.0, 0.0);
	if (vertex_id >= 6 || CROSS_SECTION_LOOKUP[face] == -1) {
		POSITION = vec4(0.0, 0.0, CLIP_SPACE_FAR, 1.0);
	} else {
		int position_edge = CROSS_SECTION_LOOKUP[face + (vertex_id % 3)];
		int edge_vert1 = TETRAHEDRON_EDGE_TO_VERTEX_MAP[position_edge * 2];
		int edge_vert2 = TETRAHEDRON_EDGE_TO_VERTEX_MAP[(position_edge * 2) + 1];
		vec4 position1_4d = verts_4d[edge_vert1];
		vec4 position2_4d = verts_4d[edge_vert2];
		float mix_weight = position1_4d.w / (position1_4d.w - position2_4d.w);
		vec4 position_4d = mix(position1_4d, position2_4d, mix_weight);
		VERTEX = position_4d.xyz;
		POSITION = PROJECTION_MATRIX * vec4(position_4d.xyz, 1.0);

		uvw = mix(uvws[edge_vert1], uvws[edge_vert2], mix_weight);
		local_pos = mix(local_4d[edge_vert1], local_4d[edge_vert2], mix_weight);

		int face_v1_edge = CROSS_SECTION_LOOKUP[face];
		int face_v2_edge = CROSS_SECTION_LOOKUP[face + 1];
		int face_v3_edge = CROSS_SECTION_LOOKUP[face + 2];
		vec3 face_v1 = slice_edge(verts_4d[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v1_edge * 2]], verts_4d[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v1_edge * 2 + 1]]);
		vec3 face_v2 = slice_edge(verts_4d[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v2_edge * 2]], verts_4d[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v2_edge * 2 + 1]]);
		vec3 face_v3 = slice_edge(verts_4d[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v3_edge * 2]], verts_4d[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v3_edge * 2 + 1]]);
		vec3 normal = normalize(cross(face_v3 - face_v1, face_v2 - face_v1));
		vec4 cell_normal_4d = perpendicular_4d(verts_4d[1] - verts_4d[0], verts_4d[2] - verts_4d[0], verts_4d[3] - verts_4d[0]);
		float cell_normal_length = length(cell_normal_4d);
		if (cell_normal_length > 0.0) {
			cell_normal_4d /= cell_normal_length;
			if (dot(cell_normal_4d.xyz, normal) < 0.0) {
				cell_normal_4d = -cell_normal_4d;
			}
		} else {
			cell_normal_4d = vec4(normal, 0.0);
		}
		normal_4d = cell_normal_4d;
		vec3 tangent = normalize(face_v2 - face_v1);
		vec3 binormal = normalize(cross(normal, tangent));
		NORMAL = normal;
		TANGENT = tangent;
		BINORMAL = binormal;
	}
}

// How close `p` is to a whole voxel on each axis lying along the surface (normal `n`), as a line
// strength 0..1, sharpened by the screen-space rate of change so a line stays a line far away.
float voxel_lines(vec4 p, vec4 n, float every, float width) {
	vec4 q = p / every;
	vec4 d = abs(fract(q + 0.5) - 0.5) * every;
	vec4 fw = max(fwidth(p), vec4(1e-4));
	vec4 a = 1.0 - smoothstep(vec4(width), vec4(width) + fw * 1.5, d);
	vec4 along = clamp(1.0 - abs(n) * 1.15, 0.0, 1.0);
	a *= along * along;
	return max(max(a.x, a.y), max(a.z, a.w));
}

void fragment() {
	NORMAL = normalize(NORMAL);
	vec3 base = albedo.rgb * texture(albedo_texture, uvw * albedo_texture_map_scale + albedo_texture_map_offset).rgb;
	float minor = voxel_lines(local_pos, local_normal_4d, 1.0, line_width);
	float major = voxel_lines(local_pos, local_normal_4d, major_every, line_width * 1.6);
	float k = max(minor * line_strength, major * major_strength);
	ALBEDO = base * (1.0 - k);
}

void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	float normal_dot_light = max(dot(normalize(normal_4d), light_direction_4d), 0.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * normal_dot_light;
}
