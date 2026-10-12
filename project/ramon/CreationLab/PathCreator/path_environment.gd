@tool
extends RefCounted

## PathCreator: the dev space's light, the Creation Lab's as it plays (Ramon, 5 Oct: "not spotlight,
## just the environment settings from the current room carried over"). That is the kit's bright
## room light (kit_style.gd ROOM_LIGHT) with Ramon's saved F1 settings over it
## (creation_lab_tuning.cfg, 5 Oct: sky fill x1.52, sun x0.66, exposure 1.05, the sun at 64 degrees up
## and 25 round), so the white floor here is lit as the lab's floor is. No spots or washes: the lab's
## only spot was its centre spot over the plinth.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")

const FILL := 1.52
const SUN := 0.66
const EXPOSURE := 1.05
const SUN_UP := 64.0
const SUN_TURN := 25.0


## `mood_overrides` for a LabRoom (lab_room_4d.gd).
static func mood_overrides() -> Dictionary:
	var b: Dictionary = (Style.ROOM_LIGHT["bright"] as Dictionary).duplicate()
	b["ambient"] = (b["ambient"] as Color) * FILL
	b["key_energy"] = float(b["key_energy"]) * SUN
	b["exposure"] = EXPOSURE
	b["key_elevation"] = SUN_UP
	b["key_azimuth"] = SUN_TURN
	return {"bright": b, "dark": {}}
