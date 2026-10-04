// The lab kit's grid surface: Unreal's prototype grid (the "Intro to Unreal" level's
// MI_PrototypeGrid_Gray, measured 4 Oct 2026, follow_up/lab_case_study/) rebuilt as our own
// shader, with two optional overlays painted INTO the surface rather than floated over it:
//
//   GRID      world-aligned lines: a major line every `grid_size` metres (1 m, as Unreal's) and
//             `sub_count` - 1 minor lines between (5 cells of 20 cm, as Unreal's). Widths are in
//             metres; each line is kept at least a pixel wide and the minor lines fade out once
//             they would be thinner than that, so a far floor does not shimmer. `grid_offset` is
//             where the mesh's origin sits in the world (the kit sets it from the box), so boxes
//             side by side continue one grid. All colours are live uniforms: a palette
//             (LabKit/lab_grid.gd) recolours every surface of a swatch at once.
//   PRINT     a texture (text, key caps, numbers; LabKit/lab_print.gd renders them) painted on one
//             face of the box: `print_normal` picks the face (in the mesh's own space),
//             `print_rect` places it in metres from that face's lower-left corner as the reader
//             sees it. Mixed in by the texture's own (premultiplied) alpha, so edges stay
//             smooth: the cross-section renderer has no translucency, and an alpha-tested decal
//             would have jagged text.
//   CHEVRONS  arrows marching along `chevron_dir` on the box's top face, drawn procedurally
//             (Ramon's my-own-01 lab scrolls a chevron texture along its floor strips).
//
// `print_glow` and `chevron_glow` lift a print or the chevrons above the lighting (EMISSION), so
// a sign still reads on a face turned away from the sun.
//
// The vertex stage is the engine's, copied from LabKit/shaders/lab_surface.gdshader (which says
// why it must stay identical to engine/modules/4d's cross-section shader). `perpendicular_4d` and
// `light()` are carried across for the same reasons given there.

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

uniform vec4 surface_size = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 grid_offset = vec4(0.0);

group_uniforms grid;
uniform vec4 surface_color : source_color = vec4(0.78, 0.78, 0.76, 1.0);
uniform vec4 line_color : source_color = vec4(0.30, 0.30, 0.30, 1.0);
uniform vec4 subline_color : source_color = vec4(0.58, 0.58, 0.57, 1.0);
uniform float grid_strength : hint_range(0.0, 1.0) = 1.0;
uniform float grid_size = 1.0;
uniform float sub_count = 5.0;
uniform float line_width = 0.022;
uniform float subline_width = 0.006;

group_uniforms print;
uniform sampler2D print_texture : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float print_on : hint_range(0.0, 1.0) = 0.0;
uniform vec4 print_normal = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 print_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 print_tint : source_color = vec4(1.0);
uniform float print_glow : hint_range(0.0, 1.0) = 0.35;

group_uniforms chevrons;
uniform float chevron_on : hint_range(0.0, 1.0) = 0.0;
uniform vec4 chevron_color : source_color = vec4(0.86, 1.0, 0.24, 1.0);
uniform float chevron_speed = 1.2;
uniform float chevron_spacing = 1.1;
uniform float chevron_band = 0.38;
uniform float chevron_arm = 0.55;
uniform float chevron_glow : hint_range(0.0, 1.0) = 0.8;
uniform float chevron_phase = 0.0;
uniform vec2 chevron_dir = vec2(0.0, -1.0);
group_uniforms;

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


// The grid's two coordinates on whichever face this cell lies on, in world metres.
vec2 grid_coords(vec4 n, vec4 p) {
	vec4 a = abs(n);
	if (a.y >= a.x && a.y >= a.z && a.y >= a.w) {
		return p.xz;
	}
	if (a.w >= a.x && a.w >= a.z) {
		return p.xz;
	}
	if (a.z >= a.x) {
		return p.xy;
	}
	return p.zy;
}

// How much of a line `width` metres wide, repeating every `period` metres, covers this pixel.
// Never thinner than a pixel; `fade` says how far it was thickened to stay that wide (1: not at
// all), so a caller can let a fine line go rather than draw it fat.
float lines(vec2 c, float period, float width, out float fade) {
	vec2 fw = max(fwidth(c), vec2(0.00001));
	vec2 d = abs(fract(c / period + 0.5) - 0.5) * period;
	vec2 w = max(vec2(width), fw);
	fade = clamp(width / max(fw.x, fw.y), 0.0, 1.0);
	vec2 cover = 1.0 - smoothstep(w * 0.5 - fw * 0.5, w * 0.5 + fw * 0.5, d);
	return max(cover.x, cover.y);
}

// The print's texture coordinate on the face it is painted on, or -1 off it. Before the flip,
// u runs to the right of a reader facing the face and v up, both in metres from the face's
// lower-left corner; on a floor, u runs along +x and the text's top points to -z.
vec2 print_uv(vec4 n, vec4 pc) {
	if (dot(n, print_normal) < 0.9) {
		return vec2(-1.0);
	}
	vec4 a = abs(print_normal);
	vec2 m;
	if (a.z >= a.x && a.z >= a.y) {
		m = vec2(print_normal.z > 0.0 ? pc.x : surface_size.x - pc.x, pc.y);
	} else if (a.x >= a.y) {
		m = vec2(print_normal.x > 0.0 ? surface_size.z - pc.z : pc.z, pc.y);
	} else {
		m = vec2(pc.x, surface_size.z - pc.z);
	}
	vec2 uv = (m - print_rect.xy) / max(print_rect.zw, vec2(0.0001));
	return vec2(uv.x, 1.0 - uv.y);
}

void fragment() {
	NORMAL = normalize(NORMAL);
	vec4 world = local_pos + grid_offset;
	vec2 g = grid_coords(local_normal_4d, world);
	float fade_major;
	float fade_minor;
	float major = lines(g, grid_size, line_width, fade_major);
	float minor = lines(g, grid_size / max(sub_count, 1.0), subline_width, fade_minor);
	vec3 c = surface_color.rgb;
	c = mix(c, subline_color.rgb, minor * fade_minor * grid_strength);
	c = mix(c, line_color.rgb, major * grid_strength);
	vec3 glow = vec3(0.0);

	// Metres from the box's lower corner.
	vec4 pc = local_pos + abs(surface_size) * 0.5;
	if (print_on > 0.0) {
		vec2 uv = print_uv(local_normal_4d, pc);
		if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
			// Premultiplied (LabKit/lab_print.gd): the ink already carries its coverage.
			vec4 t = texture(print_texture, uv);
			float k = t.a * print_on;
			vec3 ink = t.rgb * print_tint.rgb * print_on;
			c = c * (1.0 - k) + ink;
			glow += ink * print_glow;
		}
	}

	if (chevron_on > 0.0 && local_normal_4d.y > 0.9) {
		// Along the strip in `chevron_dir` from its start, and across it from -1 to 1. The
		// arrows' tips lead, so a point at the strip's side is behind the tip by `chevron_arm`
		// widths. The box is never rotated (its grid would leave the floor's), so the direction
		// is a uniform, one of the four axis directions in the box's x/z.
		vec2 d = normalize(chevron_dir);
		vec2 side = vec2(-d.y, d.x);
		float length_m = abs(dot(surface_size.xz, d));
		float width_m = abs(dot(surface_size.xz, side));
		float along = dot(pc.xz, d) - min(0.0, dot(surface_size.xz, d));
		float across = dot(local_pos.xz, side) / max(width_m * 0.5, 0.0001);
		float s = along + abs(across) * chevron_arm * width_m;
		float f = fract((s - TIME * chevron_speed - chevron_phase) / chevron_spacing);
		float aa = max(fwidth(s) / chevron_spacing, 0.0001);
		float band = smoothstep(0.0, aa, f) * (1.0 - smoothstep(chevron_band - aa, chevron_band, f));
		// A margin at the strip's sides and ends, so arrows never touch its edge.
		float edge = 1.0 - smoothstep(0.78, 0.86, abs(across));
		float ends = smoothstep(0.0, 0.25, along) * smoothstep(0.0, 0.25, length_m - along);
		float k = band * edge * ends * chevron_on;
		c = mix(c, chevron_color.rgb, k);
		glow += chevron_color.rgb * k * chevron_glow;
	}
	ALBEDO = c;
	EMISSION = glow;
}

void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	float normal_dot_light = max(dot(normalize(normal_4d), light_direction_4d), 0.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * normal_dot_light;
}
