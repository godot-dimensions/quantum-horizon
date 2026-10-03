@tool
extends "res://ramon/chickenpen/terrain/baked_ground_4d.gd"

## The hill with the hole in it, as it stands in the pen: the baked mesh, the boxes you
## stand on and bump into, and the way into the cave.
##
## The shape and the boxes come from the same recipe (terrain/pen_cave_hill_4d.gd), so what
## is drawn and what is solid cannot drift apart - rebake the mesh after changing it.
##
## THE WAY IN IS A BOX AT THE BACK OF THE TUNNEL, not a distance from a point: the tunnel is
## 7 m across in x and in w and a circle round its middle would miss people walking in along
## one wall. W is tested like any other axis - a hole on another slice is not one you are
## standing in. It is at the back, not the mouth, so the walk in through the dark happens.

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")

signal entered

@export var player_path: NodePath = NodePath("../../Player")
## The crossing that takes you to the cave and back. Its go() is called on the way in.
@export var crossing_path: NodePath = NodePath("../../CaveCrossing")

var _player: Node4D
var _crossing: Node
var _used := false
## The trigger, as a centre and half-size in world space.
var _way_in := Vector4.ZERO
var _way_in_half := Vector4.ZERO


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	add_to_group(&"slice_dial_outline")
	var recipe = CaveHill.new()
	var body := StaticBody4D.new()
	body.name = "Solid"
	add_child(body)
	for box in recipe.solid_boxes():
		var shape := BoxShape4D.new()
		shape.size = box[1]
		var holder := CollisionShape4D.new()
		holder.shape = shape
		holder.position = box[0]
		body.add_child(holder)
	var way_in: Array = recipe.way_in()
	_way_in = way_in[0]
	_way_in_half = way_in[1]
	_player = get_node_or_null(player_path) as Node4D
	_crossing = get_node_or_null(crossing_path)
	if _crossing != null and _crossing.has_method("go"):
		entered.connect(_crossing.go)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _used or _player == null:
		return
	var d: Vector4 = (_player.global_position - _way_in).abs()
	if d.x <= _way_in_half.x and d.y <= _way_in_half.y and d.z <= _way_in_half.z and d.w <= _way_in_half.w:
		_used = true
		preload("res://ramon/chickenpen/scripts/pen_quests_4d.gd").mark_visited("cave")
		# Deferred: the crossing swaps whole branches of the tree, which is not something to
		# do from inside a physics step (hub_demo_lessons.md: scene changes from physics crash).
		entered.emit.call_deferred()


## On the pen's dial (pen_slice_plane_4d.gd, Ramon, 3 Oct: "I want the marsh, the watchtower,
## the owl, the cave, all to show up on the gizmo dynamically"): the hill's footprint, named at its mouth, where it is now - asked
## for every frame, so moving it moves it on the dial too.
func dial_outline() -> Dictionary:
	var points := PackedVector4Array()
	var bend: float = 2.0 / CaveHill.ROUNDNESS
	for i in 32:
		var a: float = TAU * float(i) / 32.0
		var c: float = cos(a)
		var s: float = sin(a)
		var edge := Vector4(signf(c) * pow(absf(c), bend) * CaveHill.HALF.x, 0.0, signf(s) * pow(absf(s), bend) * CaveHill.HALF.y, 0.0)
		points.append(global_position + global_basis * (CaveHill.HILL + edge))
	return {"points": points, "label": "cave", "colour": Color(0.50, 0.88, 0.78, 0.9), "depth": CaveHill.HALF.z,
		"label_at": global_position + global_basis * CaveHill.MOUTH}


## Walkable again after coming back out - the crossing calls this on everything.
func rearm() -> void:
	_used = false
