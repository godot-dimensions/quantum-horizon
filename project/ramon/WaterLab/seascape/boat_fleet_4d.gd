extends Node4D

## WATER LAB, THE SEA: the boats (Ramon, 9 Oct, round 3: "Keep two principal boats in the presentation.
## Populate W with additional boat instances ... The additional boats should make the
## fourth-dimensional distribution more apparent without overcrowding the visible slice"; and "use
## the tool that actually distributes geometry through W ... not the static illusion").
##
## THE W TOOLS EXPLODER'S DISTRIBUTION, carried as its algorithm (WTools/exploder/w_exploder_4d.gd
## layer_ws, _dice, _place_near, _spawn; not its trunk slab, which deepens one mesh in W and places
## nothing): the slice's W is cut into layers `layer_spacing` apart either side, out to `w_reach`;
## each principal boat throws a die per layer (stable: seeded from its name and the layer), and on
## `share` of them a boat goes there, nudged sideways `shift` metres in a random direction, turned a
## random heading, a little bigger or smaller. Each is a whole boat (fishing_boat_4d.gd) riding the
## sea at its own W. Kept clear of the pier and the platform. Not preloaded from WTools: that file
## pulls in the pen's oak and grass (the scene stands on its own: carried/README.md).
##
## THE WHITE BOATS AND THE OTHERS (Ramon, 9 Oct: "about the white boat, his copies in W should not be
## orange. just other boats, and those need to be further away in the distance"): the principals and
## their copies through W are all white. Orange is only for `others`: different boats, scattered at
## random 35 to 85 m out, each 3.5 to 9 m off the slice in W, so none is in the default slice ("those
## orange boats should not be visible in the default slice, but scattered a bit") and a slice turned
## a few degrees brings them in. Not further: out there a degree of turn moves the slice the better
## part of a metre through W per 50 m, and a boat 3.8 m deep in W shows only for a degree or two
## (a first try at 80-140 m and 12-30 degree turns was never caught by the frames). Seen only far
## off, they are built simple (fishing_boat_4d.gd `simple`: no tyres, rust, crates or stays).
##
## NO class_name.

const Boat := preload("res://ramon/WaterLab/seascape/fishing_boat_4d.gd")

## The two principal boats: [x, z, heading], at w 0.
@export var principals: Array = [[48.0, 9.0, PI * 0.5], [38.0, -24.0, 0.35]]
@export var layer_spacing: float = 4.5
@export var w_reach: float = 13.5
@export var share: float = 0.55
@export var shift := Vector2(4.0, 12.0)
@export var size_jitter: float = 0.15
@export var seed_salt: int = 7
## Kept clear of: the pier and platform (a box x 0..clear_x, |z| < clear_z).
@export var clear_x: float = 34.0
@export var clear_z: float = 10.0
## The other boats: how many, how far from `centre` (m), how far off the slice in W (m, either side),
## the bearings they keep to (radians either side of +x, out to sea), and how far apart they keep (m).
@export var others: int = 6
@export var others_range := Vector2(35.0, 85.0)
@export var others_w := Vector2(3.5, 9.0)
@export var others_spread: float = 1.4
@export var others_apart: float = 16.0
var centre := Vector4.ZERO

var water: Node = null
var viewer: Node4D = null
var boats: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	for i in principals.size():
		var pr: Array = principals[i]
		_spawn("Boat%d" % i, Vector4(float(pr[0]), 0.0, float(pr[1]), 0.0), float(pr[2]), 1.0, Boat.WHITE)
		for w in layer_ws():
			rng.seed = hash([seed_salt, "Boat%d" % i, snappedf(w, 0.01)])
			if rng.randf() > share:
				continue
			for tries in 6:
				var a: float = rng.randf() * TAU
				var r: float = rng.randf_range(shift.x, shift.y)
				var p := Vector2(float(pr[0]) + cos(a) * r, float(pr[1]) + sin(a) * r)
				if p.x < clear_x and absf(p.y) < clear_z:
					continue
				_spawn("Boat%d_w%+.1f" % [i, w], Vector4(p.x, 0.0, p.y, w + rng.randf_range(-0.6, 0.6)), rng.randf() * TAU,
					1.0 + rng.randf_range(-size_jitter, size_jitter), Boat.WHITE)
				break
	# The others, scattered: a random bearing and distance each, kept clear of the pier, the platform,
	# the white boats and each other.
	rng.seed = hash([seed_salt, "others"])
	var taken: Array = []
	for pr in principals:
		taken.append(Vector2(float(pr[0]), float(pr[1])))
	for k in others:
		for tries in 16:
			var a: float = rng.randf_range(-others_spread, others_spread)
			var r: float = rng.randf_range(others_range.x, others_range.y)
			var p := Vector2(centre.x + cos(a) * r, centre.z + sin(a) * r)
			if p.x < clear_x and absf(p.y) < clear_z:
				continue
			var crowded: bool = false
			for q in taken:
				if p.distance_to(q) < others_apart:
					crowded = true
			if crowded:
				continue
			taken.append(p)
			var w: float = rng.randf_range(others_w.x, others_w.y) * (1.0 if rng.randf() < 0.5 else -1.0)
			_spawn("Other%d" % k, Vector4(p.x, 0.0, p.y, w), rng.randf() * TAU, 1.0 + rng.randf_range(-size_jitter, size_jitter), Boat.ORANGE, true)
			break


## The layers either side of the slice, the slice's own (w 0, the principals) left out.
func layer_ws() -> Array:
	var out: Array = []
	var k: int = 1
	while float(k) * layer_spacing <= w_reach + 0.001:
		out.append(float(k) * layer_spacing)
		out.append(-float(k) * layer_spacing)
		k += 1
	return out


func _spawn(nm: String, at: Vector4, heading: float, size: float, tone: String, simple: bool = false) -> void:
	var b := Node4D.new()
	b.name = nm
	b.set_script(Boat)
	b.position = at
	b.set("heading", heading)
	b.set("length", 11.0 * size)
	b.set("beam", 3.8 * size)
	b.set("water", water)
	b.set("viewer", viewer)
	b.set("tone", tone)
	b.set("simple", simple)
	add_child(b)
	boats.append(b)
