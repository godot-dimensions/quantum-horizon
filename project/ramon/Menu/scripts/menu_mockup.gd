@tool
extends Control
## Scrolling banner menu - a LAYOUT MOCKUP, not the shipping menu.
##
## @tool, so the whole screen draws in the EDITOR viewport and every change to
## the style or catalogue resource redraws it immediately - open
## `ramon/Menu.tscn`, select the root node, and edit. Without this the
## inspector showed the properties and a blank viewport, which is a poor way to
## judge a layout.
##
## Generated nodes are never given an `owner`, so none of them are serialised
## into the .tscn. That is what keeps the scene file a single node and sidesteps
## the `[editable path]` resave trap in CLAUDE.md, the same discipline
## `hub_gate_ring_4d.gd` and `ascent_builder_4d.gd` follow.
##
## Nothing here replaces `menu/main_menu.tscn`, and `project.godot` is untouched.
## The scene lives at `res://ramon/Menu.tscn` - alongside HubFinal.tscn at the
## ramon root, with its scripts, style, catalogue, shader and clips in
## `ramon/Menu/`. It is the project's `run/main_scene`, so F5 opens it too.
##
## NOTHING VISUAL IS HARDCODED IN THIS FILE ANY MORE.
##
##   - every size, colour, gap and radius comes from `style/default_style.tres`
##     ([MenuStyle]) - and type is a MODULAR SCALE, so one base size moves the
##     whole hierarchy together instead of eight numbers drifting apart
##   - every string and every prototype comes from `entries/catalogue.tres`
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

const DEFAULT_STYLE: String = "res://ramon/Menu/style/default_style.tres"
const DEFAULT_CATALOGUE: String = "res://ramon/Menu/entries/catalogue.tres"

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

var _selected: int = 0
var _played: Array[bool] = []
var _rows: Array[PanelContainer] = []
var _shell: Control = null

var _preview_atlas: AtlasTexture = null
var _preview_frame: Control = null
var _preview_material: ShaderMaterial = null
var _video_material: ShaderMaterial = null
var _preview_icon: TextureRect = null
var _preview_video: VideoStreamPlayer = null
var _preview_caption: Label = null
var _detail_title: Label = null
var _detail_badge: PanelContainer = null
var _detail_badge_label: Label = null
var _detail_blurb: Label = null
var _controls_host: HBoxContainer = null
var _info_host: GridContainer = null
var _detail_path: Label = null
var _launch_button: Button = null

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
	_connect_resource(style)
	_connect_resource(catalogue)
	rebuild()


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
	for entry in catalogue.entries:
		if entry != null and not entry.changed.is_connected(_on_entry_changed):
			entry.changed.connect(_on_entry_changed)


func _on_entry_changed() -> void:
	if is_inside_tree():
		_refresh_details.call_deferred()


## Re-reads the selected entry into the detail pane without reloading its media.
func _refresh_details() -> void:
	if catalogue == null or _detail_title == null:
		return
	if _selected >= catalogue.entries.size():
		return
	var entry: MenuEntry = catalogue.entries[_selected]
	if entry == null:
		return
	_detail_title.text = entry.title.to_upper()
	_detail_badge_label.text = entry.maturity.to_upper()
	_detail_blurb.text = entry.blurb
	_build_controls(entry)
	_build_info(entry)
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
		push_warning("menu mockup: missing style or catalogue resource")
		return

	_connect_entries()

	if _shell != null and is_instance_valid(_shell):
		_shell.queue_free()
	_rows.clear()
	_preview_atlas = null

	_played.resize(catalogue.entries.size())
	if _played.count(true) == 0:
		_played.fill(false)

	_shell = Control.new()
	_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shell)

	var background := ColorRect.new()
	background.color = style.background
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_margins(margin, style.space(4))
	_shell.add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", style.space(4))
	margin.add_child(columns)

	columns.add_child(_build_list_column())
	columns.add_child(_build_detail_column())

	# Siblings of _shell rather than children of it: the shell is hidden while a
	# prototype runs, and these have to outlive that.
	_build_launch_overlay()
	_build_notice()

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


func _process(delta: float) -> void:
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
	column.custom_minimum_size.x = style.scaled(style.list_width)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", style.space(1.75))

	column.add_child(_label(catalogue.header, MenuStyle.CAPTION, style.text_dim, true))
	column.add_child(_build_hero())
	column.add_child(_label(catalogue.list_heading, MenuStyle.MICRO, style.text_dim, true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", style.space(1))
	scroll.add_child(rows)

	for i in catalogue.entries.size():
		var row := _build_row(i)
		_rows.append(row)
		rows.add_child(row)

	# States the interaction rather than leaving it to be guessed at.
	column.add_child(_label(catalogue.hint, MenuStyle.MICRO, style.text_dim, false))
	return column


## Deliberately much larger than a row: it is the difference between "a menu of
## tech demos" and "a thing somebody sequenced for you", and if it reads as just
## another list item the whole argument collapses.
func _build_hero() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stylebox(style.accent))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_hero_input)

	var margin := MarginContainer.new()
	_set_margins(margin, style.space(2.5), style.space(2))
	panel.add_child(margin)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", style.space(0.25))
	margin.add_child(text)
	text.add_child(_label(catalogue.tour_title, MenuStyle.TITLE, style.text, false))
	text.add_child(_label(catalogue.subtitle_text(), MenuStyle.BODY, Color(0.78, 0.85, 0.95), false))
	return panel


func _build_row(index: int) -> PanelContainer:
	var entry: MenuEntry = catalogue.entries[index]

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stylebox(style.surface))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_row_input.bind(index))
	panel.mouse_entered.connect(_on_row_hover.bind(index, true))
	panel.mouse_exited.connect(_on_row_hover.bind(index, false))

	var margin := MarginContainer.new()
	_set_margins(margin, style.space(1.25))
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", style.space(1.75))
	margin.add_child(row)

	# Rows stay STILL even when clips exist. Eight simultaneously playing
	# previews is a slot machine; only the selected one moves.
	var thumb := TextureRect.new()
	thumb.texture = entry.icon
	var thumb_width: float = style.scaled(style.thumbnail_width)
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
	text.add_child(_label(entry.title.to_upper(), MenuStyle.SUBTITLE, style.text, false))

	var blurb := _label(entry.blurb, MenuStyle.CAPTION, style.text_dim, false)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size.x = style.scaled(250)
	text.add_child(blurb)

	# Played / not played. Set ONLY by actually launching something and coming
	# back - never by selecting, which is what made these fill in unexplained.
	var dot := ColorRect.new()
	dot.name = "PlayedDot"
	var dot_size: float = style.scaled(9)
	dot.custom_minimum_size = Vector2(dot_size, dot_size)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = style.surface_raised
	row.add_child(dot)

	return panel


## Right column, top to bottom: the hook, then what it is, then how to play it,
## then - at low visual weight - what it was for.
##
## The weighting is the design. A stakeholder reads the video, the title and the
## key caps and launches; an academic reader carries on into the cells. Same
## pane, no mode switch, and the cells cost the skimmer nothing because they are
## visually subordinate rather than merely shorter.
func _build_detail_column() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _stylebox(style.surface))

	var margin := MarginContainer.new()
	_set_margins(margin, style.space(3.25))
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", style.space(2))
	margin.add_child(column)

	var preview_width: float = style.scaled(576)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(preview_width, preview_width / style.preview_aspect)
	frame.clip_contents = true
	# The shader needs the pane's real pixel size, which is only known after the
	# container has laid out - and changes again whenever the window does.
	frame.resized.connect(_on_preview_resized.bind(frame))
	column.add_child(frame)

	_preview_frame = frame
	_preview_material = ShaderMaterial.new()
	_preview_material.shader = load(ROUNDED_SHADER) as Shader
	_preview_material.set_shader_parameter("corner_radius", Vector4(
		style.preview_corner_top_left,
		style.preview_corner_top_right,
		style.preview_corner_bottom_right,
		style.preview_corner_bottom_left
	))
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

	_preview_caption = _label("", MenuStyle.MICRO, style.text_dim, true)
	column.add_child(_preview_caption)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", style.space(1.5))
	column.add_child(title_row)

	_detail_title = _label("", MenuStyle.DISPLAY, style.text, false)
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

	_detail_blurb = _label("", MenuStyle.SUBTITLE, style.text_dim, false)
	_detail_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_blurb)

	_controls_host = HBoxContainer.new()
	_controls_host.add_theme_constant_override("separation", style.space(1.5))
	column.add_child(_controls_host)

	_info_host = GridContainer.new()
	_info_host.columns = style.info_columns
	_info_host.add_theme_constant_override("h_separation", style.space(2))
	_info_host.add_theme_constant_override("v_separation", style.space(1.5))
	column.add_child(_info_host)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_detail_path = _label("", MenuStyle.MICRO, style.text_faint, false)
	column.add_child(_detail_path)

	_launch_button = Button.new()
	_launch_button.text = catalogue.launch_label
	_launch_button.custom_minimum_size.y = style.space(6)
	_launch_button.add_theme_font_override("font", style.label_font())
	_launch_button.add_theme_font_size_override("font_size", style.size_for(MenuStyle.BODY))
	_launch_button.pressed.connect(_on_launch_pressed)
	column.add_child(_launch_button)

	return panel


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
	_add_info_cell(catalogue.finding_label, entry.finding)


func _add_info_cell(label_text: String, body_text: String) -> void:
	if body_text == "":
		return
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", style.space(0.5))

	cell.add_child(_label(label_text, style.info_label_step, style.accent.lightened(0.35), true))

	var body := _label(body_text, style.info_body_step, style.text_dim, false)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = style.scaled(150)
	cell.add_child(body)

	_info_host.add_child(cell)


# --------------------------------------------------------------------------
# Selection
# --------------------------------------------------------------------------

func _select(index: int) -> void:
	_selected = clampi(index, 0, catalogue.entries.size() - 1)
	var entry: MenuEntry = catalogue.entries[_selected]

	for i in _rows.size():
		var chosen: bool = i == _selected
		var box := _stylebox(style.surface_raised if chosen else style.surface)
		if chosen and style.selection_bar > 0:
			box.border_color = style.accent
			box.border_width_left = style.selection_bar
		_rows[i].add_theme_stylebox_override("panel", box)

	_load_preview(entry)

	_detail_title.text = entry.title.to_upper()
	_detail_badge_label.text = entry.maturity.to_upper()
	_detail_blurb.text = entry.blurb
	_build_controls(entry)
	_build_info(entry)
	_detail_path.text = entry.scene_path if entry.scene_path != "" else "no scene wired yet"


func _load_preview(entry: MenuEntry) -> void:
	_preview_atlas = null
	_loop_time = 0.0

	_preview_video.stop()
	_preview_video.visible = false
	_preview_icon.visible = true

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

	_preview_icon.texture = entry.icon
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_caption.text = "NO CAPTURE YET  ·  RUN _capture_clip.gd FOR THIS ONE"


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
	if catalogue != null and _selected < catalogue.entries.size():
		var entry: MenuEntry = catalogue.entries[_selected]
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
	if index == _selected or _running != null:
		return
	_rows[index].add_theme_stylebox_override("panel", _stylebox(style.surface_raised if entered else style.surface))


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


func _on_hero_input(event: InputEvent) -> void:
	if _running != null or _launching or Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_notice()


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

	match key.keycode:
		KEY_DOWN:
			_select(_selected + 1)
		KEY_UP:
			_select(_selected - 1)
		KEY_ENTER, KEY_KP_ENTER:
			_on_launch_pressed()


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
func _launch(index: int) -> void:
	var entry: MenuEntry = catalogue.entries[index]
	if entry.scene_path == "":
		_detail_path.text = "no scene wired yet - nothing to launch"
		return
	if not ResourceLoader.exists(entry.scene_path):
		push_error("menu mockup: scene missing - %s" % entry.scene_path)
		_detail_path.text = "MISSING: %s" % entry.scene_path
		return

	_launching = true
	_preview_video.stop()
	_show_overlay(entry)

	# TWO frames, not one. Making the overlay visible only queues a redraw; the
	# first frame after this is when it actually reaches the screen. Blocking on
	# the load before that gives the frozen click this whole thing exists to
	# remove - the overlay would appear only after the wait it was meant to
	# cover.
	await get_tree().process_frame
	await get_tree().process_frame

	# Threaded, so the bar shows REAL progress instead of a made-up animation.
	# Only the resource load is measurable this way; see below.
	ResourceLoader.load_threaded_request(entry.scene_path)
	while true:
		var progress: Array = []
		var status: int = ResourceLoader.load_threaded_get_status(entry.scene_path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("menu mockup: could not load %s" % entry.scene_path)
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

	var packed: PackedScene = ResourceLoader.load_threaded_get(entry.scene_path) as PackedScene
	if packed == null:
		push_error("menu mockup: could not load %s" % entry.scene_path)
		_hide_overlay()
		_launching = false
		return

	_running = packed.instantiate()
	_claim_return_button(_running)
	get_tree().root.add_child(_running)

	_shell.visible = false
	_hide_overlay()
	_launching = false
	_mark_played(index)


func _show_overlay(entry: MenuEntry) -> void:
	if _overlay == null:
		return
	_overlay_title.text = entry.title.to_upper()
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
	_load_preview(catalogue.entries[_selected])


func _mark_played(index: int) -> void:
	_played[index] = true
	var dot := _rows[index].find_child("PlayedDot", true, false) as ColorRect
	if dot != null:
		dot.color = style.positive


func _on_launch_pressed() -> void:
	# `_launching` matters as much as `_running`: the load is asynchronous now,
	# so there is a window where nothing is running yet and a second click would
	# start a parallel launch. Clicking again during a wait is exactly what
	# people do when a screen looks stuck.
	if _running != null or _launching or Engine.is_editor_hint():
		return
	_launch(_selected)


# --------------------------------------------------------------------------
# Helpers - every one of these reads the style resource, never a literal.
# --------------------------------------------------------------------------

func _label(text: String, step: int, color: Color, tracked: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", style.label_font() if tracked else style.font)
	label.add_theme_font_size_override("font_size", style.size_for(step))
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
