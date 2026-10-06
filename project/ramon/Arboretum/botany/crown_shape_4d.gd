extends "res://ramon/Arboretum/carried/shrubbery/attractor_shape_4d.gd"

## The Arboretum: a crown envelope for the space colonization (carried/shrubbery/), a 4D ellipsoid
## cut flat underneath, with points denser toward its skin (Runions et al.: a tree is densest at the
## crown's surface, where the light is). The oak's crown is wider than it is tall and starts low; its
## W depth is its own number, so the tree is round through W or flatter, as wanted.
##
## NO class_name (engine_gotchas.md): preload it.

var center: Vector4
var radii: Vector4
## Nothing below this height (the crown's flat underside), in the tree's own space.
var floor_y: float
## 0: points spread evenly through the crown; 1: all near its skin.
var skin_bias: float
var _rng := RandomNumberGenerator.new()


func _init(p_center: Vector4, p_radii: Vector4, p_floor_y: float = -INF, p_skin_bias: float = 0.4, seed: int = 1) -> void:
	center = p_center
	radii = p_radii
	floor_y = p_floor_y
	skin_bias = p_skin_bias
	_rng.seed = seed


func get_bounds() -> Dictionary:
	var lo: Vector4 = center - radii
	lo.y = maxf(lo.y, floor_y)
	return {"min": lo, "max": center + radii}


func contains(point: Vector4) -> bool:
	if point.y < floor_y:
		return false
	var d: Vector4 = (point - center) / radii
	var r2: float = d.length_squared()
	if r2 > 1.0:
		return false
	# Denser toward the skin: an inner point is kept with a chance that falls toward the middle.
	if skin_bias > 0.0:
		var keep: float = lerpf(1.0, sqrt(r2), skin_bias)
		return _rng.randf() < keep
	return true
