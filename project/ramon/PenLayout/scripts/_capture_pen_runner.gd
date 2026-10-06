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
		{"name": "ref", "at": Vector4(-12.5, 1.2, -1.0, 0), "yaw": 62.0, "pitch": 20.0, "distance": 10.0,
			"spawn": {"res://ramon/chickenpen/units/rune_range/rune_range.tscn": Vector4(-19.0, 0.0, -9.0, 0.0)},
			"hide": ["World/Range"]},
		{"name": "near", "at": Vector4(-15.0, 1.2, -6.5, 0), "yaw": 80.0, "pitch": 8.0, "distance": 5.0},
		{"name": "boards", "at": Vector4(-24.0, 1.2, -9.0, 0), "yaw": 90.0, "pitch": 4.0, "distance": 5.0},
		{"name": "table", "at": Vector4(-15.6, 1.2, -5.0, 0), "yaw": 100.0, "pitch": -12.0, "distance": 3.5},
		{"name": "stone", "at": Vector4(-17.3, 1.2, -7.4, 0), "yaw": 70.0, "pitch": -20.0, "distance": 3.0},
		{"name": "w1", "at": Vector4(-12.5, 1.2, -1.0, 1.0), "yaw": 62.0, "pitch": 20.0, "distance": 10.0},
		{"name": "combined", "at": Vector4(-12.5, 1.2, -1.0, 0), "yaw": 62.0, "pitch": 20.0, "distance": 10.0, "engine": "Combined"},
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
		{"name": "east_w4", "at": Vector4(28.0, 1.2, 15.0, 4.0), "yaw": 90.0, "pitch": -2.0, "distance": 5.0},
		{"name": "west_w4", "at": Vector4(-12.0, 1.2, 15.0, 4.0), "yaw": -90.0, "pitch": -2.0, "distance": 5.0},
		{"name": "back_w4", "at": Vector4(8.0, 1.2, -4.0, 4.0), "yaw": 180.0, "pitch": -2.0, "distance": 5.0},
		{"name": "east_w0", "at": Vector4(28.0, 1.2, 15.0, 0.0), "yaw": 90.0, "pitch": -2.0, "distance": 5.0},
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
	var scene: String = args[1] if args.size() > 1 else "res://ramon/chickenpen/playable_world.tscn"
	var shots: Array = SETS[set_name]
	var dir: String = OUT + set_name + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_room = (load(scene) as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
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
		if c is CanvasItem:
			(c as CanvasItem).visible = on
		elif c is CanvasLayer:
			(c as CanvasLayer).visible = on
