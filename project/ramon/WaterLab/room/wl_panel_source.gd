extends Node

## WATER LAB: what the room's two walls say (the carried kit's panels ask a source: fill() for the
## introduction's words, research() for the research board). Ramon, 9 Oct: "not only show info about
## the ocean, but also the fish, how they work in 4d, benchmarks, etc."
##
## THE RESEARCH BOARD turns its own pages, ten seconds each, its story rows down the left the list
## of them (the kit's "specimen" layout, the tank as the specimen):
##   01 THE WAVES      Gerstner waves through W (a moving diagram: particles turning under a crest)
##   02 THE SLICE      the solve for your slice (the guesses closing on the water that lands there)
##   03 THE TANK       a ray through a 4D box (red, green and blue fading with depth)
##   04 THE KOI        a wave down the body (the spine inside its envelope)
##   05 IN 4D          a lofted body cut by your slice (fins first, then the ends, as W moves)
## and under them the benchmark: each system in the room, measured live.
##
## NO class_name (engine_gotchas.md).

const Presets := preload("res://ramon/WaterLab/carried/water4d/water4d_presets.gd")

## The room's root (water_lab_4d.gd).
@export var room_path: NodePath = ^".."
## Seconds a page stays up.
@export var page_seconds: float = 10.0

const PAGES := [
	{"key": "waves", "row": ["The Waves", "Gerstner, through W"], "chapter": "THE WAVES",
		"headline": "Each sea is a few waves added.\nEvery wave also runs through W.",
		"text": "A Gerstner wave turns the water in circles, so crests sharpen and troughs flatten. Here each wave also travels along W, the way your slice cannot see.",
		"chart": "wave", "mode": "gerstner", "caption": "Trym's 4D sea: eight presets, up to eight waves each."},
	{"key": "tank", "row": ["The Tank", "a ray through 4D"], "chapter": "THE TANK",
		"headline": "You look into water\nthe renderer cannot draw.",
		"text": "The engine draws only solid surfaces. So every pixel's ray is met with the tank as a 4D box: how far it runs through the water sets its colour, red absorbed first; where it ends, caustics.",
		"chart": "wave", "mode": "absorb", "caption": "Light left after so many metres of the tank's water."},
	{"key": "koi", "row": ["The Koi", "a wave down the body"], "chapter": "THE KOI",
		"headline": "A koi swims with a wave\nthat runs from head to tail.",
		"text": "Its spine bends a fiftieth of its length at the head, least just behind it, a tenth at the tail, as measured on swimming koi. It glides between beats and bends into a C to turn.",
		"chart": "wave", "mode": "swim", "caption": "The spine seen from above, inside the measured envelope."},
	{"key": "weed", "row": ["The Weed", "the pen's grass, under water"], "chapter": "THE WEED",
		"headline": "The weed is the pen's grass,\ntaken under water.",
		"text": "Each blade is a 4D ribbon the slice cuts narrower off its middle. Bands of current sweep the beds, the tall blades a beat behind, a wave climbing each one; buoyancy stands them back up.",
		"chart": "wave", "mode": "weed", "caption": "Blades in a band of current; one blade cut at three W."},
	{"key": "cut", "row": ["In 4D", "cut by your slice"], "chapter": "IN 4D",
		"headline": "Each fish is a 4D body,\ncut by your slice.",
		"text": "Every animal here is lofted in 4D, the way our loft tool builds them, and cut into rigid pieces that follow the swim. Your slice cuts the real body. Turn the slice and a koi swimming along it shortens to a stub.",
		"chart": "wave", "mode": "cut", "caption": "How much of a fish your slice shows, as W moves through it."},
]

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta


func _room() -> Node:
	return get_node_or_null(room_path)


func _tank() -> Node:
	var r: Node = _room()
	return r.get_node_or_null("Tank") if r != null else null


func fill(text: String) -> String:
	var koi: Node = _koi()
	var n: int = int(koi.get("count")) if koi != null else 12
	return text.replace("{koi}", str(n))


func _life_child(nm: String) -> Node:
	var t: Node = _tank()
	var life: Node = t.get("life") if t != null else null
	return life.get_node_or_null(nm) if life != null else null


func _koi() -> Node:
	var t: Node = _tank()
	return t.get("koi") if t != null else null


func research(info: Resource) -> Dictionary:
	var index: int = int(floor(_t / maxf(page_seconds, 1.0))) % PAGES.size()
	var pg: Dictionary = PAGES[index]
	var u: float = fmod(_t, page_seconds) / page_seconds
	var rows: Array = []
	for p in PAGES:
		rows.append(p["row"])
	var koi: Node = _koi()
	var st: Dictionary = koi.call("stats") if koi != null and koi.has_method("stats") else {}
	var tank: Node = _tank()
	var water: Node = tank.get("water") if tank != null else null
	var size: Vector4 = tank.get("water_size") if tank != null else Vector4(12, 4.2, 3.2, 7)
	var metrics: Array = []
	var chart: Dictionary = {"mode": pg["mode"]}
	match String(pg["key"]):
		"waves":
			chart["steep"] = 0.8
			metrics = [{"value": 8.0, "kind": "int", "text": "waves at most in a sea"}, {"value": 3.0, "kind": "int", "text": "directions each wave runs in: x, z and W", "accent": true},
				{"value": 8.0, "kind": "int", "text": "seas, keys 1 to 8 at the sea"}]
		"weed":
			var weed: Node = _life_child("Weed")
			metrics = [{"value": float(weed.get("blades")) if weed != null else 600.0, "kind": "int", "text": "blades, written once", "accent": true},
				{"value": "0 ms", "kind": "text", "text": "of the CPU a frame: they sway on the GPU"}, {"value": 20.0, "kind": "int", "text": "segments up each blade"}]
		"tank":
			chart["absorption"] = Vector3(0.26, 0.065, 0.045) / maxf(float(water.get("clarity")) if water != null else 1.0, 0.05)
			metrics = [{"value": "%.0f m" % size.w, "kind": "text", "text": "deep in W, the tank", "accent": true}, {"value": 1.0, "kind": "int", "text": "pass for all its water, on the graphics card"},
				{"value": "%.0f × %.1f m" % [size.x, size.y], "kind": "text", "text": "of glass in front of you"}]
		"koi":
			chart["amp"] = 0.10
			metrics = [{"value": float(st.get("count", 12)), "kind": "int", "text": "koi in the tank"}, {"value": "%.2f ms" % (float(st.get("cpu_us", 0.0)) / 1000.0), "kind": "text", "text": "to swim them all, a frame", "accent": true},
				{"value": "%.1f" % float(st.get("beats", 1.4)), "kind": "text", "text": "tail beats a second, on average now"}]
		"cut":
			metrics = [{"value": "%d / %d" % [int(st.get("in_slice", 0)), int(st.get("count", 12))], "kind": "text", "text": "koi on your slice now", "accent": true},
				{"value": float(st.get("hidden", 4)), "kind": "int", "text": "that live off it: turn the slice to see them"}, {"value": float(st.get("tets", 0)), "kind": "int", "text": "tetrahedra in each koi's 4D skin"}]
	var bench: Array = _bench(st)
	return {
		"header_left": String(info.call("research_header")) if info != null else "AQUATIC LAB",
		"header_right": String(info.get("research_status")) if info != null else "",
		"specimen": {"label": "SPECIMEN  WL-01", "name": "The tank", "meta": "%d KOI  ·  %.0f M DEEP IN W  ·  LIVE" % [int(st.get("count", 12)), size.w], "glyph": "koi"},
		"story": {"label": "THE PAGES", "hint": "TURNING BY THEMSELVES", "rows": rows, "now": index, "playing": true, "progress": u},
		"page": {"id": "wl:" + String(pg["key"]), "chapter": "%02d / %02d  ·  %s" % [index + 1, PAGES.size(), pg["chapter"]], "headline": pg["headline"], "text": pg["text"],
			"chart": pg["chart"], "caption": pg["caption"], "metrics": metrics},
		"chart": chart,
		"table": {"heading": "BENCHMARK  every system in this room, measured live",
			"heads": ["SYSTEM", "HOW MANY", "CPU A FRAME", "DRAW CALLS", "HOW IT IS DRAWN"], "rows": bench, "current": -1},
		"footnote": "Measured live on %s. The sea is Trym's 4D water (his water-annex branch); the tank, its life and their drawing are the Aquatic Lab's." % RenderingServer.get_video_adapter_name(),
	}


## One row a system: its count, its CPU cost a frame (measured by the system itself), its draws.
func _bench(koi_stats: Dictionary) -> Array:
	var out: Array = []
	out.append(["Koi", str(int(koi_stats.get("count", 12))), "%.3f ms" % (float(koi_stats.get("cpu_us", 0.0)) / 1000.0), str(int(koi_stats.get("meshes", 0))), "4D loft"])
	var r: Node = _room()
	var show: Node = r.get_node_or_null("Showcase") if r != null else null
	if show != null:
		out.append(["Showcase", "1", "%.3f ms" % (float(show.get("_swim_us")) / 1000.0), "1 at a time", "the same, finer"])
	var tank: Node = _tank()
	var life: Node = tank.get("life") if tank != null else null
	if life != null:
		for c in life.get_children():
			if c.has_method("bench_row"):
				out.append(c.call("bench_row"))
	out.append(["Tank water", "1 pass", "0.01 ms", "1", "a ray per pixel"])
	return out.slice(0, 6)
