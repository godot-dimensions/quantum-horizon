@tool
extends RefCounted

## The lab kit's visual decisions in one place: type, spacing, the colour code, and the two
## moods. Every kit piece asks this file rather than writing a colour or a size of its own, so
## a change here restyles every lab that uses the kit (the Creation Lab first).
##
## TWO MOODS, BOTH DESIGNED. Bright dev is the default and dark dev the toggle, and both are
## tuned on their own terms (Ramon, 3 Oct: "you have to optimize for both"). So nothing here is
## "the bright colour, darkened": each mood has its own full palette, and the HUD flips from a
## light card with dark type (bright) to dark glass with light type (dark), because dark glass
## at the pen's 0.34 alpha goes muddy over a white floor.
##
## THE COLOUR CODE never changes meaning between moods, only brightness:
##   structure  greys            interact  yellow (stand here, press this)
##   w          cyan (the fourth axis: the lift, rulers, slice markers)
##   build      violet           motion    blue
##   limit      red (a limit, a failed check)   ok  green (a passed check, a done task)
## The hues are taken from Ramon's dev textures (res://textures/dev_finals/ramdev_*.png). On a
## white ground the bright accents are too light to read as lines or type, so the bright mood
## uses deeper versions of the same hues; the dark mood uses them as they are.
##
## TYPE AND SPACING are derived, as MenuStyle does it: one base size and one ratio give every
## step; one spacing unit gives every gap. NO class_name (engine_gotchas.md): preload this file.

const BRIGHT := "bright"
const DARK := "dark"
const MOODS := [BRIGHT, DARK]

# -- type --------------------------------------------------------------------------------------

const FONT_DIR := "res://ramon/Demo/fonts/Montserrat/static/"
const MICRO := -2
const CAPTION := -1
const BODY := 0
const SUBTITLE := 1
const TITLE := 2
const DISPLAY := 3
const BASE_SIZE := 15.0
const RATIO := 1.28
const SPACING_UNIT := 8.0
const CORNER := 6
const LABEL_TRACKING := 2

static var _fonts: Dictionary = {}


## A Montserrat weight: "Regular", "Medium", "SemiBold", "Bold", "Light". Cached.
static func font(weight: String = "SemiBold") -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f: Font = load(FONT_DIR + "Montserrat-%s.ttf" % weight) as Font
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[weight] = f
	return f


## The pixel size of a step on the type scale (BODY = 15, TITLE = 24.6, ...), times `scale`.
static func size(step: int, scale: float = 1.0) -> int:
	return int(round(BASE_SIZE * pow(RATIO, step) * scale))


## A multiple of the spacing unit.
static func space(n: float, scale: float = 1.0) -> float:
	return SPACING_UNIT * n * scale


# -- the colour code ---------------------------------------------------------------------------

const _CODE := {
	BRIGHT: {
		"interact": Color(0.52, 0.62, 0.05),    # ramdev_yellow, deepened to read on white
		"interact_fill": Color(0.875, 0.969, 0.349),
		"w": Color(0.05, 0.56, 0.62),          # ramdev_cyan, deepened
		"w_fill": Color(0.282, 0.886, 0.910),
		"build": Color(0.47, 0.25, 0.86),      # ramdev_violet, deepened
		"build_fill": Color(0.604, 0.345, 0.918),
		"motion": Color(0.20, 0.27, 0.86),     # ramdev_blue, deepened
		"motion_fill": Color(0.271, 0.329, 0.914),
		"limit": Color(0.72, 0.16, 0.22),
		"ok": Color(0.12, 0.55, 0.30),
	},
	DARK: {
		"interact": Color(0.875, 0.969, 0.349),
		"interact_fill": Color(0.875, 0.969, 0.349),
		"w": Color(0.282, 0.886, 0.910),
		"w_fill": Color(0.282, 0.886, 0.910),
		"build": Color(0.70, 0.52, 1.0),
		"build_fill": Color(0.604, 0.345, 0.918),
		"motion": Color(0.45, 0.56, 1.0),
		"motion_fill": Color(0.271, 0.329, 0.914),
		"limit": Color(1.0, 0.42, 0.45),
		"ok": Color(0.45, 0.90, 0.58),
	},
}


## The colour for a role in the code ("interact", "w", "build", "motion", "limit", "ok", and the
## "_fill" variants for surfaces) in a mood.
static func code(role: String, mood: String = BRIGHT) -> Color:
	var table: Dictionary = _CODE.get(mood, _CODE[BRIGHT])
	return table.get(role, Color.MAGENTA)


# -- the HUD and the cards ---------------------------------------------------------------------

const _UI := {
	BRIGHT: {
		"panel": Color(0.985, 0.985, 0.98, 0.90),
		"panel_border": Color(0.0, 0.0, 0.0, 0.10),
		"text": Color(0.09, 0.10, 0.12, 1.0),
		"text_dim": Color(0.09, 0.10, 0.12, 0.62),
		"text_faint": Color(0.09, 0.10, 0.12, 0.40),
		"rule": Color(0.0, 0.0, 0.0, 0.10),
		"chip": Color(0.0, 0.0, 0.0, 0.06),
		"chip_border": Color(0.0, 0.0, 0.0, 0.22),
		"chip_text": Color(0.09, 0.10, 0.12, 0.95),
		"shadow": Color(0.0, 0.0, 0.0, 0.10),
	},
	DARK: {
		"panel": Color(0.035, 0.042, 0.06, 0.78),
		"panel_border": Color(1.0, 1.0, 1.0, 0.09),
		"text": Color(0.93, 0.94, 0.96, 1.0),
		"text_dim": Color(0.93, 0.94, 0.96, 0.62),
		"text_faint": Color(0.93, 0.94, 0.96, 0.40),
		"rule": Color(1.0, 1.0, 1.0, 0.10),
		"chip": Color(1.0, 1.0, 1.0, 0.10),
		"chip_border": Color(1.0, 1.0, 1.0, 0.24),
		"chip_text": Color(0.95, 0.96, 0.98, 0.95),
		"shadow": Color(0.0, 0.0, 0.0, 0.35),
	},
}


## A UI colour ("panel", "panel_border", "text", "text_dim", "text_faint", "rule", "chip",
## "chip_border", "chip_text", "shadow") in a mood.
## The mood the scene's room is in now (the node in the group "lab_mood"), for kit pieces built
## after the room broadcast it: a piece reads this when it is built and listens for changes after.
static func mood_of(tree: SceneTree) -> String:
	if tree == null or Engine.is_editor_hint():
		return BRIGHT
	var room: Node = tree.get_first_node_in_group("lab_mood")
	return String(room.get("mood")) if room != null else BRIGHT


static func ui(role: String, mood: String = BRIGHT) -> Color:
	var table: Dictionary = _UI.get(mood, _UI[BRIGHT])
	return table.get(role, Color.MAGENTA)


## A filled, bordered panel box in the mood, the one style every kit card uses.
static func panel_box(mood: String = BRIGHT, scale: float = 1.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ui("panel", mood)
	box.border_color = ui("panel_border", mood)
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(CORNER * scale))
	box.content_margin_left = space(2.0, scale)
	box.content_margin_right = space(2.0, scale)
	box.content_margin_top = space(1.5, scale)
	box.content_margin_bottom = space(1.5, scale)
	box.shadow_color = ui("shadow", mood)
	box.shadow_size = int(6 * scale)
	box.shadow_offset = Vector2(0, 2) * scale
	return box


# -- surfaces: which of Ramon's dev textures each part of a room wears, per mood ---------------

const _SURFACE := {
	BRIGHT: {
		"floor": "white", "wall": "white", "trim": "grey", "rig": "white", "rig_top": "grey",
		"metal": "black_metal", "lectern": "black_metal", "pad": "white",
	},
	DARK: {
		"floor": "dark_grey", "wall": "black", "trim": "dark_grey", "rig": "dark_grey", "rig_top": "black",
		"metal": "black_metal", "lectern": "black_metal", "pad": "dark_grey",
	},
}


## The dev texture name (ramdev_<name>.png) a part of the room wears in a mood.
## THE PART TINTS (Ramon, 4 Oct: "make color variations of mine"): the colour code reaches the
## surfaces as a cast on his dev textures, so a room says which half of the explanation you are
## in before any text does. Build is violet, Motion blue; the Atrium, the Hall and anything
## neutral stay untinted. Faint on purpose: the cast is felt on the light walls and trim of the
## bright mood and on the floor and trim of the dark one (black walls take no tint); the glow
## strips and the numeral carry the full colour.
const _TINTS := {
	BRIGHT: {
		"build": {"wall": Color(0.95, 0.93, 1.0), "trim": Color(0.86, 0.82, 1.0), "rig": Color(0.97, 0.95, 1.0)},
		"motion": {"wall": Color(0.92, 0.95, 1.0), "trim": Color(0.80, 0.88, 1.0), "rig": Color(0.95, 0.97, 1.0)},
	},
	DARK: {
		"build": {"floor": Color(0.96, 0.90, 1.0), "trim": Color(0.92, 0.80, 1.0), "rig": Color(0.95, 0.88, 1.0)},
		"motion": {"floor": Color(0.88, 0.95, 1.0), "trim": Color(0.78, 0.90, 1.0), "rig": Color(0.88, 0.95, 1.0)},
	},
}


## The cast a surface role takes in a part ("build", "motion"), white for none.
static func tint(part: String, role: String, mood: String = BRIGHT) -> Color:
	var by_part: Dictionary = (_TINTS.get(mood, {}) as Dictionary).get(part, {})
	return by_part.get(role, Color.WHITE)


static func surface(part: String, mood: String = BRIGHT) -> String:
	var table: Dictionary = _SURFACE.get(mood, _SURFACE[BRIGHT])
	return table.get(part, "grey")
