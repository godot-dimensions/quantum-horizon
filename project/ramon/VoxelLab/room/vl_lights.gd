extends Node

## The Voxel Lab's lights, from nothing (Ramon, 8 Oct: "I don't want any spotlights in here [the
## corridor]"; "there should be just spotlights, soft, soft spotlights on each of the items ... they can
## all be having the same parameter sliders for everything in the same room, except those three
## separate ones [specimens A, B and C]"; "separate sliders that I can adjust for each one ... a layout
## and top view ... show me where the lights are ... and then make a save button").
##
## Every light is a carried kit light (kit_light_4d.gd, a soft downlight from the ceiling with its
## glowing disc), a child of the room's Lights node, with metadata: "room" (hall or gallery), "group"
## (A, B, C or none) and "item" (what it lights). Its aim stays on its item; moving it tilts it.
##
## WHAT SETS A LIGHT, in order:
##   the room's values   strength, cone (degrees), softness, height (m)
##   A, B and C          their own strength in place of the hall's
##   the light's own     a strength factor, its own cone, softness or height, and a move (dx, dz)
## Everything is saved to SAVE_PATH by the dev panel's SAVE and read back when the room starts.
##
## NO class_name (engine_gotchas.md).

const SAVE_PATH := "res://ramon/VoxelLab/voxel_lab_lights.cfg"
## The rooms' first values: soft pools from the ceiling.
const ROOM_DEFAULTS := {
	"hall": {"strength": 2.4, "cone": 34.0, "softness": 2.6, "height": 8.2},
	"gallery": {"strength": 2.4, "cone": 34.0, "softness": 2.6, "height": 7.2},
}
const GROUP_DEFAULT := 1.2
## The ceilings, for the fixture discs.
const CEILING := {"hall": 8.94, "gallery": 7.94}
const OWN_KEYS := ["strength_k", "cone", "softness", "height", "dx", "dz"]

var lights: Array = []
var rooms: Dictionary = ROOM_DEFAULTS.duplicate(true)
var groups: Dictionary = {"A": GROUP_DEFAULT, "B": GROUP_DEFAULT, "C": GROUP_DEFAULT}
## Per light name: any of OWN_KEYS.
var own: Dictionary = {}

signal changed


## Finds the lights under `holder` and lights them as saved.
func setup(holder: Node) -> void:
	lights = []
	if holder != null:
		for c in holder.get_children():
			if c.has_meta("room"):
				lights.append(c)
				if not c.has_meta("base"):
					c.set_meta("base", Vector2(c.position.x, c.position.z))
	load_saved()
	apply_all()


func light(name: String) -> Node:
	for l in lights:
		if String(l.name) == name:
			return l
	return null


## What a light is set to, all things counted: {"strength", "cone", "softness", "height", "x", "z"}.
func effective(l: Node) -> Dictionary:
	var room: Dictionary = rooms.get(String(l.get_meta("room", "hall")), ROOM_DEFAULTS["hall"])
	var mine: Dictionary = own.get(String(l.name), {})
	var g: String = String(l.get_meta("group", ""))
	var strength: float = float(groups.get(g, room["strength"])) if groups.has(g) else float(room["strength"])
	var base: Vector2 = l.get_meta("base", Vector2(l.position.x, l.position.z))
	return {
		"strength": strength * float(mine.get("strength_k", l.get_meta("strength_k", 1.0))),
		# A light may carry its own first cone (the big terrain pedestal needs a wide pool).
		"cone": float(mine.get("cone", l.get_meta("cone", room["cone"]))),
		"softness": float(mine.get("softness", room["softness"])),
		"height": float(mine.get("height", room["height"])),
		"x": base.x + float(mine.get("dx", 0.0)),
		"z": base.y + float(mine.get("dz", 0.0)),
	}


func apply_all() -> void:
	for l in lights:
		apply(l)
	changed.emit()


func apply(l: Node) -> void:
	var e: Dictionary = effective(l)
	var room: String = String(l.get_meta("room", "hall"))
	(l as Node4D).position = Vector4(float(e["x"]), float(e["height"]), float(e["z"]), 0.0)
	l.set("angle", float(e["cone"]))
	l.set("softness", float(e["softness"]))
	l.set("reach", float(e["height"]) + 6.0)
	l.set("energy", {"bright": float(e["strength"]), "dark": float(e["strength"]) * 1.3})
	l.set("fixture_at", float(CEILING.get(room, 8.94)))


## A room slider: `key` one of strength, cone, softness, height.
func set_room(room: String, key: String, v: float) -> void:
	(rooms[room] as Dictionary)[key] = v
	for l in lights:
		if String(l.get_meta("room", "")) == room:
			apply(l)
	changed.emit()


func set_group(g: String, v: float) -> void:
	groups[g] = v
	for l in lights:
		if String(l.get_meta("group", "")) == g:
			apply(l)
	changed.emit()


## One light's own value (OWN_KEYS).
func set_own(name: String, key: String, v: float) -> void:
	var mine: Dictionary = own.get(name, {})
	mine[key] = v
	own[name] = mine
	var l: Node = light(name)
	if l != null:
		apply(l)
	changed.emit()


## Moves a light to (x, z) in the room, as an offset from where the plan put it.
func move_to(name: String, x: float, z: float) -> void:
	var l: Node = light(name)
	if l == null:
		return
	var base: Vector2 = l.get_meta("base")
	var mine: Dictionary = own.get(name, {})
	mine["dx"] = x - base.x
	mine["dz"] = z - base.y
	own[name] = mine
	apply(l)
	changed.emit()


## Back to its room's values, where the plan put it.
func reset_own(name: String) -> void:
	own.erase(name)
	var l: Node = light(name)
	if l != null:
		apply(l)
	changed.emit()


func save(path: String = SAVE_PATH) -> int:
	var cf := ConfigFile.new()
	for r in rooms:
		for k in rooms[r]:
			cf.set_value("room_" + String(r), String(k), float(rooms[r][k]))
	for g in groups:
		cf.set_value("groups", String(g), float(groups[g]))
	for n in own:
		for k in own[n]:
			cf.set_value("light_" + String(n), String(k), float(own[n][k]))
	return cf.save(path)


func load_saved(path: String = SAVE_PATH) -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	for sec in cf.get_sections():
		if sec.begins_with("room_"):
			var r: String = sec.trim_prefix("room_")
			if rooms.has(r):
				for k in cf.get_section_keys(sec):
					(rooms[r] as Dictionary)[k] = float(cf.get_value(sec, k))
		elif sec == "groups":
			for k in cf.get_section_keys(sec):
				groups[k] = float(cf.get_value(sec, k))
		elif sec.begins_with("light_"):
			var mine: Dictionary = {}
			for k in cf.get_section_keys(sec):
				if k in OWN_KEYS:
					mine[k] = float(cf.get_value(sec, k))
			own[sec.trim_prefix("light_")] = mine
