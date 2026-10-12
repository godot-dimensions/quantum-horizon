@tool
extends Control
## THE MENU'S VARIATIONS, FROZEN 9 OCT 2026. Scene: `res://ramon/menu_variations.tscn`.
##
## A reference copy for Ramon, taken when design A became the menu ("keep the variation menu as
## temp file i can access ... keep the menu final as the new main master and remove the tab
## variations"). It is menu_final.gd exactly as it was that morning, with all 41 designs behind
## Tab (0 to 39 and A), the palettes (B) and the groupings (G). Its builders are its own copies
## (menu_variations_b.gd, menu_variations_c.gd). It still reads the shared catalogue_final.tres,
## style and MenuEntry, so a change there shows here too. Do not develop the menu here: the
## master is menu_final.gd / menu_a.gd.
##
## What follows is menu_final.gd's own header as it stood.
##
## Scrolling banner menu, final. Scene: `res://ramon/menu_final.tscn`.
##
## A COPY OF MENU2, taken 30 Sept 2026 when Ramon called Menu2 final ("menu 2 is
## final ... copied and renamed to menu_final"). `Menu2.tscn` and `menu2.gd` are
## left exactly as they were; changes from here on go in this file. It has its own
## `style/menu_final_style.tres`, so retuning the look here cannot alter Menu2.
##
## OWN CATALOGUE SINCE 8 OCT. Until then this read the shared `entries/catalogue.tres`.
## Ramon's 8 Oct lineup renames entries (Slice Vision is now Crosswise, Voxel Mining the
## Voxel Lab, ...), and the Frontier Map places its nodes by entry TITLE, so renaming
## them in the shared file would have broken the map. This menu now reads
## `entries/catalogue_final.tres`; Menu, Menu2 and the Frontier Map keep the old one.
## An entry taken off the menu is unticked (`MenuEntry.show_in_menu`), never deleted.
##
## The Frontier Map is no longer linked from here (Ramon, 8 Oct: "i want the frontier
## map to be opened as a tscn whenever i want ... just not in the menu"). It still opens
## on its own: `res://ramon/FrontierMap.tscn`.
##
## WHAT MENU2 ADDED OVER THE FIRST MENU
##
##   - Auto-advance: coming back from a prototype moves the selection to the
##     next unplayed one. The guided tour at a fraction of its cost.
##   - Duration per entry, and the maturity badge repeated in the row, so the
##     list can be scanned without clicking anything.
##   - A measurements strip under the three info cells, for R&D readers.
##   - The detail pane no longer repeats the row's blurb verbatim.
##   - Esc returns HERE from a prototype instead of the old main menu.
##   - A live crop handle for the video, on this node rather than buried inside
##     the catalogue array.
##   - Spacing and info-text size are draggable in the style resource.
##
## @tool, so the whole screen draws in the EDITOR viewport and every change to
## the style or catalogue resource redraws it immediately - open
## `ramon/menu_final.tscn`, select the root node, and edit. Without this the
## inspector showed the properties and a blank viewport, which is a poor way to
## judge a layout.
##
## Generated nodes are never given an `owner`, so none of them are serialised
## into the .tscn. That is what keeps the scene file a single node and sidesteps
## the `[editable path]` resave trap in CLAUDE.md, the same discipline
## `hub_gate_ring_4d.gd` and `ascent_builder_4d.gd` follow.
##
## The scene lives at `res://ramon/menu_final.tscn` - beside Menu2.tscn at the
## ramon root, with its scripts, style, catalogue, shader and clips in
## `ramon/Menu/`. It is the project's `run/main_scene` again since 8 Oct (the pen was,
## 7 to 8 Oct).
##
## NOTHING VISUAL IS HARDCODED IN THIS FILE ANY MORE.
##
##   - every size, colour, gap and radius comes from `style/menu_final_style.tres`
##     ([MenuStyle]) - and type is a MODULAR SCALE, so one base size moves the
##     whole hierarchy together instead of eight numbers drifting apart
##   - every string and every prototype comes from `entries/catalogue_final.tres`
##     ([MenuCatalogue] / [MenuEntry]) - editable in the inspector, reorderable
##     by dragging, and array order IS the tour order
##
## The screen is generated from those two resources, the same "it is a list, not
## a layout" pattern the Demo hub and the Ascent course already use. Adding a
## prototype is an array entry; restyling the whole menu is one resource.
##
## Three ideas the layout exists to argue for:
##
## 1. **A vertical banner list implies an ORDER; a grid implies "pick any".**
## 2. **The hero banner resolves the select-vs-sequence question** by being both:
##    it runs the sequence, the list beneath it is the jump-to-one escape hatch.
## 3. **Previews must MOVE.** A still frame of a 4D cross-section is
##    indistinguishable from an ordinary 3D screenshot; the whole subject is what
##    happens when the slice turns. See `_capture_clip.gd`.

# --------------------------------------------------------------------------
# Window
# --------------------------------------------------------------------------

## Set to BORDERLESS_FULLSCREEN because this is a presentation screen: no window
## chrome to mis-click, no desktop behind it, clean when screen-shared. Not
## EXCLUSIVE_FULLSCREEN - that does a display mode switch, which makes alt-tab
## and screen sharing worse for no benefit.
##
## Switch to WINDOWED while iterating if F6 going fullscreen gets annoying.
enum WindowMode { WINDOWED, BORDERLESS_FULLSCREEN, EXCLUSIVE_FULLSCREEN }
const WINDOW_MODE: WindowMode = WindowMode.BORDERLESS_FULLSCREEN
const WINDOWED_SIZE: Vector2i = Vector2i(1600, 900)

## Everything is authored against this and scaled to whatever the window is.
## CANVAS_ITEMS scales the drawing rather than the viewport, so text stays sharp;
## EXPAND treats 1080p as a minimum and hands a wider display the extra space
## rather than letterboxing. Swap EXPAND for KEEP to guarantee a pixel-identical
## layout everywhere at the cost of black bars.
const DESIGN_RESOLUTION: Vector2i = Vector2i(1920, 1080)

# --------------------------------------------------------------------------
# Content and style
# --------------------------------------------------------------------------

const DEFAULT_STYLE: String = "res://ramon/Menu/style/menu_final_style.tres"
const DEFAULT_CATALOGUE: String = "res://ramon/Menu/entries/catalogue_final.tres"

## The header's height in design pixels (the slim title line that replaced the 104 px banner).
const HEADER_HEIGHT: float = 56.0

## The system groups the list is sorted into (Ramon, 8 Oct: group the menu by system, the
## way the Frontier Map does), in the order they are listed. The names match
## MenuEntry.category; the labels and colours on screen come from the map's own layout.
const SYSTEMS: PackedStringArray = ["Orientation", "Spatial interaction", "World systems", "Living systems"]

## The second way to group (G in the design HUD): the programme's own three questions, the
## RFP's thrusts (Notion, D3, 3 Oct): "Thrust A, Build it: engine and rendering. Can a 4D world
## be rendered and simulated in real time, at the density games need?" / "Thrust B, Fill it:
## content at 4D scale. Can small teams create enough 4D content to make a world feel
## inhabited?" / "Thrust C, Live it: interface, control and perception. Can ordinary players
## understand, navigate and control a rich 4D world?" Listed in the order a first-time visitor
## meets them: learn to read and move (Live it), then how the content is made (Fill it), then
## the engine under load (Build it). The names match MenuEntry.thrust.
const THRUSTS: PackedStringArray = ["Live it", "Fill it", "Build it"]
const THRUST_LABELS: PackedStringArray = ["LIVE IT", "FILL IT", "BUILD IT"]
const THRUST_LINES: PackedStringArray = [
	"can ordinary players understand and control 4D?",
	"can small teams make enough 4D content?",
	"can 4D run in real time, at game density?",
]
const THRUST_COLORS: Array[Color] = [Color(0.294, 0.663, 1.0), Color(0.333, 0.784, 0.741), Color(1.0, 0.69, 0.33)]
## Which of the map's four marks each thrust borrows: the reticle (perception), the cells
## (content), the cube (the engine).
const THRUST_MARKS: Array[int] = [0, 2, 1]
const GROUP_OTHER: int = 4
const GROUP_FILMS: int = 5
## The original design's lab (entries whose `section` is Lab), listed last.
const GROUP_LAB: int = 6
const FRONTIER_LAYOUT: String = "res://ramon/Menu/entries/frontier_layout.tres"

# --------------------------------------------------------------------------
# Design review (temporary)
# --------------------------------------------------------------------------

## DESIGN REVIEW, 8 Oct. Ramon: the system groups did not read ("the categories don't cut in
## between the cards, it's not clear what belongs to what ... it just becomes noise"), so
## the list can be drawn eight ways, switched live by the number keys or the strip in the
## banner, and B switches the palette between the current grey and the bright lab one. The
## content, the detail pane and every launch are the same in all eight; only how the groups
## are drawn changes. When he has picked one, the others and this switch come out.
##
## Each design leans on one grouping principle (Gestalt: proximity, common region,
## connectedness, similarity), named in its line in the strip.
## Indexed by the design's own number, 0 to 19. 0 is the menu as it was on the morning of 8 Oct
## (Ramon: "i still want the original look you changed also in there"); 1 to 9 the first round;
## 10 to 19 the second round (Ramon, 8 Oct: all white or all near black, never mixed; the left
## list and right panel kept for some, number 7's board tackled again for others, and "a better
## relation to how the different protos fit"). The second round is in menu_designs_b.gd.
const DESIGN_NAMES: PackedStringArray = [
	"ORIGINAL", "CURRENT", "SEGMENTED", "GROUPED PANELS", "ROUTE", "NUMBERED INDEX", "SYSTEM TABS",
	"SYSTEM BOARD", "LAB WALL", "LAB HUD",
	"RESEARCH LIST", "BLUE PLAQUES", "CHAPTERS", "THREE PANES", "WORLD FIRST", "QUESTION BOARD",
	"STACK", "HUB", "EVIDENCE MATRIX", "JOURNEY",
	"DECK SLIDE", "ROUTE SLIDE", "DIVIDER NUMERALS", "MEASURED ROWS", "COVER", "TWO VIEWS", "INDEX",
	"TESSERACT", "QUIET", "FULL DECK",
	"KIT TYPE", "KIT CAPS", "ACCENT BARS", "GRID ROOM", "KICKERS", "HAIRLINES", "RESEARCH HEADER",
	"BLUE WALL HERO", "PILLS", "THE FULL WASH",
	"A",
]
const DESIGN_IDEAS: PackedStringArray = [
	"The menu as it was this morning: the tour, the cinematics and the lab, under EXPLORE FREELY",
	"Today's list: headings between identical cards",
	"Proximity: a system's cards touch as one segmented stack, wide gaps between systems",
	"Common region: each system is one panel, its prototypes inside it",
	"Connectedness: the Frontier Map's route runs down each system, a node per prototype",
	"A two-column index: the system on the left, its prototypes numbered on the right",
	"One system at a time: tabs, and only that system's prototypes",
	"Like the Frontier Map: one column per system, the details below",
	"The lab's blue teaching wall for the list, the details as a screen",
	"The Creation Lab's screens: black glass, round pills, outline key caps, cards with an accent bar",
	"The research wall's story list: numbered, hairlines, where each lives in the world on the right",
	"Each group on a blue teaching plaque, its prototypes as cards beneath",
	"The run as chapters, and the world as the last chapter",
	"Group, then prototype, then details: three panes, left to right",
	"The world on top, built from the prototypes: each one a piece you can open",
	"Number 7 again: a column per group, all of them feeding into the world beneath",
	"Engine at the base, content on it, players on top, the world as the roof",
	"The world at the centre, each prototype a spoke, labelled with where it lives",
	"Which questions each prototype answers, and where it lives in the world",
	"A route from left to right through the groups, ending in the world",
	"The deck's content slide: running header, a two-line claim, an editorial list, the footer",
	"The deck's route slide: group heads, a curve through every prototype, ending in the world",
	"The deck's dividers in the list: each group under a huge outlined numeral",
	"The deck's measured rows (P1, P2, P3): the name large, its line small, its icon drawn",
	"The deck's cover as the left half: the claim, Build it, Fill it, Live it, then the cards",
	"The deck's menu slide: the list and the details as two framed screens with captions",
	"An index: a column per group under its outlined numeral, the details below",
	"The cover's 4D cube, turning live, over the claim and a plain list",
	"The original layout in the deck's type: Regular names, hairlines, nothing boxed",
	"The route slide with the turning cube and outlined numerals over each group",
	"The original, in the lab's ExtraBold titles and the white and black palettes",
	"The original with the lab's outline key caps, a pill launch button and pill badges",
	"The original's cards carrying the lab title card's accent bar",
	"The original on the lab's grid ground",
	"The original with the lab's kicker over the title (PART 04 OF 07) and numbered rows",
	"The original's cards loosened into flat rows split by hairlines",
	"The original under the research wall's slim header instead of the big banner",
	"The original's world card set like a Figma wall panel: kicker, big ExtraBold title",
	"The original's headings as small pills, and the lab's control strip for the hint",
	"All of the fourth row's washes together, on the original's layout",
	"Ramon's pick (23, measured rows), worked: each prototype's logo in place of P1, one blue, the launch button's corners on the world and the video, a flat details panel",
]
## Designs ordered from the least change to the most.
const DESIGN_ORIGINAL: int = 0
const DESIGN_CURRENT: int = 1
const DESIGN_SEGMENTED: int = 2
const DESIGN_PANELS: int = 3
const DESIGN_ROUTE: int = 4
const DESIGN_INDEX: int = 5
const DESIGN_TABS: int = 6
const DESIGN_BOARD: int = 7
const DESIGN_WALL: int = 8
const DESIGN_HUD: int = 9
## The second round starts here: 10 to 19, mouse only in the HUD, white or near black.
const FIRST_B: int = 10
## Round 3 (20 to 29): from the Octobergate deck's top row in Figma, in white and blue (B: near
## black and light blue), in menu_designs_c.gd. Round 4 (30 to 39): the
## original's layout washed with the kit and Figma styles (Ramon, 8 Oct: "subtle variations that
## respect the original menu ... 10 variants based on the most original design. including black
## toggle"). Each flag below is one wash; 39 has them all but the hairlines (it keeps the bars).
const FIRST_C: int = 20
const FIRST_WASH: int = 30
## The final row: Ramon's picks, worked further. "A" is number 23 with his 8 Oct changes.
const FIRST_FINAL: int = 40
const DESIGN_A: int = 40
const WASH_FLAGS: Array = [
	["heavy"], ["heavy", "caps"], ["heavy", "bars"], ["heavy", "grid"], ["heavy", "kicker"],
	["heavy", "hairlines"], ["heavy", "slimhead"], ["heavy", "bluehero"], ["heavy", "pills"],
	["heavy", "caps", "bars", "grid", "kicker", "slimhead", "bluehero", "pills"],
]
const DesignsB := preload("res://ramon/Menu/scripts/menu_variations_b.gd")
const DesignsC := preload("res://ramon/Menu/scripts/menu_variations_c.gd")

## The palette keys B switches. The grey ones are the style resource's own, read once.
const PALETTE_KEYS: PackedStringArray = [
	"background", "surface", "surface_raised", "accent", "text", "text_dim", "text_faint",
	"positive", "benchmark_accent", "launch_fill", "launch_fill_hover", "thumbnail_tint",
]
## The LAB palette (B): how the Creation Lab and the Shooting Range put their screens over
## their rooms. Both use one screen style (QuantumRange/carried/kit/kit_style.gd is a copy of
## CreationLab/kit/kit_style.gd): black glass, UI_GLASS (0.04, 0.06, 0.10) at 0.86 with a
## white 8% edge, white type, UI_ACCENT light blue for what is lit, the code blue for walls
## that teach and for buttons. The ground is the range's light holodeck wall, gridded.
const LAB_PALETTE: Dictionary = {
	"background": Color(0.91, 0.92, 0.93),
	"surface": Color(0.04, 0.06, 0.10, 0.90),
	"surface_raised": Color(0.11, 0.16, 0.24, 0.96),
	"accent": Color(0.13, 0.40, 0.86),
	"text": Color(1.0, 1.0, 1.0),
	"text_dim": Color(0.80, 0.85, 0.94),
	"text_faint": Color(0.60, 0.67, 0.78),
	"positive": Color(0.45, 1.0, 0.62),
	"benchmark_accent": Color(0.40, 0.76, 1.0),
	"launch_fill": Color(0.13, 0.40, 0.86),
	"launch_fill_hover": Color(0.20, 0.48, 0.95),
	"thumbnail_tint": Color(0.80, 0.82, 0.86),
}
## The second round's two palettes (B), never mixed: all white, as the Creation Lab's grey
## mood with the old LabKit's light cards; all near black, as its black mood (kit_style.gd
## BLACK: walls 0.075, floor 0.06, grid lines 0.15 to 0.17). Code blue in both, as in both rooms.
const WHITE_PALETTE: Dictionary = {
	"background": Color(0.925, 0.932, 0.942),
	"surface": Color(1.0, 1.0, 1.0),
	"surface_raised": Color(0.905, 0.930, 0.970),
	"accent": Color(0.13, 0.40, 0.86),
	"text": Color(0.06, 0.09, 0.15),
	"text_dim": Color(0.33, 0.38, 0.46),
	"text_faint": Color(0.55, 0.59, 0.66),
	"positive": Color(0.11, 0.56, 0.31),
	"benchmark_accent": Color(0.13, 0.40, 0.86),
	"launch_fill": Color(0.13, 0.40, 0.86),
	"launch_fill_hover": Color(0.20, 0.48, 0.95),
	"thumbnail_tint": Color(0.40, 0.45, 0.53),
}
const BLACK_PALETTE: Dictionary = {
	"background": Color(0.043, 0.046, 0.052),
	"surface": Color(0.078, 0.082, 0.090),
	"surface_raised": Color(0.130, 0.137, 0.150),
	"accent": Color(0.13, 0.40, 0.86),
	"text": Color(0.95, 0.96, 0.98),
	"text_dim": Color(0.68, 0.71, 0.77),
	"text_faint": Color(0.46, 0.49, 0.55),
	"positive": Color(0.45, 1.0, 0.62),
	"benchmark_accent": Color(0.40, 0.76, 1.0),
	"launch_fill": Color(0.13, 0.40, 0.86),
	"launch_fill_hover": Color(0.20, 0.48, 0.95),
	"thumbnail_tint": Color(0.62, 0.65, 0.70),
}
## The third round's palettes: the deck's own system (Octobergate, top row) recoloured white and
## blue as Ramon asked, and its dark divider slides as near black and light blue (B).
const DECK_WHITE: Dictionary = {
	"background": Color(0.980, 0.984, 0.992),
	"surface": Color(1.0, 1.0, 1.0),
	"surface_raised": Color(0.925, 0.945, 0.975),
	"accent": Color(0.125, 0.384, 0.863),
	"text": Color(0.067, 0.098, 0.165),
	"text_dim": Color(0.37, 0.41, 0.47),
	"text_faint": Color(0.54, 0.58, 0.64),
	"positive": Color(0.12, 0.56, 0.32),
	"benchmark_accent": Color(0.125, 0.384, 0.863),
	"launch_fill": Color(0.125, 0.384, 0.863),
	"launch_fill_hover": Color(0.20, 0.46, 0.93),
	"thumbnail_tint": Color(0.24, 0.33, 0.48),
}
const DECK_DARK: Dictionary = {
	"background": Color(0.063, 0.075, 0.094),
	"surface": Color(0.086, 0.102, 0.125),
	"surface_raised": Color(0.13, 0.16, 0.20),
	"accent": Color(0.55, 0.77, 1.0),
	"text": Color(0.94, 0.95, 0.97),
	"text_dim": Color(0.66, 0.71, 0.78),
	"text_faint": Color(0.45, 0.50, 0.57),
	"positive": Color(0.45, 1.0, 0.62),
	"benchmark_accent": Color(0.55, 0.77, 1.0),
	"launch_fill": Color(0.125, 0.384, 0.863),
	"launch_fill_hover": Color(0.20, 0.46, 0.93),
	"thumbnail_tint": Color(0.72, 0.80, 0.92),
}
## The deck's category colours become a blue ramp, one blue per group.
const DECK_BLUES_WHITE: Array[Color] = [Color(0.09, 0.28, 0.71), Color(0.125, 0.384, 0.863), Color(0.20, 0.53, 0.90), Color(0.33, 0.62, 0.92)]
const DECK_BLUES_DARK: Array[Color] = [Color(0.40, 0.64, 1.0), Color(0.55, 0.77, 1.0), Color(0.70, 0.85, 1.0), Color(0.82, 0.91, 1.0)]
const DECK_FONT: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Regular.ttf"

## The range's wall grid (range_style.gd: wall line) on the LAB ground.
const LAB_GRID: Color = Color(0.70, 0.72, 0.75)
## The lab's glass edge, and a card inside glass (kit_data_panel.gd's inner cards).
const GLASS_EDGE: Color = Color(1.0, 1.0, 1.0, 0.08)
const GLASS_CARD: Color = Color(1.0, 1.0, 1.0, 0.045)
const GLASS_LIT: Color = Color(1.0, 1.0, 1.0, 0.10)
## The lab's teaching-wall blue (kit/panels/kit_panel_spec.gd, #2062dc) and the type on it,
## for the lab wall design. Selection on the wall is a white veil (kit_style.gd UI_VEIL).
const WALL_BLUE: Color = Color(0.125, 0.384, 0.863)
const WALL_INK: Color = Color(1.0, 1.0, 1.0)

## Row kinds, one per way a design draws a prototype.
enum RowKind { CARD, FLAT, ROUTE, INDEX, TILE, GLASS }

## The lab HUD design's tokens (CreationLab/kit/kit_style.gd, copied by the range): UI_GLASS at
## 0.86 with a white 8% edge, UI_ACCENT for what is lit, the title card's 4 px accent bar, the
## outline key caps, and Montserrat ExtraBold for titles (LabKit/lab_print.gd).
const HUD_GLASS: Color = Color(0.04, 0.06, 0.10, 0.86)
const HUD_EDGE: Color = Color(1.0, 1.0, 1.0, 0.08)
const HUD_ACCENT: Color = Color(0.40, 0.76, 1.0)
const HUD_INK_SOFT: Color = Color(0.86, 0.91, 1.0, 0.92)
const HUD_INK_DIM: Color = Color(0.72, 0.80, 0.94, 0.72)
const HUD_RADIUS: int = 10
const HEAVY_FONT: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-ExtraBold.ttf"
## Type on the banner's accent blue, in either palette.
const ON_ACCENT: Color = Color(0.97, 0.98, 1.0)

## Allows the design HUD: Tab shows and hides it over the menu (for Ramon while he designs,
## never seen otherwise). While it shows, the number keys pick the design and B the palette;
## hidden, the keys do what they always did.
@export var design_review: bool = true:
	set(value):
		design_review = value
		_request_rebuild()

## Which design draws the list, 0 to 40 (see DESIGN_NAMES; 40 is "A"). Also switched at run time.
## "A" is the menu since 9 Oct (Ramon: "install final A as the main menu lander"); the others stay
## reachable from the Tab panel, which opens closed.
@export_range(0, 40, 1) var design: int = 40:
	set(value):
		if not _design_available(value):
			return
		design = clampi(value, 0, DESIGN_NAMES.size() - 1)
		_request_rebuild()

## The LAB palette instead of the grey one (B, designs 0 to 9). Run time only: in the editor the
## palette is the style resource's own, so nothing here can write into it.
var _bright: bool = false
## The second round's palette (B, designs 10 to 19): white, or near black.
var _light: bool = true
var _designs_b: RefCounted = null
var _designs_c: RefCounted = null
## "A": the list, or the route (design 21's view, built in), switched at its foot.
var _a_route: bool = false
## The style's own font, kept while the deck rounds swap in Regular.
var _base_font: Font = null
var _grey_palette: Dictionary = {}
## The design HUD, and whether Tab has it showing (kept for the session).
var _design_hud: Control = null
var _hud_open: bool = false
## The grouping (G): 0 the Frontier Map's four systems, 1 the RFP's three thrusts.
var _taxonomy: int = 0
## Tabs design: the system whose tab is open, its tabs, and the line naming what it shows.
var _tab_group: int = 0
var _tab_panels: Dictionary = {}
var _tab_line: Label = null
## The route's track beside each row, by entry index, redrawn as rows are played.
var _tracks: Dictionary = {}
## Segmented design: per entry index, Vector2i(first in its group, last in its group).
var _segments: Dictionary = {}
var _list_scroll: ScrollContainer = null

## Assign a different style or catalogue here to A/B a look or a running order
## without touching this script. Left empty, the defaults above load.
##
## Both re-emit `changed` when any of their properties is edited, so the preview
## follows the inspector live rather than needing a manual refresh.
@export var style: MenuStyle = null:
	set(value):
		_disconnect_resource(style)
		style = value
		_connect_resource(style)
		_request_rebuild()

@export var catalogue: MenuCatalogue = null:
	set(value):
		_disconnect_resource(catalogue)
		catalogue = value
		_connect_resource(catalogue)
		_request_rebuild()

@export_tool_button("Rebuild preview") var _rebuild_action: Callable = rebuild

## Reorders the entry currently shown in `preview_entry`.
##
## The array can also be dragged in the inspector, but with ten collapsed
## elements that means finding a grip handle on a row identified only by its
## index. These act on the entry you are already looking at, which is the one
## you formed an opinion about.
##
## ORDER IS THE CURRICULUM - it is the running order of the tour as well as the
## list, so this is a design control, not housekeeping.
@export_tool_button("Move up") var _move_up_action: Callable = move_selected_up
@export_tool_button("Move down") var _move_down_action: Callable = move_selected_down

## Live vertical crop for the SELECTED entry's clip. 0 is the top of the
## recorded frame, 1 the bottom.
##
## This is the handle. Dragging `preview_focus` inside the catalogue array meant
## drilling three levels down, losing sight of the preview, and editing a
## sub-resource whose `changed` signal does not reach the menu on its own. This
## sits on the node you already have selected, writes straight through to the
## entry, and re-crops on the same frame - so you can watch the clip while you
## find the band you want.
##
## Reads back the selected entry's value on every rebuild, so it always shows
## what is actually applied rather than a stale slider position.
@export_range(0.0, 1.0, 0.01) var preview_focus_live: float = 0.5:
	set(value):
		preview_focus_live = value
		_push_focus_to_entry()

## Which prototype the pane is showing, as a dropdown of their actual titles.
##
## Needed because the editor viewport does NOT forward clicks to generated
## controls - the 2D editor keeps mouse input for its own selection and
## manipulation - so there is no way to pick a row while authoring, and the crop
## slider above could only ever edit whichever entry happened to be selected.
##
## Declared through _get_property_list() rather than as an @export, because the
## list of names is only known once a catalogue is assigned. EDITOR without
## STORAGE, so it drives the preview and is never written into the .tscn - the
## same proxy pattern `Demo/_sign_board.gd` uses for its typography.
var _preview_entry: int = 0


func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if catalogue == null or _entries().is_empty():
		return list
	var names := PackedStringArray()
	for entry in _entries():
		names.append(entry.title if entry != null and entry.title != "" else "(untitled)")
	list.append({
		"name": "preview_entry",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(names),
	})
	return list


func _get(property: StringName):
	if property == &"preview_entry":
		return _preview_entry
	return null


func _set(property: StringName, value) -> bool:
	if property != &"preview_entry":
		return false
	_preview_entry = int(value)
	if is_inside_tree() and catalogue != null:
		_select(_preview_entry)
	return true

## Preview media, in priority order per entry:
##   1. `thumbs/<clip>.ogv`      - a recorded playthrough (best)
##   2. `thumbs/<clip>_loop.png` - the older sprite-sheet flipbook
##   3. the entry's icon, with the caption saying so
##
## DROP YOUR OWN VIDEO IN: put `<clip>.ogv` in thumbs/ and it plays - no code
## change, no rebuild, no editor import. Ogg Theora is the one video format
## Godot decodes without a third-party addon:
##
##   ffmpeg -i yours.mp4 -c:v libtheora -q:v 8 -an thumbs/<clip>.ogv
const CLIP_DIR: String = "res://ramon/Menu/thumbs/"
const ROUNDED_SHADER: String = "res://ramon/Menu/shaders/rounded_frame.gdshader"
const LOOP_FRAMES: int = 24
const LOOP_COLUMNS: int = 6
const LOOP_FRAME_SIZE: Vector2i = Vector2i(280, 161)
const LOOP_FPS: float = 12.0

## Returning from a prototype. Esc because it is what anyone reaches for; H
## because that is what the prototype's own prompt advertises.
const RETURN_KEY: Key = KEY_ESCAPE
const PROTOTYPE_RETURN_KEY: Key = KEY_H

## `_selected` is an index into `catalogue.entries`, or HERO for the banner above the list
## (`catalogue.hero`, which is deliberately not one of the entries). Everything that reads
## the selection goes through _entry() / _selected_entry() so the two cannot be confused.
const HERO: int = -1

## Starts on the banner, so the first thing the detail pane describes is the world rather
## than the first test chamber. Inside a laptop trip rebuild() moves it to the first tour
## entry instead, since the banner there only takes you back.
var _selected: int = HERO
var _played: Array[bool] = []
## Indexed by ENTRY index, not by screen position - the tour and the lab are drawn in two
## groups, so the two orders differ. `_order` is the screen order, top to bottom.
var _rows: Array[PanelContainer] = []
var _order: Array[int] = []
## Per system group, in SYSTEMS order: {"label": String, "color": Color}. See _load_systems().
var _systems: Array[Dictionary] = []
var _hero_panel: PanelContainer = null
var _shell: Control = null
## The banner's reference-space host, and the content margin beneath it. Both
## are re-fitted on every resize so the bar matches the Frontier Map's exactly.
var _banner_host: Control = null
var _margin: MarginContainer = null

var _preview_atlas: AtlasTexture = null
var _preview_frame: Control = null
var _preview_material: ShaderMaterial = null
var _video_material: ShaderMaterial = null
var _preview_icon: TextureRect = null
var _preview_video: VideoStreamPlayer = null
## "VIDEO N/A", centred in the frame, for an entry with no recording.
var _preview_na: Label = null
var _preview_caption: Label = null
var _detail_title: Label = null
## The system row under the title: one mark per group (only the entry's own is shown, or
## all four for the world) and the group's name.
var _detail_system: HBoxContainer = null
var _detail_marks: Array[Control] = []
var _detail_system_label: Label = null
var _detail_badge: PanelContainer = null
var _detail_badge_label: Label = null
var _detail_blurb: Label = null
var _controls_host: HBoxContainer = null
var _info_host: GridContainer = null
var _detail_duration: Label = null
var _benchmark_host: VBoxContainer = null
var _benchmark_label: Label = null
var _benchmark_value: Label = null
var _detail_path: Label = null
var _launch_row: HBoxContainer = null
## One per launch target of the selected entry, rebuilt on every selection.
var _launch_targets: Array[Dictionary] = []

var _loop_time: float = 0.0
var _running: Node = null

var _overlay: Control = null
var _overlay_title: Label = null
var _overlay_stage: Label = null
var _overlay_hint: Label = null
var _overlay_bar: ProgressBar = null
var _spinner: Spinner = null
var _launching: bool = false
var _notice: Control = null


## A ring that sweeps rather than an image, so it needs no asset and takes its
## colour from the style like everything else.
##
## Honest about what it can promise: the resource LOAD is genuinely threaded and
## reports real progress, but a prototype's geometry is built in its `_ready`,
## on the main thread, and that cannot be measured or interrupted. So the bar
## fills for the part that is measurable, and the spinner sits still during the
## build. A frozen spinner is not ideal - a bar that invented progress it did not
## have would be worse.
class Spinner extends Control:
	var colour: Color = Color.WHITE
	var track: Color = Color(1, 1, 1, 0.15)
	var thickness: float = 4.0
	var _angle: float = 0.0

	func _process(delta: float) -> void:
		_angle = fmod(_angle + delta * 3.4, TAU)
		queue_redraw()

	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - thickness
		if radius <= 0.0:
			return
		draw_arc(centre, radius, 0.0, TAU, 48, track, thickness, true)
		# A 100-degree sweep reads as motion at a glance; a full ring does not.
		draw_arc(centre, radius, _angle, _angle + deg_to_rad(100.0), 24, colour, thickness, true)


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Gameplay scenes capture the mouse and nothing else gives it back, so a
		# menu that does not do this is unusable after returning from a prototype.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_apply_window_mode()
		# Design review: the design and palette chosen last stay chosen for the session,
		# through a trip to the pen and back. The style is copied so B never writes into
		# the resource on disk.
		var root: Window = get_tree().root
		if root.has_meta(&"menu_design"):
			design = int(root.get_meta(&"menu_design"))
		_bright = bool(root.get_meta(&"menu_bright", false))
		_light = bool(root.get_meta(&"menu_light", true))
		_hud_open = bool(root.get_meta(&"menu_design_hud", false))
		_taxonomy = int(root.get_meta(&"menu_taxonomy", 0))
		_a_route = bool(root.get_meta(&"menu_a_route", false))
		if style != null:
			style = style.duplicate()
		_apply_palette()
	_connect_resource(style)
	_connect_resource(catalogue)
	rebuild()


## Puts the grey or the bright palette into the (run-time copy of the) style, quietly, so
## the caller's one rebuild is the only one.
func _apply_palette() -> void:
	if style == null or Engine.is_editor_hint():
		return
	if _grey_palette.is_empty():
		for key in PALETTE_KEYS:
			_grey_palette[key] = style.get(key)
	var palette: Dictionary = LAB_PALETTE if _bright else _grey_palette
	if _round3():
		palette = DECK_WHITE if _light else DECK_DARK
	elif design >= FIRST_B:
		palette = WHITE_PALETTE if _light else BLACK_PALETTE
	_disconnect_resource(style)
	for key in palette:
		style.set(key, palette[key])
	# The deck sets its body in Regular, where the menu uses SemiBold.
	if _base_font == null:
		_base_font = style.font
	style.font = (load(DECK_FONT) as Font) if _round3() else _base_font
	_connect_resource(style)


## Design review: switch the design (1 to 7) or the palette, remember it for the session,
## and draw the screen again.
func _set_design(value: int) -> void:
	design = value
	get_tree().root.set_meta(&"menu_design", design)
	_apply_palette()


## "A": switch between the list and the route view.
func _toggle_a_route(route: bool) -> void:
	if _a_route == route:
		return
	_a_route = route
	get_tree().root.set_meta(&"menu_a_route", _a_route)
	rebuild()


## G: group by the Frontier Map's four systems, or by the RFP's three questions.
func _toggle_taxonomy() -> void:
	_taxonomy = 1 - _taxonomy
	get_tree().root.set_meta(&"menu_taxonomy", _taxonomy)
	rebuild()


func _toggle_bright() -> void:
	if design >= FIRST_B:
		_light = not _light
		get_tree().root.set_meta(&"menu_light", _light)
	else:
		_bright = not _bright
		get_tree().root.set_meta(&"menu_bright", _bright)
	_apply_palette()
	rebuild()


## Which designs exist: all of them since round 3 came in from the deck.
func _design_available(value: int) -> bool:
	return value >= 0 and value < DESIGN_NAMES.size()


## Rounds 2 to 4 use the white and near-black palettes (B); round 1 grey and LAB.
func _white_black() -> bool:
	return design >= FIRST_B


## The second round's designs, built in menu_designs_b.gd.
func _round2() -> bool:
	return design >= FIRST_B and design < FIRST_C


## The third round's designs, from the Octobergate deck, built in menu_designs_c.gd; "A" is
## one of them worked further, so it counts here too.
func _round3() -> bool:
	return (design >= FIRST_C and design < FIRST_WASH) or design == DESIGN_A


## The original's layout: design 0, and every wash of the fourth round.
func _original_like() -> bool:
	return design == DESIGN_ORIGINAL or (design >= FIRST_WASH and design < FIRST_FINAL)


## The LAB palette's own touches (glass, its grid), first round only.
func _lab() -> bool:
	return _bright and design < FIRST_B


## Whether a fourth-round wash is on in this design.
func _wash(flag: String) -> bool:
	return design >= FIRST_WASH and design - FIRST_WASH < WASH_FLAGS.size() and (WASH_FLAGS[design - FIRST_WASH] as Array).has(flag)


## Whether the ground is light (the LAB palette, or the second round's white): type drawn
## straight on it is dark.
func _light_ground() -> bool:
	return (design >= FIRST_B and _light) or (design < FIRST_B and _bright)


## The third round's builders (menu_designs_c.gd), made on first use.
func _c() -> RefCounted:
	if _designs_c == null:
		_designs_c = DesignsC.new(self)
	return _designs_c


## The second round's builders (menu_designs_b.gd), made on first use.
func _b() -> RefCounted:
	if _designs_b == null:
		_designs_b = DesignsB.new(self)
	return _designs_b


## Deferred so a burst of inspector edits - dragging a slider, say - collapses
## into one rebuild instead of one per pixel of drag.
func _request_rebuild() -> void:
	if not is_inside_tree():
		return
	rebuild.call_deferred()


func _connect_resource(resource: Resource) -> void:
	if resource != null and not resource.changed.is_connected(_request_rebuild):
		resource.changed.connect(_request_rebuild)


## Each entry has to be listened to individually.
##
## A sub-resource's `changed` does NOT bubble up to the resource holding it -
## editing an entry's preview_focus fires `changed` on that MenuEntry and the
## MenuCatalogue never re-emits, so listening only to the catalogue means every
## per-entry edit is silently ignored in the editor preview. Reported exactly as
## "checking preview focus but doesn't update in realtime".
##
## Re-run on every rebuild, because the entries array can gain or lose members.
## _connect_resource already guards against duplicate connections.
## Deliberately NOT wired to the full rebuild. Rebuilding tears down and
## recreates the VideoStreamPlayer, so the clip would restart from frame zero on
## every step of a slider drag - which makes tuning a crop by eye impossible,
## the one thing this signal exists to support. The light refresh below updates
## the detail pane and re-crops in place without touching playback.
##
## The trade: edits to a row's TITLE or BLURB, and any change to the number or
## order of entries, still need the Rebuild preview button, because those live
## in generated row widgets this does not touch.
func _connect_entries() -> void:
	if catalogue == null:
		return
	var all: Array[MenuEntry] = _entries()
	if catalogue.hero != null:
		all.append(catalogue.hero)
	for entry in all:
		if entry != null and not entry.changed.is_connected(_on_entry_changed):
			entry.changed.connect(_on_entry_changed)


## Every row this menu lists: the catalogue's entries and, after them, its cinematics. Row
## indices, `_selected` and the played dots all count through this one list. Menu2 and the
## Frontier Map read `entries` alone, so the cinematics live apart in the resource.
##
## Entries with `show_in_menu` unticked are left out here, and so everywhere: they keep
## their place in the catalogue but get no row, no index and no launch.
func _entries() -> Array[MenuEntry]:
	var all: Array[MenuEntry] = []
	if catalogue == null:
		return all
	for entry in catalogue.entries + catalogue.cinematics:
		if entry != null and entry.show_in_menu:
			all.append(entry)
	return all


## The entry behind an index: HERO is the banner's `catalogue.hero`, anything else an
## index into `_entries()`. Null for anything out of range.
func _entry(index: int) -> MenuEntry:
	if catalogue == null:
		return null
	if index == HERO:
		return catalogue.hero
	var all: Array[MenuEntry] = _entries()
	if index < 0 or index >= all.size():
		return null
	return all[index]


func _selected_entry() -> MenuEntry:
	return _entry(_selected)


## Entry indices in the order they are drawn: the four system groups in SYSTEMS order, then
## any entry with no system, then the cinematics. Each group keeps the catalogue's own
## order, so "order is the curriculum" still holds inside it, and the groups themselves run
## the way a first-time visitor learns: read a slice, move through it, the world, life.
## (Until 8 Oct: the tour, the cinematics, then the lab.)
func _display_order() -> Array[int]:
	var groups: Array = []
	for g in GROUP_LAB + 1:
		groups.append([])
	var all: Array[MenuEntry] = _entries()
	for i in all.size():
		(groups[_group_of(all[i])] as Array).append(i)
	var order: Array[int] = []
	for group in groups:
		order.append_array(group)
	return order


## Which group an entry is listed under: 0 to 3 for the systems (SYSTEMS order),
## GROUP_OTHER for an entry with no system (the banner's own entry too), GROUP_FILMS for a
## cinematic.
func _group_of(entry: MenuEntry) -> int:
	if entry == null:
		return GROUP_OTHER
	if entry.section == "Cinematic":
		return GROUP_FILMS
	# The original: the tour, then the films, then the lab (and the fourth round keeps it).
	if _original_like():
		return GROUP_LAB if entry.section == "Lab" else GROUP_OTHER
	var system: int = THRUSTS.find(entry.thrust) if _taxonomy == 1 else SYSTEMS.find(entry.category)
	return system if system >= 0 else GROUP_OTHER


## A system group's colour, or the accent for an entry with none.
func _group_color(group: int) -> Color:
	# "A": one blue throughout, no hue shifts (Ramon, 8 Oct).
	if design == DESIGN_A:
		return style.accent
	if _round3() and group >= 0 and group < _systems.size():
		var ramp: Array[Color] = DECK_BLUES_WHITE if _light else DECK_BLUES_DARK
		return ramp[group % ramp.size()]
	if group >= 0 and group < _systems.size():
		return _systems[group]["color"]
	return style.accent


## Takes the four groups' names and colours from the Frontier Map's own layout, so the menu
## and the map cannot drift apart: retune a colour there and both follow. Falls back to the
## names in SYSTEMS and the accent colour if the layout cannot be read.
func _load_systems() -> void:
	_systems.clear()
	if _taxonomy == 1:
		for i in THRUSTS.size():
			_systems.append({"label": THRUST_LABELS[i], "color": THRUST_COLORS[i]})
		return
	for system in SYSTEMS:
		_systems.append({"label": system.to_upper(), "color": style.accent})
	if not ResourceLoader.exists(FRONTIER_LAYOUT):
		return
	var layout: Resource = load(FRONTIER_LAYOUT)
	if layout == null:
		return
	for category in layout.get("categories"):
		# The four kinds of proof draw a mark; sub-map lane headings do not.
		if category == null or not bool(category.get("show_mark")):
			continue
		var i: int = int(category.get("category"))
		if i >= 0 and i < _systems.size():
			_systems[i] = {"label": String(category.get("label")), "color": category.get("color") as Color}


## The cinematics, in the order listed: index 0 is the one the 1 key plays.
func _cinematic_order() -> Array[int]:
	var films: Array[int] = []
	var all: Array[MenuEntry] = _entries()
	for i in _order:
		var entry: MenuEntry = all[i]
		if entry != null and entry.section == "Cinematic":
			films.append(i)
	return films


## "CINEMATICS  ·  PRESS 1 OR 2", counted from the entries.
func _cinematics_heading() -> String:
	var n: int = _cinematic_order().size()
	var keys: String = "PRESS 1" if n == 1 else ("PRESS 1 OR 2" if n == 2 else "PRESS 1 TO %d" % n)
	return "%s  ·  %s" % [catalogue.cinematics_heading, keys]


## The laptop trip that opened this menu from inside the chicken pen, or null.
##
## pen_laptop_trip_4d.gd parks the game, marks the root with `laptop_trip` and stays at
## the root as "LaptopTrip" until you go home; its come_back() is the way back. Duck
## typed, because the menu must not depend on the pen's scripts.
func _laptop_trip() -> Node:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	var root: Window = get_tree().root
	if not root.has_meta(&"laptop_trip"):
		return null
	var trip: Node = root.get_node_or_null(^"LaptopTrip")
	return trip if trip != null and trip.has_method("come_back") else null


func move_selected_up() -> void:
	_move_selected(-1)


func move_selected_down() -> void:
	_move_selected(1)


func _move_selected(delta: int) -> void:
	# The banner is not in the running order, so there is nothing to move.
	if catalogue == null or _selected == HERO:
		return
	# `_selected` counts shown rows only, so find the entry's own place in the catalogue,
	# where entries taken off the menu still sit. The reorder tool works on `entries` only;
	# the cinematics keep their own order.
	var moved: MenuEntry = _selected_entry()
	var from: int = catalogue.entries.find(moved)
	var to: int = from + delta
	if from < 0 or to < 0 or to >= catalogue.entries.size():
		return

	var entries: Array[MenuEntry] = catalogue.entries
	entries.remove_at(from)
	entries.insert(to, moved)
	catalogue.entries = entries
	_selected = maxi(0, _entries().find(moved))

	_save_catalogue()
	rebuild()
	print("menu_final: moved '%s' to position %d" % [moved.title, to + 1])


## Writes the catalogue straight to disk.
##
## Not left to the editor's own dirty tracking: `entries` has no emit_changed in
## its setter - a custom setter on a TYPED array re-enters itself and hangs
## ResourceSaver - so nothing marks the resource modified when it is reordered
## from code, and Ctrl+S would quietly save nothing.
##
## Saving explicitly costs one known hazard, handled below: ResourceSaver strips
## the .tres `uid` header, and Menu.tscn, Menu2.tscn and menu_final.tscn reference the
## catalogue by uid.
func _save_catalogue() -> void:
	if catalogue == null or catalogue.resource_path.is_empty():
		return
	var path: String = catalogue.resource_path
	var absolute: String = ProjectSettings.globalize_path(path)

	var previous_uid: String = ""
	var before := FileAccess.open(absolute, FileAccess.READ)
	if before != null:
		var head: String = before.get_line()
		before.close()
		var found: int = head.find("uid=\"")
		if found >= 0:
			previous_uid = head.substr(found + 5, head.find("\"", found + 5) - found - 5)

	if ResourceSaver.save(catalogue, path) != OK:
		push_error("menu_final: could not save %s" % path)
		return

	if previous_uid.is_empty():
		return
	var after := FileAccess.open(absolute, FileAccess.READ)
	if after == null:
		return
	var text: String = after.get_as_text()
	after.close()
	if text.contains("uid=\"uid://"):
		return
	var bracket: int = text.find("]")
	if bracket < 0:
		return
	var out := FileAccess.open(absolute, FileAccess.WRITE)
	out.store_string(text.insert(bracket, " uid=\"%s\"" % previous_uid))
	out.close()


func _on_entry_changed() -> void:
	if is_inside_tree():
		_refresh_details.call_deferred()


## Writes the live slider into the selected entry and re-crops immediately.
##
## Immediately, not deferred: this is a drag handle, and a frame of lag between
## the slider and the picture is what makes a control feel broken.
func _push_focus_to_entry() -> void:
	if not is_inside_tree() or catalogue == null:
		return
	var entry: MenuEntry = _selected_entry()
	if entry == null or is_equal_approx(entry.preview_focus, preview_focus_live):
		return
	entry.preview_focus = preview_focus_live
	_layout_video()


## Pulls the selected entry's crop back onto the slider, so selecting a
## different prototype moves the handle to that one's value.
func _pull_focus_from_entry() -> void:
	var entry: MenuEntry = _selected_entry()
	if entry == null:
		return
	var focus: float = entry.preview_focus if entry.preview_focus >= 0.0 else style.preview_focus_default
	if not is_equal_approx(focus, preview_focus_live):
		preview_focus_live = focus


## Re-reads the selected entry into the detail pane without reloading its media.
func _refresh_details() -> void:
	if catalogue == null or _detail_title == null:
		return
	var entry: MenuEntry = _selected_entry()
	if entry == null:
		return
	_apply_entry_text(entry)
	_layout_video()


func _disconnect_resource(resource: Resource) -> void:
	if resource != null and resource.changed.is_connected(_request_rebuild):
		resource.changed.disconnect(_request_rebuild)


## Throws the whole screen away and builds it again from the two resources.
##
## Cheap enough to do on every edit - this is a few hundred Control nodes, not
## geometry - and rebuilding wholesale rather than patching in place means there
## is exactly one code path producing the layout, so the editor preview cannot
## drift from what actually runs.
func rebuild() -> void:
	if not is_inside_tree():
		return

	if style == null:
		style = load(DEFAULT_STYLE) as MenuStyle
	if catalogue == null:
		catalogue = load(DEFAULT_CATALOGUE) as MenuCatalogue
	if style == null or catalogue == null:
		push_warning("menu_final: missing style or catalogue resource")
		return

	_connect_entries()
	_load_systems()
	# The dropdown's options ARE the entry titles, so it has to be rebuilt
	# whenever they might have changed - a renamed entry, a new one, a reorder.
	notify_property_list_changed()

	if _shell != null and is_instance_valid(_shell):
		_shell.queue_free()
	_list_scroll = null
	# Whatever the last design drew per row goes with it: a jump from one design straight to
	# any other must not leave references to freed controls behind.
	_tracks.clear()
	_segments.clear()
	_tab_panels.clear()
	_rows.clear()
	_rows.resize(_entries().size())
	_order = _display_order()
	_hero_panel = null
	_preview_atlas = null

	_played.resize(_entries().size())
	if _played.count(true) == 0:
		_played.fill(false)

	# The banner is only a way back inside a laptop trip, so there the pane starts on the
	# first prototype instead; and with no hero configured there is nothing to start on.
	if _selected == HERO and (catalogue.hero == null or _laptop_trip() != null):
		_selected = _order[0] if not _order.is_empty() else 0

	_shell = Control.new()
	_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shell)

	# The ground, with the lab's faint grid in the bright palette (the Creation Lab's floor,
	# the range's holodeck walls). Drawn, so it costs no asset and follows the palette.
	var background := Control.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.draw.connect(_draw_background.bind(background))
	background.resized.connect(background.queue_redraw)
	_shell.add_child(background)

	# The header: the project's name over a hairline, the lab research wall's way. Until 8 Oct
	# this was the Frontier Map's banner (QUANTUM HORIZON over a big EXPLORE FREELY, and the
	# two tabs); with the map no longer linked, Ramon: "the explore freely header is something
	# we no longer need".
	if _round3():
		_banner_host = _c().build_frame()
	elif _original_like() and not _wash("slimhead"):
		_banner_host = _build_original_banner()
	else:
		_banner_host = _build_header()
	_shell.add_child(_banner_host)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_margins(margin, style.space(4))
	_shell.add_child(margin)
	_margin = margin

	if _round2():
		_b().build(margin)
	elif _round3():
		_c().build(margin)
	elif design == DESIGN_BOARD:
		# The board: the world and the four systems as columns across the top, the details
		# below, laid out sideways.
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", style.space(3))
		margin.add_child(stack)
		stack.add_child(_build_board())
		var detail := _build_detail_column(true)
		detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stack.add_child(detail)
	else:
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", style.space(4))
		margin.add_child(columns)
		columns.add_child(_build_list_column())
		columns.add_child(_build_detail_column())

	if design_review:
		_design_hud = _build_design_hud()
		_design_hud.visible = _hud_open
		_shell.add_child(_design_hud)

	# Siblings of _shell rather than children of it: the shell is hidden while a
	# prototype runs, and these have to outlive that. Rebuilt with everything else, so the
	# old ones go first (a rebuild used to leave its predecessors behind, hidden).
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	if _notice != null and is_instance_valid(_notice):
		_notice.queue_free()
	_build_launch_overlay()
	_build_notice()

	_layout_banner()
	if not resized.is_connected(_layout_banner):
		resized.connect(_layout_banner)

	_select(_selected)


## The launch overlay. Hidden until a launch begins.
##
## It also repeats the control key caps, which is not padding - the seconds
## before a prototype starts are exactly when someone wants to know the keys,
## and it is the last moment they can read them before the mouse is captured.
func _build_launch_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(style.background.r, style.background.g, style.background.b, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(centre)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", style.space(2))
	centre.add_child(column)

	var spinner_row := CenterContainer.new()
	column.add_child(spinner_row)
	_spinner = Spinner.new()
	_spinner.custom_minimum_size = Vector2(style.scaled(64), style.scaled(64))
	_spinner.colour = style.accent.lightened(0.35)
	_spinner.track = Color(style.text.r, style.text.g, style.text.b, 0.12)
	_spinner.thickness = style.scaled(5)
	spinner_row.add_child(_spinner)

	# DISPLAY rather than TITLE: with the menu dimmed out behind it, this is the
	# only thing anchoring the composition, and at TITLE it read as a caption
	# under the spinner rather than as the subject.
	_overlay_title = _label("", MenuStyle.DISPLAY, style.text, false)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_overlay_title)

	_overlay_bar = ProgressBar.new()
	_overlay_bar.custom_minimum_size = Vector2(style.scaled(320), style.scaled(4))
	_overlay_bar.show_percentage = false
	_overlay_bar.max_value = 1.0
	_overlay_bar.value = 0.0
	var track_box := _stylebox(Color(style.text.r, style.text.g, style.text.b, 0.12))
	var fill_box := _stylebox(style.accent.lightened(0.25))
	_overlay_bar.add_theme_stylebox_override("background", track_box)
	_overlay_bar.add_theme_stylebox_override("fill", fill_box)
	column.add_child(_overlay_bar)

	_overlay_stage = _label("", MenuStyle.MICRO, style.text_dim, true)
	_overlay_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_overlay_stage)

	_overlay_hint = _label("", MenuStyle.CAPTION, Color(0.72, 0.80, 0.92), false)
	_overlay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_overlay_hint)


## The hero banner's placeholder. The guided tour is not built, and the button
## previously launched the first entry - which reads as the button misfiring
## rather than as a feature that is not finished yet. Saying so plainly is the
## honest behaviour, and it costs nothing to dismiss.
func _build_notice() -> void:
	_notice = Control.new()
	_notice.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP, so a click anywhere lands here and dismisses rather than falling
	# through to whatever row happens to be underneath.
	_notice.mouse_filter = Control.MOUSE_FILTER_STOP
	_notice.gui_input.connect(_on_notice_input)
	_notice.visible = false
	add_child(_notice)

	var dim := ColorRect.new()
	dim.color = Color(style.background.r, style.background.g, style.background.b, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_child(centre)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", style.space(2.5))
	centre.add_child(column)

	var title := _label(catalogue.notice_title, MenuStyle.DISPLAY, style.text, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var body := _label(catalogue.notice_text(), MenuStyle.SUBTITLE, style.text_dim, false)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(body)

	var hint := _label(catalogue.notice_hint, MenuStyle.MICRO, style.text_faint, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _show_notice() -> void:
	if _notice != null:
		_notice.visible = true


func _hide_notice() -> void:
	if _notice != null:
		_notice.visible = false


func _on_notice_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_notice()


func _apply_window_mode() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = DESIGN_RESOLUTION

	# Opened from a laptop in the chicken pen, the game's window is the game's: leave its
	# mode and size alone (pen_laptop_trip_4d.gd puts the scaling above back on return).
	if get_tree().root.has_meta(&"laptop_trip"):
		return
	# Nor when a runner drives it (`--script`): a test has no business filling the author's
	# screen. The same check pen_fullscreen_4d.gd makes, for the same reason.
	for argument in OS.get_cmdline_args():
		if String(argument) == "--script" or String(argument) == "-s":
			return

	match WINDOW_MODE:
		WindowMode.BORDERLESS_FULLSCREEN:
			window.mode = Window.MODE_FULLSCREEN
			window.borderless = true
		WindowMode.EXCLUSIVE_FULLSCREEN:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			window.mode = Window.MODE_WINDOWED
			window.size = WINDOWED_SIZE
			var screen_size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
			window.position = (screen_size - WINDOWED_SIZE) / 2


## Hands the window's scaling back to the PROJECT's own settings, before a scene that
## owns the window replaces this menu (an `opens_as_scene` entry - the chicken pen).
##
## _apply_window_mode() switched the window to canvas-items scaling at 1920x1080 so this
## layout fits any screen, and nothing else puts that back: the pen's HUD, laid out for
## the project's unscaled window, came back scaled off the screen the first time a menu
## had changed it (pen_laptop_trip_4d.gd documents the same bug). Read from
## ProjectSettings rather than remembered at _ready, because arriving here from the
## Frontier Map the window already carries this menu's scaling.
func _restore_project_scaling() -> void:
	var window := get_window()
	match str(ProjectSettings.get_setting("display/window/stretch/mode", "disabled")):
		"canvas_items":
			window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		"viewport":
			window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		_:
			window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	match str(ProjectSettings.get_setting("display/window/stretch/aspect", "keep")):
		"ignore":
			window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		"keep_width":
			window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
		"keep_height":
			window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		"expand":
			window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		_:
			window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))
	window.content_scale_factor = float(ProjectSettings.get_setting("display/window/stretch/scale", 1.0))


## STOPGAP for a 4D-module bug, reported to Aaron on 30 Sept 2026. Remove once his fix lands.
##
## When a Cross-section (or other Godot-3D) rendering engine lets go of the root Window - its
## last Camera4D leaving, as when a prototype closes or a laptop parks the pen, or another
## engine taking over - its cleanup sets the root's World3D to null
## (godot_3d_rendering_engine_4d.cpp, cleanup_for_viewport). The root has no parent to fall
## back on, so it is left with no 3D world at all. The Combined engine then adds its
## SubViewports under it, and Godot's Viewport dereferences the missing world: a hard crash,
## every time a Combined scene (Voxel Mining, Shrubbery Lab, Lofted Creatures) followed a
## Cross-section one. Handing the root a fresh, empty World3D while the menu is up - and
## again just before a launch - removes the crash; the next engine replaces it as usual.
## Measured with _repro_sequence_runner.gd: six mixed launches in a row survive with it,
## the second one crashes without it.
static func ensure_root_world_3d(tree: SceneTree) -> void:
	if tree != null and tree.root != null and tree.root.world_3d == null:
		tree.root.world_3d = World3D.new()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		ensure_root_world_3d(get_tree())
	if _running != null or _preview_atlas == null:
		return
	# Sprite-sheet fallback playback: one PNG, an AtlasTexture region walking
	# across it. Only runs when there is no video for this entry.
	_loop_time += delta
	var frame: int = int(_loop_time * LOOP_FPS) % LOOP_FRAMES
	_preview_atlas.region = Rect2(
		Vector2((frame % LOOP_COLUMNS) * LOOP_FRAME_SIZE.x, (frame / LOOP_COLUMNS) * LOOP_FRAME_SIZE.y),
		Vector2(LOOP_FRAME_SIZE)
	)


# --------------------------------------------------------------------------
# Layout
# --------------------------------------------------------------------------

func _build_list_column() -> Control:
	var column := VBoxContainer.new()
	# One width for every design, so they compare like for like (and the world's line fits).
	column.custom_minimum_size.x = style.scaled(maxf(style.list_width, 620.0))
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", style.space(1.75))
	_tracks.clear()
	_tab_panels.clear()
	_segments.clear()

	# The list sits on a plate of its own in the LAB palette (black glass over the light
	# ground, so its type is never light on light) and in the lab wall design (the teaching-wall
	# blue, the world's banner on it too). In the grey palette it sits on the ground.
	var holder: VBoxContainer = column
	var plate := _list_plate()
	if design != DESIGN_WALL:
		column.add_child(_build_hero())
	if plate != null:
		plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(plate)
		var plate_margin := MarginContainer.new()
		_set_margins(plate_margin, style.space(2), style.space(2))
		plate.add_child(plate_margin)
		holder = VBoxContainer.new()
		holder.add_theme_constant_override("separation", style.space(1.75))
		plate_margin.add_child(holder)
	if design == DESIGN_WALL:
		holder.add_child(_build_hero())

	if design == DESIGN_TABS:
		holder.add_child(_build_tab_bar())
	elif _wash("pills"):
		holder.add_child(_heading_pill(catalogue.list_heading))
	else:
		holder.add_child(_label(catalogue.list_heading, MenuStyle.MICRO, _list_ink("dim"), true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)
	_list_scroll = scroll

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", style.space(1))
	scroll.add_child(rows)

	if _original_like():
		_fill_original(rows)
		holder.add_child(_list_hint())
		return column
	match design:
		DESIGN_HUD:
			_fill_hud(rows)
		DESIGN_SEGMENTED:
			_fill_segmented(rows)
		DESIGN_PANELS:
			_fill_panels(rows)
		DESIGN_ROUTE:
			_fill_route(rows)
		DESIGN_INDEX, DESIGN_WALL:
			_fill_index(rows)
		DESIGN_TABS:
			_fill_tabs(rows)
		DESIGN_ORIGINAL:
			_fill_original(rows)
		_:
			_fill_current(rows)

	# States the interaction rather than leaving it to be guessed at. In the lab HUD design, as
	# the lab's own control strip: a round glass pill of outline key caps.
	if design == DESIGN_HUD:
		holder.add_child(_control_strip([["Up / Down", "choose"], ["Enter", "launch"], ["Esc", "back"]]))
	else:
		holder.add_child(_label(catalogue.hint, MenuStyle.MICRO, _list_ink("dim"), false))
	return column


## The plate the list sits on, or null for none (the grey palette, every design but the lab wall).
func _list_plate() -> PanelContainer:
	var fill: Color
	if design == DESIGN_WALL:
		fill = WALL_BLUE
	elif _lab():
		fill = style.surface
	else:
		return null
	var plate := PanelContainer.new()
	var box := _stylebox(fill)
	if design != DESIGN_WALL:
		box.border_color = GLASS_EDGE
		box.set_border_width_all(1)
	plate.add_theme_stylebox_override("panel", box)
	return plate


## The list's own type: white on the wall, the palette's otherwise.
func _list_ink(role: String) -> Color:
	if design == DESIGN_WALL:
		match role:
			"dim":
				return Color(WALL_INK, 0.82)
			"faint":
				return Color(WALL_INK, 0.62)
		return WALL_INK
	match role:
		"dim":
			return style.text_dim
		"faint":
			return style.text_faint
	return style.text


## A system's colour for type and marks in the list: the map's colour, or white on the wall.
func _group_ink(group: int) -> Color:
	if design == DESIGN_WALL:
		return WALL_INK if group < _systems.size() else Color(WALL_INK, 0.82)
	if group < _systems.size():
		return _group_color(group)
	return style.text_dim


## The entries in screen order, cut into their groups: [[group, [entry indices]], ...].
func _groups_in_order() -> Array:
	var out: Array = []
	for i in _order:
		var group: int = _group_of(_entry(i))
		if out.is_empty() or int(out[-1][0]) != group:
			out.append([group, []])
		(out[-1][1] as Array).append(i)
	return out


## A group's name: the system's own (from the map), CINEMATICS or MORE.
func _group_label(group: int) -> String:
	if group < _systems.size():
		return _systems[group]["label"]
	if group == GROUP_FILMS:
		return _cinematics_heading()
	if group == GROUP_LAB:
		return catalogue.lab_heading
	return catalogue.other_heading


func _group_line(group: int) -> String:
	if _taxonomy == 1:
		return THRUST_LINES[group] if group < THRUST_LINES.size() else ""
	if group < _systems.size() and group < catalogue.system_lines.size():
		return catalogue.system_lines[group]
	return ""


## Position in the run (the prototypes in screen order, films left out), 1-based, and how
## many there are: "01 / 07".
func _run_number(index: int) -> int:
	var n: int = 0
	for i in _order:
		if _group_of(_entry(i)) == GROUP_FILMS:
			continue
		n += 1
		if i == index:
			return n
	return 0


func _run_total() -> int:
	var n: int = 0
	for i in _order:
		if _group_of(_entry(i)) != GROUP_FILMS:
			n += 1
	return n


## A hairline between rows of one group, and a heavier rule between groups.
func _hairline(strong: bool = false) -> ColorRect:
	var line := ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size.y = 2 if strong else 1
	if design == DESIGN_WALL:
		line.color = Color(WALL_INK, 0.45 if strong else 0.20)
	else:
		line.color = Color(style.text, 0.22 if strong else 0.07)
	return line


func _gap(rows: VBoxContainer, units: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = style.space(units)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(gap)


## A group's heading as one line: mark, name in the system's colour, what it shows.
## `step` sets the name's size; `wrap` lets the line run on under the name.
func _group_heading(group: int, step: int, wrap: bool) -> Control:
	var ink: Color = _group_ink(group)
	var box: BoxContainer = VBoxContainer.new() if wrap else HBoxContainer.new()
	box.add_theme_constant_override("separation", style.space(0.5 if wrap else 0.9))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", style.space(0.9))
	box.add_child(top)
	if group < _systems.size():
		top.add_child(_system_mark(group, ink, style.scaled(20 if step <= MenuStyle.CAPTION else 24)))
	var name_label := _label(_group_label(group), step, ink, true)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_label)
	var what: String = _group_line(group)
	if what != "":
		var note := _label(what, MenuStyle.CAPTION, _list_ink("dim"), false)
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if wrap:
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(note)
	return box


## The original: the tour with no heading, then the cinematics and the lab under theirs, the cards
## as they were.
func _fill_original(rows: VBoxContainer) -> void:
	var lines: bool = _wash("hairlines")
	if lines:
		rows.add_theme_constant_override("separation", 0)
	var group_now: int = GROUP_OTHER
	var first_in_group: bool = true
	for i in _order:
		var group: int = _group_of(_entry(i))
		if group != group_now:
			group_now = group
			first_in_group = true
			_add_group_heading(rows, _group_label(group), true)
			if lines:
				_gap(rows, 0.75)
		if lines and not first_in_group:
			rows.add_child(_hairline())
		first_in_group = false
		var row := _build_row(i)
		_rows[i] = row
		rows.add_child(row)


## Current, as it was: headings between identical cards.
func _fill_current(rows: VBoxContainer) -> void:
	# The system groups, then the cinematics, each under its own heading. Rows are stored by
	# entry index, so selection, played dots and auto-advance do not care which group a row
	# sits in.
	var group_now: int = -1
	for i in _order:
		var group: int = _group_of(_entry(i))
		if group != group_now:
			var first: bool = group_now == -1
			group_now = group
			if group < _systems.size():
				_add_system_heading(rows, group, not first)
			elif group == GROUP_FILMS:
				_add_group_heading(rows, _cinematics_heading(), not first)
			else:
				_add_group_heading(rows, catalogue.other_heading, not first)
		var row := _build_row(i)
		_rows[i] = row
		rows.add_child(row)


## Segmented: the current cards, but a system's cards touch (3 px) as one stack with rounded
## ends, its heading 8 px above it and 36 px of air above that (proximity: the gap between
## groups many times the gap inside one), and slimmer cards so the whole list fits at 1080p.
func _fill_segmented(rows: VBoxContainer) -> void:
	rows.add_theme_constant_override("separation", 0)
	var first: bool = true
	for chunk in _groups_in_order():
		var group: int = int(chunk[0])
		var ids: Array = chunk[1]
		if not first:
			_gap(rows, 4.5)
		first = false
		rows.add_child(_group_heading(group, MenuStyle.CAPTION, false))
		_gap(rows, 1.0)
		for k in ids.size():
			if k > 0:
				var seam := Control.new()
				seam.custom_minimum_size.y = 3
				seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
				rows.add_child(seam)
			var i: int = int(ids[k])
			_segments[i] = Vector2i(1 if k == 0 else 0, 1 if k == ids.size() - 1 else 0)
			var row := _build_row(i, RowKind.CARD, false, true)
			_rows[i] = row
			rows.add_child(row)


## The lab HUD design: each system's heading a round glass pill (mark, name, what it shows),
## its prototypes as lab title cards under it, a wider gap before the next pill.
func _fill_hud(rows: VBoxContainer) -> void:
	rows.add_theme_constant_override("separation", 0)
	var first: bool = true
	for chunk in _groups_in_order():
		var group: int = int(chunk[0])
		var ids: Array = chunk[1]
		if not first:
			_gap(rows, 3.5)
		first = false
		var pill := PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pill.add_theme_stylebox_override("panel", _pill_box(HUD_GLASS, HUD_EDGE))
		var pad := MarginContainer.new()
		_set_margins(pad, style.space(1.75), style.space(0.75))
		pill.add_child(pad)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", style.space(0.9))
		pad.add_child(line)
		var ink: Color = _group_color(group) if group < _systems.size() else HUD_ACCENT
		if group < _systems.size():
			line.add_child(_system_mark(group, ink, style.scaled(18)))
		var name_label := _label(_group_label(group), MenuStyle.CAPTION, ink, true)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(name_label)
		var what: String = _group_line(group)
		if what != "":
			var note := _label(what, MenuStyle.CAPTION, HUD_INK_DIM, false)
			note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(note)
		rows.add_child(pill)
		_gap(rows, 1.0)
		for k in ids.size():
			if k > 0:
				_gap(rows, 0.75)
			var i: int = int(ids[k])
			var row := _build_row(i, RowKind.GLASS)
			_rows[i] = row
			rows.add_child(row)


## A fully round pill: the lab's buttons, chips and strips.
func _pill_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(999)
	box.anti_aliasing = true
	return box


## The lab's outline key cap: no fill, a white 70% edge, radius 5.
func _keycap_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	# The palette's own ink: white on the dark grounds, navy on white.
	box.border_color = Color(style.text, 0.7)
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	return box


## The lab's control strip: a round glass pill of key caps and what they do, thin dividers
## between (CreationLab/scripts/rd_hud.gd).
func _control_strip(pairs: Array) -> Control:
	var strip := PanelContainer.new()
	strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var glass: bool = design == DESIGN_HUD
	strip.add_theme_stylebox_override("panel", _pill_box(HUD_GLASS, HUD_EDGE) if glass else _pill_box(style.surface, Color(style.text, 0.12)))
	var pad := MarginContainer.new()
	_set_margins(pad, style.space(2), style.space(0.75))
	strip.add_child(pad)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", style.space(1.25))
	pad.add_child(line)
	for k in pairs.size():
		if k > 0:
			var divider := ColorRect.new()
			divider.color = Color(1, 1, 1, 0.25) if glass else Color(style.text, 0.2)
			divider.custom_minimum_size = Vector2(1, style.scaled(16))
			divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(divider)
		var cap := PanelContainer.new()
		cap.add_theme_stylebox_override("panel", _keycap_box())
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key := _label(String(pairs[k][0]), MenuStyle.CAPTION, Color(1, 1, 1) if glass else style.text, false)
		_heavy(key)
		cap.add_child(key)
		line.add_child(cap)
		var what := _label(String(pairs[k][1]), MenuStyle.CAPTION, HUD_INK_SOFT if glass else style.text_dim, false)
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(what)
	return strip


## Sets a label in Montserrat ExtraBold, the lab's title weight.
func _heavy(label: Label) -> void:
	var font: Font = load(HEAVY_FONT) as Font
	if font != null:
		label.add_theme_font_override("font", font)


## Panels, common region: each group one panel, its heading inside at the top under an edge
## in the system's colour, its prototypes as flat rows with hairlines between.
func _fill_panels(rows: VBoxContainer) -> void:
	rows.add_theme_constant_override("separation", style.space(2.5))
	for chunk in _groups_in_order():
		var group: int = int(chunk[0])
		var ids: Array = chunk[1]
		var panel := PanelContainer.new()
		var box := _stylebox(GLASS_CARD if _lab() else style.surface)
		if group < _systems.size():
			box.border_color = _group_color(group)
			box.border_width_top = 3
		panel.add_theme_stylebox_override("panel", box)
		rows.add_child(panel)
		var pad := MarginContainer.new()
		_set_margins(pad, style.space(1.25), style.space(1.5))
		panel.add_child(pad)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 0)
		pad.add_child(inner)
		var head := _group_heading(group, MenuStyle.CAPTION, false)
		inner.add_child(head)
		_gap(inner, 1.0)
		for k in ids.size():
			if k > 0:
				inner.add_child(_hairline())
			var i: int = int(ids[k])
			var row := _build_row(i, RowKind.FLAT)
			_rows[i] = row
			inner.add_child(row)


## Route, connectedness: a route like the Frontier Map's runs down each group, a node per
## prototype (filled once played, ringed when selected), the group's mark at its head; wide
## gaps between groups, none between the rows of one.
func _fill_route(rows: VBoxContainer) -> void:
	rows.add_theme_constant_override("separation", 0)
	var first: bool = true
	for chunk in _groups_in_order():
		var group: int = int(chunk[0])
		var ids: Array = chunk[1]
		if not first:
			_gap(rows, 3.5)
		first = false
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", style.space(1))
		var cap := Control.new()
		cap.custom_minimum_size = Vector2(style.scaled(30), style.scaled(30))
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.draw.connect(_draw_route_cap.bind(cap, group))
		head.add_child(cap)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 0)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(words)
		words.add_child(_label(_group_label(group), MenuStyle.BODY, _group_ink(group), true))
		var what: String = _group_line(group)
		if what != "":
			words.add_child(_label(what, MenuStyle.CAPTION, _list_ink("dim"), false))
		rows.add_child(head)
		for k in ids.size():
			var i: int = int(ids[k])
			var row := _build_row(i, RowKind.ROUTE, k == ids.size() - 1)
			_rows[i] = row
			rows.add_child(row)


## Numbered index and the lab wall: a two-column index, the system on the left, its prototypes numbered on the
## right (the research wall's numbered story); heavy rules between systems, hairlines within.
func _fill_index(rows: VBoxContainer) -> void:
	rows.add_theme_constant_override("separation", 0)
	var first: bool = true
	for chunk in _groups_in_order():
		var group: int = int(chunk[0])
		var ids: Array = chunk[1]
		if not first:
			_gap(rows, 1.25)
		rows.add_child(_hairline(true))
		_gap(rows, 1.25)
		first = false
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", style.space(2))
		rows.add_child(line)
		var left := VBoxContainer.new()
		left.custom_minimum_size.x = style.scaled(128)
		left.add_theme_constant_override("separation", style.space(0.6))
		line.add_child(left)
		if group < _systems.size():
			left.add_child(_system_mark(group, _group_ink(group), style.scaled(24)))
		var name_label := _label(_group_label(group), MenuStyle.CAPTION, _group_ink(group), true)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size.x = style.scaled(128)
		left.add_child(name_label)
		var what: String = _group_line(group)
		if what != "":
			var note := _label(what, MenuStyle.MICRO, _list_ink("dim"), false)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = style.scaled(128)
			left.add_child(note)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 0)
		line.add_child(right)
		for k in ids.size():
			if k > 0:
				right.add_child(_hairline())
			var i: int = int(ids[k])
			var row := _build_row(i, RowKind.INDEX)
			_rows[i] = row
			right.add_child(row)


## Tabs: one system at a time. Every row is built; only the open tab's are shown.
func _fill_tabs(rows: VBoxContainer) -> void:
	_tab_line = _label("", MenuStyle.CAPTION, _list_ink("dim"), false)
	rows.add_child(_tab_line)
	for i in _order:
		var row := _build_row(i)
		_rows[i] = row
		rows.add_child(row)
	var entry: MenuEntry = _selected_entry()
	var group: int = _group_of(entry) if entry != null and _selected != HERO else _tab_group
	_open_tab(group if _tab_panels.has(group) else _first_tab(), false)


func _first_tab() -> int:
	var groups: Array = _groups_in_order()
	return int(groups[0][0]) if not groups.is_empty() else 0


## The tabs: one per group present, its mark over its name, the open one lit and underlined
## in its colour.
func _build_tab_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", style.space(0.75))
	for chunk in _groups_in_order():
		var group: int = int(chunk[0])
		var tab := PanelContainer.new()
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.gui_input.connect(_on_tab_input.bind(group))
		var pad := MarginContainer.new()
		_set_margins(pad, style.space(0.75), style.space(1))
		tab.add_child(pad)
		var stack := VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", style.space(0.5))
		pad.add_child(stack)
		if group < _systems.size():
			var mark := _system_mark(group, _group_ink(group), style.scaled(22))
			mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			stack.add_child(mark)
		var label_text: String = _systems[group]["label"] if group < _systems.size() else catalogue.cinematics_heading
		var name_label := _label(label_text, MenuStyle.MICRO, _list_ink("title"), true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(name_label)
		bar.add_child(tab)
		_tab_panels[group] = tab
	return bar


func _on_tab_input(event: InputEvent, group: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_open_tab(group, true)


## Opens a tab: lights it, shows only its rows and, from a click, selects its first row.
func _open_tab(group: int, select_first: bool) -> void:
	_tab_group = group
	for g in _tab_panels:
		var open: bool = int(g) == group
		var lit: Color = GLASS_LIT if _lab() else style.surface_raised
		var box := _stylebox(lit if open else Color(0, 0, 0, 0))
		if open:
			box.border_color = _group_color(group) if group < _systems.size() else style.text_dim
			box.border_width_bottom = 3
		(_tab_panels[g] as Control).add_theme_stylebox_override("panel", box)
	var first_row: int = -1
	for i in _order:
		if _rows[i] == null:
			continue
		var here: bool = _group_of(_entry(i)) == group
		_rows[i].visible = here
		if here and first_row < 0:
			first_row = i
	if _tab_line != null:
		var what: String = _group_line(group)
		_tab_line.text = what.substr(0, 1).to_upper() + what.substr(1) if what != "" else ""
		_tab_line.visible = what != ""
	if select_first and first_row >= 0 and Engine.is_editor_hint() == false:
		_select(first_row)
	elif select_first and first_row >= 0:
		_select(first_row)


## Board: the world and each group as columns across the top, the way the Frontier Map
## lays its categories out left to right.
func _build_board() -> Control:
	_tracks.clear()
	_tab_panels.clear()
	var board := HBoxContainer.new()
	board.add_theme_constant_override("separation", style.space(2))
	var world := VBoxContainer.new()
	world.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hero := _build_hero(true)
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world.add_child(hero)
	board.add_child(world)
	for chunk in _groups_in_order():
		var group: int = int(chunk[0])
		var ids: Array = chunk[1]
		var column := PanelContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := _stylebox(style.surface)
		if group < _systems.size():
			box.border_color = _group_color(group)
			box.border_width_top = 3
		if _lab():
			box.border_color = _group_color(group) if group < _systems.size() else GLASS_EDGE
		column.add_theme_stylebox_override("panel", box)
		board.add_child(column)
		var pad := MarginContainer.new()
		_set_margins(pad, style.space(1.25), style.space(1.5))
		column.add_child(pad)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", style.space(1))
		pad.add_child(inner)
		inner.add_child(_group_heading(group, MenuStyle.CAPTION, true))
		for k in ids.size():
			var i: int = int(ids[k])
			var row := _build_row(i, RowKind.TILE)
			_rows[i] = row
			inner.add_child(row)
	return board


func _add_group_heading(rows: VBoxContainer, text: String, gap_above: bool = true) -> void:
	if gap_above:
		_add_group_gap(rows)
	rows.add_child(_heading_pill(text) if _wash("pills") else _label(text, MenuStyle.MICRO, style.text_dim, true))


## The pills wash: a heading as a small round pill in the palette's own colours.
func _heading_pill(text: String) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.add_theme_stylebox_override("panel", _pill_box(Color(style.text, 0.05), Color(style.text, 0.14)))
	var pad := MarginContainer.new()
	_set_margins(pad, style.space(1.5), style.space(0.5))
	pill.add_child(pad)
	pad.add_child(_label(text, MenuStyle.MICRO, style.text_dim, true))
	return pill


## The hint under the list: the line, or in the pills wash the lab's control strip.
func _list_hint() -> Control:
	if _wash("pills"):
		return _control_strip([["Up / Down", "choose"], ["Enter", "launch"], ["Esc", "back"]])
	return _label(catalogue.hint, MenuStyle.MICRO, _list_ink("dim"), false)


func _add_group_gap(rows: VBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = style.space(1.5)
	rows.add_child(gap)


## A system group's heading: the Frontier Map's mark and name in the group's colour, then
## what the group shows ("ORIENTATION  reading a 4D slice").
func _add_system_heading(rows: VBoxContainer, group: int, gap_above: bool) -> void:
	if gap_above:
		_add_group_gap(rows)
	var ink: Color = _group_color(group)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", style.space(0.9))
	line.add_child(_system_mark(group, ink, style.scaled(20)))
	var heading := _label(_systems[group]["label"], MenuStyle.CAPTION, ink, true)
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(heading)
	var what: String = catalogue.system_lines[group] if group < catalogue.system_lines.size() else ""
	if what != "":
		var note := _label(what, MenuStyle.CAPTION, style.text_dim, false)
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(note)
	rows.add_child(line)


## The Frontier Map's mark for a system group, as a small square Control.
func _system_mark(group: int, ink: Color, side: float) -> Control:
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(side, side)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(_draw_system_mark.bind(mark, group, ink))
	return mark


## The four marks, drawn the Frontier Map's way (frontier_map.gd, _draw_category_mark) at
## any size: a reticle for Orientation, a cube for Spatial interaction, three cells for
## World systems, two strands for Living systems. Its numbers are for a 30 px box, scaled.
func _draw_system_mark(mark: Control, group: int, ink: Color) -> void:
	var k: float = minf(mark.size.x, mark.size.y) / 30.0
	if k <= 0.0:
		return
	var mid: Vector2 = mark.size * 0.5
	var w: float = maxf(1.2, 1.6 * k)
	var shape: int = THRUST_MARKS[group] if _taxonomy == 1 and group < THRUST_MARKS.size() else group
	# "A": the cube (Spatial interaction) draws more lines in the same box than the others, so it
	# read heavier; a thinner stroke evens it out (Ramon, 8 Oct).
	if design == DESIGN_A and shape == 1:
		w *= 0.72
	match shape:
		0:
			mark.draw_arc(mid, 9.0 * k, 0.0, TAU, 32, ink, w, true)
			mark.draw_arc(mid, 2.6 * k, 0.0, TAU, 12, ink, w, true)
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				mark.draw_line(mid + direction * 13.0 * k, mid + direction * 9.5 * k, ink, w, true)
		1:
			var top := PackedVector2Array([
				mid + Vector2(0, -10) * k, mid + Vector2(9, -5) * k,
				mid + Vector2(0, 0) * k, mid + Vector2(-9, -5) * k, mid + Vector2(0, -10) * k])
			mark.draw_polyline(top, ink, w, true)
			mark.draw_line(mid + Vector2(-9, -5) * k, mid + Vector2(-9, 5) * k, ink, w, true)
			mark.draw_line(mid + Vector2(9, -5) * k, mid + Vector2(9, 5) * k, ink, w, true)
			mark.draw_line(mid, mid + Vector2(0, 10) * k, ink, w, true)
			mark.draw_line(mid + Vector2(-9, 5) * k, mid + Vector2(0, 10) * k, ink, w, true)
			mark.draw_line(mid + Vector2(9, 5) * k, mid + Vector2(0, 10) * k, ink, w, true)
		2:
			for offset in [Vector2(-5, -6), Vector2(6, 0), Vector2(-5, 7)]:
				var cell := PackedVector2Array()
				for i in 7:
					var angle: float = TAU * float(i) / 6.0 - PI * 0.5
					cell.append(mid + (offset + Vector2(cos(angle), sin(angle)) * 5.2) * k)
				mark.draw_polyline(cell, ink, w, true)
		3:
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for i in 13:
				var t: float = float(i) / 12.0
				var y: float = -11.0 + t * 22.0
				left.append(mid + Vector2(sin(t * PI * 1.6) * 6.0, y) * k)
				right.append(mid + Vector2(-sin(t * PI * 1.6) * 6.0, y) * k)
			mark.draw_polyline(left, ink, w, true)
			mark.draw_polyline(right, ink, w, true)
			for i in [3, 6, 9]:
				mark.draw_line(left[i], right[i], Color(ink, 0.7), maxf(1.0, 1.2 * k), true)


## The ground: the palette's background and, in the LAB palette, the range's wall grid (a light
## line every 48 px, a heavier one every fourth).
func _draw_background(node: Control) -> void:
	node.draw_rect(Rect2(Vector2.ZERO, node.size), style.background)
	if _round3():
		return
	if _white_black():
		if _round2() or _wash("grid"):
			_b().draw_ground(node)
		return
	if not _lab():
		return
	var step: float = 48.0
	var n: int = 0
	var x: float = 0.0
	while x <= node.size.x:
		node.draw_line(Vector2(x, 0), Vector2(x, node.size.y), Color(LAB_GRID, 0.55 if n % 4 == 0 else 0.25), 1.0)
		x += step
		n += 1
	n = 0
	var y: float = 0.0
	while y <= node.size.y:
		node.draw_line(Vector2(0, y), Vector2(node.size.x, y), Color(LAB_GRID, 0.55 if n % 4 == 0 else 0.25), 1.0)
		y += step
		n += 1


## The design HUD (Tab): a small glass panel over the top right of the menu, only for designing.
## The designs as numbered buttons the number keys also press, the palette as a pill that B
## also presses (named for what it switches to, like the Creation Lab's "BLACK · B"), the
## design's name and the grouping idea it tests, and how to close it.
func _build_design_hud() -> Control:
	var hud := PanelContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.offset_left = -style.scaled(900)
	hud.offset_right = -style.space(2)
	hud.offset_top = style.space(1.5)
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := _stylebox(Color(0.04, 0.06, 0.10, 0.88))
	box.border_color = Color(1, 1, 1, 0.14)
	box.set_border_width_all(1)
	hud.add_theme_stylebox_override("panel", box)
	var pad := MarginContainer.new()
	_set_margins(pad, style.space(1.5), style.space(1.25))
	hud.add_child(pad)
	var strip := VBoxContainer.new()
	strip.add_theme_constant_override("separation", style.space(0.75))
	pad.add_child(strip)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 6)
	strip.add_child(keys)
	var tag := _label("DESIGN", MenuStyle.MICRO, Color(0.72, 0.80, 0.94), true)
	tag.custom_minimum_size.x = 64
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(tag)
	for i in FIRST_B:
		keys.add_child(_hud_design_button(i))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.add_child(spacer)
	var grouping := _review_button("BY SYSTEM  ·  G" if _taxonomy == 1 else "BY QUESTION  ·  G", false, Vector2(150, 32))
	grouping.pressed.connect(_toggle_taxonomy)
	grouping.tooltip_text = "Group by the Frontier Map's systems, or by the RFP's Build it / Fill it / Live it"
	keys.add_child(grouping)
	var palette_text: String = ("BLACK  ·  B" if _light else "WHITE  ·  B") if _white_black() else ("GREY  ·  B" if _bright else "LAB  ·  B")
	var palette := _review_button(palette_text, false, Vector2(110, 32))
	palette.pressed.connect(_toggle_bright)
	keys.add_child(palette)
	# Rounds 2 to 4 under the first: mouse only.
	for row in [[FIRST_B, "ROUND 2"], [FIRST_C, "ROUND 3"], [FIRST_WASH, "ROUND 4"]]:
		var keys_row := HBoxContainer.new()
		keys_row.add_theme_constant_override("separation", 6)
		strip.add_child(keys_row)
		var tag_row := _label(String(row[1]), MenuStyle.MICRO, Color(0.72, 0.80, 0.94), true)
		tag_row.custom_minimum_size.x = 64
		tag_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		keys_row.add_child(tag_row)
		if not _design_available(int(row[0])):
			keys_row.add_child(_label("waiting for the Figma frame", MenuStyle.CAPTION, Color(0.60, 0.67, 0.78), false))
			continue
		for i in range(int(row[0]), int(row[0]) + 10):
			keys_row.add_child(_hud_design_button(i))
	# The final row: Ramon's picks, worked further.
	var keys_final := HBoxContainer.new()
	keys_final.add_theme_constant_override("separation", 6)
	strip.add_child(keys_final)
	var tag_final := _label("FINAL", MenuStyle.MICRO, Color(0.72, 0.80, 0.94), true)
	tag_final.custom_minimum_size.x = 64
	tag_final.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys_final.add_child(tag_final)
	keys_final.add_child(_hud_design_button(DESIGN_A))
	var name_line := _label("%s   %s" % ["A" if design == DESIGN_A else str(design), DESIGN_NAMES[design]], MenuStyle.CAPTION, Color(1, 1, 1), true)
	strip.add_child(name_line)
	var idea := _label(DESIGN_IDEAS[design], MenuStyle.CAPTION, Color(0.80, 0.85, 0.94), false)
	idea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strip.add_child(idea)
	var grouped := "Grouped by the RFP's questions: Live it, Fill it, Build it" if _taxonomy == 1 else "Grouped by the Frontier Map's four systems"
	strip.add_child(_label(grouped, MenuStyle.CAPTION, Color(0.72, 0.80, 0.94), false))
	strip.add_child(_label("TAB  hides this   ·   0 to 9 on the keys, the second row by mouse", MenuStyle.MICRO, Color(0.60, 0.67, 0.78), true))
	return hud


func _hud_design_button(i: int) -> Button:
	var button := _review_button("A" if i == DESIGN_A else str(i), i == design, Vector2(34, 32))
	button.pressed.connect(_set_design.bind(i))
	button.tooltip_text = DESIGN_NAMES[i]
	return button


func _review_button(text: String, active: bool, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	# Never takes the keyboard: the arrows and Enter stay the list's.
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_override("font", style.label_font())
	button.add_theme_font_size_override("font_size", 13)
	var ink: Color = ON_ACCENT if active else Color(0.80, 0.85, 0.94)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	var blue := Color(0.13, 0.40, 0.86)
	var idle := _stylebox(blue if active else Color(0, 0, 0, 0))
	idle.border_color = blue if active else Color(1, 1, 1, 0.22)
	idle.set_border_width_all(1)
	var hover := _stylebox(blue.lightened(0.1) if active else Color(1, 1, 1, 0.08))
	hover.border_color = idle.border_color
	hover.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


## The header: what this screen is, and how much it covers. Left, the project and its subject
## ("QUANTUM HORIZON  /  4D PROTOTYPES", the subject editable as `catalogue.header_subject`);
## right, the coverage counted from the catalogue so it can never go stale ("ONE WORLD  ·  7
## PROTOTYPES  ·  4 SYSTEMS"), the Frontier Map's argument in one line. Laid out like the
## Creation Lab research wall's header ("CREATION LAB / RESEARCH WALL" and its claim on the
## right). Inside a laptop trip the right side is the pen's way home, so the count steps aside.
func _build_header() -> Control:
	var header := Control.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.custom_minimum_size.y = HEADER_HEIGHT
	header.offset_bottom = HEADER_HEIGHT
	var ink: Color = Color(0.06, 0.11, 0.19) if _light_ground() else style.text
	var dim: Color = Color(0.32, 0.38, 0.48) if _light_ground() else style.text_dim
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", style.space(1.25))
	line.position = Vector2(style.space(4), style.space(2.25))
	header.add_child(line)
	var title := _label(catalogue.header, MenuStyle.BODY, ink, true)
	line.add_child(title)
	var subject: String = catalogue.explore_tab if _original_like() else catalogue.header_subject
	if subject != "":
		line.add_child(_label("/", MenuStyle.BODY, dim, false))
		line.add_child(_label(subject, MenuStyle.BODY, dim, true))
	if _laptop_trip() == null:
		var count := _label(_coverage_line(), MenuStyle.CAPTION, dim, true)
		count.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.offset_right = -style.space(4)
		count.offset_top = style.space(2.5)
		header.add_child(count)
	header.draw.connect(_draw_header.bind(header, line))
	return header


## "ONE WORLD  ·  7 PROTOTYPES  ·  4 SYSTEMS", counted from what the menu shows.
func _coverage_line() -> String:
	var systems: Dictionary = {}
	for i in _order:
		var group: int = _group_of(_entry(i))
		if group < _systems.size():
			systems[group] = true
	var parts: PackedStringArray = []
	if catalogue.hero != null:
		parts.append("ONE WORLD")
	parts.append("%d PROTOTYPES" % _run_total())
	if not systems.is_empty():
		parts.append(("%d QUESTIONS" if _taxonomy == 1 else "%d SYSTEMS") % systems.size())
	return "  ·  ".join(parts)


## The hairline under the header, with a short accent stretch under the name (the research
## wall's header carries the same mark).
func _draw_header(header: Control, title: Control) -> void:
	var y: float = HEADER_HEIGHT - 1.0
	var x0: float = style.space(4)
	var ink: Color = Color(0.06, 0.11, 0.19, 0.25) if _light_ground() else Color(style.text, 0.10)
	header.draw_line(Vector2(x0, y), Vector2(header.size.x - x0, y), ink, 1.0)
	header.draw_line(Vector2(x0, y), Vector2(x0 + style.scaled(88), y), style.accent.lightened(0.2), 2.0)


## The original's banner (until 8 Oct): QUANTUM HORIZON over a big EXPLORE FREELY, the Frontier
## Map's bar, without its tabs.
func _build_original_banner() -> Control:
	var host := Control.new()
	host.size = MenuBanner.REFERENCE
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner := MenuBanner.new()
	# On white the band is the page's own white with a hairline under it, not a grey bar.
	var band: Color = style.surface if _light_ground() else style.background.darkened(0.35)
	var rule: Color = Color(style.text, 0.10) if _light_ground() else style.surface_raised
	banner.setup(
		catalogue.header, catalogue.explore_tab,
		PackedStringArray(), -1, "",
		{"caps": style.label_font(), "caps_tight": style.label_font()},
		{
			"fill": band, "rule": rule,
			"text_bright": style.text, "text_faint": style.text_dim,
			"tab_active_fill": style.surface_raised, "tab_active_stroke": style.accent,
			"tab_idle_fill": style.surface, "tab_idle_stroke": style.surface_raised,
			"action_fill": style.accent, "action_stroke": style.accent,
			"action_hover": style.launch_fill_hover, "action_text": style.text,
		})
	host.add_child(banner)
	return host


## Stretches the header across the window and pushes this screen's content clear of it.
func _layout_banner() -> void:
	if _margin == null:
		return
	if _round3():
		_margin.add_theme_constant_override("margin_top", int(_c().header_height()))
		if _banner_host != null:
			_banner_host.queue_redraw()
		return
	# The original's banner sits in the 1920x1080 reference space, fitted the way the Frontier
	# Map fits its layout.
	if _original_like() and not _wash("slimhead") and _banner_host != null:
		var factor: float = MenuBanner.reference_scale(size)
		_banner_host.scale = Vector2(factor, factor)
		_banner_host.position = MenuBanner.reference_origin(size)
		var below: float = _banner_host.position.y + MenuBanner.HEIGHT * factor
		_margin.add_theme_constant_override("margin_top", int(below) + style.space(3))
		return
	if _banner_host != null:
		_banner_host.queue_redraw()
	_margin.add_theme_constant_override("margin_top", int(HEADER_HEIGHT) + style.space(2))


## Deliberately much larger than a row: it is the difference between "a menu of
## tech demos" and "a thing somebody sequenced for you", and if it reads as just
## another list item the whole argument collapses.
##
## It opens the WORLD - `catalogue.hero`, the chicken pen - where the prototypes' ideas
## come together, and the list beneath stays the way to jump to one of them. That answers
## the select-or-sequence question without a tour system, which was never built: the
## banner used to promise one and then show a COMING SOON notice, and still does when no
## hero is configured. Opened from a laptop inside the pen it reads BACK TO THE PEN and
## takes you home instead of starting a second copy.
func _build_hero(compact: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.set_meta(&"hud", design == DESIGN_HUD)
	panel.add_theme_stylebox_override("panel", _stylebox(style.accent))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_hero_input)
	_hero_panel = panel

	var margin := MarginContainer.new()
	_set_margins(margin, style.space(2.5), style.space(2))
	panel.add_child(margin)

	var heading: String = catalogue.tour_title
	var subtitle: String = catalogue.subtitle_text()
	var hero: MenuEntry = catalogue.hero
	if hero != null:
		if _laptop_trip() != null:
			heading = catalogue.hero_return_heading
			subtitle = catalogue.hero_return_subtitle
		else:
			heading = catalogue.hero_heading
			subtitle = hero.blurb
			if hero.duration != "":
				subtitle = "%s  ·  %s" % [hero.blurb, hero.duration]

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", style.space(0.25))
	margin.add_child(text)

	# The heading, and at the right of its line the four system marks: the world is where
	# every system the list below shows runs together. On the heading's line rather than
	# beside the whole text, so the subtitle keeps the banner's full width. Light on the
	# banner's blue, where two of the groups' own colours would vanish.
	# The blue wall hero wash: a wall panel's kicker over a bigger ExtraBold title.
	if _wash("bluehero"):
		_set_margins(margin, style.space(3), style.space(2.5))
		text.add_child(_label("01  /  THE WORLD", MenuStyle.MICRO, Color(ON_ACCENT, 0.72), true))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", style.space(2))
	text.add_child(top)
	var title := _label(heading, MenuStyle.DISPLAY if _wash("bluehero") else MenuStyle.TITLE, ON_ACCENT, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if design == DESIGN_HUD or _wash("heavy"):
		_heavy(title)
	if compact:
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(title)
	var marks := HBoxContainer.new()
	marks.add_theme_constant_override("separation", style.space(0.6))
	marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _original_like():
		for g in _systems.size():
			marks.add_child(_system_mark(g, Color(0.78, 0.85, 0.95), style.scaled(22)))

	var line := _label(subtitle, MenuStyle.BODY, Color(0.78, 0.85, 0.95), false)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(line)
	# Compact (the board's narrow column): the marks get a line of their own, under the words.
	if compact:
		text.add_child(marks)
	else:
		top.add_child(marks)
	return panel


## Marks the banner selected the way a row is marked: a lighter fill and the selection bar.
func _style_hero(chosen: bool) -> void:
	if _hero_panel == null:
		return
	if _round2():
		_hero_panel.add_theme_stylebox_override("panel", _b().hero_box(chosen))
		return
	if _round3():
		_hero_panel.add_theme_stylebox_override("panel", _c().hero_box(chosen))
		return
	var box: StyleBoxFlat
	if design == DESIGN_WALL:
		# On the wall the banner is a white veil over the blue, like the wall's own cards.
		box = _stylebox(Color(WALL_INK, 0.20 if chosen else 0.11))
	else:
		box = _stylebox(style.accent.lightened(0.12) if chosen else style.accent)
	if design == DESIGN_HUD:
		box.set_corner_radius_all(HUD_RADIUS + 4)
	if chosen and style.selection_bar > 0:
		box.border_color = ON_ACCENT
		box.border_width_left = style.selection_bar if design != DESIGN_HUD else 4
	_hero_panel.add_theme_stylebox_override("panel", box)


func _build_row(index: int, kind: RowKind = RowKind.CARD, last: bool = false, slim: bool = false) -> PanelContainer:
	var entry: MenuEntry = _entry(index)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_box(index, false, false))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_row_input.bind(index))
	panel.mouse_entered.connect(_on_row_hover.bind(index, true))
	panel.mouse_exited.connect(_on_row_hover.bind(index, false))

	var margin := MarginContainer.new()
	match kind:
		RowKind.CARD, RowKind.TILE:
			_set_margins(margin, style.space(1.25), style.space(0.9 if slim else 1.25))
		RowKind.GLASS:
			# Clear of the 4 px accent bar, the lab title card's padding.
			_set_margins(margin, style.space(2), style.space(1.1))
		_:
			_set_margins(margin, style.space(1), style.space(1))
	# On the route the track runs the row's full height, outside its padding, so the line
	# is unbroken from one row to the next.
	if kind == RowKind.ROUTE:
		var outer := HBoxContainer.new()
		outer.add_theme_constant_override("separation", style.space(0.5))
		panel.add_child(outer)
		var track := Control.new()
		track.custom_minimum_size.x = style.scaled(30)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.draw.connect(_draw_route_track.bind(track, index, last))
		outer.add_child(track)
		_tracks[index] = track
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_theme_constant_override("margin_left", 0)
		outer.add_child(margin)
	else:
		panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", style.space(1.75 if kind == RowKind.CARD else 1.25))
	margin.add_child(row)

	if kind == RowKind.GLASS:
		row.add_theme_constant_override("separation", style.space(1.25))

	if kind == RowKind.INDEX:
		var number := _label("%02d" % _run_number(index) if _group_of(entry) != GROUP_FILMS else "·",
			MenuStyle.SUBTITLE, _group_ink(_group_of(entry)), false)
		number.custom_minimum_size.x = style.scaled(34)
		number.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(number)

	if kind == RowKind.CARD or kind == RowKind.FLAT:
		# Rows stay STILL even when clips exist. Eight simultaneously playing
		# previews is a slot machine; only the selected one moves.
		var thumb := TextureRect.new()
		thumb.texture = entry.icon
		var thumb_width: float = style.scaled(style.thumbnail_width) * (0.62 if kind == RowKind.FLAT else (0.8 if slim else 1.0))
		thumb.custom_minimum_size = Vector2(thumb_width, thumb_width / style.preview_aspect)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Knocked back from pure white so the glyph sits below the title in the
		# hierarchy rather than competing with it.
		thumb.modulate = style.thumbnail_tint
		row.add_child(thumb)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", style.space(0.4))
	row.add_child(text)
	# Title, then maturity and duration on the same line.
	#
	# Both repeated from the detail pane on purpose: a presenter scanning the
	# list cannot otherwise see which entries are rough or how long each takes
	# without clicking every one of them.
	# The lab title card's kicker ("PART 2 OF 5 · GOAT"): here the place in the run, the
	# maturity and the length, in the system's colour, over an ExtraBold title.
	if kind == RowKind.GLASS:
		var group: int = _group_of(entry)
		var bits: PackedStringArray = []
		if group != GROUP_FILMS:
			bits.append("%02d / %02d" % [_run_number(index), _run_total()])
		if entry.maturity != "":
			bits.append(entry.maturity.to_upper())
		if entry.duration != "":
			bits.append(entry.duration.to_upper())
		var kicker := _label("  ·  ".join(bits), MenuStyle.MICRO, _group_color(group) if group < _systems.size() else HUD_ACCENT, true)
		text.add_child(kicker)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", style.space(1))
	text.add_child(title_row)
	# A cinematic's row says which number key plays it.
	var films: Array[int] = _cinematic_order()
	if _wash("kicker") and not films.has(index):
		var number := _label("%02d" % _run_number(index), MenuStyle.SUBTITLE, style.accent if _light_ground() else style.accent.lightened(0.35), false)
		title_row.add_child(number)
	if films.has(index):
		var key := _label(str(films.find(index) + 1), MenuStyle.SUBTITLE, style.accent.lightened(0.35), false)
		title_row.add_child(key)
	var title := _label(entry.title.to_upper(), MenuStyle.BODY if kind == RowKind.TILE else MenuStyle.SUBTITLE,
		_list_ink("title"), false)
	if kind == RowKind.TILE:
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kind == RowKind.GLASS or _wash("heavy"):
		_heavy(title)
	title_row.add_child(title)

	# On a tile the tags go on a line of their own, under the title.
	var tags: HBoxContainer = title_row
	if kind == RowKind.GLASS:
		tags = HBoxContainer.new()
	elif kind == RowKind.TILE:
		tags = HBoxContainer.new()
		tags.add_theme_constant_override("separation", style.space(1))
		text.add_child(tags)
	if entry.maturity != "":
		var tag := _label(entry.maturity.to_upper(), MenuStyle.MICRO, _list_ink("faint"), true)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tags.add_child(tag)

	if entry.duration != "":
		var length := _label(entry.duration, MenuStyle.MICRO, _list_ink("faint"), true)
		length.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tags.add_child(length)

	var blurb := _label(entry.blurb, MenuStyle.CAPTION, HUD_INK_SOFT if kind == RowKind.GLASS else _list_ink("dim"), false)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size.x = style.scaled(120 if kind == RowKind.TILE else 250)
	text.add_child(blurb)

	# Played / not played. Set ONLY by actually launching something and coming
	# back - never by selecting, which is what made these fill in unexplained.
	# (On the route the node says it instead.)
	if kind != RowKind.ROUTE:
		var dot := ColorRect.new()
		dot.name = "PlayedDot"
		var dot_size: float = style.scaled(9)
		dot.custom_minimum_size = Vector2(dot_size, dot_size)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = Color(WALL_INK, 0.25) if design == DESIGN_WALL else style.surface_raised
		if index < _played.size() and _played[index]:
			dot.color = style.positive
		row.add_child(dot)

	return panel


## How a row is drawn, unselected, hovered or selected, in the current design and palette.
## Cards (current, segmented, tabs, board) keep a fill; flat rows (panels, route, index) show
## one only when lit; on the wall the light is a white veil. Segmented cards round only their
## group's outer corners. The selection bar takes the row's system colour.
func _row_box(index: int, chosen: bool, hovered: bool) -> StyleBoxFlat:
	if _round2():
		return _b().row_box(index, chosen, hovered)
	if _round3():
		return _c().row_box(index, chosen, hovered)
	if design >= FIRST_WASH:
		return _wash_row_box(index, chosen, hovered)
	var group: int = _group_of(_entry(index))
	var bar: Color = _group_color(group) if group < _systems.size() else style.text_dim
	if _original_like():
		bar = style.accent
	var fill: Color
	if design == DESIGN_HUD:
		# The lab title card: glass with its accent bar always on; lit as the lab lights a
		# step box, a 16% accent fill and a 2 px accent edge.
		var card := _stylebox(Color(bar, 0.16) if chosen else (Color(0.08, 0.11, 0.17, 0.90) if hovered else HUD_GLASS))
		card.set_corner_radius_all(HUD_RADIUS)
		card.border_color = bar if chosen else HUD_EDGE
		card.set_border_width_all(2 if chosen else 1)
		card.border_width_left = 4
		if not chosen:
			# The bar keeps its colour while the edge stays a hairline.
			card.border_color = Color(bar, 0.9)
			card.set_border_width_all(0)
			card.border_width_left = 4
		card.content_margin_left = 0
		return card
	if design == DESIGN_WALL:
		fill = Color(WALL_INK, 0.16 if chosen else (0.08 if hovered else 0.0))
		bar = WALL_INK
	elif design == DESIGN_PANELS or design == DESIGN_ROUTE or design == DESIGN_INDEX:
		var lit: Color = GLASS_LIT if _lab() else style.surface_raised
		fill = lit if chosen else (Color(lit, lit.a * 0.5) if hovered else Color(0, 0, 0, 0))
	else:
		var base: Color = GLASS_CARD if _lab() else style.surface
		var lit: Color = GLASS_LIT if _lab() else style.surface_raised
		fill = lit if (chosen or hovered) else base
	var box := _stylebox(fill)
	if design == DESIGN_SEGMENTED and _segments.has(index):
		# The stack is one shape: big corners at its ends, small ones where its cards meet.
		var ends: Vector2i = _segments[index]
		var big: int = style.corner_radius + 4
		var small: int = 2
		box.corner_radius_top_left = big if ends.x == 1 else small
		box.corner_radius_top_right = big if ends.x == 1 else small
		box.corner_radius_bottom_left = big if ends.y == 1 else small
		box.corner_radius_bottom_right = big if ends.y == 1 else small
	if chosen and style.selection_bar > 0:
		box.border_color = bar
		box.border_width_left = style.selection_bar
	# The bar lies over the row's padding rather than pushing its contents along, so nothing
	# shifts when the selection moves (and the route's line stays straight).
	box.content_margin_left = 0
	return box


## A row in the fourth round: the original's card (or, in the hairlines wash, a flat row), the
## bars wash adding the lab title card's accent bar on every card, lit and edged when selected.
func _wash_row_box(index: int, chosen: bool, hovered: bool) -> StyleBoxFlat:
	var group: int = _group_of(_entry(index))
	var bar: Color = style.accent if group != GROUP_LAB else style.text_faint
	var box: StyleBoxFlat
	if _wash("hairlines"):
		box = _stylebox(style.surface_raised if chosen else (Color(style.surface_raised, style.surface_raised.a * 0.5) if hovered else Color(0, 0, 0, 0)))
	else:
		box = _stylebox(style.surface_raised if chosen or hovered else style.surface)
		if _light_ground():
			# White cards on a light ground need an edge.
			box.border_color = Color(style.text, 0.08)
			box.set_border_width_all(1)
	if _wash("bars"):
		box.border_color = bar if chosen else box.border_color
		if chosen:
			box.set_border_width_all(2)
		box.border_width_left = 4
		if not chosen:
			box.border_color = Color(bar, 0.85)
			box.border_width_top = 0
			box.border_width_right = 0
			box.border_width_bottom = 0
	elif chosen and style.selection_bar > 0:
		box.border_color = bar
		box.border_width_left = style.selection_bar
	box.content_margin_left = 0
	return box


## Route design: the head of a group's route, its mark sitting on the line, the line running on
## down to the first row.
func _draw_route_cap(cap: Control, group: int) -> void:
	var x: float = cap.size.x * 0.5
	var ink: Color = _group_color(group) if group < _systems.size() else style.text_faint
	cap.draw_line(Vector2(x, cap.size.y * 0.5 + style.scaled(12)), Vector2(x, cap.size.y), Color(ink, 0.6), maxf(1.5, style.scaled(2)), true)
	if group < _systems.size():
		_draw_system_mark(cap, group, ink)


## Route design: one row's stretch of the route and its node: filled once played, a ring round
## it while selected. The last row of a group ends the line at its node.
func _draw_route_track(track: Control, index: int, last: bool) -> void:
	var group: int = _group_of(_entry(index))
	var ink: Color = _group_color(group) if group < _systems.size() else style.text_faint
	var x: float = track.size.x * 0.5
	var y: float = track.size.y * 0.5
	var width: float = maxf(1.5, style.scaled(2))
	track.draw_line(Vector2(x, 0.0), Vector2(x, y if last else track.size.y), Color(ink, 0.6), width, true)
	var radius: float = style.scaled(5.5)
	var played: bool = index < _played.size() and _played[index]
	track.draw_circle(Vector2(x, y), radius, ink if played else style.background)
	track.draw_arc(Vector2(x, y), radius, 0.0, TAU, 24, ink, width, true)
	if index == _selected:
		track.draw_arc(Vector2(x, y), radius + style.scaled(4), 0.0, TAU, 32, Color(ink, 0.8), width, true)


## Right column, top to bottom: the hook, then what it is, then how to play it,
## then - at low visual weight - what it was for.
##
## The weighting is the design. A stakeholder reads the video, the title and the
## key caps and launches; an academic reader carries on into the cells. Same
## pane, no mode switch, and the cells cost the skimmer nothing because they are
## visually subordinate rather than merely shorter.
func _build_detail_column(sideways: bool = false, halves: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pane_box := _stylebox(style.surface)
	if _round2():
		pane_box = _b().pane_box()
	elif _round3():
		pane_box = _c().pane_box()
	elif design >= FIRST_WASH:
		# The washes keep the original's pane, with a hairline edge so white sits on white.
		pane_box.border_color = Color(style.text, 0.08)
		pane_box.set_border_width_all(1)
	if design == DESIGN_HUD:
		pane_box = _stylebox(HUD_GLASS)
		pane_box.set_corner_radius_all(HUD_RADIUS + 4)
		pane_box.border_color = HUD_EDGE
		pane_box.set_border_width_all(1)
	if design == DESIGN_WALL:
		# The lab's rule: blue for the walls that teach, a framed screen for everything shown.
		pane_box.border_color = Color(style.text, 0.55)
		pane_box.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", pane_box)

	var margin := MarginContainer.new()
	_set_margins(margin, style.space(3.25))
	panel.add_child(margin)

	var column := VBoxContainer.new()
	# Draggable in the style resource - this is the one number that sets how
	# much air sits between the blocks down this pane.
	column.add_theme_constant_override("separation", style.space(style.detail_paragraph_gap))
	# Sideways (the board design): the video and its caption on the left, the words on
	# the right. Otherwise one column, top to bottom.
	var media: VBoxContainer = column
	if sideways:
		var split := HBoxContainer.new()
		split.add_theme_constant_override("separation", style.space(4))
		margin.add_child(split)
		media = VBoxContainer.new()
		media.add_theme_constant_override("separation", style.space(1))
		split.add_child(media)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.add_child(column)
		if halves:
			# "A" on the route: the cut in the middle, the video as tall as the words beside it.
			media.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			media.size_flags_stretch_ratio = 1.0
			column.size_flags_stretch_ratio = 1.0
			column.custom_minimum_size.x = 0.0
	else:
		margin.add_child(column)

	var preview_width: float = style.scaled(576)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(preview_width, preview_width / style.preview_aspect)
	if halves:
		frame.custom_minimum_size = Vector2(0.0, 240.0)
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.clip_contents = true
	# The shader needs the pane's real pixel size, which is only known after the
	# container has laid out - and changes again whenever the window does.
	frame.resized.connect(_on_preview_resized.bind(frame))
	media.add_child(frame)

	_preview_frame = frame
	_preview_material = ShaderMaterial.new()
	_preview_material.shader = load(ROUNDED_SHADER) as Shader
	var corners := Vector4(
		style.preview_corner_top_left,
		style.preview_corner_top_right,
		style.preview_corner_bottom_right,
		style.preview_corner_bottom_left
	)
	# "A": the video frame takes the launch button's corners (Ramon, 8 Oct).
	if design == DESIGN_A:
		var r: float = float(style.corner_radius)
		corners = Vector4(r, r, r, r)
	_preview_material.set_shader_parameter("corner_radius", corners)
	_preview_material.set_shader_parameter("edge_softness", style.preview_edge_softness)

	var frame_bg := ColorRect.new()
	frame_bg.color = style.background
	frame_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The backing plate is rounded too, or square corners show through behind a
	# rounded video and the whole effect is lost.
	frame_bg.material = _preview_material
	frame.add_child(frame_bg)

	_preview_icon = TextureRect.new()
	_preview_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_icon.material = _preview_material
	frame.add_child(_preview_icon)

	_video_material = _preview_material.duplicate() as ShaderMaterial

	_preview_video = VideoStreamPlayer.new()
	# NOT full-rect. The video is sized and positioned by _layout_video() to
	# cover the frame at its own aspect; anchoring it to the frame is exactly
	# what squashed a 16:9 clip into a 4:1 pane.
	_preview_video.expand = true
	_preview_video.visible = false
	_preview_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# `loop` exists on newer builds; restarting on `finished` covers the ones
	# where it does not. A preview that plays once and sits on a black frame for
	# the rest of a demo is worse than no preview.
	if "loop" in _preview_video:
		_preview_video.set("loop", true)
	_preview_video.finished.connect(_on_preview_finished)
	_preview_video.material = _video_material
	frame.add_child(_preview_video)

	# Ramon, 8 Oct: no new videos for now; where an entry has none, say so in the frame.
	_preview_na = _label("VIDEO N/A", MenuStyle.SUBTITLE, style.text_faint, true)
	_preview_na.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_na.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_na.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_na.visible = false
	frame.add_child(_preview_na)

	_preview_caption = _label("", MenuStyle.MICRO, style.text_dim, true)
	media.add_child(_preview_caption)

	# The system it shows and where it sits in the run ("ORIENTATION · 01 / 07"), as a
	# kicker over the title: the Creation Lab's title card leads the same way ("PART 2 OF 5
	# · GOAT"). Their own tight stack, so the pane's paragraph gap does not split them.
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", style.space(0.6))
	column.add_child(head)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", style.space(1.5))

	_detail_system = HBoxContainer.new()
	_detail_system.add_theme_constant_override("separation", style.space(0.75))
	head.add_child(_detail_system)
	_detail_marks.clear()
	for g in _systems.size():
		var mark := _system_mark(g, _group_color(g), style.scaled(18))
		_detail_system.add_child(mark)
		_detail_marks.append(mark)
	_detail_system_label = _label("", MenuStyle.CAPTION, style.text_dim, true)
	_detail_system_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_system.add_child(_detail_system_label)
	head.add_child(title_row)

	_detail_title = _label("", MenuStyle.DISPLAY, style.text, false)
	if design == DESIGN_HUD or _round2() or _wash("heavy"):
		_heavy(_detail_title)
	elif _round3():
		_c().deck_title(_detail_title)
	if halves:
		_detail_title.add_theme_font_size_override("font_size", 36)
	title_row.add_child(_detail_title)

	# Maturity badge. People read badges even when they read nothing else, and
	# it pre-empts a greybox being taken for a broken build.
	_detail_badge = PanelContainer.new()
	_detail_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_box := _stylebox(style.surface_raised)
	if design == DESIGN_HUD or _wash("caps"):
		badge_box = _pill_box(Color(style.text, 0.06), Color(style.text, 0.22))
	_detail_badge.add_theme_stylebox_override("panel", badge_box)
	var badge_margin := MarginContainer.new()
	_set_margins(badge_margin, style.space(1), style.space(0.4))
	_detail_badge.add_child(badge_margin)
	_detail_badge_label = _label("", MenuStyle.MICRO, style.text_dim, true)
	badge_margin.add_child(_detail_badge_label)
	title_row.add_child(_detail_badge)

	_detail_duration = _label("", MenuStyle.MICRO, style.text_faint, true)
	_detail_duration.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_detail_duration)

	_detail_blurb = _label("", MenuStyle.SUBTITLE, style.text_dim, false)
	_detail_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_blurb)
	if halves:
		# Half the height it has elsewhere: the words a step smaller and closer together, so a
		# typical entry ends where the screen does (the long ones push the route up, never off).
		_detail_blurb.add_theme_font_size_override("font_size", style.scaled(18))
		column.add_theme_constant_override("separation", style.space(1.4))

	_controls_host = HBoxContainer.new()
	_controls_host.add_theme_constant_override("separation", style.space(1.5))
	column.add_child(_controls_host)

	_info_host = GridContainer.new()
	_info_host.columns = style.info_columns
	_info_host.add_theme_constant_override("h_separation", style.space(style.info_cell_h_gap))
	_info_host.add_theme_constant_override("v_separation", style.space(1.4 if halves else style.detail_paragraph_gap))
	column.add_child(_info_host)

	# Measurements sit BELOW the cells and outside the grid, full width.
	#
	# A finding is a claim and a benchmark is a number; giving them separate
	# places keeps each legible as what it is. Full width also means a long
	# figure list does not squeeze a cell into a two-word column.
	_benchmark_host = VBoxContainer.new()
	_benchmark_host.add_theme_constant_override("separation", style.space(style.info_cell_label_gap))
	_benchmark_host.visible = false
	column.add_child(_benchmark_host)

	_benchmark_label = _label("", style.info_label_step, style.benchmark_accent, true, style.info_label_nudge)
	_benchmark_host.add_child(_benchmark_label)

	_benchmark_value = _label("", style.info_body_step, style.text_dim, false, style.info_body_nudge)
	_benchmark_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_benchmark_host.add_child(_benchmark_value)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_detail_path = _label("", MenuStyle.MICRO, style.text_faint, false)
	column.add_child(_detail_path)
	_detail_path.visible = not halves

	# Styled rather than left on Godot's default theme, which on this ground sat
	# at almost exactly the panel colour - the most important control on screen
	# was the hardest to see.
	# A ROW, because an entry can carry more than one scene - Portal is a wall you
	# shoot and a chamber of linked openings. Filled per selection by
	# _build_launch_buttons(); an entry with one scene gets one full-width button
	# and looks exactly as it did before.
	_launch_row = HBoxContainer.new()
	_launch_row.add_theme_constant_override("separation", style.space(1))
	column.add_child(_launch_row)

	return panel


## One button per launch target, sharing the row's width equally.
func _build_launch_buttons(entry: MenuEntry) -> void:
	for child in _launch_row.get_children():
		_launch_row.remove_child(child)
		child.queue_free()
	_launch_targets = entry.launch_targets(catalogue.launch_label)
	# From a laptop, the world's own entry is a way home, never a second copy of it.
	if entry == catalogue.hero and _laptop_trip() != null:
		_launch_targets = [{"label": catalogue.hero_return_heading, "path": ""}]
	for i in _launch_targets.size():
		var button := _make_launch_button(str(_launch_targets[i]["label"]))
		# Bound by index rather than by path so the handler runs the same
		# guards - _running, _launching, editor - as every other launch route.
		button.pressed.connect(_on_launch_pressed.bind(i))
		_launch_row.add_child(button)


## Styled rather than left on Godot's default theme, which on this ground sat at
## almost exactly the panel colour - the most important control on screen was the
## hardest to see.
func _make_launch_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = style.space(6)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", style.label_font())
	button.add_theme_font_size_override("font_size", style.size_for(MenuStyle.BODY))
	# On the code blue of the second round's palettes the type is white in both.
	var ink: Color = ON_ACCENT if design >= FIRST_B else style.text
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	if design == DESIGN_HUD or _wash("caps"):
		# The lab's buttons are pills: the code blue, fully round.
		var blue := Color(0.13, 0.40, 0.86)
		button.add_theme_color_override("font_color", Color(1, 1, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		button.add_theme_stylebox_override("normal", _pill_box(blue, blue))
		button.add_theme_stylebox_override("hover", _pill_box(blue.lightened(0.1), blue.lightened(0.1)))
		button.add_theme_stylebox_override("pressed", _pill_box(blue.darkened(0.1), blue))
		button.add_theme_stylebox_override("focus", _pill_box(blue, Color(1, 1, 1)))
		return button
	button.add_theme_stylebox_override("normal", _stylebox(style.launch_fill))
	button.add_theme_stylebox_override("hover", _stylebox(style.launch_fill_hover))
	button.add_theme_stylebox_override("pressed", _stylebox(style.accent))
	button.add_theme_stylebox_override("focus", _stylebox(style.launch_fill_hover))
	return button


## Key caps, not a sentence. A cap is recognised in under a second and needs no
## reading; a sentence has to be parsed. Same visual language as the Phase Maze
## billboard, so the menu and the prototypes agree with each other.
func _build_controls(entry: MenuEntry) -> void:
	for child in _controls_host.get_children():
		child.queue_free()
	_controls_host.visible = style.show_control_keys
	if not style.show_control_keys:
		return

	for pair in entry.control_pairs():
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", style.space(0.75))

		var cap := PanelContainer.new()
		var cap_style := _stylebox(style.surface_raised)
		cap_style.border_color = style.text_faint
		cap_style.set_border_width_all(1)
		if design == DESIGN_HUD or _wash("caps"):
			cap_style = _keycap_box()
		cap.add_theme_stylebox_override("panel", cap_style)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var cap_margin := MarginContainer.new()
		_set_margins(cap_margin, style.space(0.9), style.space(0.35))
		cap.add_child(cap_margin)
		cap_margin.add_child(_label(str(pair["key"]), MenuStyle.CAPTION, style.text, true))
		group.add_child(cap)

		var action := _label(str(pair["action"]), MenuStyle.CAPTION, style.text_dim, false)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		group.add_child(action)

		_controls_host.add_child(group)


## The fixed three-question schema. Identical labels for every prototype, which
## is what makes eight of them comparable rather than eight unrelated blurbs.
func _build_info(entry: MenuEntry) -> void:
	for child in _info_host.get_children():
		child.queue_free()
	_info_host.columns = style.info_columns
	_info_host.visible = style.show_info_cells and entry.has_info()
	if not _info_host.visible:
		return

	_add_info_cell(catalogue.question_label, entry.question)
	_add_info_cell(catalogue.approach_label, entry.approach)
	_add_info_cell(catalogue.finding_label, entry.finding, entry.finding_tier)


## `tier` is printed small under the body - the finding's evidence tier, so the menu never
## claims more certainty than the stakeholder deck does for the same sentence.
func _add_info_cell(label_text: String, body_text: String, tier: String = "") -> void:
	if body_text == "":
		return
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", style.space(style.info_cell_label_gap))

	var label_ink: Color = style.accent if design >= FIRST_B and _light else style.accent.lightened(0.35)
	cell.add_child(_label(label_text, style.info_label_step, label_ink, true, style.info_label_nudge))

	var body := _label(body_text, style.info_body_step, style.text_dim, false, style.info_body_nudge)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = style.scaled(150)
	cell.add_child(body)

	if tier != "":
		# Capitals like every other label here, except the sample size, which the deck
		# writes as a lowercase n.
		var tag := _label(tier.to_upper().replace("N = ", "n = "), MenuStyle.MICRO, style.text_faint, true)
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(tag)

	_info_host.add_child(cell)


# --------------------------------------------------------------------------
# Selection
# --------------------------------------------------------------------------

func _select(index: int) -> void:
	if index == HERO and catalogue.hero != null:
		_selected = HERO
	else:
		_selected = clampi(index, 0, _entries().size() - 1)
		# Kept in step so the inspector dropdown always names what is on screen,
		# including when selection moves from a click or from auto-advance. (The
		# banner has no place in that dropdown, so selecting it leaves it alone.)
		_preview_entry = _selected
	var entry: MenuEntry = _selected_entry()
	if entry == null:
		return

	_style_hero(_selected == HERO)
	for i in _rows.size():
		if _rows[i] == null:
			continue
		# The bar takes the row's system colour, so the selection says which group it is in.
		_rows[i].add_theme_stylebox_override("panel", _row_box(i, i == _selected, false))
	for track in _tracks.values():
		(track as Control).queue_redraw()
	# The tabs design follows the selection to its system's tab.
	if design == DESIGN_TABS and _selected != HERO and not _tab_panels.is_empty():
		var group: int = _group_of(entry)
		if group != _tab_group and _tab_panels.has(group):
			_open_tab(group, false)
	if _round2() and _selected != HERO:
		_b().follow_selection(_group_of(entry))
	# Keep the selected row in sight when the arrow keys walk past the list's edge.
	if _selected != HERO and _selected < _rows.size() and _rows[_selected] != null \
			and is_instance_valid(_list_scroll) and _list_scroll.is_ancestor_of(_rows[_selected]):
		_list_scroll.ensure_control_visible.call_deferred(_rows[_selected])

	_load_preview(entry)
	_apply_entry_text(entry)
	_pull_focus_from_entry()
	_detail_path.text = entry.scene_path if entry.scene_path != "" else "no scene wired yet"


## Everything the detail pane says about an entry, in one place, so selecting and
## live-editing cannot drift apart.
func _apply_entry_text(entry: MenuEntry) -> void:
	_detail_title.text = entry.title.to_upper()
	_detail_badge_label.text = entry.maturity.to_upper()
	_detail_duration.text = entry.duration
	_detail_duration.visible = entry.duration != ""
	# Falls back to the blurb, but prefers the longer line when there is one -
	# the row already carries the blurb, and repeating it verbatim wastes the
	# most valuable line in the pane.
	_detail_blurb.text = entry.detail if entry.detail != "" else entry.blurb
	_apply_entry_system(entry)
	_build_controls(entry)
	_build_info(entry)
	_build_benchmark(entry)
	_build_launch_buttons(entry)


## The system row under the title: the entry's own group, in its colour; for the world, all
## four marks and `hero_systems_line`; nothing for an entry with no system or a cinematic.
func _apply_entry_system(entry: MenuEntry) -> void:
	if _detail_system == null:
		return
	var group: int = _group_of(entry)
	var world: bool = entry == catalogue.hero
	_detail_system.visible = not _original_like() or _wash("kicker")
	# The kicker wash: the lab title card's "PART 04 OF 07" over the title, in the accent.
	if _original_like():
		for g in _detail_marks.size():
			_detail_marks[g].visible = false
		var index_k: int = _entries().find(entry)
		var where: String = "THE WORLD" if world else ("CINEMATIC" if group == GROUP_FILMS else ("THE LAB" if group == GROUP_LAB else "TOUR"))
		_detail_system_label.text = where if world or group == GROUP_FILMS else "%s  ·  PART %02d OF %02d" % [where, _run_number(index_k), _run_total()]
		_detail_system_label.add_theme_color_override("font_color", style.accent if _light_ground() else style.accent.lightened(0.35))
		return
	for g in _detail_marks.size():
		_detail_marks[g].visible = world or g == group
	if world:
		_detail_system_label.text = catalogue.hero_systems_line
		_detail_system_label.add_theme_color_override("font_color", style.text_dim)
	elif group < _systems.size():
		# "ORIENTATION  ·  01 / 07": the system, and where this sits in the run.
		var index: int = _entries().find(entry)
		_detail_system_label.text = "%s  ·  %02d / %02d" % [_systems[group]["label"], _run_number(index), _run_total()]
		_detail_system_label.add_theme_color_override("font_color", _group_color(group))
	else:
		_detail_system_label.text = _group_label(group) if group != GROUP_FILMS else catalogue.cinematics_heading
		_detail_system_label.add_theme_color_override("font_color", style.text_dim)


func _build_benchmark(entry: MenuEntry) -> void:
	var has_numbers: bool = style.show_info_cells and entry.benchmark != ""
	_benchmark_host.visible = has_numbers
	if not has_numbers:
		return
	_benchmark_label.text = catalogue.benchmark_label
	_benchmark_value.text = entry.benchmark


func _load_preview(entry: MenuEntry) -> void:
	_preview_atlas = null
	_loop_time = 0.0

	_preview_video.stop()
	_preview_video.visible = false
	_preview_icon.visible = true
	_preview_na.visible = false

	var video_path: String = "%s%s.ogv" % [CLIP_DIR, entry.clip]
	var stream: VideoStream = _load_video(video_path)
	if stream != null:
		_preview_video.stream = stream
		_preview_video.visible = true
		_preview_icon.visible = false
		_preview_video.play()
		# Re-laid out per entry, because each one can carry its own crop.
		_layout_video()
		_preview_caption.text = "RECORDED PLAYTHROUGH  ·  LOOPING"
		return

	var sheet: Texture2D = _load_loose_texture("%s%s_loop.png" % [CLIP_DIR, entry.clip])
	if sheet != null:
		_preview_atlas = AtlasTexture.new()
		_preview_atlas.atlas = sheet
		_preview_atlas.region = Rect2(Vector2.ZERO, Vector2(LOOP_FRAME_SIZE))
		_preview_icon.texture = _preview_atlas
		_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_preview_caption.text = "%d-FRAME SLICE LOOP" % LOOP_FRAMES
		return

	# No recording: the frame says so, in place of the icon (Ramon, 8 Oct: "if there is
	# none, say, video N/A in that space"). The row keeps the icon.
	_preview_icon.visible = false
	_preview_na.visible = true
	_preview_caption.text = ""


## Pushes the pane's actual pixel size to the shader. Without this the SDF would
## have to work in UV space, which makes the corners elliptical on any pane that
## is not square - and this one is 16:9.
func _on_preview_resized(frame: Control) -> void:
	if _preview_material != null:
		_preview_material.set_shader_parameter("rect_size", frame.size)
		_preview_material.set_shader_parameter("node_size", frame.size)
		_preview_material.set_shader_parameter("node_offset", Vector2.ZERO)
	_layout_video()


## Sizes and places the video to COVER the frame at its recorded aspect, then
## slides it vertically to the chosen crop.
##
## Cover, not fit: the pane is as wide as the detail column makes it (often
## nearly 4:1) while a clip is 16:9, so fitting would letterbox and stretching
## would squash. Scaling to the frame's WIDTH and letting the extra height spill
## past the clip boundary keeps every pixel the right shape.
##
## `focus` picks which horizontal band survives - 0 the top of the recorded
## frame, 1 the bottom. That is the whole point of exposing it per entry: the
## interesting part of a shot sits somewhere different in every prototype.
func _layout_video() -> void:
	if _preview_video == null or _preview_frame == null or style == null:
		return
	var frame_size: Vector2 = _preview_frame.size
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return

	var aspect: float = maxf(0.1, style.clip_aspect)
	var size := Vector2(frame_size.x, frame_size.x / aspect)
	if size.y < frame_size.y:
		# Frame is taller than the clip's aspect - cover by height instead.
		size = Vector2(frame_size.y * aspect, frame_size.y)

	var focus: float = style.preview_focus_default
	var entry: MenuEntry = _selected_entry()
	if entry != null and entry.preview_focus >= 0.0:
		focus = entry.preview_focus

	var overflow: Vector2 = size - frame_size
	var offset := Vector2(-overflow.x * 0.5, -overflow.y * clampf(focus, 0.0, 1.0))

	_preview_video.size = size
	_preview_video.position = offset

	if _video_material != null:
		_video_material.set_shader_parameter("rect_size", frame_size)
		_video_material.set_shader_parameter("node_size", size)
		_video_material.set_shader_parameter("node_offset", offset)


func _on_preview_finished() -> void:
	if _preview_video != null and _preview_video.visible:
		_preview_video.play()


## Loads an .ogv whether or not the editor has imported it. A file the project's
## own tools just wrote is not yet a resource as far as ResourceLoader is
## concerned; pointing VideoStreamTheora at the path sidesteps the import step,
## which is also what makes "drop your own .ogv in and it plays" true.
func _load_video(path: String) -> VideoStream:
	if not FileAccess.file_exists(path):
		return null
	if ResourceLoader.exists(path):
		var imported: VideoStream = load(path) as VideoStream
		if imported != null:
			return imported
	var stream := VideoStreamTheora.new()
	stream.file = path
	return stream


## Same problem, same fix, for the sprite-sheet fallback.
func _load_loose_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D
		if imported != null:
			return imported
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _on_row_hover(index: int, entered: bool) -> void:
	if index == _selected or _running != null or _rows[index] == null:
		return
	_rows[index].add_theme_stylebox_override("panel", _row_box(index, false, entered))


func _on_row_input(event: InputEvent, index: int) -> void:
	if _running != null or _launching:
		return
	if Engine.is_editor_hint():
		# Selecting still works in the editor - it is how you preview another
		# entry's pane - but launching a prototype does not.
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select(index)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index == _selected:
			_on_launch_pressed()
		else:
			_select(index)


## The banner behaves like a row - click to show it in the pane, again to go - so the
## world can be read about before committing ten minutes to it. Two exceptions: with no
## hero configured it shows the old COMING SOON notice, and from a laptop it takes you
## home on the first click, because going back needs no description.
func _on_hero_input(event: InputEvent) -> void:
	if _running != null or _launching:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if Engine.is_editor_hint():
		if catalogue.hero != null:
			_select(HERO)
		return
	if catalogue.hero == null:
		_show_notice()
		return
	if _selected == HERO or _laptop_trip() != null:
		_select(HERO)
		_on_launch_pressed()
	else:
		_select(HERO)


## _input rather than _unhandled_input, so the return keys reach the menu even
## while a prototype that consumes input is running on top of it.
func _input(event: InputEvent) -> void:
	# @tool means this also runs while authoring, where launching a prototype or
	# swallowing Esc would fight the editor.
	if Engine.is_editor_hint():
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	# The notice takes precedence over everything: while it is up, Esc dismisses
	# it rather than doing whatever Esc would otherwise do.
	if _notice != null and _notice.visible:
		if key.keycode == RETURN_KEY:
			get_viewport().set_input_as_handled()
			_hide_notice()
		return

	# Swallow everything mid-launch. Half a launch is not a state anything else
	# here is written to handle, and pressing keys at a screen that looks stuck
	# is exactly what people do.
	if _launching:
		return

	if _running != null:
		if key.keycode == RETURN_KEY or key.keycode == PROTOTYPE_RETURN_KEY:
			get_viewport().set_input_as_handled()
			_close_running()
		return

	# Design review: Tab shows the design HUD; while it shows, the number keys pick the design
	# and B the palette.
	if design_review and key.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_hud_open = not _hud_open
		get_tree().root.set_meta(&"menu_design_hud", _hud_open)
		if is_instance_valid(_design_hud):
			_design_hud.visible = _hud_open
		return
	if design_review and _hud_open:
		if key.keycode >= KEY_0 and key.keycode <= KEY_9:
			get_viewport().set_input_as_handled()
			_set_design(int(key.keycode - KEY_0))
			return
		if key.keycode == KEY_B:
			get_viewport().set_input_as_handled()
			_toggle_bright()
			return
		if key.keycode == KEY_G:
			get_viewport().set_input_as_handled()
			_toggle_taxonomy()
			return

	# The number keys play the cinematics, in the order they are listed.
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var films: Array[int] = _cinematic_order()
		var n: int = int(key.keycode - KEY_1)
		if n < films.size():
			get_viewport().set_input_as_handled()
			_select(films[n])
			_on_launch_pressed()
		return

	match key.keycode:
		KEY_DOWN:
			_step_selection(1)
		KEY_UP:
			_step_selection(-1)
		KEY_ENTER, KEY_KP_ENTER:
			_on_launch_pressed()


## Up and down walk the rows in SCREEN order - the banner, then the system groups, then the
## cinematics - not in catalogue order, which the groups no longer match.
func _step_selection(delta: int) -> void:
	var position_now: int = -1 if _selected == HERO else _order.find(_selected)
	var next: int = position_now + delta
	if next < 0:
		if catalogue.hero != null:
			_select(HERO)
		return
	if next >= _order.size():
		return
	_select(_order[next])


# --------------------------------------------------------------------------
# Launching
# --------------------------------------------------------------------------

## Runs the prototype as a CHILD of the tree root instead of changing scene.
##
## change_scene_to_file only frees the CURRENT scene - this menu - so a
## prototype added at the root survives it, which is exactly the bug that left an
## orphaned return prompt floating over a freshly reloaded menu. Keeping the menu
## alive underneath means Esc/H can free the prototype and restore it, played
## dots and all.
##
## Known cost: get_tree().current_scene stays the MENU, so a prototype that
## identifies itself by current_scene.scene_file_path - MiegakureLook's level
## base does - will not know which level it is and will not auto-advance.
func _launch(index: int, target: int = 0) -> void:
	var entry: MenuEntry = _entry(index)
	if entry == null:
		return
	if entry.section == "Cinematic" and entry.cinematic == "":
		_detail_path.text = "a placeholder - this cinematic is not made yet"
		return
	# A cinematic, opened from a laptop inside the pen: play it in that pen rather than a
	# second copy, and give the pen back afterwards (pen_cinematics_4d.gd reads both metas).
	if entry.cinematic != "":
		var trip: Node = _laptop_trip()
		get_tree().root.set_meta(&"pen_cinematic", entry.cinematic)
		get_tree().root.set_meta(&"pen_cinematic_return", "pen" if trip != null else "menu")
		if trip != null:
			trip.call("come_back")
			return
	var targets: Array[Dictionary] = entry.launch_targets(catalogue.launch_label)
	if targets.is_empty():
		_detail_path.text = "no scene wired yet - nothing to launch"
		return
	var chosen: Dictionary = targets[clampi(target, 0, targets.size() - 1)]
	var path: String = str(chosen["path"])
	if not ResourceLoader.exists(path):
		push_error("menu_final: scene missing - %s" % path)
		_detail_path.text = "MISSING: %s" % path
		return

	_launching = true
	# See ensure_root_world_3d(): the scene about to arrive may use the Combined engine.
	ensure_root_world_3d(get_tree())
	_preview_video.stop()
	# The overlay names the SCENE when an entry has more than one, because
	# "PORTAL" over a loading bar does not say which of the two is coming.
	var heading: String = entry.title
	if targets.size() > 1:
		heading = "%s · %s" % [entry.title, str(chosen["label"])]
	_show_overlay(entry, heading)

	# TWO frames, not one. Making the overlay visible only queues a redraw; the
	# first frame after this is when it actually reaches the screen. Blocking on
	# the load before that gives the frozen click this whole thing exists to
	# remove - the overlay would appear only after the wait it was meant to
	# cover.
	await get_tree().process_frame
	await get_tree().process_frame

	# Threaded, so the bar shows REAL progress instead of a made-up animation.
	# Only the resource load is measurable this way; see below.
	ResourceLoader.load_threaded_request(path)
	while true:
		var progress: Array = []
		var status: int = ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("menu_final: could not load %s" % path)
			_hide_overlay()
			_launching = false
			return
		if progress.size() > 0:
			_overlay_bar.value = float(progress[0])
		await get_tree().process_frame

	_overlay_bar.value = 1.0
	# The honest part. instantiate() runs the prototype's _ready on the main
	# thread - Portal builds 21 chunks in ~1,093 ms there, Voxel Mining ~512 ms -
	# and that cannot be measured or interrupted, so the bar stops and the label
	# says what is happening instead of inventing a percentage.
	_overlay_stage.text = "BUILDING THE SCENE"
	await get_tree().process_frame

	var packed: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		push_error("menu_final: could not load %s" % path)
		_hide_overlay()
		_launching = false
		return

	# A place rather than a test (the chicken pen): it REPLACES the menu instead of
	# running on top of it, so it is the current scene its own code expects, and it owns
	# Esc and H. The window's scaling goes back to the project's first, or the pen's HUD
	# is laid out on this menu's 1920x1080 canvas. The overlay stays up until the menu is
	# freed at the end of the frame, so there is no flash of the list in between.
	if entry.opens_as_scene:
		_restore_project_scaling()
		get_tree().change_scene_to_packed(packed)
		return

	_running = packed.instantiate()
	_claim_return_button(_running)
	get_tree().root.add_child(_running)

	# THE ESC FIX. player.gd handles `ui_cancel` itself and calls
	# change_scene_to_file("res://menu/main_menu.tscn") - the OLD menu - so
	# pressing Esc in Phase Maze landed on Trym's menu with this one orphaned
	# underneath. Reported exactly that way.
	#
	# Godot delivers _input to nodes in REVERSE tree order, so whichever sibling
	# sits last is asked first. Moving the prototype to index 0 makes this menu
	# last, so it sees Esc first and can consume it with set_input_as_handled()
	# before the player ever hears about it.
	#
	# Done here rather than by editing player.gd, which is shared with the main
	# project and everyone else's scenes.
	get_tree().root.move_child(_running, 0)

	_shell.visible = false
	_hide_overlay()
	_launching = false
	_mark_played(index)


func _show_overlay(entry: MenuEntry, heading: String = "") -> void:
	if _overlay == null:
		return
	_overlay_title.text = (heading if heading != "" else entry.title).to_upper()
	_overlay_stage.text = "LOADING"
	_overlay_bar.value = 0.0
	var keys: Array[String] = []
	for pair in entry.control_pairs():
		keys.append("%s  %s" % [str(pair["key"]), str(pair["action"])])
	_overlay_hint.text = "   ·   ".join(keys)
	_overlay.visible = true


func _hide_overlay() -> void:
	if _overlay != null:
		_overlay.visible = false


## Takes over the prototype's H key without hiding its prompt.
##
## The prompt stays VISIBLE - it is the only thing telling the player which key
## gets them out. Only its input handling is switched off, so the menu answers H
## itself with the same lossless unwind Esc uses: no scene change, no orphan.
func _claim_return_button(node: Node) -> void:
	for child in node.get_children():
		if "hub_scene_path" in child:
			child.set_process_unhandled_input(false)
			child.set_process_input(false)
		_claim_return_button(child)


func _close_running() -> void:
	if _running == null:
		return
	# Freed deferred for the same reason gate triggers and level hand-offs are:
	# tearing a scene down from inside input dispatch pulls the ground out from
	# under the event still being delivered.
	_running.queue_free()
	_running = null
	_shell.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Auto-advance: the guided tour at a fraction of its cost.
	#
	# Coming back lands on the next thing you have not seen, so the running order
	# actually does something today without taking the choice away - the list is
	# still right there and nothing launches on its own. Wraps around, and stops
	# moving once everything is played, so the last return leaves you where you
	# were rather than bouncing to the top.
	var next: int = _next_unplayed(_selected)
	if next >= 0:
		_select(next)
	else:
		_load_preview(_selected_entry())


## The next unplayed prototype after `from`, in screen order, wrapping. -1 when every one is
## played. Since 8 Oct that runs through all four system groups in order (read, move, the
## world, life); the cinematics are left out, being films rather than prototypes. Until
## then the lab was left out instead.
func _next_unplayed(from: int) -> int:
	var tour: Array[int] = []
	for i in _order:
		if _group_of(_entry(i)) != GROUP_FILMS:
			tour.append(i)
	if tour.is_empty():
		return -1
	# From the banner or a cinematic, find() gives -1, which starts the search at the top.
	var start: int = tour.find(from)
	for step in range(1, tour.size() + 1):
		var candidate: int = tour[(start + step) % tour.size()]
		if candidate < _played.size() and not _played[candidate]:
			return candidate
	return -1


func _mark_played(index: int) -> void:
	if index < 0 or index >= _played.size():
		return
	_played[index] = true
	if _rows[index] == null:
		return
	var dot := _rows[index].find_child("PlayedDot", true, false) as ColorRect
	if dot != null:
		dot.color = style.positive
	if _tracks.has(index):
		(_tracks[index] as Control).queue_redraw()


func _on_launch_pressed(target: int = 0) -> void:
	# `_launching` matters as much as `_running`: the load is asynchronous now,
	# so there is a window where nothing is running yet and a second click would
	# start a parallel launch. Clicking again during a wait is exactly what
	# people do when a screen looks stuck.
	if _running != null or _launching or Engine.is_editor_hint():
		return
	# From a laptop the banner - and its entry's launch button - is the way home.
	if _selected == HERO:
		var trip: Node = _laptop_trip()
		if trip != null:
			trip.call("come_back")
			return
	_launch(_selected, target)


# --------------------------------------------------------------------------
# Helpers - every one of these reads the style resource, never a literal.
# --------------------------------------------------------------------------

## `nudge` is a pixel offset applied after the modular scale has decided the
## size. The scale moves in ~28% steps, which is far coarser than "one point
## bigger" ever means, so a couple of places need the fine adjustment.
func _label(text: String, step: int, color: Color, tracked: bool, nudge: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", style.label_font() if tracked else style.font)
	label.add_theme_font_size_override("font_size", maxi(6, style.size_for(step) + nudge))
	label.add_theme_color_override("font_color", color)
	return label


func _stylebox(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_radius_top_left = style.corner_radius
	box.corner_radius_top_right = style.corner_radius
	box.corner_radius_bottom_left = style.corner_radius
	box.corner_radius_bottom_right = style.corner_radius
	return box


func _set_margins(node: MarginContainer, horizontal: int, vertical: int = -1) -> void:
	var top_bottom: int = horizontal if vertical < 0 else vertical
	node.add_theme_constant_override("margin_left", horizontal)
	node.add_theme_constant_override("margin_right", horizontal)
	node.add_theme_constant_override("margin_top", top_bottom)
	node.add_theme_constant_override("margin_bottom", top_bottom)
