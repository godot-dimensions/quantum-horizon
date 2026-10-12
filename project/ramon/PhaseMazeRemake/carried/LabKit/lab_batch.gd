extends RefCounted

## Many small boxes merged into one mesh per kind, so a ring of 64 light segments is one instance,
## not 64. Every 4D instance takes five shader instance variables and a few thousand at once
## overflow the engine's buffer for them (follow_up/lab_kit.md, "Traps"); a strip of light is
## also one draw call instead of dozens.
##
##   var b := LabBatch.new()
##   b.box("path", Vector4(0.2, 0.02, 1.0, 4.0), at, basis)
##   for kind in b.kinds(): parent.add_child(b.instance(kind))   # then colour it by kind
##
## NO class_name (engine_gotchas.md): preload it.

const Mats := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_materials.gd")

var _meshes: Dictionary = {}     # kind -> ArrayTetraMesh4D


func box(kind: String, size: Vector4, at: Vector4, basis: Projection = Projection.IDENTITY) -> void:
	var piece: ArrayTetraMesh4D = Mats.box_mesh(size).to_array_tetra_mesh()
	if not _meshes.has(kind):
		_meshes[kind] = ArrayTetraMesh4D.new()
	(_meshes[kind] as ArrayTetraMesh4D).merge_with(piece, at, basis)


## A ring of `segments` boxes round the Y axis at `centre`, radius `r`, each `width` wide and
## `tall` high, `w` thick through W; `dash` below 1 leaves gaps (0.5: half lit, half gap).
func ring(kind: String, centre: Vector4, r: float, width: float, tall: float, w: float, segments: int = 64, dash: float = 1.0) -> void:
	for i in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * (float(i) + dash) / float(segments)
		var p0 := Vector4(cos(a0) * r, 0.0, sin(a0) * r, 0.0)
		var p1 := Vector4(cos(a1) * r, 0.0, sin(a1) * r, 0.0)
		box(kind, Vector4((p1 - p0).length() * (1.02 if dash >= 1.0 else 1.0), tall, width, w), centre + (p0 + p1) * 0.5,
			Basis4D.from_zx(atan2(p1.x - p0.x, p1.z - p0.z) - PI * 0.5))


## A straight dashed line from `a` to `b` on the plane, `dash` metres lit and `gap` dark.
func dashed_line(kind: String, a: Vector4, b: Vector4, width: float, tall: float, w: float, dash: float, gap: float) -> void:
	var d: Vector4 = b - a
	var length: float = Vector2(d.x, d.z).length()
	if length < 0.001:
		return
	var dir: Vector4 = d / length
	var basis: Projection = Basis4D.from_zx(atan2(dir.x, dir.z))
	var t: float = 0.0
	while t < length:
		var l: float = minf(dash, length - t)
		box(kind, Vector4(width, tall, l, w), a + dir * (t + l * 0.5), basis)
		t += dash + gap


func kinds() -> Array:
	return _meshes.keys()


## One MeshInstance4D for every box of `kind`, named after it.
func instance(kind: String) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = "Batch_" + kind
	m.mesh = _meshes[kind]
	return m
