shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, unshaded;

// The smallest thing that shows foam_4d working: a flat plane at y = 0, painted with the
// foam field and nothing else. Unshaded on purpose - this is for looking at the PATTERN, so
// no lighting is allowed to flatter or hide it.
//
// It is also the reference for how to feed the module. The only thing that matters is the
// last argument to foam_4d: a point in the WORLD, in (x, z, w). Everything above it exists
// to work out what that point is for this pixel.

#include "res://shaders/foam_4d.gdshaderinc"

uniform vec4 cam_position;
uniform vec4 cam_basis_x;
uniform vec4 cam_basis_y;
uniform vec4 cam_basis_z;
// The two horizontal directions the slice can see, in (x, z, w).
uniform vec3 slice_axis_a;
uniform vec3 slice_axis_b;

uniform float foam_density = 0.45;
uniform float foam_cell_size = 0.90;
uniform float foam_time = 0.0;
uniform float plane_height = 0.0;

varying vec3 rest_world;


void vertex() {
	vec3 cam_h = vec3(cam_position.x, cam_position.z, cam_position.w);
	// The grid is laid out along the slice's own horizontal axes, so it stays flat however
	// the camera is pitched, and it is anchored to the world rather than to the camera.
	vec3 world_h = cam_h + VERTEX.x * slice_axis_a + VERTEX.z * slice_axis_b;
	rest_world = world_h;

	vec4 world = vec4(world_h.x, plane_height, world_h.y, world_h.z);
	vec4 rel = world - cam_position;
	VERTEX = vec3(dot(rel, cam_basis_x), dot(rel, cam_basis_y), dot(rel, cam_basis_z));
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}


void fragment() {
	float foam = foam_4d(rest_world, foam_density, foam_cell_size, foam_time);
	ALBEDO = vec3(foam);
}
