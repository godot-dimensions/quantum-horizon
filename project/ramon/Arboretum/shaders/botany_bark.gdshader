// The Arboretum's tree surface: every tree in the room wears this, whatever built it (voxels, the
// engine's dual contouring, the loft), so the wind and the colours are one system.
//
// A fork of Arboretum/carried/LabKit/shaders/lab_surface.gdshader (itself a fork of the engine's
// tetra_cross_section_shader.glsl as of godot-4d da3586b). THE VERTEX STAGE MUST STAY THE ENGINE'S:
// it slices each tetrahedron to the current cross-section and unpacks the corner UVWs from the bone
// weights. The deliberate deltas:
//
//   1. WIND (Pivot Painter's idea, in 4D). Every corner carries its branch in its texture coordinate
//      (uvw = material / 255, (branch + 0.5) / 1024, how far along the branch). A float texture holds
//      every branch: its base (the pivot), its direction, its parent, how far along its parent it
//      starts, its flexibility, its own sway frequency and phase. Before the slice, each corner is
//      swung about its own branch's base, then its parent's, down to the trunk, in the plane of the
//      branch and the wind: a twig carries its branch's motion, which carries its limb's. Turning
//      about a point keeps lengths, so nothing stretches; corners that share a vertex share a branch,
//      so nothing cracks. A branch bends more toward its tip (the angle grows along it), and the wind
//      may have a W part, which swings branches out of your slice and back.
//   2. COLOUR BY MATERIAL: 1 wood, 2 leaf, 3 the skeleton (gold), 4 a ball of the loft (gold). Wood
//      darkens toward the root and each branch has its own slight tone; leaves vary by clump.
//   3. `perpendicular_4d` inlined and `light()` carried across, as in lab_surface.gdshader.

shader_type spatial;
render_mode skip_vertex_transform;

instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

// Bound by the engine's Material4D; unused here but declared so its updates find them.
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler3D albedo_texture : hint_default_white, source_color;
uniform vec3 albedo_texture_map_offset = vec3(0.0);
uniform vec3 albedo_texture_map_scale = vec3(1.0);

// Colours (botany_style.gd).
uniform vec4 bark_color : source_color = vec4(0.42, 0.36, 0.30, 1.0);
uniform vec4 bark_root : source_color = vec4(0.26, 0.22, 0.19, 1.0);
uniform vec4 leaf_color : source_color = vec4(0.31, 0.49, 0.16, 1.0);
uniform vec4 leaf_alt : source_color = vec4(0.40, 0.55, 0.20, 1.0);
uniform vec4 gold_color : source_color = vec4(1.0, 0.78, 0.30, 1.0);
// How tall the tree is (the root's darkening runs over its lower part), metres.
uniform float tree_height = 4.0;
// How much each branch's tone wanders, and the leaves' clump size for their two greens, metres.
uniform float branch_tone = 0.08;
uniform float clump_size = 0.6;
// The skeleton and balls glow a little, to read as overlays on the wood.
uniform float gold_glow = 0.35;

// The branches (botany/tree_pivots.gd): 4 texels a branch, one row each.
uniform sampler2D pivot_tex : filter_nearest, repeat_disable;
uniform int pivot_count = 0;
// The wind in the tree's own space: its direction times its speed, m/s (W included).
uniform vec4 wind = vec4(0.0);
// Seconds, shared by every tree in the room (wind_4d.gd).
uniform float wind_time = 0.0;
// How far a branch turns per unit of wind pressure, radians, and the sway's share of it.
uniform float bend = 0.05;
uniform float sway = 0.35;
// A gust: its front's place along the wind in the tree's space, its width and its strength.
uniform float gust_front = -1000.0;
uniform float gust_width = 3.0;
uniform float gust_strength = 0.0;
// Off: the tree stands still (the stories' first parts, a paused room).
uniform float wind_on = 1.0;

varying vec3 uvw;
varying vec4 normal_4d;
varying flat vec4 local_normal_4d;
varying vec4 local_pos;
varying flat float v_branch;

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

// A smoothed triangle wave (Crysis, GPU Gems 3 ch. 16): cheaper than sin and less regular.
float smooth_wave(float x) {
	float t = abs(fract(x + 0.5) * 2.0 - 1.0);
	return t * t * (3.0 - 2.0 * t) * 2.0 - 1.0;
}

// Swings `p` (the tree's own space) about the pivot `c` by `angle` in the plane of the unit vectors
// `u` (the branch) and `v` (the wind, square to it).
vec4 swing(vec4 p, vec4 c, vec4 u, vec4 v, float angle) {
	vec4 d = p - c;
	float du = dot(d, u);
	float dv = dot(d, v);
	float ca = cos(angle);
	float sa = sin(angle);
	return p + u * (du * ca - dv * sa - du) + v * (du * sa + dv * ca - dv);
}

// The whole hierarchy: the corner's own branch first (bent by how far along it the corner is), then
// each parent in turn (bent by where the child joins it).
vec4 wind_offset(vec4 p, int branch, float along) {
	if (wind_on <= 0.0 || pivot_count <= 0 || branch < 0 || branch >= pivot_count) {
		return p;
	}
	float speed = length(wind);
	vec4 wdir = speed > 0.0001 ? wind / speed : vec4(1.0, 0.0, 0.0, 0.0);
	int r = branch;
	float t = along;
	for (int k = 0; k < 10; k++) {
		if (r < 0 || r >= pivot_count) {
			break;
		}
		vec4 piv = texelFetch(pivot_tex, ivec2(0, r), 0);
		vec4 dir = texelFetch(pivot_tex, ivec2(1, r), 0);
		vec4 info = texelFetch(pivot_tex, ivec2(2, r), 0); // parent, flexibility, phase, frequency
		vec4 more = texelFetch(pivot_tex, ivec2(3, r), 0); // length, attach (along the parent), order, -
		vec4 wv = wdir - dir * dot(wdir, dir);
		float wl = length(wv);
		if (wl > 0.0001) {
			vec4 v = wv / wl;
			// Pressure goes with the speed squared and saturates, so a breeze barely moves a branch and
			// a gale lays it over but never flat.
			float pressure = tanh(speed * speed * 0.02) * wl;
			float g = gust_strength * exp(-pow((dot(piv, wdir) - gust_front) / max(gust_width, 0.01), 2.0));
			float osc = 0.6 * smooth_wave(wind_time * info.w + info.z) + 0.4 * smooth_wave(wind_time * info.w * 2.31 + info.z * 1.7);
			float a = info.y * bend * (pressure * (1.0 + sway * osc) + g);
			// A branch bends more toward its tip: a quarter of the angle at its base, all of it at the end.
			a *= 0.25 + 0.75 * clamp(t, 0.0, 1.0);
			p = swing(p, piv, dir, v, a);
		}
		t = more.y;
		r = int(info.x + 0.5) - 1;
	}
	return p;
}

void vertex() {
	mat4 modelview_basis_4d = mat4(modelview_basis_x, modelview_basis_y, modelview_basis_z, modelview_basis_w);

	vec3 uvw2 = vec3(UV2, VERTEX.y);
	vec4 uvw_offsets = (BONE_WEIGHTS * 2.0 - 1.0) * exp2(float(BONE_INDICES.x) - 64.0);
	vec3 uvws[] = { vec3(UV, uvw2.z + uvw_offsets.x), uvw2, vec3(NORMAL.xy / NORMAL.z, VERTEX.z), uvw2 + uvw_offsets.yzw };

	vec4 local_4d[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	vec4 moved[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	for (int i = 0; i < 4; i++) {
		int b = int(floor(uvws[i].y * 1024.0));
		moved[i] = wind_offset(local_4d[i], b, uvws[i].z);
	}
	vec4 verts_4d[] = { moved[0], moved[1], moved[2], moved[3] };
	verts_4d[0] = (modelview_basis_4d * verts_4d[0]) + modelview_origin;
	verts_4d[1] = (modelview_basis_4d * verts_4d[1]) + modelview_origin;
	verts_4d[2] = (modelview_basis_4d * verts_4d[2]) + modelview_origin;
	verts_4d[3] = (modelview_basis_4d * verts_4d[3]) + modelview_origin;

	vec4 ln = perpendicular_4d(local_4d[1] - local_4d[0], local_4d[2] - local_4d[0], local_4d[3] - local_4d[0]);
	local_normal_4d = length(ln) > 0.0 ? normalize(ln) : vec4(0.0, 1.0, 0.0, 0.0);
	v_branch = floor(uvws[0].y * 1024.0);

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

float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float hash41(vec4 p) {
	return fract(sin(dot(p, vec4(12.9898, 78.233, 37.719, 59.381))) * 43758.5453);
}

void fragment() {
	NORMAL = normalize(NORMAL);
	int material = int(round(uvw.x * 255.0));
	vec3 col;
	if (material == 2) {
		// Leaves: two greens by clump (a coarse cell of the tree's own space), a little per-cell hue.
		vec4 cell = floor(local_pos / max(clump_size, 0.05));
		float h = hash41(cell);
		col = mix(leaf_color.rgb, leaf_alt.rgb, step(0.5, h));
		col *= 0.9 + 0.2 * hash41(floor(local_pos / max(clump_size * 0.3, 0.02)));
	} else if (material == 3 || material == 4) {
		col = gold_color.rgb;
		EMISSION = gold_color.rgb * gold_glow;
	} else {
		// Wood: darker toward the root, each branch its own slight tone.
		float up = clamp(local_pos.y / max(tree_height * 0.45, 0.1), 0.0, 1.0);
		col = mix(bark_root.rgb, bark_color.rgb, up);
		col *= 1.0 + branch_tone * (hash11(v_branch + 1.0) * 2.0 - 1.0);
	}
	ALBEDO = col * albedo.rgb;
}

void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	float normal_dot_light = max(dot(normalize(normal_4d), light_direction_4d), 0.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * normal_dot_light;
}
