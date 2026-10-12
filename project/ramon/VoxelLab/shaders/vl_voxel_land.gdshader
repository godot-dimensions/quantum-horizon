// The open world's land (round 3, Ramon, 9 Oct: "make the green terrain noticeably darker. Introduce
// some subtle terrain texture or surface variation if possible. The current terrain looks too blocky
// ... If true smoothing isn't practical, consider visual alternatives that reduce the blocky look").
//
// A fork of vl_voxel_crop.gdshader (itself the engine's cross-section shader as of godot-4d 5dd394c);
// the vertex stage is unchanged. The voxels stay the voxels: dual contouring gives each tetrahedron
// one flat normal, and the cross-section has no per-vertex normals to smooth between, so true smooth
// shading would be an engine change. What this does instead:
//   1. VARIATION: the palette colour, varied a little by two octaves of value noise over the ground
//      (in world metres: no seams at the chunks' edges), warmer where the noise is high.
//   2. SLOPES: steep ground a little darker and browner than flat ground, so a hillside reads as a
//      hillside and not as more facets of the same green.
//   3. SOFTER FACETS: the lighting normal bent a third of the way toward up, and the light wrapped, so
//      neighbouring facets differ less in brightness: the blockiness is mostly that difference.
//   4. THE RED DESERT (round 6, #72): strata, bands of darker and lighter red up the slopes, wobbling with
//      the noise, as layered rock. Round 7: the wind ripple on the flats is gone (#89: it drew parallel
//      stripes a metre apart across the ground, which read as "vertical banding"), and broad patches of
//      ochre and pale sand break up the orange (#91: "subtle yellow, sandy, or ochre tones ... selectively"),
//      each matched to the ground's brightness so it stays one desert.
//   5. THE LAVA FIELD (round 6, #73: "lava texture breakup, variation, heat or molten behavior"): the lava
//      (the palette's only bright red, the generator's sea) moves: two octaves of value noise drifting
//      through x, z and w over time make its heat; where it is low a black crust in plates, bright cracks
//      between them, the rest molten orange to yellow, glowing (EMISSION) and breathing. The rock just over
//      the lava warmer, its cracks faintly alight; the rock elsewhere patched with ash and rust.
// world_pos needs the camera's 4D frame each frame (cam_*), set from the field's pre_render, with the land
// (land_kind: 0 green, 1 desert, 2 lava) and its lowest ground (low_y, the lava's level).

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

uniform vec4 cam_origin = vec4(0.0);
uniform vec4 cam_x = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 cam_y = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 cam_z = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 cam_w = vec4(0.0, 0.0, 0.0, 1.0);

uniform float variation = 0.14;
uniform float variation_scale = 7.0;
uniform float slope_dark = 0.22;
uniform float soften = 0.35;
uniform float wrap = 0.35;
uniform int land_kind = 0;
uniform float low_y = 0.0;
uniform float lava_glow = 1.5;

varying vec3 uvw;
varying vec4 normal_4d;
varying flat vec4 local_normal_4d;
varying vec4 local_pos;
varying vec4 world_pos;
varying vec3 view_pos;
varying vec4 lit_n4;
varying flat vec4 raw_n4;

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
		world_pos = cam_origin + mat4(cam_x, cam_y, cam_z, cam_w) * position_4d;
		view_pos = position_4d.xyz;
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
		raw_n4 = cell_normal_4d;
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

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	NORMAL = normalize(NORMAL);
	vec3 base = albedo.rgb * texture(albedo_texture, uvw * albedo_texture_map_scale + albedo_texture_map_offset).rgb;
	// The ground's own wobble: over x, z and w, in metres.
	vec3 g = vec3(world_pos.x, world_pos.z, world_pos.w);
	float n = value_noise(g / variation_scale) * 0.65 + value_noise(g / (variation_scale * 0.27)) * 0.35;
	float k = (n - 0.5) * 2.0 * variation;
	base *= 1.0 + k;
	base = mix(base, base * vec3(1.08, 1.02, 0.86), clamp(k * 2.0, 0.0, 1.0));
	// The slope: the surface's up-ness in the world (its 4D normal taken out of the camera's frame).
	vec4 nw = mat4(cam_x, cam_y, cam_z, cam_w) * normalize(normal_4d);
	float steep = 1.0 - clamp(abs(nw.y), 0.0, 1.0);
	base = mix(base, base * vec3(0.78, 0.70, 0.60), smoothstep(0.25, 0.75, steep) * slope_dark * 2.5);
	vec3 emit = vec3(0.0);
	if (land_kind == 1) {
		float band = sin((world_pos.y + n * 1.6) * 3.1) * 0.5 + 0.5;
		float band2 = sin((world_pos.y + n * 0.9) * 7.3 + 1.7) * 0.5 + 0.5;
		// Cliffs only (round 7 review: on gentle slopes the bands spread into broad stripes across the ground).
		float strata = smoothstep(0.55, 0.85, steep);
		vec3 layered = base * mix(vec3(0.74, 0.66, 0.64), vec3(1.12, 1.0, 0.92), band) * mix(0.9, 1.05, band2);
		base = mix(base, layered, strata);
		// Ochre and pale sand in patches tens of metres across, mostly on the flats.
		float lum = dot(base, vec3(0.299, 0.587, 0.114));
		float patch_o = smoothstep(0.55, 0.78, value_noise(g / 26.0 + vec3(11.7)));
		float patch_s = smoothstep(0.6, 0.82, value_noise(g / 17.0 + vec3(4.3)));
		vec3 ochre = vec3(0.80, 0.58, 0.27);
		vec3 sand = vec3(0.86, 0.73, 0.50);
		ochre *= lum / dot(ochre, vec3(0.299, 0.587, 0.114)) * 1.06;
		sand *= lum / dot(sand, vec3(0.299, 0.587, 0.114)) * 1.12;
		float flats = 1.0 - strata * 0.7;
		base = mix(base, ochre, patch_o * 0.55 * flats);
		base = mix(base, sand, patch_s * 0.45 * flats);
	} else if (land_kind == 2) {
		float molten = smoothstep(0.5, 0.8, base.r - base.b);
		float t = TIME;
		vec3 q = g * 0.45;
		float heat = clamp(value_noise(q + vec3(t * 0.08, t * 0.05, -t * 0.03)) * 0.65
				+ value_noise(q * 2.7 - vec3(t * 0.15, -t * 0.11, t * 0.07)) * 0.35, 0.0, 1.0);
		// Plates of crust where the heat is low (about half of it); cracks glowing between them. Deep red to
		// orange where it is hot, yellow only in the hottest spots (round 6 review: all-yellow read as flat).
		float plate = smoothstep(0.47, 0.6, heat);
		float crack = 1.0 - smoothstep(0.0, 0.035, abs(value_noise(q * 1.6 + vec3(t * 0.02)) - 0.5));
		vec3 hot = mix(vec3(0.62, 0.08, 0.015), vec3(1.0, 0.32, 0.04), smoothstep(0.6, 0.8, heat));
		hot = mix(hot, vec3(1.0, 0.66, 0.22), smoothstep(0.86, 0.97, heat));
		float pulse = 0.85 + 0.15 * sin(t * 1.3 + n * 9.0);
		float m = max(plate, crack * 0.6);
		vec3 crust = vec3(0.045, 0.03, 0.026) * (0.8 + 0.4 * value_noise(q * 3.1));
		base = mix(base, mix(crust, hot * 0.35, m), molten);
		emit += hot * m * molten * lava_glow * pulse;
		// The rock just over the lava: warmer, a few of its cracks faintly alight, in patches (thin and broken,
		// not lines all over: seen low they read as contour lines).
		float near = (1.0 - molten) * (1.0 - smoothstep(0.0, 2.0, world_pos.y - low_y));
		base = mix(base, base * vec3(1.3, 0.88, 0.75), near * 0.5);
		float rock_crack = 1.0 - smoothstep(0.0, 0.018, abs(value_noise(g * 1.7) - 0.5));
		float patches = smoothstep(0.6, 0.78, value_noise(g * 0.23 + vec3(3.1)));
		emit += vec3(0.9, 0.22, 0.03) * rock_crack * patches * near * 0.45;
		// The rock elsewhere: patches of ash and of rust.
		float ash = value_noise(g / 11.0 + vec3(7.3));
		base = mix(base, base * vec3(1.5, 1.35, 1.25), (1.0 - molten) * smoothstep(0.6, 0.85, ash) * 0.5);
		base = mix(base, base * vec3(1.4, 0.9, 0.7), (1.0 - molten) * smoothstep(0.65, 0.9, 1.0 - ash) * 0.5);
	}
	ALBEDO = base;
	EMISSION = emit;
	// The lighting normal a little toward the world's up, in the camera's frame.
	vec4 up_c = vec4(cam_x.y, cam_y.y, cam_z.y, cam_w.y);
	vec4 ln = normalize(normal_4d);
	if (dot(ln, up_c) < 0.0) {
		up_c = -up_c;
	}
	lit_n4 = normalize(mix(ln, up_c, soften));
}

void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	float d = dot(normalize(lit_n4), light_direction_4d);
	// Wrapped: light reaches a little past the terminator, so facets turning away fade, not snap.
	float normal_dot_light = max((d + wrap) / (1.0 + wrap), 0.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * normal_dot_light;
}
