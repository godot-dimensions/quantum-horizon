// BOTANY LAB, round 3 (follow_up/arboretum.md section 9, step 7): what every lofted flower and leaf in
// the flower room wears (flower_4d.gd builds them; flora_room_4d.gd sets the wind and the camera each
// render).
//
// A fork of Arboretum/shaders/botany_bark.gdshader (itself the engine's tetra_cross_section_shader.glsl
// as of godot-4d da3586b). THE SLICE IN THE VERTEX STAGE STAYS THE ENGINE'S. The deltas:
//
//   1. THE PLANT SWAYS, bending rather than tipping. Before the slice each corner is swung about the
//      plant's own foot in the plane of its up and the wind, by an angle that grows with the square of
//      its height: the stem curves, the bloom moves most. The wind comes in the camera's space each
//      render and is carried into the plant's own by the transpose of its modelview basis, so one shared
//      material serves every plant, however each is turned through W; each plant's phase comes from
//      where its foot stands in the world (the camera's frame back to the world, also each render).
//      A gust is a band along the wind, as in the trees (wind_4d.gd).
//   2. COLOUR from the flora texture (flower_4d.gd: u along a part, v out from its midrib, the part
//      kind in the third coordinate); thin parts (petals, leaves) lit through from behind, petals with a
//      little light of their own, so the room reads soft rather than plastic under shadowless lights.

shader_type spatial;
render_mode skip_vertex_transform;

instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler3D albedo_texture : hint_default_white, source_color, filter_linear;
uniform vec3 albedo_texture_map_offset = vec3(0.0);
uniform vec3 albedo_texture_map_scale = vec3(1.0);

// The wind in the camera's space (direction times m/s), and the camera's frame back to the world.
uniform vec4 wind_view = vec4(0.0);
uniform vec4 view_to_world_x = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 view_to_world_y = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 view_to_world_z = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 view_to_world_w = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 view_to_world_origin = vec4(0.0);
// The wind's direction in the world (unit), for the gust's front.
uniform vec4 wind_world_dir = vec4(1.0, 0.0, 0.0, 0.0);
uniform float wind_time = 0.0;
// Radians per metre of height squared at full pressure; the sway's share of it.
uniform float flex = 0.16;
uniform float sway = 0.55;
uniform float gust_front = -1000.0;
uniform float gust_width = 4.0;
uniform float gust_strength = 0.0;
uniform float wind_on = 1.0;
// Light of their own (petals), and through from behind (petals and leaves).
uniform float petal_glow = 0.1;
uniform float back_light = 0.45;
// The kinds (flower_4d.gd): 8 slices.
uniform float kinds = 8.0;

varying vec3 uvw;
varying vec4 normal_4d;
varying flat float v_kind;

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

float smooth_wave(float x) {
	float t = abs(fract(x + 0.5) * 2.0 - 1.0);
	return t * t * (3.0 - 2.0 * t) * 2.0 - 1.0;
}

float hash41(vec4 p) {
	return fract(sin(dot(p, vec4(12.9898, 78.233, 37.719, 59.381))) * 43758.5453);
}

// The corner `p` (the plant's own space, its foot at the origin, y up) bent with the wind: swung about
// the foot in the plane of up and the wind by an angle growing with height squared.
vec4 bent(vec4 p, vec4 wind_local, float phase, float gust) {
	if (wind_on <= 0.0) {
		return p;
	}
	vec4 wl = vec4(wind_local.x, 0.0, wind_local.z, wind_local.w);
	float speed = length(wl);
	if (speed < 0.0001) {
		return p;
	}
	vec4 v = wl / speed;
	float pressure = tanh(speed * speed * 0.03);
	float osc = 0.6 * smooth_wave(wind_time * 0.42 + phase) + 0.4 * smooth_wave(wind_time * 0.97 + phase * 1.7);
	float h = clamp(p.y, 0.0, 1.6);
	float a = flex * (pressure * (0.35 + sway * osc) + gust) * h * h;
	float du = p.y;
	float dv = dot(p, v);
	float ca = cos(a);
	float sa = sin(a);
	return p + vec4(0.0, du * ca - dv * sa - du, 0.0, 0.0) + v * (du * sa + dv * ca - dv);
}

void vertex() {
	mat4 modelview_basis_4d = mat4(modelview_basis_x, modelview_basis_y, modelview_basis_z, modelview_basis_w);

	vec3 uvw2 = vec3(UV2, VERTEX.y);
	vec4 uvw_offsets = (BONE_WEIGHTS * 2.0 - 1.0) * exp2(float(BONE_INDICES.x) - 64.0);
	vec3 uvws[] = { vec3(UV, uvw2.z + uvw_offsets.x), uvw2, vec3(NORMAL.xy / NORMAL.z, VERTEX.z), uvw2 + uvw_offsets.yzw };

	// The wind in the plant's own space: the modelview basis is a turn times a uniform scale, so its
	// inverse is its transpose over the scale squared.
	float s2 = max(dot(modelview_basis_x, modelview_basis_x), 1e-8);
	vec4 wind_local = (transpose(modelview_basis_4d) * wind_view) / s2;
	mat4 v2w = mat4(view_to_world_x, view_to_world_y, view_to_world_z, view_to_world_w);
	vec4 foot_world = v2w * modelview_origin + view_to_world_origin;
	float phase = hash41(floor(foot_world * 20.0)) * 6.2831853;
	float gust = gust_strength * exp(-pow((dot(foot_world, wind_world_dir) - gust_front) / max(gust_width, 0.01), 2.0));

	vec4 local_4d[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	vec4 verts_4d[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	for (int i = 0; i < 4; i++) {
		verts_4d[i] = modelview_basis_4d * bent(local_4d[i], wind_local, phase, gust) + modelview_origin;
	}
	v_kind = floor(uvws[0].z * kinds);

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
	vec3 col = texture(albedo_texture, uvw * albedo_texture_map_scale + albedo_texture_map_offset).rgb * albedo.rgb;
	ALBEDO = col;
	// Petals (2, 3) and the corona and bells' spots (7) glow a little.
	if (v_kind == 2.0 || v_kind == 3.0 || v_kind == 7.0) {
		EMISSION = col * petal_glow;
	}
}

void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	float ndl = dot(normalize(normal_4d), light_direction_4d);
	// Thin parts (leaves 1, petals 2 and 3, spots 7) take the light through them from behind.
	bool thin = v_kind == 1.0 || v_kind == 2.0 || v_kind == 3.0 || v_kind == 7.0;
	float through = thin ? back_light * max(-ndl, 0.0) : 0.0;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (max(ndl, 0.0) + through);
}
