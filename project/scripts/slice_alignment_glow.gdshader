shader_type canvas_item;

// Full-screen slice-alignment glow: a green, edge-only vignette (not a
// full-screen tint) - transparent center, glowing border. Opacity is driven
// entirely from GDScript (slice_alignment_glow.gd) via the `intensity`
// uniform; this shader has no gameplay logic of its own.

uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.35, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float edge_thickness : hint_range(0.0, 0.5) = 0.18;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	// Chebyshev (box) distance, not radial - gives an even border hugging
	// all four edges of a non-square screen, rather than a circular glow
	// that would over-emphasize the corners or under-emphasize the middle
	// of each edge.
	float dist = max(abs(centered.x), abs(centered.y)) * 2.0;
	float edge_factor = smoothstep(1.0 - edge_thickness, 1.0, dist);
	COLOR = vec4(glow_color.rgb, glow_color.a * edge_factor * intensity);
}
