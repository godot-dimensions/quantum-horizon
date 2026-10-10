extends Node4D

## WATER LAB, THE SEA: the boats (Ramon, 9 Oct, round 3: "Keep two principal boats in the presentation.
## Populate W with additional boat instances ... The additional boats should make the
## fourth-dimensional distribution more apparent without overcrowding the visible slice"; and "use
## the tool that actually distributes geometry through W ... not the static illusion").
##
## THROUGH W (round 4 to 5: the W Tools Exploder's layers, the principals' copies nudged near them; round
## 6, below: one rule for all of them, spread wide). Each is a whole boat (fishing_boat_4d.gd) riding the
## sea at its own W, turned a random heading, a little bigger or smaller. Kept clear of the pier and the
## platform.
##
## THE WHITE BOATS AND THE OTHERS (Ramon, 9 Oct: "about the white boat, his copies in W should not be
## orange. just other boats, and those need to be further away in the distance"): the principal and its
## copies through W are white. Orange is only for `others`: different boats, scattered further out, none
## in the default slice ("those orange boats should not be visible in the default slice, but scattered a
## bit"). Seen only far off, they are built simple (fishing_boat_4d.gd `simple`: no tyres, rust, crates or
## stays).
##
## ROUND 6 (Ramon, #38: "There are currently two boats visible in the default W-slice. I don't want that.
## Remove the left boat from the default slice. Keep the remaining one as the primary visible boat"; #45:
## "When rotating through W, the boats currently appear much too close together ... Spread them across a
## much wider area. Vary their positions through W. Avoid placing multiple boats immediately beside each
## other in neighboring slices. Keep the overall number of boats manageable"). One principal now (the
## right one as you walk out; the seascape passes it). Its copies were nudged 4 to 12 m from it, so a turn
## that brought one in showed it beside the principal's own place, and the copies of the two principals
## sat in the same few layers. Now every boat but the principal is placed by one rule, seeded: anywhere
## from `range_m` out to sea, at least `apart` metres from every other boat, and at least `neighbour_apart`
## from any boat whose W is within `neighbour_w` of its own (the next slices over), its W itself spread
## between `w_range` metres either side. Nine boats in all. A boat this far out shows for a few degrees of
## turn (at 100 m a degree moves the slice nearly 2 m through W, and a boat is about 4 m deep in it), so
## each W is also kept within `max_angle` of the slice as seen from the platform: every one can be found.

const Boat := preload("res://ramon/WaterLab/seascape/fishing_boat_4d.gd")

## The principal boat(s): [x, z, heading], at w 0.
@export var principals: Array = [[48.0, 9.0, PI * 0.5]]
## The principal's copies through W (white), and the other boats (orange).
@export var copies: int = 3
@export var others: int = 5
## How far out (m from `centre`), the bearings they keep to (radians either side of +x, out to sea).
@export var range_m := Vector2(40.0, 150.0)
@export var spread: float = 1.45
## How far apart every two boats keep (m, in x and z), and how far apart two in neighbouring slices do.
@export var apart: float = 34.0
@export var neighbour_apart: float = 70.0
@export var neighbour_w: float = 5.0
## How far off the slice in W, either side (m), and at most how steep a turn finds each (degrees, seen
## from `centre`).
@export var w_range := Vector2(4.0, 16.0)
@export var max_angle: float = 14.0
@export var size_jitter: float = 0.15
@export var seed_salt: int = 11
## Kept clear of: the pier and platform (a box x 0..clear_x, |z| < clear_z).
@export var clear_x: float = 34.0
@export var clear_z: float = 10.0
var centre := Vector4.ZERO

var water: Node = null
var viewer: Node4D = null
var boats: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_salt, "fleet"])
	var placed: Array = []
	for i in principals.size():
		var pr: Array = principals[i]
		_spawn("Boat%d" % i, Vector4(float(pr[0]), 0.0, float(pr[1]), 0.0), float(pr[2]), 1.0, Boat.WHITE)
		placed.append(Vector3(float(pr[0]), float(pr[1]), 0.0))
	var kinds: Array = []
	for k in copies:
		kinds.append(["Copy%d" % k, Boat.WHITE, false])
	for k in others:
		kinds.append(["Other%d" % k, Boat.ORANGE, true])
	# Alternate the side of W, so the turns either way each find some.
	var side: float = 1.0
	for kind in kinds:
		for tries in 40:
			var a: float = rng.randf_range(-spread, spread)
			var r: float = rng.randf_range(range_m.x, range_m.y)
			var p := Vector2(centre.x + cos(a) * r, centre.z + sin(a) * r)
			if p.x < clear_x and absf(p.y) < clear_z:
				continue
			var w_max: float = minf(w_range.y, r * sin(deg_to_rad(max_angle)))
			if w_max < w_range.x:
				continue
			var w: float = side * rng.randf_range(w_range.x, w_max)
			var ok: bool = true
			for q in placed:
				var d: float = p.distance_to(Vector2(q.x, q.y))
				if d < apart or (absf(w - q.z) < neighbour_w and d < neighbour_apart):
					ok = false
					break
			if not ok:
				continue
			placed.append(Vector3(p.x, p.y, w))
			_spawn(String(kind[0]), Vector4(p.x, 0.0, p.y, w), rng.randf() * TAU, 1.0 + rng.randf_range(-size_jitter, size_jitter), String(kind[1]), bool(kind[2]))
			side = -side
			break


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
