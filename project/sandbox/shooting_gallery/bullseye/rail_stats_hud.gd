extends Control
## Rail mode's HUD: live running totals for the CURRENT ride (aim, slice -
## see rail_controller.gd's own header comment on why these stay separate),
## plus this session's best-ever total for each, tracked independently - no
## single combined "best run" judgment, same never-blend rule as the totals
## themselves. Session-only, in memory - no persistence across restarting
## the game, per spec.
##
## Pure "dumb readout" of rail_controller.gd's own signals - owns nothing
## about ride state itself, only the cross-ride session-best comparison,
## which is a genuinely separate, presentation-only concern (see
## rail_controller.gd's own comment on this split).

@onready var rail_controller: Node = $"../RailController"
@onready var label: Label = $Label

var _session_best_aim: int = 0
var _session_best_slice: int = 0
var _showing_results: bool = false


func _ready() -> void:
	rail_controller.ride_started.connect(_on_ride_started)
	rail_controller.score_updated.connect(_on_score_updated)
	rail_controller.ride_completed.connect(_on_ride_completed)
	rail_controller.ride_reset.connect(_on_ride_reset)
	_show_ready()


func _on_ride_started() -> void:
	_showing_results = false
	_on_score_updated(0, 0)


func _on_score_updated(aim_total: int, slice_total: int) -> void:
	if _showing_results:
		return
	label.text = "Aim: %d   Slice: %d" % [aim_total, slice_total]


func _on_ride_completed(aim_total: int, slice_total: int) -> void:
	_showing_results = true
	_session_best_aim = maxi(_session_best_aim, aim_total)
	_session_best_slice = maxi(_session_best_slice, slice_total)
	label.text = "RIDE COMPLETE!\nAim: %d (best %d)\nSlice: %d (best %d)" % [
		aim_total, _session_best_aim, slice_total, _session_best_slice,
	]


func _on_ride_reset() -> void:
	_showing_results = false
	_show_ready()


func _show_ready() -> void:
	label.text = "Ready - walk into the start marker\nBest so far - Aim: %d   Slice: %d" % [
		_session_best_aim, _session_best_slice,
	]
