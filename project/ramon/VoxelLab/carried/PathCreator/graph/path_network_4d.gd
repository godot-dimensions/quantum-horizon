@tool
extends Node4D

## PathCreator: draws a route graph (path_graph.gd) on the floor, live, in the game and in the
## editor. Every edge is one thin flat 4D box along its chord and every node one small square box,
## all carrying the vector shader (render/path_mark.gdshader): the marks are the Figma's own outlines,
## repeated by distance along each route, the destinations in their states, the frames round their
## objects. No 4D meshes of arrows (Ramon: "only do it when absolutely necessary").
##
## THE SHEET'S RULES, as built here:
##   arc length   a route's marks repeat by distance along the whole route (rule 01), so they march
##                on unbroken through its bends; each box is told where along the route it begins
##   keep clear   marks stop short of every node by its art's radius + 0.25P (rule 03) and slide
##                under that edge as they flow ("the hide under strip technique")
##   short        a chord too short for a mark and both clearances carries only the guide (B1)
##   crossings    where two routes cross without a node, the weaker one's marks break (rule 05)
##   states       a destination shows D, E, F or G by its state; E and F turn their arc (rule 07)
##   frames       an object's frame (H or I) grown round its footprint, open toward the approach
##
## W (PLAN.md part F): an edge's box is as deep in W as its band, at the W its mode says
##   static  the floor's whole W depth: readable from anywhere
##   here    at its from-node's W
##   follow  from the from-node's W to the to-node's: the box is sheared through W along its length,
##           so the slice cuts a stretch of it that slides along the route as you move through W
##   reveal  at its to-node's W only
## and each node's box is its own band deep at its own W (a wide band is a bracket you see from afar).
##
## LOOKS AND SETS: `look` DEV or WALK for every box at once; `libraries` says which library each
## symbol slot comes from (Ramon, 5 Oct: "toggle not entire sets at once, but subicons separately").
##
## DRAPING (`drape`, PLAN.md step 85): the routes lie on whatever static box is under them rather
## than on the floor at y 0. Each node sits on the top it stands over (a ray straight down at its x,
## z and W), and each route is sampled every DRAPE_STEP_M and laid as runs, one per height, so it
## climbs a step as a run on the lower box and a run on the upper. A mark never crosses a riser: it
## shrinks as it nears the edge and the next run's grows back beyond it. Physics is boxes only (no
## slope exists), so a step is the only bend ground can have. Rays are cast when the routes are
## laid, never per frame.
## In the editor there may be no physics to ask, and the routes lie at y 0.
##
## ANCHORS (PLAN.md step 86): a destination with "anchor" set follows its object as it moves (a
## chicken, a cart), keeping the place it was authored at beside it in x, z and W. Only its own
## edges, ball and frame are laid again, and the graph file keeps the authored place.
##
## BLOCKED ROUTES (rule 09: "invalid edges hide", `hide_blocked`): a route whose way is shut, a
## static box across it BLOCK_H_M above its ground, hides, and shows again when the way opens.
## Checked every BLOCK_CHECK_S, one ray along each run of each edge. Only routes hide; the nodes
## stay, so a junction still says there was a way.
##
## Moving a node rebuilds only what changed: boxes are kept by key and re-laid in place.
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/VoxelLab/carried/PathCreator/path_spec.gd")
const Draw := preload("res://ramon/VoxelLab/carried/PathCreator/render/path_draw.gd")
const GENERATED := "pc_generated"
## Across the route, metres: room for the widest mark.
const EDGE_W := 0.8
## A crossing's break either side of the crossing point, metres.
const GAP_HALF := 0.5
## A frame's margin round its object's footprint, and the opening toward its approach, metres.
const FRAME_MARGIN := 0.35
const FRAME_GAP := 1.6

@export var graph: Resource:
	set(v):
		if graph != null and graph.changed.is_connected(_later):
			graph.changed.disconnect(_later)
		graph = v
		if graph != null and not graph.changed.is_connected(_later):
			graph.changed.connect(_later)
		_later()
## Where the objects its destinations name stand (their footprints shape the frames).
@export var targets: NodePath
@export_enum("dev", "walk") var look: String = "dev":
	set(v):
		look = v
		_apply_look()
## slot -> library folder ("A": "07", ...); a slot not named uses `default_library`.
@export var libraries: Dictionary = {}:
	set(v):
		libraries = v
		_later()
@export var default_library: String = "07":
	set(v):
		default_library = v
		_later()
## The floor's own albedo, which a mark's antialiased edge blends into.
@export var under_color: Color = Color(0.96, 0.965, 0.97):
	set(v):
		under_color = v
		_apply_look()
@export var motion: bool = true:
	set(v):
		motion = v
		_apply_look()
## Where marks end at a node: "hide" under its art, or "keep" the sheet's 0.25P clear (path_spec.gd).
@export_enum("hide", "keep") var clear_style: String = Spec.CLEAR_STYLE:
	set(v):
		clear_style = v
		_later()
## The marks flow this fast, metres a second.
@export var flow: float = Spec.FLOW_M_S:
	set(v):
		flow = v
		_apply_look()

## Lay the routes on the static boxes under them (steps, platforms) instead of at y 0.
@export var drape: bool = false:
	set(v):
		drape = v
		_later()
## Which physics layers draping stands on.
@export_flags_3d_physics var drape_mask: int = 0xFFFFFFFF:
	set(v):
		drape_mask = v
		_later()
## Hide a route while a static box shuts its way (rule 09).
@export var hide_blocked: bool = false
## How big the symbols are drawn: the sheet's P (0.6 m, the player's width) times this. Everything
## the sheet gives in P scales with it (symbols, repeats, clear floor, the guide); what is given in
## metres round objects (frames' margin, the approach gap) does not.
@export_range(0.5, 3.0, 0.05) var p_scale: float = 1.0:
	set(v):
		p_scale = v
		_later()

var _items: Dictionary = {}
var _queued: bool = false
var _notes: PackedStringArray = PackedStringArray()
## Anchored destinations: node id -> its offset from its object, and its place now.
var _anchor_off: Dictionary = {}
var _anchor_at: Dictionary = {}
## From the last full layout: each edge's start along its route, its crossings' gaps, and where it
## lies (for the blocked check).
var _s0: Dictionary = {}
var _gaps: Dictionary = {}
var _geo: Dictionary = {}
## Routes shut now (route index -> its edge indices), and the time to the next check.
var _shut: Dictionary = {}
var _block_t: float = 0.0


func _ready() -> void:
	if graph != null and not graph.changed.is_connected(_later):
		graph.changed.connect(_later)
	rebuild()
	if drape and not Engine.is_editor_hint():
		# Once more after the first physics frame, when every box in the scene is surely registered.
		await get_tree().physics_frame
		rebuild()


## The height of the static ground under (x, z) at W `w`, in this network's own space: a ray down
## from `from_y` + DRAPE_REACH_M. Characters, areas and anything in `skip` are looked through; no
## ground, or draping off, is y 0.
func ground_at(x: float, z: float, w: float, from_y: float = 0.0, skip: Array = []) -> float:
	if not drape or not is_inside_tree():
		return 0.0
	var params := RaycastParameters4D.new()
	var o: Vector4 = global_position
	params.global_ray_origin = Vector4(o.x + x, o.y + from_y + Spec.DRAPE_REACH_M, o.z + z, o.w + w)
	params.global_ray_direction = Vector4(0, -1, 0, 0)
	params.max_distance = Spec.DRAPE_REACH_M + 6.0
	params.collision_mask = drape_mask
	var ex: Array[Node4D] = []
	for s in skip:
		if s is Node4D:
			ex.append(s)
	for i in 8:
		params.set_exclude_nodes(ex)
		var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
		if hit.is_empty() or not bool(hit.get("hit", false)) or not hit.has("global_point"):
			return 0.0
		var body: Object = hit.get("body")
		if body is StaticBody4D:
			return (hit["global_point"] as Vector4).y - o.y
		if not (body is Node4D):
			return 0.0
		ex.append(body as Node4D)
	return 0.0


## Where an edge's ground changes height: [[from, to, height], ...] along it, metres from its
## start. One run (the whole edge at y 0) when draping is off. `w_at` gives the route's W at a
## distance along it (a follow route climbs).
func _runs(A: Vector4, dir: Vector2, L: float, w_at: Callable) -> Array:
	if not drape:
		return [[0.0, L, 0.0]]
	var h_at := func(t: float) -> float:
		return ground_at(A.x + dir.x * t, A.z + dir.y * t, float(w_at.call(t)), A.y)
	var n: int = maxi(1, ceili(L / Spec.DRAPE_STEP_M))
	var out: Array = []
	var t0: float = 0.0
	var h0: float = h_at.call(0.0)
	var prev_t: float = 0.0
	for i in range(1, n + 1):
		var t: float = L * float(i) / float(n)
		var h: float = h_at.call(t)
		if absf(h - h0) > 0.005:
			# A riser between prev_t and t: find it to a centimetre.
			var lo: float = prev_t
			var hi: float = t
			for k in 6:
				var mid: float = (lo + hi) * 0.5
				if absf(float(h_at.call(mid)) - h0) > 0.005:
					hi = mid
				else:
					lo = mid
			out.append([t0, (lo + hi) * 0.5, h0])
			t0 = (lo + hi) * 0.5
			h0 = h
		prev_t = t
	out.append([t0, L, h0])
	return out


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func lib_for(slot: String) -> String:
	return String(libraries.get(slot, default_library))


func sym(slot: String) -> int:
	var id: int = Draw.sym(lib_for(slot), slot)
	return id if id >= 0 else Draw.sym(default_library, slot)


## What the validator and the builder say about the graph now.
func notes() -> PackedStringArray:
	return _notes


# -- building ------------------------------------------------------------------------------------

func rebuild() -> void:
	if graph == null:
		_clear_unused({})
		return
	var used: Dictionary = {}
	var routes: Array = graph.call("routes")
	_s0.clear()
	for r in routes:
		var s: float = 0.0
		for ei in r["edges"]:
			_s0[int(ei)] = s
			s += _floor_len(graph.edges[int(ei)])
	_gaps = _crossings()
	_geo.clear()
	for i in graph.edges.size():
		_lay_edge(i, graph.edges[i], float(_s0.get(i, 0.0)), _gaps.get(i, []), used)
	for n in graph.nodes:
		_lay_node(n, used)
	_clear_unused(used)
	_notes = graph.call("validate")
	_notes.append_array(acceptance())
	# A draped route that climbs more at once than the walker can step.
	for i in _geo:
		var runs: Array = _geo[i]["runs"]
		for k in range(1, runs.size()):
			var rise: float = absf(float(runs[k][2]) - float(runs[k - 1][2]))
			if rise > Spec.STEP_MAX_M + 0.005:
				_notes.append("Route %d changes height by %.2f m at once, more than a step (%.2f m)." % [int(i), rise, Spec.STEP_MAX_M])
	_apply_look()
	_apply_shut()


func _floor_len(e: Dictionary) -> float:
	var a: Vector4 = _pos(graph.call("node", int(e["from"])))
	var b: Vector4 = _pos(graph.call("node", int(e["to"])))
	return Vector2(b.x - a.x, b.z - a.z).length()


## Metres a sheet unit, at this network's scale.
func _u() -> float:
	return Spec.UNIT_M * p_scale


## A node's place now: where it was authored, or where its anchor has carried it.
func _pos(n: Dictionary) -> Vector4:
	if n.is_empty():
		return Vector4.ZERO
	return _anchor_at.get(int(n["id"]), n["pos"])


## The object a node is for (under `targets`), or null.
func _target_of(n: Dictionary) -> Node4D:
	var host: Node = get_node_or_null(targets) if not targets.is_empty() else null
	return host.get_node_or_null(String(n.get("target", ""))) as Node4D if host != null and String(n.get("target", "")) != "" else null


func _process(dt: float) -> void:
	if Engine.is_editor_hint() or graph == null:
		return
	var moved: Array = []
	for n in graph.nodes:
		if not bool(n.get("anchor", false)):
			continue
		var t: Node4D = _target_of(n)
		if t == null:
			continue
		var id: int = int(n["id"])
		var tp: Vector4 = t.global_position - global_position
		if not _anchor_off.has(id):
			_anchor_off[id] = (n["pos"] as Vector4) - tp
		var want: Vector4 = tp + (_anchor_off[id] as Vector4)
		want.y = (n["pos"] as Vector4).y
		if (want - _pos(n)).length() > Spec.ANCHOR_MOVE_M:
			_anchor_at[id] = want
			moved.append(id)
	if not moved.is_empty():
		_relay(moved)
	if hide_blocked:
		_block_t -= dt
		if _block_t <= 0.0:
			_block_t = Spec.BLOCK_CHECK_S
			check_blocked()


## Lays again only what touches the nodes `ids`: their edges (each keeps its start along its route,
## so the marks flow on unbroken), their balls and their frames.
func _relay(ids: Array) -> void:
	var used: Dictionary = {}
	var prefixes: Array = []
	for i in graph.edges.size():
		var e: Dictionary = graph.edges[i]
		if int(e["from"]) in ids or int(e["to"]) in ids:
			_lay_edge(i, e, float(_s0.get(i, 0.0)), _gaps.get(i, []), used)
			prefixes.append("Edge%d_" % i)
	for n in graph.nodes:
		if int(n["id"]) in ids:
			_lay_node(n, used)
			prefixes.append("Cue%d" % int(n["id"]))
	# A relaid edge may have fewer runs, or a node no W cue, than before.
	for key in _items.keys():
		if used.has(key):
			continue
		for pre in prefixes:
			if String(key).begins_with(pre):
				var mi: MeshInstance4D = _items[key]
				if is_instance_valid(mi):
					mi.queue_free()
				_items.erase(key)
				break
	_apply_look()
	_apply_shut()


## Rule 09: which routes are shut now. A route is shut when any of its edges is.
func check_blocked() -> void:
	if graph == null:
		return
	var routes: Array = graph.call("routes")
	var shut: Dictionary = {}
	for ri in routes.size():
		for ei in routes[ri]["edges"]:
			if _edge_shut(int(ei)):
				shut[ri] = (routes[ri]["edges"] as Array).duplicate()
				break
	_shut = shut
	_apply_shut()


## RULE 10's ACCEPTANCE, the parts a layout can check for itself (the sheet: "Test at the actual
## player camera: direction readable, equal branches equally weighted, no symbol overlaps, object
## clearance maintained, arrival reachable, and every visible route ends at a valid destination").
## Reading direction and weighing branches need the camera, so scripts/_proof_runner.gd does them.
## The rest, as sentences for the builder's notes (empty when all is well):
##   no symbol overlaps   node art apart (chords excepted: they are a curve's own small balls)
##                        where their W bands meet, and no other node inside an object's frame
##   object clearance     no route through an object or within half a player of it, except into
##                        its own destination, and except the objects a draped route stands on;
##                        in W, where the route is walked (its nodes' W), not how far off it shows
##   arrival reachable    no destination standing inside an object (at the destination's own W)
##   valid ends           every route that stops, stops at a destination
func acceptance() -> PackedStringArray:
	var out := PackedStringArray()
	if graph == null:
		return out
	var objs: Array = _objects()
	var half_p: float = float(graph.get("player_diameter")) * 0.5
	var nodes: Array = graph.nodes
	var label := func(n: Dictionary) -> String:
		return "%s %d" % [String(n["kind"]).capitalize(), int(n["id"])]
	for i in nodes.size():
		var a: Dictionary = nodes[i]
		if String(a["kind"]) == "chord":
			continue
		for j in range(i + 1, nodes.size()):
			var b: Dictionary = nodes[j]
			if String(b["kind"]) == "chord":
				continue
			var pa: Vector4 = _pos(a)
			var pb: Vector4 = _pos(b)
			if absf(pa.w - pb.w) > (float(a.get("band", 1.2)) + float(b.get("band", 1.2))) * 0.5:
				continue
			var need: float = art_radius(a) + art_radius(b)
			var d: float = Vector2(pa.x - pb.x, pa.z - pb.z).length()
			if d < need:
				out.append("%s and %s overlap (%.2f m apart, their art needs %.2f)." % [label.call(a), label.call(b), d, need])
	for n in nodes:
		var p: Vector4 = _pos(n)
		for o in objs:
			var rect: Rect2 = o["rect"]
			if String(n["kind"]) == "destination" and rect.has_point(Vector2(p.x, p.z)) and absf(p.w - float(o["w"])) < float(o["wd"]) * 0.5 + half_p:
				out.append("%s stands inside %s: nobody can arrive there." % [label.call(n), String(o["name"])])
			if absf(p.w - float(o["w"])) > (float(n.get("band", 1.2)) + float(o["wd"])) * 0.5:
				continue
			if String(n.get("target", "")) != String(o["name"]):
				var framed: bool = false
				for m in nodes:
					if String(m.get("target", "")) == String(o["name"]) and String(m.get("frame", "none")) != "none":
						framed = true
				if framed and rect.grow(FRAME_MARGIN).has_point(Vector2(p.x, p.z)) and String(n["kind"]) != "chord":
					out.append("%s sits in the frame round %s." % [label.call(n), String(o["name"])])
	for i in graph.edges.size():
		var e: Dictionary = graph.edges[i]
		var na: Dictionary = graph.call("node", int(e["from"]))
		var nb: Dictionary = graph.call("node", int(e["to"]))
		if na.is_empty() or nb.is_empty():
			continue
		var A: Vector4 = _pos(na)
		var B: Vector4 = _pos(nb)
		# Where in W the route is walked: from its from-node's W to its to-node's (a "here" route
		# at its start's, a "reveal" route at its end's), half a player either side.
		var w_lo: float = minf(A.w, B.w) - half_p
		var w_hi: float = maxf(A.w, B.w) + half_p
		match String(e.get("w_mode", "static")):
			"here":
				w_lo = A.w - half_p
				w_hi = A.w + half_p
			"reveal":
				w_lo = B.w - half_p
				w_hi = B.w + half_p
		var stands: Dictionary = {}
		if _geo.has(i):
			for r in _geo[i]["runs"]:
				stands[snappedf(float(r[2]), 0.01)] = true
		for o in objs:
			if String(o["name"]) in [String(na.get("target", "")), String(nb.get("target", ""))]:
				continue
			if float(o["w"]) + float(o["wd"]) * 0.5 < w_lo or float(o["w"]) - float(o["wd"]) * 0.5 > w_hi:
				continue
			if drape and stands.has(snappedf(float(o["top"]), 0.01)):
				continue
			var rect: Rect2 = (o["rect"] as Rect2).grow(half_p)
			var L: float = Vector2(B.x - A.x, B.z - A.z).length()
			var steps: int = maxi(1, ceili(L / 0.1))
			for k in steps + 1:
				var t: float = float(k) / float(steps)
				if rect.has_point(Vector2(lerpf(A.x, B.x, t), lerpf(A.z, B.z, t))):
					out.append("The route from %s to %s comes within half a player (%.1f m) of %s." % [label.call(na), label.call(nb), half_p, String(o["name"])])
					break
	var outs: Dictionary = {}
	var ins: Dictionary = {}
	for e in graph.edges:
		outs[int(e["from"])] = true
		ins[int(e["to"])] = true
	for n in nodes:
		if ins.has(int(n["id"])) and not outs.has(int(n["id"])) and String(n["kind"]) != "destination":
			out.append("A route stops at %s, not at a destination." % label.call(n))
	return out


## The objects under `targets`: name, footprint (x, z, in this network's space), W, W depth, top.
func _objects() -> Array:
	var out: Array = []
	var host: Node = get_node_or_null(targets) if not targets.is_empty() else null
	if host == null:
		return out
	for c in host.get_children():
		if not (c is Node4D) or not c.has_method("footprint"):
			continue
		var t := c as Node4D
		var f: Vector2 = t.call("footprint")
		var tp: Vector4 = t.global_position - global_position
		var sz: Variant = t.get("size")
		out.append({"name": String(t.name), "rect": Rect2(Vector2(tp.x, tp.z) - f * 0.5, f), "w": tp.w,
			"wd": float(t.get("w_depth")) if t.get("w_depth") != null else 1.2, "top": tp.y + (float((sz as Vector3).y) if sz is Vector3 else 0.0)})
	return out


## Whether the routes are shut: route index -> its edges.
func shut_routes() -> Dictionary:
	return _shut


func _apply_shut() -> void:
	var hidden: Dictionary = {}
	for ri in _shut:
		for ei in _shut[ri]:
			hidden[int(ei)] = true
	for key in _items:
		var mi: MeshInstance4D = _items[key]
		if is_instance_valid(mi) and String(key).begins_with("Edge"):
			mi.visible = not hidden.has(int(mi.get_meta("edge", -1)))


## A static box across edge `i` at BLOCK_H_M above each run of its ground, its own two ends' objects
## looked through.
func _edge_shut(i: int) -> bool:
	if not _geo.has(i):
		return false
	var geo: Dictionary = _geo[i]
	var A: Vector4 = geo["A"]
	var dir: Vector2 = geo["dir"]
	var shear: float = geo["shear"]
	var skip: Array[Node4D] = []
	var e: Dictionary = graph.edges[i]
	for id in [int(e["from"]), int(e["to"])]:
		var t: Node4D = _target_of(graph.call("node", id))
		if t != null:
			for b in t.find_children("*", "StaticBody4D", true, false):
				skip.append(b as Node4D)
	var o: Vector4 = global_position
	for r in geo["runs"]:
		var t0: float = float(r[0]) + 0.05
		var t1: float = float(r[1]) - 0.05
		if t1 <= t0:
			continue
		var d4 := Vector4(dir.x, 0.0, dir.y, shear)
		var params := RaycastParameters4D.new()
		params.global_ray_origin = o + Vector4(A.x + dir.x * t0, float(r[2]) + Spec.BLOCK_H_M, A.z + dir.y * t0, float(geo["w_at"].call(t0)))
		params.global_ray_direction = d4.normalized()
		params.max_distance = (t1 - t0) * d4.length()
		params.collision_mask = drape_mask
		var ex: Array[Node4D] = skip.duplicate()
		for k in 8:
			params.set_exclude_nodes(ex)
			var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
			if hit.is_empty() or not bool(hit.get("hit", false)):
				break
			var body: Object = hit.get("body")
			if body is StaticBody4D:
				return true
			if not (body is Node4D):
				break
			ex.append(body as Node4D)
	return false


## The radius of a node's art on the floor, metres, which marks keep clear of (plus 0.25P).
func art_radius(n: Dictionary) -> float:
	match String(n.get("kind", "")):
		"chord":
			return Spec.CHORD_BALL_R * _u()
		"bend":
			return (Spec.BEND_RING_R + Spec.BEND_RING_W * 0.5) * _u()
		"junction":
			return Draw.sym_size(sym("C")).x * 0.5 * _u() * Spec.JUNCTION_SCALE
		"destination":
			return Draw.sym_size(sym("D")).x * 0.5 * _u()
	return 0.12


func _item(key: String, mode: int, used: Dictionary) -> MeshInstance4D:
	used[key] = true
	var mi: MeshInstance4D = _items.get(key)
	if mi == null or not is_instance_valid(mi) or int(mi.get_meta("mode", -1)) != mode:
		if mi != null and is_instance_valid(mi):
			mi.queue_free()
		mi = Draw.box(self, key, mode, Vector4.ONE, Vector4.ZERO)
		mi.set_meta("mode", mode)
		mi.set_meta(GENERATED, true)
		_items[key] = mi
	return mi


func _size(mi: MeshInstance4D, s: Vector4) -> void:
	var m: BoxTetraMesh4D = mi.mesh as BoxTetraMesh4D
	if m.size != s:
		m.size = s
	Draw.set_param(mi, "box_size", s)
	Draw.set_param(mi, "w_half", s.w * 0.5)


func _lay_edge(i: int, e: Dictionary, s0: float, gap_list: Array, used: Dictionary) -> void:
	var na: Dictionary = graph.call("node", int(e["from"]))
	var nb: Dictionary = graph.call("node", int(e["to"]))
	if na.is_empty() or nb.is_empty():
		return
	var A: Vector4 = _pos(na)
	var B: Vector4 = _pos(nb)
	var d := Vector2(B.x - A.x, B.z - A.z)
	var L: float = d.length()
	if L < 0.05:
		return
	var dir: Vector2 = d / L
	var mode: String = String(e.get("w_mode", "static"))
	var band: float = float(e.get("band", 1.2))
	var wc: float = 0.0
	var depth: float = Spec.W_REACH * 2.0
	var shear: float = 0.0
	match mode:
		"here":
			wc = A.w
			depth = band
		"reveal":
			wc = B.w
			depth = band
		"follow":
			wc = (A.w + B.w) * 0.5
			depth = band
			shear = (B.w - A.w) / L
	var primary: bool = String(e.get("priority", "primary")) == "primary"
	var mark: int = sym("A" if primary else "B")
	# A chord the route runs on through is a joint: marks are whole there, drawn by the stretch that
	# holds their middle and reaching over the joint, so the box is that much longer at that end.
	var join0: bool = String(na.get("kind", "")) == "chord" and bool(graph.call("is_pass_through", int(na["id"])))
	var join1: bool = String(nb.get("kind", "")) == "chord" and bool(graph.call("is_pass_through", int(nb["id"])))
	var half: float = (Draw.sym_size(mark).x * 0.5 * Spec.UNIT_M + 0.04) * p_scale
	var pad: float = (Spec.HIDE_GAP_M if clear_style == "hide" else Spec.CLEAR_M) * p_scale
	var c0: float = art_radius(na) + pad
	var c1: float = art_radius(nb) + pad
	# The short-segment rule is about crowding end markers; a joint has none.
	var room: float = L - (0.0 if join0 else c0) - (0.0 if join1 else c1)
	var marks_on: bool = room >= Spec.SHORT_SEGMENT_M * p_scale * 0.5 or (join0 and join1)
	var w_at := func(t: float) -> float:
		return wc + shear * (t - L * 0.5)
	# One box per run of ground at one height (one run unless draped over a step).
	var runs: Array = _runs(A, dir, L, w_at)
	_geo[i] = {"A": A, "dir": dir, "L": L, "shear": shear, "w_at": w_at, "runs": runs}
	for k in runs.size():
		var t0: float = float(runs[k][0])
		var t1: float = float(runs[k][1])
		var first: bool = k == 0
		var last: bool = k == runs.size() - 1
		var ext0: float = half if (join0 and first) else 0.0
		var ext1: float = half if (join1 and last) else 0.0
		var seg: float = t1 - t0
		var mid: float = t0 + (seg - ext0 + ext1) * 0.5
		var mi: MeshInstance4D = _item("Edge%d" % i if first else "Edge%d_%d" % [i, k], Draw.SEGMENT, used)
		_size(mi, Vector4(seg + ext0 + ext1, Spec.BOX_H_M, EDGE_W * p_scale, depth))
		mi.position = Vector4(A.x + dir.x * mid, float(runs[k][2]) + Spec.PROUD_M, A.z + dir.y * mid, float(w_at.call(mid)))
		mi.basis = Projection(Vector4(dir.x, 0, dir.y, shear), Vector4(0, 1, 0, 0), Vector4(-dir.y, 0, dir.x, 0), Vector4(0, 0, 0, 1))
		Draw.set_param(mi, "mark_sym", mark if marks_on else -1)
		Draw.set_param(mi, "join0", 1.0 if (join0 and first) else 0.0)
		Draw.set_param(mi, "join1", 1.0 if (join1 and last) else 0.0)
		Draw.set_param(mi, "drop0", 0.0 if first else 1.0)
		Draw.set_param(mi, "drop1", 0.0 if last else 1.0)
		Draw.set_param(mi, "ext0", ext0)
		Draw.set_param(mi, "ext1", ext1)
		Draw.set_param(mi, "mark_half", half)
		Draw.set_param(mi, "repeat_m", (Spec.PRIMARY_REPEAT_M if primary else Spec.SECONDARY_REPEAT_M) * p_scale)
		Draw.set_param(mi, "guide_dot", 0.0 if primary else Spec.GUIDE_DOT_M * p_scale)
		Draw.set_param(mi, "s0", s0 + t0)
		Draw.set_param(mi, "clear0", c0 if first else 0.0)
		Draw.set_param(mi, "clear1", c1 if last else 0.0)
		var g := Vector4(-1, -1, -1, -1)
		if gap_list.size() > 0:
			g.x = float(gap_list[0]) - GAP_HALF - t0
			g.y = float(gap_list[0]) + GAP_HALF - t0
		if gap_list.size() > 1:
			g.z = float(gap_list[1]) - GAP_HALF - t0
			g.w = float(gap_list[1]) + GAP_HALF - t0
		Draw.set_param(mi, "gap0", g)
		mi.set_meta("edge", i)


func _lay_node(n: Dictionary, used: Dictionary) -> void:
	var id: int = int(n["id"])
	var kind: String = String(n["kind"])
	var P: Vector4 = _pos(n)
	var band: float = float(n.get("band", 1.2))
	var mi: MeshInstance4D
	match kind:
		"chord", "bend", "start":
			mi = _item("Node%d" % id, Draw.PIVOT, used)
			_size(mi, Vector4(0.5 * p_scale, Spec.BOX_H_M, 0.5 * p_scale, band))
			Draw.set_param(mi, "ring_on", 1.0 if kind == "bend" else 0.0)
			Draw.set_param(mi, "ball_r", (Spec.BEND_BALL_R if kind == "bend" else (Spec.CHORD_BALL_R if kind == "chord" else 8.0)) * _u())
			Draw.set_param(mi, "ring_r", Spec.BEND_RING_R * _u())
			Draw.set_param(mi, "ring_w", Spec.BEND_RING_W * _u())
		_:
			var slot: String = "C"
			if kind == "destination":
				slot = {"arrival": "D", "available": "E", "focused": "F", "completed": "G"}.get(String(n.get("state", "arrival")), "D")
			mi = _item("Node%d" % id, Draw.NODE, used)
			var s: int = sym(slot)
			var scale: float = Spec.JUNCTION_SCALE if kind == "junction" else 1.0
			var sz: Vector2 = Draw.sym_size(s) * _u() * scale
			_size(mi, Vector4(sz.x + 0.1, Spec.BOX_H_M, sz.y + 0.1, band))
			Draw.set_param(mi, "node_sym", s)
			Draw.set_param(mi, "node_scale", scale)
			Draw.set_param(mi, "arc_on", 1.0 if slot in ["E", "F"] else 0.0)
			Draw.set_param(mi, "accent_on", 1.0 if slot in ["E", "F"] else 0.0)
			Draw.set_param(mi, "focus", 1.0 if slot == "F" else 0.0)
	var gy: float = ground_at(P.x, P.z, P.w, P.y)
	mi.position = Vector4(P.x, gy + Spec.PROUD_M + 0.002, P.z, P.w)
	mi.basis = Projection.IDENTITY
	mi.set_meta("node", id)
	Draw.set_param(mi, "w_step", 0.0)
	# The W cue: where the route goes on at another W, a row of dots beside the node, shown at the W
	# you arrive from (the end of the stretch you can see), not at the node's own.
	var wsi: Array = w_step_info(id)
	if not wsi.is_empty() and absf(float(wsi[0])) > 0.25:
		var cue: MeshInstance4D = _item("Cue%d" % id, Draw.PIVOT, used)
		var reach: float = (art_radius(n) / _u() + 4.0 + Spec.W_CUE_GAP * float(Spec.W_CUE_MAX)) * _u() * 2.0 + 0.1
		_size(cue, Vector4(reach, Spec.BOX_H_M, 0.3, float(wsi[2])))
		cue.position = Vector4(P.x, ground_at(P.x, P.z, float(wsi[1]), P.y) + Spec.PROUD_M + 0.003, P.z, float(wsi[1]))
		cue.basis = Projection.IDENTITY
		Draw.set_param(cue, "ball_r", 0.0)
		Draw.set_param(cue, "ring_on", 0.0)
		Draw.set_param(cue, "w_step", float(wsi[0]))
		Draw.set_param(cue, "cue_from", art_radius(n) / _u() + 4.0)
		Draw.set_param(cue, "cue_ana", Spec.W_CUE_ANA)
		Draw.set_param(cue, "cue_kata", Spec.W_CUE_KATA)
		Draw.set_param(cue, "cue_dot_r", Spec.W_CUE_DOT_R)
		Draw.set_param(cue, "cue_gap", Spec.W_CUE_GAP)
	if kind == "destination" and String(n.get("frame", "none")) != "none":
		_lay_frame(n, used)


func _lay_frame(n: Dictionary, used: Dictionary) -> void:
	var host: Node = get_node_or_null(targets) if not targets.is_empty() else null
	var t: Node4D = host.get_node_or_null(String(n.get("target", ""))) as Node4D if host != null else null
	if t == null or not t.has_method("footprint"):
		return
	var round_frame: bool = String(n["frame"]) == "round"
	var s: int = sym("I" if round_frame else "H")
	if s < 0:
		return
	var foot: Vector2 = t.call("footprint")
	var outer: Vector2 = foot + Vector2.ONE * FRAME_MARGIN * 2.0
	var mi: MeshInstance4D = _item("Frame%d" % int(n["id"]), Draw.FRAME, used)
	var band: float = float(n.get("band", 1.2))
	_size(mi, Vector4(outer.x + 0.3, Spec.BOX_H_M, outer.y + 0.3, band))
	var tp: Vector4 = t.global_position - global_position
	# Round the object's foot: the ground it stands on, looking through the object itself.
	var fw: float = _pos(n).w
	var fy: float = ground_at(tp.x, tp.z, fw, tp.y, t.find_children("*", "StaticBody4D", true, false))
	mi.position = Vector4(tp.x, fy + Spec.PROUD_M, tp.z, fw)
	mi.basis = Projection.IDENTITY
	var ss: Vector2 = Draw.sym_size(s)
	var grow: Vector2 = (outer / _u() - ss) * 0.5
	if round_frame:
		grow = Vector2.ONE * (maxf(outer.x, outer.y) / _u() - ss.x) * 0.5
	Draw.set_param(mi, "frame_sym", s)
	Draw.set_param(mi, "frame_grow", grow)
	Draw.set_param(mi, "frame_round", 1.0 if round_frame else 0.0)
	var ap: Vector2 = n.get("approach", Vector2(0, 1))
	Draw.set_param(mi, "approach", Vector3(ap.x, ap.y, FRAME_GAP / _u()))


func _clear_unused(used: Dictionary) -> void:
	for key in _items.keys():
		if not used.has(key):
			var mi: MeshInstance4D = _items[key]
			if is_instance_valid(mi):
				mi.queue_free()
			_items.erase(key)


## The W a route lies at where it leaves (or, for a destination, reaches) node `id`, against the W
## it arrived at: what the W cue shows. Edges at a fixed W ("here", "reveal") step; "follow" climbs
## smoothly (no step) and "static" lies everywhere.
func w_step_at(id: int) -> float:
	var info: Array = w_step_info(id)
	return float(info[0]) if not info.is_empty() else 0.0


## [the step in W, the W you arrive at the node from, that stretch's band], or [] if no step.
func w_step_info(id: int) -> Array:
	var n: Dictionary = graph.call("node", id)
	if n.is_empty():
		return []
	var in_w: Variant = null
	var out_w: Variant = null
	var in_band: float = 1.2
	for e in graph.edges:
		var mode: String = String(e.get("w_mode", "static"))
		if mode in ["static", "follow"]:
			continue
		var a: Dictionary = graph.call("node", int(e["from"]))
		var b: Dictionary = graph.call("node", int(e["to"]))
		var ew: float = _pos(a).w if mode == "here" else _pos(b).w
		if int(e["to"]) == id:
			in_w = ew
			in_band = float(e.get("band", 1.2))
		if int(e["from"]) == id:
			out_w = ew
	if String(n.get("kind", "")) == "destination" and in_w != null:
		return [_pos(n).w - float(in_w), float(in_w), in_band]
	if in_w != null and out_w != null:
		return [float(out_w) - float(in_w), float(in_w), in_band]
	return []


## Where routes cross without a node (rule 05): {edge index: [distances along it to break at]},
## the break going to the weaker of the two (secondary before primary, else the later edge).
func _crossings() -> Dictionary:
	var out: Dictionary = {}
	var E: Array = graph.edges
	for i in E.size():
		for j in range(i + 1, E.size()):
			var a: Dictionary = E[i]
			var b: Dictionary = E[j]
			var shared: bool = int(a["from"]) in [int(b["from"]), int(b["to"])] or int(a["to"]) in [int(b["from"]), int(b["to"])]
			if shared:
				continue
			var p0: Vector4 = _pos(graph.call("node", int(a["from"])))
			var p1: Vector4 = _pos(graph.call("node", int(a["to"])))
			var q0: Vector4 = _pos(graph.call("node", int(b["from"])))
			var q1: Vector4 = _pos(graph.call("node", int(b["to"])))
			var hit: Variant = Geometry2D.segment_intersects_segment(Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), Vector2(q0.x, q0.z), Vector2(q1.x, q1.z))
			if hit == null:
				continue
			var x: Vector2 = hit
			var weak_b: bool = String(b.get("priority", "primary")) == "secondary" or String(a.get("priority", "primary")) == String(b.get("priority", "primary"))
			var k: int = j if weak_b else i
			var s: Vector4 = q0 if weak_b else p0
			var list: Array = out.get(k, [])
			list.append(x.distance_to(Vector2(s.x, s.z)))
			out[k] = list
	return out


# -- looks ------------------------------------------------------------------------------------------

func _apply_look() -> void:
	for key in _items:
		var mi: MeshInstance4D = _items[key]
		if not is_instance_valid(mi):
			continue
		Draw.set_param(mi, "walk", 1.0 if look == "walk" else 0.0)
		Draw.set_param(mi, "unit_m", _u())
		Draw.set_param(mi, "guide_w", Spec.GUIDE_W_M * p_scale)
		Draw.set_param(mi, "under_color", under_color)
		Draw.set_param(mi, "motion", 1.0 if motion else 0.0)
		Draw.set_param(mi, "flow", flow)


## Every slot to the next library on disk (F5).
func next_library() -> String:
	var uniq: Array = []
	for k in (Draw.symbols()["ids"] as Dictionary).keys():
		var l: String = String(k).get_slice("/", 0)
		if not (l in uniq):
			uniq.append(l)
	uniq.sort()
	var i: int = uniq.find(default_library)
	default_library = String(uniq[(i + 1) % uniq.size()])
	libraries = {}
	return default_library
