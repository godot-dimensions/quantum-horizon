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

const LabGrid := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_grid.gd")

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
		"kit_card": [Color(0.22, 0.52, 0.96), Color(0.22, 0.52, 0.96), Color(0.22, 0.52, 0.96), 0.0],
		"kit_glass": [Color(0.035, 0.042, 0.055), Color(0.035, 0.042, 0.055), Color(0.035, 0.042, 0.055), 0.0],
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
		"kit_card": [Color(0.14, 0.38, 0.80), Color(0.14, 0.38, 0.80), Color(0.14, 0.38, 0.80), 0.0],
		"kit_glass": [Color(0.03, 0.036, 0.048), Color(0.03, 0.036, 0.048), Color(0.03, 0.036, 0.048), 0.0],
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

## THE LAB'S SCREENS AND OVERLAYS, one set for all of them (Ramon, 4 Oct: "keep consistent"; "a
## solution for the stylistic changes across the whole room and ui"). Two families and one rule
## (Ramon, 5 Oct: "we can have blue and black, black for the screens, and blue for the walls"):
##   BLUE: THE WALLS   painted walls that teach (the Creation Lab wall, the research wall, Room 2's
##                     sign): the code blue ("kit_code_blue"), white type, cards as a white veil, light
##                     blue (UI_ACCENT_SCREEN) for what is live
##   BLACK: SCREENS    every screen and overlay (the loft-builder desk, the specimen picker, the title
##   AND OVERLAYS      card and callouts, the control strip, the slice view, the data panel, the key
##                     prompt): black glass ("kit_glass" on a screen in the room, UI_GLASS on the
##                     screen), a white frame round a screen in the room, white type, light blue
##                     (UI_ACCENT) for what is active or live
##   A NUMBERED BOX IS A BUTTON: it does something when you press it (the arrows, a click), never a
##                     display that lights by itself (Ramon: "the 1,2,3,4 makes you feel like you can
##                     click it"); what only follows along is drawn without numbers or borders
##   gold is the slice and the joints wherever they are drawn; warm orange is the costly
##   alternative; green is "live"
## Montserrat throughout: ExtraBold for titles and figures, Bold for headings and keys, SemiBold
## for reading text (ui_font).
const UI_GLASS := Color(0.04, 0.06, 0.10)
const UI_GLASS_ALPHA := 0.86
const UI_EDGE := Color(1, 1, 1, 0.08)
const UI_INK := Color(1, 1, 1)
const UI_INK_SOFT := Color(0.86, 0.91, 1.0, 0.92)
const UI_INK_DIM := Color(0.72, 0.80, 0.94, 0.72)
const UI_GREY := Color(0.80, 0.82, 0.86)
const UI_ACCENT := Color(0.40, 0.76, 1.0)
const UI_ACCENT_SCREEN := Color(0.55, 0.85, 1.0)
const UI_VEIL := Color(1, 1, 1, 0.07)
const UI_GOLD := Color(1.0, 0.80, 0.35)
const UI_WARM := Color(1.0, 0.55, 0.36)
const UI_LIVE := Color(0.45, 1.0, 0.62)


## THE TYPE LADDER (Ramon, 4 Oct: "we will also need some consistency in font sizes and how it
## compares to one another"): every size of type in the lab is a step on one ladder, each step 1.25
## times the one below, so a title is always the same number of steps above its text wherever it
## is. Overlays on the screen count from TYPE_PX pixels (at a 720-high window), surfaces in the room
## (the walls, the desk, the picker) from TYPE_M metres. The named steps:
##   micro -2   footnotes, column heads, the key on a key cap
##   caption -1 labels, kickers ("PART 2 OF 5"), small print you still read
##   body 0     reading text, callouts, list items
##   lead 1     a line under a title, a toast
##   subhead 2  a title on an overlay card, an icon's label on a wall
##   title 3    a panel's title
##   headline 4 a wall's claim, a big figure, the lesson's paragraph
##   display 5  a specimen's name on a screen
##   hero 6     a wall's subtitle, a specimen's name on a wall
##   poster 11  the lesson's own title
const TYPE_RATIO := 1.25
const TYPE_PX := 11.0
const TYPE_M := 0.12
const TYPE_STEP := {"micro": -2, "caption": -1, "body": 0, "lead": 1, "subhead": 2, "title": 3, "headline": 4, "display": 5, "hero": 6, "poster": 11}


## A step's size in screen pixels for an overlay; `u` is the window's height over 720. Never below
## seven pixels, so the smallest print stays legible in a small window.
static func type_px(role: String, u: float) -> int:
	return maxi(7, int(round(TYPE_PX * pow(TYPE_RATIO, float(TYPE_STEP.get(role, 0))) * u)))


## A step's size in metres for a surface in the room; a number is a step counted from body.
static func type_m(role: Variant) -> float:
	var step: float = float(role) if (role is int or role is float) else float(TYPE_STEP.get(String(role), 0))
	return TYPE_M * pow(TYPE_RATIO, step)


## A dark-glass box for a control or an overlay, `radius` in pixels, faded by `a`.
static func glass_box(radius: float, a: float = 1.0, alpha: float = UI_GLASS_ALPHA) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UI_GLASS, alpha * a)
	sb.border_color = Color(UI_EDGE, UI_EDGE.a * a)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	return sb


## A card on a teaching surface: the white veil, `radius` in pixels.
static func veil_box(radius: float, a: float = 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UI_VEIL, UI_VEIL.a * a)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	return sb


## The type for a role: "title", "figure" (ExtraBold), "heading", "key" (Bold), "text" (SemiBold).
static func ui_font(role: String) -> Font:
	match role:
		"title", "figure":
			return preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd").font("black")
		"heading", "key":
			return preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd").font("bold")
	return preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd").font("body")


## THE PALETTE, on top of the mood (Ramon, 5 Oct: "keep [the B switch] and replace all white textures
## with a dark near black one ... keep the light settings the same, just darken the texture palette
## on the whites"; "keep the light settings of the bright room ... and then only change the textures
## for the dark mode"): the goat room stays in its bright light for both; "grey" is the lab as it is;
## "black" keeps every light exactly as it is and swaps
## the light surfaces (walls, floor, ceiling, frames, the pedestal's lip) for near-black, their grid
## lines a little lighter than the surface so the tiles still read. The blues stay.
static var palette: String = "grey"
const BLACK := {
	"kit_wall": [Color(0.075, 0.078, 0.085), Color(0.17, 0.175, 0.19), Color(0.11, 0.115, 0.125), 0.6],
	"kit_floor": [Color(0.06, 0.062, 0.068), Color(0.15, 0.155, 0.17), Color(0.095, 0.098, 0.106), 0.5],
	"kit_ceiling": [Color(0.045, 0.047, 0.052), Color(0.10, 0.104, 0.112), Color(0.07, 0.072, 0.078), 0.3],
	"kit_desk": [Color(0.09, 0.093, 0.10), Color(0.09, 0.093, 0.10), Color(0.09, 0.093, 0.10), 0.0],
	"kit_bezel": [Color(0.11, 0.114, 0.122), Color(0.11, 0.114, 0.122), Color(0.11, 0.114, 0.122), 0.0],
}
const LIP_BLACK := Color(0.12, 0.124, 0.132)


## The pedestal's lip in the current palette.
static func lip() -> Color:
	return LIP_BLACK if palette == "black" else pick(LIP)


static var mood: String = "bright"
## Live multipliers from the tuning sliders (kit_tuner.gd): spots and downlights, washes.
## Washes start off (Ramon, 4 Oct: "as for the wash, I have no use for it now, but keep the
## slider, make default inactive").
static var gain: Dictionary = {"spot": 1.0, "wash": 0.0}


static func apply(m: String) -> void:
	mood = m
	var sw: Dictionary = SWATCHES.get(m, SWATCHES["bright"])
	for k in sw:
		var v: Array = BLACK[k] if palette == "black" and BLACK.has(k) else sw[k]
		LabGrid.set_swatch(String(k), v[0], v[1], v[2], float(v[3]))


static func pick(d: Dictionary) -> Color:
	return d.get(mood, d["bright"])
