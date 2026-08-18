extends Node
## Shared combat event bus (autoload singleton).
##
## Decouples "a shot was fired" from whatever cares about it - ammo pips,
## stats HUDs, future modes - so a weapon script only needs to emit here,
## and any listener component gets identical tracking just by instancing
## itself and connecting, with no direct references to the weapon at all.

signal shot_fired(hit: bool)
