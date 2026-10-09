@tool
extends Node4D

## The water scene: an object a route leads to (after the Arboretum's arb_target_4d.gd), for the
## path network's frames (carried PathCreator: graph/path_network_4d.gd reads footprint(), size and
## w_depth from anything under its `targets`).
## Draws nothing: it stands where a pedestal, a door or a pad is, as big as its footprint on the
## floor, so the destination's frame grows round the real thing.
##
## NO class_name (engine_gotchas.md).

## What it stands for, for the builder's labels.
@export var label: String = "Pedestal"
## Its size: x and z the footprint on the floor, y how tall (m).
@export var size: Vector3 = Vector3(4, 1, 4)
## How deep in W it is (m).
@export var w_depth: float = 6.0
## Its colour in the path builder's top view (F4 draws every target's footprint in it).
@export var color: Color = Color(0.35, 0.62, 0.95)


func footprint() -> Vector2:
	return Vector2(size.x, size.z)
