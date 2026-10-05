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
## Moving a node rebuilds only what changed: boxes are kept by key and re-laid in place.
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const Draw := preload("res://ramon/CreationLab/PathCreator/render/path_draw.gd")
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

var _items: Dictionary = {}
var _queued: bool = false
var _notes: PackedStringArray = PackedStringArray()


func _ready() -> void:
	if graph != null and not graph.changed.is_connected(_later):
		graph.changed.connect(_later)
	rebuild()


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
	var info: Dictionary = {}   # edge index -> [route, s0]
	for r in routes:
		var s: float = 0.0
		for ei in r["edges"]:
			info[int(ei)] = [r, s]
			s += _floor_len(graph.edges[int(ei)])
	var gaps: Dictionary = _crossings()
	for i in graph.edges.size():
		_lay_edge(i, graph.edges[i], float(info.get(i, [null, 0.0])[1]), gaps.get(i, []), used)
	for n in graph.nodes:
		_lay_node(n, used)
	_clear_unused(used)
	_notes = graph.call("validate")
	_apply_look()


func _floor_len(e: Dictionary) -> float:
	var a: Vector4 = graph.call("node", int(e["from"])).get("pos", Vector4.ZERO)
	var b: Vector4 = graph.call("node", int(e["to"])).get("pos", Vector4.ZERO)
	return Vector2(b.x - a.x, b.z - a.z).length()


## The radius of a node's art on the floor, metres, which marks keep clear of (plus 0.25P).
func art_radius(n: Dictionary) -> float:
	match String(n.get("kind", "")):
		"chord":
			return Spec.CHORD_BALL_R * Spec.UNIT_M
		"bend":
			return (Spec.BEND_RING_R + Spec.BEND_RING_W * 0.5) * Spec.UNIT_M
		"junction":
			return Draw.sym_size(sym("C")).x * 0.5 * Spec.UNIT_M * Spec.JUNCTION_SCALE
		"destination":
			return Draw.sym_size(sym("D")).x * 0.5 * Spec.UNIT_M
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
	var A: Vector4 = na["pos"]
	var B: Vector4 = nb["pos"]
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
	var mi: MeshInstance4D = _item("Edge%d" % i, Draw.SEGMENT, used)
	_size(mi, Vector4(L, Spec.BOX_H_M, EDGE_W, depth))
	mi.position = Vector4((A.x + B.x) * 0.5, Spec.PROUD_M, (A.z + B.z) * 0.5, wc)
	mi.basis = Projection(Vector4(dir.x, 0, dir.y, shear), Vector4(0, 1, 0, 0), Vector4(-dir.y, 0, dir.x, 0), Vector4(0, 0, 0, 1))
	var primary: bool = String(e.get("priority", "primary")) == "primary"
	var pad: float = Spec.HIDE_GAP_M if clear_style == "hide" else Spec.CLEAR_M
	var c0: float = art_radius(na) + pad
	var c1: float = art_radius(nb) + pad
	var room: float = L - c0 - c1
	Draw.set_param(mi, "mark_sym", sym("A" if primary else "B") if room >= Spec.SHORT_SEGMENT_M * 0.5 else -1)
	Draw.set_param(mi, "repeat_m", Spec.PRIMARY_REPEAT_M if primary else Spec.SECONDARY_REPEAT_M)
	Draw.set_param(mi, "guide_dot", 0.0 if primary else Spec.GUIDE_DOT_M)
	Draw.set_param(mi, "s0", s0)
	Draw.set_param(mi, "clear0", c0)
	Draw.set_param(mi, "clear1", c1)
	var g := Vector4(-1, -1, -1, -1)
	if gap_list.size() > 0:
		g.x = float(gap_list[0]) - GAP_HALF
		g.y = float(gap_list[0]) + GAP_HALF
	if gap_list.size() > 1:
		g.z = float(gap_list[1]) - GAP_HALF
		g.w = float(gap_list[1]) + GAP_HALF
	Draw.set_param(mi, "gap0", g)
	mi.set_meta("edge", i)


func _lay_node(n: Dictionary, used: Dictionary) -> void:
	var id: int = int(n["id"])
	var kind: String = String(n["kind"])
	var P: Vector4 = n["pos"]
	var band: float = float(n.get("band", 1.2))
	var mi: MeshInstance4D
	match kind:
		"chord", "bend", "start":
			mi = _item("Node%d" % id, Draw.PIVOT, used)
			_size(mi, Vector4(0.5, Spec.BOX_H_M, 0.5, band))
			Draw.set_param(mi, "ring_on", 1.0 if kind == "bend" else 0.0)
			Draw.set_param(mi, "ball_r", (Spec.BEND_BALL_R if kind == "bend" else (Spec.CHORD_BALL_R if kind == "chord" else 8.0)) * Spec.UNIT_M)
			Draw.set_param(mi, "ring_r", Spec.BEND_RING_R * Spec.UNIT_M)
			Draw.set_param(mi, "ring_w", Spec.BEND_RING_W * Spec.UNIT_M)
		_:
			var slot: String = "C"
			if kind == "destination":
				slot = {"arrival": "D", "available": "E", "focused": "F", "completed": "G"}.get(String(n.get("state", "arrival")), "D")
			mi = _item("Node%d" % id, Draw.NODE, used)
			var s: int = sym(slot)
			var scale: float = Spec.JUNCTION_SCALE if kind == "junction" else 1.0
			var sz: Vector2 = Draw.sym_size(s) * Spec.UNIT_M * scale
			_size(mi, Vector4(sz.x + 0.1, Spec.BOX_H_M, sz.y + 0.1, band))
			Draw.set_param(mi, "node_sym", s)
			Draw.set_param(mi, "node_scale", scale)
			Draw.set_param(mi, "arc_on", 1.0 if slot in ["E", "F"] else 0.0)
			Draw.set_param(mi, "accent_on", 1.0 if slot in ["E", "F"] else 0.0)
			Draw.set_param(mi, "focus", 1.0 if slot == "F" else 0.0)
	mi.position = Vector4(P.x, Spec.PROUD_M + 0.002, P.z, P.w)
	mi.basis = Projection.IDENTITY
	mi.set_meta("node", id)
	Draw.set_param(mi, "w_step", 0.0)
	# The W cue: where the route goes on at another W, a row of dots beside the node, shown at the W
	# you arrive from (the end of the stretch you can see), not at the node's own.
	var wsi: Array = w_step_info(id)
	if not wsi.is_empty() and absf(float(wsi[0])) > 0.25:
		var cue: MeshInstance4D = _item("Cue%d" % id, Draw.PIVOT, used)
		var reach: float = (art_radius(n) / Spec.UNIT_M + 4.0 + Spec.W_CUE_GAP * float(Spec.W_CUE_MAX)) * Spec.UNIT_M * 2.0 + 0.1
		_size(cue, Vector4(reach, Spec.BOX_H_M, 0.3, float(wsi[2])))
		cue.position = Vector4(P.x, Spec.PROUD_M + 0.003, P.z, float(wsi[1]))
		cue.basis = Projection.IDENTITY
		Draw.set_param(cue, "ball_r", 0.0)
		Draw.set_param(cue, "ring_on", 0.0)
		Draw.set_param(cue, "w_step", float(wsi[0]))
		Draw.set_param(cue, "cue_from", art_radius(n) / Spec.UNIT_M + 4.0)
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
	mi.position = Vector4(tp.x, Spec.PROUD_M, tp.z, float((n["pos"] as Vector4).w))
	mi.basis = Projection.IDENTITY
	var ss: Vector2 = Draw.sym_size(s)
	var grow: Vector2 = (outer / Spec.UNIT_M - ss) * 0.5
	if round_frame:
		grow = Vector2.ONE * (maxf(outer.x, outer.y) / Spec.UNIT_M - ss.x) * 0.5
	Draw.set_param(mi, "frame_sym", s)
	Draw.set_param(mi, "frame_grow", grow)
	Draw.set_param(mi, "frame_round", 1.0 if round_frame else 0.0)
	var ap: Vector2 = n.get("approach", Vector2(0, 1))
	Draw.set_param(mi, "approach", Vector3(ap.x, ap.y, FRAME_GAP / Spec.UNIT_M))


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
		var ew: float = float((a["pos"] as Vector4).w) if mode == "here" else float((b["pos"] as Vector4).w)
		if int(e["to"]) == id:
			in_w = ew
			in_band = float(e.get("band", 1.2))
		if int(e["from"]) == id:
			out_w = ew
	if String(n.get("kind", "")) == "destination" and in_w != null:
		return [float((n["pos"] as Vector4).w) - float(in_w), float(in_w), in_band]
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
			var p0: Vector4 = graph.call("node", int(a["from"])).get("pos", Vector4.ZERO)
			var p1: Vector4 = graph.call("node", int(a["to"])).get("pos", Vector4.ZERO)
			var q0: Vector4 = graph.call("node", int(b["from"])).get("pos", Vector4.ZERO)
			var q1: Vector4 = graph.call("node", int(b["to"])).get("pos", Vector4.ZERO)
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
