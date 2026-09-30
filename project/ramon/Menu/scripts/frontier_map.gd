@tool
extends Control
## The Frontier Map. Scene: `res://ramon/FrontierMap.tscn`.
##
## The second way into the same nine prototypes. `Menu2.tscn` answers "what can I
## play"; this answers "what is this programme, and what has it proved". They are
## two views of ONE catalogue, not two catalogues - `entries/catalogue.tres` is
## shared, so a blurb rewritten for one is rewritten for both, and neither can
## drift into claiming a prototype the other does not have.
##
## WHAT THIS SCREEN ADDS
##
##   - The four categories. Nine prototypes in a list read as nine unrelated
##     demos; sorted into Orientation, Spatial Interaction, World Systems and
##     Living Systems they read as a programme with coverage. That is the whole
##     argument, and it is why the category anchors are more load-bearing than
##     the curve.
##   - Room for work that does not exist yet. [MenuEntry] can only describe
##     something with a scene behind it; [FrontierEntry] adds UPCOMING and FOG,
##     so the map can be honest about what is coming without offering a button
##     that does nothing.
##   - The October Gate cross-reference, as one gold badge.
##
## WHAT IT DELIBERATELY DOES NOT ADD: voting, conviction, contribution nodes,
## unlock economies, persistent profiles, or a dependency graph generated from
## Notion. All out of scope per the brief, and all of them would turn a way of
## reading the work into a product of their own.
##
## THE CURVE IS RHYTHM, NOT LOGIC. Edges join catalogue-ADJACENT prototypes and
## nothing else. See [FrontierEdges].
##
## `@tool`, so the whole screen draws in the editor viewport and every edit to
## the style or layout resource redraws it immediately. Generated children are
## never given an `owner`, so none of them are serialised into the .tscn - the
## same discipline `menu2.gd` follows, and what keeps the scene file one node and
## sidesteps the `[editable path]` resave trap in CLAUDE.md.

const DEFAULT_STYLE: String = "res://ramon/Menu/style/frontier_style.tres"
const DEFAULT_LAYOUT: String = "res://ramon/Menu/entries/frontier_layout.tres"
const DEFAULT_CATALOGUE: String = "res://ramon/Menu/entries/catalogue.tres"
const LIST_MENU_SCENE: String = "res://ramon/menu_final.tscn"

## The space the reference art is measured in. Everything is authored against
## this and the whole map is scaled uniformly into the window, which is why the
## positions in `frontier_layout.tres` can be read straight off the mock-up.
##
## Uniform scale rather than an HBoxContainer on purpose: a container would
## re-flow the nodes and destroy the one thing the layout is FOR, which is that
## the shape of the field is composed rather than computed.
const REFERENCE: Vector2 = Vector2(1920, 1080)

## The detail panel's box, in reference pixels: the left margin out to the
## screen's midpoint, so the lower half splits cleanly in two. The planning
## gateways take the other half and get their air back - at 65% their subtitles
## were nearly touching.
##
## The gateways heading derives its x from these, so widening the panel later
## moves the whole right-hand column with it instead of stranding the heading.
const PANEL_LEFT: float = 70.0
const PANEL_WIDTH: float = 890.0

const RETURN_KEY: Key = KEY_ESCAPE
const PROTOTYPE_RETURN_KEY: Key = KEY_H

@export var style: FrontierStyle = null:
	set(value):
		_disconnect_resource(style)
		style = value
		_connect_resource(style)
		_request_rebuild()

@export var layout: FrontierLayout = null:
	set(value):
		_disconnect_resource(layout)
		layout = value
		_connect_resource(layout)
		_request_rebuild()

@export var catalogue: MenuCatalogue = null:
	set(value):
		_disconnect_resource(catalogue)
		catalogue = value
		_connect_resource(catalogue)
		_request_rebuild()

@export_tool_button("Rebuild preview") var _rebuild_action: Callable = rebuild

var _shell: Control = null
var _reference_root: Control = null
## The node field, offset up by whatever height the banner gave back.
var _field_root: Control = null
var _edge_layer: FrontierEdges = null
var _nodes: Array[FrontierNode] = []
## Catalogue titles, in catalogue order, that have a placement on the map.
var _placed_titles: PackedStringArray = PackedStringArray()
var _selected_title: String = ""
var _played: Dictionary = {}

var _panel_title: Label = null
var _panel_head: Label = null
var _panel_body: Label = null
var _panel_note: Label = null
var _panel_tags: HBoxContainer = null
var _panel_glyph: Control = null
var _launch_button: Button = null
var _activity_button: Button = null

var _overlay: Control = null
var _overlay_title: Label = null
var _overlay_stage: Label = null
var _overlay_bar: ProgressBar = null
var _notice: Control = null

var _launcher: PrototypeLauncher = null
var _audio: MenuAudio = null
var _speaker: Control = null
var _drawer: FrontierDrawer = null

## The overview, kept so BACK TO OVERVIEW always has somewhere to return to and
## the sub-maps never have to know what opened them.
var _root_layout: FrontierLayout = null
## Selection to restore when we come back up. The proposal asks for the overview
## to keep its last selection across a sub-map visit.
var _root_selection: String = ""


func in_sub_map() -> bool:
	return _root_layout != null and layout != _root_layout


func _ready() -> void:
	if style == null:
		style = load(DEFAULT_STYLE) as FrontierStyle
	if layout == null:
		layout = load(DEFAULT_LAYOUT) as FrontierLayout
	if catalogue == null:
		catalogue = load(DEFAULT_CATALOGUE) as MenuCatalogue
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not Engine.is_editor_hint():
		# Added to the node itself rather than to the rebuilt shell, so the
		# ambience does not restart every time the screen is rebuilt - which it
		# is on every return from a prototype.
		_audio = MenuAudio.new()
		add_child(_audio)
		_drawer = FrontierDrawer.new()
		_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_drawer)
		_drawer.closed.connect(_on_drawer_closed)
		# The drawer's deeper records - briefs, PRs, credits, galleries - are
		# explicitly one level below this screen and none of them exist yet. The
		# refusal cue is what stops that button reading as broken rather than as
		# not-built, which is the same rule the map applies to Nevada and the
		# planning gateways.
		_drawer.brief_requested.connect(func(_id: String) -> void: _refused())
		_drawer.refused.connect(_refused)
		# Submitting does change something - the drawer records the choice - so it
		# gets the cue for an action that landed.
		_drawer.signal_submitted.connect(func(_id: String, _option: int) -> void:
			if _audio != null:
				_audio.select())
		_launcher = PrototypeLauncher.new(self)
		_launcher.progress_changed.connect(_on_launch_progress)
		_launcher.stage_changed.connect(_on_launch_stage)
		_launcher.failed.connect(_on_launch_failed)
		_launcher.closed.connect(_on_prototype_closed)
	resized.connect(_layout_reference)
	rebuild()


func _request_rebuild() -> void:
	if not is_inside_tree():
		return
	if not is_node_ready():
		return
	call_deferred("rebuild")


func _connect_resource(resource: Resource) -> void:
	if resource != null and not resource.changed.is_connected(_request_rebuild):
		resource.changed.connect(_request_rebuild)


func _disconnect_resource(resource: Resource) -> void:
	if resource != null and resource.changed.is_connected(_request_rebuild):
		resource.changed.disconnect(_request_rebuild)


## Each placement has to be listened to individually - a sub-resource's `changed`
## does not bubble up to the resource holding it, so listening only to the layout
## means every per-node edit is silently ignored in the editor preview. Same trap
## `menu2.gd` documents for its catalogue entries.
func _connect_placements() -> void:
	if layout == null:
		return
	for group in [layout.placements, layout.categories, layout.edges]:
		for item in group:
			_connect_resource(item)


# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------

func rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		# The audio component and the drawer outlive every rebuild. The screen is rebuilt on
		# every return from a prototype, and freeing the player with it would
		# restart the ambience track from the top each time - and silently drop
		# the mute the viewer had chosen.
		if child == _audio or child == _drawer:
			continue
		child.queue_free()
	_nodes.clear()
	_placed_titles = PackedStringArray()
	if style == null or layout == null or catalogue == null:
		return
	_connect_placements()

	_shell = Control.new()
	_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shell)

	var ground := ColorRect.new()
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.color = style.background
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(ground)

	_reference_root = Control.new()
	_reference_root.size = REFERENCE
	_reference_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(_reference_root)

	_build_header()
	_build_map()
	_build_detail_panel()
	_build_legend()
	_build_overlay()
	_build_notice()
	_layout_reference()

	# The drawer is created once in _ready and survives every rebuild, so it ends
	# up BELOW the shell each time the screen is rebuilt. Godot draws children in
	# order, so an overlay that is not last is not an overlay - it was opening
	# correctly and rendering underneath the map.
	if _drawer != null and is_instance_valid(_drawer):
		move_child(_drawer, get_child_count() - 1)

	# Initial selection: the first placed prototype in catalogue order. The brief
	# allows last-selected or first-relevant; first-in-order is the one that
	# agrees with "order is the curriculum" and needs no stored state.
	if _placed_titles.size() > 0:
		_select(_placed_titles[0])


## Scales the 1920x1080 reference space to fit the window and centres it.
##
## Necessary because `project.godot` runs CANVAS_ITEMS + EXPAND, which hands a
## wider-than-16:9 display the extra width rather than letterboxing. Absolute
## positions authored at 1920 would then sit hard against the left edge. Fitting
## and centring keeps the composition intact at any aspect.
func _layout_reference() -> void:
	if _reference_root == null:
		return
	var available: Vector2 = size
	if available.x <= 0.0 or available.y <= 0.0:
		return
	# Shared with Menu2 via [MenuBanner], so the banner lands on identical screen
	# pixels on both screens rather than each computing its own fit.
	var factor: float = MenuBanner.reference_scale(available)
	_reference_root.scale = Vector2(factor, factor)
	_reference_root.position = MenuBanner.reference_origin(available)


## The shared banner. Identical on both screens - see [MenuBanner].
##
## Tab 0 is this screen, tab 1 is the list, so pressing tab 1 switches. Menu2
## builds the same banner with the same labels and the active index flipped.
func _build_header() -> void:
	var banner := MenuBanner.new()
	banner.position = Vector2.ZERO
	_reference_root.add_child(banner)
	banner.setup(
		layout.eyebrow, layout.title,
		PackedStringArray([catalogue.guided_tab, catalogue.explore_tab]), 0,
		_banner_action_label(),
		banner_fonts(style.caps_font(style.caps_tracking), style.caps_font(2)),
		{
			"fill": style.header_fill, "rule": style.rule,
			"text_bright": style.text_bright, "text_faint": style.text_faint,
			"tab_active_fill": style.tab_active_fill,
			"tab_active_stroke": style.tab_active_stroke,
			"tab_idle_fill": style.tab_idle_fill,
			"tab_idle_stroke": style.tab_idle_stroke,
			"action_fill": style.button_fill, "action_stroke": style.button_stroke,
			"action_hover": style.button_fill_hover, "action_text": style.text_bright,
		})
	banner.tab_pressed.connect(func(_index: int) -> void: _on_explore_freely())
	# One button, two meanings by depth. On the overview it starts the tour; in a
	# sub-map it is the way back up. Adding a fourth permanent tab for each
	# sub-map was rejected in the proposal - gateways are entered through their
	# nodes, so the only persistent modes stay Frontier Map and Explore Freely.
	banner.action_pressed.connect(_on_banner_action)


func _banner_action_label() -> String:
	if in_sub_map():
		return "←  BACK TO OVERVIEW"
	return layout.start_tour_text(_prototype_count())


func _on_banner_action() -> void:
	if Engine.is_editor_hint():
		return
	if in_sub_map():
		back_to_overview()
	else:
		_on_start_tour()


## Shared shape for [MenuBanner]'s font argument, so both screens cannot get the
## two keys subtly different.
static func banner_fonts(caps: Font, caps_tight: Font) -> Dictionary:
	return {"caps": caps, "caps_tight": caps_tight}


## Prototypes only. The banner claims a number of PROTOTYPES, and gateways and
## planning nodes are neither playable nor part of the tour.
func _prototype_count() -> int:
	if layout == null:
		return 0
	var total: int = 0
	for placement in layout.placements:
		if placement != null and placement.kind == FrontierEntry.Kind.PROTOTYPE:
			total += 1
	return total


func _build_map() -> void:
	# The node field lives in its own layer, shifted up by whatever the banner
	# gave back. Positions in `frontier_layout.tres` stay authored against the
	# reference art's 128px header, so shortening the banner buys the map room
	# without invalidating every measured position in the resource.
	_field_root = Control.new()
	_field_root.position = Vector2(0, MenuBanner.HEIGHT - 128.0)
	_field_root.size = REFERENCE
	_field_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reference_root.add_child(_field_root)

	_edge_layer = FrontierEdges.new()
	_edge_layer.style = style
	_edge_layer.size = REFERENCE
	_field_root.add_child(_edge_layer)

	var drops: Array[Dictionary] = []
	var separators: Array[float] = []
	for category in layout.categories:
		if category == null:
			continue
		# The little line mark before each heading, drawn rather than imported:
		# four marks is less asset pipeline than four SVGs, and they recolour
		# with the category automatically. Sub-map lanes turn it off - their
		# headings are organisational bands, not the four kinds of proof.
		if category.show_mark:
			var mark := Control.new()
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.size = Vector2(30, 30)
			mark.position = category.label_position + Vector2(-46, -5)
			_field_root.add_child(mark)
			mark.draw.connect(_draw_category_mark.bind(mark, category))

		# QUARTER headings are large and quiet - chapter markers for the 2027
		# map's timeline rather than labels competing with the nodes under them.
		var quarter: bool = category.text_style == FrontierCategory.TextStyle.QUARTER
		_add_label(_field_root, category.label, category.label_position,
			style.title_size - 7 if quarter else style.section_size,
			Color(category.color, 0.45) if quarter else category.color,
			style.section_tracking)
		if category.drop_line != Vector3.ZERO:
			drops.append({
				"x": category.drop_line.x,
				"from_y": category.drop_line.y,
				"to_y": category.drop_line.z,
				"color": category.color,
			})
		if category.separator_x >= 0.0:
			separators.append(category.separator_x)

	for placement in _ordered_placements():
		var entry: MenuEntry = _entry_for(placement.entry_title)
		_placed_titles.append(placement.entry_title)
		var node := FrontierNode.new()
		node.setup(placement, style, placement.label_text().to_upper(),
			_sub_text_for(entry, placement), null if entry == null else entry.icon)
		_field_root.add_child(node)
		node.place_at(placement.reference_position)
		node.focused.connect(_select)
		node.activated.connect(_on_node_activated)
		node.drag_started.connect(func(_title: String) -> void: _click())
		node.activity_requested.connect(func(title: String) -> void:
			_open_activity(title, FrontierDrawer.Tab.ACTIVITY))
		node.dragged.connect(_on_node_dragged)
		node.drag_released.connect(_on_node_released)
		_nodes.append(node)

	_edge_layer.set_geometry(_build_edges(), drops, separators, layout.field_span)

	_add_label(_field_root, layout.route_caption, layout.caption_position,
		style.small_caps_size, style.text_faint, 1)

	# Breadcrumb, caveat and signal pill are sub-map furniture. The overview
	# leaves all three empty, so the root screen keeps its clean top edge.
	if layout.breadcrumb != "":
		_add_label(_field_root, layout.breadcrumb, Vector2(70, 138),
			style.small_caps_size, style.text_faint, 2)
	if layout.caveat != "":
		var caveat := _make_tag(layout.caveat)
		caveat.position = Vector2(70, 196)
		_field_root.add_child(caveat)
	if layout.signal_pill != "":
		_build_signal_pill()

	# Heading over the lower band's right column. Only drawn where there are
	# gateway nodes to head, so the sub-maps do not inherit it.
	if layout.gateways_heading != "" and _has_gateways():
		var heading_x: float = layout.panel_rect.position.x + layout.panel_rect.size.x + 40.0
		_add_label(_reference_root, layout.gateways_heading, Vector2(heading_x, 636),
			style.section_size, style.text_section, style.section_tracking)
		_add_label(_reference_root, layout.gateways_note, Vector2(heading_x, 664),
			style.small_caps_size, style.text_faint, 1)

	if layout.fog_teaser_position != Vector2.ZERO:
		var haze := Control.new()
		haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
		haze.size = Vector2(280, 240)
		haze.position = layout.fog_teaser_position - haze.size * 0.5
		_reference_root.add_child(haze)
		haze.draw.connect(_draw_fog_teaser.bind(haze))

	var divider := ColorRect.new()
	divider.position = Vector2(70, 604)
	divider.size = Vector2(1780, 1)
	divider.color = style.divider
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reference_root.add_child(divider)


## The route order: the catalogue's array order, with standalone placements
## spliced in after whichever entry they name.
##
## Catalogue order is the project's one running order and stays authoritative -
## reordering `catalogue.tres` re-sequences this map too, which is the whole
## reason the brief's separate `tour_index` was dropped. Standalone nodes are
## work with no catalogue entry yet; they cannot be in that order, so they say
## what they follow instead.
func _ordered_placements() -> Array[FrontierEntry]:
	var ordered: Array[FrontierEntry] = []
	var used: Array[FrontierEntry] = []

	# Sub-maps are not tours. Their nodes have no catalogue order to inherit and
	# their lines are dependencies rather than a sequence, so the authored array
	# order is the only order there is.
	if not layout.route_from_catalogue:
		for placement in layout.placements:
			if placement != null:
				ordered.append(placement)
		return ordered

	for entry in catalogue.entries:
		if entry == null:
			continue
		var placement: FrontierEntry = layout.placement_for(entry.title)
		if placement == null or placement.kind != FrontierEntry.Kind.PROTOTYPE:
			continue
		ordered.append(placement)
		used.append(placement)

	# Standalone PROTOTYPES splice into the route where they say they belong.
	# Gateways deliberately do not: they sit in the lower band and are not stages
	# of the tour, which is the whole reason the proposal keeps them off it.
	for placement in layout.placements:
		if placement == null or used.has(placement):
			continue
		if placement.kind != FrontierEntry.Kind.PROTOTYPE:
			continue
		var after: int = -1
		for i in ordered.size():
			if ordered[i].entry_title == placement.route_after:
				after = i
				break
		if after < 0:
			if placement.route_after != "":
				push_warning("frontier map: '%s' follows unknown '%s'; appended instead"
					% [placement.entry_title, placement.route_after])
			ordered.append(placement)
		else:
			ordered.insert(after + 1, placement)
		used.append(placement)

	# Everything that is not a prototype - the gateways - is built as a node but
	# appended after the route, so it never joins the chain of edges.
	for placement in layout.placements:
		if placement != null and not used.has(placement):
			ordered.append(placement)
	return ordered


func _entry_for(entry_title: String) -> MenuEntry:
	if catalogue == null:
		return null
	for entry in catalogue.entries:
		if entry != null and entry.title == entry_title:
			return entry
	return null


## The subtitle under a node. PLAYED wins over everything, then the map's own
## state, then the catalogue's maturity - so the line always describes the most
## specific thing currently true about that prototype.
##
## `entry` is null for a standalone node, which has no maturity to fall back to
## and uses its own authored subtitle.
func _sub_text_for(entry: MenuEntry, placement: FrontierEntry) -> String:
	if _played.has(placement.entry_title):
		return "PLAYED"
	match placement.state:
		FrontierEntry.State.UPCOMING: return placement.standalone_subtitle
		FrontierEntry.State.RESEARCH: return "RESEARCH"
		FrontierEntry.State.FOG: return ""
	if entry == null:
		return placement.standalone_subtitle
	return entry.maturity.to_upper()


func _build_edges() -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	if not layout.route_from_catalogue:
		return _explicit_edges()
	var chain: Array[FrontierNode] = []
	for node in _nodes:
		if node.placement.kind == FrontierEntry.Kind.PROTOTYPE:
			chain.append(node)
	for i in chain.size() - 1:
		var from: FrontierNode = chain[i]
		var to: FrontierNode = chain[i + 1]
		# THE RULE: an edge takes the colour of the category it LEADS INTO. So the
		# hue changes on the edge that crosses into a new kind of proof rather
		# than one node later, and the reader sees the transition as they travel
		# it. Arrival rather than departure is also what the reference art does
		# at every category boundary.
		var category: FrontierCategory = layout.category_for(to.placement.category)
		var color: Color = style.available_stroke if category == null else category.edge_color
		# Dashed only into things that DO NOT EXIST - upcoming and fog. Research
		# was in this list and should not have been: a research strand is real,
		# live work you can go and look at, so a dashed line into it said "not
		# built yet" about something that is built. The node's own dashed ring
		# already marks it as exploratory, which is the honest signal.
		var dashed: bool = to.placement.state == FrontierEntry.State.UPCOMING \
			or to.placement.state == FrontierEntry.State.FOG
		edges.append({
			"from": from.centre(), "to": to.centre(),
			"color": Color(color, 0.9), "dashed": dashed,
			"from_radius": from.base_radius(), "to_radius": to.base_radius(),
		})
	return edges


## Sub-map edges, named node to node in the layout.
##
## Estimated edges draw dashed and dimmer whatever their tone. That is the
## proposal's honesty rule made visual: the dependency graph is a planning
## hypothesis until Aaron and Andrew validate it, and a solid line would quietly
## promote a guess into a claim.
func _explicit_edges() -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for edge in layout.edges:
		if edge == null:
			continue
		var from: FrontierNode = _node_named(edge.from_id)
		var to: FrontierNode = _node_named(edge.to_id)
		if from == null or to == null:
			push_warning("frontier map: edge names unknown node - %s -> %s"
				% [edge.from_id, edge.to_id])
			continue
		var color: Color = _edge_tone(edge.tone)
		edges.append({
			"from": from.centre(), "to": to.centre(),
			"color": Color(color, 0.55 if edge.estimated else 0.9),
			"dashed": edge.estimated,
			"curvature": edge.curvature,
			"from_radius": from.base_radius(), "to_radius": to.base_radius(),
		})
	return edges


func _edge_tone(tone: int) -> Color:
	match tone:
		FrontierEdge.Tone.STRUCTURAL: return style.available_stroke.darkened(0.25)
		FrontierEdge.Tone.WORLD: return style.upcoming_stroke
		FrontierEdge.Tone.RESEARCH: return style.research_stroke
		FrontierEdge.Tone.DEFERRED: return style.fog_stroke
	return style.selection_ring


func _node_named(id: String) -> FrontierNode:
	for node in _nodes:
		if node.placement.entry_title == id:
			return node
	return null


## "NEXT-CYCLE SIGNAL OPEN · 3 CURATED OPTIONS", as a real button.
##
## It is one of the four documented ways into the drawer and the only one that
## opens on the SIGNAL tab directly. Landing on Activity and making someone find
## the second tab is exactly the extra click the overlay exists to remove.
func _has_gateways() -> bool:
	for placement in layout.placements:
		if placement != null and placement.kind == FrontierEntry.Kind.GATEWAY:
			return true
	return false


func _build_signal_pill() -> void:
	var button := Button.new()
	button.text = layout.signal_pill
	button.focus_mode = Control.FOCUS_ALL
	button.position = Vector2(1425, 150)
	button.size = Vector2(405, 30)
	button.add_theme_font_size_override("font_size", style.small_caps_size - 1)
	button.add_theme_color_override("font_color", style.upcoming_stroke)
	var font: Font = style.caps_font(1)
	if font != null:
		button.add_theme_font_override("font", font)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(style.upcoming_stroke, 0.12)
	box.border_color = Color(style.upcoming_stroke, 0.75)
	box.set_border_width_all(1)
	box.set_corner_radius_all(15)
	button.add_theme_stylebox_override("normal", box)
	var hover: StyleBoxFlat = box.duplicate()
	hover.bg_color = Color(style.upcoming_stroke, 0.22)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(func() -> void:
		_open_activity(layout.signal_node, FrontierDrawer.Tab.SIGNAL))
	_field_root.add_child(button)


func _build_detail_panel() -> void:
	var panel := PanelContainer.new()
	# Out to the midpoint. The panel is the thing
	# that will grow - the plan is to carry the controls, findings and
	# measurements Menu2 already shows - so it gets the space now, and the
	# gateways get a tighter column. Gateway CIRCLES keep their radius; only the
	# spacing between them closes up.
	panel.position = layout.panel_rect.position
	panel.size = layout.panel_rect.size
	# A PanelContainer grows to fit its content, and the legend sits directly
	# under this one. The longest entry - Nevada, carrying both the gate note and
	# the not-built note - pushed the panel down into the legend row. Clipping
	# holds it at the authored 800x300; the copy is written short enough that
	# nothing actually reaches the clip, so this is a backstop, not a crop.
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _panel_box())
	_reference_root.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)

	_panel_glyph = Control.new()
	_panel_glyph.custom_minimum_size = Vector2(112, 112)
	_panel_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel_glyph.draw.connect(_draw_panel_glyph)
	row.add_child(_panel_glyph)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)

	_panel_title = _make_label("", style.panel_title_size, style.text_bright, 1)
	column.add_child(_panel_title)
	_panel_head = _make_label("", style.small_caps_size, style.panel_head, 2)
	column.add_child(_panel_head)

	column.add_child(_spacer(8))
	_panel_body = _make_label("", style.body_size, style.text_dim, 0)
	_panel_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_body.custom_minimum_size = Vector2(560, 0)
	column.add_child(_panel_body)

	# A step below the body text. The notes are qualifications - what the badge
	# means, why a node cannot be entered - and they should be readable without
	# competing with the sentence that says what the prototype IS. It also keeps
	# the longest entry inside the panel's authored 300px height.
	_panel_note = _make_label("", style.body_size - 2, style.text_faint, 0)
	_panel_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_note.custom_minimum_size = Vector2(560, 0)
	column.add_child(_panel_note)

	column.add_child(_spacer(0, true))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	column.add_child(bottom)

	_panel_tags = HBoxContainer.new()
	_panel_tags.add_theme_constant_override("separation", 12)
	_panel_tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_tags.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(_panel_tags)

	# Secondary, and visually quieter than the primary action. The proposal is
	# firm that opening a contribution drawer must never be something you do by
	# accident while trying to launch a prototype, so it is its own labelled
	# button rather than a second meaning for the big one.
	_activity_button = _add_button(bottom, "VIEW ACTIVITY", Rect2(0, 0, 165, 44),
		style.tab_idle_fill, style.tab_idle_stroke)
	_activity_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_activity_button.pressed.connect(func() -> void:
		_open_activity(_selected_title, FrontierDrawer.Tab.ACTIVITY))

	_launch_button = _add_button(bottom, layout.launch_label, Rect2(0, 0, 195, 44),
		style.button_fill, style.button_stroke)
	_launch_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_launch_button.pressed.connect(_on_primary_action)


func _draw_panel_glyph() -> void:
	var placement: FrontierEntry = _selected_placement()
	if placement == null or style == null:
		return
	var mid: Vector2 = _panel_glyph.size * 0.5
	var radius: float = 46.0
	var stroke: Color = style.upcoming_stroke
	if placement.state == FrontierEntry.State.RESEARCH:
		stroke = style.research_stroke
	elif _played.has(placement.entry_title):
		stroke = style.played_stroke
	_panel_glyph.draw_circle(mid, radius, style.played_fill)
	_panel_glyph.draw_arc(mid, radius, 0.0, TAU, 64, stroke, 2.0, true)
	if placement.glyph == "" or style.font == null:
		return
	var glyph_size: int = 31
	var width: float = style.font.get_string_size(
		placement.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
	_panel_glyph.draw_string(style.font, mid + Vector2(-width * 0.5, glyph_size * 0.36),
		placement.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, style.played_glyph)






## The small line mark before a category heading.
##
## One shape per kind of proof, drawn from the same vocabulary as the reference
## art: a sighting reticle for Orientation, a cube for Spatial Interaction, a
## cluster of cells for World Systems, a twist of strands for Living Systems.
## Drawn rather than imported so they take the category's colour for free and a
## fifth category needs no new asset.
func _draw_category_mark(mark: Control, category: FrontierCategory) -> void:
	var mid: Vector2 = mark.size * 0.5
	var ink: Color = category.color
	var w: float = 1.6
	match category.category:
		0: # Orientation - a reticle: you are being told where you are.
			mark.draw_arc(mid, 9.0, 0.0, TAU, 32, ink, w, true)
			mark.draw_arc(mid, 2.6, 0.0, TAU, 12, ink, w, true)
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				mark.draw_line(mid + direction * 13.0, mid + direction * 9.5, ink, w, true)
		1: # Spatial interaction - a cube seen in three-quarter view.
			var top := PackedVector2Array([
				mid + Vector2(0, -10), mid + Vector2(9, -5),
				mid + Vector2(0, 0), mid + Vector2(-9, -5), mid + Vector2(0, -10)])
			mark.draw_polyline(top, ink, w, true)
			mark.draw_line(mid + Vector2(-9, -5), mid + Vector2(-9, 5), ink, w, true)
			mark.draw_line(mid + Vector2(9, -5), mid + Vector2(9, 5), ink, w, true)
			mark.draw_line(mid + Vector2(0, 0), mid + Vector2(0, 10), ink, w, true)
			mark.draw_line(mid + Vector2(-9, 5), mid + Vector2(0, 10), ink, w, true)
			mark.draw_line(mid + Vector2(9, 5), mid + Vector2(0, 10), ink, w, true)
		2: # World systems - three cells, because a world is made of many.
			for offset in [Vector2(-5, -6), Vector2(6, 0), Vector2(-5, 7)]:
				_draw_hex(mark, mid + offset, 5.2, ink, w)
		3: # Living systems - two strands with rungs between them.
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for i in 13:
				var t: float = float(i) / 12.0
				var y: float = -11.0 + t * 22.0
				left.append(mid + Vector2(sin(t * PI * 1.6) * 6.0, y))
				right.append(mid + Vector2(-sin(t * PI * 1.6) * 6.0, y))
			mark.draw_polyline(left, ink, w, true)
			mark.draw_polyline(right, ink, w, true)
			for i in [3, 6, 9]:
				mark.draw_line(left[i], right[i], Color(ink, 0.7), 1.2, true)


func _draw_hex(on: Control, at: Vector2, radius: float, ink: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 7:
		var angle: float = TAU * float(i) / 6.0 - PI * 0.5
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
	on.draw_polyline(points, ink, width, true)


## Undifferentiated atmosphere past the last named gateway.
##
## Three circles at three sizes with three dash rhythms, plus a soft radial
## wash - enough to imply that the map continues, deliberately not enough to
## count. Drawn as concentric fading rings rather than with a blur shader,
## because a shader here would be a whole render pass for something that must
## stay quieter than every real element on the screen.
func _draw_fog_teaser(haze: Control) -> void:
	var mid: Vector2 = haze.size * 0.5
	for i in range(10, 0, -1):
		var t: float = float(i) / 10.0
		haze.draw_circle(mid, 118.0 * t, Color(style.fog_stroke, 0.022 * (1.0 - t) + 0.008))

	var blobs: Array[Vector2] = [Vector2(-20, -60), Vector2(47, -12), Vector2(-6, 61)]
	var radii: Array[float] = [17.0, 23.0, 13.0]
	for i in blobs.size():
		var at: Vector2 = mid + blobs[i]
		haze.draw_circle(at, radii[i], Color(style.background, 0.85))
		var dashes: int = 10 + i * 2
		var step: float = TAU / float(dashes)
		for d in dashes:
			if d % 2 == 1:
				continue
			haze.draw_arc(at, radii[i], float(d) * step, float(d) * step + step * 0.6,
				4, Color(style.fog_stroke, 0.55), 1.5, true)




func _build_legend() -> void:
	var swatch_colors: Array[Color] = [
		style.played_stroke, style.selection_ring, style.available_stroke,
		style.research_stroke, style.fog_stroke,
	]
	var x: float = 55.0
	for i in layout.legend_labels.size():
		var color: Color = swatch_colors[i] if i < swatch_colors.size() else style.text_faint
		var dot := Control.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size = Vector2(18, 18)
		dot.position = Vector2(x, 1010)
		_reference_root.add_child(dot)
		dot.draw.connect(_draw_legend_dot.bind(dot, color, i >= 3))
		var label := _make_label(layout.legend_labels[i], style.small_caps_size,
			style.text_legend, 1)
		label.position = Vector2(x + 26.0, 1008)
		label.size = Vector2(200, 20)
		_reference_root.add_child(label)
		x += 26.0 + _text_width(layout.legend_labels[i], style.small_caps_size, 1) + 40.0

	var gate := Control.new()
	gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gate.size = Vector2(20, 20)
	gate.position = Vector2(x, 1009)
	_reference_root.add_child(gate)
	gate.draw.connect(_draw_legend_gate.bind(gate))
	var gate_label := _make_label(layout.gate_legend_label, style.small_caps_size,
		style.text_legend, 1)
	gate_label.position = Vector2(x + 28.0, 1008)
	gate_label.size = Vector2(240, 20)
	_reference_root.add_child(gate_label)
	x += 28.0 + _text_width(layout.gate_legend_label, style.small_caps_size, 1) + 48.0

	_build_speaker(x)


## The sound switch, parked at the end of the legend.
##
## In the LEGEND rather than the header because that is where this screen already
## explains itself, and because muting is a viewer's preference rather than a
## navigation action - it should not sit beside the two controls that change what
## you are looking at.
##
## It stops the BACKGROUND TRACK only. Interface cues keep firing, so the screen
## still answers a click after the music is off - a menu that goes completely
## silent feels broken rather than quiet.
func _build_speaker(x: float) -> void:
	_speaker = Control.new()
	_speaker.size = Vector2(30, 26)
	_speaker.position = Vector2(x, 1005)
	_speaker.mouse_filter = Control.MOUSE_FILTER_STOP
	_speaker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_speaker.tooltip_text = "Mute background music"
	_reference_root.add_child(_speaker)
	_speaker.draw.connect(_draw_speaker)
	_speaker.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
			return
		if _audio == null:
			return
		_audio.toggle_muted()
		# Always audible now, since the mute no longer silences the cues - the
		# click is what confirms the press either way.
		_audio.click()
		_speaker.queue_redraw())

	var label := _make_label("SOUND", style.small_caps_size, style.text_legend, 1)
	label.position = Vector2(x + 38.0, 1008)
	label.size = Vector2(120, 20)
	_reference_root.add_child(label)


## A speaker, plus a cross through it when muted.
##
## Drawn rather than two PNGs, for the same reason the category marks are: it
## recolours with the palette and needs no import step.
func _draw_speaker() -> void:
	var muted: bool = _audio != null and _audio.is_muted()
	var ink: Color = style.text_faint if muted else style.text_legend
	var mid: Vector2 = _speaker.size * 0.5

	# Cone: a small box at the left, opening into a trapezoid.
	var body := PackedVector2Array([
		mid + Vector2(-11, -3), mid + Vector2(-6, -3), mid + Vector2(-1, -9),
		mid + Vector2(-1, 9), mid + Vector2(-6, 3), mid + Vector2(-11, 3),
		mid + Vector2(-11, -3),
	])
	_speaker.draw_polyline(body, ink, 1.6, true)

	if muted:
		# The cross replaces the waves rather than sitting on top of them - two
		# sets of marks in the same place is a smudge, not a symbol.
		_speaker.draw_line(mid + Vector2(3, -6), mid + Vector2(12, 5), ink, 1.6, true)
		_speaker.draw_line(mid + Vector2(12, -6), mid + Vector2(3, 5), ink, 1.6, true)
		return
	for i in 2:
		var r: float = 5.0 + float(i) * 4.5
		_speaker.draw_arc(mid + Vector2(-1, 0), r, -PI * 0.34, PI * 0.34, 12,
			Color(ink, 0.85 - float(i) * 0.25), 1.5, true)


func _draw_legend_dot(dot: Control, color: Color, dashed: bool) -> void:
	var mid: Vector2 = dot.size * 0.5
	dot.draw_circle(mid, 8.0, style.available_fill)
	if dashed:
		var step: float = TAU / 12.0
		for i in 12:
			if i % 2 == 1:
				continue
			dot.draw_arc(mid, 8.0, float(i) * step, float(i) * step + step * 0.6, 4, color, 1.4, true)
	else:
		dot.draw_arc(mid, 8.0, 0.0, TAU, 32, color, 1.4, true)


func _draw_legend_gate(gate: Control) -> void:
	var mid: Vector2 = gate.size * 0.5
	gate.draw_circle(mid, 9.0, style.gate_gold)
	gate.draw_arc(mid, 9.0, 0.0, TAU, 32, style.gate_gold_bright, 1.0, true)
	if style.font == null:
		return
	var width: float = style.font.get_string_size("G", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	gate.draw_string(style.font, mid + Vector2(-width * 0.5, 3.0), "G",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, style.gate_gold_ink)


# --------------------------------------------------------------------------
# Selection
# --------------------------------------------------------------------------

func _select(entry_title: String) -> void:
	_selected_title = entry_title
	for node in _nodes:
		node.selected = node.placement.entry_title == entry_title
	_refresh_panel()


func _selected_entry() -> MenuEntry:
	if catalogue == null:
		return null
	for entry in catalogue.entries:
		if entry != null and entry.title == _selected_title:
			return entry
	return null


func _selected_placement() -> FrontierEntry:
	if layout == null:
		return null
	return layout.placement_for(_selected_title)


func _refresh_panel() -> void:
	var entry: MenuEntry = _selected_entry()
	var placement: FrontierEntry = _selected_placement()
	if placement == null or _panel_title == null:
		return

	# `entry` is null for a standalone node - work placed on the map with no
	# catalogue entry behind it yet. The panel then runs entirely off the
	# placement, which is why `map_detail` is not merely an override.
	_panel_title.text = placement.label_text().replace("
", " ").to_upper()
	# A node's own head line wins over its category's. On a sub-map the category
	# is a layout band ("LIVE ARTIFACT") while the node wants to say what it IS
	# ("GATE-ESSENTIAL PROCEDURAL PROOF"), and those are different sentences.
	var category: FrontierCategory = layout.category_for(placement.category)
	_panel_head.text = placement.detail_head
	if _panel_head.text == "":
		_panel_head.text = "" if category == null else category.label
	if category != null:
		_panel_head.add_theme_color_override("font_color", category.color)
	_panel_body.text = placement.map_detail
	if _panel_body.text == "" and entry != null:
		_panel_body.text = entry.detail if entry.detail != "" else entry.blurb

	# Both notes, not one or the other. Nevada Terrain is gate-essential AND
	# unbuilt, and an `elif` here would have shown the badge explanation while
	# silently dropping the more important fact that there is nothing to enter.
	var notes: PackedStringArray = PackedStringArray()
	if placement.gate_essential:
		notes.append("The gold G marks evidence for the October Gate; it does not alter the playable tour order.")
	if placement.state == FrontierEntry.State.UPCOMING and placement.upcoming_note != "":
		notes.append(placement.upcoming_note)
	_panel_note.text = "\n\n".join(notes)

	for child in _panel_tags.get_children():
		child.queue_free()
	for tag in placement.tags:
		_panel_tags.add_child(_make_tag(tag))

	# A node that cannot be entered says so on the button instead of offering an
	# action that would fail. Same rule the brief sets for planning gateways.
	var enterable: bool = placement.is_enterable()
	var label: String = placement.action_label
	match placement.kind:
		FrontierEntry.Kind.GATEWAY:
			if label == "":
				label = "OPEN SUB-MAP" if enterable else "SUB-MAP NOT BUILT"
		FrontierEntry.Kind.PLANNING:
			enterable = false
			if label == "":
				label = "INSPECT ONLY"
		_:
			enterable = enterable and entry != null and entry.scene_path != ""
			if label == "":
				label = layout.launch_label if enterable else "NOT BUILT YET"

	_activity_button.visible = placement.activity != null

	# NEVER ACTUALLY DISABLED. A greyed-out button that cannot be pressed gives
	# no answer at all, and on this map most primary actions lead somewhere that
	# does not exist yet - inspecting a planning node, launching Nevada. The
	# button stays pressable and refuses out loud; `_on_primary_action` routes
	# every unenterable case to the refusal cue.
	_launch_button.disabled = false
	_launch_button.text = label
	# Still LOOKS unavailable - muted fill, muted border - so the refusal is not
	# a surprise. It just answers when pressed instead of swallowing the press.
	var fill: Color = style.button_fill if enterable else style.button_fill_disabled
	var stroke: Color = style.button_stroke if enterable else style.panel_stroke
	for state in ["normal", "disabled"]:
		_launch_button.add_theme_stylebox_override(state, _button_box(fill, stroke))
	_launch_button.add_theme_stylebox_override("hover",
		_button_box(fill.lightened(0.08), stroke))
	_launch_button.add_theme_color_override("font_color",
		style.text_bright if enterable else style.text_faint)

	if _panel_glyph != null:
		_panel_glyph.queue_redraw()


# --------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------

## Pulls the dragged node's route neighbours along with it, so a drag moves a
## connected piece of the graph rather than one lonely circle.
##
## The neighbours' share decays fast (0.34, then 0.12) and is measured along the
## ROUTE, not by screen distance - the map's whole claim is that the line is the
## relationship, so that is what should visibly bend when you pull on it.
func _on_node_dragged(entry_title: String) -> void:
	var index: int = -1
	for i in _nodes.size():
		if _nodes[i].placement.entry_title == entry_title:
			index = i
			break
	if index < 0:
		return
	var pull: Vector2 = _nodes[index].drag_target
	const FALLOFF: Array[float] = [0.34, 0.12]
	for step in FALLOFF.size():
		for side in [-(step + 1), step + 1]:
			var at: int = index + side
			if at < 0 or at >= _nodes.size() or _nodes[at].dragging:
				continue
			_nodes[at].drag_target = pull * FALLOFF[step]
	set_process(true)


## Everything a node was pulling returns home the moment the button comes up.
func _on_node_released(_entry_title: String) -> void:
	for node in _nodes:
		if not node.dragging:
			node.drag_target = Vector2.ZERO
	set_process(true)


## Advances every node and redraws the route while anything is moving.
##
## The edges are rebuilt from the nodes' live centres each frame, which is what
## makes the connections follow a drag instead of staying pinned to the authored
## positions. Stops itself the moment everything has settled, so a still screen
## does no per-frame work at all.
func _process(delta: float) -> void:
	if _nodes.is_empty():
		set_process(false)
		return
	var moving: bool = false
	for node in _nodes:
		if node.advance_drag(delta):
			moving = true
	if _edge_layer != null:
		_edge_layer.set_edges(_build_edges())
	if not moving:
		set_process(false)


## Confirming a node. What that MEANS depends on the node's kind, which is the
## whole reason `kind` exists - one gesture, one predictable outcome per type.
func _on_node_activated(entry_title: String) -> void:
	_select(entry_title)
	var placement: FrontierEntry = _selected_placement()
	if placement == null:
		return
	if placement.kind == FrontierEntry.Kind.GATEWAY:
		_open_sub_map(placement)
	else:
		_on_launch_pressed()


## Enters a planning sub-map. The overview's selection is remembered so BACK TO
## OVERVIEW returns you to the gateway you left through, not to the top of the
## list - the proposal asks for the last selection to be preserved.
func _open_sub_map(placement: FrontierEntry) -> void:
	if Engine.is_editor_hint():
		return
	if placement.opens_map == "" or not ResourceLoader.exists(placement.opens_map):
		_refused()
		return
	var next: FrontierLayout = load(placement.opens_map) as FrontierLayout
	if next == null:
		_refused()
		return
	if _audio != null:
		_audio.select()
	if not in_sub_map():
		_root_layout = layout
		_root_selection = _selected_title
	layout = next
	rebuild()


func back_to_overview() -> void:
	if not in_sub_map():
		return
	if _audio != null:
		_audio.select()
	layout = _root_layout
	rebuild()
	if _root_selection != "":
		_select(_root_selection)


## Opens the contextual drawer for a node without changing the current
## selection - the proposal is explicit that inspecting activity must not
## disturb where you were.
func _open_activity(node_id: String, tab: int) -> void:
	if Engine.is_editor_hint() or _drawer == null:
		return
	var placement: FrontierEntry = layout.placement_for(node_id)
	if placement == null or placement.activity == null:
		_refused()
		return
	# SWIPE, not select. The drawer slides over the map rather than opening
	# something new, and the cue should say which of those two just happened.
	if _audio != null:
		_audio.swipe()
	_drawer.style = style
	_drawer.open_for(node_id, placement.label_text().replace("
", " "), placement.activity, tab)


func _on_drawer_closed() -> void:
	# The same cue on the way out, because it is the same gesture reversed.
	if _audio != null:
		_audio.swipe()
	# Focus returns to the node the drawer was opened from, so keyboard users
	# are not dropped at the top of the map.
	var node: FrontierNode = _node_named(_selected_title)
	if node != null and node.focus_mode != Control.FOCUS_NONE:
		node.grab_focus()


func _click() -> void:
	if _audio != null:
		_audio.click()


## The error cue, for the things this map deliberately shows but cannot open:
## an UPCOMING node and the planning gateways. Silence there reads as a broken
## button; a refusal sound reads as "not yet", which is what the map means.
func _refused() -> void:
	if _audio != null:
		_audio.error()


## The panel's primary button. Routes by kind for the same reason node
## activation does: one control, one predictable outcome per node type.
func _on_primary_action() -> void:
	if Engine.is_editor_hint():
		return
	var placement: FrontierEntry = _selected_placement()
	if placement != null and placement.kind == FrontierEntry.Kind.GATEWAY:
		_open_sub_map(placement)
		return
	_on_launch_pressed()


func _on_launch_pressed() -> void:
	if Engine.is_editor_hint() or _launcher == null:
		return
	var entry: MenuEntry = _selected_entry()
	var placement: FrontierEntry = _selected_placement()
	if placement == null or entry == null or not placement.is_enterable() 			or entry.scene_path == "":
		_refused()
		return
	if _audio != null:
		_audio.select()
	_show_overlay(entry.title)
	var started: bool = await _launcher.launch(entry.scene_path)
	if not started:
		_hide_overlay()
		return
	_played[entry.title] = true
	_shell.visible = false
	_hide_overlay()


func _on_prototype_closed() -> void:
	_shell.visible = true
	# Rebuilt rather than patched so the played tick, the subtitle and the panel
	# all come from the one code path that produced them in the first place.
	var restore: String = _selected_title
	rebuild()
	if restore != "":
		_select(restore)


## The guided run-through is NOT built. Saying so plainly is the honest
## behaviour, and it is the same notice `menu2.gd` shows for the same button -
## deliberately, so the two screens do not disagree about what exists.
func _on_start_tour() -> void:
	if Engine.is_editor_hint():
		return
	# The guided run is not built, so this opens a notice rather than a tour -
	# still an opening, so it takes the select cue rather than the error one.
	if _audio != null:
		_audio.select()
	_show_notice()


func _on_explore_freely() -> void:
	if Engine.is_editor_hint():
		return
	if _audio != null:
		_audio.select()
	get_tree().change_scene_to_file(LIST_MENU_SCENE)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	# STRICT ORDER, per the proposal: close drawer, then leave sub-map, then
	# leave the Frontier Map. Anything else and Escape becomes a gamble about
	# how much you are about to lose.
	if _notice != null and _notice.visible:
		if key.keycode == RETURN_KEY:
			get_viewport().set_input_as_handled()
			_notice.visible = false
		return

	if _drawer != null and _drawer.is_open():
		if key.keycode == RETURN_KEY:
			get_viewport().set_input_as_handled()
			_drawer.close()
		return

	if _launcher != null and _launcher.is_busy():
		return

	if _launcher != null and _launcher.is_running():
		if key.keycode == RETURN_KEY or key.keycode == PROTOTYPE_RETURN_KEY:
			get_viewport().set_input_as_handled()
			_launcher.close()
		return

	if key.keycode == RETURN_KEY and in_sub_map():
		get_viewport().set_input_as_handled()
		back_to_overview()
		return

	# Left/right walk the tour order, which is the only ordering this screen has.
	if key.keycode == KEY_RIGHT or key.keycode == KEY_LEFT:
		var step: int = 1 if key.keycode == KEY_RIGHT else -1
		var index: int = _placed_titles.find(_selected_title)
		if index >= 0 and _placed_titles.size() > 0:
			_select(_placed_titles[posmod(index + step, _placed_titles.size())])
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_on_launch_pressed()


# --------------------------------------------------------------------------
# Overlay and notice
# --------------------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_overlay as ColorRect).color = Color(style.background, 0.94)
	_overlay.visible = false
	add_child(_overlay)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(560, 0)
	column.add_theme_constant_override("separation", 14)
	_overlay.add_child(column)

	_overlay_title = _make_label("", style.panel_title_size, style.text_bright, 2)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_overlay_title)

	_overlay_bar = ProgressBar.new()
	_overlay_bar.custom_minimum_size = Vector2(560, 6)
	_overlay_bar.max_value = 1.0
	_overlay_bar.show_percentage = false
	column.add_child(_overlay_bar)

	_overlay_stage = _make_label("", style.small_caps_size, style.text_faint, 2)
	_overlay_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_overlay_stage)


func _show_overlay(title: String) -> void:
	if _overlay == null:
		return
	_overlay_title.text = title.to_upper()
	_overlay_stage.text = PrototypeLauncher.STAGE_LOADING
	_overlay_bar.value = 0.0
	_overlay.visible = true


func _hide_overlay() -> void:
	if _overlay != null:
		_overlay.visible = false


func _on_launch_progress(value: float) -> void:
	if _overlay_bar != null:
		_overlay_bar.value = value


func _on_launch_stage(stage: String) -> void:
	if _overlay_stage != null:
		_overlay_stage.text = stage


func _on_launch_failed(message: String) -> void:
	if _panel_note != null:
		_panel_note.text = message
	_hide_overlay()


func _build_notice() -> void:
	_notice = ColorRect.new()
	_notice.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_notice as ColorRect).color = Color(style.background, 0.93)
	_notice.visible = false
	_notice.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_notice.visible = false)
	add_child(_notice)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 16)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_child(column)

	var heading := _make_label("COMING SOON", style.panel_title_size, style.text_bright, 3)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	var body := _make_label(
		"The guided run-through of all %d in order isn't built yet.\nPick one from the map in the meantime."
			% _prototype_count(), style.body_size, style.text_dim, 0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(body)

	var hint := _make_label("ESC OR CLICK TO GO BACK", style.small_caps_size, style.text_faint, 2)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _show_notice() -> void:
	if _notice != null:
		_notice.visible = true


# --------------------------------------------------------------------------
# Helpers - every one of these reads the style resource, never a literal.
# --------------------------------------------------------------------------

## Measured width of a caps string, or a rough estimate when no font is loaded.
##
## The legend lays itself out by measuring each label rather than by fixed
## columns, so a renamed state does not overlap its neighbour. Falling back to an
## estimate keeps that working in the editor before the font resource resolves,
## which otherwise crashed the whole @tool preview on a null font.
func _text_width(text: String, font_size: int, tracking: int) -> float:
	var font: Font = style.caps_font(tracking)
	if font == null:
		return float(text.length()) * float(font_size) * 0.62
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _make_label(text: String, font_size: int, color: Color, tracking: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	var font: Font = style.caps_font(tracking)
	if font != null:
		label.add_theme_font_override("font", font)
	return label


func _add_label(parent: Control, text: String, at: Vector2, font_size: int,
		color: Color, tracking: int) -> Label:
	var label := _make_label(text, font_size, color, tracking)
	label.position = at
	parent.add_child(label)
	return label


func _add_tab(text: String, at: Vector2, active: bool, on_pressed: Callable) -> Button:
	var button := _add_button(_reference_root, text, Rect2(at.x, at.y, 214, 54),
		style.tab_active_fill if active else style.tab_idle_fill,
		style.tab_active_stroke if active else style.tab_idle_stroke)
	button.add_theme_color_override("font_color",
		style.tab_active_stroke if active else style.text_dim)
	button.disabled = active
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	return button


func _add_button(parent: Control, text: String, rect: Rect2, fill: Color, stroke: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.custom_minimum_size = rect.size
	if parent == _reference_root:
		button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", style.small_caps_size + 1)
	button.add_theme_color_override("font_color", style.text_bright)
	button.add_theme_color_override("font_disabled_color", style.text_faint)
	var font: Font = style.caps_font(2)
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_stylebox_override("normal", _button_box(fill, stroke))
	button.add_theme_stylebox_override("hover", _button_box(style.button_fill_hover, stroke))
	button.add_theme_stylebox_override("pressed", _button_box(stroke.darkened(0.4), stroke))
	button.add_theme_stylebox_override("disabled", _button_box(fill, stroke))
	button.add_theme_stylebox_override("focus", _button_box(fill, style.focus_ring))
	parent.add_child(button)
	return button


func _button_box(fill: Color, stroke: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = stroke
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = style.panel_fill
	box.border_color = style.panel_stroke
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	return box


func _make_tag(text: String) -> Control:
	var tint: Color = style.panel_head
	if text.to_upper().contains("GATE"):
		tint = style.gate_gold
	elif text.to_upper().contains("VOXEL"):
		tint = style.upcoming_stroke
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(tint, 0.12)
	box.border_color = Color(tint, 0.75)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(_make_label(text, style.small_caps_size - 1, tint, 1))
	return panel


func _spacer(height: int, expand: bool = false) -> Control:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, height)
	if expand:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer
