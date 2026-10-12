extends Node

## The lobby walls' live data (the kit's contract: a node with fill(text) and research(info);
## carried/kit/panels/kit_wall_panels_4d.gd hands it to both panels, ten times a second). The walls are
## the Creation Lab's: dynamic, drawn from this live, never baked (Ramon, 9 Oct: "ideally i want teacher
## walls to be dynamic like the walls in creatorlab").
##
## THE RESEARCH WALL (the kit's "specimen" layout, read for a maze):
##   specimen     the level chosen or in play: its number, name, its size in cells and its par through W
##   the story    the six levels, each with its best once it has one; the one chosen lit
##   the page     the level's one idea and what it asks, bars of the best times, and three live figures:
##                the clock, W moves against par, and how often you turned into W
##   the table    every level's last run, measured the same way: time, W moves, par, turns, hints
##   footnote     the machine, the date
##
## NO class_name (engine_gotchas.md).

## The maze root (phase_maze_remake_4d.gd).
var maze: Node

var _gpu: String = ""


func _ready() -> void:
	_gpu = RenderingServer.get_video_adapter_name()


func fill(text: String) -> String:
	return text


static func _clock(s: float) -> String:
	return "%d:%04.1f" % [int(s) / 60, fmod(s, 60.0)]


func research(info: Resource) -> Dictionary:
	var d: Dictionary = {"header_left": String(info.call("research_header")), "header_right": String(info.get("research_status"))}
	if maze == null:
		return d
	var levels: Array = maze.call("levels")
	var state: String = String(maze.get("state"))
	var playing: bool = state == "playing"
	var i: int = int(maze.get("level_index")) if state != "lobby" else int(maze.get("sel"))
	var bests: Dictionary = maze.get("bests")
	var results: Dictionary = maze.get("results")
	var facts: Dictionary = maze.call("level_facts", i)
	d["specimen"] = {"label": "LEVEL  %02d" % (i + 1), "name": String(facts.get("short", "")),
		"meta": String(facts.get("meta", "")), "glyph": String(levels[i]["glyph"])}
	var rows: Array = []
	for k in levels.size():
		rows.append([String(maze.call("_level_name", k)), ("best  " + _clock(float(bests[k]))) if bests.has(k) else ""])
	d["story"] = {"label": "THE LEVELS", "hint": "IN PLAY" if playing else "CHOOSE AT THE CONSOLE",
		"now": i, "playing": playing, "progress": 1.0, "rows": rows}
	var t_now: float = float(maze.get("time")) if playing else (float(results[i]["time"]) if results.has(i) else -1.0)
	var wm: int = int(maze.get("w_moves")) if playing else (int(results[i]["w_moves"]) if results.has(i) else -1)
	var turns: int = int(maze.get("turns")) if playing else (int(results[i]["turns"]) if results.has(i) else -1)
	d["page"] = {"id": "%d:%s" % [i, "run" if playing else "rest"],
		"chapter": "%02d / %02d  ·  %s" % [i + 1, levels.size(), String(facts.get("name", "")).to_upper()],
		"headline": String(facts.get("lesson", "")), "text": String(levels[i].get("intro", "")), "chart": "bars",
		"caption": "Best time per level, in seconds; the chosen one lit.",
		"metrics": [
			{"value": _clock(t_now) if t_now >= 0.0 else "", "kind": "text", "text": "on the clock" if playing else "the last run", "accent": playing},
			{"value": ("%d / %d" % [wm, int(facts.get("par", 0))]) if wm >= 0 else "", "kind": "text", "text": "W moves against par", "accent": false},
			{"value": str(turns) if turns >= 0 else "", "kind": "text", "text": "turns into W", "accent": false}]}
	var bars: Array = []
	for k in levels.size():
		bars.append(snappedf(float(bests.get(k, 0.0)), 0.1))
	d["chart"] = {"values": bars, "lit": i}
	var trow: Array = []
	var current: int = -1
	var first: int = clampi(i - 3, 0, maxi(0, levels.size() - 4))
	for k in range(first, mini(first + 4, levels.size())):
		if k == i:
			current = k - first
		var f: Dictionary = maze.call("level_facts", k)
		var name: String = "%02d  %s" % [k + 1, String(f.get("name", ""))]
		if results.has(k):
			var r: Dictionary = results[k]
			trow.append([name, String(f.get("cells", "")), _clock(float(r["time"])), str(int(r["w_moves"])), str(int(f.get("par", 0))),
				str(int(r["turns"])), str(int(r["hints"])), ("best " + _clock(float(bests[k]))) if bests.has(k) else "·"])
		else:
			trow.append([name, String(f.get("cells", "")), "·", "·", str(int(f.get("par", 0))), "·", "·", ("best " + _clock(float(bests[k]))) if bests.has(k) else "·"])
	d["table"] = {"heading": "RESULTS  every level, the last run, measured the same way",
		"heads": ["LEVEL", "CELLS", "TIME", "W MOVES", "PAR", "TURNS", "HINTS", "BEST"], "rows": trow, "current": current}
	d["footnote"] = "Measured on this machine: %s, %s. Bests kept per viewer. %s." % [_gpu, OS.get_name(), Time.get_date_string_from_system()]
	return d
