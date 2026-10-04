@tool
extends Node

## The grid's colours for a scene, live (Ramon, 4 Oct: "consider a dynamic way to change color
## and also grid line color"). Each swatch here (wall, floor, the chamber colours, ...) has a
## surface colour, a line colour, a subline colour and a grid strength; change one in the inspector
## and every surface wearing that swatch follows at once, in the editor and in play
## (LabKit/lab_grid.gd keeps the list). Code can call `set_swatch()` or `use_preset()` the same way.
##
## PRESETS are whole looks, cycled with `preset_key` while playing: Unreal's grey studio (the
## default), a black Marathon look with acid lines, and a white gallery with faint lines. A preset
## only touches the swatches it names.
##
## NO class_name (engine_gotchas.md).

const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")

## Every swatch, [surface, line, subline, strength]. Edit freely; the walls follow.
@export var swatches: Dictionary = {}:
	set(v):
		swatches = v
		_push()
## Cycles the presets while playing (none in the editor).
@export var preset_key: Key = KEY_F2

const PRESETS := [
	{"name": "Studio grey"},
	{
		"name": "Marathon black",
		"wall": [Color(0.09, 0.09, 0.10), Color(0.878, 0.976, 0.341), Color(0.20, 0.22, 0.16), 0.9],
		"floor": [Color(0.13, 0.13, 0.14), Color(0.42, 0.47, 0.18), Color(0.20, 0.21, 0.18), 0.9],
		"slate": [Color(0.878, 0.976, 0.341), Color(0.55, 0.62, 0.15), Color(0.80, 0.90, 0.30), 0.5],
	},
	{
		"name": "White gallery",
		"wall": [Color(0.93, 0.93, 0.92), Color(0.80, 0.80, 0.79), Color(0.89, 0.89, 0.88), 0.6],
		"floor": [Color(0.86, 0.86, 0.85), Color(0.70, 0.70, 0.70), Color(0.81, 0.81, 0.80), 0.6],
		"slate": [Color(0.12, 0.12, 0.13), Color(0.06, 0.06, 0.07), Color(0.10, 0.10, 0.11), 0.6],
	},
]

var _preset: int = 0


func _ready() -> void:
	if swatches.is_empty():
		var start: Dictionary = {}
		for k in LabGrid.DEFAULTS:
			start[k] = (LabGrid.DEFAULTS[k] as Array).duplicate()
		swatches = start
	_push()


## Sets one swatch, here and on every surface wearing it.
func set_swatch(swatch: String, surface: Color, line: Color, subline: Color, strength: float = 1.0) -> void:
	swatches[swatch] = [surface, line, subline, strength]
	LabGrid.set_swatch(swatch, surface, line, subline, strength)


## Switches to preset `index` (0 is the swatches as edited in the inspector).
func use_preset(index: int) -> void:
	_preset = posmod(index, PRESETS.size())
	if _preset == 0:
		_push()
		return
	var p: Dictionary = PRESETS[_preset]
	for k in p:
		if k == "name":
			continue
		var v: Array = p[k]
		LabGrid.set_swatch(String(k), v[0], v[1], v[2], float(v[3]))


func preset_name() -> String:
	return String((PRESETS[_preset] as Dictionary)["name"])


func _push() -> void:
	for k in swatches:
		var v: Array = swatches[k]
		if v.size() >= 4:
			LabGrid.set_swatch(String(k), v[0], v[1], v[2], float(v[3]))


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var k := event as InputEventKey
	# Not marked handled: the scene may want to say which preset is on.
	if k != null and k.pressed and not k.echo and k.keycode == preset_key:
		use_preset(_preset + 1)
