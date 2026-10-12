extends Node

## The Arboretum's wall panels' data (carried/kit/panels/kit_wall_panel_4d.gd `source`): the
## research wall in its "methods" layout, the four pedestals side by side on one scale, and under them
## the benchmark of all four. Every number is the exhibit's own record (the bake's, or what it measured
## when grown live), and each says which.
##
##   fill(text)        the room's words with {tokens} filled in
##   research(info)    the research panel's data (kit_panel_research.gd, "methods")
##
## NO class_name (engine_gotchas.md).

const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")

## The room (arboretum_4d.gd), for its stations and which one you are at.
@export var room: NodePath

## The second figure each column shows, by method: what it took and by what.
const SECOND := {
	"voxel": ["build_ms", "to build, in GDScript"],
	"dc": ["mesh_ms", "to mesh, in the engine's C++"],
	"loft": ["build_ms", "to loft, in GDScript"],
	"oak": ["leaves", "leaves, not one a tetrahedron"],
}
const SURFACE := {"voxel": "boxes", "dc": "dual contoured", "loft": "lofted", "oak": "lofted"}
const FOLIAGE := {"voxel": "leaf cells", "dc": "leaf balls", "loft": "lofted clumps", "oak": "GPU leaves"}
const BY := {"voxel": "GDScript", "dc": "engine C++", "loft": "GDScript", "oak": "GDScript + GPU"}


func _room() -> Node:
	return get_node_or_null(room)


func _stations() -> Array:
	var r: Node = _room()
	var out: Array = []
	if r == null:
		return out
	for i in 4:
		out.append(r.get_node_or_null("Station%02d" % (i + 1)))
	return out


func fill(text: String) -> String:
	var out: String = text
	var total: int = 0
	for s in _stations():
		var ex: Node = s.get("exhibit") if s != null else null
		if ex != null:
			total += int((ex.get("record") as Dictionary).get("tets", 0))
	out = out.replace("{tets}", Bake.thousands(total))
	return out


func research(info: Resource) -> Dictionary:
	var out: Dictionary = {
		"header_left": String(info.call("research_header")) if info != null else "RESEARCH",
		"header_right": String(info.get("research_status")) if info != null else "",
	}
	var r: Node = _room()
	var here: Node = r.get("active") if r != null else null
	var cols: Array = []
	var rows: Array = []
	var current: int = -1
	var dates: Dictionary = {}
	var stations: Array = _stations()
	for i in stations.size():
		var s: Node = stations[i]
		var ex: Node = s.get("exhibit") if s != null else null
		if ex == null:
			cols.append({})
			continue
		var m: Dictionary = ex.call("info")
		var rec: Dictionary = ex.get("record")
		var key: String = String(ex.get("method"))
		var tets: int = int(rec.get("tets", 0)) + int(rec.get("clump_tets", 0))
		var live: String = String(ex.get("live_note"))
		var tier: String = ("PRE-BAKED " + String(rec.get("date", ""))).strip_edges() if live.is_empty() else "GROWN LIVE"
		if not live.is_empty() or rec.has("date"):
			dates[String(rec.get("date", ""))] = true
		var sec: Array = SECOND[key]
		var second: String
		if String(sec[0]) == "leaves":
			second = Bake.short(int(rec.get("leaves", 0)))
		else:
			second = Bake.ms(float(rec.get(String(sec[0]), 0.0)))
		var card: Dictionary = ex.call("card")
		cols.append({"label": "%02d  ·  %s" % [i + 1, String(m.get("code", ""))], "title": String(m.get("name", "")),
			"text": String(card.get("short", _first_sentence(String(card.get("method", ""))))),
			"metrics": [[Bake.short(tets), "tetrahedra, about %.0f MB" % Bake.mb(tets)], [second, String(sec[1]), key == "dc" or key == "oak"]],
			"bar": float(tets), "bar_label": tier, "here": s == here})
		if s == here:
			current = i
		rows.append([String(m.get("name", "")), SURFACE[key], Bake.thousands(tets), "%.0f MB" % Bake.mb(tets),
			Bake.ms(float(rec.get("build_ms", 0.0))), BY[key], FOLIAGE[key], "live" if not live.is_empty() else "baked"])
	out["methods"] = cols
	out["table"] = {"heading": "BENCHMARK  every tree here, measured the same way",
		"heads": ["METHOD", "SURFACE", "TETRAHEDRA", "MEMORY", "BUILT IN", "BY", "FOLIAGE", "STATE"], "rows": rows, "current": current}
	var when: String = ", ".join(PackedStringArray(dates.keys())).strip_edges()
	out["footnote"] = "Measured on %s, %s. The pedestal trees were baked%s by scripts/_bake_runner.gd and are loaded as they are; a tree grown live here is timed as it grows. One machine, one scene." % [
		RenderingServer.get_video_adapter_name(), OS.get_name(), (" " + when) if not when.is_empty() else ""]
	return out


static func _first_sentence(t: String) -> String:
	var i: int = t.find(". ")
	var s: String = t if i < 0 else t.substr(0, i + 1)
	return s if s.length() <= 120 else s.substr(0, 117) + "..."
