@tool
extends Node4D

## A landmark's place for the paths (PenLayout/PLAN_B.md steps 26 and 29): stood at the landmark's
## middle as a child of it, so it moves with it. The path network (CreationLab/PathCreator/graph/
## path_network_4d.gd) anchors the landmark's action circle to it, and in the dev look draws a
## rectangle or circle round [member size] on the floor (Ramon, 6 Oct: "in the dev look all landmarks
## need a rectangle or circle around it to signify the here location").

## The landmark's footprint on the floor, x by z, metres.
@export var size: Vector2 = Vector2(6.0, 6.0)


## The network asks for this to size its frame.
func footprint() -> Vector2:
	return size
