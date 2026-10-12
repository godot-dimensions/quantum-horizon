extends RefCounted
## Owns the level order for the Miegakure levels, in one place.
##
## Exists because the three levels in ../levels/ were built with no way to get
## from one to the next: the goal banner drew its text and the game then sat
## there forever. Reported as "after completing level 1, level 2 doesn't start",
## which is exactly what it did.
##
## Referenced by preload rather than class_name - global class names resolve from
## .godot/global_script_class_cache.cfg, which only the editor regenerates, so a
## class_name added with the editor closed takes down every script naming it.
## `const LevelFlow = preload(...)` plus static functions needs no cache at all.
##
## Adding a level 4 means adding one line to LEVELS. Nothing else knows the order.

const LEVELS: Array[String] = [
	"res://ramon/MiegakureLook/levels/level_1_wall.tscn",
	"res://ramon/MiegakureLook/levels/level_2_bridge.tscn",
	"res://ramon/MiegakureLook/levels/level_3_detour.tscn",
]


## -1 for anything not in the list, so the older one-off scenes
## (miegakure_look_2/3/4.tscn) still work standalone and simply never advance.
static func index_of(scene_path: String) -> int:
	return LEVELS.find(scene_path)


## Empty string when there is no next level - either because this is the last one
## or because the scene isn't part of the sequence at all.
static func next_scene_path(scene_path: String) -> String:
	var index := index_of(scene_path)
	if index < 0 or index >= LEVELS.size() - 1:
		return ""
	return LEVELS[index + 1]


## 1-based, for display. 0 when the scene isn't in the sequence.
static func level_number(scene_path: String) -> int:
	return index_of(scene_path) + 1


static func total() -> int:
	return LEVELS.size()
