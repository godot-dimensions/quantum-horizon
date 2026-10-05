@tool
extends Node4D

## A camera mark: a place and a direction a shot can be taken from. The lab's runners, its
## Play breakdown and the explainer film all frame their shots from marks rather than from
## numbers written into code, so moving a mark in the editor re-frames every use of it at once.
##
## The mark's own transform IS the camera's: a Camera4D looks down its local -Z, so a mark is
## aimed by turning it, or by `aim_at()` from a script.
##
## NO class_name. A class_name written outside the editor stays invisible to every other script
## until the editor rescans (engine_gotchas.md), so the kit's scripts find marks by group
## ("lab_mark") and preload this file for its constants.

const GROUP := "lab_mark"

## The lens, as Camera4D.field_of_view_4d. A Camera4D projects in 4D by default, so this is the
## one that frames the shot; field_of_view_3d does nothing (wolf.md, "Traps").
@export_range(0.2, 2.5, 0.01) var lens: float = 1.0
## How long a shot from here holds by default, in seconds (a sequence can override it).
@export_range(0.0, 30.0, 0.1) var hold: float = 3.0
## What the mark is for, for lists and logs ("wide", "rig close").
@export var label: String = ""


func _enter_tree() -> void:
	add_to_group(GROUP)


## Points the mark from where it stands at `target`, level horizon: yaw about Y, then pitch.
func aim_at(target: Vector4) -> void:
	global_basis = basis_looking(global_position, target)


## The basis of a camera at `eye` looking at `at`, with no roll and no turn through W.
static func basis_looking(eye: Vector4, at: Vector4) -> Projection:
	var d: Vector4 = at - eye
	var flat: float = Vector2(d.x, d.z).length()
	return Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, maxf(flat, 0.0001)))


## Every mark under `root` with this label, or null.
static func find(root: Node, wanted: String) -> Node4D:
	for node in root.get_tree().get_nodes_in_group(GROUP):
		if root.is_ancestor_of(node) and String(node.get("label")) == wanted:
			return node as Node4D
	return null
