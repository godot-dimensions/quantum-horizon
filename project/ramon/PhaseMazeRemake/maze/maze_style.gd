@tool
extends RefCounted

## The Phase Maze remake's look in one place (PLAN.md steps 21 to 31): the Creation Lab's light grid in
## the maze's own swatches, the lab's bright sky and sun, and the kit's colour code: yellow where you start,
## green where you finish, cyan for anything about W.
##
## The kit keeps swatch colours in static state, so apply() sets the maze's and remember() / restore() put
## back whatever was there before: nothing here outlives the scene (the range's range_style.gd does the
## same).
##
## NO class_name (engine_gotchas.md): preload it.

const LabGrid := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_grid.gd")

## [surface, line, subline, grid strength] per swatch, sRGB.
const SWATCHES := {
	"kit_wall": [Color(0.91, 0.92, 0.93), Color(0.70, 0.72, 0.75), Color(0.84, 0.85, 0.87), 0.75],
	"kit_floor": [Color(0.83, 0.84, 0.86), Color(0.60, 0.62, 0.66), Color(0.76, 0.77, 0.80), 0.7],
	"kit_code_blue": [Color(0.06, 0.24, 0.66), Color(0.11, 0.31, 0.74), Color(0.08, 0.27, 0.70), 0.5],
	# Maze walls that stand across x or z: the lab's white grid.
	"maze_wall": [Color(0.92, 0.93, 0.94), Color(0.64, 0.66, 0.70), Color(0.82, 0.83, 0.86), 0.8],
	# Maze walls that stand across W: the kit's cyan, so a wall that only a turn shows you says so.
	"maze_wall_w": [Color(0.42, 0.80, 0.90), Color(0.27, 0.62, 0.74), Color(0.36, 0.73, 0.84), 0.6],
	# The maze floor, a little darker than the walls so wall feet read.
	"maze_floor": [Color(0.58, 0.60, 0.63), Color(0.42, 0.44, 0.48), Color(0.52, 0.54, 0.57), 0.85],
	# Wall caps: the kit's dark edge line along every wall top.
	"maze_cap": [Color(0.30, 0.32, 0.36), Color(0.30, 0.32, 0.36), Color(0.30, 0.32, 0.36), 0.0],
	# The console's plate and glass (the kit's bezel and screen).
	"maze_bezel": [Color(0.90, 0.91, 0.92), Color(0.90, 0.91, 0.92), Color(0.90, 0.91, 0.92), 0.0],
	"maze_screen": [Color(0.035, 0.042, 0.055), Color(0.035, 0.042, 0.055), Color(0.035, 0.042, 0.055), 0.0],
}

## The sky and the sun over the carried LabKit's bright mood: the range's pale sky and high key light.
const LIGHT := {
	"sky_top": Color(0.60, 0.71, 0.86), "sky_horizon": Color(0.93, 0.95, 0.97), "sky_bottom": Color(0.88, 0.88, 0.88),
	"ambient": Color(0.54, 0.57, 0.62), "ambient_sky": 0.35,
	"tonemap": 2, "exposure": 0.95, "white": 6.0,
	"key_color": Color(1.0, 0.965, 0.91), "key_energy": 1.35, "key_elevation": 58.0, "key_azimuth": 30.0,
	"fill_color": Color(0.80, 0.87, 1.0), "fill_energy": 0.35, "fill_elevation": 35.0, "fill_azimuth": 200.0,
}

## The kit's colour code (lab_kit.md "the look"), one colour, one meaning.
const ROLE := {
	"start": Color(0.98, 0.80, 0.18),   # yellow: stand here
	"exit": Color(0.25, 0.82, 0.42),    # green: pass
	"w": Color(0.20, 0.86, 1.0),        # cyan: anything about W
	"ghost": Color(0.30, 0.85, 1.0),    # 4D sight's ghosts (the material albedo only the ghost pass uses)
	"trail": Color(0.96, 0.84, 0.40),   # breadcrumbs, newest
	"done": Color(0.62, 0.64, 0.68),    # a dead end you have finished
	"x": Color(0.94, 0.36, 0.33),       # the badge's x axis
	"z": Color(0.40, 0.62, 1.0),        # the badge's z axis
}
const GLOW := {
	"start": Color(1.0, 0.86, 0.30),
	"exit": Color(0.40, 1.0, 0.55),
	"w": Color(0.35, 0.92, 1.0),
}

static var _saved: Dictionary = {}


static func remember() -> void:
	_saved = {}
	for k in SWATCHES:
		_saved[k] = LabGrid.values(String(k))


static func apply() -> void:
	for k in SWATCHES:
		var v: Array = SWATCHES[k]
		LabGrid.set_swatch(String(k), v[0], v[1], v[2], float(v[3]))


static func restore() -> void:
	for k in _saved:
		var v: Array = _saved[k]
		LabGrid.set_swatch(String(k), v[0], v[1], v[2], float(v[3]))
	_saved = {}


static func role(r: String) -> Color:
	return ROLE.get(r, Color.WHITE)


static func glow(r: String) -> Color:
	return GLOW.get(r, ROLE.get(r, Color.WHITE))
