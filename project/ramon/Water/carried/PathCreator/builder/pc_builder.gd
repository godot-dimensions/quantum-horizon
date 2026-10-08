extends Control

## PathCreator: the builder, a mode of the running dev space (F4). The view goes straight down over
## where you were, still the live slice, and every route graph in the space is drawn over it: nodes
## coloured by their W (blue kata, white at W 0, warm ana), each one's W band as a halo, what is off
## the slice dimmed. You edit the graph files the scene loaded (graphs/*.tres), and the paths on the
## floor follow as you drag. Ramon, 5 Oct: "maybe we could also design a path builder where i have
## access to a top view ... and as we play we can position stuff".
##
## MOUSE   left: pick a node, drag it            wheel: zoom (over a node: its W, shift: its band)
##         middle or right drag: pan             the W lane (bottom): drag a node up or down in W
## KEYS    N  new node at the mouse, joined from the picked one (1-5 pick its kind: start, chord,
##            bend, junction, destination)
##         X  split the route under the mouse with a chord     C  join the picked node to the hovered
##         Del  remove the picked node   K  its kind   S  a destination's state   F  its frame
##         R  round the corner under the mouse (or the picked one) with chords, the sheet's curve;
##            R on a curve again: wider (2, 4, 7 m), then sharp again
##         P / M  the hovered route's priority / its W mode (static, here, follow, reveal)
##         L  the next library for just this symbol (the picked node's, or the hovered route's
##            chevron): one slot at a time (Ramon: "toggle not entire sets at once, but subicons
##            separately"); F5 still changes every slot
##         [ ]  the slice through W   G  snap to 0.25 m   Ctrl+Z / Ctrl+Y  undo, redo
##         T  walk from here: the player put at the mouse, at the slice's W, and back to walking
##         Ctrl+S  save every graph   F4  back to walking
##
## The panels are black glass (kit_style.gd: screens and overlays are black).
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/Water/carried/PathCreator/path_spec.gd")
const Style := preload("res://ramon/Water/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/Water/carried/LabKit/lab_print.gd")
const KIND_KEYS := {KEY_1: "start", KEY_2: "chord", KEY_3: "bend", KEY_4: "junction", KEY_5: "destination"}
const LANE_H := 190.0
## All the builder's text at this times its first sizes (Ramon, 5 Oct: "make the text bigger"), and
## the panel wide enough for it.
const TEXT := 1.5
const PANEL_W := 500.0
const UNDO_MAX := 60

var space: Node            # pathcreator_4d.gd
var cam: Camera4D          # the builder's own, straight down
var slice_w: float = 0.0
var snap: bool = true
var add_kind: String = "bend"

var _pick: Array = []       # [network, node id]
var _hover_node: Array = []
var _hover_edge: Array = []  # [network, edge index]
var _drag: bool = false
var _lane_drag: bool = false
var _pan: bool = false
var _pan_from: Vector2
var _cam_from: Vector4
var _undo: Array = []
var _redo: Array = []
var _saved_note: String = ""
var _mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	# Under a CanvasLayer there is no parent Control to anchor to: the builder takes the window's size.
	fit()
	get_viewport().size_changed.connect(fit)


func fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


# -- the view ------------------------------------------------------------------------------------

func view_height() -> float:
	return float(cam.get("orthographic_size")) if cam != null else 30.0


func to_world(sp: Vector2) -> Vector2:
	var k: float = view_height() / maxf(size.y, 1.0)
	return Vector2(cam.global_position.x, cam.global_position.z) + (sp - size * 0.5) * k


func to_screen(x: float, z: float) -> Vector2:
	var k: float = maxf(size.y, 1.0) / view_height()
	return size * 0.5 + (Vector2(x, z) - Vector2(cam.global_position.x, cam.global_position.z)) * k


func px_per_m() -> float:
	return maxf(size.y, 1.0) / view_height()


func set_slice(w: float) -> void:
	slice_w = clampf(w, -Spec.W_REACH, Spec.W_REACH)
	if cam != null:
		cam.global_position = Vector4(cam.global_position.x, cam.global_position.y, cam.global_position.z, slice_w)
	queue_redraw()


func networks() -> Array:
	return space.call("networks") if space != null else []


static func w_color(w: float, a: float = 1.0) -> Color:
	# Kata cool blue, W 0 white, ana warm: the Combined view's convention of colouring by side.
	var t: float = clampf(w / 8.0, -1.0, 1.0)
	var c: Color = Color(1, 1, 1).lerp(Color(1.0, 0.62, 0.25), t) if t >= 0.0 else Color(1, 1, 1).lerp(Color(0.35, 0.62, 1.0), -t)
	return Color(c, a)


# -- picking ----------------------------------------------------------------------------------------

func _node_at(sp: Vector2) -> Array:
	var best: Array = []
	var best_d: float = 14.0
	for net in networks():
		var g: Resource = net.get("graph")
		if g == null:
			continue
		for n in g.nodes:
			var p: Vector4 = n["pos"]
			var d: float = to_screen(p.x, p.z).distance_to(sp)
			if d < best_d:
				best_d = d
				best = [net, int(n["id"])]
	return best


func _edge_at(sp: Vector2) -> Array:
	var best: Array = []
	var best_d: float = 10.0
	for net in networks():
		var g: Resource = net.get("graph")
		if g == null:
			continue
		for i in g.edges.size():
			var e: Dictionary = g.edges[i]
			var a: Vector4 = g.call("node", int(e["from"])).get("pos", Vector4.ZERO)
			var b: Vector4 = g.call("node", int(e["to"])).get("pos", Vector4.ZERO)
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(sp, to_screen(a.x, a.z), to_screen(b.x, b.z))
			var d: float = q.distance_to(sp)
			if d < best_d:
				best_d = d
				best = [net, i]
	return best


func _graph_of(sel: Array) -> Resource:
	return (sel[0] as Node).get("graph") if not sel.is_empty() else null


func _picked_node() -> Dictionary:
	if _pick.is_empty():
		return {}
	return _graph_of(_pick).call("node", int(_pick[1]))


# -- undo ---------------------------------------------------------------------------------------------

func _snapshot() -> Array:
	var out: Array = []
	for net in networks():
		var g: Resource = net.get("graph")
		if g != null:
			out.append([g, (g.nodes as Array).duplicate(true), (g.edges as Array).duplicate(true), int(g.get("next_id"))])
	return out


func _restore(snap_: Array) -> void:
	for s in snap_:
		var g: Resource = s[0]
		g.nodes = (s[1] as Array).duplicate(true)
		g.edges = (s[2] as Array).duplicate(true)
		g.set("next_id", int(s[3]))
		g.emit_changed()


func _before_edit() -> void:
	_undo.append(_snapshot())
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()
	_redo.clear()
	_saved_note = "unsaved changes"


func _changed(g: Resource) -> void:
	if g != null:
		g.emit_changed()
	queue_redraw()


# -- input ------------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse = mm.position
		if _pan:
			var k: float = view_height() / maxf(size.y, 1.0)
			var d: Vector2 = (mm.position - _pan_from) * k
			cam.global_position = Vector4(_cam_from.x - d.x, _cam_from.y, _cam_from.z - d.y, slice_w)
		elif _drag and not _pick.is_empty():
			var n: Dictionary = _picked_node()
			if not n.is_empty():
				var wp: Vector2 = to_world(mm.position)
				if snap:
					wp = wp.snapped(Vector2(0.25, 0.25))
				var p: Vector4 = n["pos"]
				n["pos"] = Vector4(wp.x, p.y, wp.y, p.w)
				_changed(_graph_of(_pick))
		elif _lane_drag and not _pick.is_empty():
			var n2: Dictionary = _picked_node()
			if not n2.is_empty():
				var p2: Vector4 = n2["pos"]
				var w: float = _lane_w(mm.position.y)
				n2["pos"] = Vector4(p2.x, p2.y, p2.z, snappedf(w, 0.25) if snap else w)
				_changed(_graph_of(_pick))
		else:
			_hover_node = _node_at(mm.position)
			_hover_edge = [] if not _hover_node.is_empty() else _edge_at(mm.position)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_mouse = mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.position.y > size.y - LANE_H and not _pick.is_empty():
					_before_edit()
					_lane_drag = true
				else:
					_pick = _node_at(mb.position)
					if not _pick.is_empty():
						_before_edit()
						_drag = true
			else:
				_drag = false
				_lane_drag = false
		elif mb.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_pan = mb.pressed
			_pan_from = mb.position
			_cam_from = cam.global_position
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var up: bool = mb.button_index == MOUSE_BUTTON_WHEEL_UP
			var over: Array = _node_at(mb.position)
			if not over.is_empty():
				_before_edit()
				var n: Dictionary = _graph_of(over).call("node", int(over[1]))
				if mb.shift_pressed:
					n["band"] = clampf(float(n.get("band", 1.2)) + (0.2 if up else -0.2), 0.2, Spec.W_REACH * 2.0)
				else:
					var p: Vector4 = n["pos"]
					n["pos"] = Vector4(p.x, p.y, p.z, clampf(p.w + (0.25 if up else -0.25), -Spec.W_REACH, Spec.W_REACH))
				_pick = over
				_changed(_graph_of(over))
			else:
				cam.set("orthographic_size", clampf(view_height() * (1.0 / 1.15 if up else 1.15), 4.0, 140.0))
		queue_redraw()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	var handled: bool = true
	if k.ctrl_pressed and k.keycode == KEY_Z:
		if not _undo.is_empty():
			_redo.append(_snapshot())
			_restore(_undo.pop_back())
	elif k.ctrl_pressed and k.keycode == KEY_Y:
		if not _redo.is_empty():
			_undo.append(_snapshot())
			_restore(_redo.pop_back())
	elif k.ctrl_pressed and k.keycode == KEY_S:
		save_all()
	elif KIND_KEYS.has(k.keycode):
		add_kind = String(KIND_KEYS[k.keycode])
	else:
		match k.keycode:
			KEY_N:
				_add_node()
			KEY_X:
				_split_edge()
			KEY_C:
				_connect()
			KEY_DELETE, KEY_BACKSPACE:
				_delete()
			KEY_R:
				_round()
			KEY_K:
				_cycle_node("kind", (load("res://ramon/Water/carried/PathCreator/graph/path_graph.gd") as Script).get_script_constant_map()["KINDS"])
			KEY_S:
				_cycle_node("state", ["arrival", "available", "focused", "completed"])
			KEY_F:
				_cycle_node("frame", ["none", "rect", "round"])
			KEY_P:
				_cycle_edge("priority", ["primary", "secondary"])
			KEY_M:
				_cycle_edge("w_mode", ["static", "here", "follow", "reveal"])
			KEY_L:
				_cycle_slot()
			KEY_BRACKETLEFT:
				set_slice(slice_w - 0.25)
			KEY_BRACKETRIGHT:
				set_slice(slice_w + 0.25)
			KEY_G:
				snap = not snap
			KEY_T:
				# Walk from here: at the mouse, at the slice's W.
				var wp: Vector2 = to_world(_mouse)
				space.call("go_to", Vector4(wp.x, 0.05, wp.y, slice_w))
				space.call("set_build", false)
			_:
				handled = false
	if handled:
		queue_redraw()
		get_viewport().set_input_as_handled()


# -- edits --------------------------------------------------------------------------------------------

func _target_net() -> Node:
	if not _pick.is_empty():
		return _pick[0]
	var nets: Array = networks()
	return nets[0] if not nets.is_empty() else null


func _add_node() -> void:
	var net: Node = _target_net()
	if net == null or net.get("graph") == null:
		return
	var g: Resource = net.get("graph")
	_before_edit()
	var wp: Vector2 = to_world(_mouse)
	if snap:
		wp = wp.snapped(Vector2(0.25, 0.25))
	var from: Dictionary = _picked_node()
	var w: float = float((from["pos"] as Vector4).w) if not from.is_empty() else slice_w
	var band: float = float(from.get("band", 1.2)) if not from.is_empty() else 1.2
	var id: int = g.call("add_node", add_kind, Vector4(wp.x, 0.0, wp.y, w), {"band": band})
	if not from.is_empty():
		var pri: String = "primary"
		var mode: String = "static"
		var eband: float = 1.2
		for e in g.edges:
			if int(e["to"]) == int(from["id"]) or int(e["from"]) == int(from["id"]):
				pri = String(e["priority"])
				mode = String(e["w_mode"])
				eband = float(e.get("band", 1.2))
				break
		g.call("add_edge", int(from["id"]), id, pri, mode, eband)
	_pick = [net, id]
	_changed(g)


func _split_edge() -> void:
	var he: Array = _edge_at(_mouse)
	if he.is_empty():
		return
	var g: Resource = _graph_of(he)
	_before_edit()
	var e: Dictionary = g.edges[int(he[1])]
	var a: Vector4 = g.call("node", int(e["from"]))["pos"]
	var b: Vector4 = g.call("node", int(e["to"]))["pos"]
	var wp: Vector2 = Geometry2D.get_closest_point_to_segment(to_world(_mouse), Vector2(a.x, a.z), Vector2(b.x, b.z))
	var t: float = Vector2(wp.x - a.x, wp.y - a.z).length() / maxf(Vector2(b.x - a.x, b.z - a.z).length(), 1e-4)
	var id: int = g.call("add_node", "chord", Vector4(wp.x, 0.0, wp.y, lerpf(a.w, b.w, t)), {"band": float(g.call("node", int(e["from"])).get("band", 1.2))})
	var to: int = int(e["to"])
	e["to"] = id
	g.call("add_edge", id, to, String(e["priority"]), String(e["w_mode"]), float(e.get("band", 1.2)))
	_pick = [he[0], id]
	_changed(g)


func _connect() -> void:
	var over: Array = _node_at(_mouse)
	if _pick.is_empty() or over.is_empty() or over[0] != _pick[0] or int(over[1]) == int(_pick[1]):
		return
	var g: Resource = _graph_of(_pick)
	_before_edit()
	g.call("add_edge", int(_pick[1]), int(over[1]), "primary", "static")
	_changed(g)


func _delete() -> void:
	if _pick.is_empty():
		return
	var g: Resource = _graph_of(_pick)
	_before_edit()
	g.call("remove_node", int(_pick[1]))
	_pick = []
	_changed(g)


## The curve tool (path_graph.gd round_corner): R on a corner rounds it at the first radius, R on
## one of a curve's chords takes it to the next radius, and past the widest makes it sharp again.
func _round() -> void:
	var over: Array = _node_at(_mouse)
	if over.is_empty():
		over = _pick
	if over.is_empty():
		return
	var g: Resource = _graph_of(over)
	var n: Dictionary = g.call("node", int(over[1]))
	if n.is_empty():
		return
	_before_edit()
	var radii: Array = Spec.CURVE_RADII
	if n.has("curve"):
		var asked: float = float(n.get("curve_r", radii[0]))
		var nid: int = g.call("sharpen", int(n["curve"]))
		_pick = [over[0], nid]
		for r in radii:
			if float(r) > asked + 0.01:
				var cid: int = g.call("round_corner", nid, float(r))
				_pick = [over[0], int((g.call("curve_nodes", cid) as Array)[0])] if cid > 0 else [over[0], nid]
				_saved_note = "curve: %.0f m" % float(r)
				break
		if g.call("node", int(_pick[1])).get("curve", 0) == 0:
			_saved_note = "curve: sharp again"
	else:
		var cid: int = g.call("round_corner", int(over[1]), float(radii[0]))
		if cid < 0:
			_undo.pop_back()
			_saved_note = "R rounds a corner: a bend or chord with one route in and one out"
			queue_redraw()
			return
		_pick = [over[0], int((g.call("curve_nodes", cid) as Array)[0])]
		_saved_note = "curve: %.0f m" % float(radii[0])
	_changed(g)


func _cycle_node(key: String, values: Array) -> void:
	var n: Dictionary = _picked_node()
	if n.is_empty():
		return
	_before_edit()
	var i: int = values.find(String(n.get(key, values[0])))
	n[key] = values[(i + 1) % values.size()]
	_changed(_graph_of(_pick))


func _cycle_edge(key: String, values: Array) -> void:
	var he: Array = _hover_edge if not _hover_edge.is_empty() else _edge_at(_mouse)
	if he.is_empty():
		return
	var g: Resource = _graph_of(he)
	_before_edit()
	var e: Dictionary = g.edges[int(he[1])]
	var i: int = values.find(String(e.get(key, values[0])))
	e[key] = values[(i + 1) % values.size()]
	_changed(g)


## The symbol slot under the hand: the picked node's (by its kind and state), else the hovered
## route's chevron (A primary, B secondary). [network, slot] or [].
func _slot_here() -> Array:
	if not _pick.is_empty():
		var n: Dictionary = _picked_node()
		match String(n.get("kind", "")):
			"junction":
				return [_pick[0], "C"]
			"destination":
				var slot: String = {"arrival": "D", "available": "E", "focused": "F", "completed": "G"}.get(String(n.get("state", "arrival")), "D")
				return [_pick[0], slot]
	var he: Array = _hover_edge if not _hover_edge.is_empty() else _edge_at(_mouse)
	if not he.is_empty():
		var e: Dictionary = _graph_of(he).edges[int(he[1])]
		return [he[0], "A" if String(e.get("priority", "primary")) == "primary" else "B"]
	return []


func _cycle_slot() -> void:
	var here: Array = _slot_here()
	if here.is_empty():
		return
	var net: Node = here[0]
	var slot: String = here[1]
	var libs: Array = []
	for k in ((load("res://ramon/Water/carried/PathCreator/render/path_draw.gd") as Script).call("symbols")["ids"] as Dictionary).keys():
		if String(k).get_slice("/", 1) == slot and not (String(k).get_slice("/", 0) in libs):
			libs.append(String(k).get_slice("/", 0))
	libs.sort()
	if libs.is_empty():
		return
	var cur: String = String(net.call("lib_for", slot))
	var next: String = String(libs[(libs.find(cur) + 1) % libs.size()])
	var m: Dictionary = (net.get("libraries") as Dictionary).duplicate()
	m[slot] = next
	net.set("libraries", m)
	_saved_note = "slot %s now from library %s" % [slot, next]


## Every graph back to its file.
func save_all() -> void:
	var saved: PackedStringArray = PackedStringArray()
	for net in networks():
		var g: Resource = net.get("graph")
		if g != null and not g.resource_path.is_empty():
			var err: int = ResourceSaver.save(g, g.resource_path)
			saved.append("%s%s" % [g.resource_path.get_file(), "" if err == OK else " (error %d)" % err])
	_saved_note = "saved %s at %s" % [", ".join(saved), Time.get_time_string_from_system()]
	queue_redraw()


# -- the W lane ---------------------------------------------------------------------------------------

func _lane_rect() -> Rect2:
	return Rect2(Vector2(16, size.y - LANE_H + 8), Vector2(size.x - PANEL_W - 40.0, LANE_H - 24))


func _lane_w(y: float) -> float:
	var r: Rect2 = _lane_rect()
	var t: float = clampf((r.end.y - y) / r.size.y, 0.0, 1.0)
	return lerpf(-Spec.W_REACH * 0.6, Spec.W_REACH * 0.6, t)


func _lane_y(w: float) -> float:
	var r: Rect2 = _lane_rect()
	return r.end.y - r.size.y * inverse_lerp(-Spec.W_REACH * 0.6, Spec.W_REACH * 0.6, w)


## The picked node's route: [[node, distance along], ...].
func _lane_route() -> Array:
	if _pick.is_empty():
		return []
	var g: Resource = _graph_of(_pick)
	for r in g.call("routes"):
		if int(_pick[1]) in (r["nodes"] as Array):
			var out: Array = []
			var s: float = 0.0
			var prev: Vector4 = Vector4.INF
			for id in r["nodes"]:
				var n: Dictionary = g.call("node", int(id))
				var p: Vector4 = n["pos"]
				if prev != Vector4.INF:
					s += Vector2(p.x - prev.x, p.z - prev.z).length()
				out.append([n, s])
				prev = p
			return out
	return []


# -- drawing --------------------------------------------------------------------------------------------

func _draw() -> void:
	if cam == null:
		return
	var f: Font = LabPrint.font("bold")
	var fb: Font = LabPrint.font("body")
	var k: float = px_per_m()
	# Targets: their footprints, names and W.
	var targets_root: Array = space.call("target_nodes") if space.has_method("target_nodes") else []
	for t in targets_root:
		var tp: Vector4 = (t as Node4D).global_position
		var fp: Vector2 = t.call("footprint")
		var on: bool = absf(tp.w - slice_w) <= float(t.get("w_depth")) * 0.5
		var r := Rect2(to_screen(tp.x - fp.x * 0.5, tp.z - fp.y * 0.5), fp * k)
		var col: Color = (t.get("color") as Color)
		draw_rect(r, Color(col, 0.28 if on else 0.08), true)
		draw_rect(r, Color(col.lightened(0.3), 0.9 if on else 0.35), false, 2.0)
		draw_string(fb, r.position + Vector2(4, -6), "%s   W %+.1f" % [String(t.get("label")), tp.w], HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13), Color(1, 1, 1, 0.85 if on else 0.45))
	# Routes.
	for net in networks():
		var g: Resource = net.get("graph")
		if g == null:
			continue
		for i in g.edges.size():
			var e: Dictionary = g.edges[i]
			var na: Dictionary = g.call("node", int(e["from"]))
			var nb: Dictionary = g.call("node", int(e["to"]))
			if na.is_empty() or nb.is_empty():
				continue
			var a: Vector4 = na["pos"]
			var b: Vector4 = nb["pos"]
			var sa: Vector2 = to_screen(a.x, a.z)
			var sb: Vector2 = to_screen(b.x, b.z)
			var hot: bool = not _hover_edge.is_empty() and _hover_edge[0] == net and int(_hover_edge[1]) == i
			var primary: bool = String(e["priority"]) == "primary"
			var col: Color = Color(0.25, 0.55, 1.0) if primary else Color(0.55, 0.75, 1.0)
			if hot:
				col = Color(1.0, 0.85, 0.3)
			var mode: String = String(e.get("w_mode", "static"))
			if mode == "static":
				draw_line(sa, sb, col, 4.0 if primary else 3.0, true)
			else:
				# Dashed: it lives in a band of W, not everywhere.
				var n: int = int(sa.distance_to(sb) / 10.0)
				for j in n:
					if j % 2 == 0:
						draw_line(sa.lerp(sb, float(j) / float(n)), sa.lerp(sb, float(j + 1) / float(n)), col, 3.0, true)
			var mid: Vector2 = (sa + sb) * 0.5
			var dir: Vector2 = (sb - sa).normalized()
			draw_colored_polygon(PackedVector2Array([mid + dir * 7.0, mid - dir * 5.0 + dir.orthogonal() * 5.0, mid - dir * 5.0 - dir.orthogonal() * 5.0]), col)
			if hot or mode != "static":
				draw_string(fb, mid + Vector2(8, -8), "%s · %s%s" % [String(e["priority"]), mode, "" if mode == "static" else " %.1f" % float(e.get("band", 1.2))], HORIZONTAL_ALIGNMENT_LEFT, -1, _px(12), Color(1, 1, 1, 0.85))
		for n in g.nodes:
			var p: Vector4 = n["pos"]
			var sp: Vector2 = to_screen(p.x, p.z)
			var band: float = float(n.get("band", 1.2))
			var on: bool = absf(p.w - slice_w) <= band * 0.5
			var kind: String = String(n["kind"])
			var r: float = {"start": 9.0, "chord": 5.0, "bend": 7.0, "junction": 9.0, "destination": 12.0}.get(kind, 7.0)
			draw_circle(sp, r + 5.0, Color(w_color(p.w), 0.18 if on else 0.06))
			draw_circle(sp, r, w_color(p.w, 1.0 if on else 0.4))
			draw_arc(sp, r, 0.0, TAU, 24, Color(0.06, 0.08, 0.12, 0.9), 2.0, true)
			if kind == "destination":
				draw_arc(sp, r - 4.0, 0.0, TAU, 24, Color(0.06, 0.08, 0.12, 0.9), 2.0, true)
			if kind == "junction":
				draw_rect(Rect2(sp - Vector2(3, 3), Vector2(6, 6)), Color(0.06, 0.08, 0.12, 0.9))
			var picked: bool = not _pick.is_empty() and _pick[0] == net and int(_pick[1]) == int(n["id"])
			if picked:
				draw_arc(sp, r + 6.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.3), 3.0, true)
			if picked or absf(p.w) > 0.01:
				draw_string(fb, sp + Vector2(r + 6, 4), "W %+.2f" % p.w, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(12), Color(1, 1, 1, 0.9 if on else 0.5))
	_draw_panel(f, fb)
	_draw_lane(fb)


func _glass(r: Rect2) -> void:
	draw_style_box(Style.glass_box(10.0), r)


## A text size at the builder's scale.
func _px(n: float) -> int:
	return int(round(n * TEXT))


func _draw_panel(f: Font, fb: Font) -> void:
	var r := Rect2(Vector2(size.x - PANEL_W - 16.0, 16), Vector2(PANEL_W, size.y - LANE_H - 24))
	_glass(r)
	# The writing line, held in an array: a lambda copies plain locals, so it could not move `y` on.
	# A line too long for the panel wraps (up to three lines) rather than running off its edge.
	var cur: Array = [r.position.y + 16.0 + float(_px(16))]
	var x: float = r.position.x + 16.0
	var line := func(t: String, font: Font, size_: float, col: Color) -> void:
		var px: int = _px(size_)
		var wide: float = r.size.x - 32.0
		draw_multiline_string(font, Vector2(x, float(cur[0])), t, HORIZONTAL_ALIGNMENT_LEFT, wide, px, 3, col)
		var h: float = font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, wide, px, 3).y
		cur[0] = float(cur[0]) + maxf(h, float(px)) + 6.0
	line.call("BUILDER", f, 16, Style.UI_ACCENT)
	line.call("slice W %+.2f    snap %s    adding a %s" % [slice_w, "on" if snap else "off", add_kind], fb, 13, Style.UI_INK_SOFT)
	cur[0] = float(cur[0]) + 6.0
	var n: Dictionary = _picked_node()
	if not n.is_empty():
		var p: Vector4 = n["pos"]
		line.call("%s %d" % [String(n["kind"]).to_upper(), int(n["id"])], f, 15, Style.UI_INK)
		line.call("x %.2f   z %.2f   W %+.2f   band %.1f" % [p.x, p.z, p.w, float(n.get("band", 1.2))], fb, 13, Style.UI_INK_SOFT)
		if String(n["kind"]) == "destination":
			line.call("state %s   frame %s   for %s" % [String(n.get("state", "")), String(n.get("frame", "none")), String(n.get("target", "-"))], fb, 13, Style.UI_INK_SOFT)
	else:
		line.call("Pick a node (left click).", fb, 13, Style.UI_INK_DIM)
	cur[0] = float(cur[0]) + 6.0
	for t in ["N new node (1-5 its kind)   X split   C join", "Del remove   K kind   S state   F frame",
			"R  round a corner (again: wider, then sharp)", "P / M  hovered route: priority / W mode",
			"L  this symbol's library (one slot)",
			"wheel on a node: W   shift: band", "[ ]  slice W   G snap   Ctrl+Z / Y   Ctrl+S save", "drag: move   middle or right drag: pan",
			"T  walk from here (at the mouse)", "F4  back to walking"]:
		line.call(t, fb, 12, Style.UI_INK_DIM)
	cur[0] = float(cur[0]) + 6.0
	if not _saved_note.is_empty():
		line.call(_saved_note, fb, 12, Style.UI_ACCENT)
	var notes: PackedStringArray = PackedStringArray()
	for net in networks():
		notes.append_array(net.call("notes"))
	if not notes.is_empty():
		line.call("ROUTE NOTES", f, 13, Style.UI_WARM)
		for t in notes:
			if float(cur[0]) > r.end.y - float(_px(12)):
				break
			line.call(t, fb, 12, Style.UI_INK_SOFT)


func _draw_lane(fb: Font) -> void:
	var r: Rect2 = _lane_rect()
	_glass(r.grow(6.0))
	for w in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		var y: float = _lane_y(w)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.08 if w != 0.0 else 0.18), 1.0)
		draw_string(fb, Vector2(r.position.x + 4, y - 3), "W %+d" % int(w), HORIZONTAL_ALIGNMENT_LEFT, -1, _px(11), Color(1, 1, 1, 0.45))
	var sy: float = _lane_y(slice_w)
	draw_line(Vector2(r.position.x, sy), Vector2(r.end.x, sy), Color(Style.UI_ACCENT, 0.8), 2.0)
	var tag_w: float = fb.get_string_size("your slice", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(11)).x
	draw_string(fb, Vector2(r.end.x - tag_w - 8.0, sy - 4), "your slice", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(11), Style.UI_ACCENT)
	var route: Array = _lane_route()
	if route.is_empty():
		# At the top, clear of the W 0 line and its tag, wrapped to the lane.
		draw_multiline_string(fb, r.position + Vector2(80, float(_px(12)) + 4.0), "THE W LANE  pick a node: its route laid out flat, distance against W; drag a node up or down",
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 100.0 - tag_w, _px(12), 2, Style.UI_INK_DIM)
		return
	var total: float = maxf(float(route.back()[1]), 1.0)
	var at := func(s: float, w: float) -> Vector2: return Vector2(r.position.x + 80.0 + (r.size.x - 100.0) * s / total, _lane_y(w))
	var prev: Vector2 = Vector2.INF
	for item in route:
		var n: Dictionary = item[0]
		var p: Vector4 = n["pos"]
		var sp: Vector2 = at.call(float(item[1]), p.w)
		var band: float = float(n.get("band", 1.2))
		var lr: Rect2 = _lane_rect()
		var y0: float = clampf(_lane_y(p.w - band * 0.5), lr.position.y, lr.end.y)
		var y1: float = clampf(_lane_y(p.w + band * 0.5), lr.position.y, lr.end.y)
		draw_line(Vector2(sp.x, y0), Vector2(sp.x, y1), Color(w_color(p.w), 0.35), 6.0)
		if prev != Vector2.INF:
			draw_line(prev, sp, Color(0.4, 0.65, 1.0), 2.0, true)
		var picked: bool = int(n["id"]) == int(_pick[1])
		draw_circle(sp, 7.0 if picked else 5.0, w_color(p.w))
		if picked:
			draw_arc(sp, 10.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3), 2.0, true)
		prev = sp
