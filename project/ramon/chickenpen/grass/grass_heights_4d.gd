extends RefCounted

## THE GROUND'S HEIGHT FOR THE GRASS (Ramon, 7 Oct: "grass on hill is a different green"). The grass
## grew only on the flat field, at y 0, and every hill was bare, so a hill showed its baked turf, the
## main green (an olive, #4d4f1d) lit warm by the sky, beside a meadow of cool green blades. Now the
## blades stand on the hills too: each blade's root is lifted to the ground's height where it stands.
##
## THE HILLS HAVE NO COLLIDER (lookout/lookout_ground_4d.gd says so too): they are baked 4D meshes
## drawn over the flat ground's box, so the height comes from the meshes themselves. A mesh is the 3D
## boundary of a 4D solid, made of tetrahedra; seen from above, along y, each tetrahedron covers a
## small solid of (x, z, W), and over it its own y is linear. So for every point of a grid in (x, z, W)
## the ground's height is the highest y of any upward-facing tetrahedron over it (the hill's top skin,
## not the floor of the cave's tunnel under it). That is slow in GDScript (tens of seconds over the
## mountains' shell), so it is baked: _bake_grass_heights_runner.gd writes BAKED, and the grass reads
## it into a 3D texture at the start.
##
## WHERE: the grass's own grid in x and z (half a metre, 240 cells a side round the field's middle) and
## a layer a metre apart in W from W0, LAYERS of them, which covers the farm, the camp (2.5 kata), the
## cave (4 ana) and the marsh (8 ana). Outside the layers the nearest is used.
##
## STALE IS MENDED: what the bake was made from (each terrain piece's name and place) is kept with it; if a
## hill has been moved since, or there is no bake, the grass makes the heights itself as it starts (about
## half a second, measured 7 Oct) and the panel says to bake them again.
##
## No class_name (engine_gotchas.md).

const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")
const BAKED := "res://ramon/chickenpen/grass/baked/grass_heights.res"
const CELL := 0.5
const CELLS := 240
const W0 := -8.0
const DW := 1.0
const LAYERS := 19
## Where no tetrahedron lies over a point: the flat ground.
const NONE := -100.0
## The terrain: the mountains, the round hills, the mounds, under World; and the cave's hill.
const PIECES := ["World/Hills", "World/WestHill", "World/TowerHill", "World/MoundA", "World/MoundB", "World/MoundC",
	"World/MoundD", "World/MoundE", "World/Cave/CaveHill"]


## The terrain's meshes under [param room], every MeshInstance4D in each piece.
static func meshes(room: Node) -> Array:
	var out: Array = []
	for path in PIECES:
		var piece: Node = room.get_node_or_null(path)
		if piece == null:
			continue
		var all: Array = [piece] if piece is MeshInstance4D else []
		all.append_array(piece.find_children("*", "MeshInstance4D", true, false))
		for mi in all:
			if Look.own_mesh(mi as MeshInstance4D) is TetraMesh4D:
				out.append(mi)
	return out


## What the heights are made from, as text: each piece's name and place.
static func signature(room: Node) -> String:
	var parts := PackedStringArray()
	for path in PIECES:
		var piece := room.get_node_or_null(path) as Node4D
		if piece == null:
			continue
		var p: Vector4 = piece.global_position
		var b: Projection = piece.global_basis
		parts.append("%s %.2f,%.2f,%.2f,%.2f %.3f,%.3f,%.3f" % [path, p.x, p.y, p.z, p.w, b.x.x, b.x.z, b.z.x])
	return " | ".join(parts)


## The heights over the grid, every layer: an Image CELLS wide and CELLS * LAYERS tall (layer k's rows
## from k * CELLS), one float a texel, NONE where only the flat ground is.
static func bake(room: Node) -> Image:
	var heights := PackedFloat32Array()
	heights.resize(CELLS * CELLS * LAYERS)
	heights.fill(NONE)
	var half: float = CELL * CELLS * 0.5
	var tops: int = 0
	for mi: MeshInstance4D in meshes(room):
		var mesh: TetraMesh4D = Look.own_mesh(mi) as TetraMesh4D
		var verts: PackedVector4Array = mesh.get_simplex_cell_positions()
		var normals: PackedVector4Array = mesh.get_simplex_cell_boundary_normals()
		var b: Projection = mi.global_basis
		var o: Vector4 = mi.global_position
		var k: int = 0
		var cell: int = 0
		while k + 3 < verts.size():
			var a: Vector4 = b * verts[k] + o
			var bb: Vector4 = b * verts[k + 1] + o
			var c: Vector4 = b * verts[k + 2] + o
			var d: Vector4 = b * verts[k + 3] + o
			k += 4
			if cell < normals.size():
				var n: Vector4 = (b * normals[cell]).normalized()
				cell += 1
				if n.y < 0.05:
					continue
			else:
				cell += 1
			if maxf(maxf(a.y, bb.y), maxf(c.y, d.y)) < 0.02:
				continue
			var p0 := Vector3(a.x, a.z, a.w)
			var m := Basis(Vector3(bb.x, bb.z, bb.w) - p0, Vector3(c.x, c.z, c.w) - p0, Vector3(d.x, d.z, d.w) - p0)
			var det: float = m.determinant()
			if absf(det) < 1e-7:
				continue
			var inv: Basis = m.inverse()
			var lo := Vector3(minf(minf(a.x, bb.x), minf(c.x, d.x)), minf(minf(a.z, bb.z), minf(c.z, d.z)), minf(minf(a.w, bb.w), minf(c.w, d.w)))
			var hi := Vector3(maxf(maxf(a.x, bb.x), maxf(c.x, d.x)), maxf(maxf(a.z, bb.z), maxf(c.z, d.z)), maxf(maxf(a.w, bb.w), maxf(c.w, d.w)))
			var i0: int = maxi(int(ceil((lo.x + half) / CELL - 0.5)), 0)
			var i1: int = mini(int(floor((hi.x + half) / CELL - 0.5)), CELLS - 1)
			var j0: int = maxi(int(ceil((lo.y + half) / CELL - 0.5)), 0)
			var j1: int = mini(int(floor((hi.y + half) / CELL - 0.5)), CELLS - 1)
			var l0: int = maxi(int(ceil((lo.z - W0) / DW)), 0)
			var l1: int = mini(int(floor((hi.z - W0) / DW)), LAYERS - 1)
			for l in range(l0, l1 + 1):
				var w: float = W0 + float(l) * DW
				for j in range(j0, j1 + 1):
					var z: float = -half + (float(j) + 0.5) * CELL
					for i in range(i0, i1 + 1):
						var x: float = -half + (float(i) + 0.5) * CELL
						var bary: Vector3 = inv * (Vector3(x, z, w) - p0)
						var first: float = 1.0 - bary.x - bary.y - bary.z
						if bary.x < -1e-4 or bary.y < -1e-4 or bary.z < -1e-4 or first < -1e-4:
							continue
						var y: float = a.y * first + bb.y * bary.x + c.y * bary.y + d.y * bary.z
						var at: int = (l * CELLS + j) * CELLS + i
						if y > heights[at]:
							heights[at] = y
							tops += 1
	# The flat ground where no hill is: 0, never NONE, or the texture's filtering would pull the edge of
	# every hill down toward -100.
	for at in heights.size():
		if heights[at] < 0.0:
			heights[at] = 0.0
	var image := Image.create_from_data(CELLS, CELLS * LAYERS, false, Image.FORMAT_RF, heights.to_byte_array())
	image.set_meta(&"signature", signature(room))
	image.set_meta(&"tops", tops)
	return image


## The baked heights as a 3D texture for the grass, if they were made from the terrain as it stands:
## {"tex", "stale": false}; {"stale": true, "why"} when a piece has moved; {} when there is no bake.
static func load_for(room: Node) -> Dictionary:
	if not ResourceLoader.exists(BAKED):
		return {}
	var image := load(BAKED) as Image
	if image == null:
		return {}
	var was: String = String(image.get_meta(&"signature", ""))
	var now: String = signature(room)
	if was != now:
		return {"stale": true, "why": "the terrain has moved since the grass heights were baked"}
	return {"tex": texture_from(image), "stale": false}


## [param image] (as bake makes it) as the 3D texture the grass reads.
static func texture_from(image: Image) -> ImageTexture3D:
	var layers: Array[Image] = []
	for l in LAYERS:
		var layer: Image = image.get_region(Rect2i(0, l * CELLS, CELLS, CELLS))
		layer.convert(Image.FORMAT_RF)
		layers.append(layer)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RF, CELLS, CELLS, LAYERS, false, layers)
	return tex
