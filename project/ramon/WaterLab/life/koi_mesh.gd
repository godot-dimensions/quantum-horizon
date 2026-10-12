extends RefCounted

## WATER LAB: the koi's shape, one body length long (snout at z = +0.45, the tail fin's root at s = 0.8;
## +Z ahead, +X right, +Y up): its profile and where its fins and eyes sit. The lofted koi
## (life/koi_loft_4d.gd) is lofted in 4D from it. (Until round 5, 9 Oct, this file also built the 3D
## mesh a shader bent and shrank off the slice; that stand-in is gone: every animal is a 4D loft.)
##
## THE PROFILE is the koi's from above and from the side (photographs of show koi: a blunt round
## head, the back highest a third of the way along, a deep body tapering to a narrow peduncle). The
## half heights above and below the midline differ: the back is fuller than the belly.
##
## NO class_name (engine_gotchas.md).

## s, half height above the midline, half height below it, half width. Body lengths.
## (9 Oct, second pass: a fifth deeper and the back arched higher; the first read as a torpedo.)
const PROFILE := [
	[0.000, 0.000, 0.000, 0.000],
	[0.012, 0.026, 0.021, 0.016],
	[0.035, 0.047, 0.037, 0.031],
	[0.070, 0.072, 0.054, 0.048],
	[0.120, 0.099, 0.071, 0.067],
	[0.200, 0.124, 0.088, 0.077],
	[0.300, 0.142, 0.103, 0.083],
	[0.400, 0.144, 0.107, 0.082],
	[0.500, 0.131, 0.099, 0.074],
	[0.600, 0.108, 0.082, 0.060],
	[0.700, 0.077, 0.060, 0.043],
	[0.770, 0.053, 0.043, 0.027],
	[0.800, 0.048, 0.040, 0.022],
]
const SNOUT_Z := 0.45
const BODY_END := 0.8
## The midline drops a little at the snout: a koi's mouth is low on its face.
const MOUTH_DROP := 0.012

## Where the eyes sit (s, height above the midline) and their radius.
const EYE_S := 0.072
const EYE_UP := 0.020
const EYE_R := 0.0125
## The pectoral fins' root (s, height, half width) and the pelvic fins'.
const PECTORAL_ROOT := Vector3(0.205, -0.050, 0.060)
const PELVIC_ROOT := Vector3(0.455, -0.082, 0.032)


static func z_of(s: float) -> float:
	return SNOUT_Z - s


## The profile at `s`: [top, bottom, half width], a smooth curve through PROFILE.
static func at(s: float) -> Vector3:
	s = clampf(s, 0.0, BODY_END)
	var n: int = PROFILE.size()
	var i: int = 0
	while i < n - 2 and s > float(PROFILE[i + 1][0]):
		i += 1
	var out := Vector3.ZERO
	for c in 3:
		out[c] = _hermite(i, c + 1, s)
	return out


static func _hermite(i: int, c: int, s: float) -> float:
	var s0: float = PROFILE[i][0]
	var s1: float = PROFILE[i + 1][0]
	var p0: float = PROFILE[i][c]
	var p1: float = PROFILE[i + 1][c]
	var m0: float = _slope(i, c)
	var m1: float = _slope(i + 1, c)
	var h: float = s1 - s0
	var t: float = clampf((s - s0) / maxf(h, 0.00001), 0.0, 1.0)
	var t2: float = t * t
	var t3: float = t2 * t
	var v: float = (2.0 * t3 - 3.0 * t2 + 1.0) * p0 + (t3 - 2.0 * t2 + t) * h * m0 + (-2.0 * t3 + 3.0 * t2) * p1 + (t3 - t2) * h * m1
	return maxf(v, 0.0)


static func _slope(i: int, c: int) -> float:
	var n: int = PROFILE.size()
	if i == 0:
		# The snout: round, so the profile leaves it steeply.
		return (float(PROFILE[1][c]) - float(PROFILE[0][c])) / (float(PROFILE[1][0]) - float(PROFILE[0][0])) * 1.6
	if i == n - 1:
		return (float(PROFILE[n - 1][c]) - float(PROFILE[n - 2][c])) / (float(PROFILE[n - 1][0]) - float(PROFILE[n - 2][0]))
	return (float(PROFILE[i + 1][c]) - float(PROFILE[i - 1][c])) / (float(PROFILE[i + 1][0]) - float(PROFILE[i - 1][0]))


static func midline(s: float) -> float:
	return -MOUTH_DROP * (1.0 - smoothstep(0.0, 0.12, s))
