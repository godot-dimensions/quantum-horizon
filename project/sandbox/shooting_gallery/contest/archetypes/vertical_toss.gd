extends Node
## Contest movement archetype: tosses the parent target straight up in a
## simple parabolic arc (4*h*t*(1-t), peaking at height h at the midpoint of
## the flight) over a fixed flight duration, then expires whether or not it
## was hit mid-flight - the caller is responsible for freeing/stopping this
## early on an actual hit, same as every other archetype.

signal expired

@export var flight_duration_sec: float = 1.75
@export var toss_height: float = 2.0

var _elapsed_sec: float = 0.0
var _start_position: Vector4 = Vector4.ZERO
var _target: Node4D = null


func _ready() -> void:
	_target = get_parent()
	_start_position = _target.position


func _process(delta: float) -> void:
	_elapsed_sec += delta
	var t: float = clampf(_elapsed_sec / flight_duration_sec, 0.0, 1.0)
	var height_offset: float = 4.0 * toss_height * t * (1.0 - t)
	_target.position = _start_position + Vector4(0.0, height_offset, 0.0, 0.0)
	if _elapsed_sec >= flight_duration_sec:
		set_process(false)
		expired.emit()
