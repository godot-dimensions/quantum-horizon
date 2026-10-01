extends RefCounted

## How high the field's ground is at a point, for placing the lookout's pieces - the tower's
## feet, the marsh, a balloon that must not graze a hill.
##
## THE HILLS HAVE NO COLLIDER. The pen's only ground collider is the flat box at y 0; the
## hills and the cave hill are baked 4D meshes drawn on top of it. So height comes from the
## meshes' own vertices: a grid of cells over (x, z) near a chosen w, each holding the
## highest vertex that falls in it. Built once (one pass over the vertices); then a lookup
## is a few array reads. Preloaded by path, no class_name, like the rest of the pen.

const CELL := 2.0
const SPAN := 220.0

var _cells: int = 0
var _heights := PackedFloat32Array()
var _w: float = 0.0


## The ground near w [param w], from the meshes at [param paths] under [param room].
static func build(room: Node, w: float = 0.0, w_band: float = 2.5,
		paths: PackedStringArray = PackedStringArray(["World/Hills", "World/CaveHill"])) -> RefCounted:
	var ground: RefCounted = load("res://ramon/chickenpen/lookout/lookout_ground_4d.gd").new()
	ground.call("_build", room, w, w_band, paths)
	return ground


func _build(room: Node, w: float, w_band: float, paths: PackedStringArray) -> void:
	_w = w
	_cells = int(SPAN * 2.0 / CELL)
	_heights.resize(_cells * _cells)
	_heights.fill(0.0)
	for path in paths:
		var hill := room.get_node_or_null(path) as MeshInstance4D
		if hill == null or not (hill.mesh is ArrayTetraMesh4D):
			continue
		var basis: Projection = hill.global_basis
		var origin: Vector4 = hill.global_position
		for v in (hill.mesh as ArrayTetraMesh4D).get_vertex_positions():
			var p: Vector4 = basis * v + origin
			if absf(p.w - w) > w_band:
				continue
			var k: int = _index(p.x, p.z)
			if k >= 0 and p.y > _heights[k]:
				_heights[k] = p.y


func _index(x: float, z: float) -> int:
	var cx: int = int((x + SPAN) / CELL)
	var cz: int = int((z + SPAN) / CELL)
	if cx < 0 or cz < 0 or cx >= _cells or cz >= _cells:
		return -1
	return cz * _cells + cx


## The highest ground in the cell under (x, z) and its eight neighbours - a little high on
## a slope, which is the safe side for feet and balloons.
func height(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var cx: int = int((x + SPAN) / CELL)
	var cz: int = int((z + SPAN) / CELL)
	var top: float = 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var gx: int = cx + dx
			var gz: int = cz + dz
			if gx >= 0 and gz >= 0 and gx < _cells and gz < _cells:
				top = maxf(top, _heights[gz * _cells + gx])
	return top


## The lowest of the cell and its neighbours: where a foot would actually touch.
func floor_at(x: float, z: float) -> float:
	var k: int = _index(x, z)
	return _heights[k] if k >= 0 else 0.0
