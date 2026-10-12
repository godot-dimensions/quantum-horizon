extends Node4D

## WATER LAB, THE SEA: waves breaking on the platform (Ramon, 9 Oct, round 4: "When a wave approaches or
## strikes the platform, add localized water effects ... water spray or particles appear along the
## side facing the incoming waves ... some temporary wetness to the affected platform surface ...
## They shouldn't appear continuously when no waves are approaching").
##
## WATCHING THE WATER: `rim` points round the platform's edge, the sea's height at each (the surface's
## own height_at, the shader's waves solved on the CPU) read four times a second. A point is HIT when
## the water there rises into the top of what this sea has lately thrown at the rim (`share` of its
## recent highest, which sinks slowly so a calmer sea is judged by its own crests), and at least
## `floor_h` over the mean: a big crest arriving against the platform's side. (First a metre under
## the deck, which no sea here reached; then a fixed 0.75 m, then 1.3 m. Measured at the rim, the
## crests of the swell and the storm overlap, 1.2 to 1.8 m either way, so no one height worked:
## 28 bursts in ten seconds of swell, or none in a storm.) Only then, there:
##   SPRAY  a burst of white drops thrown up the platform's side from the water at that point of the
##          rim (up, out, a little sideways), the strongest topping the deck's edge, falling back under
##          gravity, gone in a second or so; drawn as the tank's bubbles are (life/blob.gdshader), each
##          a small 4D ball;
##   WET    a dark patch on the deck at that point (the deck's lab grid, wet_spot uniforms), as big as
##          the hit was hard, drying over some seconds; four at most at once.
## A calm sea never reaches: nothing shows.
##
## `deck` is the deck's material; `centre` the platform's middle, `radius` its edge, `deck_y` its top.
## NO class_name (engine_gotchas.md).

const Herd := preload("res://ramon/WaterLab/shared/slice_herd_4d.gd")
const BLOB := preload("res://ramon/WaterLab/life/blob.gdshader")

var water: Node = null
var deck: TetraMaterial4D = null
var centre := Vector4.ZERO
var radius: float = 5.2
var deck_y: float = 2.8
## A hit: the water at the rim within the top (1 - share) of this sea's recent highest, rising, and
## at least floor_h over the mean; the recent highest sinks `settle` metres a second.
## (At 0.85, 0.6 and 0.04 the swell threw 32 bursts in about forty seconds, nearly every crest.)
@export var share: float = 0.9
@export var floor_h: float = 0.8
@export var settle: float = 0.02
var _recent: float = 1.0
@export var points: int = 24
@export var max_drops: int = 700

var herd: Node4D
var _drops: Array = []
var _last_h: PackedFloat32Array = PackedFloat32Array()
var _check: float = 0.0
var _cool: PackedFloat32Array = PackedFloat32Array()
var _wet: Array = []
var _rng := RandomNumberGenerator.new()
## For the test runner: bursts so far, and the highest water seen at the rim.
var bursts: int = 0
var peak: float = -100.0


func _ready() -> void:
	_rng.randomize()
	herd = Node4D.new()
	herd.name = "SprayHerd"
	herd.set_script(Herd)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 5
	herd.set("mesh", ball)
	herd.set("shader", BLOB)
	herd.set("w_radius", 1.0)
	herd.set("count", 0)
	add_child(herd)
	_last_h.resize(points)
	_cool.resize(points)
	for i in points:
		_last_h[i] = -100.0


func _rim(i: int) -> Vector4:
	var a: float = TAU * float(i) / float(points)
	return centre + Vector4(cos(a) * radius, 0.0, sin(a) * radius, 0.0)


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	_check -= dt
	if _check <= 0.0 and water != null and water.has_method("height_at"):
		_check = 0.25
		_recent = maxf(_recent - settle * 0.25, 0.0)
		var hit_at: float = maxf(floor_h, share * _recent)
		for i in points:
			_cool[i] = maxf(_cool[i] - 0.25, 0.0)
			var p: Vector4 = _rim(i)
			var h: float = float(water.call("height_at", Vector3(p.x, p.z, p.w)))
			var rising: bool = h > _last_h[i] + 0.02
			_last_h[i] = h
			peak = maxf(peak, h)
			_recent = maxf(_recent, h)
			if h > hit_at and rising and _cool[i] <= 0.0:
				var strength: float = clampf((h - floor_h) / 1.1, 0.25, 1.0)
				_cool[i] = 1.2
				bursts += 1
				_burst(p + Vector4(0.0, h, 0.0, 0.0), strength)
				# Wet only where it tops the deck.
				if strength > 0.45:
					_wet_at(p, strength)
	_step(dt)
	_dry(dt)


## A new sea (keys 1-4): its crests are judged afresh (frames of 9 Oct: the storm, coming after the
## swell's higher crests at the rim, threw nothing in its first ten seconds).
func new_sea() -> void:
	_recent = floor_h


## A burst of drops from the water at rim point `p`, thrown up the side: the strongest clear the deck.
func _burst(p: Vector4, strength: float) -> void:
	var out: Vector4 = (p - centre)
	out.y = 0.0
	out = out.normalized()
	# (Frames of 9 Oct: 18-46 drops of 3-9 cm were specks from the deck; then 30-70 of 7-17 cm, thrown
	# from one point, read as a clump of bubbles at the rail. Now a sheet: spread two metres along the
	# rim, fanned in and out, the hardest thrown well over the deck.)
	var n: int = int(lerpf(50.0, 120.0, strength))
	for k in n:
		if _drops.size() >= max_drops:
			break
		var along := Vector4(-out.z, 0.0, out.x, 0.0)
		var spread: float = _rng.randf_range(-1.0, 1.0)
		# Up: enough to climb from the water to the deck's edge and up to a metre and a half over.
		var climb: float = maxf(deck_y - p.y, 0.5) + 1.5 * strength
		var up: float = sqrt(2.0 * 9.8 * climb) * _rng.randf_range(0.5, 1.05) * (0.7 + 0.3 * strength)
		# Fanned: most thrown in over the deck (the wave's push), some back out to sea, a little along.
		var v: Vector4 = out * _rng.randf_range(-2.4, 0.9) + along * (spread * 0.9) + Vector4(0.0, up, 0.0, _rng.randf_range(-0.3, 0.3))
		_drops.append({"p": p + out * 0.2 + along * (spread * 1.1), "v": v, "life": _rng.randf_range(0.9, 1.7), "r": _rng.randf_range(0.04, 0.12)})


func _step(dt: float) -> void:
	var i: int = _drops.size() - 1
	while i >= 0:
		var d: Dictionary = _drops[i]
		d["life"] = float(d["life"]) - dt
		var v: Vector4 = d["v"]
		v.y -= 9.8 * dt
		v *= 1.0 - 0.6 * dt
		d["v"] = v
		d["p"] = (d["p"] as Vector4) + v * dt
		if float(d["life"]) <= 0.0:
			_drops.remove_at(i)
		i -= 1
	if herd == null:
		return
	if int(herd.get("count")) != _drops.size():
		herd.call("set_count", _drops.size())
	for k in _drops.size():
		var d2: Dictionary = _drops[k]
		var fade: float = clampf(float(d2["life"]) / 0.3, 0.0, 1.0)
		herd.call("write", k, global_basis.inverse() * ((d2["p"] as Vector4) - global_position), Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0),
			Color(0.92, 0.96, 0.98, 1.0), Vector4(float(d2["r"]) * fade, 0.6, 1.0, 0.0))
	herd.call("upload")


## A wet patch at `p` on the deck, the newest replacing the oldest of four.
func _wet_at(p: Vector4, strength: float) -> void:
	var at: Vector4 = centre + (p - centre) * 0.86
	_wet.append({"x": at.x, "z": at.z, "r": lerpf(0.9, 1.8, strength), "a": 1.0})
	while _wet.size() > 4:
		_wet.pop_front()


func _dry(dt: float) -> void:
	if deck == null:
		return
	var cs: ShaderMaterial = deck.get_cross_section_material_3d()
	for k in 4:
		var v := Vector4(0, 0, 0, 0)
		if k < _wet.size():
			var w: Dictionary = _wet[k]
			w["a"] = maxf(float(w["a"]) - dt / 7.0, 0.0)
			v = Vector4(float(w["x"]), float(w["z"]), float(w["r"]), float(w["a"]))
		cs.set_shader_parameter("wet%d" % k, v)
