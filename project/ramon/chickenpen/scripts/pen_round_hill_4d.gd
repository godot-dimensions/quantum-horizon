@tool
extends "res://ramon/chickenpen/terrain/baked_ground_4d.gd"

## A plain hill as it stands in the pen (6 Oct 2026): the baked mesh of its shape
## (terrain/pen_round_hill_4d.gd SHAPES, baked by _bake_terrain_runner.gd what=<shape>) and the boxes
## you bump into, from the same recipe so what is drawn and what is solid cannot drift apart.

const RoundHill := preload("res://ramon/chickenpen/terrain/pen_round_hill_4d.gd")

## Which shape this is: a key of RoundHill.SHAPES, and the name of its baked mesh.
@export var shape: String = "hill_west"


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	var recipe = RoundHill.new(shape)
	var body := StaticBody4D.new()
	body.name = "Solid"
	add_child(body)
	for box in recipe.solid_boxes():
		var holder := CollisionShape4D.new()
		var s := BoxShape4D.new()
		s.size = box[1]
		holder.shape = s
		holder.position = box[0]
		body.add_child(holder)
