extends Node
## Shooting gallery minimap: fading position trail (Outer Wilds-style),
## ported from godot_boids_4d's player.gd - there it lived inline inside the
## controller script; here it's its own sibling script reading
## Player.global_position externally, consistent with how sprint/POI-arrow/
## hitscan have all been kept out of player.gd this session.
##
## Recorded continuously every trail_sample_interval seconds regardless of
## anything else going on; minimap_overlay.gd just reads whatever's here.

@export var trail_duration: float = 30.0
@export var trail_sample_interval: float = 0.25

@onready var player: CharacterBody4D = $"../Player"

## Each entry: {"position": Vector4, "age": float}. Oldest first.
var _trail: Array = []
var _sample_timer_sec: float = 0.0

func _process(delta: float) -> void:
	for entry in _trail:
		entry["age"] += delta
	while _trail.size() > 0 and _trail[0]["age"] > trail_duration:
		_trail.pop_front()

	_sample_timer_sec += delta
	if _sample_timer_sec >= trail_sample_interval:
		_sample_timer_sec = 0.0
		_trail.append({"position": player.global_position, "age": 0.0})

func get_trail() -> Array:
	return _trail
