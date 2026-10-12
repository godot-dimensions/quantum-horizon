extends Resource

## The creature hall's info cards, every word in one place (PLAN_V2 part J: "words in one resource, so they
## are easy to edit"): creature_hall_info.tres. One card per station, by the station's name in the hall's
## STATIONS (creature_hall_4d.gd):
##
##   title    the animal's name
##   kicker   one line over it, capitals: what kind, how many balls, how it moves
##   moves    HOW IT MOVES, a sentence or two
##   four_d   WHAT IS 4D ABOUT IT, a sentence or two
##   built    HOW IT IS BUILT, for the close look's panel (round 4), from the code
##
## NO class_name (engine_gotchas.md).

@export var cards: Dictionary = {}
## The line along the card's foot.
@export var close_hint: String = "LEFT CLICK  ·  CLOSE"
