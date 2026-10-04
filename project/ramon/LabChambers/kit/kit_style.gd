@tool
extends RefCounted

## The gallery kit's look in one place: the grid swatches, the glow colours, the plinth's deck,
## the route's blue and the lights, each for both moods. Every kit piece reads from here, so the
## room, the showcase and the lights stay one style (Ramon, 4 Oct: "nail the style together, and
## hence create the kit").
##
## THE LOOK (Ramon, 4 Oct, picking frame 4 of the light bench): mid-grey tiled surfaces under a dim
## blue sky light, so every shadow is blue, and broad soft white spots washing the subjects. DARK is
## exactly that; BRIGHT is the same look lifted a little, not a different one.

## NO class_name (engine_gotchas.md): preload it.

const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")

const SWATCHES := {
	"bright": {
		"kit_wall": [Color(0.70, 0.71, 0.72), Color(0.58, 0.59, 0.61), Color(0.66, 0.67, 0.68), 0.6],
		"kit_floor": [Color(0.64, 0.65, 0.66), Color(0.52, 0.53, 0.55), Color(0.60, 0.61, 0.62), 0.5],
		"kit_ceiling": [Color(0.82, 0.83, 0.84), Color(0.74, 0.75, 0.76), Color(0.79, 0.80, 0.81), 0.3],
		"kit_screen": [Color(0.12, 0.40, 0.88), Color(0.12, 0.40, 0.88), Color(0.12, 0.40, 0.88), 0.0],
		"kit_screen2": [Color(0.18, 0.22, 0.30), Color(0.18, 0.22, 0.30), Color(0.18, 0.22, 0.30), 0.0],
		"kit_desk": [Color(0.80, 0.81, 0.82), Color(0.80, 0.81, 0.82), Color(0.80, 0.81, 0.82), 0.0],
		"kit_bezel": [Color(0.90, 0.91, 0.92), Color(0.90, 0.91, 0.92), Color(0.90, 0.91, 0.92), 0.0],
		"kit_code_blue": [Color(0.13, 0.40, 0.86), Color(0.20, 0.48, 0.93), Color(0.16, 0.44, 0.90), 0.5],
		"kit_metal": [Color(0.24, 0.25, 0.28), Color(0.24, 0.25, 0.28), Color(0.24, 0.25, 0.28), 0.0],
	},
	"dark": {
		"kit_wall": [Color(0.62, 0.63, 0.64), Color(0.50, 0.51, 0.53), Color(0.58, 0.59, 0.60), 0.6],
		"kit_floor": [Color(0.58, 0.59, 0.60), Color(0.46, 0.47, 0.49), Color(0.54, 0.55, 0.56), 0.5],
		"kit_ceiling": [Color(0.78, 0.79, 0.80), Color(0.70, 0.71, 0.72), Color(0.75, 0.76, 0.77), 0.3],
		"kit_screen": [Color(0.08, 0.28, 0.66), Color(0.08, 0.28, 0.66), Color(0.08, 0.28, 0.66), 0.0],
		"kit_screen2": [Color(0.12, 0.15, 0.21), Color(0.12, 0.15, 0.21), Color(0.12, 0.15, 0.21), 0.0],
		"kit_desk": [Color(0.70, 0.71, 0.72), Color(0.70, 0.71, 0.72), Color(0.70, 0.71, 0.72), 0.0],
		"kit_bezel": [Color(0.80, 0.81, 0.82), Color(0.80, 0.81, 0.82), Color(0.80, 0.81, 0.82), 0.0],
		"kit_code_blue": [Color(0.08, 0.27, 0.64), Color(0.14, 0.35, 0.74), Color(0.11, 0.31, 0.69), 0.5],
		"kit_metal": [Color(0.15, 0.155, 0.17), Color(0.15, 0.155, 0.17), Color(0.15, 0.155, 0.17), 0.0],
	},
}

## COLOUR CODES (Ramon, 4 Oct: "since we need to colorcode, make the wall with the text blue
## coded"): a wall carrying text with a `code` is painted in that code's swatch, and its text
## in that code's ink (white on blue) instead of the room's.
const CODES := {"blue": "kit_code_blue"}
const CODE_INK := {
	"blue": {
		"bright": {"name": "bright", "text": Color(1, 1, 1), "dim": Color(0.84, 0.91, 1.0), "accent": Color(0.62, 0.86, 1.0),
			"on_accent": Color(0.06, 0.18, 0.42), "line": Color(0.55, 0.74, 1.0), "panel": Color(1, 1, 1)},
		"dark": {"name": "dark", "text": Color(0.95, 0.97, 1.0), "dim": Color(0.76, 0.85, 0.98), "accent": Color(0.55, 0.82, 1.0),
			"on_accent": Color(0.04, 0.12, 0.30), "line": Color(0.45, 0.64, 0.95), "panel": Color(0.95, 0.97, 1.0)},
	},
}


## The wall swatch for a colour code ("" or "none": `fallback`, the room's own).
static func code_swatch(code: String, fallback: String = "kit_wall") -> String:
	return String(CODES.get(code, fallback))


## The ink to print with on a wall of colour code `code`, for the mood `ink` was made for.
static func code_ink(code: String, ink: Dictionary) -> Dictionary:
	if not CODE_INK.has(code):
		return ink
	return (CODE_INK[code] as Dictionary).get(String(ink.get("name", "bright")), ink)

const COVE := {"bright": Color(0.96, 0.97, 1.0), "dark": Color(1.0, 0.80, 0.56)}
const FIXTURE := {"bright": Color(1.0, 0.98, 0.94), "dark": Color(1.0, 0.92, 0.80)}
const RIM := {"bright": Color(0.96, 0.98, 1.0), "dark": Color(1.0, 0.90, 0.75)}
const DECK := {"bright": Color(0.12, 0.42, 0.92), "dark": Color(0.08, 0.32, 0.78)}
const PLINTH := {"bright": Color(0.22, 0.23, 0.26), "dark": Color(0.12, 0.125, 0.14)}
## The pedestal's white lip, and the warm light lines tucked under it and round its foot.
const LIP := {"bright": Color(0.90, 0.91, 0.92), "dark": Color(0.80, 0.81, 0.82)}
const GLOW_WARM := {"bright": Color(1.0, 0.86, 0.64), "dark": Color(1.0, 0.80, 0.55)}
const ROUTE := {"bright": Color(0.12, 0.45, 1.0), "dark": Color(0.35, 0.72, 1.0)}
## The 4D Basics wall's blue, for the floor's arrows and the pedestal's ring (Ramon, 4 Oct, a test).
const CODE_BLUE := {"bright": Color(0.13, 0.40, 0.86), "dark": Color(0.12, 0.36, 0.80)}
const FRAME_DIM := {"bright": Color(0.62, 0.70, 0.82), "dark": Color(0.26, 0.32, 0.42)}
const FRAME_LIT := {"bright": Color(0.10, 0.42, 0.95), "dark": Color(0.40, 0.78, 1.0)}

## The room light per mood, merged over LabKit's (lab_room_4d.gd `mood_overrides`). Dark is LabKit's
## own dark (the bench's frame 4). Bright is that same blue night lifted: more sky light, a little
## more key, a touch more exposure.
const ROOM_LIGHT := {
	"bright": {
		"sky_top": Color(0.06, 0.08, 0.13), "sky_horizon": Color(0.12, 0.15, 0.22), "sky_bottom": Color(0.05, 0.06, 0.08),
		"ambient": Color(0.20, 0.24, 0.33), "ambient_sky": 0.0,
		"tonemap": 2, "exposure": 1.25, "white": 4.0,
		"key_color": Color(0.72, 0.82, 1.0), "key_energy": 0.42, "key_elevation": 64.0, "key_azimuth": 25.0,
		"fill_color": Color(0.80, 0.87, 1.0), "fill_energy": 0.08, "fill_elevation": 30.0, "fill_azimuth": -150.0,
	},
	"dark": {},
}

static var mood: String = "bright"
## Live multipliers from the tuning sliders (kit_tuner.gd): spots and downlights, washes.
## Washes start off (Ramon, 4 Oct: "as for the wash, I have no use for it now, but keep the
## slider, make default inactive").
static var gain: Dictionary = {"spot": 1.0, "wash": 0.0}


static func apply(m: String) -> void:
	mood = m
	var sw: Dictionary = SWATCHES.get(m, SWATCHES["bright"])
	for k in sw:
		var v: Array = sw[k]
		LabGrid.set_swatch(String(k), v[0], v[1], v[2], float(v[3]))


static func pick(d: Dictionary) -> Color:
	return d.get(mood, d["bright"])
