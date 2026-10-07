extends SceneTree

## Pen layout (6 Oct 2026): frames of the pen to judge a layout by eye. Two kinds of shot:
##   top  an orthographic camera straight down over a point, [size] metres across, at a slice W:
##        the map view, north (-z) up
##   eye  the player put somewhere, facing a heading, seen through their own camera: what you see
##        walking there
## Any shot can ask for a renderer ("Cross-section", "Combined", "Projected"). The HUD is hidden
## unless the shot says "hud". The player's input is off and the window never takes focus, so
## nothing typed or moved elsewhere gets into the frames (feedback_test_windows_steal_focus).
##
## Frames go to res://smoke_test_output/pen_layout/<set>/<shot>.png.
##
##   CreationLab/scripts/lab_run.sh windowed pl_cap res://ramon/PenLayout/scripts/_capture_pen_runner.gd <set> [scene]

const OUT := "res://smoke_test_output/pen_layout/"
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
## PathCreator's lab floor (pathcreator_4d.gd FLOOR), and its grid's two line colours.
const DEV_FLOOR := Color(0.96, 0.965, 0.97)
## A shot: "top" (centre) or "at" (where the player stands) with "yaw" (degrees, 0 looks north),
## and optionally "pitch" (degrees), "distance" (the orbit camera's), "w" (the slice), "size"
## (top: metres across), "engine", "hud"; "paths" (properties set on World/Paths first: reveal,
## show_marks, show_sand), "forget" (reveal forgets what it found first) and "walk" (points the
## player is walked through at a run before the shot, so reveal finds what is near them); "set"
## (node path -> {property: value}, set before the shot: a tower's fence frame on, say);
## "devfloor" (from that shot on, the ground is PathCreator's white lab floor and the paths' floor
## colour matches it: the look of a dev version of the pen, Ramon 6 Oct); "tilt" (eye shots: the
## slice turned, Vector2(xw, zw) in degrees, as slice_angles_4d.gd turns it; flat when left out);
## "spawn" (scene path -> Vector4: instanced under World there, from that shot on: a new piece seen
## in the pen before the pen holds it) and "hide" (node paths hidden from that shot on).
const DEV_LOOK := {"look": "dev", "show_marks": true, "show_sand": true, "under_color": Color(0.93, 0.935, 0.94)}
const SAND_LOOK := {"look": "walk", "show_marks": false, "show_sand": true}
const SETS := {
	# Ramon's notes of 6 Oct (the second round): the paths' edge and colour and the two looks, the
	# road at the rock pile's fork, the ruined wall's arch and its fallen pillar, the funnel of hills,
	# the tower, the balloon, the tower's hill, the oak, and the cave's mouth with the slice turned.
	"feedback": [
		{"name": "paths_fork_sand", "at": Vector4(-4.5, 1.2, 4.5, 0), "yaw": 0.0, "pitch": -22.0, "distance": 7.0, "paths": SAND_LOOK},
		{"name": "paths_fork_dev", "at": Vector4(-4.5, 1.2, 4.5, 0), "yaw": 0.0, "pitch": -22.0, "distance": 7.0, "paths": DEV_LOOK},
		{"name": "paths_close_sand", "at": Vector4(-8.0, 1.2, 12.0, 0), "yaw": 160.0, "pitch": -30.0, "distance": 4.0, "paths": SAND_LOOK},
		{"name": "paths_close_dev", "at": Vector4(-8.0, 1.2, 12.0, 0), "yaw": 160.0, "pitch": -30.0, "distance": 4.0, "paths": DEV_LOOK},
		{"name": "paths_pen", "at": Vector4(0.0, 1.2, 2.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 8.0, "paths": SAND_LOOK},
		{"name": "funnel", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 22.0, "pitch": -4.0, "distance": 6.0},
		{"name": "arch_south", "at": Vector4(-11.2, 1.2, 23.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 6.0},
		{"name": "arch_close", "at": Vector4(-11.2, 1.2, 20.0, 0), "yaw": 0.0, "pitch": -4.0, "distance": 4.0},
		{"name": "arch_tilted", "at": Vector4(-11.2, 1.2, 20.0, 0), "yaw": 0.0, "pitch": -4.0, "distance": 4.0, "tilt": Vector2(0.0, 14.0)},
		{"name": "arch_tilted_b", "at": Vector4(-11.2, 1.2, 20.0, 0), "yaw": 0.0, "pitch": -4.0, "distance": 4.0, "tilt": Vector2(0.0, -14.0)},
		{"name": "ruins_long", "at": Vector4(-3.0, 1.2, 25.0, 0), "yaw": 55.0, "pitch": -6.0, "distance": 7.0},
		{"name": "ruins_w15", "at": Vector4(-3.0, 1.2, 25.0, 1.5), "yaw": 55.0, "pitch": -6.0, "distance": 7.0},
		{"name": "arch_north", "at": Vector4(-11.2, 1.2, 9.0, 0), "yaw": 180.0, "pitch": -6.0, "distance": 6.0},
		{"name": "tower_w0", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "tower_w2", "at": Vector4(-7.0, 1.2, -23.0, 2.0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "tower_w3", "at": Vector4(-7.0, 1.2, -23.0, 3.1), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "tower_close", "at": Vector4(-12.0, 1.2, -26.0, 0), "yaw": 20.0, "pitch": 24.0, "distance": 6.0},
		{"name": "tower_deck", "at": Vector4(-16.0, 11.2, -33.6, 0), "yaw": 0.0, "pitch": -4.0, "distance": 5.0},
		{"name": "balloon", "at": Vector4(-14.0, 1.2, -18.0, 0), "yaw": 25.0, "pitch": 6.0, "distance": 8.0},
		{"name": "tower_hill", "at": Vector4(0.0, 1.2, -4.0, 0), "yaw": 8.0, "pitch": 2.0, "distance": 6.0},
		{"name": "oak", "at": Vector4(-6.0, 1.2, 42.0, 0), "yaw": 90.0, "pitch": 8.0, "distance": 7.0},
		{"name": "oak_far", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 80.0, "pitch": 0.0, "distance": 6.0},
		{"name": "cave_tilt_a", "at": Vector4(7.5, 1.2, 35.0, 0), "yaw": 0.0, "pitch": -2.0, "distance": 6.0, "tilt": Vector2(0.0, 28.0)},
		{"name": "cave_tilt_b", "at": Vector4(7.5, 1.2, 35.0, 0), "yaw": 0.0, "pitch": -2.0, "distance": 6.0, "tilt": Vector2(0.0, -28.0)},
		{"name": "cave_w4", "at": Vector4(7.5, 1.2, 33.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 6.0},
		{"name": "camp", "at": Vector4(20.0, 1.2, 4.5, -2.5), "yaw": 0.0, "pitch": -12.0, "distance": 6.0},
		{"name": "camp_close", "at": Vector4(18.0, 1.2, 1.5, -2.5), "yaw": -25.0, "pitch": -18.0, "distance": 4.5},
		{"name": "camp_side", "at": Vector4(25.0, 1.2, -2.0, -2.5), "yaw": 90.0, "pitch": -10.0, "distance": 5.0},
		{"name": "camp_from_farm", "at": Vector4(20.0, 1.2, 4.5, 0.0), "yaw": 0.0, "pitch": -12.0, "distance": 6.0},
		{"name": "camp_combined", "at": Vector4(20.0, 1.2, 4.5, 0.0), "yaw": 0.0, "pitch": -12.0, "distance": 6.0, "engine": "Combined"},
	],
	# The main character, front and back, in the cross-section and in volume view (Ramon, 6 Oct:
	# "can you make a screenshot showing the main character in 2 views").
	"hero": [
		{"name": "front", "at": Vector4(12.0, 1.2, 37.0, 0), "yaw": 180.0, "pitch": -4.0, "distance": 3.2, "set": {"Player": {"_facing": PI}}},
		{"name": "back", "at": Vector4(12.0, 1.2, 37.0, 0), "yaw": 0.0, "pitch": -4.0, "distance": 3.2, "set": {"Player": {"_facing": PI}}},
		{"name": "front_volume", "at": Vector4(12.0, 1.2, 37.0, 0), "yaw": 180.0, "pitch": -4.0, "distance": 3.2, "engine": "Combined", "set": {"Player": {"_facing": PI}}},
		{"name": "back_volume", "at": Vector4(12.0, 1.2, 37.0, 0), "yaw": 0.0, "pitch": -4.0, "distance": 3.2, "engine": "Combined", "set": {"Player": {"_facing": PI}}},
	],
	# The green bit, taken apart: the same view with one thing hidden at a time.
	"cavediag": [
		{"name": "all", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, -45.0)},
		{"name": "no_ground", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, -45.0), "set": {"World/Ground/GroundMesh": {"visible": false}}},
		{"name": "no_hill", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, -45.0), "set": {"World/Ground/GroundMesh": {"visible": true}, "World/Cave/CaveHill": {"visible": false}}},
		{"name": "no_mountains", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, -45.0), "set": {"World/Cave/CaveHill": {"visible": true}, "World/Hills": {"visible": false}}},
		{"name": "top_w8", "top": Vector4(7.5, 0, 18, 8.0), "size": 40.0, "set": {"World/Hills": {"visible": true}}},
		{"name": "top_w10", "top": Vector4(7.5, 0, 18, 10.0), "size": 40.0},
		{"name": "top_w12", "top": Vector4(7.5, 0, 18, 12.0), "size": 40.0},
	],
	# The same from where Ramon stood, at steeper tilts, to find the green bit.
	"cavesweep": [
		{"name": "zw35", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, -35.0)},
		{"name": "zw45", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, -45.0)},
		{"name": "zw55", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, -55.0)},
		{"name": "zw65", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, -65.0)},
		{"name": "zw75", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, -75.0)},
		{"name": "zw45_xw-25", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(-25.0, -45.0)},
		{"name": "zw45_xw25", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(25.0, -45.0)},
		{"name": "zwp35", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, 35.0)},
		{"name": "zwp50", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, 50.0)},
		{"name": "zwp65", "at": Vector4(7.5, 1.2, 31.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 8.0, "tilt": Vector2(0.0, 65.0)},
	],
	# The Watchstone (PenLayout/PLAN_WATCHSTONE.md), in the Lookout's place since step 11: from the
	# painting's angle, at its foot, on its top with Wren, through W, in volume view.
	"watchstone": [
		{"name": "ref", "at": Vector4(-6.0, 1.2, -22.0, 0), "yaw": 36.0, "pitch": 12.0, "distance": 11.0},
		{"name": "front", "at": Vector4(-16.5, 1.2, -18.0, 0), "yaw": 0.0, "pitch": 16.0, "distance": 10.0},
		{"name": "path_end", "at": Vector4(-18.5, 1.2, -27.4, 0), "yaw": 30.0, "pitch": 18.0, "distance": 6.0},
		{"name": "side", "at": Vector4(-1.0, 1.2, -36.0, 0), "yaw": 90.0, "pitch": 14.0, "distance": 9.0},
		{"name": "arrive", "at": Vector4(-17.4, 15.0, -34.7, 0), "yaw": 0.0, "pitch": -8.0, "distance": 3.0},
		{"name": "wren_close", "at": Vector4(-15.4, 15.0, -36.3, 0), "yaw": 0.0, "pitch": -4.0, "distance": 2.6},
		{"name": "way_down", "at": Vector4(-14.8, 15.0, -34.9, 0), "yaw": -40.0, "pitch": -16.0, "distance": 4.0},
		{"name": "w15", "at": Vector4(-16.5, 1.2, -18.0, 1.5), "yaw": 0.0, "pitch": 16.0, "distance": 10.0},
		{"name": "combined", "at": Vector4(-16.5, 1.2, -18.0, 0), "yaw": 0.0, "pitch": 16.0, "distance": 10.0, "engine": "Combined"},
		{"name": "from_pen", "at": Vector4(0.0, 1.2, -4.0, 0), "yaw": 28.0, "pitch": 6.0, "distance": 7.0},
	],
	# The range, remade (PenLayout/PLAN_WATCHSTONE.md part C), where the old one stands, it hidden.
	"rune_range": [
		{"name": "arrive", "at": Vector4(-13.5, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 14.0, "distance": 6.0},
		{"name": "ref", "at": Vector4(-13.0, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 24.0, "distance": 11.0},
		{"name": "table", "at": Vector4(-15.3, 1.2, -7.0, 0), "yaw": 130.0, "pitch": 6.0, "distance": 3.5},
		{"name": "boards", "at": Vector4(-23.0, 1.2, -7.6, 0), "yaw": 90.0, "pitch": 4.0, "distance": 4.5},
		{"name": "stone", "at": Vector4(-15.4, 1.2, -9.0, 0), "yaw": 70.0, "pitch": -14.0, "distance": 3.0},
		{"name": "w1", "at": Vector4(-13.0, 1.2, -7.5, 1.0), "yaw": 90.0, "pitch": 24.0, "distance": 11.0},
		{"name": "combined", "at": Vector4(-13.0, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 24.0, "distance": 11.0, "engine": "Combined"},
	],
	# Ramon's round of 6 Oct afternoon: the range without its ground boxes and grass, the camp's sand
	# painted (the ring at the farm's W, its floor at its own), the cave's sides, the wider paths, and
	# the ground's greens against the mountains' foot.
	"round4": [
		{"name": "range_ref", "at": Vector4(-13.0, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 24.0, "distance": 11.0},
		{"name": "range_arrive", "at": Vector4(-13.5, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 14.0, "distance": 6.0},
		{"name": "range_back", "at": Vector4(-21.0, 1.2, -7.5, 0), "yaw": 70.0, "pitch": 10.0, "distance": 6.0},
		{"name": "range_top", "top": Vector4(-19.0, 0, -7.5, 0.0), "size": 26.0},
		{"name": "camp_ring_w0", "at": Vector4(20.0, 1.2, 6.0, 0.0), "yaw": 0.0, "pitch": -22.0, "distance": 8.0},
		{"name": "camp_w25", "at": Vector4(20.0, 1.2, 6.0, -2.5), "yaw": 0.0, "pitch": -22.0, "distance": 8.0},
		{"name": "camp_close", "at": Vector4(18.0, 1.2, 1.5, -2.5), "yaw": -25.0, "pitch": -18.0, "distance": 4.5},
		{"name": "camp_top_w0", "top": Vector4(20.0, 0, -2.0, 0.0), "size": 22.0},
		{"name": "camp_top_w25", "top": Vector4(20.0, 0, -2.0, -2.5), "size": 22.0},
		{"name": "cave_front_w4", "at": Vector4(7.5, 1.2, 37.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "cave_near_w4", "at": Vector4(9.5, 1.2, 31.0, 4.0), "yaw": -15.0, "pitch": 6.0, "distance": 4.0},
		{"name": "cave_tunnel_w4", "at": Vector4(7.5, 1.2, 25.0, 4.0), "yaw": 0.0, "pitch": 0.0, "distance": 2.0},
		{"name": "paths_close", "at": Vector4(-8.0, 1.2, 12.0, 0), "yaw": 160.0, "pitch": -30.0, "distance": 4.0, "paths": {"look": "walk", "show_marks": false, "show_sand": true}},
		{"name": "paths_fork", "at": Vector4(-4.5, 1.2, 4.5, 0), "yaw": 0.0, "pitch": -22.0, "distance": 7.0, "paths": {"look": "walk", "show_marks": false, "show_sand": true}},
		{"name": "greens_hills", "at": Vector4(0.0, 1.2, 20.0, 0), "yaw": 180.0, "pitch": 4.0, "distance": 6.0},
		{"name": "greens_pen", "at": Vector4(0.0, 1.2, -4.0, 0), "yaw": 8.0, "pitch": 2.0, "distance": 6.0},
	],
	# The ground's greens (Ramon, 6 Oct: the painted ground "a different color green than the source
	# ground, and the green of the start of the mountains"): out to the hills three ways, painted and not.
	"greens": [
		{"name": "eastB_paint", "at": Vector4(25.0, 1.2, 15.0, 0), "yaw": -90.0, "pitch": 1.0, "distance": 4.0},
		{"name": "eastA_paint", "at": Vector4(0.0, 1.2, 22.0, 0), "yaw": 180.0, "pitch": 1.0, "distance": 4.0},
		{"name": "west_paint", "at": Vector4(-26.0, 1.2, 12.0, 0), "yaw": 90.0, "pitch": 1.0, "distance": 4.0},
		{"name": "pen_paint", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0},
		{"name": "eastB_source", "at": Vector4(25.0, 1.2, 15.0, 0), "yaw": -90.0, "pitch": 1.0, "distance": 4.0, "set": {"World/Grass": {"ground_paint": false}}},
		{"name": "eastA_source", "at": Vector4(0.0, 1.2, 22.0, 0), "yaw": 180.0, "pitch": 1.0, "distance": 4.0},
		{"name": "west_source", "at": Vector4(-26.0, 1.2, 12.0, 0), "yaw": 90.0, "pitch": 1.0, "distance": 4.0},
		{"name": "pen_source", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0},
	],
	# The two ways to one green, to choose between. A: the glow's green over the whole field, so the
	# field runs into the mountains' foot (measured the same green) with no dark band between. B: only
	# the sand painted, the field the ground's own green, unadjusted.
	"greens_ab": [
		{"name": "A_east", "at": Vector4(25.0, 1.2, 15.0, 0), "yaw": -90.0, "pitch": 1.0, "distance": 4.0,
			"set": {"World/Grass": {"glow_in": 60.0, "glow_out": 150.0, "glow_w": 60.0, "ground_glow": true}}},
		{"name": "A_south", "at": Vector4(0.0, 1.2, 22.0, 0), "yaw": 180.0, "pitch": 1.0, "distance": 4.0},
		{"name": "A_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0},
		{"name": "A_high", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "B_east", "at": Vector4(25.0, 1.2, 15.0, 0), "yaw": -90.0, "pitch": 1.0, "distance": 4.0,
			"set": {"World/Grass": {"glow_in": 12.0, "glow_out": 40.0, "glow_w": 30.0, "paint_brightness": 1.0, "paint_saturation": 1.0, "ground_glow": false}}},
		{"name": "B_south", "at": Vector4(0.0, 1.2, 22.0, 0), "yaw": 180.0, "pitch": 1.0, "distance": 4.0},
		{"name": "B_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0},
		{"name": "B_high", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "now_high", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0,
			"set": {"World/Grass": {"paint_brightness": 0.88, "paint_saturation": 0.85, "ground_glow": true}}},
	],
	# A as built (World/Grass even_green, on by default), then switched off: the falloff back.
	"even": [
		{"name": "on_east", "at": Vector4(25.0, 1.2, 15.0, 0), "yaw": -90.0, "pitch": 1.0, "distance": 4.0},
		{"name": "on_join", "at": Vector4(38.0, 1.2, 10.0, 0), "yaw": -90.0, "pitch": -2.0, "distance": 4.0},
		{"name": "on_high", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "on_hill", "at": Vector4(0.0, 1.2, -4.0, 0), "yaw": 8.0, "pitch": 2.0, "distance": 6.0},
		{"name": "on_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0},
		{"name": "off_east", "at": Vector4(25.0, 1.2, 15.0, 0), "yaw": -90.0, "pitch": 1.0, "distance": 4.0, "set": {"World/Grass": {"even_green": false}}},
		{"name": "off_join", "at": Vector4(38.0, 1.2, 10.0, 0), "yaw": -90.0, "pitch": -2.0, "distance": 4.0},
		{"name": "off_high", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "off_hill", "at": Vector4(0.0, 1.2, -4.0, 0), "yaw": 8.0, "pitch": 2.0, "distance": 6.0},
	],

	# The main green picker (grass panel, terrain/main_green_4d.gd), driven through the panel itself: a
	# clearly different green picked, rebaked, switched off and on, then the first green back and baked.
	"picker": [
		{"name": "a_now_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0},
		{"name": "a_now_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "a_now_cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "b_picked_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0,
			"call": {"GrassPanel": ["_on_swatch", Color(0.17, 0.36, 0.30)]}},
		{"name": "c_baked_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"GrassPanel": ["_rebake"]}},
		{"name": "c_baked_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "c_baked_cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "c_baked_east", "at": Vector4(38.0, 1.2, 10.0, 0), "yaw": -90.0, "pitch": -2.0, "distance": 4.0},
		{"name": "c_baked_range", "at": Vector4(-21.0, 1.2, -7.5, 0), "yaw": 70.0, "pitch": 10.0, "distance": 6.0},
		{"name": "d_off_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "call": {"GrassPanel": ["_toggle_even"]}},
		{"name": "e_on_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "call": {"GrassPanel": ["_toggle_even"]}},
		{"name": "f_first_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"GrassPanel": ["_first_green"]}},
		{"name": "g_first_baked_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "call": {"GrassPanel": ["_rebake"]}},
		{"name": "g_first_baked_cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
	],
	# The dev look's fixed viewpoints (PenLayout/PLAN_DEV_LOOK.md steps 3, 30, 42, 56, 73): taken with
	# tag=<when>, in whichever look the pen opens in (PEN_LOOK=dev|art in the environment).
	"lookview": [
		{"name": "pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0},
		{"name": "tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "cavedoor", "at": Vector4(7.5, 1.2, 37.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "camp", "at": Vector4(20.0, 1.2, 6.0, -2.5), "yaw": 0.0, "pitch": -22.0, "distance": 8.0},
		{"name": "ring", "at": Vector4(20.0, 1.2, 6.0, 0.0), "yaw": 0.0, "pitch": -22.0, "distance": 8.0},
		{"name": "range", "at": Vector4(-13.0, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 24.0, "distance": 11.0},
		{"name": "start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "shed", "at": Vector4(-4.0, 1.2, 33.0, 0), "yaw": 70.0, "pitch": -8.0, "distance": 8.0},
		{"name": "wall", "at": Vector4(-11.2, 1.2, 23.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 6.0},
		{"name": "east", "at": Vector4(25.0, 1.2, 15.0, 0), "yaw": -90.0, "pitch": 1.0, "distance": 4.0},
		{"name": "top", "top": Vector4(-2, 0, 8, 0), "size": 92.0},
	],
	# The map from above (Ramon, 6 Oct: "create a topview of the current map. one in dev look, one in
	# final look"): the farm's slice, every path shown (not found-as-you-go), no panels. Run once with
	# PEN_LOOK=dev and once with PEN_LOOK=art.
	"topmap": [
		{"name": "map", "top": Vector4(-2, 0, 8, 0), "size": 96.0, "paths": {"reveal": false},
			"set": {"UI/GrassPanel": {"process_mode": Node.PROCESS_MODE_DISABLED}}, "hide": ["UI/GrassPanel", "Player/StateLabel"]},
	],
	# The range down its yard, flat, turned 45 degrees and a quarter into W, and from above (Ramon, 6 Oct:
	# "shooting range doesnt slice well. you used the fence tech?"): tag=before / tag=after.
	"range4d": [
		{"name": "flat", "at": Vector4(-17.0, 1.2, 2.4, 0), "yaw": 90.0, "pitch": 10.0, "distance": 6.0},
		{"name": "turned45", "at": Vector4(-17.0, 1.2, 2.4, 0), "yaw": 90.0, "pitch": 10.0, "distance": 6.0, "tilt": Vector2(45.0, 0.0)},
		{"name": "turned90", "at": Vector4(-17.0, 1.2, 2.4, 0), "yaw": 90.0, "pitch": 10.0, "distance": 6.0, "tilt": Vector2(90.0, 0.0)},
		{"name": "w15", "at": Vector4(-17.0, 1.2, 2.4, 1.5), "yaw": 90.0, "pitch": 10.0, "distance": 6.0},
		{"name": "close_boards", "at": Vector4(-26.0, 1.2, 2.4, 0), "yaw": 90.0, "pitch": 4.0, "distance": 4.0},
		{"name": "close_boards_turned", "at": Vector4(-26.0, 1.2, 2.4, 0), "yaw": 90.0, "pitch": 4.0, "distance": 4.0, "tilt": Vector2(90.0, 0.0)},
		{"name": "top", "top": Vector4(-27.0, 0, 2.4, 0.0), "size": 18.0},
	],
	# The detailed oak up on the Lookout rock, and the light ones below (Ramon, 6 Oct: "move the detailed
	# oak tree to the top of the lookout rock"). The rock's plateau is at y 13.65 over (-16, -36).
	"oaktop": [
		{"name": "rock", "at": Vector4(-6.0, 1.2, -20.0, 0), "yaw": 34.0, "pitch": 14.0, "distance": 10.0},
		{"name": "rock_far", "at": Vector4(0.0, 1.2, -4.0, 0), "yaw": 30.0, "pitch": 8.0, "distance": 8.0},
		{"name": "plateau", "at": Vector4(-14.0, 14.9, -32.0, 0), "yaw": 210.0, "pitch": -6.0, "distance": 5.0},
		{"name": "shed_oaks", "at": Vector4(-22.0, 1.2, 31.0, 0), "yaw": 180.0, "pitch": 6.0, "distance": 7.0},
	],
	# Layout B, round 2 (PenLayout/PLAN_B_ROUND2.md; Ramon's notes of 7 Oct): one frame per note, taken
	# tag=before and tag=after, in both looks (PEN_LOOK=art / dev).
	"round2": [
		{"name": "01_pen_sand", "at": Vector4(-10.5, 1.2, 37.1, 0), "yaw": 90.0, "pitch": -20.0, "distance": 7.0},
		{"name": "02_pen_top", "top": Vector4(-19.2, 0, 37.1, 0), "size": 22.0},
		{"name": "03_range_rings", "at": Vector4(-26.0, 1.2, 2.4, 0), "yaw": 90.0, "pitch": 4.0, "distance": 3.0},
		{"name": "04_range_yard", "at": Vector4(-16.0, 1.2, 2.4, 0), "yaw": 90.0, "pitch": -18.0, "distance": 6.0},
		{"name": "05_range_top", "top": Vector4(-24.0, 0, 2.6, 0), "size": 22.0},
		{"name": "06_camp_path", "at": Vector4(6.0, 1.2, -4.0, -2.5), "yaw": -90.0, "pitch": -20.0, "distance": 6.0},
		{"name": "07_camp_top", "top": Vector4(13.0, 0, -4.0, -2.5), "size": 22.0},
		{"name": "08_tower_sand", "at": Vector4(-11.0, 1.2, -27.0, 0), "yaw": 30.0, "pitch": -25.0, "distance": 6.0},
		{"name": "09_tower_top", "top": Vector4(-15.0, 0, -32.0, 0), "size": 22.0},
		{"name": "10_cave_mouth", "at": Vector4(7.4, 1.2, 34.0, 4.0), "yaw": 0.0, "pitch": -12.0, "distance": 6.0},
		{"name": "11_cave_top", "top": Vector4(7.5, 0, 28.0, 4.0), "size": 22.0},
		{"name": "12_hills_west", "at": Vector4(-22.0, 1.2, 20.0, 0), "yaw": 90.0, "pitch": 2.0, "distance": 7.0},
		{"name": "13_mounds", "at": Vector4(26.0, 1.2, -2.0, 0), "yaw": 0.0, "pitch": 0.0, "distance": 7.0},
		{"name": "14_mithra", "at": Vector4(-7.5, 1.2, -2.0, 0), "yaw": 180.0, "pitch": -6.0, "distance": 6.0},
		{"name": "15_professor", "at": Vector4(3.6, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -4.0, "distance": 4.0},
		{"name": "16_gate", "at": Vector4(-11.6, 1.2, 20.0, 0), "yaw": 0.0, "pitch": -2.0, "distance": 6.0},
		{"name": "17_trees", "at": Vector4(0.0, 1.2, 40.0, 0), "yaw": 180.0, "pitch": 0.0, "distance": 6.0},
		{"name": "18_tower_oak", "at": Vector4(-6.0, 1.2, -20.0, 0), "yaw": 34.0, "pitch": 14.0, "distance": 10.0},
		{"name": "19_balloon", "at": Vector4(-14.0, 1.2, -18.0, 0), "yaw": 25.0, "pitch": 6.0, "distance": 8.0},
		{"name": "20_grass_edge", "at": Vector4(20.0, 1.2, 40.0, 0), "yaw": 0.0, "pitch": -16.0, "distance": 5.0},
	],
	# The pen house by the fence tech (7 Oct: "ramake penhouse with the fence set where possible. but make it look
	# like the original house"; pen_coop_4d.gd fence_walls): the coop at (-22.3, 37.1), its door east. Old:
	# pre=Pen/Coop:fence_walls=false.
	"coop": [
		{"name": "door", "at": Vector4(-18.0, 1.2, 37.1, 0), "yaw": 90.0, "pitch": -10.0, "distance": 4.0, "hide": ["Player/Avatar"]},
		{"name": "side", "at": Vector4(-21.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -8.0, "distance": 4.0, "hide": ["Player/Avatar"]},
		{"name": "turn20", "at": Vector4(-18.0, 1.2, 37.1, 0), "yaw": 90.0, "pitch": -10.0, "distance": 4.0, "tilt": Vector2(20.0, 0.0), "hide": ["Player/Avatar"]},
		{"name": "turn45", "at": Vector4(-18.0, 1.2, 37.1, 0), "yaw": 90.0, "pitch": -10.0, "distance": 4.0, "tilt": Vector2(45.0, 0.0), "hide": ["Player/Avatar"]},
		{"name": "turn90", "at": Vector4(-18.0, 1.2, 37.1, 0), "yaw": 90.0, "pitch": -10.0, "distance": 4.0, "tilt": Vector2(90.0, 0.0), "hide": ["Player/Avatar"]},
		{"name": "w1", "at": Vector4(-18.0, 1.2, 37.1, 1.0), "yaw": 90.0, "pitch": -10.0, "distance": 4.0, "hide": ["Player/Avatar"]},
		{"name": "top", "top": Vector4(-21.0, 0, 37.1, 0), "size": 9.0},
		{"name": "close", "at": Vector4(-19.4, 1.2, 37.1, 0), "yaw": 90.0, "pitch": -6.0, "distance": 1.6, "hide": ["Player/Avatar"]},
		{"name": "close_corner", "at": Vector4(-19.6, 1.2, 35.6, 0), "yaw": 60.0, "pitch": -6.0, "distance": 1.6, "hide": ["Player/Avatar"]},
	],
	# Volume view (Ramon, 7 Oct: "dont forget to use volume view and take screenshots, dont just rely on code"):
	# the coop, the planting with its W layers, the range and the tower, projected (the whole 4D shape seen
	# at once) and combined (the slice inside its volume).
	"volume": [
		{"name": "coop_projected", "at": Vector4(-18.0, 1.2, 37.1, 0), "yaw": 90.0, "pitch": -10.0, "distance": 4.0, "engine": "Projected", "hide": ["Player/Avatar"]},
		{"name": "coop_combined", "at": Vector4(-18.0, 1.2, 37.1, 0), "yaw": 90.0, "pitch": -10.0, "distance": 4.0, "engine": "Combined", "hide": ["Player/Avatar"]},
		{"name": "trees_projected", "at": Vector4(14.0, 1.2, 2.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0, "engine": "Projected"},
		{"name": "trees_combined", "at": Vector4(14.0, 1.2, 2.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0, "engine": "Combined"},
		{"name": "trees_top_projected", "top": Vector4(28.0, 0, 6.0, 0), "size": 40.0, "engine": "Projected"},
		{"name": "range_projected", "at": Vector4(-16.0, 1.2, 2.4, 0), "yaw": 90.0, "pitch": -12.0, "distance": 6.0, "engine": "Projected"},
		{"name": "range_combined", "at": Vector4(-16.0, 1.2, 2.4, 0), "yaw": 90.0, "pitch": -12.0, "distance": 6.0, "engine": "Combined"},
		{"name": "tower_projected", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "engine": "Projected"},
		{"name": "tower_combined", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "engine": "Combined"},
	],
	# The planting through W (7 Oct: "more trees have to be placed in the W ... now they just dissapear instant
	# when you rotate the slice"; scripts/pen_trees_4d.gd): three wooded spots, flat and the slice turned.
	"wturn": [
		{"name": "eastA_00", "at": Vector4(14.0, 1.2, 2.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0},
		{"name": "eastA_08", "at": Vector4(14.0, 1.2, 2.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0, "tilt": Vector2(8.0, 0.0)},
		{"name": "eastA_16", "at": Vector4(14.0, 1.2, 2.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0, "tilt": Vector2(16.0, 0.0)},
		{"name": "eastA_30", "at": Vector4(14.0, 1.2, 2.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0, "tilt": Vector2(30.0, 0.0)},
		{"name": "west_00", "at": Vector4(-22.0, 1.2, -12.0, 0), "yaw": 100.0, "pitch": 2.0, "distance": 6.0},
		{"name": "west_08", "at": Vector4(-22.0, 1.2, -12.0, 0), "yaw": 100.0, "pitch": 2.0, "distance": 6.0, "tilt": Vector2(8.0, 0.0)},
		{"name": "west_16", "at": Vector4(-22.0, 1.2, -12.0, 0), "yaw": 100.0, "pitch": 2.0, "distance": 6.0, "tilt": Vector2(16.0, 0.0)},
		{"name": "west_30", "at": Vector4(-22.0, 1.2, -12.0, 0), "yaw": 100.0, "pitch": 2.0, "distance": 6.0, "tilt": Vector2(30.0, 0.0)},
		{"name": "eastB_00", "at": Vector4(16.0, 1.2, 24.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0},
		{"name": "eastB_08", "at": Vector4(16.0, 1.2, 24.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0, "tilt": Vector2(8.0, 0.0)},
		{"name": "eastB_16", "at": Vector4(16.0, 1.2, 24.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0, "tilt": Vector2(16.0, 0.0)},
		{"name": "eastB_30", "at": Vector4(16.0, 1.2, 24.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0, "tilt": Vector2(30.0, 0.0)},
	],
	# One oak alone, the same shot in both looks (7 Oct: "SCALE BLUE TREEBLOCKS a bit larger upward so they
	# match the artlook more"): OakL03 (lite3, 5.7 m) and OakL20 (lite3, 5.8 m), from 12 m.
	"treecmp": [
		{"name": "oakl03", "at": Vector4(-19.0, 1.2, -6.84, 0), "yaw": 90.0, "pitch": 4.0, "distance": 3.5, "hide": ["Player/Avatar"]},
		{"name": "oakl20", "at": Vector4(-25.34, 1.2, 43.0, 0), "yaw": 180.0, "pitch": 4.0, "distance": 3.5, "hide": ["Player/Avatar"]},
	],
	# Layout B along Ramon's route (PenLayout/PLAN_B.md step 40): start, Trym, the cave, the pen, the gate
	# both ways, the range, the camp, the tower road, the meadow and a tree belt.
	"layoutb": [
		{"name": "01_start", "at": Vector4(24.9, 1.2, 19.5, 0), "yaw": 180.0, "pitch": -10.0, "distance": 7.0},
		{"name": "02_trym", "at": Vector4(24.9, 1.2, 35.5, 0), "yaw": 180.0, "pitch": -8.0, "distance": 7.0},
		{"name": "03_cave", "at": Vector4(7.3, 1.2, 39.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 8.0},
		{"name": "03b_cave_door", "at": Vector4(7.4, 1.2, 33.0, 4.0), "yaw": 0.0, "pitch": -4.0, "distance": 6.0},
		{"name": "04_pen", "at": Vector4(-8.0, 1.2, 37.1, 0), "yaw": 90.0, "pitch": -12.0, "distance": 8.0},
		{"name": "05_gate_south", "at": Vector4(-11.0, 1.2, 22.0, 0), "yaw": 0.0, "pitch": -2.0, "distance": 7.0},
		{"name": "06_gate_north", "at": Vector4(-12.0, 1.2, 4.0, 0), "yaw": 180.0, "pitch": -2.0, "distance": 7.0},
		{"name": "07_range", "at": Vector4(-15.0, 1.2, 2.1, 0), "yaw": 90.0, "pitch": -6.0, "distance": 7.0},
		{"name": "08_camp", "at": Vector4(0.0, 1.2, -4.0, 0), "yaw": -90.0, "pitch": -8.0, "distance": 7.0},
		{"name": "09_tower_road", "at": Vector4(-14.0, 1.2, -10.0, 0), "yaw": 15.0, "pitch": 6.0, "distance": 8.0},
		{"name": "10_meadow", "at": Vector4(-10.0, 1.2, -26.0, 0), "yaw": -70.0, "pitch": 6.0, "distance": 6.0},
		{"name": "11_west_belt", "at": Vector4(-22.0, 1.2, -12.0, 0), "yaw": 100.0, "pitch": 2.0, "distance": 7.0},
		{"name": "12_south_belt", "at": Vector4(0.0, 1.2, 40.0, 0), "yaw": 180.0, "pitch": 0.0, "distance": 6.0},
		{"name": "13_east_trees", "at": Vector4(16.0, 1.2, 24.0, 0), "yaw": -90.0, "pitch": 4.0, "distance": 5.0},
	],
	# The big oak and the light one beside it (Ramon, 6 Oct: "put an oak next to it, heavily optimised").
	"oakpen": [
		{"name": "both", "at": Vector4(-22.0, 1.2, 31.0, 0), "yaw": 180.0, "pitch": 6.0, "distance": 7.0},
		{"name": "both_far", "at": Vector4(-22.0, 1.2, 24.0, 0), "yaw": 180.0, "pitch": 4.0, "distance": 9.0},
	],
	# The cave in the dev look: its own hill baked coarser, not a wedge (Ramon, 6 Oct: "keep the original
	# cave in the greybox version. just lower res"). Run with PEN_LOOK=dev (and =art to compare).
	"lowcave": [
		{"name": "cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "cavedoor", "at": Vector4(7.5, 1.2, 37.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "cave_side", "at": Vector4(-4.0, 1.2, 22.0, 0), "yaw": 60.0, "pitch": -10.0, "distance": 8.0},
	],
	# The paths close and at a distance, every one shown (Ramon, 6 Oct: "the beige paths look like
	# they're always clipping"): taken before and after the lift, tag=before / tag=after.
	"pathclip": [
		{"name": "fork", "at": Vector4(-4.5, 1.2, 4.5, 0), "yaw": 0.0, "pitch": -22.0, "distance": 7.0, "paths": {"reveal": false}},
		{"name": "long", "at": Vector4(-8.0, 1.2, 12.0, 0), "yaw": 160.0, "pitch": -10.0, "distance": 5.0, "paths": {"reveal": false}},
		{"name": "ring", "at": Vector4(9.0, 1.2, 4.0, 0), "yaw": -70.0, "pitch": -12.0, "distance": 6.0, "paths": {"reveal": false}},
		{"name": "start", "at": Vector4(4.0, 1.2, 40.0, 0), "yaw": 0.0, "pitch": -10.0, "distance": 6.0, "paths": {"reveal": false}},
	],
	# The dev palette, three ways (PenLayout/PLAN_DEV_LOOK.md step 10): A the defaults, B lighter,
	# C darker. Run in the dev look (PEN_LOOK=dev).
	"lookpalette": [
		{"name": "A_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "set": {"Systems/Look": {"key_energy": 0.45, "fill_energy": 0.2, "ambient": Color(0.42, 0.44, 0.48), "ambient_sky": 0.3}}, "call": {"Systems/Look": ["reapply"]}},
		{"name": "A_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "A_start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "A_east", "at": Vector4(25.0, 1.2, 15.0, 0), "yaw": -90.0, "pitch": 1.0, "distance": 4.0},
		{"name": "B_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "set": {"Systems/Look": {"key_energy": 0.6, "fill_energy": 0.25, "ambient": Color(0.5, 0.52, 0.56), "ambient_sky": 0.3}}, "call": {"Systems/Look": ["reapply"]}},
		{"name": "B_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "B_start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "B_east", "at": Vector4(25.0, 1.2, 15.0, 0), "yaw": -90.0, "pitch": 1.0, "distance": 4.0},
		{"name": "C_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "set": {"Systems/Look": {"key_energy": 0.35, "fill_energy": 0.15, "ambient": Color(0.36, 0.38, 0.42), "ambient_sky": 0.25}}, "call": {"Systems/Look": ["reapply"]}},
		{"name": "C_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "C_start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "C_east", "at": Vector4(25.0, 1.2, 15.0, 0), "yaw": -90.0, "pitch": 1.0, "distance": 4.0},
	],

	# A walk through the pen in whichever look it opens in (PLAN_DEV_LOOK.md step 58): the start, the
	# fork, the cave door at W 4, the pen, the wall's arch, the Watchstone, the range, the camp's ring
	# and the camp at W -2.5. Each place walked to, so the reveal finds the paths as a player would.
	"lookwalk": [
		{"name": "01_start", "at": Vector4(4.0, 1.2, 40.0, 0), "yaw": 0.0, "pitch": -8.0, "distance": 5.0},
		{"name": "02_arch", "at": Vector4(-11.2, 1.2, 25.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "walk": [Vector4(-6.0, 1.2, 32.0, 0), Vector4(-11.2, 1.2, 25.0, 0)]},
		{"name": "03_cave_door", "at": Vector4(7.5, 1.2, 36.0, 4.0), "yaw": 0.0, "pitch": -4.0, "distance": 5.0},
		{"name": "04_fork", "at": Vector4(-4.5, 1.2, 6.0, 0), "yaw": 0.0, "pitch": -12.0, "distance": 6.0, "walk": [Vector4(-8.0, 1.2, 14.0, 0), Vector4(-4.5, 1.2, 6.0, 0)]},
		{"name": "05_pen", "at": Vector4(2.0, 1.2, -2.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "06_tower", "at": Vector4(-10.0, 1.2, -20.0, 0), "yaw": 30.0, "pitch": 8.0, "distance": 7.0, "walk": [Vector4(-6.0, 1.2, -12.0, 0), Vector4(-10.0, 1.2, -20.0, 0)]},
		{"name": "07_range", "at": Vector4(-12.5, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 10.0, "distance": 6.0},
		{"name": "08_ring", "at": Vector4(16.0, 1.2, 4.0, 0.0), "yaw": -20.0, "pitch": -16.0, "distance": 7.0, "walk": [Vector4(10.0, 1.2, 2.0, 0), Vector4(16.0, 1.2, 4.0, 0)]},
		{"name": "09_camp", "at": Vector4(20.0, 1.2, 5.0, -2.5), "yaw": 0.0, "pitch": -16.0, "distance": 7.0},
		{"name": "10_marsh", "at": Vector4(-30.0, 1.2, -16.0, 8.0), "yaw": 0.0, "pitch": -16.0, "distance": 7.0},
	],
	# The pen enclosure's frame in the dev look, close.
	"lookpen": [
		{"name": "pen_frame", "at": Vector4(2.0, 1.2, -2.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "pen_frame_high", "at": Vector4(0.0, 1.2, -2.0, 0), "yaw": 0.0, "pitch": -40.0, "distance": 12.0},
	],
	# The Watchstone's other blockout: three blocks (Systems/Look tower_three_blocks).
	"looktower3": [
		{"name": "tower3", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "set": {"Systems/Look": {"tower_three_blocks": true}}},
	],
	# The pen's own switch, timed (PLAN_DEV_LOOK.md step 57): opened in DEV, the first switch to the art,
	# back, and again (helper=dev_look_probe_4d.gd).
	"lookswitch": [
		{"name": "s1_dev", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0},
		{"name": "s2_first_art", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["pen_look", false]}},
		{"name": "s3_dev_again", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["pen_look", true]}},
		{"name": "s4_art_again", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["pen_look", false]}},
	],
	# Frame and GPU time at three of them (helper=dev_look_probe_4d.gd, which only measures here).
	"lookperf": [
		{"name": "perf_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["measure", "pen", 150]}},
		{"name": "perf_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "call": {"DevProbe": ["measure", "tower", 150]}},
		{"name": "perf_cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0, "call": {"DevProbe": ["measure", "cave", 150]}},
	],
	# The dev look case study (PenLayout/DEV_LOOK_STUDY.md), built live by dev_look_probe_4d.gd
	# (helper=res://ramon/PenLayout/scripts/dev_look_probe_4d.gd): the pen as it is, then clay (its own
	# meshes flat blue/red, ground and mountains white, the paths' arrows), then blocks (each
	# landmark's colliders drawn instead of it), then back, each look measured.
	"devlook": [
		{"name": "art_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["measure", "art", 150]}},
		{"name": "clay_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["switch_cost", "clay"]}},
		{"name": "clay_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "clay_cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "clay_cavedoor", "at": Vector4(7.5, 1.2, 37.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "clay_camp", "at": Vector4(20.0, 1.2, 6.0, -2.5), "yaw": 0.0, "pitch": -22.0, "distance": 8.0},
		{"name": "clay_range", "at": Vector4(-13.0, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 24.0, "distance": 11.0},
		{"name": "clay_start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "clay_top", "top": Vector4(-2, 0, 8, 0), "size": 92.0},
		{"name": "clay_check", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["check"]}},
		{"name": "clay_measure", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["measure", "clay", 150]}},
		{"name": "blocks_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["switch_cost", "blocks"]}},
		{"name": "blocks_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "blocks_cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "blocks_cavedoor", "at": Vector4(7.5, 1.2, 37.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "blocks_camp", "at": Vector4(20.0, 1.2, 6.0, -2.5), "yaw": 0.0, "pitch": -22.0, "distance": 8.0},
		{"name": "blocks_range", "at": Vector4(-13.0, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 24.0, "distance": 11.0},
		{"name": "blocks_start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "blocks_top", "top": Vector4(-2, 0, 8, 0), "size": 92.0},
		{"name": "blocks_check", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["check"]}},
		{"name": "blocks_measure", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["measure", "blocks", 150]}},
		{"name": "back_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["switch_cost", "art"]}},
		{"name": "back_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "back_check", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["check"]}},
		{"name": "back_measure", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["measure", "art again", 150]}},
	],
	# Ramon's round on the study (6 Oct): simpler blockouts (the Watchstone a cylinder, or three
	# blocks; the cave a wedge with its door) and the sky swapped too (dev_look_probe_4d.gd simple).
	"devsimple": [
		{"name": "simple_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["switch_cost", "simple"]}},
		{"name": "simple_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "simple_cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "simple_cavedoor", "at": Vector4(7.5, 1.2, 37.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "simple_camp", "at": Vector4(20.0, 1.2, 6.0, -2.5), "yaw": 0.0, "pitch": -22.0, "distance": 8.0},
		{"name": "simple_range", "at": Vector4(-13.0, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 24.0, "distance": 11.0},
		{"name": "simple_start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "simple_shed", "at": Vector4(6.0, 1.2, 46.0, 0), "yaw": 30.0, "pitch": -10.0, "distance": 8.0},
		{"name": "simple_top", "top": Vector4(-2, 0, 8, 0), "size": 92.0},
		{"name": "simple_measure", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["measure", "simple", 150]}},
		{"name": "simple3_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "call": {"DevProbe": ["switch_cost", "simple3"]}},
		{"name": "simple3_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0},
		{"name": "clay_sky_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["switch_cost", "clay"]}},
		{"name": "clay_sky_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "clay_sky_cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "back_art_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["switch_cost", "art"]}},
		{"name": "back_art_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "back_art_check", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["check"]}},
	],
	# The art itself from the study's viewpoints that had no art frame yet.
	"devart": [
		{"name": "art_top", "top": Vector4(-2, 0, 8, 0), "size": 92.0},
		{"name": "art_cavedoor", "at": Vector4(7.5, 1.2, 37.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
	],
	# The third automatic blockout: each piece of art as its own turned box (dev_look_probe_4d.gd boxes).
	"devboxes": [
		{"name": "boxes_pen", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["switch_cost", "boxes"]}},
		{"name": "boxes_tower", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "boxes_cave", "at": Vector4(10.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -20.0, "distance": 12.0},
		{"name": "boxes_cavedoor", "at": Vector4(7.5, 1.2, 37.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "boxes_camp", "at": Vector4(20.0, 1.2, 6.0, -2.5), "yaw": 0.0, "pitch": -22.0, "distance": 8.0},
		{"name": "boxes_range", "at": Vector4(-13.0, 1.2, -7.5, 0), "yaw": 90.0, "pitch": 24.0, "distance": 11.0},
		{"name": "boxes_start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "boxes_top", "top": Vector4(-2, 0, 8, 0), "size": 92.0},
		{"name": "boxes_measure", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["measure", "boxes", 150]}},
	],
	# The pen opened straight into blocks (cold=blocks), the art never drawn: what the first switch
	# to the art costs, then the warm switches.
	"devcold": [
		{"name": "cold_blocks", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["measure", "blocks, cold", 90]}},
		{"name": "cold_first_art", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["switch_cost", "art"]}},
		{"name": "cold_back_blocks", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["switch_cost", "blocks"]}},
		{"name": "cold_art_again", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "call": {"DevProbe": ["switch_cost", "art"]}},
		{"name": "cold_clay", "at": Vector4(-4.0, 1.2, 4.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 5.0, "call": {"DevProbe": ["switch_cost", "clay"]}},
	],
	# The rock kit (PenLayout/PLAN_WATCHSTONE.md step 2): six boulders in a row and two big ones,
	# out in the open east of the hill.
	"rocks": [
		{"name": "front", "at": Vector4(30.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -8.0, "distance": 9.0,
			"spawn": {"res://ramon/PenLayout/Watchstone/rock_study.tscn": Vector4(30.0, 0.0, 22.0, 0.0)}},
		{"name": "close", "at": Vector4(29.0, 1.2, 26.0, 0), "yaw": 0.0, "pitch": -12.0, "distance": 4.0},
		{"name": "side", "at": Vector4(42.0, 1.2, 20.0, 0), "yaw": 90.0, "pitch": -6.0, "distance": 8.0},
		{"name": "w05", "at": Vector4(30.0, 1.2, 30.0, 0.5), "yaw": 0.0, "pitch": -8.0, "distance": 9.0},
		{"name": "w1", "at": Vector4(30.0, 1.2, 30.0, 1.0), "yaw": 0.0, "pitch": -8.0, "distance": 9.0},
		{"name": "combined", "at": Vector4(30.0, 1.2, 30.0, 0), "yaw": 0.0, "pitch": -8.0, "distance": 9.0, "engine": "Combined"},
	],
	# The cave's mouth with the slice turned lengthways (Ramon's screenshot, 6 Oct: "when opening the
	# cave a little green bit is in the back"), from close, at several tilts each way.
	"cavetilt": [
		{"name": "z30_m15", "at": Vector4(7.5, 1.2, 30.5, 0), "yaw": 0.0, "pitch": -2.0, "distance": 6.0, "tilt": Vector2(0.0, -15.0)},
		{"name": "z30_m22", "at": Vector4(7.5, 1.2, 30.5, 0), "yaw": 0.0, "pitch": -2.0, "distance": 6.0, "tilt": Vector2(0.0, -22.0)},
		{"name": "z30_m30", "at": Vector4(7.5, 1.2, 30.5, 0), "yaw": 0.0, "pitch": -2.0, "distance": 6.0, "tilt": Vector2(0.0, -30.0)},
		{"name": "z30_m40", "at": Vector4(7.5, 1.2, 30.5, 0), "yaw": 0.0, "pitch": -2.0, "distance": 6.0, "tilt": Vector2(0.0, -40.0)},
		{"name": "z28_m30", "at": Vector4(7.5, 1.2, 28.5, 0), "yaw": 0.0, "pitch": 0.0, "distance": 4.0, "tilt": Vector2(0.0, -30.0)},
		{"name": "z28_m45", "at": Vector4(7.5, 1.2, 28.5, 0), "yaw": 0.0, "pitch": 0.0, "distance": 4.0, "tilt": Vector2(0.0, -45.0)},
		{"name": "z30_x25", "at": Vector4(7.5, 1.2, 30.5, 0), "yaw": 0.0, "pitch": -2.0, "distance": 6.0, "tilt": Vector2(25.0, -25.0)},
		{"name": "z30_xm25", "at": Vector4(7.5, 1.2, 30.5, 0), "yaw": 0.0, "pitch": -2.0, "distance": 6.0, "tilt": Vector2(-25.0, -25.0)},
	],
	"before": [
		{"name": "top", "top": Vector4(0, 0, -2, 0), "size": 108.0},
		{"name": "top_combined", "top": Vector4(0, 0, -2, 0), "size": 108.0, "engine": "Combined"},
		{"name": "start", "at": Vector4(4.6, 1.2, -2.0, 0), "yaw": 27.1, "pitch": -15.0, "distance": 8.0},
		{"name": "start_combined", "at": Vector4(4.6, 1.2, -2.0, 0), "yaw": 27.1, "pitch": -15.0, "distance": 8.0, "engine": "Combined"},
		{"name": "from_south", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 6.0},
		{"name": "from_shoulder", "at": Vector4(-11.0, 1.2, 9.0, 0), "yaw": 20.0, "pitch": -8.0, "distance": 6.0},
	],
	"paths": [
		{"name": "top", "top": Vector4(-2, 0, 8, 0), "size": 92.0, "paths": {"reveal": false, "show_marks": false, "show_sand": true, "look": "walk"}},
		{"name": "start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "start_west", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -16.0, "distance": 7.0},
		{"name": "wall_w0", "at": Vector4(-10.5, 1.2, 21.0, 0), "yaw": 0.0, "pitch": -18.0, "distance": 6.0},
		{"name": "wall_w15", "at": Vector4(-10.5, 1.2, 21.0, 1.5), "yaw": 0.0, "pitch": -18.0, "distance": 6.0},
		{"name": "wall_combined", "at": Vector4(-10.5, 1.2, 21.0, 0), "yaw": 0.0, "pitch": -18.0, "distance": 6.0, "engine": "Combined"},
		{"name": "door_w0", "at": Vector4(6.0, 1.2, 34.0, 0), "yaw": 10.0, "pitch": -14.0, "distance": 6.0},
		{"name": "door_w4", "at": Vector4(6.0, 1.2, 34.0, 4.0), "yaw": 10.0, "pitch": -14.0, "distance": 6.0},
		{"name": "meadow_ring", "at": Vector4(24.0, 1.2, 8.0, 0), "yaw": -20.0, "pitch": -24.0, "distance": 9.0},
		{"name": "egg1_kata", "at": Vector4(20.0, 1.2, 5.5, -2.5), "yaw": 0.0, "pitch": -18.0, "distance": 6.0},
		{"name": "egg2_ana", "at": Vector4(27.0, 1.2, 17.0, 7.0), "yaw": -30.0, "pitch": -16.0, "distance": 6.0},
		{"name": "gate", "at": Vector4(6.0, 1.2, 2.0, 0), "yaw": 10.0, "pitch": -18.0, "distance": 8.0},
		{"name": "icons_only", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -16.0, "distance": 7.0, "paths": {"show_marks": true, "show_sand": false, "look": "dev"}},
		{"name": "sand_only", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -16.0, "distance": 7.0, "paths": {"show_marks": false, "show_sand": true, "look": "walk"}},
		{"name": "reveal_start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0,
			"paths": {"show_marks": false, "show_sand": true, "reveal": true, "look": "walk"}, "forget": true},
		{"name": "reveal_walked", "at": Vector4(-10.0, 1.2, 23.0, 0), "yaw": 180.0, "pitch": -20.0, "distance": 9.0,
			"walk": [Vector4(4.0, 1.2, 37.0, 0), Vector4(-5.0, 1.2, 31.0, 0), Vector4(-10.0, 1.2, 23.0, 0)]},
		{"name": "reveal_top", "top": Vector4(-2, 0, 8, 0), "size": 92.0},
	],
	"devfloor": [
		{"name": "start_icons", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0, "devfloor": true,
			"paths": {"reveal": false, "show_marks": true, "show_sand": false, "look": "dev"}},
		{"name": "west_icons", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -16.0, "distance": 7.0},
		{"name": "wall_icons", "at": Vector4(-10.5, 1.2, 21.0, 0), "yaw": 0.0, "pitch": -18.0, "distance": 6.0},
		{"name": "gate_icons", "at": Vector4(6.0, 1.2, 2.0, 0), "yaw": 10.0, "pitch": -18.0, "distance": 8.0},
		{"name": "close_icons", "at": Vector4(-6.0, 1.2, 30.5, 0), "yaw": 60.0, "pitch": -40.0, "distance": 4.0},
		{"name": "top_icons", "top": Vector4(-2, 0, 8, 0), "size": 92.0},
		{"name": "west_sand", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -16.0, "distance": 7.0,
			"paths": {"show_sand": true, "show_marks": false, "look": "walk"}},
	],
	"cave": [
		{"name": "front_w4", "at": Vector4(7.5, 1.2, 37.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0, "paths": {"show_marks": false, "show_sand": false}},
		{"name": "front_w0", "at": Vector4(7.5, 1.2, 37.0, 0.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "front_w2", "at": Vector4(7.5, 1.2, 37.0, 2.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "front_w6", "at": Vector4(7.5, 1.2, 37.0, 6.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "front_w8", "at": Vector4(7.5, 1.2, 37.0, 8.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0},
		{"name": "near_w4", "at": Vector4(9.5, 1.2, 31.0, 4.0), "yaw": -15.0, "pitch": 6.0, "distance": 4.0},
		{"name": "tunnel_w4", "at": Vector4(7.5, 1.2, 25.0, 4.0), "yaw": 0.0, "pitch": 0.0, "distance": 2.0},
		{"name": "eastB_w4", "at": Vector4(28.0, 1.2, 15.0, 4.0), "yaw": 90.0, "pitch": -2.0, "distance": 5.0},
		{"name": "west_w4", "at": Vector4(-12.0, 1.2, 15.0, 4.0), "yaw": -90.0, "pitch": -2.0, "distance": 5.0},
		{"name": "back_w4", "at": Vector4(8.0, 1.2, -4.0, 4.0), "yaw": 180.0, "pitch": -2.0, "distance": 5.0},
		{"name": "eastB_w0", "at": Vector4(28.0, 1.2, 15.0, 0.0), "yaw": 90.0, "pitch": -2.0, "distance": 5.0},
		{"name": "top_w4", "top": Vector4(8, 0, 15, 4.0), "size": 40.0},
		{"name": "top_w0", "top": Vector4(8, 0, 15, 0.0), "size": 40.0},
		{"name": "front_combined", "at": Vector4(7.5, 1.2, 37.0, 4.0), "yaw": 0.0, "pitch": -2.0, "distance": 5.0, "engine": "Combined"},
	],
	"tower": [
		{"name": "classic_w0", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0,
			"set": {"World/LookoutSite/Lookout": {"fence_frame": false}}},
		{"name": "classic_w2", "at": Vector4(-7.0, 1.2, -23.0, 2.0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "classic_combined", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "engine": "Combined"},
		{"name": "fence_w0", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0,
			"set": {"World/LookoutSite/Lookout": {"fence_frame": true}}},
		{"name": "fence_w1", "at": Vector4(-7.0, 1.2, -23.0, 1.0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "fence_w2", "at": Vector4(-7.0, 1.2, -23.0, 2.0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "fence_w3", "at": Vector4(-7.0, 1.2, -23.0, 3.1), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "fence_w5", "at": Vector4(-7.0, 1.2, -23.0, 5.0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "fence_ladder", "at": Vector4(-16.0, 1.2, -28.0, 0), "yaw": 0.0, "pitch": 28.0, "distance": 5.0},
		{"name": "fence_deck", "at": Vector4(-16.0, 11.2, -33.6, 0), "yaw": 0.0, "pitch": -4.0, "distance": 5.0},
		{"name": "fence_combined", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "engine": "Combined"},
		{"name": "fence_projected", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "engine": "Projected"},
	],
	"hut": [
		{"name": "shed_classic_w0", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 124.0, "pitch": -6.0, "distance": 6.0},
		{"name": "shed_classic_w1", "at": Vector4(-3.0, 1.2, 33.0, 1.0), "yaw": 124.0, "pitch": -6.0, "distance": 6.0},
		{"name": "shed_fence_w0", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 124.0, "pitch": -6.0, "distance": 6.0,
			"set": {"World/TrymCabin/Shed": {"fence_frame": true}}},
		{"name": "shed_fence_w1", "at": Vector4(-3.0, 1.2, 33.0, 1.0), "yaw": 124.0, "pitch": -6.0, "distance": 6.0},
		{"name": "shed_fence_combined", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 124.0, "pitch": -6.0, "distance": 6.0, "engine": "Combined"},
		{"name": "booth_classic_w0", "at": Vector4(-12.0, 1.2, -4.0, 0), "yaw": 54.0, "pitch": -6.0, "distance": 6.0},
		{"name": "booth_classic_w1", "at": Vector4(-12.0, 1.2, -4.0, 1.0), "yaw": 54.0, "pitch": -6.0, "distance": 6.0},
		{"name": "booth_fence_w0", "at": Vector4(-12.0, 1.2, -4.0, 0), "yaw": 54.0, "pitch": -6.0, "distance": 6.0,
			"set": {"World/Range/RangeBooth": {"fence_posts": true}}},
		{"name": "booth_fence_w1", "at": Vector4(-12.0, 1.2, -4.0, 1.0), "yaw": 54.0, "pitch": -6.0, "distance": 6.0},
		{"name": "booth_fence_combined", "at": Vector4(-12.0, 1.2, -4.0, 0), "yaw": 54.0, "pitch": -6.0, "distance": 6.0, "engine": "Combined"},
	],
	"a": [
		{"name": "top", "top": Vector4(0, 0, -2, 0), "size": 108.0},
		{"name": "top_w4", "top": Vector4(0, 0, -2, 4.0), "size": 108.0},
		{"name": "top_combined", "top": Vector4(0, 0, -2, 0), "size": 108.0, "engine": "Combined"},
		{"name": "wake", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 6.0},
		{"name": "wake_combined", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 6.0, "engine": "Combined"},
		{"name": "arch_w0", "at": Vector4(6.5, 1.2, 33.0, 0), "yaw": 0.0, "pitch": -4.0, "distance": 5.0},
		{"name": "arch_w4", "at": Vector4(6.5, 1.2, 33.0, 4.0), "yaw": 0.0, "pitch": -4.0, "distance": 5.0},
		{"name": "west_path", "at": Vector4(-8.0, 1.2, 28.0, 0), "yaw": 10.0, "pitch": -8.0, "distance": 6.0},
		{"name": "shoulder", "at": Vector4(-11.0, 1.2, 9.0, 0), "yaw": 20.0, "pitch": -8.0, "distance": 6.0},
		{"name": "pen_from_gate", "at": Vector4(4.6, 1.2, -2.0, 0), "yaw": 27.1, "pitch": -15.0, "distance": 8.0},
		{"name": "east_meadow", "at": Vector4(24.0, 1.2, 10.0, 0), "yaw": -40.0, "pitch": -8.0, "distance": 6.0},
	],
}

var _room: Node


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var set_name: String = args[0] if args.size() > 0 else "before"
	var scene: String = args[1] if args.size() > 1 and not args[1].contains("=") else "res://ramon/chickenpen/playable_world.tscn"
	var shots: Array = SETS[set_name] if SETS.has(set_name) else _tiles(set_name)
	# tag=<name>: frames into <set>_<name>/, so one set can be taken before and after a change.
	var tag: String = ""
	for a in args:
		if a.begins_with("tag="):
			tag = "_" + a.substr(4)
	var dir: String = OUT + set_name + tag + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_room = (load(scene) as PackedScene).instantiate()
	# helper=<script>: a Node with that script added to the scene before it starts (a probe the
	# "call" steps drive, e.g. dev_look_probe_4d.gd).
	for a in args:
		if a.begins_with("helper="):
			var helper := Node.new()
			helper.set_script(load(a.substr(7)))
			_room.add_child(helper)
	# pre=<node path>:<property>=<value>: set before the scene starts (a value as GDScript reads it), e.g.
	# pre=World/Trees:echoes=false for the planting without its W layers.
	for a in args:
		if a.begins_with("pre="):
			var spec: String = a.substr(4)
			var target: Node = _room.get_node_or_null(NodePath(spec.get_slice(":", 0)))
			var assign: String = spec.get_slice(":", 1)
			if target != null:
				target.set(assign.get_slice("=", 0), str_to_var(assign.get_slice("=", 1)))
				print("PRE %s" % spec)
	root.add_child(_room)
	current_scene = _room
	# Nobody's typing reaches the frames (input_guard.gd).
	var guard := Node.new()
	guard.name = "InputGuard"
	guard.set_script(load("res://ramon/PenLayout/scripts/input_guard.gd"))
	root.add_child(guard)
	await _frames(60)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player := _room.get_node("Player") as Node4D
	player.set("input_enabled", false)
	var rig: Node4D = player.get_node("CameraRig") as Node4D
	var player_cam: Camera4D = player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	var top_cam := Camera4D.new()
	top_cam.name = "CaptureTop"
	top_cam.projection_type = Camera4D.PROJECTION4D_ORTHOGRAPHIC
	top_cam.clip_far = 400.0
	_room.add_child(top_cam)
	for shot: Dictionary in shots:
		var engine: String = shot.get("engine", "Cross-section")
		_hud(bool(shot.get("hud", false)))
		# The Lookout puts whichever camera is current on Combined or Cross-section every frame
		# (its P toggle); for Projected it is paused for the shot.
		if lookout != null:
			lookout.process_mode = Node.PROCESS_MODE_DISABLED if engine == "Projected" else Node.PROCESS_MODE_INHERIT
			if engine != "Projected" and lookout.has_method("set_projection"):
				lookout.call("set_projection", engine == "Combined")
		var net: Node = _room.get_node_or_null("World/Paths")
		if bool(shot.get("devfloor", false)):
			var ground := _room.get_node_or_null("World/Ground/GroundMesh") as MeshInstance4D
			if ground != null:
				LabGrid.set_swatch("pen_dev_floor", DEV_FLOOR, Color(0.86, 0.87, 0.89), Color(0.92, 0.925, 0.93), 1.0)
				var size: Vector4 = (ground.mesh as BoxTetraMesh4D).size if ground.mesh is BoxTetraMesh4D else Vector4(120, 2, 120, 120)
				ground.material_override = LabGrid.material("pen_dev_floor", size, ground.global_position)
			if net != null:
				net.set("under_color", DEV_FLOOR)
		if net != null:
			var props: Dictionary = shot.get("paths", {})
			for key in props:
				net.set(key, props[key])
			if bool(shot.get("forget", false)) and net.has_method("reset_reveal"):
				net.call("reset_reveal")
		var spawn: Dictionary = shot.get("spawn", {})
		for path in spawn:
			var piece: Node = (load(path) as PackedScene).instantiate()
			_room.get_node("World").add_child(piece)
			(piece as Node4D).global_position = spawn[path]
		for path in shot.get("hide", []):
			var gone: Node = _room.get_node_or_null(NodePath(path))
			if gone != null and gone.get("visible") != null:
				gone.set("visible", false)
		var sets: Dictionary = shot.get("set", {})
		for path in sets:
			var target: Node = _room.get_node_or_null(NodePath(path))
			if target != null:
				for key in sets[path]:
					target.set(key, sets[path][key])
		# "call": node path -> [method, args...], called before the shot (awaited), and the frames after
		# it left to settle (the panel's Rebake greens, say).
		var calls: Dictionary = shot.get("call", {})
		for path in calls:
			var callee: Node = _room.get_node_or_null(NodePath(path))
			if callee == null:
				callee = _room.find_child(String(path), true, false)
			if callee != null:
				var said: Variant = await callee.callv(String(calls[path][0]), (calls[path] as Array).slice(1))
				print("CALL %s.%s -> %s" % [path, calls[path][0], str(said).left(200)])
			else:
				print("CALL: no %s" % path)
		if not calls.is_empty():
			for k in 20:
				await process_frame
		for p: Vector4 in shot.get("walk", []):
			await _walk_to(player, p)
		if shot.has("top"):
			var c: Vector4 = shot["top"]
			top_cam.orthographic_size = float(shot.get("size", 100.0))
			top_cam.position = Vector4(c.x, 120.0, c.z, float(shot.get("w", c.w)))
			top_cam.look_at(Vector4(c.x, 0.0, c.z, float(shot.get("w", c.w))), Vector4(0, 0, -1, 0))
			# A camera's renderer only changes while it is not current.
			player_cam.make_current()
			await _frames(2)
			top_cam.rendering_engine_name = engine
			top_cam.make_current()
		else:
			var at: Vector4 = shot["at"]
			player.global_position = at
			if player is CharacterBody4D:
				(player as CharacterBody4D).linear_velocity = Vector4.ZERO
			var tilt: Vector2 = shot.get("tilt", Vector2.ZERO)
			SliceAngles.tilt(rig, deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(float(shot.get("yaw", 0.0))))
			rig.set("pitch", deg_to_rad(float(shot.get("pitch", -10.0))))
			if shot.has("distance"):
				# The rig eases its distance toward _zoom_target, so both, or the shot keeps the old one.
				rig.set("distance", float(shot["distance"]))
				rig.set("_zoom_target", float(shot["distance"]))
			if rig.has_method("_apply"):
				rig.call("_apply")
			top_cam.make_current()
			await _frames(2)
			player_cam.rendering_engine_name = engine
			player_cam.make_current()
		# Long enough for the player to settle on the ground and the rig to catch up.
		await _frames(38)
		var path: String = dir + String(shot["name"]) + ".png"
		root.get_texture().get_image().save_png(path)
		print("FRAME %s" % path)
	print("CAPTURE DONE %s: %d frames" % [set_name, shots.size()])
	quit(0)


## A map from above too big for one frame, in tiles (Ramon, 6 Oct: "i need higher res capture of both
## topviews"): [member TILES]' rows and columns of top shots, each [code]tile_h[/code] metres tall
## and as wide as the window's aspect makes it, named t_<row>_<col> from the north-west corner. The
## camera is orthographic, so the tiles meet exactly; scratchpad stitch_tiles.py joins them.
const TILES := {
	"topmap_hi": {"centre": Vector2(-2.0, 8.0), "rows": 4, "cols": 3, "tile_h": 24.0, "like": "topmap"},
}


func _tiles(set_name: String) -> Array:
	var spec: Dictionary = TILES[set_name]
	var like: Dictionary = (SETS[spec["like"]] as Array)[0]
	var size: Vector2 = Vector2(root.size)
	var tile_h: float = spec["tile_h"]
	var tile_w: float = tile_h * size.x / size.y
	var rows: int = spec["rows"]
	var cols: int = spec["cols"]
	var centre: Vector2 = spec["centre"]
	var out: Array = []
	for r in rows:
		for c in cols:
			var shot: Dictionary = like.duplicate(true)
			var x: float = centre.x + (float(c) + 0.5 - float(cols) * 0.5) * tile_w
			var z: float = centre.y + (float(r) + 0.5 - float(rows) * 0.5) * tile_h
			shot["name"] = "t_%d_%d" % [r, c]
			shot["top"] = Vector4(x, 0.0, z, 0.0)
			shot["size"] = tile_h
			out.append(shot)
	print("TILES %s: %d x %d, each %.2f x %.2f m, %.1f px a metre" % [set_name, rows, cols, tile_w, tile_h, size.y / tile_h])
	return out


## The player run to [param p] at 3 m/s, a frame at a time (reveal finds by nearness each frame).
func _walk_to(player: Node4D, p: Vector4) -> void:
	var from: Vector4 = player.global_position
	var steps: int = maxi(1, int(from.distance_to(p) / 3.0 * 60.0))
	for i in steps:
		player.global_position = from.lerp(p, float(i + 1) / float(steps))
		await process_frame


func _hud(on: bool) -> void:
	var ui: Node = _room.get_node_or_null("UI")
	if ui == null:
		return
	for c in ui.get_children():
		# The grass and paths panels show themselves again every frame while on the farm: paused too.
		if String(c.name) in ["GrassPanel", "PathsPanel"]:
			c.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		if c is CanvasItem:
			(c as CanvasItem).visible = on
		elif c is CanvasLayer:
			(c as CanvasLayer).visible = on
