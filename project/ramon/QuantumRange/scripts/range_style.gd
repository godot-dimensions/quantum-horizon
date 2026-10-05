@tool
extends RefCounted

## The Quantum Range's look in one place: the light holodeck palette for the room's grid surfaces, the
## sky and the sun, and the colour of every role a target can play.
##
## THE LOOK (Ramon, 5 Oct: "a light R&D style this time. simple lighting, readable shapes. different
## colors for the important objects ... scene is generally white, and/or grey ... explainer sign white
## text on blue. slight scifi aestetic. likea holodeck of sorts"): white and light grey prototype grid
## under a pale open sky (no roof), a warm key sun, a cool fill and ambient light; the blue walls and the
## cyan light lines are the only saturated surfaces, so the targets' colours carry the meaning.
##
## The room is built with the carried kit (carried/kit/kit_room_4d.gd), which paints its surfaces in the
## swatches "kit_wall", "kit_floor" and "kit_code_blue". The kit keeps a swatch's colours in static
## state, so apply() sets the range's and remember() / restore() put back whatever the kit had: nothing
## here outlives the range.
##
## NO class_name (engine_gotchas.md): preload it.

const LabGrid := preload("res://ramon/QuantumRange/carried/LabKit/lab_grid.gd")

## [surface, line, subline, grid strength] per swatch, sRGB.
const SWATCHES := {
	"kit_wall": [Color(0.91, 0.92, 0.93), Color(0.70, 0.72, 0.75), Color(0.84, 0.85, 0.87), 0.75],
	"kit_floor": [Color(0.83, 0.84, 0.86), Color(0.60, 0.62, 0.66), Color(0.76, 0.77, 0.80), 0.7],
	"kit_code_blue": [Color(0.06, 0.24, 0.66), Color(0.11, 0.31, 0.74), Color(0.08, 0.27, 0.70), 0.5],
	"range_counter": [Color(0.95, 0.95, 0.96), Color(0.80, 0.81, 0.83), Color(0.90, 0.91, 0.92), 0.35],
	"range_dark": [Color(0.20, 0.21, 0.24), Color(0.30, 0.31, 0.35), Color(0.24, 0.25, 0.28), 0.4],
	"range_top": [Color(0.66, 0.68, 0.72), Color(0.56, 0.58, 0.62), Color(0.62, 0.64, 0.68), 0.4],
	"range_lane": [Color(0.78, 0.80, 0.83), Color(0.58, 0.61, 0.66), Color(0.72, 0.74, 0.78), 0.6],
}

## The sky and the sun, merged over the carried LabKit's bright mood (carried/LabKit/lab_room_4d.gd):
## a pale sky and the key straight behind you, high (azimuth is from +Z towards +X; you face -Z), so
## what faces you is lit from above. Straight behind, not off to one side: the two wings turn 56 degrees
## either way to face you, and a key from behind-left left the explainer in shadow and lit the metrics
## wall twice as bright (frame room/06_bay, 5 Oct). A weak cool back light from downrange rims the far
## sides; the ambient light carries the shaded faces.
const LIGHT := {
	"sky_top": Color(0.60, 0.71, 0.86), "sky_horizon": Color(0.93, 0.95, 0.97), "sky_bottom": Color(0.88, 0.88, 0.88),
	"ambient": Color(0.66, 0.69, 0.74), "ambient_sky": 0.35,
	"tonemap": 2, "exposure": 1.0, "white": 6.0,
	"key_color": Color(1.0, 0.965, 0.91), "key_energy": 1.6, "key_elevation": 50.0, "key_azimuth": 0.0,
	"fill_color": Color(0.80, 0.87, 1.0), "fill_energy": 0.3, "fill_elevation": 35.0, "fill_azimuth": 180.0,
}

## THE ROLES (follow_up/quantum_range_final.md section 4). One colour, one meaning, everywhere: on the
## target, on the radar, in the explainer wall's key.
const ROLE := {
	"core": Color(0.90, 0.13, 0.12),      # red: the thing to hit, one quick shot
	"armour": Color(1.0, 0.62, 0.10),     # amber: only a charged shot breaks it
	"cover": Color(0.96, 0.96, 0.97),     # white: breakable cover
	"shell": Color(0.30, 0.32, 0.36),     # grey metal: never breaks, go round it through W
	"friend": Color(0.18, 0.74, 0.36),    # green: friendly, do not shoot
	"w": Color(0.20, 0.86, 1.0),          # cyan: anything about W
	"info": Color(0.13, 0.40, 0.86),      # blue: information
}
## The glow each role's light parts take (unshaded, carried/LabKit/lab_materials.gd glow()).
const GLOW := {
	"core": Color(1.0, 0.30, 0.24),
	"armour": Color(1.0, 0.78, 0.35),
	"w": Color(0.35, 0.92, 1.0),
	"friend": Color(0.45, 1.0, 0.60),
}

static var _saved: Dictionary = {}


## Notes what the kit's swatches hold now, so restore() can put it back when the range closes.
static func remember() -> void:
	_saved = {}
	for k in SWATCHES:
		_saved[k] = LabGrid.values(String(k))


## Paints every range swatch.
static func apply() -> void:
	for k in SWATCHES:
		var v: Array = SWATCHES[k]
		LabGrid.set_swatch(String(k), v[0], v[1], v[2], float(v[3]))


## Puts back what remember() saw.
static func restore() -> void:
	for k in _saved:
		var v: Array = _saved[k]
		LabGrid.set_swatch(String(k), v[0], v[1], v[2], float(v[3]))
	_saved = {}


static func role(r: String) -> Color:
	return ROLE.get(r, Color.WHITE)


static func glow(r: String) -> Color:
	return GLOW.get(r, ROLE.get(r, Color.WHITE))
