extends Node4D

## The far room at the end of the way through W, and the tunnel to it (cave_rock_4d.gd,
## "THE FAR ROOM"): its baked rock, its lamps, and the standing stones' colliders. A scene
## of its own so that it is only in memory while it can be seen - cave_far_stream_4d.gd
## loads it and lets it go. It sits at the cave's own origin, so everything in it is in
## the cave's frame.

const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")


func _ready() -> void:
	var body := StaticBody4D.new()
	body.name = "Solid"
	add_child(body)
	for box in CaveRock.new().far_solid_boxes():
		var shape := BoxShape4D.new()
		shape.size = box[1]
		var holder := CollisionShape4D.new()
		holder.shape = shape
		holder.position = box[0]
		body.add_child(holder)
