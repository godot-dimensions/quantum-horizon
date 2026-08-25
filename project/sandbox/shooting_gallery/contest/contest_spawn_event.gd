class_name ContestSpawnEvent
extends Resource
## One authored spawn in a contest sequence: which movement archetype, where
## (including w), and when relative to its own pair becoming active (not the
## sequence as a whole - see ContestSequencePlayer). Archetype-specific
## parameters below are grouped per archetype and simply ignored for events
## using a different one - keeps every event's full parameter set editable
## in the inspector without needing a different resource type per archetype.

enum Archetype { POP_HOLD_RETRACT, VERTICAL_TOSS, CONSTANT_VELOCITY_CROSSING }

@export var archetype: Archetype = Archetype.POP_HOLD_RETRACT
## Seconds after this event's pair becomes active (not sequence start).
@export var spawn_delay_sec: float = 0.0
@export var spawn_position: Vector4 = Vector4.ZERO

@export_group("Pop hold retract")
@export var hold_duration_sec: float = 2.5

@export_group("Vertical toss")
@export var flight_duration_sec: float = 1.75
@export var toss_height: float = 2.0

@export_group("Constant velocity crossing")
@export var velocity: Vector4 = Vector4(2.0, 0.0, 0.0, 0.0)
@export var travel_distance: float = 8.0
