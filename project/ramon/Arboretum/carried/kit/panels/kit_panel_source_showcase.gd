@tool
extends Node

## Kit: a wall panel source for a room with a showcase (kit_showcase_4d.gd): it turns the animal on
## the plinth, the part of its story playing, and what the bench measured into the plain data the
## two wall panels show (kit_wall_panel_4d.gd `source`). Another prototype writes its own source
## with the same two methods and the panels show it the same way:
##   fill(text)          the room's words with their {tokens} filled in
##   research(info)      the research panel's data (keys: kit_panel_research.gd sample())
##
## The measurements are the first research wall's (kit_research_wall_4d.gd), moved here as they
## were: every number from the exhibit's own data and its bench (kit_bench.gd), the walk's cost kept
## in the bench book as it walks, every specimen's record read back every two seconds.
##
## NO class_name (engine_gotchas.md).

const Presentation := preload("res://ramon/Arboretum/carried/kit/kit_presentation.gd")
const Bench := preload("res://ramon/Arboretum/carried/kit/kit_bench.gd")

## Short lines under each part's name in the story list.
const STEP_LINES := {"balls": "placed by a designer", "skin": "lofted by the tool", "slice": "seen through W",
	"rig": "joints from the balls", "walk": "rigid pieces in motion"}
const HEADS := ["SPECIMEN", "BALLS", "TETRAHEDRA", "LOFTED IN", "ONE LEG", "WALK EACH FRAME", "IF RE-LOFTED", "RIGID IS"]

@export var showcase: NodePath

var _clock: float = 0.0
var _serial: int = -1
var _data: Dictionary = {}
var _shape: Dictionary = {}
var _profile: Dictionary = {}
var _stops: Array = []
var _records: Dictionary = {}
var _records_at: float = -10.0
var _wrote_at: float = -10.0


func _process(delta: float) -> void:
	_clock += delta


func _sc() -> Node:
	return get_node_or_null(showcase) if not showcase.is_empty() else null


## `text` with {name}, {balls} and {action} filled in from the animal on the plinth.
func fill(text: String) -> String:
	if not text.contains("{"):
		return text
	var sc: Node = _sc()
	var d: Dictionary = sc.call("data") if sc != null and not Engine.is_editor_hint() else {}
	var nm: String = String(d.get("name", "")).to_lower()
	var balls: int = int((d.get("stats", {}) as Dictionary).get("balls", 0))
	var act: String = String(sc.call("action_label")) if sc != null and not Engine.is_editor_hint() else ""
	return text.replace("{name}", nm if not nm.is_empty() else "goat").replace("{balls}", str(balls) if balls > 0 else "24") \
		.replace("{action}", act if not act.is_empty() else "Add a ball")


func _cache(sc: Node) -> void:
	if int(sc.get("serial")) != _serial:
		_serial = int(sc.get("serial"))
		_data = {}
		_profile = {}
		_stops = []
		_shape = {}
	if _data.is_empty():
		_data = sc.call("data")
	if _profile.is_empty() and sc.has_method("profile"):
		_profile = sc.call("profile")
		_stops = sc.call("slice_stops") if sc.has_method("slice_stops") else []
	if _shape.is_empty() and sc.has_method("shape"):
		_shape = sc.call("shape")


func research(info: Resource) -> Dictionary:
	var out: Dictionary = {
		"header_left": String(info.call("research_header")) if info != null else "RESEARCH",
		"header_right": String(info.get("research_status")) if info != null else "",
	}
	var sc: Node = _sc()
	if sc == null:
		return out
	_cache(sc)
	if _data.is_empty():
		out["page"] = {"id": "waiting", "chapter": "", "headline": "Waiting for a specimen", "metrics": []}
		return out
	var ex: Node = sc.get("exhibit")
	var bench: Dictionary = sc.call("bench")
	var code: String = String(_data.get("code", "XX-01"))
	var st: Dictionary = _data.get("stats", {})
	# The bench book: the walk's measured cost kept as it walks, every specimen read back now and then.
	if bool(bench.get("walking", false)) and float(bench.get("anim_ms", -1.0)) > 0.0 and _clock - _wrote_at > 3.0:
		_wrote_at = _clock
		Bench.write(code, {"anim_ms": float(bench["anim_ms"])})
	if _clock - _records_at > 2.0:
		_records_at = _clock
		_records = Bench.all()
	var want: int = int(sc.get("seq_index"))
	var playing: bool = want >= 0
	var progress: float = clampf(float(sc.get("seq_t")) / maxf(float(sc.get("seq_len")), 0.01), 0.0, 1.0) if playing else 0.0
	var name: String = String(_data.get("name", ""))
	out["specimen"] = {"label": "SPECIMEN  " + code, "name": name,
		"meta": "%d BALLS  ·  %s TETRAHEDRA" % [int(st.get("balls", 0)), Presentation.thousands(int(st.get("tetra", 0)))],
		"glyph": String(_data.get("icon", name.to_lower()))}
	var rows: Array = []
	for ch in Presentation.chapters():
		rows.append([String(ch["title"]).capitalize(), String(STEP_LINES.get(String(ch["key"]), ""))])
	var hint: String = "PLAYING  ·  CLICK FOR THE NEXT PART" if playing else ("ARRIVING" if bool(sc.call("arriving")) else "PAUSED  ·  CLICK TO PLAY")
	out["story"] = {"label": "THE STORY", "hint": hint, "rows": rows, "now": want, "playing": playing, "progress": snappedf(progress, 0.02)}
	var key: String = String(Presentation.chapters()[want]["key"]) if playing else "summary"
	out["page"] = _page(sc, ex, key, want, bench, st, code)
	out["chart"] = _chart(sc, ex, key, bench)
	out["table"] = _table(code, bench)
	var when: String = String(bench.get("measured", Time.get_date_string_from_system()))
	out["footnote"] = "Measured in this room on %s, %s. Loft times recorded %s; the walk is timed every frame it plays. One machine, one scene." % [RenderingServer.get_video_adapter_name(), OS.get_name(), when]
	return out


func _page(sc: Node, _ex: Node, key: String, index: int, bench: Dictionary, st: Dictionary, code: String) -> Dictionary:
	var nm: String = String(_data.get("name", "specimen")).to_lower()
	var anim: float = float(bench.get("anim_ms", -1.0))
	var reloft: float = float(bench.get("limb_ms", -1.0)) * float(bench.get("limbs", 0))
	var balls: int = int(st.get("balls", 0))
	var tetra: int = int(st.get("tetra", 0))
	var m := func(v: float, kind: String, text: String, accent: bool = false) -> Dictionary:
		return {"value": v, "kind": kind, "text": text, "accent": accent}
	var p: Dictionary = {"id": "%s:%s:%d" % [code, key, _serial]}
	var n: int = Presentation.chapters().size()
	p["chapter"] = ("%02d / %02d  ·  %s" % [index + 1, n, String(Presentation.chapters()[index]["title"]).to_upper()]) if index >= 0 else "SPECIMEN FILE  ·  %s" % nm.to_upper()
	match key:
		"balls":
			p["headline"] = "Every shape starts\nas a handful of balls."
			p["text"] = "A designer places each ball by hand. Each one is a cross-section of the body: a size, two stretches, a squareness, and a reach into W."
			p["chart"] = "balls"
			p["metrics"] = [m.call(float(balls), "int", "balls placed by hand"),
				m.call(float(tetra) / maxf(float(balls), 1.0), "ratio", "tetrahedra the tool makes from every ball", true),
				m.call(float(st.get("stages", 0)), "int", "build steps from the first ball to the finished body")]
			p["caption"] = "The %s's balls, drawn from the exhibit itself, lit as they are placed." % nm
		"skin":
			p["headline"] = "The tool lofts the skin.\nNothing is modelled by hand."
			p["text"] = "Between neighbouring balls the loft fills in tetrahedra, the four-dimensional cousin of triangles. Each bar is the mesh after one more build step."
			p["chart"] = "bars"
			p["metrics"] = [m.call(float(tetra), "int", "tetrahedra in the finished body"),
				m.call(float(bench.get("build_ms", -1.0)), "ms", "to loft all of it from its balls, on this machine", true),
				m.call(float(st.get("mb", 0.0)), "mb", "of mesh data in memory")]
			p["caption"] = "Tetrahedra after each build step of the %s." % nm
		"slice":
			var frac: float = float(sc.call("slice_fraction"))
			var bins: PackedFloat32Array = _profile.get("bins", PackedFloat32Array())
			var cut: float = -1.0
			if bins.size() > 1:
				cut = bins[clampi(int(round((frac * 0.5 + 0.5) * float(bins.size() - 1))), 0, bins.size() - 1)] * 100.0
			p["headline"] = "Four dimensions,\nseen one slice at a time."
			p["text"] = "We only ever see a 3D slice of a 4D body. Slide the slice along W and the same animal shows a different shape."
			p["chart"] = "profile"
			p["metrics"] = [m.call(float(st.get("reach", 0.0)), "pm", "its reach through W, either side of its middle"),
				m.call(cut, "pct_live", "of its fullest cross-section, in the slice right now", true),
				m.call(float(int(sc.get("slice_index")) + 1), "slice", "the slice on show, of nine")]
			p["caption"] = "How much of the %s each W holds. The line is the slice you see." % nm
		"rig":
			p["headline"] = "The balls are the joints.\nThe rig comes with the build."
			p["text"] = "The same balls that shape the body become its skeleton, so a new animal is ready to animate the moment it is built."
			p["chart"] = "joints"
			p["metrics"] = [m.call(float(balls), "int", "joints, one for every ball"),
				m.call(float(bench.get("pieces", -1)), "int", "rigid pieces hung on them", true),
				m.call(0.0, "zero", "bones placed by hand")]
			p["caption"] = "The %s's joints, ball to ball, as the x-ray shows them." % nm
		"walk":
			p["headline"] = "It walks without\nrebuilding its mesh."
			p["text"] = "The skin is cut once into rigid pieces. Each frame moves a few transforms and never a vertex, so the cost stays a sliver of a frame."
			p["chart"] = "cost"
			p["metrics"] = [m.call(anim, "ms_live", "the walk's cost each frame, measured live", true),
				m.call(reloft, "ms", "if its %d legs were re-lofted every frame" % int(bench.get("limbs", 0))),
				m.call(reloft / anim if anim > 0.0 and reloft > 0.0 else -1.0, "times", "cheaper with rigid pieces")]
			p["caption"] = "Milliseconds a frame, on a log scale: the walk, live, against re-lofting."
		_:
			p["headline"] = "Built from %d balls.\n%s" % [balls, ("Walking at %s a frame." % Presentation.ms(anim)) if anim > 0.0 else "Walking without re-lofting."]
			p["text"] = "Press 1 to 6 for another specimen. Every one is built, sliced and animated the same way, so their numbers compare."
			p["chart"] = "balls"
			p["metrics"] = [m.call(float(tetra), "int", "tetrahedra, lofted from its balls"),
				m.call(float(bench.get("build_ms", -1.0)), "ms", "to loft it whole, on this machine"),
				m.call(anim, "ms", "for its walk, each frame", true)]
			p["caption"] = "The %s, ball by ball." % nm
	return p


func _chart(sc: Node, ex: Node, key: String, bench: Dictionary) -> Dictionary:
	var balls: Array = _shape.get("balls", [])
	match key:
		"skin":
			var on_show: int = int(ex.call("stage_in_view")) if ex != null and ex.has_method("stage_in_view") else -1
			return {"values": _data.get("bars", []), "lit": on_show}
		"slice":
			return {"bins": _profile.get("bins", PackedFloat32Array()), "stops": _stops, "index": int(sc.get("slice_index")), "frac": float(sc.call("slice_fraction"))}
		"rig":
			return {"balls": balls, "bones": _shape.get("bones", []), "gold": true, "pulse": int(_clock * 7.0) % maxi(balls.size(), 1)}
		"walk":
			return {"samples": bench.get("samples", PackedFloat32Array()), "anim": float(bench.get("anim_ms", -1.0)),
				"reloft": float(bench.get("limb_ms", -1.0)) * float(bench.get("limbs", 0))}
	var lit: int = balls.size()
	if key == "balls" and ex != null and ex.has_method("balls_in_view"):
		lit = int(ex.call("balls_in_view"))
	return {"balls": balls, "bones": _shape.get("bones", []), "lit": lit}


## Every specimen measured so far, the same columns for each, the one on the plinth marked.
func _table(code: String, bench: Dictionary) -> Dictionary:
	var codes: Array = _records.keys()
	codes.sort()
	if not codes.has(code):
		codes.append(code)
		codes.sort()
	var rows: Array = []
	var current: int = -1
	for cd in codes:
		var rec: Dictionary = _records.get(cd, {})
		if cd == code:
			rec = rec.duplicate()
			for k in bench:
				rec[k] = bench[k]
			rec["name"] = String(_data.get("name", rec.get("name", cd)))
			rec["balls"] = int(_data.get("stats", {}).get("balls", rec.get("balls", 0)))
			rec["tetra"] = int(_data.get("stats", {}).get("tetra", rec.get("tetra", 0)))
			current = rows.size()
		var an: float = float(rec.get("anim_ms", -1.0))
		var rl: float = float(rec.get("limb_ms", -1.0)) * float(rec.get("limbs", 0))
		var ms := func(v: float) -> String: return Presentation.ms(v) if v > 0.0 else "not yet"
		rows.append(["%s %s" % [String(rec.get("name", cd)), String(cd)], str(int(rec.get("balls", 0))), Presentation.thousands(int(rec.get("tetra", 0))),
			ms.call(float(rec.get("build_ms", -1.0))), ms.call(float(rec.get("limb_ms", -1.0))), ms.call(an), ms.call(rl),
			("%s× cheaper" % Presentation.thousands(int(round(rl / an)))) if an > 0.0 and rl > 0.0 else "not yet"])
	return {"heading": "BENCHMARK  every specimen, measured the same way in this room", "heads": HEADS, "rows": rows, "current": current}
