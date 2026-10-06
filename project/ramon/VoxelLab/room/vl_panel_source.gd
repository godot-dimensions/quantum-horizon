extends Node

## The Voxel Lab's wall panels' data (carried/kit/panels/kit_wall_panel_4d.gd `source`): the research
## wall in its "specimen" layout, live.
##
##   LEFT     the block, its glyph, and its story's six parts, the one playing lit
##   PAGE     while the story plays: the part's own headline, what it shows and three figures; otherwise
##            the bench: what the last cut cost, as bars, cut by cut
##   TABLE    every specimen in the room, measured the same way: voxels, chunks, tetrahedra, memory,
##            and its cuts' worst frame and time to show
##
##   fill(text)        the room's words with {tokens} filled in
##   research(info)    the research panel's data
##
## Every number is measured in this run, on this machine; the footnote says so.
##
## NO class_name (engine_gotchas.md).

## The room (voxel_lab_4d.gd).
@export var room: NodePath
## The showcase whose story the wall follows (the hero block's).
@export var hero: NodePath

const SHORT := {"specimen": "what it is", "voxels": "cells and a surface", "two": "a ball and a box", "tunnel": "a tube in 4D",
	"hidden": "ana of your slice", "yours": "the bench"}
## The story's parts as the wall's rows name them (a row holds one short line).
const ROW := {"specimen": "Specimen", "voxels": "Voxels", "two": "Two cuts", "tunnel": "Tunnel", "hidden": "Hidden room", "yours": "Your turn"}


func _room() -> Node:
	return get_node_or_null(room)


func _hero() -> Node:
	return get_node_or_null(hero)


func fill(text: String) -> String:
	var ex: Node = _hero().get("exhibit") if _hero() != null else null
	if ex == null:
		return text
	var n: Dictionary = ex.call("numbers")
	var out: String = text
	for k in n:
		out = out.replace("{%s}" % k, String(n[k]))
	return out


func research(info: Resource) -> Dictionary:
	var out: Dictionary = {
		"header_left": String(info.call("research_header")) if info != null else "RESEARCH",
		"header_right": String(info.get("research_status")) if info != null else "",
	}
	var sc: Node = _hero()
	var ex: Node = sc.get("exhibit") if sc != null else null
	if ex == null:
		return out
	var n: Dictionary = ex.call("numbers")
	out["specimen"] = {"label": "SPECIMEN  %s" % String(ex.get("code")), "name": String(ex.get("title")),
		"meta": "%s VOXELS  ·  %s TETRAHEDRA" % [String(n["voxels"]), String(n["tets"])], "glyph": "block"}
	var chs: Array = ex.call("chapters")
	var now: int = int(sc.get("seq_index"))
	var rows: Array = []
	for c in chs:
		rows.append([String(ROW.get(String(c["key"]), String(c["title"]).capitalize())), String(SHORT.get(String(c["key"]), ""))])
	out["story"] = {"label": "THE STORY", "hint": ("PLAYING  ·  CLICK FOR THE NEXT PART" if now >= 0 else "PLAYS AS YOU COME NEAR"),
		"now": now, "playing": now >= 0, "progress": clampf(float(sc.get("seq_t")) / maxf(float(sc.get("seq_len")), 0.1), 0.0, 1.0), "rows": rows}
	var sp: Node = ex.get("specimen")
	var recs: Array = _cut_records(sp)
	if now >= 0 and now < chs.size():
		var c: Dictionary = chs[now]
		var lines: PackedStringArray = []
		for co in c.get("callouts", []):
			lines.append(fill(String(co[1])))
		out["page"] = {"id": "part:" + String(c["key"]), "chapter": "%02d / %02d  ·  %s" % [now + 1, chs.size(), String(c["title"])],
			"headline": fill(String(c["line"])), "text": " ".join(lines), "chart": "bars",
			"caption": "Time until each cut showed, ms (this run).",
			"metrics": _metrics(n, recs)}
	else:
		out["page"] = {"id": "bench", "chapter": "THE BENCH  ·  CUT IT YOURSELF",
			"headline": "Every cut is timed.\nNo frame waits for it.",
			"text": "A cut is an edit of air. The engine meshes the chunks it touched in C++; the lab builds their draw buffers on a worker thread and shows them together.",
			"chart": "bars", "caption": "Time until each cut showed, ms (this run).", "metrics": _metrics(n, recs)}
	var bars: Array = []
	for r in recs.slice(maxi(0, recs.size() - 12)):
		bars.append(float(r.get("latency_ms", 0.0)))
	if bars.is_empty():
		bars = [0.0]
	out["chart"] = {"values": bars, "lit": bars.size() - 1}
	out["table"] = _table()
	out["footnote"] = "Measured in this room on %s, %s, this run. Voxels counted on every second point and scaled; memory is about 1.25 KB a tetrahedron, the engine's own figure. One machine, one scene." % [
		RenderingServer.get_video_adapter_name(), OS.get_name()]
	return out


func _cut_records(sp: Node) -> Array:
	return (sp.get("records") as Array) if sp != null else []


func _metrics(n: Dictionary, recs: Array) -> Array:
	var last: Dictionary = recs[-1] if not recs.is_empty() else {}
	# Before the first cut the cut's two numbers have nothing to show, and the kit writes "measuring",
	# which read as broken on a board you pass on the way in (6 Oct): the block's own build instead.
	if recs.is_empty():
		return [
			{"value": float(String(n.get("voxels", "0")).replace(",", "")), "kind": "int", "text": "voxels of %s in the block" % String(n.get("voxel", "")), "accent": false},
			{"value": float(String(n.get("chunks", "0")).replace(",", "")), "kind": "int", "text": "chunk meshes, 8 voxels a side", "accent": true},
			{"value": float(String(n.get("tets", "0")).replace(",", "")), "kind": "int", "text": "tetrahedra on screen", "accent": false},
		]
	return [
		{"value": float(String(n.get("voxels", "0")).replace(",", "")), "kind": "int", "text": "voxels of %s in the block" % String(n.get("voxel", "")), "accent": false},
		{"value": float(last.get("latency_ms", -1.0)), "kind": "ms_live", "text": "until the last cut showed", "accent": true},
		{"value": float(last.get("worst_ms", -1.0)), "kind": "ms_live", "text": "its worst frame", "accent": false},
	]


## Every specimen in the room, measured the same way.
func _table() -> Dictionary:
	var rows: Array = []
	var current: int = -1
	var r: Node = _room()
	var stations: Array = r.get("stations") if r != null else []
	for s in stations:
		var ex: Node = s.get("exhibit")
		if ex == null or not ex.has_method("numbers"):
			continue
		var n: Dictionary = ex.call("numbers")
		var sp: Node = ex.get("specimen")
		var recs: Array = _cut_records(sp)
		var worst: float = 0.0
		var lat: float = 0.0
		for rec in recs:
			worst = maxf(worst, float(rec.get("worst_ms", 0.0)))
			lat = maxf(lat, float(rec.get("latency_ms", 0.0)))
		if s == (r.get("active") if r != null else null):
			current = rows.size()
		rows.append(["%s  %s" % [String(ex.get("title")), String(ex.get("code"))], String(n.get("voxel", "")), String(n.get("voxels", "")),
			String(n.get("chunks", "")), String(n.get("tets", "")), String(n.get("mb", "")), str(recs.size()),
			("%.0f ms" % worst) if not recs.is_empty() else "-", ("%.0f ms" % lat) if not recs.is_empty() else "-"])
	return {"heading": "BENCHMARK  every specimen in this room, measured the same way",
		"heads": ["SPECIMEN", "VOXEL", "VOXELS", "CHUNKS", "TETRAHEDRA", "MEMORY", "CUTS", "WORST FRAME", "SLOWEST TO SHOW"],
		"rows": rows, "current": current}
