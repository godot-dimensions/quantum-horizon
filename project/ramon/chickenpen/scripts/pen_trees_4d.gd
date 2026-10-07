extends Node4D

## THE PLANTING IN FOUR DIMENSIONS (Ramon, 7 Oct: "more trees have to be oplaced in the W, above and
## under, so the scene reads more 4d. now they just dissapear instant when you rotate the slice. we dont
## want to be too reset dependant. so figure out the right amount, to place trees in a 4d way, and in
## what manner, so it looks natural. directly above, slightly repositioned? use your expertise").
##
## WHY THEY WENT ALL AT ONCE. Every tree stood at W 0. Turn the slice by an angle and a tree d metres off
## is d times its sine out of it in W: at 20 m, three degrees is a metre, and the light oaks were only
## 1.8 m deep in W either side, so the whole wood went in a flick of the mouse and came back only at R.
##
## WHAT THIS DOES. The trees Ramon placed stay exactly where he put them, at W 0; they are the farm's
## slice. Round them, a forest through W: at each of [member echo_ws] (4.5 and 9 ana and kata), about
## three in four of them stand again, each shifted a metre or two to one side ([member shift]), turned
## both ways round (about the trunk, and in X and W, which shows another cut of the same 4D tree), a
## little bigger or smaller, now and then the other size of oak. With the trees round in W (pen_oak_4d.gd
## w_stretch: a crown reaches some 3.6 m either side in W) and a layer every 4.5 m, any slice, flat or turned,
## passes near some layer everywhere, so the wood never empties: as the slice turns, the trees near you
## draw in and their neighbours in W come up a pace or two over, and the wood is always a wood. Why not
## directly above: the same tree at the same spot in every layer reads as one tree that will not go away;
## shifted and turned, they read as more trees, standing in W beside each other.
##
## WHAT STAYS CLEAR, IN EVERY W: the paths ([member clear_of_paths] from every stretch, from the path
## graph), the landmarks' frames, the town walls, the valley's edge, and any hill or mound (from the
## grass's baked heights; a tree's trunk is stood on the flat ground, so on a hill it would be buried).
## A shifted spot that falls in any of them is tried elsewhere, six times, then left out.
##
## ONE LOOP. Each tree culled itself in a call of its own every frame; with the layers that was four
## hundred calls. Here one pass over all of them (cull_usec, for runners).
##
## Made when the pen starts, never saved: the scene holds only what Ramon placed. Off: [member echoes].
## No class_name (engine_gotchas.md).

const OAK := preload("res://ramon/chickenpen/scripts/pen_oak_4d.gd")
const Heights := preload("res://ramon/chickenpen/grass/grass_heights_4d.gd")

@export var echoes: bool = true
## The W's the planting stands at again (each a layer), relative to each tree's own.
## 4.5 apart, not 4: a crown reaches some 3.6 m either side in W, so at 4 the next layer's leaf tips came
## into the farm's own slice without their trunks, leaves in the air (measured 7 Oct,
## PenLayout/scratch/tests/probe_trees_turn_runner.gd). At 4.5 the farm's slice is what Ramon placed.
@export var echo_ws: PackedFloat32Array = PackedFloat32Array([-9.0, -4.5, 4.5, 9.0])
## The share of the trees that stand again in each layer.
@export_range(0.0, 1.0, 0.01) var echo_share: float = 0.75
## How far to one side, nearest and furthest (m).
@export var shift: Vector2 = Vector2(0.8, 2.2)
@export_range(0.0, 0.4, 0.01) var size_jitter: float = 0.12
## The share that are the other size of oak (large for medium and the other way).
@export_range(0.0, 1.0, 0.01) var swap_share: float = 0.3
@export var echo_seed: int = 47
@export_range(0.0, 8.0, 0.1, "suffix:m") var clear_of_paths: float = 2.4
@export_range(0.0, 8.0, 0.1, "suffix:m") var clear_of_frames: float = 1.5
@export_range(0.0, 8.0, 0.1, "suffix:m") var clear_of_walls: float = 2.0
## The valley: no tree further than this from its middle (scripts/pen_bounds_4d.gd: 58 round (0, 6)).
@export var valley_centre: Vector2 = Vector2(0.0, 6.0)
@export_range(10.0, 80.0, 0.5, "suffix:m") var valley_radius: float = 54.0
@export var paths_path: NodePath = ^"../Paths"

## For runners: how many stood again, how many spots were turned away, and the last cull's time.
var echo_count: int = 0
var echo_refused: int = 0
var cull_usec: int = 0

var _oaks: Array[Node] = []
var _segments: Array = []
var _rounds: Array = []
var _heights: Image


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if echoes:
		_plant()
	for child in get_children():
		if child.has_method("set_managed"):
			child.call("set_managed", true)
			_oaks.append(child)
	RenderingServer4D.pre_render.connect(_on_pre_render)


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)


func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	if viewport != get_viewport():
		return
	var started: int = Time.get_ticks_usec()
	for oak in _oaks:
		oak.call("cull", camera, viewport, engine)
	cull_usec = Time.get_ticks_usec() - started


func _plant() -> void:
	_keep_outs()
	if ResourceLoader.exists(Heights.BAKED):
		_heights = load(Heights.BAKED) as Image
	var rng := RandomNumberGenerator.new()
	rng.seed = echo_seed
	var placed: Array = []
	for child in get_children():
		if child.get_script() == OAK:
			placed.append(child)
	for w in echo_ws:
		for src: Node4D in placed:
			if rng.randf() > echo_share:
				continue
			var bake: String = String(src.get("bake"))
			var bush: bool = bake.begins_with("bush")
			var spot := Vector2.INF
			for attempt in 6:
				var a: float = rng.randf() * TAU
				var r: float = rng.randf_range(shift.x, shift.y) * (0.6 if bush else 1.0)
				var p := Vector2(src.position.x + cos(a) * r, src.position.z + sin(a) * r)
				if _clear(p, src.position.w + w, 0.6 if bush else 1.0):
					spot = p
					break
			if spot == Vector2.INF:
				echo_refused += 1
				continue
			var oak := Node4D.new()
			oak.set_script(OAK)
			var height: float = float(src.get("height")) * (1.0 + rng.randf_range(-size_jitter, size_jitter))
			if bush:
				bake = "bush_%d" % rng.randi_range(1, 3)
			elif rng.randf() < swap_share:
				if bake == "oak_lite3":
					bake = "oak_lite4"
					height *= 0.88
				elif bake == "oak_lite4":
					bake = "oak_lite3"
					height *= 1.12
			oak.set("bake", bake)
			oak.set("height", clampf(height, 0.8, 14.0))
			oak.set("trunk", src.get("trunk"))
			oak.set("leaf_seed", src.get("leaf_seed"))
			oak.set("w_stretch", src.get("w_stretch"))
			oak.set("managed", true)
			oak.name = "%s_%s%d" % [src.name, "ana" if w > 0.0 else "kata", int(absf(w))]
			oak.position = Vector4(spot.x, src.position.y, spot.y, src.position.w + w)
			# About the trunk, and a turn in X and W: another cut through the same 4D tree.
			oak.basis = Basis4D.from_zx(rng.randf() * TAU) * Basis4D.from_xw(rng.randf() * TAU)
			add_child(oak)
			echo_count += 1


## What the planting keeps clear: the paths' stretches and the walls as segments [a, b, clearance],
## the landmarks' frames as circles [centre, radius].
func _keep_outs() -> void:
	_segments.clear()
	_rounds.clear()
	var net: Node = get_node_or_null(paths_path)
	var graph: Resource = net.get("graph") if net != null else null
	if graph != null:
		var at: Dictionary = {}
		for n in graph.get("nodes"):
			var p: Vector4 = n["pos"]
			at[int(n["id"])] = Vector2(p.x, p.z)
		for e in graph.get("edges"):
			var a: Variant = at.get(int(e["from"]))
			var b: Variant = at.get(int(e["to"]))
			if a != null and b != null:
				_segments.append([a, b, clear_of_paths])
		for k in at:
			_rounds.append([at[k], clear_of_paths])
	var world: Node = get_parent()
	for node in world.find_children("*", "Node4D", true, false):
		if node == self or is_ancestor_of(node):
			continue
		var n4 := node as Node4D
		# (A landmark's footprint() takes nothing; the crag chunks' footprint(at) is another thing.)
		if n4.has_method("footprint") and n4.get_method_argument_count("footprint") == 0:
			var size: Vector2 = n4.call("footprint")
			_rounds.append([Vector2(n4.global_position.x, n4.global_position.z), size.length() * 0.5 + clear_of_frames])
		elif "from" in n4 and "to" in n4 and "gaps" in n4:
			var b: Projection = n4.global_basis
			var o: Vector4 = n4.global_position
			var f: Vector2 = n4.get("from")
			var t: Vector2 = n4.get("to")
			var fa: Vector4 = o + b * Vector4(f.x, 0.0, f.y, 0.0)
			var ta: Vector4 = o + b * Vector4(t.x, 0.0, t.y, 0.0)
			_segments.append([Vector2(fa.x, fa.z), Vector2(ta.x, ta.z), clear_of_walls])


func _clear(p: Vector2, w: float, scale: float) -> bool:
	if p.distance_to(valley_centre) > valley_radius:
		return false
	for s in _segments:
		if Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p) < float(s[2]) * scale:
			return false
	for r in _rounds:
		if p.distance_to(r[0]) < float(r[1]) * scale:
			return false
	if _heights != null:
		var i: int = int(floor((p.x + Heights.CELL * Heights.CELLS * 0.5) / Heights.CELL))
		var j: int = int(floor((p.y + Heights.CELL * Heights.CELLS * 0.5) / Heights.CELL))
		var l: int = clampi(int(round((w - Heights.W0) / Heights.DW)), 0, Heights.LAYERS - 1)
		if i >= 0 and j >= 0 and i < Heights.CELLS and j < Heights.CELLS:
			if _heights.get_pixel(i, l * Heights.CELLS + j).r > 0.25:
				return false
	return true
