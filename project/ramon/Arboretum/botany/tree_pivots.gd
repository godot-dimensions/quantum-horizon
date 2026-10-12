extends RefCounted

## The Arboretum: a skeleton's branches packed for the shaders, and a fast "which branch is this
## point on" for meshes that do not know (the engine's dual-contoured surface).
##
##   texture(sk)       a float texture, 4 texels a branch, one row each, as botany_bark.gdshader and
##                     botany_leaf.gdshader read it:
##                       (0, b)  its base, the pivot it swings about (x, y, z, w)
##                       (1, b)  its direction, base to tip (unit)
##                       (2, b)  its parent + 1 (0 for the trunk), its flexibility, phase, frequency (Hz)
##                       (3, b)  its length, where it joins its parent (0 to 1), its order
##   Index.new(sk)     a hash grid of every branch segment; nearest(p) -> [branch, along]
##   uvw(material, branch, along)   the texture coordinate every tree mesh carries (the shaders'
##                     convention: material / 255, (branch + 0.5) / 1024, along)
##
## NO class_name (engine_gotchas.md): preload it.

const MAX_BRANCHES := 1024


static func uvw(material: int, branch: int, along: float) -> Vector3:
	return Vector3(float(material) / 255.0, (float(clampi(branch, 0, MAX_BRANCHES - 1)) + 0.5) / float(MAX_BRANCHES), clampf(along, 0.0, 1.0))


static func image(sk: Resource) -> Image:
	var branches: Array = sk.get("branches")
	var n: int = branches.size()
	var img := Image.create_empty(4, maxi(n, 1), false, Image.FORMAT_RGBAF)
	for bi in n:
		var b: Dictionary = branches[bi]
		var pts: PackedVector4Array = sk.call("branch_points", bi)
		var base: Vector4 = pts[0]
		var tip: Vector4 = pts[pts.size() - 1]
		var dir: Vector4 = tip - base
		dir = dir.normalized() if dir.length() > 0.0001 else Vector4(0, 1, 0, 0)
		img.set_pixel(0, bi, Color(base.x, base.y, base.z, base.w))
		img.set_pixel(1, bi, Color(dir.x, dir.y, dir.z, dir.w))
		img.set_pixel(2, bi, Color(float(int(b["parent"]) + 1), float(b.get("flex", 0.3)), float(b.get("phase", 0.0)), float(b.get("freq", 0.5))))
		img.set_pixel(3, bi, Color(float(b.get("length", 1.0)), float(b.get("attach", 0.0)), float(b.get("order", 0)), 0.0))
	return img


static func texture(sk: Resource) -> ImageTexture:
	return ImageTexture.create_from_image(image(sk))


## A hash grid over every segment of every branch, for many nearest-branch questions at once.
class Index:
	var _sk: Resource
	var _cell: float
	var _grid: Dictionary = {}
	## Segments: [a, b, branch, along_a, along_b].
	var _segs: Array = []

	func _init(sk: Resource, cell: float = 0.5) -> void:
		_sk = sk
		_cell = cell
		var positions: PackedVector4Array = sk.get("positions")
		var node_along: PackedFloat32Array = sk.get("node_along")
		var branches: Array = sk.get("branches")
		var radii: PackedFloat32Array = sk.get("radii")
		for bi in branches.size():
			var nodes: PackedInt32Array = branches[bi]["nodes"]
			var child: bool = int(branches[bi]["parent"]) >= 0
			for k in range(1, nodes.size()):
				var a: Vector4 = positions[nodes[k - 1]]
				var c: Vector4 = positions[nodes[k]]
				var ta: float = 0.0 if (k == 1 and child) else node_along[nodes[k - 1]]
				var tb: float = node_along[nodes[k]]
				var s: int = _segs.size()
				_segs.append([a, c, bi, ta, tb])
				# A surface point lies about a radius from its branch (a leaf ball's radius at a twig,
				# plus up to half a cell where a grid builder placed it): reach that far, no further,
				# so a cell holds few segments.
				var grow: float = maxf(radii[nodes[k - 1]], 0.25) + 0.12
				var lo: Vector4i = _key(a.min(c) - Vector4(grow, grow, grow, grow))
				var hi: Vector4i = _key(a.max(c) + Vector4(grow, grow, grow, grow))
				for x in range(lo.x, hi.x + 1):
					for y in range(lo.y, hi.y + 1):
						for z in range(lo.z, hi.z + 1):
							for w in range(lo.w, hi.w + 1):
								var key := Vector4i(x, y, z, w)
								var list: PackedInt32Array = _grid.get(key, PackedInt32Array())
								list.append(s)
								_grid[key] = list

	func _key(p: Vector4) -> Vector4i:
		return Vector4i(floori(p.x / _cell), floori(p.y / _cell), floori(p.z / _cell), floori(p.w / _cell))

	## [branch, along] of the nearest segment to `p`.
	func nearest(p: Vector4) -> Array:
		var cand: PackedInt32Array = _grid.get(_key(p), PackedInt32Array())
		if cand.is_empty():
			cand = PackedInt32Array(range(_segs.size()))
		var best: float = INF
		var out: Array = [0, 0.0]
		for s in cand:
			var seg: Array = _segs[s]
			var a: Vector4 = seg[0]
			var ab: Vector4 = (seg[1] as Vector4) - a
			var l2: float = ab.length_squared()
			var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
			var d: float = p.distance_squared_to(a + ab * t)
			if d < best:
				best = d
				out = [int(seg[2]), lerpf(float(seg[3]), float(seg[4]), t)]
		return out
