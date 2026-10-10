@tool
extends MeshInstance4D

## The wolf's eye, a 24-cell (Creature Lab round 5, 10 Oct 2026; Ramon's item 56: "the eyes ... too large or
## elongated, giving the impression that the wolf is wearing sunglasses ... smaller ... a more rounded or semi-rounded
## shape ... consider using 24-cell geometry ... integrated into the face"). Round 2 had made them black boxes 3 by 4 cm
## standing out of the head; this is the 24-cell (every arrangement of (+-1, +-1, 0, 0), hulled: the engine has no
## 24-cell mesh of its own, but turns any hull into one), `radius` to its corners, about half sunk into the face.
##
## The same in every direction, W included, so it reads round in any slice. Built as it enters the tree; a copy made
## with duplicate() (room 1's wolf puts its eyes on its walk this way) builds its own.
##
## NO class_name (engine_gotchas.md).

@export var radius: float = 0.012:
	set(v):
		radius = v
		if is_inside_tree():
			_build()
@export var color: Color = Color(0.02, 0.018, 0.016)


func _ready() -> void:
	_build()


func _build() -> void:
	var pts := PackedVector4Array()
	for i in 4:
		for j in range(i + 1, 4):
			for a in [-1.0, 1.0]:
				for b in [-1.0, 1.0]:
					var v := Vector4.ZERO
					v[i] = a
					v[j] = b
					pts.append(v * (radius / sqrt(2.0)))
	var hull := ConvexHullShape4D.new()
	hull.set_points(pts)
	mesh = hull.to_tetra_mesh()
	var m := TetraMaterial4D.new()
	m.albedo_color = color
	material_override = m
