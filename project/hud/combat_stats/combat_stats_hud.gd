extends Control
## Reusable combat stats readout - hits, misses, accuracy, elapsed time.
##
## Fully self-contained and gun/mode-agnostic: it only listens to
## CombatEvents.shot_fired, so any gameplay mode (rail mode, etc.) gets
## identical tracking just by instancing this scene, with no wiring
## beyond that one shared signal already being emitted by the weapon.

@onready var label: Label = $Label

var _hits: int = 0
var _misses: int = 0
var _elapsed_sec: float = 0.0


func _ready() -> void:
	CombatEvents.shot_fired.connect(_on_shot_fired)
	_update_label()


func _process(delta: float) -> void:
	_elapsed_sec += delta
	_update_label()


func _on_shot_fired(hit: bool) -> void:
	if hit:
		_hits += 1
	else:
		_misses += 1


func _update_label() -> void:
	var total_fired: int = _hits + _misses
	var accuracy: float = (100.0 * _hits / total_fired) if total_fired > 0 else 0.0
	label.text = "Hits: %d\nMisses: %d\nAccuracy: %.0f%%\nTime: %.1fs" % [_hits, _misses, accuracy, _elapsed_sec]
