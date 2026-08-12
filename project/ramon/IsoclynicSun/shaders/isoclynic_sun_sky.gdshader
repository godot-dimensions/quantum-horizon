shader_type sky;

// Minimal procedural sky. sun_direction/sun_energy/sky_ramp are pushed every
// frame (or on change) by sun_4d.gd - this shader has no opinion on 4D at
// all, it just draws whatever apparent 3D direction/energy/ramp it's told
// (see sun_4d.gd for how those are derived from the authoritative
// sun_direction_4d and sky_gradient).

// A GradientTexture1D generated from sun_4d.gd's exported sky_gradient.
// Sampled by height: x=0.0 is straight down, x=0.5 is the horizon, x=1.0 is
// straight up - edit the ramp's stops in the Inspector, no shader edits
// needed to restyle the sky.
uniform sampler2D sky_ramp : source_color, hint_default_black;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_energy = 1.0;
uniform float sun_angular_size = 0.03;

void sky() {
	float ramp_pos = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 base = texture(sky_ramp, vec2(ramp_pos, 0.5)).rgb;

	vec3 sun_dir_n = normalize(sun_direction);
	float sun_dot = dot(EYEDIR, sun_dir_n);
	float sun_disc = smoothstep(cos(sun_angular_size * 2.0), cos(sun_angular_size), sun_dot);
	float sun_glow = pow(clamp(sun_dot, 0.0, 1.0), 64.0) * 0.5;

	COLOR = base + sun_color * sun_energy * (sun_disc + sun_glow);
}
