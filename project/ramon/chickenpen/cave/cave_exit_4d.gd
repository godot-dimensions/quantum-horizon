extends Node4D

## The way back out: daylight at the end of the tunnel behind you, and walking into it
## takes you home to the field.
##
## CALLED ExitArch ON PURPOSE. The pen's crossing already looks for a node of that name
## with an `entered` signal when it opens a scene (pen_crossing_4d.gd), which is how the
## theatre's door home works. Using the same contract means the cave needed no new code in
## the crossing to find its way out.
##
## DAYLIGHT, NOT A DOOR. You came in through a hole in a hill; the way out should look like
## the hole in the hill from the inside - a bright opening, not a glowing portal. It is a
## flat pale block at the tunnel's end with a warm lamp in front of it, which is all
## daylight in a dark tunnel ever is.

signal entered

@export var player_path: NodePath = NodePath("../../Player")
## How close to the light counts as walking into it, along the tunnel.
@export_range(0.3, 4.0, 0.1) var enter_within: float = 1.3
## Half the tunnel's width in x and w: anywhere across it counts.
@export_range(0.5, 4.0, 0.1) var half_width: float = 2.3
@export var light_colour: Color = Color(1.0, 0.93, 0.78)

var _player: Node4D
var _used := false


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	var panel := MeshInstance4D.new()
	panel.name = "Daylight"
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(half_width * 2.2, 4.6, 0.1, half_width * 2.2)
	panel.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = light_colour
	panel.material_override = material
	add_child(panel)
	panel.position = Vector4(0.0, 2.1, 0.0, 0.0)
	var lamp := OmniLight4D.new()
	lamp.name = "Spill"
	lamp.light_color = Color(1.0, 0.86, 0.62)
	lamp.light_energy = 2.4
	lamp.omni_range_meters = 9.0
	add_child(lamp)
	lamp.position = Vector4(0.0, 2.4, -0.9, 0.0)


func _physics_process(_delta: float) -> void:
	if _used or _player == null:
		return
	var local: Vector4 = global_basis.inverse() * (_player.global_position - global_position)
	if local.z > -enter_within and absf(local.x) <= half_width and absf(local.w) <= half_width:
		_used = true
		# Deferred: the crossing swaps whole branches of the tree, not a thing to do from
		# inside a physics step (hub_demo_lessons.md).
		entered.emit.call_deferred()


func rearm() -> void:
	_used = false
