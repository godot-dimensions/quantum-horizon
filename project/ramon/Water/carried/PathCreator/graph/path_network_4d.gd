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

const Spec := preload("res://ramon/Water/carried/PathCreator/path_spec.gd")
const Draw := preload("res://ramon/Water/carried/PathCreator/render/path_draw.gd")
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
## EVERY STRETCH ONE WAY (6 Oct, Ramon: "remember how we can toggle cameras by pressing tab more then
## once. we could do the same for the path types"): "drawn" (or "") lays each stretch by its own
## w_mode; "static", "here", "follow" or "reveal" lays every stretch that way, to compare them over a
## whole layout. The graph is not changed.
@export_enum("drawn", "static", "here", "follow", "reveal") var w_mode_override: String = "drawn":
	set(v):
		w_mode_override = v
		_later()

## THE PEN'S LOOKS (6 Oct 2026, PenLayout/PLAN_A.md phase 5): the marks (the sheet's chevrons, balls,
## symbols, frames and W cues) and a sand strip under them are shown separately, so a route can be
## icons, a sandy path, both or neither.
@export var show_marks: bool = true:
	set(v):
		show_marks = v
		_apply_visible()
@export var show_sand: bool = false:
	set(v):
		show_sand = v
		_apply_visible()
## THE ACTION CIRCLES ALWAYS (6 Oct, Ramon: "i want a circle indicator that rotates in front of each
## landmark you can go to"): the destinations drawn even with the marks off (the pen's art look, sand
## strips and no chevrons), in the sheet's colours, so a place you can go reads in either look.
@export var show_destinations: bool = false:
	set(v):
		show_destinations = v
		_apply_visible()
		_apply_look()
## The sand strip's width, metres (a secondary route's is narrower); every node gets a round patch a
## quarter wider, so bends and joints are smooth, and a destination one `sand_patch` times wider.
@export_range(0.3, 4.0, 0.05) var sand_width: float = 1.3:
	set(v):
		sand_width = v
		_later()
@export_range(1.0, 4.0, 0.05) var sand_patch: float = 2.0:
	set(v):
		sand_patch = v
		_later()
## REVEAL: a stretch of route shows only once you have been near it (within `reveal_radius`, W
## counted as distance too), fading in at its ends, and it stays found; a route leaving a found node
## shows its first `reveal_tease` metres, so you can see that a way goes on. Off (static): every
## route shows all the time.
@export var reveal: bool = false:
	set(v):
		reveal = v
		_push_reveal()
## Whose nearness finds routes (the player).
@export var reveal_from: NodePath
@export_range(2.0, 60.0, 0.5) var reveal_radius: float = 14.0
@export_range(0.0, 20.0, 0.5) var reveal_tease: float = 3.0
@export_range(0.1, 6.0, 0.1) var reveal_fade: float = 1.5
## Look destinations' objects up anywhere under `targets`, not only among its children (the pen's
## arrival markers live inside its units).
@export var targets_deep: bool = false

## THE GROUND UNDER THE SAND (6 Oct 2026): the sand's soft edge fades into the ground's own colour
## (render/path_sand.gdshader). set_ground() hands it the colours the ground is painted with: the
## pen's glow, from its Grass node (chickenpen/scripts/pen_paths_4d.gd). Empty: `under_color`.
var _ground: Dictionary = {}

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
## Reveal: edge -> the stretch found, metres along it (x to y); node id -> how far it has faded in.
var _found: Dictionary = {}
var _node_found: Dictionary = {}
var _reveal_t: float = 0.0
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
		# A body marked "drape_through" is in the way, not underfoot (the pen's fallen pillar lies
		# across its path): the route lies on whatever is under it.
		if body is StaticBody4D and not (body as Node).has_meta(&"drape_through"):
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


## How [param e] lies in W now: its own w_mode, or every stretch's ([member w_mode_override]).
func mode_of(e: Dictionary) -> String:
	return w_mode_override if w_mode_override in ["static", "here", "follow", "reveal"] else String(e.get("w_mode", "static"))


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
	_push_reveal()


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
	var nm: String = String(n.get("target", ""))
	if host == null or nm == "":
		return null
	if targets_deep:
		return host.find_child(nm, true, false) as Node4D
	return host.get_node_or_null(nm) as Node4D


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
	if reveal:
		_fade_in(dt)
		_reveal_t -= dt
		if _reveal_t <= 0.0:
			_reveal_t = 0.15
			_find_near()


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
			prefixes.append("Sand%d_" % i)
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
	_push_reveal()


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
		match mode_of(e):
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
	_apply_visible()


## What shows: the marks or the sand by their switches, and no part of a shut route.
func _apply_visible() -> void:
	var hidden: Dictionary = {}
	for ri in _shut:
		for ei in _shut[ri]:
			hidden[int(ei)] = true
	for key in _items:
		var mi: MeshInstance4D = _items[key]
		if not is_instance_valid(mi):
			continue
		var k: String = String(key)
		var on: bool = show_sand if (k.begins_with("Sand") or k.begins_with("Pad")) else show_marks
		if show_destinations and _is_destination_item(k, mi):
			on = true
		if mi.has_meta("edge") and hidden.has(int(mi.get_meta("edge", -1))):
			on = false
		mi.visible = on


# -- reveal --------------------------------------------------------------------------------------

## Forget what has been found (a restart).
func reset_reveal() -> void:
	_found.clear()
	_node_found.clear()
	_push_reveal()


## How much of `edge` has been found, metres along it (x to y; x > y: none).
func found_of(edge: int) -> Vector2:
	return _found.get(edge, Vector2(1.0e9, -1.0e9))


## The reveal state onto every box: a stretch's found part (in its own run's metres), a node's fade.
func _push_reveal() -> void:
	for key in _items:
		var mi: MeshInstance4D = _items[key]
		if not is_instance_valid(mi):
			continue
		Draw.set_param(mi, "reveal_on", 1.0 if reveal else 0.0)
		if not reveal:
			continue
		Draw.set_param(mi, "reveal_fade", reveal_fade)
		if mi.has_meta("edge"):
			var f: Vector2 = found_of(int(mi.get_meta("edge")))
			var t0: float = float(mi.get_meta("t0", 0.0))
			Draw.set_param(mi, "found0", f.x - t0)
			Draw.set_param(mi, "found1", f.y - t0)
		elif mi.has_meta("node"):
			Draw.set_param(mi, "found", float(_node_found.get(int(mi.get_meta("node")), 0.0)))


## Found nodes fade in over 0.6 s.
func _fade_in(dt: float) -> void:
	var fading: Array = []
	for id in _node_found:
		if float(_node_found[id]) < 1.0:
			_node_found[id] = minf(float(_node_found[id]) + dt / 0.6, 1.0)
			fading.append(int(id))
	if fading.is_empty():
		return
	for key in _items:
		var mi: MeshInstance4D = _items[key]
		if is_instance_valid(mi) and mi.has_meta("node") and int(mi.get_meta("node")) in fading:
			Draw.set_param(mi, "found", float(_node_found[int(mi.get_meta("node"))]))


## What the player is near now: nodes within reach, and the stretch of each edge within reach (the
## edge is straight, so that is one stretch, and what is found is kept as one: from the first
## metre found to the last).
func _find_near() -> void:
	var who: Node4D = get_node_or_null(reveal_from) as Node4D
	if who == null or graph == null:
		return
	var p: Vector4 = global_basis.inverse() * (who.global_position - global_position)
	var r: float = reveal_radius
	var changed: bool = false
	for n in graph.nodes:
		var id: int = int(n["id"])
		if _node_found.has(id):
			continue
		var q: Vector4 = _pos(n)
		if Vector3(q.x - p.x, q.z - p.z, q.w - p.w).length() <= r:
			_node_found[id] = 0.0
			changed = true
	for i in _geo:
		var g: Dictionary = _geo[i]
		var a: Vector4 = g["A"]
		var dir: Vector2 = g["dir"]
		var length: float = g["L"]
		var t: float = clampf((p.x - a.x) * dir.x + (p.z - a.z) * dir.y, 0.0, length)
		var dx: float = a.x + dir.x * t - p.x
		var dz: float = a.z + dir.y * t - p.z
		var dw: float = float((g["w_at"] as Callable).call(t)) - p.w
		var d2: float = dx * dx + dz * dz + dw * dw
		var lo: float = 1.0e9
		var hi: float = -1.0e9
		if d2 < r * r:
			var h: float = sqrt(r * r - d2)
			lo = maxf(t - h, 0.0)
			hi = minf(t + h, length)
		var e: Dictionary = graph.edges[int(i)]
		if _node_found.has(int(e["from"])):
			lo = minf(lo, 0.0)
			hi = maxf(hi, minf(reveal_tease, length))
		if _node_found.has(int(e["to"])):
			lo = minf(lo, maxf(length - reveal_tease, 0.0))
			hi = maxf(hi, length)
		if lo > hi:
			continue
		var f: Vector2 = found_of(int(i))
		var nf := Vector2(minf(f.x, lo), maxf(f.y, hi))
		if nf != f:
			_found[int(i)] = nf
			changed = true
	if changed:
		_push_reveal()


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
			return Draw.sym_size(sym("D")).x * 0.5 * _u() * float(n.get("size", 1.0))
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
	var mode: String = mode_of(e)
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
		mi.set_meta("t0", t0)
		# The sand under it: the run's own length (the node patches cover the joints), a little
		# below the marks, as deep in W and as sheared as they are.
		var sb: MeshInstance4D = _item("Sand%d" % i if first else "Sand%d_%d" % [i, k], Draw.SAND, used)
		var sm: float = t0 + seg * 0.5
		_size(sb, Vector4(seg, Spec.BOX_H_M, sand_width * (1.0 if primary else 0.6), depth))
		sb.position = Vector4(A.x + dir.x * sm, float(runs[k][2]) + Spec.PROUD_M - 0.004, A.z + dir.y * sm, float(w_at.call(sm)))
		sb.basis = mi.basis
		Draw.set_param(sb, "s0", s0 + t0)
		Draw.set_param(sb, "sand_round", 0.0)
		sb.set_meta("edge", i)
		sb.set_meta("t0", t0)
		_editor_tint(mi, mode)
		_editor_tint(sb, mode)


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
			# A destination may be drawn larger ("size", 6 Oct: Trym's house, "on top a larger destination circle").
			var scale: float = (Spec.JUNCTION_SCALE if kind == "junction" else 1.0) * float(n.get("size", 1.0))
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
	# The sand patch: a little wider than the strip at a node on the way, so it covers the corners
	# two strips' square ends leave where they meet at an angle; wider again at a destination.
	var pad: MeshInstance4D = _item("Pad%d" % id, Draw.SAND, used)
	var pad_d: float = sand_width * (sand_patch if kind == "destination" else 1.25)
	_size(pad, Vector4(pad_d, Spec.BOX_H_M, pad_d, band))
	pad.position = Vector4(P.x, gy + Spec.PROUD_M - 0.004, P.z, P.w)
	pad.basis = Projection.IDENTITY
	Draw.set_param(pad, "sand_round", 1.0)
	Draw.set_param(pad, "s0", float(id) * 7.31)
	pad.set_meta("node", id)
	_editor_tint(mi, "")
	_editor_tint(pad, "")
	Draw.set_param(mi, "w_step", 0.0)
	# The W cue: where the route goes on at another W, a row of dots beside the node, shown at the W
	# you arrive from (the end of the stretch you can see), not at the node's own.
	var wsi: Array = w_step_info(id)
	if not wsi.is_empty() and absf(float(wsi[0])) > 0.25:
		var cue: MeshInstance4D = _item("Cue%d" % id, Draw.PIVOT, used)
		cue.set_meta("node", id)
		_editor_tint(cue, "")
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
	var t: Node4D = _target_of(n)
	if t == null or not t.has_method("footprint"):
		return
	var round_frame: bool = String(n["frame"]) == "round"
	var s: int = sym("I" if round_frame else "H")
	if s < 0:
		return
	var foot: Vector2 = t.call("footprint")
	var outer: Vector2 = foot + Vector2.ONE * FRAME_MARGIN * 2.0
	var mi: MeshInstance4D = _item("Frame%d" % int(n["id"]), Draw.FRAME, used)
	mi.set_meta("node", int(n["id"]))
	_editor_tint(mi, "")
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


## IN THE EDITOR'S VOLUME VIEW, EACH STRETCH IN ITS W TYPE'S COLOUR (Ramon, 7 Oct: to see the paths as shapes there,
## "editor only"). Playing they stay sand. Only the volume view reads this colour; the slice draws with the
## marks' and the sand's own shaders, which never read it. Nodes, their sand patches, W cues and frames are white.
const EDITOR_TYPE_COLOURS := {
	"static": Color(0.2, 0.8, 1.0),
	"here": Color(1.0, 0.85, 0.1),
	"follow": Color(1.0, 0.25, 0.8),
	"reveal": Color(1.0, 0.3, 0.2),
}
const EDITOR_NODE_COLOUR := Color(0.95, 0.95, 0.95)
## SOLID (Ramon, 7 Oct: "can you make them less transparent in volume view?", then "i dont have a problem with the
## paths just looking like a solid"): the volume view weighs a shape by how much of it lies along its collapsed axis,
## and a path is a thin floor box among deep ground, which drowned it. In the editor the boxes draw the volume view
## with the engine's own shader plus one setting (path_draw.gd volume_shader()): their weight times this. 1 is the
## engine's own; high reads solid. Nothing more is drawn for it.
@export_range(1.0, 1000.0, 1.0, "exp") var editor_volume_solidity: float = 200.0:
	set(v):
		editor_volume_solidity = v
		if Engine.is_editor_hint() and is_inside_tree():
			for mi in _items.values():
				if is_instance_valid(mi):
					_editor_solidity(mi)


func _editor_tint(mi: MeshInstance4D, type: String) -> void:
	if not Engine.is_editor_hint():
		return
	var m := mi.material_override as TetraMaterial4D
	var c: Color = EDITOR_TYPE_COLOURS.get(type, EDITOR_NODE_COLOUR)
	if m != null and m.albedo_color != c:
		m.albedo_color = c
	_editor_solidity(mi)


func _editor_solidity(mi: MeshInstance4D) -> void:
	var m := mi.material_override as TetraMaterial4D
	if m != null:
		m.get_projected_material_3d().set_shader_parameter("opacity_scale", editor_volume_solidity)


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
		var mode: String = mode_of(e)
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

## Whether item [param key] is a destination's own symbol (not its sand pad, frame or cue).
func _is_destination_item(key: String, mi: MeshInstance4D) -> bool:
	if not key.begins_with("Node") or graph == null or not mi.has_meta("node"):
		return false
	var n: Dictionary = graph.call("node", int(mi.get_meta("node")))
	return String(n.get("kind", "")) == "destination"


func _apply_look() -> void:
	for key in _items:
		var mi: MeshInstance4D = _items[key]
		if not is_instance_valid(mi):
			continue
		var as_walk: bool = look == "walk" and not (show_destinations and _is_destination_item(String(key), mi))
		Draw.set_param(mi, "walk", 1.0 if as_walk else 0.0)
		Draw.set_param(mi, "unit_m", _u())
		Draw.set_param(mi, "guide_w", Spec.GUIDE_W_M * p_scale)
		Draw.set_param(mi, "under_color", under_color)
		Draw.set_param(mi, "motion", 1.0 if motion else 0.0)
		Draw.set_param(mi, "flow", flow)
		var k: String = String(key)
		if k.begins_with("Sand") or k.begins_with("Pad"):
			_sand_in_field(mi)


## A sand box's place in the field, for its mottle and its ground (path_sand.gdshader `field_*`):
## where its own x and z axes lie in the field's x and z, and its W. And the ground's colours.
func _sand_in_field(mi: MeshInstance4D) -> void:
	var o: Vector4 = mi.position
	var bx: Vector4 = mi.basis.x
	var bz: Vector4 = mi.basis.z
	if is_inside_tree():
		o = global_position + global_basis * mi.position
		bx = global_basis * mi.basis.x
		bz = global_basis * mi.basis.z
	Draw.set_param(mi, "field_origin", Vector2(o.x, o.z))
	Draw.set_param(mi, "field_x", Vector2(bx.x, bx.z))
	Draw.set_param(mi, "field_z", Vector2(bz.x, bz.z))
	Draw.set_param(mi, "field_w", o.w)
	Draw.set_param(mi, "field_wx", bx.w)
	Draw.set_param(mi, "ground_mode", 0.0 if _ground.is_empty() else 1.0)
	for gk in _ground:
		Draw.set_param(mi, String(gk), _ground[gk])


## The ground's colours for the sand's edge: glow_area (centre x, z, full out to, gone by),
## glow_colour, edge_colour (Vector3s, sRGB), glow_on, glow_w. An empty Dictionary: under_color. With
## ground_mode 2.0 and ground_tex, ground_breaks, ground_breaks_n, ground_size: the ground's own paint
## (path_sand.gdshader says why).
func set_ground(p: Dictionary) -> void:
	_ground = p
	_apply_look()


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
