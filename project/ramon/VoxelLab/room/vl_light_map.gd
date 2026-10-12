extends Control

## The dev panel's top view of the lights (Ramon, 8 Oct: "some kind of layout and top view ... show me
## where the lights are and the sliders that I can use"). The corridor, the hall and the gallery from
## above, north up the page (the gallery at the top, the corridor at the bottom); the items as grey
## shapes; every light a dot with its pool drawn to scale on the floor. Click a light to pick it (its
## sliders appear under the map), drag it to move it; the light follows at once.
##
##   rig        the room's light rig (vl_lights.gd)
##   room       the lab root, for the hall's outline and the stations
##   selected   the picked light's name; picked(name) when it changes
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")

signal picked(name: String)

var rig: Node
var room: Node
var selected: String = ""
## What the map shows, in metres: x from left to right, z from far (top) to near (bottom).
var bounds := Rect2(-14.0, -33.5, 28.0, 61.0)
var _drag: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(400, 470)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


## Metres on the floor (x, z) to the map's pixels, and back.
func to_map(x: float, z: float) -> Vector2:
	var k: float = _scale()
	var o: Vector2 = _origin(k)
	return o + Vector2(x - bounds.position.x, z - bounds.position.y) * k


func to_floor(p: Vector2) -> Vector2:
	var k: float = _scale()
	var o: Vector2 = _origin(k)
	var m: Vector2 = (p - o) / k
	return Vector2(m.x + bounds.position.x, m.y + bounds.position.y)


func _scale() -> float:
	return minf((size.x - 16.0) / bounds.size.x, (size.y - 16.0) / bounds.size.y)


func _origin(k: float) -> Vector2:
	return Vector2((size.x - bounds.size.x * k) * 0.5, (size.y - bounds.size.y * k) * 0.5)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var best: String = ""
			var best_d: float = 14.0
			for l in (rig.get("lights") if rig != null else []):
				var e: Dictionary = rig.call("effective", l)
				var d: float = to_map(float(e["x"]), float(e["z"])).distance_to(mb.position)
				if d < best_d:
					best_d = d
					best = String(l.name)
			if not best.is_empty():
				if best != selected:
					selected = best
					picked.emit(best)
				_drag = true
		else:
			_drag = false
		accept_event()
	var mm := event as InputEventMouseMotion
	if mm != null and _drag and not selected.is_empty() and rig != null:
		var f: Vector2 = to_floor(mm.position)
		rig.call("move_to", selected, snappedf(f.x, 0.05), snappedf(f.y, 0.05))
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.035, 0.9))
	var k: float = _scale()
	var wall := Color(0.62, 0.70, 0.82, 0.8)
	var fl: Font = LabPrint.font("bold")
	# The rooms: the corridor, the hall's outline, the gallery.
	var plan: Dictionary = room.get("plan") if room != null else {}
	var outline: PackedVector2Array = plan.get("outline", PackedVector2Array())
	if not outline.is_empty():
		var pts := PackedVector2Array()
		for p in outline:
			pts.append(to_map(p.x, p.y))
		pts.append(pts[0])
		draw_polyline(pts, wall, 1.5, true)
	_rect_room(room.get_node_or_null("Entrance") if room != null else null, wall)
	_rect_room(room.get_node_or_null("GalleryRoom") if room != null else null, wall)
	# The items: every station, as its pedestal.
	for s in (room.get("stations") if room != null else []):
		var p: Vector4 = (s as Node4D).global_position
		var r: float = float(s.get("radius"))
		if String(s.get("pedestal_shape")) == "box":
			var c: Vector2 = to_map(p.x, p.z)
			draw_rect(Rect2(c - Vector2(r, r) * k, Vector2(r, r) * 2.0 * k), Color(0.45, 0.48, 0.53, 0.9))
		else:
			draw_circle(to_map(p.x, p.z), r * k, Color(0.45, 0.48, 0.53, 0.9))
	# The lights: the pool on the floor, the light itself, its name when picked.
	for l in (rig.get("lights") if rig != null else []):
		var e: Dictionary = rig.call("effective", l)
		var at: Vector2 = to_map(float(e["x"]), float(e["z"]))
		var aim: Vector3 = l.get("aim")
		var pool_c: Vector2 = to_map(aim.x, aim.z)
		var pool_r: float = float(e["height"]) * tan(deg_to_rad(float(e["cone"]) * 0.5)) * k
		var sel: bool = String(l.name) == selected
		var warm := Color(1.0, 0.86, 0.5)
		draw_circle(pool_c, pool_r, Color(warm, 0.10 + 0.05 * clampf(float(e["strength"]) / 3.0, 0.0, 2.0)))
		draw_arc(pool_c, pool_r, 0.0, TAU, 40, Color(warm, 0.45 if sel else 0.25), 1.0, true)
		draw_line(at, pool_c, Color(warm, 0.4), 1.0, true)
		draw_circle(at, 6.0 if sel else 4.5, Style.UI_ACCENT if sel else warm)
		if sel:
			draw_arc(at, 10.0, 0.0, TAU, 24, Style.UI_ACCENT, 2.0, true)
			draw_string(fl, at + Vector2(12, -8), String(l.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(fl, Vector2(8, 16), "GALLERY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.UI_INK_DIM)
	draw_string(fl, Vector2(8, size.y - 8), "CORRIDOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.UI_INK_DIM)


func _rect_room(n: Node, col: Color) -> void:
	if n == null:
		return
	var sz: Vector3 = n.get("size")
	var p: Vector4 = (n as Node4D).position
	var a: Vector2 = to_map(p.x - sz.x * 0.5, p.z - sz.z * 0.5)
	var b: Vector2 = to_map(p.x + sz.x * 0.5, p.z + sz.z * 0.5)
	draw_rect(Rect2(a, b - a), col, false, 1.5)
