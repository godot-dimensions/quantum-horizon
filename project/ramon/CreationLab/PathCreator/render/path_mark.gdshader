// PathCreator: the path's marks on the floor, drawn as vectors (CreationLab/PathCreator/PLAN.md).
//
// Every mark is the Figma sheet's own outline: path_symbols.gd packs each symbol master (an SVG)
// into straight segments in three small float textures, and this shader measures, for each pixel,
// the exact distance to those outlines (and the winding, for fills) in sheet units, so a mark is as
// sharp from a metre as from thirty, and antialiased by its own distance against the pixel's size.
// No pictures, so nothing goes soft up close.
//
// One shader, four jobs, by `mode`, each on a thin flat 4D box laid on the floor (path_network_4d.gd):
//   0 SEGMENT  a straight stretch of route along the box's x: the guide line along its middle, the
//              route's mark repeated every `repeat_m` by cumulative arc length (`s0` is the route's
//              length at this box's start), flowing at `flow` m/s. Marks slide under the keep-clear
//              ends (`clear0`, `clear1`) and vanish there, the sheet's "segments stop short of the
//              ball"; `gap0` breaks the marks where a stronger route crosses without a node.
//   1 NODE     one symbol in the middle of the box: a destination in its state (the arc turning once
//              in `ARC_TURN_S`, the accent and cyan when focused), or a junction.
//   2 PIVOT    a bend's ball and ring, or a curve's small ball (the B1 field map's own pivots).
//   3 FRAME    an object's frame (slot H or I) grown to the footprint without growing its strokes:
//              the plane is folded so the symbol's straight middles stretch and its corners only
//              move; an opening is cut toward the approach.
//   4 SAND     the pen's sand under the marks (6 Oct 2026): a strip as wide as the box, its edges
//              broken by noise that runs on unbroken from stretch to stretch (`s0` + along), or a
//              round patch at a node (`sand_round`); speckled, lit like the ground. Its edge is
//              dithered, not blended: a pixel is all sand or not drawn, by a 5 cm grain. The
//              cross-section is opaque, so a soft edge mixes toward the floor's colour even where
//              another strip's sand lies beneath it, and the joints showed dark seams. The W band
//              and the reveal thin the sand out grain by grain the same way.
//
// REVEAL (6 Oct 2026): with `reveal_on`, a stretch shows only its found part, `found0` to `found1`
// metres along it, fading over `reveal_fade` at each end; a node's box shows as `found` (0 to 1).
//
// W: the box is as deep in W as the route is visible (its band). Over `w_soft` at the band's edges the
// marks shrink to nothing, so a route recedes as you slice out of it rather than being cut off.
//
// LOOKS: `walk` paints every role in the one sand (the WALK look for the pen); otherwise each role
// keeps the sheet's token. Edges are blended toward `under_color` (the floor's own albedo, the
// cross-section being opaque); `scissor` instead cuts at half coverage, for grounds of many colours.
//
// The vertex stage and light() are the engine's, copied from LabKit/shaders/lab_surface.gdshader
// (which says why they must stay identical to engine/modules/4d's cross-section shader).

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

// The symbol libraries (path_symbols.gd).
uniform sampler2D seg_tex : filter_nearest, repeat_disable;
uniform sampler2D segcap_tex : filter_nearest, repeat_disable;
uniform sampler2D shape_tex : filter_nearest, repeat_disable;
uniform sampler2D sym_tex : filter_nearest, repeat_disable;
const int SEG_W = 1024;
const int SHAPE_W = 256;
const int SYM_W = 64;

uniform int mode = 0;
uniform vec4 box_size = vec4(1.0);
uniform float unit_m = 0.015;

// SEGMENT
uniform int mark_sym = -1;
uniform float mark_scale = 1.0;
uniform float repeat_m = 1.2;
uniform float s0 = 0.0;
uniform float clear0 = 0.0;
uniform float clear1 = 0.0;
// JOINTS: an end at a chord the route runs on through. There a mark is never cut: it is drawn
// whole by the stretch that holds its middle, reaching past the joint over the ball (the box is
// `ext0` / `ext1` longer at that end), so it turns as it moves on rather than breaking in two.
// `mark_half` is how far a mark reaches either side of its middle, metres.
uniform float join0 = 0.0;
uniform float join1 = 0.0;
uniform float ext0 = 0.0;
uniform float ext1 = 0.0;
uniform float mark_half = 0.2;
// DRAPED RUNS: an end where the ground steps (a riser). A mark never crosses it: nearing the edge
// it shrinks about its own middle (as at a W band's edge) and the next run's grows back beyond it,
// so the marks keep moving and nothing hangs over a step or is cut by one.
uniform float drop0 = 0.0;
uniform float drop1 = 0.0;
uniform float flow = 0.55;
uniform vec4 gap0 = vec4(-1.0, -1.0, -1.0, -1.0);
uniform float guide_on = 1.0;
uniform float guide_w = 0.035;
// 0: a solid guide line; otherwise dots this far apart (the secondary route's, as the field map).
uniform float guide_dot = 0.0;
// The guide's own light blue (path_spec.gd GUIDE_COLOR); sand in the WALK look.
uniform vec4 col_guide : source_color = vec4(0.435, 0.651, 0.949, 1.0);

// NODE
uniform int node_sym = -1;
uniform float node_scale = 1.0;
uniform float arc_on = 1.0;
uniform float accent_on = 1.0;
uniform float focus = 0.0;
uniform float arc_turn_s = 6.0;

// PIVOT (metres)
uniform float ring_on = 1.0;
uniform float ball_r = 0.075;
uniform float ring_r = 0.135;
uniform float ring_w = 0.0225;

// W CUE: a row of dots to the node's east, `w_step` metres of W to go (+ ana, - kata), starting
// `cue_from` sheet units from its middle.
uniform float w_step = 0.0;
uniform float cue_from = 10.0;
uniform vec4 cue_ana : source_color = vec4(1.0, 0.6, 0.22, 1.0);
uniform vec4 cue_kata : source_color = vec4(0.34, 0.6, 1.0, 1.0);
uniform float cue_dot_r = 2.4;
uniform float cue_gap = 7.0;

// FRAME (sheet units)
uniform int frame_sym = -1;
uniform vec2 frame_grow = vec2(0.0);
uniform float frame_round = 0.0;
uniform vec3 approach = vec3(0.0, 1.0, 0.0);

// LOOKS
uniform vec4 col_blue : source_color = vec4(0.090, 0.380, 0.843, 1.0);
uniform vec4 col_cyan : source_color = vec4(0.286, 0.851, 1.0, 1.0);
uniform vec4 col_edge : source_color = vec4(0.400, 0.545, 0.682, 1.0);
uniform vec4 col_muted : source_color = vec4(0.557, 0.667, 0.784, 1.0);
uniform vec4 under_color : source_color = vec4(1.0);
uniform vec4 sand : source_color = vec4(0.804, 0.706, 0.549, 1.0);
uniform float walk = 0.0;
// DEV: the marks are the sheet's own colours, not lit (a lit mark on a sunlit floor washes out to
// sky blue), `ink_gain` setting how bright they come out through the room's exposure and tone map
// (measured: _probe_colour_runner.gd). WALK: lit like paint on the ground.
uniform float ink_gain = 1.0;
uniform float motion = 1.0;
uniform float scissor = 0.0;

// SAND
uniform float sand_round = 0.0;
uniform float sand_rough = 0.18;

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

vec4 tfetch(sampler2D t, int i, int w) {
	return texelFetch(t, ivec2(i % w, i / w), 0);
}

vec3 role_color(int role) {
	if (role == 4) {
		return under_color.rgb;
	}
	if (walk > 0.5) {
		return sand.rgb;
	}
	if (role == 1) {
		return col_cyan.rgb;
	}
	if (role == 2) {
		return col_edge.rgb;
	}
	if (role == 3) {
		return col_muted.rgb;
	}
	return col_blue.rgb;
}

mat2 rot(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

// Coverage `c` of colour `col` laid over what is there (rgb, coverage).
vec4 over(vec4 below, vec3 col, float c) {
	float a = c + below.a * (1.0 - c);
	vec3 rgb = a > 0.0 ? (col * c + below.rgb * below.a * (1.0 - c)) / a : below.rgb;
	return vec4(rgb, a);
}

// Symbol `sym` at `p` (sheet units, its middle at 0, y down): its colour and coverage. `px` is a
// pixel in sheet units, `erode` thins every shape by that much (the W band's edge), `arc` turns the
// moving arc (radians), `show_arc` / `show_accent` hide those layers, `to_cyan` blends the moving
// layers toward cyan (focus).
vec4 draw_symbol(int sym, vec2 p, float px, float erode, float arc, float show_arc, float show_accent, float to_cyan) {
	vec4 out_col = vec4(0.0);
	if (sym < 0) {
		return out_col;
	}
	vec4 h0 = tfetch(sym_tex, sym * 2, SYM_W);
	vec4 h1 = tfetch(sym_tex, sym * 2 + 1, SYM_W);
	if (length(p) > h1.x + 2.0 * px) {
		return out_col;
	}
	int first = int(h0.x);
	int count = int(h0.y);
	for (int i = 0; i < count; i++) {
		vec4 a = tfetch(shape_tex, (first + i) * 2, SHAPE_W);
		vec4 b = tfetch(shape_tex, (first + i) * 2 + 1, SHAPE_W);
		int layer = int(b.x + 0.5);
		if (layer == 1 && show_arc < 0.5) {
			continue;
		}
		if (layer == 2 && show_accent < 0.5) {
			continue;
		}
		vec2 q = layer == 1 ? rot(arc) * p : p;
		float d = 1e9;
		float wind = 0.0;
		float crossings = 0.0;
		int k0 = int(a.x);
		int kn = int(a.y);
		for (int k = 0; k < kn; k++) {
			vec4 sg = tfetch(seg_tex, k0 + k, SEG_W);
			vec2 A = sg.xy;
			vec2 B = sg.zw;
			vec2 pa = q - A;
			vec2 ba = B - A;
			float t_raw = dot(pa, ba) / max(dot(ba, ba), 1e-9);
			float t = clamp(t_raw, 0.0, 1.0);
			bool cut = false;
			if (a.z > 1.5) {
				// Flat (butt) caps: nothing of the run beyond the plane at either open end.
				vec4 c0 = tfetch(segcap_tex, (k0 + k) * 2, SEG_W);
				vec4 c1 = tfetch(segcap_tex, (k0 + k) * 2 + 1, SEG_W);
				cut = (dot(c0.zw, c0.zw) > 0.5 && dot(q - c0.xy, c0.zw) > 0.0) || (dot(c1.zw, c1.zw) > 0.5 && dot(q - c1.xy, c1.zw) > 0.0);
			}
			if (!cut) {
				d = min(d, length(pa - ba * t));
			}
			if (a.z < 1.5 && ((A.y > q.y) != (B.y > q.y))) {
				float x_at = A.x + (q.y - A.y) * (B.x - A.x) / (B.y - A.y);
				if (x_at > q.x) {
					crossings += 1.0;
					wind += B.y > A.y ? 1.0 : -1.0;
				}
			}
		}
		float sd;
		if (a.z > 1.5) {
			sd = d - a.w * 0.5;
		} else {
			bool inside = a.z < 0.5 ? (abs(wind) > 0.5) : (mod(crossings, 2.0) > 0.5);
			sd = inside ? -d : d;
		}
		sd += erode;
		float c = clamp(0.5 - sd / max(px, 1e-5), 0.0, 1.0);
		if (c <= 0.0) {
			continue;
		}
		vec3 col = role_color(int(b.y + 0.5));
		if (layer > 0 && walk < 0.5) {
			col = mix(col, col_cyan.rgb, to_cyan);
		}
		out_col = over(out_col, col, c);
	}
	return out_col;
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

float disc(vec2 p, float r, float px) {
	return clamp(0.5 - (length(p) - r) / max(px, 1e-5), 0.0, 1.0);
}

float ring(vec2 p, float r, float w, float px) {
	return clamp(0.5 - (abs(length(p) - r) - w * 0.5) / max(px, 1e-5), 0.0, 1.0);
}

void fragment() {
	NORMAL = normalize(NORMAL);
	// Only the box's top shows marks; its thin sides and W faces stay bare.
	if (local_normal_4d.y < 0.5) {
		discard;
	}
	// The W band: full inside, thinning to nothing over its soft edge.
	float wd = abs(local_pos.w);
	float band = 1.0 - smoothstep(w_half - w_soft, w_half, wd);
	if (band <= 0.0) {
		discard;
	}
	vec2 m = vec2(local_pos.x, local_pos.z);
	vec4 col = vec4(0.0);
	float px_m = max(length(fwidth(m)) * 0.7, 1e-5);
	// Toward the band's edge a mark shrinks about its own middle (to a quarter, then gone).
	float shrink = mix(0.25, 1.0, band);
	float erode_m = 0.0;
	if (mode == 0) {
		// `along` from the segment's start; the box may reach past either end at a joint.
		float L = box_size.x - ext0 - ext1;
		float along = m.x + box_size.x * 0.5 - ext0;
		bool past = along < 0.0 || along > L;
		bool in_clear = (join0 < 0.5 && along < clear0) || (join1 < 0.5 && along > L - clear1);
		bool in_gap = (along > gap0.x && along < gap0.y) || (along > gap0.z && along < gap0.w);
		// The nearest mark's middle, and whether it is this stretch's to draw.
		float s = s0 + along;
		float phase = mod(TIME * flow * motion, repeat_m);
		float c_s = floor((s - phase) / repeat_m + 0.5) * repeat_m + phase;
		float lc = c_s - s0;
		bool by_neighbour = (join0 > 0.5 && lc < 0.0) || (join1 > 0.5 && lc >= L);
		float riser = 1.0;
		if (drop0 > 0.5) {
			riser = min(riser, lc / mark_half);
		}
		if (drop1 > 0.5) {
			riser = min(riser, (L - lc) / mark_half);
		}
		riser = clamp(riser, 0.0, 1.0);
		bool mine = !by_neighbour && riser > 0.2;
		// The guide runs under the marks: it gives way along each drawn mark's whole length (a
		// little more), so it never shows through a chevron's gaps and reads as passing beneath. That
		// also keeps it off a neighbour's mark reaching over a joint (the two boxes lie at one height
		// and would fight for the pixel). It stops short of the nodes' art by their clear floor.
		bool mark_drawn = mark_sym >= 0 && !in_clear && !in_gap && (mine || by_neighbour);
		float cut = mark_half * shrink * (mine ? riser : 1.0);
		bool under_mark = mark_drawn && abs(s - c_s) < cut;
		if (guide_on > 0.5 && !in_clear && !in_gap && !past && !under_mark) {
			float g;
			if (guide_dot > 0.0) {
				float sd = s0 + along;
				vec2 q = vec2(sd - (floor(sd / guide_dot) + 0.5) * guide_dot, m.y);
				g = clamp(0.5 - (length(q) - guide_w * 0.6 * band) / px_m, 0.0, 1.0);
			} else {
				g = clamp(0.5 - (abs(m.y) - guide_w * 0.5 * band) / px_m, 0.0, 1.0);
			}
			col = over(col, walk > 0.5 ? sand.rgb : col_guide.rgb, g);
		}
		if (mark_sym >= 0 && !in_clear && !in_gap && mine) {
			vec2 p = vec2(s - c_s, m.y) / (unit_m * mark_scale * shrink * riser);
			float px = px_m / (unit_m * mark_scale * shrink * riser);
			vec4 mk = draw_symbol(mark_sym, p, px, erode_m / (unit_m * mark_scale), 0.0, 0.0, 0.0, 0.0);
			col = over(col, mk.rgb, mk.a);
		}
	} else if (mode == 1) {
		vec2 p = m / (unit_m * node_scale * shrink);
		float px = px_m / (unit_m * node_scale * shrink);
		float a = -TAU * TIME * motion / max(arc_turn_s, 0.01);
		col = draw_symbol(node_sym, p, px, erode_m / (unit_m * node_scale), a, arc_on, accent_on, focus);
	} else if (mode == 2) {
		vec3 b = role_color(0);
		col = over(col, b, disc(m, ball_r * shrink, px_m));
		if (ring_on > 0.5) {
			col = over(col, b, ring(m, ring_r * shrink, ring_w * shrink, px_m));
		}
	} else if (mode == 3) {
		vec2 p = m / unit_m;
		float px = px_m / unit_m;
		vec2 q;
		if (frame_round > 0.5) {
			float r = length(p);
			q = r > 1e-4 ? p / r * max(r - frame_grow.x, 0.0) : p;
		} else {
			q = p - clamp(p, -frame_grow, frame_grow);
		}
		// The opening toward the approach: no frame within half the gap of the approach line.
		vec2 ad = normalize(approach.xy + vec2(1e-6));
		float across_ap = abs(dot(p, vec2(-ad.y, ad.x)));
		if (approach.z > 0.0 && dot(p, ad) > 0.0 && across_ap < approach.z * 0.5) {
			discard;
		}
		col = draw_symbol(frame_sym, q, px, erode_m / unit_m, 0.0, 1.0, 1.0, 0.0);
	} else if (mode == 4) {
		float hw = box_size.z * 0.5;
		float d;
		if (sand_round > 0.5) {
			float ang = atan(m.y, m.x);
			float rr = hw * (1.0 + sand_rough * (0.6 * vnoise(ang * 2.5 + s0) + 0.4 * vnoise(ang * 6.0 + s0 * 1.7)));
			d = length(m) - rr;
		} else {
			float sx = s0 + m.x + box_size.x * 0.5;
			float rr = hw * (1.0 + sand_rough * (0.6 * vnoise(sx * 0.9) + 0.4 * vnoise(sx * 2.7 + 13.0)));
			d = abs(m.y) - rr;
		}
		float cov = (1.0 - smoothstep(-0.12, 0.03, d)) * band;
		if (reveal_on > 0.5) {
			float vis = found;
			if (sand_round < 0.5) {
				float al = m.x + box_size.x * 0.5;
				vis = clamp(min((al - (found0 - reveal_fade)) / reveal_fade, ((found1 + reveal_fade) - al) / reveal_fade), 0.0, 1.0);
			}
			cov *= vis;
		}
		vec2 grain_at = floor((m + vec2(s0, 0.0)) * 20.0);
		if (cov < 0.02 + 0.96 * hash2(grain_at + vec2(17.0, 3.0))) {
			discard;
		}
		float speck = hash2(floor((m + vec2(s0, 0.0)) * 9.0));
		col = vec4(sand.rgb * (0.9 + 0.16 * speck), 1.0);
	}
	if (abs(w_step) > 0.25 && (mode == 1 || mode == 2)) {
		// The W cue: dots in a row east of the node, one a metre of W, warm ana, cool kata.
		float n = min(round(abs(w_step)), 4.0);
		vec2 pc = m / unit_m;
		float pxu = px_m / unit_m;
		vec3 cc = walk > 0.5 ? sand.rgb : (w_step > 0.0 ? cue_ana.rgb : cue_kata.rgb);
		for (float i = 0.0; i < 4.0; i += 1.0) {
			if (i >= max(n, 1.0)) {
				break;
			}
			vec2 c = vec2(cue_from + cue_gap * (i + 0.5), 0.0);
			col = over(col, cc, disc(pc - c, cue_dot_r * shrink, pxu));
		}
	}
	if (reveal_on > 0.5 && mode != 4) {
		float vis = found;
		if (mode == 0) {
			float al = m.x + box_size.x * 0.5 - (mode == 0 ? ext0 : 0.0);
			vis = clamp(min((al - (found0 - reveal_fade)) / reveal_fade, ((found1 + reveal_fade) - al) / reveal_fade), 0.0, 1.0);
		}
		col.a *= vis;
	}
	if (col.a < (scissor > 0.5 ? 0.5 : 0.01)) {
		discard;
	}
	float a = scissor > 0.5 ? 1.0 : col.a;
	if (walk > 0.5 || mode == 4) {
		ALBEDO = mix(under_color.rgb, col.rgb, a);
	} else {
		// The mark's own colour, emitted; its antialiased edge blends into the lit floor beneath.
		// Floor-coloured fills (role 4) are lit as the floor is, not emitted.
		float floorish = 1.0 - step(0.02, distance(col.rgb, under_color.rgb));
		ALBEDO = under_color.rgb * (1.0 - a) + under_color.rgb * a * floorish;
		EMISSION = col.rgb * ink_gain * a * (1.0 - floorish);
	}
}

void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	float normal_dot_light = max(dot(normalize(normal_4d), light_direction_4d), 0.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * normal_dot_light;
}
