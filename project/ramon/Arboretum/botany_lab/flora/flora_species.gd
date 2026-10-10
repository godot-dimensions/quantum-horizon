extends RefCounted

## BOTANY LAB, round 3 (follow_up/arboretum.md section 9, step 1): the twelve flowering plants of the
## flower room, as data for flower_4d.gd. Real counts and real forms, sized as the plant is (metres);
## the room scales them.
##
## WHAT IS 4D ABOUT A 4D FLOWER. A flower's petals radiate round its stem. In 3D "round" is a circle;
## in 4D it is a whole sphere of directions (x, z and W), so a 4D flower carries petals the slice cannot
## show you until it turns. Each form below says how its parts fill that sphere:
##   ring + W pair   the familiar ring in the slice, and one petal more each way through W (ana and
##                   kata): unseen at first, they come into view as the flower turns while the ring's
##                   own petals turn away. A four-petalled poppy becomes six, the octahedron's corners.
##   band            many rays spread over a band of directions either side of the slice (Fibonacci, the
##                   golden angle): those near the slice show whole, the rest as shorter stubs, and a turn
##                   reshuffles which is which.
##   ball            florets or seeds pointing every way in all four directions (the super-Fibonacci
##                   spiral on the 3-sphere): a ball in every cut, like the real one in ours.
##   bells           tubes round in every direction across them: a 4D bell, as round in W as in x.
##
## Colours by part (flower_4d.gd's KIND rows): "stem" [base, top]; "leaf" [base, tip, midrib];
## "petal"/"petal2" [base, middle, tip, edge] with an optional "blotch" [colour, to u, to v] and
## "spots" [colour, from u, to u, density]; "centre" [middle, rim]; "stamen" [filament, anther];
## "extra" [a, b] (beard, stigma, pappus); "corona" [base, band, tip] (the passionflower's filaments).
##
## ROUND 5 (follow_up/arboretum.md section 11; Ramon: "Several flower species currently look too similar ...
## The flowers should feel like distinct botanical specimens rather than small variations of the same
## procedural object"): the rose rebuilt as whorls (flower_4d.gd _rose), the poppy an open scarlet bowl round
## its capsule with a nodding bud, the tulip yellow and flamed (three reds stood together); every species its
## own stem `bend` and `wiggle` (radians); and four more, so the sixteen pots by 01 each hold a different
## plant: lavender, cornflower, marigold and snowdrop.
##
## NO class_name (engine_gotchas.md).

## The order is the texture's row order: never reorder, only append (bakes and textures index it).
const KEYS := ["tulip", "poppy", "daisy", "sunflower", "iris", "lily", "allium", "dandelion", "foxglove", "bluebell", "rose", "passionflower", "clematis",
	"lavender", "cornflower", "marigold", "snowdrop"]
## The ones grown in the pockets (clematis climbs the walls, its blooms only: flower_4d.gd bloom_mesh()).
const POCKET_KEYS := ["tulip", "poppy", "daisy", "sunflower", "iris", "lily", "allium", "dandelion", "foxglove", "bluebell", "rose", "passionflower"]
## How much bigger than life each is shown, so a bloom reads across the room.
const DISPLAY := {"tulip": 1.7, "poppy": 1.8, "daisy": 1.9, "sunflower": 1.15, "iris": 1.35, "lily": 1.3, "allium": 1.25, "dandelion": 2.0,
	"foxglove": 1.15, "bluebell": 2.1, "rose": 1.7, "passionflower": 1.8, "clematis": 1.8, "lavender": 1.9, "cornflower": 2.4, "marigold": 2.6, "snowdrop": 3.2}


static func all() -> Array:
	var out: Array = []
	for k in KEYS:
		out.append(by_key(k))
	return out


static func row_of(key: String) -> int:
	return KEYS.find(key)


static func by_key(key: String) -> Dictionary:
	var d: Dictionary = _data(key)
	d["key"] = key
	d["row"] = row_of(key)
	return d


static func _data(key: String) -> Dictionary:
	match key:
		"tulip":
			return {
				"name": "Tulip", "latin": "Tulipa gesneriana",
				"line": "Six tepals in a cup, and one more each way through W.",
				"form": "ring", "height": 0.42, "stem_r": 0.0032, "plants": 5, "bend": 0.22, "wiggle": 0.1,
				"petal": {"n": 3, "phase": 0.0, "L": 0.066, "hw": 0.023, "peak": 0.58, "round": 0.95, "elev": 1.0, "curl": 0.42, "r0": 0.004, "thick": 0.0016},
				"petal2": {"n": 3, "phase": PI / 3.0, "L": 0.062, "hw": 0.021, "peak": 0.58, "round": 0.95, "elev": 1.08, "curl": 0.38, "r0": 0.003, "thick": 0.0016},
				"w_pair": true,
				"stamens": {"n": 6, "L": 0.02, "elev": 1.2, "anther": 0.003},
				"pistil": {"L": 0.016, "r": 0.0028},
				"leaves": [{"at": 0.03, "L": 0.2, "hw": 0.032, "peak": 0.35, "elev": 1.2, "curl": -1.3, "dir": 0.3},
					{"at": 0.06, "L": 0.17, "hw": 0.028, "peak": 0.35, "elev": 1.25, "curl": -1.1, "dir": 3.5},
					{"at": 0.05, "L": 0.15, "hw": 0.026, "peak": 0.35, "elev": 1.2, "curl": -1.2, "dir": 1.9, "w": 0.7}],
				"c": {"stem": [Color(0.26, 0.38, 0.22), Color(0.4, 0.52, 0.3)], "leaf": [Color(0.26, 0.4, 0.28), Color(0.42, 0.56, 0.4), Color(0.5, 0.62, 0.46)],
					"petal": [Color(0.96, 0.84, 0.22), Color(0.99, 0.82, 0.14), Color(0.97, 0.52, 0.1), Color(0.92, 0.3, 0.08)],
					"petal2": [Color(0.96, 0.84, 0.22), Color(0.98, 0.8, 0.13), Color(0.96, 0.48, 0.09), Color(0.9, 0.28, 0.07)],
					"centre": [Color(0.55, 0.62, 0.3), Color(0.5, 0.58, 0.28)], "stamen": [Color(0.12, 0.08, 0.1), Color(0.08, 0.05, 0.08)],
					"extra": [Color(0.75, 0.75, 0.4), Color(0.6, 0.6, 0.3)]},
			}
		"poppy":
			return {
				"name": "Corn poppy", "latin": "Papaver rhoeas",
				"line": "Four petals in the slice and two through W: six, at an octahedron's corners.",
				"form": "ring", "height": 0.56, "stem_r": 0.0016, "plants": 4, "bend": 0.34, "wiggle": 0.3,
				"petal": {"n": 4, "phase": 0.4, "L": 0.056, "hw": 0.047, "peak": 0.68, "round": 1.0, "elev": 0.72, "curl": 0.4, "r0": 0.005, "thick": 0.0012, "crumple": 0.24},
				"w_pair": true,
				"capsule": {"r": 0.0105, "h": 0.017, "star": 9},
				"stamens": {"n": 40, "band": 0.65, "L": 0.011, "elev": 0.8, "anther": 0.0016},
				"bud": {"at": 0.62, "L": 0.1, "r": 0.0075, "dir": 2.4},
				"leaves": [{"at": 0.02, "L": 0.12, "hw": 0.018, "peak": 0.5, "elev": 0.9, "curl": -0.9, "dir": 0.8, "teeth": 5, "depth": 0.6},
					{"at": 0.03, "L": 0.11, "hw": 0.016, "peak": 0.5, "elev": 0.9, "curl": -0.8, "dir": 2.9, "teeth": 5, "depth": 0.6},
					{"at": 0.18, "L": 0.07, "hw": 0.011, "peak": 0.5, "elev": 0.6, "curl": -0.4, "dir": 4.8, "teeth": 4, "depth": 0.6, "w": 0.6}],
				"c": {"stem": [Color(0.3, 0.42, 0.18), Color(0.4, 0.52, 0.22)], "leaf": [Color(0.26, 0.4, 0.16), Color(0.36, 0.5, 0.2), Color(0.42, 0.56, 0.26)],
					"petal": [Color(0.05, 0.03, 0.03), Color(0.97, 0.2, 0.04), Color(0.99, 0.27, 0.06), Color(0.99, 0.34, 0.12)],
					"blotch": [Color(0.04, 0.03, 0.03), 0.18, 0.6],
					"centre": [Color(0.55, 0.62, 0.42), Color(0.45, 0.55, 0.38)], "stamen": [Color(0.1, 0.07, 0.1), Color(0.18, 0.12, 0.2)],
					"extra": [Color(0.2, 0.12, 0.2), Color(0.32, 0.2, 0.3)]},
			}
		"daisy":
			return {
				"name": "Ox-eye daisy", "latin": "Leucanthemum vulgare",
				"line": "Its rays spread through W as well: the slice shows a few whole, the rest as stubs.",
				"form": "band", "height": 0.46, "stem_r": 0.0017, "plants": 5, "bend": 0.32, "wiggle": 0.2,
				"rays": {"n": 46, "band": 0.62, "L": 0.026, "hw": 0.0042, "peak": 0.6, "round": 0.85, "elev": 0.08, "curl": -0.12, "r0": 0.008, "thick": 0.0009, "wr": 2.2, "kind": "petal"},
				"disc": {"r": 0.0085, "h": 0.004},
				"leaves": [{"at": 0.02, "L": 0.07, "hw": 0.009, "peak": 0.7, "elev": 0.7, "curl": -0.6, "dir": 0.5, "teeth": 4, "depth": 0.35},
					{"at": 0.02, "L": 0.065, "hw": 0.009, "peak": 0.7, "elev": 0.7, "curl": -0.6, "dir": 2.6, "teeth": 4, "depth": 0.35},
					{"at": 0.15, "L": 0.045, "hw": 0.005, "peak": 0.4, "elev": 0.9, "curl": -0.3, "dir": 4.4, "teeth": 3, "depth": 0.4},
					{"at": 0.26, "L": 0.035, "hw": 0.004, "peak": 0.4, "elev": 0.9, "curl": -0.3, "dir": 1.2, "teeth": 3, "depth": 0.4, "w": 0.6}],
				"c": {"stem": [Color(0.24, 0.38, 0.16), Color(0.34, 0.48, 0.2)], "leaf": [Color(0.16, 0.3, 0.12), Color(0.24, 0.4, 0.16), Color(0.3, 0.46, 0.2)],
					"petal": [Color(0.95, 0.93, 0.78), Color(0.98, 0.98, 0.95), Color(0.99, 0.99, 0.97), Color(0.96, 0.96, 0.94)],
					"centre": [Color(0.96, 0.66, 0.05), Color(0.98, 0.78, 0.12)]},
			}
		"sunflower":
			return {
				"name": "Sunflower", "latin": "Helianthus annuus",
				"line": "A golden band of rays round a disc that is a dome in every direction.",
				"form": "band", "height": 0.92, "stem_r": 0.0075, "plants": 2, "face": 0.55, "bend": 0.12, "wiggle": 0.08,
				"rays": {"n": 40, "band": 0.5, "L": 0.068, "hw": 0.013, "peak": 0.5, "round": 0.4, "elev": 0.06, "curl": -0.2, "r0": 0.046, "thick": 0.0016, "wr": 1.8, "kind": "petal"},
				"rays2": {"n": 22, "band": 0.4, "L": 0.016, "hw": 0.006, "peak": 0.5, "round": 0.5, "elev": 0.3, "curl": 0.2, "r0": 0.046, "thick": 0.0015, "kind": "leaf"},
				"disc": {"r": 0.05, "h": 0.012},
				"leaves": [{"at": 0.25, "L": 0.15, "hw": 0.055, "peak": 0.35, "elev": 0.5, "curl": -0.9, "dir": 0.4, "stalk": 0.06},
					{"at": 0.42, "L": 0.14, "hw": 0.05, "peak": 0.35, "elev": 0.5, "curl": -0.9, "dir": 2.8, "stalk": 0.055},
					{"at": 0.58, "L": 0.12, "hw": 0.045, "peak": 0.35, "elev": 0.5, "curl": -0.9, "dir": 5.2, "stalk": 0.05, "w": 0.7},
					{"at": 0.72, "L": 0.1, "hw": 0.038, "peak": 0.35, "elev": 0.5, "curl": -0.8, "dir": 1.4, "stalk": 0.04}],
				"c": {"stem": [Color(0.3, 0.42, 0.16), Color(0.36, 0.5, 0.2)], "leaf": [Color(0.22, 0.38, 0.12), Color(0.3, 0.48, 0.16), Color(0.36, 0.52, 0.22)],
					"petal": [Color(0.95, 0.6, 0.02), Color(1.0, 0.76, 0.05), Color(1.0, 0.82, 0.12), Color(0.98, 0.72, 0.04)],
					"centre": [Color(0.16, 0.12, 0.04), Color(0.36, 0.2, 0.06)]},
			}
		"iris":
			return {
				"name": "Bearded iris", "latin": "Iris germanica",
				"line": "Three falls and three standards, and a pair of each through W.",
				"form": "ring", "height": 0.62, "stem_r": 0.004, "plants": 3, "bend": 0.16, "wiggle": 0.08,
				"petal": {"n": 3, "phase": 0.0, "L": 0.075, "hw": 0.024, "peak": 0.62, "round": 0.9, "elev": 0.35, "curl": -2.1, "r0": 0.006, "thick": 0.0016},
				"petal2": {"n": 3, "phase": PI / 3.0, "L": 0.066, "hw": 0.021, "peak": 0.6, "round": 0.95, "elev": 1.35, "curl": 0.7, "r0": 0.004, "thick": 0.0016},
				"w_pair": true,
				"beard": {"from": 0.08, "to": 0.45, "r": 0.0022},
				"leaves": [{"at": 0.0, "L": 0.42, "hw": 0.016, "peak": 0.35, "elev": 1.42, "curl": -0.18, "dir": 0.0, "pointed": true},
					{"at": 0.0, "L": 0.38, "hw": 0.015, "peak": 0.35, "elev": 1.35, "curl": -0.25, "dir": PI, "pointed": true},
					{"at": 0.0, "L": 0.33, "hw": 0.014, "peak": 0.35, "elev": 1.25, "curl": -0.3, "dir": 0.15, "pointed": true},
					{"at": 0.0, "L": 0.3, "hw": 0.013, "peak": 0.35, "elev": 1.2, "curl": -0.3, "dir": PI + 0.15, "pointed": true},
					{"at": 0.0, "L": 0.34, "hw": 0.014, "peak": 0.35, "elev": 1.3, "curl": -0.25, "dir": PI * 0.5, "pointed": true, "w": 1.0}],
				"c": {"stem": [Color(0.28, 0.42, 0.34), Color(0.36, 0.5, 0.4)], "leaf": [Color(0.26, 0.42, 0.36), Color(0.38, 0.54, 0.46), Color(0.44, 0.6, 0.5)],
					"petal": [Color(0.9, 0.86, 0.8), Color(0.34, 0.1, 0.56), Color(0.28, 0.06, 0.48), Color(0.38, 0.14, 0.6)],
					"spots": [Color(0.92, 0.9, 0.86), 0.0, 0.42, 7.0],
					"petal2": [Color(0.62, 0.5, 0.86), Color(0.58, 0.44, 0.88), Color(0.64, 0.52, 0.92), Color(0.7, 0.6, 0.95)],
					"extra": [Color(1.0, 0.62, 0.08), Color(1.0, 0.8, 0.2)]},
			}
		"lily":
			return {
				"name": "Lily", "latin": "Lilium 'Stargazer'",
				"line": "Six spotted tepals curling back, one more each way through W.",
				"form": "ring", "height": 0.72, "stem_r": 0.0042, "plants": 3, "face": 1.05, "bend": 0.0, "wiggle": 0.04,
				"petal": {"n": 3, "phase": 0.0, "L": 0.085, "hw": 0.02, "peak": 0.4, "round": 0.2, "elev": 0.45, "curl": -1.6, "r0": 0.005, "thick": 0.0017},
				"petal2": {"n": 3, "phase": PI / 3.0, "L": 0.08, "hw": 0.017, "peak": 0.4, "round": 0.2, "elev": 0.5, "curl": -1.5, "r0": 0.004, "thick": 0.0017},
				"w_pair": true,
				"stamens": {"n": 6, "L": 0.07, "elev": 0.65, "curl": 0.25, "anther": 0.0055, "flat": true},
				"pistil": {"L": 0.075, "r": 0.0016, "knob": 0.0032},
				"leaves": [{"at": 0.12, "L": 0.08, "hw": 0.009, "peak": 0.4, "elev": 0.7, "curl": -0.5, "dir": 0.3, "pointed": true},
					{"at": 0.2, "L": 0.08, "hw": 0.009, "peak": 0.4, "elev": 0.7, "curl": -0.5, "dir": 2.7, "pointed": true},
					{"at": 0.28, "L": 0.075, "hw": 0.009, "peak": 0.4, "elev": 0.7, "curl": -0.5, "dir": 5.1, "pointed": true},
					{"at": 0.36, "L": 0.07, "hw": 0.008, "peak": 0.4, "elev": 0.7, "curl": -0.5, "dir": 1.2, "pointed": true, "w": 0.8},
					{"at": 0.44, "L": 0.065, "hw": 0.008, "peak": 0.4, "elev": 0.7, "curl": -0.5, "dir": 3.6, "pointed": true},
					{"at": 0.52, "L": 0.06, "hw": 0.007, "peak": 0.4, "elev": 0.7, "curl": -0.5, "dir": 6.0, "pointed": true}],
				"c": {"stem": [Color(0.24, 0.36, 0.16), Color(0.3, 0.44, 0.2)], "leaf": [Color(0.18, 0.34, 0.12), Color(0.26, 0.44, 0.16), Color(0.3, 0.48, 0.2)],
					"petal": [Color(0.72, 0.82, 0.38), Color(0.86, 0.18, 0.42), Color(0.96, 0.62, 0.74), Color(0.99, 0.94, 0.96)],
					"spots": [Color(0.5, 0.04, 0.14), 0.12, 0.62, 9.0],
					"petal2": [Color(0.72, 0.82, 0.38), Color(0.84, 0.16, 0.4), Color(0.95, 0.6, 0.72), Color(0.99, 0.94, 0.96)],
					"stamen": [Color(0.72, 0.8, 0.5), Color(0.52, 0.22, 0.08)], "extra": [Color(0.55, 0.65, 0.35), Color(0.4, 0.5, 0.28)]},
			}
		"allium":
			return {
				"name": "Ornamental onion", "latin": "Allium giganteum",
				"line": "A ball of starry florets pointing every way in four directions: a ball in every cut.",
				"form": "ball", "height": 0.8, "stem_r": 0.0042, "plants": 3, "bend": 0.2, "wiggle": 0.12,
				"ball": {"n": 300, "R": 0.062, "floret": 0.0078, "pedicel": 0.0007, "kind": "petal", "seed": 3},
				"leaves": [{"at": 0.0, "L": 0.24, "hw": 0.014, "peak": 0.3, "elev": 1.0, "curl": -1.4, "dir": 0.4},
					{"at": 0.0, "L": 0.22, "hw": 0.013, "peak": 0.3, "elev": 1.0, "curl": -1.5, "dir": 3.3},
					{"at": 0.0, "L": 0.2, "hw": 0.012, "peak": 0.3, "elev": 1.0, "curl": -1.4, "dir": 1.8, "w": 0.8}],
				"c": {"stem": [Color(0.32, 0.46, 0.34), Color(0.4, 0.54, 0.4)], "leaf": [Color(0.42, 0.5, 0.3), Color(0.62, 0.6, 0.34), Color(0.5, 0.56, 0.34)],
					"petal": [Color(0.4, 0.22, 0.52), Color(0.56, 0.32, 0.76), Color(0.66, 0.42, 0.88), Color(0.7, 0.5, 0.9)]},
			}
		"dandelion":
			return {
				"name": "Dandelion clock", "latin": "Taraxacum officinale",
				"line": "Its seeds point every way in four directions; a gust carries some off.",
				"form": "ball", "height": 0.28, "stem_r": 0.0019, "plants": 4, "bend": 0.36, "wiggle": 0.18,
				"ball": {"n": 320, "R": 0.033, "floret": 0.0042, "pedicel": 0.00045, "kind": "extra", "seed": 7, "pappus": true},
				"leaves": [{"at": 0.0, "L": 0.13, "hw": 0.016, "peak": 0.65, "elev": 0.25, "curl": -0.2, "dir": 0.2, "teeth": 6, "depth": 0.7},
					{"at": 0.0, "L": 0.12, "hw": 0.015, "peak": 0.65, "elev": 0.25, "curl": -0.2, "dir": 1.5, "teeth": 6, "depth": 0.7},
					{"at": 0.0, "L": 0.12, "hw": 0.015, "peak": 0.65, "elev": 0.25, "curl": -0.2, "dir": 2.8, "teeth": 6, "depth": 0.7},
					{"at": 0.0, "L": 0.11, "hw": 0.014, "peak": 0.65, "elev": 0.25, "curl": -0.2, "dir": 4.1, "teeth": 6, "depth": 0.7},
					{"at": 0.0, "L": 0.12, "hw": 0.015, "peak": 0.65, "elev": 0.25, "curl": -0.2, "dir": 5.3, "teeth": 6, "depth": 0.7},
					{"at": 0.0, "L": 0.1, "hw": 0.013, "peak": 0.65, "elev": 0.3, "curl": -0.2, "dir": 0.9, "teeth": 5, "depth": 0.7, "w": 1.1}],
				"c": {"stem": [Color(0.5, 0.52, 0.34), Color(0.58, 0.58, 0.4)], "leaf": [Color(0.2, 0.36, 0.12), Color(0.3, 0.46, 0.18), Color(0.46, 0.4, 0.3)],
					"petal": [Color(0.4, 0.3, 0.18), Color(0.4, 0.3, 0.18), Color(0.4, 0.3, 0.18), Color(0.4, 0.3, 0.18)],
					"centre": [Color(0.45, 0.36, 0.22), Color(0.5, 0.42, 0.28)],
					"extra": [Color(0.62, 0.56, 0.44), Color(0.98, 0.98, 0.96)]},
			}
		"foxglove":
			return {
				"name": "Foxglove", "latin": "Digitalis purpurea",
				"line": "Spotted bells all on one side of the spike, each bell round in W as in x.",
				"form": "spike", "height": 1.0, "stem_r": 0.0045, "plants": 2, "bend": 0.12, "wiggle": 0.07,
				"bells": {"n": 20, "from": 0.38, "to": 0.95, "L": 0.052, "R": 0.016, "droop": 0.8, "side": 0.0, "spread": 1.05, "bud": 4, "w_side": 0.12},
				"leaves": [{"at": 0.02, "L": 0.22, "hw": 0.045, "peak": 0.4, "elev": 0.5, "curl": -0.7, "dir": 0.2},
					{"at": 0.02, "L": 0.2, "hw": 0.042, "peak": 0.4, "elev": 0.5, "curl": -0.7, "dir": 1.5},
					{"at": 0.02, "L": 0.21, "hw": 0.043, "peak": 0.4, "elev": 0.5, "curl": -0.7, "dir": 2.8},
					{"at": 0.02, "L": 0.2, "hw": 0.042, "peak": 0.4, "elev": 0.5, "curl": -0.7, "dir": 4.1},
					{"at": 0.02, "L": 0.19, "hw": 0.04, "peak": 0.4, "elev": 0.5, "curl": -0.7, "dir": 5.3},
					{"at": 0.03, "L": 0.18, "hw": 0.04, "peak": 0.4, "elev": 0.55, "curl": -0.7, "dir": 0.8, "w": 1.0},
					{"at": 0.2, "L": 0.1, "hw": 0.022, "peak": 0.4, "elev": 0.7, "curl": -0.4, "dir": 3.5},
					{"at": 0.3, "L": 0.08, "hw": 0.018, "peak": 0.4, "elev": 0.8, "curl": -0.3, "dir": 0.4}],
				"c": {"stem": [Color(0.3, 0.4, 0.22), Color(0.4, 0.42, 0.3)], "leaf": [Color(0.3, 0.42, 0.24), Color(0.42, 0.52, 0.34), Color(0.52, 0.6, 0.42)],
					"petal": [Color(0.72, 0.36, 0.62), Color(0.8, 0.28, 0.6), Color(0.86, 0.42, 0.7), Color(0.96, 0.9, 0.94)],
					"spots": [Color(0.36, 0.06, 0.26), 0.68, 1.0, 6.0]},
			}
		"bluebell":
			return {
				"name": "Bluebell", "latin": "Hyacinthoides non-scripta",
				"line": "Nodding bells down one side of an arching stem, each round in W.",
				"form": "raceme", "height": 0.32, "stem_r": 0.0018, "plants": 5, "bend": 0.0, "wiggle": 0.06,
				"bells": {"n": 8, "from": 0.55, "to": 0.98, "L": 0.021, "R": 0.0068, "droop": 1.25, "side": 0.0, "spread": 0.35, "bud": 2, "flare": true, "w_side": 0.3},
				"arch": 1.1, "arch_dir": "side",
				"leaves": [{"at": 0.0, "L": 0.24, "hw": 0.007, "peak": 0.35, "elev": 1.15, "curl": -1.2, "dir": 0.5},
					{"at": 0.0, "L": 0.22, "hw": 0.0065, "peak": 0.35, "elev": 1.2, "curl": -1.3, "dir": 2.6},
					{"at": 0.0, "L": 0.2, "hw": 0.006, "peak": 0.35, "elev": 1.2, "curl": -1.2, "dir": 4.6, "w": 0.8}],
				"c": {"stem": [Color(0.24, 0.4, 0.2), Color(0.34, 0.42, 0.4)], "leaf": [Color(0.12, 0.3, 0.1), Color(0.2, 0.4, 0.16), Color(0.26, 0.46, 0.2)],
					"petal": [Color(0.34, 0.3, 0.7), Color(0.38, 0.34, 0.86), Color(0.44, 0.38, 0.92), Color(0.6, 0.56, 0.96)]},
			}
		"rose":
			return {
				"name": "Rose", "latin": "Rosa 'Crimson Glory'",
				"form": "rose", "height": 0.55, "stem_r": 0.0038, "plants": 2, "bend": 0.24, "wiggle": 0.12,
				"line": "Whorls of petals, tight and upright in the middle, opening outward, and a pair of each through W.",
				"rose": {"thick": 0.0016, "whorls": [
					{"n": 3, "L": 0.018, "hw": 0.011, "elev": 1.5, "curl": 0.35, "r0": 0.001, "lift": 0.004},
					{"n": 4, "L": 0.022, "hw": 0.014, "elev": 1.38, "curl": 0.25, "r0": 0.002, "lift": 0.003},
					{"n": 5, "L": 0.027, "hw": 0.017, "elev": 1.2, "curl": 0.05, "r0": 0.003, "lift": 0.002},
					{"n": 5, "L": 0.032, "hw": 0.02, "elev": 0.95, "curl": -0.35, "r0": 0.004, "lift": 0.001},
					{"n": 5, "L": 0.036, "hw": 0.023, "elev": 0.62, "curl": -0.7, "r0": 0.005, "lift": 0.0}]},
				"sepals": {"n": 5, "L": 0.024, "hw": 0.004, "elev": -0.5, "curl": -0.6},
				"compound": [{"at": 0.35, "dir": 0.4, "L": 0.09}, {"at": 0.55, "dir": 2.6, "L": 0.08}, {"at": 0.7, "dir": 4.6, "L": 0.07, "w": 0.7}],
				"c": {"stem": [Color(0.22, 0.34, 0.14), Color(0.4, 0.3, 0.16)], "leaf": [Color(0.14, 0.26, 0.1), Color(0.2, 0.36, 0.14), Color(0.26, 0.4, 0.18)],
					"petal": [Color(0.42, 0.0, 0.06), Color(0.66, 0.02, 0.1), Color(0.72, 0.05, 0.14), Color(0.48, 0.0, 0.08)]},
			}
		"passionflower":
			return {
				"name": "Passionflower", "latin": "Passiflora caerulea",
				"line": "Ten tepals, a banded crown of filaments through W, five stamens and three stigmas.",
				"form": "passion", "height": 0.55, "stem_r": 0.0022, "plants": 2, "face": 1.2, "bend": 0.3, "wiggle": 0.16,
				"petal": {"n": 5, "phase": 0.0, "L": 0.04, "hw": 0.009, "peak": 0.45, "round": 0.6, "elev": 0.12, "curl": -0.25, "r0": 0.004, "thick": 0.0012},
				"petal2": {"n": 5, "phase": PI / 5.0, "L": 0.037, "hw": 0.0085, "peak": 0.45, "round": 0.6, "elev": 0.16, "curl": -0.2, "r0": 0.004, "thick": 0.0012},
				"w_pair": true,
				"corona": {"n": 64, "band": 0.55, "L": 0.027, "hw": 0.0011, "elev": 0.22, "curl": -0.35, "r0": 0.006, "wr": 2.5},
				"column": {"h": 0.014, "r": 0.0022},
				"stamens": {"n": 5, "L": 0.012, "elev": -0.35, "anther": 0.004, "flat": true, "at_top": true},
				"stigmas": {"n": 3, "L": 0.011, "elev": 0.7, "knob": 0.0026},
				"leaves": [{"at": 0.3, "L": 0.06, "hw": 0.009, "peak": 0.45, "elev": 0.6, "curl": -0.5, "dir": 0.4, "palmate": 5, "stalk": 0.03},
					{"at": 0.55, "L": 0.055, "hw": 0.008, "peak": 0.45, "elev": 0.6, "curl": -0.5, "dir": 2.9, "palmate": 5, "stalk": 0.028},
					{"at": 0.78, "L": 0.05, "hw": 0.008, "peak": 0.45, "elev": 0.6, "curl": -0.5, "dir": 5.0, "palmate": 5, "stalk": 0.025, "w": 0.7}],
				"tendrils": 2,
				"c": {"stem": [Color(0.24, 0.38, 0.16), Color(0.3, 0.44, 0.18)], "leaf": [Color(0.12, 0.28, 0.1), Color(0.2, 0.38, 0.14), Color(0.26, 0.42, 0.2)],
					"petal": [Color(0.86, 0.92, 0.84), Color(0.95, 0.97, 0.93), Color(0.92, 0.95, 0.9), Color(0.88, 0.94, 0.86)],
					"petal2": [Color(0.8, 0.86, 0.9), Color(0.9, 0.93, 0.97), Color(0.86, 0.9, 0.95), Color(0.82, 0.88, 0.94)],
					"centre": [Color(0.66, 0.74, 0.42), Color(0.6, 0.7, 0.4)], "stamen": [Color(0.62, 0.74, 0.36), Color(0.8, 0.82, 0.3)],
					"extra": [Color(0.38, 0.22, 0.24), Color(0.44, 0.26, 0.3)],
					"corona": [Color(0.34, 0.08, 0.36), Color(0.97, 0.97, 0.98), Color(0.3, 0.42, 0.92)]},
			}
		"clematis":
			return {
				"name": "Clematis", "latin": "Clematis 'Jackmanii'",
				"line": "Four velvet sepals in the slice and a pair through W, on vines up the walls.",
				"form": "ring", "height": 0.0, "stem_r": 0.0015, "plants": 0, "bloom_only": true,
				"petal": {"n": 4, "phase": 0.3, "L": 0.05, "hw": 0.019, "peak": 0.55, "round": 0.45, "elev": 0.12, "curl": -0.15, "r0": 0.004, "thick": 0.0014},
				"w_pair": true,
				"stamens": {"n": 18, "band": 0.6, "L": 0.009, "elev": 1.0, "anther": 0.0016},
				"c": {"petal": [Color(0.5, 0.3, 0.62), Color(0.36, 0.16, 0.56), Color(0.4, 0.2, 0.62), Color(0.5, 0.32, 0.7)],
					"stamen": [Color(0.9, 0.88, 0.72), Color(0.96, 0.92, 0.7)]},
			}
		"lavender":
			return {
				"name": "Lavender", "latin": "Lavandula angustifolia",
				"line": "Tiny florets round the top of a slim spike, pointing every way, through W as well.",
				"form": "spike", "height": 0.5, "stem_r": 0.0016, "plants": 5, "bend": 0.28, "wiggle": 0.14,
				"bells": {"n": 48, "from": 0.7, "to": 0.99, "L": 0.012, "R": 0.0055, "droop": -0.6, "side": 0.0, "spread": 3.1, "bud": 8, "w_side": 1.2},
				"leaves": [{"at": 0.0, "L": 0.08, "hw": 0.0028, "peak": 0.4, "elev": 0.9, "curl": -0.3, "dir": 0.3, "pointed": true},
					{"at": 0.0, "L": 0.075, "hw": 0.0028, "peak": 0.4, "elev": 0.95, "curl": -0.3, "dir": 1.9, "pointed": true},
					{"at": 0.02, "L": 0.07, "hw": 0.0026, "peak": 0.4, "elev": 0.9, "curl": -0.3, "dir": 3.4, "pointed": true},
					{"at": 0.04, "L": 0.065, "hw": 0.0025, "peak": 0.4, "elev": 1.0, "curl": -0.3, "dir": 4.9, "pointed": true, "w": 0.8},
					{"at": 0.12, "L": 0.05, "hw": 0.0022, "peak": 0.4, "elev": 1.0, "curl": -0.2, "dir": 2.6, "pointed": true}],
				"c": {"stem": [Color(0.42, 0.5, 0.4), Color(0.5, 0.56, 0.48)], "leaf": [Color(0.4, 0.5, 0.42), Color(0.52, 0.6, 0.52), Color(0.58, 0.64, 0.56)],
					"petal": [Color(0.38, 0.26, 0.66), Color(0.5, 0.34, 0.84), Color(0.58, 0.4, 0.9), Color(0.66, 0.5, 0.94)]},
			}
		"cornflower":
			return {
				"name": "Cornflower", "latin": "Centaurea cyanus",
				"line": "Ragged blue florets round a dark eye, spread through W: a few whole in the slice, the rest as stubs.",
				"form": "band", "height": 0.44, "stem_r": 0.0014, "plants": 5, "bend": 0.34, "wiggle": 0.22,
				"rays": {"n": 18, "band": 0.5, "L": 0.022, "hw": 0.0065, "peak": 0.85, "round": 0.25, "elev": 0.28, "curl": 0.15, "r0": 0.006, "thick": 0.0009, "wr": 1.8, "kind": "petal"},
				"disc": {"r": 0.006, "h": 0.006},
				"leaves": [{"at": 0.05, "L": 0.08, "hw": 0.004, "peak": 0.5, "elev": 0.8, "curl": -0.4, "dir": 0.6, "pointed": true},
					{"at": 0.2, "L": 0.065, "hw": 0.0035, "peak": 0.5, "elev": 0.8, "curl": -0.4, "dir": 3.0, "pointed": true},
					{"at": 0.38, "L": 0.05, "hw": 0.003, "peak": 0.5, "elev": 0.9, "curl": -0.3, "dir": 5.1, "pointed": true, "w": 0.7}],
				"c": {"stem": [Color(0.4, 0.5, 0.36), Color(0.46, 0.56, 0.42)], "leaf": [Color(0.38, 0.48, 0.36), Color(0.46, 0.56, 0.42), Color(0.52, 0.6, 0.48)],
					"petal": [Color(0.18, 0.2, 0.62), Color(0.16, 0.36, 0.9), Color(0.22, 0.44, 0.96), Color(0.34, 0.54, 0.98)],
					"centre": [Color(0.24, 0.1, 0.36), Color(0.3, 0.16, 0.5)]},
			}
		"marigold":
			return {
				"name": "French marigold", "latin": "Tagetes patula",
				"line": "A pompom of frilled orange petals packed in every direction, so it stays round in every slice.",
				"form": "band", "height": 0.3, "stem_r": 0.0026, "plants": 3, "bend": 0.2, "wiggle": 0.12,
				"rays": {"n": 64, "band": 1.25, "L": 0.016, "hw": 0.0085, "peak": 0.7, "round": 1.0, "elev": 0.55, "curl": 0.35, "r0": 0.004, "thick": 0.001, "wr": 1.5, "kind": "petal"},
				"rays2": {"n": 36, "band": 1.4, "L": 0.01, "hw": 0.0065, "peak": 0.7, "round": 1.0, "elev": 1.0, "curl": 0.3, "r0": 0.003, "thick": 0.001, "kind": "petal"},
				"disc": {"r": 0.004, "h": 0.005},
				"leaves": [{"at": 0.1, "L": 0.07, "hw": 0.009, "peak": 0.5, "elev": 0.6, "curl": -0.5, "dir": 0.4, "teeth": 7, "depth": 0.7},
					{"at": 0.25, "L": 0.06, "hw": 0.008, "peak": 0.5, "elev": 0.6, "curl": -0.5, "dir": 2.6, "teeth": 6, "depth": 0.7},
					{"at": 0.42, "L": 0.05, "hw": 0.007, "peak": 0.5, "elev": 0.6, "curl": -0.4, "dir": 4.7, "teeth": 5, "depth": 0.7, "w": 0.7}],
				"c": {"stem": [Color(0.3, 0.42, 0.18), Color(0.38, 0.48, 0.22)], "leaf": [Color(0.16, 0.32, 0.12), Color(0.22, 0.4, 0.14), Color(0.28, 0.44, 0.18)],
					"petal": [Color(0.86, 0.3, 0.02), Color(0.98, 0.52, 0.04), Color(1.0, 0.64, 0.08), Color(0.94, 0.42, 0.04)],
					"centre": [Color(0.8, 0.42, 0.04), Color(0.9, 0.5, 0.06)]},
			}
		"snowdrop":
			return {
				"name": "Snowdrop", "latin": "Galanthus nivalis",
				"line": "One white bell hanging from an arching stalk, as round through W as across it.",
				"form": "raceme", "height": 0.17, "stem_r": 0.0013, "plants": 6, "bend": 0.1, "wiggle": 0.05,
				"bells": {"n": 1, "from": 0.97, "to": 0.98, "L": 0.022, "R": 0.0085, "droop": 1.45, "side": 0.0, "spread": 0.1, "bud": 0, "flare": true, "w_side": 0.0},
				"arch": 0.75,
				"leaves": [{"at": 0.0, "L": 0.15, "hw": 0.0042, "peak": 0.4, "elev": 1.3, "curl": -0.5, "dir": 0.4},
					{"at": 0.0, "L": 0.13, "hw": 0.004, "peak": 0.4, "elev": 1.3, "curl": -0.6, "dir": 3.4, "w": 0.6}],
				"c": {"stem": [Color(0.36, 0.5, 0.38), Color(0.44, 0.58, 0.44)], "leaf": [Color(0.34, 0.48, 0.38), Color(0.44, 0.58, 0.46), Color(0.52, 0.64, 0.52)],
					"petal": [Color(0.9, 0.95, 0.9), Color(0.97, 0.98, 0.97), Color(0.95, 0.97, 0.95), Color(0.62, 0.8, 0.56)]},
			}
	return {}
