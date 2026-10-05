extends RefCounted

## Kit: the exhibit's presentation, one story for every animal on the plinth (Ramon, 4 Oct:
## "sequence logic and callouts should be the same for each featured animal"). The showcase plays
## these parts in order and round again; each exhibit only says how it looks in each part
## (play_part(key, t, length)); the room's presenter (kit_presenter.gd) puts up a title card as a
## part begins and the callouts at their times; the research wall turns its pages by the same keys.
##
## THE ORDER is the order of the work: build it (the balls, then the skin lofted between them),
## understand it (it is 4D, you see a slice), animate it (the balls are the joints, and on them it
## walks). The walk comes last: the whole animal moving is the payoff, and the rig before it is the
## reason it can move without being rebuilt.
##
## CALLOUTS carry the animal's own numbers: {name} {balls} {tetra} {build_ms} {reach} {pieces}
## {anim_ms} {reloft_ms} {speedup}. A callout whose number is not known yet is left out rather than
## shown with a gap.
##
## Each part also keeps its camera for the watched cinematic (eye and look in the exhibit's frame).
##
## NO class_name (engine_gotchas.md).

const CHAPTERS := [
	{"key": "balls", "title": "THE BALLS", "length": 7.0,
		"line": "A designer places balls. Each one is a cross-section of the body.",
		"callouts": [[2.0, "Every ball is a handful of numbers: a size, two stretches, a squareness, and how far it reaches into W."],
			[4.6, "{balls} balls in all. That is the whole model."]],
		"eye": Vector4(-3.6, 3.0, 6.4, 0.0), "look": Vector4(0.2, 1.3, 0.0, 0.0), "fov": 0.85},
	{"key": "skin", "title": "THE SKIN", "length": 6.5,
		"line": "The tool lofts a skin between the balls. Nothing is modelled by hand.",
		"callouts": [[1.6, "The skin is made of tetrahedra, the four-dimensional cousin of triangles."],
			[3.9, "{tetra} of them, lofted from the balls in {build_ms} on this machine."]],
		"eye": Vector4(-5.4, 2.6, 4.2, 0.0), "look": Vector4(0.0, 1.5, 0.0, 0.0), "fov": 0.85},
	{"key": "slice", "title": "THE SLICE", "length": 8.0,
		"line": "The animal is four-dimensional. We only ever see a 3D slice of it.",
		"callouts": [[1.6, "As the slice slides through W, the same body shows a different shape."],
			[4.2, "This one reaches {reach} into W, either side of its middle."],
			[6.2, "Your turn after the show: the wheel slides the slice, a right drag turns it."]],
		"eye": Vector4(-1.0, 3.0, 8.4, 0.0), "look": Vector4(0.6, 1.3, -1.0, 0.0), "fov": 0.95},
	{"key": "rig", "title": "THE RIG", "length": 6.5,
		"line": "Under the skin, the balls are the joints.",
		"callouts": [[1.6, "No bones were placed by hand. The build gives the rig for free."],
			[3.9, "The legs bend at the same balls that shaped them."]],
		"eye": Vector4(-4.5, 2.4, 5.5, 0.0), "look": Vector4(0.0, 1.4, 0.0, 0.0), "fov": 0.9},
	{"key": "walk", "title": "THE WALK", "length": 10.0,
		"line": "Cut once into rigid pieces, it walks without lofting again.",
		"callouts": [[1.6, "{pieces} rigid pieces hang on the joints. Each frame moves them, never their vertices."],
			[4.4, "The whole walk costs {anim_ms} a frame."],
			[7.0, "Re-lofting its legs every frame would cost {reloft_ms}. Rigid pieces are {speedup} cheaper."]],
		"eye": Vector4(-4.5, 2.4, 5.5, 0.0), "look": Vector4(0.0, 1.4, 0.0, 0.0), "fov": 0.9},
]


static func chapters() -> Array:
	return CHAPTERS


static func index_of(key: String) -> int:
	for i in CHAPTERS.size():
		if String(CHAPTERS[i]["key"]) == key:
			return i
	return -1


static func length_of(key: String) -> float:
	var i: int = index_of(key)
	return float(CHAPTERS[i]["length"]) if i >= 0 else 0.0


## The numbers a callout can name, from the exhibit's data and its measured bench, formatted;
## missing ones are left out.
static func numbers(data: Dictionary, bench: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var st: Dictionary = data.get("stats", {})
	if not data.is_empty():
		out["name"] = String(data.get("name", "")).to_lower()
		out["balls"] = str(int(st.get("balls", 0)))
		out["tetra"] = thousands(int(st.get("tetra", 0)))
		out["reach"] = "%.2f m" % float(st.get("reach", 0.0))
	if float(bench.get("build_ms", -1.0)) > 0.0:
		out["build_ms"] = ms(float(bench["build_ms"]))
	if int(bench.get("pieces", 0)) > 0:
		out["pieces"] = str(int(bench["pieces"]))
	var anim: float = float(bench.get("anim_ms", -1.0))
	if anim > 0.0:
		out["anim_ms"] = ms(anim)
	var reloft: float = float(bench.get("limb_ms", -1.0)) * float(bench.get("limbs", 0))
	if reloft > 0.0:
		out["reloft_ms"] = ms(reloft)
		if anim > 0.0:
			out["speedup"] = "%s times" % thousands(int(round(reloft / anim)))
	return out


## `text` with its {names} filled in, or "" if any is not known.
static func fill(text: String, nums: Dictionary) -> String:
	var out: String = text
	var at: int = out.find("{")
	while at >= 0:
		var close: int = out.find("}", at)
		if close < 0:
			break
		var key: String = out.substr(at + 1, close - at - 1)
		if not nums.has(key):
			return ""
		out = out.substr(0, at) + String(nums[key]) + out.substr(close + 1)
		at = out.find("{")
	return out


static func ms(v: float) -> String:
	if v < 0.1:
		return "%.3f ms" % v
	if v < 10.0:
		return "%.2f ms" % v
	return "%.0f ms" % v


static func thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
