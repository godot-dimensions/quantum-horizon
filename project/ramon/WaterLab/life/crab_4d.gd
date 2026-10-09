extends Node4D

## WATER LAB: the crab (Ramon, 9 Oct: "if you could add a walking crab that would be cool, one that
## appears in different areas of W"). An edible crab a third of a metre across, LOFTED IN 4D
## (life/crab_loft_4d.gd, round 5: its shell, jointed legs and claws rigid pieces; until 9 Oct a 3D mesh
## a shader shrank off the slice), walked here over the sand of the water's own frame (life/: x along
## the tank, y up, z to the glass, W).
##
## IT WALKS THROUGH W. The tank's floor is a 3D floor (x, z AND W), and the crab wanders all of it: by
## turns it walks onto your slice at some spot along the tank, stops there and picks at the sand with
## its claws, then walks off through W, its legs cut away first and then its shell smaller and gone,
## to come back somewhere else. Its
## body keeps facing the glass-ish way it faced; it walks sideways, as crabs do, its legs stepping
## whether the step carries it along the tank or through W.
##
## NO class_name (engine_gotchas.md).

const CrabLoft := preload("res://ramon/WaterLab/life/crab_loft_4d.gd")

@export var size: float = 0.34
@export var speed: float = 0.16
var half_extents: Vector4 = Vector4(9.2, 2.4, 1.6, 3.5)
var floor_y: float = -2.14
var obstacles: Array = []
var ground: Node = null

var crab: Node4D
var cpu_us: float = 0.0
var _p := Vector4.ZERO
var _yaw: float = 0.0
var _target := Vector4.ZERO
var _on_slice_next: bool = true
var _walking: bool = true
var _pause: float = 0.0
var _phase: float = 0.0
var _walk: float = 0.0
var _reach: float = 0.0
var _pinch: float = 0.0
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0


func _ready() -> void:
	_rng.seed = 7731
	crab = Node4D.new()
	crab.name = "Crab"
	crab.set_script(CrabLoft)
	add_child(crab)
	_p = Vector4(_rng.randf_range(-6.0, 6.0), floor_y, _rng.randf_range(0.3, 1.1), 1.6)
	_pick_target()


func _pick_target() -> void:
	var x: float = _rng.randf_range(-half_extents.x + 0.8, half_extents.x - 0.8)
	var z: float = _rng.randf_range(0.1, half_extents.z - 0.35)
	var w: float = 0.0
	if _on_slice_next:
		# Right on your slice: its legs are only a few centimetres thick through W.
		w = 0.0
	else:
		w = (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(0.9, minf(2.4, half_extents.w - 0.4))
		# Off through W it also moves along the tank, so it comes back somewhere new.
		x = clampf(_p.x + _rng.randf_range(-5.0, 5.0), -half_extents.x + 0.8, half_extents.x - 0.8)
	_target = Vector4(x, floor_y, z, w)
	_on_slice_next = not _on_slice_next


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var dt: float = minf(delta, 0.05)
	_t += dt
	if _walking:
		var to: Vector4 = _target - _p
		to.y = 0.0
		if to.length() < 0.05:
			_walking = false
			# A long stop on your slice, a short one off it.
			_pause = _rng.randf_range(6.0, 11.0) if absf(_p.w) < 0.1 else _rng.randf_range(1.0, 3.0)
		else:
			var step: Vector4 = to.normalized() * minf(speed * dt, to.length())
			_p += step
			# Turn the body so its walk along the floor is sideways (crabs face away from their way).
			var flat := Vector2(to.x, to.z)
			if flat.length() > 0.05:
				var want: float = atan2(flat.x, flat.y) + PI * 0.5
				if absf(wrapf(want - _yaw, -PI, PI)) > PI * 0.5:
					want += PI
				_yaw = lerp_angle(_yaw, want, 1.0 - exp(-0.8 * dt))
			_walk = lerpf(_walk, 1.0, 1.0 - exp(-5.0 * dt))
			_phase += TAU * 2.2 * dt
	else:
		_walk = lerpf(_walk, 0.0, 1.0 - exp(-4.0 * dt))
		_pause -= dt
		if _pause <= 0.0:
			_walking = true
			_pick_target()
	_p.y = float(ground.call("height_at", _p.x, _p.z, _p.w)) if ground != null else floor_y
	# Stopped, the claws pick at the sand and come back to the mouth.
	var picking: bool = not _walking
	_reach = lerpf(_reach, (0.5 + 0.5 * sin(_t * 2.4)) if picking else 0.0, 1.0 - exp(-4.0 * dt))
	_pinch = 0.5 + 0.5 * sin(_t * 5.0) if picking else lerpf(_pinch, 0.0, dt * 3.0)
	_draw()
	cpu_us = lerpf(cpu_us, float(Time.get_ticks_usec() - t0), 0.05)


func _draw() -> void:
	var h := Vector4(sin(_yaw), 0.0, cos(_yaw), 0.0)
	var right := Vector4(cos(_yaw), 0.0, -sin(_yaw), 0.0)
	crab.call("pose", _p, Projection(right, Vector4(0, 1, 0, 0), h, Vector4(0, 0, 0, 1)), size, _phase, _walk, _reach, _pinch, _t)


## On your (level) slice now, and where (for the panels): within its shell's half depth through W.
func on_slice() -> bool:
	return absf(_p.w) < 0.3 * size


func bench_row() -> Array:
	return ["Crab", "1", "%.3f ms" % (cpu_us / 1000.0), str(int(crab.get("meshes"))), "4D loft, jointed"]
