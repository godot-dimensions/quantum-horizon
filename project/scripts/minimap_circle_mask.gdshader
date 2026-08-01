shader_type canvas_item;

// Shooting gallery minimap: circular "orb" framing (element 5 of the
// requested minimap - NOT present in the godot_boids_4d reference, built
// net-new here). Applied as a material on MiniMapContainer: clips its
// SubViewport texture to a circle with a soft edge, plus a thin ring border.

uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 0.7);
uniform float ring_width : hint_range(0.0, 0.1) = 0.015;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	vec4 tex_color = texture(TEXTURE, UV);
	float inside_alpha = smoothstep(0.5, 0.485, dist);
	float ring_mask = smoothstep(0.5, 0.5 - ring_width, dist) - smoothstep(0.5 - ring_width, 0.5 - ring_width * 2.0, dist);
	vec3 final_rgb = mix(tex_color.rgb, ring_color.rgb, ring_mask * ring_color.a);
	COLOR = vec4(final_rgb, tex_color.a * inside_alpha);
}
