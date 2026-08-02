extends Node4D
## Rotating 4D "core" of the player's gun viewmodel - continuous isoclinic
## rotation: equal-angle rotation in two completely orthogonal planes at
## once (xw and yz here - they share no common axis, which is exactly what
## makes a compound rotation "isoclinic" rather than a "simple" rotation
## that leaves one whole plane fixed; the other two valid disjoint pairs
## would be xy/zw or xz/yw).
##
## Specifically NOT xy/zw (the first version of this script): for the w
## component of the spin to be visible at all in Cross-section rendering,
## the mesh needs real w-extent, and whichever spatial axis that extent
## gets rotated INTO during the spin periodically inherits that same
## extent (that's the whole mechanism that makes the w-rotation visible -
## w isn't rendered directly, so its only way to show up is by swapping
## into a spatial axis). zw would rotate the mesh's w-extent into z - the
## same axis Barrel/Stock are arranged along - so a mesh with enough
## w-extent to see would periodically balloon in z far enough to clip
## straight through them (confirmed by watching the actual render, not
## just trusting the math: the basis was genuinely changing, per the
## isoclinic-rotation check in the test suite, but a z-half-extent that's
## supposed to stay ~0.08 was actually reaching the full w half-extent at
## certain rotation phases). xw instead rotates the w-extent into x, where
## there's open space to the sides of the viewmodel - the swelling still
## happens, it just doesn't happen where Barrel/Stock are sitting. yz is
## the harmless remainder: y and z are both already small/comparable
## spatial extents, so mixing them is just an ordinary contained roll.
##
## rotate_rotor() is "same as operator* but as a function" (confirmed
## directly in rotor_4d.cpp - Rotor4D's *= isn't exposed to GDScript at
## all). Order doesn't matter here specifically because xw and yz share no
## axis and therefore commute; this wouldn't generally hold for two
## rotations that share an axis.
##
## Speeds up briefly on fire (call pulse()) then eases back down to
## base_speed - an exponential decay of the speed multiplier back toward
## 1.0, not an instant snap.

@export var base_speed: float = 1.5 # Radians per second, in each of the xw/yz planes.
@export var pulse_speed_multiplier: float = 6.0
@export var pulse_decay_rate: float = 4.0 # Higher = settles back to base_speed faster.

var _speed_multiplier: float = 1.0


func _process(delta: float) -> void:
	_speed_multiplier = 1.0 + (_speed_multiplier - 1.0) * exp(-pulse_decay_rate * delta)
	var angle: float = base_speed * _speed_multiplier * delta
	rotate_rotor_local(Rotor4D.from_xw(angle).rotate_rotor(Rotor4D.from_yz(angle)))


func pulse() -> void:
	_speed_multiplier = pulse_speed_multiplier
