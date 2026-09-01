// Tiling variant of the engine's tetrahedral cross-section shader.
//
// A copy of engine/modules/4d/render/cross_section/tetra_cross_section_shader.glsl
// with three deliberate deltas. The vertex stage MUST stay identical: it is what
// slices each tetrahedron to the current 3D cross-section, via the 16-case lookup
// on the sign of each corner's w. Reimplementing that is not an option.
//
//   1. `uv_scale`. The stock fragment stage samples `texture(albedo_texture, uvw)`
//      directly, so a texture maps exactly once across whatever the mesh's cell
//      texture map covers - one texture per side with FILL_EACH_SIDE, one across
//      the whole net with CROSS_ISLAND. There is no way to repeat it. Multiplying
//      uvw before the lookup is the only place a repeat can be introduced, and it
//      is why this fork exists: real tiling on ONE box, rather than a grid of
//      boxes each carrying a single copy.
//
//   2. `perpendicular_4d` is inlined. The engine file reaches it through
//      `#include "../shaders/perpendicular_4d.glsl"`, a module-relative path that
//      does not resolve from res://. skybox_sky.gdshader and
//      phase_maze_flat_shaded.gdshader sidestep this by being `unshaded`, which
//      drops the 4D normal entirely - but a floor wants light, so the eight-line
//      function is copied in verbatim instead.
//
//   3. `light()` is carried across from tetra_cross_section_light_shader.glsl,
//      which the engine APPENDS to its own shader source at build time. A fork
//      never receives that append. Without it this surface would silently render
//      unlit while every un-forked surface around it was shaded - the same trap
//      that flattened the clouds when the stock angle-based term was removed.
//
// The texture must have repeat enabled for tiling to show; a Texture3D imported
// with repeat off will clamp and the surface will look stretched instead.

shader_type spatial;
render_mode skip_vertex_transform;

// World space
// Not allowed to pass matrices through instance uniforms, so have to unpack into vectors.
instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform vec4 albedo : source_color;
uniform sampler3D albedo_texture : hint_default_white, source_color, filter_linear_mipmap, repeat_enable;

// The box's full size in metres, and how many metres one texture should cover.
//
// A single scale vector cannot texture a box consistently, because each of a 4D
// box's eight cells spans a DIFFERENT three of the four axes: the +Y cell spans
// x/z/w, the +X cell spans y/z/w, and so on. Scaling every cell by the same
// vector is only correct for whichever face you happened to tune it for - fine
// for a floor you only ever see the top of, wrong the moment the surface is a
// pillar you walk past the side of.
//
// So the size goes in whole and the fragment stage picks the right three
// components per cell, using normal_4d to tell which cell it is on. That makes
// one texture cover texture_metres on EVERY face of every box regardless of its
// proportions, which is the only way a shared texture scale reads as consistent
// across a scene.
uniform vec4 surface_size = vec4(1.0, 1.0, 1.0, 1.0);
uniform float texture_metres = 1.0;

// Shifts the tiling within each tile, in texture widths.
//
// The dev textures carry their grid lines through the MIDDLE of the image, so
// tiling them straight puts a cross in the centre of every tile and only quarter
// lines at the seams. Half a tile of offset moves those centre lines onto the
// tile boundaries, where adjacent tiles line up into one continuous grid - which
// is what a grid texture is usually drawn expecting.
// MEASURED, not assumed: 0.5 does not shift the grid onto the seams, it removes
// the lines altogether. So the relationship between this and where the lines land
// is not the simple one the comment above assumes - left at 0 until it is worked
// out against a render rather than reasoned about.
uniform float texture_offset = 0.0;

varying vec3 uvw;
// Flat shading currently computes this from the transformed cell positions. Future smooth shading
// can interpolate transformed 4D vertex normals into the same varying without changing light().
varying vec4 normal_4d;

// Inlined from render/shaders/perpendicular_4d.glsl - see note 2 above.
// The 4D equivalent of a 3D cross product: returns a vector perpendicular to all three inputs.
vec4 perpendicular_4d(vec4 a, vec4 b, vec4 c) {
	return vec4(
			-a.y * (b.z * c.w - b.w * c.z) + a.z * (b.y * c.w - b.w * c.y) - a.w * (b.y * c.z - b.z * c.y),
			+a.x * (b.z * c.w - b.w * c.z) - a.z * (b.x * c.w - b.w * c.x) + a.w * (b.x * c.z - b.z * c.x),
			-a.x * (b.y * c.w - b.w * c.y) + a.y * (b.x * c.w - b.w * c.x) - a.w * (b.x * c.y - b.y * c.x),
			+a.x * (b.y * c.z - b.z * c.y) - a.y * (b.x * c.z - b.z * c.x) + a.z * (b.x * c.y - b.y * c.x));
}

// Maps from an arbitrary edge index to the indices of the vertices in a tetrahedron [a,b,c,d].
const int TETRAHEDRON_EDGE_TO_VERTEX_MAP[] = {
	0, 1,
	0, 2,
	0, 3,
	1, 2,
	1, 3,
	2, 3
};
// 16 cases for number of vertices above and below the cross-section plane, each case leads to at most two triangles for 6 vertices.
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
	// Bitwise ops limit compatibility so summing instead.
	int negative1 = w1 < 0.0 ? 1 : 0;
	int negative2 = w2 < 0.0 ? 2 : 0;
	int negative3 = w3 < 0.0 ? 4 : 0;
	int negative4 = w4 < 0.0 ? 8 : 0;
	int lookup_index = negative1 + negative2 + negative3 + negative4;

	// First index in the group of three that the indicated vertex belongs to.
	return (lookup_index * 6) + vertex_id - (vertex_id % 3);
}

vec3 slice_edge(vec4 v1, vec4 v2) {
	float mix_weight = v1.w / (v1.w - v2.w);
	return mix(v1, v2, mix_weight).xyz;
}

void vertex() {
	mat4 modelview_basis = mat4(modelview_basis_x, modelview_basis_y, modelview_basis_z, modelview_basis_w);

	vec4 verts[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	verts[0] = (modelview_basis * verts[0]) + modelview_origin;
	verts[1] = (modelview_basis * verts[1]) + modelview_origin;
	verts[2] = (modelview_basis * verts[2]) + modelview_origin;
	verts[3] = (modelview_basis * verts[3]) + modelview_origin;

	vec3 uvws[] = { vec3(UV, COLOR.a), vec3(UV2, VERTEX.y), vec3(NORMAL.xy / NORMAL.z, VERTEX.z), COLOR.rgb };

	int vertex_id = int(VERTEX.x);
	int face = get_face_lookup_index(verts[0].w, verts[1].w, verts[2].w, verts[3].w, vertex_id);
	normal_4d = vec4(0.0, 0.0, 1.0, 0.0);
	// vertex_id >= 6 is a cull condition added upstream: a tetrahedron
	// cross-section is at most a quad, so anything past six vertices is
	// surplus. Without this test those vertices survive with undefined
	// positions and stray geometry appears in the slice.
	if (vertex_id >= 6 || CROSS_SECTION_LOOKUP[face] == -1) {
		// This vertex is unused, cull
		POSITION = vec4(0.0, 0.0, CLIP_SPACE_FAR, 1.0);
	} else {
		int position_edge = CROSS_SECTION_LOOKUP[face + (vertex_id % 3)];
		int edge_vert1 = TETRAHEDRON_EDGE_TO_VERTEX_MAP[position_edge * 2];
		int edge_vert2 = TETRAHEDRON_EDGE_TO_VERTEX_MAP[(position_edge * 2) + 1];
		vec4 position1 = verts[edge_vert1];
		vec4 position2 = verts[edge_vert2];
		float mix_weight = position1.w / (position1.w - position2.w);
		vec4 position = mix(position1, position2, mix_weight);
		// Vertex is view space and used for lighting, position is clip space and used for rasterizing.
		VERTEX = position.xyz;
		POSITION = PROJECTION_MATRIX * vec4(position.xyz, 1.0);

		uvw = mix(uvws[edge_vert1], uvws[edge_vert2], mix_weight);

		// Compute flat normals.
		int face_v1_edge = CROSS_SECTION_LOOKUP[face];
		int face_v2_edge = CROSS_SECTION_LOOKUP[face + 1];
		int face_v3_edge = CROSS_SECTION_LOOKUP[face + 2];
		vec3 face_v1 = slice_edge(verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v1_edge * 2]], verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v1_edge * 2 + 1]]);
		vec3 face_v2 = slice_edge(verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v2_edge * 2]], verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v2_edge * 2 + 1]]);
		vec3 face_v3 = slice_edge(verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v3_edge * 2]], verts[TETRAHEDRON_EDGE_TO_VERTEX_MAP[face_v3_edge * 2 + 1]]);
		vec3 normal = normalize(cross(face_v3 - face_v1, face_v2 - face_v1));
		vec4 cell_normal_4d = perpendicular_4d(verts[1] - verts[0], verts[2] - verts[0], verts[3] - verts[0]);
		float cell_normal_length = length(cell_normal_4d);
		if (cell_normal_length > 0.0) {
			cell_normal_4d /= cell_normal_length;
			// Keep the 4D normal's orientation consistent with the generated triangle winding.
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

// Picks the three box dimensions that a cell actually spans, from its normal.
// With FILL_EACH_SIDE a cell's uvw runs 0..1 across the three axes that are not
// its normal, in x/y/z/w order - so the +Y cell's uvw maps to (x, z, w).
vec3 cell_extent(vec4 n, vec4 s) {
	vec4 a = abs(n);
	if (a.x >= a.y && a.x >= a.z && a.x >= a.w) {
		return vec3(s.y, s.z, s.w);
	}
	if (a.y >= a.z && a.y >= a.w) {
		return vec3(s.x, s.z, s.w);
	}
	if (a.z >= a.w) {
		return vec3(s.x, s.y, s.w);
	}
	return vec3(s.x, s.y, s.z);
}

void fragment() {
	NORMAL = normalize(NORMAL);
	// The one functional change: repeat the texture at a fixed world scale
	// instead of stretching one copy across each side.
	vec3 tiles = cell_extent(normal_4d, abs(surface_size)) / max(texture_metres, 0.0001);
	ALBEDO = albedo.rgb * texture(albedo_texture, uvw * tiles + vec3(texture_offset)).rgb;
}

// Carried over from tetra_cross_section_light_shader.glsl - see note 3 above.
void light() {
	float slice_component = clamp(LIGHT_SLICE_COMPONENT, -1.0, 1.0);
	float light_xyz_component = sqrt(max(1.0 - slice_component * slice_component, 0.0));
	vec4 light_direction_4d = vec4(LIGHT * light_xyz_component, slice_component);
	float normal_dot_light = max(dot(normalize(normal_4d), light_direction_4d), 0.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * normal_dot_light;
}
