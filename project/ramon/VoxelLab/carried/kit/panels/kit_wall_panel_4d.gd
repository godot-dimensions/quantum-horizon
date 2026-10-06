@tool
extends Node4D

## Kit: one wall panel, hung on a wall like a picture. Two of them, an introduction and a research
## panel, make a room's walls (Ramon's Figma handoff, 5 Oct 2026; the template is kit_panel_spec.gd,
## the words kit_room_info.gd, the live numbers a source such as kit_panel_source_showcase.gd).
##
## WHERE IT HANGS. Give it a room (`room_path`, a KitRoom, kit_room_4d.gd) and a wall of it: its
## name (`wall_name`, from the room's plan, kit_room_plan.gd: "left_corner", "right", ...), an edge
## number in a polygon room (any angle: the Creation Lab's angled walls take it as its square ones
## do) or a side ("n", "s", "w", "e") in a rectangular one. It always sits in the middle of that wall
## (Ramon, 5 Oct: "text panels should always be align to mid of a wall in the horizontal"), its foot
## `foot` off the floor, printed into the wall's own surface: the room paints the whole wall in code
## blue for it, however long the wall and whatever the panel's size (a claim, never saved with the
## scene), and the room's light and shadow fall on it as on the paint around it. With no room it
## brings its own wall: a blue slab a little bigger than the panel, standing on the node's floor and
## facing the node's +Z, so it can stand anywhere at any angle.
##
## ONE SIZE. 9.6 x 5.9 m in every prototype (kit_panel_spec.gd UNIT_M), whatever the wall. A wall too
## short or too low for it is flagged (a warning on the node and, in the editor, a red frame), never
## a smaller panel. A room's two panels are kept a pair by kit_wall_panels_4d.gd: the same size (the
## kit's, or both fitted to their walls together), the same height, the same words and data.
##
## LIVE. The panel is a 2D page in its own viewport (kit_panel_intro.gd, kit_panel_research.gd),
## every part a node of its own; it asks its source `poll_hz` times a second and draws again only
## when what it shows has changed or while it animates. The introduction lights a shortcut's icon
## when its control is used. In the editor it shows the room's words and the Figma's reference
## numbers, so it can be placed by eye.
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/VoxelLab/carried/kit/panels/kit_panel_spec.gd")
const Intro := preload("res://ramon/VoxelLab/carried/kit/panels/kit_panel_intro.gd")
const Research := preload("res://ramon/VoxelLab/carried/kit/panels/kit_panel_research.gd")
const Info := preload("res://ramon/VoxelLab/carried/kit/panels/kit_room_info.gd")
const Build := preload("res://ramon/VoxelLab/carried/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/VoxelLab/carried/LabKit/lab_grid.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
## Which of the two panels.
@export_enum("intro", "research") var kind: String = "intro":
	set(v):
		kind = v
		_later()
## The room's words (kit_room_info.gd).
@export var info: Resource:
	set(v):
		info = v
		_later()
## Where its live data comes from (a node with fill() and research(), e.g. kit_panel_source_showcase.gd).
@export var source: NodePath
## Off: no panel, its wall back to the room's own.
@export var enabled: bool = true:
	set(v):
		enabled = v
		_later()

@export_group("Placement")
## The room it hangs in (empty: freestanding, on a wall of its own).
@export var room_path: NodePath:
	set(v):
		room_path = v
		_later()
## The wall by its name in the room's plan (empty: `wall_side` / `wall_edge`).
@export var wall_name: String = "":
	set(v):
		wall_name = v
		_later()
## "edge" for a polygon room's edge `wall_edge`; a side for a rectangular room.
@export_enum("edge", "n", "s", "w", "e") var wall_side: String = "edge":
	set(v):
		wall_side = v
		_later()
@export var wall_edge: int = 0:
	set(v):
		wall_edge = v
		_later()
## Its lower edge above the floor, metres.
@export var foot: float = Spec.FOOT_M:
	set(v):
		foot = v
		_later()

@export_group("Freestanding")
## Wall left round the panel when it brings its own: sides, top (metres).
@export var slab_margin: Vector2 = Vector2(0.6, 0.6):
	set(v):
		slab_margin = v
		_later()
@export var slab_thickness: float = 0.3:
	set(v):
		slab_thickness = v
		_later()

@export_group("Look")
## How much the print glows in the bright mood (the dark mood adds 0.15), as the lesson wall's paint.
@export_range(0.0, 1.0, 0.01) var glow: float = 0.15:
	set(v):
		glow = v
		_retarget()
## Pixels a unit it is drawn at.
@export_range(1.0, 6.0, 0.25) var ppu: float = Spec.PPU:
	set(v):
		ppu = v
		_later()
## Times a second it asks its source what to show.
@export_range(1.0, 30.0, 1.0) var poll_hz: float = 10.0

var page: Control
## Set by its pair (kit_wall_panels_4d.gd): both panels of a room are always this much of the kit size.
var scale_factor: float = 1.0
var _vp: SubViewport
var _slab: MeshInstance4D
var _claimed: Variant = null
var _claimed_room: Node
var _queued: bool = false
var _key: String = ""
var _sig: int = 0
var _poll: float = 0.0
var _was_busy: bool = true
var _too_short: bool = false
var _warnings: PackedStringArray = PackedStringArray()


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func _ready() -> void:
	rebuild()


func _exit_tree() -> void:
	_release()


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func _retarget() -> void:
	_key = ""


## The panel's size in metres: the kit's, times its pair's scale.
func panel_m() -> Vector2:
	return Spec.panel_m() * scale_factor


func set_scale_factor(s: float) -> void:
	if not is_equal_approx(s, scale_factor):
		scale_factor = s
		_later()


## How big the panel could be on its wall, as a share of the kit size: the room left along the wall
## round its place (`margin.x` either side) and above it (`margin.y` under the top). No room: any.
func fit_scale(margin: Vector2, at_foot: float) -> float:
	var room: Node = _room()
	if room == null or not bool(room.call("has_wall", wall())):
		return INF
	var ws: Vector2 = room.call("wall_span", wall())
	var mid: float = (ws.x + ws.y) * 0.5
	var room_w: float = (minf(mid - ws.x, ws.y - mid) - margin.x) * 2.0
	var room_h: float = float(room.call("wall_height")) - at_foot - margin.y
	var pm: Vector2 = Spec.panel_m()
	return maxf(0.0, minf(room_w / pm.x, room_h / pm.y))


func _room() -> Node:
	if room_path.is_empty():
		return null
	var r: Node = get_node_or_null(room_path)
	return r if r != null and r.has_method("print_targets") else null


## The wall it hangs on: an edge number or a side.
func wall() -> Variant:
	if not wall_name.is_empty():
		return wall_name
	return wall_edge if wall_side == "edge" else wall_side


static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


func _release() -> void:
	if _claimed != null and is_instance_valid(_claimed_room):
		_claimed_room.call("release_wall", _claimed, self)
	_claimed = null
	_claimed_room = null


func rebuild() -> void:
	Build.clear(self)
	page = null
	_vp = null
	_slab = null
	_key = ""
	_sig = 0
	var room: Node = _room()
	if not enabled or info == null:
		_release()
		update_configuration_warnings()
		return
	# The page, in a viewport of its own.
	_vp = SubViewport.new()
	_vp.name = "PanelView"
	_vp.size = Vector2i(int(ceil(Spec.PANEL.x * ppu)), int(ceil(Spec.PANEL.y * ppu)))
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.msaa_2d = Viewport.MSAA_4X
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.set_meta(Build.GENERATED, true)
	add_child(_vp)
	if kind == "research":
		page = Research.new()
		(page as Object).call("set_layout", String(info.get("research_layout")))
	else:
		page = Intro.new()
	page.name = "Intro" if kind == "intro" else "Research"
	_vp.add_child(page)
	page.call("setup", ppu)
	# Its wall: the room's, claimed in code blue, or one of its own.
	if room != null and bool(room.call("has_wall", wall())):
		if not _same(_claimed, wall()) or _claimed_room != room:
			_release()
		# Its whole wall blue, split where the panel begins and ends (a piece of wall carries one
		# picture).
		var span: Vector2 = _span(room)
		room.call("claim_wall", wall(), "blue", self, span.x, span.y)
		_claimed = wall()
		_claimed_room = room
	else:
		_release()
		if room == null:
			_build_slab()
	_show(_data())
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	update_configuration_warnings()


## For the plan view (kit_plan_view.gd): [room, wall, from, to] along that wall, or [] if it is not
## on a room's wall.
func plan_mark() -> Array:
	var room: Node = _room()
	if not enabled or room == null or not bool(room.call("has_wall", wall())):
		return []
	var sp: Vector2 = _span(room)
	return [room, room.call("wall_key", wall()), sp.x, sp.y]


## Where along its wall the panel runs, centred on it: Vector2(from, to), metres.
func _span(room: Node) -> Vector2:
	var ws: Vector2 = room.call("wall_span", wall())
	var mid: float = (ws.x + ws.y) * 0.5
	var w: float = panel_m().x
	return Vector2(mid - w * 0.5, mid + w * 0.5)


func _build_slab() -> void:
	var pm: Vector2 = panel_m()
	var w: float = pm.x + slab_margin.x * 2.0
	var h: float = foot + pm.y + slab_margin.y
	# The physics is box-only and square to the world: a slab turned off the axes gets no collision
	# rather than a box the size of its whole footprint.
	var z: Vector4 = global_basis * Vector4(0, 0, 1, 0) if is_inside_tree() else Vector4(0, 0, 1, 0)
	var square: bool = absf(z.x) < 0.001 or absf(z.z) < 0.001
	_slab = Build.box(self, "Slab", Vector3(0, h * 0.5, -slab_thickness * 0.5), Vector3(w, h, slab_thickness), Style.code_swatch("blue"), square)


# -- what it shows -----------------------------------------------------------------------------------

func _src() -> Node:
	if Engine.is_editor_hint() or source.is_empty():
		return null
	return get_node_or_null(source)


func _fill(text: String) -> String:
	var src: Node = _src()
	if src != null and src.has_method("fill"):
		return String(src.call("fill", text))
	# The editor's preview: the words as they would read with the goat on the plinth.
	return text.replace("{name}", "goat").replace("{balls}", "24").replace("{action}", "Add a ball")


func _data() -> Dictionary:
	if info == null:
		return {}
	if kind == "intro":
		var controls: Array = []
		for it in info.get("interactions"):
			controls.append([String(it[0]), _fill(String(it[1]))])
		return {"header_left": String(info.call("intro_header")), "header_right": String(info.get("status")),
			"title": String(info.get("title")), "lead": _fill(String(info.get("lead"))), "body": _fill(String(info.get("description"))),
			"heading": String(info.get("controls_heading")), "controls": controls}
	var src: Node = _src()
	if src != null and src.has_method("research"):
		return src.call("research", info)
	var d: Dictionary = Research.sample(String(info.get("research_layout")))
	d["header_left"] = String(info.call("research_header"))
	d["header_right"] = String(info.get("research_status"))
	return d


func _show(d: Dictionary) -> void:
	if page == null:
		return
	var sig: int = hash(str(d))
	if sig == _sig:
		return
	_sig = sig
	page.call("refresh", d)
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	if page == null or _vp == null:
		return
	if not Engine.is_editor_hint():
		_poll -= delta
		if _poll <= 0.0:
			_poll = 1.0 / maxf(poll_hz, 1.0)
			_show(_data())
		var busy: bool = bool(page.call("tick", delta))
		if busy or _was_busy:
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		_was_busy = busy
	_print()


func _input(event: InputEvent) -> void:
	if kind != "intro" or page == null or Engine.is_editor_hint():
		return
	var lit: String = ""
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				lit = "wheel"
			MOUSE_BUTTON_RIGHT:
				lit = "rdrag"
			MOUSE_BUTTON_LEFT:
				lit = "click"
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kc: Key = (event as InputEventKey).keycode
		if kc == KEY_LEFT or kc == KEY_RIGHT:
			lit = "arrows"
		else:
			lit = "key:" + OS.get_keycode_string(kc)
	if not lit.is_empty():
		page.call("flash", lit)


# -- on the wall ---------------------------------------------------------------------------------------

func _print() -> void:
	var tex: Texture2D = _vp.get_texture()
	var pm: Vector2 = panel_m()
	var targets: Array = []
	var room: Node = _room()
	var short: bool = false
	if is_instance_valid(_slab):
		targets = [[_slab, Vector4(0, 0, 1, 0), Rect2(Vector2(slab_margin.x, foot), pm)]]
	elif room != null and bool(room.call("has_wall", wall())):
		var span: Vector2 = room.call("wall_span", wall())
		var at: Vector2 = _span(room)
		var a0: float = at.x
		var a1: float = at.y
		short = a0 < span.x - 0.001 or a1 > span.y + 0.001 or foot + pm.y > float(room.call("wall_height")) + 0.001
		targets = room.call("print_targets", wall(), a0, a1, foot, foot + pm.y)
	if short != _too_short:
		_too_short = short
		update_configuration_warnings()
	if page != null and bool(page.get("warn")) != (short and Engine.is_editor_hint()):
		page.set("warn", short and Engine.is_editor_hint())
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var key: String = Style.mood
	for t in targets:
		key += ":%d" % (t[0] as Object).get_instance_id()
	if key == _key:
		return
	_key = key
	var g: float = glow + (0.15 if Style.mood == "dark" else 0.0)
	for t in targets:
		var m: TetraMaterial4D = (t[0] as MeshInstance4D).material_override as TetraMaterial4D
		if m == null:
			continue
		LabGrid.set_print(m, tex, t[1], t[2], Color.WHITE, g)
		LabGrid.set_print_strength(m, 1.0)
		m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)


func apply_mood(_m: String, _instant: bool = false) -> void:
	_key = ""
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Where the panel's middle is in the world and the way it faces, for the legibility check.
func panel_frame() -> Array:
	var pm: Vector2 = panel_m()
	var room: Node = _room()
	if room != null and bool(room.call("has_wall", wall())):
		var fr: Array = room.call("wall_frame", wall())
		var centre2: Vector2 = fr[0]
		var normal2: Vector2 = fr[1]
		var r4: Node4D = room as Node4D
		var c4: Vector4 = r4.global_position + Vector4(centre2.x, foot + pm.y * 0.5, centre2.y, 0.0)
		return [c4, Vector4(normal2.x, 0.0, normal2.y, 0.0)]
	var n4: Vector4 = global_basis * Vector4(0, 0, 1, 0)
	return [global_position + global_basis * Vector4(0, foot + pm.y * 0.5, 0, 0), n4.normalized()]


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if info == null:
		out.append("Give it the room's words: a kit_room_info.gd resource in `info`.")
	if not room_path.is_empty():
		var room: Node = _room()
		if room == null:
			out.append("`room_path` is not a KitRoom (kit_room_4d.gd).")
		elif not bool(room.call("has_wall", wall())):
			out.append("That room has no wall %s." % str(wall()))
	if _too_short:
		out.append("The wall is too short or too low for a %.1f x %.1f m panel; the panel is never made smaller on its own. Lengthen the wall, lower its foot, pick a longer wall, or let its pair (kit_wall_panels_4d.gd) fit both panels to their walls." % [panel_m().x, panel_m().y])
	if page != null:
		for p in page.call("overflowed"):
			out.append("Text runs over its lines (never shrunk; shorten it): " + String(p))
	return out
