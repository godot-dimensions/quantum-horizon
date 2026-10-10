extends Node4D

## WATER LAB: the tank's koi. Each is swum here, on the CPU, and drawn as a koi LOFTED IN 4D
## (life/koi_loft_4d.gd): its rigid pieces posed along the bent spine every frame, so a turned slice
## cuts the real 4D body. (Until 9 Oct they were a 3D mesh that a shader only shrank off the slice:
## Ramon, "they need to be true 4D lofts".) This node sits at the middle of the tank's water, and
## everything here is in that frame: x along the tank, y up, z toward the glass (+z is the front), W
## through it.
##
## HOW A KOI SWIMS HERE (Wu et al. 2007; the research in follow_up/water_lab.md):
##   BURST AND COAST  a few tail beats (amplitude 0.10 body lengths, about 1.4 beats a second at half
##                    a body length a second), then a glide with the tail almost still while the
##                    water slows it, then a few beats again. That rhythm is most of what reads as
##                    a koi rather than a fish-shaped thing sliding about.
##   TURNING          by bending: a turn bends the body into a C about a point a third of the way
##                    back (the shader's bend), the harder the faster it turns, and the fish leans a
##                    little into it.
##   HOVERING         nearly still, the pectorals swung out and sculling, the tail barely moving.
##   AT THE SURFACE   now and then one rises, tips up, and gulps at the surface a few times.
##   AT THE GLASS     stand near the tank and the nearest koi come to the glass in front of you and
##                    gulp, as pond koi do at anyone who might feed them.
##   THROUGH W        most keep to the slice (a spring in W, and once near it they settle exactly onto
##                    it: a lofted koi shows only within its own half width of the slice), but now
##                    and then one wanders off through W, thinning away fin first, to come back
##                    later. A few live off it.
##   FEEDING          drop_food_at(points) drops a pinch of pellets into the water (the room's F, at the
##                    feeding panel or on the turning square); they fall in fast, slow as they sink
##                    through the koi's water, then drift down to the sand. Every koi near enough comes
##                    for them, faster than it ever swims otherwise, and gulps them down one by one
##                    (Ramon, 9 Oct: "maybe you can interact with the fishtank").
##
## NO class_name (engine_gotchas.md).

const Herd := preload("res://ramon/WaterLab/shared/slice_herd_4d.gd")
const KoiLoft := preload("res://ramon/WaterLab/life/koi_loft_4d.gd")
const Kit := preload("res://ramon/WaterLab/life/loft_kit.gd")
const BLOB := preload("res://ramon/WaterLab/life/blob.gdshader")
const MAX_FOOD := 72
## A pellet's radius, metres, and its colour. ROUND 6 (Ramon: "Food particles should visibly fall into
## the aquarium ... The player should immediately understand that feeding has occurred"): they were 1.3 cm
## across, brown, and scattered 10 cm through W, while a pellet is a 4D ball only its own radius deep in W:
## most were never in the slice at all, and the rest were a pixel or two at the glass. Now 9 cm and a strong
## orange with a little shine (at 6 cm and amber, the first frames read them as the marine snow), each
## dropped exactly in your slice (the room works out where that is in the turned contents).
const FOOD_RADIUS := 0.045
const FOOD_COLOUR := Color(1.0, 0.42, 0.06, 1.0)

## The varieties in the shader's order.
const VARIETIES := ["Kohaku", "Taisho Sanke", "Showa", "Tancho", "Ogon", "Platinum Ogon", "Asagi", "Chagoi"]

@export_range(0, 40) var count: int = 16
@export var school_seed: int = 4417
## The water's half extents (x, y, z, W), metres; the koi keep `margin` inside them.
@export var half_extents: Vector4 = Vector4(6.0, 2.1, 1.6, 1.6)
@export var margin: float = 0.3
## The bottom's height above the water's floor (the sand and the stones), metres.
@export var floor_height: float = 0.35
## How high above the water's floor they wander, metres (0: the whole water). The tank reaches the
## ceiling (9 Oct), and from the floor you see its lower few metres: they keep there, and food dropped
## on the surface sinks into it.
@export var view_band: float = 0.0
@export var length_range: Vector2 = Vector2(0.62, 0.98)
## Cruising speed in body lengths a second.
@export var cruise_bl: float = 0.5
## The W spring's strength, and how often (a share of retargets) a koi wanders out through W.
@export var w_pull: float = 0.8
@export var w_wander_share: float = 0.12
## How many of the koi live off the level slice, through W (seen only when the slice is turned).
@export var hidden_count: int = 4
## How near the glass you stand (metres from the tank's front, in the tank's x range) before koi come.
@export var beg_distance: float = 4.5
## Each koi's half depth through W at its deepest, per metre of its length (the lofted koi is round
## across x and W: its half width there, life/koi_mesh.gd PROFILE).
var w_half: float = 0.083

## Spheres the koi swim round (rocks, coral heads): [centre (tank space), radius].
var obstacles: Array = []
## The sand's 4D hills (dunes_4d.gd height_at), or null for the flat floor.
var ground: Node = null
## The arches' openings (reef_4d.gd): now and then a koi swims through one.
var arches: Array = []
## Something big the koi keep clear of (the hammerhead, shark_4d.gd: its `p`), or null.
var predator: Node = null
## Where you are, in the tank's frame (set by the room each frame; far away when unset).
var viewer := Vector4(0.0, 0.0, 1000.0, 0.0)

var food_herd: Node4D
var fish: Array = []
## The lofted koi, one a fish.
var koi_nodes: Array = []
## Pellets: {"p": Vector4, "v": Vector4, "age": float, "taken": int (the koi going for it, or -1)}.
var food: Array = []
## Microseconds a frame the swim takes (a running mean), for the research board's benchmark.
var cpu_us: float = 0.0
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0


func _ready() -> void:
	_rng.seed = school_seed
	# The food pellets stay slice-drawn: a pellet is a 4D ball, and a ball's cut really is a sphere
	# that shrinks as the slice leaves it, which is all that trick draws.
	food_herd = Node4D.new()
	food_herd.name = "FoodHerd"
	food_herd.set_script(Herd)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 10
	ball.rings = 6
	food_herd.set("mesh", ball)
	food_herd.set("shader", BLOB)
	food_herd.set("w_radius", 1.0)
	food_herd.set("count", MAX_FOOD)
	add_child(food_herd)
	respawn()


func respawn() -> void:
	fish.clear()
	for k in koi_nodes:
		(k as Node).queue_free()
	koi_nodes.clear()
	var order: Array = [0, 1, 2, 4, 0, 3, 6, 5, 1, 7, 0, 2, 4, 1, 6, 0, 3, 5, 2, 7]
	for i in count:
		var f: Dictionary = {}
		f["len"] = _rng.randf_range(length_range.x, length_range.y)
		f["variety"] = int(order[i % order.size()])
		f["long"] = 1 if _rng.randf() < 0.25 else 0
		f["seed"] = _rng.randf()
		f["p"] = _random_point(0.0)
		var a: float = _rng.randf() * TAU
		f["h"] = Vector4(cos(a), 0.0, sin(a) * 0.5, 0.0).normalized()
		f["v"] = 0.15
		f["phase"] = _rng.randf() * TAU
		f["amp"] = 0.05
		f["bend"] = 0.0
		f["roll"] = 0.0
		f["spread"] = 0.1
		f["gulp"] = 0.0
		f["mode"] = "cruise"
		f["mode_t"] = _rng.randf_range(2.0, 10.0)
		f["target"] = _random_point(0.0)
		f["stroke"] = 0.0
		f["coast"] = _rng.randf_range(0.0, 2.0)
		f["leader"] = -1
		f["turn"] = 0.0
		# The hidden koi: their home is a W of their own, ana or kata of the slice.
		f["home_w"] = 0.0
		if i >= count - hidden_count:
			# Near enough that a turn of 20 degrees from the glass finds them, far enough that the level
			# slice never does.
			f["home_w"] = (1.0 if i % 2 == 0 else -1.0) * _rng.randf_range(0.7, 1.5)
			var p0: Vector4 = f["p"]
			p0.w = f["home_w"]
			f["p"] = p0
		var h0: Vector4 = f["h"]
		f["frame"] = Kit.frame_for(h0, Projection(Vector4(h0.z, 0.0, -h0.x, 0.0).normalized(), Vector4(0, 1, 0, 0), h0, Vector4(0, 0, 0, 1)))
		fish.append(f)
		var k := Node4D.new()
		k.name = "Koi%02d" % i
		k.set_script(KoiLoft)
		k.set("variety", int(f["variety"]))
		k.set("long_fins", int(f["long"]) == 1)
		k.set("pattern_seed", float(f["seed"]))
		add_child(k)
		koi_nodes.append(k)


func _random_point(w_spread: float) -> Vector4:
	var p := Vector4(_rng.randf_range(-half_extents.x + margin + 0.6, half_extents.x - margin - 0.6), 0.0,
		_rng.randf_range(-half_extents.z + margin + 0.35, half_extents.z - margin - 0.35), _rng.randf_range(-w_spread, w_spread))
	var lo_y: float = _floor_at(p) + margin + 0.35
	var hi_y: float = minf(half_extents.y - margin - 0.35, _band_top())
	p.y = _rng.randf_range(lo_y, maxf(hi_y, lo_y + 0.1))
	return p


## The top of where they wander (the surface when there is no band).
func _band_top() -> float:
	if view_band <= 0.0:
		return half_extents.y
	return minf(half_extents.y, -half_extents.y + floor_height + view_band)


## The sand under a point (the dunes, or the flat floor).
func _floor_at(p: Vector4) -> float:
	if ground != null:
		return float(ground.call("height_at", p.x, p.z, p.w))
	return -half_extents.y + floor_height


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var dt: float = minf(delta, 0.05)
	_time += dt
	_float_food(dt)
	for i in fish.size():
		_think(i, dt)
		_swim(i, dt)
	_draw()
	cpu_us = lerpf(cpu_us, float(Time.get_ticks_usec() - t0), 0.05)


## What a koi wants to do: modes change on their timers, or when you come near the glass.
func _think(i: int, dt: float) -> void:
	var f: Dictionary = fish[i]
	f["mode_t"] = float(f["mode_t"]) - dt
	var mode: String = f["mode"]
	var p: Vector4 = f["p"]
	# You at the glass: the nearest few koi come to you.
	var at_glass: bool = viewer.z > half_extents.z and viewer.z < half_extents.z + beg_distance and absf(viewer.x) < half_extents.x + 1.0
	if at_glass and mode != "beg" and mode != "rise" and _beggars() < 3 and absf(p.x - viewer.x) < 3.5 and _rng.randf() < dt * 0.5:
		mode = "beg"
		f["mode_t"] = _rng.randf_range(7.0, 13.0)
	if mode == "beg" and not at_glass:
		f["mode_t"] = minf(float(f["mode_t"]), 0.5)
	# Food on the water: every koi within reach goes for the nearest pellet nobody else has taken.
	if not food.is_empty() and mode != "feed":
		var j: int = _nearest_food(p, i)
		if j >= 0 and absf((food[j]["p"] as Vector4).x - p.x) < 7.0:
			mode = "feed"
			f["mode_t"] = 30.0
	if mode == "feed":
		var j2: int = -1
		for k in food.size():
			if int(food[k]["taken"]) == i:
				j2 = k
		if j2 < 0:
			j2 = _nearest_food(p, i)
			if j2 >= 0:
				food[j2]["taken"] = i
		if j2 < 0:
			mode = "cruise"
			f["mode_t"] = _rng.randf_range(2.0, 5.0)
			f["target"] = _random_point(0.0)
		else:
			f["target"] = food[j2]["p"]
	if float(f["mode_t"]) <= 0.0:
		var r: float = _rng.randf()
		if r < 0.14:
			mode = "rise"
			f["mode_t"] = _rng.randf_range(9.0, 14.0)
			f["target"] = Vector4(clampf(p.x + _rng.randf_range(-2.0, 2.0), -half_extents.x + 1.0, half_extents.x - 1.0),
				minf(half_extents.y - 0.16, _band_top()), clampf(p.z, -half_extents.z + 0.5, half_extents.z - 0.5), 0.0)
		elif r < 0.30:
			mode = "hover"
			f["mode_t"] = _rng.randf_range(3.0, 7.0)
		elif r < 0.40 and not arches.is_empty():
			# Through an arch: to a point before its opening, then out the other side.
			var a: Dictionary = arches[_rng.randi_range(0, arches.size() - 1)]
			var way: float = 1.0 if _rng.randf() < 0.5 else -1.0
			var mid: Vector4 = a["centre"]
			var axis: Vector4 = a["axis"]
			mid.y += _rng.randf_range(-0.25, 0.25) * float(a["half"])
			f["run"] = [mid - axis * 2.4 * way, mid, mid + axis * 2.6 * way]
			f["run_i"] = 0
			f["target"] = (f["run"] as Array)[0]
			mode = "arch"
			f["mode_t"] = 30.0
		elif r < 0.56 and fish.size() > 1:
			mode = "follow"
			var j: int = _rng.randi_range(0, fish.size() - 1)
			f["leader"] = j if j != i else (i + 1) % fish.size()
			f["mode_t"] = _rng.randf_range(6.0, 14.0)
		else:
			mode = "cruise"
			f["mode_t"] = _rng.randf_range(5.0, 12.0)
			var wander: bool = _rng.randf() < w_wander_share
			f["target"] = _random_point(0.0)
			var tw: Vector4 = f["target"]
			tw.w = float(f["home_w"])
			f["target"] = tw
			if wander:
				var t: Vector4 = f["target"]
				t.w = (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(0.6, half_extents.w - margin)
				f["target"] = t
				f["mode_t"] = _rng.randf_range(8.0, 14.0)
	f["mode"] = mode
	match mode:
		"beg":
			var bx: float = clampf(viewer.x + (float(i % 3) - 1.0) * 0.7, -half_extents.x + 0.8, half_extents.x - 0.8)
			var by: float = clampf(viewer.y - 0.3 + float(i % 2) * 0.35, -half_extents.y + floor_height + 0.6, half_extents.y - 0.5)
			f["target"] = Vector4(bx, by, half_extents.z - margin - 0.32, 0.0)
		"follow":
			var l: Dictionary = fish[int(f["leader"])]
			f["target"] = (l["p"] as Vector4) - (l["h"] as Vector4) * float(l["len"]) * 1.3


func _beggars() -> int:
	var n: int = 0
	for f in fish:
		if String(f["mode"]) == "beg":
			n += 1
	return n


## Steering, the beat and the glide, the bend and the lean.
func _swim(i: int, dt: float) -> void:
	var f: Dictionary = fish[i]
	var p: Vector4 = f["p"]
	var h: Vector4 = f["h"]
	var L: float = f["len"]
	var v: float = f["v"]
	var mode: String = f["mode"]
	var target: Vector4 = f["target"]
	var to: Vector4 = target - p
	var dist: float = to.length()
	var want: Vector4 = to / maxf(dist, 0.001)
	var want_speed: float = cruise_bl * L
	var hovering: bool = false
	match mode:
		"hover":
			want_speed = 0.02
			want = h
			hovering = true
		"feed":
			# Faster than anything else they do: food.
			want_speed = clampf(dist * 1.2, 0.08, cruise_bl * L * 2.2)
			if dist < 0.30:
				hovering = true
				want = to.normalized() if dist > 0.01 else h
		"beg", "rise":
			want_speed = clampf(dist * 0.5, 0.03, cruise_bl * L)
			if dist < 0.35:
				hovering = true
				# Face the glass (begging) or nose up at the surface (rising).
				want = Vector4(0.0, 0.0, 1.0, 0.0) if mode == "beg" else Vector4(h.x, 0.0, h.z, 0.0).normalized() + Vector4(0.0, 0.45, 0.0, 0.0)
				want = want.normalized()
		"follow":
			want_speed = clampf(dist * 0.6, 0.05, cruise_bl * L * 1.3)
		"arch":
			want_speed = cruise_bl * L * 1.1
			if dist < 0.45:
				var run: Array = f["run"]
				f["run_i"] = int(f["run_i"]) + 1
				if int(f["run_i"]) >= run.size():
					f["mode_t"] = 0.0
				else:
					f["target"] = run[int(f["run_i"])]
		_:
			if dist < 0.5:
				f["mode_t"] = minf(float(f["mode_t"]), 0.2)
	# Keep apart.
	var push := Vector4.ZERO
	for j in fish.size():
		if j == i:
			continue
		var o: Dictionary = fish[j]
		var d: Vector4 = p - (o["p"] as Vector4)
		var reach: float = (L + float(o["len"])) * 0.55
		var dl: float = d.length()
		if dl < reach and dl > 0.0001:
			push += d / dl * (reach - dl) / reach
	if predator != null:
		# Give the shark room: a wide berth, pushed hard, and quicker for it.
		var dp: Vector4 = p - (predator.get("p") as Vector4)
		var dl3: float = dp.length()
		if dl3 < 2.2 and dl3 > 0.001:
			push += dp / dl3 * (2.2 - dl3) * 1.8
			want_speed = maxf(want_speed, cruise_bl * L * 1.6)
	for ob in obstacles:
		var c: Vector4 = ob[0]
		var r: float = float(ob[1]) + L * 0.6
		var d2: Vector4 = p + h * L * 0.5 - c
		var dl2: float = d2.length()
		if dl2 < r and dl2 > 0.0001:
			push += d2 / dl2 * (r - dl2) / r * 2.5
	# The walls, looked for ahead.
	var ahead: Vector4 = p + h * (0.4 + v * 2.0 + L * 0.5)
	var wall := Vector4.ZERO
	var lo := Vector4(-half_extents.x, _floor_at(p) + 0.08 + L * 0.2, -half_extents.z, -half_extents.w) + Vector4.ONE * margin
	var hi := Vector4(half_extents.x, half_extents.y - 0.12, half_extents.z, half_extents.w) - Vector4.ONE * margin
	for k in 4:
		if ahead[k] < lo[k] + L * 0.4:
			wall[k] += (lo[k] + L * 0.4 - ahead[k])
		elif ahead[k] > hi[k] - L * 0.4:
			wall[k] -= (ahead[k] - hi[k] + L * 0.4)
	# W: back toward its home W (the slice, for most) unless it is wandering.
	var home_w: float = float(f["home_w"])
	if absf(target.w - home_w) < 0.3:
		want.w += (home_w - p.w) * w_pull
	var steer: Vector4 = want + push * 1.5 + wall * 3.0
	# Koi swim level: climbing and diving are kept gentle, a little steeper at the surface and for food.
	steer.y = clampf(steer.y, -0.35, 0.55 if (mode == "rise" or mode == "feed") else 0.35)
	if steer.length() > 0.0001:
		steer = steer.normalized()
	# Turning, at a rate that depends on how fast it swims (a hovering koi still turns, slowly).
	var max_rate: float = 0.5 + 2.2 * clampf(v / maxf(L, 0.1), 0.0, 1.0)
	if hovering:
		max_rate = 0.6
	var cosang: float = clampf(h.dot(steer), -1.0, 1.0)
	var ang: float = acos(cosang)
	var step: float = minf(ang, max_rate * dt)
	var h_new: Vector4 = h
	if ang > 0.0005:
		var perp: Vector4 = steer - h * cosang
		var pl: float = perp.length()
		if pl < 0.0001:
			perp = Vector4(h.z, 0.0, -h.x, 0.0)
			pl = perp.length()
		perp /= maxf(pl, 0.0001)
		h_new = (h * cos(step) + perp * sin(step)).normalized()
	# The signed turn rate about the fish's own up: + to its right.
	var right := Vector4(h.z, 0.0, -h.x, 0.0)
	right = right.normalized() if right.length() > 0.05 else Vector4(1.0, 0.0, 0.0, 0.0)
	var rate: float = (h_new - h).dot(right) / maxf(dt, 0.0001)
	f["turn"] = lerpf(float(f["turn"]), rate, 1.0 - exp(-8.0 * dt))
	h = h_new
	# BURST AND COAST: strokes while below the speed it wants, a glide above it.
	var stroke: float = float(f["stroke"])
	var coast: float = float(f["coast"])
	if stroke > 0.0:
		stroke -= dt
		if stroke <= 0.0:
			coast = _rng.randf_range(0.8, 2.6) * (0.5 if mode == "follow" else 1.0)
	elif coast > 0.0:
		coast -= dt
	elif v < want_speed * 1.05 and not hovering:
		stroke = _rng.randf_range(1.5, 3.0) / maxf(_beat_rate(want_speed, L), 0.3)
	var drag: float = 0.35
	var thrust: float = 0.0
	if stroke > 0.0:
		thrust = want_speed * drag + 0.12 * L
	if hovering:
		thrust = want_speed * drag
	v = maxf(v + (thrust - drag * v) * dt, 0.0)
	f["stroke"] = stroke
	f["coast"] = coast
	# The tail: big while beating, a ripple while gliding; the C bend from the turn.
	var beating: bool = stroke > 0.0
	var amp_want: float = 0.10 if beating else (0.018 if hovering else 0.03)
	f["amp"] = lerpf(float(f["amp"]), amp_want, 1.0 - exp(-(5.0 if beating else 2.0) * dt))
	var freq: float = _beat_rate(maxf(v, 0.05 * L), L) if beating else 0.55
	f["phase"] = fmod(float(f["phase"]) + TAU * freq * dt, TAU * 64.0)
	f["bend"] = lerpf(float(f["bend"]), clampf(float(f["turn"]) * 0.16, -0.32, 0.32), 1.0 - exp(-6.0 * dt))
	f["roll"] = lerpf(float(f["roll"]), clampf(-float(f["turn"]) * 0.12, -0.3, 0.3), 1.0 - exp(-3.0 * dt))
	# The pectorals spread to brake and to hover.
	var braking: bool = v > want_speed * 1.4 + 0.02
	f["spread"] = lerpf(float(f["spread"]), 1.0 if (hovering or braking) else 0.08, 1.0 - exp(-3.0 * dt))
	# Gulps: at the surface, and begging at the glass.
	var gulping: bool = hovering and (mode == "rise" or mode == "beg" or mode == "feed")
	f["gulp"] = (0.5 + 0.5 * sin(_time * 7.5 + float(f["seed"]) * 9.0)) if gulping else lerpf(float(f["gulp"]), 0.0, 1.0 - exp(-6.0 * dt))
	# On its home W: once near it, it settles exactly onto it and swims level in it (unless it is off
	# on a wander through W, when its target lies away from home).
	if absf(target.w - home_w) < 0.3 and absf(p.w - home_w) < 0.3:
		h.w *= exp(-4.0 * dt)
		p.w = move_toward(p.w, home_w, dt * (0.05 + 0.6 * absf(p.w - home_w)))
		h = h.normalized()
	# Never steeper than about 35 degrees (a koi does not stand on its tail).
	if absf(h.y) > 0.57:
		var flat := Vector4(h.x, 0.0, h.z, h.w)
		if flat.length() < 0.001:
			flat = Vector4(1.0, 0.0, 0.0, 0.0)
		h = (flat.normalized() * 0.82 + Vector4(0.0, signf(h.y) * 0.57, 0.0, 0.0)).normalized()
	p += h * v * dt
	# Hard walls, in case steering lost.
	for k in 4:
		p[k] = clampf(p[k], lo[k] - margin * 0.5, hi[k] + margin * 0.5)
	f["p"] = p
	f["h"] = h
	f["v"] = v


## A pinch of food at `points` (this node's frame), falling. The room puts them in your slice, in front of
## you and near the top of what you see through the glass: the tank reaches the ceiling, so a pinch on the
## real surface (until round 6) fell where no one could see it, and the koi rose out of view to eat.
func drop_food_at(points: Array) -> void:
	for at in points:
		if food.size() >= MAX_FOOD:
			break
		var p: Vector4 = at
		for k in 4:
			p[k] = clampf(p[k], -half_extents[k] + 0.15, half_extents[k] - 0.15)
		food.append({"p": p, "v": Vector4(0.0, -_rng.randf_range(0.5, 0.7), 0.0, 0.0), "age": 0.0, "taken": -1})


func _nearest_food(p: Vector4, me: int) -> int:
	var best: int = -1
	var best_d: float = INF
	for k in food.size():
		if int(food[k]["taken"]) >= 0 and int(food[k]["taken"]) != me:
			continue
		var d: float = ((food[k]["p"] as Vector4) - p).length()
		if d < best_d:
			best_d = d
			best = k
	return best


## Pellets fall in fast, slow as they sink through the koi's water, then drift down to the sand; a koi's
## mouth on one eats it. Straight down only: a sideways drift would carry them out of the slice when the
## contents are turned through W.
func _float_food(dt: float) -> void:
	var i: int = food.size() - 1
	while i >= 0:
		var fd: Dictionary = food[i]
		fd["age"] = float(fd["age"]) + dt
		var p: Vector4 = fd["p"]
		var v: Vector4 = fd["v"]
		v.y = move_toward(v.y, -0.18 if float(fd["age"]) < 7.0 else -0.05, dt * 0.3)
		p += v * dt
		p.x = clampf(p.x, -half_extents.x + 0.1, half_extents.x - 0.1)
		p.z = clampf(p.z, -half_extents.z + 0.1, half_extents.z - 0.1)
		p.y = maxf(p.y, -half_extents.y + floor_height - 0.1)
		fd["p"] = p
		fd["v"] = v
		var eaten: bool = float(fd["age"]) > 60.0
		for f in fish:
			var mouth: Vector4 = (f["p"] as Vector4) + (f["h"] as Vector4) * float(f["len"]) * 0.45
			if (mouth - p).length() < 0.07 + float(f["len"]) * 0.05:
				eaten = true
				break
		if eaten:
			food.remove_at(i)
		i -= 1
	# Who was going for an eaten pellet now looks again (the taken marks are by index).
	for k in food.size():
		var t: int = int(food[k]["taken"])
		if t >= 0 and String(fish[t]["mode"]) != "feed":
			food[k]["taken"] = -1


## Tail beats a second: about 1.4 at half a body length a second (koi, measured).
func _beat_rate(speed: float, L: float) -> float:
	return 0.6 + 1.6 * speed / maxf(L, 0.1)


## Each lofted koi posed: its frame carried on from the last (so it never flips), leaning into turns.
func _draw() -> void:
	for i in mini(fish.size(), koi_nodes.size()):
		var f: Dictionary = fish[i]
		var h: Vector4 = f["h"]
		var frame: Projection = Kit.frame_for(h, f["frame"])
		f["frame"] = frame
		var roll: float = f["roll"]
		var leaned := Projection(frame.x * cos(roll) + frame.y * sin(roll), frame.y * cos(roll) - frame.x * sin(roll), frame.z, frame.w)
		(koi_nodes[i] as Node4D).call("pose", f["p"], leaned, float(f["len"]), float(f["phase"]), float(f["amp"]), float(f["bend"]),
			float(f["spread"]), float(f["gulp"]), _time + float(f["seed"]) * 37.0)
	if food_herd != null:
		for k in MAX_FOOD:
			if k < food.size():
				food_herd.call("write", k, food[k]["p"], Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0), FOOD_COLOUR, Vector4(FOOD_RADIUS, 0.0, 0.25, 0.0))
			else:
				food_herd.call("write", k, Vector4(0, -100, 0, 0), Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0), Color(0, 0, 0, 1), Vector4.ZERO)
		food_herd.call("upload")


## For the panels and the HUD: what the school is doing (on the level slice through the tank).
func stats() -> Dictionary:
	var modes: Dictionary = {}
	var in_slice: int = 0
	var beats: float = 0.0
	for f in fish:
		modes[f["mode"]] = int(modes.get(f["mode"], 0)) + 1
		if absf((f["p"] as Vector4).w) < w_half * float(f["len"]):
			in_slice += 1
		if float(f["stroke"]) > 0.0:
			beats += _beat_rate(float(f["v"]), float(f["len"]))
	var meshes: int = 0
	for k in koi_nodes:
		meshes += int((k as Node).get("meshes"))
	return {"count": fish.size(), "modes": modes, "in_slice": in_slice, "hidden": hidden_count, "cpu_us": cpu_us,
		"meshes": meshes, "tets": int(koi_nodes[0].get("tets")) if not koi_nodes.is_empty() else 0,
		"beats": beats / maxf(float(fish.size()), 1.0) * 2.0}
