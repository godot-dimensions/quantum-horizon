extends Node4D
## Rotating 4D "core" of the player's gun viewmodel - continuous isoclinic
## rotation: equal-angle rotation in two completely orthogonal planes at
## once (xy and zw here - they share no common axis, which is exactly what
## makes a compound rotation "isoclinic" rather than a "simple" rotation
## that leaves one whole plane fixed; the other two valid disjoint pairs
## would be xz/yw or xw/yz, any of the three works the same way). xy stays
## entirely within the visible 3-space (an ordinary roll around the forward
## axis), while zw mixes depth with the w axis, so the shape's cross-section
## visibly changes as it spins - showing off the "it's a 4D object" point
## rather than just looking like an ordinary spinning prop.
##
## rotate_rotor() is "same as operator* but as a function" (confirmed
## directly in rotor_4d.cpp - Rotor4D's *= isn't exposed to GDScript at
## all). Order doesn't matter here specifically because xy and zw share no
## axis and therefore commute; this wouldn't generally hold for two
## rotations that share an axis.
##
## Speeds up briefly on fire (call pulse()) then eases back down to
## base_speed - an exponential decay of the speed multiplier back toward
## 1.0, not an instant snap.

@export var base_speed: float = 1.5 # Radians per second, in each of the xy/zw planes.
@export var pulse_speed_multiplier: float = 6.0
@export var pulse_decay_rate: float = 4.0 # Higher = settles back to base_speed faster.

var _speed_multiplier: float = 1.0


func _process(delta: float) -> void:
	_speed_multiplier = 1.0 + (_speed_multiplier - 1.0) * exp(-pulse_decay_rate * delta)
	var angle: float = base_speed * _speed_multiplier * delta
	rotate_rotor_local(Rotor4D.from_xy(angle).rotate_rotor(Rotor4D.from_zw(angle)))


func pulse() -> void:
	_speed_multiplier = pulse_speed_multiplier
