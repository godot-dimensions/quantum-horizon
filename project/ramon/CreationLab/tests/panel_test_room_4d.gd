@tool
extends Node4D

## A second prototype in miniature, to prove the wall panel kit (kit/panels/) works outside the
## Creation Lab (follow_up/wall_panels_plan.md, steps 13 and 20): a plain box room (a rectangular
## KitRoom, sides n/s/w/e) with an introduction on its north wall and research panels on its east
## and west walls in the two other layout families (compare, steps), and outside its open south
## side a panel with no room at all, standing on its own wall and turned `turned_degrees`. No
## showcase and no source: the panels show the room's words and the Figma's reference numbers.
##
## NO class_name (engine_gotchas.md).

const KitPlayer := preload("res://ramon/CreationLab/kit/kit_player.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")

## How far the freestanding panel is turned off facing straight back at the room, degrees.
@export_range(-180.0, 180.0, 1.0) var turned_degrees: float = 30.0:
	set(v):
		turned_degrees = v
		_turn()

var player: CharacterBody4D


func _ready() -> void:
	_turn()
	if Engine.is_editor_hint():
		return
	Style.apply("bright")
	player = KitPlayer.make()
	add_child(player)
	player.global_position = Vector4(0.0, 0.05, 6.0, 0.0)
	player.set("_facing", PI)


func _turn() -> void:
	var p: Node4D = get_node_or_null("Freestanding") as Node4D
	if p == null:
		return
	p.basis = Basis4D.from_zx(PI + deg_to_rad(turned_degrees))
	if p.is_inside_tree():
		p.call("rebuild")
