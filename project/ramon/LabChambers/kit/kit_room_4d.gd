@tool
extends Node4D

## Kit: a room. Floor, four walls with doorways, a ceiling and a line of cove light, all on the
## gallery grid (kit_style.gd). Move the node and the room moves; set `size` and it rebuilds.
##
## TEXT ON ITS WALLS: KitWallText children (kit_wall_text_4d.gd) say which wall and where; the
## room splits that wall where the text begins and ends and paints it straight onto the wall
## (Ramon, 4 Oct: a proud sign "reads as a glitch").
##
## A ROUTE on its floor: `route` (world x/z) is painted into the floor's own surface as soft
## arrows, no geometry above it (LabKit/lab_grid.gd set_route).
##
## The room's interior is `size` (x, height, z) centred on the node, x and z only (it is never
## turned). Doorways are [side, from, to, height] with from/to measured along that wall from the
## room's centre; "n" is the -Z wall, "s" +Z, "w" -X, "e" +X.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/LabChambers/scripts/chamber_build.gd")
const RD := preload("res://ramon/LabChambers/scripts/rd_build.gd")
const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Batch := preload("res://ramon/LabKit/lab_batch.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var size: Vector3 = Vector3(20, 8, 18):
	set(v):
		size = v
		_later()
@export var doorways: Array = []:
	set(v):
		doorways = v
		_later()
@export var open_sides: Array = []:
	set(v):
		open_sides = v
		_later()
@export var ceiling: bool = true:
	set(v):
		ceiling = v
		_later()
@export var cove: bool = true:
	set(v):
		cove = v
		_later()
## Arrows painted into the floor, in world x/z, from the first point to the last.
@export var route: PackedVector2Array = PackedVector2Array():
	set(v):
		route = v
		_show_route()
@export var route_lit: bool = true:
	set(v):
		route_lit = v
		_show_route()

var _floor: MeshInstance4D
var _walls: Dictionary = {}       # side -> pieces
var _prints: Array = []
var _cove: MeshInstance4D
var _queued: bool = false


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")
	add_to_group("kit_room")


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func rebuild() -> void:
	Build.clear(self)
	_prints = []
	_walls = {}
	var x0: float = -size.x * 0.5
	var x1: float = size.x * 0.5
	var z0: float = -size.z * 0.5
	var z1: float = size.z * 0.5
	var h: float = size.y
	var t: float = 0.5
	_floor = Build.box(self, "Floor", Vector3(0, -0.25, 0), Vector3(size.x, 0.5, size.z), "kit_floor")
	var texts: Array = _texts()
	for side in ["n", "s", "w", "e"]:
		if side in open_sides:
			continue
		var ops: Array = []
		for d in doorways:
			if String(d[0]) == side:
				ops.append([float(d[1]), float(d[2]), float(d[3]) if d.size() > 3 else 3.6])
		var cuts: Array = []
		for tx in texts:
			if String(tx.get("side")) == side:
				var a: Vector2 = tx.get("along")
				cuts.append(a.x)
				cuts.append(a.y)
		_walls[side] = RD.wall(self, "Wall" + side.to_upper(), side, x0, z0, x1, z1, h, t, ops, cuts, "kit_wall")
	if ceiling:
		RD.ceiling(self, "Ceiling", x0 - t, z0 - t, x1 + t, z1 + t, h, "kit_ceiling")
	if cove:
		var b := Batch.new()
		RD.strip_rect(b, "cove", x0 + 0.3, z0 + 0.3, x1 - 0.3, z1 - 0.3, h - 0.22, 0.09, 0.05)
		_cove = b.instance("cove")
		_cove.set_meta(Build.GENERATED, true)
		add_child(_cove)
	_apply_mood_now()
	_show_route()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for tx in texts:
		var side: String = String(tx.get("side"))
		if not _walls.has(side):
			continue
		var a: Vector2 = tx.get("along")
		var up: Vector2 = tx.get("up")
		var rec: Dictionary = await RD.print_wall(tree, _walls[side], RD.wall_normal(side, not bool(tx.get("outside"))),
			minf(a.x, a.y), maxf(a.x, a.y), up.x, up.y, Callable(tx, "paint"), {"bright": float(tx.get("glow")), "dark": float(tx.get("glow")) + 0.15})
		_prints.append(rec)
	_apply_mood_now()


func _texts() -> Array:
	var out: Array = []
	for c in get_children():
		if c.has_method("paint") and c.get("side") != null:
			out.append(c)
	return out


## The floor's box, for anything that wants to paint on it.
func floor_box() -> MeshInstance4D:
	return _floor


## True if `p` (world) stands inside the room.
func inside(p: Vector4) -> bool:
	var l: Vector4 = p - global_position
	return absf(l.x) <= size.x * 0.5 + 0.3 and absf(l.z) <= size.z * 0.5 + 0.3


func apply_mood(_m: String, _instant: bool = false) -> void:
	_apply_mood_now()


func _apply_mood_now() -> void:
	for rec in _prints:
		RD.apply(rec, Style.mood)
	if is_instance_valid(_cove):
		_cove.material_override = Mats.glow(Style.pick(Style.COVE), 1.0)
	_show_route()


func _show_route() -> void:
	if not is_instance_valid(_floor):
		return
	LabGrid.set_route(_floor.material_override as TetraMaterial4D, route, 1.0 if route_lit else 0.0, Style.pick(Style.ROUTE))
