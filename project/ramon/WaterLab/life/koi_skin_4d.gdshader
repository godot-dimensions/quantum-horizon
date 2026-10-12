// WATER LAB: the lofted koi's skin (life/koi_loft_4d.gd), on the 4D renderer's cross-section.
//
// A fork of engine/modules/4d/render/3d/cross_section/tetra_cross_section_shader.glsl, its vertex stage
// copied from CreationLab/LabKit/shaders/lab_surface.gdshader (current as of godot-4d b288c8d, the last
// change to the engine's file, 30 Sept). The vertex stage must stay the engine's: it cuts each
// tetrahedron of the koi's 4D skin by your slice, and unpacks the corner UVWs from the bone weights.
// If the engine's vertex stage changes again, re-copy it.
//
// The deliberate deltas:
//   1. The colours are worked out per pixel (life/koi_pattern.gdshaderinc) from the point's place on
//      the 4D body: its UVW (s along the fish and which part it is, baked by koi_loft_4d.gd) and its
//      own 4D position in the piece's mesh (`local_pos`). The engine's own shader can only look a
//      colour up in one 3D texture by the UVW; per-vertex colour is never read by it
//      (follow_up/engine_gotchas.md).
//   2. `perpendicular_4d` inlined (the engine's #include does not resolve from res://).
//   3. `light()` carried across (the engine appends it in C++, so a fork never receives it), and a
//      wet highlight added to it: the 4D half vector between the light and your eye, against the
//      skin's 4D normal. Stronger on the metallic koi.

shader_type spatial;
render_mode skip_vertex_transform;

#include "res://ramon/WaterLab/life/koi_pattern.gdshaderinc"

instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler3D albedo_texture : hint_default_white, source_color;
uniform vec3 albedo_texture_map_offset = vec3(0.0);
uniform vec3 albedo_texture_map_scale = vec3(1.0);

// The koi: its variety (0-7), long fins (0 or 1), its own pattern (0-1), the showcase's fine detail.
uniform float variety = 0.0;
uniform float long_fins = 0.0;
uniform float pattern_seed = 0.37;
uniform float detail = 0.0;
// How strong the wet highlight is (the metallic koi get three times it).
uniform float sheen = 0.22;

varying vec3 uvw;
varying vec4 normal_4d;
varying vec4 local_pos;
varying float v_shine;

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

void fragment() {
	NORMAL = normalize(NORMAL);
	// The piece's mesh is the koi's rest pose moved along z only, so x, y and W are the rest pose's.
	float shine;
	vec3 col = koi_colour(variety, long_fins, pattern_seed, detail, uvw, vec3(local_pos.x, local_pos.y, local_pos.w), shine);
	v_shine = shine;
	ALBEDO = albedo.rgb * col;
}

void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	vec4 n4 = normalize(normal_4d);
	float normal_dot_light = max(dot(n4, light_direction_4d), 0.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * normal_dot_light;
	// Wet skin: a highlight where the 4D normal halves the light and your eye (your eye lies in the
	// slice, so its 4D direction has no W).
	vec4 half_4d = normalize(light_direction_4d + vec4(VIEW, 0.0));
	float spec = pow(max(dot(n4, half_4d), 0.0), mix(28.0, 60.0, v_shine)) * normal_dot_light;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * sheen * (1.0 + 2.0 * v_shine);
}
