extends RefCounted
## The wave sets, and the Wave they are made of. Data only.
##
## SEPARATE FROM water4d_surface.gd ON PURPOSE. The surface node is wrapped in QHProfiler
## scopes, and QHProfiler is an autoload, which is not declared when Godot is run with
## `--script` - so anything that preloads the surface fails to compile in exactly the place
## a probe wants to run. Keeping the numbers here lets _probe_jacobian_runner.gd read the
## real presets instead of a second copy that would drift away from them.
##
## Throughout, a `Vector3` named dir or h is (x, z, w) - NOT (x, y, z). Gravity is along y,
## so horizontal space here is three-dimensional and a wave vector is a 3-vector in it.
##
## HOW SHARP A PRESET LOOKS is set by sum(Q k A) over its waves, not by any one of them.
## water4d_surface.gd clamps that sum to 1 every frame - past it the horizontal map folds
## through itself - so a preset that wants cusped crests has to spend the whole budget on a
## few aligned waves rather than spreading it thin over eight. That is the only real
## difference between "Sharp crests" and "Storm" here.

const MAX_WAVES := 8


## One wave: a direction in (x, z, w) - NOT (x, y, z) - with its amplitude, wavelength and
## Gerstner steepness.
class Wave:
	var dir: Vector3
	var amplitude: float
	var wavelength: float
	var steepness: float

	func _init(d: Vector3, a: float, l: float, q: float) -> void:
		dir = d.normalized() if d.length() > 0.0001 else Vector3(1.0, 0.0, 0.0)
		amplitude = a
		wavelength = maxf(l, 0.1)
		steepness = q


## Directions spread around a mean by `spread` radians, walked around the cone so successive
## waves do not stack up on one side. In three horizontal dimensions the spread is over a
## patch of the sphere rather than an arc, which is the whole reason a 4D sea looks busier
## than a 3D one at the same wave count.
static func _spread(mean: Vector3, spread: float, index: int, total: int) -> Vector3:
	if total <= 1 or spread <= 0.0:
		return mean.normalized()
	var m := mean.normalized()
	# Any two vectors perpendicular to the mean.
	var seed := Vector3(0.0, 0.0, 1.0) if absf(m.z) < 0.9 else Vector3(1.0, 0.0, 0.0)
	var u := m.cross(seed).normalized()
	var v := m.cross(u).normalized()
	# Golden-angle walk so a handful of waves land evenly rather than in a line.
	var angle := float(index) * 2.39996
	var t := (float(index) / float(total - 1)) * 2.0 - 1.0
	var off := (u * cos(angle) + v * sin(angle)) * (spread * t)
	return (m + off).normalized()


## One train of waves: `count` of them around `mean`, with amplitude and wavelength both
## falling off geometrically, which is what a single wind system actually looks like.
static func _train(into: Array[Wave], mean: Vector3, spread: float, count: int,
		amplitude: float, wavelength: float, falloff: float, steepness: float) -> void:
	for i in range(count):
		var k := pow(falloff, float(i))
		into.append(Wave.new(_spread(mean, spread, i, count),
				amplitude * k, wavelength * k, steepness))


static func _preset(index: int) -> Array[Wave]:
	var waves: Array[Wave] = []
	match index:
		0: # Calm: long low swells, nearly in line, nearly all in-slice.
			_train(waves, Vector3(1.0, 0.25, 0.08), 0.18, 3, 0.55, 70.0, 0.68, 0.45)
		1: # Moderate swell: a wind direction with real spread over the sphere.
			_train(waves, Vector3(0.85, 0.45, 0.28), 0.55, 5, 0.62, 31.0, 0.80, 0.75)
		2: # Storm: short next to their height, steep, crests that pinch and foam.
			_train(waves, Vector3(0.7, 0.6, 0.38), 0.42, 7, 1.30, 26.0, 0.86, 1.0)
		3: # Off-slice swell: the dominant train runs almost entirely along W.
			# THE 4D SHOWCASE. Its wave vectors are nearly perpendicular to the slice, so
			# from the default view the surface mostly heaves in place - crests arriving from
			# a direction you cannot see. Turn the slice and it becomes an ordinary swell.
			_train(waves, Vector3(0.06, 0.04, 1.0), 0.14, 4, 1.05, 44.0, 0.80, 0.80)
			# One small in-slice wave so the surface is not completely featureless before you
			# turn: without it the preset reads as "broken" rather than "4D".
			waves.append(Wave.new(Vector3(1.0, 0.3, 0.0), 0.11, 17.0, 0.40))
		4: # Short chop: brief wavelengths thrown wide.
			_train(waves, Vector3(0.5, 0.8, 0.5), 0.85, MAX_WAVES, 0.21, 7.0, 0.88, 0.95)
		5: # Wind sea over swell: TWO SYSTEMS, differing in direction AND in frequency.
			# A real sea is almost never one train. An old swell has travelled in from a
			# storm somewhere else - long, low, smooth, and pointing wherever that storm was
			# - and today's wind piles short steep chop on top of it from a different
			# quarter. The two do not interact here, they simply sum, which is what linear
			# wave theory says to do and what the eye reads as "weather".
			#
			# The 4D twist: the swell is almost entirely in-slice while the wind sea carries
			# a real W component, so turning the slice changes the chop without touching the
			# swell underneath it. That separation is the thing to watch.
			_train(waves, Vector3(1.0, 0.18, 0.05), 0.12, 3, 0.95, 78.0, 0.72, 0.35)
			_train(waves, Vector3(-0.35, 0.86, 0.55), 0.75, 5, 0.30, 11.0, 0.84, 0.95)
		6: # Sharp crests: the whole steepness budget on a few aligned waves.
			# At sum(Q k A) = 1 a Gerstner wave is a cusped trochoid - the crest comes to a
			# point and the troughs flatten out. Three waves nearly in line reach it; eight
			# spread over the sphere never can, because the clamp divides the same budget
			# between them. Acute peaks, and the Jacobian dips hard enough that the foam sits
			# right on the points.
			_train(waves, Vector3(0.92, 0.34, 0.20), 0.10, 3, 1.15, 19.0, 0.78, 1.0)
		_: # Crossing seas: two swells of the same size meeting at a wide angle, one of them
			# travelling through W. Where they cross they make the short-lived pyramid peaks
			# a real crossing sea does, and in 4D the pattern reorganises as you turn the
			# slice, because only one of the two trains is in it.
			_train(waves, Vector3(1.0, 0.25, 0.0), 0.16, 3, 0.80, 34.0, 0.80, 0.70)
			_train(waves, Vector3(0.0, 0.30, 1.0), 0.16, 3, 0.80, 29.0, 0.80, 0.70)
	# Pad to a fixed eight so a blend is a straight lerp of every slot and the shader's loop
	# bound never has to change mid-blend.
	while waves.size() < MAX_WAVES:
		waves.append(Wave.new(Vector3(1.0, 0.0, 0.0), 0.0, 10.0, 0.0))
	return waves


static func count() -> int:
	return 8


static func preset_name(index: int) -> String:
	match index:
		0: return "Calm"
		1: return "Moderate swell"
		2: return "Storm"
		3: return "Off-slice swell"
		4: return "Short chop"
		5: return "Wind sea over swell"
		6: return "Sharp crests"
		_: return "Crossing seas"
