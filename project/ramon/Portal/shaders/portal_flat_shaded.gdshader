// Flat-shaded cross-section shader with an ambient floor, for the Portal scenes.
//
// A copy of PhaseMaze's flat-shaded variant with exactly one change, in
// fragment(). That shader's term is dot(normal, up) / 2 + 0.5, which maps a
// straight-down normal to ZERO - so every downward-facing surface renders pure
// black. Against a dark clear colour that is indistinguishable from a hole, and
// it caused a long hunt for "lost faces" and "clipping" that turned out to be
// geometry which was demonstrably solid to a raycast and merely unlit: the
// underside of a lip above an opening, a ceiling, the top edge of a cut.
//
// Here the same term is remapped into [AMBIENT_FLOOR, 1], so a downward face is
// dim but unmistakably a surface. Nothing else differs; the vertex stage must
// stay identical to the engine's, since it is what slices each tetrahedron.

shader_type spatial;
// cull_disabled is load-bearing, not a convenience.
//
// Dual contouring here still leaves a small fraction of hexahedra disagreeing
// about winding - voxel_port.md measures the residual at 0.44% after the
// per-hexahedron winding vote - and a backwards-wound triangle is culled as a
// back face. That is invisible head-on and appears as a face that blinks out of
// existence when you move to one side, which is exactly the "lost faces from an
// angle" this scene kept showing. Rendering both sides makes winding stop
// mattering: a mis-wound triangle draws correctly instead of vanishing.
//
// The cost is that back faces are shaded too, and that standing inside a solid
// shows its interior rather than nothing. Both are cheap next to hunting
// winding bugs in a contour we forked rather than wrote.
render_mode skip_vertex_transform, unshaded, cull_disabled;

// World space
// Not allowed to pass matrices through instance uniforms, so have to unpack into vectors.
instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform vec4 albedo : source_color;
uniform sampler3D albedo_texture : hint_default_white, source_color;

varying vec3 uvw;

// How dark a surface facing directly away from up is allowed to get.
const float AMBIENT_FLOOR = 0.42;

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
// Each triangle in the cross-section is made up of vertices that are interpolated along the edges of the tetrahedron,
// falling where the edge intersects the cross-section plane. So this table is 16x6, 16 cases, 6 possible verts,
// each value maps to an edge in the TETRAHEDRON_EDGE_TO_VERTEX_MAP. -1 indicates the vertex is unused for that case.
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
	if (CROSS_SECTION_LOOKUP[face] == -1) {
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
		vec3 tangent = normalize(face_v2 - face_v1);
		vec3 binormal = normalize(cross(normal, tangent));
		NORMAL = normal;
		TANGENT = tangent;
		BINORMAL = binormal;
	}
}

void fragment() {
	NORMAL = normalize(NORMAL);
	// Angle term remapped into [AMBIENT_FLOOR, 1] rather than [0, 1]. The
	// unmapped version renders anything facing straight down as pure black,
	// which reads as a hole rather than as a surface.
	float up_facing = (dot((vec4(NORMAL, 0.0) * INV_VIEW_MATRIX).xyz, vec3(0.0, 1.0, 0.0)) / 2.0) + 0.5;
	ALBEDO = albedo.rgb * texture(albedo_texture, uvw).rgb * mix(AMBIENT_FLOOR, 1.0, up_facing);
}
