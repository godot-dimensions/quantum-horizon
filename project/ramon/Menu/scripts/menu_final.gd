@tool
extends Control
## Scrolling banner menu, final. Scene: `res://ramon/menu_final.tscn`. THE PROJECT'S MENU.
##
## THE MASTER SINCE 9 OCT 2026: one design, "A", drawn by `menu_a.gd`. Ramon: "install final A
## as the main menu lander ... keep the menu final as the new main master and remove the tab
## variations". The 8 Oct design review it came from (41 designs behind Tab, two palettes, two
## groupings) is frozen as `res://ramon/menu_variations.tscn` for reference; nothing here
## depends on it. Change the menu here and in menu_a.gd, never there. Handover:
## `ramon/follow_up/menu.md`.
##
## The split: menu_a.gd is the look (header and footer, the list, the route, the world's card,
## how a row lights up); this file is the working parts (the catalogue, selection, keys, the
## details pane, previews, launching and the way home, the window).
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
## NOTHING VISUAL IS HARDCODED IN THIS FILE ANY MORE. (Since 9 Oct A's own measures, taken from
## the Octobergate deck, live in menu_a.gd and its two palettes here; the style resource still
## sets the type scale, the spacing and the details pane.)
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

## The groups the menu is listed in: since 9 Oct its two FAMILIES (Ramon's brief, "make the
## prototype collection feel like two coherent families"), named in the catalogue
## (`family_names`, `family_lines`) and chosen per entry by MenuEntry.family: the labs
## (EXPLORE THE SYSTEMS, interactive R&D exhibitions) and the playable experiments (EXPERIENCE
## 4D). Until then: the Frontier Map's four systems (MenuEntry.category, still in the catalogue
## as metadata). Group indices: 0 and 1 the families, then these.
const GROUP_OTHER: int = 4
const GROUP_FILMS: int = 5

# --------------------------------------------------------------------------
# The look
# --------------------------------------------------------------------------

## Everything the menu draws is built in menu_a.gd ("A", Ramon's pick from the 8 Oct design
## review, the menu since 9 Oct). The 41 designs it was picked from, the Tab panel that switched
## them, and their palettes are frozen in `res://ramon/menu_variations.tscn`.
const MenuA := preload("res://ramon/Menu/scripts/menu_a.gd")
## The loading screen, in the Voxel Lab board's style (menu_load_board.gd).
const MenuLoadBoard := preload("res://ramon/Menu/scripts/menu_load_board.gd")

## The two palettes (the light / dark square at the foot): the Octobergate deck's own system
## recoloured white and blue as Ramon asked, and its dark divider slides as near black and light
## blue. Never mixed.
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
const DECK_FONT: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Regular.ttf"
## Type on the code blue, in either palette.
const ON_ACCENT: Color = Color(0.97, 0.98, 1.0)

## The palette: white (true) or near black, kept for the session.
var _light: bool = true
## The view: the list (false) or the route, kept for the session.
var _route_view: bool = false
var _look: RefCounted = null
## The route's ring for each prototype, by entry index, redrawn as rows are played.
var _tracks: Dictionary = {}
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
## Indexed by ENTRY index, not by screen position - the entries are drawn by system group,
## so the two orders differ. `_order` is the screen order, top to bottom.
var _rows: Array[PanelContainer] = []
var _order: Array[int] = []
## Per family, in the catalogue's order: {"label": String, "color": Color}. See _load_systems().
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
## "VIDEO COMING TODAY" over a screenshot, while an entry has a still and no video yet.
var _preview_soon: Control = null
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
## The menu, set aside while a prototype is the current scene (see _launch).
var _menu_scene: Node = null

## The loading screen (menu_load_board.gd), on its own CanvasLayer; hidden until a launch.
var _overlay: Control = null
var _launching: bool = false
var _notice: Control = null
## The Frontier Map's interface sounds (MenuAudio), the same four cues for the same four meanings:
## click when you pick something, select when something opens or a mode switches, error when it
## cannot open, swipe when a layer goes away. Only the cues: the map's music bed stays off here,
## because it would go on playing under a running prototype.
var _audio: MenuAudio = null

## The greys Ramon tunes behind Tab (10 Oct: "a secret hud ... where i can change the logo grey and
## save in settings"), each the ink's strength 0..1: higher is darker on white, lighter on dark.
## Kept in their own settings file rather than the style resource, which carries the run-time
## palette and would save that too. Read in the editor as well, so the scene preview agrees.
const TUNING_PATH := "res://ramon/Menu/style/menu_tuning.cfg"
const TUNING_DEFAULTS := {"list_logos": 0.28, "route_logos": 0.7, "route_rings": 0.3, "music": 0.667}
## Which section of the .cfg each tuning key is saved in.
const TUNING_SECTIONS := {"list_logos": "greys", "route_logos": "greys", "route_rings": "greys", "music": "sound"}
## The music slider's range: 0 is MUSIC_DB_LOW, 1 is MUSIC_DB_HIGH; the default (0.667) is the
## Frontier Map's -26 dB, which measures about -40 LUFS in the menu, some 10 dB under the select cue.
const MUSIC_DB_LOW := -46.0
const MUSIC_DB_HIGH := -16.0
const MenuTuningHud := preload("res://ramon/Menu/scripts/menu_tuning_hud.gd")
## The one Esc question and the way back to the world, at the root (menu_way_home.gd says why).
const MenuWayHome := preload("res://ramon/Menu/scripts/menu_way_home.gd")
var tuning: Dictionary = TUNING_DEFAULTS.duplicate()
var _tuning_hud: CanvasLayer = null


func _ready() -> void:
	# THIS NODE MUST NOT EAT THE MOUSE. It is a full-screen Control and the default filter is
	# STOP, so while a prototype runs - this menu stays alive underneath it, by design - every
	# mouse motion was consumed here and never reached the prototype's _unhandled_input. The
	# symptom was that looking around did nothing in the Aquatic Lab when it was started from
	# the menu, while working perfectly when the scene was opened on its own.
	#
	# IGNORE on this node only: its children keep their own filters and are tested before it,
	# so the menu's own buttons and panels are unaffected. It handles no GUI events itself.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		# Gameplay scenes capture the mouse and nothing else gives it back, so a
		# menu that does not do this is unusable after returning from a prototype.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_apply_window_mode()
		# Light or dark, and list or route, stay as chosen for the session, through a trip to a
		# prototype or the pen and back. The style is copied so the palette never writes into
		# the resource on disk.
		var root: Window = get_tree().root
		_light = bool(root.get_meta(&"menu_light", true))
		_route_view = bool(root.get_meta(&"menu_route_view", false))
		if style != null:
			style = style.duplicate()
		_apply_palette()
		# On the menu node itself, not the rebuilt shell, as the map does: it lives as long as the menu.
		_audio = MenuAudio.new()
		add_child(_audio)
		# The map's music bed plays on the menu again (Ramon, 10 Oct: "bring that back"); it fades
		# out under a prototype and picks up on the way back (_music). Its level is the Tab panel's.
		_apply_music_level.call_deferred()
		MenuWayHome.ensure(get_tree())
	load_tuning()
	_connect_resource(style)
	_connect_resource(catalogue)
	rebuild()


## Reads the tuned greys from TUNING_PATH; a missing file or key keeps the default.
func load_tuning() -> void:
	tuning = TUNING_DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(TUNING_PATH) != OK:
		return
	for key in tuning:
		tuning[key] = clampf(float(cfg.get_value(String(TUNING_SECTIONS.get(key, "greys")), key, tuning[key])), 0.0, 1.0)


## Writes the greys to TUNING_PATH (the project's file, so they become everyone's menu).
func save_tuning() -> Error:
	var cfg := ConfigFile.new()
	for key in tuning:
		cfg.set_value(String(TUNING_SECTIONS.get(key, "greys")), key, snappedf(float(tuning[key]), 0.001))
	return cfg.save(TUNING_PATH)


## One grey changed live: repaints the logos and rings in place, no rebuild (a rebuild would
## restart the preview video on every step of a drag).
func set_tuning(key: String, value: float) -> void:
	tuning[key] = clampf(value, 0.0, 1.0)
	_a().apply_greys()
	_apply_music_level()


## The music slider's level into the bed (MenuAudio), in dB.
func _apply_music_level() -> void:
	if _audio != null and is_instance_valid(_audio):
		_audio.set_ambience_db(lerpf(MUSIC_DB_LOW, MUSIC_DB_HIGH, float(tuning.get("music", 0.667))))


## Tab: the tuning panel, on its own layer on this node (not the shell, which every rebuild replaces).
func _toggle_tuning() -> void:
	if _tuning_hud == null or not is_instance_valid(_tuning_hud):
		_tuning_hud = MenuTuningHud.new(self, TUNING_PATH)
		add_child(_tuning_hud)
		_tuning_hud.visible = false
	_tuning_hud.visible = not _tuning_hud.visible
	if _tuning_hud.visible:
		_tuning_hud.call("refresh")


func _hide_tuning() -> void:
	if _tuning_hud != null and is_instance_valid(_tuning_hud):
		_tuning_hud.visible = false


## Puts the white or the dark palette, and the deck's Regular, into the (run-time copy of the)
## style, quietly, so the caller's one rebuild is the only one. In the editor the style
## resource's own palette shows, so nothing here can write into it.
func _apply_palette() -> void:
	if style == null or Engine.is_editor_hint():
		return
	_disconnect_resource(style)
	var palette: Dictionary = DECK_WHITE if _light else DECK_DARK
	for key in palette:
		style.set(key, palette[key])
	# The deck sets its body in Regular, where the style resource uses SemiBold.
	style.font = load(DECK_FONT) as Font
	_connect_resource(style)


## LIST / ROUTE, at the foot.
func _show_route(route: bool) -> void:
	if _route_view == route:
		return
	_route_view = route
	get_tree().root.set_meta(&"menu_route_view", _route_view)
	_cue("select")
	rebuild()


## The light / dark square, at the foot.
func _toggle_shade() -> void:
	_light = not _light
	get_tree().root.set_meta(&"menu_light", _light)
	_cue("select")
	_apply_palette()
	rebuild()


## The menu's look (menu_a.gd), made on first use.
func _a() -> RefCounted:
	if _look == null:
		_look = MenuA.new(self)
	return _look


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


## Entry indices in the order they are drawn: the families in the catalogue's order (the labs,
## then the playable experiments), then any entry with no family, then the cinematics. Each
## group keeps the catalogue's own order, so "order is the curriculum" still holds inside it.
## (Until 8 Oct: the tour, the cinematics, then the lab; until 9 Oct: the four systems.)
func _display_order() -> Array[int]:
	var groups: Array = []
	for g in GROUP_FILMS + 1:
		groups.append([])
	var all: Array[MenuEntry] = _entries()
	for i in all.size():
		(groups[_group_of(all[i])] as Array).append(i)
	var order: Array[int] = []
	for group in groups:
		order.append_array(group)
	return order


## Which group an entry is listed under: its family's index (the catalogue's `family_names`),
## GROUP_OTHER for an entry with no family (the banner's own entry too), GROUP_FILMS for a
## cinematic.
func _group_of(entry: MenuEntry) -> int:
	if entry == null:
		return GROUP_OTHER
	if entry.section == "Cinematic":
		return GROUP_FILMS
	var family: int = catalogue.family_names.find(entry.family) if catalogue != null else -1
	return family if family >= 0 else GROUP_OTHER


## One blue for every group (Ramon, 8 Oct: no hue shifts). The map's own colours are still
## read into `_systems`, just not shown.
func _group_color(_group: int) -> Color:
	return style.accent


## The families' names, from the catalogue, in its order; one blue for all. (Until 9 Oct the four
## systems' names and colours, from the Frontier Map's layout.)
func _load_systems() -> void:
	_systems.clear()
	for family in catalogue.family_names:
		_systems.append({"label": String(family).to_upper(), "color": style.accent})


## The line under a family's name ("Interactive R&D exhibitions").
func _group_line(group: int) -> String:
	if group >= 0 and group < catalogue.family_lines.size():
		return catalogue.family_lines[group]
	return ""


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
	# What the last build drew per row goes with it: no references to freed controls behind.
	_tracks.clear()
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

	# The ground. Drawn, so it costs no asset and follows the palette.
	var background := Control.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.draw.connect(_draw_background.bind(background))
	background.resized.connect(background.queue_redraw)
	_shell.add_child(background)

	# The deck's running header and footer, with the light / dark and LIST / ROUTE switches.
	# Until 8 Oct this was the Frontier Map's banner (QUANTUM HORIZON over a big EXPLORE
	# FREELY); Ramon: "the explore freely header is something we no longer need".
	_banner_host = _a().build_frame()
	_shell.add_child(_banner_host)

	# A WAY OUT THAT IS NOT ALT+F4. The menu had no quit at all, so coming back from a
	# prototype left the window manager as the only exit.
	#
	# Put INTO the frame's corner row (after the light / dark switch) rather than positioned at
	# offsets. Two attempts at absolute offsets landed it on the LIST / ROUTE switches and then
	# across the PLAY THE WORLD button; the row already solves that, and it moves with the
	# footer if the frame ever changes. It lives under `_shell`, so it hides with the menu while a prototype runs
	# - a quit button floating over the Aquatic Lab would be worse than none.
	_add_quit_button(_banner_host)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_margins(margin, style.space(4))
	_shell.add_child(margin)
	_margin = margin

	# The list or the route, with the details (menu_a.gd).
	_a().build(margin)

	# Siblings of _shell rather than children of it: the shell is hidden while a
	# prototype runs, and these have to outlive that. Rebuilt with everything else, so the
	# old ones go first (a rebuild used to leave its predecessors behind, hidden).
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.get_parent().queue_free()
	if _notice != null and is_instance_valid(_notice):
		_notice.queue_free()
	_build_launch_overlay()
	_build_notice()

	_layout_banner()
	if not resized.is_connected(_layout_banner):
		resized.connect(_layout_banner)

	_select(_selected)


## The loading screen, in the Voxel Lab board's style: the lab's blue, white type, the line along
## the foot (Ramon, 9 Oct, "consistent across all scenes"). Hidden until a launch begins.
##
## It shows the prototype's keys, which is not padding - the seconds before a prototype starts are
## exactly when someone wants to know them, and it is the last moment they can read them before the
## mouse is captured.
func _build_launch_overlay() -> void:
	_overlay = MenuLoadBoard.open(self)


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
	return catalogue.other_heading


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


## A family's mark, as a small square Control.
func _system_mark(group: int, ink: Color, side: float) -> Control:
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(side, side)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(_draw_system_mark.bind(mark, group, ink))
	return mark


## The families' marks, line drawings in the Frontier Map's manner at any size: a flask for the
## labs, a play button in a ring for the playable experiments. Their numbers are for a 30 px box,
## scaled. (Until 9 Oct the four systems' marks: reticle, cube, cells, strands.)
func _draw_system_mark(mark: Control, group: int, ink: Color) -> void:
	var k: float = minf(mark.size.x, mark.size.y) / 30.0
	if k <= 0.0:
		return
	_paint_system_mark(mark, mark.size * 0.5, k, group, ink)


## One family's mark drawn into any canvas item, centred on `mid`, `k` times its 30 px size (the
## loading screen paints both for the world).
func _paint_system_mark(mark: CanvasItem, mid: Vector2, k: float, group: int, ink: Color) -> void:
	var w: float = maxf(1.2, 1.6 * k)
	match group:
		0:
			# The labs: a flask, its liquid line a third of the way up.
			var body := PackedVector2Array([
				mid + Vector2(-3.2, -11) * k, mid + Vector2(-3.2, -4) * k, mid + Vector2(-10, 10) * k,
				mid + Vector2(10, 10) * k, mid + Vector2(3.2, -4) * k, mid + Vector2(3.2, -11) * k])
			mark.draw_polyline(body, ink, w, true)
			mark.draw_line(mid + Vector2(-5.5, -11) * k, mid + Vector2(5.5, -11) * k, ink, w, true)
			mark.draw_line(mid + Vector2(-6.9, 3.6) * k, mid + Vector2(6.9, 3.6) * k, ink, w, true)
		1:
			# The playable experiments: a play button in a ring.
			mark.draw_arc(mid, 11.0 * k, 0.0, TAU, 40, ink, w, true)
			var play := PackedVector2Array([
				mid + Vector2(-3.4, -5.6) * k, mid + Vector2(6.0, 0) * k, mid + Vector2(-3.4, 5.6) * k,
				mid + Vector2(-3.4, -5.6) * k])
			mark.draw_polyline(play, ink, w, true)


## The ground: the palette's background.
func _draw_background(node: Control) -> void:
	node.draw_rect(Rect2(Vector2.ZERO, node.size), style.background)


## Pushes the content clear of the running header.
func _layout_banner() -> void:
	if _margin == null:
		return
	_margin.add_theme_constant_override("margin_top", int(_a().header_height()))
	if _banner_host != null:
		_banner_host.queue_redraw()


## Marks the world selected: its blue a step lighter.
func _style_hero(chosen: bool) -> void:
	if _hero_panel == null:
		return
	_hero_panel.add_theme_stylebox_override("panel", _a().hero_box(chosen))


## How a row lights up (menu_a.gd).
func _row_box(index: int, chosen: bool, hovered: bool) -> StyleBoxFlat:
	return _a().row_box(index, chosen, hovered)


## Right column, top to bottom: the hook, then what it is, then how to play it,
## then - at low visual weight - what it was for.
##
## The weighting is the design. A stakeholder reads the video, the title and the
## key caps and launches; an academic reader carries on into the cells. Same
## pane, no mode switch, and the cells cost the skimmer nothing because they are
## visually subordinate rather than merely shorter.
func _build_detail_column(halves: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _a().pane_box())

	var margin := MarginContainer.new()
	_set_margins(margin, style.space(3.25))
	panel.add_child(margin)

	var column := VBoxContainer.new()
	# Draggable in the style resource - this is the one number that sets how
	# much air sits between the blocks down this pane.
	column.add_theme_constant_override("separation", style.space(style.detail_paragraph_gap))
	# In halves (the route view): the video and its caption on the left, the words on the
	# right, cut in the middle, the video as tall as the words beside it. Otherwise one column,
	# top to bottom.
	var media: VBoxContainer = column
	if halves:
		var split := HBoxContainer.new()
		split.add_theme_constant_override("separation", style.space(4))
		margin.add_child(split)
		media = VBoxContainer.new()
		media.add_theme_constant_override("separation", style.space(1))
		split.add_child(media)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.add_child(column)
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
	# The video frame takes the launch button's corners (Ramon, 8 Oct), not the style's own
	# preview corners.
	var r: float = float(style.corner_radius)
	_preview_material.set_shader_parameter("corner_radius", Vector4(r, r, r, r))
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

	# Over a screenshot, until the video exists (Ramon, 9 Oct: "write video coming today on that
	# image"): a small code-blue label in the frame's bottom left corner.
	var soon := PanelContainer.new()
	soon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var soon_box := StyleBoxFlat.new()
	soon_box.bg_color = style.launch_fill
	soon_box.content_margin_left = 12
	soon_box.content_margin_right = 12
	soon_box.content_margin_top = 6
	soon_box.content_margin_bottom = 6
	soon.add_theme_stylebox_override("panel", soon_box)
	soon.add_child(_label("VIDEO COMING TODAY", MenuStyle.CAPTION, ON_ACCENT, true))
	soon.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	soon.grow_vertical = Control.GROW_DIRECTION_BEGIN
	soon.offset_left = 16
	soon.offset_bottom = -16
	soon.visible = false
	frame.add_child(soon)
	_preview_soon = soon

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
	_a().deck_title(_detail_title)
	if halves:
		_detail_title.add_theme_font_size_override("font_size", 36)
	title_row.add_child(_detail_title)

	# Maturity badge. People read badges even when they read nothing else, and
	# it pre-empts a greybox being taken for a broken build.
	_detail_badge = PanelContainer.new()
	_detail_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_badge.add_theme_stylebox_override("panel", _stylebox(style.surface_raised))
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
	for i in _launch_targets.size():
		var button := _make_launch_button(str(_launch_targets[i]["label"]))
		# Bound by index rather than by path so the handler runs the same
		# guards - _running, _launching, editor - as every other launch route.
		button.pressed.connect(_on_launch_pressed.bind(i))
		_launch_row.add_child(button)


## Styled rather than left on Godot's default theme, which on this ground sat at
## almost exactly the panel colour - the most important control on screen was the
## hardest to see.
## Finds the frame's corner row (menu_a's "CornerRow", the light / dark switch) and puts QUIT at
## its end, the very corner (Ramon, 10 Oct: "push the quit button to the corner bottom right").
## Still inside a row, never at absolute offsets, which is what went wrong twice. Falls back to
## the first HBox, then to nothing.
func _add_quit_button(frame: Control) -> void:
	var row := frame.find_child("CornerRow", true, false) as HBoxContainer
	if row == null:
		row = _first_hbox(frame)
	if row == null:
		push_warning("menu: no switch row found, so no quit button.")
		return
	# In the foot's own button look, like LIST / ROUTE (Ramon, 10 Oct: "fit in style"), not the
	# filled LAUNCH blue: quitting is not the page's main action.
	var quit_button: Button = _a().foot_button("QUIT")
	quit_button.name = "QuitButton"
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_button.pressed.connect(_on_quit_pressed)
	row.add_child(quit_button)


func _first_hbox(node: Node) -> HBoxContainer:
	for child in node.get_children():
		if child is HBoxContainer:
			return child as HBoxContainer
		var deeper: HBoxContainer = _first_hbox(child)
		if deeper != null:
			return deeper
	return null


## Whether a prototype - or a room it opened for itself - is on screen.
##
## NOT `_running != null`. A prototype that opens a second room through change_scene_to_file
## (the Aquatic Lab's sea, the Voxel Lab's open world) frees itself in the process, and this
## reference stops being a reliable test the moment it does. Esc then fell past this menu to
## the sea's own camera rig, whose Esc frees the cursor once and QUITS THE APPLICATION on the
## second press - so leaving the sea closed the game instead of coming back here.
##
## The current scene is the honest question: anything that is not this menu is a prototype.
func _prototype_up() -> bool:
	if _running != null and is_instance_valid(_running):
		return true
	if _menu_scene == null:
		return false
	var current: Node = get_tree().current_scene
	return current != null and current != _menu_scene


## Leaves for good. Deferred, for the same reason the prototype teardown is: quitting from
## inside input dispatch pulls the ground out from under the event still being delivered.
func _on_quit_pressed() -> void:
	get_tree().quit.call_deferred()


func _make_launch_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = style.space(6)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", style.label_font())
	button.add_theme_font_size_override("font_size", style.size_for(MenuStyle.BODY))
	# White on the code blue, in both palettes.
	button.add_theme_color_override("font_color", ON_ACCENT)
	button.add_theme_color_override("font_hover_color", ON_ACCENT)
	button.add_theme_color_override("font_pressed_color", ON_ACCENT)
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

	var label_ink: Color = style.accent if _light else style.accent.lightened(0.35)
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
	for g in _detail_marks.size():
		_detail_marks[g].visible = world or g == group
	if world:
		_detail_system_label.text = catalogue.hero_systems_line
		_detail_system_label.add_theme_color_override("font_color", style.text_dim)
	elif group < _systems.size():
		# "THE LABS  ·  2 OF 4": the family, and where this sits in it (the route's stages count the
		# same way; menu_review_9oct.md §3).
		var members: Array[int] = []
		for i in _order:
			if _group_of(_entry(i)) == group:
				members.append(i)
		var index: int = _entries().find(entry)
		_detail_system_label.text = "%s  ·  %d OF %d" % [_systems[group]["label"], members.find(index) + 1, members.size()]
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
	_preview_soon.visible = false

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

	# No video yet: a screenshot, marked as such (Ramon, 9 Oct: "for now in the video sections, just
	# paste a screenshot. videos will be made later"). Put <clip>.ogv beside <clip>_still.png and the
	# video takes over by itself.
	var still: Texture2D = _load_loose_texture("%s%s_still.png" % [CLIP_DIR, entry.clip])
	if still != null:
		_preview_icon.texture = still
		_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_preview_soon.visible = true
		_preview_caption.text = "SCREENSHOT"
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
			_cue("click")
			_select(index)


## The banner behaves like a row - click to show it in the pane, again to go - so the
## world can be read about before committing ten minutes to it. With no hero configured it
## shows the old COMING SOON notice. (Until 10 Oct a laptop trip made it the way home on the
## first click; the blue RETURN TO THE WORLD button at the foot is that now, and the card
## always means a new world.)
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
	if _selected == HERO:
		_on_launch_pressed()
	else:
		_cue("click")
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

	# Over a running prototype Esc is the one shared question now (menu_way_home.gd, 10 Oct), heard
	# last so the prototype's own panels close first; it calls _close_running on yes. H is no longer
	# a way home (Ramon: the H buttons go). So nothing here while a prototype is up.
	if _prototype_up():
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
		KEY_TAB:
			# The secret tuning panel (only here, never over a running prototype: see above).
			get_viewport().set_input_as_handled()
			_toggle_tuning()


## Up and down walk the rows in SCREEN order - the banner, then the system groups, then the
## cinematics - not in catalogue order, which the groups no longer match.
func _step_selection(delta: int) -> void:
	var position_now: int = -1 if _selected == HERO else _order.find(_selected)
	var next: int = position_now + delta
	if next < 0:
		if catalogue.hero != null and _selected != HERO:
			_cue("click")
			_select(HERO)
		return
	if next >= _order.size():
		return
	_cue("click")
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
## Known cost, now fixed by setting current_scene below: a prototype that
## identifies itself by current_scene.scene_file_path - MiegakureLook's level
## base does - will not know which level it is and will not auto-advance.
func _launch(index: int, target: int = 0) -> void:
	var entry: MenuEntry = _entry(index)
	if entry == null:
		return
	if entry.section == "Cinematic" and entry.cinematic == "":
		_detail_path.text = "a placeholder - this cinematic is not made yet"
		_cue("error")
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
		_cue("error")
		return
	var chosen: Dictionary = targets[clampi(target, 0, targets.size() - 1)]
	var path: String = str(chosen["path"])
	if not ResourceLoader.exists(path):
		push_error("menu_final: scene missing - %s" % path)
		_detail_path.text = "MISSING: %s" % path
		_cue("error")
		return

	# A lab launched with a world on hold: the world is written down and freed first, so the lab
	# runs alone and its numbers are its own (Ramon, 10 Oct). Not for the world itself: going back
	# to it is _return_to_world's business.
	if index != HERO:
		var holding: Node = _laptop_trip()
		if holding != null and holding.has_method("release_world"):
			holding.call("release_world")

	_cue("select")
	_music(false)
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
			_music(true)
			_launching = false
			return
		if progress.size() > 0:
			_overlay.set("progress", float(progress[0]))
		await get_tree().process_frame

	_overlay.set("progress", 1.0)
	# The honest part. instantiate() runs the prototype's _ready on the main
	# thread - Portal builds 21 chunks in ~1,093 ms there, Voxel Mining ~512 ms -
	# and that cannot be measured or interrupted, so the bar stops and the label
	# says what is happening instead of inventing a percentage.
	_overlay.set("stage", "BUILDING THE SCENE")
	await get_tree().process_frame

	var packed: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		push_error("menu_final: could not load %s" % path)
		_hide_overlay()
		_music(true)
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

	# THE PROTOTYPE BECOMES THE CURRENT SCENE, while staying a root child.
	#
	# Leaving `current_scene` on the menu had a second consequence beyond the one noted above,
	# and it took a soft-lock to find: a prototype with a door of its own calls
	# `change_scene_to_file`, which frees the CURRENT scene - the menu, not the prototype. The
	# new room then arrived while the old one was still running underneath, its door trigger
	# fired again, and the Aquatic Lab bounced between the pier and a black loading screen for
	# ever. The Voxel Lab's open world and the Creature Lab's hall open the same way.
	#
	# This costs nothing: the node is already parented to the root, and the Esc fix above
	# works by tree ORDER, not by which scene is current.
	if _menu_scene == null:
		_menu_scene = get_tree().current_scene
	get_tree().current_scene = _running

	_shell.visible = false
	_hide_tuning()
	# One white fade, at the very end of the loading (Ramon, 9 Oct: "the white fade in happens after
	# the tscn loader"). A scene with its own loading board (the Voxel Lab's, opened in its _ready on a
	# layer above this one) takes over blue to blue and does the white itself once it is built; any
	# other scene gets this board's white now.
	if _running.find_child("LoadBoard", true, false) != null:
		_hand_over_overlay()
	else:
		_finish_overlay()
	_launching = false
	_mark_played(index)


## Puts the loading screen up for `entry`: the system it shows and where it sits in the run (what
## the details pane's kicker says), its name, its line, its keys, its logo and its question, and
## its state and length along the bottom.
func _show_overlay(entry: MenuEntry, heading: String = "") -> void:
	if _overlay == null:
		return
	var where: String = _detail_system_label.text if _detail_system_label != null else ""
	_overlay.set("kicker", "QUANTUM HORIZON" + ("  ·  " + where.to_upper() if where != "" else ""))
	_overlay.set("title", (heading if heading != "" else entry.title).to_upper())
	_overlay.set("subtitle", entry.blurb)
	var keys: Array = []
	for pair in entry.control_pairs():
		keys.append([str(pair["key"]), str(pair["action"])])
	_overlay.set("keys", keys)
	_overlay.set("logo", entry.icon)
	# The world has no logo of its own: its square shows the families it holds, side by side.
	var painter: Callable = Callable()
	if entry.icon == null and entry == catalogue.hero:
		painter = func(canvas: CanvasItem, area: Rect2) -> void:
			var cell: float = area.size.x * 0.26
			var n: int = _systems.size()
			for g in n:
				var at: Vector2 = area.get_center() + Vector2((float(g) - float(n - 1) * 0.5) * cell * 1.5, 0.0)
				_paint_system_mark(canvas, at, cell / 30.0, g, Color(1, 1, 1, 0.92))
	_overlay.set("painter", painter)
	_overlay.set("question", entry.question)
	var numbers: Array = []
	if entry.maturity != "":
		numbers.append(["Status", entry.maturity])
	if entry.duration != "":
		numbers.append(["Length", entry.duration])
	_overlay.set("numbers", numbers)
	_overlay.call("begin")


## The map's music bed: on while the menu is up, faded out and paused under a prototype.
func _music(on: bool) -> void:
	if _audio != null and is_instance_valid(_audio):
		_audio.pause_ambience(not on)


## Plays one of the map's cues ("click", "select", "error", "swipe"); silent in the editor.
func _cue(cue: String) -> void:
	if _audio != null and is_instance_valid(_audio):
		_audio.call(cue)


## Gone at once: a launch that failed.
func _hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.call("close_now")


## The prototype is there: the board goes white and the white fades to it, as the Voxel Lab's does.
func _finish_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.call("finish")


## The scene's own board is up over this one: this one goes, without a white of its own, once the
## other has drawn (its first frame draws nothing, before it knows the window's size).
func _hand_over_overlay() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_hide_overlay()


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
	# WHAT IS RUNNING MAY NOT BE WHAT WAS LAUNCHED. A prototype that opened a room of its own
	# through change_scene_to_file left `_running` holding a freed node and the second room as
	# the current scene; freeing only `_running` would leave that room on screen under the
	# menu.
	var live: Node = _running if (_running != null and is_instance_valid(_running)) else null
	var current: Node = get_tree().current_scene
	if live == null and current != null and current != _menu_scene:
		live = current
	if live == null and _running == null:
		return
	_running = null
	# Freed deferred for the same reason gate triggers and level hand-offs are:
	# tearing a scene down from inside input dispatch pulls the ground out from
	# under the event still being delivered.
	if live != null:
		live.queue_free()
	if _menu_scene != null and is_instance_valid(_menu_scene):
		get_tree().current_scene = _menu_scene
	_menu_scene = null
	_hide_overlay()
	_cue("swipe")
	_music(true)
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
	# A world on hold and PLAY THE WORLD pressed: a new world, but only after asking, since the
	# held one is lost (Ramon, 10 Oct: the card starts fresh, the blue button goes back).
	if _selected == HERO and _world_on_hold():
		var way_home: Node = get_tree().root.get_node_or_null(^"WayHome")
		if way_home != null:
			way_home.call("ask", "Start a new world?", "The world you left will be lost. To go back to it instead, use Return to the World.",
				"Yes, Start a New World", "No, Keep It", _start_new_world.bind(target))
			return
	_launch(_selected, target)


## Whether a world is waiting to be gone back to: held by a laptop trip (pen_laptop_trip_4d.gd)
## while this menu is up. Shows the blue RETURN TO THE WORLD button at the foot (menu_a).
func _world_on_hold() -> bool:
	return _laptop_trip() != null


## The blue button: back to the world where it was left. Still held (no lab since): put back in an
## instant. Written down and freed (a lab ran): loaded again behind the loading board, and the trip
## restores what was written down once it is up.
func _return_to_world() -> void:
	var trip: Node = _laptop_trip()
	if trip == null or _running != null or _launching:
		return
	_cue("select")
	if not trip.has_method("has_world") or bool(trip.call("has_world")):
		trip.call("come_back")
		return
	trip.call("expect_world")
	_launch(HERO)


func _start_new_world(target: int) -> void:
	_discard_world()
	_launch(HERO, target)


## The held world given up (PLAY THE WORLD said yes to a new one).
func _discard_world() -> void:
	var trip: Node = _laptop_trip()
	if trip != null and trip.has_method("discard"):
		trip.call("discard")


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
