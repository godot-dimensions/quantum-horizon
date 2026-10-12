extends Node
## Contest movement archetype: hover in place, doing nothing, until either
## hit (handled entirely by the caller freeing the parent target - this
## script has no idea whether it was hit, it just stops existing along with
## it) or a hold-duration timeout elapses, in which case it retracts.
##
## Reusable as-is for a "stationary companion" target too (e.g. contest
## pair 2) - a hold with no motion at all is exactly this archetype, no
## separate "do nothing" archetype needed.

signal expired

@export var hold_duration_sec: float = 2.5

var _elapsed_sec: float = 0.0


func _process(delta: float) -> void:
	_elapsed_sec += delta
	if _elapsed_sec >= hold_duration_sec:
		set_process(false)
		expired.emit()
