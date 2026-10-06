// Crosswise's surface: the Creation Lab's look (Ramon, 6 Oct: "take the general look and lighting
// from creatorlabs"): its procedural grid (CreationLab/LabKit/shaders/lab_grid.gdshader: Unreal's
// grid, 1 m cells of five 20 cm subdivisions, in the kit's mid greys), or one of Ramon's dev textures
// at true metres; plus the four things that make a 4D diorama readable from inside one slice
// (PLAN.md, decisions 4 and 5; RESEARCH.md):
//
//   LANES    the floor is banded along W in lanes (Marc ten Bosch's "texture the ground differently
//            at intervals, to group parallel worlds together"): a tint per lane, warm ana and cool
//            kata of the home lane, and the seams between lanes, drawn as you turn into W (in the
//            normal view a whole floor would flash as you crossed one). A lane can be marked.
//   W FACES  a cell whose 4D normal points along W is where the solid ENDS in W. Those faces only
//            face the camera after a turn, so tinting them says "this is where it stops in W" (the
//            way Miegakure's cut faces read deep blue).
//   W EDGE   near a solid's W ends its cross-section takes a tint, so something about to vanish (or
//            appear) as you move through W warns you first (Miegakure's raked rings grow before a
//            spherinder appears).
//   HAZARD   a band of stripes across the floor at a world Z, in every lane: "stand here and turn".
//
// THE PATTERN FOLLOWS THE VIEW. The grid and the texture are laid in world metres along the axes you
// can SEE: X and the view's depth axis (Z in the normal view, W once turned, and in between during a
// turn), so a floor is the same square grid in both views instead of a smear of one row along W.
//
// The vertex stage is the engine's, copied from CreationLab/LabKit/shaders/lab_surface.gdshader,
// which is current as of godot-4d da3586b; checked unchanged up to 5dd394c (5 Oct). If the engine's
// vertex stage changes, re-copy it. Two outputs are added: the slice's normal in this mesh's own
// space (`slice_n`, from the model-view basis: its .w is 1 in the normal view and 0 once turned),
// and that is all the view knowledge the fragment needs.

shader_type spatial;
render_mode skip_vertex_transform;

instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler3D albedo_texture : hint_default_white, source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 albedo_texture_map_offset = vec3(0.0);
uniform vec3 albedo_texture_map_scale = vec3(1.0);

uniform vec4 surface_size = vec4(1.0, 1.0, 1.0, 1.0);
uniform float texture_metres = 1.0;
uniform vec3 texture_offset = vec3(0.0);
uniform vec4 tint : source_color = vec4(1.0);

// The lab grid (on: replaces the texture). Colours are the kit's swatches (kit_style.gd).
uniform bool grid_on = false;
uniform vec4 grid_surface : source_color = vec4(0.64, 0.65, 0.66, 1.0);
uniform vec4 grid_line : source_color = vec4(0.52, 0.53, 0.55, 1.0);
uniform vec4 grid_subline : source_color = vec4(0.60, 0.61, 0.62, 1.0);
uniform float grid_strength = 0.5;
uniform float grid_size = 1.0;
uniform float grid_sub_count = 5.0;
uniform float grid_line_width = 0.022;
uniform float grid_subline_width = 0.006;
// Vertical faces (the island's sides, a wall's ends): their own multiplier, for the slab look.
uniform vec4 side_tint : source_color = vec4(1.0);

// Where this mesh's origin is in the world (lanes and hazard bands are world measures).
uniform vec4 origin_4d = vec4(0.0);

uniform bool lanes_on = false;
uniform float lane_width = 1.6;
uniform float lane_zero_w = 0.0;
uniform vec4 lane_m2 : source_color = vec4(1.0);
uniform vec4 lane_m1 : source_color = vec4(1.0);
uniform vec4 lane_0 : source_color = vec4(1.0);
uniform vec4 lane_p1 : source_color = vec4(1.0);
uniform vec4 lane_p2 : source_color = vec4(1.0);
uniform vec4 lane_seam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float lane_seam_width = 0.06;
// A marked lane: index (-2..2; 99 for none), its colour and how much of it.
uniform int mark_lane = 99;
uniform vec4 mark_color : source_color = vec4(0.35, 0.85, 0.9, 1.0);
uniform float mark_mix = 0.55;

uniform vec4 wface_color : source_color = vec4(0.36, 0.33, 0.78, 1.0);
uniform float wface_mix = 0.0;
uniform vec4 wedge_color : source_color = vec4(0.55, 0.45, 1.0, 1.0);
uniform float wedge_mix = 0.0;
uniform float wedge_band = 0.35;

uniform bool hazard_on = false;
uniform vec2 hazard_z = vec2(0.0, 0.0);
uniform vec4 hazard_color : source_color = vec4(1.0, 0.78, 0.12, 1.0);
uniform vec4 hazard_dark : source_color = vec4(0.12, 0.12, 0.14, 1.0);

varying vec3 uvw;
varying vec4 normal_4d;
varying flat vec4 local_normal_4d;
varying vec4 local_pos;
varying flat vec4 slice_n;

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
	// The view's W axis (the slice's normal) written in this mesh's own axes: row 3 of the
	// model-view basis. Normalised, so a scaled mesh still reads 1 when the view is not turned.
	vec4 sn = vec4(modelview_basis_x.w, modelview_basis_y.w, modelview_basis_z.w, modelview_basis_w.w);
	slice_n = length(sn) > 0.0 ? normalize(sn) : vec4(0.0, 0.0, 0.0, 1.0);

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

// The face's two pattern coordinates, along the axes you can see: X and the view's depth axis `d`
// (Z normal, W turned). A floor gets (x, depth); a wall facing along X gets (depth, -y); any other
// wall (facing the depth axis, or W) gets (x, -y).
vec2 face_coords(vec4 n, vec4 p, vec4 d) {
	vec4 a = abs(n);
	if (a.y >= a.x && a.y >= a.z && a.y >= a.w) {
		return vec2(p.x, dot(p, d));
	}
	if (a.x >= abs(dot(n, d))) {
		return vec2(dot(p, d), -p.y);
	}
	return vec2(p.x, -p.y);
}

// How much of a line `width` metres wide, repeating every `period` metres, covers this pixel (the
// lab grid's, never thinner than a pixel; `fade` says how far it had to be thickened).
float grid_lines(vec2 c, float period, float width, out float fade) {
	vec2 fw = max(fwidth(c), vec2(0.00001));
	vec2 dd = abs(fract(c / period + 0.5) - 0.5) * period;
	vec2 w = max(vec2(width), fw);
	fade = clamp(width / max(fw.x, fw.y), 0.0, 1.0);
	vec2 cover = 1.0 - smoothstep(w * 0.5 - fw * 0.5, w * 0.5 + fw * 0.5, dd);
	return max(cover.x, cover.y);
}

vec4 lane_tint(int lane) {
	if (lane <= -2) {
		return lane_m2;
	}
	if (lane == -1) {
		return lane_m1;
	}
	if (lane == 0) {
		return lane_0;
	}
	if (lane == 1) {
		return lane_p1;
	}
	return lane_p2;
}

void fragment() {
	NORMAL = normalize(NORMAL);
	vec4 n = abs(local_normal_4d);
	bool top = n.y >= n.x && n.y >= n.z && n.y >= n.w;
	bool w_face = !top && n.w >= n.x && n.w >= n.z;
	vec4 world = origin_4d + local_pos;
	// How far the view has turned into W: 0 in the normal view, 1 once turned.
	float turned = clamp(1.0 - abs(slice_n.w), 0.0, 1.0);

	// The view's depth axis in this mesh's space: perpendicular to the slice's normal within Z-W.
	vec2 zw = vec2(slice_n.w, -slice_n.z);
	vec4 depth = length(zw) > 0.0001 ? vec4(0.0, 0.0, normalize(zw)) : vec4(0.0, 0.0, 1.0, 0.0);
	vec3 col;
	if (grid_on) {
		vec2 g = face_coords(local_normal_4d, world, depth);
		float fade_major;
		float fade_minor;
		float major = grid_lines(g, grid_size, grid_line_width, fade_major);
		float minor = grid_lines(g, grid_size / max(grid_sub_count, 1.0), grid_subline_width, fade_minor);
		col = grid_surface.rgb;
		col = mix(col, grid_subline.rgb, minor * fade_minor * grid_strength);
		col = mix(col, grid_line.rgb, major * grid_strength);
		col *= tint.rgb;
	} else {
		vec4 p = (local_pos + abs(surface_size) * 0.5) / max(texture_metres, 0.0001);
		vec2 st = face_coords(local_normal_4d, p, depth) + texture_offset.xy;
		col = albedo.rgb * tint.rgb * texture(albedo_texture, vec3(st, 0.5)).rgb;
	}
	if (!top) {
		col *= side_tint.rgb;
	}

	if (lanes_on) {
		float u = (world.w - lane_zero_w) / lane_width + 0.5;
		int lane = int(floor(u));
		col *= lane_tint(lane).rgb;
		if (lane == mark_lane) {
			col = mix(col, mark_color.rgb, mark_mix);
		}
		if (top) {
			// The seams: thin lines at lane edges, as the view turns into W.
			float d = abs(fract(u) - 0.5) * 2.0;
			float edge = (1.0 - d) * lane_width * 0.5;
			float seam = 1.0 - smoothstep(lane_seam_width * 0.5, lane_seam_width, edge);
			col = mix(col, lane_seam_color.rgb, seam * turned * lane_seam_color.a);
		}
	}

	if (hazard_on && top && world.z >= hazard_z.x && world.z <= hazard_z.y) {
		float stripe = step(0.5, fract((world.x + world.z + world.w) * 1.25));
		vec3 band = mix(hazard_color.rgb, hazard_dark.rgb, stripe);
		float inner = min(world.z - hazard_z.x, hazard_z.y - world.z);
		// Strong where you see the band across your path (normal view); faint once turned, when the
		// slice lies inside the band and the whole floor would be stripes.
		col = mix(col, band, smoothstep(0.0, 0.04, inner) * 0.85 * (1.0 - 0.75 * turned));
	}

	if (w_face && wface_mix > 0.0) {
		col = mix(col, wface_color.rgb, wface_mix);
	}
	if (wedge_mix > 0.0) {
		float half_w = abs(surface_size.w) * 0.5;
		float to_edge = half_w - abs(local_pos.w);
		float near = 1.0 - smoothstep(0.0, wedge_band, to_edge);
		col = mix(col, wedge_color.rgb, near * wedge_mix);
	}

	ALBEDO = col;
}

void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	float normal_dot_light = max(dot(normalize(normal_4d), light_direction_4d), 0.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * normal_dot_light;
}
