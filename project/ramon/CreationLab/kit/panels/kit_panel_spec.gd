@tool
extends RefCounted

## Kit: the wall panels' one template. Every number here comes from Ramon's Figma handoff
## ("Creation Lab / Aligned Layout", 5 Oct 2026: frame 01 the layout, frame 02 its rules), and
## nothing else in the kit types a position, a size or a colour of its own: a prototype gives its
## words (kit_room_info.gd) and its live data, never its layout (rule 6, "keep layout positions
## and typography in the shared template rather than per-room content").
##
## TWO PANELS, ONE SHELL. The introduction (the room's number, title, lead, description and its
## controls) and the research panel (denser, data-focused) are siblings of the same 800 x 492
## unit shell: the same running header and its rule, the same main track, the same lower rule
## and supporting band. The controls row under the introduction and the benchmark under the
## research panel start on the same line, so the two panels read as a pair from across a room.
##
## UNITS. Figma's logical units. In the room one unit is UNIT_M metres on EVERY wall of EVERY
## prototype (Ramon, 5 Oct: "regardless of the wall size, all prototypes should have a fixed size
## for both panels, or things get messy"), so a panel is 9.6 x 5.9 m with its foot FOOT_M off the
## floor. It is never stretched or shrunk to fit a wall; a wall too short for it is flagged by
## its host (kit_wall_panel_4d.gd). 9.6 m is the widest panel the Creation Lab's angled left wall
## (10.6 m) carries with half a metre either side.
##
## TYPE. Montserrat, ten fixed roles: the same role is the same size on either panel and in every
## room (rule 4). Sizes and line heights are Figma's; a line of a role is its line height tall and
## its baseline sits where Figma puts it (half the leading above the font's ascent). Essential
## text is never shrunk to fit: copy that runs over is reported (rule 2).
##
## COLOUR. Figma's six tokens. Printed on a lit wall, the three that are tints of the blue (muted,
## rule, surface) become white veils of the same strength, so the room's light and shadow fall on
## them as on the paint around them; the flat review sheet draws the tokens themselves.
##
## NO class_name (engine_gotchas.md): preload it.

# -- scale ---------------------------------------------------------------------------------------

## Metres a unit, in every prototype.
const UNIT_M := 0.012
## The panel's lower edge above the floor, metres.
const FOOT_M := 1.3
## Pixels a unit the panels are drawn at (250 px a metre in the room).
const PPU := 3.0

# -- geometry (units) --------------------------------------------------------------------------------

## The reference canvas holding both panels side by side (frame 01).
const CANVAS := Vector2(2048, 732)
const MARGIN := 144.0
const GAP := 160.0
## One panel.
const PANEL := Vector2(800, 492)
## The shared spacing unit; internal gaps are 16 / 24 / 32.
const STEP := 8.0

## The shared tracks, panel y (frame 02: "both headers start at y = 144; top rule at y = 163. Main
## content starts at y = 180. Lower rule at y = 504. Supporting rows start at y = 513").
const HEADER_Y := 0.0
const HEADER_RULE_Y := 19.0
const MAIN_Y := 36.0
const LOWER_RULE_Y := 360.0
const SUPPORT_Y := 369.0
const FOOTNOTE_Y := 479.0

## The introduction's body copy is at most this wide, and at most this many lines.
const BODY_MAX_W := 680.0
const BODY_MAX_LINES := 5

## The controls row: up to four shortcuts this wide, this far apart; an icon box, then its label 48
## below its top. The row stands on the bottom line of the pair: its labels' baseline is the
## research panel's footnote baseline (Ramon, 5 Oct: "move the icons of the creation lab panel
## further down so they align at the bottom with the small text on the second panel");
## shortcut_label_y() works it out from the two roles.
const SHORTCUT_W := 180.0
const SHORTCUT_PITCH := 216.0
const ICON_BOX := Vector2(36, 40)
const SHORTCUT_LABEL_DY := 48.0

## The research panel's columns ("196 / 1 / 571, with 16 px gaps around the vertical divider").
const LEFT_W := 196.0
const DIVIDER_X := 212.0
const RIGHT_X := 229.0
const RIGHT_W := 571.0
## The main track's usable height (the divider's length).
const MAIN_H := 312.0

## The specimen family's left column, top to bottom (y from MAIN_Y).
const SPEC_NAME_DY := 12.0
const SPEC_META_DY := 54.0
const SPEC_GLYPH_DY := 64.0
const SPEC_GLYPH := Vector2(196, 108)
const SPEC_GLYPH_FIG := 86.0
const STORY_DY := 172.0
const STORY_RULE_DY := 190.0
const STORY_ROW_DY := 191.0
const STORY_ROW_H := 24.0
## A story row's three columns: number, title, line (right aligned), 8 apart.
const STORY_COLS := [14.0, 76.0, 90.0]
const STORY_LATER_ALPHA := 0.65

## The specimen family's right column (y from MAIN_Y).
const PAGE_HEAD_DY := 16.0
const PAGE_TEXT_DY := 80.0
const PAGE_CHART_DY := 120.0
const CHART := Vector2(344, 184)
const CHART_RADIUS := 9.0
const METRICS_DX := 364.0
const METRICS_W := 207.0
const METRIC_PITCH := 66.0
const METRIC_LABEL_DY := 32.0
const PAGE_CAPTION_DY := 308.0

## The bar chart inside its surface (frame 01's build-step plot).
const PLOT := Rect2(32, 0, 300, 156)
const PLOT_PAD := 12.0
const BAR_W := 28.0
const BAR_GAP := 12.0
const BAR_RADIUS := 2.0
const BAR_LABEL_Y := 160.0
const AXIS_X := 10.0

## The benchmark: its columns and how far apart its rows are.
const TABLE_COLS := [126.0, 64.0, 92.0, 92.0, 82.0, 116.0, 100.0, 128.0]
const TABLE_HEAD_DY := 16.0
const TABLE_ROW_DY := 32.0
const TABLE_ROW_PITCH := 16.0
const TABLE_ROWS := 4

## The two other research layout families (rule 3; only the specimen family was drawn): two
## equal comparison columns, or three sequential steps, both inside the same main track.
const COMPARE_W := 392.0
const STEPS_W := 256.0

# -- type ---------------------------------------------------------------------------------------------

## role: [weight, size, line height], Figma's text styles ("Creation Lab/..."). "tiny" and
## "fine" are the dense research labels Figma keeps at the source's scale (the story hint, the
## benchmark's column heads and footnote).
const ROLES := {
	"hero": ["bold", 64.0, 78.0],
	"lead": ["semibold", 26.0, 36.0],
	"body": ["medium", 18.0, 26.0],
	"specimen": ["bold", 34.0, 42.0],
	"value": ["bold", 24.0, 30.0],
	"section": ["bold", 22.0, 28.0],
	"control": ["semibold", 12.0, 18.0],
	"small": ["medium", 10.0, 14.0],
	"label": ["semibold", 8.0, 12.0],
	"micro": ["medium", 7.0, 10.0],
	"fine": ["medium", 6.0, 10.0],
	"tiny": ["medium", 5.0, 10.0],
}
## Which roles must read from the normal reading position (rule 5); the rest reward walking up.
const ESSENTIAL := ["hero", "lead", "body", "control", "specimen", "value", "section"]

const FONTS := {
	"medium": preload("res://ramon/Demo/fonts/Montserrat/static/Montserrat-Medium.ttf"),
	"semibold": preload("res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf"),
	"bold": preload("res://ramon/Demo/fonts/Montserrat/static/Montserrat-Bold.ttf"),
}


static func font(role: String) -> Font:
	return FONTS[String(ROLES.get(role, ROLES["body"])[0])]


static func size_of(role: String) -> float:
	return float(ROLES.get(role, ROLES["body"])[1])


static func line_of(role: String) -> float:
	return float(ROLES.get(role, ROLES["body"])[2])


## How far below the top of its line a line of `role` has its baseline, units (Figma's half
## leading above the font's ascent).
static func baseline(role: String) -> float:
	var f: Font = font(role)
	var px: int = int(round(size_of(role) * 16.0))
	var asc: float = f.get_ascent(px) / 16.0
	var desc: float = f.get_descent(px) / 16.0
	return (line_of(role) - (asc + desc)) * 0.5 + asc


## The top of the shortcuts' labels: their baseline on the footnote's.
static func shortcut_label_y() -> float:
	return FOOTNOTE_Y + baseline("fine") - baseline("control")


# -- colour -------------------------------------------------------------------------------------------

## Figma's tokens ("--creation-*").
const TOKENS := {
	"blue": Color("#2062dc"),
	"white": Color(1, 1, 1),
	"muted": Color("#b7d3ff"),
	"rule": Color("#5689e4"),
	"surface": Color("#3775dd"),
	"accent": Color("#8edcff"),
}
## On a wall: the tints of the blue as white veils of the same strength (worked out from the
## tokens over #2062dc), so they take the wall's light.
const VEILS := {
	"muted": Color(1, 1, 1, 0.70),
	"rule": Color(1, 1, 1, 0.24),
	"surface": Color(1, 1, 1, 0.11),
	"blue": Color(1, 1, 1, 0.0),
}

## True while drawing the flat review sheet (the tokens themselves); false on a wall.
static var flat: bool = false


static func ink(token: String, alpha: float = 1.0) -> Color:
	var c: Color = TOKENS.get(token, TOKENS["white"])
	if not flat and VEILS.has(token):
		c = VEILS[token]
	return Color(c, c.a * alpha)


# -- the panel's place in the world ---------------------------------------------------------------

## A panel's size in metres.
static func panel_m() -> Vector2:
	return PANEL * UNIT_M


## A role's em size in metres on a wall, for the legibility check.
static func em_m(role: String) -> float:
	return size_of(role) * UNIT_M
