extends Node4D

## Copies another node's local position every frame.
##
## Exists because of a trap in the loft rig: a ball node runs
## `visible = Engine.is_editor_hint()`, so at runtime it hides ITSELF AND EVERY CHILD.
## Anything parented to a ball - a foot, a marker, a carry anchor - therefore vanishes
## the moment the game runs, while looking perfectly correct in the editor.
##
## So attachments sit beside the balls as siblings under the rig, and follow one. Both
## are in the same parent space, so copying the position is exact and needs no transform
## maths. Far cheaper than the alternative, which is moving whole limbs in script.
##
## Only the position is copied by default. A ball's basis carries the loft's own
## section scaling, which is not something an attachment wants to inherit.

@export var target_path: NodePath

@export var copy_basis: bool = false

## Added after copying, in the target's own space.
@export var offset: Vector4 = Vector4.ZERO

var _target: Node4D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node4D
	if _target == null:
		push_warning("FollowNode4D on %s: target_path '%s' resolves to nothing - the attachment will sit at the origin." % [name, target_path])


func _process(_delta: float) -> void:
	if _target == null:
		return
	position = _target.position + offset
	if copy_basis:
		basis = _target.basis
