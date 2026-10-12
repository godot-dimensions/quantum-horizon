extends Node4D

## A creature or a tree, turned through W round its own middle (Creature Lab round 3, 10 Oct 2026; Ramon's
## item 38: "only the creatures, trees and their 4D representations should be affected by W-slice rotation;
## everything else should remain stationary ... the room itself provides a stable architectural reference").
##
## The hall no longer turns the view's slice: right drag turns the exhibits instead, as room 1 and the Voxel
## Lab turn theirs. This node sits between an exhibit and its parent and holds the turn (xw, then zw).
##
## WHY IT DOES NOT BREAK THE WALKS: the exhibit's position is written by its walker, its roam, its flight,
## all in this node's frame. Each frame this node is moved so that the exhibit's origin lands exactly where
## that position says, unturned (position = c - R c, so R c + position = c): the walk, the deck clamp and
## the flight run as if nothing turned, and only the body turns, round its own origin.
##
## It runs after the exhibit's own scripts (process_priority), so the turn never lags the walk.
##
## NO class_name (engine_gotchas.md).

## The turn: x the xw angle, y the zw angle (radians). The hall sets it on every pivot (group "hall_turn").
var turn: Vector2 = Vector2.ZERO


func _enter_tree() -> void:
	add_to_group("hall_turn")
	process_priority = 100


func _process(_delta: float) -> void:
	var m: Node4D = null
	for c in get_children():
		if c is Node4D:
			m = c
			break
	if m == null:
		return
	var r: Projection = Basis4D.from_xw(turn.x) * Basis4D.from_zw(turn.y)
	basis = r
	var c: Vector4 = m.position
	position = c - r * c
