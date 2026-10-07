@tool
extends Node4D

## A patch of the yard's sand painted on the pen's ground (grass/pen_grass_4d.gd's ground_sand group),
## where this node stands, and bare of grass (the grass clears every sand shape, 7 Oct): round, or with
## [member size] set, a rectangle along this node's own x and z. In front of Trym's house in layout B
## (Ramon, 6 Oct: "sand in front of the house, and on top a larger destination circle"); over the pen's
## run (7 Oct: "pen sand should extend beyond the fence, and grass should start beyond that"); under
## the cave's mouth (7 Oct: "a bit of sand color patch under the entrance of the cave would be good").
## A child of what it is for, so it moves with it.

@export_range(0.5, 12.0, 0.1, "suffix:m") var radius: float = 3.0
## Width (x) and depth (z) for a rectangle; zero for the circle of [member radius].
@export var size: Vector2 = Vector2.ZERO
## How far through W either side of this node's W the sand reaches.
@export_range(0.2, 6.0, 0.1, "suffix:m") var w_half: float = 1.0


func _enter_tree() -> void:
	add_to_group(&"ground_sand")


func ground_sand() -> Array:
	if size.x > 0.0 and size.y > 0.0:
		var b: Projection = global_basis
		return [{"centre": global_position, "half": size * 0.5, "ax": Vector2(b.x.x, b.x.z).normalized(),
			"az": Vector2(b.z.x, b.z.z).normalized(), "w_half": w_half}]
	return [{"centre": global_position, "radius": radius, "w_half": w_half}]
