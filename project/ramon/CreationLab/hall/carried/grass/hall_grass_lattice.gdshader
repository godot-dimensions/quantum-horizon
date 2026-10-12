// CREATURE LAB, THE HALL: CARRIED 10 Oct 2026 from Arboretum/botany_lab/carried/grass/bl_grass_lattice.gdshader, unchanged.
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

// VOXEL LAB (carried copy of ramon/chickenpen/grass/pen_grass_lattice.gdshader, 9 Oct, round 5 #49: "reuse
// the grass system from the Chicken Pen prototype ... a few small grass patches across the island terrain ...
// blades somewhat thicker"). The pen's blades, wind, clumps, colours, bands and slice cut, as they are. Out:
// the pen's mask, clearings and paths (it has none of them). In: PATCHES, where the field's own 4D noise (noise3,
// over x, z and W) is over `coverage_cut`, so `coverage` of the grass ground is grass (Ramon, 9 Oct: "the amount
// being covered by grass in percentage"; the cut is the noise's quantile, worked out on the CPU); patch_scale sets
// how big they are; within patch_w_reach of W 0 (as far as the ground is baked); their edges ragged and thinning
// as the clearings' did, inverted. The heights (height_tex over mask_rect, in W layers) are baked from
// the island's own chunk meshes by carried/grass/vl_grass_4d.gd, grass ground only: elsewhere a height far
// over height_max, so no blade stands on rock or under the sea.

// ANDREW'S 4D FIELD (4Denthusiast, 5 Oct, commit 5e03383 "Make the grass more 4D isotropic"), kept beside
// Ramon's pen_grass.gdshader as a second mode rather than in its place (Ramon, 7 Oct: "can we take andrew's grass
// coding and make the switch in our hud"). pen_grass_4d.gd andrew_4d picks it; the grass panel switches it. His
// shader as he wrote it, with Ramon's later work merged in: the hills (ground_h), the four W lanes of the
// clearings and the paths, each now judged by the blade's lattice cell (cell3) instead of its x-z cell.
//
// Grass for the pen: blades built and moved entirely here, from noise, every frame
// (pen_grass_4d.gd sets the uniforms; follow_up/grass_study.md is the why).
//
// HOW IT GETS INTO A 4D PICTURE. As the flock's starlings do (flock_bird.gdshader): this is a
// plain 3D MultiMesh in the Cross-section engine's own World3D, which draws in camera space,
// and the shader moves every vertex into the camera's frame itself with the view uniforms. The
// blades live in 4D - each has a w - and each is thin along W, so the slice cuts it: full size on
// its own slice, shrinking to nothing as it leaves (the section of a 4D body, sqrt(1-(w/r)^2)).
// Walk ana and the grass round you shrinks away while the next grass grows in.
//
// WHERE THE BLADES ARE. No positions are stored. The blades are the points of one world LATTICE
// over the floor's three horizontal dimensions (x, z, w), at this band's pitch `spacing`, each
// jittered within its cell by a hash of the cell alone - so a blade is the same blade from every
// camera and every slice. The slice meets the floor in a plane; pen_grass_4d.gd picks the axis d
// of (x, z, w) that plane is steepest along and cuts the other two into square TILES, snapped to
// the world; it lists the tiles in view every frame (tiles[], one per instance), and the mesh is
// one tile's blades, each knowing its column (iu, iv) and its place k among the `layers` lattice
// cells along d that can reach the slice from that column, from UV2. Level, that is the floor
// tiled in x and z with a few cells of w each; turned a quarter onto W it is x and w tiled, with
// cells of z - the same lattice either way, so nothing moves when the axis changes.
//
// WHAT A BLADE IS (Ghost of Tsushima's, GDC 2021): a cubic Bezier from the root to the tip,
// rebuilt every frame from four points - so bending it is moving the points. Widest at the
// root, a point at the tip, more vertices towards the tip where it bends. Its normals are
// turned out at the edges so a flat strip shades like a rounded blade, and seen edge-on it is
// thickened in view space so it never vanishes into a line.
//
// CLUMPS. A Voronoi of clump points over the ground (and along W, in bands): every blade knows
// its nearest clump, which sets its height, its colour - lush, ordinary or dry - and leans it
// towards the clump's middle. That is what makes a field look grown, not scattered.
//
// WIND, as wind in a field behaves (Ramon, 2 Oct: "a realistic wind algorithm ... more subtle"):
//   - a mean wind leans everything a little downwind;
//   - GUSTS travel downwind at about the wind's speed, in bands lying ACROSS the wind - the
//     waves that roll over a field of wheat (honami: the shear at the top of the canopy makes
//     coherent gusts that sweep the field). Anisotropic noise, stretched across the wind,
//     advected at 0.8 of the wind speed, with a slow swell in the gustiness;
//   - the bend follows the wind's PRESSURE, which goes as speed squared, and saturates at the
//     blade's stiffness (tanh): a little wind barely moves it, a gust lays it over, never flat;
//   - taller blades answer later: each samples the gusts a moment in the past, the lag growing
//     with its height, so a gust passes through the field rather than snapping it;
//   - each blade rocks about its bent pose at its own natural frequency (shorter ones faster),
//     harder in a gust, with a little turbulent flutter across the wind.
// People and animals walking through push the blades aside.
//
// THE BANDS (Ramon, 2 Oct: "a radial gradient of widening the space in between the blades,
// coming from center", and "less complex blades in radial rows"). Several of these materials,
// one per band round you, each with simpler blades than the one inside it (11 vertices at your
// feet down to 3 at the edge) but the SAME blade. The gap between blades widens smoothly with
// distance, not band by band: each band's grid is as fine as the gap at its inner edge and
// drops blades, by hash, to the gap wanted where each one stands. Neighbouring bands overlap and
// cross-fade, and a dropped blade shrinks away rather than vanishing, so walking moves no line.
// The width never steps either: it is the blade's own until the blade would be thinner than
// about a pixel, then a pixel.
// Not inside things: a mask texture gives, for each half metre of ground, up to two stretches
// of W where something stands on it (a floor, a pond, a hill), and no blade grows there.

// The camera's frame, set every render in one go (pen_grass_4d.gd): 0-3 the view basis (grass
// space to camera space), 4 its origin, 5 the camera's position in grass space, 6 the slice's
// normal, 7 the rings' middle (x, z), the view's half-width as a tangent, a pixel's angle; 8 the
// rings' middle's w, the dominant axis d (0 x, 1 z, 2 w), and c of the plane m . p = c where the
// slice meets the floor (m being the normal's x, z, w).
uniform vec4 frame[9];

// This band: its grid's gap, a tile's cells per side, the tiles in view (as tile indices), a
// seed so no two bands' blades line up.
uniform float spacing = 0.085;
uniform int tile_cells = 24;
uniform vec2 tiles[384];
uniform float seed = 0.0;
// Lattice cells a column holds along d, and a blade's thickness in W, in lattice pitches.
uniform int layers = 8;
uniform float w_radius_cells = 1.0;
// Where this band starts and ends round you, and how wide each cross-fade is (the last band's
// outer one is the long fade into the bare field).
uniform float band_in = 0.0;
uniform float band_in_fade = 1.0;
uniform float band_out = 5.0;
uniform float band_out_fade = 1.0;
uniform bool last_band = false;
// THE FAR FIELD FADES INTO THE GROUND (Ramon, 3 Oct: the hard cutoff of the grass in the
// distance). From far_from to far_to round you the blades go over to the colour of the ground
// under them, far_amount of the way, so the field has no edge to see: it was 55% at most, and
// only in the last band, and ended bright against the dark ground in a line.
uniform float far_from = 22.0;
uniform float far_to = 44.0;
uniform float far_amount = 1.0;
// The gap wanted at distance d: spacing_near out to spacing_from, then growing as a power of d.
uniform float spacing_near = 0.085;
uniform float spacing_from = 3.0;
uniform float spacing_power = 0.5;
uniform float blade_height = 0.42;
uniform float blade_width = 0.011;
// How the blade narrows to its point: 1 straight, less stays broad longer.
uniform float taper = 0.5;
// The fewest pixels wide a blade may be.
uniform float min_pixels = 0.8;
uniform float ground_extent = 59.0;
uniform float clump_size = 1.3;
// One blade in this many is a flower stem: a little coloured head on a thin stalk.
uniform float flower_share = 0.012;
// DAISIES (Ramon, 3 Oct, for Pasture: "patches of these very little white flowers"): flowers in
// patches, flower_patch_size across, flower_share of the blades inside a patch and none between
// (0 size: scattered evenly, as the meadows have them); drawn as small dots facing you,
// flower_dot across, white with a warm heart, instead of stems with heads; flower_white is the
// share that are white (the rest from the meadow palette).
uniform float flower_patch_size = 0.0;
uniform float flower_dot = 0.0;
uniform float flower_white = 0.5;
// Pairs of vertices up this band's blade (the tip apart): 1 for a single triangle.
uniform int blade_levels = 5;
// A flower stem's height against a blade's (1.5: they stand above the grass, as in a meadow;
// under 1: low among it, as clover and daisies in a pasture).
uniform float flower_height = 1.5;
// How far a blade leans its own way, as a share of its height (0.08: a meadow standing up;
// more: a grazed field, tousled).
uniform float splay = 0.08;
// The share of clumps left long - the tufts grazing animals pass over - and how much taller.
uniform float tuft_share = 0.0;
uniform float tuft_height = 1.9;
uniform vec3 flower_a : source_color = vec3(0.92, 0.90, 0.80);
uniform vec3 flower_b : source_color = vec3(0.95, 0.78, 0.22);
uniform vec3 flower_c : source_color = vec3(0.62, 0.45, 0.78);

// x, z of the mask's corner, its cell size, its cells per side.
uniform vec4 mask_rect = vec4(-60.0, -60.0, 0.5, 240.0);
// CLEARINGS (Ramon, 2 Oct: "the marsh, the pen, and the tower, should have a radius around it
// that doesn't have the grass, the edges shouldnt be straight square or round, but uneven like
// realistic"). Over the same cells as the mask, how far inside a clearing each spot is, m
// (> 0 inside), for the things at the farm's w, ana and kata (r, g, b); each group's w; the
// clearing's edge broken up by two scales of noise, and a fringe outside it where the grass
// thins and is trodden short.
// The paths (pen_grass_4d.gd path_inset): per mask cell, how far inside the nearest stretch's sand
// (r, m), the sand's W there (g) and its reach in W (b); blades stop path_inset inside the sand's edge
// and thin to trodden ones over path_fringe outside it, only near the sand's W.
// THE GROUND'S HEIGHT (pen_grass_4d.gd, grass_heights_4d.gd; 7 Oct, "grass on hill is a different
// green"): over the mask's x-z, in layers along W (height_w: the first layer's W, the step, how many),
// so blades stand on the hills too; none higher than height_max or on ground steeper than slope_max.
uniform sampler3D height_tex : filter_linear, repeat_disable;
uniform float height_on = 0.0;
uniform vec3 height_w = vec3(-8.0, 1.0, 19.0);
uniform float height_max = 9.0;
uniform float slope_max = 0.9;
// VOXEL LAB: the patches: the noise level over which the ground is grass, the noise's period in metres (a
// patch is about a third of it), how far through W either side of W 0 there is grass; how ragged their edges
// are and over how much they thin.
uniform float coverage_cut = 0.5;
uniform float patch_scale = 18.0;
uniform float patch_w_reach = 6.0;
uniform float patch_ragged = 1.2;
uniform float patch_fringe = 1.6;

uniform sampler2D wind_noise : filter_linear, repeat_enable;
uniform vec2 wind_dir = vec2(0.82, 0.57);
// The mean wind, m/s, and how gusty it is (0 steady, 1 squally).
uniform float wind_speed = 3.0;
uniform float gustiness = 0.55;
// A gust band's length down the wind and across it, m.
uniform float gust_length = 7.0;
uniform float gust_width = 18.0;
// How far over the strongest gust can lay a blade (the tip's lean, 0..1 of its height).
uniform float bend_max = 0.5;
// The wind pressure, (m/s)^2, that lays a blade half way over.
uniform float stiffness = 30.0;
// BARLEY WAVES (Ramon, 2 Oct: "make it flow like on barley fields, even though its not"). On
// barley the wind shows as long soft crests lying across it that roll downwind through the
// field, one after another, in sets - each laying the ears over as it passes, the light running
// along the crest. Here: a travelling wave down the wind (wave_length apart, at wave_speed),
// its crests bent and broken by noise so they are wavy and wave_width long, not ruled lines;
// its pressure added to the wind's, so the stalks lean and come back in step, the tall ones a
// moment after (the lag). 0 is off.
uniform float wave_strength = 0.0;
uniform float wave_length = 8.0;
uniform float wave_speed = 3.2;
uniform float wave_width = 22.0;
// BIG GUSTS (Ramon, 3 Oct: "sometimes have a stronger and larger gust of wind blow over"): now
// and then one broad front, its line bent by noise, sweeps downwind across the whole field round
// you, laying the grass over well past the usual gusts and lighting the tips as it goes. One
// chance every big_gust_every seconds, taken big_gust_chance of the time; it adds
// big_gust_strength m/s over a band big_gust_width deep, travelling at big_gust_speed.
uniform float big_gust_strength = 0.0;
uniform float big_gust_every = 18.0;
uniform float big_gust_chance = 0.6;
uniform float big_gust_width = 9.0;
uniform float big_gust_speed = 9.0;
// How much further over a big gust lays the grass than the wind's own limit (bend_max), as a
// share of its height: a speed alone saturates against bend_max, so the front would barely
// show over grass already leaning in the breeze.
uniform float big_gust_lean = 0.3;

// Whoever walks through: where (x, strength, z, w), and the way they went (x, z), with the
// reach of their push (w). Grass is laid the way they move, not away from them; the player
// leaves a trail of these that fades over the metres behind them.
uniform vec4 pushers[32];
uniform vec4 pusher_motion[32];
uniform int pusher_count = 0;

// Cool at the root, not black or brown: the painted warm-over-cool split.
uniform vec3 colour_root : source_color = vec3(0.07, 0.15, 0.14);
// The field's main colour: sap green.
uniform vec3 colour_base : source_color = vec3(0.31, 0.49, 0.16);
uniform vec3 colour_lush : source_color = vec3(0.27, 0.47, 0.18);
uniform vec3 colour_dry : source_color = vec3(0.47, 0.44, 0.22);
uniform vec3 colour_tip : source_color = vec3(0.48, 0.62, 0.26);
uniform vec3 ground_colour : source_color = vec3(0.16, 0.22, 0.11);
// What the field's far edge turns into: the ground there (the pen's own dark green, which the
// painted ground also is that far out).
uniform vec3 edge_colour : source_color = vec3(0.16, 0.22, 0.11);
// The painted ground's glow (pen_grass_4d.gd, pen_ground_paint_4d.gd), worked out the same way
// here so the far edge fades to the ground actually under it: its middle (x, z), full out to
// z, gone by w; its colour; 0 or 1, whether it is on.
uniform vec4 glow_area = vec4(-4.0, -14.0, 12.0, 40.0);
uniform vec3 glow_colour : source_color = vec3(0.25, 0.31, 0.095);
uniform float glow_on = 0.0;
uniform float sheen = 0.32;
// THE PAINTED LOOK (Ramon, 2 Oct, after Ghibli's meadows: "a very subtle color/hue offset for each
// blade, and clump parts with different color regions", then "the brighter grass regions ... 3
// color coded region types", and at last "sapgreen as main ... and 2 corresponding offsets ...
// so sapgreen has the highest ratio", less contrasty). Broad regions over the field, from slow
// world-space noise at the root, so whole patches of blades share a colour as brush strokes do:
// sap green over half of it, and two offsets of it - lighter and warmer, deeper and cooler -
// over a quarter each. Each region moves the whole blade by its offset from sap green, root to
// tip. And each blade's hue is nudged a little towards yellow or towards blue.
uniform vec3 region_deep : source_color = vec3(0.21, 0.40, 0.19);
uniform vec3 region_bright : source_color = vec3(0.40, 0.56, 0.17);
// About how big a region is, m, and how far the field goes over to its colours (0 none, 1 all).
uniform float region_size = 13.0;
uniform float region_strength = 1.0;
// Where the noise turns deep (below x..y) and bright (above z..w): its quantiles, worked out
// by pen_grass_4d.gd so each offset covers region_share of the field.
uniform vec4 region_cuts = vec4(0.36, 0.46, 0.55, 0.65);
// How far one blade's hue may wander from its neighbours'.
uniform float hue_jitter = 0.05;
// How light the blades are, all colours together (Ramon, 2 Oct: darker, to sit with the ground
// between and beyond them). In linear light: 0.7 is about 0.85 on the sRGB numbers.
uniform float shade = 0.7;
// How dark a blade is at its root: the colour ramp from colour_root and the light it loses there
// (fake ambient occlusion). 1 as the meadows have it; 0 a blade the one colour root to tip
// (Pasture: Ramon, 3 Oct, "remove the strong brown gradient from the bottom entirely").
uniform float root_dark = 1.0;
// How far sap green, its bright offset, the lush clumps and the tips go towards the ground's own
// colour (Ramon, 2 Oct: the deep region "merges with the base green ground" and he likes it;
// "darkening the remaining 2 colors closer to the base ground color too"). The deep region is
// left where it is.
uniform float toward_ground = 0.18;
// How saturated the blades are: 1 as the colours say, more is greener (Ramon, 2 Oct: "saturate
// the grass a bit"). About the blade's own brightness, so it changes no values.
uniform float saturation = 1.45;
// (A glow of the sun's colour through the tips you see against it was tried and taken out: at
// 0.3 it moved the field's brightness 2%, and the yellow against the sun was already there, from
// BACKLIGHT; at ten times it only bleached a band along the horizon.)
// Haze with distance, towards the horizon's colour. Off: tried at 0.5, it washed the field grey
// while the bare ground and the buildings beside it stayed clear, so the grass stood out more.
uniform vec3 haze_colour : source_color = vec3(0.62, 0.56, 0.45);
uniform float haze_distance = 45.0;
uniform float haze_amount = 0.0;
// Cloud shadows: big soft dark patches drifting across the field with the wind (0 off).
uniform float cloud_shadows = 0.0;
uniform float cloud_size = 40.0;

varying vec3 v_colour;
varying float v_t;
varying float v_haze;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// Noise over the floor's three dimensions (x, z, w) from the one 2D texture: the texture read
// over each pair of axes and averaged, so the field is a little stripey along three directions
// instead of wholly stripey along one - a 2D field is constant along SOME line through (x, z, w),
// however it is turned. The average has a third of the texture's variance, so the spread is put
// back (x sqrt(3) about 1/2): the mean and spread are a single read's, and the thresholds tuned
// against the texture keep their sense. pen_grass_4d.gd's _cuts takes the regions' quantiles
// from this same distribution.
float noise3(vec3 p, vec2 shift) {
	float sum = texture(wind_noise, p.xy + shift).r
			+ texture(wind_noise, p.yz + shift + vec2(0.37, 0.59)).r
			+ texture(wind_noise, p.zx + shift + vec2(0.71, 0.13)).r;
	return 0.5 + (sum / 3.0 - 0.5) * 1.7320508;
}

// The nearest clump point in (x, z, w): its offset from p (x, z, w) and its id.
vec4 clump(vec3 p) {
	vec3 g = floor(p / clump_size);
	vec3 f = p / clump_size - g;
	float best = 1e9;
	vec4 out_value = vec4(0.0);
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 o = vec3(float(i), float(j), float(k));
				vec3 key = g + o;
				vec3 d = o + hash33(key) - f;
				float dd = dot(d, d);
				if (dd < best) {
					best = dd;
					out_value = vec4(d * clump_size, hash13(key + 5.3));
				}
			}
		}
	}
	return out_value;
}

float ground_h(vec2 xz, float w) {
	if (height_on < 0.5) {
		return 0.0;
	}
	vec2 uv = (xz - mask_rect.xy) / (mask_rect.z * mask_rect.w);
	float lw = clamp((w - height_w.x) / height_w.y, 0.0, height_w.z - 1.0);
	return max(texture(height_tex, vec3(uv, (lw + 0.5) / height_w.z)).r, 0.0);
}

void vertex() {
	mat4 vb = mat4(frame[0], frame[1], frame[2], frame[3]);
	vec4 view_origin = frame[4];
	vec4 camera_world = frame[5];
	vec4 slice_normal = frame[6];
	// The middle of the rings, in x and z, is you: the player when the camera is following them,
	// the camera itself when it is your eye (the hawk, the Lookout's camera). The slice and the
	// frustum are still the camera's.
	vec3 ring_centre = vec3(frame[7].xy, frame[8].x);
	// tan of half the camera's horizontal view, with a margin: blades off the sides are dropped.
	float frustum_x = frame[7].z;
	// A pixel's width at one metre (2 tan(fov / 2) / the view's height).
	float pixel_angle = frame[7].w;
	int n = tile_cells;
	int ixk = int(UV2.x + 0.5);
	int k = ixk / n;
	int iu = ixk - k * n;
	int iv = int(UV2.y + 0.5);
	// This column of the lattice, (iu, iv) over the plane's (u, v), and the plane's own numbers:
	// which axis is d, and m . p = c with m the slice normal's (x, z, w).
	int axis = int(frame[8].y + 0.5);
	float plane_c = frame[8].z;
	vec3 plane_m = vec3(slice_normal.x, slice_normal.z, slice_normal.w);
	vec2 muv = axis == 0 ? plane_m.yz : (axis == 1 ? plane_m.xz : plane_m.xy);
	float md = axis == 0 ? plane_m.x : (axis == 1 ? plane_m.y : plane_m.z);
	vec2 column = tiles[INSTANCE_ID] * float(n) + vec2(float(iu), float(iv));
	// Where the plane crosses this column, in cells along d, and the first cell that can reach it
	// (a blade's own jitter and its column's each move it by up to a cell; pen_grass_4d.gd sizes
	// `layers` so the last cell that can is covered too). The k-th cell on from there is this one.
	float pd = (plane_c - dot(muv, (column + 0.5) * spacing)) / (md * spacing);
	float kd = ceil(pd - w_radius_cells / abs(md) - 2.0) + float(k);
	// The cell in the lattice's own order (x, z, w), whatever d is, so its hash is its own.
	vec3 cell3 = axis == 0 ? vec3(kd, column) : (axis == 1 ? vec3(column.x, kd, column.y) : vec3(column, kd));
	vec3 root3 = (cell3 + hash33(cell3 + seed)) * spacing;
	vec2 root_xz = root3.xy;
	float root_w = root3.z;
	// On the hills (Ramon's grass_heights_4d.gd, 7 Oct): the root stands on the ground there. The slice's
	// normal has no y (the camera's pitch turns y and z, never w), so the plane above is the same at any
	// height and only the root is lifted.
	float root_y = ground_h(root_xz, root_w);
	vec4 root = vec4(root3.x, root_y, root3.y, root3.z);

	float alive = 1.0;
	if (height_on > 0.5) {
		float hx = ground_h(root_xz + vec2(0.5, 0.0), root_w);
		float hz = ground_h(root_xz + vec2(0.0, 0.5), root_w);
		if (root_y > height_max || length(vec2(hx - root_y, hz - root_y)) * 2.0 > slope_max) {
			alive = 0.0;
		}
	}
	if (abs(root.x) > ground_extent || abs(root.z) > ground_extent || abs(root.w) > ground_extent) {
		alive = 0.0;
	}
	// VOXEL LAB: only inside a patch; at its ragged edge, fewer, and trodden short (the pen's clearings,
	// turned inside out).
	float trodden = 1.0;
	float inward = (noise3(root3 / patch_scale, vec2(0.43, 0.17)) - coverage_cut) * patch_scale * 0.5;
	inward = min(inward, patch_w_reach - abs(root_w));
	inward += (texture(wind_noise, root_xz / 6.0 + vec2(0.21, 0.83)).r - 0.5) * 2.0 * patch_ragged
			+ (texture(wind_noise, root_xz / 1.7 + vec2(0.57, 0.19)).r - 0.5) * 0.7 * patch_ragged;
	float in_by = clamp(inward / patch_fringe, 0.0, 1.0);
	if (inward < 0.0 || hash13(cell3 + vec3(3.3, 9.1, 0.0) + seed) > mix(0.25, 1.0, in_by)) {
		alive = 0.0;
	}
	trodden = mix(0.45, 1.0, smoothstep(0.0, 1.0, in_by));
	// THE GAP GROWS WITH DISTANCE, blade by blade: this band's grid is as fine as the gap at its
	// inner edge, so it keeps (its gap / the gap wanted here)^2 of its blades, chosen by hash,
	// and hands over to the next band across the cross-fade. A blade near its hash's cut is
	// shrunk, not dropped, so walking grows and shrinks blades instead of popping them. The cut
	// is centred on the share kept, so a band gives exactly its share and two cross-fading
	// bands add up to one (it had overshot by a quarter, so each band ended denser than the next
	// began: the faint rings that moved with you). The shrink is in height only, so a shrunk
	// blade's area falls as its share does.
	// Distance in the floor's (x, z, w): in the slice, that is how far away the blade is.
	float dist = length(root3 - ring_centre);
	float wanted = dist <= spacing_from ? spacing_near : spacing_near * pow(dist / spacing_from, spacing_power);
	float share = min(1.0, (spacing / wanted) * (spacing / wanted));
	float w_in = band_in > 0.0 ? smoothstep(band_in - band_in_fade, band_in + band_in_fade, dist) : 1.0;
	float w_out = last_band ? 1.0 - smoothstep(band_out - band_out_fade, band_out, dist)
			: 1.0 - smoothstep(band_out - band_out_fade, band_out + band_out_fade, dist);
	float keep = hash13(cell3 + vec3(7.7, 1.3, 0.0) + seed);
	float kept = share * w_in * w_out;
	float soft = min(0.2, 2.0 * min(kept, 1.0 - kept));
	float ring = soft > 0.001 ? clamp(0.5 + (kept - keep) / soft, 0.0, 1.0) : (keep < kept ? 1.0 : 0.0);
	// Only the field's far edge turns the ground's colour.
	float tint = 1.0 - far_amount * smoothstep(far_from, far_to, dist);
	// The cut: as much of the blade as the slice passes through.
	vec4 rel_root = vb * root + view_origin;
	float w_radius = w_radius_cells * spacing;
	float s2 = 1.0 - (rel_root.w / w_radius) * (rel_root.w / w_radius);
	float section = s2 > 0.0 ? sqrt(s2) : 0.0;
	float grow = ring * section * alive;
	// What the slice leaves of it, for its width: thinning shrinks a blade's height only.
	float cut = section * alive;
	// DEAD BLADES COST NOTHING MORE: out of the slice, thinned out, under a floor, behind the
	// camera or off the side of the view - all its vertices go to one point behind the camera,
	// before any of the clump, wind and curve work below.
	float ahead = -rel_root.z;
	bool dead = grow <= 0.0 || ahead < -0.8 || abs(rel_root.x) > ahead * frustum_x + 1.0;
	// (Godot does not allow a return in vertex(), so the rest is in an else.)
	if (dead) {
		VERTEX = vec3(0.0, 0.0, 1.0);
		NORMAL = vec3(0.0, 1.0, 0.0);
		v_colour = vec3(0.0);
		v_t = 0.0;
		v_haze = 0.0;
	} else {

		// The blade's own numbers, from its cell and its clump.
		vec4 cl = clump(root3);
		float clump_h = mix(0.82, 1.18, hash12(vec2(cl.w, 3.1)));
		float dry = smoothstep(0.62, 0.95, hash12(vec2(cl.w, 8.7)));
		float lush = max(1.0 - smoothstep(0.0, 0.5, hash12(vec2(cl.w, 1.9))), step(1.0 - tuft_share, hash12(vec2(cl.w, 4.4))) * 0.7);
		float rnd = hash13(cell3 + 4.2);
		float patch = 1.0;
		if (flower_patch_size > 0.0) {
			patch = smoothstep(0.58, 0.72, noise3(root3 / (flower_patch_size * 3.1), vec2(0.63, 0.27)));
		}
		float flower = step(hash13(cell3 + 2.6), flower_share * patch);
		float tuft = step(1.0 - tuft_share, hash12(vec2(cl.w, 4.4)));
		float h = blade_height * clump_h * mix(0.7, 1.25, rnd) * mix(1.0, tuft_height, tuft) * grow * trodden * mix(1.0, flower_height, flower);
		// A BLADE IS A BLADE FROM EVERY SIDE. Its width, its splay and its lean to its clump lie in
		// the horizontal plane of the SLICE - the two horizontal directions perpendicular to the
		// slice normal - not in the floor's x and z: a width laid along z is a line, seen edge-on,
		// to a slice turned onto W. h1 is the camera's own right, on the floor; h2 is perpendicular
		// to it and to the slice normal within the floor's (x, z, w).
		vec4 h1 = vec4(vb[0].x, 0.0, vb[2].x, vb[3].x);
		if (dot(h1, h1) < 1e-6) {
			h1 = vec4(1.0, 0.0, 0.0, 0.0);
		}
		h1 = normalize(h1);
		vec3 h2f = cross(normalize(plane_m), vec3(h1.x, h1.z, h1.w));
		vec4 h2 = vec4(h2f.x, 0.0, h2f.y, h2f.z);
		if (dot(h2, h2) < 1e-6) {
			h2 = vec4(0.0, 0.0, 1.0, 0.0);
		}
		h2 = normalize(h2);
		float facing = hash13(cell3 + 9.1) * 6.2831853;
		vec4 splay_dir = cos(facing) * h1 + sin(facing) * h2;
		// The clump's pull, as seen in the slice.
		vec4 toward = vec4(cl.x, 0.0, cl.y, cl.z);
		vec4 lean = (h1 * dot(toward, h1) + h2 * dot(toward, h2)) * 0.06 + splay_dir * splay * mix(0.4, 1.0, rnd);

		// Wind (see the top): gust bands advected downwind, a pressure-driven bend, a lag by
		// height, a natural rock and a flutter.
		vec2 across_wind = vec2(-wind_dir.y, wind_dir.x);
		float lag = 0.12 + 0.35 * clamp(h / max(blade_height, 0.01), 0.0, 2.0);
		float tw = TIME - lag;
		float along = dot(root_xz, wind_dir) - wind_speed * 0.8 * tw;
		float side_pos = dot(root_xz, across_wind);
		// Across the wind is two directions on this floor, the floor's own and W: the gust bands
		// vary over both, and still travel down the wind.
		vec3 gust_at = vec3(along / gust_length, side_pos / gust_width, root_w / gust_width) * 0.18;
		float g1 = noise3(gust_at, vec2(0.0));
		float g2 = noise3(gust_at * 2.3 + vec3(0.31, 0.77, 0.0), -vec2(0.05 * tw, 0.0));
		float swell = 0.75 + 0.25 * sin(TIME * 0.21) * sin(TIME * 0.077 + 1.3);
		float gust = smoothstep(0.32, 0.8, g1 * 0.75 + g2 * 0.25) * swell;
		float wave = 0.0;
		if (wave_strength > 0.0) {
			float down = dot(root_xz, wind_dir);
			float moving = down - wave_speed * tw;
			// The crests' bend: a slow noise across them, drifting with them.
			float warp = noise3(vec3(side_pos / (wave_width * 2.2), moving / (wave_length * 5.0), root_w / (wave_width * 2.2)), vec2(0.41, 0.83));
			float crest = 0.5 + 0.5 * sin((moving / wave_length + warp * 1.6) * 6.2831853);
			crest = smoothstep(0.3, 1.0, crest);
			// Where a crest is, along it: each one wave_width or so long, then it breaks off.
			float run = smoothstep(0.28, 0.68, noise3(vec3(side_pos / (wave_width * 3.1), moving / (wave_length * 3.1), root_w / (wave_width * 3.1)), vec2(0.17, 0.29)));
			// The sets: a few strong crests, then a few weak.
			float sets = 0.6 + 0.4 * sin(moving / (wave_length * 4.0) * 6.2831853 + warp * 2.0);
			wave = crest * mix(0.25, 1.0, run) * sets * wave_strength;
		}
		float big = 0.0;
		if (big_gust_strength > 0.0) {
			// The front's place along the wind, from 90 m upwind of you to 110 m past you, once a
			// cycle (so its tail has left the field before the next can start: cut short, it ended
			// in a flash); whether this cycle has one at all, from the cycle's own hash.
			float cycle = floor(tw / big_gust_every);
			float into = tw - cycle * big_gust_every;
			float on = step(hash12(vec2(cycle, 9.7)), big_gust_chance);
			float front = -90.0 + big_gust_speed * into;
			float rel_along = dot(root_xz - ring_centre.xy, wind_dir);
			float bow = (noise3(vec3(side_pos / 90.0, cycle * 0.137, root_w / 90.0), vec2(0.0)) - 0.5) * 30.0;
			float d = (rel_along - front - bow) / big_gust_width;
			// Steep in front, a longer tail behind, as a gust front is.
			big = on * exp(-d * d * (d > 0.0 ? 2.5 : 0.6)) * step(front, 110.0);
		}
		float speed = wind_speed * (1.0 - gustiness * 0.5 + gustiness * 1.6 * gust + 1.2 * wave) + big_gust_strength * big;
		float bend = bend_max * tanh(speed * speed / stiffness) + big_gust_lean * big;
		// The rock about the bent pose, at the blade's own frequency: shorter ones faster.
		float freq = mix(2.2, 1.1, clamp(h / max(blade_height * 1.3, 0.01), 0.0, 1.0)) * mix(0.85, 1.15, rnd);
		// Under the waves the stalks move together, so each one's own rock and flutter are less.
		float together = 1.0 - 0.6 * min(wave_strength, 1.0);
		float rock = sin(TIME * 6.2831853 * freq + rnd * 40.0) * (0.03 + 0.07 * gust) * bend_max * together;
		// (The flutter is the wind's too: none in still air, as at the usual 3 m/s.)
		float flutter = (noise3(root3 * 0.9, vec2(TIME * 0.6, TIME * 0.37)) - 0.5) * 0.08 * (0.3 + gust) * min(wind_speed / 3.0, 2.0) * mix(1.0, together, 0.8);
		vec2 push = wind_dir * (bend + rock) + across_wind * flutter;
		// Whoever walks through lays it the way they are going (a little aside too, so it does
		// not stand up through their legs); the trails of the player and Nike keep it down behind
		// them, less and less over the metres. They are all within reach of the middle of the rings.
		if (dist < 16.0) {
			for (int i = 0; i < pusher_count; i++) {
				vec4 p = pushers[i];
				vec4 m = pusher_motion[i];
				vec2 d = root_xz - p.xz;
				float dl = length(d);
				float near = (1.0 - smoothstep(0.1, m.w, dl)) * (1.0 - smoothstep(0.25, 0.6, abs(root_w - p.w))) * p.y;
				if (near > 0.0) {
					vec2 radial = d / max(dl, 0.01);
					vec2 way = dot(m.xy, m.xy) > 0.01 ? m.xy : radial;
					push += normalize(way + radial * 0.25) * near * 1.5;
				}
			}
		}
		// The wind and whoever walks through act on the floor's x and z, as they do in the world;
		// what you see of that lean is its part within the slice.
		vec4 hz = lean + vec4(push.x, 0.0, push.y, 0.0);
		float hl = length(hz);
		if (hl > 0.9) {
			hz *= 0.9 / hl;
		}

		// The Bezier: root at the origin, the tip where the lean and the wind put it, bending all
		// along its length as a stalk held at the root does: upright at the root, the tip's slope
		// about one and a half times the lean. (The middle points were at 40% and 90% of the
		// height, which left all the bend for the last few centimetres: a hook at every tip.)
		vec4 up = vec4(0.0, 1.0, 0.0, 0.0);
		vec4 p3 = (hz + up * sqrt(max(1.0 - dot(hz, hz), 0.1))) * h;
		vec4 p1 = up * (p3.y * 0.35);
		vec4 p2 = hz * 0.45 * h + up * (p3.y * 0.7);
		float t = UV.y;
		float side = UV.x;
		float u = 1.0 - t;
		vec4 b = 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3;
		vec4 tangent = 3.0 * u * u * p1 + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (p3 - p2);
		tangent = normalize(tangent + up * 1e-5);
		vec4 across = -sin(facing) * h1 + cos(facing) * h2;
		// Never thinner than about a pixel: past that a blade flickers and the field goes bare.
		float bw = max(blade_width, length(rel_root.xyz) * pixel_angle * min_pixels);
		float width = bw * cut * pow(u, taper) * mix(0.8, 1.25, rnd);
		if (flower > 0.5) {
			// A thin stalk, and a head: wide for the last fifth of it.
			width = bw * cut * (t > 0.86 ? 1.25 * sin((t - 0.86) / 0.14 * 3.14159) + 0.2 : 0.35);
		}
		vec4 pos = b + across * side * width;

		// Into the camera's frame. The strip is drawn there, so its normal is taken there, from its
		// two directions; turned out at the edges so a flat strip shades like a rounded blade, and
		// the strip thickened when seen edge-on.
		vec4 rel = vb * (root + pos) + view_origin;
		vec3 a_view = (vb * across).xyz;
		vec3 t_view = (vb * tangent).xyz;
		vec3 n_view = normalize(cross(a_view, t_view) + vec3(0.0, 0.0, 1e-6));
		if (n_view.y < 0.0) {
			n_view = -n_view;
		}
		n_view = normalize(n_view + a_view * side * 0.6);
		float edge = 1.0 - abs(dot(n_view, normalize(-rel.xyz)));
		rel.xyz += a_view * side * width * edge * 1.4;
		VERTEX = rel.xyz;
		NORMAL = n_view;
		if (flower > 0.5 && flower_dot > 0.0) {
			// A daisy: a small dot facing you at the top of the stem, whatever the blade's shape;
			// its three corners around the head, in the camera's own right and up.
			vec4 head = vb * (root + p3) + view_origin;
			float s = max(flower_dot, length(head.xyz) * pixel_angle * 1.6) * cut;
			// A triangle on a one-triangle blade; on more, a pentagon from its first five corners
			// (the root pair, the next pair, the tip: their triangles cover it), the rest folded
			// into the tip. Up close a triangle reads as a triangle.
			vec2 corner = vec2(0.0, 1.0);
			if (blade_levels <= 1) {
				corner = side < -0.5 ? vec2(-0.87, -0.5) : (side > 0.5 ? vec2(0.87, -0.5) : vec2(0.0, 1.0));
			} else if (t < 0.001) {
				corner = side < 0.0 ? vec2(-0.59, -0.81) : vec2(0.59, -0.81);
			} else if (side < -0.5 || side > 0.5) {
				corner = t < 0.6 ? (side < 0.0 ? vec2(-0.95, 0.31) : vec2(0.95, 0.31)) : vec2(0.0, 1.0);
			}
			VERTEX = head.xyz + vec3(corner * s, 0.0);
			// Lit as a flower facing the sky, not as a card facing you: it stays white.
			NORMAL = normalize((vb * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		}

		// Colour: dark at the root, the clump's green, a pale tip; the region it stands in; its own
		// small hue shift; the passing gust bright on the tips; the field's far edge going over to
		// the ground's colour.
		vec3 sap = mix(colour_base, ground_colour, toward_ground);
		vec3 base = mix(sap, mix(colour_lush, ground_colour, toward_ground), lush);
		base = mix(base, colour_dry, dry * 0.45);
		vec3 tip = mix(mix(colour_tip, ground_colour, toward_ground), colour_dry * 1.2, dry * 0.35);
		// The regions, from one slow field of the noise (a feature of it is about a third of the
		// texture), its low end deep, its high end bright, sap green between; each with a soft
		// edge, not a blur. A region moves the blade by its offset from sap green. Read over all
		// three of the floor's dimensions (noise3), so the regions change along W as they do along
		// x and z.
		float field = noise3(root3 / (region_size * 3.1), vec2(0.37, 0.11));
		float deep = (1.0 - smoothstep(region_cuts.x, region_cuts.y, field)) * region_strength;
		float bright = smoothstep(region_cuts.z, region_cuts.w, field) * region_strength;
		vec3 offset = (region_deep - sap) * deep + (mix(region_bright, ground_colour, toward_ground) - sap) * bright;
		base += offset;
		tip += offset * 0.8;
		// The blade's own hue: a little towards yellow (red up, blue down) or towards blue.
		float hue = hash13(cell3 + 11.3) - 0.5;
		vec3 shift = vec3(1.0, 0.3, -0.8) * hue * hue_jitter * 2.0;
		base = max(base + shift, vec3(0.0)) * mix(0.9, 1.08, rnd);
		tip = max(tip + shift, vec3(0.0));
		vec3 c = mix(mix(base, colour_root, root_dark), base, smoothstep(0.0, 0.45, t));
		c = mix(c, tip, smoothstep(0.55, 1.0, t));
		c = max(mix(vec3(dot(c, vec3(0.2126, 0.7152, 0.0722))), c, saturation), vec3(0.0));
		c *= shade;
		// Under a passing cloud: darker.
		float cloud = 0.0;
		if (cloud_shadows > 0.0) {
			vec3 cloud_at = (root3 - vec3(wind_dir * wind_speed * 0.6 * TIME, 0.0)) / (cloud_size * 3.1);
			cloud = smoothstep(0.42, 0.62, noise3(cloud_at, vec2(0.13, 0.61))) * cloud_shadows;
		}
		c *= 1.0 - cloud * 0.4;
		v_haze = haze_amount * (1.0 - exp(-length(rel.xyz) / haze_distance));
		// The light on the tips as a gust or a crest lays them over.
		c += sheen * max(max(gust, wave), big * 2.0) * t * t * vec3(0.5, 0.52, 0.3) * shade;
		if (flower > 0.5 && (t > 0.86 || flower_dot > 0.0)) {
			float pick = hash13(cell3 + 6.6);
			c = pick < flower_white ? flower_a : (pick < flower_white + (1.0 - flower_white) * 0.6 ? flower_b : flower_c);
			if (flower_dot > 0.0 && pick < flower_white) {
				// White petals, the heart a little warm: the top corner gets the yellow.
				c = flower_a;
			}

		}
		float glow_here = glow_on * (1.0 - smoothstep(glow_area.z, glow_area.w, length(root_xz - glow_area.xy)));
		v_colour = mix(mix(edge_colour, glow_colour, glow_here), c, tint);
		v_t = t;
	}
}

void fragment() {
	// The haze takes the place of the blade's own colour, lit or not.
	ALBEDO = v_colour * (1.0 - v_haze);
	EMISSION = haze_colour * v_haze * 0.55;
	ROUGHNESS = 0.72;
	SPECULAR = 0.22;
	BACKLIGHT = v_colour * 0.5 * v_t;
	AO = mix(1.0 - 0.5 * root_dark, 1.0, v_t);
	AO_LIGHT_AFFECT = 0.5;
}
