class_name Terrain4DProfile
extends RefCounted
## TEMPORARY instrumentation utility for a one-off performance spike
## (see the benchmark runner that uses this) - NOT a permanent profiling
## system, and NOT meant to inform any lasting architecture decision by
## itself. Delete this file and its call sites (grep for
## "Terrain4DProfile.add") once the spike's numbers are captured. A real
## long-term profiling story should probably use Godot's built-in
## Performance/Profiler tools instead of this hand-rolled accumulator.
##
## Static accumulator keyed by stage name - call reset() before a
## measurement window, add() from inside whatever's being timed, then
## read snapshot() after.

static var _usec: Dictionary = {}
static var _calls: Dictionary = {}

static func reset() -> void:
	_usec = {}
	_calls = {}

static func add(stage: String, usec: int) -> void:
	_usec[stage] = _usec.get(stage, 0) + usec
	_calls[stage] = _calls.get(stage, 0) + 1

static func get_usec(stage: String) -> int:
	return _usec.get(stage, 0)

static func get_calls(stage: String) -> int:
	return _calls.get(stage, 0)

static func snapshot() -> Dictionary:
	var result := {}
	for stage in _usec:
		result[stage] = {"usec": _usec[stage], "calls": _calls.get(stage, 0)}
	return result
