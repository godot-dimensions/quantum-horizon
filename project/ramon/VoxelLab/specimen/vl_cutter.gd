extends RefCounted

## The Voxel Lab's four tools, as the bench and the story use them: from where the mouse's ray meets
## the specimen (vl_recipe.gd raycast, in the specimen's voxels) to a cut (vl_cut.gd). Sizes are in
## VOXELS, so a tool takes the same bite on every specimen, whatever its voxel size (a ball of 13 cm
## was a voxel and a bit on the 10 cm block and would vanish on a 12 cm one).
##
##   ball    a crater: a 4D ball sunk a third of its radius into the surface
##   block   a square notch: a 4D box, the specimen's own way up, sunk into the surface
##   drill   a tunnel along your view, from just outside the surface, as deep as its size
##   saw     a channel between where you pressed and where you let go, a blade's width wide, cut to
##           its depth and right through the specimen in W
##
## NO class_name (engine_gotchas.md).

const Cut := preload("res://ramon/VoxelLab/specimen/vl_cut.gd")

const TOOLS := ["ball", "block", "drill", "saw"]
const NAMES := {"ball": "Ball", "block": "Block", "drill": "Drill", "saw": "Saw"}
const LINES := {
	"ball": "A crater. A 4D ball: slide through W and its hole shrinks.",
	"block": "A square notch. A 4D box: the same through W, then it stops.",
	"drill": "A tunnel along your view. A tube in 4D.",
	"saw": "Press, drag, let go: a clean channel, right through W.",
}
## Small, medium, large, in voxels: the ball's and the drill's radius, the block's half size, the saw's
## depth.
const SIZES := {
	"ball": [1.3, 2.2, 3.4],
	"block": [1.0, 1.7, 2.6],
	"drill": [0.9, 1.2, 1.7],
	"saw": [2.5, 4.5, 7.0],
}
const SIZE_NAMES := ["S", "M", "L"]
## The drill's depth for each size (voxels), and the saw's blade (a voxel and a bit: thinner vanishes).
const DRILL_DEPTH := [6.0, 10.0, 15.0]
const SAW_KERF_VOXELS := 1.35


## A cut of `tool` at size `size` (0 to 2), where the ray met the surface: `hit` and `normal` (voxels),
## the ray's direction `ray` (voxels), and `w_dir` the slice's W direction in the specimen's voxels.
## For the saw, `hit2` is where the drag ended. `voxel` is the specimen's voxel size (m).
static func make(tool: String, size: int, hit: Vector4, normal: Vector4, ray: Vector4, w_dir: Vector4, voxel: float, hit2: Vector4 = Vector4.INF, w_extent: float = 40.0) -> Dictionary:
	var s: float = float((SIZES[tool] as Array)[clampi(size, 0, 2)])
	var n: Vector4 = normal.normalized() if normal.length() > 0.0 else -ray.normalized()
	var cut: Dictionary
	match tool:
		"ball":
			cut = Cut.ball(hit - n * s * 0.35, s)
		"block":
			cut = Cut.block(hit - n * s * 0.55, Vector4.ONE * s)
		"drill":
			var d: Vector4 = ray.normalized()
			var depth: float = float(DRILL_DEPTH[clampi(size, 0, 2)])
			cut = Cut.drill(hit - d * s * 0.6, d, s, depth + s * 0.6)
		"saw":
			var b: Vector4 = hit2 if hit2 != Vector4.INF else hit + perp(n, w_dir, Vector4(0, 1, 0, 0)) * s
			var along: Vector4 = b - hit
			if along.length() < 0.5:
				along = perp(n, w_dir, Vector4(1, 0, 0, 0)) * 0.5
				b = hit + along
			var kerf_dir: Vector4 = perp(along, n, w_dir)
			cut = Cut.saw(hit, b, kerf_dir, SAW_KERF_VOXELS, -n, s, w_dir, w_extent)
	cut["tool"] = tool
	cut["size"] = size
	cut["label"] = "%s %s" % [NAMES[tool], SIZE_NAMES[clampi(size, 0, 2)]]
	return cut


## A unit vector at right angles to `a` and `b` (and `c` if it is not zero): the rest of 4D after them,
## by Gram-Schmidt over the four axes, keeping the first that survives.
static func perp(a: Vector4, b: Vector4, c: Vector4 = Vector4.ZERO) -> Vector4:
	var basis: Array = []
	for v in [a, b, c]:
		var u: Vector4 = v
		for e in basis:
			u -= (e as Vector4) * u.dot(e)
		if u.length() > 1e-5:
			basis.append(u.normalized())
	for axis in 4:
		var u := Vector4.ZERO
		u[axis] = 1.0
		for e in basis:
			u -= (e as Vector4) * u.dot(e)
		if u.length() > 1e-3:
			return u.normalized()
	return Vector4(1, 0, 0, 0)
