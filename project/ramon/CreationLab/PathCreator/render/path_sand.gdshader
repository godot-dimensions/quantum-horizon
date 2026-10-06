// PathCreator: the sand under the pen's paths (6 Oct 2026), one thin flat 4D box per stretch or
// node, as path_mark.gdshader's boxes are; this shader is theirs for the sand alone.
//
//   a stretch   a strip as wide as the box, its two edges wavering on their own (noise along the
//               route's length, running on unbroken from stretch to stretch: `s0` + along)
//   a node      a round patch (`sand_round`), its rim wavering the same way round its circle
//
// SOFT, IRREGULAR, AND NO SEAMS (Ramon, 6 Oct: "lowres jittery pixel edges on paths, a no go. if
// you cant create a soft irregular edge, rather have it straight"). The edge is soft: over
// `sand_soft` metres the sand gives way to the ground under it, its colour worked out here as the
// pen paints it (the glow, `ground_mode`), so the fade lands on the real green and not a guess. The
// cross-section is opaque, so a soft edge drawn over another strip's sand would paint a dark seam
// where the two overlap; so each pixel also writes its DEPTH a hair further away the less sand it
// has: wherever boxes overlap, the one with the most sand at that pixel is the one in front, and
// the union of every strip and patch has one soft edge, its outer one. (Before this the edge was
// dithered in 5 cm grains, which read as jittery low-res pixels.)
//
// THE PEN'S SAND (Ramon: "path doesnt look like the sand color in the pen"): the yard's colour and
// mottle from chickenpen/grass/pen_ground_paint_4d.gd, worn toward the ground near the edge as the
// yard is. The mottle is laid in the field's own x and z (`field_*`, set per box), so two boxes
// that overlap show the same sand, not two patterns.
//
// THE DEV LOOK (`walk` 0): the strip is white, for the sheet's blue marks to sit on.
//
// The vertex stage and light() are the engine's, copied from path_mark.gdshader (which says why).

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

uniform vec4 box_size = vec4(1.0);
uniform float s0 = 0.0;
uniform float sand_round = 0.0;

// THE LOOK
uniform float walk = 1.0;
uniform vec4 sand : source_color = vec4(0.64, 0.47, 0.29, 1.0);
uniform vec4 dev_sand : source_color = vec4(0.93, 0.935, 0.94, 1.0);
// How much the edge wavers, as a share of the half width, and how wide the soft edge is (m).
uniform float sand_rough = 0.16;
uniform float sand_soft = 0.32;
// The mottle's depth, and how far the sand is worn toward the ground near its edge.
uniform float mottle = 0.16;
uniform float worn = 0.45;

// THE GROUND UNDER IT: `under_color`, or (ground_mode 1) the pen's painted glow, as the grass
// works it out (pen_grass.gdshader): own green far out, the glow's brighter green in the middle.
uniform vec4 under_color : source_color = vec4(0.16, 0.22, 0.11, 1.0);
uniform float ground_mode = 0.0;
uniform vec4 glow_area = vec4(-4.0, -14.0, 12.0, 40.0);
// In LINEAR light, converted by whoever sets them (pen_paths_4d.gd): a Vector3 handed to a
// source_color uniform is not converted, and the fade landed on a green far lighter than the ground.
uniform vec3 glow_colour = vec3(0.051, 0.078, 0.0093);
uniform vec3 edge_colour = vec3(0.022, 0.040, 0.012);
uniform float glow_on = 0.0;
uniform float glow_w = 30.0;

// Where the box's own (x, z) lie in the field: field = origin + x * field_x + z * field_z; and its W.
uniform vec2 field_origin = vec2(0.0);
uniform vec2 field_x = vec2(1.0, 0.0);
uniform vec2 field_z = vec2(0.0, 1.0);
uniform float field_w = 0.0;

// How far back (m, along the view) a pixel with no sand is pushed against one that is all sand.
uniform float depth_push = 0.003;

// REVEAL
uniform float reveal_on = 0.0;
uniform float found0 = -1.0e9;
uniform float found1 = 1.0e9;
uniform float found = 1.0;
uniform float reveal_fade = 1.5;

// W (metres, in the box's own W)
uniform float w_half = 100.0;
uniform float w_soft = 0.35;

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

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

// Smooth value noise along a line, -1 to 1.
float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), u) * 2.0 - 1.0;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise over a plane, -1 to 1.
float vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

// An edge's waver at `t` metres along it: three octaves, the long one leading, so the edge is
// irregular from far off and still smooth close up. -1 to 1, about.
float waver(float t, float lane) {
	return 0.55 * vnoise(t * 0.9 + lane) + 0.3 * vnoise(t * 2.6 + lane * 1.7 + 5.0) + 0.15 * vnoise(t * 7.0 + lane * 2.3 + 9.0);
}

// The same round a patch's rim: noise read on a circle, so it closes on itself without a seam.
float waver_round(vec2 dir, float r, float lane) {
	return 0.55 * vnoise2(dir * r * 0.9 + vec2(lane, 3.0)) + 0.3 * vnoise2(dir * r * 2.6 + vec2(5.0, lane)) + 0.15 * vnoise2(dir * r * 7.0 + vec2(lane, 11.0));
}

void fragment() {
	NORMAL = normalize(NORMAL);
	// Only the box's top shows sand; its thin sides and W faces stay bare.
	if (local_normal_4d.y < 0.5) {
		discard;
	}
	// The W band and the reveal narrow the sand rather than thinning it: toward the band's edge,
	// or the end of what has been found, the strip draws in to nothing, its edge soft all the way.
	float vis = 1.0 - smoothstep(w_half - w_soft, w_half, abs(local_pos.w));
	vec2 m = vec2(local_pos.x, local_pos.z);
	if (reveal_on > 0.5) {
		float rv = found;
		if (sand_round < 0.5) {
			float al = m.x + box_size.x * 0.5;
			rv = clamp(min((al - (found0 - reveal_fade)) / reveal_fade, ((found1 + reveal_fade) - al) / reveal_fade), 0.0, 1.0);
		}
		vis *= rv;
	}
	if (vis <= 0.001) {
		discard;
	}
	float hw = box_size.z * 0.5;
	// Signed distance to the sand's edge, metres, negative inside.
	float d;
	if (sand_round > 0.5) {
		float r = length(m);
		vec2 dir = r > 1e-4 ? m / r : vec2(1.0, 0.0);
		float rr = hw * vis * (1.0 + sand_rough * waver_round(dir, hw, s0));
		d = r - rr;
	} else {
		float sx = s0 + m.x + box_size.x * 0.5;
		float lane = m.y < 0.0 ? 17.0 : 61.0;
		float rr = hw * vis * (1.0 + sand_rough * waver(sx, lane));
		d = abs(m.y) - rr;
	}
	vec2 fxz = field_origin + m.x * field_x + m.y * field_z;
	// A little grain in the soft edge itself, so it is not a ruled gradient.
	d += 0.05 * vnoise2(fxz * 3.1);
	float soft = sand_soft * clamp(vis * 1.5, 0.35, 1.0);
	float cov = 1.0 - smoothstep(-soft, 0.0, d);
	if (cov < 0.015) {
		discard;
	}
	vec3 ground = under_color.rgb;
	if (ground_mode > 0.5) {
		float fade = 1.0 - smoothstep(2.0, glow_w, abs(field_w + local_pos.w));
		float g = glow_on * fade * (1.0 - smoothstep(glow_area.z, glow_area.w, length(fxz - glow_area.xy)));
		ground = mix(edge_colour, glow_colour, g);
	}
	vec3 col;
	if (walk > 0.5) {
		// The yard's mottle, broad and soft, in the field's own frame.
		float mt = 0.6 * vnoise2(fxz * 0.6) + 0.4 * vnoise2(fxz * 1.7 + vec2(7.0, 3.0));
		col = sand.rgb * (0.94 + mottle * mt);
		// Worn toward the ground as it nears the edge, as the yard is.
		col = mix(col, ground, worn * smoothstep(-soft * 2.5, 0.0, d));
	} else {
		col = dev_sand.rgb;
	}
	ALBEDO = mix(ground, col, cov);
	// The pixel deepest in its own sand wins where boxes overlap: pushed back along the view by how
	// much sand it lacks AND by how near its edge it is, so neither a soft edge nor a worn band ever
	// draws over another strip's middle.
	//
	// THE WORN BAND COUNTS TOO (6 Oct, Ramon: "the beige paths look like they're always clipping ...
	// a miniature offset differential that's unnoticeable to the eye"). The push used to follow the
	// cover alone, and the worn band is all cover: darkened toward the ground but level with the next
	// strip's middle, so at every joint the two fought and the worn one won in places, darker wedges
	// cut straight by a strip's end. Now the push grows from the middle out through the worn band and
	// the soft edge, twice depth_push at most: millimetres, never through the ground 13 mm below even
	// at a grazing view, and nothing the eye can see but the order.
	float inside = 1.0 - smoothstep(-soft * 2.5, 0.0, d);
	vec3 back = VERTEX + normalize(VERTEX) * depth_push * ((1.0 - cov) + (1.0 - inside));
	vec4 clip = PROJECTION_MATRIX * vec4(back, 1.0);
	DEPTH = clip.z / clip.w;
}

void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	float normal_dot_light = max(dot(normalize(normal_4d), light_direction_4d), 0.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * normal_dot_light;
}
