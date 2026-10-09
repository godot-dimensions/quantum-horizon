extends RefCounted

## The creature hall's population through W (PLAN_V2 part I; Ramon's walkthrough item 16: "fully sliceable,
## using a real W-distribution tool, not the illusion"). The W Exploder's idea (WTools/exploder/w_exploder_4d.gd:
## every plant again at W steps either side, each copy a little to one side, turned, a little bigger or
## smaller, its dice from its own name) for the hall's stations.
##
## WHY NO SECOND PEDESTAL: everything the kit builds is W_DEPTH (8 m) deep in W, the pedestals too. So a
## station's copies stand on the same deck at other W's: step ana or kata (E, Q) or turn the slice, and the
## deck holds other animals. They are real: they walk, roam, peck and fly where they are, as the first ones
## do. Never the illusion of a copy drawn where the thing is not.
##
## A station asks for copies with "w_copies" (how many) in the hall's STATIONS; the brachiosaurus never.
## layers() gives the station's layers, its own first: {"w", "turn", "grow"}.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/CreationLab/scripts/chamber_build.gd")

## Metres between layers through W, how far each is shaken off its step, and the size change either way.
const SPACING := 2.4
const JITTER := 0.35
const GROW := 0.1
## Kept this far inside the deck's W depth (an animal is some tens of centimetres deep in W itself).
const W_MARGIN := 1.0


## The layers of station `s`: its own at W 0, then a copy ana, one kata, one further ana, ... as many as
## its "w_copies". A round deck's copies turn any way; a square deck's only end for end (its walkers keep to
## its sides); the crows' not at all (their perches are measured unturned).
static func layers(s: Dictionary) -> Array:
	var out: Array = [{"w": 0.0, "turn": 0.0, "grow": 1.0}]
	var n: int = int(s.get("w_copies", 0))
	var limit: float = Build.W_DEPTH * 0.5 - W_MARGIN
	for i in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(s["name"]) + "/w%d" % i)
		var step: int = i / 2 + 1
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var w: float = clampf(side * (float(step) * SPACING + rng.randf_range(-JITTER, JITTER)), -limit, limit)
		var turn: float = 0.0
		var grow: float = 1.0
		if String(s["kind"]) != "crows":
			grow = 1.0 + rng.randf_range(-GROW, GROW)
			if String(s["shape"]) == "round":
				turn = rng.randf_range(0.0, TAU)
			elif rng.randf() < 0.5:
				turn = PI
		out.append({"w": w, "turn": turn, "grow": grow})
	return out
