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
// WATER LAB: 1 draws the print as light, not paint (the PathCreator's marks' way: what is under it
// goes dark, the print's colour is emitted). A code-blue print on a floor under spotlights was lit
// past its colour and clipped to cyan (Ramon, 9 Oct: "its not blue but cyan").
uniform float print_emit : hint_range(0.0, 1.0) = 0.0;
// A print wrapped round a cylinder's side instead (the pedestal's label): x and y of
// print_cylinder are the angles it runs between (radians from +Z towards +X, so it reads left to
// right from outside), z and w the heights (in the mesh's own space) it runs between.
// A live print (a viewport's texture) has no mipmaps: 1 samples it four times across its own
// footprint on screen instead, so it stays smooth from a distance.
uniform float print_aa = 0.0;
uniform float print_cyl = 0.0;
uniform vec4 print_cylinder = vec4(-0.4, 0.4, -0.1, 0.1);

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

// A ROUTE painted into a floor: up to eight straight segments in WORLD x/z, each (ax, az, bx, bz),
// with the distance along the route at each one's start, so the arrows run on unbroken from one
// segment to the next and from one floor box to the next. No geometry above the floor, so nothing
// can fight it for depth or flicker (Ramon, 4 Oct, of the raised chevron strips). The arrows
// fade as they shrink to a few pixels, so the far end of a route stays calm.
// A RING painted into a floor round a point (the pedestal's): a ring of dashes and outside it a
// ring of arcs with wide breaks, turning slowly (Ramon, 4 Oct: "a circle decal around the
// pedestal, that rotates slowly, keep it simple"; then "more breaks, the line on the inside gone,
// less dots, a thicker blue like the 4D Basics blue"). ring_at is world x, z, the radius, and the
// turn speed in radians a second; ring_on 0 hides it.
group_uniforms ring;
uniform float ring_on : hint_range(0.0, 1.0) = 0.0;
// HOLOGRAM (Ramon, 4 Oct: "a cylinder with an opacity falloff upward ... from 80% blue opaque to 0%
// ... a subtle holographic bounding box"). The renderer has no translucency, so it is faked with an
// ordered dither: the surface's coverage falls from `holo_base` at its foot to nothing at its top
// (`holo_falloff` the curve), and a pixel is drawn only where its place in a 4x4 Bayer matrix is
// under that coverage; the eye averages the pattern into a fade. Being real geometry it sorts with
// everything in front of and behind it, and survives the slice turning. Thin bands rise through it.
uniform float holo_on : hint_range(0.0, 1.0) = 0.0;
uniform vec4 holo_color : source_color = vec4(0.25, 0.60, 1.0, 1.0);
uniform float holo_base : hint_range(0.0, 1.0) = 0.8;
uniform float holo_falloff = 1.6;
uniform float holo_glow = 0.6;
uniform float holo_scan = 0.35;
uniform float holo_scan_density = 2.2;
uniform float holo_scan_speed = 0.35;
uniform float holo_fine : hint_range(0.0, 1.0) = 0.0;
// PATH (CreationLab/kit/kit_path_4d.gd): this surface is a path's strip, a thin band of tetrahedra a
// hair above the floor that follows a curve through the floor's own space (x, z and W). Its texture
// coordinates are metres along the curve, -1..1 across it, and -1..1 through its thickness in W.
// The floor's own grid is drawn on it (the same swatch, the same world offset), so the strip
// itself is invisible and only its marks show, moving on along the curve at `path_speed`.
// THE MARKS ARE RIGID (Ramon, 5 Oct: "the curved arrows deform, better keep them intact and let them
// do a rotational turn, like a shape following a path"): the curve itself is handed in
// (`path_curve_tex`, points evenly spaced along it), and each arrow or block is drawn in a straight frame
// of its own, turned to the curve's direction at its middle, so it turns as it goes round a bend
// instead of bending. The marks end in a fixed line across the strip at either end of an open path
// (they run into it and are gone, no fade), and are cut only where the strip itself ends, in W too:
// what the slice leaves is gone, as the renderer slices the strip.
//   path_style 0  RAMON'S ARROW (the route's chevron pair, measured from arrow.png)
//              1  ZEBRA (stripes across the strip, slanted; they follow the curve, as a road's do)
//              2  BLOCKS (squares)
//              3  LINE (a thin line with balls running along it)
//              4  SOLID (the whole strip)
uniform float path_on : hint_range(0.0, 1.0) = 0.0;
uniform float path_style = 0.0;
uniform vec4 path_color : source_color = vec4(0.13, 0.40, 0.86, 1.0);
uniform float path_glow = 0.0;
uniform float path_spacing = 3.0;
uniform float path_speed = 0.7;
uniform float path_length = 10.0;
uniform float path_width = 1.15;
uniform float path_closed = 0.0;
uniform float path_pair = 0.76;
uniform float path_cap = 0.08;
// The strip is this much wider than its marks, so a rigid arrow turning on a bend is not cut off.
uniform float path_margin = 1.4;
// The curve as a 1-pixel-high float texture, one point per texel: (x, z, w). A texture, not a uniform
// array: arrays were not kept per material here (every path drew with the last path's curve).
uniform sampler2D path_curve_tex : filter_nearest, repeat_disable;
uniform int path_curve_n = 0;
uniform vec4 ring_at = vec4(0.0, 0.0, 3.0, 0.08);
uniform vec4 ring_color : source_color = vec4(0.12, 0.45, 1.0, 1.0);

group_uniforms route;
uniform float route_on : hint_range(0.0, 1.0) = 0.0;
uniform vec4 route_seg[8];
uniform float route_start[8];
uniform int route_count = 0;
// The arrow's full width, metres; its whole design scales with it (Ramon, 4 Oct: "a bit wider").
uniform float route_width = 1.15;
uniform vec4 route_color : source_color = vec4(0.12, 0.45, 1.0, 1.0);
uniform float route_speed = 0.7;
// One pair of arrows to the next, metres: two close together, then a gap (Ramon, 4 Oct).
uniform float route_spacing = 3.0;
// How far the second arrow of a pair trails the first, metres (0: single arrows). His own arrow
// sheet stacks them 0.661 of an arrow's width apart.
uniform float route_pair = 0.76;
uniform float route_glow : hint_range(0.0, 1.0) = 0.25;
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

// The path's curve at `s` metres along: (x, z, w) in the strip's own space, and its direction on the
// floor.
vec3 path_point(float s) {
	float n1 = float(max(path_curve_n - 1, 1));
	float f = clamp(s / max(path_length, 0.001), 0.0, 1.0) * n1;
	int i = int(min(floor(f), n1 - 1.0));
	return mix(texelFetch(path_curve_tex, ivec2(i, 0), 0).xyz, texelFetch(path_curve_tex, ivec2(i + 1, 0), 0).xyz, f - float(i));
}

vec2 path_dir(float s) {
	float n1 = float(max(path_curve_n - 1, 1));
	float f = clamp(s / max(path_length, 0.001), 0.0, 1.0) * n1;
	int i = int(min(floor(f), n1 - 1.0));
	int j = min(i + 1, path_curve_n - 1);
	int h = max(i - 1, 0);
	int k = min(i + 2, path_curve_n - 1);
	vec2 cj = texelFetch(path_curve_tex, ivec2(j, 0), 0).xy;
	vec2 ch = texelFetch(path_curve_tex, ivec2(h, 0), 0).xy;
	vec2 ck = texelFetch(path_curve_tex, ivec2(k, 0), 0).xy;
	vec2 ci = texelFetch(path_curve_tex, ivec2(i, 0), 0).xy;
	vec2 t = mix(cj - ch, ck - ci, f - float(i));
	return length(t) > 1e-5 ? normalize(t) : vec2(0.0, 1.0);
}

// Where this fragment is in the straight frame of a mark whose middle is `sc` metres along: (along,
// across), metres.
vec2 path_frame(float sc, vec2 p) {
	float sm = path_closed > 0.5 ? mod(sc, path_length) : sc;
	vec2 c = path_point(sm).xy;
	vec2 t = path_dir(sm);
	vec2 rel = p - c;
	return vec2(dot(rel, t), dot(rel, vec2(t.y, -t.x)));
}

// As path_frame, but a mark near an open path's end straightens out to the end's direction over its
// last 1.8 m (and from its start's over its first), so it meets the end line square and slides under
// it cleanly instead of being cut across at a slant.
vec2 path_frame_ends(float sc, vec2 p) {
	if (path_closed > 0.5) {
		return path_frame(sc, p);
	}
	vec2 c = path_point(clamp(sc, 0.0, path_length)).xy;
	vec2 t = path_dir(clamp(sc, 0.0, path_length));
	float we = smoothstep(path_length - 1.8, path_length - 0.4, sc);
	float ws = 1.0 - smoothstep(0.4, 1.8, sc);
	t = normalize(mix(t, path_dir(path_length - path_cap * 0.5), we));
	t = normalize(mix(t, path_dir(path_cap * 0.5), ws));
	vec2 rel = p - c;
	return vec2(dot(rel, t), dot(rel, vec2(t.y, -t.x)));
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
		if (print_cyl > 0.5) {
			uv = vec2(-1.0);
			if (abs(local_normal_4d.y) < 0.5) {
				float ang = atan(local_pos.x, local_pos.z);
				uv = vec2((ang - print_cylinder.x) / (print_cylinder.y - print_cylinder.x),
					1.0 - (local_pos.y - print_cylinder.z) / (print_cylinder.w - print_cylinder.z));
			}
		}
		if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
			// Premultiplied (LabKit/lab_print.gd): the ink already carries its coverage.
			vec4 t = texture(print_texture, uv);
			if (print_aa > 0.5) {
				vec2 du = dFdx(uv) * 0.375;
				vec2 dv = dFdy(uv) * 0.375;
				t = 0.25 * (texture(print_texture, uv + du + dv * 0.33) + texture(print_texture, uv - du - dv * 0.33)
					+ texture(print_texture, uv + dv - du * 0.33) + texture(print_texture, uv - dv + du * 0.33));
			}
			float k = t.a * print_on;
			vec3 ink = t.rgb * print_tint.rgb * print_on;
			c = c * (1.0 - k) + ink * (1.0 - print_emit);
			glow += ink * mix(print_glow, 1.0, print_emit);
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
	if (ring_on > 0.0 && local_normal_4d.y > 0.9) {
		vec2 rel = world.xz - ring_at.xy;
		float r = length(rel);
		float fr = max(fwidth(r), 0.0005);
		float rr = ring_at.z;
		if (r > rr - 0.1 && r < rr + 0.6) {
			float ang = atan(rel.y, rel.x) + TIME * ring_at.w;
			// A ring of dashes, few and long.
			float dash = step(fract(ang / TAU * 28.0), 0.42);
			float k = dash * (1.0 - smoothstep(0.045, 0.045 + fr, abs(r - rr)));
			// Outside it, six arcs with wide breaks, turning the other way.
			float ang2 = atan(rel.y, rel.x) - TIME * ring_at.w * 0.6;
			float arcs = step(fract(ang2 / TAU * 6.0), 0.55);
			k = max(k, arcs * (1.0 - smoothstep(0.105, 0.105 + fr, abs(r - (rr + 0.3)))));
			k *= ring_on * (1.0 - smoothstep(0.03, 0.08, fr));
			c = mix(c, ring_color.rgb, k * 0.95);
			glow += ring_color.rgb * k * 0.2;
		}
	}
	if (route_on > 0.0 && route_count > 0 && local_normal_4d.y > 0.9) {
		vec2 p2 = world.xz;
		float best = 0.0;
		for (int i = 0; i < 8; i++) {
			if (i >= route_count) {
				break;
			}
			vec2 a = route_seg[i].xy;
			vec2 b = route_seg[i].zw;
			vec2 ab = b - a;
			float len = max(length(ab), 0.0001);
			vec2 dir = ab / len;
			vec2 rel = p2 - a;
			float along = dot(rel, dir);
			float across = dot(rel, vec2(-dir.y, dir.x)) / (route_width * 0.5);
			if (along < -0.05 || along > len + 0.05 || abs(across) > 1.0) {
				continue;
			}
			// RAMON'S ARROW (my-own-01/_textures/decals/test/arrow.png, measured in pixels on its
			// 428 px width): a thick chevron band, a hair of a gap, a thin band, both cut square at
			// 0.446 of the width out from the middle, and past each cut a small tab, the thin band
			// stepped down by its own depth. Depths are measured along the route behind the
			// arm's front edge, which slopes back 0.685 per unit out from the middle.
			float wdt = route_width;
			float au = abs(across) * wdt * 0.5;
			float t1 = 0.2056 * wdt;
			float g1 = 0.0234 * wdt;
			float t2 = 0.0981 * wdt;
			float half_w = 0.4463 * wdt;
			float tab_w = 0.0537 * wdt;
			float span = 0.768 * wdt;
			float fw = max(fwidth(along), 0.0001);
			float soft = max(fw, 0.004);
			// Metres into the current pair, the pattern sliding on at route_speed.
			float d = fract((route_start[i] + along - TIME * route_speed) / route_spacing) * route_spacing;
			float band = 0.0;
			for (int n = 0; n < 2; n++) {
				if (n == 1 && route_pair <= 0.0) {
					break;
				}
				float apex = span + 0.02 + (n == 1 ? route_pair : 0.0);
				float e = (apex - d) - 0.685 * au;
				float in_x = 1.0 - smoothstep(half_w - soft, half_w, au);
				float tab_x = smoothstep(half_w, half_w + soft, au) * (1.0 - smoothstep(half_w + tab_w - soft, half_w + tab_w, au));
				float thick = smoothstep(0.0, soft, e) * (1.0 - smoothstep(t1 - soft, t1, e));
				float thin = smoothstep(t1 + g1, t1 + g1 + soft, e) * (1.0 - smoothstep(t1 + g1 + t2 - soft, t1 + g1 + t2, e));
				float tab = smoothstep(t1 + g1 + t2, t1 + g1 + t2 + soft, e) * (1.0 - smoothstep(t1 + g1 + t2 * 2.0 - soft, t1 + g1 + t2 * 2.0, e));
				band = max(band, max(thick, thin) * in_x + tab * tab_x);
			}
			// Far away an arrow is a few pixels across: let it go rather than shimmer.
			float calm = 1.0 - smoothstep(0.06, 0.16, fw);
			float ends = smoothstep(0.0, 0.6, route_start[i] + along);
			best = max(best, band * calm * ends);
		}
		float k = best * route_on;
		c = mix(c, route_color.rgb, k * 0.95);
		glow += route_color.rgb * k * route_glow;
	}
	if (path_on > 0.5) {
		float s = uvw.x;
		float vac = uvw.y * path_margin;
		vec2 p2 = local_pos.xz;
		float fws = max(fwidth(s), 0.0001);
		float soft = max(fws, 0.004);
		float sp = max(path_spacing, 0.05);
		float off = TIME * path_speed;
		float k = 0.0;
		if (path_style < 0.5) {
			// The chevron pair, measured in its own straight frame.
			float wdt = path_width * 0.9;
			float t1 = 0.2056 * wdt;
			float g1 = 0.0234 * wdt;
			float t2 = 0.0981 * wdt;
			float half_w = 0.4463 * wdt;
			float tab_w = 0.0537 * wdt;
			float span = 0.768 * wdt;
			float pair = path_pair;
			float mid = (span + 0.02 + pair * 0.5) - (t1 + g1 + t2 * 2.0 + 0.685 * half_w) * 0.5;
			float base = floor((s - off - mid) / sp);
			for (int j = -1; j <= 1; j++) {
				float sc = (base + float(j)) * sp + off + mid;
				vec2 fr = path_frame_ends(sc, p2);
				float d = fr.x + mid;
				float au = abs(fr.y);
				for (int n = 0; n < 2; n++) {
					if (n == 1 && pair <= 0.0) {
						break;
					}
					float apex = span + 0.02 + (n == 1 ? pair : 0.0);
					float e = (apex - d) - 0.685 * au;
					float in_x = 1.0 - smoothstep(half_w - soft, half_w, au);
					float tab_x = smoothstep(half_w, half_w + soft, au) * (1.0 - smoothstep(half_w + tab_w - soft, half_w + tab_w, au));
					float thick = smoothstep(0.0, soft, e) * (1.0 - smoothstep(t1 - soft, t1, e));
					float thin = smoothstep(t1 + g1, t1 + g1 + soft, e) * (1.0 - smoothstep(t1 + g1 + t2 - soft, t1 + g1 + t2, e));
					float tab = smoothstep(t1 + g1 + t2, t1 + g1 + t2 + soft, e) * (1.0 - smoothstep(t1 + g1 + t2 * 2.0 - soft, t1 + g1 + t2 * 2.0, e));
					k = max(k, max(thick, thin) * in_x + tab * tab_x);
				}
			}
		} else if (path_style < 1.5) {
			float z = fract((s + vac * path_width * 0.35 - off) / sp);
			float stripe = smoothstep(0.0, soft / sp * 2.0, z) * (1.0 - smoothstep(0.5 - soft / sp * 2.0, 0.5, z));
			k = stripe * (1.0 - smoothstep(0.82, 0.98, abs(vac)));
		} else if (path_style < 2.5) {
			// Square blocks, each in its own straight frame.
			float hs = path_width * 0.2;
			float base2 = floor((s - off) / sp);
			for (int j = -1; j <= 1; j++) {
				vec2 fr = path_frame_ends((base2 + float(j)) * sp + off + sp * 0.5, p2);
				float bx = 1.0 - smoothstep(hs - soft, hs + soft, abs(fr.x));
				float by = 1.0 - smoothstep(hs - soft, hs + soft, abs(fr.y));
				k = max(k, bx * by);
			}
		} else if (path_style < 3.5) {
			// A thin line, and solid balls running along it.
			float line = 1.0 - smoothstep(0.1, 0.1 + soft * 4.0, abs(vac));
			float r = path_width * 0.17;
			float base3 = floor((s - off) / sp);
			float ball = 0.0;
			for (int j = -1; j <= 1; j++) {
				vec2 fr = path_frame((base3 + float(j)) * sp + off + sp * 0.5, p2);
				ball = max(ball, 1.0 - smoothstep(r - soft, r + soft, length(fr)));
			}
			k = max(line, ball);
		} else {
			k = 1.0 - smoothstep(0.96, 1.0, abs(vac));
		}
		float calm = 1.0 - smoothstep(0.06, 0.16, fws);
		k = clamp(k, 0.0, 1.0) * calm;
		if (path_closed < 0.5) {
			// A fixed line across each end, straight, in the end's own frame; the marks slide under it:
			// whatever of them lies past the line's near edge is not drawn (Ramon, 5 Oct: "the arrows
			// should disappear like they're sliding under the line"). Only near the ends, so a path
			// that curls back past its own end is not cut elsewhere.
			float cap = path_cap;
			float hw = path_width * 0.5;
			float inside = 1.0;
			float bar = 0.0;
			if (s > path_length - 3.0) {
				vec2 fe = path_frame(path_length - cap * 0.5, p2);
				inside *= 1.0 - smoothstep(-cap * 0.5 - soft, -cap * 0.5, fe.x);
				bar = max(bar, (1.0 - smoothstep(cap * 0.5 - soft, cap * 0.5, abs(fe.x))) * (1.0 - smoothstep(hw - soft, hw, abs(fe.y))));
			}
			if (s < 3.0) {
				vec2 fs = path_frame(cap * 0.5, p2);
				inside *= smoothstep(cap * 0.5, cap * 0.5 + soft, fs.x);
				bar = max(bar, (1.0 - smoothstep(cap * 0.5 - soft, cap * 0.5, abs(fs.x))) * (1.0 - smoothstep(hw - soft, hw, abs(fs.y))));
			}
			k = max(k * inside, bar);
		}
		// Only the marks are drawn: the rest of the strip lets the floor through, so strips that
		// overlap at a crossroad never hide each other's marks.
		if (k < 0.02) {
			discard;
		}
		c = mix(c, path_color.rgb, k);
		glow += path_color.rgb * k * path_glow;
	}
	if (holo_on > 0.5) {
		float hf = clamp(local_pos.y / max(abs(surface_size.y), 0.001) + 0.5, 0.0, 1.0);
		float cover = holo_base * pow(1.0 - hf, holo_falloff);
		float scan = smoothstep(0.9, 1.0, fract(local_pos.y * holo_scan_density - TIME * holo_scan_speed));
		cover = min(1.0, cover + scan * holo_scan * (1.0 - hf));
		ivec2 cell = ivec2(FRAGCOORD.xy) % 4;
		int bayer[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
		float threshold = (float(bayer[cell.y * 4 + cell.x]) + 0.5) / 16.0;
		if (holo_fine > 0.5) {
			// The finer grain: per pixel, moving every frame, no repeating 4x4 pattern.
			vec2 gp = floor(FRAGCOORD.xy) + mod(floor(TIME * 60.0), 64.0) * 5.588238;
			threshold = fract(52.9829189 * fract(dot(gp, vec2(0.06711056, 0.00583715))));
		}
		if (cover <= threshold) {
			discard;
		}
		c = holo_color.rgb;
		glow = holo_color.rgb * (holo_glow + scan * 0.8);
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
