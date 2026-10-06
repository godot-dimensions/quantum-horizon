extends Node

## The two walls' live data (the kit's contract: a node with fill(text) and research(info); carried/kit/
## panels/kit_wall_panels_4d.gd hands it to both panels).
##
## THE METRICS WALL (the research panel's "specimen" layout, re-read for a range):
##   specimen     the experiment chosen or in play: its number, name, how much it asks of W, its glyph
##   the story    the experiments in order, each with its best time once it has one; the one in play
##                lit, those done ticked
##   the page     the experiment's claim and what it shows, a bar per stage (seconds, the last run or the
##                one in play), and three live figures: the clock, accuracy and W travelled
##   the table    every experiment's last run, measured the same way: time, shots, accuracy, wasted shots,
##                W travelled, slice turned and what one 4D raycast cost on this machine
##   footnote     the machine, the OS, the date
##
## NO class_name (engine_gotchas.md).

var director: Node

var _gpu: String = ""


func _ready() -> void:
	_gpu = RenderingServer.get_video_adapter_name()


func fill(text: String) -> String:
	return text


func _clock(s: float) -> String:
	return "%d:%04.1f" % [int(s) / 60, fmod(s, 60.0)]


func research(info: Resource) -> Dictionary:
	var d: Dictionary = {"header_left": String(info.call("research_header")), "header_right": String(info.get("research_status"))}
	if director == null or (director.get("experiments") as Array).is_empty():
		return d
	var exps: Array = director.get("experiments")
	var sel: int = int(director.get("sel"))
	var e: RefCounted = exps[sel]
	var id: String = String(e.get("id"))
	var state: String = String(director.get("state"))
	var running: bool = state in ["intro", "stage", "cleared", "failed"]
	var results: Dictionary = director.get("results")
	var bests: Dictionary = director.get("bests")
	d["specimen"] = {"label": "EXPERIMENT  %02d" % int(e.get("number")), "name": String(e.get("short")),
		"meta": "%s  ·  W: %s" % [String(e.get("title")).to_upper(), String(e.get("w_load"))], "glyph": String(e.get("glyph"))}
	var rows: Array = []
	for x in exps:
		var xid: String = String(x.get("id"))
		rows.append([String(x.get("short")), ("best  " + _clock(float(bests[xid]))) if bests.has(xid) else ""])
	d["story"] = {"label": "THE SEQUENCE", "hint": ("STAGE %s  ·  IN PLAY" % char(65 + int(director.get("stage")))) if running else "CHOOSE AT THE CONSOLE",
		"now": sel, "playing": running, "progress": 1.0, "rows": rows}
	# The page: the bars are the stages' times, this run's while it plays, else the last run's.
	var times: Array = []
	var lit: int = -1
	if running:
		times = (director.get("stage_times") as Array).duplicate()
		times.append(float(director.get("t_stage")))
		lit = times.size() - 1
	elif results.has(id):
		times = (results[id]["stage_times"] as Array).duplicate()
	var st: Dictionary = director.get("weapon").get("stats") if director.get("weapon") != null else {}
	var shots: int = int(st.get("shots", 0))
	var useful: int = int(st.get("pops", 0)) + int(st.get("breaks", 0)) + int(st.get("chips", 0))
	var acc: float = 100.0 * float(useful) / float(shots) if shots > 0 else -1.0
	var player: Node = director.get("player")
	var t_now: float = float(director.get("t_run")) if running else (float(results[id]["time"]) if results.has(id) else -1.0)
	var w_now: float = float(player.get("w_travelled")) if running else (float(results[id]["w"]) if results.has(id) else -1.0)
	if not running and results.has(id):
		acc = float(results[id]["accuracy"])
	d["page"] = {"id": "%s:%s" % [id, "run" if running else "rest"],
		"chapter": "%02d / %02d  ·  %s" % [int(e.get("number")), exps.size(), String(e.get("title")).to_upper()],
		"headline": String(e.get("headline")), "text": String(e.get("explain")), "chart": "bars",
		"caption": "Seconds per stage, A to D%s." % (", this run" if running else (", the last run" if results.has(id) else ": not run yet")),
		"metrics": [
			{"value": _clock(t_now) if t_now >= 0.0 else "", "kind": "text", "text": "on the clock" if running else "the last run", "accent": running},
			{"value": acc, "kind": "pct_live", "text": "of shots did something", "accent": false},
			{"value": ("%.1f m" % w_now) if w_now >= 0.0 else "", "kind": "text", "text": "travelled through W", "accent": false}]}
	var bars: Array = []
	for v in times:
		bars.append(snappedf(float(v), 0.1))
	d["chart"] = {"values": bars, "lit": lit}
	var trow: Array = []
	var current: int = -1
	# The kit's table holds four rows (kit_panel_spec.gd TABLE_ROWS): four experiments in a row, the
	# chosen one always among them.
	var first: int = clampi(sel - 3, 0, maxi(0, exps.size() - 4))
	for i in range(first, mini(first + 4, exps.size())):
		var x: RefCounted = exps[i]
		var xid: String = String(x.get("id"))
		if i == sel:
			current = i - first
		if results.has(xid):
			var r: Dictionary = results[xid]
			trow.append(["%02d  %s" % [int(x.get("number")), String(x.get("short"))], _clock(float(r["time"])), str(int(r["shots"])),
				"%d%%" % int(round(float(r["accuracy"]))), str(int(r["wasted"])), "%.1f m" % float(r["w"]), "%d°" % int(round(float(r["slice"]))),
				"%d µs" % int(round(float(r["ray_us"])))])
		else:
			trow.append(["%02d  %s" % [int(x.get("number")), String(x.get("short"))], "·", "·", "·", "·", "·", "·", "·"])
	d["table"] = {"heading": "RESULTS  every experiment, the last run, measured the same way",
		"heads": ["EXPERIMENT", "TIME", "SHOTS", "ACCURACY", "WASTED", "W TRAVEL", "SLICE TURN", "ONE RAY"], "rows": trow, "current": current}
	d["footnote"] = "Measured on this machine: %s, %s. Bests kept per viewer. %s." % [_gpu, OS.get_name(), Time.get_date_string_from_system()]
	return d
