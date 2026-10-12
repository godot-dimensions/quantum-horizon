// The Dream Shifter's crystal (discovery/dream_shifter/pen_dream_shifter_4d.gd): a faceted glow. Unshaded, as the lab
// kit's glow is (CreationLab/LabKit/shaders/lab_glow.gdshader), because the cross-section renderer has no emission or
// bloom and only an unshaded surface reads as giving off light. What makes it a crystal rather than a flat blob of
// colour: every facet of the cut is shaded by which way it faces (its normal from the screen-space derivatives of the
// cut's own surface, so flat per facet), bright at the rims where it turns away from you, and a slow band of light
// runs up through it. The cut itself changes as the 24-cell turns through W, so the facets come and go.
//
// The vertex stage is the engine's, copied as of godot-4d da3586b (lab_surface.gdshader says why it must stay identical).

shader_type spatial;
render_mode skip_vertex_transform, unshaded;

instance uniform vec4 modelview_origin;
instance uniform vec4 modelview_basis_x;
instance uniform vec4 modelview_basis_y;
instance uniform vec4 modelview_basis_z;
instance uniform vec4 modelview_basis_w;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler3D albedo_texture : hint_default_white, source_color;
uniform vec3 albedo_texture_map_offset = vec3(0.0);
uniform vec3 albedo_texture_map_scale = vec3(1.0);

// The crystal's deep colour (facets facing you), its rim colour, and how bright it all is (the awake and flaring states
// raise it from pen_dream_shifter_4d.gd).
uniform vec4 core_color : source_color = vec4(0.18, 0.36, 0.95, 1.0);
uniform vec4 rim_color : source_color = vec4(0.70, 0.96, 1.0, 1.0);
uniform float energy = 1.0;
// 0..1: the rising band of light, as a share of the band's travel (driven from the script, so it can sweep on a flare).
uniform float band = 0.0;

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

varying vec3 world_up;

int get_face_lookup_index(float w1, float w2, float w3, float w4, int vertex_id) {
	int negative1 = w1 < 0.0 ? 1 : 0;
	int negative2 = w2 < 0.0 ? 2 : 0;
	int negative3 = w3 < 0.0 ? 4 : 0;
	int negative4 = w4 < 0.0 ? 8 : 0;
	int lookup_index = negative1 + negative2 + negative3 + negative4;
	return (lookup_index * 6) + vertex_id - (vertex_id % 3);
}

void vertex() {
	mat4 modelview_basis_4d = mat4(modelview_basis_x, modelview_basis_y, modelview_basis_z, modelview_basis_w);
	vec4 verts_4d[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
	verts_4d[0] = (modelview_basis_4d * verts_4d[0]) + modelview_origin;
	verts_4d[1] = (modelview_basis_4d * verts_4d[1]) + modelview_origin;
	verts_4d[2] = (modelview_basis_4d * verts_4d[2]) + modelview_origin;
	verts_4d[3] = (modelview_basis_4d * verts_4d[3]) + modelview_origin;

	int vertex_id = int(VERTEX.x);
	int face = get_face_lookup_index(verts_4d[0].w, verts_4d[1].w, verts_4d[2].w, verts_4d[3].w, vertex_id);
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
	}
	// The world's up in view space, for the band of light (it rises with the world, not the screen).
	world_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	// Flat per facet: the cut's surface normal from how VERTEX changes across the pixel.
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	vec3 v = normalize(-VERTEX);
	if (dot(n, v) < 0.0) {
		n = -n;
	}
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.2);
	// Each facet a little different, by the way it faces: a crystal's broken light.
	float facet = fract(sin(dot(floor(n * 3.0 + 0.5), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	vec3 colour = mix(core_color.rgb, rim_color.rgb, clamp(rim * 1.25 + facet * 0.22, 0.0, 1.0));
	// The band: a soft line of light at a height through the cut that the script sweeps upward.
	float h = dot(VERTEX - (VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz, world_up);
	float line = smoothstep(0.12, 0.0, abs(fract(h * 1.6 - band) - 0.5) - 0.38);
	colour += rim_color.rgb * line * 0.35;
	ALBEDO = colour * energy;
}
