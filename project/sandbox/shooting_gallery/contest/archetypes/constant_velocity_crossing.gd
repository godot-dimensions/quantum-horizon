extends Node
## Contest movement archetype: moves the parent target at a constant 4D
## velocity (any combination of x/y/z/w - a pure lateral crossing and a
## combined lateral+ana drift are both just "a velocity" to this script,
## no special-casing needed) until it's covered a fixed travel distance,
## then expires.

signal expired

@export var velocity: Vector4 = Vector4(2.0, 0.0, 0.0, 0.0)
@export var travel_distance: float = 8.0

var _traveled: float = 0.0
var _target: Node4D = null


func _ready() -> void:
	_target = get_parent()


func _process(delta: float) -> void:
	var step: Vector4 = velocity * delta
	_target.position += step
	_traveled += step.length()
	if _traveled >= travel_distance:
		set_process(false)
		expired.emit()
