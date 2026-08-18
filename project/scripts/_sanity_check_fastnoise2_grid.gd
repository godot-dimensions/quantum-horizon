extends Node
## Verifies Math4D.fastnoise2_4d_grid()'s axis-remap against
## Math4D.fastnoise2_4d() (GenSingle4D, no remap) directly. The grid
## function takes arguments in THIS codebase's own (x,y,z,w) role naming
## and internally remaps them to FastNoise2's native (x,y,z,w) parameter
## slots so the OUTPUT flat-index matches _read_density's convention
## (w innermost) - see the comment in math_4d.cpp. That means a scalar
## fastnoise2_4d() call reproducing one grid point must ALSO apply the
## remap to its own arguments: FN2's x-slot <- our w, y-slot <- our z,
## z-slot <- our y, w-slot <- our x.
func _ready() -> void:
	var n := 4
	var x0 := 0.0
	var y0 := 0.3
	var z0 := 0.5
	var w0 := 0.7
	var step_x := 0.11
	var step_y := 0.13
	var step_z := 0.17
	var step_w := 0.19
	var arr: PackedFloat64Array = Math4D.fastnoise2_4d_grid(1, x0, y0, z0, w0, step_x, step_y, step_z, step_w, n)
	print("size=%d (expect %d)" % [arr.size(), n * n * n * n])

	var all_finite := true
	for v in arr:
		if not is_finite(v):
			all_finite = false
	print("all_finite=%s" % [all_finite])

	# flat index 0: (i=0,j=0,k=0,l=0) -> our (x0,y0,z0,w0).
	var expect0 := Math4D.fastnoise2_4d(1, w0, z0, y0, x0)
	print("index0: grid=%.6f expect=%.6f match=%s" % [arr[0], expect0, is_equal_approx(arr[0], expect0)])

	# flat index 1: (i=0,j=0,k=0,l=1) -> our w advances one step.
	var idx1 := 1
	var expect1 := Math4D.fastnoise2_4d(1, w0 + step_w, z0, y0, x0)
	print("index1(w+step): grid=%.6f expect=%.6f match=%s" % [arr[idx1], expect1, is_equal_approx(arr[idx1], expect1)])

	# flat index n: (i=0,j=0,k=1,l=0) -> our z advances one step.
	var idxN := n
	var expectN := Math4D.fastnoise2_4d(1, w0, z0 + step_z, y0, x0)
	print("indexN(z+step): grid=%.6f expect=%.6f match=%s" % [arr[idxN], expectN, is_equal_approx(arr[idxN], expectN)])

	# flat index n*n: (i=0,j=1,k=0,l=0) -> our y advances one step.
	var idxNN := n * n
	var expectNN := Math4D.fastnoise2_4d(1, w0, z0, y0 + step_y, x0)
	print("indexNN(y+step): grid=%.6f expect=%.6f match=%s" % [arr[idxNN], expectNN, is_equal_approx(arr[idxNN], expectNN)])

	# flat index n*n*n: (i=1,j=0,k=0,l=0) -> our x advances one step.
	var idxNNN := n * n * n
	var expectNNN := Math4D.fastnoise2_4d(1, w0, z0, y0, x0 + step_x)
	print("indexNNN(x+step): grid=%.6f expect=%.6f match=%s" % [arr[idxNNN], expectNNN, is_equal_approx(arr[idxNNN], expectNNN)])

	# A middle index touching all four axes at once: (i=2,j=1,k=3,l=2).
	var i := 2
	var j := 1
	var k := 3
	var l := 2
	var idxMixed := ((i * n + j) * n + k) * n + l
	var expectMixed := Math4D.fastnoise2_4d(1, w0 + l * step_w, z0 + k * step_z, y0 + j * step_y, x0 + i * step_x)
	print("indexMixed: grid=%.6f expect=%.6f match=%s" % [arr[idxMixed], expectMixed, is_equal_approx(arr[idxMixed], expectMixed)])

	print("DONE")
	get_tree().quit()
