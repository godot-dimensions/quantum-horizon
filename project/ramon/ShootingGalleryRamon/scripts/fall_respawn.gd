extends Node
## Shooting gallery experiment: falling off the play area used to leave the
## player stuck below the world; this respawns them back at their original
## spawn transform once they've fallen far enough below the ground to be
## clearly gone (not just mid-jump or dipping near a floor edge).
##
## Reads Player externally rather than adding this to player.gd - unlike
## sprint (which had no external hook available), a fall check needs nothing
## player.gd doesn't already expose (global_position/global_basis/
## linear_velocity are all public CharacterBody4D/Node4D properties).

## Ground tops sit at y=0, undersides at y=-1 (floor half-extent 0.5,
## centered at y=-0.5) - comfortably below that so this only triggers once
## the player has genuinely fallen off, not while briefly dipping near a
## floor's edge.
const DEATH_Y := -10.0

@onready var player: CharacterBody4D = $"../Player"

var _spawn_position: Vector4
var _spawn_basis: Projection


func _ready() -> void:
	_spawn_position = player.global_position
	_spawn_basis = player.global_basis


func _physics_process(_delta: float) -> void:
	if player.global_position.y < DEATH_Y:
		player.linear_velocity = Vector4.ZERO
		player.global_position = _spawn_position
		player.global_basis = _spawn_basis
