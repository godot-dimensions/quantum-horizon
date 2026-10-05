@tool
extends Resource

## PathCreator: a room's routes as a graph (the sheet's rule 01: "a graph, not scattered arrow
## objects"; rule 10's minimum room data). Saved as a .tres the scene loads, the builder edits in
## the game and the editor dock edits in the editor: the file is the link between them.
##
## NODES, each a Dictionary:
##   id        a number, unique in the graph
##   kind      "start" (where you come in), "chord" (a curve's small ball), "bend" (a turn's ball
##             and ring), "junction" (a choice), "destination" (a place to arrive and act)
##   pos       Vector4: x, y (0 on the floor), z, and its W
##   band      how deep in W its symbol is, metres (wide: it shows from far off in W)
##   state     a destination's: "arrival", "available", "focused", "completed" (rule 07)
##   target    the name of the object it is for (a node under the network's `targets`), whose
##             footprint its frame goes round; "" for none
##   frame     "none", "rect" or "round" (slots H, I)
##   approach  Vector2, the way you arrive from (x, z), where the frame opens
## EDGES, each a Dictionary:
##   from, to  node ids; the route runs from -> to (marks point that way)
##   priority  "primary" or "secondary" (rule 06: priority belongs to the route)
##   w_mode    how it lies in W (PLAN.md part F): "static" (deep, readable from any W), "here" (at
##             its from-node's W), "follow" (from the from-node's W to the to-node's, a slanted
##             band), "reveal" (only at its to-node's W)
##   band      how deep in W it is when not static, metres
##
## A ROUTE is a run of edges through chords and bends, from a start, junction or destination to the
## next; arrows go by distance along it. routes() works them out; validate() checks rule 10.
##
## NO class_name (engine_gotchas.md).

const KINDS := ["start", "chord", "bend", "junction", "destination"]
const STATES := ["arrival", "available", "focused", "completed"]
const W_MODES := ["static", "here", "follow", "reveal"]

@export var player_diameter: float = 0.6
@export var nodes: Array = []
@export var edges: Array = []
@export var next_id: int = 1


func node(id: int) -> Dictionary:
	for n in nodes:
		if int(n["id"]) == id:
			return n
	return {}


func index_of(id: int) -> int:
	for i in nodes.size():
		if int(nodes[i]["id"]) == id:
			return i
	return -1


func add_node(kind: String, pos: Vector4, extra: Dictionary = {}) -> int:
	var n: Dictionary = {"id": next_id, "kind": kind, "pos": pos, "band": 1.2, "state": "arrival", "target": "",
		"frame": "none", "approach": Vector2(0, 1)}
	n.merge(extra, true)
	nodes.append(n)
	next_id += 1
	emit_changed()
	return int(n["id"])


func add_edge(from: int, to: int, priority: String = "primary", w_mode: String = "static", band: float = 1.2) -> int:
	edges.append({"from": from, "to": to, "priority": priority, "w_mode": w_mode, "band": band})
	emit_changed()
	return edges.size() - 1


func remove_node(id: int) -> void:
	var i: int = index_of(id)
	if i < 0:
		return
	nodes.remove_at(i)
	var kept: Array = []
	for e in edges:
		if int(e["from"]) != id and int(e["to"]) != id:
			kept.append(e)
	edges = kept
	emit_changed()


## Edges in and out of node `id`.
func edges_at(id: int) -> Array:
	var out: Array = []
	for e in edges:
		if int(e["from"]) == id or int(e["to"]) == id:
			out.append(e)
	return out


## A node a route passes through rather than ends at: a chord or a bend with one way in and one out.
func is_pass_through(id: int) -> bool:
	var n: Dictionary = node(id)
	if n.is_empty() or not (String(n["kind"]) in ["chord", "bend"]):
		return false
	var ins: int = 0
	var outs: int = 0
	for e in edges:
		if int(e["to"]) == id:
			ins += 1
		if int(e["from"]) == id:
			outs += 1
	return ins == 1 and outs == 1


## The routes: [{"edges": [edge indices in order], "nodes": [ids from first to last]}, ...]. A route
## starts at a node that is not a pass-through and runs on through chords and bends.
func routes() -> Array:
	var out: Array = []
	var used: Dictionary = {}
	for i in edges.size():
		if used.has(i):
			continue
		var e: Dictionary = edges[i]
		# Walk back to the route's first edge.
		var first: int = i
		var guard: int = 0
		while is_pass_through(int(edges[first]["from"])) and guard < edges.size():
			var back: int = _edge_into(int(edges[first]["from"]))
			if back < 0 or back == i:
				break
			first = back
			guard += 1
		var r_edges: Array = []
		var r_nodes: Array = [int(edges[first]["from"])]
		var cur: int = first
		guard = 0
		while cur >= 0 and not used.has(cur) and guard <= edges.size():
			used[cur] = true
			r_edges.append(cur)
			var to: int = int(edges[cur]["to"])
			r_nodes.append(to)
			cur = _edge_out_of(to) if is_pass_through(to) else -1
			guard += 1
		out.append({"edges": r_edges, "nodes": r_nodes})
	return out


func _edge_into(id: int) -> int:
	for i in edges.size():
		if int(edges[i]["to"]) == id:
			return i
	return -1


func _edge_out_of(id: int) -> int:
	for i in edges.size():
		if int(edges[i]["from"]) == id:
			return i
	return -1


## Rule 10's checks, as plain sentences; empty when the graph is sound.
func validate() -> PackedStringArray:
	var out := PackedStringArray()
	var ids: Dictionary = {}
	for n in nodes:
		ids[int(n["id"])] = n
	for e in edges:
		if not ids.has(int(e["from"])) or not ids.has(int(e["to"])):
			out.append("An edge points at a node that is gone (%d to %d)." % [int(e["from"]), int(e["to"])])
	for n in nodes:
		var id: int = int(n["id"])
		var deg: int = edges_at(id).size()
		var kind: String = String(n["kind"])
		if deg == 0:
			out.append("%s %d stands alone: no route reaches it." % [kind.capitalize(), id])
		elif kind in ["chord", "bend"] and not is_pass_through(id):
			out.append("%s %d is not on one route through (a turn needs one way in and one out; a choice is a junction)." % [kind.capitalize(), id])
	# Every destination reachable from a start, every route ending at something you can arrive at.
	var starts: Array = []
	for n in nodes:
		if String(n["kind"]) == "start":
			starts.append(int(n["id"]))
	var seen: Dictionary = {}
	var stack: Array = starts.duplicate()
	while not stack.is_empty():
		var id: int = stack.pop_back()
		if seen.has(id):
			continue
		seen[id] = true
		for e in edges:
			if int(e["from"]) == id:
				stack.append(int(e["to"]))
	for n in nodes:
		if String(n["kind"]) == "destination" and not seen.has(int(n["id"])) and not starts.is_empty():
			out.append("Destination %d cannot be reached from a start." % int(n["id"]))
	for r in routes():
		var last: Dictionary = node(int((r["nodes"] as Array).back()))
		if not last.is_empty() and String(last["kind"]) in ["chord", "bend", "start"]:
			out.append("A route ends at %s %d instead of a junction or a destination." % [String(last["kind"]), int(last["id"])])
	return out
